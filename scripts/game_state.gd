extends Node
## Core state & simulation (autoload: GameState). Long gated curve + monetization.

const BASE_SPEED := 0.45
const BASE_PER_DRONE := 1.2
const OFFLINE_CAP_BASE := 7200.0
const OFFLINE_EFF := 0.5
const AUTOSAVE_INTERVAL := 15.0
const EARN_BOOST_DURATION := 300.0
const MAX_VISUAL_DRONES := 14

signal delivered(amount: float, hub_index: int)
signal prestiged(gain: int)
signal hub_unlocked(index: int)
signal milestone_reached(mult: float)
signal fleet_changed()

# --- persisted ---
var credits := 0.0
var gems := 0
var influence := 0
var influence_total := 0
var drones := 1
var hubs_unlocked := 2          # base + first city free
var levels := {"speed": 0, "cargo": 0, "value": 0}
var talents := {"global": 0, "speed": 0, "value": 0, "hangar": 0, "offline": 0}
var gem_boost := 0              # permanent +25% income per level (gem sink)
var earn_boost_timer := 0.0
var lifetime_credits := 0.0

# --- transient ---
var earn_boost_mult := 2.0
var buy_mode := 1
var pending_offline := 0.0
var pending_offline_seconds := 0.0
var vdrones: Array = []
var _autosave_t := 0.0
var _last_milestone := 0

func _ready() -> void:
	_last_milestone = milestone_steps()
	_rebuild_drones()

# ---------------------------------------------------------------- derived
func milestone_steps() -> int:
	return int(drones / Economy.MILESTONE_STEP)

func milestone_mult() -> float:
	return 1.0 + 0.5 * float(milestone_steps())   # additive, not explosive

func per_drone() -> float:
	var cargo_f := 1.0 + 0.5 * float(levels["cargo"])
	var speed_f := pow(1.05, float(levels["speed"])) * (1.0 + 0.08 * float(talents["speed"]))
	var value_f := pow(1.06, float(levels["value"])) * (1.0 + 0.08 * float(talents["value"]))
	return BASE_PER_DRONE * cargo_f * speed_f * value_f

func routes() -> int:
	return max(1, hubs_unlocked - 1)

func network_mult() -> float:
	return 1.0 + 0.5 * float(hubs_unlocked - 1)

func vip_mult() -> float:
	return 2.0 if Billing.vip else 1.0

func global_mult() -> float:
	return (1.0 + 0.10 * float(influence)) * (1.0 + 0.12 * float(talents["global"])) \
		* (1.0 + 0.25 * float(gem_boost)) * Billing.perm_mult * vip_mult()

func earn_mult() -> float:
	var m := global_mult()
	if earn_boost_timer > 0.0:
		m *= earn_boost_mult
	return m

func offline_cap() -> float:
	var cap := OFFLINE_CAP_BASE + 1800.0 * float(talents["offline"])
	if Billing.vip:
		cap += 79200.0   # VIP: up to 24h total
	return cap

func income_per_sec() -> float:
	return float(drones) * per_drone() * network_mult() * milestone_mult() * global_mult()

func drone_cost() -> float:
	return Economy.drone_cost(drones) * max(0.5, 1.0 - 0.02 * float(talents["hangar"]))

# ---------------------------------------------------------------- visuals
func _rebuild_drones() -> void:
	vdrones.clear()
	var n: int = min(drones, MAX_VISUAL_DRONES)
	var r := routes()
	for i in range(n):
		vdrones.append({"route": 1 + (i % r), "t": randf(), "dir": 1})
	fleet_changed.emit()

func payout_pop() -> float:
	return income_per_sec() * 0.6 / float(max(1, vdrones.size()))

# ---------------------------------------------------------------- loop
func _process(delta: float) -> void:
	if earn_boost_timer > 0.0:
		earn_boost_timer = max(0.0, earn_boost_timer - delta)
	var inc := income_per_sec() * (earn_boost_mult if earn_boost_timer > 0.0 else 1.0)
	credits += inc * delta
	lifetime_credits += income_per_sec() * delta

	for v in vdrones:
		var d := Economy.route_dist(int(v["route"]))
		var rate := BASE_SPEED * (1.0 + 0.04 * float(levels["speed"])) / d
		v["t"] += rate * float(v["dir"]) * delta
		if v["t"] >= 1.0:
			v["t"] = 1.0; v["dir"] = -1
			delivered.emit(payout_pop(), int(v["route"]))
		elif v["t"] <= 0.0:
			v["t"] = 0.0; v["dir"] = 1

	_autosave_t += delta
	if _autosave_t >= AUTOSAVE_INTERVAL:
		_autosave_t = 0.0
		SaveSystem.save_game()

func _check_milestone() -> void:
	var m := milestone_steps()
	if m > _last_milestone:
		_last_milestone = m
		milestone_reached.emit(milestone_mult())

# ---------------------------------------------------------------- buy drones
func drone_cost_multi(count: int) -> float:
	var rate := 1.13
	var first := Economy.drone_cost(drones)
	return first * (pow(rate, float(count)) - 1.0) / (rate - 1.0) * max(0.5, 1.0 - 0.02 * float(talents["hangar"]))

func drone_max_affordable() -> int:
	var rate := 1.13
	var first := drone_cost()
	if credits < first: return 0
	return max(0, int(floor(log(1.0 + credits * (rate - 1.0) / first) / log(rate))))

func drone_planned() -> int:
	return max(1, drone_max_affordable()) if buy_mode == -1 else buy_mode

func buy_drones() -> int:
	var count := drone_planned()
	var cost := drone_cost_multi(count)
	if count < 1 or credits < cost: return 0
	credits -= cost; drones += count
	_rebuild_drones(); _check_milestone()
	return count

