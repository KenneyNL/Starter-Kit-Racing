extends RefCounted

const SAVE_PATH := "user://progression.cfg"

static func record(track: String, car: String, time_s: float, score: int = 0) -> Dictionary:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	var key := track + "_" + car
	var runs := int(cfg.get_value(key, "runs", 0)) + 1
	var best := float(cfg.get_value(key, "best_time", INF))
	var total := float(cfg.get_value("global", "total_race_seconds", 0.0)) + time_s
	var old_score := int(cfg.get_value(key, "best_score", 0))
	cfg.set_value(key, "runs", runs)
	cfg.set_value(key, "best_time", minf(best, time_s))
	cfg.set_value(key, "best_score", maxi(old_score, score))
	cfg.set_value("global", "total_races", int(cfg.get_value("global", "total_races", 0)) + 1)
	cfg.set_value("global", "total_race_seconds", total)
	var medal := "GOLD" if time_s <= 60.0 else ("SILVER" if time_s <= 90.0 else "BRONZE")
	# Medal thresholds are provisional until calibrated against actual circuit lengths.
	var medals: Dictionary = cfg.get_value(key, "medals", {})
	medals[medal] = true
	cfg.set_value(key, "medals", medals)
	var achievements: Dictionary = cfg.get_value("global", "achievements", {})
	achievements["FIRST_FINISH"] = true
	if runs >= 10:
		achievements["TEN_RUNS_ONE_CAR"] = true
	if cfg.has_section("circuit_ae86") and cfg.has_section("circuit_rx7"):
		achievements["DUAL_DRIVER"] = true
	cfg.set_value("global", "achievements", achievements)
	var error := cfg.save(SAVE_PATH)
	if error != OK:
		push_warning("Could not save progression: %d" % error)
	return {"best": minf(best, time_s), "medal": medal, "runs": runs, "saved": error == OK}

static func read() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	return cfg
