extends Node
## Core state & simulation (autoload: GameState) for the drone delivery tycoon.

const BASE_SPEED := 0.45        # route-fraction per second at speed level 0
const OFFLINE_CAP := 7200.0     # 2h
const OFFLINE_EFF := 0.5
const AUTOSAVE_INTERVAL := 15.0
const EARN_BOOST_DURATION := 60.0
const MAX_VISUAL_DRONES := 14

signal delivered(amount: float, hub_index: int)
signal prestiged(gain: int)
signal hub_unlocked(index: int)
signal fleet_changed()

# --- persisted ---
var credits := 0.0
var gems := 0
var influence := 0            # prestige currency (permanent)
var influence_total := 0
var drones := 1
var hubs_unlocked := 2        # home + first city
var levels := {"speed": 0, "cargo": 0, "value": 0}
var earn_boost_timer := 0.0
var lifetime_credits := 0.0

# --- transient ---
var earn_boost_mult := 2.0
var buy_mode := 1
var pending_offline := 0.0
var pending_offline_seconds := 0.0
var vdrones: Array = []        # visual drones: {route, t, dir}
var _autosave_t := 0.0
var _pop_accum := 0.0

func _ready() -> void:
	_rebuild_drones()

# ---------------------------------------------------------------- derived
func speed_mult() -> float:
	return pow(1.07, float(levels["speed"]))

func cargo() -> int:
	return 1 + int(levels["cargo"])

func pkg_value() -> float:
	return 5.0 * pow(1.10, float(levels["value"]))

func routes() -> int:
	return max(1, hubs_unlocked - 1)

func network_mult() -> float:
	return pow(1.18, float(hubs_unlocked - 1))

func global_mult() -> float:
	return (1.0 + 0.10 * float(influence)) * Billing.perm_mult

func earn_mult() -> float:
	var m := global_mult()
	if earn_boost_timer > 0.0:
		m *= earn_boost_mult
	return m

func payout_for_route(city_index: int) -> float:
	var d := Economy.route_dist(city_index)
	return float(cargo()) * pkg_value() * network_mult() * (1.0 + 1.5 * d)

func income_per_sec() -> float:
	var r := routes()
	var s := 0.0
	for i in range(1, hubs_unlocked):
		var d := Economy.route_dist(i)
		# deliveries/sec on this route = speed/(2*dist); payout includes (1+1.5d)
		s += (BASE_SPEED * speed_mult() / (2.0 * d)) * (1.0 + 1.5 * d)
	var avg_rate := s / float(r)
	return float(drones) * float(cargo()) * pkg_value() * network_mult() * global_mult() * avg_rate

# ---------------------------------------------------------------- fleet
func _rebuild_drones() -> void:
	vdrones.clear()
	var n: int = min(drones, MAX_VISUAL_DRONES)
	for i in range(n):
		var route := 1 + (i % routes())
		vdrones.append({"route": route, "t": randf(), "dir": 1})
	fleet_changed.emit()

# ---------------------------------------------------------------- loop
func _process(delta: float) -> void:
	if earn_boost_timer > 0.0:
		earn_boost_timer = max(0.0, earn_boost_timer - delta)

	# Income (continuous, exact) — covers the whole fleet.
	credits += income_per_sec() * (earn_boost_mult if earn_boost_timer > 0.0 else 1.0) * delta
	lifetime_credits += income_per_sec() * delta

	# Visual drones + delivery pops.
	for v in vdrones:
		var d := Economy.route_dist(int(v["route"]))
		var rate := BASE_SPEED * speed_mult() / d
		v["t"] += rate * float(v["dir"]) * delta
		if v["t"] >= 1.0:
			v["t"] = 1.0; v["dir"] = -1
			delivered.emit(payout_for_route(int(v["route"])) * (earn_boost_mult if earn_boost_timer > 0.0 else 1.0), int(v["route"]))
		elif v["t"] <= 0.0:
			v["t"] = 0.0; v["dir"] = 1

	_autosave_t += delta
	if _autosave_t >= AUTOSAVE_INTERVAL:
		_autosave_t = 0.0
		SaveSystem.save_game()

# ---------------------------------------------------------------- actions
func can_afford_drone() -> bool:
	return credits >= Economy.drone_cost(drones)

