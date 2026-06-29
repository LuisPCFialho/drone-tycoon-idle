extends Control
class_name MapView
## Flat aerial map: gradient land, decorative blocks, routes, hubs and animated
## drones flying deliveries. Reads GameState.

var band_top := 150.0
var band_bottom := 760.0

var _t := 0.0
var _font: Font
var _pops: Array = []
var _clouds: Array = []
var _blocks: Array = []

var _drone_tex: Array = []
var _package: Texture2D
var _hub_home: Texture2D
var _hub_city: Array = []
var _cloud: Texture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = UITheme.font("Bold")
	_drone_tex = [load("res://assets/art/drone_blue.png"), load("res://assets/art/drone_teal.png"), load("res://assets/art/drone_amber.png")]
	_package = load("res://assets/art/package.png")
	_hub_home = load("res://assets/art/hub_home.png")
	_hub_city = [load("res://assets/art/hub_city.png"), load("res://assets/art/hub_city2.png")]
	_cloud = load("res://assets/art/cloud.png")
	var rng := RandomNumberGenerator.new(); rng.seed = 1234
	for i in range(7):
		_clouds.append({"x": rng.randf(), "y": rng.randf_range(0.04, 0.5), "s": rng.randf_range(0.5, 1.0), "sp": rng.randf_range(0.01, 0.03)})
	for i in range(26):
		_blocks.append({"x": rng.randf(), "y": rng.randf_range(0.05, 0.97), "w": rng.randf_range(0.06, 0.16), "h": rng.randf_range(0.04, 0.1), "c": rng.randi_range(0, 3)})
	GameState.delivered.connect(_on_delivered)
	set_process(true)

func _process(delta: float) -> void:
	_t += delta
	for c in _clouds:
		c["x"] += c["sp"] * delta
		if c["x"] > 1.15:
			c["x"] = -0.2
	var keep: Array = []
	for p in _pops:
		p["life"] -= delta; p["y"] -= 26.0 * delta
		if p["life"] > 0.0:
			keep.append(p)
	_pops = keep
	queue_redraw()

func _m2s(p: Vector2) -> Vector2:
	return Vector2(p.x * size.x, band_top + p.y * (band_bottom - band_top))

func _draw() -> void:
	var w := size.x
	# land gradient
	var top := Color(0.79, 0.88, 0.79)
	var bot := Color(0.62, 0.76, 0.66)
	var steps := 48
	var h := band_bottom - band_top
	for i in range(steps):
		var y := band_top + h * float(i) / steps
		draw_rect(Rect2(0, y, w, h / steps + 1.0), top.lerp(bot, float(i) / steps))
	# decorative city blocks
	var block_cols := [Color(0.72, 0.8, 0.86), Color(0.8, 0.82, 0.7), Color(0.86, 0.78, 0.74), Color(0.7, 0.84, 0.78)]
	for b in _blocks:
		var pos := _m2s(Vector2(b["x"], b["y"]))
		var bw: float = b["w"] * w
		var bh: float = b["h"] * h
		_rrect(Rect2(pos.x - bw * 0.5, pos.y - bh * 0.5, bw, bh), 10.0, block_cols[b["c"]])
	# routes
	var home := _m2s(Economy.hub_pos(0))
	for i in range(1, GameState.hubs_unlocked):
		var hp := _m2s(Economy.hub_pos(i))
		draw_line(home, hp, Color(0.25, 0.45, 0.85, 0.35), 5.0)
		_dots(home, hp, Color(1, 1, 1, 0.5))
	# locked routes (faint)
	for i in range(GameState.hubs_unlocked, Economy.num_hubs()):
		var hp := _m2s(Economy.hub_pos(i))
		draw_line(home, hp, Color(0.3, 0.3, 0.35, 0.12), 3.0)
	# hubs
	for i in range(Economy.num_hubs()):
		_draw_hub(i)
	# drones
	for idx in range(GameState.vdrones.size()):
		_draw_drone(idx)
	# clouds (parallax over everything)
	for c in _clouds:
		var cw: float = _cloud.get_width() * c["s"] * 1.6
		var ch: float = _cloud.get_height() * c["s"] * 1.6
		var cpos := _m2s(Vector2(c["x"], c["y"]))
		draw_texture_rect(_cloud, Rect2(cpos.x - cw * 0.5, cpos.y - ch * 0.5, cw, ch), false, Color(1, 1, 1, 0.85))
	_draw_pops()

