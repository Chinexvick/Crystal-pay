import { neon } from '@neondatabase/serverless';
import { env } from './env';

let client: ReturnType<typeof neon> | undefined;

/** Parameterised query. Never build SQL by joining user input. */
export async function q<T = Record<string, any>>(text: string, params: unknown[] = []): Promise<T[]> {
  client ??= neon(env.dbUrl);
  return (await client.query(text, params as any[])) as unknown as T[];
}

export async function one<T = Record<string, any>>(text: string, params: unknown[] = []): Promise<T | undefined> {
  return (await q<T>(text, params))[0];
}
