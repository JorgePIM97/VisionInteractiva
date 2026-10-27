"""Dibujo del centro del bounding box y su distancia."""
from __future__ import annotations

import cv2
import numpy as np

CENTER_COLOR = (0, 255, 255)


def draw_center(img: np.ndarray, cx: int, cy: int, depth_m: float | None, show_depth: bool) -> None:
    cv2.drawMarker(img, (cx, cy), CENTER_COLOR, cv2.MARKER_CROSS, 18, 2)
    cv2.circle(img, (cx, cy), 4, CENTER_COLOR, -1)
    if not show_depth:
        return
    text = f"{depth_m:.2f} m" if depth_m is not None else "sin dato"
    (tw, th), _ = cv2.getTextSize(text, cv2.FONT_HERSHEY_SIMPLEX, 0.6, 2)
    x, y = cx + 8, cy - 8
    cv2.rectangle(img, (x - 2, y - th - 4), (x + tw + 2, y + 4), (0, 0, 0), -1)
    cv2.putText(img, text, (x, y), cv2.FONT_HERSHEY_SIMPLEX, 0.6, CENTER_COLOR, 2, cv2.LINE_AA)
