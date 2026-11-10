extends CanvasLayer

# Schermata di riepilogo a fine gara: tempo e tempo passato a ogni livello della Drift Bar.
# Stessi asset della Drift Bar (pannello vetro, segmenti, font) e del menu (bottoni, cursore).
# Mette il gioco in pausa; RIPROVA ricarica la scena, MENU torna al menu principale.

const PANEL_TEXTURE := preload("res://assets/kenney_ui-pack-space-expansion/PNG/Extra/panel_glass.png")
const SEGMENT_OFF := preload("res://assets/kenney_ui-pack-space-expansion/PNG/Extra/bar_shadow_square_outline_small_square.png")
const SEGMENT_ON := preload("res://assets/kenney_ui-pack-space-expansion/PNG/Blue/bar_square_gloss_small_square.png")
const FONT := preload("res://assets/kenney_ui-pack-space-expansion/Font/Kenney Future Narrow.ttf")
const BUTTON_NORMAL := preload("res://assets/ui/button_normal.png")
const BUTTON_ACTIVE := preload("res://assets/ui/button_active.png")
const CURSOR := preload("res://assets/ui/cursor_h.png")
const VEHICLE_CATALOG := preload("res://scripts/vehicle_catalog.gd")
const MENU_SCENE := "res://scenes/menu.tscn"
const TEXT_COLOR := Color(0.2, 0.24, 0.35)   # stesso colore del testo della Drift Bar
const RETRY_META := "deja_vu_mountain_retry"

var retry_button: Button


# time_s: durata della gara in secondi.
# bar_time[n]: secondi di derapata effettiva al livello n (n = 0 .. DriftBar.SEGMENTS).
func show_results(time_s: float, bar_time: PackedFloat32Array, impacts: int, ranking: Dictionary) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	var total := 0.0
	for v in bar_time:
		total += v
	total = maxf(total, 0.001)
	var drift_total := total - bar_time[0]

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.set("mouse_default_cursor_texture", CURSOR)   # stesso cursore del menu
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var style := StyleBoxTexture.new()
	style.texture = PANEL_TEXTURE
	style.modulate_color = Color(1.0, 1.0, 1.0, 0.88)
	style.set_texture_margin_all(16)
	style.content_margin_left = 40
	style.content_margin_right = 40
	style.content_margin_top = 26
	style.content_margin_bottom = 26
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	box.add_child(_label("FINISH", 44))
	box.add_child(_label("%d PTS   /   %s" % [ranking.score, format_time(time_s)], 30))
	if ranking.saved and int(ranking.rank) <= 3:
		box.add_child(_podium_banner(int(ranking.rank)))
	box.add_child(HSeparator.new())

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 36)
	box.add_child(columns)

	var stats := VBoxContainer.new()
	stats.add_theme_constant_override("separation", 6)
	columns.add_child(stats)
	stats.add_child(_label("DRIFT TIME PER BAR", 20))

	for level in range(1, DriftBar.SEGMENTS + 1):
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 16)
		var segs := HBoxContainer.new()
		segs.add_theme_constant_override("separation", 3)
		for k in DriftBar.SEGMENTS:
			var seg := TextureRect.new()
			seg.custom_minimum_size = Vector2(18, 26)
			seg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			seg.stretch_mode = TextureRect.STRETCH_SCALE
			seg.texture = SEGMENT_ON if k < level else SEGMENT_OFF
			segs.add_child(seg)
		row.add_child(segs)
		var pct := _label("%.1f%%" % (100.0 * bar_time[level] / total), 22, HORIZONTAL_ALIGNMENT_RIGHT)
		pct.custom_minimum_size = Vector2(96, 0)
		row.add_child(pct)
		stats.add_child(row)

	stats.add_child(_label("TOTAL DRIFT  %.1f%%" % (100.0 * drift_total / total), 20))
	stats.add_child(_label("IMPACTS  %d" % impacts, 20))
	columns.add_child(VSeparator.new())
	columns.add_child(_leaderboard(ranking))

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	retry_button = _button("RETRY")
	retry_button.pressed.connect(_retry)
	buttons.add_child(retry_button)
	var menu_button := _button("MENU")
	menu_button.pressed.connect(_menu)
	buttons.add_child(menu_button)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	box.add_child(spacer)
	box.add_child(buttons)

	get_tree().paused = true
	retry_button.call_deferred("grab_focus")


