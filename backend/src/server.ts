import 'dotenv/config';
import app from './app';
import { pool } from './db';

const PORT = Number(process.env.PORT ?? '4000');

async function start(): Promise<void> {
  if (!Number.isInteger(PORT) || PORT < 1 || PORT > 65535) {
    throw new Error('PORT debe ser un entero entre 1 y 65535. Revisa backend/.env.');
  }
  await pool.query('SELECT 1');
  const server = app.listen(PORT, () => {
    console.log(`[server] API corriendo en http://localhost:${PORT}`);
    console.log(`[server] Entorno: ${process.env.NODE_ENV ?? 'development'}`);
    console.log(`[server] Health check: http://localhost:${PORT}/health`);
  });
  server.on('error', async (error: NodeJS.ErrnoException) => {
    console.error(error.code === 'EADDRINUSE'
      ? `[server] El puerto ${PORT} ya esta ocupado. Usa la instancia activa o detenla antes de ejecutar npm.cmd run dev.`
      : `[server] No se pudo iniciar: ${error.message}`);
    await pool.end();
    process.exitCode = 1;
  });
}

start().catch(async (error: Error) => {
  console.error(`[server] No se pudo iniciar. Revisa PostgreSQL y backend/.env: ${error.message}`);
  await pool.end();
  process.exitCode = 1;
});
