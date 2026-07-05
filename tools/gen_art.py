#!/usr/bin/env python3
"""Premium asset generator for Drone Tycoon: Sky Fleet (Aurora Logistics).
Supersampled (anti-aliased) PNGs -> assets/art/.  Run: python tools/gen_art.py

Design system: smooth vertical/radial gradients, soft navy drop shadows,
inner top-highlights, colored neon under-glows, crisp white-tintable particles.
All output filenames/sizes match the prior generator so .import files stay valid.
"""
import os, math, random
from PIL import Image, ImageDraw, ImageFilter

random.seed(11)
SS = 5  # supersample factor (bumped 4->5 for crisp 48px icons on high-DPI)
ART = os.path.join(os.path.dirname(__file__), "..", "assets", "art")
os.makedirs(ART, exist_ok=True)

# ---------------------------------------------------------------- palette (spec hex)
def H(s):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16))

VOID      = H("070B16")
MIDNIGHT  = H("0E1526")
PANEL     = H("141C30")
PANEL2    = H("1A2440")
HAIRLINE  = H("2A3654")
INK       = H("F2F6FF")
MUTED     = H("8794B0")
SKY       = H("4A8CFF")
SKY_D     = H("2E5BD6")
MINT      = H("22D08A")
GOLD      = H("FFC838")
CYAN      = H("3AD6F0")
VIOLET    = H("9B6BFF")
AMBER     = H("F5A623")
ORANGE    = H("FF7A2E")
CORAL     = H("FF5A5F")
MAGENTA   = H("FF6FB5")
SHADOW    = H("0A0F1E")
WHITE     = (255, 255, 255)
SLATE     = H("334155")

# ---------------------------------------------------------------- core helpers
def canvas(n):
    return Image.new("RGBA", (n * SS, n * SS), (0, 0, 0, 0))

def finish(img, n, name):
    img.resize((n, n), Image.LANCZOS).save(os.path.join(ART, name))

def rr(d, box, r, **kw):
    d.rounded_rectangle([box[0]*SS, box[1]*SS, box[2]*SS, box[3]*SS], radius=r*SS, **kw)

def circle(d, cx, cy, rad, **kw):
    d.ellipse([(cx-rad)*SS, (cy-rad)*SS, (cx+rad)*SS, (cy+rad)*SS], **kw)

def lerp(a, b, t):
    return tuple(int(a[i] + (b[i]-a[i])*t) for i in range(3))

def darken(c, f):
    return tuple(int(x*(1-f)) for x in c)

def lighten(c, f):
    return tuple(int(x + (255-x)*f) for x in c)

def add_shadow(img, blur, dy, alpha=110, color=SHADOW):
    a = img.split()[3]
    sh = Image.composite(
        Image.new("RGBA", img.size, color + (255,)),
        Image.new("RGBA", img.size, (0, 0, 0, 0)), a)
    sh = sh.filter(ImageFilter.GaussianBlur(blur * SS))
    # scale alpha
    sa = sh.split()[3].point(lambda v: int(v * alpha / 255))
    sh.putalpha(sa)
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.alpha_composite(sh, (0, int(dy * SS)))
    out.alpha_composite(img)
    return out

def vgrad_mask(n, c_top, c_bot, mask):
    """Return an RGBA layer of vertical gradient c_top->c_bot, clipped by mask (L, full SS size)."""
    w = n * SS; h = n * SS
    grad = Image.new("RGBA", (1, h))
    gp = grad.load()
    for y in range(h):
        t = y / max(1, h - 1)
        gp[0, y] = lerp(c_top, c_bot, t) + (255,)
    grad = grad.resize((w, h))
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.paste(grad, (0, 0), mask)
    return out

def rect_mask(n, box, radius):
    m = Image.new("L", (n*SS, n*SS), 0)
    ImageDraw.Draw(m).rounded_rectangle(
        [box[0]*SS, box[1]*SS, box[2]*SS, box[3]*SS], radius=radius*SS, fill=255)
    return m

def ellipse_mask(n, cx, cy, rx, ry):
    m = Image.new("L", (n*SS, n*SS), 0)
    ImageDraw.Draw(m).ellipse(
        [(cx-rx)*SS, (cy-ry)*SS, (cx+rx)*SS, (cy+ry)*SS], fill=255)
    return m

def vgrad_rr(img, n, box, r, c_top, c_bot):
    img.alpha_composite(vgrad_mask(n, c_top, c_bot, rect_mask(n, box, r)))

def vgrad_ellipse(img, n, cx, cy, rx, ry, c_top, c_bot):
    img.alpha_composite(vgrad_mask(n, c_top, c_bot, ellipse_mask(n, cx, cy, rx, ry)))

def gloss_cap(img, n, box, alpha=110):
    """Soft white ellipse over the top third of box, blurred."""
    x0, y0, x1, y1 = box
    gx0, gy0 = x0 + (x1-x0)*0.12, y0 + (y1-y0)*0.06
    gx1, gy1 = x1 - (x1-x0)*0.12, y0 + (y1-y0)*0.42
    lay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(lay).ellipse([gx0*SS, gy0*SS, gx1*SS, gy1*SS], fill=WHITE + (alpha,))
    lay = lay.filter(ImageFilter.GaussianBlur(1.5 * SS))
    img.alpha_composite(lay)

def glow(img, color, blur, alpha=150):
    """Composite a blurred colored copy of the shape's alpha behind it -> neon bloom."""
    a = img.split()[3]
    col = Image.composite(
        Image.new("RGBA", img.size, color + (255,)),
        Image.new("RGBA", img.size, (0, 0, 0, 0)), a)
    col = col.filter(ImageFilter.GaussianBlur(blur * SS))
    ga = col.split()[3].point(lambda v: int(v * alpha / 255))
    col.putalpha(ga)
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.alpha_composite(col)
    out.alpha_composite(img)
    return out

def rim(d, box, r, color=WHITE, alpha=70, w=1):
    """1px-inset inner stroke for a candy/glass edge."""
    rr(d, (box[0]+0.4, box[1]+0.4, box[2]-0.4, box[3]-0.4), max(0.5, r-0.4),
       outline=color + (alpha,), width=int(w*SS))

def inner_glow_disc(img, n, cx, cy, rad, color, alpha=120):
    """Soft inner glow ring inside a currency token disc."""
    lay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    dd = ImageDraw.Draw(lay)
    circle(dd, cx, cy, rad*0.86, outline=color + (alpha,), width=int(rad*0.34*SS))
    lay = lay.filter(ImageFilter.GaussianBlur(rad*0.18*SS))
    # clip to disc
    lay.putalpha(Image.composite(lay.split()[3],
        Image.new("L", img.size, 0), ellipse_mask(n, cx, cy, rad, rad)))
    img.alpha_composite(lay)

