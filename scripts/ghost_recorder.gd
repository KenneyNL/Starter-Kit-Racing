extends RefCounted

const ROOT := "user://ghost_"
const SAMPLE_INTERVAL := 0.10
const MAX_SAMPLES := 12000

static func _path(track: String, car: String) -> String:
	return ROOT + track.validate_filename() + "_" + car.validate_filename() + ".dat"

static func load_best(track: String, car: String) -> Dictionary:
	var file := FileAccess.open(_path(track, car), FileAccess.READ)
	if file == null:
		return {}
	var value: Variant = file.get_var()
	if value is Dictionary and value.has("frames") and value.has("time"):
		return value
	return {}

static func save_best(track: String, car: String, time_s: float, frames: Array) -> bool:
	if frames.is_empty():
		return false
	var old := load_best(track, car)
	if not old.is_empty() and float(old.get("time", INF)) <= time_s:
		return false
	var file := FileAccess.open(_path(track, car), FileAccess.WRITE)
	if file == null:
		return false
	file.store_var({"time": time_s, "frames": frames})
	return true
