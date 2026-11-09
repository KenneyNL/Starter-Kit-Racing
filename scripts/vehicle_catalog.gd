class_name VehicleCatalog
extends RefCounted

const SETTINGS_PATH := "user://vehicle.cfg"
const SECTION := "gameplay"
const KEY_SELECTED_VEHICLE := "selected_vehicle"
const DEFAULT_VEHICLE_ID := "ae86"

const VEHICLE_LABELS := {
	"ae86": "TOYOTA AE86",
	"rx7": "MAZDA RX-7",
}


static func get_selected_id() -> String:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return DEFAULT_VEHICLE_ID

	var vehicle_id := str(config.get_value(SECTION, KEY_SELECTED_VEHICLE, DEFAULT_VEHICLE_ID))
	return vehicle_id if VEHICLE_LABELS.has(vehicle_id) else DEFAULT_VEHICLE_ID


static func get_selected_label() -> String:
	return get_label(get_selected_id())


static func get_label(vehicle_id: String) -> String:
	return str(VEHICLE_LABELS.get(vehicle_id, VEHICLE_LABELS[DEFAULT_VEHICLE_ID]))


static func set_selected_id(vehicle_id: String) -> bool:
	if not VEHICLE_LABELS.has(vehicle_id):
		return false
	var config := ConfigFile.new()
	var load_error := config.load(SETTINGS_PATH)
	if load_error != OK and load_error != ERR_FILE_NOT_FOUND:
		push_warning("VehicleCatalog: could not load vehicle settings (error %d)." % load_error)
	config.set_value(SECTION, KEY_SELECTED_VEHICLE, vehicle_id)
	var save_error := config.save(SETTINGS_PATH)
	if save_error != OK:
		push_warning("VehicleCatalog: could not save vehicle selection (error %d)." % save_error)
		return false
	return true


static func toggle_selected_vehicle() -> String:
	var next_id := "rx7" if get_selected_id() == "ae86" else "ae86"
	var config := ConfigFile.new()
	var load_error := config.load(SETTINGS_PATH)
	if load_error != OK and load_error != ERR_FILE_NOT_FOUND:
		push_warning("VehicleCatalog: could not load vehicle settings (error %d)." % load_error)
		return get_selected_id()

	config.set_value(SECTION, KEY_SELECTED_VEHICLE, next_id)
	var save_error := config.save(SETTINGS_PATH)
	if save_error != OK:
		push_warning("VehicleCatalog: could not save vehicle selection (error %d)." % save_error)
		return get_selected_id()

	return next_id
