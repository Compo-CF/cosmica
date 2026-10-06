"""Cosmica App Store creative assets: product page header (21:9) + search result (3:2).

Specs (App Store Connect, creative assets): header 3840x1646, search 3840x2560,
PNG/JPEG, no alpha. On iPhone the 21:9 header is center-cropped (~4:3) with the
back/share buttons over the top corners, so the idea lives in the middle.
"""
import math, os, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = r"P:\digital products\Cosmica App Store Header and Search"
SRC_SHOT = r"P:\digital products\IMG_0130.PNG"
BLACK = r"C:\Windows\Fonts\seguibl.ttf"
SEMI = r"C:\Windows\Fonts\seguisb.ttf"
os.makedirs(OUT, exist_ok=True)

PINK, PURPLE, CYAN, GOLD = (255, 110, 215), (165, 105, 255), (80, 185, 230), (255, 205, 120)


def lerpc(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def arr(img):
    return np.asarray(img, dtype=np.float32)


def add_light(base, layer_img, weights=((0, 1.0),)):
    """Additively blend a light layer (plus blurred copies for glow) into base."""
    for radius, w in weights:
        l = layer_img if radius == 0 else layer_img.filter(ImageFilter.GaussianBlur(radius))
        base += arr(l) * w
    return base


def background(W, H, seed):
    y = np.linspace(0, 1, H, dtype=np.float32)[:, None, None]
    top, mid, bot = np.array([12, 5, 30.]), np.array([30, 10, 62.]), np.array([5, 2, 14.])
    g = np.where(y < 0.5, top + (mid - top) * (y / 0.5), mid + (bot - mid) * ((y - 0.5) / 0.5))
    base = np.broadcast_to(g, (H, W, 3)).astype(np.float32).copy()
    rng = np.random.default_rng(seed)
    for color, cells, strength in [((150, 40, 170), 5, 0.55), ((40, 70, 210), 7, 0.45), ((210, 60, 150), 10, 0.3)]:
        small = rng.random((cells, max(2, int(cells * W / H)))).astype(np.float32)
        n = Image.fromarray((small * 255).astype(np.uint8)).resize((W, H), Image.BICUBIC)
        n = arr(n.filter(ImageFilter.GaussianBlur(H / 9))) / 255.0
        n = np.clip((n - 0.45) * 2.2, 0, 1) ** 2
        base += n[:, :, None] * np.array(color, dtype=np.float32) * strength
    return base


def sparkle(d, x, y, s, color):
    w = s * 0.18
    d.polygon([(x, y - s), (x + w, y - w), (x + s, y), (x + w, y + w),
               (x, y + s), (x - w, y + w), (x - s, y), (x - w, y - w)], fill=color)


def stars(W, H, n, seed, big=14, avoid=None):
    """avoid: (x0, y0, x1, y1) kept free of twinkles (text sits there)."""
    layer = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(layer)
    rng = random.Random(seed)
    for _ in range(n):
        x, y = rng.random() * W, rng.random() * H
        r = 1.2 + rng.random() ** 3 * 4.5
        v = int(110 + rng.random() * 145)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(v, v, min(255, v + 25)))
    for _ in range(big):  # a few four-point twinkles
        x, y = rng.random() * W, rng.random() * H
        if avoid and avoid[0] <= x <= avoid[2] and avoid[1] <= y <= avoid[3]:
            continue
        sparkle(d, x, y, 18 + rng.random() * 30, (235, 230, 255))
    return layer


