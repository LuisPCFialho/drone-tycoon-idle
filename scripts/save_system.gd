extends Node
## Persistence (autoload: SaveSystem). Plain JSON in user:// for MVP robustness.
## (Encryption/HMAC is a documented post-MVP hardening step.)

const SAVE_PATH := "user://deepcore_save.json"
const SAVE_VERSION := 1

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game() -> void:
	var data := {
		"v": SAVE_VERSION,
		"ts": int(Time.get_unix_time_from_system()),
		"game": GameState.to_dict(),
		"billing": Billing.to_dict(),
		"audio": Audio.to_dict(),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("SaveSystem: could not open save file for writing.")
		return
	f.store_string(JSON.stringify(data))
	f.close()

## Returns true if a save was loaded. Also computes pending offline earnings.
func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var txt := f.get_as_text()
	f.close()
	var data: Variant = JSON.parse_string(txt)
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("SaveSystem: corrupt save, ignoring.")
		return false

	Billing.from_dict(data.get("billing", {}))
	Audio.from_dict(data.get("audio", {}))
	GameState.from_dict(data.get("game", {}))

	var ts := int(data.get("ts", 0))
	var now := int(Time.get_unix_time_from_system())
	var elapsed: float = float(max(0, now - ts))
	GameState.pending_offline_seconds = min(elapsed, GameState.offline_cap())
	GameState.pending_offline = GameState.income_per_sec() * GameState.pending_offline_seconds * GameState.OFFLINE_EFF
	return true

func wipe() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
