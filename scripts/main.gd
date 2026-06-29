extends Control
## Main scene — Drone Tycoon: Sky Fleet  v1.5.0

const NAV_H  := 110.0
const TABS_H := 540.0
const AD_H   := 50.0
const ART    := "res://assets/art/"

var _map: MapView
var _hud: PanelContainer
var _adbar: HBoxContainer
var _pages: Array
var _nav_btns: Array
var _toasts: VBoxContainer
var _achieve_popup: Control   # achievement slide-in

# HUD labels
var _credits_lbl: Label
var _gems_lbl: Label
var _infl_lbl: Label
var _pgems_lbl: Label
var _income_lbl: Label
var _country_lbl: Label
var _vip_badge: PanelContainer
var _event_row: HBoxContainer
var _event_icon_lbl: Label
var _event_name_lbl: Label
var _event_timer_bar: Control
var _disp_credits := 0.0

# Tab widgets
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
var _prestige_btn: Button      # big prestige button in fleet tab
var _prestige_info_lbl: Label
var _achieve_cells := {}       # id -> PanelContainer for glow update

func _ready() -> void:
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.build()
	_bg(); _build_map(); _build_hud(); _build_adbar()
	_build_bottom_bg(); _build_pages(); _build_nav(); _build_toasts()

	# Connect signals
	GameState.city_unlocked.connect(func(_i): _toast("🏙 Cidade desbloqueada!", UITheme.CYAN))
	GameState.country_changed.connect(func(i): _toast("🌍 " + Economy.country_name(i) + "!", UITheme.GOLD))
	Achievements.unlocked.connect(_on_achievement)
	Events.started.connect(_on_event_start)
	Events.ended.connect(func(_id): _event_row.visible = false)
	Daily.reward_ready.connect(func(): _show_daily_popup())
	Prestige.prestiged.connect(_on_prestige)

	var loaded := SaveSystem.load_game()
	_disp_credits = GameState.credits
	if loaded and GameState.pending_offline > 1.0:
		_show_offline_popup(GameState.pending_offline, GameState.pending_offline_seconds)
	elif Daily.pending:
		_show_daily_popup()
	_switch_tab(0)

# ── Background ──────────────────────────────────────────────────────────────────

func _bg() -> void:
	var grad := Gradient.new(); grad.set_color(0, UITheme.BG0); grad.set_color(1, UITheme.BG1)
	var gt := GradientTexture2D.new(); gt.gradient = grad; gt.fill_from = Vector2(0,0); gt.fill_to = Vector2(0,1); gt.width = 16; gt.height = 128
	var bg := TextureRect.new(); bg.texture = gt; bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE; bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(bg)

func _build_map() -> void:
	_map = MapView.new(); _map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(_map)

# ── HUD ─────────────────────────────────────────────────────────────────────────

