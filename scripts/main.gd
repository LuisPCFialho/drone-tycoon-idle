extends Control
## Main scene for Drone Tycoon: Sky Fleet (portrait, full-screen).

const TABS_H := 520.0
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
var _fleet_lbl: Label

var _rows := {}          # upgrade key -> {btn, detail}
var _mode_btns := {}
var _drone_btn: Button
var _drone_detail: Label
var _hub_btn: Button
var _hub_detail: Label
var _net_lbl: Label
var _prestige_btn: Button
var _prestige_info: Label
var _confirm: ConfirmationDialog

const UPG_ICON := {"speed": "ic_speed", "cargo": "ic_cargo", "value": "ic_value"}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.build()
	# sky-blue backdrop behind everything
	var bg := ColorRect.new(); bg.color = Color(0.85, 0.91, 0.97)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(bg)
	_build_map()
	_build_hud()
	_build_tabs()
	_build_boost_bar()
	_build_toasts()
	_build_confirm()
	GameState.hub_unlocked.connect(func(i): _toast("Nova cidade ligada: " + Economy.hub_name(i)))
	GameState.prestiged.connect(func(g): _toast("Rede expandida! +%d Influência" % g))
	var loaded := SaveSystem.load_game()
	if loaded and GameState.pending_offline > 1.0:
		_show_offline_popup(GameState.pending_offline, GameState.pending_offline_seconds)

func _tex(n: String) -> Texture2D:
	return load(ART + n + ".png")

func _icon(n: String, sz := 28) -> TextureRect:
	var r := TextureRect.new()
	r.texture = _tex(n)
	r.custom_minimum_size = Vector2(sz, sz)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return r

func _build_map() -> void:
	_map = MapView.new()
	_map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_map)

func _chip(icon: String, color: Color) -> Dictionary:
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 6); pc.add_child(h)
	h.add_child(_icon(icon, 26))
	var lbl := _lbl("0", 26, color); lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(lbl)
	return {"root": pc, "label": lbl}

func _build_hud() -> void:
	_hud = PanelContainer.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_hud.offset_left = 8; _hud.offset_right = -8; _hud.offset_top = 8
	add_child(_hud)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 6); _hud.add_child(v)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8); v.add_child(row)
	var c1 := _chip("ic_credits", Color(0.85, 0.6, 0.05)); _credits_lbl = c1["label"]; row.add_child(c1["root"])
	var c2 := _chip("ic_gems", Color(0.05, 0.6, 0.7)); _gems_lbl = c2["label"]; row.add_child(c2["root"])
	var c3 := _chip("ic_prestige", Color(0.5, 0.35, 0.85)); _infl_lbl = c3["label"]; row.add_child(c3["root"])
	var gear := Button.new(); gear.custom_minimum_size = Vector2(54, 54)
	gear.add_child(_icon("ic_gear", 28)); gear.pressed.connect(_show_settings); row.add_child(gear)
	var row2 := HBoxContainer.new(); row2.add_theme_constant_override("separation", 10); v.add_child(row2)
	var fl := HBoxContainer.new(); fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; fl.add_theme_constant_override("separation", 6)
	fl.add_child(_icon("ic_drone", 22)); _fleet_lbl = _lbl("1 drones", 22, UITheme.MUTED); fl.add_child(_fleet_lbl); row2.add_child(fl)
	_income_lbl = _lbl("+0/s", 24, Color(0.13, 0.6, 0.33))
	_income_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; _income_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(_income_lbl)

func _build_boost_bar() -> void:
	_boost_bar = HBoxContainer.new()
	_boost_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_boost_bar.offset_top = -(TABS_H + BOOST_H); _boost_bar.offset_bottom = -TABS_H
	_boost_bar.offset_left = 8; _boost_bar.offset_right = -8
	_boost_bar.add_theme_constant_override("separation", 8)
	add_child(_boost_bar)
	_boost_bar.add_child(_green_btn("ic_boost", "2x Lucros 60s", func(): Ads.show_rewarded("x2", GameState.boost_earn_2x)))
	_boost_bar.add_child(_green_btn("ic_gems", "+50 Gemas", func(): Ads.show_rewarded("gems", func(): GameState.grant_gems(50))))

