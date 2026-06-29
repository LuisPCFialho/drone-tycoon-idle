extends Node
## Economy data & formulas (autoload: Economy) for the drone delivery tycoon.

# Hub network. pos is normalized inside the map area (x:0..1, y:0..1, y=0 at top).
# index 0 is the home base; the rest are delivery cities unlocked over time.
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

const UPGRADES := {
	# Cost growth deliberately exceeds benefit growth so no upgrade self-funds
	# (prevents runaway/overflow): speed +12%/lvl, value +15%/lvl, cargo +1 flat/lvl.
	"speed": {"name": "Velocidade dos Drones", "base": 40.0, "rate": 1.22},
	"cargo": {"name": "Capacidade de Carga", "base": 55.0, "rate": 1.18},
	"value": {"name": "Valor da Encomenda", "base": 70.0, "rate": 1.25},
}
const UPGRADE_ORDER := ["speed", "cargo", "value"]

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
	return 60.0 * pow(1.20, float(max(0, count - 1)))

func hub_unlock_cost(next_index: int) -> float:
	# Cost to unlock the city at HUBS[next_index].
	return 600.0 * pow(7.5, float(max(0, next_index - 1)))