func _build_hud() -> void:
	_hud = PanelContainer.new()
	_hud.anchor_left = 0; _hud.anchor_right = 1; _hud.anchor_top = 0; _hud.anchor_bottom = 0
	_hud.offset_left = 12; _hud.offset_right = -12; _hud.offset_top = 22
	_hud.add_theme_stylebox_override("panel", UITheme.glass())
	add_child(_hud)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 6); _hud.add_child(v)

	# Row 1: stat chips
	var r1 := HBoxContainer.new(); r1.add_theme_constant_override("separation", 6); v.add_child(r1)
	var c1 := _stat_chip("ic_credits", UITheme.GOLD,    24); _credits_lbl = c1["label"]; r1.add_child(c1["root"])
	var c2 := _stat_chip("ic_gems",    UITheme.CYAN,    24); _gems_lbl   = c2["label"]; r1.add_child(c2["root"])
	var c3 := _stat_chip("ic_prestige",UITheme.VIOLET,  22); _infl_lbl   = c3["label"]; r1.add_child(c3["root"])
	var c4 := _stat_chip("ic_prestige",UITheme.PRESTIGE,22); _pgems_lbl  = c4["label"]; r1.add_child(c4["root"])
	_vip_badge = PanelContainer.new(); _vip_badge.add_theme_stylebox_override("panel", UITheme.solid(UITheme.GOLD, 16))
	var vl := Label.new(); vl.text = "VIP"; vl.add_theme_font_size_override("font_size", 16)
	vl.add_theme_color_override("font_color", Color(0.12, 0.08, 0.0))
	vl.add_theme_font_override("font", UITheme.font("Bold")); _vip_badge.add_child(vl)
	_vip_badge.visible = false; r1.add_child(_vip_badge)
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; r1.add_child(sp)
	var gear := Button.new(); gear.text = "⚙"; gear.add_theme_font_size_override("font_size", 26)
	gear.custom_minimum_size = Vector2(52, 52)
	gear.add_theme_stylebox_override("normal", UITheme.nav_item(false))
	gear.add_theme_stylebox_override("hover",  UITheme.nav_item(true))
	gear.add_theme_stylebox_override("focus",  StyleBoxEmpty.new())
	gear.add_theme_color_override("font_color", UITheme.MUTED)
	gear.pressed.connect(_show_settings); r1.add_child(gear)

	# Row 2: country + income
	var r2 := HBoxContainer.new(); r2.add_theme_constant_override("separation", 6); v.add_child(r2)
	_country_lbl = Label.new(); _country_lbl.add_theme_font_size_override("font_size", 18)
	_country_lbl.add_theme_color_override("font_color", UITheme.MUTED)
	_country_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; r2.add_child(_country_lbl)
	_income_lbl = Label.new(); _income_lbl.add_theme_font_size_override("font_size", 20)
	_income_lbl.add_theme_color_override("font_color", UITheme.GREEN)
	_income_lbl.add_theme_font_override("font", UITheme.font("Bold"))
	_income_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; r2.add_child(_income_lbl)

	# Row 3: Event banner (hidden when no event)
	_event_row = HBoxContainer.new(); _event_row.add_theme_constant_override("separation", 8)
	_event_row.visible = false; v.add_child(_event_row)
	_event_icon_lbl = Label.new(); _event_icon_lbl.add_theme_font_size_override("font_size", 22); _event_row.add_child(_event_icon_lbl)
	var ev_info := VBoxContainer.new(); ev_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _event_row.add_child(ev_info)
	_event_name_lbl = Label.new(); _event_name_lbl.add_theme_font_size_override("font_size", 18)
	_event_name_lbl.add_theme_font_override("font", UITheme.font("Bold")); ev_info.add_child(_event_name_lbl)
	# Timer bar
	var bar_bg := Panel.new(); bar_bg.custom_minimum_size = Vector2(0, 6)
	bar_bg.add_theme_stylebox_override("panel", UITheme.prog_bg()); ev_info.add_child(bar_bg)
	_event_timer_bar = Panel.new()
	_event_timer_bar.anchor_left = 0; _event_timer_bar.anchor_right = 1
	_event_timer_bar.anchor_top = 0; _event_timer_bar.anchor_bottom = 1
	bar_bg.add_child(_event_timer_bar)

func _stat_chip(icon: String, color: Color, lbl_size: int) -> Dictionary:
	var pc := PanelContainer.new()
	var s := StyleBoxFlat.new(); s.bg_color = Color(color.r, color.g, color.b, 0.18)
	s.set_corner_radius_all(16); s.content_margin_left = 8; s.content_margin_right = 8
	s.content_margin_top = 5; s.content_margin_bottom = 5
	pc.add_theme_stylebox_override("panel", s)
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 4); pc.add_child(h)
	h.add_child(_icon(icon, 22))
	var lbl := Label.new(); lbl.add_theme_font_size_override("font_size", lbl_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_override("font", UITheme.font("Bold")); h.add_child(lbl)
	return {"root": pc, "label": lbl}

# ── Ad bar ──────────────────────────────────────────────────────────────────────

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
		func(): Ads.show_rewarded("cash", func():
			GameState.grant_cash_minutes(30); _disp_credits = GameState.credits
			_toast("+30min de lucros!", UITheme.GREEN))))
	_adbar.add_child(_ad_pill("💎", "+60 Gemas",
		func(): Ads.show_rewarded("gems", func():
			GameState.grant_gems(60); _toast("+60 💎 Gemas!", UITheme.CYAN))))

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

# ── Bottom bg ───────────────────────────────────────────────────────────────────

func _build_bottom_bg() -> void:
	var bg := Panel.new()
	bg.anchor_left = 0; bg.anchor_right = 1
	bg.anchor_top = 1; bg.anchor_bottom = 1
	bg.offset_top = -(NAV_H + TABS_H + AD_H); bg.offset_bottom = 0
	bg.add_theme_stylebox_override("panel", UITheme.bottom_panel())
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(bg)

# ── Pages ────────────────────────────────────────────────────────────────────────

func _build_pages() -> void:
	_pages = [_build_fleet_tab(), _build_cities_tab(), _build_talents_tab(),
			  _build_legado_tab(), _build_shop_tab()]
	for pg in _pages:
		add_child(pg)

