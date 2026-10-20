import { beforeAll, afterAll, describe, expect, it } from 'vitest';
import request from 'supertest';
import fs from 'fs';
import path from 'path';
import app from '../src/app';
import { pool } from '../src/db';

// UUID exclusivos de la base de pruebas.
const NICO = 'f2176900-7708-4b8a-9001-000000000001';
const POLITO_M = 'f2176900-7708-4b8a-9001-000000000002';
const POLITO_F = 'f2176900-7708-4b8a-9001-000000000003';
const DANTE = 'f2176900-7708-4b8a-9001-000000000004';
const OTHER = 'f2176900-7708-4b8a-9001-000000000005';
const players = [NICO, POLITO_M, POLITO_F, DANTE, OTHER];
const quest = (id: string, place: string, event: string, extra = {}) =>
  request(app).put(`/api/quests/${id}/${place}`).send({ event, ...extra });

beforeAll(async () => {
  for (const file of ['001_initial.sql', '002_player_place_progress.sql', '003_quest_progress.sql']) {
    await pool.query(fs.readFileSync(path.resolve(__dirname, '../migrations', file), 'utf8'));
  }
  await pool.query('DELETE FROM player_quest_progress WHERE player_id = ANY($1::uuid[])', [players]);
  await pool.query('DELETE FROM player_place_progress WHERE player_id = ANY($1::uuid[])', [players]);
  await pool.query('DELETE FROM player_customization WHERE player_id = ANY($1::uuid[])', [players]);
});

afterAll(async () => {
  await pool.query('DELETE FROM player_quest_progress WHERE player_id = ANY($1::uuid[])', [players]);
  await pool.query('DELETE FROM player_place_progress WHERE player_id = ANY($1::uuid[])', [players]);
  await pool.query('DELETE FROM player_customization WHERE player_id = ANY($1::uuid[])', [players]);
  await pool.end();
});

