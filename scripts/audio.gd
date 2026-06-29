extends Node
## Procedural SFX — synthesises PCM clips at startup, no audio files needed.
## Public API: play(name), tick(), muted, to_dict/from_dict.

const RATE := 22050
var muted := false
var music_vol := -20.0   # ambient pad volume in dB
var sfx_vol := 0.0       # SFX offset in dB
var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_sell := 0
var _last_tick := 0
var _ambient: AudioStreamPlayer

func _ready() -> void:
	_build_streams()
	for i in range(16):
		var p := AudioStreamPlayer.new(); add_child(p); _players.append(p)
	_ambient = AudioStreamPlayer.new(); add_child(_ambient)
	_ambient.stream = _streams["pad"]
	_ambient.volume_db = music_vol; _ambient.play()
	if has_node("/root/GameState"):
		GameState.delivered.connect(_on_delivered)
		GameState.country_changed.connect(func(_i): play("milestone", 1.0, -2.0))
		GameState.city_unlocked.connect(func(_i): play("unlock", 1.0, -3.0))
	if has_node("/root/Events"):
		Events.started.connect(func(_id): play("event_start", 1.0, -2.0))
	if has_node("/root/Daily"):
		Daily.reward_claimed.connect(func(_idx): play("daily", 1.0, 0.0))
	if has_node("/root/Prestige"):
		Prestige.prestiged.connect(func(_n): play("prestige", 0.95, 2.0))

func _build_streams() -> void:
	_streams["tap"]         = _ping(880.0, 880.0, 0.022, 0.14)
	_streams["tick"]        = _noise(0.026, 0.12, 2.0)
	_streams["buy"]         = _ping(620.0, 1040.0, 0.090, 0.28)
	_streams["sell"]        = _chime(1046.5, 0.120, 0.22)
	_streams["unlock"]      = _arp3([523.25, 659.26, 783.99], 0.072, 0.25)
	_streams["milestone"]   = _arp3([523.25, 659.26, 783.99, 1046.5], 0.105, 0.27)
	_streams["achieve"]     = _arp3([587.33, 739.99, 987.77, 1174.66], 0.085, 0.26)
	_streams["prestige"]    = _chord([261.63, 329.63, 392.00, 523.25, 659.26], 0.55, 0.30)
	_streams["daily"]       = _arp3([783.99, 987.77, 1174.66, 1318.51], 0.090, 0.26)
	_streams["event_start"] = _ping(440.0, 880.0, 0.18, 0.24)
	_streams["error"]       = _noise(0.080, 0.18, 0.8)
	_streams["pad"]         = _pad(4.0)

func _process(_delta: float) -> void:
	if _ambient:
		_ambient.stream_paused = muted
		_ambient.volume_db = muted_music_db()

func _on_delivered(_amount: float, _hub: int) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_sell < 140: return
	_last_sell = now
	play("sell", randf_range(0.93, 1.10), -5.0)

func play(name: String, pitch := 1.0, vol_db := 0.0) -> void:
	if muted or not _streams.has(name): return
	var p := _players[_next]; _next = (_next + 1) % _players.size()
	p.stream = _streams[name]; p.pitch_scale = clampf(pitch, 0.5, 2.0)
	p.volume_db = vol_db + sfx_vol; p.play()

func tick() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_tick < 70: return
	_last_tick = now; play("tick", randf_range(0.85, 1.20), -10.0)

func set_music_vol(db: float) -> void:
	music_vol = clampf(db, -40.0, 0.0)
	if _ambient: _ambient.volume_db = muted_music_db()

func set_sfx_vol(db: float) -> void:
	sfx_vol = clampf(db, -20.0, 6.0)

func muted_music_db() -> float:
	return -80.0 if muted else music_vol

# ── Oscillators ───────────────────────────────────────────────────────────────

func _tri(freq: float, t: float) -> float:
	var x := fmod(freq * t, 1.0)
	return 1.0 - 4.0 * abs(x - 0.5)

func _sine(freq: float, t: float) -> float:
	return sin(TAU * freq * t)

