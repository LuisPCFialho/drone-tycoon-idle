extends Control
class_name MapView
## Premium dusk aerial map: glowing routes, lit hubs and drones, city lights.

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
	for i in range(6):
		_clouds.append({"x": rng.randf(), "y": rng.randf_range(0.05, 0.5), "s": rng.randf_range(0.6, 1.1), "sp": rng.randf_range(0.008, 0.022)})
	for i in range(30):
		_blocks.append({"x": rng.randf(), "y": rng.randf_range(0.05, 0.97), "w": rng.randf_range(0.05, 0.14), "h": rng.randf_range(0.035, 0.085), "lit": rng.randi_range(1, 4)})
	GameState.delivered.connect(_on_delivered)
	set_process(true)

func _process(delta: float) -> void:
	_t += delta
	for c in _clouds:
		c["x"] += c["sp"] * delta
		if c["x"] > 1.2: c["x"] = -0.25
	var keep: Array = []
	for p in _pops:
		p["life"] -= delta; p["y"] -= 30.0 * delta
		if p["life"] > 0.0: keep.append(p)
	_pops = keep
	queue_redraw()

func _m2s(p: Vector2) -> Vector2:
	return Vector2(p.x * size.x, band_top + p.y * (band_bottom - band_top))

func _draw() -> void:
	var w := size.x
	var h := band_bottom - band_top
	# dusk land gradient
	var top := Color(0.11, 0.17, 0.24)
	var bot := Color(0.05, 0.09, 0.15)
	var steps := 40
	for i in range(steps):
		draw_rect(Rect2(0, band_top + h * float(i) / steps, w, h / steps + 1.0), top.lerp(bot, float(i) / steps))
	# decorative dark city blocks with lit windows
	for b in _blocks:
		var pos := _m2s(Vector2(b["x"], b["y"]))
		var bw: float = b["w"] * w
		var bh: float = b["h"] * h
		_rrect(Rect2(pos.x - bw * 0.5, pos.y - bh * 0.5, bw, bh), 8.0, Color(0.10, 0.13, 0.20, 0.85))
		var lit: int = b["lit"]
		for k in range(lit):
			var lx := pos.x - bw * 0.5 + 6 + (k * 9) % int(max(8.0, bw - 10))
			draw_rect(Rect2(lx, pos.y - bh * 0.3 + (k % 2) * 7, 3, 3), Color(1.0, 0.82, 0.4, 0.7))
	# glowing routes
	var home := _m2s(Economy.hub_pos(0))
	for i in range(1, GameState.hubs_unlocked):
		var hp := _m2s(Economy.hub_pos(i))
		draw_line(home, hp, Color(0.30, 0.85, 0.95, 0.16), 10.0)
		draw_line(home, hp, Color(0.45, 0.95, 1.0, 0.55), 3.0)
		_dots(home, hp, Color(0.8, 1.0, 1.0, 0.6))
	for i in range(GameState.hubs_unlocked, Economy.num_hubs()):
		draw_line(home, _m2s(Economy.hub_pos(i)), Color(0.4, 0.45, 0.6, 0.10), 3.0)
	# hubs
	for i in range(Economy.num_hubs()):
		_draw_hub(i)
	# drones
	for idx in range(GameState.vdrones.size()):
		_draw_drone(idx)
	# faint clouds
	for c in _clouds:
		var cw: float = _cloud.get_width() * c["s"] * 1.7
		var ch: float = _cloud.get_height() * c["s"] * 1.7
		var cpos := _m2s(Vector2(c["x"], c["y"]))
		draw_texture_rect(_cloud, Rect2(cpos.x - cw * 0.5, cpos.y - ch * 0.5, cw, ch), false, Color(0.7, 0.78, 0.9, 0.16))
	_draw_pops()

