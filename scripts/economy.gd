extends Node
## Economy data & formulas (autoload: Economy). Tuned for a LONG idle curve:
## income scales mainly with drone count (exponential cost), modest multipliers,
## milestone x2 every 25 drones, expensive city unlocks, and a prestige talent tree.

const HUBS := [
	{"name": "Base", "pos": Vector2(0.50, 0.92)},
	{"name": "Vila Norte", "pos": Vector2(0.24, 0.74)},
	{"name": "Porto", "pos": Vector2(0.80, 0.70)},
	{"name": "Cidade Alta", "pos": Vector2(0.34, 0.52)},
	{"name": "Zona Industrial", "pos": Vector2(0.72, 0.48)},
	{"name": "Aeroporto", "pos": Vector2(0.20, 0.30)},
	{"name": "Metrópole", "pos": Vector2(0.62, 0.26)},
	{"name": "Pico", "pos": Vector2(0.46, 0.10)},
]

# Fleet upgrades — cost growth deliberately steep so income can't run away.
const UPGRADES := {
	"speed": {"name": "Velocidade dos Drones", "base": 100.0, "rate": 1.20, "icon": "ic_speed"},
	"cargo": {"name": "Capacidade de Carga", "base": 150.0, "rate": 1.22, "icon": "ic_cargo"},
	"value": {"name": "Valor da Encomenda", "base": 220.0, "rate": 1.25, "icon": "ic_value"},
}
const UPGRADE_ORDER := ["speed", "cargo", "value"]

# Prestige talents — bought with Influência (permanent).
const TALENTS := {
	"global":  {"name": "Comando Central", "desc": "+12% lucros globais", "max": 100, "icon": "ic_prestige"},
	"speed":   {"name": "Rotores Turbo", "desc": "+8% velocidade", "max": 60, "icon": "ic_speed"},
	"value":   {"name": "Rotas Premium", "desc": "+8% valor da encomenda", "max": 60, "icon": "ic_value"},
	"hangar":  {"name": "Hangar Eficiente", "desc": "-2% custo de drones", "max": 25, "icon": "ic_drone"},
	"offline": {"name": "IA Logística", "desc": "+30 min de tempo offline", "max": 12, "icon": "ic_boost"},
}
const TALENT_ORDER := ["global", "speed", "value", "hangar", "offline"]

const MILESTONE_STEP := 50   # every 50 drones -> x2 income

func num_hubs() -> int:
	return HUBS.size()

func hub_pos(i: int) -> Vector2:
	return HUBS[i]["pos"]

func hub_name(i: int) -> String:
	return HUBS[i]["name"]

func route_dist(i: int) -> float:
	return max(0.08, HUBS[0]["pos"].distance_to(HUBS[i]["pos"]))

func upgrade_cost(key: String, level: int) -> float:
	var u: Dictionary = UPGRADES[key]
	return u["base"] * pow(u["rate"], float(level))

func drone_cost(count: int) -> float:
	return 12.0 * pow(1.13, float(max(0, count - 1)))

func hub_unlock_cost(next_index: int) -> float:
	# First city is cheap (early win ~2-3 min); each next is ~11x — spans prestiges.
	return 300.0 * pow(11.0, float(max(0, next_index - 1)))

func talent_cost(level: int) -> int:
	return int(ceil(pow(1.7, float(level))))   # 1, 2, 3, 5, 8, 14, ...
