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
	match _frame:
		40:
			for c in main.get_children():
				if c is CanvasLayer:
					c.queue_free()
		80:
			_shot("shot_0_fleet.png")
			main.call("_switch_tab", 1)
		100:
			_shot("shot_1_cities.png")
			main.call("_switch_tab", 2)
		120:
			_shot("shot_2_talents.png")
			main.call("_switch_tab", 3)
		140:
			_shot("shot_3_legado.png")
			main.call("_switch_tab", 4)
		160:
			_shot("shot_4_shop.png")
			main.call("_switch_tab", 5)
		180:
			_shot("shot_5_missions.png")
			main.call("_switch_tab", 0)
		200:
			main.call("_show_settings")
		240:
			_shot("shot_6_settings.png")
			get_tree().quit()

func _shot(fname: String) -> void:
	var img := get_viewport().get_texture().get_image()
	if img != null:
		img.save_png("res://export/shots/" + fname)
