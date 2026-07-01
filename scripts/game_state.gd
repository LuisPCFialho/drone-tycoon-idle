extends Node
## Core state & simulation (autoload: GameState). World-map country progression.
## Credits are earned ONLY per delivery (no time-based trickle).

const BASE_SPEED := 0.5
const BASE_DELIV := 4.0
const OFFLINE_CAP_BASE := 7200.0
const OFFLINE_EFF := 0.5
const AUTOSAVE_INTERVAL := 15.0
const EARN_BOOST_DURATION := 300.0
const MAX_VISUAL_DRONES := 16
const COMBO_DECAY := 10.0

signal delivered(amount: float, city_index: int)
signal city_unlocked(index: int)
signal country_changed(index: int)
signal fleet_changed()

# --- persisted ---
var credits := 0.0
var gems := 0
var influence := 0
var influence_total := 0
var current_country := 0
var cities_unlocked := 1          # active delivery cities (capital is always home)
var drones := 1
var levels := {"speed": 0, "cargo": 0, "value": 0, "routes": 0}
var talents := {"global": 0, "speed": 0, "value": 0, "hangar": 0}
var gem_boost := 0
var earn_boost_timer := 0.0
var total_earned := 0.0
var total_deliveries := 0
var combo_window_bonus := 0.0   # +seconds on combo decay (gem shop, permanent)

# --- transient ---
var earn_boost_mult := 2.0
var buy_mode := 10
var pending_offline := 0.0
var pending_offline_seconds := 0.0
var vdrones: Array = []
var _autosave_t := 0.0
var combo: int = 0
var _combo_decay_t: float = 0.0

func _ready() -> void:
	_rebuild_drones()

# ---------------------------------------------------------------- derived
func max_cities() -> int:
	return Economy.country_cities(current_country).size() - 1   # excludes capital

func speed_factor() -> float:
	var base := 1.0 + 0.03 * float(levels["speed"]) + 0.04 * float(talents["speed"])
	return base * Events.current_spd_mult

func vip_mult() -> float:
	return 2.0 if Billing.vip else 1.0

func global_mult() -> float:
	return (1.0 + 0.05 * float(influence)) * (1.0 + 0.06 * float(talents["global"])) \
		* (1.0 + 0.25 * float(gem_boost)) * Billing.perm_mult * vip_mult() \
		* Events.current_mult * Prestige.permanent_mult

func route_mult() -> float:
	return 1.0 + 0.025 * float(levels.get("routes", 0))

func combo_mult() -> float:
	if combo >= 100: return 2.0
	if combo >= 50:  return 1.5
	if combo >= 25:  return 1.25
	if combo >= 10:  return 1.1
	return 1.0

## Upgrades & drones scale with the country's pay tier so they stay meaningfully
## priced after each expansion (fixes "trivial after the first country").
func cost_scale() -> float:
	return Economy.pay_tier(current_country)

func offline_cap() -> float:
	var prestige_extra: float = OFFLINE_CAP_BASE * Prestige.extra_offline_pct()
	return OFFLINE_CAP_BASE + prestige_extra + (79200.0 if Billing.vip else 0.0)

func _route_dist(r: int) -> float:
	var cities := Economy.country_cities(current_country)
	var cap := Vector2(cities[0]["x"], cities[0]["y"])
	var idx: int = clampi(1 + r, 1, cities.size() - 1)
	var c := Vector2(cities[idx]["x"], cities[idx]["y"])
	return max(0.06, cap.distance_to(c))

## Credits for one delivery to a route (weak upgrade gains; scales with country tier).
func per_delivery(dist: float) -> float:
	var vf := (1.0 + 0.25 * float(levels["cargo"])) * pow(1.04, float(levels["value"])) * (1.0 + 0.04 * float(talents["value"]))
	return BASE_DELIV * vf * (1.0 + dist) * Economy.pay_tier(current_country) * global_mult() * route_mult()

func fleet_scale() -> float:
	return float(drones) / float(max(1, vdrones.size()))

## Estimated credits/sec (for display & offline) — derived from delivery throughput.
func income_per_sec() -> float:
	var n := cities_unlocked
	if n < 1:
		return 0.0
	var s := 0.0
	for r in range(n):
		var d := _route_dist(r)
		var tt := 2.0 * d / (BASE_SPEED * speed_factor())
		s += per_delivery(d) / tt
	return float(drones) * (s / float(n))

