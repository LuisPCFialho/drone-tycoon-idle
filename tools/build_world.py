#!/usr/bin/env python3
"""Builds data/world.json for Drone Tycoon: real country outlines (Natural Earth
50m) + cities projected from real lat/lon, normalized per country.

Inputs:  scratchpad/ne110.geojson (actually 50m), scratchpad/cities.json
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

# Replace island/outlier cities with nearby mainland alternatives.
# Format: country_name -> {old_name: (new_name, lat, lon)}
CITY_OVERRIDES = {
    "Portugal": {
        "Funchal": ("Setubal", 38.524, -8.894),          # Madeira -> mainland
    },
    "Greece": {
        "Rhodes": ("Volos", 39.365, 22.942),              # Dodecanese -> Thessaly coast
        "Heraklion": ("Kavala", 41.134, 24.402),          # Crete -> Macedonia coast
    },
    "Japan": {
        "Sapporo": ("Kanazawa", 36.561, 136.656),         # Hokkaido -> Honshu west coast
        "Fukuoka": ("Hamamatsu", 34.710, 137.726),        # Kyushu -> Honshu coast
    },
    "Indonesia": {
        "Medan": ("Bogor", -6.595, 106.816),              # Sumatra -> Java (unique)
        "Makassar": ("Semarang", -6.967, 110.416),        # Sulawesi -> Java
        "Denpasar": ("Malang", -7.966, 112.632),          # Bali -> Java east
        "Jayapura": ("Yogyakarta", -7.797, 110.370),      # Papua -> Java central
    },
    "Denmark": {
        "Copenhagen": ("Fredericia", 55.566, 9.756),      # Zealand island -> Jutland
        "Ronne": ("Horsens", 55.860, 9.852),              # Bornholm island -> Jutland
    },
    "Russia": {
        "Kaliningrad": ("Volgograd", 48.708, 44.513),     # exclave -> mainland
    },
    "Argentina": {
        "Ushuaia": ("Tucuman", -26.808, -65.218),         # Tierra del Fuego -> mainland
    },
}

def load_features():
    d = json.load(open(GEO, encoding="utf-8"))
    feats = {}
    for f in d["features"]:
        p = f["properties"]
        # Only country's own name (NOT SOVEREIGNT — territories share sovereign
        # name and steal the key, e.g. US Pacific territories → USA).
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
    """Select the ring that draws the correct territory to show.

    Priority order:
    1. Contains the capital (cities[0]) — ensures Denmark shows Zealand+Copenhagen,
       Japan shows Honshu+Tokyo, etc., not a distant peninsula/island by area.
    2. Contains the most cities (tiebreak for tie on capital).
    3. Largest area (final tiebreak).
    """
    t = geom["type"]; coords = geom["coordinates"]
    rings = []
    if t == "Polygon":
        rings.append(coords[0])
    elif t == "MultiPolygon":
        for poly in coords:
            rings.append(poly[0])
    rings = [r for r in rings if len(r) >= 4]

    capital_lon = cities[0]["lon"] if cities else 0.0
    capital_lat = cities[0]["lat"] if cities else 0.0

    def score(r):
        has_capital = 1 if point_in_poly(capital_lon, capital_lat, r) else 0
        n_cities = sum(1 for c in cities if point_in_poly(c["lon"], c["lat"], r))
        return (has_capital, n_cities, ring_area(r))

    return max(rings, key=score)

def perp_dist(p, a, b):
    (x, y), (x1, y1), (x2, y2) = p, a, b
    dx, dy = x2 - x1, y2 - y1
    if dx == 0 and dy == 0:
        return math.hypot(x - x1, y - y1)
    t = ((x - x1) * dx + (y - y1) * dy) / (dx * dx + dy * dy)
    t = max(0.0, min(1.0, t))
    return math.hypot(x - (x1 + t * dx), y - (y1 + t * dy))

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
    while len(out) > 140:
        eps *= 1.4
        out = dp(pts, eps)
    return out

def apply_overrides(country_name, cities):
    overrides = CITY_OVERRIDES.get(country_name, {})
    result = []
    for c in cities:
        if c["name"] in overrides:
            new_name, new_lat, new_lon = overrides[c["name"]]
            c = dict(c, name=new_name, lat=new_lat, lon=new_lon)
            print("  override: %s %s -> %s" % (country_name, c['name'], new_name))
        result.append(c)
    return result

def build():
    feats = load_features()
    cities_data = json.load(open(CITIES, encoding="utf-8"))["countries"]
    world = {"countries": []}
    missing = []
    bad_cities = []

    for tier, cd in enumerate(cities_data):
        name = cd["name"]
        feat = find_feature(feats, name)
        if not feat:
            missing.append(name); continue

        # Apply city overrides before ring selection (ring scoring uses city coords)
        raw_cities = apply_overrides(name, cd["cities"])

        ring = simplify(mainland_ring(feat["geometry"], raw_cities))

        # Antimeridian unwrap (Russia, etc.)
        lons = [p[0] for p in ring]
        if max(lons) - min(lons) > 180:
            ring = [(p[0] + 360 if p[0] < 0 else p[0], p[1]) for p in ring]

        # Projection: equirectangular with cos(lat) aspect correction
        lons = [p[0] for p in ring]; lats = [p[1] for p in ring]
        lon_min, lon_max = min(lons), max(lons)
        lat_min, lat_max = min(lats), max(lats)
        mean_lat = (lat_min + lat_max) * 0.5
        k = math.cos(math.radians(mean_lat))
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
        for c in raw_cities:
            lon = c["lon"] + 360 if (max(lons) > 180 and c["lon"] < 0) else c["lon"]
            xy = proj(lon, c["lat"])
            cities.append({"name": c["name"], "x": xy[0], "y": xy[1], "capital": bool(c.get("capital", False))})

        # Flag cities that ended up clamped at the edges (projection outliers)
        for ci in cities:
            if ci["x"] <= 0.04 or ci["x"] >= 0.96 or ci["y"] <= 0.04 or ci["y"] >= 0.96:
                bad_cities.append(f"{name}/{ci['name']} ({ci['x']:.2f},{ci['y']:.2f})")

        world["countries"].append({"name": name, "tier": tier, "outline": outline, "cities": cities})

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    json.dump(world, open(OUT, "w", encoding="utf-8"), ensure_ascii=False)
    print(f"countries: {len(world['countries'])}  missing: {missing}")
    sizes = [len(c['outline']) for c in world['countries']]
    print(f"outline pts min/avg/max: {min(sizes)} {sum(sizes)//len(sizes)} {max(sizes)}")
    if bad_cities:
        print(f"EDGE-CLAMPED cities ({len(bad_cities)}):", bad_cities)
    else:
        print("All cities within bounds. ✓")

if __name__ == "__main__":
    build()
