extends Node
## In-app purchases (autoload: Billing). FAKE/local grants; API mirrors Google Play
## Billing. Products are designed to be genuinely valuable (see docs/ADMOB_INTEGRATION).

signal purchased(product_id: String)
signal purchase_failed(product_id: String, reason: String)

var ads_removed := false
var perm_mult := 1.0
var vip := false               # VIP pass: 2x always + 24h offline + bonus

const PRODUCTS := {
	"starter":  {"name": "Pacote Inicial", "price": "€2,99", "type": "nonconsumable", "desc": "+300 Gemas, +5 drones e Lucros x2 por 1h. Arranque rápido!"},
	"vip":      {"name": "Passe VIP", "price": "€9,99", "type": "nonconsumable", "desc": "Lucros x2 SEMPRE ativos, offline até 24h, +500 Gemas."},
	"perm_x2":  {"name": "Lucros x2 (para sempre)", "price": "€6,99", "type": "nonconsumable", "desc": "Duplica todos os lucros, para sempre."},
	"gems_xs":  {"name": "Bolso de Gemas", "price": "€0,99", "type": "consumable", "gems": 50, "desc": "+50 Gemas"},
	"gems_s":   {"name": "Punhado de Gemas", "price": "€1,99", "type": "consumable", "gems": 120, "desc": "+120 Gemas"},
	"gems_m":   {"name": "Saco de Gemas", "price": "€7,99", "type": "consumable", "gems": 650, "desc": "+650 Gemas (bónus +30%)"},
	"gems_l":   {"name": "Cofre de Gemas", "price": "€19,99", "type": "consumable", "gems": 1900, "desc": "+1900 Gemas (óptimo valor)"},
	"gems_xl":  {"name": "Tesouro de Gemas", "price": "€34,99", "type": "consumable", "gems": 3800, "desc": "+3800 Gemas (melhor valor)"},
}
const PRODUCT_ORDER := ["starter", "vip", "perm_x2", "gems_xs", "gems_s", "gems_m", "gems_l", "gems_xl"]

func buy(product_id: String) -> void:
	if not PRODUCTS.has(product_id):
		purchase_failed.emit(product_id, "produto desconhecido"); return
	var p: Dictionary = PRODUCTS[product_id]
	match product_id:
		"gems_xs", "gems_s", "gems_m", "gems_l", "gems_xl":
			GameState.gems += int(p["gems"])
		"perm_x2":
			perm_mult = max(perm_mult, 2.0)
		"vip":
			vip = true; ads_removed = true; GameState.gems += 500
		"starter":
			GameState.gems += 300; GameState.drones += 5; GameState._rebuild_drones()
			GameState.boost_earn_2x()
	purchased.emit(product_id)
	if has_node("/root/SaveSystem"):
		SaveSystem.save_game()

func to_dict() -> Dictionary:
	return {"ads_removed": ads_removed, "perm_mult": perm_mult, "vip": vip}

func from_dict(d: Dictionary) -> void:
	ads_removed = bool(d.get("ads_removed", false))
	perm_mult = float(d.get("perm_mult", 1.0))
	vip = bool(d.get("vip", false))
