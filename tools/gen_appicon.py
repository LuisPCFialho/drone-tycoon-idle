#!/usr/bin/env python3
"""Regenerate the app icon from the key art.

  python tools/gen_appicon.py

Writes:
  appicon.png              512x512 RGBA — Godot window icon + launcher_icons/main_192x192
  export/store/app_icon_512.png  same, for the Play Console listing slot

Why this exists: the previous appicon.png was the logo shrunk into a rounded tile
sitting on a blue gradient. Google Play dynamically applies its OWN 30% corner
radius, mask and drop shadow to the store icon, so that produced a rounded icon
nested inside another rounded icon on a stray blue border.

The key art is a rounded square with black corners. We crop to the artwork, scale
to 512, and knock out ONLY the black corners — by flood-filling inward from each
corner, not by keying out every dark pixel, which would punch holes through the
drone and the night sky. Play's 30% mask is more aggressive than the art's own
~14% corners, so the transparency is never actually visible in the store; it just
means the asset is honestly "the logo, no background".
"""
import os
from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(__file__), "..")
SRC = os.path.join(ROOT, "Logo app Drone Tycoon.png")
OUT_ICON = os.path.join(ROOT, "appicon.png")
OUT_STORE_DIR = os.path.join(ROOT, "export", "store")
SIZE = 512
NEAR_BLACK = 18       # luma below this counts as the black surround
SS = 4                # supersample for a clean alpha edge


def content_bbox(im):
    """Bounding box of everything that isn't the near-black surround."""
    black = Image.new("RGB", im.size, (0, 0, 0))
    mask = ImageChops.difference(im.convert("RGB"), black).convert("L")
    return mask.point(lambda v: 255 if v > NEAR_BLACK else 0).getbbox()


def corner_alpha(im):
    """Alpha where the black CORNERS are knocked out, interior darks preserved.

    Flood-fills from each corner across connected near-black pixels: the corners
    are the only black region touching the border, so interior shadows survive.
    """
    lum = im.convert("L").point(lambda v: 0 if v <= NEAR_BLACK else 255)
    w, h = lum.size
    # 255 = keep. Flood the connected black regions at each corner with 128.
    for xy in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]:
        if lum.getpixel(xy) == 0:
            ImageDraw.floodfill(lum, xy, 128, thresh=0)
    # only the flooded (128) pixels become transparent
    return lum.point(lambda v: 0 if v == 128 else 255)


def main():
    src = Image.open(SRC).convert("RGB")
    art = src.crop(content_bbox(src))

    big = art.resize((SIZE * SS, SIZE * SS), Image.LANCZOS)
    alpha = corner_alpha(big).filter(ImageFilter.GaussianBlur(SS * 0.5))
    icon = big.convert("RGBA")
    icon.putalpha(alpha)
    icon = icon.resize((SIZE, SIZE), Image.LANCZOS)   # downsample => antialiased edge

    icon.save(OUT_ICON)
    os.makedirs(OUT_STORE_DIR, exist_ok=True)
    icon.save(os.path.join(OUT_STORE_DIR, "app_icon_512.png"))

    a = icon.getchannel("A")
    print("appicon.png %dx%d RGBA  alpha min/max=%s  %.0f KB"
          % (icon.width, icon.height, a.getextrema(), os.path.getsize(OUT_ICON) / 1024))


if __name__ == "__main__":
    main()
