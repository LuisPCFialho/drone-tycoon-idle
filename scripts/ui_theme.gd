extends RefCounted
class_name UITheme
## Premium dark UI theme: deep navy panels, vibrant accents, soft shadows, Poppins.

const BG0 := Color(0.055, 0.07, 0.13)
const BG1 := Color(0.09, 0.12, 0.20)
const PANEL := Color(0.13, 0.16, 0.27)
const PANEL2 := Color(0.16, 0.20, 0.33)
const BORDER := Color(0.24, 0.30, 0.46)
const INK := Color(0.93, 0.96, 1.0)
const MUTED := Color(0.60, 0.67, 0.80)
const ACCENT := Color(0.32, 0.56, 1.0)
const ACCENT_D := Color(0.22, 0.42, 0.85)
const GREEN := Color(0.16, 0.78, 0.45)
const GREEN_D := Color(0.11, 0.62, 0.35)
const GOLD := Color(1.0, 0.80, 0.28)
const CYAN := Color(0.30, 0.85, 0.95)
const VIOLET := Color(0.66, 0.45, 1.0)

static func font(weight := "SemiBold") -> FontFile:
	return load("res://assets/fonts/Poppins-%s.ttf" % weight)

static func build() -> Theme:
	var t := Theme.new()
	t.default_font = font("SemiBold")
	t.default_font_size = 30

	t.set_stylebox("normal", "Button", _btn(ACCENT))
	t.set_stylebox("hover", "Button", _btn(ACCENT.lightened(0.07)))
	t.set_stylebox("pressed", "Button", _btn(ACCENT_D))
	t.set_stylebox("disabled", "Button", _btn(Color(0.22, 0.26, 0.36)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", Color.WHITE)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color(0.9, 0.94, 1))
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.55, 0.66))
	t.set_font("font", "Button", font("Bold"))
	t.set_font_size("font_size", "Button", 27)

	t.set_stylebox("panel", "PanelContainer", _panel(PANEL, 16))

	t.set_stylebox("panel", "TabContainer", _panel(BG1, 16))
	t.set_stylebox("tab_selected", "TabContainer", _tab(ACCENT))
	t.set_stylebox("tab_unselected", "TabContainer", _tab(Color(0.16, 0.19, 0.30)))
	t.set_stylebox("tab_hovered", "TabContainer", _tab(Color(0.2, 0.24, 0.38)))
	t.set_color("font_selected_color", "TabContainer", Color.WHITE)
	t.set_color("font_unselected_color", "TabContainer", MUTED)
	t.set_font_size("font_size", "TabContainer", 23)
	t.set_constant("side_margin", "TabContainer", 4)

	t.set_color("font_color", "Label", INK)
	t.set_color("font_color", "CheckButton", INK)
	t.set_font_size("font_size", "CheckButton", 26)
	return t

static func _btn(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(22)
	sb.content_margin_left = 18; sb.content_margin_right = 18
	sb.content_margin_top = 14; sb.content_margin_bottom = 14
	sb.border_color = bg.lightened(0.22)
	sb.border_width_top = 2
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6; sb.shadow_offset = Vector2(0, 4)
	return sb

static func _panel(bg: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(maxi(radius, 20))
	sb.set_content_margin_all(14)
	sb.border_color = BORDER
	sb.set_border_width_all(1)
	sb.shadow_color = Color(0, 0, 0, 0.30)
	sb.shadow_size = 7; sb.shadow_offset = Vector2(0, 4)
	return sb

static func _tab(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = 12; sb.corner_radius_top_right = 12
	sb.content_margin_left = 10; sb.content_margin_right = 10
	sb.content_margin_top = 8; sb.content_margin_bottom = 8
	return sb

## Pill/card stylebox with an accent left stripe.
static func card(accent: Color) -> StyleBoxFlat:
	var sb := _panel(PANEL2, 14)
	sb.border_width_left = 5
	sb.border_color = accent
	return sb

static func pill(bg := PANEL) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(22)
	sb.content_margin_left = 12; sb.content_margin_right = 14
	sb.content_margin_top = 6; sb.content_margin_bottom = 6
	sb.border_color = BORDER; sb.set_border_width_all(1)
	return sb

static func solid(bg: Color, radius := 14) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 14; sb.content_margin_right = 14
	sb.content_margin_top = 10; sb.content_margin_bottom = 10
	sb.border_color = bg.lightened(0.2); sb.border_width_top = 2
	sb.shadow_color = Color(0, 0, 0, 0.3); sb.shadow_size = 4; sb.shadow_offset = Vector2(0, 2)
	return sb
