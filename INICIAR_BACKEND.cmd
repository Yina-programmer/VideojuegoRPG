@echo off
cd /d "%~dp0"
node backend\scripts\local-services.cjs
if errorlevel 1 pause
