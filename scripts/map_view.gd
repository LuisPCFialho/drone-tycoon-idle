extends Control
class_name MapView
## Premium "Aurora Logistics" sky-command map. Draws the current country: real
## outline polygon, geographically-placed cities (capital / active / locked),
## flowing route lanes and delivery drones with trails. Reads GameState/Economy.
## mouse_filter IGNORE, draws via _draw()/queue_redraw(). Performant for mobile.

# --- public API (set every frame by main.gd) ---
var band_top := 150.0
var band_bottom := 760.0

# --- shared pulse clock ---
var _t := 0.0

# --- resources ---
var _font: Font
var _drone_tex: Array = []
var _package: Texture2D
var _cloud: Texture2D
var _hub_home: Texture2D
var _hub_city: Texture2D
var _hub_city2: Texture2D

# --- transient state ---
var _pops: Array = []                 # floating "+credits" labels
var _trails: Dictionary = {}          # drone index -> Array[Vector2] (recent positions)
var _clouds: Array = []               # decorative drifting clouds (parallax)
var _stars: Array = []                # faint ambient star/dust field
var _caustics: Array = []             # animated sea shimmer blobs
var _flash: Dictionary = {}           # city_index -> remaining flash time on delivery

# --- palette (Aurora Logistics) ---
const VOID      := Color(0.027, 0.043, 0.086)   # #070B16
const MIDNIGHT  := Color(0.055, 0.082, 0.149)   # #0E1526
const LAND      := Color(0.10, 0.17, 0.26)
const LAND_HI   := Color(0.17, 0.27, 0.40)
const INK       := Color(0.949, 0.965, 1.0)     # #F2F6FF
const MUTED     := Color(0.529, 0.580, 0.690)   # #8794B0
const SKY       := Color(0.290, 0.549, 1.0)     # #4A8CFF
const CYAN      := Color(0.227, 0.839, 0.941)   # #3AD6F0
const GOLD      := Color(1.0, 0.784, 0.220)     # #FFC838
const MINT      := Color(0.133, 0.816, 0.541)   # #22D08A
const SHADOW    := Color(0.039, 0.059, 0.118)   # #0A0F1E

const POP_CAP := 16
const TRAIL_LEN := 8

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = UITheme.font("Bold")
	_drone_tex = [load("res://assets/art/drone_blue.png"), load("res://assets/art/drone_teal.png"), load("res://assets/art/drone_amber.png")]
	_package = load("res://assets/art/package.png")
	_cloud = load("res://assets/art/cloud.png")
	_hub_home = load("res://assets/art/hub_home.png")
	_hub_city = load("res://assets/art/hub_city.png")
	_hub_city2 = load("res://assets/art/hub_city2.png")
	GameState.delivered.connect(_on_delivered)
	_seed_ambiance()
	set_process(true)

func _seed_ambiance() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	# 3 parallax clouds: depth in {0=far,1=mid,2=near} affects speed/scale/alpha
	for i in range(3):
		_clouds.append({
			"x": rng.randf(),
			"y": rng.randf_range(0.04, 0.34),
			"depth": i,
			"speed": 0.006 + float(i) * 0.006,
			"scale": 0.5 + float(i) * 0.35,
		})
	# faint star/dust field (normalized coords, slow upward drift)
	for _i in range(14):
		_stars.append({
			"x": rng.randf(),
			"y": rng.randf(),
			"r": rng.randf_range(0.8, 2.0),
			"ph": rng.randf() * TAU,
			"sp": rng.randf_range(0.01, 0.025),
		})
	# sea caustic shimmer blobs
	for _i in range(7):
		_caustics.append({
			"x": rng.randf(),
			"y": rng.randf_range(0.35, 0.95),
			"r": rng.randf_range(28.0, 64.0),
			"ph": rng.randf() * TAU,
			"sp": rng.randf_range(0.4, 0.9),
		})

func _process(delta: float) -> void:
	_t += delta
	# advance floating pops
	var keep: Array = []
	for p in _pops:
		p["life"] -= delta
		p["y"] -= 34.0 * delta
		if p["life"] > 0.0:
			keep.append(p)
	_pops = keep
	# drift clouds (wrap)
	for c in _clouds:
		c["x"] += c["speed"] * delta
		if c["x"] > 1.25:
			c["x"] = -0.25
	# decay delivery flashes
	var fk: Dictionary = {}
	for key: int in _flash:
		var rem: float = float(_flash[key]) - delta
		if rem > 0.0:
			fk[key] = rem
	_flash = fk
	queue_redraw()

