"""Carga de modelos YOLOv8 e inferencia en CUDA o CPU."""
from __future__ import annotations

import threading
from pathlib import Path

import numpy as np
import torch
from ultralytics import YOLO

MODEL_FILES = {
    "detect": "yolov8{size}.pt",
    "segment": "yolov8{size}-seg.pt",
    "pose": "yolov8{size}-pose.pt",
}


def cuda_info() -> dict:
    available = torch.cuda.is_available()
    return {
        "cuda": available,
        "gpu": torch.cuda.get_device_name(0) if available else None,
        "torch": torch.__version__,
        "default": "cuda" if available else "cpu",
    }


class Engine:
    def __init__(self, models_dir: Path):
        self.models_dir = models_dir
        self.models_dir.mkdir(parents=True, exist_ok=True)
        self._models: dict[tuple[str, str, str], YOLO] = {}
        self._lock = threading.Lock()

    def get(self, task: str, size: str, device: str) -> YOLO:
        # Un modelo por dispositivo: el predictor de ultralytics fija el
        # dispositivo en la primera inferencia y no se puede cambiar después.
        key = (task, size, device)
        with self._lock:
            model = self._models.get(key)
            if model is None:
                weights = self.models_dir / MODEL_FILES[task].format(size=size)
                model = YOLO(str(weights))  # se descarga la primera vez
                self._models[key] = model
            return model

    def is_loaded(self, task: str, size: str, device: str) -> bool:
        return (task, size, device) in self._models

    def names(self, task: str, size: str) -> dict[int, str]:
        return self.get(task, size, "cpu").names

    def predict(self, frame: np.ndarray, task: str, size: str, device: str,
                conf: float, classes: tuple[int, ...] | None):
        model = self.get(task, size, device)
        use_cuda = device == "cuda" and torch.cuda.is_available()
        results = model.predict(
            frame,
            conf=conf,
            classes=None if task == "pose" or classes is None else list(classes),
            device="cuda:0" if use_cuda else "cpu",
            half=use_cuda,
            verbose=False,
        )
        return results[0]
