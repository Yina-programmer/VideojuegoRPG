import 'dotenv/config';
import { Pool } from 'pg';

/**
 * Pool de conexiones a PostgreSQL.
 *
 * En tiempo de tests, vitest.config.ts sobreescribe DATABASE_URL con
 * TEST_DATABASE_URL antes de que este módulo sea importado, por lo que
 * el pool apunta automáticamente a la base de test sin cambios en el código.
 */
const connectionString = process.env.DATABASE_URL;

if (!connectionString) {
  throw new Error(
    'DATABASE_URL no está definida. ' +
      'Crea un archivo .env basado en .env.example con tu cadena de conexión.',
  );
}

export const pool = new Pool({
  connectionString,
  max: 10,                      // máximo de conexiones simultáneas
  idleTimeoutMillis: 30_000,    // cerrar conexiones inactivas tras 30 s
  connectionTimeoutMillis: 5_000, // error si no consigue conexión en 5 s
});

pool.on('error', (err: Error) => {
  console.error('[db] Error inesperado en cliente idle:', err.message);
});
