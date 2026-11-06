extends Control

@onready var main_menu: VBoxContainer = %MainMenu
@onready var track_select_menu: VBoxContainer = %TrackSelectMenu
@onready var single_player_button: Button = %SinglePlayerButton
@onready var circuit_button: Button = %CircuitButton
@onready var bgm: AudioStreamPlayer = %BGM
@onready var now_playing_label: Label = %NowPlayingLabel

var _is_transitioning: bool = false


func _ready() -> void:
	_setup_now_playing()


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
	track_select_menu.visible = true
	circuit_button.grab_focus()


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
	main_menu.visible = true
	single_player_button.grab_focus()


func _on_option_pressed() -> void:
	pass
