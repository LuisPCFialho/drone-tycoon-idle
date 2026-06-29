#!/usr/bin/env python3
"""Flat, modern (material-ish) asset generator for Drone Tycoon: Sky Fleet.
Supersampled (anti-aliased) PNGs -> assets/art/. Run: python tools/gen_art.py
"""
import os, math, random
from PIL import Image, ImageDraw, ImageFilter

random.seed(11)
SS = 4
ART = os.path.join(os.path.dirname(__file__), "..", "assets", "art")
os.makedirs(ART, exist_ok=True)

# palette
INK = (15, 23, 42)
SLATE = (51, 65, 85)
SLATE_D = (30, 41, 59)
SLATE_L = (100, 116, 139)
WHITE = (255, 255, 255)
BLUE = (59, 130, 246)
BLUE_D = (37, 99, 235)
TEAL = (20, 184, 166)
AMBER = (245, 158, 11)
GOLD = (251, 191, 36)
CYAN = (34, 211, 238)
VIOLET = (139, 92, 246)
GREEN = (34, 197, 94)
RED = (239, 68, 68)

def canvas(n):
	return Image.new("RGBA", (n * SS, n * SS), (0, 0, 0, 0))

def finish(img, n, name):
	img.resize((n, n), Image.LANCZOS).save(os.path.join(ART, name))

def rr(d, box, r, **kw):
	d.rounded_rectangle([box[0]*SS, box[1]*SS, box[2]*SS, box[3]*SS], radius=r*SS, **kw)

def circle(d, cx, cy, rad, **kw):
	d.ellipse([(cx-rad)*SS, (cy-rad)*SS, (cx+rad)*SS, (cy+rad)*SS], **kw)

def add_shadow(img, blur, dy, alpha=110):
	a = img.split()[3].point(lambda v: alpha if v > 30 else 0)
	sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
	sh.putalpha(a)
	sh = Image.composite(Image.new("RGBA", img.size, (10, 15, 30, 255)), Image.new("RGBA", img.size, (0,0,0,0)), a)
	sh = sh.filter(ImageFilter.GaussianBlur(blur * SS))
	out = Image.new("RGBA", img.size, (0, 0, 0, 0))
	out.alpha_composite(sh, (0, int(dy * SS)))
	out.alpha_composite(img)
	return out

# ----------------------------------------------------------------- drone
def drone(name, accent, n=96):
	img = canvas(n)
	d = ImageDraw.Draw(img)
	c = n / 2.0
	R = n * 0.30
	rotors = [(c-R, c-R), (c+R, c-R), (c-R, c+R), (c+R, c+R)]
	# arms
	for rx, ry in rotors:
		d.line([(c*SS, c*SS), (rx*SS, ry*SS)], fill=SLATE_D + (255,), width=int(n*0.06*SS))
	# rotor discs (motion blur) + housings
	for rx, ry in rotors:
		circle(d, rx, ry, n*0.20, fill=accent + (70,))
		circle(d, rx, ry, n*0.20, outline=accent + (180,), width=int(n*0.015*SS))
		circle(d, rx, ry, n*0.075, fill=SLATE + (255,))
		circle(d, rx, ry, n*0.03, fill=INK + (255,))
	# body
	bs = n * 0.17
	rr(d, (c-bs, c-bs, c+bs, c+bs), n*0.07, fill=SLATE + (255,))
	rr(d, (c-bs, c-bs, c+bs, c-bs*0.1), n*0.07, fill=accent + (255,))
	# camera lens
	circle(d, c, c+bs*0.35, n*0.06, fill=INK + (255,))
	circle(d, c, c+bs*0.35, n*0.028, fill=accent + (255,))
	# highlight
	circle(d, c-bs*0.4, c-bs*0.4, n*0.03, fill=WHITE + (140,))
	img = add_shadow(img, 5, 5, 120)
	finish(img, n, name)

# ----------------------------------------------------------------- package
def package(n=44):
	img = canvas(n); d = ImageDraw.Draw(img)
	rr(d, (n*0.18, n*0.18, n*0.82, n*0.82), n*0.12, fill=AMBER + (255,))
	rr(d, (n*0.18, n*0.18, n*0.82, n*0.42), n*0.12, fill=(255, 190, 70, 255))
	d.line([(n*0.5*SS, n*0.18*SS), (n*0.5*SS, n*0.82*SS)], fill=(180, 110, 20, 255), width=int(n*0.05*SS))
	d.line([(n*0.18*SS, n*0.4*SS), (n*0.82*SS, n*0.4*SS)], fill=(180, 110, 20, 255), width=int(n*0.04*SS))
	img = add_shadow(img, 3, 3, 110)
	finish(img, n, "package.png")