def galaxy(W, H, cx, cy, R, tilt=0.5, rot=-0.35, seed=7, n=16000, clumps=150, core=1.0):
    """Two-arm spiral in the app icon's palette: pink core -> purple -> cyan arms."""
    dots = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(dots)
    rng = random.Random(seed)
    cr, sr = math.cos(rot), math.sin(rot)

    def place(t, arm, spread):
        theta = t * 2.7 * math.pi + arm * math.pi
        r = R * (0.10 + 0.90 * t)
        x = r * math.cos(theta) + rng.gauss(0, spread)
        y = (r * math.sin(theta) + rng.gauss(0, spread)) * tilt
        return cx + x * cr - y * sr, cy + x * sr + y * cr

    def color(t):
        return lerpc(PINK, PURPLE, t / 0.45) if t < 0.45 else lerpc(PURPLE, CYAN, (t - 0.45) / 0.55)

    for i in range(n):
        t = rng.random() ** 0.85
        x, y = place(t, i % 2, R * 0.05 * (0.4 + t))
        c = tuple(int(v * (0.55 + rng.random() * 0.45)) for v in color(t))
        s = R * 0.0028 * (1 + rng.random() * 1.6)
        d.ellipse([x - s, y - s, x + s, y + s], fill=c)
    for i in range(clumps):  # star-forming knots
        t = 0.15 + rng.random() * 0.85
        x, y = place(t, i % 2, R * 0.03)
        s = R * (0.008 + rng.random() * 0.012)
        d.ellipse([x - s, y - s, x + s, y + s], fill=(235, 205, 245))
        d.ellipse([x - s / 2.5, y - s / 2.5, x + s / 2.5, y + s / 2.5], fill=(255, 255, 255))
    light = np.zeros((H, W, 3), np.float32)
    add_light(light, dots, ((0, 1.0), (R * 0.012, 1.3), (R * 0.05, 0.9)))
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    dist = np.sqrt((xx - cx) ** 2 + ((yy - cy) / max(tilt, 0.35)) ** 2) / (R * 0.32)
    light += np.exp(-dist ** 2 * 2.2)[:, :, None] * np.array([255, 220, 205], np.float32) * 1.25 * core
    light += np.exp(-dist ** 2 * 18)[:, :, None] * np.array([255, 250, 240], np.float32) * 1.4 * core
    return light


def glow_text(base, xy, text, font, fill=(255, 255, 255), glow=(190, 120, 255), radius=30,
              strength=1.4, anchor="la", spacing=0, shadow=0.0):
    W, H = base.shape[1], base.shape[0]
    mask = Image.new("L", (W, H))
    md = ImageDraw.Draw(mask)
    if spacing:
        x, y = xy
        total = sum(font.getlength(ch) for ch in text) + spacing * (len(text) - 1)
        if anchor[0] == "m":
            x -= total / 2
        for ch in text:
            md.text((x, y), ch, font=font, fill=255, anchor="l" + anchor[1])
            x += font.getlength(ch) + spacing
    else:
        md.text(xy, text, font=font, fill=255, anchor=anchor)
    m = arr(mask) / 255.0
    if shadow:  # dark halo first, so the letters separate from busy art behind
        sh = arr(mask.filter(ImageFilter.GaussianBlur(radius * 1.6))) / 255.0
        base *= (1 - np.clip(sh * 2.2, 0, 1) * shadow)[:, :, None]
    g = arr(mask.filter(ImageFilter.GaussianBlur(radius))) / 255.0
    base += g[:, :, None] * np.array(glow, np.float32) * strength
    base[:] = base * (1 - m[:, :, None]) + m[:, :, None] * np.array(fill, np.float32)
    return base


def finish(base, path):
    img = Image.fromarray(np.clip(base, 0, 255).astype(np.uint8), "RGB")
    img.save(path, optimize=True)
    return img


