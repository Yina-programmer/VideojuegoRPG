import { z } from 'zod';

export const questIdSchema = z.enum(['hippies', 'politecnico', 'theatron', 'final']);
export const questEventSchema = z.object({
  event: z.enum(['start', 'collect', 'verify_outfit', 'solve_order', 'choose_gate', 'answer', 'complete']),
  item_id: z.string().max(40).optional(),
  answer: z.union([z.string().max(40), z.array(z.string().max(40)).max(3)]).optional(),
}).strict();
