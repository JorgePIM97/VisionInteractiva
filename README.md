# Visión Interactiva · YOLOv8

App de escritorio (Windows) para enseñar visión artificial a alumnos de preparatoria.
Permite probar los modelos YOLOv8 de **detección**, **segmentación** y **pose**, filtrar los
objetos del modelo pre-entrenado (COCO, 80 clases), medir la **distancia al centro** de cada
objeto con una **Intel RealSense D457**, guardar **registros CSV** y comparar la inferencia
en **GPU (CUDA)** contra **CPU**.

```
Flutter (app/)  ── REST: configuración ──►  Python FastAPI (backend/)
                ◄─ WebSocket: video+JSON ──   ultralytics · pyrealsense2 · OpenCV
```

## Instalación (una sola vez)

1. **Python 3.11** y el **driver NVIDIA** (para CUDA).
2. **Intel RealSense SDK 2.0** (incluye `realsense-viewer`). Conecta la D457 por **USB‑C 3.x**
   y verifica en `realsense-viewer` que se ven color y profundidad. Actualiza el firmware si lo pide.
3. Ejecuta `setup_backend.bat`: crea `backend\.venv`, instala PyTorch con CUDA y las dependencias.
4. Compila la app: `cd app` y luego `flutter build windows --release`.
   El ejecutable queda en `app\build\windows\x64\runner\Release\vision_interactiva.exe`.

La primera vez que se usa cada modelo, ultralytics descarga sus pesos (6–50 MB) a `backend\models\`.

## Uso

Abre la app y espera a que diga "Listo". La app arranca sola el servidor de Python. Si lo
prefieres, puedes iniciarlo a mano con `start_backend.bat`.

- **Tarea:** Detección, Segmentación o Pose.
- **Tamaño:** Nano, Small o Medium. Es un buen ejercicio comparar la velocidad contra la precisión.
- **Procesar con:** GPU (CUDA) o CPU. Observa los ms de inferencia en la esquina del video.
- **Fuente:** RealSense, webcam o un archivo de video.
- **Objetos a detectar:** deja "Detectar todo" activado, o desactívalo y elige las clases que quieras.
- **Centro y profundidad:** dibuja el centro del bounding box y, con la RealSense, la distancia en metros.
  La distancia es la mediana de una ventana de 5×5 píxeles alrededor del centro, ignorando los huecos sin dato.
  También se calculan las coordenadas 3D (X, Y, Z) respecto a la cámara.
- **Registro:** "Grabar registro" crea `backend\logs\session_FECHA\detections.csv`. Puedes elegir
  cada cuánto se guarda una fila y si también se guardan las fotos anotadas.

### Columnas del CSV
`timestamp, frame, task, model, device, source, class_id, class_name, confidence, x1, y1, x2, y2, cx, cy, depth_m, X, Y, Z, keypoints_json`

## API del backend (para prácticas avanzadas)

| Método | Ruta | Descripción |
|---|---|---|
| GET | `/devices` | CUDA disponible, nombre de la GPU |
| GET | `/classes?task=detect&size=n` | Clases del modelo |
| GET | `/sources` | RealSense y webcams detectadas |
| GET/POST | `/config` | Configuración actual / cambio parcial (`{"task":"segment","classes":[0,41]}`) |
| POST | `/logging/start`, `/logging/stop` | Inicia o detiene el CSV |
| POST | `/snapshot` | Guarda el frame actual |
| WS | `/ws/stream` | Por cada frame: un JSON con las detecciones y después un JPEG |

La documentación interactiva está en http://127.0.0.1:8000/docs mientras el servidor está corriendo.

## Notas
- La D457 también tiene conector GMSL/FAKRA (pensado para robots y Jetson). En Windows hay que usar el USB‑C.
- Si la RealSense no aparece en la lista, cierra `realsense-viewer`, porque solo un programa puede usarla a la vez.
