extends Node3D

# Mappa di montagna di prova: la strada segue il Path3D "RoadPath" (modificabile nell'editor).
# Il primo punto del Path3D e' la partenza, l'ultimo il traguardo.
# Non usa main.tscn ne' la GridMap. Tasto R = ricomincia.

const MountainRoad := preload("res://scripts/mountain_road.gd")
const VEHICLE_SCENE := preload("res://scenes/vehicle_selectable.tscn")
const VIEW_SCRIPT := preload("res://scripts/view.gd")
const ENVIRONMENT := preload("res://scenes/main-environment.tres")
const DRIFT_BAR := preload("res://scenes/drift_bar.tscn")
const LEADERBOARD := preload("res://scripts/race_leaderboard.gd")
const RACE_SUMMARY := preload("res://scripts/race_summary.gd")
const NOW_PLAYING_BANNER := preload("res://scenes/now_playing_banner.tscn")
const UI_FONT := preload("res://assets/kenney_ui-pack-space-expansion/Font/Kenney Future Narrow.ttf")
const RETRY_META := "deja_vu_mountain_retry"
const OVERVIEW_DURATION := 4.0

## Velocita' del veicolo su questa mappa (1.0 = quella delle mappe a tile).
@export var speed_multiplier: float = 1.5
## Ingresso progressivo nello sterzo per facilitare le correzioni sui curvoni.
@export_range(0.0, 1.0, 0.01) var steering_ramp_time: float = 0.14
## Fa collidere con muri e alberi anche cofano e coda dell'auto (non solo la sfera di fisica).
@export var body_collision: bool = true
## Distanza dalla partenza (metri lungo la strada) a cui parte l'auto.
@export var spawn_distance: float = 4.0
@export var log_interval: float = 0.5
@export var leaderboard_id: String = "mountain_500m"

@export_group("Vegetation")
## Alberi e cespugli lungo la strada.
@export var enable_vegetation: bool = true
## Tentativi di piazzamento per metro quadro (piu' alto = piu' alberi, ma ne restano meno di quelli tentati).
@export_range(0.0, 0.05, 0.001) var tree_density: float = 0.008
## Distanza minima degli alberi dal centro strada (metri).
@export var min_tree_road_distance: float = 6.0
## Distanza minima tra alberi vicini (metri).
@export var min_tree_spacing: float = 3.5
## Pendenza massima del terreno per piazzare alberi (1.0 = 45 gradi).
@export_range(0.0, 1.0, 0.05) var max_tree_slope: float = 0.8
## Cambiando il seed cambia la disposizione degli alberi.
@export var vegetation_seed: int = 12345

@export_group("Nature Kit")
## Rocce nei tornanti, piu' alberi e vegetazione dal Kenney Nature Kit (oltre a quelli gia' presenti).
@export var enable_nature_kit: bool = true
## Moltiplicatore della densita' di alberi/vegetazione del Nature Kit (1.0 = default).
@export_range(0.0, 3.0, 0.1) var nature_density: float = 1.0
## Emissione dei catarifrangenti dei guardrail (la versione notturna li accende di piu').
@export var reflector_glow: float = 0.6
## Colore del pavimento di base oltre il terreno generato (stesso verde di grass_color).
@export var floor_color := Color(0.22, 0.40, 0.16)

@onready var path: Path3D = $RoadPath

var road: MountainRoad
var vehicle: VehicleSelectable
var race_time: float = 0.0
var racing: bool = true
var race_active: bool = false
var chase_camera: Camera3D
var countdown_layer: CanvasLayer
var impacts: int = 0
## Secondi di derapata effettiva a ogni livello, incluso zero durante una collisione.
var bar_time: PackedFloat32Array = PackedFloat32Array()
var log_timer: float = 0.0


func _ready() -> void:
	bar_time.resize(DriftBar.SEGMENTS + 1)
	_make_world()
	road = MountainRoad.new()
	road.name = "MountainRoad"
	road.path = path
	add_child(road)
	road.enable_vegetation = enable_vegetation
	road.tree_density = tree_density
	road.min_tree_road_distance = min_tree_road_distance
	road.min_tree_spacing = min_tree_spacing
	road.max_tree_slope = max_tree_slope
	road.vegetation_seed = vegetation_seed
	road.enable_nature_kit = enable_nature_kit
	road.nature_density = nature_density
	road.reflector_glow = reflector_glow
	road.finish_reached.connect(_on_finish_reached)
	road.build()
	_make_spectators()
	_make_vehicle_and_camera()
	_prepare_start_sequence()
	_start_sequence.call_deferred()


