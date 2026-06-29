extends RefCounted
class_name UITheme
## Modern dark theme – glassmorphic, vibrant, mobile-first.

const BG0      := Color(0.04, 0.05, 0.10)
const BG1      := Color(0.07, 0.10, 0.18)
const PANEL    := Color(0.10, 0.14, 0.24)
const PANEL2   := Color(0.13, 0.17, 0.28)
const BORDER   := Color(0.20, 0.26, 0.42)
const INK      := Color(0.95, 0.97, 1.00)
const MUTED    := Color(0.52, 0.60, 0.76)
const ACCENT   := Color(0.28, 0.52, 1.00)
const ACCENT_D := Color(0.18, 0.38, 0.82)
const GREEN    := Color(0.13, 0.82, 0.48)
const GREEN_D  := Color(0.08, 0.62, 0.35)
const GOLD     := Color(1.00, 0.78, 0.22)
const GOLD_D   := Color(0.82, 0.58, 0.10)
const CYAN     := Color(0.22, 0.82, 0.95)
const VIOLET   := Color(0.62, 0.42, 1.00)
const PRESTIGE := Color(0.82, 0.62, 1.00)   # prestige gems / prestige UI
const ORANGE   := Color(1.00, 0.52, 0.15)   # events / alerts
const RED      := Color(0.92, 0.28, 0.32)   # error / danger
const PINK     := Color(1.00, 0.40, 0.72)   # special highlight

static func font(weight := "SemiBold") -> FontFile:
	return load("res://assets/fonts/Poppins-%s.ttf" % weight)

static func build() -> Theme:
	var t := Theme.new()
	t.default_font = font("SemiBold"); t.default_font_size = 26
	t.set_stylebox("normal",   "Button", _btn(ACCENT))
	t.set_stylebox("hover",    "Button", _btn(ACCENT.lightened(0.10)))
	t.set_stylebox("pressed",  "Button", _btn(ACCENT_D))
	t.set_stylebox("disabled", "Button", _btn(Color(0.16, 0.20, 0.32)))
	t.set_stylebox("focus",    "Button", StyleBoxEmpty.new())
	t.set_color("font_color",          "Button", Color.WHITE)
	t.set_color("font_hover_color",    "Button", Color.WHITE)
	t.set_color("font_pressed_color",  "Button", Color(0.84, 0.90, 1.0))
	t.set_color("font_disabled_color", "Button", Color(0.36, 0.42, 0.55))
	t.set_font("font", "Button", font("Bold")); t.set_font_size("font_size", "Button", 24)
	t.set_stylebox("panel", "PanelContainer", _panel(PANEL, 20))
	t.set_stylebox("panel", "Panel", _panel(PANEL, 20))
	t.set_color("font_color", "Label", INK)
	t.set_color("font_color", "CheckButton", INK)
	t.set_font_size("font_size", "CheckButton", 24)
	t.set_stylebox("normal", "CheckButton", StyleBoxEmpty.new())
	return t

# ── base helpers ─────────────────────────────────────────────────────────────

