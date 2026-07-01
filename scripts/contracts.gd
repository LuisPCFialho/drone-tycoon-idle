extends Node
## Contracts — Missões: time-limited delivery goals that reward credits and gems.
## Autoload: Contracts. Registered after SaveSystem in project.godot.

signal completed(slot: int)
signal refreshed(slot: int)

const SLOT_COUNT := 4
const EXPIRE_DELAY := 20.0  # seconds before a new contract spawns after claiming

var slots: Array = []
var _refresh_timers: Array = [0.0, 0.0, 0.0, 0.0]
var _frame := 0

func _ready() -> void:
	_ensure_slots()
	GameState.delivered.connect(_on_delivered)

func _process(delta: float) -> void:
	_frame += 1
	var now := int(Time.get_unix_time_from_system())
	for i in range(SLOT_COUNT):
		if i >= slots.size():
			break
		var s: Dictionary = slots[i]
		if s.get("claimed", false):
			_refresh_timers[i] -= delta
			if _refresh_timers[i] <= 0.0:
				_replace(i)
		elif now >= int(s.get("deadline", 0)):
			_replace(i)
		elif _frame % 60 == 0 and str(s.get("type", "")) == "drones":
			slots[i]["progress"] = float(GameState.drones)
			if float(slots[i]["progress"]) >= float(s.get("target", 1.0)):
				slots[i]["ready"] = true

func _on_delivered(_amount: float, _city: int) -> void:
	var now := int(Time.get_unix_time_from_system())
	for i in range(slots.size()):
		var s: Dictionary = slots[i]
		if s.get("claimed", false) or s.get("ready", false):
			continue
		if now >= int(s.get("deadline", 0)):
			continue
		match str(s.get("type", "")):
			"deliveries":
				slots[i]["progress"] = float(s.get("progress", 0.0)) + 1.0
				if slots[i]["progress"] >= float(s.get("target", 1.0)):
					slots[i]["ready"] = true
			"earn":
				var base: float = float(s.get("earn_base", 0.0))
				slots[i]["progress"] = maxf(0.0, GameState.total_earned - base)
				if slots[i]["progress"] >= float(s.get("target", 1.0)):
					slots[i]["ready"] = true

func claim(i: int) -> bool:
	if i < 0 or i >= slots.size():
		return false
	var s: Dictionary = slots[i]
	if not s.get("ready", false) or s.get("claimed", false):
		return false
	slots[i]["claimed"] = true
	_refresh_timers[i] = EXPIRE_DELAY
	var rc: float = float(s.get("reward_credits", 0.0))
	GameState.credits += rc
	GameState.total_earned += rc
	var rg: int = int(s.get("reward_gems", 0))
	if rg > 0:
		GameState.gems += rg
	completed.emit(i)
	return true

func progress_pct(i: int) -> float:
	if i >= slots.size():
		return 0.0
	var s: Dictionary = slots[i]
	return clampf(float(s.get("progress", 0.0)) / maxf(1.0, float(s.get("target", 1.0))), 0.0, 1.0)

func time_remaining(i: int) -> float:
	if i >= slots.size():
		return 0.0
	var s: Dictionary = slots[i]
	if s.get("claimed", false):
		return maxf(0.0, _refresh_timers[i])
	return maxf(0.0, float(s.get("deadline", 0)) - float(Time.get_unix_time_from_system()))

func _replace(i: int) -> void:
	slots[i] = _gen(i)
	_refresh_timers[i] = 0.0
	refreshed.emit(i)

func _ensure_slots() -> void:
	while slots.size() < SLOT_COUNT:
		slots.append(_gen(slots.size()))

func _gen(slot_idx: int) -> Dictionary:
	var now := int(Time.get_unix_time_from_system())
	var ips := maxf(GameState.income_per_sec(), 0.5)
	var d_count := maxi(GameState.drones, 1)

	if slot_idx == 3:
		var wk_target := maxf(500.0, float(d_count) * 200.0)
		return {
			"type": "deliveries", "weekly": true,
			"label": "Desafio Semanal: entrega %d pacotes" % int(wk_target),
			"target": wk_target, "progress": 0.0, "earn_base": 0.0,
			"deadline": now + 604800, "duration": 604800,
			"reward_credits": ips * 7200.0,
			"reward_gems": maxi(5, 5 + Prestige.count * 2),
			"claimed": false, "ready": false,
		}

	var diff := 1.0 + float(slot_idx) * 1.8

	var types := ["deliveries", "earn", "earn", "deliveries"]
	if d_count > 10:
		types.append("drones")
	var t: String = types[randi() % types.size()]

	var target := 1.0
	var label := ""
	var dur := 600.0
	var reward_credits := 0.0
	var reward_gems := 0
	var earn_base := 0.0

	match t:
		"deliveries":
			target = maxf(30.0, float(d_count) * 8.0 * diff)
			label = "Entrega %d pacotes" % int(target)
			dur = maxf(300.0, target * 3.0)
			reward_credits = ips * minf(dur, 600.0) * 0.4 * diff
			reward_gems = 1 if slot_idx >= 2 else 0
		"earn":
			target = ips * 120.0 * diff
			label = "Ganha " + Fmt.short(target) + " créditos"
			dur = maxf(600.0, 240.0 * diff)
			reward_credits = target * 0.35 * diff
			reward_gems = 1 if slot_idx >= 2 else 0
			earn_base = GameState.total_earned
		"drones":
			var need := int(float(d_count) * (1.3 + 0.2 * float(slot_idx)))
			target = float(maxi(need, d_count + 5))
			label = "Tem %d drones na frota" % int(target)
			dur = 3600.0
			reward_credits = ips * 180.0 * diff
			reward_gems = 1
		_:
			t = "earn"
			target = 1000.0
			label = "Ganha 1K créditos"
			dur = 300.0
			reward_credits = 400.0

	dur = minf(dur, 5400.0)
	return {
		"type": t, "label": label, "target": target, "progress": 0.0,
		"earn_base": earn_base, "deadline": now + int(dur), "duration": int(dur),
		"reward_credits": reward_credits, "reward_gems": reward_gems,
		"claimed": false, "ready": false,
	}

func to_dict() -> Dictionary:
	return {"slots": slots.duplicate(true), "timers": _refresh_timers.duplicate()}

func from_dict(d: Dictionary) -> void:
	var sv: Variant = d.get("slots", [])
	slots.clear()
	if sv is Array:
		for item in sv:
			if item is Dictionary:
				slots.append(item)
	var tv: Variant = d.get("timers", [])
	if tv is Array:
		for i in range(mini(SLOT_COUNT, tv.size())):
			_refresh_timers[i] = float(tv[i])
	_ensure_slots()
