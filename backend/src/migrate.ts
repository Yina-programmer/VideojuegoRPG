// Cargar .env antes de cualquier otra importación
import dotenv from 'dotenv';
dotenv.config();

import fs from 'fs';
import path from 'path';
import { Pool } from 'pg';

/**
 * Script de migración — ejecutar con: npm run migrate
 *
 * Lee DATABASE_URL del archivo .env y aplica todas las migraciones .sql
 * ordenadas por nombre. Cada archivo es idempotente.
 */
async function runMigration(): Promise<void> {
  const connectionString = process.env.DATABASE_URL;
  if (!connectionString) {
    console.error(
      '❌  DATABASE_URL no está definida.\n' +
        '    Crea un archivo .env basado en .env.example con tu cadena de conexión.',
    );
    process.exit(1);
  }

  const pool = new Pool({ connectionString });

  try {
    const migrationsPath = path.resolve(__dirname, '../migrations');
    const files = fs.readdirSync(migrationsPath)
      .filter((file) => /^\d+_.*\.sql$/.test(file))
      .sort();

    const onlyIndex = process.argv.indexOf('--only');
    const onlyFile = onlyIndex >= 0 ? process.argv[onlyIndex + 1] : undefined;
    if (onlyIndex >= 0 && (!onlyFile || !files.includes(onlyFile))) {
      throw new Error('La migración indicada no existe en backend/migrations.');
    }

    for (const file of files) {
      if (onlyFile && file !== onlyFile) continue;
      console.log(`⏳  Aplicando ${file}...`);
      await pool.query(fs.readFileSync(path.join(migrationsPath, file), 'utf8'));
      console.log(`✅  ${file} completada.`);
    }
  } catch (err) {
    console.error('❌  Error al ejecutar la migración:', err);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

runMigration();