func _proj(p: Vector2) -> Vector2:
	var bw := size.x
	var bh := band_bottom - band_top
	var side: float = min(bw, bh) * 0.92
	var ox: float = (bw - side) * 0.5
	var oy: float = band_top + (bh - side) * 0.5
	return Vector2(ox + p.x * side, oy + p.y * side)

func _draw() -> void:
	var w := size.x
	var h := band_bottom - band_top
	_draw_sea(w, h)
	_draw_grid(w, h)
	_draw_caustics(w, h)
	_draw_clouds(w, h)
	_draw_stars(w, h)

	var ci := GameState.current_country
	var outline := Economy.country_outline(ci)
	_draw_landmass(outline)

	var cities := Economy.country_cities(ci)
	if cities.is_empty():
		_draw_vignette(w, h)
		_draw_pops()
		return

	var cap := _proj(Vector2(cities[0]["x"], cities[0]["y"]))
	_draw_routes(cap, cities)
	_draw_drones(cap, cities)
	_draw_cities(cap, cities, ci)
	_draw_vignette(w, h)
	_draw_pops()

# ---------------------------------------------------------------- background

func _draw_sea(w: float, h: float) -> void:
	# layered vertical gradient Void(top) -> Midnight(bottom)
	var steps := 40
	for i in range(steps):
		var f := float(i) / float(steps)
		var col := VOID.lerp(MIDNIGHT, f)
		draw_rect(Rect2(0, band_top + h * f, w, h / float(steps) + 1.0), col)

func _draw_grid(w: float, h: float) -> void:
	# perspective dot/line grid converging toward a horizon near band_top
	var line := Color(0.165, 0.212, 0.329, 0.10)   # Hairline, low alpha
	var horizon := band_top + h * 0.06
	# horizontal lines compressing upward
	for i in range(1, 11):
		var f := float(i) / 11.0
		var y := horizon + (band_bottom - horizon) * (f * f)
		draw_line(Vector2(0, y), Vector2(w, y), line, 1.0)
	# converging verticals toward a vanishing point
	var vp := Vector2(w * 0.5, horizon)
	for i in range(0, 11):
		var bx := w * float(i) / 10.0
		draw_line(Vector2(bx, band_bottom), vp.lerp(Vector2(bx, band_bottom), 0.18), Color(line.r, line.g, line.b, 0.07), 1.0)
	# slow downward scanline band (live-console vibe)
	var sweep := fmod(_t * 0.10, 1.0)
	var sy := band_top + h * sweep
	draw_rect(Rect2(0, sy, w, 26.0), Color(CYAN.r, CYAN.g, CYAN.b, 0.04))

func _draw_caustics(w: float, h: float) -> void:
	for c in _caustics:
		var px := float(c["x"]) * w
		var py := band_top + float(c["y"]) * h
		var pulse: float = 0.5 + 0.5 * sin(_t * float(c["sp"]) + float(c["ph"]))
		var a := 0.018 + 0.022 * pulse
		var r: float = float(c["r"]) * (0.85 + 0.15 * pulse)
		draw_circle(Vector2(px, py), r, Color(SKY.r, SKY.g, SKY.b, a))

func _draw_clouds(w: float, h: float) -> void:
	if _cloud == null:
		return
	var cs := Vector2(_cloud.get_width(), _cloud.get_height())
	for c in _clouds:
		var sc: float = float(c["scale"])
		var dim := cs * sc
		var px := float(c["x"]) * (w + dim.x) - dim.x * 0.5
		var py := band_top + float(c["y"]) * h
		var depth: int = int(c["depth"])
		var alpha := 0.10 + 0.06 * float(depth)
		draw_texture_rect(_cloud, Rect2(px, py, dim.x, dim.y), false, Color(1, 1, 1, alpha))

func _draw_stars(w: float, h: float) -> void:
	for s in _stars:
		var drift := fmod(float(s["y"]) - _t * float(s["sp"]), 1.0)
		if drift < 0.0:
			drift += 1.0
		var px := float(s["x"]) * w
		var py := band_top + drift * h
		var tw: float = 0.4 + 0.6 * (0.5 + 0.5 * sin(_t * 1.4 + float(s["ph"])))
		draw_circle(Vector2(px, py), float(s["r"]), Color(CYAN.r, CYAN.g, CYAN.b, 0.18 * tw))

