"""Cosmica Binary Stars In-App Event media (CHALLENGE, Jan 15 - Feb 14 2027, a Valentine twin-star trail).

Same specs and layout rules as cosmica_event_art_solstice.py (card 16:9, details 9:16, rendered at 2x,
no headline, dark bottom for Apple's overlay). The idea: two stars, rose and blue, locked in one
orbit, with five twin-star waypoints (the five goals) leading to them.

Writes full-res PNGs to P:\\digital products\\Cosmica In-App Event Binary Stars, upload copies next to
event-binary/event.json, and previews.
"""
import math, os, random
import numpy as np
from PIL import Image, ImageDraw

from cosmica_store_art import add_light, background, finish, sparkle, stars

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = r"P:\digital products\Cosmica In-App Event Binary Stars"
SPEC_DIR = os.path.join(HERE, "event-binary")
ROSE = np.array([255, 120, 185], np.float32)
BLUE = np.array([120, 175, 255], np.float32)


def warm(base):
    """Nudge the purple night toward rose at the top, deep indigo below."""
    H = base.shape[0]
    y = np.linspace(0, 1, H, dtype=np.float32)[:, None, None]
    tint = np.array([40, 8, 34], np.float32) * (1 - y) + np.array([6, 4, 22], np.float32) * y
    base[:] = base * 0.7 + tint * 0.8


def star(base, cx, cy, R, col, strength=1.0):
    H, W = base.shape[:2]
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / R
    base += np.exp(-d ** 2 * 0.5)[:, :, None] * col * 0.45 * strength
    base += np.exp(-d ** 2 * 4)[:, :, None] * col * 0.9 * strength
    base += np.exp(-d ** 2 * 18)[:, :, None] * np.array([255, 245, 250], np.float32) * 1.1 * strength


def orbit(base, cx, cy, rx, ry, rot, width):
    """The shared orbit: an ellipse of light, rose on one side and blue on the other."""
    H, W = base.shape[:2]
    for col, a0, a1 in (((255, 150, 200), 0, math.pi), ((150, 195, 255), math.pi, math.tau)):
        layer = Image.new("RGB", (W, H))
        d = ImageDraw.Draw(layer)
        pts = []
        for i in range(181):
            a = a0 + (a1 - a0) * i / 180
            x, y = rx * math.cos(a), ry * math.sin(a)
            pts.append((cx + x * math.cos(rot) - y * math.sin(rot), cy + x * math.sin(rot) + y * math.cos(rot)))
        d.line(pts, fill=col, width=width)
        add_light(base, layer, ((0, 0.8), (width * 2, 0.9), (width * 8, 0.5)))
    return lambda a: (cx + rx * math.cos(a) * math.cos(rot) - ry * math.sin(a) * math.sin(rot),
                      cy + rx * math.cos(a) * math.sin(rot) + ry * math.sin(a) * math.cos(rot))


def twin(base, x, y, r, k):
    """A small binary pair: rose and blue dots side by side, with a sparkle."""
    H, W = base.shape[:2]
    layer = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(layer)
    for dx, col in ((-r * 0.7, (255, 140, 200)), (r * 0.7, (140, 190, 255))):
        d.ellipse([x + dx - r * 0.55, y - r * 0.55, x + dx + r * 0.55, y + r * 0.55], fill=col)
    sparkle(d, x, y, r * 1.1, (255, 240, 250))
    add_light(base, layer, ((0, 0.9 * k), (int(r / 3), 1.0 * k), (int(r), 0.6 * k)))


def trail(base, pts, sizes):
    H, W = base.shape[:2]
    path = Image.new("RGB", (W, H))
    pd = ImageDraw.Draw(path)
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        for i in range(1, 14):
            t = i / 14
            x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            r = 5 + 3 * t
            pd.ellipse([x - r, y - r, x + r, y + r], fill=(235, 170, 230))
    add_light(base, path, ((0, 0.7), (10, 0.8)))
    for i, ((x, y), r) in enumerate(zip(pts, sizes)):
        twin(base, x, y, r, 0.65 + 0.35 * i / (len(pts) - 1))


def bottom_fade(base, start, strength):
    H = base.shape[0]
    y = np.linspace(0, 1, H, dtype=np.float32)
    k = np.clip((y - start) / (1 - start), 0, 1) ** 1.4 * strength
    base *= (1 - k)[:, None, None]


def card(path):
    W, H = 3840, 2160
    base = background(W, H, 81)
    warm(base)
    add_light(base, stars(W, H, 1300, 41, big=16, avoid=(400, 300, 3500, 1700)), ((0, 0.9), (3, 0.5)))
    cx, cy = W * 0.745, H * 0.34
    at = orbit(base, cx, cy, H * 0.27, H * 0.11, -0.32, 10)
    for a, col in ((0.35, ROSE), (0.35 + math.pi, BLUE)):
        x, y = at(a)
        star(base, x, y, H * 0.065, col)
    pts = [(W * 0.13, H * 0.70), (W * 0.24, H * 0.57), (W * 0.35, H * 0.63), (W * 0.43, H * 0.50), (W * 0.505, H * 0.44)]
    trail(base, pts, (34, 40, 46, 52, 60))
    bottom_fade(base, 0.72, 0.85)
    return finish(base, path)


def details(path):
    W, H = 2160, 3840
    base = background(W, H, 83)
    warm(base)
    add_light(base, stars(W, H, 1400, 43, big=18, avoid=(150, 300, 2010, 2900)), ((0, 0.9), (3, 0.5)))
    cx, cy = W * 0.5, H * 0.24
    at = orbit(base, cx, cy, W * 0.36, W * 0.15, -0.30, 10)
    for a, col in ((0.4, ROSE), (0.4 + math.pi, BLUE)):
        x, y = at(a)
        star(base, x, y, W * 0.085, col)
    pts = [(W * 0.30, H * 0.71), (W * 0.66, H * 0.645), (W * 0.36, H * 0.575), (W * 0.62, H * 0.505), (W * 0.5, H * 0.43)]
    trail(base, pts, (38, 44, 50, 56, 62))
    bottom_fade(base, 0.70, 0.88)
    return finish(base, path)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(SPEC_DIR, exist_ok=True)
    prev = os.path.join(HERE, "previews")
    os.makedirs(prev, exist_ok=True)
    jobs = ((card, "event-card-16x9.png", "binary_card_1920x1080.png", (1920, 1080)),
            (details, "event-details-9x16.png", "binary_details_1080x1920.png", (1080, 1920)))
    for fn, full, upload, size in jobs:
        im = fn(os.path.join(OUT, full))
        im.resize(size, Image.LANCZOS).save(os.path.join(SPEC_DIR, upload), optimize=True)
        im.resize((im.width // 3, im.height // 3)).save(
            os.path.join(prev, "binary-" + full.replace(".png", ".jpg")), quality=85)
    print("done")
