extends Control
## Main scene — Drone Tycoon: Sky Fleet

const NAV_H  := 100.0   # nav bar height
const TABS_H := 560.0   # tab content height
const AD_H   := 50.0    # ad pill bar height
const ART    := "res://assets/art/"

var _map: MapView
var _hud: PanelContainer
var _adbar: HBoxContainer
var _pages: Array
var _nav_btns: Array
var _toasts: VBoxContainer

var _credits_lbl: Label
var _gems_lbl: Label
var _infl_lbl: Label
var _income_lbl: Label
var _country_lbl: Label
var _vip_badge: PanelContainer
var _disp_credits := 0.0

var _rows := {}
var _talent_rows := {}
var _gem_rows := {}
var _mode_btns := {}
var _drone_btn: Button
var _drone_detail: Label
var _city_btn: Button
var _city_detail: Label
var _expand_btn: Button
var _expand_detail: Label
var _progress_lbl: Label

func _ready() -> void:
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.build()
	_bg(); _build_map(); _build_hud(); _build_adbar()
	_build_bottom_bg(); _build_pages(); _build_nav(); _build_toasts()
	GameState.city_unlocked.connect(func(_i): _toast("Cidade desbloqueada!", UITheme.CYAN))
	GameState.country_changed.connect(func(i): _toast("Bem-vindo a " + Economy.country_name(i) + "!", UITheme.GOLD))
	var loaded := SaveSystem.load_game()
	_disp_credits = GameState.credits
	if loaded and GameState.pending_offline > 1.0:
		_show_offline_popup(GameState.pending_offline, GameState.pending_offline_seconds)
	_switch_tab(0)

# ── background ───────────────────────────────────────────────────────────────

func _bg() -> void:
	var grad := Gradient.new(); grad.set_color(0, UITheme.BG0); grad.set_color(1, UITheme.BG1)
	var gt := GradientTexture2D.new(); gt.gradient = grad; gt.fill_from = Vector2(0,0); gt.fill_to = Vector2(0,1); gt.width = 16; gt.height = 128
	var bg := TextureRect.new(); bg.texture = gt; bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE; bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(bg)

func _build_map() -> void:
	_map = MapView.new(); _map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(_map)

# ── HUD (glass bar at top) ────────────────────────────────────────────────────

func _build_hud() -> void:
	_hud = PanelContainer.new()
	_hud.anchor_left = 0; _hud.anchor_right = 1; _hud.anchor_top = 0; _hud.anchor_bottom = 0
	_hud.offset_left = 14; _hud.offset_right = -14; _hud.offset_top = 24
	_hud.add_theme_stylebox_override("panel", UITheme.glass())
	add_child(_hud)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 8); _hud.add_child(v)

	# Row 1: stat chips + gear
	var r1 := HBoxContainer.new(); r1.add_theme_constant_override("separation", 8); v.add_child(r1)
	var c1 := _stat_chip("ic_credits", UITheme.GOLD,   26); _credits_lbl = c1["label"]; r1.add_child(c1["root"])
	var c2 := _stat_chip("ic_gems",    UITheme.CYAN,   26); _gems_lbl   = c2["label"]; r1.add_child(c2["root"])
	var c3 := _stat_chip("ic_prestige",UITheme.VIOLET, 26); _infl_lbl   = c3["label"]; r1.add_child(c3["root"])
	_vip_badge = PanelContainer.new(); _vip_badge.add_theme_stylebox_override("panel", UITheme.solid(UITheme.GOLD, 18))
	var vl := Label.new(); vl.text = "VIP"; vl.add_theme_font_size_override("font_size", 18)
	vl.add_theme_color_override("font_color", Color(0.12, 0.08, 0.0))
	vl.add_theme_font_override("font", UITheme.font("Bold")); _vip_badge.add_child(vl)
	_vip_badge.visible = false; r1.add_child(_vip_badge)
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; r1.add_child(sp)
	var gear := Button.new(); gear.text = "⚙"; gear.add_theme_font_size_override("font_size", 28)
	gear.custom_minimum_size = Vector2(56, 56)
	gear.add_theme_stylebox_override("normal",  UITheme.nav_item(false))
	gear.add_theme_stylebox_override("hover",   UITheme.nav_item(true))
	gear.add_theme_stylebox_override("focus",   StyleBoxEmpty.new())
	gear.add_theme_color_override("font_color", UITheme.MUTED)
	gear.pressed.connect(_show_settings); r1.add_child(gear)

	# Row 2: country + income
	var r2 := HBoxContainer.new(); r2.add_theme_constant_override("separation", 6); v.add_child(r2)
	_country_lbl = Label.new(); _country_lbl.add_theme_font_size_override("font_size", 20)
	_country_lbl.add_theme_color_override("font_color", UITheme.MUTED)
	_country_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; r2.add_child(_country_lbl)
	_income_lbl = Label.new(); _income_lbl.add_theme_font_size_override("font_size", 22)
	_income_lbl.add_theme_color_override("font_color", UITheme.GREEN)
	_income_lbl.add_theme_font_override("font", UITheme.font("Bold"))
	_income_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; r2.add_child(_income_lbl)

