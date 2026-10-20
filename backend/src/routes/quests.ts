import { Router, Request, Response, NextFunction } from 'express';
import { PoolClient } from 'pg';
import { pool } from '../db';
import { playerIdSchema } from '../validators/exploration.schema';
import { questEventSchema, questIdSchema } from '../validators/quests.schema';

const router = Router();
type QuestId = 'hippies' | 'politecnico' | 'theatron' | 'final';
type Row = {
  player_id: string; quest_id: QuestId; status: 'active' | 'completed';
  collected_items: string[]; solved_steps: string[];
  started_at: Date; completed_at: Date | null;
  narrative_unlocked_at: Date | null; updated_at: Date;
};

const ITEMS: Record<QuestId, string[]> = {
  hippies: ['arte', 'calle', 'memoria', 'cartel_falso'],
  politecnico: ['doc_1980', 'doc_1981', 'doc_1991'],
  theatron: ['boleto_1', 'boleto_2'],
  final: [],
};
const REQUIRED: Record<QuestId, string[]> = {
  hippies: ['arte', 'calle', 'memoria'],
  politecnico: ITEMS.politecnico,
  theatron: ITEMS.theatron,
  final: [],
};
const ORDERS: Partial<Record<QuestId, string[]>> = {
  hippies: ['arte', 'calle', 'memoria'],
  politecnico: ['1980', '1981', '1991'],
  final: ['arte', 'conocimiento', 'diversidad'],
};

function reject(res: Response, message: string, hint: string, status = 409): void {
  res.status(status).json({ error: message, hint });
}

async function readRow(client: PoolClient, playerId: string, questId: QuestId): Promise<Row | undefined> {
  return (await client.query<Row>(
    'SELECT * FROM player_quest_progress WHERE player_id = $1 AND quest_id = $2 FOR UPDATE',
    [playerId, questId],
  )).rows[0];
}

router.get('/:playerId', async (req: Request, res: Response, next: NextFunction): Promise<void> => {
  try {
    const id = playerIdSchema.safeParse(req.params.playerId);
    if (!id.success) { reject(res, 'Jugador inválido', 'Reinicia el juego.', 400); return; }
    const rows = await pool.query<Row>(
      'SELECT * FROM player_quest_progress WHERE player_id = $1 ORDER BY quest_id', [id.data],
    );
    res.json({ player_id: id.data, quests: rows.rows });
  } catch (error) { next(error); }
});

