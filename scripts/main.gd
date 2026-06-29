extends Control
## Main scene — Drone Tycoon: Sky Fleet. World-map progression, premium dark UI.

const TABS_H := 556.0
const BOOST_H := 70.0
const ART := "res://assets/art/"

var _map: MapView
var _hud: PanelContainer
var _boost_bar: HBoxContainer
var _tabs: TabContainer
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

const UPG_ICON := {"speed": "ic_speed", "cargo": "ic_cargo", "value": "ic_value"}

func _ready() -> void:
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.build()
	_bg(); _build_map(); _build_hud(); _build_tabs(); _build_boost_bar(); _build_toasts()
	GameState.city_unlocked.connect(func(i): _toast("Cidade desbloqueada!", UITheme.CYAN))
	GameState.country_changed.connect(func(i): _toast("Bem-vindo a " + Economy.country_name(i) + "!", UITheme.GOLD))
	var loaded := SaveSystem.load_game()
	_disp_credits = GameState.credits
	if loaded and GameState.pending_offline > 1.0:
		_show_offline_popup(GameState.pending_offline, GameState.pending_offline_seconds)

func _bg() -> void:
	var grad := Gradient.new(); grad.set_color(0, UITheme.BG0); grad.set_color(1, UITheme.BG1)
	var gt := GradientTexture2D.new(); gt.gradient = grad; gt.fill_from = Vector2(0, 0); gt.fill_to = Vector2(0, 1); gt.width = 16; gt.height = 128
	var bg := TextureRect.new(); bg.texture = gt; bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE; bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(bg)

func _tex(n: String) -> Texture2D: return load(ART + n + ".png")

func _icon(n: String, sz := 30) -> TextureRect:
	var r := TextureRect.new(); r.texture = _tex(n); r.custom_minimum_size = Vector2(sz, sz)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return r

func _build_map() -> void:
	_map = MapView.new(); _map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(_map)

func _pill(icon: String, color: Color) -> Dictionary:
	var pc := PanelContainer.new(); pc.add_theme_stylebox_override("panel", UITheme.pill()); pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 7); pc.add_child(h)
	h.add_child(_icon(icon, 28))
	var lbl := _lbl("0", 27, color); lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; lbl.add_theme_font_override("font", UITheme.font("Bold"))
	h.add_child(lbl)
	return {"root": pc, "label": lbl}

func _build_hud() -> void:
	_hud = PanelContainer.new(); _hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_hud.offset_left = 8; _hud.offset_right = -8; _hud.offset_top = 8; add_child(_hud)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 10); _hud.add_child(v)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8); v.add_child(row)
	var c1 := _pill("ic_credits", UITheme.GOLD); _credits_lbl = c1["label"]; row.add_child(c1["root"])
	var c2 := _pill("ic_gems", UITheme.CYAN); _gems_lbl = c2["label"]; row.add_child(c2["root"])
	var c3 := _pill("ic_prestige", UITheme.VIOLET); _infl_lbl = c3["label"]; row.add_child(c3["root"])
	_vip_badge = PanelContainer.new(); _vip_badge.add_theme_stylebox_override("panel", UITheme.solid(UITheme.GOLD, 18))
	var vl := _lbl("VIP", 20, Color(0.15, 0.1, 0)); vl.add_theme_font_override("font", UITheme.font("Bold")); _vip_badge.add_child(vl); _vip_badge.visible = false; row.add_child(_vip_badge)
	var gear := Button.new(); gear.custom_minimum_size = Vector2(54, 54); gear.add_theme_stylebox_override("normal", UITheme.solid(UITheme.PANEL2))
	gear.add_child(_icon("ic_gear", 28)); gear.pressed.connect(_show_settings); row.add_child(gear)
	var row2 := HBoxContainer.new(); row2.add_theme_constant_override("separation", 10); v.add_child(row2)
	var cbox := HBoxContainer.new(); cbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL; cbox.add_theme_constant_override("separation", 7)
	cbox.add_child(_icon("ic_range", 24)); _country_lbl = _lbl("", 21, UITheme.INK); cbox.add_child(_country_lbl); row2.add_child(cbox)
	_income_lbl = _lbl("≈ +0/s", 23, UITheme.GREEN); _income_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_income_lbl.add_theme_font_override("font", UITheme.font("Bold")); row2.add_child(_income_lbl)

