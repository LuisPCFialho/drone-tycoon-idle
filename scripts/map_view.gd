extends Control
class_name MapView
## Premium "Aurora Logistics" sky-command map. Draws the current country: real
## outline polygon, geographically-placed cities (capital / active / locked),
## flowing route lanes and delivery drones with trails. Reads GameState/Economy.
## mouse_filter IGNORE, draws via _draw()/queue_redraw(). Performant for mobile.

# --- public API (set every frame by main.gd) ---
var band_top := 150.0
var band_bottom := 760.0

# --- zoom / pan (pinch + drag) ---
var zoom := 1.0
var pan := Vector2.ZERO
const ZOOM_MIN := 1.0
const ZOOM_MAX := 4.0
var _touches: Dictionary = {}      # touch index -> position
var _last_pinch := 0.0

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
var _sea_tex: GradientTexture2D
var _vig_top: GradientTexture2D
var _vig_bottom: GradientTexture2D
var _vig_left: GradientTexture2D
var _vig_right: GradientTexture2D
var _land_grad: GradientTexture2D
var _grid_tile: Texture2D
var _coin: Texture2D
var _lock: Texture2D
var _sun: Texture2D
var _aurora: Texture2D

# --- projection fit + cinematic camera ---
var _bbox := Rect2(0, 0, 1, 1)
var _outline_cache: PackedVector2Array = PackedVector2Array()
var _cam_tween: Tween

# --- landmass geometry cache (rebuilt only when zoom/pan actually change) ---
var _lm_zoom := -1.0
var _lm_pan := Vector2(INF, INF)
var _lm_pts: PackedVector2Array
var _lm_sh: PackedVector2Array
var _lm_closed: PackedVector2Array
var _lm_inner: PackedVector2Array
var _lm_grid_uvs: PackedVector2Array
var _lm_land_uvs: PackedVector2Array

# --- misc caches ---
var _next_cost_str := ""
var _text_width_cache: Dictionary = {}

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
const SEA_TOP   := Color(0.04, 0.09, 0.19)      # #0A1730 — distinct from UI chrome
const SEA_BOT   := Color(0.07, 0.16, 0.30)      # #122A4D
const LAND      := Color(0.14, 0.22, 0.35)
const LAND_HI   := Color(0.22, 0.34, 0.50)
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
	mouse_filter = Control.MOUSE_FILTER_STOP   # receives pinch/drag in its visible band
	_font = UITheme.font("Bold")
	_drone_tex = [load("res://assets/art/drone_blue.png"), load("res://assets/art/drone_teal.png"), load("res://assets/art/drone_amber.png")]
	_package = load("res://assets/art/package.png")
	_cloud = load("res://assets/art/cloud.png")
	_hub_home = load("res://assets/art/hub_home.png")
	_hub_city = load("res://assets/art/hub_city.png")
	_hub_city2 = load("res://assets/art/hub_city2.png")
	_grid_tile = load("res://assets/art/grid_tile.png")
	_coin = load("res://assets/art/coin.png")
	_lock = load("res://assets/art/ic_lock.png")
	_sun = load("res://assets/art/sun_glow.png")
	_aurora = load("res://assets/art/aurora_band.png")
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED   # lets the holo grid tile
	GameState.delivered.connect(_on_delivered)
	GameState.country_changed.connect(func(_i): _recalc_bbox(); _reset_view(); reveal_country(); _refresh_next_cost())
	# cached sea gradient (replaces 40 draw_rect calls per frame)
	var sg := Gradient.new()
	sg.set_color(0, SEA_TOP); sg.set_color(1, SEA_BOT)
	_sea_tex = GradientTexture2D.new()
	_sea_tex.gradient = sg
	_sea_tex.fill_from = Vector2(0, 0); _sea_tex.fill_to = Vector2(0, 1)
	_sea_tex.width = 4; _sea_tex.height = 256
	# cached vignette edge-fade textures (replaces 32 draw_rect calls/frame)
	_vig_top = _edge_gradient_tex(false)
	_vig_bottom = _edge_gradient_tex(true)
	_vig_left = _edge_gradient_tex(false, true)
	_vig_right = _edge_gradient_tex(true, true)
	# cached vertical land gradient (replaces a 2nd flat inner-shrink polygon)
	var lg := Gradient.new()
	lg.set_color(0, LAND_HI); lg.set_color(1, LAND)
	_land_grad = GradientTexture2D.new()
	_land_grad.gradient = lg
	_land_grad.fill_from = Vector2(0, 0); _land_grad.fill_to = Vector2(0, 1)
	_land_grad.width = 4; _land_grad.height = 128
	_seed_ambiance()
	_recalc_bbox()
	GameState.city_unlocked.connect(func(_i): _refresh_next_cost())
	_refresh_next_cost()
	set_process(true)

