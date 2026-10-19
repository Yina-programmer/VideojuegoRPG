import { defineConfig } from 'vitest/config';
import dotenv from 'dotenv';
import path from 'path';
import fs from 'fs';

// Carga .env.test ANTES de que vitest configure el entorno de pruebas.
// Esto garantiza que DATABASE_URL esté disponible cuando db.ts cree el pool.
const testEnvResult = dotenv.config({
  path: path.resolve(__dirname, '.env.test'),
});

const testDatabaseUrl = testEnvResult.parsed?.TEST_DATABASE_URL ?? '';
const developmentPath = path.resolve(__dirname, '.env');
const developmentEnv = fs.existsSync(developmentPath)
  ? dotenv.parse(fs.readFileSync(developmentPath))
  : {};

const testUrl = testDatabaseUrl ? new URL(testDatabaseUrl) : null;
const developmentUrl = developmentEnv.DATABASE_URL
  ? new URL(developmentEnv.DATABASE_URL)
  : null;
const testDatabaseName = decodeURIComponent(testUrl?.pathname.slice(1) ?? '').toLowerCase();
const sameDatabase = testUrl !== null && developmentUrl !== null &&
  testUrl.host.toLowerCase() === developmentUrl.host.toLowerCase() &&
  testUrl.pathname.toLowerCase() === developmentUrl.pathname.toLowerCase();

if (!testUrl || !testDatabaseName.includes('test') || sameDatabase) {
  throw new Error('Las pruebas requieren una base separada con "test" en su nombre.');
}

export default defineConfig({
  test: {
    environment: 'node',
    fileParallelism: false,
    // Sobreescribir DATABASE_URL con la URL de test para todos los workers
    env: {
      NODE_ENV: 'test',
      DATABASE_URL: testDatabaseUrl,
    },
  },
});
