extends Node
## Procedural SFX (autoload: Audio). Synthesizes tiny PCM clips at startup — no
## audio asset files needed. Public: play(name), tick(), muted, to_dict/from_dict.

const RATE := 22050
var muted := false
var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_tick := 0
var _last_sell := 0

func _ready() -> void:
	_streams["tick"] = _tone(180.0, 0.04, "noise", 0.18, 2.0)
	_streams["break"] = _tone(120.0, 0.07, "noise", 0.22, 2.0)
	_streams["tap"] = _tone(680.0, 0.03, "square", 0.12, 3.0)
	_streams["buy"] = _tone(520.0, 0.06, "square", 0.20, 3.0)
	_streams["sell"] = _two(660.0, 990.0, 0.14, 0.28)
	_streams["achieve"] = _two(784.0, 1175.0, 0.22, 0.30)
	_streams["prestige"] = _tone(523.0, 0.45, "sine", 0.30, 1.2)
	for i in range(10):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	if has_node("/root/GameState"):
		GameState.delivered.connect(_on_delivered)
		GameState.prestiged.connect(func(_g): play("prestige"))

func _on_delivered(_amount: float, _hub: int) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_sell < 150:
		return
	_last_sell = now
	play("sell", randf_range(0.95, 1.12), -5.0)

func play(name: String, pitch := 1.0, vol_db := 0.0) -> void:
	if muted or not _streams.has(name):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[name]
	p.pitch_scale = clampf(pitch, 0.5, 2.0)
	p.volume_db = vol_db
	p.play()

func tick() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_tick < 70:
		return
	_last_tick = now
	play("tick", randf_range(0.85, 1.2), -9.0)

func _tone(freq: float, dur: float, kind: String, vol: float, decay: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t := float(i) / RATE
		var env: float = pow(1.0 - float(i) / n, decay)
		var s := 0.0
		match kind:
			"sine": s = sin(TAU * freq * t)
			"square": s = 1.0 if sin(TAU * freq * t) >= 0.0 else -1.0
			"noise": s = randf() * 2.0 - 1.0
		var v := int(clampf(s * env * vol, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
	return _wav(data)

func _two(f1: float, f2: float, dur: float, vol: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var half := n / 2
	for i in range(n):
		var t := float(i) / RATE
		var freq: float = f1 if i < half else f2
		var env: float = pow(1.0 - float(i) / n, 1.5)
		var v := int(clampf(sin(TAU * freq * t) * env * vol, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
	return _wav(data)

func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = RATE
	st.stereo = false
	st.data = data
	return st

func to_dict() -> Dictionary:
	return {"muted": muted}

func from_dict(d: Dictionary) -> void:
	muted = bool(d.get("muted", false))