# ── Nav bar ─────────────────────────────────────────────────────────────────────

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

	var defs := [["🚁","Frota"],["🌍","Cidades"],["⭐","Talentos"],["🏆","Legado"],["💎","Loja"]]
	for i in defs.size():
		nav.add_child(_make_nav_btn(defs[i][0], defs[i][1], i))

func _make_nav_btn(emoji: String, label_text: String, idx: int) -> Button:
	var btn := Button.new()
	btn.text = emoji + "\n" + label_text
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, NAV_H)
	btn.add_theme_font_size_override("font_size", 14)
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

# ── Scroll wrapper ──────────────────────────────────────────────────────────────

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

# ── Fleet tab ───────────────────────────────────────────────────────────────────

func _build_fleet_tab() -> ScrollContainer:
	var r := _scroll("Frota"); var v: VBoxContainer = r[1]

	# Buy mode selector
	var seg_row := HBoxContainer.new(); seg_row.add_theme_constant_override("separation", 5); v.add_child(seg_row)
	for m: Array in [[1,"×1"],[10,"×10"],[100,"×100"],[-1,"Máx"]]:
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
	_drone_btn.pressed.connect(func():
		if GameState.buy_drones() > 0: _pulse(_drone_btn); Audio.play("buy"))
	dv.add_child(_drone_btn); v.add_child(dp)

	for key: String in ["speed", "cargo", "value"]:
		v.add_child(_make_upgrade_row(key))

	# Prestige section
	var psep := _lbl("— Prestige —", 17, UITheme.PRESTIGE)
	psep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(psep)

	var pp := PanelContainer.new(); pp.add_theme_stylebox_override("panel", UITheme.prestige_card()); v.add_child(pp)
	var pv := VBoxContainer.new(); pv.add_theme_constant_override("separation", 8); pp.add_child(pv)
	_prestige_info_lbl = _lbl("", 17, UITheme.MUTED)
	_prestige_info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; pv.add_child(_prestige_info_lbl)
	_prestige_btn = Button.new(); _prestige_btn.add_theme_font_size_override("font_size", 22)
	_prestige_btn.add_theme_font_override("font", UITheme.font("Bold"))
	_prestige_btn.custom_minimum_size = Vector2(0, 68)
	_prestige_btn.add_theme_stylebox_override("normal",   UITheme.prestige_btn_ready())
	_prestige_btn.add_theme_stylebox_override("hover",    UITheme.prestige_btn_ready())
	_prestige_btn.add_theme_stylebox_override("pressed",  UITheme.prestige_card())
	_prestige_btn.add_theme_stylebox_override("disabled", UITheme.action_btn_disabled())
	_prestige_btn.add_theme_stylebox_override("focus",    StyleBoxEmpty.new())
	_prestige_btn.pressed.connect(_show_prestige_confirm)
	pv.add_child(_prestige_btn)

	return r[0]

# ── Cities tab ──────────────────────────────────────────────────────────────────

func _build_cities_tab() -> ScrollContainer:
	var r := _scroll("Cidades"); var v: VBoxContainer = r[1]
	_progress_lbl = _lbl("", 17, UITheme.MUTED)
	_progress_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.add_child(_progress_lbl)

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
	var ev2 := VBoxContainer.new(); ev2.add_theme_constant_override("separation", 8); ep.add_child(ev2)
	var eh := HBoxContainer.new(); eh.add_theme_constant_override("separation", 10); ev2.add_child(eh)
	eh.add_child(_icon("ic_boost", 34))
	var el := VBoxContainer.new(); el.size_flags_horizontal = Control.SIZE_EXPAND_FILL; eh.add_child(el)
	el.add_child(_lbl("Expandir para o próximo país", 20, UITheme.INK))
	_expand_detail = _lbl("", 15, UITheme.MUTED); _expand_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; el.add_child(_expand_detail)
	_expand_btn = _wide_btn(UITheme.GOLD.darkened(0.08))
	_expand_btn.pressed.connect(func():
		if GameState.expand_country(): _pulse(_expand_btn); Audio.play("buy"))
	ev2.add_child(_expand_btn); v.add_child(ep)
	return r[0]

# ── Talents tab ─────────────────────────────────────────────────────────────────

func _build_talents_tab() -> ScrollContainer:
	var r := _scroll("Talentos"); var v: VBoxContainer = r[1]
	var info := _lbl("Influência ganha-se ao expandir países.\nGasta-a em bónus PERMANENTES.", 17, UITheme.MUTED)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.add_child(info)
	for key: String in Economy.TALENT_ORDER:
		v.add_child(_make_talent_row(key))
	return r[0]

# ── Legado tab (Achievements + Prestige Shop) ──────────────────────────────────

