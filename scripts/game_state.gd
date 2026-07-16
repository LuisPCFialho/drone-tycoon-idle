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
## Drawn drones travel on a SEPARATE, slower visual clock (v["vt"]). It STILL
## scales with speed_factor() — so buying speed upgrades visibly speeds the fleet
## up — but is 20x slower than the logical delivery cadence so they're followable
## rather than a blur. Income/combo/deliveries are unchanged (still driven by the
## fast logical v["t"]); this only affects where drones are DRAWN.
const VISUAL_SPEED_FACTOR := 0.05

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
var skins_owned: Array = ["classic"]
var skin_active := "classic"
var earn_boost_timer := 0.0
var total_earned := 0.0
var total_deliveries := 0
var combo_window_bonus := 0.0   # +seconds on combo decay (gem shop, permanent)
var vip_temp_until := 0         # unix timestamp; Prestige Shop "vip_24h" grants a temporary VIP window
var auto_manager := false       # VIP perk: auto-buys the cheapest affordable drone/upgrade periodically
var ads_watched := 0            # lifetime rewarded ads; every MEGA_BONUS_EVERY grants a gem mega-bonus

# Loyalty reward: every 10th rewarded ad drops a gem mega-bonus. Gems (not
# credits) keep it OFF the credit economy entirely — and gems are already the
# ads/IAP-only currency, so an ad-triggered gem drop is fully on-brand and
# doesn't disturb the cost/income balance.
const MEGA_BONUS_EVERY := 10
const MEGA_BONUS_GEMS := 100
# small escalating gems for watching a few ads WITHIN one day — an opt-in daily
# ad habit on top of the lifetime mega-bonus. Gems are ads/IAP/daily-only, so an
# ad-triggered gem drop is on-brand and never touches the credit economy.
const AD_DAILY_BONUS := {3: 15, 6: 25, 10: 40}
var ads_today := 0
var ads_today_key := ""

signal ad_milestone(count: int, gems_awarded: int)
signal ad_daily_bonus(count: int, gems_awarded: int)

## Called once per completed rewarded ad (see Ads.reward_granted). Advances the
## lifetime + daily counters; awards the every-10 mega-bonus and the per-day
## escalating bonus, emitting signals for the UI celebration/toast.
func register_ad_watched() -> void:
	ads_watched += 1
	var key := _today_key()
	if key != ads_today_key:
		ads_today_key = key
		ads_today = 0
	ads_today += 1
	if has_node("/root/Achievements"): Achievements.note_ads(ads_watched)
	if ads_watched % MEGA_BONUS_EVERY == 0:
		gems += MEGA_BONUS_GEMS
		ad_milestone.emit(ads_watched, MEGA_BONUS_GEMS)
	elif AD_DAILY_BONUS.has(ads_today):
		var g: int = int(AD_DAILY_BONUS[ads_today])
		gems += g
		ad_daily_bonus.emit(ads_today, g)
	SaveSystem.save_game()

func _today_key() -> String:
	var d := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d" % [int(d["year"]), int(d["month"]), int(d["day"])]

# --- transient ---
var earn_boost_mult := 2.0
var buy_mode := -1   # default to "Máx" (max affordable) per player preference
var pending_offline := 0.0
var pending_offline_seconds := 0.0
var vdrones: Array = []
var _autosave_t := 0.0
var combo: int = 0
var _combo_decay_t: float = 0.0
var _auto_manager_t := 0.0
const AUTO_MANAGER_INTERVAL := 2.5

signal auto_bought(kind: String)

func _ready() -> void:
	_rebuild_drones()

# ---------------------------------------------------------------- derived
func max_cities() -> int:
	return Economy.country_cities(current_country).size() - 1   # excludes capital

func speed_factor() -> float:
	var base := (1.0 + 0.03 * float(levels["speed"]) * Economy.milestone_mult(int(levels["speed"]))) \
		+ 0.04 * float(talents["speed"])
	return base * Events.current_spd_mult

