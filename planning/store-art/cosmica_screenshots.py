"""Cosmica App Store screenshots (6.9" 1320x2868 and 6.5" 1284x2778), 3.3 set.

Same look as the 3.0.2 set: purple starfield gradient, white Segoe UI Black
headline, lavender subhead, a cropped game screen in a white-edged, glowing
rounded frame. Raw captures come from an iPhone Pro Max (1320x2868).

Usage: python cosmica_screenshots.py   (writes to OUT/6.9in and OUT/6.5in)
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

RAW = r"P:\digital products\Cosmica App Store 3.3\raw"
OUT = r"P:\digital products\Cosmica App Store 3.3"
BLACK = r"C:\Windows\Fonts\seguibl.ttf"
SEMI = r"C:\Windows\Fonts\seguisb.ttf"
W, H = 1320, 2868
LAVENDER = (196, 168, 255)

# (output name, raw file, crop (x0, y0, x1, y1) in raw pixels, headline, subhead)
FRAMES = [
    ("01-endless-universe", "01-hero.png", (0, 220, 1320, 2590),
     "Grow an endless universe", "Tap, idle and ascend, forever"),
    ("02-big-bang", "02-big-bang.png", (0, 330, 1320, 2420),
     "Big Bang.\nCome back stronger.","Trade your universe for permanent power"),
    ("03-wonders", "03-wonders.png", (0, 175, 1320, 1900),
     "Build Wonders. Level them up.", "Permanent upgrades that survive every reset"),
    ("04-stellar-ranks", "04-cosmic-tree.png", (0, 175, 1320, 2600),
     "A tree with no ceiling", "Stellar ranks multiply forever"),
    ("05-specializations", "05-specializations.png", (0, 230, 1320, 2600),
     "Make every generator yours", "Overcharged, Resonant, Night Shift, Thrifty"),
    ("06-orb-skins", "06-orb-skins.png", (0, 840, 1320, 2200),
     "Make the cosmos yours", "Unlock orb skins as you play"),
]


def background(seed):
    y = np.linspace(0, 1, H, dtype=np.float32)[:, None, None]
    top, mid, bot = np.array([18, 6, 40.]), np.array([42, 11, 72.]), np.array([6, 2, 16.])
    t = 0.49
    g = np.where(y < t, top + (mid - top) * (y / t), mid + (bot - mid) * ((y - t) / (1 - t)))
    img = Image.fromarray(np.broadcast_to(g, (H, W, 3)).astype(np.uint8).copy())
    d = ImageDraw.Draw(img)
    rng = np.random.default_rng(seed)
    for _ in range(170):
        x, yy = rng.integers(0, W), rng.integers(0, H)
        r = rng.choice([1.5, 2, 2.5, 3.5], p=[0.45, 0.3, 0.17, 0.08])
        a = int(rng.integers(110, 255))
        d.ellipse([x - r, yy - r, x + r, yy + r], fill=(a, a, a))
    return img


def fit_text(text, path, size, max_w, max_lines=2):
    """Largest font <= size that fits `text` in max_lines lines of max_w.
    A "\n" in `text` forces the line break."""
    d = ImageDraw.Draw(Image.new("RGB", (1, 1)))
    if "\n" in text:
        lines = text.split("\n")
        while size > 40:
            font = ImageFont.truetype(path, size)
            if all(d.textlength(l, font=font) <= max_w for l in lines):
                return font, lines
            size -= 4
        return ImageFont.truetype(path, size), lines
    words = text.split()
    while size > 40:
        font = ImageFont.truetype(path, size)
        if d.textlength(text, font=font) <= max_w:
            return font, [text]
        if max_lines >= 2:
            best = None
            for i in range(1, len(words)):
                a, b = " ".join(words[:i]), " ".join(words[i:])
                wmax = max(d.textlength(a, font=font), d.textlength(b, font=font))
                if wmax <= max_w and (best is None or wmax < best[0]):
                    best = (wmax, [a, b])
            if best:
                return font, best[1]
        size -= 4
    return ImageFont.truetype(path, size), [text]


def render(raw, crop, head, sub, seed):
    img = background(seed)
    d = ImageDraw.Draw(img)
    hf, hlines = fit_text(head, BLACK, 150, 1180)
    sf, slines = fit_text(sub, SEMI, 64, 1180, max_lines=1)
    y = 250 if len(hlines) == 1 else 190
    for line in hlines:
        d.text((W / 2, y), line, font=hf, fill="white", anchor="ma")
        y += int(hf.size * 1.08)
    y += 26
    d.text((W / 2, y), slines[0], font=sf, fill=LAVENDER, anchor="ma")
    top = y + int(sf.size * 1.2) + 90

    shot = Image.open(os.path.join(RAW, raw)).convert("RGB").crop(crop)
    scale = min(1160 / shot.width, (H - 120 - top) / shot.height)
    shot = shot.resize((round(shot.width * scale), round(shot.height * scale)), Image.LANCZOS)
    x0 = (W - shot.width) // 2
    radius = 64
    box = [x0, top, x0 + shot.width, top + shot.height]

    glow = Image.new("RGB", (W, H))
    ImageDraw.Draw(glow).rounded_rectangle([box[0] - 10, box[1] - 10, box[2] + 10, box[3] + 10],
                                           radius + 10, fill=(150, 60, 255))
    glow = np.asarray(glow.filter(ImageFilter.GaussianBlur(45)), dtype=np.float32) * 0.55
    img = Image.fromarray(np.clip(np.asarray(img, dtype=np.float32) + glow, 0, 255).astype(np.uint8))

    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, shot.width - 1, shot.height - 1], radius, fill=255)
    img.paste(shot, (x0, top), mask)
    ImageDraw.Draw(img).rounded_rectangle(box, radius, outline="white", width=4)
    return img


def to_65(img):
    """1320x2868 -> 1284x2778 without stretching: scale to width, trim background rows."""
    tall = img.resize((1284, round(H * 1284 / W)), Image.LANCZOS)
    cut = (tall.height - 2778) // 2
    return tall.crop((0, cut, 1284, cut + 2778))


if __name__ == "__main__":
    for folder in ("6.9in", "6.5in"):
        os.makedirs(os.path.join(OUT, folder), exist_ok=True)
    for i, (name, raw, crop, head, sub) in enumerate(FRAMES):
        if not os.path.exists(os.path.join(RAW, raw)):
            print("missing", raw)
            continue
        big = render(raw, crop, head, sub, seed=i + 7)
        big.save(os.path.join(OUT, "6.9in", name + ".png"))
        to_65(big).save(os.path.join(OUT, "6.5in", name + ".png"))
        print("wrote", name)