func _stat_chip(icon: String, color: Color, lbl_size: int) -> Dictionary:
	var pc := PanelContainer.new()
	var s := StyleBoxFlat.new(); s.bg_color = Color(color.r, color.g, color.b, 0.18)
	s.set_corner_radius_all(18); s.content_margin_left = 10; s.content_margin_right = 10
	s.content_margin_top = 6; s.content_margin_bottom = 6
	pc.add_theme_stylebox_override("panel", s)
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 5); pc.add_child(h)
	h.add_child(_icon(icon, 24))
	var lbl := Label.new(); lbl.add_theme_font_size_override("font_size", lbl_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_override("font", UITheme.font("Bold")); h.add_child(lbl)
	return {"root": pc, "label": lbl}

# ── Ad / rewarded pill bar ─────────────────────────────────────────────────────

func _build_adbar() -> void:
	_adbar = HBoxContainer.new()
	_adbar.anchor_left = 0; _adbar.anchor_right = 1
	_adbar.anchor_top = 1; _adbar.anchor_bottom = 1
	_adbar.offset_top = -(NAV_H + TABS_H + AD_H); _adbar.offset_bottom = -(NAV_H + TABS_H)
	_adbar.offset_left = 10; _adbar.offset_right = -10
	_adbar.add_theme_constant_override("separation", 8); add_child(_adbar)
	_adbar.add_child(_ad_pill("📺", "2× 5min",
		func(): Ads.show_rewarded("x2", GameState.boost_earn_2x)))
	_adbar.add_child(_ad_pill("💰", "30min grátis",
		func(): Ads.show_rewarded("cash", func(): GameState.grant_cash_minutes(30); _disp_credits = GameState.credits; _toast("+30min lucros!", UITheme.GREEN))))
	_adbar.add_child(_ad_pill("💎", "+60 Gemas",
		func(): Ads.show_rewarded("gems", func(): GameState.grant_gems(60); _toast("+60 Gemas!", UITheme.CYAN))))

func _ad_pill(emoji: String, text: String, cb: Callable) -> Button:
	var b := Button.new(); b.text = emoji + " " + text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, AD_H - 8)
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_stylebox_override("normal",  UITheme.ad_btn())
	b.add_theme_stylebox_override("hover",   UITheme.ad_btn())
	b.add_theme_stylebox_override("pressed", UITheme.solid(UITheme.GREEN_D, 14))
	b.add_theme_stylebox_override("focus",   StyleBoxEmpty.new())
	b.pressed.connect(cb); return b

# ── Bottom background panel ────────────────────────────────────────────────────

func _build_bottom_bg() -> void:
	var bg := Panel.new()
	bg.anchor_left = 0; bg.anchor_right = 1
	bg.anchor_top = 1; bg.anchor_bottom = 1
	bg.offset_top = -(NAV_H + TABS_H + AD_H); bg.offset_bottom = 0
	bg.add_theme_stylebox_override("panel", UITheme.bottom_panel())
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(bg)

