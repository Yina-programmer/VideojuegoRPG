import express from 'express';
import { errorHandler } from './middleware/errorHandler';
import customizationRouter from './routes/customization';
import explorationRouter from './routes/exploration';
import { pool } from './db';

const app = express();

// Parsear JSON en el body de las solicitudes
app.use(express.json());

/**
 * GET /health
 * Verificación rápida de que la API está activa.
 * Útil para saber si el servidor está corriendo antes de abrir el juego.
 */
app.get('/health', async (_req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ status: 'ok', service: 'VideojuegoRPG', database: 'connected', timestamp: new Date().toISOString() });
  } catch {
    res.status(503).json({ status: 'error', service: 'VideojuegoRPG', database: 'disconnected' });
  }
});

app.use('/api/customization', customizationRouter);
app.use('/api/exploration', explorationRouter);

// Ruta no encontrada
app.use((_req, res) => {
  res.status(404).json({ error: 'Ruta no encontrada' });
});

// Manejo global de errores (debe ir al final)
app.use(errorHandler);

export default app;
