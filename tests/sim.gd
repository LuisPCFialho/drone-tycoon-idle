extends Node
## Headless economy sanity sim: drives GameState for 30 simulated minutes with a
## naive "buy cheapest sensible thing" strategy and prints progression.

func _ready() -> void:
	var dt := 0.1
	var t := 0.0
	var iter := 0
	print("=== Drone Tycoon economy sim ===")
	while t < 1800.0:
		GameState._process(dt)
		if iter % 10 == 0:   # ~1 purchase decision per simulated second (realistic)
			_auto_buy()
			_maybe_prestige()
		t += dt; iter += 1
		if iter % 1200 == 0:
			_report(t)
	_report(t)
	print("=== FINAL drones=%d cidades=%d credits=%s income/s=%s influence=%d ===" % [
		GameState.drones, GameState.hubs_unlocked - 1, Fmt.short(GameState.credits),
		Fmt.short(GameState.income_per_sec()), GameState.prestige_gain()])
	SaveSystem.wipe()
	get_tree().quit()

func _auto_buy() -> void:
	# Realistic pacing: at most one purchase per tick. Unlock a city only when it
	# costs no more than ~5x the cheapest upgrade (a sensible-investment heuristic).
	var best := ""
	var best_cost := INF
	var dcost := GameState.drone_cost()
	if dcost < best_cost: best = "drone"; best_cost = dcost
	for k in Economy.UPGRADE_ORDER:
		var c := Economy.upgrade_cost(k, int(GameState.levels[k]))
		if c < best_cost: best = k; best_cost = c
	if GameState.can_unlock_hub():
		GameState.unlock_hub(); return
	if best != "" and GameState.credits >= best_cost:
		if best == "drone": GameState.buy_drones()
		else: GameState.buy_upgrade_multi(best)

func _maybe_prestige() -> void:
	# Prestige when the gain would at least double current influence_total (or first time).
	var g := GameState.prestige_gain()
	if g >= 2 and g >= GameState.influence_total:
		GameState.do_prestige()
		# spend influence on the global talent and unlock gated cities later
		while GameState.can_buy_talent("global"):
			GameState.buy_talent("global")

func _report(t: float) -> void:
	print("t=%4ds  drones=%3d  cidades=%d  credits=%9s  income/s=%9s  infl=%d/%d" % [
		int(t), GameState.drones, GameState.hubs_unlocked - 1, Fmt.short(GameState.credits),
		Fmt.short(GameState.income_per_sec()), GameState.influence, GameState.influence_total])
