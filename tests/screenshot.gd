extends Node
## Visual smoke test: captures the Frota, Talentos and Loja tabs.

func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().create_timer(1.5).timeout
	var tabs := main.find_children("", "TabContainer", true, false)
	var tc: TabContainer = tabs[0] if tabs.size() > 0 else null
	await _shot("export/preview.png")
	if tc:
		tc.current_tab = 1  # Cidades
		await _shot("export/preview_cities.png")
		tc.current_tab = 3  # Loja
		await _shot("export/preview_shop.png")
	print("SHOT_SAVED")
	get_tree().quit()

func _shot(path: String) -> void:
	await get_tree().create_timer(0.4).timeout
	get_viewport().get_texture().get_image().save_png("C:/Apps/DroneTycoon/" + path)
