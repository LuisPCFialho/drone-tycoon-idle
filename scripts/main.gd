extends Control
## Main scene — Drone Tycoon: Sky Fleet  v1.17.0

const NAV_H  := 132.0
const TABS_H := 532.0
const AD_H   := 52.0
const ART    := "res://assets/art/"
const GUTTER := 12.0

var _map: MapView
var _bonus: BonusDrone
var _hud: PanelContainer
var _adbar: HBoxContainer
var _pages: Array
var _nav_btns: Array
var _nav_icons: Array
var _nav_labels: Array
var _nav_dots: Array
var _nav_ind: Panel
var _toasts: VBoxContainer

# HUD
var _credits_lbl: Label
var _gems_lbl: Label
var _infl_lbl: Label
var _income_lbl: Label
var _country_lbl: Label
var _credits_chip: Control
var _gems_chip: Control
var _infl_chip: Control
var _vip_badge: PanelContainer
var _event_row: HBoxContainer
var _event_icon: TextureRect
var _event_name_lbl: Label
var _event_timer_bar: Panel
var _ribbon_fill: Panel
var _disp_credits := 0.0

# previous values for chip-pop detection
var _prev_gems := 0
var _prev_infl := 0
var _prev_combo_mult := 1.0

# Tab widgets
var _rows := {}
var _talent_rows := {}
var _gem_rows := {}
var _skin_rows := {}
var _offer_card: PanelContainer = null
var _offer_time_lbl: Label = null
var _mode_btns := {}
var _drone_btn: Button
var _drone_detail: Label
var _city_btn: Button
var _city_detail: Label
var _expand_btn: Button
var _expand_detail: Label
var _streak_lbl: Label
var _streak_chip: PanelContainer
var _combo_chip: PanelContainer
var _combo_lbl: Label
var _city_prog_fill: Panel
var _progress_lbl: Label
var _city_list_box: VBoxContainer
var _prestige_btn: Button
var _prestige_info_lbl: Label
var _pgems_lbl: Label
var _achieve_cells := {}
var _achieve_prog_fills := {}
var _achieve_prog_lbls := {}
var _settings_stats_lbl: Label = null
var _prestige_ready_prev := false
var _tap_block_until := 0   # ms; drag-scroll guard so dragging never buys

# Missions tab (contracts)
var _mission_title_lbls: Array = []
var _mission_prog_bars: Array = []
var _mission_prog_lbls: Array = []
var _mission_time_lbls: Array = []
var _mission_claim_btns: Array = []
var _mission_reward_lbls: Array = []
var _mission_x2_btns: Array = []
var _mission_reroll_btns: Array = []
var _mission_gem_lbls: Array = []
var _mission_gem_icons: Array = []

# Income milestone celebration
const INCOME_MILESTONES: Array = [1000.0, 10000.0, 100000.0, 1000000.0, 10000000.0, 100000000.0, 1000000000.0]
const MILESTONE_LABELS: Array  = ["1K", "10K", "100K", "1M", "10M", "100M", "1B"]
var _income_milestone_idx := 0

# Floating delivery-earnings throttle
var _deliver_throttle := 0
var _fountain_counter := 0

func _ready() -> void:
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.build()
	_bg(); _build_map(); _build_bonus_drone(); _build_hud()
	_build_bottom_bg(); _build_adbar(); _build_pages(); _build_nav(); _build_toasts()

	GameState.city_unlocked.connect(_on_city_unlocked)
	GameState.country_changed.connect(_on_country_changed)
	GameState.delivered.connect(_on_delivered)
	Achievements.unlocked.connect(_on_achievement)
	Events.started.connect(_on_event_start)
	Events.ended.connect(func(_id): _event_row.visible = false)
	Daily.reward_ready.connect(func(): _show_daily_popup())
	Prestige.prestiged.connect(_on_prestige)
	Contracts.completed.connect(_on_contract_completed)

	var loaded := SaveSystem.load_game()
	_disp_credits = GameState.credits
	_prev_gems = GameState.gems; _prev_infl = GameState.influence
	_rebuild_city_list()
	_switch_tab(0)
	if Fx.reduce_motion or Fx.skip_boot:
		Fx.skip_boot = false
		_post_boot(loaded)
	else:
		_boot_intro(loaded)

## Welcome popups run only after the boot ceremony so it is never covered.
func _post_boot(loaded: bool) -> void:
	if loaded and GameState.pending_offline > 1.0:
		_show_offline_popup(GameState.pending_offline, GameState.pending_offline_seconds)
	elif Daily.pending:
		_show_daily_popup()

## First-launch ceremony: branded cover, drone fly-through, then UI cascade.
func _boot_intro(loaded: bool) -> void:
	var vs := get_viewport_rect().size
	var layer := CanvasLayer.new(); layer.layer = 200
	add_child(layer)
	var cover := ColorRect.new(); cover.color = UITheme.BG0
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(cover)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	cover.add_child(box)
	var t1 := _lbl("DRONE TYCOON", 44, UITheme.INK)
	t1.add_theme_font_override("font", UITheme.font("Bold"))
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(t1)
	var t2 := _lbl("SKY FLEET", 20, UITheme.CYAN)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(t2)
	var dr := TextureRect.new(); dr.texture = _opt_tex("drone_blue")
	dr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dr.size = Vector2(96, 96)
	dr.position = Vector2(-120, vs.y * 0.40)
	dr.rotation = 0.10
	cover.add_child(dr)

	_hud.offset_top = -160.0
	_map.zoom = 1.15
	for i in range(_adbar.get_child_count()):
		var pill := _adbar.get_child(i) as Control
		pill.pivot_offset = pill.size * 0.5
		pill.scale = Vector2(0.8, 0.8)

	var tw := create_tween()
	tw.tween_property(dr, "position:x", vs.x + 140.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(cover, "modulate:a", 0.0, 0.35)
	tw.parallel().tween_property(_hud, "offset_top", 20.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_map, "zoom", 1.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for i in range(_adbar.get_child_count()):
		var pill := _adbar.get_child(i) as Control
		tw.parallel().tween_property(pill, "scale", Vector2.ONE, 0.3).set_delay(float(i) * 0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		if is_instance_valid(layer):
			layer.queue_free()
		_post_boot(loaded)
	)

# ── Background (layered depth) ────────────────────────────────────────────────

func _bg() -> void:
	var grad := Gradient.new(); grad.set_color(0, UITheme.BG0); grad.set_color(1, UITheme.BG1)
	var gt := GradientTexture2D.new(); gt.gradient = grad; gt.fill_from = Vector2(0,0); gt.fill_to = Vector2(0,1); gt.width = 16; gt.height = 128
	var bg := TextureRect.new(); bg.texture = gt; bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE; bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(bg)
	# aurora band glow near the top, behind HUD
	var aurora := _opt_tex("aurora_band")
	if aurora != null:
		var ab := TextureRect.new(); ab.texture = aurora
		ab.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; ab.stretch_mode = TextureRect.STRETCH_SCALE
		ab.anchor_left = 0; ab.anchor_right = 1; ab.anchor_top = 0; ab.anchor_bottom = 0
		ab.offset_top = 0; ab.offset_bottom = 360
		ab.modulate = Color(1, 1, 1, 0.55); ab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(ab)

func _build_map() -> void:
	_map = MapView.new(); _map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(_map)
	# vignette over the map (under the UI chrome added later)
	var vig := _opt_tex("vignette")
	if vig != null:
		var vr := TextureRect.new(); vr.texture = vig
		vr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; vr.stretch_mode = TextureRect.STRETCH_SCALE
		vr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vr.modulate = Color(1, 1, 1, 0.3); vr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(vr)

func _build_bonus_drone() -> void:
	_bonus = BonusDrone.new()
	_bonus.caught.connect(_show_bonus_popup)
	add_child(_bonus)

# ── HUD ───────────────────────────────────────────────────────────────────────

func _build_hud() -> void:
	_hud = PanelContainer.new()
	_hud.anchor_left = 0; _hud.anchor_right = 1; _hud.anchor_top = 0; _hud.anchor_bottom = 0
	_hud.offset_left = GUTTER; _hud.offset_right = -GUTTER; _hud.offset_top = 20
	_hud.add_theme_stylebox_override("panel", UITheme.glass())
	add_child(_hud)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 7); _hud.add_child(v)

	# Row 1: stat chips (credits prominent)
	var r1 := HBoxContainer.new(); r1.add_theme_constant_override("separation", 6); v.add_child(r1)
	var c1 := _chip("ic_credits", UITheme.GOLD, 25); _credits_lbl = c1["label"]; _credits_chip = c1["root"]; r1.add_child(c1["root"])
	var c2 := _chip("ic_gems", UITheme.CYAN, 22); _gems_lbl = c2["label"]; _gems_chip = c2["root"]; r1.add_child(c2["root"])
	var c3 := _chip("ic_prestige", UITheme.VIOLET, 21); _infl_lbl = c3["label"]; _infl_chip = c3["root"]; r1.add_child(c3["root"])
	_vip_badge = PanelContainer.new(); _vip_badge.add_theme_stylebox_override("panel", UITheme.solid(UITheme.GOLD, 14))
	var vb := HBoxContainer.new(); vb.add_theme_constant_override("separation", 3); _vip_badge.add_child(vb)
	vb.add_child(_icon("ic_vip", 18))
	var vl := Label.new(); vl.text = "VIP"; vl.add_theme_font_size_override("font_size", 15)
	vl.add_theme_color_override("font_color", Color(0.12, 0.08, 0.0))
	vl.add_theme_font_override("font", UITheme.font("Bold")); vb.add_child(vl)
	_vip_badge.visible = false; r1.add_child(_vip_badge)
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; r1.add_child(sp)
	var gear := Button.new(); gear.icon = _opt_tex("ic_gear")
	gear.expand_icon = true; gear.add_theme_constant_override("icon_max_width", 40)
	gear.custom_minimum_size = Vector2(64, 64)
	gear.add_theme_stylebox_override("normal", UITheme.nav_item(false))
	gear.add_theme_stylebox_override("hover",  UITheme.nav_item(true))
	gear.add_theme_stylebox_override("focus",  StyleBoxEmpty.new())
	gear.pressed.connect(func(): Fx.press(gear); _show_settings()); r1.add_child(gear)

	# Row 2: country | streak chip | income
	var r2 := HBoxContainer.new(); r2.add_theme_constant_override("separation", 6); v.add_child(r2)
	_country_lbl = Label.new(); _country_lbl.add_theme_font_size_override("font_size", 17)
	_country_lbl.add_theme_color_override("font_color", UITheme.MUTED)
	_country_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; r2.add_child(_country_lbl)
	_streak_chip = PanelContainer.new()
	_streak_chip.add_theme_stylebox_override("panel", UITheme.stat_chip(UITheme.AMBER))
	var sh := HBoxContainer.new(); sh.add_theme_constant_override("separation", 3); _streak_chip.add_child(sh)
	sh.add_child(_icon("ic_streak", 18))
	_streak_lbl = Label.new(); _streak_lbl.add_theme_font_size_override("font_size", 15)
	_streak_lbl.add_theme_color_override("font_color", UITheme.AMBER)
	_streak_lbl.add_theme_font_override("font", UITheme.font("Bold")); sh.add_child(_streak_lbl)
	r2.add_child(_streak_chip)
	_combo_chip = PanelContainer.new()
	_combo_chip.add_theme_stylebox_override("panel", UITheme.stat_chip(UITheme.ORANGE))
	var cch := HBoxContainer.new(); cch.add_theme_constant_override("separation", 3); _combo_chip.add_child(cch)
	cch.add_child(_icon("ic_boost", 18))
	_combo_lbl = Label.new(); _combo_lbl.add_theme_font_size_override("font_size", 17)
	_combo_lbl.add_theme_color_override("font_color", UITheme.ORANGE)
	_combo_lbl.add_theme_font_override("font", UITheme.font("Bold")); cch.add_child(_combo_lbl)
	_combo_chip.visible = false; r2.add_child(_combo_chip)
	_income_lbl = Label.new(); _income_lbl.add_theme_font_size_override("font_size", 21)
	_income_lbl.add_theme_color_override("font_color", UITheme.GREEN)
	_income_lbl.add_theme_font_override("font", UITheme.font("Bold"))
	_income_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; r2.add_child(_income_lbl)

	# Row 3: progress ribbon (% to next unlock)
	var ribbon_bg := Panel.new(); ribbon_bg.custom_minimum_size = Vector2(0, 5)
	ribbon_bg.add_theme_stylebox_override("panel", UITheme.prog_bg()); v.add_child(ribbon_bg)
	_ribbon_fill = Panel.new()
	_ribbon_fill.anchor_left = 0; _ribbon_fill.anchor_right = 0.0
	_ribbon_fill.anchor_top = 0; _ribbon_fill.anchor_bottom = 1
	_ribbon_fill.add_theme_stylebox_override("panel", UITheme.prog_fill(UITheme.ACCENT))
	ribbon_bg.add_child(_ribbon_fill)

	# Row 4: event banner (hidden when no event)
	_event_row = HBoxContainer.new(); _event_row.add_theme_constant_override("separation", 8)
	_event_row.visible = false; v.add_child(_event_row)
	_event_icon = _icon("ic_event", 24); _event_row.add_child(_event_icon)
	var ev_info := VBoxContainer.new(); ev_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _event_row.add_child(ev_info)
	_event_name_lbl = Label.new(); _event_name_lbl.add_theme_font_size_override("font_size", 17)
	_event_name_lbl.add_theme_font_override("font", UITheme.font("Bold")); ev_info.add_child(_event_name_lbl)
	var bar_bg := Panel.new(); bar_bg.custom_minimum_size = Vector2(0, 6)
	bar_bg.add_theme_stylebox_override("panel", UITheme.prog_bg()); ev_info.add_child(bar_bg)
	_event_timer_bar = Panel.new()
	_event_timer_bar.anchor_left = 0; _event_timer_bar.anchor_right = 1
	_event_timer_bar.anchor_top = 0; _event_timer_bar.anchor_bottom = 1
	bar_bg.add_child(_event_timer_bar)

func _chip(icon: String, color: Color, lbl_size: int) -> Dictionary:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UITheme.stat_chip(color))
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 4); pc.add_child(h)
	h.add_child(_icon(icon, 22))
	var lbl := Label.new(); lbl.add_theme_font_size_override("font_size", lbl_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_override("font", UITheme.font("Bold")); h.add_child(lbl)
	return {"root": pc, "label": lbl}

# ── Ad bar ────────────────────────────────────────────────────────────────────

func _build_adbar() -> void:
	_adbar = HBoxContainer.new()
	_adbar.anchor_left = 0; _adbar.anchor_right = 1
	_adbar.anchor_top = 1; _adbar.anchor_bottom = 1
	_adbar.offset_top = -(NAV_H + TABS_H + AD_H); _adbar.offset_bottom = -(NAV_H + TABS_H)
	_adbar.offset_left = GUTTER; _adbar.offset_right = -GUTTER
	_adbar.add_theme_constant_override("separation", 8); add_child(_adbar)
	_adbar.add_child(_ad_pill("ic_boost", "2× 5min",
		func(): Ads.show_rewarded("x2", GameState.boost_earn_2x)))
	_adbar.add_child(_ad_pill("ic_cash", "30min grátis",
		func(): Ads.show_rewarded("cash", func():
			GameState.grant_cash_minutes(30); _disp_credits = GameState.credits
			Fx.chip_pop(_credits_chip, UITheme.GOLD)
			_toast("+30min de lucros!", UITheme.GREEN, "ic_cash"))))
	_adbar.add_child(_ad_pill("ic_gems", "+20 Gemas",
		func(): Ads.show_rewarded("gems", func():
			GameState.grant_gems(20)
			_toast("+20 Gemas!", UITheme.CYAN, "ic_gems"))))

func _ad_pill(icon_name: String, text: String, cb: Callable) -> Button:
	var b := Button.new(); b.text = ""
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, AD_H - 8)
	b.add_theme_stylebox_override("normal",  UITheme.ad_btn())
	b.add_theme_stylebox_override("hover",   UITheme.ad_btn())
	b.add_theme_stylebox_override("pressed", UITheme.solid(UITheme.GREEN_D, 14))
	b.add_theme_stylebox_override("focus",   StyleBoxEmpty.new())
	var row := HBoxContainer.new(); row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE; b.add_child(row)
	var ic := _icon(icon_name, 22); ic.mouse_filter = Control.MOUSE_FILTER_IGNORE; row.add_child(ic)
	var lbl := Label.new(); lbl.text = text; lbl.add_theme_font_size_override("font_size", 17)
	lbl.add_theme_color_override("font_color", Color.WHITE); lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)
	b.pressed.connect(func(): Fx.press(b); cb.call())
	# periodic shimmer to draw the eye
	Fx.shimmer(b, UITheme.GREEN, true)
	return b

