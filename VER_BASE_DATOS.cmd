@echo off
cd /d "%~dp0"
node backend\scripts\database.cjs
if errorlevel 1 pause
