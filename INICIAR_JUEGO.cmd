@echo off
cd /d "%~dp0"
node "%~dp0Iniciar-juego.cjs"
if errorlevel 1 pause