func buy_drone() -> bool:
	var cost := Economy.drone_cost(drones)
	if credits < cost:
		return false
	credits -= cost
	drones += 1
	_rebuild_drones()
	return true

func next_hub_cost() -> float:
	if hubs_unlocked >= Economy.num_hubs():
		return -1.0
	return Economy.hub_unlock_cost(hubs_unlocked)

func can_unlock_hub() -> bool:
	var c := next_hub_cost()
	return c >= 0.0 and credits >= c

func unlock_hub() -> bool:
	var c := next_hub_cost()
	if c < 0.0 or credits < c:
		return false
	credits -= c
	hubs_unlocked += 1
	_rebuild_drones()
	hub_unlocked.emit(hubs_unlocked - 1)
	return true

func upgrade_cost_multi(key: String, count: int) -> float:
	if count <= 0:
		return 0.0
	var u: Dictionary = Economy.UPGRADES[key]
	var rate: float = u["rate"]
	var first: float = u["base"] * pow(rate, float(levels[key]))
	return first * (pow(rate, float(count)) - 1.0) / (rate - 1.0)

func max_affordable(key: String) -> int:
	var u: Dictionary = Economy.UPGRADES[key]
	var rate: float = u["rate"]
	var first: float = u["base"] * pow(rate, float(levels[key]))
	if credits < first:
		return 0
	return max(0, int(floor(log(1.0 + credits * (rate - 1.0) / first) / log(rate))))

func planned_count(key: String) -> int:
	return max(1, max_affordable(key)) if buy_mode == -1 else buy_mode

func buy_upgrade_multi(key: String) -> int:
	var count := planned_count(key)
	if count < 1:
		return 0
	var cost := upgrade_cost_multi(key, count)
	if credits < cost:
		return 0
	credits -= cost
	levels[key] = int(levels[key]) + count
	return count

# ---------------------------------------------------------------- prestige
func prestige_gain() -> int:
	if not is_finite(lifetime_credits) or lifetime_credits <= 0.0:
		return 0
	var g: float = floor(sqrt(lifetime_credits / 250000.0))
	return int(min(g, 1.0e15))   # clamp to avoid int64 overflow

func can_prestige() -> bool:
	return prestige_gain() >= 1

func do_prestige() -> int:
	var g := prestige_gain()
	if g < 1:
		return 0
	influence += g
	influence_total += g
	credits = 0.0
	drones = 1
	hubs_unlocked = 2
	levels = {"speed": 0, "cargo": 0, "value": 0}
	lifetime_credits = 0.0
	_rebuild_drones()
	prestiged.emit(g)
	SaveSystem.save_game()
	return g

# ---------------------------------------------------------------- boosts
func boost_earn_2x() -> void:
	earn_boost_timer = EARN_BOOST_DURATION

func grant_gems(n: int) -> void:
	gems += n

func collect_offline(multiplier: float) -> float:
	var amount := pending_offline * multiplier
	credits += amount
	pending_offline = 0.0
	pending_offline_seconds = 0.0
	return amount

# ---------------------------------------------------------------- persistence
func to_dict() -> Dictionary:
	return {
		"credits": credits, "gems": gems, "influence": influence, "influence_total": influence_total,
		"drones": drones, "hubs_unlocked": hubs_unlocked, "levels": levels.duplicate(),
		"earn_boost_timer": earn_boost_timer, "lifetime_credits": lifetime_credits,
	}

func from_dict(d: Dictionary) -> void:
	credits = float(d.get("credits", 0.0))
	gems = int(d.get("gems", 0))
	influence = int(d.get("influence", 0))
	influence_total = int(d.get("influence_total", influence))
	drones = max(1, int(d.get("drones", 1)))
	hubs_unlocked = max(2, int(d.get("hubs_unlocked", 2)))
	var lv := {"speed": 0, "cargo": 0, "value": 0}
	var saved: Dictionary = d.get("levels", {})
	for k in lv:
		if saved.has(k):
			lv[k] = int(saved[k])
	levels = lv
	earn_boost_timer = float(d.get("earn_boost_timer", 0.0))
	lifetime_credits = float(d.get("lifetime_credits", 0.0))
	_rebuild_drones()

func get_metric(_m: String) -> float:
	return 0.0