func _green_btn(icon: String, text: String, cb: Callable) -> Button:
	var b := Button.new(); b.text = "  " + text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_stylebox_override("normal", _green_sb()); b.add_theme_stylebox_override("hover", _green_sb())
	b.add_child(_icon(icon, 26)); b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(cb)
	return b

func _green_sb() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new(); sb.bg_color = UITheme.GREEN; sb.set_corner_radius_all(14)
	sb.set_content_margin_all(8); sb.shadow_color = Color(0.1, 0.3, 0.15, 0.2); sb.shadow_size = 4; sb.shadow_offset = Vector2(0, 3)
	return sb

func _build_tabs() -> void:
	_tabs = TabContainer.new()
	_tabs.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_tabs.offset_top = -TABS_H; _tabs.offset_left = 6; _tabs.offset_right = -6
	add_child(_tabs)
	_tabs.add_child(_build_fleet_tab())
	_tabs.add_child(_build_network_tab())
	_tabs.add_child(_build_shop_tab())
	_tabs.add_child(_build_prestige_tab())

func _scroll(title: String) -> Array:
	var sc := ScrollContainer.new(); sc.name = title
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := VBoxContainer.new(); v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8); sc.add_child(v)
	return [sc, v]

func _build_fleet_tab() -> ScrollContainer:
	var r := _scroll("Frota"); var v: VBoxContainer = r[1]
	var modes := HBoxContainer.new(); modes.add_theme_constant_override("separation", 6); v.add_child(modes)
	for m in [[1, "x1"], [10, "x10"], [100, "x100"], [-1, "Máx"]]:
		var b := Button.new(); b.text = m[1]; b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(func(): GameState.buy_mode = m[0])
		modes.add_child(b); _mode_btns[m[0]] = b
	# drone purchase card
	var card := _card(); var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 8); card.add_child(h)
	h.add_child(_icon("ic_drone", 38))
	var left := VBoxContainer.new(); left.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(left)
	left.add_child(_lbl("Comprar Drone", 24, UITheme.INK))
	_drone_detail = _lbl("", 20, UITheme.MUTED); left.add_child(_drone_detail)
	_drone_btn = Button.new(); _drone_btn.custom_minimum_size = Vector2(170, 70); _drone_btn.add_theme_font_size_override("font_size", 22)
	_drone_btn.pressed.connect(func(): if GameState.buy_drone(): Audio.play("buy"))
	h.add_child(_drone_btn); v.add_child(card)
	for key in ["speed", "cargo", "value"]:
		v.add_child(_make_upgrade_row(key))
	return r[0]

func _build_network_tab() -> ScrollContainer:
	var r := _scroll("Rede"); var v: VBoxContainer = r[1]
	_net_lbl = _lbl("", 22, UITheme.INK); v.add_child(_net_lbl)
	var card := _card(); var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 8); card.add_child(h)
	h.add_child(_icon("ic_range", 38))
	var left := VBoxContainer.new(); left.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(left)
	left.add_child(_lbl("Ligar Nova Cidade", 24, UITheme.INK))
	_hub_detail = _lbl("", 20, UITheme.MUTED); _hub_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; left.add_child(_hub_detail)
	_hub_btn = Button.new(); _hub_btn.custom_minimum_size = Vector2(170, 70); _hub_btn.add_theme_font_size_override("font_size", 22)
	_hub_btn.pressed.connect(func(): if GameState.unlock_hub(): Audio.play("buy"))
	h.add_child(_hub_btn); v.add_child(card)
	var info := _lbl("Cada cidade ligada aumenta os lucros da rede (+18%)\ne abre uma nova rota para os teus drones.", 20, UITheme.MUTED)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.add_child(info)
	return r[0]