# ── Pages — added directly to Main Control, each with own anchor offsets ──────

func _build_pages() -> void:
	_pages = [_build_fleet_tab(), _build_cities_tab(), _build_talents_tab(), _build_shop_tab()]
	for pg in _pages:
		add_child(pg)

# ── Custom nav bar ─────────────────────────────────────────────────────────────

func _build_nav() -> void:
	var sep := ColorRect.new(); sep.color = UITheme.BORDER
	sep.anchor_left = 0; sep.anchor_right = 1; sep.anchor_top = 1; sep.anchor_bottom = 1
	sep.offset_top = -NAV_H - 1; sep.offset_bottom = -NAV_H
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(sep)

	var nav := HBoxContainer.new()
	nav.anchor_left = 0; nav.anchor_right = 1
	nav.anchor_top = 1; nav.anchor_bottom = 1
	nav.offset_top = -NAV_H; nav.offset_bottom = 0
	nav.add_theme_constant_override("separation", 0)
	add_child(nav)

	var tab_defs := [["🚁","Frota"],["🌍","Cidades"],["⭐","Talentos"],["💎","Loja"]]
	for i in tab_defs.size():
		nav.add_child(_make_nav_btn(tab_defs[i][0], tab_defs[i][1], i))

func _make_nav_btn(emoji: String, label_text: String, idx: int) -> Button:
	var btn := Button.new()
	btn.text = emoji + "\n" + label_text
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, NAV_H)
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_stylebox_override("normal",  UITheme.nav_item(false))
	btn.add_theme_stylebox_override("hover",   UITheme.nav_item(false))
	btn.add_theme_stylebox_override("pressed", UITheme.nav_item(true))
	btn.add_theme_stylebox_override("focus",   StyleBoxEmpty.new())
	btn.pressed.connect(func(): _switch_tab(idx))
	_nav_btns.append(btn); return btn

func _switch_tab(i: int) -> void:
	for j in _pages.size():
		_pages[j].visible = (j == i)
	for j in _nav_btns.size():
		var active := (j == i)
		_nav_btns[j].add_theme_stylebox_override("normal", UITheme.nav_item(active))
		_nav_btns[j].add_theme_stylebox_override("hover",  UITheme.nav_item(active))
		_nav_btns[j].modulate = UITheme.ACCENT if active else Color.WHITE

# ── Scroll page wrapper ────────────────────────────────────────────────────────

func _scroll(title: String) -> Array:
	var sc := ScrollContainer.new(); sc.name = title
	sc.anchor_left = 0; sc.anchor_right = 1
	sc.anchor_top = 1; sc.anchor_bottom = 1
	sc.offset_top = -(NAV_H + TABS_H); sc.offset_bottom = -NAV_H
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	sc.add_child(v)
	return [sc, v]

# ── Tab content ────────────────────────────────────────────────────────────────

func _build_fleet_tab() -> ScrollContainer:
	var r := _scroll("Frota"); var v: VBoxContainer = r[1]

	# Segmented buy-mode selector
	var seg_row := HBoxContainer.new(); seg_row.add_theme_constant_override("separation", 5); v.add_child(seg_row)
	for m in [[1,"×1"],[10,"×10"],[100,"×100"],[-1,"Máx"]]:
		var mode_val: int = m[0]; var mode_lbl: String = m[1]
		var b := Button.new(); b.text = mode_lbl; b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 48); b.add_theme_font_size_override("font_size", 20)
		b.add_theme_stylebox_override("normal",  UITheme.seg(false))
		b.add_theme_stylebox_override("hover",   UITheme.seg(false))
		b.add_theme_stylebox_override("pressed", UITheme.seg(true))
		b.add_theme_stylebox_override("focus",   StyleBoxEmpty.new())
		b.pressed.connect(func(): GameState.buy_mode = mode_val)
		seg_row.add_child(b); _mode_btns[mode_val] = b

	# Drone card
	var dp := _card(UITheme.ACCENT)
	var dv := VBoxContainer.new(); dv.add_theme_constant_override("separation", 8); dp.add_child(dv)
	var dh := HBoxContainer.new(); dh.add_theme_constant_override("separation", 10); dv.add_child(dh)
	dh.add_child(_icon("ic_drone", 34))
	var dl := VBoxContainer.new(); dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; dh.add_child(dl)
	dl.add_child(_lbl("Comprar Drones", 20, UITheme.INK))
	_drone_detail = _lbl("", 15, UITheme.MUTED); dl.add_child(_drone_detail)
	_drone_btn = _wide_btn(UITheme.GREEN)
	_drone_btn.pressed.connect(func(): if GameState.buy_drones() > 0: _pulse(_drone_btn); Audio.play("buy"))
	dv.add_child(_drone_btn); v.add_child(dp)
	for key in ["speed", "cargo", "value"]: v.add_child(_make_upgrade_row(key))
	return r[0]

