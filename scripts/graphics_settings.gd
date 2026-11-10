extends RefCounted

const SAVE_PATH := "user://graphics_settings.cfg"
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const SCALES := [0.65, 0.85, 1.0]
const MSAA := [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X]
const DEFAULTS := {"resolution": 0, "fullscreen": false, "detail": 2, "antialiasing": 1, "vsync": true}

static func load_settings() -> Dictionary:
	var cfg := ConfigFile.new()
	var result := DEFAULTS.duplicate()
	if cfg.load(SAVE_PATH) == OK:
		for key in DEFAULTS:
			result[key] = cfg.get_value("graphics", key, DEFAULTS[key])
	result["resolution"] = clampi(int(result["resolution"]), 0, RESOLUTIONS.size() - 1)
	result["detail"] = clampi(int(result["detail"]), 0, SCALES.size() - 1)
	result["antialiasing"] = clampi(int(result["antialiasing"]), 0, MSAA.size() - 1)
	result["fullscreen"] = bool(result["fullscreen"])
	result["vsync"] = bool(result["vsync"])
	return result

static func save_settings(settings: Dictionary) -> Error:
	var cfg := ConfigFile.new()
	for key in DEFAULTS:
		cfg.set_value("graphics", key, settings.get(key, DEFAULTS[key]))
	return cfg.save(SAVE_PATH)

static func apply(settings: Dictionary, viewport: Viewport) -> void:
	var resolution: Vector2i = RESOLUTIONS[clampi(int(settings["resolution"]), 0, RESOLUTIONS.size() - 1)]
	if bool(settings["fullscreen"]):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(resolution)
	var detail := clampi(int(settings["detail"]), 0, SCALES.size() - 1)
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = SCALES[detail]
	var aa := clampi(int(settings["antialiasing"]), 0, MSAA.size() - 1)
	viewport.msaa_3d = MSAA[aa]
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(settings["vsync"]) else DisplayServer.VSYNC_DISABLED)
