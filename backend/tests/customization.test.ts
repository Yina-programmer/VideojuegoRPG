import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import request from 'supertest';
import fs from 'fs';
import path from 'path';
import app from '../src/app';
import { pool } from '../src/db';

// ── UUID fijo para todos los tests ───────────────────────────────────────────
// Este ID nunca debe aparecer en la base de desarrollo.
// Se usa para aislar los datos de test y limpiarlos con DELETE puntual.
const TEST_PLAYER_ID = 'a1b2c3d4-e5f6-4789-8abc-def012345678';
const TEST_MALE_PLAYER_ID = 'b1b2c3d4-e5f6-4789-8abc-def012345678';

const VALID_BODY = {
  outfit_id: 'rosa',
  hair_style_id: 'castano',
  character_type: 'mujer',
};

const VALID_MALE_BODY = {
  outfit_id: 'male_general',
  hair_style_id: 'male_black',
  character_type: 'hombre',
};

// ── Configuración global ─────────────────────────────────────────────────────

beforeAll(async () => {
  // Aplicar migración en la BD de test (idempotente — sin DROP ni TRUNCATE)
  const sql = fs.readFileSync(
    path.resolve(__dirname, '../migrations/001_initial.sql'),
    'utf8',
  );
  await pool.query(sql);

  // Eliminar únicamente la fila de test si existe de una ejecución anterior
  await pool.query(
    'DELETE FROM player_customization WHERE player_id IN ($1, $2)',
    [TEST_PLAYER_ID, TEST_MALE_PLAYER_ID],
  );
});

afterAll(async () => {
  // Limpiar la fila de test y cerrar conexiones
  await pool.query(
    'DELETE FROM player_customization WHERE player_id IN ($1, $2)',
    [TEST_PLAYER_ID, TEST_MALE_PLAYER_ID],
  );
  await pool.end();
});

// ── Tests: GET antes de cualquier PUT ────────────────────────────────────────

describe('GET /api/customization/:playerId — jugador sin registro', () => {
  it('devuelve 404 cuando el jugador no tiene personalización guardada', async () => {
    const res = await request(app).get(
      `/api/customization/${TEST_PLAYER_ID}`,
    );
    expect(res.status).toBe(404);
    expect(res.body).toHaveProperty('error');
  });

  it('devuelve 400 para un UUID con formato inválido', async () => {
    const res = await request(app).get('/api/customization/no-es-uuid');
    expect(res.status).toBe(400);
    expect(res.body).toHaveProperty('error');
    expect(res.body).toHaveProperty('details');
  });
});

// ── Tests: validación del body en PUT ────────────────────────────────────────

describe('PUT /api/customization/:playerId — validación Zod', () => {
  it('devuelve 422 para outfit_id fuera de la lista blanca', async () => {
    const res = await request(app)
      .put(`/api/customization/${TEST_PLAYER_ID}`)
      .send({ ...VALID_BODY, outfit_id: 'outfit_fantasma' });

    expect(res.status).toBe(422);
    expect(res.body).toHaveProperty('error');
    expect(res.body).toHaveProperty('details');
  });

  it('devuelve 422 para hair_style_id fuera de la lista blanca', async () => {
    const res = await request(app)
      .put(`/api/customization/${TEST_PLAYER_ID}`)
      .send({ ...VALID_BODY, hair_style_id: 'pelo_imaginario' });

    expect(res.status).toBe(422);
    expect(res.body).toHaveProperty('error');
  });

  it('devuelve 422 para character_type no permitido', async () => {
    const res = await request(app)
      .put(`/api/customization/${TEST_PLAYER_ID}`)
      .send({ ...VALID_BODY, character_type: 'robot' });

    expect(res.status).toBe(422);
    expect(res.body).toHaveProperty('error');
  });

  it('devuelve 400 para UUID malformado en la URL', async () => {
    const res = await request(app)
      .put('/api/customization/uuid-malo-123')
      .send(VALID_BODY);

    expect(res.status).toBe(400);
    expect(res.body).toHaveProperty('error');
  });
});

// ── Tests: creación y UPSERT ─────────────────────────────────────────────────

