extends Node3D

# Scena di prova: salita con tornanti generata da codice.
# Non usa main.tscn ne' la GridMap. Tasto R = ricomincia.

const MountainRoad := preload("res://scripts/mountain_road.gd")
const VEHICLE_SCENE := preload("res://scenes/vehicle.tscn")
const VIEW_SCRIPT := preload("res://scripts/view.gd")
const ENVIRONMENT := preload("res://scenes/main-environment.tres")

@export var start_index: int = 3
@export var log_interval: float = 0.5

var road: MountainRoad
var vehicle: Vehicle
var log_timer: float = 0.0


func _ready() -> void:
	_make_world()
	road = MountainRoad.new()
	road.name = "MountainRoad"
	add_child(road)
	road.build()
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
	mat.albedo_color = Color(0.36, 0.55, 0.28)
	plane.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.position = Vector3(0.0, -0.1, 0.0)
	add_child(mi)


func _make_vehicle_and_camera() -> void:
	var start := road.centerline[start_index]

	# l'auto, a rotazione zero, guarda verso +Z: la strada di prova parte in quella direzione
	vehicle = VEHICLE_SCENE.instantiate()
	vehicle.position = start + Vector3(0.0, 0.2, 0.0)
	add_child(vehicle)

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


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R:
		get_tree().reload_current_scene()


func _physics_process(delta: float) -> void:
	if vehicle == null:
		return
	log_timer += delta
	if log_timer < log_interval:
		return
	log_timer = 0.0
	var tilt := rad_to_deg(vehicle.vehicle_model.global_basis.y.angle_to(Vector3.UP))
	var real_speed := vehicle.sphere.linear_velocity.length()
	print("inclinazione %4.1f gradi | quota %5.1f m | v reale %5.1f m/s | linear_speed %.2f | drift %s" % [
		tilt, vehicle.sphere.global_position.y, real_speed, vehicle.linear_speed, vehicle.is_drifting])