func _build_cities_tab() -> ScrollContainer:
	var r := _scroll("Cidades"); var v: VBoxContainer = r[1]
	_progress_lbl = _lbl("", 17, UITheme.MUTED); _progress_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.add_child(_progress_lbl)

	var cp := _card(UITheme.CYAN)
	var cv := VBoxContainer.new(); cv.add_theme_constant_override("separation", 8); cp.add_child(cv)
	var ch := HBoxContainer.new(); ch.add_theme_constant_override("separation", 10); cv.add_child(ch)
	ch.add_child(_icon("ic_range", 34))
	var cl := VBoxContainer.new(); cl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; ch.add_child(cl)
	cl.add_child(_lbl("Abrir Cidade", 20, UITheme.INK))
	_city_detail = _lbl("", 15, UITheme.MUTED); _city_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; cl.add_child(_city_detail)
	_city_btn = _wide_btn(UITheme.CYAN.darkened(0.10))
	_city_btn.pressed.connect(func(): if GameState.unlock_city(): _pulse(_city_btn); Audio.play("buy"))
	cv.add_child(_city_btn); v.add_child(cp)

	var ep := _card(UITheme.GOLD)
	var ev := VBoxContainer.new(); ev.add_theme_constant_override("separation", 8); ep.add_child(ev)
	var eh := HBoxContainer.new(); eh.add_theme_constant_override("separation", 10); ev.add_child(eh)
	eh.add_child(_icon("ic_boost", 34))
	var el := VBoxContainer.new(); el.size_flags_horizontal = Control.SIZE_EXPAND_FILL; eh.add_child(el)
	el.add_child(_lbl("Expandir para o próximo país", 20, UITheme.INK))
	_expand_detail = _lbl("", 15, UITheme.MUTED); _expand_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; el.add_child(_expand_detail)
	_expand_btn = _wide_btn(UITheme.GOLD.darkened(0.08))
	_expand_btn.pressed.connect(func(): if GameState.expand_country(): _pulse(_expand_btn); Audio.play("buy"))
	ev.add_child(_expand_btn); v.add_child(ep)
	return r[0]

func _build_talents_tab() -> ScrollContainer:
	var r := _scroll("Talentos"); var v: VBoxContainer = r[1]
	var info := _lbl("Influência ganha-se ao expandir países.\nGasta-a em bónus PERMANENTES.", 17, UITheme.MUTED)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.add_child(info)
	for key in Economy.TALENT_ORDER: v.add_child(_make_talent_row(key))
	return r[0]

func _build_shop_tab() -> ScrollContainer:
	var r := _scroll("Loja"); var v: VBoxContainer = r[1]
	var gi := _card(UITheme.CYAN)
	var gv := VBoxContainer.new(); gv.add_theme_constant_override("separation", 4); gi.add_child(gv)
	gv.add_child(_lbl("💎 Gemas — compra com anúncios (acima)", 18, UITheme.CYAN))
	v.add_child(gi)
	for id in Economy.GEM_SHOP_ORDER: v.add_child(_make_gem_row(id))

	var sep_lbl := _lbl("— Compras com dinheiro real —", 17, UITheme.MUTED)
	sep_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(sep_lbl)
	for id in Billing.PRODUCT_ORDER: v.add_child(_make_iap_row(id))
	return r[0]

