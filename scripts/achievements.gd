extends Node
## Achievement system (autoload: Achievements). 40+ milestones with gem rewards.

signal unlocked(id: String)

const DEFS := {
    # Deliveries
    "first_delivery":  {"name": "Primeira Entrega",      "desc": "Completa a primeira entrega.",              "icon": "🚁", "gems": 5,   "cat": "frota"},
    "deliveries_100":  {"name": "Cem Entregas",           "desc": "Completa 100 entregas.",                    "icon": "📦", "gems": 10,  "cat": "frota"},
    "deliveries_1k":   {"name": "Mil Entregas",           "desc": "Completa 1 000 entregas.",                  "icon": "📦", "gems": 25,  "cat": "frota"},
    "deliveries_10k":  {"name": "Dez Mil Entregas",       "desc": "Completa 10 000 entregas.",                 "icon": "🏆", "gems": 75,  "cat": "frota"},
    # Fleet
    "drones_5":        {"name": "Pequena Frota",          "desc": "Tem 5 drones activos.",                     "icon": "🚁", "gems": 5,   "cat": "frota"},
    "drones_25":       {"name": "Frota Sólida",           "desc": "Tem 25 drones activos.",                    "icon": "💪", "gems": 15,  "cat": "frota"},
    "drones_100":      {"name": "Exército de Drones",     "desc": "Tem 100 drones activos.",                   "icon": "⚡", "gems": 40,  "cat": "frota"},
    "drones_500":      {"name": "Força Aérea",            "desc": "Tem 500 drones activos.",                   "icon": "🌟", "gems": 100, "cat": "frota"},
    "buy_100_once":    {"name": "Atacado",                "desc": "Compra 100 drones de uma vez.",             "icon": "🛒", "gems": 30,  "cat": "frota", "secret": true},
    # Credits
    "credits_1m":      {"name": "Milionário",             "desc": "Acumula 1 M de créditos.",                  "icon": "💰", "gems": 10,  "cat": "riqueza"},
    "credits_1b":      {"name": "Bilionário",             "desc": "Acumula 1 B de créditos.",                  "icon": "💎", "gems": 30,  "cat": "riqueza"},
    "credits_1t":      {"name": "Trilionário",            "desc": "Acumula 1 T de créditos.",                  "icon": "🌟", "gems": 80,  "cat": "riqueza"},
    "earned_10b":      {"name": "Fluxo de Caixa",         "desc": "Ganha 10 B no total.",                      "icon": "📈", "gems": 50,  "cat": "riqueza"},
    "earned_1t":       {"name": "Magnata",                "desc": "Ganha 1 T no total.",                       "icon": "🏆", "gems": 150, "cat": "riqueza"},
    "income_1k":       {"name": "Rendimento Sólido",      "desc": "Atinge 1 000/s de receita.",                "icon": "📈", "gems": 15,  "cat": "riqueza"},
    "income_1m":       {"name": "Máquina de Dinheiro",    "desc": "Atinge 1 M/s de receita.",                  "icon": "💹", "gems": 50,  "cat": "riqueza"},
    # Countries / Cities
    "country_2":       {"name": "Expansão Global",        "desc": "Expande para o 2.º país.",                  "icon": "🌍", "gems": 15,  "cat": "mundo"},
    "country_5":       {"name": "Continente",             "desc": "Expande para 5 países.",                    "icon": "🌍", "gems": 40,  "cat": "mundo"},
    "country_10":      {"name": "Dominação Mundial",      "desc": "Expande para 10 países.",                   "icon": "🌐", "gems": 100, "cat": "mundo"},
    "cities_10":       {"name": "Urbanista",              "desc": "Desbloqueia 10 cidades no total.",          "icon": "🏙", "gems": 15,  "cat": "mundo"},
    "cities_50":       {"name": "Megalópole",             "desc": "Desbloqueia 50 cidades no total.",          "icon": "🌆", "gems": 50,  "cat": "mundo"},
    # Upgrades / Talents
    "upgrade_25":      {"name": "Engenheiro",             "desc": "Chega ao nível 25 num upgrade.",            "icon": "⚙", "gems": 20,  "cat": "melhorias"},
    "upgrade_100":     {"name": "Mestre Técnico",         "desc": "Chega ao nível 100 num upgrade.",           "icon": "🔧", "gems": 60,  "cat": "melhorias"},
    "all_25":          {"name": "Frota Optimizada",       "desc": "Todos os upgrades ao nível 25+.",           "icon": "✨", "gems": 40,  "cat": "melhorias"},
    "talent_10":       {"name": "Talentoso",              "desc": "Chega ao nível 10 num talento.",            "icon": "⭐", "gems": 15,  "cat": "melhorias"},
    "influence_50":    {"name": "Influente",              "desc": "Acumula 50 de influência total.",           "icon": "🎯", "gems": 30,  "cat": "melhorias"},
    "gem_boost_5":     {"name": "Obsessivo",              "desc": "Compra o Núcleo de Lucro 5 vezes.",         "icon": "💠", "gems": 50,  "cat": "melhorias", "secret": true},
    # Prestige
    "prestige_1":      {"name": "Novo Começo",            "desc": "Faz prestige pela primeira vez.",           "icon": "🔄", "gems": 100, "cat": "legado"},
    "prestige_3":      {"name": "Veterano",               "desc": "Faz prestige 3 vezes.",                     "icon": "💎", "gems": 200, "cat": "legado", "secret": true},
    "prestige_5":      {"name": "Piloto Lendário",        "desc": "Faz prestige 5 vezes.",                     "icon": "🌟", "gems": 500, "cat": "legado", "secret": true},
    # Daily / Streak
    "streak_7":        {"name": "Semana de Trabalho",     "desc": "Joga 7 dias consecutivos.",                 "icon": "📅", "gems": 50,  "cat": "legado"},
    "streak_30":       {"name": "Mês Dedicado",           "desc": "Joga 30 dias consecutivos.",                "icon": "🗓", "gems": 200, "cat": "legado"},
    "total_30":        {"name": "Piloto Fiel",            "desc": "Joga 30 dias no total.",                    "icon": "🎖", "gems": 75,  "cat": "legado"},
    # Events
    "event_first":     {"name": "Hora de Ponta",          "desc": "Participa no primeiro evento.",             "icon": "⚡", "gems": 10,  "cat": "eventos"},
    "event_5":         {"name": "Caçador de Eventos",     "desc": "Participa em 5 eventos.",                   "icon": "🎉", "gems": 30,  "cat": "eventos"},
    "event_25":        {"name": "Mestre dos Eventos",     "desc": "Participa em 25 eventos.",                  "icon": "🎯", "gems": 75,  "cat": "eventos"},
    # Offline
    "offline_big":     {"name": "Gestor Ausente",         "desc": "Recolhe mais de 1 M offline.",             "icon": "💤", "gems": 25,  "cat": "riqueza"},
    # Session
    "session_30m":     {"name": "Dedicado",               "desc": "Joga 30 minutos numa sessão.",              "icon": "⏱", "gems": 20,  "cat": "legado"},
    # Gems
    "gems_100":        {"name": "Coleccionador",          "desc": "Tens 100 gemas em simultâneo.",             "icon": "💎", "gems": 0,   "cat": "riqueza"},
    "gems_spent_500":  {"name": "Investidor",             "desc": "Gasta 500 gemas no total.",                 "icon": "💠", "gems": 20,  "cat": "riqueza"},
}

