extends RefCounted

const SAVE_PATH := "user://circuit_leaderboard.cfg"

static func record(car: String, seconds: float, laps: Array) -> Dictionary:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	var raw: Variant = cfg.get_value("circuit", "runs", [])
	var runs: Array = raw if raw is Array else []
	var entry := {"car": car, "time": seconds, "laps": laps.duplicate()}
	runs.append(entry)
	runs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("time", INF)) < float(b.get("time", INF)))
	if runs.size() > 10:
		runs.resize(10)
	cfg.set_value("circuit", "runs", runs)
	var error := cfg.save(SAVE_PATH)
	if error != OK:
		push_warning("Could not save circuit leaderboard: %d" % error)
	return {"rank": runs.find(entry) + 1, "saved": error == OK, "top": runs}

static func top() -> Array:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return []
	var value: Variant = cfg.get_value("circuit", "runs", [])
	return value if value is Array else []
