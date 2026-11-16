import { one, q } from '../lib/db';
import { ApiError, type Ctx, limit, phone, raw, str } from '../lib/http';
import { checkSecret, hashSecret, revokeAll } from '../lib/auth';
import { password } from '../lib/http';
import { balanceKobo } from '../lib/wallet';
import { notify } from '../lib/notify';
import { kycSkipped, passwordChanged, photoUpdated, pinSet, profileUpdated } from '../lib/emails';
import { env } from '../lib/env';

export async function userJson(id: string) {
  const u = await one<any>(`SELECT u.*, a.version AS av FROM users u LEFT JOIN user_avatars a ON a.user_id = u.id WHERE u.id = $1`, [id]);
  if (!u) throw new ApiError(404, 'not_found', 'Account not found');
  return {
    id: u.id, email: u.email, firstName: u.first_name, lastName: u.last_name, name: [u.first_name, u.last_name].filter(Boolean).join(' '),
    phone: u.phone, kycStatus: u.kyc_status, hasPin: !!u.pin_hash, emailVerified: !!u.email_verified_at, createdAt: u.created_at,
    avatarUrl: u.av ? `${env.baseUrl}/v1/avatars/${u.id}?v=${u.av}` : null, balance: (await balanceKobo(id)) / 100,
  };
}

export const me = (c: Ctx) => userJson(c.user!.id);

export async function updateMe(c: Ctx) {
  const id = c.user!.id;
  const old = await one<any>(`SELECT first_name, last_name, phone FROM users WHERE id = $1`, [id]);
  const first = c.body?.firstName !== undefined ? str(c.body.firstName, 'First name', { max: 40 }) : old.first_name;
  const last = c.body?.lastName !== undefined ? str(c.body.lastName, 'Last name', { max: 40 }) : old.last_name;
  const ph = c.body?.phone !== undefined ? phone(c.body.phone) : old.phone;
  const changes: [string, string][] = [];
  if (first !== old.first_name || last !== old.last_name) changes.push(['Name', `${first} ${last}`]);
  if (ph !== old.phone) changes.push(['Phone', ph ?? '']);
  if (changes.length) {
    await q(`UPDATE users SET first_name=$2, last_name=$3, phone=$4 WHERE id=$1`, [id, first, last, ph]);
    await notify(id, 'account', 'Profile updated', changes.map(([k, v]) => `${k}: ${v}`).join(' · '), (n) => profileUpdated(n, changes));
  }
  return userJson(id);
}

const MAGIC: [string, number[]][] = [['image/jpeg', [0xff, 0xd8, 0xff]], ['image/png', [0x89, 0x50, 0x4e, 0x47]], ['image/webp', [0x52, 0x49, 0x46, 0x46]]];
export async function putAvatar(c: Ctx) {
  const b64 = str(c.body?.data, 'Image', { max: 1_200_000 }).replace(/^data:[^;]+;base64,/, '');
  const buf = Buffer.from(b64, 'base64');
  if (buf.length < 100 || buf.length > 800_000) throw new ApiError(400, 'invalid_image', 'Choose a photo under 800 KB.');
  const mime = MAGIC.find(([, m]) => m.every((x, i) => buf[i] === x))?.[0];
  if (!mime) throw new ApiError(400, 'invalid_image', 'Use a JPG, PNG or WebP photo.');
  await q(`INSERT INTO user_avatars (user_id, mime, data) VALUES ($1,$2,$3) ON CONFLICT (user_id) DO UPDATE SET mime=$2, data=$3, version=user_avatars.version+1, updated_at=now()`, [c.user!.id, mime, buf]);
  await notify(c.user!.id, 'account', 'Profile photo updated', 'Your profile picture was changed.', (n) => photoUpdated(n));
  return userJson(c.user!.id);
}

