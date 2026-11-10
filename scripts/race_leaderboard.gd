extends RefCounted

const SAVE_PATH := "user://mountain_leaderboards.cfg"
const TARGET_TIME := 45.0
const IMPACT_PENALTY := 450


static func record_run(track: String, car: String, time_s: float, bar_time: PackedFloat32Array, impacts: int) -> Dictionary:
	var weighted_time := 0.0
	for level in range(1, DriftBar.SEGMENTS + 1):
		weighted_time += bar_time[level] * float(level) / DriftBar.SEGMENTS
	var weighted_drift := clampf(weighted_time / maxf(time_s, 0.001), 0.0, 1.0)
	var time_factor := 2.0 * TARGET_TIME / (TARGET_TIME + time_s)
	var score := maxi(0, roundi((2500.0 + 7500.0 * weighted_drift) * time_factor) - impacts * IMPACT_PENALTY)
	var run := {
		"score": score,
		"time": time_s,
		"car": car,
		"impacts": impacts,
		"bar_time": bar_time,
	}

	var config := ConfigFile.new()
	var load_error := config.load(SAVE_PATH)
	var can_save := load_error == OK or load_error == ERR_FILE_NOT_FOUND
	var stored: Variant = config.get_value(track, "runs", [])
	var runs: Array = stored if stored is Array else []
	runs = runs.filter(_valid_run)
	var index := 0
	while index < runs.size() and not _ranks_ahead(run, runs[index]):
		index += 1
	runs.insert(index, run)
	config.set_value(track, "runs", runs)
	var saved := can_save and _save(config)
	if not saved:
		push_warning("Could not save mountain leaderboard to " + SAVE_PATH)
	return {"score": score, "rank": index + 1, "top": runs.slice(0, 10), "saved": saved}


static func _valid_run(run: Variant) -> bool:
	return run is Dictionary and run.get("score") is int and run.get("time") is float \
		and run.get("impacts") is int and run.get("car") is String


static func _ranks_ahead(a: Dictionary, b: Dictionary) -> bool:
	if a.score != b.score:
		return a.score > b.score
	if a.impacts != b.impacts:
		return a.impacts < b.impacts
	return a.time < b.time


static func _save(config: ConfigFile) -> bool:
	var temp_path := SAVE_PATH + ".tmp"
	if config.save(temp_path) != OK:
		return false
	var error := DirAccess.rename_absolute(temp_path, SAVE_PATH)
	if error != OK:
		DirAccess.remove_absolute(temp_path)
	return error == OK
