import dotenv from 'dotenv';
import fs from 'fs';
import path from 'path';

const testPath = path.resolve(__dirname, '../.env.test');
const developmentPath = path.resolve(__dirname, '../.env');
const test = dotenv.parse(fs.readFileSync(testPath));
const development = fs.existsSync(developmentPath)
  ? dotenv.parse(fs.readFileSync(developmentPath))
  : {};
const testUrl = test.TEST_DATABASE_URL;
if (!testUrl) throw new Error('Falta TEST_DATABASE_URL en backend/.env.test');
const parsed = new URL(testUrl);
const developmentUrl = development.DATABASE_URL ? new URL(development.DATABASE_URL) : null;
if (!decodeURIComponent(parsed.pathname).toLowerCase().includes('test') ||
  (developmentUrl && developmentUrl.host.toLowerCase() === parsed.host.toLowerCase() &&
    developmentUrl.pathname.toLowerCase() === parsed.pathname.toLowerCase())) {
  throw new Error('El servidor de pruebas requiere una base distinta a la de desarrollo.');
}

process.env.DATABASE_URL = testUrl;
process.env.PORT = '4001';
process.env.NODE_ENV = 'test';
console.log(`[server:test] Base aislada: ${decodeURIComponent(parsed.pathname.slice(1))}`);
void import('./server');