# Persisted
var unlocked_ids: Array = []
var counters := {
    "deliveries": 0,
    "cities_total": 0,
    "events_total": 0,
    "gems_spent": 0,
}

# Transient
var _session_start_ms: int = 0

func _ready() -> void:
    _session_start_ms = Time.get_ticks_msec()
    if has_node("/root/GameState"):
        GameState.delivered.connect(_on_delivered)
        GameState.city_unlocked.connect(_on_city_unlocked)
        GameState.country_changed.connect(_on_country)

func _process(_delta: float) -> void:
    var session_ms := Time.get_ticks_msec() - _session_start_ms
    if session_ms >= 30 * 60 * 1000:
        check("session_30m", true)

func _on_delivered(_amount: float, _city: int) -> void:
    counters["deliveries"] = int(counters.get("deliveries", 0)) + 1
    var d: int = int(counters["deliveries"])
    check("first_delivery", d >= 1)
    check("deliveries_100",  d >= 100)
    check("deliveries_1k",   d >= 1000)
    check("deliveries_10k",  d >= 10000)

func _on_city_unlocked(_idx: int) -> void:
    counters["cities_total"] = int(counters.get("cities_total", 0)) + 1
    var ct: int = int(counters["cities_total"])
    check("cities_10", ct >= 10)
    check("cities_50", ct >= 50)

