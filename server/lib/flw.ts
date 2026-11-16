import { env } from './env';

export interface FlwResult<T = any> { ok: boolean; status: string; message: string | null; data: T; needsWhitelist: boolean; httpStatus: number }

/** Thin Flutterwave v3 client. The secret key lives only in the server environment. */
export async function flw<T = any>(path: string, opts: { method?: 'GET' | 'POST' | 'DELETE'; body?: unknown } = {}): Promise<FlwResult<T>> {
  const ctl = new AbortController();
  const timer = setTimeout(() => ctl.abort(), 25_000);
  try {
    const res = await fetch(`https://api.flutterwave.com/v3${path}`, {
      method: opts.method ?? 'GET',
      headers: { Authorization: `Bearer ${env.flw.secret}`, 'Content-Type': 'application/json' },
      body: opts.body ? JSON.stringify(opts.body) : undefined,
      signal: ctl.signal,
    });
    const j: any = await res.json().catch(() => ({}));
    const message: string | null = j.message ?? null;
    return { ok: j.status === 'success', status: j.status ?? 'error', message, data: j.data as T, needsWhitelist: /IP Whitelisting/i.test(message ?? ''), httpStatus: res.status };
  } catch (e) {
    return { ok: false, status: 'error', message: (e as Error).name === 'AbortError' ? 'Payment partner timed out' : 'Payment partner unreachable', data: undefined as T, needsWhitelist: false, httpStatus: 0 };
  } finally {
    clearTimeout(timer);
  }
}

let banksCache: { at: number; list: { code: string; name: string }[] } | undefined;
export async function banks(): Promise<{ code: string; name: string }[]> {
  if (banksCache && Date.now() - banksCache.at < 6 * 3600_000) return banksCache.list;
  const r = await flw<{ code: string; name: string }[]>('/banks/NG');
  if (!r.ok || !Array.isArray(r.data)) return banksCache?.list ?? [];
  const seen = new Set<string>();
  const list = r.data.filter((b) => (seen.has(b.code) ? false : (seen.add(b.code), true))).map((b) => ({ code: b.code, name: b.name })).sort((a, b) => a.name.localeCompare(b.name));
  banksCache = { at: Date.now(), list };
  return list;
}