def under_glow(img, n, cx, cy, rx, ry, color, blur, alpha=60):
    lay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(lay).ellipse([(cx-rx)*SS, (cy-ry)*SS, (cx+rx)*SS, (cy+ry)*SS],
                                fill=color + (255,))
    lay = lay.filter(ImageFilter.GaussianBlur(blur*SS))
    ga = lay.split()[3].point(lambda v: int(v * alpha / 255))
    lay.putalpha(ga)
    base = Image.new("RGBA", img.size, (0, 0, 0, 0))
    base.alpha_composite(lay)
    base.alpha_composite(img)
    return base

# ---------------------------------------------------------------- drones
def drone(name, accent, n=96, shadow=True):
    """Hero quadcopter. All three drones derive purely from accent."""
    img = canvas(n)
    accent_d = darken(accent, 0.13)
    c = n / 2.0
    R = n * 0.30
    rotors = [(c-R, c-R), (c+R, c-R), (c-R, c+R), (c+R, c+R)]

    # arms: tapered filled polygons (wide at body -> narrow at motor) + Ink top edge
    d = ImageDraw.Draw(img)
    aw = n*0.075   # half-width at body
    mw = n*0.028   # half-width at motor
    for rx, ry in rotors:
        dx, dy = rx - c, ry - c
        L = math.hypot(dx, dy)
        px, py = -dy/L, dx/L  # perpendicular
        p = [(c+px*aw, c+py*aw), (rx+px*mw, ry+py*mw),
             (rx-px*mw, ry-py*mw), (c-px*aw, c-py*aw)]
        d.polygon([(q[0]*SS, q[1]*SS) for q in p], fill=SLATE + (255,))
        # Ink top edge highlight
        d.line([(c+px*aw)*SS, (c+py*aw)*SS, (rx+px*mw)*SS, (ry+py*mw)*SS],
               fill=lighten(SLATE, 0.4) + (200,), width=int(n*0.01*SS))

    # rotors: two stacked translucent discs (motion blur) + dark hub + white pin
    for rx, ry in rotors:
        circle(d, rx, ry, n*0.205, fill=accent + (60,))
        circle(d, rx, ry, n*0.14, fill=accent + (80,))
        circle(d, rx, ry, n*0.205, outline=accent + (150,), width=int(n*0.012*SS))
        circle(d, rx, ry, n*0.05, fill=SHADOW + (255,))
        circle(d, rx, ry, n*0.018, fill=WHITE + (230,))

    # body: vertical gradient (bright top -> accent_d) through rounded mask
    bs = n * 0.185
    bbox = (c-bs, c-bs, c+bs, c+bs)
    vgrad_rr(img, n, bbox, n*0.12, lighten(accent, 0.28), accent_d)
    d = ImageDraw.Draw(img)
    rim(d, bbox, n*0.12, WHITE, 80, 1)

    # glass canopy: small sleek dark-glass oval near the top of the body
    cb = (c-bs*0.52, c-bs*0.58, c+bs*0.52, c-bs*0.02)
    rr(d, cb, n*0.05, fill=darken(PANEL, 0.1) + (255,))
    rim(d, cb, n*0.05, lighten(accent, 0.3), 90, 1)
    # diagonal specular streak across the canopy
    sp = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(sp).line(
        [(c-bs*0.38)*SS, (c-bs*0.42)*SS, (c+bs*0.1)*SS, (c-bs*0.12)*SS],
        fill=WHITE + (235,), width=int(n*0.018*SS))
    sp = sp.filter(ImageFilter.GaussianBlur(0.5*SS))
    sp.putalpha(Image.composite(sp.split()[3], Image.new("L", img.size, 0),
                                rect_mask(n, cb, n*0.05)))
    img.alpha_composite(sp)

    # belly LED (lower body)
    d = ImageDraw.Draw(img)
    circle(d, c, c+bs*0.5, n*0.032, fill=accent + (255,))
    circle(d, c, c+bs*0.5, n*0.015, fill=WHITE + (235,))

    if shadow:
        img = under_glow(img, n, c, c, bs*1.9, bs*1.9, accent, 9, 85)
        img = add_shadow(img, 5, 5, 120)
    finish(img, n, name)

# ---------------------------------------------------------------- package
def package(n=44, save=True):
    """Faux-isometric cargo cube: front face + lighter top parallelogram + right side."""
    img = canvas(n)
    cx = n*0.5
    # cube corners (a 2.5D box)
    L = n*0.16; R = n*0.84          # outer left/right of front face
    fy0 = n*0.4; fy1 = n*0.86        # front face top/bottom
    th = n*0.22                       # iso top depth
    # --- front face (gradient) ---
    front = (L, fy0, R, fy1)
    vgrad_rr(img, n, front, n*0.05, AMBER, darken(AMBER, 0.24))
    d = ImageDraw.Draw(img)
    # --- top parallelogram (lighter) ---
    top = [(L, fy0), (L+th*0.6, fy0-th), (R+th*0.6, fy0-th), (R, fy0)]
    poly(d, top, lighten(AMBER, 0.4) + (255,))
    # --- right side face (darker) for depth ---
    side = [(R, fy0), (R+th*0.6, fy0-th), (R+th*0.6, fy1-th), (R, fy1)]
    poly(d, side, darken(AMBER, 0.32) + (255,))
    # --- taped cross seams on front ---
    seam = darken(AMBER, 0.34)
    line(d, (cx, fy0), (cx, fy1), seam, n*0.05)
    line(d, (L, (fy0+fy1)/2), (R, (fy0+fy1)/2), seam, n*0.04)
    # seam over the top
    line(d, ((L+R)/2, fy0), ((L+R)/2+th*0.6, fy0-th), darken(AMBER,0.2), n*0.04)
    # --- shipping label ---
    lb = (cx-n*0.13, fy0+(fy1-fy0)*0.16, cx+n*0.13, fy0+(fy1-fy0)*0.4)
    rr(d, lb, n*0.025, fill=WHITE + (200,))
    line(d, (cx-n*0.09, fy0+(fy1-fy0)*0.3), (cx+n*0.09, fy0+(fy1-fy0)*0.3), MUTED+(160,), n*0.018)
    # --- corner highlight + edges ---
    rim(d, front, n*0.05, WHITE, 70, 1)
    line(d, (L, fy0), (R, fy0), WHITE+(110,), n*0.012)  # top front edge
    gloss_cap(img, n, (L, fy0, R, fy0+(fy1-fy0)*0.45), 80)
    img = add_shadow(img, 3, 3, 110)
    if save:
        finish(img, n, "package.png")
    return img

