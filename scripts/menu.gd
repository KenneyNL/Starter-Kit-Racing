extends Control

@onready var main_menu: VBoxContainer = %MainMenu
@onready var track_select_menu: VBoxContainer = %TrackSelectMenu
@onready var single_player_button: Button = %SinglePlayerButton
@onready var circuit_button: Button = %CircuitButton


func _on_single_player_pressed() -> void:
	main_menu.visible = false
	track_select_menu.visible = true
	circuit_button.grab_focus()


func _on_circuit_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_mountain_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/test_mountain.tscn")


func _on_back_pressed() -> void:
	track_select_menu.visible = false
	main_menu.visible = true
	single_player_button.grab_focus()


func _on_option_pressed() -> void:
	pass
