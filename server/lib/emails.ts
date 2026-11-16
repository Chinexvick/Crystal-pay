import { env } from './env';
import { esc } from './http';
import type { Mail } from './mail';

const PURPLE = '#5B14DD';
const INK = '#1C0B4F';
const BODY = '#4B4568';
const MUTED = '#8A84A3';
const LINE = '#ECE6FA';
const TINT = '#F1EAFE';

type Row = [string, string];
interface Parts {
  preheader: string;
  title: string;
  intro?: string;
  hero?: { label: string; value: string; tone?: 'ok' | 'warn' | 'bad' };
  code?: string;
  rows?: Row[];
  outro?: string;
  note?: { title: string; text: string; tone?: 'info' | 'warn' };
  badge?: string;
}

const naira = (n: number) => '₦' + n.toLocaleString('en-NG', { minimumFractionDigits: n % 1 ? 2 : 0, maximumFractionDigits: 2 });
const when = (d = new Date()) => d.toLocaleString('en-GB', { timeZone: 'Africa/Lagos', day: 'numeric', month: 'short', year: 'numeric', hour: 'numeric', minute: '2-digit', hour12: true }) + ' (WAT)';
const FONT = `-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif`;

function render(p: Parts): Mail {
  const logo = `${env.baseUrl}/logo.png`;
  const toneColor = p.hero?.tone === 'bad' ? '#D92D4A' : p.hero?.tone === 'warn' ? '#D97706' : PURPLE;
  const rows = (p.rows ?? [])
    .map(([k, v], i) => `<tr><td style="padding:11px 0;${i ? `border-top:1px solid ${LINE};` : ''}font-size:13px;color:${MUTED};width:42%;vertical-align:top">${esc(k)}</td><td style="padding:11px 0;${i ? `border-top:1px solid ${LINE};` : ''}font-size:14px;color:${INK};font-weight:600;text-align:right;word-break:break-all">${esc(v)}</td></tr>`)
    .join('');
  const html = `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="color-scheme" content="light only"><title>${esc(p.title)}</title></head>
<body style="margin:0;padding:0;background:#F6F3FD;font-family:${FONT}">
<div style="display:none;max-height:0;overflow:hidden;opacity:0;color:#F6F3FD">${esc(p.preheader)}&#8199;&#847;&#8199;&#847;&#8199;&#847;</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#F6F3FD"><tr><td align="center" style="padding:28px 14px">
  <table role="presentation" width="560" cellpadding="0" cellspacing="0" style="width:100%;max-width:560px">
    <tr><td align="center" style="padding:4px 0 18px">
      <table role="presentation" cellpadding="0" cellspacing="0"><tr>
        <td style="padding-right:10px"><img src="${logo}" width="44" alt="Crystal Pay" style="display:block;border:0;height:auto"></td>
        <td style="font-size:20px;font-weight:800;color:${INK};letter-spacing:-0.3px;font-family:${FONT}">Crystal Pay</td>
      </tr></table>
    </td></tr>
    <tr><td style="background:#FFFFFF;border:1px solid ${LINE};border-radius:18px;overflow:hidden">
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
        <tr><td height="5" style="height:5px;line-height:5px;font-size:0;background:${PURPLE};background-image:linear-gradient(90deg,${PURPLE},#A855F7)">&nbsp;</td></tr>
        <tr><td style="padding:32px 32px 30px">
          ${p.badge ? `<div style="display:inline-block;background:${TINT};color:${PURPLE};font-size:12px;font-weight:700;padding:5px 11px;border-radius:99px;margin-bottom:14px">${esc(p.badge)}</div>` : ''}
          <h1 style="margin:0 0 12px;font-size:23px;line-height:1.3;color:${INK};font-weight:800;letter-spacing:-0.3px">${esc(p.title)}</h1>
          ${p.intro ? `<p style="margin:0 0 20px;font-size:15px;line-height:1.65;color:${BODY}">${p.intro}</p>` : ''}
          ${p.code ? `<div style="margin:6px 0 20px;background:${TINT};border-radius:14px;padding:20px 10px;text-align:center"><div style="font-family:'SFMono-Regular',Menlo,Consolas,monospace;font-size:36px;line-height:1;font-weight:800;letter-spacing:12px;color:${PURPLE};padding-left:12px">${esc(p.code)}</div></div>` : ''}
          ${p.hero ? `<div style="margin:4px 0 20px;text-align:center;padding:18px 10px;border:1px solid ${LINE};border-radius:14px"><div style="font-size:12px;color:${MUTED};font-weight:600;text-transform:uppercase;letter-spacing:0.8px">${esc(p.hero.label)}</div><div style="font-size:32px;font-weight:800;color:${toneColor};margin-top:6px;letter-spacing:-0.5px">${esc(p.hero.value)}</div></div>` : ''}
          ${rows ? `<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin:0 0 18px">${rows}</table>` : ''}
          ${p.note ? `<div style="margin:6px 0 18px;padding:14px 16px;border-radius:12px;background:${p.note.tone === 'warn' ? '#FFF6E5' : '#F8F5FF'};border:1px solid ${p.note.tone === 'warn' ? '#FBE3B0' : LINE}"><div style="font-size:13px;font-weight:700;color:${INK};margin-bottom:3px">${esc(p.note.title)}</div><div style="font-size:13px;line-height:1.55;color:${BODY}">${p.note.text}</div></div>` : ''}
          ${p.outro ? `<p style="margin:0;font-size:14px;line-height:1.65;color:${BODY}">${p.outro}</p>` : ''}
        </td></tr>
      </table>
    </td></tr>
    <tr><td align="center" style="padding:22px 18px 6px;font-size:12px;line-height:1.7;color:${MUTED}">
      Need help? Just reply to this email and our team will get back to you.<br>
      Sent ${esc(when())} &middot; This is an automated message about your Crystal Pay account.
    </td></tr>
    <tr><td align="center" style="padding:0 18px 20px;font-size:12px;color:#B4AECB">&copy; ${new Date().getFullYear()} Crystal Pay</td></tr>
  </table>
</td></tr></table></body></html>`;
  const text = [p.title, '', p.intro?.replace(/<[^>]+>/g, ''), p.code ? `Your code: ${p.code}` : '', p.hero ? `${p.hero.label}: ${p.hero.value}` : '', ...(p.rows ?? []).map(([k, v]) => `${k}: ${v}`), p.note ? `${p.note.title}: ${p.note.text.replace(/<[^>]+>/g, '')}` : '', p.outro?.replace(/<[^>]+>/g, ''), '', 'Crystal Pay'].filter((x) => x !== undefined && x !== '').join('\n');
  return { subject: p.title, html, text };
}

const mail = (subject: string, p: Parts): Mail => ({ ...render(p), subject });
const hi = (n: string) => `Hi ${esc(n)},`;
const NOT_YOU = { title: 'Was this not you?', text: 'Reset your password right away from the sign-in screen, then reply to this email so we can secure your account.', tone: 'warn' as const };

// ───── account ─────
export const otpSignup = (code: string, minutes: number): Mail => mail(`${code} is your Crystal Pay verification code`, {
  preheader: `Your code is ${code}. It expires in ${minutes} minutes.`, badge: 'Verify your email', title: 'Confirm your email address',
  intro: `Enter this code in the Crystal Pay app to finish creating your account. It expires in <b>${minutes} minutes</b>.`, code,
  note: { title: 'Keep it private', text: 'Crystal Pay will never call or message you to ask for this code. If you did not sign up, you can ignore this email.' },
});
export const welcome = (name: string): Mail => mail('Welcome to Crystal Pay', {
  preheader: 'Your account is ready. Add money and start paying bills.', badge: 'Account created', title: 'Welcome to Crystal Pay',
  intro: `${hi(name)}<br>Your email is verified and your wallet is ready. Here is what you can do right away:`,
  rows: [['Add money', 'Card, bank transfer or CCT'], ['Pay bills', 'Airtime, data, electricity, TV'], ['Buy and sell', 'Marketplace for everyday items']],
  outro: 'Tip: set a transaction PIN in <b>Me &rsaquo; Security</b> so only you can spend from your wallet.',
});
export const loginAlert = (name: string, d: { ip: string; device: string }): Mail => mail('New sign-in to your Crystal Pay account', {
  preheader: 'We noticed a new sign-in. Check it was you.', badge: 'Security alert', title: 'New sign-in detected',
  intro: `${hi(name)}<br>Your account was just signed in to.`, rows: [['Time', when()], ['Device', d.device || 'Unknown device'], ['IP address', d.ip]], note: NOT_YOU,
});
export const otpReset = (code: string, minutes: number): Mail => mail(`${code} is your Crystal Pay password reset code`, {
  preheader: `Use ${code} to reset your password.`, badge: 'Password reset', title: 'Reset your password',
  intro: `Use this code in the app to choose a new password. It expires in <b>${minutes} minutes</b>.`, code,
  note: { title: 'Did not ask for this?', text: 'Someone may have typed your email by mistake. Your password has not changed, and you can ignore this message.' },
});
export const passwordChanged = (name: string): Mail => mail('Your Crystal Pay password was changed', {
  preheader: 'Your password was changed just now.', badge: 'Security', title: 'Password changed',
  intro: `${hi(name)}<br>The password for your Crystal Pay account was changed. You have been signed out on your other devices.`, rows: [['When', when()]], note: NOT_YOU,
});
export const profileUpdated = (name: string, changes: Row[]): Mail => mail('Your Crystal Pay profile was updated', {
  preheader: 'A change was made to your profile.', badge: 'Profile', title: 'Profile updated',
  intro: `${hi(name)}<br>These details on your account were changed:`, rows: [...changes, ['When', when()]], note: NOT_YOU,
});
export const photoUpdated = (name: string): Mail => mail('Your Crystal Pay profile photo was updated', {
  preheader: 'Your profile picture was changed.', badge: 'Profile', title: 'Profile photo updated',
  intro: `${hi(name)}<br>Your profile picture was changed.`, rows: [['When', when()]], note: NOT_YOU,
});
export const pinSet = (name: string, changed: boolean): Mail => mail(changed ? 'Your transaction PIN was changed' : 'Your transaction PIN is set', {
  preheader: 'Your 4-digit PIN protects every payment.', badge: 'Security', title: changed ? 'Transaction PIN changed' : 'Transaction PIN set',
  intro: `${hi(name)}<br>${changed ? 'Your transaction PIN was changed.' : 'Your transaction PIN is now active. You will be asked for it before bill payments and withdrawals.'}`, rows: [['When', when()]], note: NOT_YOU,
});
export const kycSkipped = (name: string): Mail => mail('Identity verification skipped for now', {
  preheader: 'You can verify your identity any time from Me.', badge: 'Verification', title: 'You can verify later',
  intro: `${hi(name)}<br>You skipped identity verification. Your account works as normal. You can add your BVN or ID any time from <b>Me &rsaquo; Verification</b> to earn your blue tick and raise your limits.`,
});

// ───── money ─────
export const walletFunded = (name: string, d: { amount: number; method: string; reference: string; balance: number }): Mail => mail(`${naira(d.amount)} added to your wallet`, {
  preheader: `Your wallet now holds ${naira(d.balance)}.`, badge: 'Wallet funded', title: 'Money added to your wallet',
  intro: hi(name), hero: { label: 'Amount added', value: naira(d.amount) },
  rows: [['Method', d.method], ['Reference', d.reference], ['New balance', naira(d.balance)], ['Date', when()]],
  outro: 'Thank you for using Crystal Pay.',
});
export const cctDetected = (name: string, d: { tokens: string; txHash: string; confirmations: number; required: number }): Mail => mail(`We received ${d.tokens} CCT`, {
  preheader: 'Waiting for network confirmations.', badge: 'CCT deposit', title: 'We have seen your CCT',
  intro: `${hi(name)}<br>Your deposit is on the network and is being confirmed. Your wallet is credited automatically once it is final.`,
  hero: { label: 'Received', value: `${d.tokens} CCT`, tone: 'warn' }, rows: [['Confirmations', `${d.confirmations} of ${d.required}`], ['Transaction', d.txHash]],
});
export const cctCredited = (name: string, d: { tokens: string; rate: number; gross: number; fee: number; net: number; txHash: string; balance: number }): Mail => mail(`${naira(d.net)} added from your CCT deposit`, {
  preheader: `${d.tokens} CCT converted to Naira.`, badge: 'CCT deposit complete', title: 'Your CCT is now in your wallet',
  intro: hi(name), hero: { label: 'Credited to wallet', value: naira(d.net) },
  rows: [['CCT sent', `${d.tokens} CCT`], ['Rate', `${naira(d.rate)} per CCT`], ['Value', naira(d.gross)], ['Service fee', naira(d.fee)], ['New balance', naira(d.balance)], ['Transaction', d.txHash], ['Date', when()]],
});
export const billSuccess = (name: string, d: { title: string; customer: string; amount: number; reference: string; token?: string; test?: boolean }): Mail => mail(`${d.title} successful`, {
  preheader: `${naira(d.amount)} paid for ${d.customer}.`, badge: 'Payment successful', title: `${d.title} paid`,
  intro: d.test ? `${hi(name)}<br><b>Test mode:</b> this payment was recorded in the sandbox, nothing was delivered.` : hi(name),
  hero: { label: 'Amount paid', value: naira(d.amount) },
  rows: [['Service', d.title], ['For', d.customer], ...(d.token ? ([['Token', d.token]] as Row[]) : []), ['Reference', d.reference], ['Date', when()]],
  outro: 'Keep this email as your receipt.',
});
export const billFailed = (name: string, d: { title: string; amount: number; reference: string }): Mail => mail(`${d.title} could not be completed`, {
  preheader: 'We refunded your wallet.', badge: 'Payment failed', title: 'We could not complete that payment',
  intro: `${hi(name)}<br>The provider did not accept this payment, so we returned <b>${naira(d.amount)}</b> to your wallet.`,
  hero: { label: 'Refunded', value: naira(d.amount), tone: 'bad' }, rows: [['Service', d.title], ['Reference', d.reference], ['Date', when()]],
});
export const withdrawalSent = (name: string, d: { amount: number; fee: number; bank: string; account: string; accountName: string; reference: string; state: 'processing' | 'success' }): Mail => mail(d.state === 'success' ? `${naira(d.amount)} sent to your bank` : `Withdrawal of ${naira(d.amount)} started`, {
  preheader: d.state === 'success' ? 'Your money is on its way to the bank.' : 'We are sending it to your bank.', badge: d.state === 'success' ? 'Withdrawal complete' : 'Withdrawal started', title: d.state === 'success' ? 'Withdrawal complete' : 'Withdrawal on its way',
  intro: hi(name), hero: { label: 'Amount', value: naira(d.amount) },
  rows: [['Bank', d.bank], ['Account', `${d.account} · ${d.accountName}`], ['Fee', naira(d.fee)], ['Reference', d.reference], ['Date', when()]], note: NOT_YOU,
});
export const withdrawalFailed = (name: string, d: { amount: number; fee: number; reference: string }): Mail => mail('Your withdrawal was refunded', {
  preheader: 'The transfer failed and your money is back.', badge: 'Withdrawal failed', title: 'Withdrawal could not be completed',
  intro: `${hi(name)}<br>The bank transfer did not go through, so we returned <b>${naira(d.amount + d.fee)}</b> to your wallet.`,
  hero: { label: 'Refunded', value: naira(d.amount + d.fee), tone: 'bad' }, rows: [['Reference', d.reference], ['Date', when()]],
});
export const payoutAccountAdded = (name: string, d: { bank: string; account: string; accountName: string }): Mail => mail('A bank account was added to your wallet', {
  preheader: 'You can now withdraw to this account.', badge: 'Bank account', title: 'Bank account added',
  intro: hi(name), rows: [['Bank', d.bank], ['Account', d.account], ['Name', d.accountName], ['When', when()]], note: NOT_YOU,
});
