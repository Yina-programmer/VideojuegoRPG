import argon2 from 'argon2';
import crypto from 'crypto';
import fs from 'fs';
import path from 'path';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import request from 'supertest';
import app from '../src/app';
import { pool } from '../src/db';

const PASSWORD = 'ChapiUnderLand-2026!';
const createdPlayers: string[] = [];

async function migrate(): Promise<void> {
  for (const file of [
    '001_initial.sql', '002_player_place_progress.sql',
    '003_quest_progress.sql', '004_player_accounts.sql',
  ]) {
    await pool.query(fs.readFileSync(path.resolve(__dirname, '../migrations', file), 'utf8'));
  }
}

async function register(username: string, email: string, password = PASSWORD) {
  const response = await request(app).post('/api/auth/register').send({
    username, email, password, password_confirmation: password,
  });
  if (response.body.profile?.player_id) createdPlayers.push(response.body.profile.player_id);
  return response;
}

beforeAll(async () => {
  await migrate();
  const oldAccounts = await pool.query<{ account_id: string; player_id: string }>(
    `SELECT account.account_id, profile.player_id
     FROM player_accounts account
     JOIN player_profiles profile ON profile.account_id = account.account_id
     WHERE account.email_normalized LIKE '%@auth-tests.invalid'`,
  );
  if (oldAccounts.rows.length > 0) {
    const ids = oldAccounts.rows.map((row) => row.player_id);
    await pool.query('DELETE FROM player_quest_progress WHERE player_id = ANY($1::uuid[])', [ids]);
    await pool.query('DELETE FROM player_place_progress WHERE player_id = ANY($1::uuid[])', [ids]);
    await pool.query('DELETE FROM player_customization WHERE player_id = ANY($1::uuid[])', [ids]);
    await pool.query('DELETE FROM player_accounts WHERE account_id = ANY($1::uuid[])', [oldAccounts.rows.map((row) => row.account_id)]);
  }
  await pool.query('DELETE FROM auth_login_attempts');
});

afterAll(async () => {
  if (createdPlayers.length > 0) {
    await pool.query('DELETE FROM player_quest_progress WHERE player_id = ANY($1::uuid[])', [createdPlayers]);
    await pool.query('DELETE FROM player_place_progress WHERE player_id = ANY($1::uuid[])', [createdPlayers]);
    await pool.query('DELETE FROM player_customization WHERE player_id = ANY($1::uuid[])', [createdPlayers]);
    await pool.query(
      `DELETE FROM player_accounts WHERE account_id IN
         (SELECT account_id FROM player_profiles WHERE player_id = ANY($1::uuid[]))`,
      [createdPlayers],
    );
  }
  await pool.query('DELETE FROM auth_login_attempts');
  await pool.end();
});

describe('HU_11: registro seguro', () => {
  it('valida campos, correo, longitud y confirmacion', async () => {
    expect((await request(app).post('/api/auth/register').send({})).status).toBe(422);
    expect((await request(app).post('/api/auth/register').send({
      username: 'ab', email: 'incorrecto', password: '123', password_confirmation: '456',
    })).status).toBe(422);
  });

  it('crea cuenta, perfil individual y hash Argon2id, nunca texto plano', async () => {
    const response = await register('AliciaAuth', 'alicia@auth-tests.invalid');
    expect(response.status).toBe(201);
    expect(response.body.token).toMatch(/^[A-Za-z0-9_-]{40,}$/);
    expect(response.body.profile.player_id).toMatch(/^[0-9a-f-]{36}$/);
    const row = await pool.query<{ password_hash: string }>(
      'SELECT password_hash FROM player_accounts WHERE account_id = $1',
      [response.body.profile.account_id],
    );
    expect(row.rows[0].password_hash).not.toBe(PASSWORD);
    expect(row.rows[0].password_hash.startsWith('$argon2id$')).toBe(true);
    expect(await argon2.verify(row.rows[0].password_hash, PASSWORD)).toBe(true);
  });

  it('rechaza usuario y correo duplicados sin distinguir mayusculas', async () => {
    expect((await register('ALICIAAUTH', 'otra@auth-tests.invalid')).status).toBe(409);
    expect((await register('OtraAlicia', 'ALICIA@AUTH-TESTS.INVALID')).status).toBe(409);
  });
});

