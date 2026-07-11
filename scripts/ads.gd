extends Node
## Ads layer (autoload: Ads).
##
## Real AdMob rewarded ads on Android when the AdmobPlugin native singleton is
## present (release/debug device or emulator builds with the plugin baked in).
## Falls back to a simulated on-screen countdown in the editor and on desktop
## builds without the plugin, so gameplay/reward flows stay testable without a
## device. Public API (is_rewarded_ready, show_rewarded, show_interstitial) is
## unchanged either way — see docs/ADMOB_INTEGRATION.md.
##
## Uses Google's public TEST ad unit IDs (Admob.ANDROID_REWARDED_DEMO_AD_UNIT_ID)
## until real ones are configured — see docs/ADMOB_INTEGRATION.md for the
## one-line switch to production ads once an AdMob account/app exists.

signal reward_granted(kind: String)

var _busy := false

# --- real AdMob path ---
var _admob: Admob = null
var _ad_ready := false
var _pending_kind := ""
var _pending_cb: Callable
var _watch_token := 0   # invalidates a stale watchdog when a newer ad is shown

func _ready() -> void:
	if OS.get_name() != "Android" or not Engine.has_singleton("AdmobPlugin"):
		return   # editor / desktop / plugin not baked into this build: fake path only
	_admob = Admob.new()
	_admob.is_real = false   # flip to true in docs/ADMOB_INTEGRATION.md once real IDs exist
	add_child(_admob)
	_admob.initialization_completed.connect(func(_status): _load_next_ad())
	_admob.rewarded_ad_loaded.connect(func(_info, _resp): _ad_ready = true)
	_admob.rewarded_ad_failed_to_load.connect(func(_info, _err): _ad_ready = false; _retry_load_later())
	_admob.rewarded_ad_user_earned_reward.connect(func(_info, _reward): _grant_pending())
	# Grant on dismiss too (not just on earned-reward): some devices/ad units
	# never fire the earned-reward callback even after a full watch, which left
	# the player unable to ever redeem. _grant_pending() is idempotent (guarded
	# by _busy) so this never double-grants. Reward-on-dismiss is intentionally
	# lenient — fine for the current test ad units; revisit if real ads demand
	# completion-gated rewards.
	_admob.rewarded_ad_dismissed_full_screen_content.connect(func(_info): _grant_pending(); _load_next_ad())
	_admob.rewarded_ad_failed_to_show_full_screen_content.connect(func(_info, _err): _grant_pending())
	_admob.initialize()

func _load_next_ad() -> void:
	_ad_ready = false
	if _admob != null:
		_admob.load_rewarded_ad()

func _retry_load_later() -> void:
	await get_tree().create_timer(30.0).timeout
	_load_next_ad()

func is_rewarded_ready() -> bool:
	if _busy:
		return false
	return true if _admob == null else _ad_ready   # fake path is always available

## Show a rewarded ad. On completion, `on_reward` is called and the signal fires.
## `kind` is a free-form tag identifying the placement (e.g. "refuel", "x2", "offline").
func show_rewarded(kind: String, on_reward: Callable = Callable()) -> void:
	if _busy:
		return
	_busy = true
	if _admob == null or not _ad_ready:
		# no plugin, or a real ad genuinely isn't ready yet — never soft-lock
		# the player behind ad-network availability, degrade to the sim.
		_play_overlay(kind, on_reward)
		return
	_pending_kind = kind
	_pending_cb = on_reward
	_watch_token += 1
	_admob.show_rewarded_ad()
	_watchdog(_watch_token)

## Safety net for the reported "ad opens but freezes, reward never redeemable"
## bug: if a shown ad produces NO terminal callback (earned / dismissed / failed)
## within a generous window, don't leave the player soft-locked behind _busy —
## grant the reward and reload. Guarded by _busy (any real callback clears it
## first) and by the token (a newer show supersedes this watchdog).
func _watchdog(token: int) -> void:
	await get_tree().create_timer(35.0).timeout
	if _busy and token == _watch_token:
		_grant_pending()
		_load_next_ad()

func _grant_pending() -> void:
	if not _busy:
		return   # rewarded_ad_user_earned_reward AND the show-failure path can
	_busy = false  # both fire in some SDK edge cases — only grant once
	if _pending_cb.is_valid():
		_pending_cb.call()
	reward_granted.emit(_pending_kind)

## Interstitials are gated by the "remove ads" purchase. No-op in this game
## by design — see docs/ADMOB_INTEGRATION.md if that ever changes.
func show_interstitial() -> void:
	if Billing.ads_removed:
		return
	pass

# ── Fake/editor fallback (unchanged from the pre-AdMob build) ────────────────

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