# ── Card widgets ───────────────────────────────────────────────────────────────

func _card(accent: Color) -> PanelContainer:
	var p := PanelContainer.new(); p.add_theme_stylebox_override("panel", UITheme.action_card(accent)); return p

func _wide_btn(color: Color) -> Button:
	var b := Button.new(); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 22); b.add_theme_font_override("font", UITheme.font("Bold"))
	b.add_theme_stylebox_override("normal",   UITheme.action_btn(color))
	b.add_theme_stylebox_override("hover",    UITheme.action_btn(color.lightened(0.10)))
	b.add_theme_stylebox_override("pressed",  UITheme.action_btn(color.darkened(0.12)))
	b.add_theme_stylebox_override("disabled", UITheme.action_btn_disabled())
	b.add_theme_stylebox_override("focus",    StyleBoxEmpty.new()); return b

func _make_upgrade_row(key: String) -> PanelContainer:
	var accent_map := {"speed": UITheme.ACCENT, "cargo": UITheme.GOLD, "value": UITheme.GREEN}
	var accent: Color = accent_map.get(key, UITheme.ACCENT)
	var panel := _card(accent)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 8); panel.add_child(v)
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 10); v.add_child(h)
	h.add_child(_icon(Economy.UPGRADES[key].get("icon", "ic_speed"), 34))
	var info := VBoxContainer.new(); info.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(info)
	info.add_child(_lbl(Economy.UPGRADES[key]["name"], 20, UITheme.INK))
	var detail := _lbl("", 15, UITheme.MUTED); info.add_child(detail)
	var btn := _wide_btn(UITheme.GREEN)
	btn.pressed.connect(func(): if GameState.buy_upgrade_multi(key) > 0: _pulse(btn); Audio.play("buy"))
	v.add_child(btn); _rows[key] = {"btn": btn, "detail": detail}; return panel

func _make_talent_row(key: String) -> PanelContainer:
	var p: Dictionary = Economy.TALENTS[key]
	var panel := _card(UITheme.VIOLET)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 8); panel.add_child(v)
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 10); v.add_child(h)
	h.add_child(_icon(p.get("icon", "ic_prestige"), 34))
	var info := VBoxContainer.new(); info.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(info)
	info.add_child(_lbl(p["name"], 20, UITheme.INK))
	var detail := _lbl("", 15, UITheme.MUTED); info.add_child(detail)
	var btn := _wide_btn(UITheme.VIOLET.darkened(0.10))
	btn.pressed.connect(func(): if GameState.buy_talent(key): _pulse(btn); Audio.play("buy"))
	v.add_child(btn); _talent_rows[key] = {"btn": btn, "detail": detail}; return panel

func _make_gem_row(id: String) -> PanelContainer:
	var p: Dictionary = Economy.GEM_SHOP[id]
	var panel := _card(UITheme.CYAN)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 8); panel.add_child(v)
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 10); v.add_child(h)
	h.add_child(_icon(p.get("icon", "ic_gems"), 34))
	var info := VBoxContainer.new(); info.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(info)
	info.add_child(_lbl(p["name"], 20, UITheme.INK))
	var dd := _lbl(p["desc"], 15, UITheme.MUTED); dd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; info.add_child(dd)
	var btn := _wide_btn(UITheme.CYAN.darkened(0.18))
	btn.pressed.connect(func(): _buy_gem(id, btn)); v.add_child(btn); _gem_rows[id] = {"btn": btn}; return panel

