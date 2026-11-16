import { one, q } from '../lib/db';
import { ApiError, type Ctx, email, limit, password, phone, str } from '../lib/http';
import { OTP_MINUTES, checkOtp, checkSecret, createOtp, hashSecret, issueSession, refreshSession, revokeAll, revokeSessionByRefresh } from '../lib/auth';
import { sendMail } from '../lib/mail';
import { notify } from '../lib/notify';
import { ensureWallet } from '../lib/wallet';
import { loginAlert, otpReset, otpSignup, passwordChanged, welcome } from '../lib/emails';
import { userJson } from './me';

async function mailOtp(to: string, mail: ReturnType<typeof otpSignup>) {
  try { await sendMail(to, mail); } catch { throw new ApiError(502, 'email_failed', 'We could not send the email right now. Please try again in a minute.'); }
}

export async function signup(c: Ctx) {
  await limit(`signup:${c.ip}`, 10, 3600);
  const em = email(c.body?.email);
  const pw = password(c.body?.password);
  const first = str(c.body?.firstName, 'First name', { max: 40 });
  const last = str(c.body?.lastName, 'Last name', { max: 40 });
  const ph = c.body?.phone ? phone(c.body.phone) : null;
  const hash = await hashSecret(pw);
  const ex = await one<{ id: string; email_verified_at: string | null }>(`SELECT id, email_verified_at FROM users WHERE email = $1`, [em]);
  if (ex?.email_verified_at) throw new ApiError(409, 'email_taken', 'An account with this email already exists. Sign in instead.');
  if (ex) await q(`UPDATE users SET password_hash=$2, first_name=$3, last_name=$4, phone=$5 WHERE id=$1`, [ex.id, hash, first, last, ph]);
  else await q(`INSERT INTO users (email, password_hash, first_name, last_name, phone) VALUES ($1,$2,$3,$4,$5)`, [em, hash, first, last, ph]);
  const code = await createOtp(em, 'signup');
  await mailOtp(em, otpSignup(code, OTP_MINUTES));
  return { __status: 201, body: { email: em, otpSent: true, expiresInMinutes: OTP_MINUTES } };
}

export async function resendOtp(c: Ctx) {
  await limit(`resend:${c.ip}`, 10, 3600);
  const em = email(c.body?.email);
  const purpose = c.body?.purpose === 'reset' ? 'reset' : 'signup';
  const u = await one<{ email_verified_at: string | null }>(`SELECT email_verified_at FROM users WHERE email = $1`, [em]);
  if (u && (purpose === 'reset' || !u.email_verified_at)) {
    const code = await createOtp(em, purpose);
    await mailOtp(em, purpose === 'reset' ? otpReset(code, OTP_MINUTES) : otpSignup(code, OTP_MINUTES));
  }
  return { otpSent: true };
}

export async function verifyOtp(c: Ctx) {
  await limit(`verify:${c.ip}`, 20, 900);
  const em = email(c.body?.email);
  await checkOtp(em, 'signup', String(c.body?.code ?? ''));
  const u = await one<{ id: string; first_name: string }>(`UPDATE users SET email_verified_at = COALESCE(email_verified_at, now()), last_login_at = now() WHERE email = $1 RETURNING id, first_name`, [em]);
  if (!u) throw new ApiError(404, 'not_found', 'Account not found');
  await ensureWallet(u.id);
  const tokens = await issueSession(u.id, em, c);
  await notify(u.id, 'account', 'Welcome to Crystal Pay', 'Your email is verified and your wallet is ready.', (n) => welcome(n));
  return { ...tokens, user: await userJson(u.id) };
}

export async function login(c: Ctx) {
  const em = email(c.body?.email);
  await limit(`login:${c.ip}`, 30, 900);
  await limit(`login:${em}`, 8, 900);
  const u = await one<{ id: string; password_hash: string; email_verified_at: string | null; status: string; first_name: string }>(`SELECT id, password_hash, email_verified_at, status, first_name FROM users WHERE email = $1`, [em]);
  const ok = await checkSecret(String(c.body?.password ?? ''), u?.password_hash ?? 'x');
  if (!u || !ok) throw new ApiError(401, 'bad_credentials', 'Email or password is not correct.');
  if (u.status !== 'active') throw new ApiError(403, 'account_frozen', 'This account is on hold. Contact support.');
  if (!u.email_verified_at) {
    const code = await createOtp(em, 'signup').catch(() => null);
    if (code) await mailOtp(em, otpSignup(code, OTP_MINUTES));
    throw new ApiError(403, 'email_not_verified', 'Verify your email to continue. We sent you a new code.', { email: em });
  }
  await q(`UPDATE users SET last_login_at = now() WHERE id = $1`, [u.id]);
  const tokens = await issueSession(u.id, em, c);
  await notify(u.id, 'security', 'New sign-in', 'Your account was signed in on a device.', (n) => loginAlert(n, { ip: c.ip, device: c.ua.slice(0, 80) }));
  return { ...tokens, user: await userJson(u.id) };
}

export async function refresh(c: Ctx) {
  await limit(`refresh:${c.ip}`, 60, 900);
  return refreshSession(str(c.body?.refreshToken, 'refreshToken', { max: 200 }), c);
}

export async function logout(c: Ctx) {
  if (typeof c.body?.refreshToken === 'string') await revokeSessionByRefresh(c.body.refreshToken);
  return { ok: true };
}

export async function forgot(c: Ctx) {
  await limit(`forgot:${c.ip}`, 10, 3600);
  const em = email(c.body?.email);
  const u = await one(`SELECT id FROM users WHERE email = $1 AND email_verified_at IS NOT NULL`, [em]);
  if (u) {
    try { const code = await createOtp(em, 'reset'); await mailOtp(em, otpReset(code, OTP_MINUTES)); } catch (e) { if (e instanceof ApiError && e.code === 'email_failed') throw e; }
  }
  return { otpSent: true }; // same answer whether or not the account exists
}

export async function reset(c: Ctx) {
  await limit(`reset:${c.ip}`, 15, 900);
  const em = email(c.body?.email);
  const pw = password(c.body?.newPassword);
  await checkOtp(em, 'reset', String(c.body?.code ?? ''));
  const u = await one<{ id: string }>(`UPDATE users SET password_hash = $2 WHERE email = $1 RETURNING id`, [em, await hashSecret(pw)]);
  if (!u) throw new ApiError(404, 'not_found', 'Account not found');
  await revokeAll(u.id);
  await notify(u.id, 'security', 'Password changed', 'Your password was reset.', (n) => passwordChanged(n));
  return { ok: true };
}
