"""Profundidad en el centro del bounding box y coordenadas 3D."""
from __future__ import annotations

import numpy as np

from .sources import DepthData, rs


def depth_at(depth: DepthData, cx: int, cy: int, win: int = 5) -> float | None:
    """Mediana (en metros) de una ventana win x win alrededor de (cx, cy), ignorando huecos (0)."""
    h, w = depth.image.shape
    r = win // 2
    patch = depth.image[max(cy - r, 0):min(cy + r + 1, h), max(cx - r, 0):min(cx + r + 1, w)]
    valid = patch[patch > 0]
    if valid.size == 0:
        return None
    return float(np.median(valid)) * depth.scale


def deproject(depth: DepthData, cx: int, cy: int, z: float) -> list[float] | None:
    """Pixel + profundidad -> punto (X, Y, Z) en metros respecto a la cámara."""
    if rs is None:
        return None
    return [float(v) for v in rs.rs2_deproject_pixel_to_point(depth.intrinsics, [cx, cy], z)]
