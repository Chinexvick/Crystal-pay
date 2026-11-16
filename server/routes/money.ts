import { randomUUID } from 'node:crypto';
import { one, q } from '../lib/db';
import { ApiError, type Ctx, amountNaira, limit, raw, str, toKobo } from '../lib/http';
import { env } from '../lib/env';
import { balanceKobo, credit, debit, ledgerJson, refund, settle, type LedgerRow } from '../lib/wallet';
import { banks, flw } from '../lib/flw';
import { notify } from '../lib/notify';
import { payoutAccountAdded, walletFunded, withdrawalFailed, withdrawalSent } from '../lib/emails';
import { settingNum } from '../lib/chain';
import { requirePin, userJson } from './me';

const MIN_FUND = 100, MAX_FUND = 5_000_000, MIN_WD = 500, MAX_WD_DAY = 2_000_000;

export async function wallet(c: Ctx) {
  return { balance: (await balanceKobo(c.user!.id)) / 100, currency: 'NGN', withdrawFee: await settingNum('withdraw_fee_ngn', 50), limits: { minFund: MIN_FUND, maxFund: MAX_FUND, minWithdraw: MIN_WD, dailyWithdraw: MAX_WD_DAY } };
}

export async function transactions(c: Ctx) {
  const lim = Math.min(Math.max(Number(c.query.get('limit')) || 30, 1), 100);
  const before = Number(c.query.get('before')) || 9e15;
  const rows = await q<LedgerRow>(`SELECT * FROM ledger WHERE user_id = $1 AND id < $2 ORDER BY id DESC LIMIT $3`, [c.user!.id, before, lim]);
  return { items: rows.map(ledgerJson), next: rows.length === lim ? String(rows[rows.length - 1]!.id) : null };
}

// ───── funding (Flutterwave hosted checkout) ─────
export async function fundInit(c: Ctx) {
  const id = c.user!.id;
  await limit(`fund:${id}`, 15, 3600);
  const amount = amountNaira(c.body?.amount, MIN_FUND, MAX_FUND);
  const u = await one<any>(`SELECT email, first_name, last_name, phone FROM users WHERE id = $1`, [id]);
  const txRef = `CP-${Date.now().toString(36)}-${randomUUID().slice(0, 8)}`.toUpperCase();
  await q(`INSERT INTO funding_sessions (tx_ref, user_id, amount_kobo, status) VALUES ($1,$2,$3,'pending')`, [txRef, id, toKobo(amount)]);
  const r = await flw<{ link: string }>('/payments', { method: 'POST', body: {
    tx_ref: txRef, amount, currency: 'NGN', redirect_url: `${env.baseUrl}/v1/pay/return`, payment_options: 'card,banktransfer,ussd',
    customer: { email: u.email, name: `${u.first_name} ${u.last_name}`, phonenumber: u.phone ?? undefined },
    customizations: { title: 'Crystal Pay', description: 'Add money to your wallet', logo: `${env.baseUrl}/logo.png` },
  } });
  if (!r.ok || !r.data?.link) {
    await q(`UPDATE funding_sessions SET status='failed', updated_at=now() WHERE tx_ref=$1`, [txRef]);
    throw new ApiError(502, 'payment_unavailable', 'Card payments are not available right now. Please try again shortly.');
  }
  return { txRef, link: r.data.link, amount };
}

/** Confirm with Flutterwave, then credit once. Safe to call from the redirect, the webhook and the app at the same time. */
export async function finalizeFunding(txRef: string): Promise<{ status: string; amount: number }> {
  const s = await one<any>(`SELECT * FROM funding_sessions WHERE tx_ref = $1`, [txRef]);
  if (!s) throw new ApiError(404, 'not_found', 'Payment not found');
  const amount = Number(s.amount_kobo) / 100;
  if (s.status === 'successful') return { status: 'successful', amount };
  const r = await flw<any>(`/transactions/verify_by_reference?tx_ref=${encodeURIComponent(txRef)}`);
  const d = r.data;
  if (!r.ok || !d) return { status: s.status, amount };
  if (d.status === 'successful' && d.tx_ref === txRef && d.currency === 'NGN' && Number(d.amount) >= amount) {
    const won = await q(`UPDATE funding_sessions SET status='successful', flw_id=$2, updated_at=now() WHERE tx_ref=$1 AND status <> 'successful' RETURNING tx_ref`, [txRef, String(d.id)]);
    const c = await credit(s.user_id, Number(s.amount_kobo), { ref: `fund:${txRef}`, kind: 'fund_card', title: 'Wallet top-up', meta: { method: d.payment_type ?? 'card', flwId: d.id, txRef } });
    if (won[0] && c.created) await notify(s.user_id, 'wallet', 'Wallet funded', `₦${amount.toLocaleString('en-NG')} was added to your wallet.`, (n) => walletFunded(n, { amount, method: String(d.payment_type ?? 'Card').replace(/^./, (x: string) => x.toUpperCase()), reference: txRef, balance: c.balanceKobo / 100 }));
    return { status: 'successful', amount };
  }
  if (['failed', 'cancelled'].includes(d.status)) { await q(`UPDATE funding_sessions SET status=$2, updated_at=now() WHERE tx_ref=$1 AND status='pending'`, [txRef, d.status]); return { status: d.status, amount }; }
  return { status: 'pending', amount };
}