func _build_boost_bar() -> void:
	_boost_bar = HBoxContainer.new(); _boost_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_boost_bar.offset_top = -(TABS_H + BOOST_H); _boost_bar.offset_bottom = -TABS_H
	_boost_bar.offset_left = 8; _boost_bar.offset_right = -8; _boost_bar.add_theme_constant_override("separation", 8); add_child(_boost_bar)
	_boost_bar.add_child(_green_btn("ic_boost", "2x 5min", func(): Ads.show_rewarded("x2", GameState.boost_earn_2x)))
	_boost_bar.add_child(_green_btn("ic_credits", "Crédito Grátis", func(): Ads.show_rewarded("cash", func(): GameState.grant_cash_minutes(30); _disp_credits = GameState.credits; _toast("+30 min de lucros!", UITheme.GREEN))))
	_boost_bar.add_child(_green_btn("ic_gems", "+60 Gemas", func(): Ads.show_rewarded("gems", func(): GameState.grant_gems(60); _toast("+60 Gemas!", UITheme.CYAN))))

func _green_btn(icon: String, text: String, cb: Callable) -> Button:
	var b := Button.new(); b.text = " " + text; b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; b.add_theme_font_size_override("font_size", 21)
	b.add_theme_stylebox_override("normal", UITheme.solid(UITheme.GREEN)); b.add_theme_stylebox_override("hover", UITheme.solid(UITheme.GREEN.lightened(0.08)))
	b.add_theme_stylebox_override("pressed", UITheme.solid(UITheme.GREEN_D)); b.icon = _tex(icon); b.add_theme_constant_override("icon_max_width", 26)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT; b.pressed.connect(cb); return b

func _build_tabs() -> void:
	_tabs = TabContainer.new(); _tabs.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_tabs.offset_top = -TABS_H; _tabs.offset_left = 6; _tabs.offset_right = -6; _tabs.clip_tabs = false; add_child(_tabs)
	_tabs.add_child(_build_fleet_tab()); _tabs.add_child(_build_cities_tab()); _tabs.add_child(_build_talents_tab()); _tabs.add_child(_build_shop_tab())

func _scroll(title: String) -> Array:
	var sc := ScrollContainer.new(); sc.name = title
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new(); v.size_flags_horizontal = Control.SIZE_EXPAND_FILL; v.add_theme_constant_override("separation", 10); sc.add_child(v)
	return [sc, v]

func _build_fleet_tab() -> ScrollContainer:
	var r := _scroll("Frota"); var v: VBoxContainer = r[1]
	var modes := HBoxContainer.new(); modes.add_theme_constant_override("separation", 8); v.add_child(modes)
	for m in [[1, "x1"], [10, "x10"], [100, "x100"], [-1, "Máx"]]:
		var b := Button.new(); b.text = m[1]; b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; b.custom_minimum_size = Vector2(0, 58); b.add_theme_font_size_override("font_size", 22)
		b.add_theme_stylebox_override("normal", UITheme.solid(UITheme.PANEL2)); b.pressed.connect(func(): GameState.buy_mode = m[0]); modes.add_child(b); _mode_btns[m[0]] = b
	var card := _card(UITheme.ACCENT); var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 12); card.add_child(h)
	h.add_child(_icon("ic_drone", 44))
	var left := VBoxContainer.new(); left.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(left)
	left.add_child(_lbl("Comprar Drone", 26, UITheme.INK)); _drone_detail = _lbl("", 20, UITheme.MUTED); left.add_child(_drone_detail)
	_drone_btn = _buy_btn(); _drone_btn.pressed.connect(func(): if GameState.buy_drones() > 0: _pulse(_drone_btn); Audio.play("buy"))
	h.add_child(_drone_btn); v.add_child(card)
	for key in ["speed", "cargo", "value"]:
		v.add_child(_make_upgrade_row(key))
	return r[0]