func _build_legado_tab() -> ScrollContainer:
	var r := _scroll("Legado"); var v: VBoxContainer = r[1]

	# Prestige stats card
	var ps_card := PanelContainer.new(); ps_card.add_theme_stylebox_override("panel", UITheme.prestige_card()); v.add_child(ps_card)
	var ps_v := VBoxContainer.new(); ps_v.add_theme_constant_override("separation", 6); ps_card.add_child(ps_v)
	ps_v.add_child(_lbl("⬡ Sistema de Prestige", 22, UITheme.PRESTIGE))
	var ps_info := _lbl("Reinicia com multiplicador permanente.\nRequer 5.º país desbloqueado.", 16, UITheme.MUTED)
	ps_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; ps_v.add_child(ps_info)

	# Prestige shop
	var sh_lbl := _lbl("Loja de Prestige (⬡ Gemas Prestige)", 20, UITheme.PRESTIGE); v.add_child(sh_lbl)
	for id: String in Prestige.SHOP_ORDER:
		v.add_child(_make_prestige_shop_row(id))

	# Achievements header
	var ach_lbl := _lbl("🏆 Conquistas", 24, UITheme.GOLD); v.add_child(ach_lbl)
	for id: String in Achievements.DEFS:
		v.add_child(_make_achievement_row(id))
	return r[0]

func _make_prestige_shop_row(id: String) -> PanelContainer:
	var item: Dictionary = Prestige.SHOP[id]
	var pp := PanelContainer.new(); pp.add_theme_stylebox_override("panel", UITheme.prestige_card())
	var ph := HBoxContainer.new(); ph.add_theme_constant_override("separation", 10); pp.add_child(ph)
	var pv := VBoxContainer.new(); pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL; ph.add_child(pv)
	pv.add_child(_lbl(item["name"], 19, UITheme.INK))
	var pd := _lbl(item["desc"], 14, UITheme.MUTED); pd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; pv.add_child(pd)
	var pb := Button.new(); pb.text = "⬡ " + str(int(item["cost"]))
	pb.custom_minimum_size = Vector2(100, 52); pb.add_theme_font_size_override("font_size", 18)
	pb.add_theme_stylebox_override("normal",   UITheme.prestige_btn_ready())
	pb.add_theme_stylebox_override("disabled", UITheme.action_btn_disabled())
	pb.add_theme_stylebox_override("focus",    StyleBoxEmpty.new())
	pb.pressed.connect(func():
		if Prestige.buy_shop(id): _pulse(pb); Audio.play("buy"); pb.text = "✓ Obtido"; pb.disabled = true
		else: Audio.play("error"))
	if Prestige.has_shop(id): pb.text = "✓ Obtido"; pb.disabled = true
	ph.add_child(pb)
	return pp

func _make_achievement_row(id: String) -> PanelContainer:
	var def: Dictionary = Achievements.DEFS[id]
	var done: bool = Achievements.is_done(id)
	var secret: bool = bool(def.get("secret", false)) and not done
	var pp := PanelContainer.new(); pp.add_theme_stylebox_override("panel", UITheme.achievement_card(done))
	var ph := HBoxContainer.new(); ph.add_theme_constant_override("separation", 10); pp.add_child(ph)
	var icon_lbl := Label.new(); icon_lbl.text = "❓" if secret else str(def["icon"])
	icon_lbl.add_theme_font_size_override("font_size", 30); ph.add_child(icon_lbl)
	var pv := VBoxContainer.new(); pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL; ph.add_child(pv)
	var name_lbl := _lbl("???" if secret else str(def["name"]), 18, UITheme.GOLD if done else UITheme.INK)
	name_lbl.add_theme_font_override("font", UITheme.font("Bold")); pv.add_child(name_lbl)
	var desc_lbl := _lbl("Conquista secreta." if secret else str(def["desc"]), 14, UITheme.MUTED)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; pv.add_child(desc_lbl)
	if int(def.get("gems", 0)) > 0:
		var reward_lbl := _lbl("+%d 💎" % int(def["gems"]), 14, UITheme.CYAN); ph.add_child(reward_lbl)
	if done:
		var check := _lbl("✓", 28, UITheme.GREEN); ph.add_child(check)
	_achieve_cells[id] = pp
	return pp

# ── Shop tab ────────────────────────────────────────────────────────────────────

