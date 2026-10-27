"""Configuración compartida entre la API y el hilo de streaming."""
from __future__ import annotations

import threading
from dataclasses import asdict, dataclass, field, replace

TASKS = ("detect", "segment", "pose")
SIZES = ("n", "s", "m")
DEVICES = ("cuda", "cpu")
SOURCE_TYPES = ("realsense", "webcam", "video")


@dataclass(frozen=True)
class Config:
    task: str = "detect"
    size: str = "n"
    # None = detectar todas las clases; lista = solo esos ids
    classes: tuple[int, ...] | None = None
    conf: float = 0.4
    device: str = "cpu"
    source: dict = field(default_factory=lambda: {"type": "webcam", "id": "0"})
    show_center: bool = True
    measure_depth: bool = True
    log_interval: float = 0.5
    log_snapshots: bool = False


class State:
    def __init__(self, default_device: str):
        self._lock = threading.Lock()
        self._config = Config(device=default_device)

    def get(self) -> Config:
        with self._lock:
            return self._config

    def update(self, changes: dict) -> Config:
        """Aplica cambios parciales validando cada campo."""
        clean = {}
        for key, value in changes.items():
            if key == "task":
                if value not in TASKS:
                    raise ValueError(f"task inválida: {value}")
            elif key == "size":
                if value not in SIZES:
                    raise ValueError(f"size inválido: {value}")
            elif key == "device":
                if value not in DEVICES:
                    raise ValueError(f"device inválido: {value}")
            elif key == "classes":
                value = None if value is None else tuple(int(c) for c in value)
            elif key == "conf":
                value = min(max(float(value), 0.01), 1.0)
            elif key == "log_interval":
                value = max(float(value), 0.0)
            elif key == "source":
                if not isinstance(value, dict) or value.get("type") not in SOURCE_TYPES:
                    raise ValueError(f"source inválida: {value}")
                value = {"type": value["type"], "id": str(value.get("id", ""))}
            elif key in ("show_center", "measure_depth", "log_snapshots"):
                value = bool(value)
            else:
                raise ValueError(f"campo desconocido: {key}")
            clean[key] = value
        with self._lock:
            self._config = replace(self._config, **clean)
            return self._config


def config_to_dict(cfg: Config) -> dict:
    data = asdict(cfg)
    data["classes"] = None if cfg.classes is None else list(cfg.classes)
    return data
