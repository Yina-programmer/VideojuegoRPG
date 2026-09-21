import { Router, Request, Response, NextFunction } from 'express';
import { pool } from '../db';
import {
  customizationBodySchema,
  playerIdSchema,
} from '../validators/customization.schema';

const router = Router();

// ── Tipo de fila devuelta por la BD ──────────────────────────────────────────
interface CustomizationRow {
  player_id: string;
  character_type: string;
  outfit_id: string;
  hair_style_id: string;
  created_at: Date;
  updated_at: Date;
}

/**
 * GET /api/customization/:playerId
 * Devuelve la personalización guardada para un jugador.
 *
 * 200 — personalización encontrada
 * 400 — player_id no es un UUID v4 válido
 * 404 — sin registro para ese jugador (primera vez)
 * 500 — error interno
 */
router.get(
  '/:playerId',
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const idParse = playerIdSchema.safeParse(req.params.playerId);
      if (!idParse.success) {
        res
          .status(400)
          .json({ error: 'player_id inválido', details: idParse.error.issues });
        return;
      }

      const { rows } = await pool.query<CustomizationRow>(
        `SELECT player_id, character_type, outfit_id, hair_style_id,
                created_at, updated_at
         FROM player_customization
         WHERE player_id = $1`,
        [idParse.data],
      );

      if (rows.length === 0) {
        res.status(404).json({
          error: 'No se encontró personalización para este jugador',
        });
        return;
      }

      res.status(200).json(rows[0]);
    } catch (err) {
      next(err);
    }
  },
);

/**
 * PUT /api/customization/:playerId
 * Crea o actualiza (UPSERT) la personalización de un jugador.
 * Garantiza exactamente 1 fila por player_id sin importar cuántas veces se llame.
 *
 * 200 — creado o actualizado correctamente (UPSERT)
 * 400 — player_id no es un UUID v4 válido
 * 422 — outfit_id, hair_style_id o character_type no reconocidos
 * 500 — error interno
 */
router.put(
  '/:playerId',
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      // 1. Validar player_id
      const idParse = playerIdSchema.safeParse(req.params.playerId);
      if (!idParse.success) {
        res
          .status(400)
          .json({ error: 'player_id inválido', details: idParse.error.issues });
        return;
      }

      // 2. Validar body con Zod (lista blanca de slugs)
      const bodyParse = customizationBodySchema.safeParse(req.body);
      if (!bodyParse.success) {
        res.status(422).json({
          error: 'Datos de personalización inválidos',
          details: bodyParse.error.issues,
        });
        return;
      }

      const { outfit_id, hair_style_id, character_type } = bodyParse.data;

      // 3. UPSERT — nunca inserta duplicados
      const { rows } = await pool.query<CustomizationRow>(
        `INSERT INTO player_customization
           (player_id, character_type, outfit_id, hair_style_id)
         VALUES ($1, $2, $3, $4)
         ON CONFLICT (player_id) DO UPDATE SET
           outfit_id      = EXCLUDED.outfit_id,
           hair_style_id  = EXCLUDED.hair_style_id,
           character_type = EXCLUDED.character_type,
           updated_at     = NOW()
         RETURNING player_id, character_type, outfit_id, hair_style_id,
                   created_at, updated_at`,
        [idParse.data, character_type, outfit_id, hair_style_id],
      );

      res.status(200).json(rows[0]);
    } catch (err) {
      next(err);
    }
  },
);

export default router;
