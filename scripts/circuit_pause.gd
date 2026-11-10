extends Node3D

const PAUSE_MENU := preload("res://scripts/pause_menu.gd")

func _ready() -> void:
	var pause := PAUSE_MENU.new()
	pause.name = "PauseMenu"
	add_child(pause)
