class_name NowPlayingBanner extends Control

# Banner "Now Playing: [Titolo]" in basso a destra.
# Stesso stile/font del menu, colore nero, compare e si dissolve dopo 5 secondi.

const FONT := preload("res://assets/kenney_ui-pack-space-expansion/Font/Kenney Future Narrow.ttf")

@export var audio_player_path: NodePath
@export var hold_time: float = 5.0
@export var fade_time: float = 1.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var player: AudioStreamPlayer = null
	if has_node(audio_player_path):
		player = get_node(audio_player_path) as AudioStreamPlayer
	if player == null:
		# Cerca un AudioStreamPlayer nei vicini o nel parent
		player = get_parent().get_node_or_null("BGM") as AudioStreamPlayer

	var title := ""
	if player and player.stream:
		var p := player.stream.resource_path
		if p != "":
			title = p.get_file().get_basename()
		elif player.stream.resource_name != "":
			title = player.stream.resource_name

	if title == "":
		title = "Music"

	var label := Label.new()
	label.name = "NowPlayingLabel"
	label.text = "Now Playing: " + title
	label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	label.offset_left = -600.0
	label.offset_top = -50.0
	label.offset_right = -24.0
	label.offset_bottom = -20.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.add_theme_color_override("font_color", Color(0, 0, 0, 1))
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 18)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

	var tween := create_tween()
	tween.tween_interval(hold_time)
	tween.tween_property(label, "modulate:a", 0.0, fade_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: queue_free())

