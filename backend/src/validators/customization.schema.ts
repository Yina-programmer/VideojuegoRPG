import { z } from 'zod';

// ── Listas blancas de slugs válidos ──────────────────────────────────────────
// Deben mantenerse sincronizadas con las opciones existentes en Godot.

export const VALID_OUTFITS = [
  'original',
  'rosa',
  'azul',
  'negro',
  'blanco_mono',
  'negro_mono',
] as const;

export const VALID_HAIR_STYLES = [
  'castano',
  'trenzas_rojas',
  'flor_verde',
  'rojo_medio',
  'negro_liso',
] as const;

export const VALID_CHARACTER_TYPES = ['mujer'] as const;

// ── Validador de UUID v4 ──────────────────────────────────────────────────────

const UUID_V4_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export const playerIdSchema = z
  .string()
  .regex(UUID_V4_REGEX, 'player_id debe ser un UUID v4 válido');

// ── Validador del body del PUT ────────────────────────────────────────────────

export const customizationBodySchema = z.object({
  outfit_id: z.enum(VALID_OUTFITS, {
    errorMap: () => ({
      message: `outfit_id debe ser uno de: ${VALID_OUTFITS.join(', ')}`,
    }),
  }),
  hair_style_id: z.enum(VALID_HAIR_STYLES, {
    errorMap: () => ({
      message: `hair_style_id debe ser uno de: ${VALID_HAIR_STYLES.join(', ')}`,
    }),
  }),
  character_type: z.enum(VALID_CHARACTER_TYPES, {
    errorMap: () => ({
      message: `character_type debe ser uno de: ${VALID_CHARACTER_TYPES.join(', ')}`,
    }),
  }),
});

export type CustomizationBody = z.infer<typeof customizationBodySchema>;
