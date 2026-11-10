extends Control

const VEHICLE_CATALOG := preload("res://scripts/vehicle_catalog.gd")
const GRAPHICS := preload("res://scripts/graphics_settings.gd")
const UI_FONT := preload("res://assets/kenney_ui-pack-space-expansion/Font/Kenney Future Narrow.ttf")
const CIRCUIT_RECORDS := preload("res://scripts/circuit_records.gd")
const PROGRESSION := preload("res://scripts/progression.gd")
const LEADERBOARD_PATH := "user://mountain_leaderboards.cfg"

@onready var main_menu: VBoxContainer = %MainMenu
@onready var track_select_menu: VBoxContainer = %TrackSelectMenu
var car_select_menu: VBoxContainer
@onready var single_player_button: Button = %SinglePlayerButton
@onready var circuit_button: Button = %CircuitButton
@onready var bgm: AudioStreamPlayer = %BGM
@onready var now_playing_label: Label = %NowPlayingLabel

var _is_transitioning: bool = false
var _settings: Dictionary
var _options_panel: Control
var _leaderboard_panel: Control
var _rebind_action := ""
var _rebind_button: Button


func _ready() -> void:
	_load_controls()
	_settings = GRAPHICS.load_settings()
	GRAPHICS.apply(_settings, get_viewport())
	GRAPHICS.apply_world(_settings, get_tree().root)
	$Center.anchor_left = 0.0
	$Center.anchor_right = 1.0
	$Center.anchor_top = 0.49
	$Center.anchor_bottom = 0.99
	$Center.offset_left = 0.0
	$Center.offset_right = 0.0
	$Center.offset_top = 0.0
	$Center.offset_bottom = 0.0
	_build_car_select_menu()
	_add_leaderboard_button()
	_setup_now_playing()


func _build_car_select_menu() -> void:
	car_select_menu = VBoxContainer.new()
	car_select_menu.name = "CarSelectMenu"
	car_select_menu.visible = false
	car_select_menu.add_theme_constant_override("separation", 16)
	$Center.add_child(car_select_menu)
	for vehicle_id in ["ae86", "rx7"]:
		var button := Button.new()
		button.custom_minimum_size = Vector2(320, 64)
		button.text = VEHICLE_CATALOG.get_label(vehicle_id)
		button.add_theme_font_size_override("font_size", 24)
		for style_name in ["normal", "hover", "pressed"]:
			button.add_theme_stylebox_override(style_name, circuit_button.get_theme_stylebox(style_name))
		for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			button.add_theme_color_override(color_name, circuit_button.get_theme_color(color_name))
		button.pressed.connect(_select_vehicle.bind(vehicle_id))
		car_select_menu.add_child(button)
	var back := Button.new()
	back.custom_minimum_size = Vector2(320, 64)
	back.text = "BACK"
	back.add_theme_font_size_override("font_size", 24)
	for style_name in ["normal", "hover", "pressed"]:
		back.add_theme_stylebox_override(style_name, circuit_button.get_theme_stylebox(style_name))
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		back.add_theme_color_override(color_name, circuit_button.get_theme_color(color_name))
	back.pressed.connect(_on_car_back_pressed)
	car_select_menu.add_child(back)


func _select_vehicle(vehicle_id: String) -> void:
	if not VEHICLE_CATALOG.set_selected_id(vehicle_id):
		return
	car_select_menu.visible = false
	track_select_menu.visible = true
	track_select_menu.mouse_filter = Control.MOUSE_FILTER_PASS
	circuit_button.grab_focus()


func _on_car_back_pressed() -> void:
	car_select_menu.visible = false
	main_menu.visible = true
	single_player_button.grab_focus()


func _setup_now_playing() -> void:
	if not now_playing_label:
		return

	var title: String = ""
	if bgm and bgm.stream:
		var res_path: String = bgm.stream.resource_path
		if res_path != "":
			title = res_path.get_file().get_basename()
		elif bgm.stream.resource_name != "":
			title = bgm.stream.resource_name

	if title == "":
		title = "Dejavu-remix-_menù-edit_"

	now_playing_label.text = "Now Playing: " + title
	now_playing_label.modulate = Color(1.0, 1.0, 1.0, 1.0)

	var tween := create_tween()
	# Rimane visibile per 5 secondi, poi svanisce in dissolvenza (fade out di 1 secondo)
	tween.tween_interval(5.0)
	tween.tween_property(now_playing_label, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: now_playing_label.visible = false)


func _on_single_player_pressed() -> void:
	main_menu.visible = false
	car_select_menu.visible = true
	(car_select_menu.get_child(0) as Button).grab_focus()


func _on_circuit_pressed() -> void:
	_start_track("res://scenes/main.tscn")


func _on_mountain_pressed() -> void:
	_start_track("res://scenes/test_mountain.tscn")


func _on_mountain_night_pressed() -> void:
	_start_track("res://scenes/test_mountain_night.tscn")


