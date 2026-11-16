import nodemailer, { type Transporter } from 'nodemailer';
import type SMTPTransport from 'nodemailer/lib/smtp-transport';
import { waitUntil } from '@vercel/functions';
import { env } from './env';
import { q } from './db';

export interface Mail { subject: string; html: string; text: string }

let tx: Transporter<SMTPTransport.SentMessageInfo> | undefined;
const transport = () =>
  (tx ??= nodemailer.createTransport({
    host: env.smtp.host,
    port: env.smtp.port,
    secure: false, // port 587 starts plain, then upgrades with STARTTLS
    requireTLS: true, // refuse to send if the upgrade fails
    auth: { user: env.smtp.user, pass: env.smtp.pass },
    connectionTimeout: 10_000,
    greetingTimeout: 10_000,
    socketTimeout: 20_000,
  } as SMTPTransport.Options));

/** Send and record the result. Throws when the mail server refuses. */
export async function sendMail(to: string, mail: Mail, userId?: string): Promise<void> {
  try {
    await transport().sendMail({
      from: { name: env.smtp.fromName, address: env.smtp.user },
      replyTo: env.smtp.user,
      to,
      subject: mail.subject,
      html: mail.html,
      text: mail.text,
      headers: { 'X-Auto-Response-Suppress': 'OOF, AutoReply' },
    });
    await q(`INSERT INTO email_log (user_id, to_email, subject, status) VALUES ($1,$2,$3,'sent')`, [userId ?? null, to, mail.subject]).catch(() => {});
  } catch (e) {
    await q(`INSERT INTO email_log (user_id, to_email, subject, status, error) VALUES ($1,$2,$3,'failed',$4)`, [userId ?? null, to, mail.subject, String((e as Error).message).slice(0, 300)]).catch(() => {});
    throw e;
  }
}

/** Send in the background so the app gets its answer fast. Failures are logged, never shown to the user. */
export function sendMailLater(to: string, mail: Mail, userId?: string): void {
  waitUntil(sendMail(to, mail, userId).catch(() => {}));
}
