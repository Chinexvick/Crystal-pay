import { one, q } from './db';

export interface LedgerRow { id: string; direction: 'credit' | 'debit'; amount_kobo: string; balance_after_kobo: string; kind: string; title: string; status: 'pending' | 'success' | 'failed'; ref: string; meta: Record<string, any>; created_at: string }

export async function ensureWallet(userId: string) {
  await q(`INSERT INTO wallets (user_id) VALUES ($1) ON CONFLICT DO NOTHING`, [userId]);
}

export async function balanceKobo(userId: string): Promise<number> {
  const r = await one<{ balance_kobo: string }>(`SELECT balance_kobo FROM wallets WHERE user_id = $1`, [userId]);
  return Number(r?.balance_kobo ?? 0);
}

interface Entry { ref: string; kind: string; title: string; meta?: Record<string, unknown>; status?: 'pending' | 'success' }

/**
 * Credit once. One SQL statement: the balance moves and the ledger row is written together, or neither.
 * The unique ledger.ref makes it safe to call twice (webhook + redirect + retry): the second call changes nothing.
 */
export async function credit(userId: string, kobo: number, e: Entry): Promise<{ created: boolean; balanceKobo: number }> {
  const rows = await q<{ balance_after_kobo: string }>(
    `WITH dup AS (SELECT 1 FROM ledger WHERE ref = $3),
          w AS (UPDATE wallets SET balance_kobo = balance_kobo + $2, updated_at = now()
                WHERE user_id = $1 AND NOT EXISTS (SELECT 1 FROM dup) RETURNING balance_kobo)
     INSERT INTO ledger (user_id, direction, amount_kobo, balance_after_kobo, kind, title, status, ref, meta)
     SELECT $1, 'credit', $2, w.balance_kobo, $4, $5, $6, $3, $7::jsonb FROM w
     RETURNING balance_after_kobo`,
    [userId, kobo, e.ref, e.kind, e.title, e.status ?? 'success', JSON.stringify(e.meta ?? {})],
  );
  if (rows[0]) return { created: true, balanceKobo: Number(rows[0].balance_after_kobo) };
  return { created: false, balanceKobo: await balanceKobo(userId) };
}

/** Debit once, only if the balance covers it. Returns null when funds are short (or the ref was already used). */
export async function debit(userId: string, kobo: number, e: Entry): Promise<{ balanceKobo: number } | null> {
  const rows = await q<{ balance_after_kobo: string }>(
    `WITH w AS (UPDATE wallets SET balance_kobo = balance_kobo - $2, updated_at = now()
                WHERE user_id = $1 AND balance_kobo >= $2 RETURNING balance_kobo)
     INSERT INTO ledger (user_id, direction, amount_kobo, balance_after_kobo, kind, title, status, ref, meta)
     SELECT $1, 'debit', $2, w.balance_kobo, $4, $5, $6, $3, $7::jsonb FROM w
     RETURNING balance_after_kobo`,
    [userId, kobo, e.ref, e.kind, e.title, e.status ?? 'pending', JSON.stringify(e.meta ?? {})],
  );
  return rows[0] ? { balanceKobo: Number(rows[0].balance_after_kobo) } : null;
}

export async function settle(ref: string, status: 'success' | 'failed', metaPatch: Record<string, unknown> = {}) {
  await q(`UPDATE ledger SET status = $2, meta = meta || $3::jsonb WHERE ref = $1 AND status = 'pending'`, [ref, status, JSON.stringify(metaPatch)]);
}

/** Give the money back after a failed debit. Safe to call twice. */
export async function refund(userId: string, kobo: number, originalRef: string, title: string, meta: Record<string, unknown> = {}) {
  await settle(originalRef, 'failed');
  return credit(userId, kobo, { ref: `refund:${originalRef}`, kind: 'refund', title, meta: { ...meta, originalRef } });
}

export function ledgerJson(r: LedgerRow) {
  return {
    id: String(r.id), type: r.direction, amount: Number(r.amount_kobo) / 100, balanceAfter: Number(r.balance_after_kobo) / 100,
    kind: r.kind, title: r.title, status: r.status, reference: r.ref, details: r.meta, date: r.created_at,
  };
}