func _start_track(scene_path: String) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true

	# Disabilita l'interazione durante il fadeout
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	if bgm and bgm.playing:
		var tween := create_tween()
		tween.tween_property(bgm, "volume_db", -80.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tween.finished

	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("Could not load track %s: %d" % [scene_path, error])
		_is_transitioning = false
		mouse_filter = Control.MOUSE_FILTER_PASS


func _on_back_pressed() -> void:
	if _is_transitioning:
		return
	track_select_menu.visible = false
	car_select_menu.visible = true
	(car_select_menu.get_child(0) as Button).grab_focus()


func _on_option_pressed() -> void:
	main_menu.visible = false
	_options_panel = _make_overlay("GRAPHICS OPTIONS")
	var content := _options_panel.get_meta("content") as VBoxContainer
	_add_choice(content, "RESOLUTION", ["1280 x 720", "1600 x 900", "1920 x 1080", "2560 x 1440"], "resolution")
	_add_choice(content, "DETAIL / RENDER SCALE", ["LOW (65%)", "MEDIUM (85%)", "HIGH (100%)"], "detail")
	_add_choice(content, "ANTI-ALIASING", ["OFF", "MSAA 2X", "MSAA 4X"], "antialiasing")
	_add_choice(content, "DISPLAY MODE", ["WINDOWED", "FULLSCREEN"], "fullscreen")
	_add_choice(content, "V-SYNC", ["OFF", "ON"], "vsync")
	_add_choice(content, "GHOST CAR", ["OFF", "ON"], "ghost")
	_add_choice(content, "SHADOWS", ["OFF", "ON", "HIGH"], "shadows")
	_add_choice(content, "SSAO", ["OFF", "ON"], "ssao")
	_add_choice(content, "VEGETATION", ["LOW", "MEDIUM", "HIGH"], "vegetation")
	_add_choice(content, "MUSIC VOLUME", ["0%", "25%", "50%", "75%", "100%"], "music_volume")
	_add_choice(content, "EFFECTS VOLUME", ["0%", "25%", "50%", "75%", "100%"], "effects_volume")
	for action in ["forward", "back", "left", "right", "bounce"]:
		var bind_button := _styled_button("REMAP " + action.to_upper())
		bind_button.pressed.connect(_start_rebind.bind(action, bind_button))
		content.add_child(bind_button)
	var back := _styled_button("SAVE & BACK")
	back.pressed.connect(func() -> void:
		var error := GRAPHICS.save_settings(_settings)
		if error != OK:
			push_warning("Unable to save graphics settings: %s" % error)
		_rebind_action = ""
		_options_panel.queue_free()
		_options_panel = null
		main_menu.visible = true
		single_player_button.grab_focus()
	)
	content.add_child(back)


func _add_leaderboard_button() -> void:
	var button := _styled_button("LEADERBOARD")
	main_menu.add_child(button)
	main_menu.move_child(button, 1)
	button.pressed.connect(_open_leaderboard)


func _styled_button(label: String) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(320, 64)
	button.add_theme_font_size_override("font_size", 24)
	for state in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, circuit_button.get_theme_stylebox("hover" if state == "focus" else state))
	for color in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(color, Color.BLACK)
	return button


func _make_overlay(title: String) -> Control:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.05, 0.09, 0.93)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(640, 540)
	scroll.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	center.add_child(scroll)
	var content := VBoxContainer.new()
	content.custom_minimum_size.x = 600
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)
	var heading := Label.new()
	heading.text = title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_override("font", UI_FONT)
	heading.add_theme_font_size_override("font_size", 38)
	content.add_child(heading)
	overlay.set_meta("content", content)
	return overlay