# ---------------------------------------------------------------- hubs
def hub_home(n=128):
    img = canvas(n)
    base = (n*0.12, n*0.16, n*0.88, n*0.9)
    # ambient gold glow disc behind
    img = under_glow(img, n, n*0.5, n*0.55, n*0.46, n*0.46, GOLD, 10, 50)
    vgrad_rr(img, n, base, n*0.12, lighten(INK, 0.0), darken(INK, 0.08))
    d = ImageDraw.Draw(img)
    # gold roof band (top 16%)
    roof = (base[0], base[1], base[2], base[1] + (base[3]-base[1])*0.16)
    vgrad_rr(img, n, roof, n*0.12, lighten(GOLD, 0.18), GOLD)
    d = ImageDraw.Draw(img)
    cx, cy = n*0.5, n*0.58
    # concentric landing ring with soft outer glow
    gl = Image.new("RGBA", img.size, (0, 0, 0, 0))
    circle(ImageDraw.Draw(gl), cx, cy, n*0.27, outline=GOLD + (255,), width=int(n*0.03*SS))
    gl = gl.filter(ImageFilter.GaussianBlur(6*SS))
    ga = gl.split()[3].point(lambda v: int(v*50/255)); gl.putalpha(ga)
    img.alpha_composite(gl)
    d = ImageDraw.Draw(img)
    circle(d, cx, cy, n*0.27, outline=GOLD + (255,), width=int(n*0.03*SS))
    circle(d, cx, cy, n*0.18, outline=GOLD + (180,), width=int(n*0.025*SS))
    # bold H
    hw = n*0.05
    d.line([(n*0.42*SS, n*0.47*SS), (n*0.42*SS, n*0.69*SS)], fill=GOLD + (255,), width=int(hw*SS))
    d.line([(n*0.58*SS, n*0.47*SS), (n*0.58*SS, n*0.69*SS)], fill=GOLD + (255,), width=int(hw*SS))
    d.line([(n*0.42*SS, n*0.58*SS), (n*0.58*SS, n*0.58*SS)], fill=GOLD + (255,), width=int(hw*SS))
    rim(d, base, n*0.12, WHITE, 90, 1)
    img = add_shadow(img, 6, 6, 120)
    finish(img, n, "hub_home.png")

def hub_city(name, base_col, n=128, antenna=False):
    img = canvas(n)
    img = under_glow(img, n, n*0.5, n*0.6, n*0.46, n*0.42, base_col, 10, 45)
    plate = (n*0.06, n*0.56, n*0.94, n*0.95)
    vgrad_rr(img, n, plate, n*0.07, lighten(INK, 0.0), darken(INK, 0.1))
    d = ImageDraw.Draw(img)
    xs = [0.14, 0.34, 0.55, 0.73]
    hs = [0.30, 0.46, 0.22, 0.38]
    tones = [base_col, lighten(base_col, 0.18), darken(base_col, 0.12)]
    tallest_x = xs[1]; tallest_top = (0.66-hs[1])*n
    for i, x in enumerate(xs):
        bh = hs[i]
        bx = (x*n, (0.66-bh)*n, (x+0.16)*n, 0.72*n)
        col = tones[i % 3]
        vgrad_rr(img, n, bx, n*0.03, lighten(col, 0.22), darken(col, 0.25))
        dd = ImageDraw.Draw(img)
        rim(dd, bx, n*0.03, WHITE, 40, 1)
        # windows
        rows = int(bh*9)
        for wy in range(rows):
            yy = (0.66-bh+0.04+wy*0.052)*n
            if yy > 0.66*n: break
            for wx in (0.035, 0.085):
                lit = random.random() < 0.22
                col_w = GOLD + (220,) if lit else (WHITE + (140,))
                dd.rectangle([((x+wx)*n)*SS, yy*SS, ((x+wx+0.03)*n)*SS, (yy+0.022*n)*SS],
                             fill=col_w)
    d = ImageDraw.Draw(img)
    # rooftop helipad ring on tallest
    circle(d, (tallest_x+0.08)*n, tallest_top+n*0.03, n*0.045,
           outline=lighten(base_col, 0.3) + (255,), width=int(n*0.012*SS))
    if antenna:
        sx = (tallest_x+0.08)*n
        d.line([sx*SS, tallest_top*SS, sx*SS, (tallest_top-n*0.12)*SS],
               fill=MUTED + (255,), width=int(n*0.012*SS))
        circle(d, sx, tallest_top-n*0.12, n*0.022, fill=MAGENTA + (230,))
        circle(d, sx, tallest_top-n*0.12, n*0.01, fill=WHITE + (230,))
    rim(d, plate, n*0.07, WHITE, 70, 1)
    img = add_shadow(img, 6, 6, 120)
    finish(img, n, name)

