import express from 'express';
import { errorHandler } from './middleware/errorHandler';
import customizationRouter from './routes/customization';
import explorationRouter from './routes/exploration';
import questsRouter from './routes/quests';

const app = express();

// Parsear JSON en el body de las solicitudes
app.use(express.json());

/**
 * GET /health
 * Verificación rápida de que la API está activa.
 * Útil para saber si el servidor está corriendo antes de abrir el juego.
 */
app.get('/health', (_req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.use('/api/customization', customizationRouter);
app.use('/api/exploration', explorationRouter);
app.use('/api/quests', questsRouter);

// Ruta no encontrada
app.use((_req, res) => {
  res.status(404).json({ error: 'Ruta no encontrada' });
});

// Manejo global de errores (debe ir al final)
app.use(errorHandler);

export default app;