func _add_choice(parent: VBoxContainer, label_text: String, options: Array[String], key: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 260
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", 20)
	row.add_child(label)
	var choice := OptionButton.new()
	choice.custom_minimum_size = Vector2(220, 42)
	for option in options:
		choice.add_item(option)
	choice.select(int(round(float(_settings[key]) / 25.0)) if key.ends_with("_volume") else (1 if bool(_settings[key]) else 0) if key in ["fullscreen", "vsync", "ghost", "ssao"] else int(_settings[key]))
	choice.item_selected.connect(func(index: int) -> void:
		_settings[key] = (index * 25) if key.ends_with("_volume") else (index == 1) if key in ["fullscreen", "vsync", "ghost", "ssao"] else index
		GRAPHICS.apply(_settings, get_viewport())
		GRAPHICS.apply_world(_settings, get_tree().root)
	)
	row.add_child(choice)


func _open_leaderboard() -> void:
	main_menu.visible = false
	_leaderboard_panel = _make_overlay("LOCAL LEADERBOARDS")
	var content := _leaderboard_panel.get_meta("content") as VBoxContainer
	var cfg := ConfigFile.new()
	var err := cfg.load(LEADERBOARD_PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		push_warning("Could not read leaderboards: %s" % err)
	var circuit_title := Label.new()
	circuit_title.text = "CIRCUIT - 3 LAPS"
	content.add_child(circuit_title)
	var circuit_runs := CIRCUIT_RECORDS.top()
	for i in circuit_runs.size():
		var run: Dictionary = circuit_runs[i]
		var line := Label.new()
		line.text = "%02d  %s  %.2f s" % [i + 1, str(run.get("car", "?")), float(run.get("time", 0.0))]
		content.add_child(line)
	if circuit_runs.is_empty():
		var empty_circuit := Label.new()
		empty_circuit.text = "NO CIRCUIT RECORDS YET"
		content.add_child(empty_circuit)
	for track in ["mountain_500m", "mountain_night_500m"]:
		var heading := Label.new()
		heading.text = "MOUNTAIN DAY" if track == "mountain_500m" else "MOUNTAIN NIGHT"
		heading.add_theme_font_override("font", UI_FONT)
		heading.add_theme_font_size_override("font_size", 24)
		content.add_child(heading)
		var raw: Variant = cfg.get_value(track, "runs", [])
		var runs: Array = raw if raw is Array else []
		if runs.is_empty():
			var empty := Label.new()
			empty.text = "NO COMPLETED RUNS YET"
			content.add_child(empty)
		else:
			for index in range(mini(runs.size(), 10)):
				var run: Variant = runs[index]
				if not run is Dictionary:
					continue
				var score := int(run.get("score", 0))
				var seconds := float(run.get("time", 0.0))
				var car := VEHICLE_CATALOG.get_label(str(run.get("car", "ae86")))
				var line := Label.new()
				line.text = "%02d  %-18s  %02d:%05.2f  %d PTS" % [index + 1, car, int(seconds / 60.0), fmod(seconds, 60.0), score]
				line.add_theme_font_override("font", UI_FONT)
				line.add_theme_font_size_override("font_size", 18)
				content.add_child(line)
	var profile := PROGRESSION.read()
	var profile_heading := Label.new()
	profile_heading.text = "DRIVER PROFILE"
	profile_heading.add_theme_font_override("font", UI_FONT)
	profile_heading.add_theme_font_size_override("font_size", 24)
	content.add_child(profile_heading)
	var total := Label.new()
	total.text = "COMPLETED RACES: %d   RACE TIME: %.1f MIN" % [int(profile.get_value("global", "total_races", 0)), float(profile.get_value("global", "total_race_seconds", 0.0)) / 60.0]
	content.add_child(total)
	for section in profile.get_sections():
		if section == "global":
			continue
		var best_time := float(profile.get_value(section, "best_time", 0.0))
		var best_score := int(profile.get_value(section, "best_score", 0))
		var medals: Dictionary = profile.get_value(section, "medals", {})
		var line := Label.new()
		line.text = "%s  |  BEST %.2f s  |  SCORE %d  |  %s" % [section.to_upper(), best_time, best_score, str(medals.keys())]
		content.add_child(line)
	var achievements: Dictionary = profile.get_value("global", "achievements", {})
	var achievements_label := Label.new()
	achievements_label.text = "ACHIEVEMENTS: " + (str(achievements.keys()) if not achievements.is_empty() else "NONE YET")
	content.add_child(achievements_label)
	var back := _styled_button("BACK")
	back.pressed.connect(func() -> void:
		_leaderboard_panel.queue_free()
		_leaderboard_panel = null
		main_menu.visible = true
		single_player_button.grab_focus()
	)
	content.add_child(back)


func _start_rebind(action: String, button: Button) -> void:
	_rebind_action = action
	_rebind_button = button
	button.text = "PRESS A KEY FOR " + action.to_upper()

func _input(event: InputEvent) -> void:
	if _rebind_action.is_empty():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_rebind_action = ""
			_rebind_button.text = "REMAP CANCELLED"
			get_viewport().set_input_as_handled()
			return
		var mapped := InputEventKey.new()
		mapped.physical_keycode = event.physical_keycode
		var events := InputMap.action_get_events(_rebind_action)
		for old in events:
			if old is InputEventKey:
				InputMap.action_erase_event(_rebind_action, old)
		InputMap.action_add_event(_rebind_action, mapped)
		var cfg := ConfigFile.new()
		cfg.load("user://controls.cfg")
		cfg.set_value("keys", _rebind_action, event.physical_keycode)
		cfg.save("user://controls.cfg")
		_rebind_button.text = "REMAP " + _rebind_action.to_upper() + ": " + event.as_text()
		_rebind_action = ""
		get_viewport().set_input_as_handled()

func _load_controls() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://controls.cfg") != OK:
		return
	for action in ["forward", "back", "left", "right", "bounce"]:
		var code := int(cfg.get_value("keys", action, 0))
		if code == 0:
			continue
		for old in InputMap.action_get_events(action):
			if old is InputEventKey:
				InputMap.action_erase_event(action, old)
		var mapped := InputEventKey.new()
		mapped.physical_keycode = code
		InputMap.action_add_event(action, mapped)
