extends Node
## Economy data & formulas (autoload: Economy). World = 40 countries loaded from
## data/world.json (real outlines + geographically-placed cities). Delivery-based.

var WORLD: Array = []

const UPGRADES := {
	# Deliberately WEAK gains (player asked: upgrades less powerful), steep cost.
	"speed":  {"name": "Velocidade dos Drones", "base": 80.0,  "rate": 1.26, "icon": "ic_speed"},
	"cargo":  {"name": "Capacidade de Carga",   "base": 110.0, "rate": 1.28, "icon": "ic_cargo"},
	"value":  {"name": "Valor da Encomenda",    "base": 150.0, "rate": 1.30, "icon": "ic_value"},
	"routes": {"name": "Rede de Rotas",         "base": 200.0, "rate": 1.32, "icon": "ic_range"},
}
const UPGRADE_ORDER := ["speed", "cargo", "value", "routes"]

const TALENTS := {
	"global":  {"name": "Comando Central", "desc": "+6% lucros globais", "max": 100, "icon": "ic_prestige"},
	"speed":   {"name": "Rotores Turbo", "desc": "+4% velocidade", "max": 60, "icon": "ic_speed"},
	"value":   {"name": "Rotas Premium", "desc": "+4% valor", "max": 60, "icon": "ic_value"},
	"hangar":  {"name": "Hangar Eficiente", "desc": "-2% custo de drones", "max": 25, "icon": "ic_drone"},
}
const TALENT_ORDER := ["global", "speed", "value", "hangar"]

const GEM_SHOP_ORDER := ["boost", "cash", "warp"]
const GEM_SHOP := {
	"boost": {"name": "Núcleo de Lucro", "desc": "+25% lucros GLOBAIS, para sempre.", "icon": "ic_prestige"},
	"cash":  {"name": "Injeção de Créditos", "desc": "Ganha já 1 hora de lucros.", "cost": 30, "icon": "ic_credits"},
	"warp":  {"name": "Salto Temporal 8h", "desc": "Ganha já 8 horas de lucros.", "cost": 80, "icon": "ic_boost"},
}

func _ready() -> void:
	var f := FileAccess.open("res://data/world.json", FileAccess.READ)
	if f:
		var d: Variant = JSON.parse_string(f.get_as_text())
		if typeof(d) == TYPE_DICTIONARY and d.has("countries"):
			WORLD = d["countries"]
		f.close()
	if WORLD.is_empty():
		WORLD = [{"name": "Portugal", "tier": 0, "outline": [[0.3,0.1],[0.4,0.9],[0.5,0.5]], "cities": [{"name":"Lisboa","x":0.4,"y":0.6,"capital":true},{"name":"Porto","x":0.42,"y":0.25,"capital":false}]}]

func num_countries() -> int:
	return WORLD.size()

func country(i: int) -> Dictionary:
	return WORLD[clampi(i, 0, WORLD.size() - 1)]

func country_name(i: int) -> String:
	return country(i)["name"]

func country_cities(i: int) -> Array:
	return country(i)["cities"]

func country_outline(i: int) -> PackedVector2Array:
	var arr := PackedVector2Array()
	for p in country(i)["outline"]:
		arr.append(Vector2(p[0], p[1]))
	return arr

const DRONE_RATE := 1.175

## Per-country payout scale (delivery value grows ~2.2x per country).
func pay_tier(i: int) -> float:
	return pow(2.2, float(i))

## Per-country COST scale — grows MUCH faster than payouts so every country needs
## a substantially bigger fleet than the last (escalating, long progression;
## you cannot rush to the USA — it takes many hours). Steepened in v1.6.3 so
## advancing country is clearly harder.
func cost_tier(i: int) -> float:
	return pow(4.6, float(i))

func upgrade_cost(key: String, level: int) -> float:
	var u: Dictionary = UPGRADES[key]
	return u["base"] * pow(u["rate"], float(level))

func drone_cost(count: int) -> float:
	return 20.0 * pow(DRONE_RATE, float(max(0, count - 1)))

## Cost to unlock the n-th delivery city in a country (n = number already active).
## Steepened in v1.6.4: base ×4.7, per-city exponent raised so later cities
## within a country require sustained grinding before expanding.
func city_unlock_cost(country_idx: int, n: int) -> float:
	return 1500.0 * pow(2.8, float(n)) * cost_tier(country_idx)

## Cost to expand to the next country (available once all cities are unlocked).
## Big upfront gate so jumping country is a real milestone, not a quick hop.
func expand_cost(country_idx: int) -> float:
	return 80000.0 * cost_tier(country_idx)

func talent_cost(level: int) -> int:
	return int(ceil(pow(1.7, float(level))))

func gem_boost_cost(level: int) -> int:
	return 60 * int(pow(2.0, float(level)))
