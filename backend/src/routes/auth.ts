import { NextFunction, Request, Response, Router } from 'express';
import { PoolClient } from 'pg';
import { pool } from '../db';
import { requireAuth } from '../middleware/auth';
import {
  createSession,
  hashOpaqueValue,
  hashPassword,
  newUuid,
  verifyPassword,
} from '../services/authService';
import { loginSchema, normalizeIdentity, registerSchema } from '../validators/auth.schema';

const router = Router();
const MAX_FAILURES = 5;
const WINDOW_MINUTES = 15;
const DUMMY_PASSWORD_HASH = '$argon2id$v=19$m=19456,t=2,p=1$kinQEGyOfvl1SJ8T/gOcNw$wvoXsTaemUUvu6i2K+6Rl2R91hmKHJuiiQmNId35DLg';

type AccountRow = {
  account_id: string;
  username: string;
  email: string;
  password_hash: string;
  player_id: string;
};

function profileResponse(account: Pick<AccountRow, 'account_id' | 'username' | 'email' | 'player_id'>) {
  return {
    account_id: account.account_id,
    username: account.username,
    email: account.email,
    player_id: account.player_id,
  };
}

async function isBlocked(identifierHash: string): Promise<boolean> {
  const { rows } = await pool.query<{ blocked: boolean }>(
    `SELECT blocked_until IS NOT NULL AND blocked_until > NOW() AS blocked
     FROM auth_login_attempts WHERE identifier_hash = $1`,
    [identifierHash],
  );
  return rows[0]?.blocked === true;
}

async function recordFailure(identifierHash: string): Promise<void> {
  await pool.query(
    `INSERT INTO auth_login_attempts
       (identifier_hash, failure_count, window_started_at, blocked_until)
     VALUES ($1, 1, NOW(), NULL)
     ON CONFLICT (identifier_hash) DO UPDATE SET
       failure_count = CASE
         WHEN auth_login_attempts.window_started_at < NOW() - ($2 * INTERVAL '1 minute') THEN 1
         ELSE auth_login_attempts.failure_count + 1
       END,
       window_started_at = CASE
         WHEN auth_login_attempts.window_started_at < NOW() - ($2 * INTERVAL '1 minute') THEN NOW()
         ELSE auth_login_attempts.window_started_at
       END,
       blocked_until = CASE
         WHEN (CASE
           WHEN auth_login_attempts.window_started_at < NOW() - ($2 * INTERVAL '1 minute') THEN 1
           ELSE auth_login_attempts.failure_count + 1
         END) >= $3 THEN NOW() + ($2 * INTERVAL '1 minute')
         ELSE NULL
       END,
       updated_at = NOW()`,
    [identifierHash, WINDOW_MINUTES, MAX_FAILURES],
  );
}

router.post('/register', async (req: Request, res: Response, next: NextFunction): Promise<void> => {
  const parsed = registerSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(422).json({ error: 'Datos de registro invalidos', details: parsed.error.issues });
    return;
  }

  const usernameNormalized = normalizeIdentity(parsed.data.username);
  const emailNormalized = normalizeIdentity(parsed.data.email);
  let client: PoolClient | undefined;
  try {
    const passwordHash = await hashPassword(parsed.data.password);
    client = await pool.connect();
    await client.query('BEGIN');
    const accountId = newUuid();
    const playerId = newUuid();
    await client.query(
      `INSERT INTO player_accounts
         (account_id, username, username_normalized, email, email_normalized, password_hash)
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [accountId, parsed.data.username.trim(), usernameNormalized,
        parsed.data.email.trim(), emailNormalized, passwordHash],
    );
    await client.query(
      `INSERT INTO player_profiles (player_id, account_id, display_name)
       VALUES ($1, $2, $3)`,
      [playerId, accountId, parsed.data.username.trim()],
    );
    const session = await createSession(client, accountId);
    await client.query('COMMIT');
    res.status(201).json({
      token: session.token,
      expires_at: session.expiresAt.toISOString(),
      profile: profileResponse({
        account_id: accountId,
        username: parsed.data.username.trim(),
        email: parsed.data.email.trim(),
        player_id: playerId,
      }),
    });
  } catch (error: unknown) {
    if (client) await client.query('ROLLBACK');
    if (typeof error === 'object' && error !== null && 'code' in error && error.code === '23505') {
      const constraint = 'constraint' in error ? String(error.constraint) : '';
      const field = constraint.includes('username') ? 'username' : 'email';
      res.status(409).json({
        error: field === 'username' ? 'El nombre de usuario ya esta en uso' : 'El correo ya esta registrado',
        field,
      });
      return;
    }
    next(error);
  } finally {
    client?.release();
  }
});

router.post('/login', async (req: Request, res: Response, next: NextFunction): Promise<void> => {
  const parsed = loginSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(422).json({ error: 'Datos de acceso invalidos', details: parsed.error.issues });
    return;
  }
  const normalized = normalizeIdentity(parsed.data.login);
  const attemptHash = hashOpaqueValue(`${normalized}|${req.ip ?? 'unknown'}`);
  try {
    if (await isBlocked(attemptHash)) {
      res.status(429).json({ error: 'Demasiados intentos. Espera unos minutos antes de volver a intentar.' });
      return;
    }
    const { rows } = await pool.query<AccountRow>(
      `SELECT account.account_id, account.username, account.email, account.password_hash,
              profile.player_id
       FROM player_accounts AS account
       JOIN player_profiles AS profile ON profile.account_id = account.account_id
       WHERE account.username_normalized = $1 OR account.email_normalized = $1`,
      [normalized],
    );
    const account = rows[0];
    const passwordMatches = await verifyPassword(
      account?.password_hash ?? DUMMY_PASSWORD_HASH,
      parsed.data.password,
    );
    if (!account || !passwordMatches) {
      await recordFailure(attemptHash);
      res.status(401).json({ error: 'Usuario o contrasena incorrectos' });
      return;
    }
    await pool.query('DELETE FROM auth_login_attempts WHERE identifier_hash = $1', [attemptHash]);
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const session = await createSession(client, account.account_id);
      await client.query('COMMIT');
      res.json({
        token: session.token,
        expires_at: session.expiresAt.toISOString(),
        profile: profileResponse(account),
      });
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  } catch (error) {
    next(error);
  }
});

router.get('/me', requireAuth, (req: Request, res: Response): void => {
  res.json({ profile: profileResponse({
    account_id: req.auth!.accountId,
    username: req.auth!.username,
    email: req.auth!.email,
    player_id: req.auth!.playerId,
  }) });
});

router.post('/logout', requireAuth, async (req: Request, res: Response, next: NextFunction): Promise<void> => {
  try {
    await pool.query(
      'UPDATE auth_sessions SET revoked_at = COALESCE(revoked_at, NOW()) WHERE session_id = $1',
      [req.auth!.sessionId],
    );
    res.status(204).send();
  } catch (error) {
    next(error);
  }
});

export default router;