func _build_cities_tab() -> ScrollContainer:
	var r := _scroll("Cidades"); var v: VBoxContainer = r[1]
	_progress_lbl = _lbl("", 22, UITheme.INK); _progress_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.add_child(_progress_lbl)
	var card := _card(UITheme.CYAN); var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 12); card.add_child(h)
	h.add_child(_icon("ic_range", 42))
	var left := VBoxContainer.new(); left.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(left)
	left.add_child(_lbl("Abrir Cidade", 25, UITheme.INK)); _city_detail = _lbl("", 19, UITheme.MUTED); _city_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; left.add_child(_city_detail)
	_city_btn = _buy_btn(); _city_btn.pressed.connect(func(): if GameState.unlock_city(): _pulse(_city_btn); Audio.play("buy"))
	h.add_child(_city_btn); v.add_child(card)
	var ecard := _card(UITheme.GOLD); var eh := HBoxContainer.new(); eh.add_theme_constant_override("separation", 12); ecard.add_child(eh)
	eh.add_child(_icon("ic_boost", 42))
	var eleft := VBoxContainer.new(); eleft.size_flags_horizontal = Control.SIZE_EXPAND_FILL; eh.add_child(eleft)
	eleft.add_child(_lbl("Expandir para o próximo país", 24, UITheme.INK)); _expand_detail = _lbl("", 19, UITheme.MUTED); _expand_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; eleft.add_child(_expand_detail)
	_expand_btn = _buy_btn(); _expand_btn.add_theme_stylebox_override("normal", UITheme.solid(UITheme.GOLD.darkened(0.05)))
	_expand_btn.pressed.connect(func(): if GameState.expand_country(): _pulse(_expand_btn); Audio.play("buy"))
	eh.add_child(_expand_btn); v.add_child(ecard)
	return r[0]

func _build_talents_tab() -> ScrollContainer:
	var r := _scroll("Talentos"); var v: VBoxContainer = r[1]
	v.add_child(_lbl("Ganhas Influência ao expandir para novos países.\nGasta-a em bónus PERMANENTES.", 20, UITheme.MUTED))
	for key in Economy.TALENT_ORDER:
		v.add_child(_make_talent_row(key))
	return r[0]

func _build_shop_tab() -> ScrollContainer:
	var r := _scroll("Loja"); var v: VBoxContainer = r[1]
	# Gems explanation banner
	var gem_info := _card(UITheme.CYAN)
	var gi := VBoxContainer.new(); gi.add_theme_constant_override("separation", 6); gem_info.add_child(gi)
	gi.add_child(_lbl("O que são Gemas? 💎", 22, UITheme.CYAN))
	var gdesc := _lbl("Ganha Gemas vendo anúncios (botão +60 Gemas acima)\nou compra pacotes. Serve para comprar bónus poderosos:", 18, UITheme.INK)
	gdesc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; gi.add_child(gdesc)
	v.add_child(gem_info)
	for id in Economy.GEM_SHOP_ORDER:
		v.add_child(_make_gem_row(id))
	v.add_child(_lbl("Comprar com dinheiro real", 22, UITheme.GOLD))
	for id in Billing.PRODUCT_ORDER:
		v.add_child(_make_iap_row(id))
	v.add_child(_lbl("Compras de demonstração (sem pagamento real).", 16, UITheme.MUTED))
	return r[0]

func _build_toasts() -> void:
	_toasts = VBoxContainer.new(); _toasts.anchor_left = 0.5; _toasts.anchor_right = 0.5
	_toasts.offset_top = 150; _toasts.offset_left = -280; _toasts.offset_right = 280; _toasts.alignment = BoxContainer.ALIGNMENT_CENTER; add_child(_toasts)

# ---------------------------------------------------------------- widgets
func _card(accent: Color) -> PanelContainer:
	var p := PanelContainer.new(); p.add_theme_stylebox_override("panel", UITheme.card(accent)); return p

func _buy_btn() -> Button:
	var b := Button.new(); b.custom_minimum_size = Vector2(186, 86); b.add_theme_font_size_override("font_size", 23)
	b.add_theme_stylebox_override("normal", UITheme.solid(UITheme.GREEN)); b.add_theme_stylebox_override("hover", UITheme.solid(UITheme.GREEN.lightened(0.08)))
	b.add_theme_stylebox_override("pressed", UITheme.solid(UITheme.GREEN_D)); b.add_theme_stylebox_override("disabled", UITheme.solid(Color(0.2, 0.24, 0.34)))
	return b