func _draw_vignette(w: float, h: float) -> void:
	# soft radial framing via stacked low-alpha edge rings (cheap, no texture)
	var rect := Rect2(0, band_top, w, h)
	# four soft edge gradients
	var bands := 8
	for i in range(bands):
		var f := float(i) / float(bands)
		var a := 0.07 * (1.0 - f)
		var inset := f * 36.0
		var col := Color(VOID.r, VOID.g, VOID.b, a)
		# top
		draw_rect(Rect2(rect.position.x, rect.position.y + inset, rect.size.x, 6.0), col)
		# bottom
		draw_rect(Rect2(rect.position.x, rect.position.y + rect.size.y - inset - 6.0, rect.size.x, 6.0), col)
		# left
		draw_rect(Rect2(rect.position.x + inset, rect.position.y, 6.0, rect.size.y), col)
		# right
		draw_rect(Rect2(rect.position.x + rect.size.x - inset - 6.0, rect.position.y, 6.0, rect.size.y), col)

# ---------------------------------------------------------------- landmass

func _draw_landmass(outline: PackedVector2Array) -> void:
	if outline.size() < 3:
		return
	var pts := PackedVector2Array()
	for p in outline:
		pts.append(_proj(p))

	# soft outer glow underlay (a few expanding faint strokes)
	var closed := pts
	closed.append(pts[0])
	for g in range(4):
		var gw := 18.0 - float(g) * 4.0
		var ga := 0.05 + 0.03 * float(g)
		draw_polyline(closed, Color(CYAN.r, CYAN.g, CYAN.b, ga), gw, true)

	# filled land with a vertical gradient fake (two stacked polys via tint band)
	draw_colored_polygon(pts, LAND)
	# inner top-light: lighter polygon shrunk toward centroid
	var ctr := _centroid(pts)
	var inner := PackedVector2Array()
	for q in pts:
		inner.append(q.lerp(ctr, 0.10))
	draw_colored_polygon(inner, Color(LAND_HI.r, LAND_HI.g, LAND_HI.b, 0.45))

	# animated holo coastline: wide soft glow + bright thin breathing rim
	var glow := 0.5 + 0.5 * sin(_t * 1.5)
	draw_polyline(closed, Color(SKY.r, SKY.g, SKY.b, 0.20), 6.0, true)
	draw_polyline(closed, Color(CYAN.r, CYAN.g, CYAN.b, 0.55 + 0.30 * glow), 2.2, true)
	# survey corner ticks at each vertex
	for q in pts:
		draw_circle(q, 2.2, Color(CYAN.r, CYAN.g, CYAN.b, 0.45 + 0.25 * glow))

func _centroid(pts: PackedVector2Array) -> Vector2:
	var acc := Vector2.ZERO
	for q in pts:
		acc += q
	return acc / float(max(1, pts.size()))

# ---------------------------------------------------------------- routes

func _draw_routes(cap: Vector2, cities: Array) -> void:
	for r in range(GameState.cities_unlocked):
		var idx: int = 1 + r
		if idx >= cities.size():
			continue
		var cp := _proj(Vector2(cities[idx]["x"], cities[idx]["y"]))
		# wide soft glow lane
		draw_line(cap, cp, Color(SKY.r, SKY.g, SKY.b, 0.10), 8.0)
		# bright core
		draw_line(cap, cp, Color(CYAN.r, CYAN.g, CYAN.b, 0.45), 2.0)
		# animated traveling flow highlight (a moving bright dot + short dash)
		var phase := fmod(_t * 0.35 + float(r) * 0.27, 1.0)
		var flow := cap.lerp(cp, phase)
		draw_circle(flow, 3.0, Color(1, 1, 1, 0.85))
		draw_circle(flow, 6.0, Color(CYAN.r, CYAN.g, CYAN.b, 0.35))

# ---------------------------------------------------------------- drones

