"""Cosmica Winter Solstice Trail In-App Event media (CHALLENGE, Dec 13 2026 - Jan 10 2027).

Same specs as the other event art: card 16:9 and details page 9:16, rendered at 2x and
saved at upload size (1920x1080 / 1080x1920). Apple lays the badge, name and short
description over the bottom, so there is no headline and the bottom stays dark.
The idea: the in-game trail itself. Five glowing snowflake waypoints (the five goals)
climb a frosted sky to the Frost orb, the event-only reward, under an aurora.

Writes full-res PNGs to P:\\digital products\\Cosmica In-App Event Solstice, upload copies
next to event-solstice/event.json, and previews.
"""
import math, os, random
import numpy as np
from PIL import Image, ImageDraw

from cosmica_store_art import add_light, background, finish, sparkle, stars

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = r"P:\digital products\Cosmica In-App Event Solstice"
SPEC_DIR = os.path.join(HERE, "event-solstice")
WHITE_ICE = (225, 245, 255)


def chill(base):
    """Pull Cosmica's purple night toward a cold blue winter sky."""
    H = base.shape[0]
    y = np.linspace(0, 1, H, dtype=np.float32)[:, None, None]
    cold = np.array([6, 16, 40], np.float32) * (1 - y) + np.array([4, 6, 18], np.float32) * y
    base[:] = base * 0.55 + cold * 0.9
    base[:, :, 2] *= 1.12


def aurora(base, y0, amp, seed, strength=1.0):
    """Two soft curtains of green-teal light across the top."""
    H, W = base.shape[:2]
    rng = random.Random(seed)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    for col, off, k in (((60, 230, 170), 0.0, 1.0), ((90, 170, 255), 0.07, 0.7)):
        ph = rng.uniform(0, math.tau)
        center = H * (y0 + off) + amp * H * np.sin(xx / W * math.tau * 1.3 + ph) * 0.5
        d = (yy - center) / (H * 0.05)
        band = np.exp(-d ** 2) * (yy < center + H * 0.02) + np.exp(-((yy - center) / (H * 0.16)) ** 2) * 0.35 * (yy < center)
        streak = 0.6 + 0.4 * np.sin(xx / W * 90 + ph) ** 2
        base += (band * streak)[:, :, None] * np.array(col, np.float32) * 0.42 * k * strength


def orb(base, cx, cy, R):
    """The Frost orb: ice-white core, blue rim, wide cold halo."""
    H, W = base.shape[:2]
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / R
    base += np.exp(-d ** 2 * 0.35)[:, :, None] * np.array([40, 110, 200], np.float32) * 0.55
    body = np.clip(1 - d, 0, 1)
    base += (body ** 0.5)[:, :, None] * np.array([120, 190, 245], np.float32) * 0.9
    base += np.exp(-d ** 2 * 6)[:, :, None] * np.array([235, 250, 255], np.float32) * 0.85
    rim = np.exp(-((d - 1) / 0.035) ** 2)
    base += rim[:, :, None] * np.array([170, 230, 255], np.float32) * 0.9


def snowflake(d, x, y, r, color, width):
    """Six arms with two pairs of side branches each."""
    for k in range(6):
        a = k * math.pi / 3 - math.pi / 2
        ex, ey = x + r * math.cos(a), y + r * math.sin(a)
        d.line([(x, y), (ex, ey)], fill=color, width=width)
        for f, L in ((0.45, 0.32), (0.72, 0.22)):
            bx, by = x + r * f * math.cos(a), y + r * f * math.sin(a)
            for s in (-1, 1):
                b = a + s * math.pi / 4
                d.line([(bx, by), (bx + r * L * math.cos(b), by + r * L * math.sin(b))], fill=color, width=width)
    d.ellipse([x - width * 1.4, y - width * 1.4, x + width * 1.4, y + width * 1.4], fill=color)


def flake_layer(W, H, x, y, r, width):
    layer = Image.new("RGB", (W, H))
    snowflake(ImageDraw.Draw(layer), x, y, r, WHITE_ICE, width)
    return layer


def trail(base, pts, sizes):
    """Five waypoints joined by a dotted frost path; the last ones brightest."""
    H, W = base.shape[:2]
    path = Image.new("RGB", (W, H))
    pd = ImageDraw.Draw(path)
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        n = 14
        for i in range(1, n):
            t = i / n
            x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            r = 5 + 3 * t
            pd.ellipse([x - r, y - r, x + r, y + r], fill=(150, 210, 255))
    add_light(base, path, ((0, 0.8), (10, 0.9)))
    for i, ((x, y), r) in enumerate(zip(pts, sizes)):
        k = 0.65 + 0.35 * i / (len(pts) - 1)
        halo = Image.new("RGB", (W, H))
        ImageDraw.Draw(halo).ellipse([x - r * 1.1, y - r * 1.1, x + r * 1.1, y + r * 1.1], fill=(50, 120, 210))
        add_light(base, halo, ((int(r * 0.6), 0.9 * k),))
        add_light(base, flake_layer(W, H, x, y, r, max(4, int(r / 9))),
                  ((0, 1.0 * k), (int(r / 8), 1.0 * k), (int(r / 3), 0.6 * k)))


