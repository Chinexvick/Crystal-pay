import { q, one } from './db';
import { sendMailLater, type Mail } from './mail';

/** In-app notification plus a confirmation email, for one user. */
export async function notify(userId: string, kind: string, title: string, body: string, mail?: (firstName: string) => Mail): Promise<void> {
  await q(`INSERT INTO notifications (user_id, kind, title, body) VALUES ($1,$2,$3,$4)`, [userId, kind, title, body]).catch(() => {});
  if (!mail) return;
  const u = await one<{ email: string; first_name: string | null }>(`SELECT email, first_name FROM users WHERE id = $1`, [userId]);
  if (u) sendMailLater(u.email, mail(u.first_name || 'there'), userId);
}