func _build_shop_tab() -> ScrollContainer:
	var r := _scroll("Loja"); var v: VBoxContainer = r[1]
	var gi := _card(UITheme.CYAN)
	var gv := VBoxContainer.new(); gv.add_theme_constant_override("separation", 4); gi.add_child(gv)
	gv.add_child(_lbl("💎 Gemas — ganha com anúncios (acima)", 18, UITheme.CYAN))
	v.add_child(gi)
	for id: String in Economy.GEM_SHOP_ORDER:
		v.add_child(_make_gem_row(id))

	# Daily reward preview
	var daily_card := _card(UITheme.GOLD); v.add_child(daily_card)
	var daily_v := VBoxContainer.new(); daily_v.add_theme_constant_override("separation", 4); daily_card.add_child(daily_v)
	daily_v.add_child(_lbl("📅 Recompensa Diária", 20, UITheme.GOLD))
	var daily_info := _lbl("Faz login todos os dias para ganhar gemas e bónus!", 16, UITheme.MUTED)
	daily_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; daily_v.add_child(daily_info)
	var daily_btn := _wide_btn(UITheme.GOLD.darkened(0.06))
	daily_btn.add_theme_color_override("font_color", Color(0.12, 0.08, 0.0))
	daily_btn.pressed.connect(func():
		if Daily.pending: _show_daily_popup()
		else: _toast("Já recebeste a recompensa de hoje!", UITheme.GOLD))
	daily_v.add_child(daily_btn)

	var sep_lbl := _lbl("— Compras com dinheiro real —", 17, UITheme.MUTED)
	sep_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(sep_lbl)
	for id: String in Billing.PRODUCT_ORDER:
		v.add_child(_make_iap_row(id))
	return r[0]

# ── Card widgets ────────────────────────────────────────────────────────────────

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
	btn.pressed.connect(func(): _buy_gem(id, btn))
	v.add_child(btn); _gem_rows[id] = {"btn": btn}; return panel

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
	btn.pressed.connect(func(): Billing.buy(id); _pulse(btn); Audio.play("buy"))
	v.add_child(btn); return panel

func _buy_gem(id: String, btn: Button) -> void:
	var ok := false
	match id:
		"boost": ok = GameState.buy_gem_boost()
		"cash":  ok = GameState.buy_gem_cash(int(Economy.GEM_SHOP["cash"]["cost"]), 3600.0)
		"warp":  ok = GameState.buy_gem_cash(int(Economy.GEM_SHOP["warp"]["cost"]), 28800.0)
	if ok: _pulse(btn); Audio.play("buy"); _disp_credits = GameState.credits
	else:  Audio.play("error")

# ── Toasts ───────────────────────────────────────────────────────────────────────

func _build_toasts() -> void:
	_toasts = VBoxContainer.new(); _toasts.anchor_left = 0.5; _toasts.anchor_right = 0.5
	_toasts.offset_top = 180; _toasts.offset_left = -290; _toasts.offset_right = 290
	_toasts.alignment = BoxContainer.ALIGNMENT_CENTER; add_child(_toasts)

func _toast(text: String, accent: Color) -> void:
	var l := Label.new(); l.text = text; l.add_theme_font_size_override("font_size", 21)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var pc := PanelContainer.new()
	var s := UITheme.solid(accent, 20); s.border_width_left = 4; s.border_color = accent.lightened(0.3)
	pc.add_theme_stylebox_override("panel", s); pc.add_child(l)
	_toasts.add_child(pc); pc.modulate = Color(1,1,1,0)
	var tw := create_tween()
	tw.tween_property(pc, "modulate", Color(1,1,1,1), 0.18)
	tw.tween_interval(2.2); tw.tween_property(pc, "modulate", Color(1,1,1,0), 0.35)
	tw.tween_callback(pc.queue_free)