## True for a real (purchased) VIP pass OR an active Prestige Shop "vip_24h"
## temporary window — the single source of truth other code should check
## instead of Billing.vip directly (that was the bug: vip_24h set nothing
## Billing.vip or this function ever read, so the purchase did nothing).
func is_vip_active() -> bool:
	return Billing.vip or vip_temp_until > int(Time.get_unix_time_from_system())

func vip_mult() -> float:
	return 2.0 if is_vip_active() else 1.0

func skin_collection_mult() -> float:
	return 1.0 + 0.02 * float(max(0, skins_owned.size() - 1))

func global_mult() -> float:
	return (1.0 + 0.05 * float(influence)) * (1.0 + 0.06 * float(talents["global"])) \
		* (1.0 + 0.25 * float(gem_boost)) * Billing.perm_mult * vip_mult() \
		* Events.current_mult * Prestige.effective_mult() * skin_collection_mult()

## [label, factor] rows for the income-breakdown popup — every multiplier that
## feeds income, so players can see WHY their rate is what it is. Order roughly
## by typical impact.
func mult_breakdown() -> Array:
	return [
		["Prestígio", Prestige.effective_mult()],
		["VIP", vip_mult()],
		["Evento", Events.current_mult],
		["Combo", combo_mult()],
		["Influência", 1.0 + 0.05 * float(influence)],
		["Talento Global", 1.0 + 0.06 * float(talents["global"])],
		["Núcleo de Lucro", 1.0 + 0.25 * float(gem_boost)],
		["Skins", skin_collection_mult()],
		["Rede de Rotas", route_mult()],
		["Velocidade", speed_factor()],
		["Compra permanente", Billing.perm_mult],
	]

func route_mult() -> float:
	var rl := int(levels.get("routes", 0))
	return 1.0 + 0.025 * float(rl) * Economy.milestone_mult(rl)

func combo_mult() -> float:
	# High tiers (150+) are a pure ACTIVE-PLAY skill reward: combo decays in ~10s,
	# so sustaining a 150/250/500 chain demands constant attention — it never
	# affects idle/offline income, so it can't inflate the tuned economy.
	if combo >= 500: return 3.0
	if combo >= 250: return 2.5
	if combo >= 150: return 2.25
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
	# +30 min of offline cap per prestige (up to +4h at count 8) — a structural
	# reward for prestiging that veterans feel, beyond the flat multiplier.
	var count_extra: float = float(mini(Prestige.count, 8)) * 1800.0
	return OFFLINE_CAP_BASE + prestige_extra + count_extra + (79200.0 if is_vip_active() else 0.0)

## `cities` optional: pass the already-fetched array to avoid re-reading
## Economy.country_cities() (a fresh Dictionary lookup) for every route/drone
## in a loop where it's identical every iteration.
func _route_dist(r: int, cities: Array = []) -> float:
	var c: Array = cities if not cities.is_empty() else Economy.country_cities(current_country)
	var cap := Vector2(c[0]["x"], c[0]["y"])
	var idx: int = clampi(1 + r, 1, c.size() - 1)
	var cc := Vector2(c[idx]["x"], c[idx]["y"])
	return max(0.06, cap.distance_to(cc))

## Per-delivery multiplier that does NOT depend on route distance — only
## (1.0 + dist) does, applied by the caller. Hoisted out of per_delivery()
## so callers looping over many routes/drones (income_per_sec(), _process()
## below) can compute this ONCE per frame instead of recomputing 2 pow()
## calls + 4 multiplier lookups for every single one.
func _delivery_const_mult() -> float:
	var vf := (1.0 + 0.25 * float(levels["cargo"]) * Economy.milestone_mult(int(levels["cargo"]))) \
		* pow(1.04, float(levels["value"])) * Economy.milestone_mult(int(levels["value"])) \
		* (1.0 + 0.04 * float(talents["value"]))
	return BASE_DELIV * vf * Economy.pay_tier(current_country) * global_mult() * route_mult()

