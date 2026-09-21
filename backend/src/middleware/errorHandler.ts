import { Request, Response, NextFunction } from 'express';

/**
 * Middleware global de manejo de errores.
 * Captura cualquier error no manejado y devuelve una respuesta JSON consistente.
 * En producción oculta los detalles del error; en desarrollo los incluye.
 */
export function errorHandler(
  err: unknown,
  _req: Request,
  res: Response,
  _next: NextFunction,
): void {
  // Evitar escribir headers si ya fueron enviados
  if (res.headersSent) return;

  console.error('[errorHandler]', err);

  const message =
    process.env.NODE_ENV !== 'production' && err instanceof Error
      ? err.message
      : undefined;

  res.status(500).json({ error: 'Error interno del servidor', message });
}