def snowfall(W, H, n, seed, avoid=None):
    layer = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(layer)
    rng = random.Random(seed)
    for _ in range(n):
        x, y = rng.random() * W, rng.random() * H
        r = 1.5 + rng.random() ** 2 * 6
        v = int(150 + rng.random() * 100)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(v - 20, v, 255))
    for _ in range(18):
        x, y = rng.random() * W, rng.random() * H
        if avoid and avoid[0] <= x <= avoid[2] and avoid[1] <= y <= avoid[3]:
            continue
        snowflake(d, x, y, 14 + rng.random() * 26, (200, 230, 255), 3)
    return layer


def bottom_fade(base, start, strength):
    H = base.shape[0]
    y = np.linspace(0, 1, H, dtype=np.float32)
    k = np.clip((y - start) / (1 - start), 0, 1) ** 1.4 * strength
    base *= (1 - k)[:, None, None]


def card(path):
    W, H = 3840, 2160
    base = background(W, H, 71)
    chill(base)
    aurora(base, 0.16, 0.10, seed=3)
    add_light(base, stars(W, H, 1200, 29, big=16, avoid=(400, 300, 3500, 1700)), ((0, 0.9), (3, 0.5)))
    ox, oy, R = W * 0.70, H * 0.36, H * 0.20
    orb(base, ox, oy, R)
    add_light(base, flake_layer(W, H, ox, oy, R * 0.62, 12), ((0, 0.55), (6, 0.5)))
    pts = [(W * 0.14, H * 0.70), (W * 0.25, H * 0.56), (W * 0.36, H * 0.62), (W * 0.46, H * 0.47), (W * 0.555, H * 0.40)]
    trail(base, pts, (60, 70, 80, 92, 106))
    add_light(base, snowfall(W, H, 700, 5, avoid=(W * 0.5, H * 0.1, W * 0.9, H * 0.7)), ((0, 0.75), (4, 0.5)))
    sp = Image.new("RGB", (W, H))
    sparkle(ImageDraw.Draw(sp), ox + R * 0.55, oy - R * 0.6, 70, (240, 250, 255))
    add_light(base, sp, ((0, 1.0), (8, 0.8)))
    bottom_fade(base, 0.72, 0.85)
    return finish(base, path)


def details(path):
    W, H = 2160, 3840
    base = background(W, H, 73)
    chill(base)
    aurora(base, 0.08, 0.05, seed=9)
    add_light(base, stars(W, H, 1300, 31, big=18, avoid=(150, 300, 2010, 2900)), ((0, 0.9), (3, 0.5)))
    ox, oy, R = W * 0.5, H * 0.25, W * 0.25
    orb(base, ox, oy, R)
    add_light(base, flake_layer(W, H, ox, oy, R * 0.62, 12), ((0, 0.55), (6, 0.5)))
    pts = [(W * 0.30, H * 0.71), (W * 0.66, H * 0.645), (W * 0.36, H * 0.575), (W * 0.62, H * 0.505), (W * 0.5, H * 0.44)]
    trail(base, pts, (66, 74, 84, 94, 104))
    add_light(base, snowfall(W, H, 800, 7, avoid=(W * 0.2, H * 0.1, W * 0.8, H * 0.4)), ((0, 0.75), (4, 0.5)))
    bottom_fade(base, 0.70, 0.88)
    return finish(base, path)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(SPEC_DIR, exist_ok=True)
    prev = os.path.join(HERE, "previews")
    os.makedirs(prev, exist_ok=True)
    jobs = ((card, "event-card-16x9.png", "solstice_card_1920x1080.png", (1920, 1080)),
            (details, "event-details-9x16.png", "solstice_details_1080x1920.png", (1080, 1920)))
    for fn, full, upload, size in jobs:
        im = fn(os.path.join(OUT, full))
        im.resize(size, Image.LANCZOS).save(os.path.join(SPEC_DIR, upload), optimize=True)
        im.resize((im.width // 3, im.height // 3)).save(
            os.path.join(prev, "solstice-" + full.replace(".png", ".jpg")), quality=85)
    print("done")