func _make_iap_row(id: String) -> PanelContainer:
	var p: Dictionary = Billing.PRODUCTS[id]
	var panel := _card(UITheme.GOLD)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 8); panel.add_child(v)
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 10); v.add_child(h)
	h.add_child(_icon("ic_gems" if id.begins_with("gems") else "ic_boost", 34))
	var info := VBoxContainer.new(); info.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(info)
	info.add_child(_lbl(p["name"], 20, UITheme.INK))
	var dd := _lbl(p["desc"], 15, UITheme.MUTED); dd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; info.add_child(dd)
	var btn := _wide_btn(UITheme.GOLD.darkened(0.06)); btn.text = p["price"]
	btn.add_theme_color_override("font_color", Color(0.12, 0.08, 0.0))
	btn.pressed.connect(func(): Billing.buy(id); _pulse(btn); Audio.play("buy")); v.add_child(btn); return panel

func _buy_gem(id: String, btn: Button) -> void:
	var ok := false
	match id:
		"boost": ok = GameState.buy_gem_boost()
		"cash":  ok = GameState.buy_gem_cash(int(Economy.GEM_SHOP["cash"]["cost"]), 3600.0)
		"warp":  ok = GameState.buy_gem_cash(int(Economy.GEM_SHOP["warp"]["cost"]), 28800.0)
	if ok: _pulse(btn); Audio.play("buy"); _disp_credits = GameState.credits

# ── Toasts ────────────────────────────────────────────────────────────────────

func _build_toasts() -> void:
	_toasts = VBoxContainer.new(); _toasts.anchor_left = 0.5; _toasts.anchor_right = 0.5
	_toasts.offset_top = 200; _toasts.offset_left = -280; _toasts.offset_right = 280
	_toasts.alignment = BoxContainer.ALIGNMENT_CENTER; add_child(_toasts)

# ── Per-frame update ───────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_disp_credits = lerpf(_disp_credits, GameState.credits, clampf(delta * 8.0, 0.0, 1.0))
	if abs(_disp_credits - GameState.credits) < 1.0:
		_disp_credits = GameState.credits
	_credits_lbl.text = Fmt.short(_disp_credits)
	_gems_lbl.text = str(GameState.gems); _infl_lbl.text = str(GameState.influence)
	_income_lbl.text = "+" + Fmt.short(GameState.income_per_sec()) + "/s"
	_vip_badge.visible = Billing.vip
	_country_lbl.text = "%s · %d/%d" % [Economy.country_name(GameState.current_country), GameState.current_country + 1, Economy.num_countries()]
	_map.band_top    = _hud.position.y + _hud.size.y + 8.0
	_map.band_bottom = _adbar.position.y - 8.0

	for m in _mode_btns:
		var active: bool = (GameState.buy_mode == int(m))
		_mode_btns[m].add_theme_stylebox_override("normal", UITheme.seg(active))
		_mode_btns[m].add_theme_stylebox_override("hover",  UITheme.seg(active))

	var dc := GameState.drone_planned(); var dcost := GameState.drone_cost_multi(max(1, dc))
	_drone_btn.text = (("×%d  " % dc) if GameState.buy_mode != 1 else "") + Fmt.short(dcost)
	_drone_btn.disabled = GameState.credits < dcost
	_drone_detail.text = "Tens %d drones" % GameState.drones

	for key in _rows:
		var count := GameState.planned_count(key); var cost := GameState.upgrade_cost_multi(key, max(1, count))
		var row: Dictionary = _rows[key]
		row["btn"].text = (("×%d  " % count) if GameState.buy_mode != 1 else "") + Fmt.short(cost)
		row["btn"].disabled = GameState.credits < cost
		row["detail"].text = "Nv %d · %s" % [int(GameState.levels[key]), _effect(key)]

	for key in _talent_rows:
		var tp: Dictionary = Economy.TALENTS[key]; var lvl := int(GameState.talents[key])
		var tr: Dictionary = _talent_rows[key]
		if lvl >= int(tp["max"]):
			tr["btn"].text = "MÁX"; tr["btn"].disabled = true
		else:
			tr["btn"].text = str(GameState.talent_cost(key)); tr["btn"].disabled = not GameState.can_buy_talent(key)
		tr["detail"].text = "Nv %d/%d · %s" % [lvl, int(tp["max"]), tp["desc"]]

	var gb: Dictionary = _gem_rows.get("boost", {})
	if not gb.is_empty():
		var boost_cost := GameState.gem_boost_cost()
		gb["btn"].text = "💎 " + str(boost_cost); gb["btn"].disabled = GameState.gems < boost_cost
	for id in ["cash", "warp"]:
		var gr: Dictionary = _gem_rows.get(id, {})
		if not gr.is_empty():
			var c: int = int(Economy.GEM_SHOP[id]["cost"])
			gr["btn"].text = "💎 " + str(c); gr["btn"].disabled = GameState.gems < c

	_progress_lbl.text = "%s — %d/%d cidades abertas." % [Economy.country_name(GameState.current_country), GameState.cities_unlocked, GameState.max_cities()]
	var cc := GameState.next_city_cost()
	if cc < 0.0:
		_city_btn.disabled = true; _city_btn.text = "TODAS"
		_city_detail.text = "Todas as cidades estão abertas."
	else:
		_city_btn.text = Fmt.short(cc); _city_btn.disabled = GameState.credits < cc
		var ci := GameState.current_country; var cities := Economy.country_cities(ci)
		var nx: int = clampi(GameState.cities_unlocked + 1, 1, cities.size() - 1)
		_city_detail.text = "Próxima: " + cities[nx]["name"]
	var ec := GameState.expand_cost()
	if ec < 0.0:
		_expand_btn.disabled = true; _expand_btn.text = "FIM"
		_expand_detail.text = "Chegaste ao último país. Parabéns!"
	elif not GameState.all_cities_unlocked():
		_expand_btn.disabled = true; _expand_btn.text = "🔒"
		_expand_detail.text = "Abre todas as cidades de " + Economy.country_name(GameState.current_country) + " primeiro."
	else:
		_expand_btn.text = Fmt.short(ec); _expand_btn.disabled = GameState.credits < ec
		_expand_detail.text = "Seguinte: " + Economy.country_name(GameState.current_country + 1) + " (+Influência)"

