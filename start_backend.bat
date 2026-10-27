@echo off
REM Arranca el servidor de vision manualmente (la app Flutter lo hace sola si no esta corriendo).
cd /d "%~dp0backend"
.venv\Scripts\python -m uvicorn app.main:app --host 127.0.0.1 --port 8000
pause
