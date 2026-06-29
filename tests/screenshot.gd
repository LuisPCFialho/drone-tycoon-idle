extends Node
## Visual smoke test: loads Main, lets it run, captures a screenshot, quits.

func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().create_timer(2.5).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png("C:/Apps/DroneTycoon/export/preview.png")
	print("SHOT_SAVED")
	get_tree().quit()
