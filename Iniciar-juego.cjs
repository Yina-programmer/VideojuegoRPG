const { spawn } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { ensureServices } = require('./backend/scripts/local-services.cjs');

const root = __dirname;

function findGodot() {
  if (process.env.GODOT_EXE) return process.env.GODOT_EXE;

  const downloads = path.join(os.homedir(), 'Downloads');
  if (fs.existsSync(downloads)) {
    const entries = fs.readdirSync(downloads, { withFileTypes: true })
      .sort((a, b) => b.name.localeCompare(a.name, undefined, { numeric: true }));
    for (const entry of entries) {
      if (!/^Godot_v4.*_win64\.exe$/i.test(entry.name)) continue;
      const executable = entry.isDirectory()
        ? path.join(downloads, entry.name, entry.name)
        : path.join(downloads, entry.name);
      if (fs.existsSync(executable)) return executable;
    }
  }

  return 'godot';
}

async function startGame() {
  await ensureServices();
  console.log('Base de datos y servidor listos. Abriendo el juego...');
  const game = spawn(findGodot(), [
    '--path', root,
    '--rendering-method', 'gl_compatibility',
    '--rendering-driver', 'opengl3',
  ], { stdio: 'inherit' });
  game.on('error', error => {
    console.error(`No se pudo abrir Godot: ${error.message}. Configura GODOT_EXE si no está en Downloads ni en el PATH.`);
    process.exitCode = 1;
  });
  game.on('exit', code => { process.exitCode = code ?? 1; });
}

if (require.main === module) {
  startGame().catch(error => { console.error(error.message); process.exitCode = 1; });
}

module.exports = { findGodot };
