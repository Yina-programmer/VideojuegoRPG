import { NextFunction, Request, Response } from 'express';
import { pool } from '../db';
import { hashOpaqueValue } from '../services/authService';

type SessionRow = {
  session_id: string;
  account_id: string;
  player_id: string;
  username: string;
  email: string;
};

export async function requireAuth(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  try {
    const authorization = req.header('authorization') ?? '';
    const match = /^Bearer\s+([^\s]+)$/i.exec(authorization);
    if (!match) {
      res.status(401).json({ error: 'Sesion requerida' });
      return;
    }

    const { rows } = await pool.query<SessionRow>(
      `UPDATE auth_sessions AS session
       SET last_used_at = NOW()
       FROM player_accounts AS account
       JOIN player_profiles AS profile ON profile.account_id = account.account_id
       WHERE session.account_id = account.account_id
         AND session.token_hash = $1
         AND session.revoked_at IS NULL
         AND session.expires_at > NOW()
       RETURNING session.session_id, account.account_id, profile.player_id,
                 account.username, account.email`,
      [hashOpaqueValue(match[1])],
    );
    if (rows.length !== 1) {
      res.status(401).json({ error: 'Sesion invalida o expirada' });
      return;
    }
    const row = rows[0];
    req.auth = {
      sessionId: row.session_id,
      accountId: row.account_id,
      playerId: row.player_id,
      username: row.username,
      email: row.email,
    };
    next();
  } catch (error) {
    next(error);
  }
}

export function requirePlayerOwnership(
  req: Request,
  res: Response,
  next: NextFunction,
): void {
  if (!req.auth || req.params.playerId !== req.auth.playerId) {
    res.status(403).json({ error: 'No tienes acceso a esta partida' });
    return;
  }
  next();
}