func _effect(key: String) -> String:
	match key:
		"speed": return "+3%/nv velocidade"
		"cargo": return "+0.3/nv carga"
		"value": return "+4%/nv valor"
	return ""

# ── Juice ──────────────────────────────────────────────────────────────────────

func _pulse(node: Control) -> void:
	node.pivot_offset = node.size * 0.5
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector2(1.07, 1.07), 0.06)
	tw.tween_property(node, "scale", Vector2.ONE, 0.12)

func _toast(text: String, accent: Color) -> void:
	var l := Label.new(); l.text = text; l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var pc := PanelContainer.new(); pc.add_theme_stylebox_override("panel", UITheme.solid(accent, 20)); pc.add_child(l)
	_toasts.add_child(pc); pc.modulate = Color(1,1,1,0)
	var tw := create_tween()
	tw.tween_property(pc, "modulate", Color(1,1,1,1), 0.2)
	tw.tween_interval(2.0); tw.tween_property(pc, "modulate", Color(1,1,1,0), 0.4)
	tw.tween_callback(pc.queue_free)

# ── Popups ─────────────────────────────────────────────────────────────────────

func _show_settings() -> void:
	var layer := _overlay(); var box := _popup_box(layer)

	box.add_child(_lbl("⚙  Definições", 34, UITheme.INK))

	# Sound
	var mute := CheckButton.new(); mute.text = "Som activado"
	mute.add_theme_font_size_override("font_size", 26)
	mute.button_pressed = not Audio.muted
	mute.toggled.connect(func(on): Audio.muted = not on; SaveSystem.save_game())
	box.add_child(mute)

	# Stats
	var stats_txt := "Ganhos totais: %s  ·  Drones: %d  ·  Países: %d" % [
		Fmt.short(GameState.total_earned), GameState.drones, GameState.current_country + 1]
	var stats := _lbl(stats_txt, 17, UITheme.MUTED)
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(stats)

	# Restore purchases
	var restore := Button.new(); restore.text = "Restaurar compras"
	restore.add_theme_font_size_override("font_size", 22); restore.custom_minimum_size = Vector2(0, 62)
	restore.add_theme_stylebox_override("normal", UITheme.solid(UITheme.ACCENT, 18))
	restore.add_theme_stylebox_override("focus",  StyleBoxEmpty.new())
	restore.pressed.connect(func():
		_toast("Verificar compras no servidor...", UITheme.ACCENT)
		SaveSystem.save_game()
	)
	box.add_child(restore)

	# Version
	var ver := _lbl("Drone Tycoon · v1.4.3 · © 2026 LPCF", 16, UITheme.MUTED)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(ver)

	# Reset (red, destructive)
	var reset := Button.new(); reset.text = "⚠  Repor progresso"
	reset.add_theme_font_size_override("font_size", 22); reset.custom_minimum_size = Vector2(0, 62)
	reset.add_theme_stylebox_override("normal", UITheme.solid(Color(0.65, 0.22, 0.26), 18))
	reset.add_theme_stylebox_override("focus",  StyleBoxEmpty.new())
	reset.pressed.connect(func(): SaveSystem.wipe(); get_tree().reload_current_scene())
	box.add_child(reset)

	# Close
	var close := Button.new(); close.text = "Fechar"
	close.add_theme_font_size_override("font_size", 26); close.custom_minimum_size = Vector2(0, 68)
	close.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	close.pressed.connect(func(): layer.queue_free()); box.add_child(close)

