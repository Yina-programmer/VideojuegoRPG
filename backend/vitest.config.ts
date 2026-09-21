import { defineConfig } from 'vitest/config';
import dotenv from 'dotenv';
import path from 'path';

// Carga .env.test ANTES de que vitest configure el entorno de pruebas.
// Esto garantiza que DATABASE_URL esté disponible cuando db.ts cree el pool.
const testEnvResult = dotenv.config({
  path: path.resolve(__dirname, '.env.test'),
});

const testDatabaseUrl = testEnvResult.parsed?.TEST_DATABASE_URL ?? '';

export default defineConfig({
  test: {
    environment: 'node',
    // Sobreescribir DATABASE_URL con la URL de test para todos los workers
    env: {
      NODE_ENV: 'test',
      ...(testDatabaseUrl ? { DATABASE_URL: testDatabaseUrl } : {}),
    },
  },
});
