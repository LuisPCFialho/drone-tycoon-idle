extends Node
## Prestige system (autoload: Prestige). Soft reset with permanent compounding bonuses.
## Requires country >= 4 (5th country). Each prestige earns Prestige Gems (pgems).

signal prestiged(count: int)

const MIN_COUNTRY := 4
const TIER_NAMES := ["Bronze", "Prata", "Ouro", "Platina", "Diamante", "Lendário"]

# Persisted
var count := 0
var pgems := 0
var total_pgems := 0
var permanent_mult := 1.0
var shop_owned: Array = []   # list of owned shop item ids

const SHOP := {
    "speed_5":     {"name": "Turbo de Arranque",    "cost": 5,  "desc": "Começa sempre com velocidade nível 5."},
    "cargo_5":     {"name": "Carga Extra",           "cost": 5,  "desc": "Começa sempre com carga nível 5."},
    "value_5":     {"name": "Rotas Premium",         "cost": 5,  "desc": "Começa sempre com valor nível 5."},
    "offline_10":  {"name": "Gestor Eficiente",      "cost": 8,  "desc": "+10% de eficiência offline permanente."},
    "offline_20":  {"name": "Operações Noturnas",    "cost": 15, "desc": "+20% de eficiência offline permanente."},
    "drones_10":   {"name": "Hangar Herdado",        "cost": 10, "desc": "Começa sempre com 10 drones extra."},
    "drones_25":   {"name": "Hangar Militar",        "cost": 20, "desc": "Começa sempre com 25 drones extra."},
    "vip_24h":     {"name": "Prévia VIP",            "cost": 30, "desc": "Activa VIP por 24 h após cada prestige."},
    "start_c2":    {"name": "Voos Internacionais",   "cost": 40, "desc": "Começa no 2.º país após prestige."},
}
const SHOP_ORDER := ["speed_5", "cargo_5", "value_5", "offline_10", "offline_20", "drones_10", "drones_25", "vip_24h", "start_c2"]

func pgems_on_next_prestige() -> int:
    return max(3, 5 + count * 3 + (GameState.current_country if has_node("/root/GameState") else 0))

func can_prestige() -> bool:
    if not has_node("/root/GameState"): return false
    return GameState.current_country >= MIN_COUNTRY

func tier_name() -> String:
    return TIER_NAMES[mini(count, TIER_NAMES.size() - 1)]

func extra_offline_pct() -> float:
    var bonus := 0.0
    if "offline_10" in shop_owned: bonus += 0.10
    if "offline_20" in shop_owned: bonus += 0.20
    return bonus

func starting_drones() -> int:
    var base := 1 + count * 2
    if "drones_10" in shop_owned: base += 10
    if "drones_25" in shop_owned: base += 25
    return mini(base, 50)

func starting_country() -> int:
    return 1 if "start_c2" in shop_owned else 0

func do_prestige() -> bool:
    if not can_prestige(): return false
    var pg := pgems_on_next_prestige()
    pgems += pg; total_pgems += pg
    count += 1
    permanent_mult = pow(1.15, float(count))
    _soft_reset()
    if has_node("/root/Achievements"): Achievements.note_prestige(count)
    if has_node("/root/Audio"): Audio.play("prestige")
    prestiged.emit(count)
    SaveSystem.save_game()
    return true

func _soft_reset() -> void:
    if not has_node("/root/GameState"): return
    var gs := GameState
    gs.credits = 0.0
    # gems are premium (ads/IAP only) — they carry over unchanged, never topped up
    gs.influence = 0
    gs.current_country = starting_country()
    gs.cities_unlocked = 1
    gs.drones = starting_drones()
    gs.levels = {"speed": 0, "cargo": 0, "value": 0, "routes": 0}
    gs.talents = {"global": 0, "speed": 0, "value": 0, "hangar": 0}
    gs.gem_boost = 0
    gs.earn_boost_timer = 0.0
    # Apply shop starting bonuses
    if "speed_5" in shop_owned: gs.levels["speed"] = 5
    if "cargo_5" in shop_owned: gs.levels["cargo"] = 5
    if "value_5" in shop_owned: gs.levels["value"] = 5
    gs._rebuild_drones()

func buy_shop(id: String) -> bool:
    if not SHOP.has(id): return false
    if id in shop_owned: return false
    var cost: int = int(SHOP[id]["cost"])
    if pgems < cost: return false
    pgems -= cost
    shop_owned.append(id)
    SaveSystem.save_game()
    return true

func has_shop(id: String) -> bool:
    return id in shop_owned

func to_dict() -> Dictionary:
    return {
        "count": count, "pgems": pgems, "total": total_pgems,
        "mult": permanent_mult, "shop": shop_owned.duplicate(),
    }

func from_dict(d: Dictionary) -> void:
    count = int(d.get("count", 0))
    pgems = int(d.get("pgems", 0))
    total_pgems = int(d.get("total", 0))
    permanent_mult = float(d.get("mult", 1.0))
    shop_owned = Array(d.get("shop", []))