# ── Per-frame update ─────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_disp_credits = lerpf(_disp_credits, GameState.credits, clampf(delta * 8.0, 0.0, 1.0))
	if abs(_disp_credits - GameState.credits) < 1.0: _disp_credits = GameState.credits
	_credits_lbl.text = Fmt.short(_disp_credits)
	_gems_lbl.text    = str(GameState.gems)
	_infl_lbl.text    = str(GameState.influence)
	_pgems_lbl.text   = str(Prestige.pgems)
	_vip_badge.visible = Billing.vip

	var ips := GameState.income_per_sec()
	_income_lbl.text  = "+" + Fmt.short(ips) + "/s"
	if Events.is_active():
		_income_lbl.add_theme_color_override("font_color", Events.color())
	else:
		_income_lbl.add_theme_color_override("font_color", UITheme.GREEN)

	_country_lbl.text = "%s · %d/%d  [streak %dd]" % [
		Economy.country_name(GameState.current_country),
		GameState.current_country + 1, Economy.num_countries(), Daily.streak]

	_map.band_top    = _hud.position.y + _hud.size.y + 8.0
	_map.band_bottom = _adbar.position.y - 8.0

	# Event timer bar
	if Events.is_active():
		var pct := Events.time_pct()
		_event_timer_bar.anchor_right = pct
		var s := UITheme.prog_fill(Events.color()); s.set_corner_radius_all(6)
		_event_timer_bar.add_theme_stylebox_override("panel", s)

	# Buy mode buttons
	for m in _mode_btns:
		var active: bool = (GameState.buy_mode == int(m))
		_mode_btns[m].add_theme_stylebox_override("normal", UITheme.seg(active))
		_mode_btns[m].add_theme_stylebox_override("hover",  UITheme.seg(active))

	# Drone button
	var dc := GameState.drone_planned(); var dcost := GameState.drone_cost_multi(maxi(1, dc))
	_drone_btn.text     = (("×%d  " % dc) if GameState.buy_mode != 1 else "") + Fmt.short(dcost)
	_drone_btn.disabled = GameState.credits < dcost
	_drone_detail.text  = "Tens %d drones" % GameState.drones

	# Upgrade rows
	for key: String in _rows:
		var count := GameState.planned_count(key); var cost := GameState.upgrade_cost_multi(key, maxi(1, count))
		var row: Dictionary = _rows[key]
		row["btn"].text    = (("×%d  " % count) if GameState.buy_mode != 1 else "") + Fmt.short(cost)
		row["btn"].disabled = GameState.credits < cost
		row["detail"].text  = "Nv %d · %s" % [int(GameState.levels[key]), _effect(key)]

	# Talent rows
	for key: String in _talent_rows:
		var tp: Dictionary = Economy.TALENTS[key]; var lvl := int(GameState.talents[key])
		var tr: Dictionary = _talent_rows[key]
		if lvl >= int(tp["max"]):
			tr["btn"].text = "MÁX"; tr["btn"].disabled = true
		else:
			tr["btn"].text = str(GameState.talent_cost(key)); tr["btn"].disabled = not GameState.can_buy_talent(key)
		tr["detail"].text = "Nv %d/%d · %s" % [lvl, int(tp["max"]), tp["desc"]]

	# Gem rows
	var gb: Dictionary = _gem_rows.get("boost", {})
	if not gb.is_empty():
		var bc := GameState.gem_boost_cost()
		gb["btn"].text = "💎 " + str(bc); gb["btn"].disabled = GameState.gems < bc
	for id: String in ["cash", "warp"]:
		var gr: Dictionary = _gem_rows.get(id, {})
		if not gr.is_empty():
			var c: int = int(Economy.GEM_SHOP[id]["cost"])
			gr["btn"].text = "💎 " + str(c); gr["btn"].disabled = GameState.gems < c

	# City / country
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

	# Prestige button
	if Prestige.can_prestige():
		_prestige_btn.text = "⬡ PRESTIGE  (+" + str(Prestige.pgems_on_next_prestige()) + " ⬡)"
		_prestige_btn.disabled = false
		_prestige_info_lbl.text = "Tier: %s · Prestige #%d · Multiplicador ×%.2f\nReinicias mantendo gemas e conquistas." % [Prestige.tier_name(), Prestige.count + 1, Prestige.permanent_mult * 1.15]
	else:
		_prestige_btn.text = "⬡ Prestige (requer 5.º país)"
		_prestige_btn.disabled = true
		_prestige_info_lbl.text = "Chega ao 5.º país para fazer prestige.\nTier actual: %s · Prestige %d · Mult ×%.2f" % [Prestige.tier_name(), Prestige.count, Prestige.permanent_mult]

	# Achievements income check (throttled to every 60 frames ~ 1s)
	if Engine.get_frames_drawn() % 60 == 0:
		Achievements.check("income_1k",  ips >= 1000.0)
		Achievements.check("income_1m",  ips >= 1_000_000.0)
		Achievements.check("credits_1m", GameState.credits >= 1_000_000.0)
		Achievements.check("credits_1b", GameState.credits >= 1_000_000_000.0)
		Achievements.check("credits_1t", GameState.credits >= 1_000_000_000_000.0)
		Achievements.check("gems_100",   GameState.gems >= 100)

func _effect(key: String) -> String:
	match key:
		"speed": return "+3%/nv velocidade"
		"cargo": return "+0.3/nv carga"
		"value": return "+4%/nv valor"
	return ""

# ── Signal handlers ──────────────────────────────────────────────────────────────

func _on_achievement(id: String) -> void:
	var def: Dictionary = Achievements.DEFS.get(id, {})
	var name_str: String = str(def.get("name", id))
	var icon_str: String = str(def.get("icon", "🏆"))
	_toast(icon_str + " " + name_str + " desbloqueada!", UITheme.GOLD)
	# Refresh achievement cell styling
	if _achieve_cells.has(id):
		_achieve_cells[id].add_theme_stylebox_override("panel", UITheme.achievement_card(true))