describe('HU_8: aventuras validadas por el servidor', () => {
  it('bloquea narrativas nuevas y acciones fuera de orden; conserva visitas', async () => {
    expect((await request(app).put(`/api/exploration/${NICO}/hippies`).send({ event: 'visit' })).status).toBe(200);
    expect((await request(app).put(`/api/exploration/${NICO}/hippies`).send({ event: 'discover' })).status).toBe(403);
    expect((await quest(NICO, 'hippies', 'collect', { item_id: 'arte' })).status).toBe(409);
    expect((await quest(NICO, 'fantasma', 'start')).status).toBe(422);
    expect((await quest(NICO, 'hippies', 'complete')).status).toBe(409);
    expect((await request(app).get(`/api/quests/${OTHER}`)).body.quests).toEqual([]);
  });

  it('Nico: cartel falso, piezas únicas, orden erróneo y desbloqueo final', async () => {
    expect((await quest(NICO, 'hippies', 'start')).status).toBe(200);
    expect((await quest(NICO, 'hippies', 'start')).status).toBe(200);
    expect((await request(app).put(`/api/exploration/${NICO}/hippies`).send({ event: 'discover' })).status).toBe(403);
    expect((await quest(NICO, 'hippies', 'solve_order', { answer: ['arte', 'calle', 'memoria'] })).status).toBe(409);
    for (const item_id of ['cartel_falso', 'arte', 'calle', 'memoria', 'arte']) {
      expect((await quest(NICO, 'hippies', 'collect', { item_id })).status).toBe(200);
    }
    expect((await quest(NICO, 'hippies', 'solve_order', { answer: ['memoria', 'calle', 'arte'] })).status).toBe(409);
    expect((await quest(NICO, 'hippies', 'complete')).status).toBe(409);
    expect((await quest(NICO, 'hippies', 'solve_order', { answer: ['arte', 'calle', 'memoria'] })).status).toBe(200);
    expect((await request(app).put(`/api/exploration/${NICO}/hippies`).send({ event: 'discover' })).status).toBe(403);
    const completed = await quest(NICO, 'hippies', 'complete');
    expect(completed.body.status).toBe('completed');
    expect(completed.body.narrative_unlocked_at).toBeTruthy();
    expect(completed.body.collected_items).toHaveLength(4);
    expect((await request(app).put(`/api/exploration/${NICO}/hippies`).send({ event: 'discover' })).body.newly_discovered).toBe(true);
    expect((await request(app).put(`/api/exploration/${NICO}/politecnico`).send({ event: 'discover' })).status).toBe(403);
    expect((await request(app).put(`/api/exploration/${NICO}/hippies`).send({ event: 'discover' })).body.newly_discovered).toBe(false);
    expect((await request(app).get(`/api/quests/${NICO}`)).body.quests[0].status).toBe('completed');
  });

  it.each([
    [POLITO_M, 'hombre', 'male_formal', 'male_black'],
    [POLITO_F, 'mujer', 'blanco_mono', 'castano'],
  ])('Polito reconoce el outfit guardado de %s', async (id, character_type, outfit_id, hair_style_id) => {
    expect((await quest(id, 'politecnico', 'start')).status).toBe(200);
    expect((await quest(id, 'politecnico', 'collect', { item_id: 'doc_1980' })).status).toBe(409);
    await pool.query(
      `INSERT INTO player_customization (player_id, character_type, outfit_id, hair_style_id)
       VALUES ($1, $2, 'original', $3)`, [id, character_type, hair_style_id],
    );
    expect((await quest(id, 'politecnico', 'verify_outfit')).status).toBe(409);
    await pool.query('UPDATE player_customization SET outfit_id = $2 WHERE player_id = $1', [id, outfit_id]);
    expect((await quest(id, 'politecnico', 'verify_outfit')).status).toBe(200);
    for (const item_id of ['doc_1991', 'doc_1980', 'doc_1981']) {
      expect((await quest(id, 'politecnico', 'collect', { item_id })).status).toBe(200);
    }
    expect((await quest(id, 'politecnico', 'solve_order', { answer: ['1991', '1981', '1980'] })).status).toBe(409);
    expect((await quest(id, 'politecnico', 'solve_order', { answer: ['1980', '1981', '1991'] })).status).toBe(200);
    expect((await quest(id, 'politecnico', 'complete')).body.status).toBe('completed');
  });

  it('Dante permite reintentos y no acepta preguntas antes de la puerta', async () => {
    await quest(DANTE, 'theatron', 'start');
    expect((await quest(DANTE, 'theatron', 'choose_gate', { answer: 'cine' })).status).toBe(409);
    await quest(DANTE, 'theatron', 'collect', { item_id: 'boleto_1' });
    await quest(DANTE, 'theatron', 'collect', { item_id: 'boleto_2' });
    expect((await quest(DANTE, 'theatron', 'answer', { answer: 'cine' })).status).toBe(409);
    expect((await quest(DANTE, 'theatron', 'choose_gate', { answer: 'aula' })).status).toBe(409);
    expect((await quest(DANTE, 'theatron', 'choose_gate', { answer: 'cine' })).status).toBe(200);
    expect((await quest(DANTE, 'theatron', 'answer', { answer: 'museo' })).status).toBe(409);
    expect((await quest(DANTE, 'theatron', 'answer', { answer: 'cine' })).status).toBe(200);
    expect((await quest(DANTE, 'theatron', 'complete')).body.status).toBe('completed');
  });

  it('misterio final exige tres misiones y entrega una única insignia', async () => {
    expect((await quest(NICO, 'final', 'start')).status).toBe(409);
    await pool.query(
      `INSERT INTO player_quest_progress (player_id, quest_id, status, completed_at, narrative_unlocked_at)
       VALUES ($1, 'politecnico', 'completed', NOW(), NOW()), ($1, 'theatron', 'completed', NOW(), NOW())`, [NICO],
    );
    expect((await quest(NICO, 'final', 'start')).status).toBe(200);
    expect((await quest(NICO, 'final', 'solve_order', { answer: ['diversidad', 'arte', 'conocimiento'] })).status).toBe(409);
    expect((await quest(NICO, 'final', 'solve_order', { answer: ['arte', 'conocimiento', 'diversidad'] })).status).toBe(200);
    expect((await quest(NICO, 'final', 'complete')).body.status).toBe('completed');
    const repeated = await quest(NICO, 'final', 'complete');
    expect(repeated.body.changed).toBe(false);
    expect((await request(app).get(`/api/quests/${OTHER}`)).body.quests).toEqual([]);
  });
});
