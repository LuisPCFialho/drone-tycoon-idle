extends Control
class_name MapView
## Draws the current country: real outline polygon, geographically-placed cities
## (capital / active / locked), routes and delivery drones. Reads GameState/Economy.

var band_top := 150.0
var band_bottom := 760.0

var _t := 0.0
var _font: Font
var _pops: Array = []
var _drone_tex: Array = []
var _package: Texture2D

const LAND := Color(0.16, 0.30, 0.34)
const LAND_HI := Color(0.22, 0.42, 0.46)
const BORDER := Color(0.45, 0.95, 0.95)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = UITheme.font("Bold")
	_drone_tex = [load("res://assets/art/drone_blue.png"), load("res://assets/art/drone_teal.png"), load("res://assets/art/drone_amber.png")]
	_package = load("res://assets/art/package.png")
	GameState.delivered.connect(_on_delivered)
	set_process(true)

func _process(delta: float) -> void:
	_t += delta
	var keep: Array = []
	for p in _pops:
		p["life"] -= delta; p["y"] -= 30.0 * delta
		if p["life"] > 0.0: keep.append(p)
	_pops = keep
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
	# sea gradient backdrop
	var top := Color(0.06, 0.12, 0.20); var bot := Color(0.03, 0.07, 0.13)
	for i in range(36):
		draw_rect(Rect2(0, band_top + h * float(i) / 36.0, w, h / 36.0 + 1.0), top.lerp(bot, float(i) / 36.0))

	var ci := GameState.current_country
	var outline := Economy.country_outline(ci)
	if outline.size() >= 3:
		var pts := PackedVector2Array()
		for p in outline:
			pts.append(_proj(p))
		draw_colored_polygon(pts, LAND)
		# subtle inner highlight + glowing coastline
		var glow := 0.5 + 0.5 * sin(_t * 1.5)
		var closed := pts; closed.append(pts[0])
		draw_polyline(closed, Color(BORDER.r, BORDER.g, BORDER.b, 0.25), 6.0, true)
		draw_polyline(closed, Color(BORDER.r, BORDER.g, BORDER.b, 0.7 + 0.2 * glow), 2.5, true)

	var cities := Economy.country_cities(ci)
	if cities.is_empty():
		return
	var cap := _proj(Vector2(cities[0]["x"], cities[0]["y"]))

	# routes (active)
	for r in range(GameState.cities_unlocked):
		var idx: int = 1 + r
		if idx >= cities.size(): continue
		var cp := _proj(Vector2(cities[idx]["x"], cities[idx]["y"]))
		draw_line(cap, cp, Color(0.4, 0.9, 1.0, 0.18), 7.0)
		draw_line(cap, cp, Color(0.6, 0.97, 1.0, 0.5), 2.0)

	# drones
	for di in range(GameState.vdrones.size()):
		var v: Dictionary = GameState.vdrones[di]
		var rr: int = clampi(1 + int(v["route"]), 1, cities.size() - 1)
		var b := _proj(Vector2(cities[rr]["x"], cities[rr]["y"]))
		var pos := cap.lerp(b, float(v["t"]))
		draw_circle(pos, 18.0, Color(0.4, 0.7, 1.0, 0.10))
		if int(v["dir"]) == 1:
			draw_texture_rect(_package, Rect2(pos.x - 9, pos.y + 9, 18, 18), false)
		var tex: Texture2D = _drone_tex[di % _drone_tex.size()]
		draw_texture_rect(tex, Rect2(pos.x - 20, pos.y - 20, 40, 40), false)

	# cities
	for i in range(cities.size()):
		var cp := _proj(Vector2(cities[i]["x"], cities[i]["y"]))
		var nm: String = cities[i]["name"]
		if i == 0:
			_city_dot(cp, Color(1.0, 0.82, 0.3), 11.0, true)
			_label(cp, nm + " (sede)", Color(1, 0.9, 0.5))
		elif i <= GameState.cities_unlocked:
			_city_dot(cp, Color(0.4, 0.95, 0.95), 8.0, false)
			_label(cp, nm, Color(0.8, 1, 1))
		else:
			_city_dot(cp, Color(0.4, 0.45, 0.55), 6.0, false)
			if i == GameState.cities_unlocked + 1:
				_label(cp, nm + "  " + Fmt.short(Economy.city_unlock_cost(ci, GameState.cities_unlocked)), Color(0.7, 0.75, 0.85))

	_draw_pops()

func _city_dot(p: Vector2, col: Color, r: float, capital: bool) -> void:
	var pulse := 0.5 + 0.5 * sin(_t * 3.0)
	draw_circle(p, r + 6.0 + pulse * 3.0, Color(col.r, col.g, col.b, 0.16))
	draw_circle(p, r, col)
	draw_circle(p, r * 0.45, Color(1, 1, 1, 0.85))
	if capital:
		draw_arc(p, r + 5.0, 0, TAU, 24, Color(col.r, col.g, col.b, 0.8), 2.0)

func _label(p: Vector2, text: String, col: Color) -> void:
	if _font == null: return
	var w := 220.0
	draw_string(_font, Vector2(p.x - w * 0.5, p.y + 26), text, HORIZONTAL_ALIGNMENT_CENTER, w, 18, Color(0, 0, 0, 0.6))
	draw_string(_font, Vector2(p.x - w * 0.5, p.y + 25), text, HORIZONTAL_ALIGNMENT_CENTER, w, 18, col)

func _on_delivered(amount: float, city_index: int) -> void:
	if _pops.size() > 16: return
	var cities := Economy.country_cities(GameState.current_country)
	var idx: int = clampi(city_index, 0, cities.size() - 1)
	var p := _proj(Vector2(cities[idx]["x"], cities[idx]["y"]))
	_pops.append({"text": "+" + Fmt.short(amount), "x": p.x, "y": p.y - 22.0, "life": 1.0})

func _draw_pops() -> void:
	if _font == null: return
	for p in _pops:
		var a: float = clamp(p["life"], 0.0, 1.0)
		draw_string(_font, Vector2(p["x"] - 50, p["y"] + 1), p["text"], HORIZONTAL_ALIGNMENT_CENTER, 100, 24, Color(0, 0, 0, a * 0.5))
		draw_string(_font, Vector2(p["x"] - 50, p["y"]), p["text"], HORIZONTAL_ALIGNMENT_CENTER, 100, 24, Color(0.55, 1.0, 0.7, a))
