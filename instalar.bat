@echo off
REM Instalador de Vision Interactiva: doble clic para preparar esta computadora.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0instalar.ps1" %*
pause