func _build_shop_tab() -> ScrollContainer:
	var r := _scroll("Loja"); var v: VBoxContainer = r[1]
	var note := _lbl("Compras de demonstração (sem pagamento real).\nProntas para Google Play Billing.", 19, UITheme.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.add_child(note)
	for id in Billing.PRODUCTS.keys():
		v.add_child(_make_shop_row(id))
	return r[0]

func _build_prestige_tab() -> ScrollContainer:
	var r := _scroll("Prestígio"); var v: VBoxContainer = r[1]
	var e := _lbl("Expandir a Rede reinicia a operação (créditos, drones,\nupgrades e cidades), mas dá Influência permanente:\n+10% de lucros por cada ponto.", 22, UITheme.INK)
	e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.add_child(e)
	_prestige_info = _lbl("", 24, Color(0.5, 0.35, 0.85)); v.add_child(_prestige_info)
	_prestige_btn = Button.new(); _prestige_btn.text = "Expandir a Rede"; _prestige_btn.add_theme_font_size_override("font_size", 26)
	_prestige_btn.pressed.connect(func(): _confirm.popup_centered())
	v.add_child(_prestige_btn)
	return r[0]

func _build_confirm() -> void:
	_confirm = ConfirmationDialog.new()
	_confirm.title = "Expandir a Rede"
	_confirm.dialog_text = "Tens a certeza? A operação será reiniciada."
	_confirm.confirmed.connect(func(): GameState.do_prestige())
	add_child(_confirm)

func _build_toasts() -> void:
	_toasts = VBoxContainer.new()
	_toasts.anchor_left = 0.5; _toasts.anchor_right = 0.5; _toasts.anchor_top = 0.0
	_toasts.offset_top = 150; _toasts.offset_left = -270; _toasts.offset_right = 270
	_toasts.alignment = BoxContainer.ALIGNMENT_CENTER; add_child(_toasts)

# --------------------------------------------------------------- rows
func _card() -> PanelContainer:
	return PanelContainer.new()

func _make_upgrade_row(key: String) -> PanelContainer:
	var panel := _card(); var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 8); panel.add_child(h)
	h.add_child(_icon(UPG_ICON.get(key, "ic_speed"), 36))
	var left := VBoxContainer.new(); left.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(left)
	left.add_child(_lbl(Economy.UPGRADES[key]["name"], 23, UITheme.INK))
	var detail := _lbl("", 20, UITheme.MUTED); left.add_child(detail)
	var btn := Button.new(); btn.custom_minimum_size = Vector2(170, 70); btn.add_theme_font_size_override("font_size", 22)
	btn.pressed.connect(func(): if GameState.buy_upgrade_multi(key) > 0: Audio.play("buy"))
	h.add_child(btn); _rows[key] = {"btn": btn, "detail": detail}
	return panel

func _make_shop_row(id: String) -> PanelContainer:
	var p: Dictionary = Billing.PRODUCTS[id]
	var panel := _card(); var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 8); panel.add_child(h)
	h.add_child(_icon("ic_gems", 34))
	var left := VBoxContainer.new(); left.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(left)
	left.add_child(_lbl(p["name"], 23, UITheme.INK))
	var d := _lbl(p["desc"], 18, UITheme.MUTED); d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; left.add_child(d)
	var btn := Button.new(); btn.text = p["price"]; btn.custom_minimum_size = Vector2(150, 64); btn.add_theme_font_size_override("font_size", 22)
	btn.pressed.connect(func(): Billing.buy(id); Audio.play("buy"))
	h.add_child(btn); return panel

# --------------------------------------------------------------- per frame
func _process(_delta: float) -> void:
	_credits_lbl.text = Fmt.short(GameState.credits)
	_gems_lbl.text = str(GameState.gems)
	_infl_lbl.text = str(GameState.influence)
	_income_lbl.text = "+" + Fmt.short(GameState.income_per_sec()) + "/s"
	_fleet_lbl.text = "%d drones · %d cidades" % [GameState.drones, GameState.hubs_unlocked - 1]
	_map.band_top = _hud.position.y + _hud.size.y + 6.0
	_map.band_bottom = _boost_bar.position.y - 6.0

	for m in _mode_btns:
		_mode_btns[m].modulate = Color(0.7, 1, 0.7) if GameState.buy_mode == m else Color.WHITE

	var dcost := Economy.drone_cost(GameState.drones)
	_drone_btn.text = Fmt.short(dcost)
	_drone_btn.disabled = GameState.credits < dcost
	_drone_detail.text = "Tens %d · +1 drone na frota" % GameState.drones

	for key in _rows:
		var count := GameState.planned_count(key)
		var cost := GameState.upgrade_cost_multi(key, max(1, count))
		var row: Dictionary = _rows[key]
		var pfx := ("x%d  " % count) if GameState.buy_mode != 1 else ""
		row["btn"].text = pfx + Fmt.short(cost)
		row["btn"].disabled = GameState.credits < cost
		row["detail"].text = "Nv %d · %s" % [int(GameState.levels[key]), _effect(key)]

	_net_lbl.text = "Cidades ligadas: %d/%d   ·   Lucro da rede: x%.2f" % [GameState.hubs_unlocked - 1, Economy.num_hubs() - 1, GameState.network_mult()]
	var hc := GameState.next_hub_cost()
	if hc < 0.0:
		_hub_btn.disabled = true; _hub_btn.text = "Máx"
		_hub_detail.text = "Todas as cidades ligadas!"
	else:
		_hub_btn.text = Fmt.short(hc); _hub_btn.disabled = GameState.credits < hc
		_hub_detail.text = "Próxima: %s" % Economy.hub_name(GameState.hubs_unlocked)

	var gain := GameState.prestige_gain()
	_prestige_info.text = "Expandir agora dá %d Influência.  Lucros globais x%.2f" % [gain, GameState.global_mult()]
	_prestige_btn.disabled = gain < 1

