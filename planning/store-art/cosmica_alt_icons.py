"""Alternate app icons for a Product Page Optimization icon test (3.1.1).

The original icon is a fine-dotted galaxy on near-black: beautiful at 1024,
a dim smudge at the ~60px size App Store Browse shows it. Each alternate
keeps the brand (space, pink/purple/cyan, a bright core) but is built to
read small: one bold shape, high contrast, light in the middle.

  Core - the same galaxy, face-on and bright: continuous glowing arms, big core
  Orb  - the in-game tap orb with its sparkles (says "tap / idle game")
  Gold - True Cosmos: a gold galaxy collapsing into a gold ring

Writes 1024x1024 RGB PNGs (no alpha) into the asset catalog, plus a
preview sheet at real App Store sizes on light and dark backgrounds.
"""
import math, os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

import cosmica_store_art as art
from cosmica_store_art import add_light, arr, sparkle, stars

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ASSETS = os.path.join(ROOT, "Cosmica", "Resources", "Assets.xcassets")
S = 1024


def radial_bg(inner, outer, cx=0.5, cy=0.5, r=0.75):
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float32) / S
    d = np.clip(np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / r, 0, 1)[:, :, None]
    return np.array(inner, np.float32) * (1 - d) + np.array(outer, np.float32) * d


def glow(cx, cy, R, color, k=1.0, falloff=2.0):
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / R
    return np.exp(-d ** 2 * falloff)[:, :, None] * np.array(color, np.float32) * k


def tone(base, white=255.0):
    """Soft shoulder so bright cores glow instead of clipping flat."""
    return white * (1 - np.exp(-base / white * 1.15))


def icon_core():
    base = radial_bg((40, 14, 70), (4, 2, 14), r=0.72)
    add_light(base, stars(S, S, 160, 5, big=0), ((0, 0.8),))
    # face-on, oversized, and blurred more than the original so the arms read
    # as two continuous bands rather than dust
    dots = art.galaxy(S, S, S / 2, S / 2, 410, tilt=0.92, rot=0.6, seed=12, n=26000, clumps=70, core=0.9)
    base += dots * 0.62
    soft = Image.fromarray(np.clip(dots, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(14))
    base += arr(soft) * 0.55
    base += glow(S / 2, S / 2, 130, (255, 150, 230), 0.9)
    return tone(base)


def icon_orb():
    base = radial_bg((34, 10, 74), (2, 0, 10), r=0.8)
    add_light(base, stars(S, S, 220, 9, big=0), ((0, 0.9),))
    cx, cy = S * 0.5, S * 0.52
    # the orb: same recipe as ObservatoryView (tier colour, 0.9 -> 0.2 -> clear)
    base += glow(cx, cy, 330, (190, 90, 255), 1.0, falloff=1.6)
    base += glow(cx, cy, 190, (255, 120, 220), 0.9, falloff=1.8)
    ring = Image.new("L", (S, S))
    ImageDraw.Draw(ring).ellipse([cx - 300, cy - 300, cx + 300, cy + 300], outline=255, width=10)
    r = arr(ring.filter(ImageFilter.GaussianBlur(6)))[:, :, None] / 255.0
    base += r * np.array([230, 170, 255], np.float32) * 0.7
    # SF "sparkles": one big four-point star and two small ones
    layer = Image.new("RGB", (S, S))
    d = ImageDraw.Draw(layer)
    sparkle(d, cx - 40, cy + 40, 250, (255, 255, 255))
    sparkle(d, cx + 175, cy - 170, 95, (255, 255, 255))
    sparkle(d, cx + 205, cy + 95, 55, (255, 255, 255))
    add_light(base, layer, ((0, 1.0), (10, 1.2), (40, 1.0), (90, 0.6)))
    return tone(base)


def icon_gold():
    base = radial_bg((30, 12, 58), (3, 1, 12), r=0.75)
    add_light(base, stars(S, S, 180, 13, big=0), ((0, 0.8),))
    old = art.PINK, art.PURPLE, art.CYAN
    art.PINK, art.PURPLE, art.CYAN = (255, 240, 200), (255, 190, 90), (230, 120, 60)
    try:
        dots = art.galaxy(S, S, S / 2, S / 2, 415, tilt=0.92, rot=-0.4, seed=31, n=24000, clumps=60, core=0.4)
    finally:
        art.PINK, art.PURPLE, art.CYAN = old
    base += dots * 0.85
    soft = Image.fromarray(np.clip(dots, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(12))
    base += arr(soft) * 0.7
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
    d = np.sqrt((xx - S / 2) ** 2 + (yy - S / 2) ** 2) / 160
    base += np.exp(-((d - 1.0) / 0.07) ** 2)[:, :, None] * np.array([255, 205, 120], np.float32) * 1.1
    base += glow(S / 2, S / 2, 120, (255, 235, 190), 1.4)
    return tone(base)


def save_icon(name, base):
    img = Image.fromarray(np.clip(base, 0, 255).astype(np.uint8), "RGB")
    folder = os.path.join(ASSETS, f"{name}.appiconset")
    os.makedirs(folder, exist_ok=True)
    img.save(os.path.join(folder, f"{name}.png"), optimize=True)
    with open(os.path.join(folder, "Contents.json"), "w") as f:
        f.write('{\n  "images" : [\n    {\n      "filename" : "%s.png",\n      "idiom" : "universal",\n'
                '      "platform" : "ios",\n      "size" : "1024x1024"\n    }\n  ],\n'
                '  "info" : {\n    "author" : "xcode",\n    "version" : 1\n  }\n}\n' % name)
    return img


def preview(icons, path):
    """Each icon at 180, 120 and 60px with the iOS corner mask, on light and dark."""
    sizes = (180, 120, 60)
    pad, col = 40, 260
    W = pad + col * len(icons)
    H = 2 * (pad + sum(sizes) + pad * len(sizes)) + 60
    sheet = Image.new("RGB", (W, H), (255, 255, 255))
    ImageDraw.Draw(sheet).rectangle([0, H // 2, W, H], fill=(0, 0, 0))
    for half, y0 in ((0, pad), (1, H // 2 + pad)):
        for i, (name, img) in enumerate(icons):
            y = y0
            for s in sizes:
                small = img.resize((s, s), Image.LANCZOS)
                m = Image.new("L", (s, s))
                ImageDraw.Draw(m).rounded_rectangle([0, 0, s - 1, s - 1], int(s * 0.2237), fill=255)
                x = pad + i * col + (col - pad - s) // 2
                sheet.paste(small, (x, y), m)
                y += s + pad
            if half == 0:
                ImageDraw.Draw(sheet).text((pad + i * col, H // 2 - 30), name, fill=(0, 0, 0))
    sheet.save(path, quality=90)


if __name__ == "__main__":
    original = Image.open(os.path.join(ASSETS, "AppIcon.appiconset", "AppIcon.png")).convert("RGB")
    made = [("Original", original)]
    for name, fn in (("AppIcon-Core", icon_core), ("AppIcon-Orb", icon_orb), ("AppIcon-Gold", icon_gold)):
        made.append((name, save_icon(name, fn())))
    prev = os.path.join(os.path.dirname(os.path.abspath(__file__)), "previews")
    os.makedirs(prev, exist_ok=True)
    preview(made, os.path.join(prev, "alt-icons-sheet.jpg"))
    for name, img in made[1:]:
        img.resize((512, 512)).save(os.path.join(prev, f"{name}.jpg"), quality=90)
    print("done")
