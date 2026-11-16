import { randomUUID } from 'node:crypto';
import { one, q } from '../lib/db';
import { ApiError, type Ctx, amountNaira, limit, str, toKobo } from '../lib/http';
import { env } from '../lib/env';
import { debit, refund, settle } from '../lib/wallet';
import { flw } from '../lib/flw';
import { type BillKind, billerFor, items, supported } from '../lib/bills';
import { notify } from '../lib/notify';
import { billFailed, billSuccess } from '../lib/emails';
import { requirePin } from './me';

const KINDS: BillKind[] = ['airtime', 'data', 'power', 'tv', 'internet'];
const TITLE: Record<BillKind, string> = { airtime: 'Airtime', data: 'Data bundle', power: 'Electricity', tv: 'TV subscription', internet: 'Internet' };
const kind = (v: unknown): BillKind => { if (!KINDS.includes(v as BillKind)) throw new ApiError(400, 'invalid_input', 'Unknown service'); return v as BillKind; };

export const providers = async () => ({ supported: supported() });

export async function plans(c: Ctx) {
  const k = kind(c.query.get('kind'));
  const r = await items(k, c.query.get('provider') ?? '');
  if (!r) throw new ApiError(404, 'unavailable', 'This provider is not available yet.');
  return { billerCode: r.billerCode, items: r.items };
}

export async function validate(c: Ctx) {
  await limit(`bv:${c.user!.id}`, 40, 900);
  const k = kind(c.body?.kind);
  const customer = str(c.body?.customer, 'Customer', { max: 40 });
  const itemCode = str(c.body?.itemCode, 'Item', { max: 40 });
  const r = await flw<any>(`/bill-items/${encodeURIComponent(itemCode)}/validate?code=${encodeURIComponent(c.body?.billerCode ?? billerFor(k, String(c.body?.provider)) ?? '')}&customer=${encodeURIComponent(customer)}`);
  if (r.ok) return { valid: true, name: r.data?.name ?? r.data?.customer ?? null, address: r.data?.address ?? null };
  if (env.isTest && (r.needsWhitelist || r.httpStatus === 0)) return { valid: true, name: 'Test customer', simulated: true };
  throw new ApiError(422, 'invalid_customer', 'We could not verify that number. Check it and try again.');
}

export async function pay(c: Ctx) {
  const id = c.user!.id;
  await limit(`bp:${id}`, 20, 3600);
  const k = kind(c.body?.kind);
  const provider = str(c.body?.provider, 'Provider', { max: 30 });
  const list = await items(k, provider);
  if (!list) throw new ApiError(404, 'unavailable', 'This provider is not available yet.');
  const itemCode = str(c.body?.itemCode, 'Plan', { max: 40 });
  const item = list.items.find((i) => i.itemCode === itemCode);
  if (!item) throw new ApiError(400, 'invalid_input', 'Choose a valid plan.');
  const customer = str(c.body?.customer, 'Customer', { max: 40 });
  const amount = item.amount > 0 && k !== 'airtime' && k !== 'power' ? item.amount : amountNaira(c.body?.amount, 50, 500_000);
  await requirePin(id, c.body?.pin);
  const oid = randomUUID(), ref = `bill:${oid}`, kobo = toKobo(amount);
  const title = `${TITLE[k]} · ${item.name || provider.toUpperCase()}`;
  const d = await debit(id, kobo, { ref, kind: `bill_${k}`, title, meta: { customer, provider, itemCode } });
  if (!d) throw new ApiError(400, 'insufficient_funds', 'Your wallet balance is too low. Add money and try again.');
  await q(`INSERT INTO bill_orders (id, user_id, category, biller_code, item_code, biller_name, customer, amount_kobo, status, ledger_ref) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,'pending',$9)`, [oid, id, k, list.billerCode, itemCode, item.name, customer, kobo, ref]);
  const r = await flw<any>(`/billers/${list.billerCode}/items/${itemCode}/payment`, { method: 'POST', body: { country: 'NG', customer_id: customer, amount, reference: `bill-${oid}` } });
  let simulated = false;
  if (!r.ok && env.isTest && (r.needsWhitelist || r.httpStatus === 0)) simulated = true;
  if (r.ok || simulated) {
    const token: string | undefined = r.data?.token ?? r.data?.extra ?? undefined;
    await q(`UPDATE bill_orders SET status='successful', provider_ref=$2, token=$3, meta = meta || $4::jsonb WHERE id=$1`, [oid, String(r.data?.reference ?? ''), token ?? null, JSON.stringify({ simulated })]);
    await settle(ref, 'success', simulated ? { simulated: true } : {});
    await notify(id, 'payment', `${TITLE[k]} successful`, `₦${amount.toLocaleString('en-NG')} · ${customer}`, (n) => billSuccess(n, { title, customer, amount, reference: ref, token, test: simulated }));
    return { id: oid, status: 'successful', simulated, amount, token: token ?? null, reference: ref, balance: d.balanceKobo / 100 };
  }
  await q(`UPDATE bill_orders SET status='failed' WHERE id=$1`, [oid]);
  await refund(id, kobo, ref, `${title} refunded`);
  await notify(id, 'payment', `${TITLE[k]} failed`, 'We returned your money.', (n) => billFailed(n, { title, amount, reference: ref }));
  throw new ApiError(502, 'bill_failed', 'The provider could not complete this payment. Your money was returned to your wallet.');
}
void one;
