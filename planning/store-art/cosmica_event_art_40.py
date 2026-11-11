"""Cosmica 4.0 In-App Event media ("Major Update": Beyond the Ceiling).

Same specs as the 3.1 event (cosmica_event_art.py): event card 16:9 (1920x1080 to
3840x2160) and event details page 9:16 (1080x1920 to 2160x3840). Apple lays the
badge, event name and short description over the bottom of the media, so the art
has no headline: the idea is the number ladder climbing to 1e300, smashing through
a glowing ceiling, and carrying on in Omniverse gold. The bottom stays dark.

Writes full-res PNGs to P:\\digital products\\Cosmica In-App Event 4.0, upload-size
copies (1920x1080 / 1080x1920) next to event-4.0/event.json, and previews.
"""
import math, os, random
import numpy as np
from PIL import Image, ImageDraw, ImageFont

from cosmica_store_art import BLACK, GOLD, add_light, background, finish, glow_text, lerpc, sparkle, stars

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = r"P:\digital products\Cosmica In-App Event 4.0"
SPEC_DIR = os.path.join(HERE, "event-4.0")
BELOW = ["1e100", "1e200", "1e300"]                  # the old world, under the ceiling
ABOVE = ["1e308", "1e500", "1e1,000", "1e10,000"]    # 4.0, past it
LAVENDER = (215, 195, 255)


def gold_glow(W, H, cx, cy, R, strength=1.0):
    """The Omniverse: a warm gold bloom with a bright heart."""
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / R
    light = np.exp(-d ** 2 * 1.2)[:, :, None] * np.array([255, 150, 40], np.float32) * 0.55
    light += np.exp(-d ** 2 * 7)[:, :, None] * np.array([255, 195, 95], np.float32) * 0.6
    light += np.exp(-d ** 2 * 40)[:, :, None] * np.array([255, 240, 205], np.float32) * 0.7
    return light * strength


def warm_above(base, y_c, soft):
    """Tint everything above the ceiling toward gold, so the two worlds read apart."""
    H = base.shape[0]
    y = np.arange(H, dtype=np.float32)
    k = np.clip((y_c - y) / soft, 0, 1)[:, None, None]
    base[:] = base * (1 - 0.35 * k) + k * np.array([70, 40, 8], np.float32)


def ceiling(base, y_c, gap_x, gap_w, seed, thick):
    """A glowing horizontal ceiling, shattered where the ladder breaks through."""
    W, H = base.shape[1], base.shape[0]
    rng = random.Random(seed)
    layer = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(layer)
    col = (200, 175, 255)
    left, right = gap_x - gap_w / 2, gap_x + gap_w / 2
    d.rectangle([0, y_c - thick / 2, left, y_c + thick / 2], fill=col)
    d.rectangle([right, y_c - thick / 2, W, y_c + thick / 2], fill=col)
    # jagged broken ends + hairline cracks running out along the ceiling
    for edge, sgn in ((left, -1), (right, 1)):
        pts = [(edge, y_c - thick / 2)]
        for i in range(5):
            pts.append((edge - sgn * rng.uniform(0, thick * 3), y_c - thick / 2 + thick * (i + 1) / 5))
        pts.append((edge, y_c + thick / 2))
        d.polygon(pts, fill=(0, 0, 0))
        for _ in range(4):
            x, y = edge, y_c + rng.uniform(-thick, thick)
            for _ in range(6):
                nx, ny = x + sgn * rng.uniform(thick * 2, thick * 6), y + rng.uniform(-thick * 1.5, thick * 1.5)
                d.line([(x, y), (nx, ny)], fill=(235, 220, 255), width=max(2, int(thick / 6)))
                x, y = nx, ny
    add_light(base, layer, ((0, 1.0), (int(thick * 1.5), 1.2), (int(thick * 6), 0.9)))
    # shards flying up out of the hole, gold-white, smaller as they rise
    shards = Image.new("RGB", (W, H))
    sd = ImageDraw.Draw(shards)
    for _ in range(36):
        t = rng.random()
        x = gap_x + rng.choice((-1, 1)) * abs(rng.gauss(gap_w * 0.25, gap_w * (0.4 + 1.1 * t)))
        y = y_c - t * gap_w * 2.2 - rng.uniform(0, thick * 2)
        s = thick * (2.6 - 1.9 * t) * rng.uniform(0.6, 1.3)
        a = rng.uniform(0, math.tau)
        poly = [(x + s * math.cos(a + k * 2.1 + rng.uniform(-0.4, 0.4)) * (1 if k else 1.6),
                 y + s * math.sin(a + k * 2.1 + rng.uniform(-0.4, 0.4)) * (1 if k else 1.6)) for k in range(3)]
        c = tuple(int(v) for v in lerpc((225, 210, 255), (255, 225, 160), t))
        sd.polygon(poly, fill=c)
    add_light(base, shards, ((0, 0.7), (int(thick * 2), 0.6)))