export async function getAvatar(c: Ctx) {
  const r = await one<{ mime: string; data: Buffer }>(`SELECT mime, data FROM user_avatars WHERE user_id::text = $1`, [c.params.id]);
  if (!r) throw new ApiError(404, 'not_found', 'No photo');
  const data = Buffer.isBuffer(r.data) ? r.data : Buffer.from(String(r.data).replace(/^\\x/, ''), 'hex');
  return raw(200, { 'Content-Type': r.mime, 'Cache-Control': 'public, max-age=86400, immutable' }, data);
}

export async function changePassword(c: Ctx) {
  const id = c.user!.id;
  await limit(`pw:${id}`, 8, 900);
  const u = await one<{ password_hash: string }>(`SELECT password_hash FROM users WHERE id = $1`, [id]);
  if (!(await checkSecret(String(c.body?.currentPassword ?? ''), u?.password_hash))) throw new ApiError(400, 'bad_credentials', 'Your current password is not correct.');
  await q(`UPDATE users SET password_hash = $2 WHERE id = $1`, [id, await hashSecret(password(c.body?.newPassword))]);
  await revokeAll(id);
  await notify(id, 'security', 'Password changed', 'Your password was changed.', (n) => passwordChanged(n));
  return { ok: true, signedOut: true };
}

const pinOk = (v: unknown): string => { if (typeof v !== 'string' || !/^\d{4}$/.test(v)) throw new ApiError(400, 'invalid_pin', 'PIN must be 4 digits'); return v; };

export async function setPin(c: Ctx) {
  const id = c.user!.id;
  await limit(`pin:${id}`, 10, 900);
  const u = await one<{ pin_hash: string | null }>(`SELECT pin_hash FROM users WHERE id = $1`, [id]);
  if (u?.pin_hash && !(await checkSecret(String(c.body?.currentPin ?? ''), u.pin_hash))) throw new ApiError(400, 'bad_pin', 'Your current PIN is not correct.');
  await q(`UPDATE users SET pin_hash = $2 WHERE id = $1`, [id, await hashSecret(pinOk(c.body?.pin))]);
  await notify(id, 'security', 'Transaction PIN set', 'Your transaction PIN was saved.', (n) => pinSet(n, !!u?.pin_hash));
  return { ok: true, hasPin: true };
}

export async function verifyPinRoute(c: Ctx) {
  await requirePin(c.user!.id, c.body?.pin);
  return { ok: true };
}

/** Used before spending money. Users who have not set a PIN yet are not blocked. */
export async function requirePin(userId: string, pin: unknown): Promise<void> {
  const u = await one<{ pin_hash: string | null }>(`SELECT pin_hash FROM users WHERE id = $1`, [userId]);
  if (!u?.pin_hash) return;
  await limit(`pinv:${userId}`, 8, 900);
  if (typeof pin !== 'string' || !(await checkSecret(pin, u.pin_hash))) throw new ApiError(400, 'bad_pin', 'Wrong PIN.');
}

export async function skipKyc(c: Ctx) {
  const id = c.user!.id;
  const r = await q(`UPDATE users SET kyc_status = 'skipped' WHERE id = $1 AND kyc_status = 'none' RETURNING id`, [id]);
  if (r[0]) await notify(id, 'account', 'Verification skipped', 'You can verify your identity later from Me.', (n) => kycSkipped(n));
  return userJson(id);
}

export async function notifications(c: Ctx) {
  const rows = await q<any>(`SELECT id, kind, title, body, read_at, created_at FROM notifications WHERE user_id = $1 ORDER BY id DESC LIMIT 50`, [c.user!.id]);
  return { items: rows.map((n) => ({ id: String(n.id), kind: n.kind, title: n.title, body: n.body, read: !!n.read_at, date: n.created_at })), unread: rows.filter((n) => !n.read_at).length };
}
export async function readNotifications(c: Ctx) {
  await q(`UPDATE notifications SET read_at = now() WHERE user_id = $1 AND read_at IS NULL`, [c.user!.id]);
  return { ok: true };
}