# ── Bottom bg ─────────────────────────────────────────────────────────────────

func _build_bottom_bg() -> void:
	var bg := Panel.new()
	bg.anchor_left = 0; bg.anchor_right = 1
	bg.anchor_top = 1; bg.anchor_bottom = 1
	bg.offset_top = -(NAV_H + TABS_H + AD_H); bg.offset_bottom = 0
	bg.add_theme_stylebox_override("panel", UITheme.bottom_panel())
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(bg)

# ── Pages ──────────────────────────────────────────────────────────────────────

func _build_pages() -> void:
	_pages = [_build_fleet_tab(), _build_cities_tab(), _build_talents_tab(),
			  _build_legado_tab(), _build_shop_tab(), _build_missions_tab()]
	for pg in _pages:
		add_child(pg)
		_make_scrollable(pg)
		(pg as ScrollContainer).gui_input.connect(_on_scroll_gui_input)

## Make the WHOLE card surface drag-scrollable. Buttons → PASS (so drags over
## them still bubble to the ScrollContainer for scrolling) but guarded by
## _can_tap() so a drag never triggers a purchase. Everything else → IGNORE.
func _make_scrollable(n: Node) -> void:
	for child in n.get_children():
		if child is BaseButton:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_PASS
		elif child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_make_scrollable(child)

## Detect a scroll drag and block taps briefly so dragging over a button never
## fires it. Built-in ScrollContainer handles the actual scrolling.
func _on_scroll_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		if absf((event as InputEventScreenDrag).relative.y) > 1.5:
			_tap_block_until = Time.get_ticks_msec() + 160
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0 and absf(mm.relative.y) > 1.5:
			_tap_block_until = Time.get_ticks_msec() + 160

func _can_tap() -> bool:
	return Time.get_ticks_msec() >= _tap_block_until

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

	var defs := [["ic_nav_fleet","Frota"],["ic_nav_cities","Cidades"],["ic_nav_talents","Talentos"],["ic_nav_legado","Legado"],["ic_nav_shop","Loja"],["ic_nav_missions","Missões"]]
	for i in defs.size():
		nav.add_child(_make_nav_btn(defs[i][0], defs[i][1], i))

	# sliding accent indicator resting on top edge of the nav bar (glowing pill)
	_nav_ind = Panel.new()
	_nav_ind.add_theme_stylebox_override("panel", UITheme.prog_fill(UITheme.ACCENT.lightened(0.15)))
	_nav_ind.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nav_ind.anchor_left = 0; _nav_ind.anchor_right = 0
	_nav_ind.anchor_top = 1; _nav_ind.anchor_bottom = 1
	_nav_ind.offset_top = -NAV_H - 2; _nav_ind.offset_bottom = -NAV_H + 4
	add_child(_nav_ind)

func _make_nav_btn(icon_name: String, label_text: String, idx: int) -> Button:
	var btn := Button.new(); btn.text = ""
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, NAV_H)
	btn.add_theme_stylebox_override("normal",  UITheme.nav_item(false))
	btn.add_theme_stylebox_override("hover",   UITheme.nav_item(false))
	btn.add_theme_stylebox_override("pressed", UITheme.nav_item(true))
	btn.add_theme_stylebox_override("focus",   StyleBoxEmpty.new())

	var box := VBoxContainer.new(); box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE; btn.add_child(box)
	var ic := _icon(icon_name, 40); ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE; box.add_child(ic)
	var lbl := Label.new(); lbl.text = label_text; lbl.add_theme_font_size_override("font_size", 17)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(lbl)

	# affordable dot (top-right)
	var dot := _icon("dot", 10); dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.modulate = UITheme.GOLD; dot.anchor_left = 1; dot.anchor_right = 1
	dot.anchor_top = 0; dot.anchor_bottom = 0
	dot.offset_left = -22; dot.offset_right = -10; dot.offset_top = 14; dot.offset_bottom = 26
	dot.visible = false; btn.add_child(dot)

	btn.pressed.connect(func(): Fx.press(btn); _switch_tab(idx))
	_nav_btns.append(btn); _nav_icons.append(ic); _nav_labels.append(lbl); _nav_dots.append(dot)
	return btn