## Small cached alpha-fade texture for a screen edge vignette band. `reverse`
## puts the opaque end at position 1 instead of 0 (bottom/right edges fade the
## opposite direction from top/left). `horizontal` fades left<->right instead
## of top<->bottom. Replaces the old per-frame 8-iteration x 4-rect loop.
func _edge_gradient_tex(reverse: bool, horizontal := false) -> GradientTexture2D:
	var g := Gradient.new()
	var opaque := Color(VOID.r, VOID.g, VOID.b, 0.42)
	var clear := Color(VOID.r, VOID.g, VOID.b, 0.0)
	g.set_color(0, clear if reverse else opaque)
	g.set_color(1, opaque if reverse else clear)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	if horizontal:
		tex.fill_from = Vector2(0, 0); tex.fill_to = Vector2(1, 0)
		tex.width = 64; tex.height = 8
	else:
		tex.fill_from = Vector2(0, 0); tex.fill_to = Vector2(0, 1)
		tex.width = 8; tex.height = 64
	return tex

## Cached "next city" unlock cost string — recomputed only when it can
## actually change (unlock/expand), not every frame from _draw_cities().
func _refresh_next_cost() -> void:
	var ci := GameState.current_country
	_next_cost_str = Fmt.short(Economy.city_unlock_cost(ci, GameState.cities_unlocked))

## Memoized text-width measurement (city/cost labels repeat every frame while
## on screen but rarely change) — avoids re-measuring the same string+size.
func _measure(text: String, font_size: int) -> float:
	var key := text + "@" + str(font_size)
	if _text_width_cache.has(key):
		return _text_width_cache[key]
	var w: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
	_text_width_cache[key] = w
	return w

## Bounding box of the current country's outline + cities (map space), so the
## projection fills the band instead of assuming the full unit square.
func _recalc_bbox() -> void:
	var ci := GameState.current_country
	_outline_cache = Economy.country_outline(ci)
	var pts := _outline_cache
	var cities := Economy.country_cities(ci)
	if pts.is_empty() and cities.is_empty():
		_bbox = Rect2(0, 0, 1, 1)
		return
	var minp := Vector2(INF, INF)
	var maxp := Vector2(-INF, -INF)
	for p in pts:
		minp = minp.min(p); maxp = maxp.max(p)
	for c in cities:
		var cp := Vector2(c["x"], c["y"])
		minp = minp.min(cp); maxp = maxp.max(cp)
	var r := Rect2(minp, maxp - minp)
	if r.size.x < 0.001 or r.size.y < 0.001:
		r = Rect2(0, 0, 1, 1)
	_bbox = r

func _reset_view() -> void:
	zoom = 1.0
	pan = Vector2.ZERO
	_touches.clear()
	_last_pinch = 0.0