func _cost_btn(color: Color) -> Button:
	var b := Button.new(); b.custom_minimum_size = Vector2(160, 78); b.add_theme_font_size_override("font_size", 22)
	b.add_theme_stylebox_override("normal", UITheme.solid(color)); b.add_theme_stylebox_override("disabled", UITheme.solid(Color(0.2, 0.24, 0.34)))
	return b

func _make_upgrade_row(key: String) -> PanelContainer:
	var panel := _card(UITheme.ACCENT); var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 12); panel.add_child(h)
	h.add_child(_icon(UPG_ICON.get(key, "ic_speed"), 40))
	var left := VBoxContainer.new(); left.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(left)
	left.add_child(_lbl(Economy.UPGRADES[key]["name"], 24, UITheme.INK)); var detail := _lbl("", 19, UITheme.MUTED); left.add_child(detail)
	var btn := _buy_btn(); btn.pressed.connect(func(): if GameState.buy_upgrade_multi(key) > 0: _pulse(btn); Audio.play("buy"))
	h.add_child(btn); _rows[key] = {"btn": btn, "detail": detail}; return panel

func _make_talent_row(key: String) -> PanelContainer:
	var p: Dictionary = Economy.TALENTS[key]
	var panel := _card(UITheme.VIOLET); var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 12); panel.add_child(h)
	h.add_child(_icon(p.get("icon", "ic_prestige"), 38))
	var left := VBoxContainer.new(); left.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(left)
	left.add_child(_lbl(p["name"], 24, UITheme.INK)); var detail := _lbl("", 18, UITheme.MUTED); left.add_child(detail)
	var btn := _cost_btn(UITheme.VIOLET); btn.icon = _tex("ic_prestige"); btn.add_theme_constant_override("icon_max_width", 24)
	btn.pressed.connect(func(): if GameState.buy_talent(key): _pulse(btn); Audio.play("buy"))
	h.add_child(btn); _talent_rows[key] = {"btn": btn, "detail": detail}; return panel

func _make_gem_row(id: String) -> PanelContainer:
	var p: Dictionary = Economy.GEM_SHOP[id]
	var panel := _card(UITheme.CYAN); var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 12); panel.add_child(h)
	h.add_child(_icon(p.get("icon", "ic_gems"), 38))
	var left := VBoxContainer.new(); left.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(left)
	left.add_child(_lbl(p["name"], 23, UITheme.INK)); var detail := _lbl(p["desc"], 17, UITheme.MUTED); detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; left.add_child(detail)
	var btn := _cost_btn(UITheme.CYAN.darkened(0.12)); btn.icon = _tex("ic_gems"); btn.add_theme_constant_override("icon_max_width", 24)
	btn.pressed.connect(func(): _buy_gem(id, btn)); h.add_child(btn); _gem_rows[id] = {"btn": btn}; return panel

func _buy_gem(id: String, btn: Button) -> void:
	var ok := false
	match id:
		"boost": ok = GameState.buy_gem_boost()
		"cash": ok = GameState.buy_gem_cash(int(Economy.GEM_SHOP["cash"]["cost"]), 3600.0)
		"warp": ok = GameState.buy_gem_cash(int(Economy.GEM_SHOP["warp"]["cost"]), 28800.0)
	if ok: _pulse(btn); Audio.play("buy"); _disp_credits = GameState.credits

func _make_iap_row(id: String) -> PanelContainer:
	var p: Dictionary = Billing.PRODUCTS[id]
	var panel := _card(UITheme.GOLD); var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 12); panel.add_child(h)
	h.add_child(_icon("ic_gems" if id.begins_with("gems") else "ic_boost", 36))
	var left := VBoxContainer.new(); left.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(left)
	left.add_child(_lbl(p["name"], 23, UITheme.INK)); var d := _lbl(p["desc"], 17, UITheme.MUTED); d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; left.add_child(d)
	var btn := _cost_btn(UITheme.GOLD.darkened(0.05)); btn.text = p["price"]; btn.add_theme_color_override("font_color", Color(0.15, 0.1, 0))
	btn.pressed.connect(func(): Billing.buy(id); _pulse(btn); Audio.play("buy")); h.add_child(btn); return panel