func _draw_drones(cap: Vector2, cities: Array) -> void:
	for di in range(GameState.vdrones.size()):
		var v: Dictionary = GameState.vdrones[di]
		var rr: int = clampi(1 + int(v["route"]), 1, cities.size() - 1)
		var b := _proj(Vector2(cities[rr]["x"], cities[rr]["y"]))
		var tval: float = float(v["t"])
		var base := cap.lerp(b, tval)
		# ambient micro-bob
		var bob := sin(_t * 2.4 + float(di) * 1.7) * 2.5
		var pos := base + Vector2(0, bob)

		# trail history
		var hist: Array = _trails.get(di, [])
		hist.append(pos)
		while hist.size() > TRAIL_LEN:
			hist.remove_at(0)
		_trails[di] = hist
		_draw_trail(hist, di)

		# soft ground shadow (offset down)
		draw_circle(pos + Vector2(0, 14), 12.0, Color(SHADOW.r, SHADOW.g, SHADOW.b, 0.30))
		# under-glow
		draw_circle(pos, 16.0, Color(SKY.r, SKY.g, SKY.b, 0.10))

		# carried package on outbound leg
		if int(v["dir"]) == 1:
			if _package != null:
				draw_texture_rect(_package, Rect2(pos.x - 9, pos.y + 9, 18, 18), false)

		var tex: Texture2D = _drone_tex[di % _drone_tex.size()]
		if tex != null:
			draw_texture_rect(tex, Rect2(pos.x - 20, pos.y - 20, 40, 40), false)

func _draw_trail(hist: Array, di: int) -> void:
	if hist.size() < 2:
		return
	var col := CYAN
	for i in range(hist.size() - 1):
		var f := float(i) / float(hist.size())
		var a := 0.30 * f
		var ww := 1.0 + 3.0 * f
		draw_line(hist[i], hist[i + 1], Color(col.r, col.g, col.b, a), ww)

# ---------------------------------------------------------------- cities

func _draw_cities(cap: Vector2, cities: Array, ci: int) -> void:
	for i in range(cities.size()):
		var cp := _proj(Vector2(cities[i]["x"], cities[i]["y"]))
		var nm: String = cities[i]["name"]
		var flash: float = float(_flash.get(i, 0.0))
		if i == 0:
			_capital_marker(cp, flash)
			_label(cp, nm + " (sede)", GOLD)
		elif i <= GameState.cities_unlocked:
			_active_marker(cp, flash)
			_label(cp, nm, Color(0.80, 1.0, 1.0))
		else:
			var is_next := (i == GameState.cities_unlocked + 1)
			_locked_marker(cp, is_next)
			if is_next:
				var cost := Economy.city_unlock_cost(ci, GameState.cities_unlocked)
				_cost_chip(cp, Fmt.short(cost))

func _capital_marker(p: Vector2, flash: float) -> void:
	# hub_home texture if available, else procedural golden pad
	var breath: float = 0.5 + 0.5 * sin(_t * 1.6)
	# tall ambient ground glow
	draw_circle(p, 30.0 + breath * 6.0, Color(GOLD.r, GOLD.g, GOLD.b, 0.10 + 0.05 * breath))
	if _hub_home != null:
		var s := 56.0
		draw_texture_rect(_hub_home, Rect2(p.x - s * 0.5, p.y - s * 0.5, s, s), false)
	else:
		draw_circle(p, 11.0, GOLD)
		draw_circle(p, 5.0, INK)
	# pulsing landing ring via draw_arc (phase from shared clock)
	var ph := _t * 1.2
	draw_arc(p, 20.0 + breath * 3.0, ph, ph + TAU, 32, Color(GOLD.r, GOLD.g, GOLD.b, 0.7), 2.5)
	if flash > 0.0:
		_delivery_flash(p, GOLD, flash)

func _active_marker(p: Vector2, flash: float) -> void:
	var pulse: float = 0.5 + 0.5 * sin(_t * 3.0)
	draw_circle(p, 14.0 + pulse * 4.0, Color(CYAN.r, CYAN.g, CYAN.b, 0.16))
	if _hub_city != null:
		var s := 40.0
		draw_texture_rect(_hub_city, Rect2(p.x - s * 0.5, p.y - s * 0.5, s, s), false)
	else:
		draw_circle(p, 8.0, CYAN)
		draw_circle(p, 3.6, INK)
	draw_arc(p, 11.0, 0, TAU, 24, Color(CYAN.r, CYAN.g, CYAN.b, 0.4 + 0.3 * pulse), 1.6)
	if flash > 0.0:
		_delivery_flash(p, CYAN, flash)

