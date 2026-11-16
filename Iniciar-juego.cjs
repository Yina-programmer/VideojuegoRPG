const {spawn}=require('child_process');
const path=require('path');
const root=__dirname, backend=path.join(root,'backend'), state=path.join(backend,'.local');
const {ensureServices}=require('./backend/scripts/local-services.cjs');
const godot='C:\\Users\\USER\\Downloads\\Godot_v4.7.2-stable_win64.exe\\Godot_v4.7.2-stable_win64.exe';
(async()=>{
 await ensureServices();
 console.log('Base de datos y servidor listos. Abriendo el juego...');
 const game=spawn(godot,['--path',root,'--rendering-method','gl_compatibility','--rendering-driver','opengl3'],{env:{...process.env,APPDATA:path.join(state,'appdata'),LOCALAPPDATA:path.join(state,'localappdata')},stdio:'inherit'});
 game.on('error',e=>{console.error(e.message);process.exitCode=1});
 game.on('exit',code=>{process.exitCode=code||0});
})().catch(e=>{console.error(e.message);process.exitCode=1});
