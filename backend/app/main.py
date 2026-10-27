"""API de VisionInteractiva: configuración por REST y video por WebSocket.

Ejecutar desde la carpeta backend:
    .venv\\Scripts\\python -m uvicorn app.main:app --port 8000
"""
from __future__ import annotations

import asyncio
from pathlib import Path

from fastapi import Body, FastAPI, HTTPException, WebSocket, WebSocketDisconnect

from .engine import Engine, cuda_info
from .recorder import Recorder
from .sources import list_realsense, list_webcams
from .state import SIZES, TASKS, State, config_to_dict
from .stream import StreamWorker

BASE_DIR = Path(__file__).resolve().parent.parent

state = State(default_device=cuda_info()["default"])
engine = Engine(BASE_DIR / "models")
recorder = Recorder(BASE_DIR / "logs")
worker = StreamWorker(state, engine, recorder)

app = FastAPI(title="VisionInteractiva")


@app.get("/health")
def health():
    return {"ok": True, "streaming": worker.running}


@app.get("/devices")
def devices():
    return cuda_info()


@app.get("/models")
def models():
    return {"tasks": list(TASKS), "sizes": list(SIZES)}


@app.get("/classes")
def classes(task: str = "detect", size: str = "n"):
    if task not in TASKS or size not in SIZES:
        raise HTTPException(400, "task o size inválido")
    names = engine.names(task, size)
    return [{"id": int(k), "name": v} for k, v in sorted(names.items())]


@app.get("/sources")
def sources():
    found = list_realsense()
    # La RealSense también aparece como webcam UVC; se listan igual por si se quiere usar así.
    webcams = list_webcams()
    current = worker.current_source
    if current and current["type"] == "webcam" and not any(w["id"] == current["id"] for w in webcams):
        webcams.append({"type": "webcam", "id": current["id"], "name": f"Webcam {current['id']} (en uso)"})
    return found + webcams


@app.get("/config")
def get_config():
    return config_to_dict(state.get())


@app.post("/config")
def set_config(changes: dict = Body(...)):
    try:
        return config_to_dict(state.update(changes))
    except ValueError as e:
        raise HTTPException(400, str(e)) from e


@app.get("/logging/status")
def logging_status():
    return recorder.status()


@app.post("/logging/start")
def logging_start():
    recorder.start()
    return recorder.status()


@app.post("/logging/stop")
def logging_stop():
    recorder.stop()
    return recorder.status()


@app.post("/snapshot")
def snapshot():
    image = worker.last_image
    if image is None:
        raise HTTPException(409, "No hay ningún frame todavía")
    return {"path": str(recorder.snapshot(image).resolve())}


@app.get("/logs")
def logs():
    return {"logs_dir": str(recorder.logs_dir.resolve()), "sessions": recorder.sessions()}


@app.websocket("/ws/stream")
async def ws_stream(websocket: WebSocket):
    """Por cada frame envía un mensaje de texto (JSON) seguido de uno binario (JPEG).
    Los mensajes de estado (type=status) no llevan imagen."""
    await websocket.accept()
    worker.add_client()
    seq = 0
    try:
        while True:
            item = await asyncio.to_thread(worker.wait_frame, seq, 1.0)
            if item is None:
                continue
            seq, meta, jpeg = item
            await websocket.send_text(meta)
            if jpeg is not None:
                await websocket.send_bytes(jpeg)
    except (WebSocketDisconnect, RuntimeError):
        pass
    finally:
        worker.remove_client()
