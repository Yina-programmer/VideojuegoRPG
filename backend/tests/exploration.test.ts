import { beforeAll, afterAll, describe, expect, it } from 'vitest';
import request from 'supertest';
import fs from 'fs';
import path from 'path';
import app from '../src/app';
import { pool } from '../src/db';

// Solo se usa en la BD de pruebas; nunca coincide con el UUID del juego.
const TEST_PLAYER_ID = 'c1b2c3d4-e5f6-4789-8abc-def012345678';
const endpoint = `/api/exploration/${TEST_PLAYER_ID}`;

beforeAll(async () => {
  for (const file of ['001_initial.sql', '002_player_place_progress.sql']) {
    const sql = fs.readFileSync(path.resolve(__dirname, '../migrations', file), 'utf8');
    await pool.query(sql);
  }
  await pool.query('DELETE FROM player_place_progress WHERE player_id = $1', [TEST_PLAYER_ID]);
});

afterAll(async () => {
  await pool.query('DELETE FROM player_place_progress WHERE player_id = $1', [TEST_PLAYER_ID]);
  await pool.end();
});

describe('HU_7: exploración persistente', () => {
  it('valida UUID, lugar y evento sin insertar filas', async () => {
    expect((await request(app).get('/api/exploration/uuid-malo')).status).toBe(400);
    expect((await request(app).put('/api/exploration/uuid-malo/hippies').send({ event: 'visit' })).status).toBe(400);
    expect((await request(app).put(`${endpoint}/fantasma`).send({ event: 'visit' })).status).toBe(422);
    expect((await request(app).put(`${endpoint}/hippies`).send({ event: 'teleport' })).status).toBe(422);
    expect((await request(app).put(`${endpoint}/hippies`).send({ event: 'visit', extra: true })).status).toBe(422);
    const { rows } = await pool.query<{ count: string }>(
      'SELECT COUNT(*) AS count FROM player_place_progress WHERE player_id = $1',
      [TEST_PLAYER_ID],
    );
    expect(Number(rows[0].count)).toBe(0);
  });

  it('progresa pendiente -> visitado -> descubierto sin duplicados ni retrocesos', async () => {
    const initial = await request(app).get(endpoint);
    expect(initial.status).toBe(200);
    expect(initial.body.places).toEqual([]);

    const visit = await request(app).put(`${endpoint}/hippies`).send({ event: 'visit' });
    expect(visit.status).toBe(200);
    expect(visit.body.state).toBe('visited');
    expect(visit.body.changed).toBe(true);
    expect(visit.body.newly_discovered).toBe(false);
    const firstVisitedAt = visit.body.visited_at;
    expect(visit.body.discovered_at).toBeNull();

    const repeatedVisit = await request(app).put(`${endpoint}/hippies`).send({ event: 'visit' });
    expect(repeatedVisit.body.changed).toBe(false);
    expect(repeatedVisit.body.visited_at).toBe(firstVisitedAt);

    const discovery = await request(app).put(`${endpoint}/hippies`).send({ event: 'discover' });
    expect(discovery.body.state).toBe('discovered');
    expect(discovery.body.changed).toBe(true);
    expect(discovery.body.newly_discovered).toBe(true);
    expect(discovery.body.visited_at).toBe(firstVisitedAt);
    const firstDiscoveredAt = discovery.body.discovered_at;

    const repeatedDiscovery = await request(app).put(`${endpoint}/hippies`).send({ event: 'discover' });
    expect(repeatedDiscovery.body.changed).toBe(false);
    expect(repeatedDiscovery.body.newly_discovered).toBe(false);
    expect(repeatedDiscovery.body.discovered_at).toBe(firstDiscoveredAt);

    const laterVisit = await request(app).put(`${endpoint}/hippies`).send({ event: 'visit' });
    expect(laterVisit.body.state).toBe('discovered');
    expect(laterVisit.body.visited_at).toBe(firstVisitedAt);
    expect(laterVisit.body.discovered_at).toBe(firstDiscoveredAt);

    const { rows } = await pool.query<{ count: string }>(
      'SELECT COUNT(*) AS count FROM player_place_progress WHERE player_id = $1 AND place_id = $2',
      [TEST_PLAYER_ID, 'hippies'],
    );
    expect(Number(rows[0].count)).toBe(1);
  });

  it('permite descubrir antes de guardar personalización y recuperar el progreso', async () => {
    const customization = await pool.query(
      'SELECT 1 FROM player_customization WHERE player_id = $1',
      [TEST_PLAYER_ID],
    );
    expect(customization.rows).toHaveLength(0);

    const discovery = await request(app).put(`${endpoint}/politecnico`).send({ event: 'discover' });
    expect(discovery.status).toBe(200);
    expect(discovery.body.newly_discovered).toBe(true);
    expect(discovery.body.visited_at).toBeTruthy();

    const loaded = await request(app).get(endpoint);
    expect(loaded.status).toBe(200);
    expect(loaded.body.places).toHaveLength(2);
    expect(loaded.body.places.map((place: { place_id: string }) => place.place_id)).toEqual([
      'hippies', 'politecnico',
    ]);
    expect(loaded.body.places.every((place: { state: string }) => place.state === 'discovered')).toBe(true);
  });

  it('solo confirma una recompensa entre dos descubrimientos simultáneos', async () => {
    const responses = await Promise.all([
      request(app).put(`${endpoint}/theatron`).send({ event: 'discover' }),
      request(app).put(`${endpoint}/theatron`).send({ event: 'discover' }),
    ]);
    expect(responses.map((response) => response.status)).toEqual([200, 200]);
    expect(responses.filter((response) => response.body.newly_discovered)).toHaveLength(1);
    const count = await pool.query<{ count: string }>(
      'SELECT COUNT(*) AS count FROM player_place_progress WHERE player_id = $1 AND place_id = $2',
      [TEST_PLAYER_ID, 'theatron'],
    );
    expect(Number(count.rows[0].count)).toBe(1);
  });
});