# ---------------------------------------------------------------- per frame
func _process(delta: float) -> void:
	_disp_credits = lerp(_disp_credits, GameState.credits, clamp(delta * 8.0, 0.0, 1.0))
	if abs(_disp_credits - GameState.credits) < 1.0: _disp_credits = GameState.credits
	_credits_lbl.text = Fmt.short(_disp_credits)
	_gems_lbl.text = str(GameState.gems); _infl_lbl.text = str(GameState.influence)
	_income_lbl.text = "≈ +" + Fmt.short(GameState.income_per_sec()) + "/s"
	_vip_badge.visible = Billing.vip
	_country_lbl.text = "%s · País %d/%d · Cidades %d/%d" % [Economy.country_name(GameState.current_country), GameState.current_country + 1, Economy.num_countries(), GameState.cities_unlocked, GameState.max_cities()]

	_map.band_top = _hud.position.y + _hud.size.y + 6.0
	_map.band_bottom = _boost_bar.position.y - 6.0

	for m in _mode_btns:
		_mode_btns[m].modulate = Color(0.6, 1, 0.7) if GameState.buy_mode == m else Color.WHITE

	var dc := GameState.drone_planned(); var dcost := GameState.drone_cost_multi(max(1, dc))
	_drone_btn.text = (("x%d  " % dc) if GameState.buy_mode != 1 else "") + Fmt.short(dcost)
	_drone_btn.disabled = GameState.credits < dcost
	_drone_detail.text = "Tens %d drones" % GameState.drones

	for key in _rows:
		var count := GameState.planned_count(key); var cost := GameState.upgrade_cost_multi(key, max(1, count)); var row: Dictionary = _rows[key]
		row["btn"].text = (("x%d  " % count) if GameState.buy_mode != 1 else "") + Fmt.short(cost)
		row["btn"].disabled = GameState.credits < cost
		row["detail"].text = "Nv %d · %s" % [int(GameState.levels[key]), _effect(key)]

	for key in _talent_rows:
		var tp: Dictionary = Economy.TALENTS[key]; var lvl := int(GameState.talents[key]); var tr: Dictionary = _talent_rows[key]
		if lvl >= int(tp["max"]):
			tr["btn"].text = "MÁX"; tr["btn"].disabled = true
		else:
			tr["btn"].text = str(GameState.talent_cost(key)); tr["btn"].disabled = not GameState.can_buy_talent(key)
		tr["detail"].text = "Nv %d/%d · %s" % [lvl, int(tp["max"]), tp["desc"]]

	var gb: Dictionary = _gem_rows.get("boost", {})
	if not gb.is_empty():
		gb["btn"].text = str(GameState.gem_boost_cost()); gb["btn"].disabled = GameState.gems < GameState.gem_boost_cost()
	for id in ["cash", "warp"]:
		var gr: Dictionary = _gem_rows.get(id, {})
		if not gr.is_empty():
			var c: int = int(Economy.GEM_SHOP[id]["cost"]); gr["btn"].text = str(c); gr["btn"].disabled = GameState.gems < c

	# cities tab
	_progress_lbl.text = "%s — cidades abertas %d de %d. Abre todas para poder expandir." % [Economy.country_name(GameState.current_country), GameState.cities_unlocked, GameState.max_cities()]
	var cc := GameState.next_city_cost()
	if cc < 0.0:
		_city_btn.disabled = true; _city_btn.text = "TODAS"; _city_detail.text = "Todas as cidades deste país estão abertas."
	else:
		_city_btn.text = Fmt.short(cc); _city_btn.disabled = GameState.credits < cc
		var ci := GameState.current_country; var cities := Economy.country_cities(ci)
		var nx: int = clampi(GameState.cities_unlocked + 1, 1, cities.size() - 1)
		_city_detail.text = "Próxima: %s" % cities[nx]["name"]
	var ec := GameState.expand_cost()
	if ec < 0.0:
		_expand_btn.disabled = true; _expand_btn.text = "FIM"; _expand_detail.text = "Chegaste ao último país. Parabéns!"
	elif not GameState.all_cities_unlocked():
		_expand_btn.disabled = true; _expand_btn.text = "🔒"; _expand_detail.text = "Abre todas as cidades de %s primeiro." % Economy.country_name(GameState.current_country)
	else:
		_expand_btn.text = Fmt.short(ec); _expand_btn.disabled = GameState.credits < ec
		_expand_detail.text = "Seguinte: %s  (+Influência)" % Economy.country_name(GameState.current_country + 1)