func _effect(key: String) -> String:
	match key:
		"speed": return "Drones +7% velocidade"
		"cargo": return "Carga +1 encomenda"
		"value": return "Encomenda +10% valor"
	return ""

# --------------------------------------------------------------- popups
func _toast(text: String) -> void:
	var l := _lbl(text, 28, Color.WHITE); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new(); sb.bg_color = UITheme.ACCENT; sb.set_corner_radius_all(14); sb.set_content_margin_all(12)
	pc.add_theme_stylebox_override("panel", sb); pc.add_child(l); _toasts.add_child(pc)
	pc.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(pc, "modulate", Color(1, 1, 1, 1), 0.2); tw.tween_interval(1.8)
	tw.tween_property(pc, "modulate", Color(1, 1, 1, 0), 0.5); tw.tween_callback(pc.queue_free)

func _show_settings() -> void:
	var layer := _overlay(); var box := _popup_box(layer)
	box.add_child(_lbl("Definições", 34, UITheme.INK))
	var mute := CheckButton.new(); mute.text = "Silenciar som"; mute.button_pressed = Audio.muted
	mute.toggled.connect(func(on): Audio.muted = on; SaveSystem.save_game()); box.add_child(mute)
	var reset := Button.new(); reset.text = "Repor progresso"; reset.add_theme_font_size_override("font_size", 24)
	reset.pressed.connect(func(): SaveSystem.wipe(); get_tree().reload_current_scene()); box.add_child(reset)
	var close := Button.new(); close.text = "Fechar"; close.add_theme_font_size_override("font_size", 24)
	close.pressed.connect(func(): layer.queue_free()); box.add_child(close)

func _show_offline_popup(amount: float, seconds: float) -> void:
	var layer := _overlay(); var box := _popup_box(layer)
	box.add_child(_lbl("Bem-vindo de volta!", 34, UITheme.INK))
	var m := _lbl("Os teus drones entregaram durante %s\ne ganharam %s Créditos." % [Fmt.duration(seconds), Fmt.short(amount)], 23, UITheme.MUTED)
	m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(m)
	var collect := Button.new(); collect.text = "Recolher"; collect.add_theme_font_size_override("font_size", 26)
	collect.pressed.connect(func(): GameState.collect_offline(1.0); layer.queue_free()); box.add_child(collect)
	var dbl := Button.new(); dbl.text = "Recolher a DOBRAR (anúncio)"; dbl.add_theme_font_size_override("font_size", 22)
	dbl.add_theme_stylebox_override("normal", _green_sb())
	dbl.pressed.connect(func(): layer.queue_free(); Ads.show_rewarded("offline2x", func(): GameState.collect_offline(2.0))); box.add_child(dbl)

func _overlay() -> CanvasLayer:
	var layer := CanvasLayer.new(); layer.layer = 150
	var dim := ColorRect.new(); dim.color = Color(0, 0, 0, 0.55); dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim); add_child(layer); return layer

func _popup_box(layer: CanvasLayer) -> VBoxContainer:
	var pc := PanelContainer.new(); pc.set_anchors_and_offsets_preset(Control.PRESET_CENTER); pc.custom_minimum_size = Vector2(560, 0)
	layer.add_child(pc)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 16); box.alignment = BoxContainer.ALIGNMENT_CENTER
	pc.add_child(box); return box

func _lbl(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new(); l.text = text
	l.add_theme_font_size_override("font_size", font_size); l.add_theme_color_override("font_color", color)
	return l
