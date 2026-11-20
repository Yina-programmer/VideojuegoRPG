
import express from 'express';
import { errorHandler } from './middleware/errorHandler';
import customizationRouter from './routes/customization';
import explorationRouter from './routes/exploration';
import questsRouter from './routes/quests';
import authRouter from './routes/auth';
import { pool } from './db';

const app = express();

app.use(express.json());

// Verificar el backend y la base de datos
app.get('/health', async (_req, res) => {
  try {
    await pool.query('SELECT 1');

    res.json({
      status: 'ok',
      service: 'VideojuegoRPG',
      database: 'connected',
      timestamp: new Date().toISOString()
    });
  } catch {
    res.status(503).json({
      status: 'error',
      service: 'VideojuegoRPG',
      database: 'disconnected'
    });
  }
});

// Funcionalidades del videojuego
app.use('/api/auth', authRouter);
app.use('/api/customization', customizationRouter);
app.use('/api/exploration', explorationRouter);
app.use('/api/quests', questsRouter);

// Ruta no encontrada
app.use((_req, res) => {
  res.status(404).json({ error: 'Ruta no encontrada' });
});

// Manejo global de errores
app.use(errorHandler);

export default app;
