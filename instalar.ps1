# Instalador de Visión Interactiva.
# Uso: doble clic en instalar.bat (o: powershell -ExecutionPolicy Bypass -File instalar.ps1)
param(
    [switch]$NoShortcut,  # no crear el acceso directo en el escritorio
    [switch]$NoBuild      # no compilar la app Flutter
)

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
$Backend = Join-Path $Root 'backend'
$Venv = Join-Path $Backend '.venv'
$VenvPython = Join-Path $Venv 'Scripts\python.exe'
$ReleaseExe = Join-Path $Root 'app\build\windows\x64\runner\Release\vision_interactiva.exe'

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Ok($msg) { Write-Host "    $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "    $msg" -ForegroundColor Yellow }
function Fail($msg) { Write-Host "`nERROR: $msg" -ForegroundColor Red; exit 1 }

function Invoke-Checked {
    & $args[0] @($args | Select-Object -Skip 1)
    if ($LASTEXITCODE -ne 0) { Fail "Falló el comando: $($args -join ' ')" }
}

# --- 1. Python ---------------------------------------------------------------
Step 'Buscando Python 3.10 - 3.12'
$PythonCmd = $null
foreach ($candidate in @(@('py', '-3.11'), @('py', '-3.12'), @('py', '-3.10'), @('python'))) {
    try {
        $version = & $candidate[0] @($candidate | Select-Object -Skip 1) -c "import sys; print('%d.%d' % sys.version_info[:2])" 2>$null
        if ($LASTEXITCODE -eq 0 -and $version -in @('3.10', '3.11', '3.12')) { $PythonCmd = $candidate; break }
    } catch { }
}
if (-not $PythonCmd) {
    Fail 'No se encontró Python 3.10-3.12. Instala Python 3.11 desde python.org marcando "Add python.exe to PATH" y vuelve a ejecutar.'
}
Ok "Python $version ($($PythonCmd -join ' '))"

# --- 2. GPU NVIDIA -------------------------------------------------------------
Step 'Detectando GPU NVIDIA'
$TorchIndex = 'https://download.pytorch.org/whl/cpu'
if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) {
    $gpu = @(& nvidia-smi --query-gpu=name --format=csv,noheader 2>$null)
    if ($LASTEXITCODE -eq 0 -and $gpu.Count -gt 0) {
        $gpu = $gpu[0]
        $TorchIndex = 'https://download.pytorch.org/whl/cu126'
        Ok "GPU encontrada: $gpu (se instalará PyTorch con CUDA)"
    }
}
if ($TorchIndex -like '*cpu') { Warn 'No hay GPU NVIDIA: se instalará PyTorch solo para CPU.' }

# --- 3. Entorno de Python --------------------------------------------------------
Step 'Creando el entorno de Python (backend\.venv)'
if (-not (Test-Path $VenvPython)) {
    Invoke-Checked $PythonCmd[0] @($PythonCmd | Select-Object -Skip 1) -m venv $Venv
} else { Ok 'Ya existe, se reutiliza.' }

Step 'Instalando PyTorch (puede tardar varios minutos, ~3 GB con CUDA)'
Invoke-Checked $VenvPython -m pip install --upgrade pip --quiet
Invoke-Checked $VenvPython -m pip install torch torchvision --index-url $TorchIndex

Step 'Instalando ultralytics, FastAPI, OpenCV y pyrealsense2'
Invoke-Checked $VenvPython -m pip install -r (Join-Path $Backend 'requirements.txt')

Step 'Verificando la instalación'
Invoke-Checked $VenvPython -c "import torch, ultralytics, cv2, fastapi, pyrealsense2; print('    torch', torch.__version__, '| CUDA:', torch.cuda.is_available())"

# --- 4. Pesos de los modelos (para poder dar clase sin internet) -------------------
Step 'Descargando los modelos YOLOv8 nano (detección, segmentación y pose)'
Push-Location $Backend
try {
    Invoke-Checked $VenvPython -c "from ultralytics import YOLO; [YOLO(f'models/yolov8n{s}.pt') for s in ('', '-seg', '-pose')]"
} finally { Pop-Location }
Ok 'Los tamaños Small y Medium se descargan la primera vez que se usan.'

# --- 5. App Flutter ------------------------------------------------------------------
Step 'Preparando la app de escritorio'
if (Test-Path $ReleaseExe) {
    Ok 'La app ya está compilada.'
} elseif ($NoBuild) {
    Warn 'Se omitió la compilación (-NoBuild).'
} elseif (Get-Command flutter -ErrorAction SilentlyContinue) {
    Push-Location (Join-Path $Root 'app')
    try {
        Invoke-Checked flutter pub get
        Invoke-Checked flutter build windows --release
    } finally { Pop-Location }
    Ok 'App compilada.'
} else {
    Warn 'Flutter no está instalado en esta computadora.'
    Warn 'Compila en otra PC con "flutter build windows --release" y copia la carpeta completa'
    Warn "app\build\windows\x64\runner\Release\ a la misma ruta de este proyecto. Luego vuelve a ejecutar este instalador."
}

# --- 6. Acceso directo ------------------------------------------------------------
if ((Test-Path $ReleaseExe) -and -not $NoShortcut) {
    Step 'Creando el acceso directo en el escritorio'
    $lnk = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Visión Interactiva.lnk'
    $shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk)
    $shortcut.TargetPath = $ReleaseExe
    $shortcut.WorkingDirectory = Split-Path $ReleaseExe
    $shortcut.Save()
    Ok $lnk
}

# --- 7. RealSense -------------------------------------------------------------------
Step 'Cámara Intel RealSense'
$devices = & $VenvPython -c "import pyrealsense2 as rs; print(len(rs.context().query_devices()))" 2>$null
if ($devices -gt 0) { Ok "$devices cámara(s) RealSense conectada(s)." }
else { Warn 'No hay RealSense conectada (puedes usar webcam o video). Para la D457 instala el Intel RealSense SDK 2.0 y conéctala por USB-C 3.x.' }

Write-Host "`nInstalación terminada." -ForegroundColor Green
