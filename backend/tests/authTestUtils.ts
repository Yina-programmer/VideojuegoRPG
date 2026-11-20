import crypto from 'crypto';
import { pool } from '../src/db';
import { hashOpaqueValue } from '../src/services/authService';

export async function seedAuthenticatedPlayer(playerId: string, username: string): Promise<string> {
  const accountId = crypto.randomUUID();
  const token = crypto.randomBytes(32).toString('base64url');
  const normalized = username.toLowerCase();
  await pool.query(
    `INSERT INTO player_accounts
       (account_id, username, username_normalized, email, email_normalized, password_hash)
     VALUES ($1, $2, $3, $4, $4, '$argon2id$test-only')`,
    [accountId, username, normalized, `${normalized}@tests.invalid`],
  );
  await pool.query(
    'INSERT INTO player_profiles (player_id, account_id, display_name) VALUES ($1, $2, $3)',
    [playerId, accountId, username],
  );
  await pool.query(
    `INSERT INTO auth_sessions (session_id, account_id, token_hash, expires_at)
     VALUES ($1, $2, $3, NOW() + INTERVAL '1 hour')`,
    [crypto.randomUUID(), accountId, hashOpaqueValue(token)],
  );
  return token;
}

export async function deleteAuthenticatedPlayers(playerIds: string[]): Promise<void> {
  if (playerIds.length === 0) return;
  await pool.query('DELETE FROM auth_login_attempts');
  await pool.query(
    `DELETE FROM player_accounts WHERE account_id IN
       (SELECT account_id FROM player_profiles WHERE player_id = ANY($1::uuid[]))`,
    [playerIds],
  );
}