# ───────── Header: wordmark over the galaxy, number ladder underneath ─────────
def header(path, ladder=True):
    W, H = 3840, 1646
    base = background(W, H, 11)
    add_light(base, stars(W, H, 900, 3, big=18), ((0, 1.0), (3, 0.6)))
    base += galaxy(W, H, W / 2, H * 0.50, 1250, tilt=0.42, rot=-0.22, seed=21) * 0.45
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    veil = np.exp(-(((xx - W / 2) / 1000) ** 2 + ((yy - H * 0.50) / 330) ** 2))
    base *= (1 - 0.6 * veil)[:, :, None]

    # Apple's template safe area for the header: x 28-71%, y 30-69%
    # (1075-2726 x 494-1136). Wordmark + subtitle live inside it.
    word = ImageFont.truetype(BLACK, 250)
    glow_text(base, (W / 2, H * 0.47), "COSMICA", word, glow=(200, 120, 255), radius=36,
              strength=0.9, anchor="mm", spacing=26, shadow=0.85)
    sub = ImageFont.truetype(SEMI, 84)
    glow_text(base, (W / 2, H * 0.47 + 200), "IDLE UNIVERSE", sub, fill=(235, 220, 255),
              glow=(120, 90, 255), radius=14, strength=0.5, anchor="mm", spacing=26, shadow=0.8)

    if ladder:
        steps = ["1", "1K", "1M", "1B", "1T", "1Qa", "1Sx", "1Dc", "1Ud"]
        x0, x1, y0 = W / 2 - 1180, W / 2 + 1180, H * 0.885
        n = len(steps) - 1
        for i, s in enumerate(steps):
            t = i / n
            x = x0 + (x1 - x0) * t
            y = y0 - math.sin(t * math.pi) * 70
            f = ImageFont.truetype(BLACK, int(58 + 50 * t))
            col = tuple(int(c) for c in lerpc((215, 195, 255), GOLD, t))
            glow_text(base, (x, y), s, f, fill=col, glow=col, radius=14 + 10 * t,
                      strength=0.5 + 0.7 * t, anchor="mm", shadow=0.7)
            if i < n:
                d = Image.new("RGB", (W, H))
                tm = (i + 0.5) / n
                sparkle(ImageDraw.Draw(d), x0 + (x1 - x0) * tm, y0 - math.sin(tm * math.pi) * 70,
                        12 + 10 * t, (255, 235, 200))
                add_light(base, d, ((0, 1.0), (6, 0.8)))
    return finish(base, path)


# ───────── Search result: one-line pitch + real gameplay + the widget ─────────
def rounded(img, r):
    m = Image.new("L", img.size)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, img.size[0] - 1, img.size[1] - 1], r, fill=255)
    return m