def climb(base, path_below, path_above, sizes_below, sizes_above):
    """Exponents along two paths: lavender under the ceiling, gold above it."""
    W, H = base.shape[1], base.shape[0]
    for steps, path_, sizes, c0, c1 in ((BELOW, path_below, sizes_below, LAVENDER, (245, 240, 255)),
                                         (ABOVE, path_above, sizes_above, (255, 215, 140), GOLD)):
        n = len(steps)
        for i, s in enumerate(steps):
            t = i / max(1, n - 1)
            x, y = path_(t)
            size = sizes[0] + (sizes[1] - sizes[0]) * t
            f = ImageFont.truetype(BLACK, int(size))
            col = tuple(int(v) for v in lerpc(c0, c1, t))
            glow_text(base, (x, y), s, f, fill=col, glow=col, radius=10 + size * 0.09,
                      strength=0.55 + 0.6 * t, anchor="mm", shadow=0.9)
            if i < n - 1:
                mx, my = path_(t + 0.5 / max(1, n - 1))
                dl = Image.new("RGB", (W, H))
                sparkle(ImageDraw.Draw(dl), mx, my, size * 0.14, (255, 235, 200))
                add_light(base, dl, ((0, 1.0), (6, 0.8)))


def bottom_fade(base, start, strength):
    """Darken the bottom so Apple's overlaid event text stays readable."""
    H = base.shape[0]
    y = np.linspace(0, 1, H, dtype=np.float32)
    k = np.clip((y - start) / (1 - start), 0, 1) ** 1.4 * strength
    base *= (1 - k)[:, None, None]


def card(path):
    W, H = 3840, 2160
    base = background(W, H, 61)
    y_c, gap_x = H * 0.50, W * 0.47
    warm_above(base, y_c, H * 0.35)
    add_light(base, stars(W, H, 1300, 19, big=22, avoid=(300, 200, 3540, 1500)), ((0, 1.0), (3, 0.6)))
    base += gold_glow(W, H, W * 0.88, H * 0.08, 900, strength=0.7)
    ceiling(base, y_c, gap_x, 300, seed=4, thick=26)
    # under: rises from the lower left to the hole; above: from the hole up and right
    climb(base,
          lambda t: (W * 0.17 + (gap_x - W * 0.04 - W * 0.17) * t, H * 0.76 - (H * 0.76 - H * 0.585) * t),
          lambda t: (gap_x + W * 0.05 + W * 0.27 * t ** 0.9, H * 0.41 - H * 0.30 * t),
          (96, 128), (138, 230))
    bottom_fade(base, 0.74, 0.8)
    return finish(base, path)


def details(path):
    W, H = 2160, 3840
    base = background(W, H, 63)
    y_c, gap_x = H * 0.47, W * 0.5
    warm_above(base, y_c, H * 0.30)
    add_light(base, stars(W, H, 1400, 23, big=24, avoid=(150, 200, 2010, 2800)), ((0, 1.0), (3, 0.6)))
    base += gold_glow(W, H, W * 0.5, H * 0.09, 950)
    ceiling(base, y_c, gap_x, 260, seed=8, thick=24)
    climb(base,
          lambda t: (W * 0.5 + math.sin(t * math.pi) * W * 0.12, H * 0.69 - (H * 0.69 - H * 0.52) * t),
          lambda t: (W * 0.5 - math.sin(t * math.pi) * W * 0.10, H * 0.42 - (H * 0.42 - H * 0.17) * t),
          (100, 130), (140, 235))
    bottom_fade(base, 0.72, 0.85)
    return finish(base, path)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(SPEC_DIR, exist_ok=True)
    prev = os.path.join(HERE, "previews")
    jobs = ((card, "event-card-16x9.png", "event40_card_1920x1080.png", (1920, 1080)),
            (details, "event-details-9x16.png", "event40_details_1080x1920.png", (1080, 1920)))
    for fn, full, upload, size in jobs:
        im = fn(os.path.join(OUT, full))
        im.resize(size, Image.LANCZOS).save(os.path.join(SPEC_DIR, upload), optimize=True)
        im.resize((im.width // 3, im.height // 3)).save(
            os.path.join(prev, "event40-" + full.replace(".png", ".jpg")), quality=85)
    print("done")