func _locked_marker(p: Vector2, is_next: bool) -> void:
	if is_next:
		# CTA: pulse brighter, alt hub texture
		var pulse: float = 0.5 + 0.5 * sin(_t * 2.2)
		draw_circle(p, 16.0 + pulse * 5.0, Color(MUTED.r, MUTED.g, MUTED.b, 0.14 + 0.06 * pulse))
		if _hub_city2 != null:
			var s := 36.0
			draw_texture_rect(_hub_city2, Rect2(p.x - s * 0.5, p.y - s * 0.5, s, s), false, Color(1, 1, 1, 0.75 + 0.25 * pulse))
		else:
			draw_circle(p, 7.0, Color(MUTED.r, MUTED.g, MUTED.b, 0.9))
		draw_arc(p, 12.0, 0, TAU, 24, Color(GOLD.r, GOLD.g, GOLD.b, 0.35 + 0.3 * pulse), 1.6)
	else:
		# far-locked: dim
		draw_circle(p, 6.0, Color(MUTED.r, MUTED.g, MUTED.b, 0.35))
		draw_circle(p, 2.4, Color(MUTED.r, MUTED.g, MUTED.b, 0.55))

func _delivery_flash(p: Vector2, col: Color, t: float) -> void:
	# expanding ring + fade, t goes 0.5 -> 0
	var f: float = clamp(t / 0.5, 0.0, 1.0)
	var r := 14.0 + (1.0 - f) * 34.0
	draw_arc(p, r, 0, TAU, 28, Color(col.r, col.g, col.b, f * 0.8), 2.5)

# ---------------------------------------------------------------- labels

func _label(p: Vector2, text: String, col: Color) -> void:
	if _font == null:
		return
	var lw := 220.0
	# frosted pill backing for legibility
	var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 16).x
	var pill := Rect2(p.x - tw * 0.5 - 8.0, p.y + 22.0, tw + 16.0, 22.0)
	draw_rect(pill, Color(MIDNIGHT.r, MIDNIGHT.g, MIDNIGHT.b, 0.55), true)
	draw_rect(pill, Color(col.r, col.g, col.b, 0.25), false, 1.0)
	draw_string(_font, Vector2(p.x - lw * 0.5, p.y + 38.0), text, HORIZONTAL_ALIGNMENT_CENTER, lw, 16, col)

func _cost_chip(p: Vector2, cost: String) -> void:
	if _font == null:
		return
	var text := "🔒 " + cost
	var lw := 200.0
	var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 15).x
	var pill := Rect2(p.x - tw * 0.5 - 9.0, p.y + 22.0, tw + 18.0, 22.0)
	draw_rect(pill, Color(MIDNIGHT.r, MIDNIGHT.g, MIDNIGHT.b, 0.62), true)
	draw_rect(pill, Color(GOLD.r, GOLD.g, GOLD.b, 0.30), false, 1.0)
	draw_string(_font, Vector2(p.x - lw * 0.5, p.y + 38.0), text, HORIZONTAL_ALIGNMENT_CENTER, lw, 15, Color(GOLD.r, GOLD.g, GOLD.b, 0.95))

# ---------------------------------------------------------------- pops / fx

func _on_delivered(amount: float, city_index: int) -> void:
	var cities := Economy.country_cities(GameState.current_country)
	var idx: int = clampi(city_index, 0, cities.size() - 1)
	var p := _proj(Vector2(cities[idx]["x"], cities[idx]["y"]))
	# beacon flash on the destination
	_flash[idx] = 0.5
	if _pops.size() > POP_CAP:
		return
	_pops.append({"text": "+" + Fmt.short(amount), "x": p.x, "y": p.y - 22.0, "life": 1.0})

func _draw_pops() -> void:
	if _font == null:
		return
	for p in _pops:
		var life: float = float(p["life"])
		var a: float = clamp(life, 0.0, 1.0)
		# spring-up scale fade: subtle glow then text
		var px: float = float(p["x"])
		var py: float = float(p["y"])
		var txt: String = String(p["text"])
		draw_string(_font, Vector2(px - 50.0, py + 1.0), txt, HORIZONTAL_ALIGNMENT_CENTER, 100.0, 24, Color(SHADOW.r, SHADOW.g, SHADOW.b, a * 0.55))
		draw_string(_font, Vector2(px - 50.0, py), txt, HORIZONTAL_ALIGNMENT_CENTER, 100.0, 24, Color(MINT.r, MINT.g, MINT.b, a))