func drone_cost() -> float:
	return Economy.drone_cost(drones) * cost_scale() * max(0.5, 1.0 - 0.02 * float(talents["hangar"]))

# ---------------------------------------------------------------- visuals
func _rebuild_drones() -> void:
	vdrones.clear()
	var n: int = min(drones, MAX_VISUAL_DRONES)
	var routes: int = max(1, cities_unlocked)
	for i in range(n):
		vdrones.append({"route": i % routes, "t": randf(), "dir": 1})
	fleet_changed.emit()

# ---------------------------------------------------------------- loop
func _process(delta: float) -> void:
	if earn_boost_timer > 0.0:
		earn_boost_timer = max(0.0, earn_boost_timer - delta)
	var boost: float = earn_boost_mult if earn_boost_timer > 0.0 else 1.0
	if _combo_decay_t > 0.0:
		_combo_decay_t -= delta
		if _combo_decay_t <= 0.0:
			combo = 0
			_combo_decay_t = 0.0
	var fs := fleet_scale()
	for v in vdrones:
		var d := _route_dist(int(v["route"]))
		var rate := BASE_SPEED * speed_factor() / d
		v["t"] += rate * float(v["dir"]) * delta
		if v["t"] >= 1.0:
			v["t"] = 1.0; v["dir"] = -1
			combo += 1
			_combo_decay_t = COMBO_DECAY + combo_window_bonus
			var amt := per_delivery(d) * fs * boost * combo_mult()
			credits += amt; total_earned += amt; total_deliveries += 1
			delivered.emit(amt, 1 + int(v["route"]))
		elif v["t"] <= 0.0:
			v["t"] = 0.0; v["dir"] = 1
	_autosave_t += delta
	if _autosave_t >= AUTOSAVE_INTERVAL:
		_autosave_t = 0.0
		SaveSystem.save_game()

# ---------------------------------------------------------------- drones
func drone_cost_multi(count: int) -> float:
	var rate := Economy.DRONE_RATE
	var first := Economy.drone_cost(drones) * cost_scale()
	return first * (pow(rate, float(count)) - 1.0) / (rate - 1.0) * max(0.5, 1.0 - 0.02 * float(talents["hangar"]))

func drone_max_affordable() -> int:
	var rate := Economy.DRONE_RATE
	var first := drone_cost()
	if credits < first:
		return 0
	return max(0, int(floor(log(1.0 + credits * (rate - 1.0) / first) / log(rate))))

func drone_planned() -> int:
	return max(1, drone_max_affordable()) if buy_mode == -1 else buy_mode

func buy_drones() -> int:
	var count := drone_planned()
	var cost := drone_cost_multi(count)
	if count < 1 or credits < cost:
		return 0
	credits -= cost; drones += count
	_rebuild_drones()
	Achievements.note_drone_buy(count, drones)
	return count

# ---------------------------------------------------------------- cities / country
func next_city_cost() -> float:
	if cities_unlocked >= max_cities():
		return -1.0
	return Economy.city_unlock_cost(current_country, cities_unlocked)

func can_unlock_city() -> bool:
	var c := next_city_cost()
	return c >= 0.0 and credits >= c

func unlock_city() -> bool:
	if not can_unlock_city():
		return false
	credits -= next_city_cost()
	cities_unlocked += 1
	_rebuild_drones()
	city_unlocked.emit(cities_unlocked)
	return true

func all_cities_unlocked() -> bool:
	return cities_unlocked >= max_cities()

func expand_cost() -> float:
	if current_country >= Economy.num_countries() - 1:
		return -1.0
	return Economy.expand_cost(current_country)

func can_expand() -> bool:
	var c := expand_cost()
	return c >= 0.0 and all_cities_unlocked() and credits >= c

func expand_country() -> bool:
	if not can_expand():
		return false
	credits -= expand_cost()
	current_country += 1
	cities_unlocked = 1
	influence += 3 + int(current_country / 4)
	influence_total = influence_total + 3 + int(current_country / 4)
	_rebuild_drones()
	country_changed.emit(current_country)
	SaveSystem.save_game()
	return true

