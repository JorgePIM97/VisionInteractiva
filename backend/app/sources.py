"""Fuentes de video: Intel RealSense (color + profundidad), webcam y archivo de video."""
from __future__ import annotations

import time
from dataclasses import dataclass
from typing import Any

import cv2
import numpy as np

try:
    import pyrealsense2 as rs
except ImportError:  # el backend funciona sin RealSense
    rs = None


@dataclass
class DepthData:
    image: np.ndarray  # uint16, alineada al frame de color
    scale: float       # metros por unidad
    intrinsics: Any    # rs.intrinsics del stream de color


class FrameSource:
    has_depth = False

    def read(self) -> tuple[np.ndarray | None, DepthData | None]:
        raise NotImplementedError

    def close(self) -> None:
        pass


class WebcamSource(FrameSource):
    def __init__(self, index: int):
        self.cap = cv2.VideoCapture(index, cv2.CAP_DSHOW)
        if not self.cap.isOpened():
            raise RuntimeError(f"No se pudo abrir la webcam {index}")
        self.cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1280)
        self.cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)

    def read(self):
        ok, frame = self.cap.read()
        return (frame if ok else None), None

    def close(self):
        self.cap.release()


class VideoFileSource(FrameSource):
    """Reproduce un video en bucle respetando su velocidad original."""

    def __init__(self, path: str):
        self.cap = cv2.VideoCapture(path)
        if not self.cap.isOpened():
            raise RuntimeError(f"No se pudo abrir el video {path}")
        fps = self.cap.get(cv2.CAP_PROP_FPS) or 30
        self.period = 1.0 / fps
        self.last = 0.0

    def read(self):
        wait = self.period - (time.perf_counter() - self.last)
        if wait > 0:
            time.sleep(wait)
        self.last = time.perf_counter()
        ok, frame = self.cap.read()
        if not ok:
            self.cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
            ok, frame = self.cap.read()
        return (frame if ok else None), None

    def close(self):
        self.cap.release()


class RealSenseSource(FrameSource):
    has_depth = True

    def __init__(self, serial: str = "", width: int = 640, height: int = 480, fps: int = 30):
        if rs is None:
            raise RuntimeError("pyrealsense2 no está instalado")
        self.pipeline = rs.pipeline()
        config = rs.config()
        if serial:
            config.enable_device(serial)
        config.enable_stream(rs.stream.color, width, height, rs.format.bgr8, fps)
        config.enable_stream(rs.stream.depth, width, height, rs.format.z16, fps)
        profile = self.pipeline.start(config)
        self.scale = profile.get_device().first_depth_sensor().get_depth_scale()
        # Alinear la profundidad al color para que el pixel (cx, cy) coincida
        self.align = rs.align(rs.stream.color)

    def read(self):
        frames = self.align.process(self.pipeline.wait_for_frames(5000))
        color = frames.get_color_frame()
        depth = frames.get_depth_frame()
        if not color or not depth:
            return None, None
        intrinsics = color.profile.as_video_stream_profile().intrinsics
        return (
            np.asanyarray(color.get_data()).copy(),
            DepthData(np.asanyarray(depth.get_data()).copy(), self.scale, intrinsics),
        )

    def close(self):
        self.pipeline.stop()


def make_source(spec: dict) -> FrameSource:
    kind, ident = spec["type"], spec.get("id", "")
    if kind == "realsense":
        return RealSenseSource(ident)
    if kind == "webcam":
        return WebcamSource(int(ident or 0))
    if kind == "video":
        return VideoFileSource(ident)
    raise ValueError(f"Fuente desconocida: {kind}")


def list_realsense() -> list[dict]:
    if rs is None:
        return []
    devices = []
    for dev in rs.context().query_devices():
        devices.append({
            "type": "realsense",
            "id": dev.get_info(rs.camera_info.serial_number),
            "name": dev.get_info(rs.camera_info.name),
        })
    return devices


def list_webcams(max_index: int = 4) -> list[dict]:
    cams = []
    for i in range(max_index):
        cap = cv2.VideoCapture(i, cv2.CAP_DSHOW)
        if cap.isOpened():
            cams.append({"type": "webcam", "id": str(i), "name": f"Webcam {i}"})
        cap.release()
    return cams