# ---------------------------------------------------------------- cloud
def cloud(n=120):
    h = int(n*0.62)
    img = Image.new("RGBA", (n*SS, h*SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    blobs = [(0.32,0.58,0.22),(0.5,0.42,0.28),(0.68,0.56,0.22),(0.5,0.66,0.3)]
    for cx, cy, r in blobs:
        d.ellipse([(cx-r)*n*SS,(cy-r*1.6)*h*SS,(cx+r)*n*SS,(cy+r*1.6)*h*SS],
                  fill=(255,255,255,200))
    # sky under-shade on bottom edge
    sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
    for cx, cy, r in blobs:
        ImageDraw.Draw(sh).ellipse(
            [(cx-r)*n*SS,(cy-r*1.6+r*1.4)*h*SS,(cx+r)*n*SS,(cy+r*1.6+r*0.5)*h*SS],
            fill=SKY + (40,))
    sh = sh.filter(ImageFilter.GaussianBlur(3*SS))
    sh.putalpha(Image.composite(sh.split()[3], Image.new("L", img.size, 0), img.split()[3]))
    img.alpha_composite(sh)
    # white rim-light top edge
    rl = Image.new("RGBA", img.size, (0, 0, 0, 0))
    for cx, cy, r in blobs:
        ImageDraw.Draw(rl).ellipse(
            [(cx-r)*n*SS,(cy-r*1.6)*h*SS,(cx+r)*n*SS,(cy-r*1.6+r*0.5)*h*SS],
            fill=WHITE + (120,))
    rl = rl.filter(ImageFilter.GaussianBlur(1.5*SS))
    rl.putalpha(Image.composite(rl.split()[3], Image.new("L", img.size, 0), img.split()[3]))
    img.alpha_composite(rl)
    img.resize((n, h), Image.LANCZOS).save(os.path.join(ART, "cloud.png"))

# ---------------------------------------------------------------- icon system
# Upgrade/utility glyph family: rendered at 96 internally, downscaled to 48.
# Duotone: accent fill + lighter top facet, 3px rounded strokes, hue-matched glow.
ICON_N = 96

def make_icon(name, fn, glow_col=None, glow_alpha=40, blur=4, ss_extra=False):
    n = ICON_N
    img = canvas(n)
    d = ImageDraw.Draw(img)
    fn(d, img, n)
    if glow_col is not None:
        img = glow(img, glow_col, blur, glow_alpha)
    finish(img, 48, name)

def duo_bar(d, box, r, col):
    """rounded bar with lighter top facet."""
    rr(d, box, r, fill=col + (255,))
    rr(d, (box[0], box[1], box[2], box[1]+(box[3]-box[1])*0.4), r, fill=lighten(col,0.3)+(255,))

def poly(d, pts, fill):
    d.polygon([(p[0]*SS, p[1]*SS) for p in pts], fill=fill)

def line(d, a, b, fill, w):
    d.line([a[0]*SS, a[1]*SS, b[0]*SS, b[1]*SS], fill=fill, width=int(w*SS))

def gem_shape(d, n, col, cx=None, top=0.12, bot=0.88, half=0.32):
    if cx is None: cx = n/2
    pts = [(cx, n*top), (cx+n*half, n*0.42), (cx, n*bot), (cx-n*half, n*0.42)]
    poly(d, pts, col + (255,))
    poly(d, [(cx, n*top), (cx+n*half, n*0.42), (cx, n*0.5)], lighten(col,0.18)+(255,))
    poly(d, [(cx, n*top), (cx-n*half, n*0.42), (cx, n*0.5)], lighten(col,0.32)+(255,))
    # bright top facet
    poly(d, [(cx, n*top), (cx+n*half*0.55, n*0.36), (cx-n*half*0.55, n*0.36)], lighten(col,0.5)+(255,))

def sparkle(d, n, cx, cy, s, col=WHITE, alpha=230):
    pts = [(cx, cy-s),(cx+s*0.25,cy-s*0.25),(cx+s,cy),(cx+s*0.25,cy+s*0.25),
           (cx,cy+s),(cx-s*0.25,cy+s*0.25),(cx-s,cy),(cx-s*0.25,cy-s*0.25)]
    poly(d, pts, col + (alpha,))

def token_disc(img, n, col):
    """36px-equiv gradient token disc with 1px lighter rim + inner glow."""
    cx = cy = n/2; rad = n*0.38
    vgrad_ellipse(img, n, cx, cy, rad, rad, lighten(col,0.25), darken(col,0.18))
    inner_glow_disc(img, n, cx, cy, rad, lighten(col,0.4), 90)
    d = ImageDraw.Draw(img)
    circle(d, cx, cy, rad, outline=lighten(col,0.4) + (180,), width=int(n*0.012*SS))
    return cx, cy, rad

def gen_icons():
    # ---- currency family (token disc) ----
    def credits(d, img, n):
        cx, cy, rad = token_disc(img, n, GOLD)
        d2 = ImageDraw.Draw(img)
        # faceted double concentric rim
        circle(d2, cx, cy, rad*0.78, outline=darken(GOLD,0.25) + (220,), width=int(n*0.02*SS))
        # embossed up-arrow
        line(d2, (cx, cy+rad*0.34), (cx, cy-rad*0.34), WHITE+(90,), n*0.05)
        poly(d2, [(cx-rad*0.28, cy-rad*0.06),(cx, cy-rad*0.4),(cx+rad*0.28, cy-rad*0.06)], WHITE+(90,))
        gloss_cap(img, n, (cx-rad, cy-rad, cx+rad, cy+rad), 80)
        sparkle(d2, n, cx-rad*0.45, cy-rad*0.45, n*0.06, WHITE, 230)
    make_icon("ic_credits.png", credits, GOLD, 40, 5)

    def gems(d, img, n):
        token_disc(img, n, darken(CYAN,0.2))
        d2 = ImageDraw.Draw(img)
        gem_shape(d2, n, CYAN)
        sparkle(d2, n, n*0.34, n*0.32, n*0.06, WHITE, 230)
    make_icon("ic_gems.png", gems, CYAN, 45, 5)

    def prestige(d, img, n):
        token_disc(img, n, darken(VIOLET,0.2))
        d2 = ImageDraw.Draw(img)
        # hexagon gem
        cx = n/2
        hexp = [(cx, n*0.14),(n*0.82, n*0.32),(n*0.82, n*0.68),
                (cx, n*0.86),(n*0.18, n*0.68),(n*0.18, n*0.32)]
        poly(d2, hexp, VIOLET + (255,))
        poly(d2, [(cx, n*0.14),(n*0.82, n*0.32),(cx, n*0.5)], lighten(VIOLET,0.22)+(255,))
        poly(d2, [(cx, n*0.14),(n*0.18, n*0.32),(cx, n*0.5)], lighten(VIOLET,0.4)+(255,))
        sparkle(d2, n, n*0.36, n*0.34, n*0.06, MAGENTA, 240)
    make_icon("ic_prestige.png", prestige, VIOLET, 55, 6)

    # ---- upgrade glyph family (no disc) ----
    def income(d, img, n):
        ws = [0.20, 0.36, 0.52]
        for i in range(3):
            duo_bar(d, (n*(0.18+i*0.24), n*(0.82-ws[i]), n*(0.34+i*0.24), n*0.84), n*0.03, MINT)
        # up arrow chip
        poly(d, [(n*0.6,n*0.34),(n*0.76,n*0.18),(n*0.76,n*0.3)], lighten(MINT,0.2)+(255,))
        line(d,(n*0.76,n*0.18),(n*0.62,n*0.18),lighten(MINT,0.2)+(255,),n*0.03)
    make_icon("ic_income.png", income, MINT, 40, 5)

    def speed(d, img, n):
        pts = [(n*0.56,n*0.1),(n*0.28,n*0.54),(n*0.46,n*0.54),(n*0.4,n*0.9),(n*0.72,n*0.44),(n*0.52,n*0.44)]
        poly(d, pts, AMBER + (255,))
        poly(d, [(n*0.56,n*0.1),(n*0.42,n*0.32),(n*0.5,n*0.32)], lighten(AMBER,0.4)+(255,))
        line(d,(n*0.5,n*0.2),(n*0.4,n*0.46),WHITE+(160,),n*0.018)
    make_icon("ic_speed.png", speed, AMBER, 40, 5)

    def cargo(d, img, n):
        front = (n*0.24, n*0.4, n*0.76, n*0.8)
        vgrad_rr(img, n, front, n*0.05, AMBER, darken(AMBER,0.22))
        d2 = ImageDraw.Draw(img)
        poly(d2, [(n*0.24,n*0.4),(n*0.5,n*0.24),(n*0.76,n*0.4)], lighten(AMBER,0.45)+(255,))
        line(d2,(n*0.5,n*0.4),(n*0.5,n*0.8),darken(AMBER,0.3)+(255,),n*0.04)
        circle(d2, n*0.5, n*0.58, n*0.05, fill=WHITE+(190,))
    make_icon("ic_cargo.png", cargo, AMBER, 40, 5)

    def value(d, img, n):
        pts=[(n*0.18,n*0.18),(n*0.52,n*0.18),(n*0.84,n*0.5),(n*0.5,n*0.84),(n*0.16,n*0.52)]
        poly(d, pts, AMBER+(255,))
        poly(d, [(n*0.18,n*0.18),(n*0.52,n*0.18),(n*0.5,n*0.45)], lighten(AMBER,0.35)+(255,))
        sparkle(d, n, n*0.42, n*0.42, n*0.12, WHITE, 230)
    make_icon("ic_value.png", value, AMBER, 40, 5)

    def drone_ic(d, img, n):
        c=n/2; R=n*0.26
        for rx,ry in [(c-R,c-R),(c+R,c-R),(c-R,c+R),(c+R,c+R)]:
            line(d,(c,c),(rx,ry),SKY+(255,),n*0.05)
            circle(d, rx, ry, n*0.12, outline=SKY+(220,), width=int(n*0.025*SS))
        # body duotone
        bb=(c-n*0.13,c-n*0.13,c+n*0.13,c+n*0.13)
        vgrad_rr(img,n,bb,n*0.05,lighten(SKY,0.2),SKY_D)
        d2=ImageDraw.Draw(img)
        circle(d2, c, c, n*0.05, fill=WHITE+(230,))
    make_icon("ic_drone.png", drone_ic, SKY, 40, 5)

    def rng(d, img, n):
        # range ring
        circle(d, n*0.5, n*0.42, n*0.34, outline=CYAN+(90,), width=int(n*0.02*SS))
        # pin teardrop
        circle(d, n*0.5, n*0.4, n*0.2, fill=CYAN+(255,))
        poly(d, [(n*0.32,n*0.5),(n*0.68,n*0.5),(n*0.5,n*0.86)], CYAN+(255,))
        circle(d, n*0.5, n*0.38, n*0.14, outline=lighten(CYAN,0.3)+(255,), width=int(n*0.012*SS))
        circle(d, n*0.5, n*0.4, n*0.08, fill=WHITE+(230,))
    make_icon("ic_range.png", rng, CYAN, 40, 5)

    def boost(d, img, n):
        for i,oy in enumerate([0.0, 0.22]):
            poly(d, [(n*0.5,n*(0.16+oy)),(n*0.74,n*(0.5+oy)),(n*0.26,n*(0.5+oy))],
                 (MINT if i==0 else lighten(MINT,0.0))+(255,))
        poly(d, [(n*0.5,n*0.16),(n*0.62,n*0.33),(n*0.38,n*0.33)], lighten(MINT,0.3)+(255,))
    make_icon("ic_boost.png", boost, MINT, 40, 5)

    def gear(d, img, n):
        cx=cy=n/2
        for a in range(0,360,45):
            x=cx+math.cos(math.radians(a))*n*0.34; y=cy+math.sin(math.radians(a))*n*0.34
            rr(d, (x-n*0.06,y-n*0.06,x+n*0.06,y+n*0.06), n*0.02, fill=MUTED+(255,))
        circle(d, cx, cy, n*0.27, fill=MUTED+(255,))
        circle(d, cx, cy, n*0.27, outline=lighten(MUTED,0.3)+(200,), width=int(n*0.012*SS))
        circle(d, cx, cy, n*0.1, fill=SHADOW+(255,))
    make_icon("ic_gear.png", gear, SKY, 30, 4)

    # ---- monochrome nav (pure white, engine modulates) ----
    def nav_fleet(d, img, n):
        c=n/2; R=n*0.24; w=n*0.04
        for rx,ry in [(c-R,c-R),(c+R,c-R),(c-R,c+R),(c+R,c+R)]:
            line(d,(c,c),(rx,ry),WHITE+(255,),w)
            circle(d, rx, ry, n*0.12, outline=WHITE+(255,), width=int(w*SS))
        circle(d, c, c, n*0.1, outline=WHITE+(255,), width=int(w*SS))
    make_icon("ic_nav_fleet.png", nav_fleet)

    def nav_cities(d, img, n):
        c=n/2
        circle(d, c, c, n*0.3, outline=WHITE+(255,), width=int(n*0.04*SS))
        # meridian
        d.arc([(c-n*0.15)*SS,(c-n*0.3)*SS,(c+n*0.15)*SS,(c+n*0.3)*SS],0,360,fill=WHITE+(255,),width=int(n*0.035*SS))
        line(d,(c-n*0.3,c),(c+n*0.3,c),WHITE+(255,),n*0.035)
        circle(d, c+n*0.18, c-n*0.18, n*0.06, fill=WHITE+(255,))
    make_icon("ic_nav_cities.png", nav_cities)

    def nav_talents(d, img, n):
        sparkle(d, n, n*0.5, n*0.5, n*0.34, WHITE, 255)
        circle(d, n*0.78, n*0.3, n*0.05, fill=WHITE+(255,))
        circle(d, n*0.24, n*0.74, n*0.045, fill=WHITE+(255,))
    make_icon("ic_nav_talents.png", nav_talents)

    def nav_legado(d, img, n):
        # trophy cup
        rr(d, (n*0.34,n*0.2,n*0.66,n*0.46), n*0.04, outline=WHITE+(255,), width=int(n*0.04*SS))
        d.arc([(n*0.18)*SS,(n*0.22)*SS,(n*0.4)*SS,(n*0.5)*SS],90,270,fill=WHITE+(255,),width=int(n*0.035*SS))
        d.arc([(n*0.6)*SS,(n*0.22)*SS,(n*0.82)*SS,(n*0.5)*SS],270,90,fill=WHITE+(255,),width=int(n*0.035*SS))
        line(d,(n*0.5,n*0.46),(n*0.5,n*0.66),WHITE+(255,),n*0.04)
        line(d,(n*0.36,n*0.7),(n*0.64,n*0.7),WHITE+(255,),n*0.05)
        line(d,(n*0.4,n*0.78),(n*0.6,n*0.78),WHITE+(255,),n*0.05)
    make_icon("ic_nav_legado.png", nav_legado)

    def nav_shop(d, img, n):
        gem_pts=[(n*0.4,n*0.22),(n*0.62,n*0.22),(n*0.72,n*0.42),(n*0.51,n*0.74),(n*0.3,n*0.42)]
        d.polygon([(p[0]*SS,p[1]*SS) for p in gem_pts], outline=WHITE+(255,), width=int(n*0.04*SS))
        line(d,(n*0.3,n*0.42),(n*0.72,n*0.42),WHITE+(255,),n*0.03)
        # price tag
        rr(d, (n*0.6,n*0.58,n*0.84,n*0.82), n*0.04, outline=WHITE+(255,), width=int(n*0.03*SS))
        circle(d, n*0.66, n*0.64, n*0.025, fill=WHITE+(255,))
    make_icon("ic_nav_shop.png", nav_shop)

    def nav_missions(d, img, n):
        # clipboard with a checkmark (task list)
        rr(d, (n*0.28,n*0.24,n*0.72,n*0.82), n*0.06, outline=WHITE+(255,), width=int(n*0.04*SS))
        rr(d, (n*0.42,n*0.15,n*0.58,n*0.28), n*0.03, fill=WHITE+(255,))
        line(d,(n*0.37,n*0.55),(n*0.46,n*0.65),WHITE+(255,),n*0.05)
        line(d,(n*0.46,n*0.65),(n*0.64,n*0.40),WHITE+(255,),n*0.05)
    make_icon("ic_nav_missions.png", nav_missions)

    # ---- emoji-replacement utility icons ----
    def event(d, img, n):
        pts=[(n*0.56,n*0.1),(n*0.28,n*0.54),(n*0.46,n*0.54),(n*0.4,n*0.9),(n*0.72,n*0.44),(n*0.52,n*0.44)]
        poly(d, pts, ORANGE+(255,))
        poly(d, [(n*0.56,n*0.1),(n*0.42,n*0.32),(n*0.5,n*0.32)], lighten(ORANGE,0.4)+(255,))
        line(d,(n*0.5,n*0.2),(n*0.4,n*0.46),WHITE+(200,),n*0.02)
    make_icon("ic_event.png", event, ORANGE, 45, 5)

    def daily(d, img, n):
        page=(n*0.2,n*0.24,n*0.8,n*0.82)
        vgrad_rr(img,n,page,n*0.06,lighten(GOLD,0.18),GOLD)
        d2=ImageDraw.Draw(img)
        # header band
        rr(d2,(n*0.2,n*0.24,n*0.8,n*0.38),n*0.06,fill=darken(GOLD,0.2)+(255,))
        # grid lines
        for gx in (0.4,0.6):
            line(d2,(n*gx,n*0.42),(n*gx,n*0.78),WHITE+(150,),n*0.02)
        for gy in (0.52,0.66):
            line(d2,(n*0.24,n*gy),(n*0.76,n*gy),WHITE+(150,),n*0.02)
        # check
        line(d2,(n*0.4,n*0.62),(n*0.48,n*0.72),WHITE+(255,),n*0.05)
        line(d2,(n*0.48,n*0.72),(n*0.64,n*0.5),WHITE+(255,),n*0.05)
    make_icon("ic_daily.png", daily, GOLD, 40, 5)

    def ad(d, img, n):
        box=(n*0.2,n*0.26,n*0.8,n*0.74)
        vgrad_rr(img,n,box,n*0.1,lighten(MINT,0.18),darken(MINT,0.1))
        d2=ImageDraw.Draw(img)
        poly(d2,[(n*0.44,n*0.4),(n*0.44,n*0.6),(n*0.62,n*0.5)],WHITE+(255,))
    make_icon("ic_ad.png", ad, MINT, 45, 5)

    def cash(d, img, n):
        for i,oy in enumerate([0.12,0.0]):
            box=(n*0.2,n*(0.36+oy),n*0.8,n*(0.56+oy))
            vgrad_rr(img,n,box,n*0.04,lighten(GOLD,0.2),darken(GOLD,0.15))
        d2=ImageDraw.Draw(img)
        circle(d2,n*0.5,n*0.46,n*0.08,outline=darken(GOLD,0.3)+(255,),width=int(n*0.02*SS))
        line(d2,(n*0.5,n*0.4),(n*0.5,n*0.52),darken(GOLD,0.3)+(255,),n*0.025)
    make_icon("ic_cash.png", cash, GOLD, 40, 5)

    def vip(d, img, n):
        pts=[(n*0.2,n*0.7),(n*0.24,n*0.36),(n*0.38,n*0.54),(n*0.5,n*0.28),
             (n*0.62,n*0.54),(n*0.76,n*0.36),(n*0.8,n*0.7)]
        poly(d, pts, GOLD+(255,))
        poly(d, [(n*0.2,n*0.7),(n*0.24,n*0.36),(n*0.5,n*0.45)], lighten(GOLD,0.3)+(255,))
        rr(d,(n*0.2,n*0.7,n*0.8,n*0.78),n*0.02,fill=darken(GOLD,0.15)+(255,))
        for gx in (0.34,0.5,0.66):
            circle(d, n*gx, n*0.6, n*0.03, fill=WHITE+(180,))
    make_icon("ic_vip.png", vip, GOLD, 45, 5)

    def streak(d, img, n):
        flame=(n*0.32,n*0.18,n*0.68,n*0.86)
        # flame shape via gradient ellipse-ish polygon mask
        pts=[(n*0.5,n*0.14),(n*0.7,n*0.46),(n*0.66,n*0.72),(n*0.5,n*0.88),
             (n*0.34,n*0.72),(n*0.3,n*0.46)]
        m=Image.new("L",img.size,0)
        ImageDraw.Draw(m).polygon([(p[0]*SS,p[1]*SS) for p in pts],fill=255)
        img.alpha_composite(vgrad_mask(n, ORANGE, GOLD, m))
        d2=ImageDraw.Draw(img)
        # inner hot core
        ip=[(n*0.5,n*0.4),(n*0.6,n*0.6),(n*0.5,n*0.78),(n*0.4,n*0.6)]
        poly(d2, ip, lighten(GOLD,0.4)+(230,))
        poly(d2, [(n*0.5,n*0.52),(n*0.55,n*0.64),(n*0.5,n*0.74),(n*0.45,n*0.64)], WHITE+(220,))
    make_icon("ic_streak.png", streak, ORANGE, 45, 5)

    def check(d, img, n):
        circle(d, n/2, n/2, n*0.4, fill=MINT+(255,))
        circle(d, n/2, n/2, n*0.4, outline=lighten(MINT,0.3)+(200,), width=int(n*0.012*SS))
        line(d,(n*0.34,n*0.52),(n*0.46,n*0.66),WHITE+(255,),n*0.06)
        line(d,(n*0.46,n*0.66),(n*0.68,n*0.36),WHITE+(255,),n*0.06)
        gloss_cap(img,n,(n*0.1,n*0.1,n*0.9,n*0.9),70)
    make_icon("ic_check.png", check, MINT, 45, 5)

    def lock(d, img, n):
        # shackle
        d.arc([(n*0.32)*SS,(n*0.18)*SS,(n*0.68)*SS,(n*0.58)*SS],180,360,
              fill=lighten(MUTED,0.2)+(255,),width=int(n*0.06*SS))
        body=(n*0.28,n*0.42,n*0.72,n*0.82)
        vgrad_rr(img,n,body,n*0.06,lighten(MUTED,0.2),darken(MUTED,0.15))
        d2=ImageDraw.Draw(img)
        circle(d2, n*0.5, n*0.58, n*0.06, fill=SHADOW+(255,))
        d2.rectangle([(n*0.48)*SS,(n*0.58)*SS,(n*0.52)*SS,(n*0.72)*SS],fill=SHADOW+(255,))
    make_icon("ic_lock.png", lock)  # no glow (locked=dim)

    def warp(d, img, n):
        for i,ox in enumerate([0.0,0.22]):
            poly(d, [(n*(0.26+ox),n*0.3),(n*(0.5+ox),n*0.5),(n*(0.26+ox),n*0.7)], CYAN+(255,))
            line(d,(n*(0.26+ox),n*0.3),(n*(0.5+ox),n*0.5),WHITE+(140,),n*0.012)
        circle(d, n*0.74, n*0.3, n*0.1, outline=CYAN+(220,), width=int(n*0.02*SS))
        line(d,(n*0.74,n*0.3),(n*0.74,n*0.24),CYAN+(220,),n*0.02)
    make_icon("ic_warp.png", warp, CYAN, 40, 5)

    def city(d, img, n):
        xs=[0.24,0.42,0.6]; hs=[0.32,0.5,0.4]
        for i,x in enumerate(xs):
            bx=(n*x,n*(0.8-hs[i]),n*(x+0.14),n*0.84)
            vgrad_rr(img,n,bx,n*0.03,lighten(CYAN,0.2),darken(CYAN,0.2))
        d2=ImageDraw.Draw(img)
        circle(d2,n*0.48,n*0.4,n*0.02,fill=GOLD+(255,))
        circle(d2,n*0.66,n*0.5,n*0.02,fill=GOLD+(255,))
    make_icon("ic_city.png", city, CYAN, 40, 5)

    def achieve(d, img, n):
        cup=(n*0.3,n*0.2,n*0.7,n*0.5)
        vgrad_rr(img,n,cup,n*0.06,lighten(GOLD,0.2),darken(GOLD,0.15))
        d2=ImageDraw.Draw(img)
        d2.arc([(n*0.16)*SS,(n*0.22)*SS,(n*0.38)*SS,(n*0.5)*SS],90,270,fill=GOLD+(255,),width=int(n*0.04*SS))
        d2.arc([(n*0.62)*SS,(n*0.22)*SS,(n*0.84)*SS,(n*0.5)*SS],270,90,fill=GOLD+(255,),width=int(n*0.04*SS))
        line(d2,(n*0.5,n*0.5),(n*0.5,n*0.68),GOLD+(255,),n*0.05)
        rr(d2,(n*0.36,n*0.68,n*0.64,n*0.78),n*0.02,fill=darken(GOLD,0.1)+(255,))
        line(d2,(n*0.4,n*0.26),(n*0.46,n*0.42),WHITE+(180,),n*0.025)
    make_icon("ic_achieve.png", achieve, GOLD, 45, 5)

# ---------------------------------------------------------------- particles
def particle_spark(n=24):
    img = canvas(n); d = ImageDraw.Draw(img)
    sparkle(d, n, n/2, n/2, n*0.42, WHITE, 255)
    img = glow(img, WHITE, 3, 120)
    finish(img, n, "spark.png")

def particle_star(n=24):
    img = canvas(n); d = ImageDraw.Draw(img)
    cx=cy=n/2; s=n*0.42; inr=s*0.42
    pts=[]
    for k in range(8):
        a=math.radians(k*45-90)
        r=s if k%2==0 else inr
        pts.append((cx+math.cos(a)*r, cy+math.sin(a)*r))
    poly(d, pts, WHITE+(255,))
    img = glow(img, WHITE, 2.5, 120)
    finish(img, n, "star.png")

def particle_dot(n=16):
    img = canvas(n)
    cx=cy=n/2; rad=n*0.42
    # radial falloff core->rim
    lay = Image.new("RGBA", img.size, (0,0,0,0))
    steps=18
    for i in range(steps):
        t=i/(steps-1)
        r=rad*(1-t)
        a=int(255*(1-t)**1.6)
        circle(ImageDraw.Draw(lay), cx, cy, max(0.5,r), fill=WHITE+(a,))
    img.alpha_composite(lay)
    finish(img, n, "dot.png")

def particle_ring(n=128):
    img = canvas(n); d = ImageDraw.Draw(img)
    cx=cy=n/2
    circle(d, cx, cy, n*0.4, outline=WHITE+(255,), width=int(n*0.03*SS))
    img = glow(img, WHITE, 5, 150)
    finish(img, n, "ring.png")

def particle_coin(n=32):
    img = canvas(n)
    cx=cy=n/2; rad=n*0.4
    vgrad_ellipse(img, n, cx, cy, rad, rad, lighten(GOLD,0.3), darken(GOLD,0.12))
    d=ImageDraw.Draw(img)
    circle(d, cx, cy, rad, outline=WHITE+(160,), width=int(n*0.02*SS))
    circle(d, cx, cy, rad*0.78, outline=darken(GOLD,0.2)+(220,), width=int(n*0.04*SS))
    # shine arc top-left
    d.arc([(cx-rad*0.6)*SS,(cy-rad*0.6)*SS,(cx+rad*0.6)*SS,(cy+rad*0.6)*SS],
          200,290,fill=WHITE+(180,),width=int(n*0.04*SS))
    gloss_cap(img,n,(cx-rad,cy-rad,cx+rad,cy+rad),70)
    img = add_shadow(img, 2, 2, 80)
    finish(img, n, "coin.png")

def particle_gem(n=32):
    img = canvas(n); d = ImageDraw.Draw(img)
    gem_shape(d, n, CYAN, half=0.3)
    sparkle(d, n, n*0.36, n*0.34, n*0.07, WHITE, 240)
    img = glow(img, CYAN, 3, 45)
    finish(img, n, "gem_particle.png")

# ---------------------------------------------------------------- atmosphere
def atm_vignette(n=256):
    img = Image.new("RGBA", (n, n), (0,0,0,0))
    px = img.load()
    cx=cy=n/2; maxd=math.hypot(cx,cy)
    for y in range(n):
        for x in range(n):
            t=math.hypot(x-cx,y-cy)/maxd
            a=int(max(0, (t-0.4)/0.6)**1.8 * 140)
            px[x,y]=VOID+(a,)
    img.save(os.path.join(ART,"vignette.png"))

def atm_grid(n=64):
    img = Image.new("RGBA", (n*SS, n*SS), (0,0,0,0)); d=ImageDraw.Draw(img)
    d.line([0,0,0,n*SS],fill=HAIRLINE+(40,),width=max(1,int(0.5*SS)))
    d.line([0,0,n*SS,0],fill=HAIRLINE+(40,),width=max(1,int(0.5*SS)))
    circle(d, 0, 0, 1.4, fill=HAIRLINE+(90,))
    circle(d, n, 0, 1.4, fill=HAIRLINE+(90,))
    circle(d, 0, n, 1.4, fill=HAIRLINE+(90,))
    circle(d, n, n, 1.4, fill=HAIRLINE+(90,))
    img.resize((n,n),Image.LANCZOS).save(os.path.join(ART,"grid_tile.png"))

def atm_aurora(n=512):
    h=int(n*0.5)
    img=Image.new("RGBA",(n,h),(0,0,0,0))
    grad=Image.new("RGBA",(n,1)); gp=grad.load()
    for x in range(n):
        t=x/(n-1)
        if t<0.5:
            c=lerp(SKY,CYAN,t*2); a=int((30+(20-30)*(t*2)))
        else:
            c=CYAN; a=int(20*(1-(t-0.5)*2))
        gp[x,0]=c+(max(0,a),)
    grad=grad.resize((n,h))
    # vertical falloff
    vmask=Image.new("L",(n,h),0); vp=vmask.load()
    for y in range(h):
        ty=abs(y-h/2)/(h/2)
        v=int(255*(1-ty)**1.5)
        for x in range(n): vp[x,y]=v
    img.paste(grad,(0,0),vmask)
    img=img.filter(ImageFilter.GaussianBlur(28))
    img.save(os.path.join(ART,"aurora_band.png"))

def atm_sun(n=384):
    img=Image.new("RGBA",(n,n),(0,0,0,0)); px=img.load()
    cx=cy=n/2; maxd=n/2
    for y in range(n):
        for x in range(n):
            t=math.hypot(x-cx,y-cy)/maxd
            a=int(max(0,(1-t))**2.4 * 40)
            px[x,y]=GOLD+(a,)
    img=img.filter(ImageFilter.GaussianBlur(20))
    img.save(os.path.join(ART,"sun_glow.png"))

# ---------------------------------------------------------------- app icon
def app_icon(n=512):
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    base = Image.new("RGBA", (n, n)); bp=base.load()
    for y in range(n):
        c=lerp(SKY,CYAN,y/(n-1));
        for x in range(n): bp[x,y]=c+(255,)
    mask = Image.new("L", (n, n), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0,0,n,n], radius=int(n*0.22), fill=255)
    img.paste(base, (0, 0), mask)
    # radial white glow center
    gl=Image.new("RGBA",(n,n),(0,0,0,0)); gp=gl.load()
    cx=cy=n/2
    for y in range(n):
        for x in range(n):
            t=math.hypot(x-cx,y-cy)/(n/2)
            a=int(max(0,(1-t))**2.5*120)
            gp[x,y]=WHITE+(a,)
    img.alpha_composite(gl)
    # star dots
    d=ImageDraw.Draw(img)
    for sx,sy,s in [(0.2,0.22,5),(0.8,0.3,4),(0.72,0.74,3)]:
        d.ellipse([sx*n-s,sy*n-s,sx*n+s,sy*n+s],fill=WHITE+(220,))
    # hero white drone (no navy shadow box) + gold package
    drone("appdrone_tmp.png", INK, 96, shadow=False)
    dr=Image.open(os.path.join(ART,"appdrone_tmp.png")).resize((int(n*0.6),int(n*0.6)),Image.LANCZOS)
    # soft white halo behind hero drone
    halo=Image.new("RGBA",(n,n),(0,0,0,0))
    ImageDraw.Draw(halo).ellipse([n*0.24,n*0.18,n*0.76,n*0.62],fill=WHITE+(70,))
    halo=halo.filter(ImageFilter.GaussianBlur(22))
    halo.putalpha(Image.composite(halo.split()[3],Image.new("L",(n,n),0),mask))
    img.alpha_composite(halo)
    img.alpha_composite(dr,(int(n*0.2),int(n*0.12)))
    pk=package(save=False).resize((int(n*0.26),int(n*0.26)),Image.LANCZOS)
    img.alpha_composite(pk,(int(n*0.37),int(n*0.62)))
    # inner vignette + bottom drop
    vg=Image.new("RGBA",(n,n),(0,0,0,0)); vp=vg.load()
    for y in range(n):
        for x in range(n):
            t=math.hypot(x-cx,y-cy)/(n/2)
            a=int(max(0,(t-0.55)/0.45)**2*90)
            vp[x,y]=SHADOW+(a,)
    vg.putalpha(Image.composite(vg.split()[3],Image.new("L",(n,n),0),mask))
    img.alpha_composite(vg)
    img.save(os.path.join(os.path.dirname(__file__),"..","appicon.png"))
    os.remove(os.path.join(ART,"appdrone_tmp.png"))

# ---------------------------------------------------------------- montage
def montage():
    files = sorted([f for f in os.listdir(ART) if f.endswith(".png")])
    cols = 8; cell = 96; rows = (len(files)+cols-1)//cols
    pad = 18
    sheet = Image.new("RGBA", (cols*cell, rows*cell + pad), (0,0,0,0))
    # dashboard backdrop gradient
    bp=sheet.load()
    for y in range(sheet.height):
        c=lerp(VOID, MIDNIGHT, y/max(1,sheet.height-1))
        for x in range(sheet.width): bp[x,y]=c+(255,)
    for i, f in enumerate(files):
        im = Image.open(os.path.join(ART, f)).convert("RGBA")
        sc = min(80/max(1, im.width), 80/max(1, im.height))
        im2 = im.resize((max(1,int(im.width*sc)), max(1,int(im.height*sc))), Image.LANCZOS)
        x = (i % cols)*cell + (cell-im2.width)//2
        y = (i//cols)*cell + (cell-im2.height)//2
        sheet.alpha_composite(im2, (x, y))
    sheet.convert("RGB").save(os.path.join(os.path.dirname(__file__), "_montage.png"))
    print("MONTAGE files:", len(files))

if __name__ == "__main__":
    drone("drone_blue.png", SKY)
    drone("drone_teal.png", CYAN)
    drone("drone_amber.png", AMBER)
    package()
    hub_home()
    hub_city("hub_city.png", SKY)
    hub_city("hub_city2.png", VIOLET, antenna=True)
    cloud()
    gen_icons()
    particle_spark(); particle_star(); particle_dot()
    particle_ring(); particle_coin(); particle_gem()
    atm_vignette(); atm_grid(); atm_aurora(); atm_sun()
    app_icon()
    montage()
    print("DONE ->", ART)
