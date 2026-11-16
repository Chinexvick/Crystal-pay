import type { IncomingMessage, ServerResponse } from 'node:http';
import { ApiError, type Ctx, clientIp, isRaw } from '../lib/http';
import { requireUser } from '../lib/auth';
import { one } from '../lib/db';
import { env } from '../lib/env';
import * as A from '../routes/auth';
import * as M from '../routes/me';
import * as W from '../routes/money';
import * as B from '../routes/bills';
import * as C from '../routes/cct';

type H = (c: Ctx) => Promise<unknown> | unknown;
const routes: { m: string; re: RegExp; keys: string[]; h: H; auth: boolean }[] = [];
const add = (m: string, p: string, h: H, auth = true) => {
  const keys: string[] = [];
  const re = new RegExp('^' + p.replace(/:(\w+)/g, (_, k) => (keys.push(k), '([^/]+)')) + '/?$');
  routes.push({ m, re, keys, h, auth });
};

add('GET', '/health', async () => { await one('SELECT 1'); return { ok: true, mode: env.mode }; }, false);
add('POST', '/auth/signup', A.signup, false);
add('POST', '/auth/verify-otp', A.verifyOtp, false);
add('POST', '/auth/resend-otp', A.resendOtp, false);
add('POST', '/auth/login', A.login, false);
add('POST', '/auth/refresh', A.refresh, false);
add('POST', '/auth/logout', A.logout, false);
add('POST', '/auth/forgot', A.forgot, false);
add('POST', '/auth/reset', A.reset, false);
add('GET', '/avatars/:id', M.getAvatar, false);
add('GET', '/pay/return', W.payReturn, false);
add('POST', '/webhooks/flutterwave', W.flwWebhook, false);

add('GET', '/me', M.me);
add('PATCH', '/me', M.updateMe);
add('PUT', '/me/avatar', M.putAvatar);
add('POST', '/me/password', M.changePassword);
add('POST', '/me/pin', M.setPin);
add('POST', '/me/pin/verify', M.verifyPinRoute);
add('POST', '/me/kyc/skip', M.skipKyc);
add('GET', '/notifications', M.notifications);
add('POST', '/notifications/read', M.readNotifications);

add('GET', '/wallet', W.wallet);
add('GET', '/transactions', W.transactions);
add('POST', '/funding/flutterwave/initialize', W.fundInit);
add('GET', '/funding/flutterwave/:txRef', W.fundStatus);
add('GET', '/banks', W.bankList);
add('POST', '/banks/resolve', W.resolveAccount);
add('GET', '/payout-accounts', W.listAccounts);
add('POST', '/payout-accounts', W.addAccount);
add('DELETE', '/payout-accounts/:id', W.deleteAccount);
add('POST', '/payouts/bank', W.withdraw);

add('GET', '/bills/providers', B.providers);
add('GET', '/bills/plans', B.plans);
add('POST', '/bills/validate', B.validate);
add('POST', '/bills/pay', B.pay);

add('GET', '/cct/rate', C.rate);
add('GET', '/cct/address', C.address);
add('GET', '/cct/deposits', C.deposits);
add('GET', '/cct/deposits/:id', C.deposit);
add('POST', '/cct/simulate', C.simulate);

async function readBody(req: IncomingMessage): Promise<any> {
  const pre = (req as any).body;
  if (pre !== undefined) { if (typeof pre === 'string') { try { return JSON.parse(pre); } catch { return {}; } } return pre ?? {}; }
  const chunks: Buffer[] = [];
  for await (const ch of req) chunks.push(ch as Buffer);
  try { return JSON.parse(Buffer.concat(chunks).toString() || '{}'); } catch { return {}; }
}

function send(res: ServerResponse, status: number, body: unknown) {
  const s = JSON.stringify(body);
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
  res.end(s);
}

export default async function handler(req: IncomingMessage, res: ServerResponse) {
  try {
    const url = new URL(req.url ?? '/', 'http://x');
    const path = url.pathname.replace(/^\/v1/, '') || '/';
    const method = (req.method ?? 'GET').toUpperCase();
    if (method === 'OPTIONS') { res.writeHead(204); return res.end(); }
    const route = routes.find((r) => r.m === method && r.re.test(path));
    if (!route) throw new ApiError(404, 'not_found', 'Not found');
    const m = path.match(route.re)!;
    const ctx: Ctx = {
      method, path, query: url.searchParams, body: method === 'GET' ? {} : await readBody(req), ip: clientIp(req),
      ua: String(req.headers['user-agent'] ?? ''), headers: req.headers, params: Object.fromEntries(route.keys.map((k, i) => [k, decodeURIComponent(m[i + 1]!)])),
    };
    if (route.auth) await requireUser(ctx);
    const out: any = await route.h(ctx);
    if (isRaw(out)) { res.writeHead(out.status, out.headers); return res.end(out.body); }
    if (out && typeof out === 'object' && '__status' in out) return send(res, out.__status, out.body);
    return send(res, 200, out ?? { ok: true });
  } catch (e) {
    if (e instanceof ApiError) return send(res, e.status, { error: { code: e.code, message: e.message, ...e.extra } });
    console.error('unhandled', e);
    return send(res, 500, { error: { code: 'server_error', message: 'Something went wrong on our side. Please try again.' } });
  }
}
