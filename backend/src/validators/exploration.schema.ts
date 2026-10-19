import { z } from 'zod';
import { playerIdSchema } from './customization.schema';

// Catálogo inicial. Nuevos lugares se agregan aquí sin cambiar la API ni la bitácora.
export const placeIdSchema = z.enum(['hippies', 'politecnico', 'theatron']);

export const explorationEventSchema = z.object({
  event: z.enum(['visit', 'discover']),
}).strict();

export { playerIdSchema };
