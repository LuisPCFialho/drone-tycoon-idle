extends Node
## Ads layer (autoload: Ads).
##
## FAKE implementation: a rewarded ad is simulated with a short on-screen overlay
## and then the reward is granted for real. The public API (is_rewarded_ready,
## show_rewarded, show_interstitial) matches a real AdMob integration so it can be
## swapped without touching gameplay code — see docs/ADMOB_INTEGRATION.md.

signal reward_granted(kind: String)

var _busy := false

func is_rewarded_ready() -> bool:
	return not _busy   # fake ads are always available

## Show a rewarded ad. On completion, `on_reward` is called and the signal fires.
## `kind` is a free-form tag identifying the placement (e.g. "refuel", "x2", "offline").
func show_rewarded(kind: String, on_reward: Callable = Callable()) -> void:
	if _busy:
		return
	_busy = true
	_play_overlay(kind, on_reward)

## Interstitials are gated by the "remove ads" purchase. No-op in the fake build
## except for the brief demo overlay; real frequency-capping lives in the integration.
func show_interstitial() -> void:
	if Billing.ads_removed:
		return
	# In the fake build we intentionally show nothing intrusive.
	pass

func _play_overlay(kind: String, on_reward: Callable) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 200
	add_child(layer)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	layer.add_child(box)

	var title := Label.new()
	title.text = "Anúncio (demonstração)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	box.add_child(title)

	var count := Label.new()
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.add_theme_font_size_override("font_size", 64)
	count.add_theme_color_override("font_color", Color(0.23, 0.94, 0.63))
	box.add_child(count)

	var note := Label.new()
	note.text = "(substituível por AdMob real — ver docs)"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 22)
	note.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	box.add_child(note)

	for i in range(3, 0, -1):
		count.text = str(i)
		await get_tree().create_timer(0.7).timeout

	count.text = "✓ Recompensa!"
	await get_tree().create_timer(0.5).timeout

	layer.queue_free()
	_busy = false
	if on_reward.is_valid():
		on_reward.call()
	reward_granted.emit(kind)
