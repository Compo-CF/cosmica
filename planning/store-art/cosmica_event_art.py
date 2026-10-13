"""Cosmica 3.1 In-App Event media ("Major Update": Reach True Cosmos).

Specs (App Store Connect, in-app event media): event card 16:9 landscape,
1920x1080 to 3840x2160; event details page 9:16 portrait, 1080x1920 to
2160x3840. PNG/JPEG. Apple lays the badge, event name and short description
over the media, so the art carries no headline of its own: the idea (the
climb from 1 to Absolute, ending in a golden collapse) sits in the centre and
upper area, and the bottom stays dark enough for Apple's text. The card is
trimmed a little at the sides; the bottom ~27% of the details page is
covered, so nothing important goes there.
"""
import math, os
import numpy as np
from PIL import Image, ImageDraw, ImageFont

from cosmica_store_art import (BLACK, GOLD, add_light, background, finish, galaxy,
                               glow_text, lerpc, sparkle, stars)

OUT = r"P:\digital products\Cosmica In-App Event 3.1"
os.makedirs(OUT, exist_ok=True)

STEPS = ["1", "1K", "1M", "1B", "1T", "1Qa", "1Sx", "1Dc", "1Ud"]


def golden_core(W, H, cx, cy, R, strength=1.0):
    """True Cosmos: the universe collapsing into a gold point."""
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / R
    light = np.exp(-d ** 2 * 1.6)[:, :, None] * np.array([255, 150, 40], np.float32) * 0.75
    light += np.exp(-d ** 2 * 9)[:, :, None] * np.array([255, 190, 90], np.float32) * 0.8
    light += np.exp(-d ** 2 * 70)[:, :, None] * np.array([255, 240, 205], np.float32) * 0.9
    # thin gold ring: the event horizon of the collapse
    ring = np.exp(-((d - 0.62) / 0.025) ** 2)[:, :, None] * np.array([255, 200, 110], np.float32) * 0.55
    return (light + ring) * strength


def ladder(base, pts, size0, size1, sparkle_gap=True):
    """Tier numbers along a path, cool lavender at 1 to gold at 1Ud."""
    W, H = base.shape[1], base.shape[0]
    n = len(STEPS) - 1
    sizes = [size0 + (size1 - size0) * i / n for i in range(n + 1)]
    gaps = [sizes[i] + sizes[i + 1] for i in range(n)]
    u = [sum(gaps[:i]) / sum(gaps) for i in range(n + 1)]
    for i, s in enumerate(STEPS):
        t = i / n
        x, y = pts(u[i])
        f = ImageFont.truetype(BLACK, int(size0 + (size1 - size0) * t))
        col = tuple(int(c) for c in lerpc((215, 195, 255), GOLD, t))
        glow_text(base, (x, y), s, f, fill=col, glow=col, radius=10 + 14 * t,
                  strength=0.5 + 0.8 * t, anchor="mm", shadow=0.7)
        if sparkle_gap and i < n:
            mx, my = pts((u[i] + u[i + 1]) / 2)
            d = Image.new("RGB", (W, H))
            sparkle(ImageDraw.Draw(d), mx, my, size0 * 0.16 + 10 * t, (255, 235, 200))
            add_light(base, d, ((0, 1.0), (6, 0.8)))


def bottom_fade(base, start, strength=0.75):
    """Darken the bottom so Apple's overlaid event text stays readable."""
    H = base.shape[0]
    y = np.linspace(0, 1, H, dtype=np.float32)
    k = np.clip((y - start) / (1 - start), 0, 1) ** 1.4 * strength
    base *= (1 - k)[:, None, None]
    return base


def card(path):
    W, H = 3840, 2160
    base = background(W, H, 41)
    add_light(base, stars(W, H, 1200, 13, big=20, avoid=(500, 300, 3340, 1500)), ((0, 1.0), (3, 0.6)))
    cx, cy = W * 0.66, H * 0.40
    base += galaxy(W, H, cx, cy, 1250, tilt=0.42, rot=-0.22, seed=27, core=0.15) * 0.42
    base += golden_core(W, H, cx, cy, 430)
    # the climb rises from the lower left and ends just short of the gold core;
    # a soft veil keeps the numbers off the busy arms
    x0, y0, x1, y1 = W * 0.10, H * 0.66, W * 0.50, H * 0.30

    def path_(t):
        return x0 + (x1 - x0) * t, y0 + (y1 - y0) * (t ** 1.25)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    for t in np.linspace(0, 1, 24):
        px, py = path_(t)
        base *= (1 - 0.18 * np.exp(-(((xx - px) / 260) ** 2 + ((yy - py) / 160) ** 2)))[:, :, None]
    ladder(base, path_, 92, 175)
    bottom_fade(base, 0.72, 0.8)
    return finish(base, path)


def details(path):
    W, H = 2160, 3840
    base = background(W, H, 43)
    add_light(base, stars(W, H, 1300, 17, big=22, avoid=(200, 300, 1960, 2700)), ((0, 1.0), (3, 0.6)))
    cx, cy = W * 0.5, H * 0.24
    base += galaxy(W, H, cx, cy, 1000, tilt=0.55, rot=-0.30, seed=29, core=0.15) * 0.45
    base += golden_core(W, H, cx, cy, 330)
    # the climb runs up the page toward the collapse, smallest at the bottom
    yb, yt = H * 0.70, H * 0.415

    def path_(t):
        return W * 0.5 + math.sin(t * math.pi * 2) * W * 0.16 * (1 - t), yb + (yt - yb) * t
    ladder(base, path_, 96, 190)
    bottom_fade(base, 0.70, 0.85)
    return finish(base, path)


if __name__ == "__main__":
    card(os.path.join(OUT, "event-card-16x9.png"))
    details(os.path.join(OUT, "event-details-9x16.png"))
    prev = os.path.join(os.path.dirname(os.path.abspath(__file__)), "previews")
    os.makedirs(prev, exist_ok=True)
    for name in ("event-card-16x9.png", "event-details-9x16.png"):
        im = Image.open(os.path.join(OUT, name))
        im.resize((im.width // 3, im.height // 3)).save(os.path.join(prev, name.replace(".png", ".jpg")), quality=85)
    print("done")
