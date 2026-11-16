import { HDNodeWallet, formatUnits, zeroPadValue } from 'ethers';
import { env } from './env';
import { one, q } from './db';
import { credit } from './wallet';
import { notify } from './notify';
import { cctCredited, cctDetected } from './emails';

const TRANSFER_TOPIC = '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef';
const SIM_SECONDS_PER_CONF = 3;

let root: HDNodeWallet | undefined;
/** Each user gets their own address derived from one master phrase. Private keys are never stored. */
export function deriveAddress(index: number): string {
  root ??= HDNodeWallet.fromPhrase(env.chain.mnemonic, '', "m/44'/60'/0'/0");
  return root.deriveChild(index).address.toLowerCase();
}

async function rpc<T = any>(method: string, params: unknown[]): Promise<T> {
  const ctl = new AbortController();
  const t = setTimeout(() => ctl.abort(), 12_000);
  try {
    const res = await fetch(env.chain.rpc, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ jsonrpc: '2.0', id: 1, method, params }), signal: ctl.signal });
    const j: any = await res.json();
    if (j.error) throw new Error(j.error.message);
    return j.result as T;
  } finally { clearTimeout(t); }
}
const latestBlock = async () => parseInt(await rpc<string>('eth_blockNumber', []), 16);

export async function settingNum(key: string, d: number): Promise<number> {
  const r = await one<{ value: string }>(`SELECT value FROM settings WHERE key = $1`, [key]);
  const n = Number(r?.value);
  return Number.isFinite(n) && n > 0 ? n : d;
}

export async function ensureAddress(userId: string): Promise<{ address: string }> {
  const have = await one<{ address: string }>(`SELECT address FROM deposit_addresses WHERE user_id = $1`, [userId]);
  if (have) return have;
  const idx = (await one<{ n: string }>(`SELECT nextval('deposit_index_seq') AS n`))!.n;
  const address = deriveAddress(Number(idx));
  let start: number | null = null;
  try { if (env.chain.contract) start = await latestBlock(); } catch { /* the first scan will set it */ }
  await q(`INSERT INTO deposit_addresses (user_id, hd_index, address, last_scanned_block) VALUES ($1,$2,$3,$4) ON CONFLICT (user_id) DO NOTHING`, [userId, Number(idx), address, start]);
  return (await one<{ address: string }>(`SELECT address FROM deposit_addresses WHERE user_id = $1`, [userId]))!;
}

const lastScan = new Map<string, number>();

/** Look for new CCT transfers to this user's address, update confirmations, and credit the wallet once final. */
export async function scanUser(userId: string): Promise<void> {
  const addr = await one<{ address: string; last_scanned_block: string | null }>(`SELECT address, last_scanned_block FROM deposit_addresses WHERE user_id = $1`, [userId]);
  if (!addr) return;
  if (env.chain.contract && Date.now() - (lastScan.get(userId) ?? 0) > 2500) {
    lastScan.set(userId, Date.now());
    try { await scanChain(userId, addr.address, addr.last_scanned_block === null ? null : Number(addr.last_scanned_block)); } catch (e) { console.error('chain scan failed', (e as Error).message); }
  }
  await advance(userId);
}

async function scanChain(userId: string, address: string, last: number | null) {
  const latest = await latestBlock();
  let from = last === null ? latest : Math.max(last - 20, 0); // small overlap so a reorg cannot hide a transfer
  const topicTo = zeroPadValue(address, 32);
  let scanned = last ?? latest;
  for (let i = 0; i < 6 && from <= latest; i++) {
    const to = Math.min(from + 2999, latest);
    const logs = await rpc<any[]>('eth_getLogs', [{ address: env.chain.contract, fromBlock: '0x' + from.toString(16), toBlock: '0x' + to.toString(16), topics: [TRANSFER_TOPIC, null, topicTo] }]);
    for (const l of logs) {
      const tokens = formatUnits(BigInt(l.data), env.chain.decimals);
      const ins = await q<{ id: string }>(
        `INSERT INTO cct_deposits (user_id, address, tx_hash, log_index, tokens, block_number) VALUES ($1,$2,$3,$4,$5,$6) ON CONFLICT (tx_hash, log_index) DO NOTHING RETURNING id`,
        [userId, address, l.transactionHash, parseInt(l.logIndex, 16), tokens, parseInt(l.blockNumber, 16)],
      );
      if (ins[0]) await notify(userId, 'cct', 'CCT received', `${tokens} CCT is on the network. Waiting for confirmations.`, (n) => cctDetected(n, { tokens, txHash: l.transactionHash, confirmations: 0, required: env.chain.confirmations }));
    }
    scanned = to;
    from = to + 1;
  }
  await q(`UPDATE deposit_addresses SET last_scanned_block = $2 WHERE user_id = $1`, [userId, scanned]);
}

