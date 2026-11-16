import { createHash, createHmac, randomBytes, randomInt, scrypt as scryptCb, timingSafeEqual } from 'node:crypto';
import { promisify } from 'node:util';
import { SignJWT, jwtVerify } from 'jose';
import { env } from './env';
import { one, q } from './db';
import { ApiError, type Ctx } from './http';

const scrypt = promisify(scryptCb) as (pw: string, salt: Buffer, len: number, opts: object) => Promise<Buffer>;
const SCRYPT = { N: 16384, r: 8, p: 1, maxmem: 64 * 1024 * 1024 };

export async function hashSecret(secret: string): Promise<string> {
  const salt = randomBytes(16);
  const hash = await scrypt(secret, salt, 32, SCRYPT);
  return `s1$${salt.toString('base64')}$${hash.toString('base64')}`;
}

export async function checkSecret(secret: string, stored: string | null | undefined): Promise<boolean> {
  if (!stored) return false;
  const [v, s, h] = stored.split('$');
  if (v !== 's1' || !s || !h) return false;
  const expect = Buffer.from(h, 'base64');
  const got = await scrypt(secret, Buffer.from(s, 'base64'), expect.length, SCRYPT);
  return timingSafeEqual(got, expect);
}

export const sha256 = (s: string): string => createHash('sha256').update(s).digest('hex');
const safeEq = (a: string, b: string): boolean => { const x = Buffer.from(a), y = Buffer.from(b); return x.length === y.length && timingSafeEqual(x, y); };

// ───── sessions ─────
const ACCESS_TTL = '30m';
const REFRESH_DAYS = 30;

export async function issueSession(userId: string, email: string, ctx: Pick<Ctx, 'ip' | 'ua'>) {
  const refresh = randomBytes(32).toString('base64url');
  const rows = await q<{ id: string }>(
    `INSERT INTO sessions (user_id, token_hash, device, ip, expires_at) VALUES ($1,$2,$3,$4, now() + ($5 || ' days')::interval) RETURNING id`,
    [userId, sha256(refresh), ctx.ua.slice(0, 160), ctx.ip, String(REFRESH_DAYS)],
  );
  return { accessToken: await signAccess(userId, email, rows[0]!.id), refreshToken: refresh, expiresIn: 30 * 60 };
}

async function signAccess(userId: string, email: string, sid: string): Promise<string> {
  return new SignJWT({ email, sid }).setProtectedHeader({ alg: 'HS256' }).setSubject(userId).setIssuer('crystalpay').setIssuedAt().setExpirationTime(ACCESS_TTL).sign(env.jwtSecret);
}

/** Rotating refresh tokens. A reused (already rotated) token revokes every session of that user. */
export async function refreshSession(token: string, ctx: Pick<Ctx, 'ip' | 'ua'>) {
  const row = await one<{ id: string; user_id: string; revoked_at: string | null; expires_at: string; email: string; status: string }>(
    `SELECT s.id, s.user_id, s.revoked_at, s.expires_at, u.email, u.status FROM sessions s JOIN users u ON u.id = s.user_id WHERE s.token_hash = $1`,
    [sha256(token)],
  );
  if (!row) throw new ApiError(401, 'invalid_session', 'Please sign in again');
  if (row.revoked_at) {
    await q(`UPDATE sessions SET revoked_at = now() WHERE user_id = $1 AND revoked_at IS NULL`, [row.user_id]);
    throw new ApiError(401, 'invalid_session', 'Please sign in again');
  }
  if (new Date(row.expires_at) < new Date() || row.status !== 'active') throw new ApiError(401, 'invalid_session', 'Please sign in again');
  await q(`UPDATE sessions SET revoked_at = now() WHERE id = $1`, [row.id]);
  return issueSession(row.user_id, row.email, ctx);
}

