extends Node3D

const PAUSE_MENU := preload("res://scripts/pause_menu.gd")
const RECORDS := preload("res://scripts/circuit_records.gd")
const PROGRESSION := preload("res://scripts/progression.gd")
const GHOST := preload("res://scripts/ghost_recorder.gd")
const GRAPHICS := preload("res://scripts/graphics_settings.gd")
const CATALOG := preload("res://scripts/vehicle_catalog.gd")

const LAPS := 3
const CHECKPOINT_RADIUS := 7.0
const MIN_LAP_SECONDS := 8.0
const CHECKPOINTS := [
	Vector3(3.5, 0.0, 5.0),
	Vector3(40.0, 0.0, 5.0),
	Vector3(40.0, 0.0, -35.0),
	Vector3(-30.0, 0.0, -35.0),
	Vector3(-30.0, 0.0, 5.0)
]

var vehicle: VehicleSelectable
var time_s := 0.0
var lap_started := 0.0
var lap_times: Array = []
var next_gate := 1
var was_inside := false
var finished := false
var hud: Label
var ghost_visual: Node3D
var ghost_data: Array = []
var frames: Array = []
var sample_accum := 0.0

func _ready() -> void:
	var pause := PAUSE_MENU.new()
	pause.name = "PauseMenu"
	add_child(pause)
	vehicle = get_node_or_null("Vehicle") as VehicleSelectable
	if vehicle == null:
		push_error("Circuit: VehicleSelectable not found")
		return
	_make_hud()
	_make_gates()
	var settings := GRAPHICS.load_settings()
	if bool(settings.get("ghost", true)):
		var best := GHOST.load_best("circuit", CATALOG.get_selected_id())
		var raw: Variant = best.get("frames", [])
		if raw is Array:
			ghost_data = raw
			if not ghost_data.is_empty():
				_make_ghost()

func _make_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)
	hud = Label.new()
	hud.position = Vector2(24, 24)
	hud.add_theme_font_size_override("font_size", 26)
	canvas.add_child(hud)
	_update_hud()

func _make_gates() -> void:
	for i in CHECKPOINTS.size():
		var marker := MeshInstance3D.new()
		marker.name = "CircuitGate%d" % i
		var mesh := CylinderMesh.new()
		mesh.top_radius = CHECKPOINT_RADIUS
		mesh.bottom_radius = CHECKPOINT_RADIUS
		mesh.height = 0.12
		marker.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.1, 0.9, 0.95, 0.35) if i == 0 else Color(1.0, 0.7, 0.15, 0.3)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		marker.material_override = material
		marker.position = CHECKPOINTS[i] + Vector3.UP * 0.15
		add_child(marker)

func _make_ghost() -> void:
	ghost_visual = Node3D.new()
	ghost_visual.name = "BestLapGhost"
	add_child(ghost_visual)
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = Vector3(1.7, 0.8, 3.6)
	mesh.mesh = shape
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.1, 0.9, 1.0, 0.3)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = material
	ghost_visual.add_child(mesh)

func _physics_process(delta: float) -> void:
	if finished or vehicle == null or vehicle.sphere == null:
		return
	time_s += delta
	var position := vehicle.sphere.global_position
	var target: Vector3 = CHECKPOINTS[next_gate]
	var inside := Vector2(position.x - target.x, position.z - target.z).length() <= CHECKPOINT_RADIUS
	if inside and not was_inside:
		if next_gate == 0:
			if time_s - lap_started >= MIN_LAP_SECONDS:
				lap_times.append(time_s - lap_started)
				lap_started = time_s
				if lap_times.size() >= LAPS:
					_finish()
				else:
					next_gate = 1
		else:
			next_gate = (next_gate + 1) % CHECKPOINTS.size()
	was_inside = inside
	sample_accum += delta
	if sample_accum >= GHOST.SAMPLE_INTERVAL and frames.size() < GHOST.MAX_SAMPLES:
		sample_accum = 0.0
		frames.append({"t": time_s, "transform": vehicle.vehicle_model.global_transform})
	_update_ghost()
	_update_hud()

func _update_ghost() -> void:
	if ghost_visual == null or ghost_data.is_empty():
		return
	var index := clampi(int(time_s / GHOST.SAMPLE_INTERVAL), 0, ghost_data.size() - 1)
	var frame: Variant = ghost_data[index]
	if frame is Dictionary and frame.has("transform"):
		ghost_visual.global_transform = frame["transform"]

func _update_hud() -> void:
	if hud != null:
		hud.text = "CIRCUIT  |  LAP %d/%d  |  %02d:%05.2f  |  NEXT GATE %d" % [mini(lap_times.size() + 1, LAPS), LAPS, int(time_s / 60.0), fmod(time_s, 60.0), next_gate]

func _finish() -> void:
	finished = true
	var car := CATALOG.get_selected_id()
	var ranking := RECORDS.record(car, time_s, lap_times)
	var progression := PROGRESSION.record("circuit", car, time_s)
	GHOST.save_best("circuit", car, time_s, frames)
	var canvas := CanvasLayer.new()
	canvas.layer = 20
	add_child(canvas)
	var panel := CenterContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title := Label.new()
	title.text = "FINISHED  |  %s  |  %02d:%05.2f  |  RANK %d" % [progression["medal"], int(time_s / 60.0), fmod(time_s, 60.0), int(ranking["rank"])]
	title.add_theme_font_size_override("font_size", 30)
	box.add_child(title)
	for i in lap_times.size():
		var row := Label.new()
		row.text = "LAP %d: %.2f s" % [i + 1, float(lap_times[i])]
		box.add_child(row)
	var restart := Button.new()
	restart.text = "RESTART"
	restart.pressed.connect(func() -> void: get_tree().reload_current_scene())
	box.add_child(restart)
	var menu := Button.new()
	menu.text = "MAIN MENU"
	menu.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/menu.tscn"))
	box.add_child(menu)