## Credits for one delivery to a route (weak upgrade gains; scales with country tier).
func per_delivery(dist: float) -> float:
	return _delivery_const_mult() * (1.0 + dist)

func fleet_scale() -> float:
	return float(drones) / float(max(1, vdrones.size()))

## Estimated credits/sec (for display & offline) — derived from delivery throughput.
func income_per_sec() -> float:
	var n := cities_unlocked
	if n < 1:
		return 0.0
	# hoisted out of the loop: identical for every route, was previously
	# recomputed (2 pow() calls + a fresh country_cities() lookup) per route
	var sf := speed_factor()
	var cities := Economy.country_cities(current_country)
	var const_mult := _delivery_const_mult()
	var s := 0.0
	for r in range(n):
		var d := _route_dist(r, cities)
		var tt := 2.0 * d / (BASE_SPEED * sf)
		s += const_mult * (1.0 + d) / tt
	return float(drones) * (s / float(n))

func drone_cost() -> float:
	return Economy.drone_cost(drones) * cost_scale() * max(0.5, 1.0 - 0.02 * float(talents["hangar"]))

# ---------------------------------------------------------------- visuals
func _rebuild_drones() -> void:
	vdrones.clear()
	var n: int = min(drones, MAX_VISUAL_DRONES)
	var routes: int = max(1, cities_unlocked)
	for i in range(n):
		vdrones.append({"route": i % routes, "t": randf(), "dir": 1, "vt": randf(), "vdir": 1})
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
	# hoisted out of the per-drone loop: identical for every drone this frame
	# (was recomputed up to MAX_VISUAL_DRONES=16 times/frame otherwise)
	var sf := speed_factor()
	# Same hoist, and the one _delivery_const_mult()'s own docstring asks for:
	# income_per_sec() already does this, _process() didn't and still paid ~7 pow()
	# + a Time syscall per delivery. Late game every drone delivers every frame, so
	# that was up to 16x/frame. Bit-exact: nothing this reads (levels, talents,
	# influence, gem_boost, country, event/prestige mults) is mutated in the loop.
	# combo_mult() stays INSIDE — combo increments per delivery and each must see
	# its own value, so hoisting THAT would move the tuned economy.
	var const_mult := _delivery_const_mult()
	var cities := Economy.country_cities(current_country)
	for v in vdrones:
		var d := _route_dist(int(v["route"]), cities)
		var rate := BASE_SPEED * sf / d
		v["t"] += rate * float(v["dir"]) * delta
		if v["t"] >= 1.0:
			v["t"] = 1.0; v["dir"] = -1
			combo += 1
			_combo_decay_t = COMBO_DECAY + combo_window_bonus
			var amt := const_mult * (1.0 + d) * fs * boost * combo_mult()
			credits += amt; total_earned += amt; total_deliveries += 1
			delivered.emit(amt, 1 + int(v["route"]))
		elif v["t"] <= 0.0:
			v["t"] = 0.0; v["dir"] = 1
		# cosmetic slow visual travel (see VISUAL_SPEED_FACTOR) — scales with sf
		# (speed upgrades still visibly speed drones up) but 20x slower than the
		# income logic above, so the fleet is followable instead of a blur
		var vrate := BASE_SPEED * sf * VISUAL_SPEED_FACTOR / d
		v["vt"] += vrate * float(v["vdir"]) * delta
		if v["vt"] >= 1.0:
			v["vt"] = 1.0; v["vdir"] = -1
		elif v["vt"] <= 0.0:
			v["vt"] = 0.0; v["vdir"] = 1
	_autosave_t += delta
	if _autosave_t >= AUTOSAVE_INTERVAL:
		_autosave_t = 0.0
		SaveSystem.save_game()

	if auto_manager and is_vip_active():
		_auto_manager_t += delta
		if _auto_manager_t >= AUTO_MANAGER_INTERVAL:
			_auto_manager_t = 0.0
			_try_auto_buy()

