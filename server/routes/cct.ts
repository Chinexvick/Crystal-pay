import { one, q } from '../lib/db';
import { ApiError, type Ctx, amountNaira } from '../lib/http';
import { env } from '../lib/env';
import { depositJson, ensureAddress, scanUser, settingNum, simulateDeposit } from '../lib/chain';

export async function rate() {
  return { rate: await settingNum('cct_rate_ngn', 12.4), feePercent: await settingNum('cct_fee_percent', 1.5), confirmations: env.chain.confirmations, chain: env.chain.name, network: env.chain.name === 'bsc' ? 'BNB Smart Chain (BEP-20)' : 'BNB Smart Chain Testnet (BEP-20)', contract: env.chain.contract || null, watching: !!env.chain.contract, testMode: env.isTest };
}

export async function address(c: Ctx) {
  const a = await ensureAddress(c.user!.id);
  return { address: a.address, ...(await rate()) };
}

export async function deposits(c: Ctx) {
  await scanUser(c.user!.id);
  const rows = await q(`SELECT * FROM cct_deposits WHERE user_id = $1 ORDER BY detected_at DESC LIMIT 30`, [c.user!.id]);
  return { items: rows.map(depositJson) };
}

export async function deposit(c: Ctx) {
  await scanUser(c.user!.id);
  const d = await one(`SELECT * FROM cct_deposits WHERE id::text = $1 AND user_id = $2`, [c.params.id, c.user!.id]);
  if (!d) throw new ApiError(404, 'not_found', 'Deposit not found');
  return depositJson(d);
}

export async function simulate(c: Ctx) {
  if (!env.isTest) throw new ApiError(404, 'not_found', 'Not found');
  const tokens = amountNaira(c.body?.tokens ?? 100, 1, 1_000_000);
  await simulateDeposit(c.user!.id, tokens);
  return { ok: true, note: 'Test deposit created. It confirms in about 40 seconds.' };
}
