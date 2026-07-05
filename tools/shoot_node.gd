extends Node
## Dev-only screenshot harness. Temporarily registered as autoload "DevShoot"
## (added/removed from project.godot by the capture task — never shipped).
## Captures per-tab screenshots of the REAL running game to export/shots/.

var _frame := 0

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://export/shots"))
	DisplayServer.window_set_size(Vector2i(540, 960))

func _process(_delta: float) -> void:
	_frame += 1
	var main := get_tree().current_scene
	if main == null:
		return
	# Boot intro's own tween chain (drone fly-through, HUD cascade) runs for
	# up to ~1.5s (~90 frames) and frees ITS OWN CanvasLayer when done, then
	# _post_boot() may open the daily-reward popup. Do not force-free any
	# overlay before that settles — doing so mid-tween kills nodes a queued
	# Tweener still references ("lambda capture was freed" engine error).
	match _frame:
		150:
			_close_overlays(main)   # closes the daily-reward popup, if any
			_shot("shot_0_fleet.png")
			main.call("_switch_tab", 1)
		165:
			_shot("shot_1_cities.png")
			main.call("_switch_tab", 2)
		180:
			_shot("shot_2_talents.png")
			main.call("_switch_tab", 3)
		195:
			_shot("shot_3_legado.png")
			main.call("_switch_tab", 4)
		210:
			_shot("shot_4_shop.png")
		255:
			var pg: ScrollContainer = main.get("_pages")[4]
			var vb := pg.get_child(0)
			pg.scroll_vertical = int(vb.size.y)
		265:
			_shot("shot_4b_shop_iap.png")
			main.call("_switch_tab", 5)
		280:
			_shot("shot_5_missions.png")   # nav bar: check Missions icon present
			# switch language to EN in-place (no reload) and verify live retranslate
			main.call("_set_language", "en")
		300:
			main.call("_switch_tab", 0)
		315:
			_shot("shot_5b_fleet_en.png")   # tabs must be English + no crash
			main.call("_switch_tab", 5)
		330:
			_shot("shot_5c_missions_en.png")
			main.call("_switch_tab", 0)
			main.call("_set_language", "pt")   # back to PT for the rest
		345:
			main.call("_show_settings")
		370:
			_shot("shot_6_settings.png")
		# Simulate REAL taps on the PT/EN buttons inside the still-open Settings
		# popup — the reported bug was the highlight not moving after a tap
		# (stale captured locale var), which only reproduces via the actual
		# button callback, not by calling _set_language() directly.
		375:
			var en_btn := _find_button_by_text(_topmost_overlay(main), "EN")
			if en_btn != null: en_btn.pressed.emit()
		390:
			_shot("shot_6b_settings_en.png")   # highlight must be on EN now
		392:
			var pt_btn := _find_button_by_text(_topmost_overlay(main), "PT")
			if pt_btn != null: pt_btn.pressed.emit()
		407:
			_shot("shot_6c_settings_pt.png")   # highlight back on PT
		# Reset Progress end-to-end via real button taps — this used to crash
		# the app (reload_current_scene() mid-callback on Android).
		410:
			var reset_btn := _find_button_by_text(_topmost_overlay(main), "Repor progresso")
			if reset_btn != null: reset_btn.pressed.emit()
		425:
			var confirm_btn := _find_button_by_text(_topmost_overlay(main), "SIM, APAGAR TUDO")
			if confirm_btn != null: confirm_btn.pressed.emit()
		440:
			_shot("shot_6d_after_reset.png")   # must show Fleet, no crash, credits ~0
			_close_overlays(main)
			main.call("_switch_tab", 4)
		450:
			var pg2: ScrollContainer = main.get("_pages")[4]
			var vb2 := pg2.get_child(0)
			pg2.scroll_vertical = int(vb2.size.y * 0.45)
		540:
			# late shot: the tab's stagger-in fade (0.04s/row) needs ~1.8s to
			# reveal mid-list rows, so shooting right after the scroll is blank
			_shot("shot_7_shop_skins.png")
			main.call("_switch_tab", 0)
			var bonus: Node = main.get("_bonus")
			bonus.set("_wait", 0.0)     # force golden bonus drone to spawn now
		570:
			var bonus2: Node = main.get("_bonus")
			bonus2.set("_t", 0.45)      # park it mid-screen for the shot
		572:
			_shot("shot_8_bonus_drone.png")
			(main.get("_bonus") as Node).call("_on_tapped")
		605:
			_shot("shot_9_bonus_popup.png")
			get_tree().quit()

func _find_button_by_text(node: Node, text: String) -> Button:
	if node == null:
		return null
	if node is Button and (node as Button).text == text:
		return node
	for c in node.get_children():
		var r := _find_button_by_text(c, text)
		if r != null:
			return r
	return null

## Topmost open CanvasLayer overlay directly under main (last one added).
func _topmost_overlay(main: Node) -> CanvasLayer:
	var found: CanvasLayer = null
	for c in main.get_children():
		if c is CanvasLayer:
			found = c
	return found

## Frees any open CanvasLayer overlay (daily popup, toasts, offline popup...).
## Only ever called once boot intro has fully settled (see comment above).
func _close_overlays(main: Node) -> void:
	for c in main.get_children():
		if c is CanvasLayer:
			c.queue_free()

func _shot(fname: String) -> void:
	var img := get_viewport().get_texture().get_image()
	if img != null:
		img.save_png("res://export/shots/" + fname)
