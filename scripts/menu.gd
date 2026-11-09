extends Control

const VEHICLE_CATALOG := preload("res://scripts/vehicle_catalog.gd")

@onready var main_menu: VBoxContainer = %MainMenu
@onready var track_select_menu: VBoxContainer = %TrackSelectMenu
var car_select_menu: VBoxContainer
@onready var single_player_button: Button = %SinglePlayerButton
@onready var circuit_button: Button = %CircuitButton
@onready var bgm: AudioStreamPlayer = %BGM
@onready var now_playing_label: Label = %NowPlayingLabel

var _is_transitioning: bool = false


func _ready() -> void:
	_build_car_select_menu()
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

	get_tree().change_scene_to_file(scene_path)


func _on_back_pressed() -> void:
	if _is_transitioning:
		return
	track_select_menu.visible = false
	car_select_menu.visible = true
	(car_select_menu.get_child(0) as Button).grab_focus()


func _on_option_pressed() -> void:
	pass