describe('PUT /api/customization/:playerId — UPSERT', () => {
  it('crea un nuevo registro para un jugador nuevo (primer PUT)', async () => {
    const res = await request(app)
      .put(`/api/customization/${TEST_PLAYER_ID}`)
      .send(VALID_BODY);

    expect(res.status).toBe(200);
    expect(res.body.player_id).toBe(TEST_PLAYER_ID);
    expect(res.body.outfit_id).toBe(VALID_BODY.outfit_id);
    expect(res.body.hair_style_id).toBe(VALID_BODY.hair_style_id);
    expect(res.body.character_type).toBe(VALID_BODY.character_type);
    expect(res.body).toHaveProperty('created_at');
    expect(res.body).toHaveProperty('updated_at');
  });

  it('CRÍTICO: dos PUTs del mismo player_id producen exactamente 1 fila', async () => {
    // Segundo PUT con datos diferentes
    const segundoPut = await request(app)
      .put(`/api/customization/${TEST_PLAYER_ID}`)
      .send({ outfit_id: 'azul', hair_style_id: 'flor_verde', character_type: 'mujer' });

    expect(segundoPut.status).toBe(200);
    expect(segundoPut.body.outfit_id).toBe('azul');
    expect(segundoPut.body.hair_style_id).toBe('flor_verde');

    // Verificar directamente en la BD que solo hay 1 fila
    const { rows } = await pool.query<{ count: string }>(
      'SELECT COUNT(*) AS count FROM player_customization WHERE player_id = $1',
      [TEST_PLAYER_ID],
    );
    expect(parseInt(rows[0].count, 10)).toBe(1);
  });

  it('created_at no cambia en actualizaciones posteriores (UPSERT preserva fecha original)', async () => {
    // Guardar el created_at actual
    const { rows: before } = await pool.query<{ created_at: Date }>(
      'SELECT created_at FROM player_customization WHERE player_id = $1',
      [TEST_PLAYER_ID],
    );
    const createdAtBefore = before[0].created_at.getTime();

    // Tercer PUT
    await request(app)
      .put(`/api/customization/${TEST_PLAYER_ID}`)
      .send({ outfit_id: 'negro', hair_style_id: 'trenzas_rojas', character_type: 'mujer' });

    const { rows: after } = await pool.query<{ created_at: Date }>(
      'SELECT created_at FROM player_customization WHERE player_id = $1',
      [TEST_PLAYER_ID],
    );

    // created_at debe ser idéntico antes y después del UPSERT
    expect(after[0].created_at.getTime()).toBe(createdAtBefore);
  });

  it('updated_at se actualiza en cada UPSERT (updated_at >= created_at)', async () => {
    const { rows } = await pool.query<{ created_at: Date; updated_at: Date }>(
      'SELECT created_at, updated_at FROM player_customization WHERE player_id = $1',
      [TEST_PLAYER_ID],
    );
    expect(rows[0].updated_at.getTime()).toBeGreaterThanOrEqual(
      rows[0].created_at.getTime(),
    );
  });
});

// ── Tests: GET después de los PUTs ───────────────────────────────────────────

describe('PUT/GET masculino — persistencia completa', () => {
  it('guarda y recupera outfit, cabello y tipo del personaje hombre', async () => {
    const putResponse = await request(app)
      .put(`/api/customization/${TEST_MALE_PLAYER_ID}`)
      .send(VALID_MALE_BODY);

    expect(putResponse.status).toBe(200);
    expect(putResponse.body.outfit_id).toBe(VALID_MALE_BODY.outfit_id);
    expect(putResponse.body.hair_style_id).toBe(VALID_MALE_BODY.hair_style_id);
    expect(putResponse.body.character_type).toBe(VALID_MALE_BODY.character_type);

    const getResponse = await request(app).get(
      `/api/customization/${TEST_MALE_PLAYER_ID}`,
    );

    expect(getResponse.status).toBe(200);
    expect(getResponse.body.outfit_id).toBe(VALID_MALE_BODY.outfit_id);
    expect(getResponse.body.hair_style_id).toBe(VALID_MALE_BODY.hair_style_id);
    expect(getResponse.body.character_type).toBe(VALID_MALE_BODY.character_type);
  });
});

describe('GET /api/customization/:playerId — después de UPSERT', () => {
  it('devuelve los datos del último PUT correctamente', async () => {
    const res = await request(app).get(
      `/api/customization/${TEST_PLAYER_ID}`,
    );

    expect(res.status).toBe(200);
    expect(res.body.player_id).toBe(TEST_PLAYER_ID);
    // El último PUT fue con negro/trenzas_rojas
    expect(res.body.outfit_id).toBe('negro');
    expect(res.body.hair_style_id).toBe('trenzas_rojas');
    expect(res.body.character_type).toBe('mujer');
    expect(res.body).toHaveProperty('created_at');
    expect(res.body).toHaveProperty('updated_at');
  });
});

// ── Test: health check ───────────────────────────────────────────────────────

describe('GET /health', () => {
  it('devuelve status ok', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
    expect(res.body).toHaveProperty('timestamp');
  });
});