func _leaderboard(ranking: Dictionary) -> VBoxContainer:
	var board := VBoxContainer.new()
	board.custom_minimum_size.x = 440
	board.add_theme_constant_override("separation", 5)
	board.add_child(_label("LOCAL LEADERBOARD", 20))
	var status := "YOUR RANK  #%d" % ranking.rank if ranking.saved else "RESULT NOT SAVED"
	board.add_child(_label(status, 18))
	for index in ranking.top.size():
		var run: Dictionary = ranking.top[index]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		board.add_child(row)
		var fields := [
			["%02d" % (index + 1), 26],
			[VEHICLE_CATALOG.get_label(run.car), 132],
			[format_time(run.time), 84],
			["%d PTS" % run.score, 86],
		]
		for field in fields:
			var label := _label(field[0], 16)
			label.custom_minimum_size.x = field[1]
			if ranking.saved and index + 1 == ranking.rank:
				label.add_theme_color_override("font_color", Color(0.08, 0.24, 0.64))
			row.add_child(label)
	return board


func _podium_banner(rank: int) -> PanelContainer:
	var names := ["GOLD PODIUM", "SILVER PODIUM", "BRONZE PODIUM"]
	var colors := [
		Color(0.90, 0.68, 0.16),
		Color(0.70, 0.73, 0.78),
		Color(0.72, 0.42, 0.20),
	]
	var index := clampi(rank - 1, 0, 2)
	var style := StyleBoxTexture.new()
	style.texture = BUTTON_NORMAL
	style.set_texture_margin_all(6)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	var medal := TextureRect.new()
	medal.texture = _make_medal_texture(colors[index])
	medal.custom_minimum_size = Vector2(42, 48)
	medal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	medal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(medal)

	var message := _label("%s  •  #%d LOCAL" % [names[index], rank], 22)
	message.add_theme_color_override("font_color", Color.BLACK)
	row.add_child(message)
	return panel


func _make_medal_texture(medal_color: Color) -> ImageTexture:
	var image := Image.create(48, 56, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var ribbon := Color(0.12, 0.22, 0.44)
	for y in range(0, 24):
		var inset := int(float(y) * 0.18)
		for x in range(9 + inset, 22):
			image.set_pixel(x, y, ribbon)
		for x in range(26, 39 - inset):
			image.set_pixel(x, y, ribbon)
	var center := Vector2(24, 34)
	for y in range(14, 54):
		for x in range(4, 44):
			var d := Vector2(x, y).distance_to(center)
			if d <= 18.0:
				var col := medal_color.lightened(0.16) if d < 13.5 else medal_color.darkened(0.20)
				image.set_pixel(x, y, col)
	for y in range(26, 42):
		for x in range(19, 29):
			if abs(x - 24) + abs(y - 34) < 8:
				image.set_pixel(x, y, medal_color.darkened(0.36))
	return ImageTexture.create_from_image(image)


static func format_time(t: float) -> String:
	return "%02d:%05.2f" % [int(t / 60.0), fmod(t, 60.0)]


func _label(text: String, size: int, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", TEXT_COLOR)
	return l


# Bottone con lo stesso stile del menu (texture 9-slice, testo nero, 24 px).
func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(200, 56)
	b.add_theme_font_size_override("font_size", 24)
	var normal := StyleBoxTexture.new()
	normal.texture = BUTTON_NORMAL
	normal.set_texture_margin_all(6)
	var active := StyleBoxTexture.new()
	active.texture = BUTTON_ACTIVE
	active.set_texture_margin_all(6)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", active)
	b.add_theme_stylebox_override("pressed", active)
	b.add_theme_stylebox_override("focus", active)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, Color.BLACK)
	return b


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_R:
			_retry()
		elif event.physical_keycode == KEY_ESCAPE:
			_menu()


func _retry() -> void:
	get_tree().paused = false
	get_tree().set_meta(RETRY_META, true)
	get_tree().reload_current_scene()


func _menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)
