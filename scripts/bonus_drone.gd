extends Control
class_name BonusDrone
## Golden bonus drone that periodically crosses the map band. Tapping it opens
## a reward choice in main.gd (small free reward vs. big rewarded-ad reward).
## Emits `caught(ad_reward)` — ad_reward is randomized per spawn so the popup
## can show the concrete prize before the player commits to watching an ad.

signal caught(ad_reward: Dictionary)

const FLIGHT_TIME := 9.0
const FIRST_WAIT_MIN := 90.0
const FIRST_WAIT_MAX := 150.0
const WAIT_MIN := 180.0
const WAIT_MAX := 360.0

## Possible big (ad) rewards. "kind" is matched in main.gd's popup handler.
const AD_REWARDS := [
	{"kind": "boost", "label": "Lucros ×2 durante 10 min"},
	{"kind": "cash",  "label": "+20 min de lucros imediatos"},
	{"kind": "gems",  "label": "+40 Gemas"},
]

# set by main.gd every frame (same band as the map)
var band_top := 150.0
var band_bottom := 760.0

var _btn: Button
var _glow: TextureRect
var _icon: TextureRect
var _wait := 0.0
var _flying := false
var _t := 0.0            # flight progress 0..1
var _clock := 0.0        # bob/pulse clock
var _from_left := true
var _fly_y := 0.5        # normalized y within the band
var _ad_reward: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wait = randf_range(FIRST_WAIT_MIN, FIRST_WAIT_MAX)

	_btn = Button.new()
	_btn.flat = true
	_btn.custom_minimum_size = Vector2(96, 96)
	_btn.size = Vector2(96, 96)
	_btn.add_theme_stylebox_override("normal",  StyleBoxEmpty.new())
	_btn.add_theme_stylebox_override("hover",   StyleBoxEmpty.new())
	_btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	_btn.add_theme_stylebox_override("focus",   StyleBoxEmpty.new())
	_btn.visible = false
	_btn.pressed.connect(_on_tapped)
	add_child(_btn)

	_glow = TextureRect.new()
	_glow.texture = _load_tex("sun_glow")
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.stretch_mode = TextureRect.STRETCH_SCALE
	_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glow.modulate = Color(1.0, 0.82, 0.25, 0.55)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_btn.add_child(_glow)

	_icon = TextureRect.new()
	_icon.texture = _load_tex("drone_amber")
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon.offset_left = 14; _icon.offset_right = -14
	_icon.offset_top = 14; _icon.offset_bottom = -14
	_icon.modulate = Color(1.0, 0.88, 0.45)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_btn.add_child(_icon)

func _load_tex(n: String) -> Texture2D:
	var path := "res://assets/art/" + n + ".png"
	if ResourceLoader.exists(path):
		return load(path)
	return null

func _process(delta: float) -> void:
	_clock += delta
	if _flying:
		_t += delta / FLIGHT_TIME
		if _t >= 1.0:
			_end_flight()
			return
		var w := size.x
		var x := lerpf(-110.0, w + 110.0, _t) if _from_left else lerpf(w + 110.0, -110.0, _t)
		var bh := band_bottom - band_top
		var y := band_top + _fly_y * bh + sin(_clock * 2.2) * 18.0
		_btn.position = Vector2(x - 48.0, y - 48.0)
		var pulse := 1.0 + 0.10 * sin(_clock * 5.0)
		_glow.scale = Vector2(pulse, pulse)
		_glow.pivot_offset = _glow.size * 0.5
		_icon.rotation = 0.10 * sin(_clock * 3.0) * (1.0 if _from_left else -1.0)
	else:
		_wait -= delta
		if _wait <= 0.0:
			_spawn()

func _spawn() -> void:
	_flying = true
	_t = 0.0
	_from_left = randf() < 0.5
	_fly_y = randf_range(0.18, 0.72)
	var pick: Dictionary = AD_REWARDS[randi() % AD_REWARDS.size()]
	_ad_reward = pick
	_btn.visible = true

func _end_flight() -> void:
	_flying = false
	_btn.visible = false
	_wait = randf_range(WAIT_MIN, WAIT_MAX)

func _on_tapped() -> void:
	if not _flying:
		return
	var reward := _ad_reward
	_end_flight()
	caught.emit(reward)
