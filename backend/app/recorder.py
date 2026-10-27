"""Registro de detecciones en CSV por sesión, con capturas opcionales."""
from __future__ import annotations

import csv
import json
import threading
import time
from datetime import datetime
from pathlib import Path

import cv2
import numpy as np

COLUMNS = [
    "timestamp", "frame", "task", "model", "device", "source",
    "class_id", "class_name", "confidence", "x1", "y1", "x2", "y2",
    "cx", "cy", "depth_m", "X", "Y", "Z", "keypoints_json",
]


def _fmt(value, digits=3):
    return "" if value is None else round(value, digits)


class Recorder:
    def __init__(self, logs_dir: Path):
        self.logs_dir = logs_dir
        self.logs_dir.mkdir(parents=True, exist_ok=True)
        self._lock = threading.Lock()
        self._file = None
        self._writer = None
        self.session_dir: Path | None = None
        self.rows = 0
        self._last_log = 0.0

    @property
    def active(self) -> bool:
        return self._writer is not None

    def start(self) -> Path:
        with self._lock:
            self._close()
            self.session_dir = self.logs_dir / datetime.now().strftime("session_%Y%m%d_%H%M%S")
            (self.session_dir / "snapshots").mkdir(parents=True, exist_ok=True)
            # utf-8-sig para que Excel muestre bien los acentos
            self._file = open(self.session_dir / "detections.csv", "w", newline="", encoding="utf-8-sig")
            self._writer = csv.writer(self._file)
            self._writer.writerow(COLUMNS)
            self.rows = 0
            self._last_log = 0.0
            return self.session_dir

    def stop(self) -> None:
        with self._lock:
            self._close()

    def _close(self) -> None:
        if self._file:
            self._file.close()
        self._file = self._writer = None

    def maybe_log(self, frame_idx: int, meta: dict, image: np.ndarray,
                  interval: float, save_snapshot: bool) -> None:
        with self._lock:
            if self._writer is None:
                return
            now = time.time()
            if now - self._last_log < interval:
                return
            self._last_log = now
            ts = datetime.fromtimestamp(now).isoformat(timespec="milliseconds")
            for det in meta["detections"]:
                x1, y1, x2, y2 = det["bbox"]
                center = det.get("center") or (None, None)
                xyz = det.get("xyz") or (None, None, None)
                kpts = det.get("keypoints")
                self._writer.writerow([
                    ts, frame_idx, meta["task"], meta["model"], meta["device"], meta["source"],
                    det["cls"], det["name"], _fmt(det["conf"]),
                    round(x1), round(y1), round(x2), round(y2),
                    center[0] if center[0] is not None else "", center[1] if center[1] is not None else "",
                    _fmt(det.get("depth_m")), _fmt(xyz[0]), _fmt(xyz[1]), _fmt(xyz[2]),
                    json.dumps(kpts) if kpts else "",
                ])
                self.rows += 1
            self._file.flush()
            if save_snapshot and meta["detections"]:
                name = f"frame_{frame_idx:06d}.jpg"
                cv2.imwrite(str(self.session_dir / "snapshots" / name), image)

    def snapshot(self, image: np.ndarray) -> Path:
        with self._lock:
            folder = (self.session_dir / "snapshots") if self.active else (self.logs_dir / "snapshots")
        folder.mkdir(parents=True, exist_ok=True)
        path = folder / datetime.now().strftime("captura_%Y%m%d_%H%M%S_%f.jpg")
        cv2.imwrite(str(path), image)
        return path

    def status(self) -> dict:
        return {
            "active": self.active,
            "session": str(self.session_dir) if self.session_dir else None,
            "rows": self.rows,
            "logs_dir": str(self.logs_dir.resolve()),
        }

    def sessions(self) -> list[dict]:
        out = []
        for d in sorted(self.logs_dir.glob("session_*"), reverse=True):
            csv_path = d / "detections.csv"
            out.append({
                "name": d.name,
                "path": str(d.resolve()),
                "size_kb": round(csv_path.stat().st_size / 1024, 1) if csv_path.exists() else 0,
            })
        return out