func _on_event_start(id: String) -> void:
	var def: Dictionary = Events.DEFS.get(id, {})
	_event_icon_lbl.text = str(def.get("icon", "⚡"))
	_event_name_lbl.text = str(def.get("name", "")) + " " + str(def.get("desc", ""))
	_event_name_lbl.add_theme_color_override("font_color", Events.color())
	_event_row.visible = true
	_toast(str(def.get("icon", "⚡")) + " " + str(def.get("name", "Evento")), Events.color())

func _on_prestige(_count: int) -> void:
	_toast("⬡ PRESTIGE! Bem-vindo ao recomeço!", UITheme.PRESTIGE)
	_disp_credits = 0.0

# ── Juice ────────────────────────────────────────────────────────────────────────

func _pulse(node: Control) -> void:
	node.pivot_offset = node.size * 0.5
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector2(1.08, 1.08), 0.06)
	tw.tween_property(node, "scale", Vector2.ONE, 0.14)

# ── Popups ───────────────────────────────────────────────────────────────────────

func _show_daily_popup() -> void:
	var layer := _overlay(); var box := _popup_box(layer)
	box.add_child(_lbl("📅 Recompensa Diária", 32, UITheme.GOLD))
	var streak_info := _lbl("Streak: %d dias consecutivos!" % Daily.streak, 20, UITheme.INK)
	streak_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(streak_info)

	# 7-day grid
	var grid := GridContainer.new(); grid.columns = 7; grid.add_theme_constant_override("h_separation", 6); grid.add_theme_constant_override("v_separation", 6); box.add_child(grid)
	for i in Daily.REWARDS.size():
		var day_box := PanelContainer.new()
		var claimed := (i < (Daily.streak - 1) % Daily.REWARDS.size())
		var current := (i == (Daily.streak - 1) % Daily.REWARDS.size()) and Daily.pending
		day_box.add_theme_stylebox_override("panel", UITheme.daily_card(claimed, current))
		var dv := VBoxContainer.new(); dv.add_theme_constant_override("separation", 2); day_box.add_child(dv)
		var dl := _lbl("D%d" % (i+1), 12, UITheme.MUTED if not current else UITheme.GOLD)
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; dv.add_child(dl)
		var rl := _lbl(str(Daily.REWARDS[i]["label"]), 11, UITheme.INK if not claimed else UITheme.GREEN)
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; dv.add_child(rl)
		if claimed: dv.add_child(_lbl("✓", 18, UITheme.GREEN))
		grid.add_child(day_box)

	if Daily.pending:
		var claim_btn := _wide_btn(UITheme.GOLD.darkened(0.06))
		claim_btn.text = "Receber Recompensa!"
		claim_btn.add_theme_color_override("font_color", Color(0.12, 0.08, 0.0))
		claim_btn.pressed.connect(func(): Daily.claim(); _disp_credits = GameState.credits; layer.queue_free())
		box.add_child(claim_btn)
	var close := Button.new(); close.text = "Fechar"; close.add_theme_font_size_override("font_size", 24)
	close.custom_minimum_size = Vector2(0, 62); close.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	close.pressed.connect(func(): layer.queue_free()); box.add_child(close)

func _show_prestige_confirm() -> void:
	var layer := _overlay(); var box := _popup_box(layer)
	box.add_child(_lbl("⬡ Confirmar Prestige", 30, UITheme.PRESTIGE))
	var gain := Prestige.pgems_on_next_prestige()
	var info := _lbl("Vais ganhar  %d ⬡  Gemas Prestige\ne um multiplicador ×%.2f permanente.\n\nPerdes créditos, drones e upgrades.\nMantens gemas normais e conquistas." % [gain, Prestige.permanent_mult * 1.15], 18, UITheme.MUTED)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(info)
	var confirm := Button.new(); confirm.text = "⬡ SIM, FAZER PRESTIGE"
	confirm.add_theme_font_size_override("font_size", 22); confirm.custom_minimum_size = Vector2(0, 68)
	confirm.add_theme_stylebox_override("normal", UITheme.prestige_btn_ready())
	confirm.add_theme_stylebox_override("focus",  StyleBoxEmpty.new())
	confirm.pressed.connect(func(): layer.queue_free(); Prestige.do_prestige())
	box.add_child(confirm)
	var cancel := Button.new(); cancel.text = "Cancelar"; cancel.add_theme_font_size_override("font_size", 22)
	cancel.custom_minimum_size = Vector2(0, 62); cancel.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	cancel.pressed.connect(func(): layer.queue_free()); box.add_child(cancel)