# ----------------------------------------------------------------- hubs
def hub_home(n=128):
	img = canvas(n); d = ImageDraw.Draw(img)
	rr(d, (n*0.1, n*0.18, n*0.9, n*0.92), n*0.12, fill=WHITE + (255,))
	rr(d, (n*0.1, n*0.18, n*0.9, n*0.34), n*0.12, fill=TEAL + (255,))
	# landing target
	circle(d, n*0.5, n*0.62, n*0.26, outline=TEAL + (255,), width=int(n*0.03*SS))
	circle(d, n*0.5, n*0.62, n*0.15, outline=TEAL + (180,), width=int(n*0.025*SS))
	# H
	hw = n*0.05
	d.line([(n*0.43*SS, n*0.52*SS), (n*0.43*SS, n*0.72*SS)], fill=TEAL + (255,), width=int(hw*SS))
	d.line([(n*0.57*SS, n*0.52*SS), (n*0.57*SS, n*0.72*SS)], fill=TEAL + (255,), width=int(hw*SS))
	d.line([(n*0.43*SS, n*0.62*SS), (n*0.57*SS, n*0.62*SS)], fill=TEAL + (255,), width=int(hw*SS))
	img = add_shadow(img, 6, 6, 120)
	finish(img, n, "hub_home.png")

def hub_city(name, base_col, n=128):
	img = canvas(n); d = ImageDraw.Draw(img)
	rr(d, (n*0.08, n*0.55, n*0.92, n*0.95), n*0.08, fill=WHITE + (255,))
	# buildings
	cols = [base_col, tuple(min(255,x+30) for x in base_col), tuple(max(0,x-25) for x in base_col)]
	xs = [0.16, 0.36, 0.56, 0.74]
	hs = [0.30, 0.46, 0.22, 0.38]
	for i, x in enumerate(xs):
		bh = hs[i]
		rr(d, (x*n, (0.62-bh)*n, (x+0.16)*n, 0.7*n), n*0.03, fill=cols[i % 3] + (255,))
		for wy in range(1, int(bh*10), 2):
			d.rectangle([((x+0.04)*n)*SS, ((0.62-bh+wy*0.05)*n)*SS, ((x+0.07)*n)*SS, ((0.62-bh+wy*0.05+0.02)*n)*SS], fill=(255,255,255,150))
	# pad
	circle(d, n*0.5, n*0.8, n*0.1, outline=base_col + (255,), width=int(n*0.025*SS))
	img = add_shadow(img, 6, 6, 120)
	finish(img, n, name)

# ----------------------------------------------------------------- cloud
def cloud(n=120):
	img = Image.new("RGBA", (n*SS, int(n*0.6)*SS), (0, 0, 0, 0)); d = ImageDraw.Draw(img)
	for cx, cy, r in [(0.32,0.55,0.22),(0.5,0.42,0.28),(0.68,0.55,0.22),(0.5,0.62,0.3)]:
		d.ellipse([(cx-r)*n*SS,(cy-r)*n*SS,(cx+r)*n*SS,(cy+r)*n*SS], fill=(255,255,255,235))
	img.resize((n, int(n*0.6)), Image.LANCZOS).save(os.path.join(ART, "cloud.png"))

# ----------------------------------------------------------------- icons
def ic(name, fn, n=48):
	img = canvas(n); d = ImageDraw.Draw(img); fn(d, n)
	finish(img, n, "ic_" + name + ".png")

def gem_shape(d, n, col):
	cx = n/2
	pts = [(cx, n*0.12), (n*0.82, n*0.42), (cx, n*0.88), (n*0.18, n*0.42)]
	d.polygon([(p[0]*SS, p[1]*SS) for p in pts], fill=col + (255,))
	d.polygon([(cx*SS, n*0.12*SS), (n*0.82*SS, n*0.42*SS), (cx*SS, n*0.5*SS)], fill=tuple(min(255,x+40) for x in col) + (255,))
	d.polygon([(cx*SS, n*0.12*SS), (n*0.18*SS, n*0.42*SS), (cx*SS, n*0.5*SS)], fill=tuple(min(255,x+70) for x in col) + (255,))

