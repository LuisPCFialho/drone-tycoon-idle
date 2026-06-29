extends Node
## In-app purchases (autoload: Billing). FAKE/local grants for now; API matches a
## real Google Play Billing integration (see docs/ADMOB_INTEGRATION.md).

signal purchased(product_id: String)
signal purchase_failed(product_id: String, reason: String)

var ads_removed := false
var perm_mult := 1.0   # permanent global earnings multiplier ("x2 para sempre")

const PRODUCTS := {
	"gems_s":     {"name": "Punhado de Gemas",     "price": "€1,99",  "type": "consumable",    "gems": 100,  "desc": "+100 Gemas"},
	"gems_m":     {"name": "Saco de Gemas",         "price": "€7,99",  "type": "consumable",    "gems": 550,  "desc": "+550 Gemas (melhor valor)"},
	"gems_l":     {"name": "Caixa de Gemas",        "price": "€19,99", "type": "consumable",    "gems": 1500, "desc": "+1500 Gemas"},
	"remove_ads": {"name": "Remover Anúncios",      "price": "€3,99",  "type": "nonconsumable", "desc": "Sem intersticiais. Os anúncios de recompensa (opcionais) mantêm-se."},
	"perm_x2":    {"name": "Lucros x2 (para sempre)","price": "€7,99", "type": "nonconsumable", "desc": "Duplica todos os ganhos, para sempre."},
	"starter":    {"name": "Pacote Inicial",        "price": "€2,99",  "type": "nonconsumable", "desc": "+250 Gemas, +3 drones e remove anúncios."},
}

func buy(product_id: String) -> void:
	if not PRODUCTS.has(product_id):
		purchase_failed.emit(product_id, "produto desconhecido")
		return
	var p: Dictionary = PRODUCTS[product_id]
	match product_id:
		"gems_s", "gems_m", "gems_l":
			GameState.gems += int(p["gems"])
		"remove_ads":
			ads_removed = true
		"perm_x2":
			perm_mult = 2.0
		"starter":
			GameState.gems += 250
			GameState.drones += 3
			ads_removed = true
	purchased.emit(product_id)
	if has_node("/root/SaveSystem"):
		SaveSystem.save_game()

func to_dict() -> Dictionary:
	return {"ads_removed": ads_removed, "perm_mult": perm_mult}

func from_dict(d: Dictionary) -> void:
	ads_removed = bool(d.get("ads_removed", false))
	perm_mult = float(d.get("perm_mult", 1.0))