func _show_offline_popup(amount: float, seconds: float) -> void:
	var layer := _overlay(); var box := _popup_box(layer)
	box.add_child(_lbl("✈  Bem-vindo de volta!", 34, UITheme.INK))
	var m := _lbl("Os drones entregaram durante %s\ne ganharam  %s  Créditos." % [Fmt.duration(seconds), Fmt.short(amount)], 21, UITheme.MUTED)
	m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(m)
	var collect := Button.new(); collect.text = "Recolher"; collect.add_theme_font_size_override("font_size", 26)
	collect.custom_minimum_size = Vector2(0, 72); collect.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	collect.pressed.connect(func(): GameState.collect_offline(1.0); _disp_credits = GameState.credits; layer.queue_free()); box.add_child(collect)
	var dbl := Button.new(); dbl.text = "📺  Recolher em DOBRO (anúncio)"; dbl.add_theme_font_size_override("font_size", 20)
	dbl.custom_minimum_size = Vector2(0, 68)
	dbl.add_theme_stylebox_override("normal", UITheme.solid(UITheme.GREEN, 18))
	dbl.add_theme_stylebox_override("focus",  StyleBoxEmpty.new())
	dbl.pressed.connect(func(): layer.queue_free(); Ads.show_rewarded("offline2x", func(): GameState.collect_offline(2.0); _disp_credits = GameState.credits)); box.add_child(dbl)

func _overlay() -> CanvasLayer:
	var layer := CanvasLayer.new(); layer.layer = 150
	var dim := ColorRect.new(); dim.color = Color(0,0,0,0.70)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim); add_child(layer); return layer

func _popup_box(layer: CanvasLayer) -> VBoxContainer:
	var wrap := Control.new(); wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); layer.add_child(wrap)
	var center := CenterContainer.new(); center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); wrap.add_child(center)
	var sc := ScrollContainer.new(); sc.custom_minimum_size = Vector2(580, 0)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; center.add_child(sc)
	var pc := PanelContainer.new(); pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL; sc.add_child(pc)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 14); pc.add_child(box)
	return box

# ── Primitives ─────────────────────────────────────────────────────────────────

func _lbl(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new(); l.text = text
	l.add_theme_font_size_override("font_size", font_size); l.add_theme_color_override("font_color", color); return l

func _icon(n: String, sz := 30) -> TextureRect:
	var r := TextureRect.new(); r.texture = _tex(n); r.custom_minimum_size = Vector2(sz, sz)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; return r

func _tex(n: String) -> Texture2D: return load(ART + n + ".png")
