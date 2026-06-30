extends Node
## Daily login rewards and streak tracking (autoload: Daily).

signal streak_updated(days: int)
signal reward_ready()
signal reward_claimed(day_idx: int)

## 7-day rotating rewards (loops every 7 days). Mix of gems, cash, boost, influence.
const REWARDS := [
    {"influence": 15, "label": "+15 🌐 Influência"},
    {"hours": 2,  "label": "+2h 💰"},
    {"gems": 40,  "label": "+40 💎"},
    {"boost": 15, "label": "2× 15min ⚡"},
    {"influence": 25, "gems": 25, "label": "+25 Influência + 25 💎"},
    {"hours": 8,  "label": "+8h 💰"},
    {"gems": 150, "pgems": 1, "label": "+150 💎 + 1 ⬡ Prestige"},
]

# Persisted
var last_claim := ""      # "YYYY-MM-DD"
var streak := 0
var total_days := 0
var pending := false

func _ready() -> void:
    _check_new_day()

func _check_new_day() -> void:
    var today := _today()
    if today == last_claim: return
    var yesterday := _yesterday()
    if last_claim == yesterday:
        streak += 1
    elif last_claim != "":
        streak = 1
    else:
        streak = 1
    total_days += 1
    pending = true
    if has_node("/root/Achievements"):
        Achievements.note_streak(streak, total_days)
    streak_updated.emit(streak)
    reward_ready.emit()

func claim() -> void:
    if not pending: return
    var idx: int = (streak - 1) % REWARDS.size()
    var r: Dictionary = REWARDS[idx]
    if has_node("/root/GameState"):
        if r.has("gems"):      GameState.gems += int(r["gems"])
        if r.has("hours"):     GameState.credits += GameState.income_per_sec() * float(r["hours"]) * 3600.0
        if r.has("boost"):     GameState.earn_boost_timer = float(r["boost"]) * 60.0
        if r.has("influence"):
            GameState.influence += int(r["influence"])
            GameState.influence_total += int(r["influence"])
    if r.has("pgems") and has_node("/root/Prestige"):
        Prestige.pgems += int(r["pgems"])
        Prestige.total_pgems += int(r["pgems"])
    last_claim = _today()
    pending = false
    if has_node("/root/Audio"): Audio.play("milestone")
    reward_claimed.emit(idx)
    SaveSystem.save_game()

func next_reward_idx() -> int:
    return streak % REWARDS.size()

func _today() -> String:
    var d := Time.get_datetime_dict_from_system()
    return "%04d-%02d-%02d" % [int(d["year"]), int(d["month"]), int(d["day"])]

func _yesterday() -> String:
    var ts: int = int(Time.get_unix_time_from_system()) - 86400
    var d := Time.get_datetime_dict_from_unix_time(ts)
    return "%04d-%02d-%02d" % [int(d["year"]), int(d["month"]), int(d["day"])]

func to_dict() -> Dictionary:
    return {"last": last_claim, "streak": streak, "total": total_days, "pending": pending}

func from_dict(d: Dictionary) -> void:
    last_claim = str(d.get("last", ""))
    streak = int(d.get("streak", 0))
    total_days = int(d.get("total", 0))
    pending = bool(d.get("pending", false))