func _draw_hub(i: int) -> void:
	var pos := _m2s(Economy.hub_pos(i))
	var unlocked := i < GameState.hubs_unlocked
	if i == 0:
		var s := 86.0
		draw_texture_rect(_hub_home, Rect2(pos.x - s * 0.5, pos.y - s * 0.5, s, s), false)
		return
	var s := 76.0
	var tex: Texture2D = _hub_city[(i - 1) % _hub_city.size()]
	if unlocked:
		draw_texture_rect(tex, Rect2(pos.x - s * 0.5, pos.y - s * 0.5, s, s), false)
	else:
		draw_texture_rect(tex, Rect2(pos.x - s * 0.5, pos.y - s * 0.5, s, s), false, Color(0.5, 0.52, 0.56, 0.75))
		# lock + cost
		if i == GameState.hubs_unlocked:
			var cost := Economy.hub_unlock_cost(i)
			_label(Vector2(pos.x, pos.y + s * 0.5 + 6), Fmt.short(cost) + " Cr", Color(1, 1, 1), 22, true)

func _draw_drone(idx: int) -> void:
	var v: Dictionary = GameState.vdrones[idx]
	var home := _m2s(Economy.hub_pos(0))
	var hp := _m2s(Economy.hub_pos(int(v["route"])))
	var pos := home.lerp(hp, float(v["t"]))
	var tex: Texture2D = _drone_tex[idx % _drone_tex.size()]
	var ds := 46.0
	if int(v["dir"]) == 1:
		# carrying a package outbound
		var ps := 22.0
		draw_texture_rect(_package, Rect2(pos.x - ps * 0.5, pos.y + ds * 0.25, ps, ps), false)
	draw_texture_rect(tex, Rect2(pos.x - ds * 0.5, pos.y - ds * 0.5, ds, ds), false)

func _on_delivered(amount: float, hub_index: int) -> void:
	if _pops.size() > 18:
		return
	var pos := _m2s(Economy.hub_pos(hub_index))
	_pops.append({"text": "+" + Fmt.short(amount), "x": pos.x, "y": pos.y - 30.0, "life": 1.1})

func _draw_pops() -> void:
	if _font == null:
		return
	for p in _pops:
		var a: float = clamp(p["life"], 0.0, 1.0)
		draw_string(_font, Vector2(p["x"] - 50, p["y"]), p["text"], HORIZONTAL_ALIGNMENT_CENTER, 100, 26, Color(0.1, 0.45, 0.2, a))
		draw_string(_font, Vector2(p["x"] - 51, p["y"] - 1), p["text"], HORIZONTAL_ALIGNMENT_CENTER, 100, 26, Color(1, 1, 1, a * 0.7))

func _label(pos: Vector2, text: String, col: Color, sz: int, outline := false) -> void:
	if _font == null:
		return
	if outline:
		for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
			draw_string(_font, Vector2(pos.x - 60, pos.y) + o, text, HORIZONTAL_ALIGNMENT_CENTER, 120, sz, Color(0.1, 0.12, 0.18, 0.9))
	draw_string(_font, Vector2(pos.x - 60, pos.y), text, HORIZONTAL_ALIGNMENT_CENTER, 120, sz, col)

func _rrect(r: Rect2, rad: float, col: Color) -> void:
	# simple filled rounded rect via center + side rects + corner circles
	draw_rect(Rect2(r.position.x + rad, r.position.y, r.size.x - 2 * rad, r.size.y), col)
	draw_rect(Rect2(r.position.x, r.position.y + rad, r.size.x, r.size.y - 2 * rad), col)
	draw_circle(Vector2(r.position.x + rad, r.position.y + rad), rad, col)
	draw_circle(Vector2(r.end.x - rad, r.position.y + rad), rad, col)
	draw_circle(Vector2(r.position.x + rad, r.end.y - rad), rad, col)
	draw_circle(Vector2(r.end.x - rad, r.end.y - rad), rad, col)

func _dots(a: Vector2, b: Vector2, col: Color) -> void:
	var n := int(a.distance_to(b) / 22.0)
	for i in range(n + 1):
		var p := a.lerp(b, float(i) / max(1, n))
		draw_circle(p, 2.5, col)