## VIP perk: every AUTO_MANAGER_INTERVAL, buy ONE unit (never bulk — stays
## incremental rather than instant-maxing) of whichever single purchase
## (1 drone, or 1 level of any of the 4 upgrades) is currently cheapest and
## affordable. Silently does nothing if auto_manager is off or VIP lapsed
## (temp "vip_24h" window expiring), rather than force-disabling the toggle.
func _try_auto_buy() -> void:
	var best_kind := ""
	var best_cost := INF
	var dc := drone_cost()
	if credits >= dc and dc < best_cost:
		best_kind = "drone"; best_cost = dc
	for key: String in Economy.UPGRADE_ORDER:
		var uc := upgrade_cost_multi(key, 1)
		if credits >= uc and uc < best_cost:
			best_kind = key; best_cost = uc
	if best_kind == "":
		return
	if best_kind == "drone":
		credits -= dc; drones += 1
		_rebuild_drones()
		Achievements.note_drone_buy(1, drones)
	else:
		credits -= best_cost; levels[best_kind] = int(levels[best_kind]) + 1
	auto_bought.emit(best_kind)

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

## Seconds until `cost` is affordable at the current income rate. -1.0 if
## already affordable (nothing to wait for) or if income is ~0 (would divide
## by ~zero / never happen) — callers should treat -1.0 as "no ETA to show".
func eta_seconds(cost: float) -> float:
	if cost <= credits:
		return -1.0
	var ips := income_per_sec()
	if ips <= 0.01:
		return -1.0
	return (cost - credits) / ips

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
	# Bumped alongside the softer talent cost curve so a talent is actually
	# fundable within a normal run (talents reset on prestige).
	influence += 4 + int(current_country / 3)
	influence_total = influence_total + 4 + int(current_country / 3)
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

# ---------------------------------------------------------------- skins
func has_skin(id: String) -> bool:
	return id in skins_owned

func buy_skin(id: String) -> bool:
	if not Economy.SKINS.has(id) or has_skin(id):
		return false
	var c := int(Economy.SKINS[id]["cost"])
	if gems < c:
		return false
	gems -= c
	skins_owned.append(id)
	skin_active = id
	Achievements.note_gems_spent(c)
	SaveSystem.save_game()
	return true

func set_skin(id: String) -> bool:
	if not has_skin(id):
		return false
	skin_active = id
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

## Full reset ("Reset Progress" in Settings). from_dict({}) already resolves
## every field to its declared default via d.get(key, default) — reuse it
## instead of duplicating the defaults a second time.
func reset() -> void:
	from_dict({})

# ---------------------------------------------------------------- persistence
func to_dict() -> Dictionary:
	return {
		"credits": credits, "gems": gems, "influence": influence, "influence_total": influence_total,
		"current_country": current_country, "cities_unlocked": cities_unlocked, "drones": drones,
		"levels": levels.duplicate(), "talents": talents.duplicate(), "gem_boost": gem_boost,
		"earn_boost_timer": earn_boost_timer, "total_earned": total_earned, "total_deliveries": total_deliveries,
		"combo_window_bonus": combo_window_bonus,
		"skins_owned": skins_owned.duplicate(), "skin_active": skin_active,
		"vip_temp_until": vip_temp_until, "auto_manager": auto_manager,
		"ads_watched": ads_watched, "ads_today": ads_today, "ads_today_key": ads_today_key,
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
	vip_temp_until = int(d.get("vip_temp_until", 0))
	auto_manager = bool(d.get("auto_manager", false))
	ads_watched = int(d.get("ads_watched", 0))
	ads_today = int(d.get("ads_today", 0))
	ads_today_key = str(d.get("ads_today_key", ""))
	skins_owned = ["classic"]
	for s in Array(d.get("skins_owned", [])):
		var sid: String = str(s)
		if Economy.SKINS.has(sid) and sid not in skins_owned:
			skins_owned.append(sid)
	skin_active = str(d.get("skin_active", "classic"))
	if not has_skin(skin_active):
		skin_active = "classic"
	_rebuild_drones()