describe('HU_12: sesion, propiedad y progreso aislado', () => {
  it('autentica contrasena, consulta perfil y revoca la sesion al salir', async () => {
    const wrong = await request(app).post('/api/auth/login').send({
      login: 'alicia@auth-tests.invalid', password: 'Contrasena-equivocada',
    });
    expect(wrong.status).toBe(401);
    expect(wrong.body.error).toBe('Usuario o contrasena incorrectos');

    const login = await request(app).post('/api/auth/login').send({
      login: 'AliciaAuth', password: PASSWORD,
    });
    expect(login.status).toBe(200);
    const token = login.body.token as string;
    const me = await request(app).get('/api/auth/me').set('Authorization', `Bearer ${token}`);
    expect(me.status).toBe(200);
    expect(me.body.profile.player_id).toBe(login.body.profile.player_id);

    expect((await request(app).post('/api/auth/logout').set('Authorization', `Bearer ${token}`)).status).toBe(204);
    expect((await request(app).get('/api/auth/me').set('Authorization', `Bearer ${token}`)).status).toBe(401);
  });

  it('aísla personalizacion, exploracion y misiones entre dos cuentas', async () => {
    const a = await request(app).post('/api/auth/login').send({ login: 'AliciaAuth', password: PASSWORD });
    const b = await register('BrunoAuth', 'bruno@auth-tests.invalid');
    const aToken = a.body.token as string;
    const bToken = b.body.token as string;
    const aId = a.body.profile.player_id as string;
    const bId = b.body.profile.player_id as string;
    const auth = (token: string) => ({ Authorization: `Bearer ${token}` });

    expect((await request(app).put(`/api/customization/${aId}`).set(auth(aToken)).send({
      outfit_id: 'azul', hair_style_id: 'castano', character_type: 'mujer',
    })).status).toBe(200);
    expect((await request(app).put(`/api/exploration/${aId}/hippies`).set(auth(aToken)).send({ event: 'visit' })).status).toBe(200);
    expect((await request(app).put(`/api/quests/${aId}/hippies`).set(auth(aToken)).send({ event: 'start' })).status).toBe(200);

    expect((await request(app).get(`/api/customization/${aId}`).set(auth(bToken))).status).toBe(403);
    expect((await request(app).get(`/api/exploration/${aId}`).set(auth(bToken))).status).toBe(403);
    expect((await request(app).get(`/api/quests/${aId}`).set(auth(bToken))).status).toBe(403);
    expect((await request(app).get(`/api/exploration/${bId}`).set(auth(bToken))).body.places).toEqual([]);
    expect((await request(app).get(`/api/quests/${bId}`).set(auth(bToken))).body.quests).toEqual([]);

    const restored = await request(app).post('/api/auth/login').send({ login: 'alicia@auth-tests.invalid', password: PASSWORD });
    const restoredAuth = auth(restored.body.token);
    expect(restored.body.profile.player_id).toBe(aId);
    expect((await request(app).get(`/api/customization/${aId}`).set(restoredAuth)).body.outfit_id).toBe('azul');
    expect((await request(app).get(`/api/exploration/${aId}`).set(restoredAuth)).body.places).toHaveLength(1);
    expect((await request(app).get(`/api/quests/${aId}`).set(restoredAuth)).body.quests).toHaveLength(1);
  });

  it('rechaza una sesion expirada y limita intentos repetidos', async () => {
    const user = await register('RateLimitAuth', 'rate@auth-tests.invalid');
    const tokenHash = crypto.createHash('sha256').update(user.body.token).digest('hex');
    await pool.query(
      `UPDATE auth_sessions
       SET created_at = NOW() - INTERVAL '2 hours', expires_at = NOW() - INTERVAL '1 hour'
       WHERE token_hash = $1`,
      [tokenHash],
    );
    expect((await request(app).get('/api/auth/me').set('Authorization', `Bearer ${user.body.token}`)).status).toBe(401);

    for (let attempt = 0; attempt < 5; attempt += 1) {
      expect((await request(app).post('/api/auth/login').send({ login: 'RateLimitAuth', password: 'incorrecta-123' })).status).toBe(401);
    }
    expect((await request(app).post('/api/auth/login').send({ login: 'RateLimitAuth', password: 'incorrecta-123' })).status).toBe(429);
  });
});
