"""Hilo de streaming: lee la fuente, infiere, anota y publica el último frame."""
from __future__ import annotations

import json
import threading
import time

import cv2
import numpy as np
import torch

from .annotate import draw_center
from .depth import deproject, depth_at
from .engine import MODEL_FILES, Engine
from .recorder import Recorder
from .sources import DepthData, FrameSource, make_source
from .state import Config, State


def extract_detections(result, cfg: Config, depth: DepthData | None, image: np.ndarray) -> list[dict]:
    boxes = result.boxes
    if boxes is None or len(boxes) == 0:
        return []
    xyxy = boxes.xyxy.cpu().numpy()
    confs = boxes.conf.cpu().numpy()
    clss = boxes.cls.cpu().numpy().astype(int)
    kpts = None
    if cfg.task == "pose" and result.keypoints is not None:
        kpts = result.keypoints.data.cpu().numpy()
    h, w = image.shape[:2]
    measure = depth is not None and cfg.measure_depth

    detections = []
    for i in range(len(xyxy)):
        x1, y1, x2, y2 = (float(v) for v in xyxy[i])
        det = {
            "cls": int(clss[i]),
            "name": result.names[int(clss[i])],
            "conf": float(confs[i]),
            "bbox": [round(x1, 1), round(y1, 1), round(x2, 1), round(y2, 1)],
        }
        if cfg.task != "pose":
            cx = min(max(int(round((x1 + x2) / 2)), 0), w - 1)
            cy = min(max(int(round((y1 + y2) / 2)), 0), h - 1)
            det["center"] = [cx, cy]
            if measure:
                z = depth_at(depth, cx, cy)
                det["depth_m"] = z
                det["xyz"] = deproject(depth, cx, cy, z) if z else None
            if cfg.show_center:
                draw_center(image, cx, cy, det.get("depth_m"), measure)
        if kpts is not None:
            det["keypoints"] = [[round(float(x), 1), round(float(y), 1), round(float(c), 2)]
                                for x, y, c in kpts[i]]
        detections.append(det)
    return detections


class StreamWorker:
    """Corre mientras haya al menos un cliente WebSocket conectado."""

    def __init__(self, state: State, engine: Engine, recorder: Recorder):
        self.state = state
        self.engine = engine
        self.recorder = recorder
        self._lock = threading.Lock()
        self._cond = threading.Condition()
        self._clients = 0
        self._thread: threading.Thread | None = None
        self._last_thread: threading.Thread | None = None
        self._seq = 0
        self._latest: tuple[str, bytes | None] | None = None
        self.last_image: np.ndarray | None = None
        self.current_source: dict | None = None

    # --- clientes ---------------------------------------------------------
    def add_client(self) -> None:
        with self._lock:
            self._clients += 1
            if self._thread is None:
                # El hilo anterior puede seguir liberando la cámara: el nuevo lo espera
                self._thread = threading.Thread(target=self._run, args=(self._last_thread,), daemon=True)
                self._last_thread = self._thread
                self._thread.start()

    def remove_client(self) -> None:
        with self._lock:
            self._clients = max(self._clients - 1, 0)

    @property
    def running(self) -> bool:
        return self._thread is not None

    def wait_frame(self, last_seq: int, timeout: float):
        with self._cond:
            if self._seq == last_seq:
                self._cond.wait(timeout)
            if self._seq == last_seq or self._latest is None:
                return None
            return (self._seq, *self._latest)

    def _publish(self, meta: dict, jpeg: bytes | None) -> None:
        with self._cond:
            self._seq += 1
            self._latest = (json.dumps(meta), jpeg)
            self._cond.notify_all()

    def _status(self, message: str, error: bool = False) -> None:
        self._publish({"type": "status", "message": message, "error": error}, None)

    # --- bucle principal --------------------------------------------------
    def _run(self, previous: threading.Thread | None) -> None:
        if previous is not None:
            previous.join(timeout=10)

        source: FrameSource | None = None
        spec = None
        frame_idx = 0
        fps = 0.0
        t_prev = time.perf_counter()
        try:
            while True:
                with self._lock:
                    if self._clients == 0:
                        self._thread = None
                        break
                cfg = self.state.get()

                if source is None or cfg.source != spec:
                    if source:
                        source.close()
                        source = None
                    spec = cfg.source
                    self._status(f"Abriendo fuente {spec['type']} {spec['id']}...")
                    try:
                        source = make_source(spec)
                        self.current_source = spec
                    except Exception as e:  # noqa: BLE001
                        self._status(f"Error al abrir la fuente: {e}", error=True)
                        time.sleep(1)
                        continue

                try:
                    frame, depth = source.read()
                except Exception as e:  # noqa: BLE001
                    frame, depth = None, None
                    self._status(f"Error leyendo la fuente: {e}", error=True)
                if frame is None:
                    source.close()
                    source = None
                    time.sleep(0.5)
                    continue

                use_cuda = cfg.device == "cuda" and torch.cuda.is_available()
                device = "cuda" if use_cuda else "cpu"
                model_name = MODEL_FILES[cfg.task].format(size=cfg.size).removesuffix(".pt")

                infer_ms = 0.0
                if cfg.task != "pose" and cfg.classes is not None and len(cfg.classes) == 0:
                    # Ninguna clase seleccionada: no hay nada que detectar
                    image, detections = frame, []
                else:
                    if not self.engine.is_loaded(cfg.task, cfg.size, device):
                        self._status(f"Cargando {model_name} en {device.upper()}...")
                    try:
                        t0 = time.perf_counter()
                        result = self.engine.predict(frame, cfg.task, cfg.size, device, cfg.conf, cfg.classes)
                        infer_ms = (time.perf_counter() - t0) * 1000
                    except Exception as e:  # noqa: BLE001
                        self._status(f"Error en la inferencia: {e}", error=True)
                        time.sleep(1)
                        continue
                    image = result.plot()
                    detections = extract_detections(result, cfg, depth, image)

                now = time.perf_counter()
                dt = now - t_prev
                t_prev = now
                fps = (1 / dt) if fps == 0 else fps * 0.9 + (1 / dt) * 0.1
                frame_idx += 1

                meta = {
                    "type": "frame",
                    "frame": frame_idx,
                    "fps": round(fps, 1),
                    "infer_ms": round(infer_ms, 1),
                    "device": device,
                    "task": cfg.task,
                    "model": model_name,
                    "source": f"{spec['type']}:{spec['id']}",
                    "has_depth": depth is not None,
                    "width": image.shape[1],
                    "height": image.shape[0],
                    "detections": detections,
                }
                self.last_image = image
                self.recorder.maybe_log(frame_idx, meta, image, cfg.log_interval, cfg.log_snapshots)
                meta["logging"] = self.recorder.status()

                ok, jpeg = cv2.imencode(".jpg", image, [cv2.IMWRITE_JPEG_QUALITY, 80])
                self._publish(meta, jpeg.tobytes() if ok else None)
        finally:
            if source:
                source.close()
            self.current_source = None