func _draw_hub(i: int) -> void:
	var pos := _m2s(Economy.hub_pos(i))
	var unlocked := i < GameState.hubs_unlocked
	var s := 86.0 if i == 0 else 74.0
	if unlocked:
		var glow := 0.5 + 0.5 * sin(_t * 2.0 + i)
		draw_circle(pos, s * 0.62 + glow * 5.0, Color(0.3, 0.8, 0.95, 0.12))
		var tex: Texture2D = _hub_home if i == 0 else _hub_city[(i - 1) % _hub_city.size()]
		draw_texture_rect(tex, Rect2(pos.x - s * 0.5, pos.y - s * 0.5, s, s), false)
	else:
		var tex2: Texture2D = _hub_city[(i - 1) % _hub_city.size()]
		draw_texture_rect(tex2, Rect2(pos.x - s * 0.5, pos.y - s * 0.5, s, s), false, Color(0.4, 0.43, 0.5, 0.55))
		if i == GameState.hubs_unlocked:
			_label(Vector2(pos.x, pos.y + s * 0.5 + 4), Fmt.short(Economy.hub_unlock_cost(i)), Color(1, 0.85, 0.4))

func _draw_drone(idx: int) -> void:
	var v: Dictionary = GameState.vdrones[idx]
	var pos: Vector2
	if int(v["route"]) <= 0:
		var home := _m2s(Economy.hub_pos(0))
		pos = home + Vector2(sin(_t * 1.5 + idx) * 26.0, -44.0 - cos(_t * 1.3 + idx) * 10.0)
	else:
		var home := _m2s(Economy.hub_pos(0))
		var hp := _m2s(Economy.hub_pos(int(v["route"])))
		pos = home.lerp(hp, float(v["t"]))
	var tex: Texture2D = _drone_tex[idx % _drone_tex.size()]
	var ds := 46.0
	draw_circle(pos, 22.0, Color(0.4, 0.7, 1.0, 0.10))
	if int(v["dir"]) == 1 and int(v["route"]) > 0:
		draw_texture_rect(_package, Rect2(pos.x - 11, pos.y + 12, 22, 22), false)
	draw_texture_rect(tex, Rect2(pos.x - ds * 0.5, pos.y - ds * 0.5, ds, ds), false)

func _on_delivered(amount: float, hub_index: int) -> void:
	if _pops.size() > 16: return
	var pos := _m2s(Economy.hub_pos(hub_index if hub_index > 0 else 0))
	_pops.append({"text": "+" + Fmt.short(amount), "x": pos.x, "y": pos.y - 28.0, "life": 1.0})

func _draw_pops() -> void:
	if _font == null: return
	for p in _pops:
		var a: float = clamp(p["life"], 0.0, 1.0)
		draw_string(_font, Vector2(p["x"] - 50, p["y"] + 1), p["text"], HORIZONTAL_ALIGNMENT_CENTER, 100, 26, Color(0, 0, 0, a * 0.5))
		draw_string(_font, Vector2(p["x"] - 50, p["y"]), p["text"], HORIZONTAL_ALIGNMENT_CENTER, 100, 26, Color(0.55, 1.0, 0.7, a))

func _label(pos: Vector2, text: String, col: Color) -> void:
	if _font == null: return
	for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		draw_string(_font, Vector2(pos.x - 60, pos.y) + o, text, HORIZONTAL_ALIGNMENT_CENTER, 120, 22, Color(0, 0, 0, 0.8))
	draw_string(_font, Vector2(pos.x - 60, pos.y), text, HORIZONTAL_ALIGNMENT_CENTER, 120, 22, col)

func _rrect(r: Rect2, rad: float, col: Color) -> void:
	draw_rect(Rect2(r.position.x + rad, r.position.y, r.size.x - 2 * rad, r.size.y), col)
	draw_rect(Rect2(r.position.x, r.position.y + rad, r.size.x, r.size.y - 2 * rad), col)
	draw_circle(Vector2(r.position.x + rad, r.position.y + rad), rad, col)
	draw_circle(Vector2(r.end.x - rad, r.position.y + rad), rad, col)
	draw_circle(Vector2(r.position.x + rad, r.end.y - rad), rad, col)
	draw_circle(Vector2(r.end.x - rad, r.end.y - rad), rad, col)

func _dots(a: Vector2, b: Vector2, col: Color) -> void:
	var n := int(a.distance_to(b) / 24.0)
	var phase := fmod(_t * 0.6, 1.0)
	for i in range(n + 1):
		var p := a.lerp(b, clamp((float(i) / max(1, n) + phase) - floor(float(i) / max(1, n) + phase), 0.0, 1.0))
		draw_circle(a.lerp(b, float(i) / max(1, n)), 2.0, col)