func _switch_tab(i: int) -> void:
	for j in _pages.size():
		_pages[j].visible = (j == i)
	for j in _nav_btns.size():
		var active := (j == i)
		var btn: Button = _nav_btns[j]
		var ic: TextureRect = _nav_icons[j]
		var lbl: Label = _nav_labels[j]
		btn.add_theme_stylebox_override("normal", UITheme.nav_item(active))
		btn.add_theme_stylebox_override("hover",  UITheme.nav_item(active))
		ic.modulate = UITheme.ACCENT if active else UITheme.MUTED
		lbl.add_theme_color_override("font_color", UITheme.INK if active else UITheme.MUTED)
		var target := 1.12 if active else 1.0
		ic.pivot_offset = ic.size * 0.5
		var tw := ic.create_tween()
		tw.tween_property(ic, "scale", Vector2(target, target), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _nav_ind != null:
		var bw := get_viewport_rect().size.x / 6.0
		var pad := bw * 0.22
		var tw2 := _nav_ind.create_tween()
		tw2.set_parallel(true)
		tw2.tween_property(_nav_ind, "offset_left", bw * float(i) + pad, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw2.tween_property(_nav_ind, "offset_right", bw * float(i + 1) - pad, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_stagger_in(i)

## Fade-cascade the rows of the newly shown tab.
func _stagger_in(i: int) -> void:
	if Fx.reduce_motion: return
	if i < 0 or i >= _pages.size(): return
	var sc: ScrollContainer = _pages[i]
	if sc.get_child_count() == 0: return
	var vbox := sc.get_child(0)
	var k := 0
	for child in vbox.get_children():
		if not (child is CanvasItem): continue
		var ci := child as CanvasItem
		ci.modulate = Color(1, 1, 1, 0)
		var tw := ci.create_tween()
		tw.tween_interval(float(k) * 0.04)
		tw.tween_property(ci, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		k += 1

# ── Scroll wrapper ──────────────────────────────────────────────────────────────

func _scroll(title: String) -> Array:
	var sc := ScrollContainer.new(); sc.name = title
	sc.anchor_left = 0; sc.anchor_right = 1
	sc.anchor_top = 1; sc.anchor_bottom = 1
	sc.offset_top = -(NAV_H + TABS_H); sc.offset_bottom = -NAV_H
	sc.offset_left = GUTTER - 6.0; sc.offset_right = -(GUTTER - 6.0)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 11)
	sc.add_child(v)
	return [sc, v]

# ── Section header (uppercase + hairline rule) ────────────────────────────────

func _section(text: String, color: Color, icon_name := "") -> Control:
	var wrap := VBoxContainer.new(); wrap.add_theme_constant_override("separation", 4)
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 6); wrap.add_child(h)
	if icon_name != "":
		h.add_child(_icon(icon_name, 22))
	# tr() explicitly BEFORE upper-casing: Label.text auto-translates on
	# assignment, so translating the already-uppercased string would look up
	# the wrong (uppercase) key in the CSV and silently miss.
	var l := Label.new(); l.text = tr(text).to_upper()
	l.add_theme_font_size_override("font_size", 16); l.add_theme_font_override("font", UITheme.font("Bold"))
	l.add_theme_color_override("font_color", color)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(l)
	var rule := Panel.new(); rule.custom_minimum_size = Vector2(0, 2)
	rule.add_theme_stylebox_override("panel", UITheme.section_rule()); wrap.add_child(rule)
	return wrap

# ── Fleet tab ───────────────────────────────────────────────────────────────────

func _build_fleet_tab() -> ScrollContainer:
	var r := _scroll("Frota"); var v: VBoxContainer = r[1]

	var seg_row := HBoxContainer.new(); seg_row.add_theme_constant_override("separation", 6); v.add_child(seg_row)
	for m: Array in [[1,"×1"],[10,"×10"],[100,"×100"],[-1,"Máx"]]:
		var mode_val: int = m[0]; var mode_lbl: String = m[1]
		var b := Button.new(); b.text = mode_lbl; b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 48); b.add_theme_font_size_override("font_size", 20)
		b.add_theme_stylebox_override("normal",  UITheme.seg(false))
		b.add_theme_stylebox_override("hover",   UITheme.seg(false))
		b.add_theme_stylebox_override("pressed", UITheme.seg(true))
		b.add_theme_stylebox_override("focus",   StyleBoxEmpty.new())
		b.pressed.connect(func(): GameState.buy_mode = mode_val; Fx.press(b))
		seg_row.add_child(b); _mode_btns[mode_val] = b

	var dr := _row(UITheme.ACCENT, "ic_drone")
	dr["title"].text = "Comprar Drones"
	_drone_detail = dr["detail"]
	_drone_btn = _cbuy(UITheme.GREEN, 160.0)
	_drone_btn.pressed.connect(func():
		if not _can_tap(): return
		if GameState.buy_drones() > 0:
			Fx.press(_drone_btn); Audio.play("whoosh")
			_reward_fx(_drone_btn, UITheme.ACCENT, "spark", 8)
		else:
			Fx.error_shake(_drone_btn)
	)
	dr["right"].add_child(_drone_btn); v.add_child(dr["card"])

	for key: String in ["speed", "cargo", "value", "routes"]:
		v.add_child(_make_upgrade_row(key))

	v.add_child(_section("Prestige", UITheme.PRESTIGE, "ic_prestige"))
	var pp := PanelContainer.new(); pp.add_theme_stylebox_override("panel", UITheme.prestige_card()); v.add_child(pp)
	var pv := VBoxContainer.new(); pv.add_theme_constant_override("separation", 8); pp.add_child(pv)
	_prestige_info_lbl = _lbl("", 16, UITheme.MUTED)
	_prestige_info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; pv.add_child(_prestige_info_lbl)
	_prestige_btn = Button.new(); _prestige_btn.add_theme_font_size_override("font_size", 22)
	_prestige_btn.add_theme_font_override("font", UITheme.font("Bold"))
	_prestige_btn.icon = _opt_tex("ic_prestige"); _prestige_btn.expand_icon = true
	_prestige_btn.add_theme_constant_override("icon_max_width", 26)
	_prestige_btn.custom_minimum_size = Vector2(0, 68)
	_prestige_btn.add_theme_stylebox_override("normal",   UITheme.prestige_btn_ready())
	_prestige_btn.add_theme_stylebox_override("hover",    UITheme.prestige_btn_ready())
	_prestige_btn.add_theme_stylebox_override("pressed",  UITheme.prestige_card())
	_prestige_btn.add_theme_stylebox_override("disabled", UITheme.action_btn_disabled())
	_prestige_btn.add_theme_stylebox_override("focus",    StyleBoxEmpty.new())
	_prestige_btn.pressed.connect(func():
		if not _can_tap(): return
		Fx.press(_prestige_btn); _show_prestige_confirm()
	)
	pv.add_child(_prestige_btn)
	return r[0]

# ── Cities tab ──────────────────────────────────────────────────────────────────

func _build_cities_tab() -> ScrollContainer:
	var r := _scroll("Cidades"); var v: VBoxContainer = r[1]
	_progress_lbl = _lbl("", 17, UITheme.MUTED)
	_progress_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.add_child(_progress_lbl)
	var cpb := Panel.new(); cpb.custom_minimum_size = Vector2(0, 8)
	cpb.add_theme_stylebox_override("panel", UITheme.prog_bg()); v.add_child(cpb)
	_city_prog_fill = Panel.new()
	_city_prog_fill.anchor_left = 0; _city_prog_fill.anchor_right = 0.0
	_city_prog_fill.anchor_top = 0; _city_prog_fill.anchor_bottom = 1
	_city_prog_fill.add_theme_stylebox_override("panel", UITheme.prog_fill(UITheme.CYAN))
	cpb.add_child(_city_prog_fill)

	var cr := _row(UITheme.CYAN, "ic_range")
	cr["title"].text = "Abrir Cidade"
	cr["detail"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_city_detail = cr["detail"]
	_city_btn = _cbuy(UITheme.CYAN.darkened(0.10), 150.0)
	_city_btn.pressed.connect(func():
		if not _can_tap(): return
		if GameState.unlock_city(): Fx.press(_city_btn); Audio.play("buy")
		else: Fx.error_shake(_city_btn)
	)
	cr["right"].add_child(_city_btn); v.add_child(cr["card"])

	var er := _row(UITheme.GOLD, "ic_city")
	er["title"].text = "Expandir país"
	er["detail"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_expand_detail = er["detail"]
	_expand_btn = _cbuy(UITheme.GOLD.darkened(0.08), 150.0)
	_expand_btn.pressed.connect(func():
		if not _can_tap(): return
		if GameState.expand_country(): Fx.press(_expand_btn); Audio.play("buy")
		else: Fx.error_shake(_expand_btn)
	)
	er["right"].add_child(_expand_btn); v.add_child(er["card"])

	v.add_child(_section("Rede de cidades", UITheme.CYAN, "ic_city"))
	_city_list_box = VBoxContainer.new()
	_city_list_box.add_theme_constant_override("separation", 7)
	v.add_child(_city_list_box)
	_rebuild_city_list()
	return r[0]

## One compact status row per city of the current country (fills the Cidades tab).
func _rebuild_city_list() -> void:
	if _city_list_box == null: return
	for c in _city_list_box.get_children():
		c.queue_free()
	var ci := GameState.current_country
	var cities := Economy.country_cities(ci)
	for i in range(cities.size()):
		var row := PanelContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 8); row.add_child(h)
		var nm := _lbl(str(cities[i]["name"]), 17, UITheme.INK)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if i == 0:
			row.add_theme_stylebox_override("panel", UITheme.solid(UITheme.PANEL2.lerp(UITheme.GOLD, 0.10), 14))
			h.add_child(_icon("ic_city", 22)); h.add_child(nm)
			var tag := _lbl("SEDE", 14, UITheme.GOLD)
			tag.add_theme_font_override("font", UITheme.font("Bold")); h.add_child(tag)
		elif i <= GameState.cities_unlocked:
			row.add_theme_stylebox_override("panel", UITheme.solid(UITheme.PANEL2.lerp(UITheme.CYAN, 0.08), 14))
			h.add_child(_icon("ic_range", 22)); h.add_child(nm)
			h.add_child(_icon("ic_check", 20))
		elif i == GameState.cities_unlocked + 1:
			row.add_theme_stylebox_override("panel", UITheme.solid(UITheme.PANEL2.lerp(UITheme.ACCENT, 0.10), 14))
			h.add_child(_icon("ic_city", 22)); h.add_child(nm)
			var cost := _lbl(Fmt.short(Economy.city_unlock_cost(ci, GameState.cities_unlocked)), 15, UITheme.GOLD)
			cost.add_theme_font_override("font", UITheme.font("Bold")); h.add_child(cost)
		else:
			row.add_theme_stylebox_override("panel", UITheme.solid(UITheme.PANEL2.darkened(0.15), 14))
			nm.add_theme_color_override("font_color", UITheme.MUTED)
			h.add_child(_icon("ic_lock", 20)); h.add_child(nm)
		_make_scrollable(row)
		_city_list_box.add_child(row)

# ── Talents tab ─────────────────────────────────────────────────────────────────

func _build_talents_tab() -> ScrollContainer:
	var r := _scroll("Talentos"); var v: VBoxContainer = r[1]
	var info := _lbl("Influência ganha-se ao expandir países.\nGasta-a em bónus válidos até ao próximo Prestige.", 16, UITheme.MUTED)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.add_child(info)
	for key: String in Economy.TALENT_ORDER:
		v.add_child(_make_talent_row(key))
	return r[0]

# ── Legado tab ──────────────────────────────────────────────────────────────────

func _build_legado_tab() -> ScrollContainer:
	var r := _scroll("Legado"); var v: VBoxContainer = r[1]

	var ps_card := PanelContainer.new(); ps_card.add_theme_stylebox_override("panel", UITheme.prestige_card()); v.add_child(ps_card)
	var ps_v := VBoxContainer.new(); ps_v.add_theme_constant_override("separation", 6); ps_card.add_child(ps_v)
	var ps_h := HBoxContainer.new(); ps_h.add_theme_constant_override("separation", 6); ps_v.add_child(ps_h)
	ps_h.add_child(_icon("ic_prestige", 24))
	ps_h.add_child(_lbl("Sistema de Prestige", 21, UITheme.PRESTIGE))
	var ps_info := _lbl("Reinicia com multiplicador permanente.\nRequer 5.º país desbloqueado.", 15, UITheme.MUTED)
	ps_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; ps_v.add_child(ps_info)

	# Prestige Gems balance — distinct from the HUD's Influência chip, which
	# players previously had no way to tell apart (same icon/colour, no label
	# anywhere showed the actual pgems total).
	var pg_row := HBoxContainer.new(); pg_row.add_theme_constant_override("separation", 6); ps_v.add_child(pg_row)
	pg_row.add_child(_icon("ic_prestige", 20))
	pg_row.add_child(_lbl("Gemas de Prestígio:", 15, UITheme.MUTED))
	_pgems_lbl = _lbl("0", 17, UITheme.PRESTIGE)
	_pgems_lbl.add_theme_font_override("font", UITheme.font("Bold")); pg_row.add_child(_pgems_lbl)

	v.add_child(_section("Loja de Prestige", UITheme.PRESTIGE, "ic_prestige"))
	for id: String in Prestige.SHOP_ORDER:
		v.add_child(_make_prestige_shop_row(id))

	v.add_child(_section("Conquistas", UITheme.GOLD, "ic_achieve"))
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
	var pb := Button.new(); pb.text = str(int(item["cost"]))
	pb.icon = _opt_tex("ic_prestige"); pb.expand_icon = true; pb.add_theme_constant_override("icon_max_width", 20)
	pb.custom_minimum_size = Vector2(106, 52); pb.add_theme_font_size_override("font_size", 18)
	pb.add_theme_stylebox_override("normal",   UITheme.prestige_btn_ready())
	pb.add_theme_stylebox_override("disabled", UITheme.action_btn_disabled())
	pb.add_theme_stylebox_override("focus",    StyleBoxEmpty.new())
	pb.pressed.connect(func():
		if not _can_tap(): return
		if Prestige.buy_shop(id):
			Fx.press(pb); Audio.play("buy"); _reward_fx(pb, UITheme.PRESTIGE, "gem", 8)
			pb.text = "Obtido"; pb.icon = _opt_tex("ic_check"); pb.disabled = true
		else:
			Fx.error_shake(pb)
	)
	if Prestige.has_shop(id):
		pb.text = "Obtido"; pb.icon = _opt_tex("ic_check"); pb.disabled = true
	ph.add_child(pb)
	return pp

func _make_achievement_row(id: String) -> PanelContainer:
	var def: Dictionary = Achievements.DEFS[id]
	var done: bool = Achievements.is_done(id)
	var secret: bool = bool(def.get("secret", false)) and not done
	var pp := PanelContainer.new(); pp.add_theme_stylebox_override("panel", UITheme.achievement_card(done))
	var ph := HBoxContainer.new(); ph.add_theme_constant_override("separation", 10); pp.add_child(ph)
	var icon_lbl := Label.new(); icon_lbl.text = "?" if secret else str(def["icon"])
	icon_lbl.add_theme_font_size_override("font_size", 28); icon_lbl.custom_minimum_size = Vector2(34, 0)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; ph.add_child(icon_lbl)
	var pv := VBoxContainer.new(); pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL; ph.add_child(pv)
	var name_lbl := _lbl("???" if secret else str(def["name"]), 18, UITheme.GOLD if done else UITheme.INK)
	name_lbl.add_theme_font_override("font", UITheme.font("Bold")); pv.add_child(name_lbl)
	var desc_lbl := _lbl("Conquista secreta." if secret else str(def["desc"]), 14, UITheme.MUTED)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; pv.add_child(desc_lbl)
	if not done and not secret:
		var prog := Achievements.progress(id)
		if prog.y > 0.0:
			var pb_bg := Panel.new(); pb_bg.custom_minimum_size = Vector2(0, 5)
			pb_bg.add_theme_stylebox_override("panel", UITheme.prog_bg()); pv.add_child(pb_bg)
			var pb_fill := Panel.new(); pb_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
			pb_fill.anchor_right = clampf(prog.x / prog.y, 0.0, 1.0)
			pb_fill.visible = pb_fill.anchor_right >= 0.02
			pb_fill.add_theme_stylebox_override("panel", UITheme.prog_fill(UITheme.GOLD))
			pb_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE; pb_bg.add_child(pb_fill)
			var prog_lbl := _lbl("%s / %s" % [Fmt.short(prog.x), Fmt.short(prog.y)], 12, UITheme.MUTED)
			pv.add_child(prog_lbl)
			_achieve_prog_fills[id] = pb_fill
			_achieve_prog_lbls[id] = prog_lbl
	if done:
		ph.add_child(_icon("ic_check", 26))
	_achieve_cells[id] = pp
	return pp

# ── Shop tab ────────────────────────────────────────────────────────────────────

func _build_shop_tab() -> ScrollContainer:
	var r := _scroll("Loja"); var v: VBoxContainer = r[1]
	_build_offer_card(v)
	var gi := _card(UITheme.CYAN)
	var gv := HBoxContainer.new(); gv.add_theme_constant_override("separation", 6); gi.add_child(gv)
	gv.add_child(_icon("ic_gems", 22))
	gv.add_child(_lbl("Gemas — ganha com anúncios (acima)", 17, UITheme.CYAN))
	v.add_child(gi)
	for id: String in Economy.GEM_SHOP_ORDER:
		v.add_child(_make_gem_row(id))

	v.add_child(_section("Hangar de Skins", UITheme.CYAN, "ic_drone"))
	var sk_info := _lbl("Skins permanentes para a tua frota. Cada skin extra dá +2% de lucros.", 15, UITheme.MUTED)
	sk_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.add_child(sk_info)
	for id: String in Economy.SKIN_ORDER:
		v.add_child(_make_skin_row(id))

	var daily_card := _card(UITheme.GOLD); v.add_child(daily_card)
	var daily_v := VBoxContainer.new(); daily_v.add_theme_constant_override("separation", 4); daily_card.add_child(daily_v)
	var dch := HBoxContainer.new(); dch.add_theme_constant_override("separation", 6); daily_v.add_child(dch)
	dch.add_child(_icon("ic_daily", 22))
	dch.add_child(_lbl("Recompensa Diária", 20, UITheme.GOLD))
	var daily_info := _lbl("Faz login todos os dias para ganhar gemas e bónus!", 15, UITheme.MUTED)
	daily_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; daily_v.add_child(daily_info)
	var daily_btn := _wide_btn(UITheme.GOLD.darkened(0.06))
	daily_btn.text = "Abrir"
	daily_btn.add_theme_color_override("font_color", Color(0.12, 0.08, 0.0))
	daily_btn.pressed.connect(func():
		Fx.press(daily_btn)
		if Daily.pending: _show_daily_popup()
		else: _toast("Já recebeste a recompensa de hoje!", UITheme.GOLD, "ic_daily")
	)
	daily_v.add_child(daily_btn)

	v.add_child(_section("Compras com dinheiro real", UITheme.MUTED))
	for id: String in Billing.PRODUCT_ORDER:
		v.add_child(_make_iap_row(id))
	return r[0]

## Limited-time highlight of the starter pack (real Play product). Countdown to
## local midnight; the card hides once the pack is owned or VIP is active.
func _build_offer_card(v: VBoxContainer) -> void:
	_offer_card = _card(UITheme.GOLD)
	var ov := VBoxContainer.new(); ov.add_theme_constant_override("separation", 5); _offer_card.add_child(ov)
	var oh := HBoxContainer.new(); oh.add_theme_constant_override("separation", 6); ov.add_child(oh)
	oh.add_child(_icon("ic_boost", 24))
	var ot := _lbl("Oferta de Fundador", 21, UITheme.GOLD)
	ot.add_theme_font_override("font", UITheme.font("Bold"))
	ot.size_flags_horizontal = Control.SIZE_EXPAND_FILL; oh.add_child(ot)
	_offer_time_lbl = _lbl("", 16, UITheme.ORANGE)
	_offer_time_lbl.add_theme_font_override("font", UITheme.font("Bold")); oh.add_child(_offer_time_lbl)
	var od := _lbl(str(Billing.PRODUCTS["starter"]["desc"]), 15, UITheme.MUTED)
	od.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; ov.add_child(od)
	var ob := _wide_btn(UITheme.GOLD.darkened(0.06))
	ob.text = str(Billing.PRODUCTS["starter"]["price"]) + "  ·  " + tr("Começar já!")
	ob.add_theme_color_override("font_color", Color(0.12, 0.08, 0.0))
	ob.custom_minimum_size = Vector2(0, 62)
	ob.pressed.connect(func():
		if not _can_tap(): return
		Fx.press(ob); Billing.buy("starter"); Audio.play("buy")
	)
	ov.add_child(ob)
	Fx.shimmer(ob, UITheme.GOLD, true)
	v.add_child(_offer_card)

func _make_skin_row(id: String) -> PanelContainer:
	var p: Dictionary = Economy.SKINS[id]
	var body: Color = p["body"]
	var r := _row(body if id != "classic" else UITheme.CYAN, "ic_drone")
	r["title"].text = p["name"]
	r["detail"].text = p["desc"]; r["detail"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var btn := _cbuy(UITheme.CYAN.darkened(0.18), 120.0)
	btn.pressed.connect(func():
		if not _can_tap(): return
		if GameState.has_skin(id):
			if GameState.set_skin(id):
				Fx.press(btn); Audio.play("whoosh")
				_toast(tr("Skin ativa: %s") % tr(str(p["name"])), body, "ic_drone")
		elif GameState.buy_skin(id):
			Fx.press(btn); Audio.play("buy"); _reward_fx(btn, body, "gem", 8)
			_toast(tr("Nova skin: %s!") % tr(str(p["name"])), body, "ic_drone")
			Fx.confetti(self, Vector2(size.x * 0.5, size.y * 0.45), 24, [body, UITheme.CYAN, UITheme.GOLD])
		else:
			Fx.error_shake(btn)
	)
	r["right"].add_child(btn)
	_skin_rows[id] = {"btn": btn}
	return r["card"]

# ── Card / button widgets ─────────────────────────────────────────────────────

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

## Buy button with cached normal/affordable styleboxes (no per-frame alloc).
func _buy_btn(color: Color) -> Button:
	var b := _wide_btn(color)
	b.set_meta("sb_n", UITheme.action_btn(color))
	b.set_meta("sb_a", UITheme.action_btn_affordable(color))
	return b

func _afford(b: Button, affordable: bool) -> void:
	if not is_instance_valid(b): return
	var sb: StyleBox = b.get_meta("sb_a") if affordable else b.get_meta("sb_n")
	b.add_theme_stylebox_override("normal", sb)

## Compact horizontal purchase row: [icon] [title+detail] [buy button].
## Returns {card, title, detail, right(HBox for the action button)}.
func _row(accent: Color, icon_name: String) -> Dictionary:
	var card := _card(accent)
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 10)
	card.add_child(h)
	h.add_child(_icon(icon_name, 32))
	var info := VBoxContainer.new(); info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER; info.add_theme_constant_override("separation", 1)
	h.add_child(info)
	var title := _lbl("", 18, UITheme.INK); info.add_child(title)
	var detail := _lbl("", 13, UITheme.MUTED); info.add_child(detail)
	var right := HBoxContainer.new(); right.alignment = BoxContainer.ALIGNMENT_END
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER; h.add_child(right)
	return {"card": card, "title": title, "detail": detail, "right": right}

## Compact fixed-width buy button (right-aligned in a row).
func _cbuy(color: Color, w := 150.0) -> Button:
	var b := _buy_btn(color)
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	b.custom_minimum_size = Vector2(w, 54)
	b.add_theme_font_size_override("font_size", 19)
	return b

func _make_upgrade_row(key: String) -> PanelContainer:
	var accent_map := {"speed": UITheme.ACCENT, "cargo": UITheme.AMBER, "value": UITheme.GREEN, "routes": UITheme.CYAN}
	var accent: Color = accent_map.get(key, UITheme.ACCENT)
	var r := _row(accent, Economy.UPGRADES[key].get("icon", "ic_speed"))
	r["title"].text = Economy.UPGRADES[key]["name"]
	var btn := _cbuy(UITheme.GREEN)
	btn.pressed.connect(func():
		if not _can_tap(): return
		var before_tier := int(GameState.levels[key]) / Economy.MILESTONE_STEP
		if GameState.buy_upgrade_multi(key) > 0:
			Fx.press(btn); Audio.play("buy"); _reward_fx(btn, accent, "spark", 6)
			if int(GameState.levels[key]) / Economy.MILESTONE_STEP > before_tier:
				_toast(tr("MARCO! %s ×2!") % tr(str(Economy.UPGRADES[key]["name"])), UITheme.GOLD, "ic_achieve")
				var c := Vector2(size.x * 0.5, size.y * 0.45)
				Fx.confetti(self, c, 30, [UITheme.GOLD, accent, UITheme.CYAN])
				Fx.screen_flash(self, UITheme.GOLD, 0.12)
				Fx.ring_pulse(self, c, UITheme.GOLD, 2.6)
				Audio.play("milestone")
		else:
			Fx.error_shake(btn)
	)
	r["right"].add_child(btn)
	_rows[key] = {"btn": btn, "detail": r["detail"]}
	return r["card"]

func _make_talent_row(key: String) -> PanelContainer:
	var p: Dictionary = Economy.TALENTS[key]
	var r := _row(UITheme.VIOLET, p.get("icon", "ic_prestige"))
	r["title"].text = p["name"]
	var btn := _cbuy(UITheme.VIOLET.darkened(0.10), 120.0)
	btn.icon = _opt_tex("ic_prestige"); btn.expand_icon = true
	btn.add_theme_constant_override("icon_max_width", 20)
	btn.pressed.connect(func():
		if not _can_tap(): return
		if GameState.buy_talent(key):
			Fx.press(btn); Audio.play("buy"); _reward_fx(btn, UITheme.VIOLET, "gem", 6)
		else:
			Fx.error_shake(btn)
	)
	r["right"].add_child(btn)
	_talent_rows[key] = {"btn": btn, "detail": r["detail"]}
	return r["card"]

func _make_gem_row(id: String) -> PanelContainer:
	var p: Dictionary = Economy.GEM_SHOP[id]
	var r := _row(UITheme.CYAN, p.get("icon", "ic_gems"))
	r["title"].text = p["name"]
	r["detail"].text = p["desc"]; r["detail"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var btn := _cbuy(UITheme.CYAN.darkened(0.18), 120.0)
	btn.icon = _opt_tex("ic_gems"); btn.expand_icon = true
	btn.add_theme_constant_override("icon_max_width", 20)
	btn.pressed.connect(func(): _buy_gem(id, btn))
	r["right"].add_child(btn)
	_gem_rows[id] = {"btn": btn}
	return r["card"]

func _make_iap_row(id: String) -> PanelContainer:
	var p: Dictionary = Billing.PRODUCTS[id]
	var r := _row(UITheme.GOLD, "ic_gems" if id.begins_with("gems") else "ic_boost")
	r["title"].text = p["name"]
	r["detail"].text = p["desc"]; r["detail"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var btn := _cbuy(UITheme.GOLD.darkened(0.06), 130.0); btn.text = p["price"]
	btn.add_theme_color_override("font_color", Color(0.12, 0.08, 0.0))
	btn.pressed.connect(func():
		if not _can_tap(): return
		Fx.press(btn); Billing.buy(id); Audio.play("buy")
	)
	r["right"].add_child(btn)
	if id == "vip":
		_add_ribbon(r["card"], "RECOMENDADO", UITheme.VIOLET)
	elif id == "gems_xl":
		_add_ribbon(r["card"], "MELHOR VALOR", UITheme.GOLD)
	return r["card"]

## Small pinned corner badge for highlighting the best-value / recommended
## purchase. NOTE: PanelContainer is a real Container — unlike a plain
## Control (see the nav bar's affordable "dot"), it ignores a child's own
## anchors/offsets and stretches every direct child to the full content rect.
## The correct way to carve out a corner within a Container is size_flags
## (SHRINK_END/SHRINK_BEGIN), which lets the child collapse to its natural
## size and align within that shared rect instead of filling it.
func _add_ribbon(card: PanelContainer, text: String, color: Color) -> void:
	var rb := PanelContainer.new()
	rb.size_flags_horizontal = Control.SIZE_SHRINK_END
	rb.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	rb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = color; sb.set_corner_radius_all(8)
	sb.content_margin_left = 8; sb.content_margin_right = 8
	sb.content_margin_top = 3; sb.content_margin_bottom = 3
	rb.add_theme_stylebox_override("panel", sb)
	var l := _lbl(text, 11, Color(0.08, 0.06, 0.0))
	l.add_theme_font_override("font", UITheme.font("Bold"))
	rb.add_child(l)
	card.add_child(rb)

func _buy_gem(id: String, btn: Button) -> void:
	if not _can_tap(): return
	var ok := false
	var grants_cash := false
	match id:
		"boost":      ok = GameState.buy_gem_boost()
		"cash":       ok = GameState.buy_gem_cash(int(Economy.GEM_SHOP["cash"]["cost"]), 3600.0); grants_cash = true
		"warp":       ok = GameState.buy_gem_cash(int(Economy.GEM_SHOP["warp"]["cost"]), 28800.0); grants_cash = true
		"warp24":     ok = GameState.buy_gem_cash(int(Economy.GEM_SHOP["warp24"]["cost"]), 86400.0); grants_cash = true
		"drone_pack": ok = GameState.buy_gem_drones(int(Economy.GEM_SHOP["drone_pack"]["cost"]), 10)
		"combo_time": ok = GameState.buy_gem_combo_time(int(Economy.GEM_SHOP["combo_time"]["cost"]))
	if ok:
		Fx.press(btn); Audio.play("buy"); _disp_credits = GameState.credits
		_reward_fx(btn, UITheme.CYAN, "gem", 7)
		if grants_cash: Fx.chip_pop(_credits_chip, UITheme.GOLD)
	else:
		Fx.error_shake(btn)

# ── Toasts ───────────────────────────────────────────────────────────────────────

func _build_toasts() -> void:
	_toasts = VBoxContainer.new(); _toasts.anchor_left = 0.5; _toasts.anchor_right = 0.5
	_toasts.offset_top = 200; _toasts.offset_left = -290; _toasts.offset_right = 290
	_toasts.alignment = BoxContainer.ALIGNMENT_CENTER; add_child(_toasts)

func _toast(text: String, accent: Color, icon_name := "") -> void:
	while _toasts.get_child_count() >= 3:
		var old := _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UITheme.toast(accent))
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 8); pc.add_child(h)
	if icon_name != "":
		h.add_child(_icon(icon_name, 22))
	var l := Label.new(); l.text = text; l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; h.add_child(l)
	_toasts.add_child(pc)
	pc.modulate = Color(1, 1, 1, 0); pc.position.y -= 8
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(pc, "modulate:a", 1.0, 0.18)
	tw.tween_property(pc, "position:y", pc.position.y + 8, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(2.0)
	tw.chain().tween_property(pc, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(pc.queue_free)

# ── Per-frame update ─────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_disp_credits = lerpf(_disp_credits, GameState.credits, clampf(delta * 8.0, 0.0, 1.0))
	if abs(_disp_credits - GameState.credits) < 1.0: _disp_credits = GameState.credits
	_credits_lbl.text = Fmt.short(_disp_credits)
	_gems_lbl.text    = str(GameState.gems)
	_infl_lbl.text    = (Prestige.tier_name() + " · " + str(GameState.influence)) if Prestige.count > 0 else str(GameState.influence)
	_vip_badge.visible = Billing.vip
	if _pgems_lbl != null and is_instance_valid(_pgems_lbl):
		_pgems_lbl.text = str(Prestige.pgems)

	# chip-pop on discrete currency increases
	if GameState.gems > _prev_gems: Fx.chip_pop(_gems_chip, UITheme.CYAN)
	if GameState.influence > _prev_infl: Fx.chip_pop(_infl_chip, UITheme.VIOLET)
	_prev_gems = GameState.gems; _prev_infl = GameState.influence

	var ips := GameState.income_per_sec()
	_income_lbl.text = "+" + Fmt.short(ips) + "/s"
	_income_lbl.add_theme_color_override("font_color", Events.color() if Events.is_active() else UITheme.GREEN)
	var cm := GameState.combo_mult()
	if cm > 1.0:
		_combo_chip.visible = true
		_combo_lbl.text = "×%.2f" % cm
		if cm > _prev_combo_mult:
			Fx.chip_pop(_combo_chip, UITheme.ORANGE)
	else:
		_combo_chip.visible = false
	_prev_combo_mult = cm

	_country_lbl.text = "%s · %d/%d" % [
		Economy.country_name(GameState.current_country),
		GameState.current_country + 1, Economy.num_countries()]
	_streak_lbl.text = "%dd" % Daily.streak
	_streak_chip.modulate = UITheme.GOLD if Daily.streak >= 7 else Color.WHITE

	_map.band_top    = _hud.position.y + _hud.size.y + 8.0
	_map.band_bottom = _adbar.position.y - 8.0
	_bonus.band_top = _map.band_top
	_bonus.band_bottom = _map.band_bottom

	# progress ribbon (HUD): % to next city or expand
	_set_fill(_ribbon_fill, _unlock_progress())
	# cities tab progress bar: strictly city unlock progress
	var _cc := GameState.next_city_cost()
	_set_fill(_city_prog_fill, clampf(GameState.credits / _cc, 0.0, 1.0) if _cc > 0.0 else 1.0)

	if Events.is_active():
		_set_fill(_event_timer_bar, Events.time_pct())

	for m in _mode_btns:
		var active: bool = (GameState.buy_mode == int(m))
		_mode_btns[m].add_theme_stylebox_override("normal", UITheme.seg(active))
		_mode_btns[m].add_theme_stylebox_override("hover",  UITheme.seg(active))

	var dc := GameState.drone_planned(); var dcost := GameState.drone_cost_multi(maxi(1, dc))
	_drone_btn.text     = (("×%d   " % dc) if GameState.buy_mode != 1 else "") + Fmt.short(dcost)
	_drone_btn.disabled = GameState.credits < dcost
	_afford(_drone_btn, not _drone_btn.disabled)
	_drone_detail.text  = "Tens %d drones" % GameState.drones

	for key: String in _rows:
		var count := GameState.planned_count(key); var cost := GameState.upgrade_cost_multi(key, maxi(1, count))
		var row: Dictionary = _rows[key]
		var btn: Button = row["btn"]
		btn.text    = (("×%d   " % count) if GameState.buy_mode != 1 else "") + Fmt.short(cost)
		btn.disabled = GameState.credits < cost
		_afford(btn, not btn.disabled)
		var ulvl := int(GameState.levels[key])
		var mm := int(Economy.milestone_mult(ulvl))
		var nxt := (ulvl / Economy.MILESTONE_STEP + 1) * Economy.MILESTONE_STEP
		var mi: String = (tr("Marco ×%d · próx. Nv %d") % [mm, nxt]) if mm > 1 else (tr("Marco ×2 ao Nv %d") % nxt)
		row["detail"].text = (tr("Nv %d · %s · %s") % [ulvl, _effect_total(key, ulvl), mi]) if ulvl > 0 else (tr("Nv 0 · %s · %s") % [_effect(key), mi])

	for key: String in _talent_rows:
		var tp: Dictionary = Economy.TALENTS[key]; var lvl := int(GameState.talents[key])
		# NOTE: named "trow" (not "tr") — "tr" would shadow the global tr()
		# translation function used two lines below.
		var trow: Dictionary = _talent_rows[key]
		var tbtn: Button = trow["btn"]
		if lvl >= int(tp["max"]):
			tbtn.text = tr("MÁX"); tbtn.disabled = true; tbtn.icon = null
		else:
			tbtn.text = str(GameState.talent_cost(key)); tbtn.disabled = not GameState.can_buy_talent(key)
		_afford(tbtn, not tbtn.disabled)
		var tdesc: String = _talent_effect_total(key, lvl) if lvl > 0 else str(tp["desc"])
		trow["detail"].text = tr("Nv %d/%d · %s") % [lvl, int(tp["max"]), tdesc]

	var gb: Dictionary = _gem_rows.get("boost", {})
	if not gb.is_empty():
		var bc := GameState.gem_boost_cost()
		var bbtn: Button = gb["btn"]
		bbtn.text = str(bc); bbtn.disabled = GameState.gems < bc; _afford(bbtn, not bbtn.disabled)
	for id: String in ["cash", "warp", "warp24", "drone_pack"]:
		var gr: Dictionary = _gem_rows.get(id, {})
		if not gr.is_empty():
			var c: int = int(Economy.GEM_SHOP[id]["cost"])
			var gbtn: Button = gr["btn"]
			gbtn.text = str(c); gbtn.disabled = GameState.gems < c; _afford(gbtn, not gbtn.disabled)
	var gct: Dictionary = _gem_rows.get("combo_time", {})
	if not gct.is_empty():
		var ct_btn: Button = gct["btn"]
		if GameState.combo_window_bonus > 0.0:
			ct_btn.text = tr("Obtido"); ct_btn.disabled = true; ct_btn.icon = null
			_afford(ct_btn, false)
		else:
			var cc2: int = int(Economy.GEM_SHOP["combo_time"]["cost"])
			ct_btn.text = str(cc2); ct_btn.disabled = GameState.gems < cc2
			_afford(ct_btn, not ct_btn.disabled)

	for sid: String in _skin_rows:
		var sbtn: Button = _skin_rows[sid]["btn"]
		if GameState.skin_active == sid:
			sbtn.text = tr("Ativa"); sbtn.disabled = true; sbtn.icon = _opt_tex("ic_check")
			_afford(sbtn, false)
		elif GameState.has_skin(sid):
			sbtn.text = tr("Usar"); sbtn.disabled = false; sbtn.icon = null
			_afford(sbtn, true)
		else:
			var scost: int = int(Economy.SKINS[sid]["cost"])
			sbtn.text = str(scost); sbtn.icon = _opt_tex("ic_gems")
			sbtn.disabled = GameState.gems < scost
			_afford(sbtn, not sbtn.disabled)

	if _offer_card != null:
		var show_offer: bool = not Billing.starter_owned and not Billing.vip
		_offer_card.visible = show_offer
		if show_offer and Engine.get_frames_drawn() % 30 == 0:
			var now := Time.get_datetime_dict_from_system()
			var left: int = (23 - int(now["hour"])) * 3600 + (59 - int(now["minute"])) * 60 + (60 - int(now["second"]))
			_offer_time_lbl.text = tr("Termina em %d:%02d:%02d") % [left / 3600, (left % 3600) / 60, left % 60]

	_progress_lbl.text = tr("%s — %d/%d cidades abertas.") % [Economy.country_name(GameState.current_country), GameState.cities_unlocked, GameState.max_cities()]
	var cc := GameState.next_city_cost()
	if cc < 0.0:
		_city_btn.disabled = true; _city_btn.text = tr("TODAS")
		_city_detail.text = tr("Todas as cidades estão abertas.")
	else:
		_city_btn.text = Fmt.short(cc); _city_btn.disabled = GameState.credits < cc
		var ci := GameState.current_country; var cities := Economy.country_cities(ci)
		var nx: int = clampi(GameState.cities_unlocked + 1, 1, cities.size() - 1)
		_city_detail.text = tr("Próxima: %s") % cities[nx]["name"]
	_afford(_city_btn, not _city_btn.disabled and cc >= 0.0)
	var ec := GameState.expand_cost()
	if ec < 0.0:
		_expand_btn.disabled = true; _expand_btn.text = tr("FIM")
		_expand_detail.text = tr("Chegaste ao último país. Parabéns!")
	elif not GameState.all_cities_unlocked():
		_expand_btn.disabled = true; _expand_btn.text = tr("Bloqueado")
		_expand_detail.text = tr("Abre todas as cidades de %s primeiro.") % Economy.country_name(GameState.current_country)
	else:
		_expand_btn.text = Fmt.short(ec); _expand_btn.disabled = GameState.credits < ec
		_expand_detail.text = tr("Seguinte: %s (+Influência)") % Economy.country_name(GameState.current_country + 1)
	_afford(_expand_btn, not _expand_btn.disabled and ec >= 0.0 and GameState.all_cities_unlocked())

	# prestige button
	var ready := Prestige.can_prestige()
	if ready:
		_prestige_btn.text = "PRESTIGE  (+%d)" % Prestige.pgems_on_next_prestige()
		_prestige_btn.disabled = false
		_prestige_info_lbl.text = tr("Tier: %s · Prestige #%d · ×%.2f\nReinicias mantendo gemas e conquistas.") % [Prestige.tier_name(), Prestige.count + 1, Prestige.permanent_mult * 1.15]
	else:
		_prestige_btn.text = tr("Prestige (requer 5.º país)")
		_prestige_btn.disabled = true
		_prestige_info_lbl.text = tr("Chega ao 5.º país para fazer prestige.\nTier: %s · Prestige %d · ×%.2f") % [Prestige.tier_name(), Prestige.count, Prestige.permanent_mult]
	if ready != _prestige_ready_prev:
		Fx.breathe(_prestige_btn, ready)
		_prestige_ready_prev = ready

	_update_nav_dots()

	if Engine.get_frames_drawn() % 15 == 0:
		_update_contracts()
	if Engine.get_frames_drawn() % 30 == 0 and _settings_stats_lbl != null:
		if is_instance_valid(_settings_stats_lbl):
			_settings_stats_lbl.text = _settings_stats_text()
		else:
			_settings_stats_lbl = null

	if Engine.get_frames_drawn() % 60 == 0:
		Achievements.check("income_1k",    ips >= 1000.0)
		Achievements.check("income_1m",    ips >= 1_000_000.0)
		Achievements.check("credits_1m",   GameState.credits >= 1_000_000.0)
		Achievements.check("credits_1b",   GameState.credits >= 1_000_000_000.0)
		Achievements.check("credits_1t",   GameState.credits >= 1_000_000_000_000.0)
		Achievements.check("earned_10b",   GameState.total_earned >= 10_000_000_000.0)
		Achievements.check("earned_1t",    GameState.total_earned >= 1_000_000_000_000.0)
		Achievements.check("influence_50", GameState.influence_total >= 50)
		Achievements.check("gems_100",     GameState.gems >= 100)
		_check_income_milestones()
		for id: String in _achieve_prog_fills:
			if Achievements.is_done(id): continue
			var prog := Achievements.progress(id)
			if prog.y > 0.0:
				_set_fill(_achieve_prog_fills[id] as Panel, clampf(prog.x / prog.y, 0.0, 1.0))
				(_achieve_prog_lbls[id] as Label).text = "%s / %s" % [Fmt.short(prog.x), Fmt.short(prog.y)]

## Hide near-zero fills: rounded corners + glow made sub-pixel fills render as
## floating glowing dots.
func _set_fill(p: Panel, pct: float) -> void:
	p.anchor_right = pct
	p.visible = pct >= 0.02

func _unlock_progress() -> float:
	var cc := GameState.next_city_cost()
	if cc < 0.0:
		var ec := GameState.expand_cost()
		if ec <= 0.0: return 1.0
		return clampf(GameState.credits / ec, 0.0, 1.0)
	return clampf(GameState.credits / cc, 0.0, 1.0)

func _update_nav_dots() -> void:
	if _nav_dots.size() < 6: return
	# Fleet
	var fleet := GameState.credits >= GameState.drone_cost_multi(1) or Prestige.can_prestige()
	for key: String in _rows:
		if not (_rows[key]["btn"] as Button).disabled: fleet = true
	_nav_dots[0].visible = fleet
	# Cities
	_nav_dots[1].visible = GameState.can_unlock_city() or GameState.can_expand()
	# Talents
	var tal := false
	for key: String in _talent_rows:
		if not (_talent_rows[key]["btn"] as Button).disabled: tal = true
	_nav_dots[2].visible = tal
	# Legado: affordable prestige shop
	var leg := false
	for id: String in Prestige.SHOP_ORDER:
		if not Prestige.has_shop(id) and Prestige.pgems >= int(Prestige.SHOP[id]["cost"]): leg = true
	_nav_dots[3].visible = leg
	# Shop: daily pending or gem boost affordable
	_nav_dots[4].visible = Daily.pending or GameState.gems >= GameState.gem_boost_cost()
	# Missões: any contract is ready to claim
	var mis := false
	for i in range(Contracts.SLOT_COUNT):
		if i < Contracts.slots.size() and Contracts.slots[i].get("ready", false) and not Contracts.slots[i].get("claimed", false):
			mis = true; break
	_nav_dots[5].visible = mis

func _effect(key: String) -> String:
	# tr() at return so these embedded (%s) effect strings follow the active
	# locale instead of staying Portuguese inside a translated template.
	match key:
		"speed":  return tr("+3%/nv velocidade")
		"cargo":  return tr("+0.25/nv carga")
		"value":  return tr("+4%/nv valor")
		"routes": return tr("+2.5%/nv eficiência de rota")
	return ""

## Cumulative total bonus at the given level (vs. the flat per-level rate in
## _effect) — much more useful once a few levels are owned.
func _effect_total(key: String, lvl: int) -> String:
	match key:
		"speed":  return tr("+%.0f%% total") % (3.0 * float(lvl))
		"cargo":  return tr("+%.0f%% total") % (25.0 * float(lvl))
		"value":  return tr("+%.0f%% total") % ((pow(1.04, float(lvl)) - 1.0) * 100.0)
		"routes": return tr("+%.0f%% total") % (2.5 * float(lvl))
	return ""

func _talent_effect_total(key: String, lvl: int) -> String:
	match key:
		"global": return tr("+%.0f%% lucros") % (6.0 * float(lvl))
		"speed":  return tr("+%.0f%% velocidade") % (4.0 * float(lvl))
		"value":  return tr("+%.0f%% valor") % (4.0 * float(lvl))
		"hangar": return tr("-%.0f%% custo drones") % (2.0 * float(lvl))
	return ""

# ── Signal handlers ──────────────────────────────────────────────────────────────

func _on_city_unlocked(i: int) -> void:
	_toast("Cidade desbloqueada!", UITheme.CYAN, "ic_city")
	var c := Vector2(size.x * 0.5, size.y * 0.42)
	Fx.confetti(self, c, 22)
	Fx.ring_pulse(self, c, UITheme.CYAN, 2.2)
	Fx.screen_flash(self, UITheme.CYAN, 0.10)
	_map.focus_city(i)
	_rebuild_city_list()

func _on_country_changed(i: int) -> void:
	_rebuild_city_list()
	var c := Vector2(size.x * 0.5, size.y * 0.40)
	if i >= Economy.num_countries() - 1:
		_toast("🏆 MISSÃO COMPLETA! Conquistaste o mundo!", UITheme.GOLD, "ic_city")
		_banana_rain()
		Fx.confetti(self, c, 80, [UITheme.GOLD, UITheme.CYAN, UITheme.GREEN, UITheme.PINK, Color(1,0.9,0.1)])
		Fx.screen_flash(self, UITheme.GOLD, 0.30)
		Fx.screen_shake(_map, 14.0)
		for _r in range(4):
			Fx.ring_pulse(self, c, UITheme.GOLD, 3.2)
			Fx.ring_pulse(self, c, UITheme.CYAN, 2.6)
		Audio.play("prestige")
	else:
		_toast(tr("Bem-vindo a %s!") % Economy.country_name(i), UITheme.GOLD, "ic_city")
		Fx.confetti(self, c, 48, [UITheme.GOLD, UITheme.CYAN, UITheme.GREEN, UITheme.PINK])
		Fx.screen_flash(self, UITheme.GOLD, 0.18)
		Fx.screen_shake(_map, 9.0)
		Fx.ring_pulse(self, c, UITheme.GOLD, 2.8)
		Fx.ring_pulse(self, c, UITheme.CYAN, 2.2)
		Audio.play("milestone")

func _banana_rain() -> void:
	var rng := RandomNumberGenerator.new(); rng.randomize()
	for i in range(50):
		var ban := Label.new()
		ban.text = "🍌"
		var sz := int(rng.randf_range(28.0, 72.0))
		ban.add_theme_font_size_override("font_size", sz)
		ban.position = Vector2(rng.randf() * size.x, -90.0)
		ban.rotation = rng.randf_range(-0.6, 0.6)
		add_child(ban)
		var dur := rng.randf_range(1.4, 3.2)
		var delay := rng.randf_range(0.0, 2.5)
		var tw := ban.create_tween()
		tw.tween_interval(delay)
		tw.set_parallel(true)
		tw.tween_property(ban, "position:y", size.y + 120.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(ban, "rotation", ban.rotation + rng.randf_range(-1.2, 1.2), dur)
		tw.chain().tween_callback(ban.queue_free)

func _on_achievement(id: String) -> void:
	var def: Dictionary = Achievements.DEFS.get(id, {})
	_toast(str(def.get("name", id)) + " desbloqueada!", UITheme.GOLD, "ic_achieve")
	Fx.screen_flash(self, UITheme.GOLD, 0.08)
	if _achieve_cells.has(id):
		_achieve_cells[id].add_theme_stylebox_override("panel", UITheme.achievement_card(true))
	if _achieve_prog_fills.has(id):
		(_achieve_prog_fills[id] as Panel).anchor_right = 1.0

func _on_event_start(id: String) -> void:
	var def: Dictionary = Events.DEFS.get(id, {})
	_event_name_lbl.text = str(def.get("name", "")) + " · " + str(def.get("desc", ""))
	_event_name_lbl.add_theme_color_override("font_color", Events.color())
	_event_icon.modulate = Events.color()
	# stylebox cached once per event (was allocated every frame in _process)
	_event_timer_bar.add_theme_stylebox_override("panel", UITheme.prog_fill(Events.color()))
	_event_row.visible = true
	_toast(str(def.get("name", "Evento")), Events.color(), "ic_event")
	_show_event_banner(def)

func _show_event_banner(def: Dictionary) -> void:
	var ev_col := Events.color()
	Fx.screen_flash(self, ev_col, 0.16, 0.12)
	if Fx.reduce_motion: return
	var bw := size.x * 0.86
	var banner := PanelContainer.new()
	banner.z_index = 90
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_theme_stylebox_override("panel", UITheme.solid(
		Color(0.06, 0.09, 0.17, 0.94).lerp(ev_col, 0.18), 24))
	banner.size = Vector2(bw, 160)
	banner.position = Vector2((size.x - bw) * 0.5, -170)
	var bv := VBoxContainer.new()
	bv.alignment = BoxContainer.ALIGNMENT_CENTER
	bv.add_theme_constant_override("separation", 5)
	banner.add_child(bv)
	var em := Label.new(); em.text = str(def.get("icon", "⚡"))
	em.add_theme_font_size_override("font_size", 44)
	em.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; bv.add_child(em)
	var nm := Label.new(); nm.text = str(def.get("name", "Evento"))
	nm.add_theme_font_size_override("font_size", 26)
	nm.add_theme_color_override("font_color", ev_col.lightened(0.25))
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; bv.add_child(nm)
	var dc := Label.new(); dc.text = str(def.get("desc", ""))
	dc.add_theme_font_size_override("font_size", 17)
	dc.add_theme_color_override("font_color", Color(0.82, 0.86, 0.95))
	dc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; bv.add_child(dc)
	add_child(banner)
	var tw := banner.create_tween()
	tw.tween_property(banner, "position:y", 210.0, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.0)
	tw.tween_property(banner, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(banner.queue_free)

func _on_prestige(_count: int) -> void:
	_disp_credits = 0.0
	_prev_gems = GameState.gems; _prev_infl = GameState.influence
	_toast("PRESTIGE! Bem-vindo ao recomeço!", UITheme.PRESTIGE, "ic_prestige")

# ── FX helpers ───────────────────────────────────────────────────────────────────

func _reward_fx(node: Control, color: Color, kind := "spark", n := 6) -> void:
	if not is_instance_valid(node): return
	var c := node.get_global_rect().get_center()
	Fx.burst(self, c, color, n, kind)

# ── Popups ───────────────────────────────────────────────────────────────────────

## Compact [icon_name, short_text] for a daily reward cell (avoids text wrap).
func _daily_compact(r: Dictionary) -> Array:
	if r.has("hours"):     return ["ic_cash", "%dh" % int(r["hours"])]
	if r.has("boost"):     return ["ic_boost", "2×"]
	if r.has("pgems"):     return ["ic_prestige", "+%d" % int(r.get("gems", r["pgems"]))]
	if r.has("influence") and not r.has("gems"): return ["ic_prestige", "+%d🌐" % int(r["influence"])]
	if r.has("gems"):      return ["ic_gems", "+%d" % int(r["gems"])]
	return ["ic_gems", "?"]

func _show_daily_popup() -> void:
	var layer := _overlay(); var box := _popup_box(layer, UITheme.GOLD)
	var hd := HBoxContainer.new(); hd.alignment = BoxContainer.ALIGNMENT_CENTER; hd.add_theme_constant_override("separation", 8)
	hd.add_child(_icon("ic_daily", 30)); hd.add_child(_lbl("Recompensa Diária", 30, UITheme.GOLD)); box.add_child(hd)
	var streak_info := _lbl(tr("Streak: %d dias consecutivos!") % Daily.streak, 19, UITheme.INK)
	streak_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(streak_info)

	var grid := GridContainer.new(); grid.columns = 7
	grid.add_theme_constant_override("h_separation", 5); grid.add_theme_constant_override("v_separation", 5); box.add_child(grid)
	var cur_idx := (Daily.streak - 1) % Daily.REWARDS.size()
	for i in Daily.REWARDS.size():
		var day_box := PanelContainer.new()
		day_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var claimed := (i < cur_idx)
		var current := (i == cur_idx) and Daily.pending
		day_box.add_theme_stylebox_override("panel", UITheme.daily_card(claimed, current))
		var dv := VBoxContainer.new(); dv.add_theme_constant_override("separation", 3); day_box.add_child(dv)
		var dl := _lbl("D%d" % (i+1), 12, UITheme.MUTED if not current else UITheme.GOLD)
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; dv.add_child(dl)
		var cd := _daily_compact(Daily.REWARDS[i])
		var ic := _icon(cd[0], 20); ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; dv.add_child(ic)
		var rl := _lbl(cd[1], 12, UITheme.INK if not claimed else UITheme.GREEN)
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; dv.add_child(rl)
		if claimed:
			var ck := _icon("ic_check", 15); ck.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; dv.add_child(ck)
		if current:
			Fx.breathe(day_box, true)
		grid.add_child(day_box)

	if Daily.pending:
		var claim_btn := _wide_btn(UITheme.GOLD.darkened(0.06))
		claim_btn.text = "Receber Recompensa!"
		claim_btn.add_theme_color_override("font_color", Color(0.12, 0.08, 0.0))
		claim_btn.pressed.connect(func():
			Fx.press(claim_btn)
			var from := claim_btn.get_global_rect().get_center()
			Daily.claim(); _disp_credits = GameState.credits
			Fx.coin_fountain(self, from, _credits_chip.get_global_rect().get_center(), 10)
			Fx.chip_pop(_gems_chip, UITheme.CYAN)
			layer.queue_free()
		)
		box.add_child(claim_btn)
	var close := _close_btn(layer); box.add_child(close)

## Reward choice after tapping the golden bonus drone: small free reward now,
## or watch a rewarded ad for the (randomized-at-spawn) big reward.
func _show_bonus_popup(ad_reward: Dictionary) -> void:
	Audio.play("unlock")
	var layer := _overlay(); var box := _popup_box(layer, UITheme.GOLD)
	var hd := HBoxContainer.new(); hd.alignment = BoxContainer.ALIGNMENT_CENTER; hd.add_theme_constant_override("separation", 8)
	hd.add_child(_icon("ic_drone", 30)); hd.add_child(_lbl("Drone Bónus!", 30, UITheme.GOLD)); box.add_child(hd)
	var info := _lbl("Apanhaste um drone de carga dourado.\nEscolhe a tua recompensa:", 18, UITheme.MUTED)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(info)

	var free_btn := _wide_btn(UITheme.PANEL2)
	free_btn.text = tr("Receber: +3 min de lucros")
	free_btn.custom_minimum_size = Vector2(0, 64)
	free_btn.pressed.connect(func():
		GameState.grant_cash_minutes(3.0)
		_disp_credits = GameState.credits
		Fx.chip_pop(_credits_chip, UITheme.GOLD)
		_toast(tr("+3 min de lucros!"), UITheme.GREEN, "ic_cash")
		layer.queue_free()
	)
	box.add_child(free_btn)

	var kind: String = str(ad_reward.get("kind", "cash"))
	var ad_btn := _wide_btn(UITheme.GREEN)
	ad_btn.text = tr(str(ad_reward.get("label", "")))
	ad_btn.icon = _opt_tex("ic_ad"); ad_btn.expand_icon = true
	ad_btn.add_theme_constant_override("icon_max_width", 24)
	ad_btn.custom_minimum_size = Vector2(0, 70)
	ad_btn.pressed.connect(func():
		layer.queue_free()
		Ads.show_rewarded("bonus_drone", func():
			match kind:
				"boost":
					GameState.earn_boost_timer = 600.0
					_toast(tr("Lucros ×2 durante 10 min!"), UITheme.GREEN, "ic_boost")
				"gems":
					GameState.grant_gems(40)
					_toast(tr("+40 Gemas!"), UITheme.CYAN, "ic_gems")
				_:
					GameState.grant_cash_minutes(20.0)
					_disp_credits = GameState.credits
					Fx.chip_pop(_credits_chip, UITheme.GOLD)
					_toast(tr("+20 min de lucros!"), UITheme.GREEN, "ic_cash")
		)
	)
	box.add_child(ad_btn)
	Fx.shimmer(ad_btn, UITheme.GREEN, true)

func _show_prestige_confirm() -> void:
	var layer := _overlay(); var box := _popup_box(layer, UITheme.PRESTIGE)
	var hd := HBoxContainer.new(); hd.alignment = BoxContainer.ALIGNMENT_CENTER; hd.add_theme_constant_override("separation", 8)
	hd.add_child(_icon("ic_prestige", 28)); hd.add_child(_lbl("Confirmar Prestige", 28, UITheme.PRESTIGE)); box.add_child(hd)
	var gain := Prestige.pgems_on_next_prestige()
	var info := _lbl(tr("Vais ganhar  %d  Gemas Prestige\ne um multiplicador ×%.2f permanente.\n\nPerdes créditos, drones e upgrades.\nMantens gemas normais e conquistas.") % [gain, Prestige.permanent_mult * 1.15], 18, UITheme.MUTED)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(info)
	var confirm := Button.new(); confirm.text = "SIM, FAZER PRESTIGE"
	confirm.add_theme_font_size_override("font_size", 22); confirm.custom_minimum_size = Vector2(0, 68)
	confirm.add_theme_stylebox_override("normal", UITheme.prestige_btn_ready())
	confirm.add_theme_stylebox_override("focus",  StyleBoxEmpty.new())
	confirm.pressed.connect(func():
		layer.queue_free()
		Fx.prestige_ceremony(self, func(): Prestige.do_prestige())
	)
	box.add_child(confirm)
	var cancel := Button.new(); cancel.text = "Cancelar"; cancel.add_theme_font_size_override("font_size", 22)
	cancel.custom_minimum_size = Vector2(0, 62); cancel.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	cancel.pressed.connect(func(): layer.queue_free()); box.add_child(cancel)

## Big, unmistakable settings toggle: the whole row is tappable and shows a
## large track+knob switch (green ON / grey OFF) that slides on change. Replaces
## the tiny default CheckButton switch the user disliked. Signature unchanged:
## (label, initial state, callback(on)).
func _settings_toggle(text: String, pressed: bool, cb: Callable) -> Control:
	var row := Button.new()
	row.toggle_mode = true
	row.button_pressed = pressed
	row.custom_minimum_size = Vector2(0, 92)
	var rowsb := UITheme.solid(UITheme.PANEL, 16)
	row.add_theme_stylebox_override("normal",  rowsb)
	row.add_theme_stylebox_override("hover",   rowsb)
	row.add_theme_stylebox_override("pressed", rowsb)
	row.add_theme_stylebox_override("focus",   StyleBoxEmpty.new())

	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 20; h.offset_right = -20
	h.add_theme_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(h)

	var lbl := _lbl(text, 26, UITheme.INK)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(lbl)

	var pill := Panel.new()
	pill.custom_minimum_size = Vector2(104, 56)
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(pill)
	var knob := Panel.new()
	knob.size = Vector2(46, 46)
	knob.position = Vector2(52, 5) if pressed else Vector2(5, 5)
	knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var kb := StyleBoxFlat.new(); kb.bg_color = Color.WHITE; kb.set_corner_radius_all(23)
	knob.add_theme_stylebox_override("panel", kb)
	pill.add_child(knob)

	var paint_track := func(on: bool) -> void:
		var track := StyleBoxFlat.new()
		track.bg_color = UITheme.GREEN if on else UITheme.PANEL2
		track.set_corner_radius_all(28)
		pill.add_theme_stylebox_override("panel", track)
	paint_track.call(pressed)

	row.toggled.connect(func(on: bool) -> void:
		paint_track.call(on)
		if Fx.reduce_motion:
			knob.position.x = 52.0 if on else 5.0
		else:
			var tw := knob.create_tween()
			tw.tween_property(knob, "position:x", 52.0 if on else 5.0, 0.16) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Fx.press(row)
		Audio.play("tap")
		cb.call(on)
	)
	return row

func _set_language(l: String) -> void:
	if Fx.locale == l:
		return   # already explicitly on this language
	Fx.set_locale(l)
	SaveSystem.save_game()
	Fx.skip_boot = true            # skip the branded intro on a language reload
	get_tree().reload_current_scene()   # rebuild EVERY label fresh in the new locale

func _settings_stats_text() -> String:
	return tr("Entregas: %s  ·  Ganhos: %s\nRendimento: %s/s  ·  Combo: %d\nDrones: %d  ·  Países: %d/%d  ·  Streak: %dd\nPrestige: %d  ·  Conquistas: %d/%d") % [
		Fmt.short(float(GameState.total_deliveries)), Fmt.short(GameState.total_earned),
		Fmt.short(GameState.income_per_sec()), GameState.combo,
		GameState.drones, GameState.current_country + 1, Economy.num_countries(), Daily.streak,
		Prestige.count, Achievements.done_count(), Achievements.total_count()]

func _show_settings() -> void:
	var layer := _overlay(); var box := _popup_box(layer, UITheme.ACCENT)
	var hd := HBoxContainer.new(); hd.alignment = BoxContainer.ALIGNMENT_CENTER; hd.add_theme_constant_override("separation", 10)
	hd.add_child(_icon("ic_gear", 38)); hd.add_child(_lbl("Definições", 32, UITheme.INK)); box.add_child(hd)

	box.add_child(_settings_toggle("Som activado", not Audio.muted,
		func(on): Audio.muted = not on; SaveSystem.save_game()))
	box.add_child(_settings_toggle("Vibração", Fx.haptics,
		func(on): Fx.haptics = on; SaveSystem.save_game()))
	box.add_child(_settings_toggle("Reduzir animações", Fx.reduce_motion,
		func(on): Fx.set_reduce_motion(on); SaveSystem.save_game()))

	var lang_row := HBoxContainer.new(); lang_row.add_theme_constant_override("separation", 6)
	box.add_child(lang_row)
	var lang_lbl := _lbl("Idioma / Language", 22, UITheme.INK)
	lang_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; lang_row.add_child(lang_lbl)
	var eff_locale := Fx.locale if Fx.locale != "" else TranslationServer.get_locale()
	var pt_btn := Button.new(); pt_btn.text = "PT"; pt_btn.custom_minimum_size = Vector2(64, 56)
	var en_btn := Button.new(); en_btn.text = "EN"; en_btn.custom_minimum_size = Vector2(64, 56)
	pt_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	en_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var refresh_lang_btns := func():
		var is_pt := not eff_locale.begins_with("en")
		pt_btn.add_theme_stylebox_override("normal", UITheme.seg(is_pt))
		pt_btn.add_theme_stylebox_override("hover", UITheme.seg(is_pt))
		en_btn.add_theme_stylebox_override("normal", UITheme.seg(not is_pt))
		en_btn.add_theme_stylebox_override("hover", UITheme.seg(not is_pt))
	refresh_lang_btns.call()
	pt_btn.pressed.connect(func(): Fx.press(pt_btn); _set_language("pt"))
	en_btn.pressed.connect(func(): Fx.press(en_btn); _set_language("en"))
	lang_row.add_child(pt_btn); lang_row.add_child(en_btn)

	var rule := Panel.new(); rule.custom_minimum_size = Vector2(0, 2)
	rule.add_theme_stylebox_override("panel", UITheme.section_rule()); box.add_child(rule)

	var stats_card := PanelContainer.new()
	stats_card.add_theme_stylebox_override("panel", UITheme.solid(UITheme.PANEL, 14))
	box.add_child(stats_card)
	var stats := _lbl(_settings_stats_text(), 17, UITheme.MUTED)
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_card.add_child(stats)
	_settings_stats_lbl = stats

	var attr := _lbl("Música: Eric Matyas · soundimage.org", 14, UITheme.MUTED)
	attr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(attr)

	var restore := _wide_btn(UITheme.ACCENT); restore.text = "Restaurar compras"
	restore.custom_minimum_size = Vector2(0, 84)
	restore.add_theme_font_size_override("font_size", 26)
	restore.pressed.connect(func():
		Fx.press(restore)
		if Billing.restore():
			_toast("A verificar compras na Google Play...", UITheme.ACCENT)
		else:
			_toast("Disponível apenas na versão Android.", UITheme.MUTED)
		SaveSystem.save_game()
	)
	box.add_child(restore)

	var ver := _lbl("Drone Tycoon: Sky Fleet · v1.17.0 · © 2026 LPCF", 15, UITheme.MUTED)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ver.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(ver)

	var reset := Button.new(); reset.text = "Repor progresso"
	reset.add_theme_font_size_override("font_size", 20)
	reset.add_theme_color_override("font_color", UITheme.RED)
	reset.custom_minimum_size = Vector2(0, 56)
	reset.add_theme_stylebox_override("normal", UITheme.danger_outline())
	reset.add_theme_stylebox_override("focus",  StyleBoxEmpty.new())
	reset.pressed.connect(func(): Fx.press(reset); _show_reset_confirm())
	box.add_child(reset)

	box.add_child(_close_btn(layer))

func _show_reset_confirm() -> void:
	var layer := _overlay(); var box := _popup_box(layer, UITheme.RED)
	var hd := _lbl("Repor progresso?", 28, UITheme.RED)
	hd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hd.size_flags_horizontal = Control.SIZE_EXPAND_FILL; box.add_child(hd)
	var warn := _lbl("Apaga TODO o progresso: créditos, drones, países, prestige e conquistas.\nNão pode ser desfeito.", 18, UITheme.MUTED)
	warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(warn)
	var confirm := Button.new(); confirm.text = "SIM, APAGAR TUDO"
	confirm.add_theme_font_size_override("font_size", 22); confirm.custom_minimum_size = Vector2(0, 66)
	confirm.add_theme_stylebox_override("normal", UITheme.danger_btn())
	confirm.add_theme_stylebox_override("focus",  StyleBoxEmpty.new())
	confirm.pressed.connect(func(): SaveSystem.wipe(); get_tree().reload_current_scene())
	box.add_child(confirm)
	var cancel := Button.new(); cancel.text = "Cancelar"; cancel.add_theme_font_size_override("font_size", 22)
	cancel.custom_minimum_size = Vector2(0, 62); cancel.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	cancel.pressed.connect(func(): layer.queue_free()); box.add_child(cancel)

func _show_offline_popup(amount: float, seconds: float) -> void:
	var layer := _overlay(); var box := _popup_box(layer, UITheme.ACCENT)
	box.add_child(_lbl("Bem-vindo de volta!", 30, UITheme.INK))
	var m := _lbl(tr("Os drones entregaram durante %s:") % Fmt.duration(seconds), 19, UITheme.MUTED)
	m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(m)
	var big := _lbl(Fmt.short(amount), 40, UITheme.GOLD)
	big.add_theme_font_override("font", UITheme.font("Bold"))
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(big)
	if not Fx.reduce_motion:
		var ctw := create_tween()
		# guard: a player who taps "Recolher" before the 0.9s count-up finishes
		# frees `big` (and the whole popup) while this tween is still stepping it
		var _set_big_text := func(v: float) -> void:
			if is_instance_valid(big):
				big.text = Fmt.short(v)
		ctw.tween_method(_set_big_text, 0.0, amount, 0.9) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var collect := Button.new(); collect.text = "Recolher"
	collect.add_theme_font_size_override("font_size", 24); collect.custom_minimum_size = Vector2(0, 70)
	collect.add_theme_stylebox_override("normal", UITheme.action_btn(UITheme.GREEN))
	collect.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	collect.pressed.connect(func():
		GameState.collect_offline(1.0)
		_disp_credits = GameState.credits
		Fx.coin_fountain(self, collect.get_global_rect().get_center(), _credits_chip.get_global_rect().get_center(), 12)
		Fx.chip_pop(_credits_chip, UITheme.GOLD)
		Audio.play("milestone")
		layer.queue_free()
		if Daily.pending:
			_show_daily_popup()
	)
	box.add_child(collect)
	var dbl := Button.new(); dbl.text = "Recolher em DOBRO (anúncio)"
	dbl.icon = _opt_tex("ic_ad"); dbl.expand_icon = true; dbl.add_theme_constant_override("icon_max_width", 24)
	dbl.add_theme_font_size_override("font_size", 19); dbl.custom_minimum_size = Vector2(0, 66)
	dbl.add_theme_stylebox_override("normal", UITheme.solid(UITheme.GREEN, 16))
	dbl.add_theme_stylebox_override("focus",  StyleBoxEmpty.new())
	dbl.pressed.connect(func():
		layer.queue_free()
		Ads.show_rewarded("offline2x", func():
			GameState.collect_offline(2.0)
			_disp_credits = GameState.credits
			Fx.coin_fountain(self, Vector2(size.x * 0.5, size.y * 0.5), _credits_chip.get_global_rect().get_center(), 12)
			Fx.chip_pop(_credits_chip, UITheme.GOLD)
			Audio.play("milestone")
			if Daily.pending:
				_show_daily_popup()
		)
	)
	box.add_child(dbl)
	Fx.shimmer(dbl, UITheme.GREEN, true)

func _overlay() -> CanvasLayer:
	var layer := CanvasLayer.new(); layer.layer = 150
	var dim := ColorRect.new(); dim.color = Color(0.02, 0.03, 0.07, 0.0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim); add_child(layer)
	var tw := create_tween()
	tw.tween_property(dim, "color:a", 0.78, 0.2)
	return layer

func _popup_box(layer: CanvasLayer, accent := UITheme.ACCENT) -> VBoxContainer:
	# ScrollContainer anchored to a tall region with screen-edge margins, so the
	# popup always has a real (non-zero) height and scrolls if taller than screen.
	var sc := ScrollContainer.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.offset_left = 30; sc.offset_right = -30
	sc.offset_top = 64; sc.offset_bottom = -64
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layer.add_child(sc)
	# Center the panel vertically when the content is shorter than the viewport.
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.custom_minimum_size = Vector2(0, 1)
	sc.add_child(col)
	var pc := PanelContainer.new(); pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.add_theme_stylebox_override("panel", UITheme.popup_frame(accent)); col.add_child(pc)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 14); pc.add_child(box)
	# fade + tiny spring-in (modulate always ends at 1, even with reduce_motion)
	pc.modulate = Color(1, 1, 1, 0)
	if Fx.reduce_motion:
		pc.modulate = Color.WHITE
	else:
		pc.pivot_offset = Vector2(330, 90); pc.scale = Vector2(0.96, 0.96)
		var tw := pc.create_tween(); tw.set_parallel(true)
		tw.tween_property(pc, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(pc, "modulate:a", 1.0, 0.18)
	return box

func _close_btn(layer: CanvasLayer) -> Button:
	var close := Button.new(); close.text = "Fechar"; close.add_theme_font_size_override("font_size", 30)
	close.custom_minimum_size = Vector2(0, 84); close.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	close.pressed.connect(func(): Fx.press(close); layer.queue_free())
	return close

# ── Primitives ───────────────────────────────────────────────────────────────────

func _lbl(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new(); l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color); return l

func _icon(n: String, sz := 30) -> TextureRect:
	var r := TextureRect.new(); r.texture = _opt_tex(n); r.custom_minimum_size = Vector2(sz, sz)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; return r

func _opt_tex(n: String) -> Texture2D:
	var path := ART + n + ".png"
	if ResourceLoader.exists(path):
		return load(path)
	return null

# ── Floating delivery earnings ────────────────────────────────────────────────────

func _on_delivered(amount: float, _city_idx: int) -> void:
	_deliver_throttle += 1
	var n := maxi(1, GameState.drones / 4)
	if _deliver_throttle % n != 0: return
	var cx := size.x * 0.5 + randf_range(-80, 80)
	var cy := size.y * 0.42 + randf_range(-50, 50)
	Fx.floating_label(self, "+" + Fmt.short(amount * n), Fx.GOLD, Vector2(cx, cy), 26)
	# every ~8th shown delivery, fly coins into the credits chip (it never
	# animated before — the core earn beat now lands on the HUD)
	_fountain_counter += 1
	if _fountain_counter % 8 == 0:
		Fx.coin_fountain(self, Vector2(cx, cy), _credits_chip.get_global_rect().get_center(), 6)
		Fx.chip_pop(_credits_chip, UITheme.GOLD)

# ── Contract signal handlers ──────────────────────────────────────────────────────

func _on_contract_completed(_slot: int) -> void:
	_toast("Missão concluída! Recompensa recebida", UITheme.CYAN, "ic_achieve")
	Fx.confetti(self, Vector2(size.x * 0.5, size.y * 0.45), 30, [UITheme.CYAN, UITheme.GREEN, UITheme.GOLD])
	Fx.screen_flash(self, UITheme.CYAN, 0.10)
	Audio.play("milestone")

# ── Income milestone celebration ──────────────────────────────────────────────────

func _check_income_milestones() -> void:
	var ips := GameState.income_per_sec()
	while _income_milestone_idx < INCOME_MILESTONES.size() and ips >= float(INCOME_MILESTONES[_income_milestone_idx]):
		var lbl: String = str(MILESTONE_LABELS[_income_milestone_idx])
		_toast(tr("Nova marca: %s/s!") % lbl, UITheme.GREEN, "ic_fleet")
		var c := Vector2(size.x * 0.5, size.y * 0.43)
		Fx.confetti(self, c, 36, [UITheme.GREEN, UITheme.GOLD, UITheme.CYAN])
		Fx.screen_flash(self, UITheme.GREEN, 0.12)
		Fx.ring_pulse(self, c, UITheme.GREEN, 2.6)
		_income_milestone_idx += 1

# ── Contract card UI updates ──────────────────────────────────────────────────────

func _update_contracts() -> void:
	for i in range(Contracts.SLOT_COUNT):
		if i >= _mission_title_lbls.size(): break
		var s: Dictionary = Contracts.slots[i] if i < Contracts.slots.size() else {}
		(_mission_title_lbls[i] as Label).text = str(s.get("label", ""))
		_set_fill(_mission_prog_bars[i] as Panel, Contracts.progress_pct(i))
		var tgt := float(s.get("target", 1.0))
		var prg := minf(float(s.get("progress", 0.0)), tgt)
		(_mission_prog_lbls[i] as Label).text = Fmt.short(prg) + "/" + Fmt.short(tgt)
		var rem := Contracts.time_remaining(i)
		var t_lbl := _mission_time_lbls[i] as Label
		if s.get("claimed", false):
			t_lbl.text = tr("Nova em %ds") % int(rem)
		elif i == 3:
			t_lbl.text = "%dd %dh" % [int(rem) / 86400, (int(rem) % 86400) / 3600]
		else:
			t_lbl.text = "%d:%02d" % [int(rem) / 60, int(rem) % 60]
		var ready: bool = s.get("ready", false) and not s.get("claimed", false)
		var cbtn := _mission_claim_btns[i] as Button
		cbtn.disabled = not ready
		if ready:
			cbtn.text = "REIVINDICAR"; cbtn.icon = null
		elif s.get("claimed", false):
			cbtn.text = "Recebido"; cbtn.icon = _opt_tex("ic_check")
		else:
			cbtn.text = "Em curso"; cbtn.icon = null
		_afford(cbtn, ready)
		if i < _mission_x2_btns.size():
			(_mission_x2_btns[i] as Button).visible = ready
		if i < _mission_reroll_btns.size():
			(_mission_reroll_btns[i] as Button).visible = (i < 3) and not ready and not s.get("claimed", false)
		var rc: float = float(s.get("reward_credits", 0.0))
		var rg: int = int(s.get("reward_gems", 0))
		(_mission_reward_lbls[i] as Label).text = "+" + Fmt.short(rc)
		if i < _mission_gem_lbls.size():
			(_mission_gem_icons[i] as TextureRect).visible = rg > 0
			var gl := _mission_gem_lbls[i] as Label
			gl.visible = rg > 0
			gl.text = "+%d" % rg

# ── Missions tab ──────────────────────────────────────────────────────────────────

func _build_missions_tab() -> ScrollContainer:
	var r := _scroll("Missões"); var v: VBoxContainer = r[1]
	var info := _lbl("Completa missões para ganhar créditos e gemas bónus.", 16, UITheme.MUTED)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.add_child(info)

	for i in range(Contracts.SLOT_COUNT):
		if i == 3:
			v.add_child(_section("Desafio Semanal", UITheme.GOLD, "ic_achieve"))
		var slot_color: Color = UITheme.GOLD if i == 3 else UITheme.CYAN
		var s: Dictionary = Contracts.slots[i] if i < Contracts.slots.size() else {}
		var card := _card(slot_color); v.add_child(card)
		var cv := VBoxContainer.new(); cv.add_theme_constant_override("separation", 8); card.add_child(cv)

		# Top row: title + time remaining
		var top := HBoxContainer.new(); top.add_theme_constant_override("separation", 6); cv.add_child(top)
		var title := _lbl(str(s.get("label", "")), 18, UITheme.INK)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; top.add_child(title)
		_mission_title_lbls.append(title)
		var time_lbl := _lbl("--:--", 15, UITheme.MUTED); top.add_child(time_lbl)
		_mission_time_lbls.append(time_lbl)

		# rewarded-ad reroll (rotating slots only; weekly is fixed)
		var ri := i
		var rbtn := Button.new(); rbtn.text = "Trocar"
		rbtn.icon = _opt_tex("ic_ad"); rbtn.expand_icon = true
		rbtn.add_theme_constant_override("icon_max_width", 20)
		rbtn.add_theme_font_size_override("font_size", 14)
		rbtn.custom_minimum_size = Vector2(96, 44)
		rbtn.add_theme_stylebox_override("normal", UITheme.solid(UITheme.PANEL2, 12))
		rbtn.add_theme_stylebox_override("focus",  StyleBoxEmpty.new())
		rbtn.visible = (i < 3)
		rbtn.pressed.connect(func():
			if not _can_tap(): return
			Fx.press(rbtn)
			Ads.show_rewarded("reroll", func():
				if Contracts.reroll(ri):
					_toast("Missão substituída!", UITheme.CYAN, "ic_achieve"))
		)
		top.add_child(rbtn)
		_mission_reroll_btns.append(rbtn)

		# Progress bar
		var pb_bg := Panel.new(); pb_bg.custom_minimum_size = Vector2(0, 8)
		pb_bg.add_theme_stylebox_override("panel", UITheme.prog_bg()); cv.add_child(pb_bg)
		var pb_fill := Panel.new(); pb_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
		pb_fill.anchor_right = 0.0
		pb_fill.add_theme_stylebox_override("panel", UITheme.prog_fill(slot_color))
		pb_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE; pb_bg.add_child(pb_fill)
		_mission_prog_bars.append(pb_fill)

		# Bottom row: progress text + reward label + claim button
		var bot := HBoxContainer.new(); bot.add_theme_constant_override("separation", 6); cv.add_child(bot)
		var prog_lbl := _lbl("0/0", 15, UITheme.MUTED)
		prog_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; bot.add_child(prog_lbl)
		_mission_prog_lbls.append(prog_lbl)

		var rc: float = float(s.get("reward_credits", 0.0))
		var rg: int = int(s.get("reward_gems", 0))
		var rew_lbl := _lbl("+" + Fmt.short(rc), 15, UITheme.GREEN); bot.add_child(rew_lbl)
		_mission_reward_lbls.append(rew_lbl)
		var gic := _icon("ic_gems", 16); gic.visible = rg > 0; bot.add_child(gic)
		_mission_gem_icons.append(gic)
		var gem_lbl := _lbl("+%d" % rg, 15, UITheme.CYAN); gem_lbl.visible = rg > 0; bot.add_child(gem_lbl)
		_mission_gem_lbls.append(gem_lbl)

		var ci := i
		var cbtn := _buy_btn(slot_color.darkened(0.18))
		cbtn.text = "Em curso"; cbtn.disabled = true
		cbtn.expand_icon = true
		cbtn.add_theme_constant_override("icon_max_width", 20)
		cbtn.size_flags_horizontal = Control.SIZE_SHRINK_END
		cbtn.custom_minimum_size = Vector2(130, 52)
		cbtn.add_theme_font_size_override("font_size", 16)
		cbtn.pressed.connect(func():
			if not _can_tap(): return
			Fx.press(cbtn)
			if Contracts.claim(ci):
				Audio.play("buy")
				Fx.chip_pop(_credits_chip, UITheme.GOLD)
		)
		bot.add_child(cbtn)
		_mission_claim_btns.append(cbtn)

		# double reward via rewarded ad
		var xbtn := _buy_btn(UITheme.GREEN_D)
		xbtn.text = "2×"
		xbtn.icon = _opt_tex("ic_ad"); xbtn.expand_icon = true
		xbtn.add_theme_constant_override("icon_max_width", 20)
		xbtn.size_flags_horizontal = Control.SIZE_SHRINK_END
		xbtn.custom_minimum_size = Vector2(84, 52)
		xbtn.add_theme_font_size_override("font_size", 16)
		xbtn.visible = false
		xbtn.pressed.connect(func():
			if not _can_tap(): return
			Fx.press(xbtn)
			Ads.show_rewarded("mission2x", func():
				if Contracts.claim(ci, 2.0):
					Audio.play("milestone")
					Fx.chip_pop(_credits_chip, UITheme.GOLD)
					_toast("Recompensa a DOBRAR!", UITheme.GREEN, "ic_achieve"))
		)
		bot.add_child(xbtn)
		_mission_x2_btns.append(xbtn)

	return r[0]
