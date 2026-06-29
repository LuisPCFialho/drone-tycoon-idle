#!/usr/bin/env python3
"""Builds data/world.json for Drone Tycoon: real country outlines (Natural Earth
110m) + cities projected from real lat/lon, normalized per country.

Inputs:  scratchpad/ne110.geojson, scratchpad/cities.json
Output:  <project>/data/world.json
"""
import json, math, os

SP = os.environ.get("SP", r"C:/Users/LUISFI~1/AppData/Local/Temp/claude/c--Apps/23fd3c88-4b55-441d-bf94-96050388dc41/scratchpad")
PROJ = os.path.join(os.path.dirname(__file__), "..")
GEO = os.path.join(SP, "ne110.geojson")
CITIES = os.path.join(SP, "cities.json")
OUT = os.path.join(PROJ, "data", "world.json")

ALIASES = {
	"United States": ["United States of America", "United States"],
	"Czechia": ["Czechia", "Czech Republic"],
	"South Korea": ["South Korea", "Republic of Korea"],
	"Russia": ["Russia", "Russian Federation"],
	"Turkey": ["Turkey", "Turkiye", "Republic of Turkey"],
}

def load_features():
	d = json.load(open(GEO, encoding="utf-8"))
	feats = {}
	for f in d["features"]:
		p = f["properties"]
		# Only the country's own name (NOT SOVEREIGNT — territories share their
		# sovereign's name and would steal the key, e.g. US Pacific territories).
		for key in ("ADMIN", "NAME_LONG", "NAME", "GEOUNIT"):
			n = p.get(key)
			if n:
				feats.setdefault(n.lower(), f)
	return feats

def find_feature(feats, name):
	cands = ALIASES.get(name, []) + [name]
	for c in cands:
		if c.lower() in feats:
			return feats[c.lower()]
	# substring fallback
	for k, f in feats.items():
		if name.lower() in k or k in name.lower():
			return f
	return None

def ring_area(ring):
	s = 0.0
	for i in range(len(ring) - 1):
		x1, y1 = ring[i]; x2, y2 = ring[i + 1]
		s += x1 * y2 - x2 * y1
	return abs(s) * 0.5

def point_in_poly(lon, lat, ring):
	inside = False; n = len(ring); j = n - 1
	for i in range(n):
		xi, yi = ring[i]; xj, yj = ring[j]
		if ((yi > lat) != (yj > lat)) and (lon < (xj - xi) * (lat - yi) / ((yj - yi) or 1e-12) + xi):
			inside = not inside
		j = i
	return inside

def mainland_ring(geom, cities):
	t = geom["type"]; coords = geom["coordinates"]
	rings = []
	if t == "Polygon":
		rings.append(coords[0])
	elif t == "MultiPolygon":
		for poly in coords:
			rings.append(poly[0])
	rings = [r for r in rings if len(r) >= 4]
	# Prefer the ring that contains the most of the country's cities (correct mainland),
	# tie-broken by area. Avoids antimeridian-distorted rings (e.g. Alaska for USA).
	def score(r):
		inside = sum(1 for c in cities if point_in_poly(c["lon"], c["lat"], r))
		return (inside, ring_area(r))
	return max(rings, key=score)

def perp_dist(p, a, b):
	(x, y), (x1, y1), (x2, y2) = p, a, b
	dx, dy = x2 - x1, y2 - y1
	if dx == 0 and dy == 0:
		return math.hypot(x - x1, y - y1)
	t = ((x - x1) * dx + (y - y1) * dy) / (dx * dx + dy * dy)
	t = max(0.0, min(1.0, t))
	px, py = x1 + t * dx, y1 + t * dy
	return math.hypot(x - px, y - py)

def dp(pts, eps):
	if len(pts) < 3:
		return pts
	dmax, idx = 0.0, 0
	for i in range(1, len(pts) - 1):
		d = perp_dist(pts[i], pts[0], pts[-1])
		if d > dmax:
			dmax, idx = d, i
	if dmax > eps:
		left = dp(pts[:idx + 1], eps); right = dp(pts[idx:], eps)
		return left[:-1] + right
	return [pts[0], pts[-1]]

def simplify(ring):
	pts = [tuple(p) for p in ring]
	xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
	span = max(max(xs) - min(xs), max(ys) - min(ys))
	eps = 0.004 * span
	out = dp(pts, eps)
	# cap point count for performance
	while len(out) > 140:
		eps *= 1.4
		out = dp(pts, eps)
	return out

def build():
	feats = load_features()
	cities_data = json.load(open(CITIES, encoding="utf-8"))["countries"]
	world = {"countries": []}
	missing = []
	for tier, cd in enumerate(cities_data):
		name = cd["name"]
		feat = find_feature(feats, name)
		if not feat:
			missing.append(name); continue
		ring = simplify(mainland_ring(feat["geometry"], cd["cities"]))
		# antimeridian unwrap (e.g. Russia)
		lons = [p[0] for p in ring]
		if max(lons) - min(lons) > 180:
			ring = [(p[0] + 360 if p[0] < 0 else p[0], p[1]) for p in ring]
	# projection setup from outline bbox
		lons = [p[0] for p in ring]; lats = [p[1] for p in ring]
		lon_min, lon_max = min(lons), max(lons)
		lat_min, lat_max = min(lats), max(lats)
		mean_lat = (lat_min + lat_max) * 0.5
		k = math.cos(math.radians(mean_lat))  # longitude aspect correction
		gx_min, gx_max = lon_min * k, lon_max * k
		cx_geo = (gx_min + gx_max) * 0.5; cy_geo = (lat_min + lat_max) * 0.5
		w = max(1e-6, gx_max - gx_min); h = max(1e-6, lat_max - lat_min)
		scale = 0.84 / max(w, h)

		def proj(lon, lat):
			nx = 0.5 + (lon * k - cx_geo) * scale
			ny = 0.5 - (lat - cy_geo) * scale
			return [round(min(0.97, max(0.03, nx)), 4), round(min(0.97, max(0.03, ny)), 4)]

		outline = [proj(p[0], p[1]) for p in ring]
		cities = []
		for c in cd["cities"]:
			lon = c["lon"] + 360 if (max(lons) > 180 and c["lon"] < 0) else c["lon"]
			xy = proj(lon, c["lat"])
			cities.append({"name": c["name"], "x": xy[0], "y": xy[1], "capital": bool(c.get("capital", False))})
		world["countries"].append({"name": name, "tier": tier, "outline": outline, "cities": cities})
	os.makedirs(os.path.dirname(OUT), exist_ok=True)
	json.dump(world, open(OUT, "w", encoding="utf-8"), ensure_ascii=False)
	print("countries:", len(world["countries"]), "missing:", missing)
	print("outline sizes:", [len(c["outline"]) for c in world["countries"][:6]], "...")
	print("sample Portugal cities:", [(c["name"], c["x"], c["y"]) for c in world["countries"][0]["cities"][:4]])

if __name__ == "__main__":
	build()