func _on_country(idx: int) -> void:
    check("country_2",  idx >= 1)
    check("country_5",  idx >= 4)
    check("country_10", idx >= 9)

## Call after loading save to re-evaluate state-based achievements
func check_all_state() -> void:
    if not has_node("/root/GameState"): return
    var gs := GameState
    check("drones_5",    gs.drones >= 5)
    check("drones_25",   gs.drones >= 25)
    check("drones_100",  gs.drones >= 100)
    check("drones_500",  gs.drones >= 500)
    check("credits_1m",  gs.credits >= 1_000_000.0)
    check("credits_1b",  gs.credits >= 1_000_000_000.0)
    check("credits_1t",  gs.credits >= 1_000_000_000_000.0)
    check("earned_10b",  gs.total_earned >= 10_000_000_000.0)
    check("earned_1t",   gs.total_earned >= 1_000_000_000_000.0)
    var max_lv: int = maxi(int(gs.levels.get("speed", 0)), maxi(int(gs.levels.get("cargo", 0)), int(gs.levels.get("value", 0))))
    check("upgrade_25",  max_lv >= 25)
    check("upgrade_100", max_lv >= 100)
    var min_lv: int = mini(int(gs.levels.get("speed", 0)), mini(int(gs.levels.get("cargo", 0)), int(gs.levels.get("value", 0))))
    check("all_25",      min_lv >= 25)
    var max_tal: int = maxi(int(gs.talents.get("global", 0)), maxi(int(gs.talents.get("speed", 0)), maxi(int(gs.talents.get("value", 0)), int(gs.talents.get("hangar", 0)))))
    check("talent_10",   max_tal >= 10)
    check("influence_50", gs.influence_total >= 50)
    check("gems_100",    gs.gems >= 100)
    check("income_1k",   gs.income_per_sec() >= 1000.0)
    check("income_1m",   gs.income_per_sec() >= 1_000_000.0)
    check("country_2",   gs.current_country >= 1)
    check("country_5",   gs.current_country >= 4)
    check("country_10",  gs.current_country >= 9)

func note_drone_buy(count: int, total: int) -> void:
    check("buy_100_once", count >= 100)
    check("drones_5",    total >= 5)
    check("drones_25",   total >= 25)
    check("drones_100",  total >= 100)
    check("drones_500",  total >= 500)

func note_gem_boost(level: int) -> void:
    check("gem_boost_5", level >= 5)

func note_offline(amount: float) -> void:
    check("offline_big", amount >= 1_000_000.0)

func note_streak(days: int, total: int) -> void:
    check("streak_7",  days >= 7)
    check("streak_30", days >= 30)
    check("total_30",  total >= 30)

func note_event(total: int) -> void:
    check("event_first", total >= 1)
    check("event_5",     total >= 5)
    check("event_25",    total >= 25)

func note_gems_spent(amount: int) -> void:
    counters["gems_spent"] = int(counters.get("gems_spent", 0)) + amount
    check("gems_spent_500", int(counters["gems_spent"]) >= 500)

func note_prestige(count: int) -> void:
    check("prestige_1", count >= 1)
    check("prestige_3", count >= 3)
    check("prestige_5", count >= 5)

func check(id: String, condition: bool) -> void:
    if not condition: return
    if id in unlocked_ids: return
    if not DEFS.has(id): return
    unlocked_ids.append(id)
    var reward: int = int(DEFS[id].get("gems", 0))
    if reward > 0 and has_node("/root/GameState"):
        GameState.gems += reward
    if has_node("/root/Audio"):
        Audio.play("achieve")
    unlocked.emit(id)

func is_done(id: String) -> bool:
    return id in unlocked_ids

func done_count() -> int:
    return unlocked_ids.size()

func total_count() -> int:
    return DEFS.size()

func to_dict() -> Dictionary:
    return {"ids": unlocked_ids.duplicate(), "counters": counters.duplicate()}

func from_dict(d: Dictionary) -> void:
    unlocked_ids = Array(d.get("ids", []))
    var cd: Dictionary = d.get("counters", {})
    for k in counters:
        if cd.has(k):
            counters[k] = cd[k]
