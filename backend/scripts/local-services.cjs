const path = require('path');
const fs = require('fs');
const { spawn, spawnSync } = require('child_process');
const backend = path.resolve(__dirname, '..');
require('dotenv').config({ path: path.join(backend, '.env') });
const { Pool } = require('pg');
const port = Number(process.env.PORT || 4001);
const baseUrl = `http://localhost:${port}`;

async function health() {
  try {
    const response = await fetch(`${baseUrl}/health`, { signal: AbortSignal.timeout(2000) });
    const data = await response.json();
    return response.ok && data.service === 'VideojuegoRPG' && data.database === 'connected';
  } catch { return false; }
}

async function ensureServices() {
  const pool = new Pool({ connectionString: process.env.DATABASE_URL, connectionTimeoutMillis: 5000 });
  try {
    if (!process.env.DATABASE_URL) throw new Error('Falta DATABASE_URL en backend/.env.');
    await pool.query('SELECT 1');
    for (const file of fs.readdirSync(path.join(backend, 'migrations')).filter(f => /^\d+_.*\.sql$/.test(f)).sort()) {
      await pool.query(fs.readFileSync(path.join(backend, 'migrations', file), 'utf8'));
    }
  } finally { await pool.end(); }

  if (!await health()) {
    const build = spawnSync(process.execPath, [path.join(backend, 'node_modules/typescript/bin/tsc')], { cwd: backend, stdio: 'inherit', windowsHide: true });
    if (build.error) throw build.error;
    if (build.status !== 0) throw new Error('No se pudo compilar el backend.');
    const state = path.join(backend, '.local');
    fs.mkdirSync(state, { recursive: true });
    const out = fs.openSync(path.join(state, 'api.log'), 'a');
    const err = fs.openSync(path.join(state, 'api-error.log'), 'a');
    const api = spawn(process.execPath, ['dist/server.js'], { cwd: backend, detached: true, windowsHide: true, stdio: ['ignore', out, err] });
    api.on('error', error => console.error(error.message));
    api.unref();
    fs.closeSync(out);
    fs.closeSync(err);
    for (let i = 0; i < 20 && !await health(); i++) await new Promise(resolve => setTimeout(resolve, 500));
    if (!await health()) throw new Error(`No se pudo iniciar ${baseUrl}. Revisa backend/.local/api-error.log y si el puerto ${port} esta ocupado.`);
  }
  console.log(`Backend listo: ${baseUrl} (PostgreSQL conectado)`);
}

module.exports = { ensureServices, backend, baseUrl };
if (require.main === module) ensureServices().catch(error => { console.error(error.message); process.exitCode = 1; });
