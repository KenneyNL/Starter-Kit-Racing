extends CanvasLayer

const MENU_SCENE := "res://scenes/menu.tscn"
const FONT := preload("res://assets/kenney_ui-pack-space-expansion/Font/Kenney Future Narrow.ttf")
const NORMAL := preload("res://assets/ui/button_normal.png")
const ACTIVE := preload("res://assets/ui/button_active.png")
var overlay: Control
var resume_button: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 25
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.70)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 44)
	box.add_child(title)
	resume_button = _button("RESUME")
	resume_button.pressed.connect(_resume)
	box.add_child(resume_button)
	var restart := _button("RESTART")
	restart.pressed.connect(_restart)
	box.add_child(restart)
	var main_menu := _button("MAIN MENU")
	main_menu.pressed.connect(_main_menu)
	box.add_child(main_menu)

func _button(label: String) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(300, 60)
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", 24)
	var normal := StyleBoxTexture.new()
	normal.texture = NORMAL
	normal.set_texture_margin_all(6)
	var active := StyleBoxTexture.new()
	active.texture = ACTIVE
	active.set_texture_margin_all(6)
	b.add_theme_stylebox_override("normal", normal)
	for state in ["hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(state, active)
	for color in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(color, Color.BLACK)
	return b

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if overlay.visible:
			_resume()
		else:
			_pause()
		get_viewport().set_input_as_handled()

func _pause() -> void:
	if get_tree().paused:
		return
	overlay.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	resume_button.grab_focus()

func _resume() -> void:
	overlay.visible = false
	get_tree().paused = false

func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)