func _seed_ambiance() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	# 3 parallax clouds: depth in {0=far,1=mid,2=near} affects speed/scale/alpha
	for i in range(3):
		_clouds.append({
			"x": rng.randf(),
			"y": rng.randf_range(0.05, 0.45),
			"depth": i,
			"speed": 0.006 + float(i) * 0.006,
			"scale": 1.6 + float(i) * 0.5,
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
	# advance floating pops (mutate in place; skip entirely when idle — the
	# common case outside the few seconds right after a delivery/unlock)
	if not _pops.is_empty():
		for i in range(_pops.size() - 1, -1, -1):
			var p: Dictionary = _pops[i]
			p["life"] = float(p["life"]) - delta
			p["y"] = float(p["y"]) - 34.0 * delta
			if float(p["life"]) <= 0.0:
				_pops.remove_at(i)
	# drift clouds (wrap)
	for c in _clouds:
		c["x"] += c["speed"] * delta
		if c["x"] > 1.25:
			c["x"] = -0.25
	# decay delivery flashes (mutate in place; skip when nothing is flashing)
	if not _flash.is_empty():
		var expired: Array = []
		for key: int in _flash:
			var rem: float = float(_flash[key]) - delta
			if rem > 0.0:
				_flash[key] = rem
			else:
				expired.append(key)
		for key in expired:
			_flash.erase(key)
	queue_redraw()

func _band_ctr() -> Vector2:
	return Vector2(size.x * 0.5, band_top + (band_bottom - band_top) * 0.5)

## Projection without zoom/pan: fits the country bbox to the band (uniform scale).
func _base_proj(p: Vector2) -> Vector2:
	var bw := size.x
	var bh := band_bottom - band_top
	var s: float = minf(bw / _bbox.size.x, bh / _bbox.size.y) * 0.86
	return _band_ctr() + (p - _bbox.get_center()) * s

func _proj(p: Vector2) -> Vector2:
	var ctr := _band_ctr()
	return ctr + (_base_proj(p) - ctr) * zoom + pan

## Cinematic punch-in on a just-unlocked city, then ease back out.
func focus_city(idx: int) -> void:
	if Fx.reduce_motion or not _touches.is_empty():
		return
	var cities := Economy.country_cities(GameState.current_country)
	if idx < 0 or idx >= cities.size():
		return
	if _cam_tween != null and _cam_tween.is_valid():
		_cam_tween.kill()
	var pt := Vector2(cities[idx]["x"], cities[idx]["y"])
	var tz := 1.8
	var tp := -(_base_proj(pt) - _band_ctr()) * tz
	_cam_tween = create_tween()
	_cam_tween.set_parallel(true)
	_cam_tween.tween_property(self, "zoom", tz, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_cam_tween.tween_property(self, "pan", tp, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_cam_tween.chain().tween_interval(0.7)
	_cam_tween.chain().tween_property(self, "zoom", 1.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_cam_tween.tween_property(self, "pan", Vector2.ZERO, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

## Zoom-out reveal when arriving in a new country.
func reveal_country() -> void:
	if Fx.reduce_motion:
		return
	if _cam_tween != null and _cam_tween.is_valid():
		_cam_tween.kill()
	zoom = 2.2
	var cities := Economy.country_cities(GameState.current_country)
	if not cities.is_empty():
		var pt := Vector2(cities[0]["x"], cities[0]["y"])
		pan = -(_base_proj(pt) - _band_ctr()) * zoom
	_cam_tween = create_tween()
	_cam_tween.set_parallel(true)
	_cam_tween.tween_property(self, "zoom", 1.0, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_cam_tween.tween_property(self, "pan", Vector2.ZERO, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

# ---------------------------------------------------------------- input (zoom/pan)

func _gui_input(event: InputEvent) -> void:
	# any interaction cancels the cinematic camera — the player always wins
	if _cam_tween != null and _cam_tween.is_valid():
		if event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouseButton:
			_cam_tween.kill()
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_touches[t.index] = t.position
		else:
			_touches.erase(t.index)
			if _touches.size() < 2:
				_last_pinch = 0.0
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		_touches[d.index] = d.position
		if _touches.size() >= 2:
			var ks := _touches.keys()
			var a: Vector2 = _touches[ks[0]]
			var b: Vector2 = _touches[ks[1]]
			var dist := a.distance_to(b)
			if _last_pinch > 0.0 and dist > 0.0:
				_zoom_at(zoom * (dist / _last_pinch), (a + b) * 0.5)
			_last_pinch = dist
		else:
			pan += d.relative
			_clamp_pan()
		accept_event()
	elif event is InputEventMouseButton:
		if not _touches.is_empty():
			return
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(zoom * 1.12, mb.position); accept_event()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(zoom / 1.12, mb.position); accept_event()
	elif event is InputEventMouseMotion:
		if not _touches.is_empty():
			return
		var mm := event as InputEventMouseMotion
		if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			pan += mm.relative
			_clamp_pan()
			accept_event()

func _zoom_at(target: float, focus: Vector2) -> void:
	var old := zoom
	zoom = clampf(target, ZOOM_MIN, ZOOM_MAX)
	var ctr := Vector2(size.x * 0.5, band_top + (band_bottom - band_top) * 0.5)
	# keep the focus point stationary on screen
	pan = pan - (focus - ctr - pan) * (zoom / old - 1.0)
	if zoom <= ZOOM_MIN + 0.001:
		zoom = ZOOM_MIN
		pan = Vector2.ZERO
	_clamp_pan()

func _clamp_pan() -> void:
	var bh := band_bottom - band_top
	var mx := size.x * 0.5 * (zoom - 1.0) + 80.0
	var my := bh * 0.5 * (zoom - 1.0) + 80.0
	pan.x = clampf(pan.x, -mx, mx)
	pan.y = clampf(pan.y, -my, my)

func _draw() -> void:
	var w := size.x
	var h := band_bottom - band_top
	_draw_sea(w, h)
	_draw_horizon_light(w, h)
	_draw_grid(w, h)
	_draw_caustics(w, h)

	var ci := GameState.current_country
	_draw_landmass(_outline_cache)

	var cities := Economy.country_cities(ci)
	if cities.is_empty():
		# clouds/stars drift ABOVE land/routes (below only the vignette), so
		# the parallax depth cue reads instead of vanishing under the landmass
		_draw_clouds(w, h)
		_draw_stars(w, h)
		_draw_vignette(w, h)
		_draw_pops()
		return

	var cap := _proj(Vector2(cities[0]["x"], cities[0]["y"]))
	var route_geom := _draw_routes(cap, cities)
	_draw_drones(cap, cities, route_geom)
	_draw_cities(cap, cities, ci)
	_draw_clouds(w, h)
	_draw_stars(w, h)
	_draw_vignette(w, h)
	_draw_pops()

# ---------------------------------------------------------------- background

func _draw_sea(w: float, h: float) -> void:
	# single cached gradient texture + very slow aurora day-cycle tint
	var cyc := 0.5 + 0.5 * sin(_t * 0.05)
	var tint := Color(1, 1, 1).lerp(Color(0.86, 0.92, 1.0), cyc * 0.35)
	draw_texture_rect(_sea_tex, Rect2(0, band_top, w, h), false, tint)

## Warm sun glow at top-right + slowly drifting aurora ribbon on the horizon —
## the light source that gives the scene contrast against the cyan coast.
func _draw_horizon_light(w: float, _h: float) -> void:
	if _sun != null:
		draw_texture_rect(_sun, Rect2(w - 300.0, band_top - 60.0, 360.0, 360.0), false, Color(1.0, 0.72, 0.35, 0.16))
	if _aurora != null:
		var drift := sin(_t * 0.07) * 40.0
		draw_texture_rect(_aurora, Rect2(-60.0 + drift, band_top, w + 120.0, 90.0), false, Color(1, 1, 1, 0.22))

func _draw_grid(w: float, h: float) -> void:
	# perspective dot/line grid converging toward a horizon near band_top —
	# batched into 2 draw_multiline() calls instead of 21 separate draw_line()
	# calls, and the vertical line color is built once instead of per-segment.
	var line := Color(0.165, 0.212, 0.329, 0.10)   # Hairline, low alpha
	var horizon := band_top + h * 0.06
	# horizontal lines compressing upward
	var hpts := PackedVector2Array()
	for i in range(1, 11):
		var f := float(i) / 11.0
		var y := horizon + (band_bottom - horizon) * (f * f)
		hpts.append(Vector2(0, y)); hpts.append(Vector2(w, y))
	draw_multiline(hpts, line, 1.0)
	# converging verticals toward a vanishing point
	var vp := Vector2(w * 0.5, horizon)
	var vline := Color(line.r, line.g, line.b, 0.07)
	var vpts := PackedVector2Array()
	for i in range(0, 11):
		var bx := w * float(i) / 10.0
		vpts.append(Vector2(bx, band_bottom)); vpts.append(vp.lerp(Vector2(bx, band_bottom), 0.18))
	draw_multiline(vpts, vline, 1.0)
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
		var alpha := 0.05 + 0.03 * float(depth)
		draw_texture_rect(_cloud, Rect2(px, py, dim.x, dim.y), false, Color(0.62, 0.78, 1.0, alpha))

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
	# soft edge framing via 4 cached-gradient texture bands — was 8 iterations
	# x 4 draw_rect() calls (32 draws) plus 8 Color allocations every frame.
	var band := 42.0
	draw_texture_rect(_vig_top, Rect2(0, band_top, w, band), false)
	draw_texture_rect(_vig_bottom, Rect2(0, band_top + h - band, w, band), false)
	draw_texture_rect(_vig_left, Rect2(0, band_top, band, h), false)
	draw_texture_rect(_vig_right, Rect2(w - band, band_top, band, h), false)

# ---------------------------------------------------------------- landmass

func _draw_landmass(outline: PackedVector2Array) -> void:
	if outline.size() < 3:
		return
	# Geometry (projected points, shadow offset, closed outline, inner-light
	# shrink, grid/gradient UVs) only actually changes when the camera moves
	# (zoom/pan) or the outline itself changes — not while the player is just
	# watching the map sit still, the common idle-game case. Rebuild only then.
	if zoom != _lm_zoom or pan != _lm_pan or _lm_pts.size() != outline.size():
		_lm_zoom = zoom; _lm_pan = pan
		_lm_pts = PackedVector2Array()
		for p in outline:
			_lm_pts.append(_proj(p))
		_lm_sh = PackedVector2Array()
		for q in _lm_pts:
			_lm_sh.append(q + Vector2(5, 9))
		_lm_closed = _lm_pts.duplicate()
		_lm_closed.append(_lm_pts[0])
		var ctr := _centroid(_lm_pts)
		_lm_inner = PackedVector2Array()
		for q in _lm_pts:
			_lm_inner.append(q.lerp(ctr, 0.10))
		_lm_grid_uvs = PackedVector2Array()
		for q in _lm_pts:
			_lm_grid_uvs.append(q / 64.0)
		# gradient UVs: v=0 at the landmass's screen-space top, v=1 at bottom,
		# so the single cached vertical LAND_HI->LAND texture reads correctly
		# regardless of zoom/pan (replaces a 2nd flat inner-shrink fill poly)
		var min_y := INF; var max_y := -INF
		for q in _lm_pts:
			min_y = minf(min_y, q.y); max_y = maxf(max_y, q.y)
		var yr := maxf(1.0, max_y - min_y)
		_lm_land_uvs = PackedVector2Array()
		for q in _lm_pts:
			_lm_land_uvs.append(Vector2(0.5, (q.y - min_y) / yr))

	var pts := _lm_pts
	var closed := _lm_closed

	# drop shadow: land visibly lifts off the sea
	draw_colored_polygon(_lm_sh, Color(SHADOW.r, SHADOW.g, SHADOW.b, 0.5))

	# soft outer glow underlay (a few expanding faint strokes)
	for g in range(4):
		var gw := 18.0 - float(g) * 4.0
		var ga := 0.05 + 0.03 * float(g)
		draw_polyline(closed, Color(CYAN.r, CYAN.g, CYAN.b, ga), gw, true)

	# filled land: single smooth top-light gradient fill (was two flat-color
	# polygons stacked to fake a gradient, leaving a hard ring-like inner edge)
	draw_colored_polygon(pts, Color(1, 1, 1, 1), _lm_land_uvs, _land_grad)
	# holo survey grid clipped to the landmass (repeat-tiled via uv > 1)
	if _grid_tile != null:
		draw_colored_polygon(pts, Color(CYAN.r, CYAN.g, CYAN.b, 0.06), _lm_grid_uvs, _grid_tile)

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

## Quadratic-bezier control point for a route: bows the lane sideways so lanes
## read as flight arcs; alternate sides per route index to avoid overlap.
func _route_ctrl(a: Vector2, b: Vector2, r: int) -> Vector2:
	var mid := (a + b) * 0.5
	var d := a.distance_to(b)
	if d < 0.001:
		return mid
	var side_f := -1.0 if (r % 2 == 0) else 1.0
	return mid + (b - a).orthogonal().normalized() * d * 0.16 * side_f

func _route_point(a: Vector2, ctrl: Vector2, b: Vector2, t: float) -> Vector2:
	return a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t)

## Draws route lanes and returns each route's {b, ctrl} geometry so
## _draw_drones() doesn't redundantly recompute _proj()/_route_ctrl() per
## drone for a value that's identical for every drone sharing the same route.
func _draw_routes(cap: Vector2, cities: Array) -> Dictionary:
	# tie the lane's core brightness to the same breathing pulse as the
	# coastline rim — the flight lanes are more functionally important than
	# the decorative outline but used to read visibly weaker (flat 0.45)
	var glow := 0.5 + 0.5 * sin(_t * 1.5)
	var route_geom: Dictionary = {}
	for r in range(GameState.cities_unlocked):
		var idx: int = 1 + r
		if idx >= cities.size():
			continue
		var cp := _proj(Vector2(cities[idx]["x"], cities[idx]["y"]))
		var ctrl := _route_ctrl(cap, cp, r)
		route_geom[r] = {"b": cp, "ctrl": ctrl}
		var pts := PackedVector2Array()
		var segs := 14
		for i in range(segs + 1):
			pts.append(_route_point(cap, ctrl, cp, float(i) / float(segs)))
		# wide soft glow lane + bright core, along the arc
		draw_polyline(pts, Color(SKY.r, SKY.g, SKY.b, 0.10), 8.0, true)
		draw_polyline(pts, Color(CYAN.r, CYAN.g, CYAN.b, 0.55 + 0.30 * glow), 2.0, true)
		# two traveling flow highlights per lane (busier logistics feel)
		for k in range(2):
			var phase := fmod(_t * 0.35 + float(r) * 0.27 + float(k) * 0.5, 1.0)
			var flow := _route_point(cap, ctrl, cp, phase)
			draw_circle(flow, 3.0, Color(1, 1, 1, 0.85))
			draw_circle(flow, 6.0, Color(CYAN.r, CYAN.g, CYAN.b, 0.35))
	return route_geom

# ---------------------------------------------------------------- drones

func _draw_drones(cap: Vector2, cities: Array, route_geom: Dictionary) -> void:
	var skin: Dictionary = Economy.SKINS.get(GameState.skin_active, Economy.SKINS["classic"])
	var body: Color = skin["body"]
	var trail_col: Color = skin["trail"]
	for di in range(GameState.vdrones.size()):
		var v: Dictionary = GameState.vdrones[di]
		var route: int = int(v["route"])
		var b: Vector2
		var ctrl: Vector2
		if route_geom.has(route):
			# every drone on the same route shares identical geometry —
			# reuse what _draw_routes() already computed instead of rerunning
			# _proj()/_route_ctrl() (2 sqrt calls) per drone
			b = route_geom[route]["b"]
			ctrl = route_geom[route]["ctrl"]
		else:
			var rr: int = clampi(1 + route, 1, cities.size() - 1)
			b = _proj(Vector2(cities[rr]["x"], cities[rr]["y"]))
			ctrl = _route_ctrl(cap, b, route)
		var tval: float = float(v.get("vt", v["t"]))   # slow cosmetic clock (see game_state VISUAL_SPEED_FACTOR)
		var vdir: int = int(v.get("vdir", v["dir"]))
		var base := _route_point(cap, ctrl, b, tval)
		# takeoff/landing ease: shrink + settle near pads instead of instant flips
		var edge := minf(tval, 1.0 - tval)
		var k := clampf(edge / 0.08, 0.0, 1.0)
		var dsc := lerpf(0.65, 1.0, k)
		# ambient micro-bob (suppressed near pads so the drone visibly descends)
		var bob := sin(_t * 2.4 + float(di) * 1.7) * 2.5 * k
		var pos := base + Vector2(0, bob)

		# trail history
		var hist: Array = _trails.get(di, [])
		hist.append(pos)
		while hist.size() > TRAIL_LEN:
			hist.remove_at(0)
		_trails[di] = hist
		_draw_trail(hist, trail_col)

		# soft ground shadow (offset down)
		draw_circle(pos + Vector2(0, 14.0 * dsc), 12.0 * dsc, Color(SHADOW.r, SHADOW.g, SHADOW.b, 0.30))
		# under-glow
		draw_circle(pos, 16.0 * dsc, Color(SKY.r, SKY.g, SKY.b, 0.10))

		# carried package on outbound leg (world-space: hangs below the drone),
		# scaled by dsc so it shrinks/settles in sync with the drone near pads
		# instead of staying full-size while the drone shrinks around it
		if vdir == 1:
			if _package != null:
				var psz := 18.0 * dsc
				draw_texture_rect(_package, Rect2(pos.x - psz * 0.5, pos.y + 9.0 * dsc, psz, psz), false)

		# heading from bezier tangent so the drone faces its travel direction,
		# with a light banking wobble
		var deriv := (ctrl - cap).lerp(b - ctrl, tval) * float(vdir)
		var ang := 0.0
		if deriv.length_squared() > 0.0001:
			ang = deriv.angle() + PI * 0.5
		ang += sin(_t * 2.0 + float(di) * 1.3) * 0.06
		var tex: Texture2D = _drone_tex[di % _drone_tex.size()]
		if tex != null:
			draw_set_transform(pos, ang, Vector2(dsc, dsc))
			draw_texture_rect(tex, Rect2(-20, -20, 40, 40), false, body)
			draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw_trail(hist: Array, col: Color) -> void:
	if hist.size() < 2:
		return
	for i in range(hist.size() - 1):
		var f := float(i) / float(hist.size())
		var a := 0.5 * f   # was 0.30 — trails read weaker than the static coastline
		var ww := 1.0 + 3.0 * f
		draw_line(hist[i], hist[i + 1], Color(col.r, col.g, col.b, a), ww)

# ---------------------------------------------------------------- cities

func _draw_cities(cap: Vector2, cities: Array, _ci: int) -> void:
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
				_cost_chip(cp, _next_cost_str)

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
	# rotating radar sweep with fading trail arc
	var ra := _t * 0.9
	draw_arc(p, 30.0, ra - 0.85, ra, 10, Color(GOLD.r, GOLD.g, GOLD.b, 0.10), 9.0)
	draw_line(p, p + Vector2.from_angle(ra) * 34.0, Color(GOLD.r, GOLD.g, GOLD.b, 0.30), 1.6)
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
	# expanding ring + rising light beam, t goes 0.5 -> 0, eased so the ring
	# expands fast then decelerates instead of a flat constant-speed expansion
	var f: float = clamp(t / 0.5, 0.0, 1.0)
	var ef := 1.0 - pow(f, 2.5)
	var r := 14.0 + ef * 34.0
	draw_arc(p, r, 0, TAU, 28, Color(col.r, col.g, col.b, f * 0.8), 2.5)
	draw_line(p, p + Vector2(0, -46.0 * ef - 8.0), Color(col.r, col.g, col.b, f * 0.35), 3.0)
	# parcel visibly dropping onto the pad, with a smooth fade-in instead of a
	# hard t>0.2 cutoff that used to pop the sprite in at ~40% alpha in one frame
	if _package != null:
		var pkg_fade := smoothstep(0.0, 0.2, t)
		if pkg_fade > 0.0:
			var drop := (0.5 - t) * 30.0
			draw_texture_rect(_package, Rect2(p.x - 9.0, p.y - 26.0 + drop, 18, 18), false, Color(1, 1, 1, f * pkg_fade))

# ---------------------------------------------------------------- labels

func _label(p: Vector2, text: String, col: Color) -> void:
	if _font == null:
		return
	var lw := 220.0
	# frosted pill backing for legibility (pill height + baseline track the font
	# size so a larger label never clips its backing)
	var tw := _measure(text, 18)
	var pill := Rect2(p.x - tw * 0.5 - 8.0, p.y + 22.0, tw + 16.0, 25.0)
	draw_rect(pill, Color(MIDNIGHT.r, MIDNIGHT.g, MIDNIGHT.b, 0.55), true)
	draw_rect(pill, Color(col.r, col.g, col.b, 0.25), false, 1.0)
	draw_string(_font, Vector2(p.x - lw * 0.5, p.y + 40.0), text, HORIZONTAL_ALIGNMENT_CENTER, lw, 18, col)

func _cost_chip(p: Vector2, cost: String) -> void:
	if _font == null:
		return
	# lives ABOVE the marker (name pills live below) so lanes never collide
	var lw := 200.0
	var tw := _measure(cost, 17)
	var pill := Rect2(p.x - tw * 0.5 - 9.0 - 9.0, p.y - 46.0, tw + 18.0 + 18.0, 25.0)
	draw_rect(pill, Color(MIDNIGHT.r, MIDNIGHT.g, MIDNIGHT.b, 0.62), true)
	draw_rect(pill, Color(GOLD.r, GOLD.g, GOLD.b, 0.30), false, 1.0)
	if _lock != null:
		draw_texture_rect(_lock, Rect2(pill.position.x + 5.0, pill.position.y + 5.5, 14, 14), false, Color(GOLD.r, GOLD.g, GOLD.b, 0.95))
	draw_string(_font, Vector2(p.x - lw * 0.5 + 8.0, p.y - 29.0), cost, HORIZONTAL_ALIGNMENT_CENTER, lw, 17, Color(GOLD.r, GOLD.g, GOLD.b, 0.95))

# ---------------------------------------------------------------- pops / fx

func _on_delivered(amount: float, city_index: int) -> void:
	var cities := Economy.country_cities(GameState.current_country)
	var idx: int = clampi(city_index, 0, cities.size() - 1)
	var p := _proj(Vector2(cities[idx]["x"], cities[idx]["y"]))
	# beacon flash on the destination
	_flash[idx] = 0.5
	if _pops.size() > POP_CAP:
		return
	_pops.append({"text": "+" + Fmt.short(amount), "x": p.x, "y": p.y - 48.0, "life": 1.0})

func _draw_pops() -> void:
	if _font == null:
		return
	for p in _pops:
		var life: float = float(p["life"])
		var a: float = clampf(life, 0.0, 1.0)
		# spring overshoot in, settle, drift with a light sideways arc
		var age := 1.0 - life
		var sc := lerpf(0.5, 1.15, clampf(age / 0.12, 0.0, 1.0))
		if age > 0.12:
			sc = lerpf(1.15, 1.0, clampf((age - 0.12) / 0.15, 0.0, 1.0))
		var px: float = float(p["x"]) + sin(life * 3.0) * 6.0
		var py: float = float(p["y"])
		var txt: String = String(p["text"])
		draw_set_transform(Vector2(px, py), 0.0, Vector2(sc, sc))
		if _coin != null:
			draw_texture_rect(_coin, Rect2(-64.0, -11.0, 18, 18), false, Color(1, 1, 1, a))
		draw_string(_font, Vector2(-42.0, 2.0), txt, HORIZONTAL_ALIGNMENT_CENTER, 100.0, 24, Color(SHADOW.r, SHADOW.g, SHADOW.b, a * 0.8))
		draw_string(_font, Vector2(-42.0, 0.0), txt, HORIZONTAL_ALIGNMENT_CENTER, 100.0, 24, Color(MINT.r, MINT.g, MINT.b, a))
		draw_set_transform_matrix(Transform2D.IDENTITY)
