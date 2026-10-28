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

1. Instala **Python 3.11** desde python.org, marcando "Add python.exe to PATH". Si la computadora tiene
   tarjeta NVIDIA, instala también su **driver**.
2. Para la D457, instala el **Intel RealSense SDK 2.0** (incluye `realsense-viewer`). Conecta la cámara por
   **USB‑C 3.x** y verifica en `realsense-viewer` que se ven el color y la profundidad.
3. `git clone` del repositorio.
4. Doble clic en **`instalar.bat`**. El instalador:
   - detecta la GPU e instala PyTorch con CUDA, o la versión para CPU si no hay GPU;
   - instala las dependencias y descarga los modelos nano para poder trabajar sin internet;
   - compila la app si la computadora tiene Flutter;
   - crea un acceso directo en el escritorio.

   Se puede volver a ejecutar sin problema, por ejemplo después de un `git pull`.

**Computadora sin Flutter:** compila en otra PC con `flutter build windows --release` y copia la carpeta
**completa** `app\build\windows\x64\runner\Release\` a la misma ruta de este proyecto. Después vuelve a
ejecutar `instalar.bat` para que cree el acceso directo.

Los modelos Small y Medium se descargan la primera vez que se usan (a `backend\models\`).

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