/** Move 'confirming' deposits forward and credit the ones that reached the required confirmations. */
async function advance(userId: string) {
  const pending = await q<any>(`SELECT * FROM cct_deposits WHERE user_id = $1 AND status = 'confirming'`, [userId]);
  if (!pending.length) return;
  let latest = 0;
  if (pending.some((d) => !d.simulated)) { try { latest = await latestBlock(); } catch { return; } }
  const required = env.chain.confirmations;
  const rate = await settingNum('cct_rate_ngn', 12.4);
  const feePct = await settingNum('cct_fee_percent', 1.5);
  for (const d of pending) {
    const conf = d.simulated ? Math.floor((Date.now() - new Date(d.detected_at).getTime()) / 1000 / SIM_SECONDS_PER_CONF) : Math.max(latest - Number(d.block_number) + 1, 0);
    if (conf < required) { await q(`UPDATE cct_deposits SET confirmations = $2 WHERE id = $1`, [d.id, conf]); continue; }
    const grossKobo = Math.round(Number(d.tokens) * rate * 100);
    const feeKobo = Math.round((grossKobo * feePct) / 100);
    const netKobo = grossKobo - feeKobo;
    if (netKobo <= 0) { await q(`UPDATE cct_deposits SET status = 'failed', confirmations = $2 WHERE id = $1`, [d.id, conf]); continue; }
    const won = await q(`UPDATE cct_deposits SET status = 'credited', confirmations = $2, rate = $3, gross_kobo = $4, fee_kobo = $5, net_kobo = $6, credited_at = now() WHERE id = $1 AND status = 'confirming' RETURNING id`, [d.id, required, rate, grossKobo, feeKobo, netKobo]);
    if (!won[0]) continue; // another request already finished it
    const tokens = Number(d.tokens).toString();
    const c = await credit(userId, netKobo, { ref: `cct:${d.tx_hash}:${d.log_index}`, kind: 'fund_cct', title: 'Crystal Cat (CCT)', meta: { tokens, rate, txHash: d.tx_hash, feeKobo, simulated: !!d.simulated } });
    await notify(userId, 'wallet', 'Wallet credited', `₦${(netKobo / 100).toLocaleString('en-NG')} was added from your ${tokens} CCT deposit.`, (n) => cctCredited(n, { tokens, rate, gross: grossKobo / 100, fee: feeKobo / 100, net: netKobo / 100, txHash: d.tx_hash, balance: c.balanceKobo / 100 }));
  }
}

export async function simulateDeposit(userId: string, tokens: number) {
  const { address } = await ensureAddress(userId);
  const hash = '0xsim' + [...crypto.getRandomValues(new Uint8Array(30))].map((b) => b.toString(16).padStart(2, '0')).join('');
  await q(`INSERT INTO cct_deposits (user_id, address, tx_hash, log_index, tokens, block_number, simulated) VALUES ($1,$2,$3,0,$4,0,true)`, [userId, address, hash, String(tokens)]);
  await notify(userId, 'cct', 'CCT received', `${tokens} CCT is on the network. Waiting for confirmations.`, (n) => cctDetected(n, { tokens: String(tokens), txHash: hash, confirmations: 0, required: env.chain.confirmations }));
}

export const depositJson = (d: any) => ({
  id: d.id, tokens: Number(d.tokens), txHash: d.tx_hash, confirmations: Number(d.confirmations), required: env.chain.confirmations,
  status: d.status === 'credited' ? 'completed' : d.status === 'failed' ? 'failed' : Number(d.confirmations) > 0 ? 'confirming' : 'detected',
  rate: d.rate ? Number(d.rate) : null, grossNaira: d.gross_kobo ? Number(d.gross_kobo) / 100 : null, feeNaira: d.fee_kobo ? Number(d.fee_kobo) / 100 : null,
  netNaira: d.net_kobo ? Number(d.net_kobo) / 100 : null, simulated: !!d.simulated, detectedAt: d.detected_at, creditedAt: d.credited_at,
});
