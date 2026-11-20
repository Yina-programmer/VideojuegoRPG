const path = require('path');
const { spawnSync } = require('child_process');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });

try {
  if (!process.env.DATABASE_URL) throw new Error('Falta DATABASE_URL en backend/.env.');
  const url = new URL(process.env.DATABASE_URL);
  const psql = process.env.PSQL_EXE || 'psql';
  const env = { ...process.env, PGHOST: url.hostname, PGPORT: url.port || '5432', PGUSER: decodeURIComponent(url.username), PGPASSWORD: decodeURIComponent(url.password), PGDATABASE: decodeURIComponent(url.pathname.slice(1)), PGCLIENTENCODING: 'UTF8', PGCONNECT_TIMEOUT: '5' };
  console.log(`Base: ${env.PGDATABASE} | Servidor: ${env.PGHOST}:${env.PGPORT}`);
  console.log('Consultas: SELECT * FROM player_customization;  SELECT * FROM player_place_progress;');
  console.log('Lista de tablas: \\dt   |   Salir: \\q');
  const args = ['-X', '-P', 'pager=off'];
  if (process.argv.includes('--resumen')) args.push('-c', 'SELECT * FROM player_customization ORDER BY updated_at DESC LIMIT 20; SELECT * FROM player_place_progress ORDER BY updated_at DESC LIMIT 20;');
  const result = spawnSync(psql, args, { env, stdio: 'inherit', windowsHide: true });
  if (result.error) throw new Error('No se encuentra psql. Agrégalo al PATH o configura PSQL_EXE con su ruta.');
  process.exitCode = result.status ?? 1;
} catch (error) { console.error(error.message); process.exitCode = 1; }
