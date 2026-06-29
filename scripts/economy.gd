extends Node
## Economy data & formulas (autoload: Economy). Long, gated, monetizable curve.

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

# influence_total required to be allowed to unlock HUBS[i] (a prestige wall).
const HUB_GATE := [0, 0, 1, 4, 10, 22, 45, 80]

const UPGRADES := {
	"speed": {"name": "Velocidade dos Drones", "base": 100.0, "rate": 1.22, "icon": "ic_speed"},
	"cargo": {"name": "Capacidade de Carga", "base": 150.0, "rate": 1.24, "icon": "ic_cargo"},
	"value": {"name": "Valor da Encomenda", "base": 220.0, "rate": 1.26, "icon": "ic_value"},
}
const UPGRADE_ORDER := ["speed", "cargo", "value"]

const TALENTS := {
	"global":  {"name": "Comando Central", "desc": "+12% lucros globais", "max": 100, "icon": "ic_prestige"},
	"speed":   {"name": "Rotores Turbo", "desc": "+8% velocidade", "max": 60, "icon": "ic_speed"},
	"value":   {"name": "Rotas Premium", "desc": "+8% valor da encomenda", "max": 60, "icon": "ic_value"},
	"hangar":  {"name": "Hangar Eficiente", "desc": "-2% custo de drones", "max": 25, "icon": "ic_drone"},
	"offline": {"name": "IA Logística", "desc": "+30 min de tempo offline", "max": 12, "icon": "ic_boost"},
}
const TALENT_ORDER := ["global", "speed", "value", "hangar", "offline"]

# Gem shop — what GEMS buy (the gem sink). Makes gems (and buying gems) worthwhile.
const GEM_SHOP_ORDER := ["boost", "cash", "warp"]
const GEM_SHOP := {
	"boost": {"name": "Núcleo de Lucro", "desc": "+25% lucros GLOBAIS, para sempre.", "icon": "ic_prestige"},
	"cash":  {"name": "Injeção de Créditos", "desc": "Ganha já 1 hora de lucros.", "cost": 30, "icon": "ic_credits"},
	"warp":  {"name": "Salto Temporal 8h", "desc": "Ganha já 8 horas de lucros.", "cost": 80, "icon": "ic_boost"},
}

const MILESTONE_STEP := 50

func num_hubs() -> int: return HUBS.size()
func hub_pos(i: int) -> Vector2: return HUBS[i]["pos"]
func hub_name(i: int) -> String: return HUBS[i]["name"]
func route_dist(i: int) -> float: return max(0.08, HUBS[0]["pos"].distance_to(HUBS[i]["pos"]))

func upgrade_cost(key: String, level: int) -> float:
	var u: Dictionary = UPGRADES[key]
	return u["base"] * pow(u["rate"], float(level))

func drone_cost(count: int) -> float:
	return 12.0 * pow(1.13, float(max(0, count - 1)))

func hub_unlock_cost(next_index: int) -> float:
	return 400.0 * pow(6.5, float(max(0, next_index - 1)))

func hub_gate(next_index: int) -> int:
	return HUB_GATE[next_index] if next_index < HUB_GATE.size() else 999999

func talent_cost(level: int) -> int:
	return int(ceil(pow(1.7, float(level))))

func gem_boost_cost(level: int) -> int:
	return 60 * int(pow(2.0, float(level)))
