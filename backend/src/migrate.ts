// Cargar .env antes de cualquier otra importación
import dotenv from 'dotenv';
dotenv.config();

import fs from 'fs';
import path from 'path';
import { Pool } from 'pg';

/**
 * Script de migración — ejecutar con: npm run migrate
 *
 * Lee DATABASE_URL del archivo .env y aplica migrations/001_initial.sql.
 * El script es idempotente: puede ejecutarse varias veces sin efectos
 * secundarios gracias a CREATE TABLE IF NOT EXISTS e INSERT ... ON CONFLICT DO NOTHING.
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
    const sqlPath = path.resolve(__dirname, '../migrations/001_initial.sql');
    const sql = fs.readFileSync(sqlPath, 'utf8');

    console.log('⏳  Ejecutando migración...');
    await pool.query(sql);
    console.log('✅  Migración completada exitosamente.');
    console.log('    Tablas creadas: character_types, outfits, hair_styles, player_customization');
  } catch (err) {
    console.error('❌  Error al ejecutar la migración:', err);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

runMigration();