# Smooth decay envelope (fast attack, exponential decay)
func _dec(i: int, n: int, attack_n: int, decay: float) -> float:
	if i < attack_n:
		return float(i) / float(max(1, attack_n))
	return pow(1.0 - float(i - attack_n) / float(max(1, n - attack_n)), decay)

# ── Sound builders ────────────────────────────────────────────────────────────

## Rising-pitch triangle ping — "buy" and "tap"
func _ping(f_start: float, f_end: float, dur: float, vol: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray(); data.resize(n * 2)
	var atk := int(0.003 * RATE)
	for i in range(n):
		var t := float(i) / RATE
		var frac := float(i) / n
		var freq := lerpf(f_start, f_end, pow(frac, 0.5))
		var env := _dec(i, n, atk, 2.2)
		var s := _tri(freq, t) * env * vol
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	return _wav(data)

## Sine chime — "sell" (delivery)
func _chime(freq: float, dur: float, vol: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray(); data.resize(n * 2)
	var atk := int(0.004 * RATE)
	for i in range(n):
		var t := float(i) / RATE
		var env := _dec(i, n, atk, 1.5)
		var s := (_sine(freq, t) * 0.80 + _sine(freq * 2.0, t) * 0.20) * env * vol
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	return _wav(data)

## Ascending note arpeggio — unlock, milestone, achieve
func _arp3(freqs: Array, note_dur: float, vol: float) -> AudioStreamWAV:
	var note_n := int(note_dur * RATE)
	var n := note_n * freqs.size()
	var data := PackedByteArray(); data.resize(n * 2)
	var atk := int(0.003 * RATE)
	for s_idx in range(freqs.size()):
		var freq: float = freqs[s_idx]
		var base := s_idx * note_n
		for i in range(note_n):
			var t := float(base + i) / RATE
			var env := _dec(i, note_n, atk, 1.8)
			var s := _tri(freq, t) * env * vol
			data.encode_s16((base + i) * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	return _wav(data)

## Simultaneous chord strike — prestige
func _chord(freqs: Array, dur: float, vol: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray(); data.resize(n * 2)
	var atk := int(0.008 * RATE)
	var sz := freqs.size()
	for i in range(n):
		var t := float(i) / RATE
		var env := _dec(i, n, atk, 1.6)
		var mix := 0.0
		for f in freqs:
			var fv: float = float(f)
			mix += _sine(fv, t)
		mix /= float(sz)
		data.encode_s16(i * 2, int(clampf(mix * env * vol, -1.0, 1.0) * 32767.0))
	return _wav(data)

## Filtered noise burst — tick
func _noise(dur: float, vol: float, decay: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray(); data.resize(n * 2)
	var prev := 0.0
	for i in range(n):
		var env := pow(1.0 - float(i) / n, decay)
		var raw := randf() * 2.0 - 1.0
		prev = lerpf(prev, raw, 0.3)
		data.encode_s16(i * 2, int(clampf(prev * env * vol, -1.0, 1.0) * 32767.0))
	return _wav(data)

## Ambient looping pad — C minor chord, mono, 4 s
func _pad(dur: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray(); data.resize(n * 2)
	for i in range(n):
		var t := float(i) / RATE
		var lfo := 0.82 + 0.18 * sin(TAU * 0.14 * t)
		# C3 + Eb3 + G3 (C minor triad) — 3 sin calls per sample
		var s := (sin(TAU * 130.81 * t) + 0.55 * sin(TAU * 155.56 * t) + 0.45 * sin(TAU * 196.00 * t)) / 2.0
		data.encode_s16(i * 2, int(clampf(s * lfo * 0.52, -1.0, 1.0) * 32767.0))
	var st := _wav(data)
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_begin = 0; st.loop_end = n - 1
	return st

func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS; st.mix_rate = RATE
	st.stereo = false; st.data = data; return st

# ── Persistence ───────────────────────────────────────────────────────────────

func to_dict() -> Dictionary:
	return {"muted": muted, "music_vol": music_vol, "sfx_vol": sfx_vol}

func from_dict(d: Dictionary) -> void:
	muted = bool(d.get("muted", false))
	music_vol = float(d.get("music_vol", -20.0))
	sfx_vol = float(d.get("sfx_vol", 0.0))