def gen_icons():
	def credits(d, n):
		circle(d, n/2, n/2, n*0.36, fill=GOLD + (255,))
		circle(d, n/2, n/2, n*0.36, outline=(200,150,20,255), width=int(n*0.04*SS))
		circle(d, n/2, n/2, n*0.2, outline=(255,225,140,255), width=int(n*0.05*SS))
	ic("credits", credits)
	ic("gems", lambda d, n: gem_shape(d, n, CYAN))
	ic("prestige", lambda d, n: gem_shape(d, n, VIOLET))
	def income(d, n):
		for i, h in enumerate([0.2, 0.34, 0.5]):
			rr(d, (n*(0.2+i*0.22), n*(0.78-h), n*(0.34+i*0.22), n*0.8), n*0.03, fill=GREEN + (255,))
	ic("income", income)
	def speed(d, n):
		pts = [(n*0.55,n*0.1),(n*0.28,n*0.55),(n*0.46,n*0.55),(n*0.38,n*0.9),(n*0.72,n*0.42),(n*0.52,n*0.42)]
		d.polygon([(p[0]*SS,p[1]*SS) for p in pts], fill=AMBER + (255,))
	ic("speed", speed)
	def cargo(d, n):
		rr(d, (n*0.2,n*0.28,n*0.8,n*0.78), n*0.08, fill=AMBER + (255,))
		d.line([(n*0.5*SS,n*0.28*SS),(n*0.5*SS,n*0.78*SS)], fill=(180,110,20,255), width=int(n*0.05*SS))
	ic("cargo", cargo)
	def value(d, n):
		pts=[(n*0.16,n*0.16),(n*0.55,n*0.16),(n*0.86,n*0.5),(n*0.5,n*0.86),(n*0.16,n*0.55)]
		d.polygon([(p[0]*SS,p[1]*SS) for p in pts], fill=TEAL+(255,))
		circle(d, n*0.34, n*0.34, n*0.06, fill=WHITE+(255,))
	ic("value", value)
	def drone_ic(d, n):
		c=n/2; R=n*0.26
		for rx,ry in [(c-R,c-R),(c+R,c-R),(c-R,c+R),(c+R,c+R)]:
			d.line([(c*SS,c*SS),(rx*SS,ry*SS)], fill=SLATE_D+(255,), width=int(n*0.05*SS))
			circle(d, rx, ry, n*0.12, fill=BLUE+(200,))
		circle(d, c, c, n*0.13, fill=SLATE+(255,))
	ic("drone", drone_ic)
	def rng(d, n):
		circle(d, n/2, n*0.42, n*0.26, fill=BLUE+(255,))
		d.polygon([(n*0.3*SS,n*0.55*SS),(n*0.7*SS,n*0.55*SS),(n*0.5*SS,n*0.9*SS)], fill=BLUE+(255,))
		circle(d, n/2, n*0.42, n*0.1, fill=WHITE+(255,))
	ic("range", rng)
	def gear(d, n):
		circle(d, n/2, n/2, n*0.3, fill=SLATE_L+(255,))
		for a in range(0,360,45):
			x=n/2+math.cos(math.radians(a))*n*0.34; y=n/2+math.sin(math.radians(a))*n*0.34
			circle(d, x, y, n*0.08, fill=SLATE_L+(255,))
		circle(d, n/2, n/2, n*0.12, fill=INK+(255,))
	ic("gear", gear)
	def boost(d, n):
		pts=[(n*0.5,n*0.1),(n*0.72,n*0.5),(n*0.58,n*0.5),(n*0.58,n*0.9),(n*0.42,n*0.9),(n*0.42,n*0.5),(n*0.28,n*0.5)]
		d.polygon([(p[0]*SS,p[1]*SS) for p in pts], fill=GREEN+(255,))
	ic("boost", boost)

# ----------------------------------------------------------------- app icon
def app_icon(n=512):
	img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
	big = Image.new("RGBA", (n, n), (0, 0, 0, 0)); d = ImageDraw.Draw(big)
	for y in range(n):
		t = y / n
		c = (int(59+(20-59)*t), int(130+(160-130)*t), int(246+(230-246)*t))
		d.line([(0, y), (n, y)], fill=c + (255,))
	mask = Image.new("L", (n, n), 0)
	ImageDraw.Draw(mask).rounded_rectangle([0, 0, n, n], radius=int(n*0.22), fill=255)
	img.paste(big, (0, 0), mask)
	drone("appdrone_tmp.png", WHITE, 96)
	dr = Image.open(os.path.join(ART, "appdrone_tmp.png")).resize((int(n*0.62), int(n*0.62)), Image.LANCZOS)
	img.alpha_composite(dr, (int(n*0.19), int(n*0.14)))
	pk = Image.open(os.path.join(ART, "package.png")).resize((int(n*0.26), int(n*0.26)), Image.LANCZOS)
	img.alpha_composite(pk, (int(n*0.37), int(n*0.6)))
	img.save(os.path.join(os.path.dirname(__file__), "..", "appicon.png"))
	os.remove(os.path.join(ART, "appdrone_tmp.png"))

# ----------------------------------------------------------------- montage
def montage():
	files = sorted([f for f in os.listdir(ART) if f.endswith(".png")])
	cols = 7; cell = 90; rows = (len(files)+cols-1)//cols
	sheet = Image.new("RGBA", (cols*cell, rows*cell), (200, 214, 230, 255))
	for i, f in enumerate(files):
		im = Image.open(os.path.join(ART, f)).convert("RGBA")
		sc = min(78/max(1, im.width), 78/max(1, im.height))
		im2 = im.resize((max(1,int(im.width*sc)), max(1,int(im.height*sc))), Image.LANCZOS)
		x = (i % cols)*cell + (cell-im2.width)//2
		y = (i//cols)*cell + (cell-im2.height)//2
		sheet.alpha_composite(im2, (x, y))
	sheet.save(os.path.join(os.path.dirname(__file__), "_montage.png"))
	print("MONTAGE files:", len(files))

if __name__ == "__main__":
	drone("drone_blue.png", BLUE)
	drone("drone_teal.png", TEAL)
	drone("drone_amber.png", AMBER)
	package()
	hub_home()
	hub_city("hub_city.png", BLUE)
	hub_city("hub_city2.png", VIOLET)
	cloud()
	gen_icons()
	app_icon()
	montage()
	print("DONE ->", ART)