func _make_world() -> void:
	var we := WorldEnvironment.new()
	we.environment = ENVIRONMENT
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	sun.shadow_enabled = true
	sun.shadow_bias = 0.2
	sun.shadow_normal_bias = 1.0
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)

	# pavimento di base (superficie a y = -0.1, appena sotto il terreno generato)
	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(800.0, 2.0, 800.0)
	cs.shape = box
	cs.position = Vector3(0.0, -1.1, 0.0)
	floor_body.add_child(cs)
	add_child(floor_body)

	var plane := PlaneMesh.new()
	plane.size = Vector2(800.0, 800.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = floor_color
	plane.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.position = Vector3(0.0, -0.1, 0.0)
	add_child(mi)


func _make_spectators() -> void:
	_spawn_crowd("StartCrowd", road.start_transform, 18, 1001, -4.0, 10.0)
	_spawn_crowd("FinishCrowd", road.finish_transform, 16, 2001, -10.0, 5.0)


func _spawn_crowd(node_name: String, anchor: Transform3D, crowd_count: int, seed: int,
		forward_min: float, forward_max: float) -> void:
	var road_dir := anchor.basis.z.normalized()
	var road_side := Vector3(-road_dir.z, 0.0, road_dir.x).normalized()
	var specs := Spectators.new()
	specs.name = node_name
	specs.count = crowd_count
	specs.spread_radius = 12.0
	specs.min_road_distance = 4.2
	specs.forward_min = forward_min
	specs.forward_max = forward_max
	specs.rng_seed = seed
	add_child(specs)
	specs.spawn(anchor.origin, road_dir, road_side, road.finish_transform.origin)


func _make_vehicle_and_camera() -> void:
	# l'auto parte sulla strada, poco dopo la linea di partenza, orientata come il percorso
	var idx := clampi(int(spawn_distance / road.step_length), 0, road.centerline.size() - 1)
	vehicle = VEHICLE_SCENE.instantiate()
	vehicle.speed_multiplier = speed_multiplier
	vehicle.steering_ramp_time = steering_ramp_time
	vehicle.mountain_handling = true
	vehicle.body_collision = body_collision
	vehicle.process_physics_priority = -1
	vehicle.obstacle_hit.connect(_on_obstacle_hit)
	vehicle.position = road.centerline[idx] + Vector3(0.0, 0.2, 0.0)
	vehicle.rotation = road.basis_at(idx).get_euler()
	add_child(vehicle)

	# HUD: stessa Drift Bar di main.tscn, agganciata al veicolo
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	add_child(hud)
	var bar := DRIFT_BAR.instantiate() as DriftBar
	bar.name = "DriftBar"
	bar.target = vehicle
	hud.add_child(bar)

	# banner "Now Playing" come in main.tscn: legge il titolo dal nodo BGM
	var banner := NOW_PLAYING_BANNER.instantiate() as NowPlayingBanner
	banner.audio_player_path = NodePath("../../BGM")
	hud.add_child(banner)

	# Visuale dall'alto orientata verso il prossimo tratto della discesa.
	var view := Node3D.new()
	view.name = "View"
	view.set_script(VIEW_SCRIPT)
	view.set("target", vehicle)
	view.set("road_path", path)
	view.rotation_degrees = Vector3(-35.0, 45.0, 0.0)
	view.position = vehicle.position
	var cam := Camera3D.new()
	chase_camera = cam
	cam.name = "Camera"
	cam.position = Vector3(0.0, 0.0, 16.0)
	cam.fov = 40.0
	cam.far = 400.0
	view.add_child(cam)
	add_child(view)
	cam.current = true


func _prepare_start_sequence() -> void:
	race_active = false
	vehicle.sphere.freeze = true
	vehicle.set_physics_process(false)
	countdown_layer = CanvasLayer.new()
	countdown_layer.name = "StartCountdown"
	countdown_layer.layer = 20
	add_child(countdown_layer)


func _start_sequence() -> void:
	var skip_overview := bool(get_tree().get_meta(RETRY_META, false))
	if get_tree().has_meta(RETRY_META):
		get_tree().remove_meta(RETRY_META)
	if not skip_overview:
		await _play_track_overview()
	chase_camera.current = true
	await _play_countdown()
	vehicle.sphere.freeze = false
	vehicle.set_physics_process(true)
	race_active = true


func _play_track_overview() -> void:
	if road.centerline.is_empty():
		return
	var minp := road.to_global(road.centerline[0])
	var maxp := minp
	for p in road.centerline:
		var gp := road.to_global(p)
		minp = minp.min(gp)
		maxp = maxp.max(gp)
	var center := (minp + maxp) * 0.5
	var span := maxf(Vector2(maxp.x - minp.x, maxp.z - minp.z).length(), 60.0)
	var overview := Camera3D.new()
	overview.name = "TrackOverviewCamera"
	overview.fov = 48.0
	overview.far = 900.0
	add_child(overview)
	var start_pos := center + Vector3(-span * 0.42, span * 0.55 + 28.0, -span * 0.28)
	var end_pos := center + Vector3(span * 0.38, span * 0.42 + 22.0, span * 0.32)
	overview.global_position = start_pos
	overview.look_at(center, Vector3.UP)
	overview.current = true
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(_update_overview.bind(overview, start_pos, end_pos, center), 0.0, 1.0, OVERVIEW_DURATION)
	await tween.finished
	overview.queue_free()


func _update_overview(weight: float, camera: Camera3D, start_pos: Vector3, end_pos: Vector3, center: Vector3) -> void:
	camera.global_position = start_pos.lerp(end_pos, weight)
	camera.look_at(center, Vector3.UP)


func _play_countdown() -> void:
	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.position = Vector2(-100.0, -72.0)
	label.size = Vector2(200.0, 144.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", 88)
	label.add_theme_color_override("font_color", Color(0.96, 0.96, 0.92))
	label.add_theme_color_override("font_outline_color", Color(0.06, 0.08, 0.12, 0.95))
	label.add_theme_constant_override("outline_size", 8)
	countdown_layer.add_child(label)
	for n in [3, 2, 1]:
		label.text = str(n)
		label.scale = Vector2(1.18, 1.18)
		var pulse := create_tween()
		pulse.tween_property(label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await get_tree().create_timer(1.0).timeout
	label.text = "GO!"
	await get_tree().create_timer(0.45).timeout
	label.queue_free()


func _retry_scene() -> void:
	get_tree().set_meta(RETRY_META, true)
	get_tree().reload_current_scene()


func _on_obstacle_hit() -> void:
	if racing and race_active:
		impacts += 1


func _on_finish_reached(body: Node3D) -> void:
	if racing and race_active and body == vehicle.sphere:
		_finish_run.call_deferred()


func _finish_run() -> void:
	if not racing:
		return
	racing = false
	var ranking := LEADERBOARD.record_run(leaderboard_id, vehicle.selected_vehicle_id, race_time, bar_time, impacts)
	var summary = RACE_SUMMARY.new()
	summary.name = "RaceSummary"
	add_child(summary)
	summary.show_results(race_time, bar_time, impacts, ranking)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R:
		_retry_scene()


func _physics_process(delta: float) -> void:
	if vehicle == null:
		return
	if racing and race_active:
		race_time += delta
		var level := DriftBar.level_for_angle(vehicle.drift_angle)
		bar_time[level] += delta
	log_timer += delta
	if log_timer < log_interval:
		return
	log_timer = 0.0
	var tilt := rad_to_deg(vehicle.vehicle_model.global_basis.y.angle_to(Vector3.UP))
	var real_speed := vehicle.sphere.linear_velocity.length()
	print("t %5.1f s | inclinazione %4.1f gradi | quota %5.1f m | v reale %5.1f m/s | drift %s" % [
		race_time, tilt, vehicle.sphere.global_position.y, real_speed, vehicle.is_drifting])