router.put('/:playerId/:questId', async (req: Request, res: Response, next: NextFunction): Promise<void> => {
  const id = playerIdSchema.safeParse(req.params.playerId);
  const quest = questIdSchema.safeParse(req.params.questId);
  const body = questEventSchema.safeParse(req.body);
  if (!id.success || !quest.success || !body.success) {
    reject(res, 'Acción de misión inválida', 'Comprueba los datos de la misión.', 422);
    return;
  }
  const questId = quest.data;
  const { event, item_id: itemId, answer } = body.data;
  let client: PoolClient | undefined;
  try {
    client = await pool.connect();
    await client.query('BEGIN');
    // Serializa acciones del mismo jugador y misión, también antes de crear la fila.
    await client.query('SELECT pg_advisory_xact_lock(hashtext($1), hashtext($2))', [id.data, questId]);
    let row = await readRow(client, id.data, questId);
    let changed = false;
    if (event === 'start') {
      if (questId === 'final' && !row) {
        const completed = await client.query<{ quest_id: string }>(
          "SELECT quest_id FROM player_quest_progress WHERE player_id = $1 AND status = 'completed' AND quest_id <> 'final'",
          [id.data],
        );
        if (completed.rowCount !== 3) {
          reject(res, 'Faltan aventuras', 'Completa primero las misiones de Nico, Polito y Dante.');
          await client.query('ROLLBACK'); return;
        }
      }
      if (!row) {
        row = (await client.query<Row>(
          'INSERT INTO player_quest_progress (player_id, quest_id) VALUES ($1, $2) RETURNING *',
          [id.data, questId],
        )).rows[0];
        changed = true;
      }
    } else if (!row) {
      reject(res, 'Misión no iniciada', 'Habla primero con el personaje que propone la misión.');
      await client.query('ROLLBACK'); return;
    } else if (row.status === 'completed') {
      await client.query('COMMIT'); res.json({ ...row, changed: false }); return;
    } else if (event === 'collect') {
      if (!itemId || !ITEMS[questId].includes(itemId)) {
        reject(res, 'Objeto inválido', 'Busca los objetos de esta misión.');
        await client.query('ROLLBACK'); return;
      }
      if (questId === 'politecnico' && !row.solved_steps.includes('outfit')) {
        reject(res, 'Acceso pendiente', 'Regresa con Polito usando el atuendo solicitado.');
        await client.query('ROLLBACK'); return;
      }
      if (!row.collected_items.includes(itemId)) {
        row = (await client.query<Row>(
          'UPDATE player_quest_progress SET collected_items = array_append(collected_items, $3), updated_at = NOW() WHERE player_id = $1 AND quest_id = $2 RETURNING *',
          [id.data, questId, itemId],
        )).rows[0];
        changed = true;
      }
    } else if (event === 'verify_outfit') {
      if (questId !== 'politecnico') {
        reject(res, 'Desafío inválido', 'Esta prueba corresponde al Politécnico.');
        await client.query('ROLLBACK'); return;
      }
      const outfit = (await client.query<{ character_type: string; outfit_id: string }>(
        'SELECT character_type, outfit_id FROM player_customization WHERE player_id = $1', [id.data],
      )).rows[0];
      if (!outfit || !((outfit.character_type === 'hombre' && outfit.outfit_id === 'male_formal') ||
        (outfit.character_type === 'mujer' && outfit.outfit_id === 'blanco_mono'))) {
        reject(res, 'Atuendo pendiente', 'Guarda en el armario Formal (hombre) o Lazo blanco (mujer) y vuelve con Polito.');
        await client.query('ROLLBACK'); return;
      }
      if (!row.solved_steps.includes('outfit')) {
        row = (await client.query<Row>(
          "UPDATE player_quest_progress SET solved_steps = array_append(solved_steps, 'outfit'), updated_at = NOW() WHERE player_id = $1 AND quest_id = $2 RETURNING *",
          [id.data, questId],
        )).rows[0];
        changed = true;
      }
    } else if (event === 'solve_order') {
      if (!ORDERS[questId] || !Array.isArray(answer) ||
        REQUIRED[questId].some(item => !row!.collected_items.includes(item)) ||
        (questId === 'politecnico' && !row.solved_steps.includes('outfit'))) {
        reject(res, 'Faltan pistas', 'Reúne primero todas las pistas necesarias.');
        await client.query('ROLLBACK'); return;
      }
      if (JSON.stringify(answer) !== JSON.stringify(ORDERS[questId])) {
        reject(res, 'Orden incorrecto', questId === 'politecnico' ? 'Ordena las fechas de la más antigua a la más reciente.' : 'Piensa en cómo se conectan los tres símbolos.');
        await client.query('ROLLBACK'); return;
      }
      if (!row.solved_steps.includes('order')) {
        row = (await client.query<Row>(
          "UPDATE player_quest_progress SET solved_steps = array_append(solved_steps, 'order'), updated_at = NOW() WHERE player_id = $1 AND quest_id = $2 RETURNING *",
          [id.data, questId],
        )).rows[0];
        changed = true;
      }
    } else if (event === 'choose_gate') {
      if (questId !== 'theatron' || REQUIRED.theatron.some(item => !row!.collected_items.includes(item))) {
        reject(res, 'Faltan fragmentos', 'Reconstruye el boleto antes de elegir una entrada.');
        await client.query('ROLLBACK'); return;
      }
      if (answer !== 'cine') {
        reject(res, 'Ruta equivocada', '¡Ruta falsa! El boleto habla de una pantalla y una sala antigua.');
        await client.query('ROLLBACK'); return;
      }
      if (!row.solved_steps.includes('gate')) {
        row = (await client.query<Row>(
          "UPDATE player_quest_progress SET solved_steps = array_append(solved_steps, 'gate'), updated_at = NOW() WHERE player_id = $1 AND quest_id = $2 RETURNING *",
          [id.data, questId],
        )).rows[0];
        changed = true;
      }
    } else if (event === 'answer') {
      if (questId !== 'theatron' || !row.solved_steps.includes('gate')) {
        reject(res, 'Entrada pendiente', 'Resuelve primero el misterio de las entradas.');
        await client.query('ROLLBACK'); return;
      }
      if (answer !== 'cine') {
        reject(res, 'Respuesta incorrecta', 'Recuerda la pista del boleto: pantalla, sala y proyector.');
        await client.query('ROLLBACK'); return;
      }
      if (!row.solved_steps.includes('question')) {
        row = (await client.query<Row>(
          "UPDATE player_quest_progress SET solved_steps = array_append(solved_steps, 'question'), updated_at = NOW() WHERE player_id = $1 AND quest_id = $2 RETURNING *",
          [id.data, questId],
        )).rows[0];
        changed = true;
      }
    } else if (event === 'complete') {
      const required = questId === 'theatron' ? 'question' : 'order';
      if (!row.solved_steps.includes(required)) {
        reject(res, 'Desafío pendiente', 'Termina el acertijo antes de cerrar la misión.');
        await client.query('ROLLBACK'); return;
      }
      row = (await client.query<Row>(
        `UPDATE player_quest_progress SET status = 'completed', completed_at = NOW(),
           narrative_unlocked_at = CASE WHEN quest_id = 'final' THEN NULL ELSE NOW() END,
           updated_at = NOW() WHERE player_id = $1 AND quest_id = $2 RETURNING *`,
        [id.data, questId],
      )).rows[0];
      changed = true;
    }
    await client.query('COMMIT');
    res.json({ ...row, changed });
  } catch (error) {
    if (client) await client.query('ROLLBACK');
    next(error);
  } finally { client?.release(); }
});

export default router;