# ---------------------------------------------------------------- cities (gated)
func next_hub_cost() -> float:
	if hubs_unlocked >= Economy.num_hubs(): return -1.0
	return Economy.hub_unlock_cost(hubs_unlocked)

func next_hub_gate() -> int:
	return Economy.hub_gate(hubs_unlocked)

func hub_gate_ok() -> bool:
	return influence_total >= next_hub_gate()

func can_unlock_hub() -> bool:
	var c := next_hub_cost()
	return c >= 0.0 and hub_gate_ok() and credits >= c

func unlock_hub() -> bool:
	if not can_unlock_hub(): return false
	credits -= next_hub_cost(); hubs_unlocked += 1
	_rebuild_drones(); hub_unlocked.emit(hubs_unlocked - 1)
	return true

# ---------------------------------------------------------------- upgrades
func upgrade_cost_multi(key: String, count: int) -> float:
	if count <= 0: return 0.0
	var u: Dictionary = Economy.UPGRADES[key]
	var rate: float = u["rate"]
	var first: float = u["base"] * pow(rate, float(levels[key]))
	return first * (pow(rate, float(count)) - 1.0) / (rate - 1.0)

func max_affordable(key: String) -> int:
	var u: Dictionary = Economy.UPGRADES[key]
	var rate: float = u["rate"]
	var first: float = u["base"] * pow(rate, float(levels[key]))
	if credits < first: return 0
	return max(0, int(floor(log(1.0 + credits * (rate - 1.0) / first) / log(rate))))

func planned_count(key: String) -> int:
	return max(1, max_affordable(key)) if buy_mode == -1 else buy_mode

func buy_upgrade_multi(key: String) -> int:
	var count := planned_count(key)
	if count < 1: return 0
	var cost := upgrade_cost_multi(key, count)
	if credits < cost: return 0
	credits -= cost; levels[key] = int(levels[key]) + count
	return count

# ---------------------------------------------------------------- talents
func talent_cost(key: String) -> int:
	return Economy.talent_cost(int(talents[key]))

func can_buy_talent(key: String) -> bool:
	return int(talents[key]) < int(Economy.TALENTS[key]["max"]) and influence >= talent_cost(key)

func buy_talent(key: String) -> bool:
	if not can_buy_talent(key): return false
	influence -= talent_cost(key); talents[key] = int(talents[key]) + 1
	return true

# ---------------------------------------------------------------- gem shop
func gem_boost_cost() -> int:
	return Economy.gem_boost_cost(gem_boost)

func buy_gem_boost() -> bool:
	var c := gem_boost_cost()
	if gems < c: return false
	gems -= c; gem_boost += 1
	return true

func buy_gem_cash(cost: int, seconds: float) -> bool:
	if gems < cost: return false
	gems -= cost
	credits += income_per_sec() * seconds
	return true

# ---------------------------------------------------------------- prestige
func prestige_gain() -> int:
	if not is_finite(lifetime_credits) or lifetime_credits <= 0.0: return 0
	var g: float = floor(1.5 * pow(lifetime_credits / 1.0e6, 0.30))
	return int(clamp(g, 0.0, 1.0e9))

func can_prestige() -> bool:
	return prestige_gain() >= 1

func do_prestige() -> int:
	var g := prestige_gain()
	if g < 1: return 0
	influence += g; influence_total += g
	credits = 0.0; drones = 1; hubs_unlocked = 2
	levels = {"speed": 0, "cargo": 0, "value": 0}
	lifetime_credits = 0.0; _last_milestone = 0
	_rebuild_drones(); prestiged.emit(g); SaveSystem.save_game()
	return g

# ---------------------------------------------------------------- boosts/offline
func boost_earn_2x() -> void:
	earn_boost_timer = EARN_BOOST_DURATION

func grant_gems(n: int) -> void:
	gems += n

func grant_cash_minutes(minutes: float) -> void:
	credits += income_per_sec() * minutes * 60.0

func collect_offline(multiplier: float) -> float:
	var amount := pending_offline * multiplier
	credits += amount
	pending_offline = 0.0; pending_offline_seconds = 0.0
	return amount

# ---------------------------------------------------------------- persistence
func to_dict() -> Dictionary:
	return {
		"credits": credits, "gems": gems, "influence": influence, "influence_total": influence_total,
		"drones": drones, "hubs_unlocked": hubs_unlocked,
		"levels": levels.duplicate(), "talents": talents.duplicate(), "gem_boost": gem_boost,
		"earn_boost_timer": earn_boost_timer, "lifetime_credits": lifetime_credits,
	}

func from_dict(d: Dictionary) -> void:
	credits = float(d.get("credits", 0.0))
	gems = int(d.get("gems", 0))
	influence = int(d.get("influence", 0))
	influence_total = int(d.get("influence_total", influence))
	drones = max(1, int(d.get("drones", 1)))
	hubs_unlocked = max(2, int(d.get("hubs_unlocked", 2)))
	gem_boost = int(d.get("gem_boost", 0))
	var lv := {"speed": 0, "cargo": 0, "value": 0}
	var slv: Dictionary = d.get("levels", {})
	for k in lv:
		if slv.has(k): lv[k] = int(slv[k])
	levels = lv
	var tl := {"global": 0, "speed": 0, "value": 0, "hangar": 0, "offline": 0}
	var stl: Dictionary = d.get("talents", {})
	for k in tl:
		if stl.has(k): tl[k] = int(stl[k])
	talents = tl
	earn_boost_timer = float(d.get("earn_boost_timer", 0.0))
	lifetime_credits = float(d.get("lifetime_credits", 0.0))
	_last_milestone = milestone_steps()
	_rebuild_drones()