func _show_settings() -> void:
	var layer := _overlay(); var box := _popup_box(layer)
	box.add_child(_lbl("⚙  Definições", 32, UITheme.INK))

	# Sound toggle
	var mute := CheckButton.new(); mute.text = "Som activado"
	mute.add_theme_font_size_override("font_size", 24)
	mute.button_pressed = not Audio.muted
	mute.toggled.connect(func(on): Audio.muted = not on; SaveSystem.save_game())
	box.add_child(mute)

	# Stats
	var stats_txt := "Ganhos totais: %s  ·  Drones: %d  ·  Países: %d\nPrestige: %d  ·  Conquistas: %d/%d" % [
		Fmt.short(GameState.total_earned), GameState.drones, GameState.current_country + 1,
		Prestige.count, Achievements.done_count(), Achievements.total_count()]
	var stats := _lbl(stats_txt, 16, UITheme.MUTED)
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(stats)

	# Restore purchases
	var restore := Button.new(); restore.text = "Restaurar compras"
	restore.add_theme_font_size_override("font_size", 22); restore.custom_minimum_size = Vector2(0, 60)
	restore.add_theme_stylebox_override("normal", UITheme.solid(UITheme.ACCENT, 18))
	restore.add_theme_stylebox_override("focus",  StyleBoxEmpty.new())
	restore.pressed.connect(func(): _toast("A verificar compras...", UITheme.ACCENT); SaveSystem.save_game())
	box.add_child(restore)

	# Version
	box.add_child(_lbl("Drone Tycoon: Sky Fleet · v1.5.0 · © 2026 LPCF", 15, UITheme.MUTED))

	# Reset (destructive)
	var reset := Button.new(); reset.text = "⚠  Repor progresso"
	reset.add_theme_font_size_override("font_size", 22); reset.custom_minimum_size = Vector2(0, 60)
	reset.add_theme_stylebox_override("normal", UITheme.danger_btn())
	reset.add_theme_stylebox_override("focus",  StyleBoxEmpty.new())
	reset.pressed.connect(func(): SaveSystem.wipe(); get_tree().reload_current_scene())
	box.add_child(reset)

	var close := Button.new(); close.text = "Fechar"; close.add_theme_font_size_override("font_size", 24)
	close.custom_minimum_size = Vector2(0, 66); close.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	close.pressed.connect(func(): layer.queue_free()); box.add_child(close)

func _show_offline_popup(amount: float, seconds: float) -> void:
	var layer := _overlay(); var box := _popup_box(layer)
	box.add_child(_lbl("✈  Bem-vindo de volta!", 32, UITheme.INK))
	var m := _lbl("Os drones entregaram durante %s\ne ganharam  %s  Créditos." % [Fmt.duration(seconds), Fmt.short(amount)], 20, UITheme.MUTED)
	m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(m)
	var collect := Button.new(); collect.text = "Recolher"
	collect.add_theme_font_size_override("font_size", 24); collect.custom_minimum_size = Vector2(0, 70)
	collect.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	collect.pressed.connect(func():
		GameState.collect_offline(1.0)
		_disp_credits = GameState.credits
		layer.queue_free()
		if Daily.pending:
			_show_daily_popup()
	)
	box.add_child(collect)
	var dbl := Button.new(); dbl.text = "📺  Recolher em DOBRO (anúncio)"
	dbl.add_theme_font_size_override("font_size", 19); dbl.custom_minimum_size = Vector2(0, 66)
	dbl.add_theme_stylebox_override("normal", UITheme.solid(UITheme.GREEN, 18))
	dbl.add_theme_stylebox_override("focus",  StyleBoxEmpty.new())
	dbl.pressed.connect(func():
		layer.queue_free()
		Ads.show_rewarded("offline2x", func():
			GameState.collect_offline(2.0)
			_disp_credits = GameState.credits
			if Daily.pending:
				_show_daily_popup()
		)
	)
	box.add_child(dbl)

func _overlay() -> CanvasLayer:
	var layer := CanvasLayer.new(); layer.layer = 150
	var dim := ColorRect.new(); dim.color = Color(0,0,0,0.72)
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

# ── Primitives ───────────────────────────────────────────────────────────────────

func _lbl(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new(); l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color); return l

func _icon(n: String, sz := 30) -> TextureRect:
	var r := TextureRect.new(); r.texture = _tex(n); r.custom_minimum_size = Vector2(sz, sz)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; return r

func _tex(n: String) -> Texture2D: return load(ART + n + ".png")
