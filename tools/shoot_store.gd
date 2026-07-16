extends Node
## Dev-only STORE screenshot harness. Temporarily registered as autoload
## "DevShoot" (added/removed from project.godot by the capture task — never
## shipped). Captures Play Store listing shots of the REAL running game at
## 1080x1920 (Play's recommended portrait size) to export/store/.
##
## Differs from shoot_node.gd (the QA harness): higher resolution, no language
## switching / reset flows, and it seeds a mid-game state first so the shots
## show the game as an actual player sees it after a session rather than an
## empty first-launch screen. Everything rendered is the real UI — nothing here
## fabricates content that the game cannot produce.

var _frame := 0

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://export/store"))
	DisplayServer.window_set_size(Vector2i(1080, 1920))

## A plausible mid-game save: a few countries in, fleet built out, upgrades
## bought. These are the same values normal play produces.
func _seed_state() -> void:
	GameState.credits = 4.82e6
	GameState.gems = 340
	GameState.drones = 8   # 14 bunched up over the capital and stacked floating
	                       # labels on top of the city names — 8 still reads busy
	                       # without the map turning to soup
	GameState.levels = {"speed": 11, "cargo": 9, "value": 12, "routes": 6}
	GameState.talents = {"global": 4, "speed": 3, "value": 3, "hangar": 2}
	GameState.current_country = 2
	GameState.cities_unlocked = 5
	GameState.influence = 26
	GameState.influence_total = 41
	GameState.total_earned = 9.4e7
	GameState.total_deliveries = 5820
	GameState.skins_owned = ["classic", "amber", "teal"]
	GameState.skin_active = "teal"
	# Setting current_country directly leaves the map (self-heals via its own
	# bbox check) and the city list (rebuilt only on the signal) disagreeing —
	# emit so every listener rebuilds against the seeded country.
	GameState.country_changed.emit(GameState.current_country)

func _process(_delta: float) -> void:
	_frame += 1
	var main := get_tree().current_scene
	if main == null:
		return
	# Boot intro tweens free their own CanvasLayer (~90 frames); never touch
	# overlays before that settles or queued Tweeners reference freed nodes.
	match _frame:
		# _post_boot() opens the offline/daily popup AFTER the intro settles, so
		# closing earlier than this just lets it reopen over every shot.
		140:
			GameState.pending_offline = 0.0
			GameState.pending_offline_seconds = 0.0
			_close_overlays(main)
		150:
			_seed_state()
			main.call("_set_language", "en")   # store listing shots are English
		160:
			_close_overlays(main)   # safety: catches any popup opened by the seed
			main.call("_switch_tab", 0)
		# Seeding credits trips the milestone toast ("New record: 1K/s!"), whose
		# banner covers the map. Toasts are CanvasLayers under main, so close
		# them ~2 frames before each shot — queue_free needs a frame to actually
		# stop appearing in the viewport texture.
		278:
			_close_overlays(main)
		280:
			_shot("01_fleet.png")
			main.call("_switch_tab", 1)
		398:
			_close_overlays(main)
		400:
			_shot("02_cities.png")
			main.call("_switch_tab", 2)
		518:
			_close_overlays(main)
		520:
			_shot("03_talents.png")
			main.call("_switch_tab", 3)
		638:
			_close_overlays(main)
		640:
			_shot("04_legacy.png")
			main.call("_switch_tab", 4)
		758:
			_close_overlays(main)
		760:
			_shot("05_shop.png")
			main.call("_switch_tab", 5)
		878:
			_close_overlays(main)
		880:
			_shot("06_missions.png")
		890:
			get_tree().quit()

func _close_overlays(main: Node) -> void:
	for c in main.get_children():
		if c is CanvasLayer:
			c.queue_free()
	# Toasts live in main's `_toasts` VBox, NOT in a CanvasLayer — the loop above
	# never touches them, so the seeded income tripping a rate milestone left its
	# banner sitting over the map in every shot.
	var toasts: Node = main.get("_toasts")
	if toasts != null:
		for t in toasts.get_children():
			toasts.remove_child(t)
			t.queue_free()

func _shot(fname: String) -> void:
	var img := get_viewport().get_texture().get_image()
	if img != null:
		img.save_png("res://export/store/" + fname)