export async function fundStatus(c: Ctx) {
  const s = await one<any>(`SELECT user_id FROM funding_sessions WHERE tx_ref = $1`, [c.params.txRef]);
  if (!s || s.user_id !== c.user!.id) throw new ApiError(404, 'not_found', 'Payment not found');
  const r = await finalizeFunding(c.params.txRef!);
  return { ...r, balance: (await balanceKobo(c.user!.id)) / 100 };
}

const page = (ok: boolean, msg: string) => `<!doctype html><meta name=viewport content="width=device-width,initial-scale=1"><title>Crystal Pay</title><body style="font-family:system-ui;text-align:center;padding:64px 24px;color:#0F1B3D"><img src="/logo.png" width=64 height=64 alt=""><h2 style="margin:18px 0 6px">${ok ? 'Payment received' : 'Payment not completed'}</h2><p style="color:#5B6785">${msg}</p><p style="color:#5B6785">You can close this page and return to the app.</p>`;
export async function payReturn(c: Ctx) {
  const txRef = c.query.get('tx_ref') ?? '';
  let ok = false;
  if (txRef) try { ok = (await finalizeFunding(txRef)).status === 'successful'; } catch { /* shown as not completed */ }
  return raw(200, { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store' }, page(ok, ok ? 'Your wallet has been credited.' : 'If money left your account, it will appear in your wallet shortly.'));
}

export async function flwWebhook(c: Ctx) {
  const want = env.flw.webhookHash;
  if (!want || c.headers['verif-hash'] !== want) throw new ApiError(401, 'unauthorized', 'Bad signature');
  const ev = c.body?.event ?? c.body?.['event.type'];
  const d = c.body?.data ?? {};
  if (String(ev).startsWith('charge') && d.tx_ref) await finalizeFunding(d.tx_ref).catch(() => {});
  if (String(ev).startsWith('transfer') && d.reference) await finishWithdrawal(d.reference, String(d.status).toUpperCase());
  return { ok: true };
}

// ───── banks and withdrawals ─────
export const bankList = async () => ({ items: await banks() });

export async function resolveAccount(c: Ctx) {
  await limit(`resolve:${c.user!.id}`, 30, 900);
  const acct = str(c.body?.accountNumber, 'Account number', { min: 10, max: 10 });
  const code = str(c.body?.bankCode, 'Bank', { max: 10 });
  if (!/^\d{10}$/.test(acct)) throw new ApiError(400, 'invalid_account', 'Account number must be 10 digits');
  const r = await flw<{ account_name: string }>('/accounts/resolve', { method: 'POST', body: { account_number: acct, account_bank: code } });
  if (r.ok && r.data?.account_name) return { accountName: r.data.account_name };
  if (env.isTest && (r.needsWhitelist || r.httpStatus === 0)) return { accountName: 'TEST ACCOUNT HOLDER', simulated: true };
  throw new ApiError(422, 'resolve_failed', r.needsWhitelist ? 'Account lookup is not available right now.' : 'We could not find that account. Check the number and bank.');
}

const acctJson = (a: any) => ({ id: a.id, bankCode: a.bank_code, bankName: a.bank_name, accountNumber: a.account_number, accountName: a.account_name });
export async function listAccounts(c: Ctx) {
  return { items: (await q(`SELECT * FROM payout_accounts WHERE user_id = $1 ORDER BY created_at DESC`, [c.user!.id])).map(acctJson) };
}
export async function addAccount(c: Ctx) {
  const id = c.user!.id;
  const acct = str(c.body?.accountNumber, 'Account number', { min: 10, max: 10 });
  const code = str(c.body?.bankCode, 'Bank', { max: 10 });
  const name = str(c.body?.accountName, 'Account name', { max: 120 });
  const bank = (await banks()).find((b) => b.code === code)?.name ?? str(c.body?.bankName, 'Bank name', { max: 80 });
  const r = await q(`INSERT INTO payout_accounts (user_id, bank_code, bank_name, account_number, account_name) VALUES ($1,$2,$3,$4,$5) ON CONFLICT (user_id, bank_code, account_number) DO UPDATE SET account_name = EXCLUDED.account_name RETURNING *`, [id, code, bank, acct, name]);
  await notify(id, 'security', 'Bank account added', `${bank} ${acct} was added.`, (n) => payoutAccountAdded(n, { bank, account: acct, accountName: name }));
  return { __status: 201, body: acctJson(r[0]) };
}
export async function deleteAccount(c: Ctx) {
  await q(`DELETE FROM payout_accounts WHERE id::text = $1 AND user_id = $2`, [c.params.id, c.user!.id]);
  return { ok: true };
}

export async function withdraw(c: Ctx) {
  const id = c.user!.id;
  await limit(`wd:${id}`, 10, 3600);
  const amount = amountNaira(c.body?.amount, MIN_WD, MAX_WD_DAY);
  await requirePin(id, c.body?.pin);
  const acct = await one<any>(`SELECT * FROM payout_accounts WHERE id::text = $1 AND user_id = $2`, [String(c.body?.accountId ?? ''), id]);
  if (!acct) throw new ApiError(404, 'not_found', 'Choose a bank account first.');
  const feeKobo = toKobo(await settingNum('withdraw_fee_ngn', 50));
  const kobo = toKobo(amount);
  const today = await one<{ s: string }>(`SELECT COALESCE(sum(amount_kobo),0) s FROM withdrawals WHERE user_id = $1 AND status <> 'failed' AND created_at > now() - interval '24 hours'`, [id]);
  if (Number(today!.s) + kobo > MAX_WD_DAY * 100) throw new ApiError(400, 'daily_limit', `Daily withdrawal limit is ₦${MAX_WD_DAY.toLocaleString('en-NG')}.`);
  const wid = randomUUID();
  const ref = `wd:${wid}`;
  const d = await debit(id, kobo + feeKobo, { ref, kind: 'withdraw', title: `Withdrawal to ${acct.bank_name}`, meta: { bank: acct.bank_name, account: acct.account_number, accountName: acct.account_name, fee: feeKobo / 100 } });
  if (!d) throw new ApiError(400, 'insufficient_funds', 'Your wallet balance is too low for this withdrawal and fee.');
  await q(`INSERT INTO withdrawals (id, user_id, account_id, amount_kobo, fee_kobo, status, ledger_ref) VALUES ($1,$2,$3,$4,$5,'pending',$6)`, [wid, id, acct.id, kobo, feeKobo, ref]);
  const r = await flw<any>('/transfers', { method: 'POST', body: { account_bank: acct.bank_code, account_number: acct.account_number, amount, narration: 'Crystal Pay withdrawal', currency: 'NGN', reference: ref.replace(':', '-'), debit_currency: 'NGN' } });
  const mail = { amount, fee: feeKobo / 100, bank: acct.bank_name, account: acct.account_number, accountName: acct.account_name, reference: ref };
  if (r.ok) {
    await q(`UPDATE withdrawals SET provider_ref = $2 WHERE id = $1`, [wid, String(r.data?.id ?? '')]);
    await notify(id, 'wallet', 'Withdrawal started', `₦${amount.toLocaleString('en-NG')} is on its way to ${acct.bank_name}.`, (n) => withdrawalSent(n, { ...mail, state: 'processing' }));
    return { id: wid, status: 'pending', amount, fee: feeKobo / 100, balance: d.balanceKobo / 100 };
  }
  if (env.isTest && (r.needsWhitelist || r.httpStatus === 0)) {
    await finishWithdrawal(ref, 'SUCCESSFUL', true);
    return { id: wid, status: 'successful', simulated: true, amount, fee: feeKobo / 100, balance: d.balanceKobo / 100 };
  }
  await finishWithdrawal(ref, 'FAILED');
  throw new ApiError(502, 'transfer_failed', 'The bank transfer could not be started. Your money was returned to your wallet.');
}

export async function finishWithdrawal(ref: string, flwStatus: string, simulated = false) {
  const w = await one<any>(`SELECT w.*, a.bank_name, a.account_number, a.account_name FROM withdrawals w JOIN payout_accounts a ON a.id = w.account_id WHERE w.ledger_ref = $1`, [ref.replace(/^wd-/, 'wd:')]);
  if (!w || w.status !== 'pending') return;
  const amount = Number(w.amount_kobo) / 100, fee = Number(w.fee_kobo) / 100;
  const info = { amount, fee, bank: w.bank_name, account: w.account_number, accountName: w.account_name, reference: w.ledger_ref };
  if (flwStatus === 'SUCCESSFUL') {
    if (!(await q(`UPDATE withdrawals SET status='successful' WHERE id=$1 AND status='pending' RETURNING id`, [w.id]))[0]) return;
    await settle(w.ledger_ref, 'success', simulated ? { simulated: true } : {});
    await notify(w.user_id, 'wallet', 'Withdrawal complete', `₦${amount.toLocaleString('en-NG')} was sent to ${w.bank_name}.`, (n) => withdrawalSent(n, { ...info, state: 'success' }));
  } else if (flwStatus === 'FAILED') {
    if (!(await q(`UPDATE withdrawals SET status='failed' WHERE id=$1 AND status='pending' RETURNING id`, [w.id]))[0]) return;
    await refund(w.user_id, Number(w.amount_kobo) + Number(w.fee_kobo), w.ledger_ref, 'Withdrawal refunded');
    await notify(w.user_id, 'wallet', 'Withdrawal refunded', 'The transfer failed. Your money is back in your wallet.', (n) => withdrawalFailed(n, { amount, fee, reference: w.ledger_ref }));
  }
}
void userJson;