# ---------------------------------------------------------------- upgrades
func upgrade_cost_multi(key: String, count: int) -> float:
	if count <= 0:
		return 0.0
	var u: Dictionary = Economy.UPGRADES[key]
	var rate: float = u["rate"]
	var first: float = u["base"] * pow(rate, float(levels[key])) * cost_scale()
	return first * (pow(rate, float(count)) - 1.0) / (rate - 1.0)

func max_affordable(key: String) -> int:
	var u: Dictionary = Economy.UPGRADES[key]
	var rate: float = u["rate"]
	var first: float = u["base"] * pow(rate, float(levels[key])) * cost_scale()
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
	credits -= cost; levels[key] = int(levels[key]) + count
	return count

# ---------------------------------------------------------------- talents
func talent_cost(key: String) -> int:
	return Economy.talent_cost(int(talents[key]))

func can_buy_talent(key: String) -> bool:
	return int(talents[key]) < int(Economy.TALENTS[key]["max"]) and influence >= talent_cost(key)

func buy_talent(key: String) -> bool:
	if not can_buy_talent(key):
		return false
	influence -= talent_cost(key); talents[key] = int(talents[key]) + 1
	return true

# ---------------------------------------------------------------- gem shop
func gem_boost_cost() -> int:
	return Economy.gem_boost_cost(gem_boost)

func buy_gem_boost() -> bool:
	var c := gem_boost_cost()
	if gems < c:
		return false
	gems -= c; gem_boost += 1
	Achievements.note_gem_boost(gem_boost)
	Achievements.note_gems_spent(c)
	return true

func buy_gem_cash(cost: int, seconds: float) -> bool:
	if gems < cost:
		return false
	gems -= cost
	Achievements.note_gems_spent(cost)
	credits += income_per_sec() * seconds
	return true

func buy_gem_drones(cost: int, n: int) -> bool:
	if gems < cost:
		return false
	gems -= cost; drones += n
	_rebuild_drones()
	Achievements.note_drone_buy(n, drones)
	Achievements.note_gems_spent(cost)
	return true

func buy_gem_combo_time(cost: int) -> bool:
	if combo_window_bonus > 0.0:
		return false
	if gems < cost:
		return false
	gems -= cost; combo_window_bonus = COMBO_DECAY
	Achievements.note_gems_spent(cost)
	return true

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
	Achievements.note_offline(amount)
	return amount

# ---------------------------------------------------------------- persistence
func to_dict() -> Dictionary:
	return {
		"credits": credits, "gems": gems, "influence": influence, "influence_total": influence_total,
		"current_country": current_country, "cities_unlocked": cities_unlocked, "drones": drones,
		"levels": levels.duplicate(), "talents": talents.duplicate(), "gem_boost": gem_boost,
		"earn_boost_timer": earn_boost_timer, "total_earned": total_earned, "total_deliveries": total_deliveries,
		"combo_window_bonus": combo_window_bonus,
	}

func from_dict(d: Dictionary) -> void:
	credits = float(d.get("credits", 0.0))
	gems = int(d.get("gems", 0))
	influence = int(d.get("influence", 0))
	influence_total = int(d.get("influence_total", influence))
	current_country = clampi(int(d.get("current_country", 0)), 0, Economy.num_countries() - 1)
	cities_unlocked = max(1, int(d.get("cities_unlocked", 1)))
	drones = max(1, int(d.get("drones", 1)))
	var lv := {"speed": 0, "cargo": 0, "value": 0, "routes": 0}
	var slv: Dictionary = d.get("levels", {})
	for k in lv:
		if slv.has(k): lv[k] = int(slv[k])
	levels = lv
	var tl := {"global": 0, "speed": 0, "value": 0, "hangar": 0}
	var stl: Dictionary = d.get("talents", {})
	for k in tl:
		if stl.has(k): tl[k] = int(stl[k])
	talents = tl
	gem_boost = int(d.get("gem_boost", 0))
	earn_boost_timer = float(d.get("earn_boost_timer", 0.0))
	total_earned = float(d.get("total_earned", 0.0))
	total_deliveries = int(d.get("total_deliveries", 0))
	combo_window_bonus = float(d.get("combo_window_bonus", 0.0))
	_rebuild_drones()