def widget_card(S):
    """Recreation of the real Cosmica small widget layout."""
    top, bot = np.array([10, 8, 31.]), np.array([43, 18, 84.])
    t = np.linspace(0, 1, S, dtype=np.float32)[:, None, None]
    card = Image.fromarray(np.broadcast_to(top + (bot - top) * t, (S, S, 3)).astype(np.uint8))
    d = ImageDraw.Draw(card)
    pad = S * 0.10
    sparkle(d, pad + 18, pad + 22, 20, (170, 160, 200))
    d.text((pad + 50, pad + 22), "COSMICA", font=ImageFont.truetype(BLACK, int(S * 0.062)),
           fill=(165, 155, 195), anchor="lm")
    big = ImageFont.truetype(BLACK, int(S * 0.20))
    txt = "+4.51Qa"
    m = Image.new("L", card.size)
    ImageDraw.Draw(m).text((pad, S * 0.40), txt, font=big, fill=255, anchor="lm")
    grad = Image.linear_gradient("L").rotate(90).resize(card.size)
    colored = Image.merge("RGB", [grad.point(lambda v: 175 - v * 105 // 255),
                                  grad.point(lambda v: 80 + v * 50 // 255),
                                  grad.point(lambda v: 245)])
    card.paste(colored, (0, 0), m)
    sparkle(d, pad + big.getlength(txt) + S * 0.07, S * 0.40, S * 0.045, (110, 120, 255))
    d.text((pad, S * 0.555), "waiting for you", font=ImageFont.truetype(SEMI, int(S * 0.072)),
           fill=(190, 185, 215), anchor="lm")
    by = S * 0.74
    d.rounded_rectangle([pad, by, S - pad, by + S * 0.035], S * 0.02, fill=(60, 50, 90))
    d.rounded_rectangle([pad, by, pad + (S - 2 * pad) * 0.62, by + S * 0.035], S * 0.02, fill=(170, 90, 255))
    d.text((pad, S * 0.86), "Full in 3 hr, 12 min", font=ImageFont.truetype(SEMI, int(S * 0.062)),
           fill=(190, 185, 215), anchor="lm")
    return card


def paste_with_glow(base, img, x, y, radius_px, glow_color, glow_strength, corner):
    W, H = base.shape[1], base.shape[0]
    mask = rounded(img, corner)
    full = Image.new("L", (W, H))
    full.paste(mask, (x, y))
    g = arr(full.filter(ImageFilter.GaussianBlur(radius_px))) / 255.0
    base += g[:, :, None] * np.array(glow_color, np.float32) * glow_strength
    m = arr(full)[:, :, None] / 255.0
    layer = np.zeros_like(base)
    layer[y:y + img.size[1], x:x + img.size[0]] = arr(img)
    base[:] = base * (1 - m) + layer * m


def search(path):
    W, H = 3840, 2560
    base = background(W, H, 5)
    add_light(base, stars(W, H, 1100, 9, big=16, avoid=(780, 700, 2000, 1850)), ((0, 1.0), (3, 0.6)))
    # galaxy tucked into the bottom-left corner, clear of the headline
    base += galaxy(W, H, 260, 2420, 1150, tilt=0.5, rot=0.25, seed=33, core=0.7) * 0.4

    # Apple's template safe area for search results: x 22-78%, y 30-70%
    # (845-2995 x 768-1792). Headline + the orb/top rows of real gameplay sit
    # inside it; the rest of the phone and the widget are bonus on full-size cards.
    sx0, sx1, sy0, sy1 = 845, 2995, 768, 1792

    shot = Image.open(SRC_SHOT).convert("RGB").crop((0, 765, 1320, 2455))
    pw = 1000
    shot = shot.resize((pw, int(shot.height * pw / shot.width)), Image.LANCZOS)
    px, py = sx1 - pw, sy0 - 120          # orb + first generators land in the band
    frame = Image.new("RGB", (shot.width + 20, shot.height + 20), (150, 110, 230))
    frame.paste(shot, (10, 10), rounded(shot, 80))
    paste_with_glow(base, frame, px - 10, py - 10, 80, (150, 70, 255), 0.9, 90)

    wc = widget_card(700)
    paste_with_glow(base, wc, sx1 + 70, sy1 - 700 + 120, 60, (120, 60, 255), 0.8, 155)

    head = ImageFont.truetype(BLACK, 190)
    lines = ["Build a", "universe", "that runs", "itself."]
    for i, line in enumerate(lines):
        glow_text(base, (sx0 + 20, sy0 + 10 + i * 220), line, head, glow=(180, 110, 255),
                  radius=28, strength=0.8, anchor="lt", shadow=0.6)
    # "state the obvious": say what kind of game it is, still inside the band
    glow_text(base, (sx0 + 24, sy0 + 10 + 4 * 220 + 20), "An idle space game", ImageFont.truetype(SEMI, 86),
              fill=(215, 195, 255), glow=(120, 90, 255), radius=12, strength=0.5, anchor="lt", shadow=0.5)
    return finish(base, path)


def safe_overlay(src, dst, box):
    """Debug preview: Apple's safe area drawn on a downscaled copy."""
    im = Image.open(src).convert("RGB")
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(im)
    d.rectangle([x0 * im.width, y0 * im.height, x1 * im.width, y1 * im.height],
                outline=(0, 255, 0), width=10)
    im.resize((im.width // 3, im.height // 3)).save(dst, quality=85)


if __name__ == "__main__":
    header(os.path.join(OUT, "header-21x9-ladder.png"), ladder=True)
    header(os.path.join(OUT, "header-21x9-clean.png"), ladder=False)
    search(os.path.join(OUT, "search-3x2.png"))
    prev = os.path.join(os.path.dirname(os.path.abspath(__file__)), "previews")
    os.makedirs(prev, exist_ok=True)
    safe_overlay(os.path.join(OUT, "header-21x9-ladder.png"), os.path.join(prev, "header-ladder-safe.jpg"), (0.28, 0.30, 0.71, 0.69))
    safe_overlay(os.path.join(OUT, "header-21x9-clean.png"), os.path.join(prev, "header-clean-safe.jpg"), (0.28, 0.30, 0.71, 0.69))
    safe_overlay(os.path.join(OUT, "search-3x2.png"), os.path.join(prev, "search-safe.jpg"), (0.22, 0.30, 0.78, 0.70))
    print("done")
