extends RefCounted
class_name UITheme
## Modern flat UI theme: rounded cards, soft shadows, Poppins, vibrant palette.

const INK := Color(0.06, 0.09, 0.16)
const MUTED := Color(0.45, 0.5, 0.58)
const CARD := Color(1, 1, 1)
const ACCENT := Color(0.23, 0.51, 0.96)
const ACCENT_D := Color(0.15, 0.39, 0.86)
const GREEN := Color(0.13, 0.7, 0.4)
const GREEN_D := Color(0.1, 0.56, 0.33)

static func font(weight := "SemiBold") -> FontFile:
	var f := load("res://assets/fonts/Poppins-%s.ttf" % weight)
	return f

static func build() -> Theme:
	var t := Theme.new()
	t.default_font = font("SemiBold")
	t.default_font_size = 30

	t.set_stylebox("normal", "Button", _btn(ACCENT))
	t.set_stylebox("hover", "Button", _btn(ACCENT.lightened(0.06)))
	t.set_stylebox("pressed", "Button", _btn(ACCENT_D))
	t.set_stylebox("disabled", "Button", _btn(Color(0.78, 0.81, 0.85)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.95, 0.96, 0.98))
	t.set_font_size("font_size", "Button", 28)

	var card := _card(CARD, 18, true)
	t.set_stylebox("panel", "PanelContainer", card)

	t.set_stylebox("panel", "TabContainer", _card(Color(0.96, 0.97, 0.99), 18, false))
	t.set_stylebox("tab_selected", "TabContainer", _btn(ACCENT))
	t.set_stylebox("tab_unselected", "TabContainer", _card(Color(0.90, 0.92, 0.95), 12, false))
	t.set_stylebox("tab_hovered", "TabContainer", _card(Color(0.93, 0.95, 0.98), 12, false))
	t.set_color("font_selected_color", "TabContainer", Color.WHITE)
	t.set_color("font_unselected_color", "TabContainer", MUTED)
	t.set_font_size("font_size", "TabContainer", 24)

	t.set_color("font_color", "Label", INK)
	t.set_color("font_color", "CheckButton", INK)
	t.set_font_size("font_size", "CheckButton", 26)
	return t

static func _btn(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 14; sb.content_margin_right = 14
	sb.content_margin_top = 10; sb.content_margin_bottom = 10
	sb.shadow_color = Color(0.1, 0.15, 0.3, 0.18)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 3)
	return sb

static func _card(bg: Color, radius: int, shadow: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(12)
	sb.border_color = Color(0.86, 0.89, 0.93)
	sb.set_border_width_all(1)
	if shadow:
		sb.shadow_color = Color(0.1, 0.15, 0.3, 0.14)
		sb.shadow_size = 6
		sb.shadow_offset = Vector2(0, 4)
	return sb
