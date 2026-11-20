import argon2 from 'argon2';
import crypto from 'crypto';
import { PoolClient } from 'pg';

const SESSION_HOURS = Number(process.env.AUTH_SESSION_HOURS ?? 12);

export async function hashPassword(password: string): Promise<string> {
  return argon2.hash(password, {
    type: argon2.argon2id,
    memoryCost: 19_456,
    timeCost: 2,
    parallelism: 1,
  });
}

export async function verifyPassword(hash: string, password: string): Promise<boolean> {
  try {
    return await argon2.verify(hash, password);
  } catch {
    return false;
  }
}

export function hashOpaqueValue(value: string): string {
  return crypto.createHash('sha256').update(value, 'utf8').digest('hex');
}

export async function createSession(client: PoolClient, accountId: string) {
  const token = crypto.randomBytes(32).toString('base64url');
  const sessionId = crypto.randomUUID();
  const expiresAt = new Date(Date.now() + SESSION_HOURS * 60 * 60 * 1000);
  await client.query(
    `INSERT INTO auth_sessions (session_id, account_id, token_hash, expires_at)
     VALUES ($1, $2, $3, $4)`,
    [sessionId, accountId, hashOpaqueValue(token), expiresAt],
  );
  return { token, expiresAt };
}

export function newUuid(): string {
  return crypto.randomUUID();
}
