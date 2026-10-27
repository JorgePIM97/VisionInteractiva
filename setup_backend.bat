@echo off
REM Crea el entorno de Python del backend e instala las dependencias.
REM Requiere Python 3.11 y, para usar la GPU, un driver NVIDIA reciente.
cd /d "%~dp0backend"
if not exist .venv (
    python -m venv .venv || goto :error
)
.venv\Scripts\python -m pip install --upgrade pip
REM PyTorch con CUDA 12.6 (si no hay GPU NVIDIA funciona igual en CPU)
.venv\Scripts\python -m pip install torch torchvision --index-url https://download.pytorch.org/whl/cu126 || goto :error
.venv\Scripts\python -m pip install -r requirements.txt || goto :error
echo.
echo Listo. Verificando CUDA:
.venv\Scripts\python -c "import torch; print('CUDA disponible:', torch.cuda.is_available())"
pause
exit /b 0
:error
echo Ocurrio un error durante la instalacion.
pause
exit /b 1