func _effect(key: String) -> String:
	match key:
		"speed": return "+3% velocidade"
		"cargo": return "+0.3 carga"
		"value": return "+4% valor"
	return ""

# ---------------------------------------------------------------- juice / popups
func _pulse(node: Control) -> void:
	node.pivot_offset = node.size * 0.5
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector2(1.1, 1.1), 0.06); tw.tween_property(node, "scale", Vector2.ONE, 0.12)

func _toast(text: String, accent: Color) -> void:
	var l := _lbl(text, 26, Color.WHITE); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var pc := PanelContainer.new(); pc.add_theme_stylebox_override("panel", UITheme.solid(accent, 18)); pc.add_child(l); _toasts.add_child(pc); pc.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(pc, "modulate", Color(1, 1, 1, 1), 0.2); tw.tween_interval(1.9); tw.tween_property(pc, "modulate", Color(1, 1, 1, 0), 0.5); tw.tween_callback(pc.queue_free)

func _show_settings() -> void:
	var layer := _overlay(); var box := _popup_box(layer)
	box.add_child(_lbl("Definições", 34, UITheme.INK))
	var mute := CheckButton.new(); mute.text = "Silenciar som"; mute.button_pressed = Audio.muted
	mute.toggled.connect(func(on): Audio.muted = on; SaveSystem.save_game()); box.add_child(mute)
	var reset := Button.new(); reset.text = "Repor progresso"; reset.add_theme_font_size_override("font_size", 23); reset.custom_minimum_size = Vector2(0, 70)
	reset.add_theme_stylebox_override("normal", UITheme.solid(Color(0.7, 0.25, 0.3)))
	reset.pressed.connect(func(): SaveSystem.wipe(); get_tree().reload_current_scene()); box.add_child(reset)
	var close := Button.new(); close.text = "Fechar"; close.add_theme_font_size_override("font_size", 23); close.custom_minimum_size = Vector2(0, 70)
	close.pressed.connect(func(): layer.queue_free()); box.add_child(close)

func _show_offline_popup(amount: float, seconds: float) -> void:
	var layer := _overlay(); var box := _popup_box(layer)
	box.add_child(_lbl("Bem-vindo de volta!", 34, UITheme.INK))
	var m := _lbl("Os drones entregaram durante %s\ne ganharam %s Créditos." % [Fmt.duration(seconds), Fmt.short(amount)], 22, UITheme.MUTED)
	m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(m)
	var collect := Button.new(); collect.text = "Recolher"; collect.add_theme_font_size_override("font_size", 26); collect.custom_minimum_size = Vector2(0, 78)
	collect.pressed.connect(func(): GameState.collect_offline(1.0); _disp_credits = GameState.credits; layer.queue_free()); box.add_child(collect)
	var dbl := Button.new(); dbl.text = "Recolher a DOBRAR (anúncio)"; dbl.add_theme_font_size_override("font_size", 21); dbl.custom_minimum_size = Vector2(0, 74)
	dbl.add_theme_stylebox_override("normal", UITheme.solid(UITheme.GREEN))
	dbl.pressed.connect(func(): layer.queue_free(); Ads.show_rewarded("offline2x", func(): GameState.collect_offline(2.0); _disp_credits = GameState.credits)); box.add_child(dbl)

func _overlay() -> CanvasLayer:
	var layer := CanvasLayer.new(); layer.layer = 150
	var dim := ColorRect.new(); dim.color = Color(0, 0, 0, 0.62); dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim); add_child(layer); return layer

func _popup_box(layer: CanvasLayer) -> VBoxContainer:
	var pc := PanelContainer.new(); pc.set_anchors_and_offsets_preset(Control.PRESET_CENTER); pc.custom_minimum_size = Vector2(580, 0); layer.add_child(pc)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 18); box.alignment = BoxContainer.ALIGNMENT_CENTER; pc.add_child(box); return box

func _lbl(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new(); l.text = text; l.add_theme_font_size_override("font_size", font_size); l.add_theme_color_override("font_color", color); return l
