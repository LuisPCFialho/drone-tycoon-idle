#!/usr/bin/env python3
"""Play Store listing assets for Drone Tycoon: Sky Fleet.

  python tools/gen_store_assets.py

Outputs to export/store/:
  feature_graphic.png   1024x500 RGB  (Play "Feature graphic" slot)
  01..06_*.png          1080x1920 RGB (screenshots, flattened from the capture)

Play rejects alpha channels on the feature graphic and prefers 24-bit for
screenshots, so everything here is flattened to RGB on save. Reuses the game's
own key art + Poppins so the listing matches what the player installs.
"""
import os
import glob
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.join(os.path.dirname(__file__), "..")
OUT = os.path.join(ROOT, "export", "store")
FONTS = os.path.join(ROOT, "assets", "fonts")
os.makedirs(OUT, exist_ok=True)


def H(s):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16))


VOID = H("070B16")
MIDNIGHT = H("0E1526")
PANEL2 = H("1A2440")
INK = H("F2F6FF")
MUTED = H("8794B0")
SKY = H("4A8CFF")
GOLD = H("FFC838")


def font(name, size):
    return ImageFont.truetype(os.path.join(FONTS, name), size)


def vgrad(size, top, bot):
    """Vertical gradient, drawn at 1px width then stretched (cheap + smooth)."""
    w, h = size
    strip = Image.new("RGB", (1, h))
    px = strip.load()
    for y in range(h):
        t = y / max(1, h - 1)
        px[0, y] = tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3))
    return strip.resize(size, Image.BICUBIC)


def radial_glow(size, center, radius, color, strength=1.0):
    """Additive-ish soft glow blob."""
    w, h = size
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    steps = 48
    for i in range(steps, 0, -1):
        t = i / steps
        r = radius * t
        a = int(255 * strength * (1 - t) ** 2 * 0.10)
        d.ellipse(
            [center[0] - r, center[1] - r, center[0] + r, center[1] + r],
            fill=color + (a,),
        )
    return layer


def feature_graphic():
    W, Hh = 1024, 500
    img = vgrad((W, Hh), MIDNIGHT, VOID).convert("RGBA")

    # ambient depth: two soft brand-coloured glows behind the art
    img.alpha_composite(radial_glow((W, Hh), (760, 250), 420, SKY, 1.0))
    img.alpha_composite(radial_glow((W, Hh), (150, 420), 320, H("2E5BD6"), 0.7))

    # hero: crop the drone out of the key art (its lower third is the baked-in
    # wordmark, which would collide with the title we draw on the left)
    logo_path = os.path.join(ROOT, "Logo app Drone Tycoon.png")
    logo = Image.open(logo_path).convert("RGBA")
    lw, lh = logo.size
    hero = logo.crop((0, 0, lw, int(lh * 0.62)))          # drone + city map
    scale = (Hh * 1.06) / hero.height
    hero = hero.resize((int(hero.width * scale), int(hero.height * scale)), Image.LANCZOS)

    # feather the hero's left edge so it dissolves into the gradient instead of
    # ending on a hard rectangular seam
    mask = Image.new("L", hero.size, 255)
    md = ImageDraw.Draw(mask)
    fade = int(hero.width * 0.30)
    for x in range(fade):
        md.line([(x, 0), (x, hero.height)], fill=int(255 * (x / fade) ** 1.5))
    img.paste(hero, (W - hero.width + 40, int((Hh - hero.height) / 2)), mask)

    # Left-hand scrim: the tagline sat on the drone's bright fuselage and washed
    # out. Fade a dark veil from the left edge to ~60% width so the title block
    # always has contrast regardless of what the art does behind it.
    scrim = Image.new("RGBA", (W, Hh), (0, 0, 0, 0))
    sd = ImageDraw.Draw(scrim)
    scrim_to = int(W * 0.60)
    for sx in range(scrim_to):
        a = int(232 * (1 - sx / scrim_to) ** 1.4)
        sd.line([(sx, 0), (sx, Hh)], fill=VOID + (a,))
    img.alpha_composite(scrim)

    d = ImageDraw.Draw(img)

    # title block (kept clear of edges — Play crops/overlays the outer margins)
    x = 62
    d.text((x, 150), "DRONE", font=font("Poppins-Bold.ttf", 76), fill=INK)
    d.text((x, 228), "TYCOON", font=font("Poppins-Bold.ttf", 76), fill=GOLD)
    d.text((x, 322), "SKY FLEET", font=font("Poppins-SemiBold.ttf", 34), fill=SKY)
    d.text((x + 3, 372), "Build your drone delivery empire",
           font=font("Poppins-Regular.ttf", 25), fill=MUTED)

    img.convert("RGB").save(os.path.join(OUT, "feature_graphic.png"))
    print("feature_graphic.png  1024x500 RGB")


def flatten_screenshots():
    """Play wants 24-bit screenshots; the Godot capture writes RGBA."""
    for f in sorted(glob.glob(os.path.join(OUT, "*.png"))):
        if os.path.basename(f) == "feature_graphic.png":
            continue
        im = Image.open(f)
        if im.mode != "RGB":
            bg = Image.new("RGB", im.size, VOID)
            bg.paste(im, mask=im.split()[-1] if im.mode == "RGBA" else None)
            bg.save(f)
            print("flattened -> RGB  %s %s" % (os.path.basename(f), im.size))


if __name__ == "__main__":
    feature_graphic()
    flatten_screenshots()
