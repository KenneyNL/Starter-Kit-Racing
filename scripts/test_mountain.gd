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

## Velocita' del veicolo su questa mappa (1.0 = quella delle mappe a tile).
@export var speed_multiplier: float = 1.5
## Ingresso progressivo nello sterzo per facilitare le correzioni sui curvoni.
@export_range(0.0, 1.0, 0.01) var steering_ramp_time: float = 0.24
## Fa collidere con muri e alberi anche cofano e coda dell'auto (non solo la sfera di fisica).
@export var body_collision: bool = true
## Distanza dalla partenza (metri lungo la strada) a cui parte l'auto.
@export var spawn_distance: float = 4.0
@export var log_interval: float = 0.5
@export var leaderboard_id: String = "mountain"

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
	var st := road.start_transform
	var start_pos := st.origin
	# Direzione della strada (avanti) e laterale
	var road_dir := st.basis.z
	var road_side := Vector3(-road_dir.z, 0.0, road_dir.x)
	var specs := Spectators.new()
	specs.name = "Spectators"
	specs.count = 10
	specs.spread_radius = 14.0
	specs.min_road_distance = 4.0
	add_child(specs)
	specs.spawn(start_pos, road_dir, road_side)


func _make_vehicle_and_camera() -> void:
	# l'auto parte sulla strada, poco dopo la linea di partenza, orientata come il percorso
	var idx := clampi(int(spawn_distance / road.step_length), 0, road.centerline.size() - 1)
	vehicle = VEHICLE_SCENE.instantiate()
	vehicle.speed_multiplier = speed_multiplier
	vehicle.steering_ramp_time = steering_ramp_time
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

	# stessa inquadratura di main.tscn (yaw 45, pitch -35), ma far piu' lontano
	var view := Node3D.new()
	view.name = "View"
	view.set_script(VIEW_SCRIPT)
	view.set("target", vehicle)
	view.rotation_degrees = Vector3(-35.0, 45.0, 0.0)
	view.position = vehicle.position
	var cam := Camera3D.new()
	cam.name = "Camera"
	cam.position = Vector3(0.0, 0.0, 16.0)
	cam.fov = 40.0
	cam.far = 400.0
	view.add_child(cam)
	add_child(view)
	cam.current = true


func _on_obstacle_hit() -> void:
	if racing:
		impacts += 1


func _on_finish_reached(body: Node3D) -> void:
	if racing and body == vehicle.sphere:
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
		get_tree().reload_current_scene()


func _physics_process(delta: float) -> void:
	if vehicle == null:
		return
	if racing:
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
