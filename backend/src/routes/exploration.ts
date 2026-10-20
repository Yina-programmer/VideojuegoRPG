import { Router, Request, Response, NextFunction } from 'express';
import { pool } from '../db';
import {
  explorationEventSchema,
  placeIdSchema,
  playerIdSchema,
} from '../validators/exploration.schema';

const router = Router();

interface ProgressRow {
  player_id: string;
  place_id: string;
  visited_at: Date;
  discovered_at: Date | null;
  updated_at: Date;
}

function present(row: ProgressRow) {
  return {
    ...row,
    state: row.discovered_at === null ? 'visited' : 'discovered',
  };
}

// Un jugador sin filas recibe una colección vacía, no un error ni un falso descubrimiento.
router.get('/:playerId', async (req: Request, res: Response, next: NextFunction): Promise<void> => {
  try {
    const player = playerIdSchema.safeParse(req.params.playerId);
    if (!player.success) {
      res.status(400).json({ error: 'player_id inválido', details: player.error.issues });
      return;
    }

    const { rows } = await pool.query<ProgressRow>(
      `SELECT player_id, place_id, visited_at, discovered_at, updated_at
       FROM player_place_progress WHERE player_id = $1 ORDER BY place_id`,
      [player.data],
    );
    res.status(200).json({ player_id: player.data, places: rows.map(present) });
  } catch (error) {
    next(error);
  }
});

router.put('/:playerId/:placeId', async (req: Request, res: Response, next: NextFunction): Promise<void> => {
  try {
    const player = playerIdSchema.safeParse(req.params.playerId);
    const place = placeIdSchema.safeParse(req.params.placeId);
    const body = explorationEventSchema.safeParse(req.body);
    if (!player.success) {
      res.status(400).json({ error: 'player_id inválido', details: player.error.issues });
      return;
    }
    if (!place.success || !body.success) {
      res.status(422).json({
        error: 'Evento de exploración inválido',
        details: [...(place.success ? [] : place.error.issues), ...(body.success ? [] : body.error.issues)],
      });
      return;
    }

    const isDiscovery = body.data.event === 'discover';
    if (isDiscovery) {
      // HU_7 conserva sus descubrimientos históricos. Solo los nuevos requieren
      // que la aventura correspondiente haya desbloqueado la narrativa.
      const permission = await pool.query<{ allowed: boolean }>(
        `SELECT EXISTS (
           SELECT 1 FROM player_place_progress
           WHERE player_id = $1 AND place_id = $2 AND discovered_at IS NOT NULL
         ) OR EXISTS (
           SELECT 1 FROM player_quest_progress
           WHERE player_id = $1 AND quest_id = $2 AND status = 'completed'
         ) AS allowed`,
        [player.data, place.data],
      );
      if (!permission.rows[0].allowed) {
        res.status(403).json({ error: 'Historia bloqueada', hint: 'Completa la misión del lugar para abrir su narrativa.' });
        return;
      }
    }
    // El único UPDATE permitido es la transición visitado -> descubierto.
    // Repetir visitas o descubrimientos no cambia las fechas originales.
    const upsert = await pool.query<ProgressRow>(
      `INSERT INTO player_place_progress
         (player_id, place_id, visited_at, discovered_at)
       VALUES ($1, $2, NOW(), CASE WHEN $3::text = 'discover' THEN NOW() ELSE NULL END)
       ON CONFLICT (player_id, place_id) DO UPDATE SET
         discovered_at = EXCLUDED.discovered_at,
         updated_at = NOW()
       WHERE EXCLUDED.discovered_at IS NOT NULL
         AND player_place_progress.discovered_at IS NULL
       RETURNING player_id, place_id, visited_at, discovered_at, updated_at`,
      [player.data, place.data, body.data.event],
    );

    const changed = upsert.rows.length === 1;
    const row = changed ? upsert.rows[0] : (await pool.query<ProgressRow>(
      `SELECT player_id, place_id, visited_at, discovered_at, updated_at
       FROM player_place_progress WHERE player_id = $1 AND place_id = $2`,
      [player.data, place.data],
    )).rows[0];

    res.status(200).json({
      ...present(row),
      changed,
      newly_discovered: isDiscovery && changed,
    });
  } catch (error) {
    next(error);
  }
});

export default router;
