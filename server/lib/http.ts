import type { IncomingMessage } from 'node:http';
import { q } from './db';

export class ApiError extends Error {
  constructor(public status: number, public code: string, message: string, public extra?: Record<string, unknown>) {
    super(message);
  }
}

export interface Ctx {
  method: string;
  path: string;
  query: URLSearchParams;
  body: any;
  ip: string;
  ua: string;
  headers: IncomingMessage['headers'];
  params: Record<string, string>;
  user?: { id: string; email: string };
}

export interface Raw { __raw: true; status: number; headers: Record<string, string>; body: string | Buffer }
export const raw = (status: number, headers: Record<string, string>, body: string | Buffer): Raw => ({ __raw: true, status, headers, body });
export const isRaw = (v: unknown): v is Raw => !!v && typeof v === 'object' && (v as Raw).__raw === true;

export const naira = (kobo: number | string | bigint): number => Number(kobo) / 100;
export const toKobo = (n: number): number => Math.round(n * 100);

export function str(v: unknown, name: string, { min = 1, max = 200 } = {}): string {
  if (typeof v !== 'string') throw new ApiError(400, 'invalid_input', `${name} is required`);
  const s = v.trim();
  if (s.length < min || s.length > max) throw new ApiError(400, 'invalid_input', `${name} must be ${min}-${max} characters`);
  return s;
}

export function email(v: unknown): string {
  const s = str(v, 'Email', { max: 254 }).toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(s)) throw new ApiError(400, 'invalid_email', 'Enter a valid email address');
  return s;
}

export function password(v: unknown): string {
  if (typeof v !== 'string' || v.length < 8) throw new ApiError(400, 'weak_password', 'Password must be at least 8 characters');
  if (v.length > 128) throw new ApiError(400, 'weak_password', 'Password is too long');
  if (!/[a-zA-Z]/.test(v) || !/\d/.test(v)) throw new ApiError(400, 'weak_password', 'Use letters and at least one number');
  return v;
}

export function phone(v: unknown): string {
  let s = str(v, 'Phone number', { max: 20 }).replace(/[\s-]/g, '');
  if (s.startsWith('+234')) s = '0' + s.slice(4);
  else if (s.startsWith('234') && s.length === 13) s = '0' + s.slice(3);
  if (!/^0[789][01]\d{8}$/.test(s)) throw new ApiError(400, 'invalid_phone', 'Enter a valid Nigerian phone number');
  return s;
}

export function amountNaira(v: unknown, min: number, max: number): number {
  const n = typeof v === 'number' ? v : Number(v);
  if (!Number.isFinite(n) || n < min || n > max) throw new ApiError(400, 'invalid_amount', `Amount must be between ₦${min.toLocaleString('en-NG')} and ₦${max.toLocaleString('en-NG')}`);
  return Math.round(n * 100) / 100;
}

/** Fixed-window counter in Postgres. Throws 429 when the limit is exceeded. */
export async function limit(key: string, max: number, windowSec: number): Promise<void> {
  const rows = await q<{ hits: number }>(
    `INSERT INTO rate_limits (key, window_start, hits)
     VALUES ($1, to_timestamp(floor(extract(epoch from now()) / $2) * $2), 1)
     ON CONFLICT (key, window_start) DO UPDATE SET hits = rate_limits.hits + 1
     RETURNING hits`,
    [key, windowSec],
  );
  if (Math.random() < 0.02) void q(`DELETE FROM rate_limits WHERE window_start < now() - interval '1 day'`).catch(() => {});
  if ((rows[0]?.hits ?? 0) > max) throw new ApiError(429, 'too_many_requests', 'Too many attempts. Please wait a moment and try again.');
}

export const clientIp = (req: IncomingMessage): string => {
  const xf = req.headers['x-forwarded-for'];
  const first = (Array.isArray(xf) ? xf[0] : xf)?.split(',')[0]?.trim();
  return first || (req.headers['x-real-ip'] as string) || req.socket.remoteAddress || 'unknown';
};

export const esc = (s: unknown): string => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]!);