static func _btn(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new(); s.bg_color = bg; s.set_corner_radius_all(22)
	s.content_margin_left = 18; s.content_margin_right = 18
	s.content_margin_top = 13; s.content_margin_bottom = 13
	s.border_color = bg.lightened(0.28); s.border_width_top = 2
	s.shadow_color = Color(0,0,0,0.45); s.shadow_size = 8; s.shadow_offset = Vector2(0,4)
	return s

static func _panel(bg: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new(); s.bg_color = bg; s.set_corner_radius_all(radius)
	s.set_content_margin_all(16); s.border_color = BORDER; s.set_border_width_all(1)
	s.shadow_color = Color(0,0,0,0.35); s.shadow_size = 8; s.shadow_offset = Vector2(0,4)
	return s

# ── public style functions ────────────────────────────────────────────────────

## Frosted-glass panel (for HUD overlay on the map)
static func glass() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.09, 0.18, 0.92); s.set_corner_radius_all(22)
	s.set_content_margin_all(14); s.border_color = Color(0.36, 0.52, 0.74, 0.55); s.set_border_width_all(1)
	s.shadow_color = Color(0,0,0,0.55); s.shadow_size = 14; s.shadow_offset = Vector2(0,5)
	return s

## Card with accent-tinted background and glowing border
static func action_card(accent: Color) -> StyleBoxFlat:
	var base := PANEL2.lerp(accent, 0.10)
	var s := _panel(base, 18); s.set_content_margin_all(10)
	s.border_color = lerp(BORDER, accent, 0.60); s.set_border_width_all(1)
	s.shadow_color = Color(accent.r, accent.g, accent.b, 0.22)
	s.shadow_size = 10; s.shadow_offset = Vector2(0, 4)
	return s

## Full-width action button (buy / unlock)
static func action_btn(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new(); s.bg_color = color; s.set_corner_radius_all(14)
	s.content_margin_left = 12; s.content_margin_right = 12
	s.content_margin_top = 11; s.content_margin_bottom = 11
	s.border_color = color.lightened(0.32); s.border_width_top = 2
	s.shadow_color = Color(color.r, color.g, color.b, 0.42)
	s.shadow_size = 8; s.shadow_offset = Vector2(0, 4)
	return s

static func action_btn_disabled() -> StyleBoxFlat:
	var s := StyleBoxFlat.new(); s.bg_color = Color(0.14, 0.18, 0.30); s.set_corner_radius_all(14)
	s.content_margin_left = 12; s.content_margin_right = 12
	s.content_margin_top = 11; s.content_margin_bottom = 11
	return s

## Segmented control button (x1 / x10 / x100 / Max)
static func seg(active: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = ACCENT if active else Color(0.13, 0.17, 0.28); s.set_corner_radius_all(14)
	s.content_margin_left = 10; s.content_margin_right = 10
	s.content_margin_top = 11; s.content_margin_bottom = 11
	if active: s.border_color = ACCENT.lightened(0.32); s.border_width_top = 2
	s.shadow_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.40 if active else 0.0)
	s.shadow_size = 8 if active else 0
	return s

## Bottom-panel background (rounded top, flat bottom)
static func bottom_panel() -> StyleBoxFlat:
	var s := StyleBoxFlat.new(); s.bg_color = Color(0.09, 0.12, 0.22)
	s.corner_radius_top_left = 28; s.corner_radius_top_right = 28
	s.set_content_margin_all(0); s.border_color = BORDER; s.border_width_top = 1
	s.shadow_color = Color(0,0,0,0.50); s.shadow_size = 16; s.shadow_offset = Vector2(0,-6)
	return s

## Nav bar item – active or inactive
static func nav_item(active: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.22 if active else 0.0)
	s.set_corner_radius_all(20); s.set_content_margin_all(6)
	return s

## Ad / rewarded pill button
static func ad_btn() -> StyleBoxFlat:
	var s := StyleBoxFlat.new(); s.bg_color = Color(0.08, 0.44, 0.24); s.set_corner_radius_all(16)
	s.content_margin_left = 14; s.content_margin_right = 14
	s.content_margin_top = 10; s.content_margin_bottom = 10
	s.border_color = GREEN.lightened(0.30); s.border_width_top = 1
	s.shadow_color = Color(0,0.35,0.18,0.40); s.shadow_size = 6; s.shadow_offset = Vector2(0,3)
	return s

## Generic solid colour box (popups, badges, etc.)
static func solid(bg: Color, radius := 16) -> StyleBoxFlat:
	var s := StyleBoxFlat.new(); s.bg_color = bg; s.set_corner_radius_all(radius)
	s.content_margin_left = 14; s.content_margin_right = 14
	s.content_margin_top = 10; s.content_margin_bottom = 10
	s.border_color = bg.lightened(0.24); s.border_width_top = 2
	s.shadow_color = Color(0,0,0,0.32); s.shadow_size = 5; s.shadow_offset = Vector2(0,3)
	return s

## Kept for compat (aliases action_card)
static func card(accent: Color) -> StyleBoxFlat: return action_card(accent)

## Kept for compat
static func pill(bg := PANEL) -> StyleBoxFlat:
	var s := StyleBoxFlat.new(); s.bg_color = bg; s.set_corner_radius_all(24)
	s.content_margin_left = 14; s.content_margin_right = 16
	s.content_margin_top = 8; s.content_margin_bottom = 8
	s.border_color = BORDER; s.set_border_width_all(1)
	return s

## Prestige shop / prestige info card
static func prestige_card() -> StyleBoxFlat:
	var s := _panel(Color(0.16, 0.10, 0.26), 18); s.set_content_margin_all(12)
	s.border_color = Color(PRESTIGE.r, PRESTIGE.g, PRESTIGE.b, 0.60); s.set_border_width_all(1)
	s.shadow_color = Color(PRESTIGE.r, PRESTIGE.g, PRESTIGE.b, 0.25)
	s.shadow_size = 10; s.shadow_offset = Vector2(0, 4)
	return s

## Event banner (colored left border)
static func event_banner(col: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(col.r, col.g, col.b, 0.18); s.set_corner_radius_all(14)
	s.set_content_margin_all(12)
	s.border_color = col; s.border_width_left = 4
	return s

## Achievement card
static func achievement_card(done: bool) -> StyleBoxFlat:
	var bg := Color(0.12, 0.16, 0.28) if not done else Color(0.08, 0.22, 0.14)
	var s := _panel(bg, 14); s.set_content_margin_all(10)
	if done:
		s.border_color = Color(GREEN.r, GREEN.g, GREEN.b, 0.55); s.set_border_width_all(1)
	return s

## Progress bar background
static func prog_bg() -> StyleBoxFlat:
	var s := StyleBoxFlat.new(); s.bg_color = Color(0.12, 0.16, 0.28); s.set_corner_radius_all(6)
	return s

## Progress bar fill (colour = accent/green/gold based on context)
static func prog_fill(col: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new(); s.bg_color = col; s.set_corner_radius_all(6)
	s.shadow_color = Color(col.r, col.g, col.b, 0.45); s.shadow_size = 4
	return s

## Daily reward card
static func daily_card(claimed: bool, current: bool) -> StyleBoxFlat:
	var bg: Color
	if claimed:   bg = Color(0.08, 0.22, 0.14)
	elif current: bg = Color(0.20, 0.16, 0.06)
	else:         bg = PANEL
	var s := _panel(bg, 14); s.set_content_margin_all(8)
	if current:
		s.border_color = GOLD; s.set_border_width_all(2)
		s.shadow_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.40); s.shadow_size = 8
	return s

## Danger / destructive button (prestige confirm, wipe)
static func danger_btn() -> StyleBoxFlat:
	var s := StyleBoxFlat.new(); s.bg_color = Color(0.55, 0.10, 0.14); s.set_corner_radius_all(14)
	s.content_margin_left = 16; s.content_margin_right = 16
	s.content_margin_top = 12; s.content_margin_bottom = 12
	s.border_color = RED.lightened(0.20); s.border_width_top = 2
	s.shadow_color = Color(RED.r, RED.g, RED.b, 0.40); s.shadow_size = 8; s.shadow_offset = Vector2(0, 4)
	return s

## Glowing "ready to prestige" button
static func prestige_btn_ready() -> StyleBoxFlat:
	var s := StyleBoxFlat.new(); s.bg_color = Color(0.42, 0.18, 0.62); s.set_corner_radius_all(18)
	s.content_margin_left = 18; s.content_margin_right = 18
	s.content_margin_top = 14; s.content_margin_bottom = 14
	s.border_color = PRESTIGE.lightened(0.25); s.border_width_top = 2
	s.shadow_color = Color(PRESTIGE.r, PRESTIGE.g, PRESTIGE.b, 0.55); s.shadow_size = 16; s.shadow_offset = Vector2(0, 4)
	return s