export async function requireUser(ctx: Ctx): Promise<{ id: string; email: string }> {
  const h = ctx.headers.authorization;
  const token = typeof h === 'string' && h.startsWith('Bearer ') ? h.slice(7) : '';
  if (!token) throw new ApiError(401, 'unauthorized', 'Please sign in');
  try {
    const { payload } = await jwtVerify(token, env.jwtSecret, { issuer: 'crystalpay', algorithms: ['HS256'] });
    const sess = await one<{ revoked_at: string | null; status: string }>(
      `SELECT s.revoked_at, u.status FROM sessions s JOIN users u ON u.id = s.user_id WHERE s.id = $1 AND s.user_id = $2`,
      [payload.sid, payload.sub],
    );
    if (!sess || sess.revoked_at) throw new ApiError(401, 'unauthorized', 'Please sign in again');
    if (sess.status !== 'active') throw new ApiError(403, 'account_frozen', 'This account is on hold. Contact support.');
    ctx.user = { id: String(payload.sub), email: String(payload.email) };
    return ctx.user;
  } catch (e) {
    if (e instanceof ApiError) throw e;
    throw new ApiError(401, 'unauthorized', 'Your session expired. Please sign in again.');
  }
}

export async function revokeSessionByRefresh(token: string) {
  await q(`UPDATE sessions SET revoked_at = now() WHERE token_hash = $1 AND revoked_at IS NULL`, [sha256(token)]);
}
export async function revokeAll(userId: string) {
  await q(`UPDATE sessions SET revoked_at = now() WHERE user_id = $1 AND revoked_at IS NULL`, [userId]);
}

// ───── one-time codes ─────
const otpHash = (email: string, purpose: string, code: string) => createHmac('sha256', env.otpPepper).update(`${email}|${purpose}|${code}`).digest('hex');
const OTP_TTL_MIN = 10;
const OTP_MAX_ATTEMPTS = 5;

export async function createOtp(email: string, purpose: 'signup' | 'reset'): Promise<string> {
  const last = await one<{ created_at: string }>(`SELECT created_at FROM otp_codes WHERE lower(email) = $1 AND purpose = $2 AND consumed_at IS NULL ORDER BY created_at DESC LIMIT 1`, [email, purpose]);
  if (last && Date.now() - new Date(last.created_at).getTime() < 45_000) throw new ApiError(429, 'otp_cooldown', 'Please wait 45 seconds before asking for another code.');
  const code = String(randomInt(0, 1_000_000)).padStart(6, '0');
  await q(`UPDATE otp_codes SET consumed_at = now() WHERE lower(email) = $1 AND purpose = $2 AND consumed_at IS NULL`, [email, purpose]);
  await q(`INSERT INTO otp_codes (email, purpose, code_hash, expires_at) VALUES ($1,$2,$3, now() + ($4 || ' minutes')::interval)`, [email, purpose, otpHash(email, purpose, code), String(OTP_TTL_MIN)]);
  return code;
}

export async function checkOtp(email: string, purpose: 'signup' | 'reset', code: string): Promise<void> {
  const row = await one<{ id: number; code_hash: string; attempts: number; expires_at: string }>(
    `SELECT id, code_hash, attempts, expires_at FROM otp_codes WHERE lower(email) = $1 AND purpose = $2 AND consumed_at IS NULL ORDER BY created_at DESC LIMIT 1`,
    [email, purpose],
  );
  if (!row || new Date(row.expires_at) < new Date()) throw new ApiError(400, 'otp_expired', 'That code has expired. Request a new one.');
  if (row.attempts >= OTP_MAX_ATTEMPTS) throw new ApiError(429, 'otp_locked', 'Too many wrong codes. Request a new one.');
  if (!/^\d{6}$/.test(code) || !safeEq(row.code_hash, otpHash(email, purpose, code))) {
    await q(`UPDATE otp_codes SET attempts = attempts + 1 WHERE id = $1`, [row.id]);
    throw new ApiError(400, 'otp_invalid', 'That code is not correct.');
  }
  await q(`UPDATE otp_codes SET consumed_at = now() WHERE id = $1`, [row.id]);
}

export const OTP_MINUTES = OTP_TTL_MIN;
