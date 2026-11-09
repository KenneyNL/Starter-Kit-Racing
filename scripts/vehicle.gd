class_name Vehicle extends Node3D

# Nodes

@onready var sphere: RigidBody3D = $Sphere
@onready var raycast: RayCast3D = $Ground

# Vehicle elements

@onready var vehicle_model: Node3D = $Container
@onready var vehicle_body = get_node_or_null("Container/Model/body")

# Wheels (from vehicle-toyota-ae86.glb sub-nodes)
# The Car node has rotation [0.5,-0.5,0.5,-0.5] which remaps axes:
#   Car-local Y → World -Z (forward/back), Car-local Z → World X (lateral)
# So front/rear is determined by Car-local Y, side by Car-local Z.
# Wheel1 & Wheel3 share Y≈-0.055 = front, Wheel2 & Wheel4 share Y≈+0.050 = rear

@onready var wheel_fl = get_node_or_null("Container/Model/RootNode/Car/Wheel1")  # front-left
@onready var wheel_fr = get_node_or_null("Container/Model/RootNode/Car/Wheel3")  # front-right
@onready var wheel_bl = get_node_or_null("Container/Model/RootNode/Car/Wheel4")  # back-left
@onready var wheel_br = get_node_or_null("Container/Model/RootNode/Car/Wheel2")  # back-right

# Store original wheel quaternions (GLB has per-wheel orientations we must preserve)
var wheel_base_quats: Dictionary = {}

# Accumulated rolling angle
var wheel_roll_angle: float = 0.0

# Current visual steering angle (smoothed)
var current_steer_angle: float = 0.0

# Effects

@onready var trail_left = get_node_or_null("Container/TrailLeft")
@onready var trail_right = get_node_or_null("Container/TrailRight")

# Sounds

@onready var screech_sound: AudioStreamPlayer3D = $Container/ScreechSound
@onready var engine_sound: AudioStreamPlayer3D = $Container/EngineSound
@onready var impact_sound: AudioStreamPlayer3D = $Container/ImpactSound

## Moltiplica la spinta del veicolo (1.0 = velocita' originale). Lo imposta ogni mappa.
@export var speed_multiplier: float = 1.0

@export_group("Skid marks")
## Lascia sull'asfalto i segni delle gomme posteriori durante il drift.
@export var skid_marks_enabled: bool = true
## Secondi per cui i segni restano visibili.
@export var skid_marks_lifetime: float = 60.0

@export_group("Body collision")
## Fa collidere con muri e ostacoli anche il corpo dell'auto, non solo la sfera di fisica.
## Senza, cofano e coda (1,1 m oltre la sfera) attraversano i muri.
@export var body_collision: bool = true
## Layer fisici considerati ostacoli per il corpo dell'auto (1 = mondo statico).
@export_flags_3d_physics var body_collision_mask: int = 1
## Distanza lasciata tra il corpo e il muro (metri).
@export var body_collision_margin: float = 0.02

var input: Vector3
var _body_probes: Array[Vector3] = []
var _body_probes_ready: bool = false
var normal: Vector3

var acceleration: float
var angular_speed: float
var linear_speed: float

var colliding: bool

# True while the drift smoke is being emitted (read by the Drift Bar HUD)
var is_drifting: bool = false
## Slip angle in degrees between heading and motion direction on the vehicle's plane
var drift_angle: float = 0.0

var linear_velocity: Vector3
var prev_position: Vector3

var calculated_lean: float

# Public Functions

func get_vehicle_position() -> Vector3: return vehicle_model.global_position

# Functions

func _ready():
	# Capture base quaternions of each wheel after the GLB is loaded
	# We need to defer this to ensure the imported scene is fully ready
	_store_wheel_base_rotations.call_deferred()
	if skid_marks_enabled:
		_setup_skid_marks()

func _setup_skid_marks():
	var skid_marks := SkidMarks.new()
	skid_marks.name = "SkidMarks"
	skid_marks.target = self
	skid_marks.lifetime = skid_marks_lifetime
	add_child(skid_marks)

func _store_wheel_base_rotations():
	for wheel in [wheel_fl, wheel_fr, wheel_bl, wheel_br]:
		if wheel != null:
			wheel_base_quats[wheel] = wheel.quaternion

func _physics_process(delta):

	handle_input(delta)

	var direction = sign(linear_speed)
	if direction == 0: direction = sign(input.z) if abs(input.z) > 0.1 else 1

	var steering_grip = clamp(abs(linear_speed), 0.2, 1.0)

	var target_angular = -input.x * steering_grip * 4 * direction
	angular_speed = lerp(angular_speed, target_angular, delta * 4)

	vehicle_model.rotate_y(angular_speed * delta)

	# Ground alignment

	if raycast.is_colliding():
		if !colliding:
			if vehicle_body != null: vehicle_body.position = Vector3(0, 0.1, 0) # Bounce
			input.z = 0

		normal = raycast.get_collision_normal()

		# Orient model to colliding normal

		if normal.dot(vehicle_model.global_basis.y) > 0.5:
			var xform = align_with_y(vehicle_model.global_transform, normal)
			vehicle_model.global_transform = vehicle_model.global_transform.interpolate_with(xform, 0.2).orthonormalized()

	colliding = raycast.is_colliding()

	var target_speed = input.z

	if (target_speed < 0 and linear_speed > 0.01):
		linear_speed = lerp(linear_speed, 0.0, delta * 8)
	else:
		if (target_speed < 0):
			linear_speed = lerp(linear_speed, target_speed / 2, delta * 2)
		else:
			linear_speed = lerp(linear_speed, target_speed, delta * 6)

	acceleration = lerpf(acceleration, linear_speed + (abs(sphere.angular_velocity.length() * linear_speed) / (100 * speed_multiplier)), delta * 1)

	if body_collision:
		_resolve_body_overlap()

	# Match vehicle model to physics sphere

	vehicle_model.position = sphere.position - Vector3(0, 0.65, 0)
	raycast.position = sphere.position

	# Calculate vehicle model linear velocity

	linear_velocity = (vehicle_model.position - prev_position) / delta
	prev_position = vehicle_model.position

	# Visual and audio effects

	effect_engine(delta)
	effect_body(delta)
	effect_wheels(delta)
	effect_trails()

# Body collision
# La fisica usa solo la sfera (raggio 0.5) sotto l'auto, ma il corpo e' lungo oltre 3 m.
# Da ogni punto del perimetro del corpo si lancia un raggio dal centro della sfera: se un muro
# sta tra il centro e quel punto, il punto e' "dentro" il muro e la sfera viene spostata indietro.
# Il raggio parte dal lato libero, quindi anche con muri sottili non spinge mai attraverso.

func _compute_body_probes():
	_body_probes_ready = true
	_body_probes.clear()
	var minp := Vector3(INF, INF, INF)
	var maxp := Vector3(-INF, -INF, -INF)
	var inv: Transform3D = vehicle_model.global_transform.affine_inverse()
	for mi in vehicle_model.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for surface in mi.mesh.get_surface_count():
			var verts: PackedVector3Array = mi.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			var xf: Transform3D = inv * mi.global_transform
			for v in verts:
				var q: Vector3 = xf * v
				minp = minp.min(q)
				maxp = maxp.max(q)
	if minp.x == INF:
		return
	var cx := (minp.x + maxp.x) * 0.5
	for p in [
			Vector3(minp.x, 0, minp.z), Vector3(maxp.x, 0, minp.z),
			Vector3(minp.x, 0, maxp.z), Vector3(maxp.x, 0, maxp.z),
			Vector3(cx, 0, maxp.z), Vector3(cx, 0, minp.z),
			Vector3(minp.x, 0, 0), Vector3(maxp.x, 0, 0)]:
		_body_probes.append(p)

func _resolve_body_overlap():
	if !_body_probes_ready:
		_compute_body_probes()
	if _body_probes.is_empty():
		return

	var space := get_world_3d().direct_space_state
	var center := sphere.global_position
	var model_basis := vehicle_model.global_basis
	var worst_depth := 0.0
	var worst_normal := Vector3.ZERO

	for p in _body_probes:
		var target := center + model_basis * p
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(center, target, body_collision_mask))
		if hit.is_empty():
			continue
		var n: Vector3 = hit.normal
		if n.dot(target - center) > 0.0:
			n = -n # facce a senso unico: la normale deve guardare verso il centro della sfera
		if absf(n.y) > 0.6:
			continue # suolo e pendii: li gestisce la sfera
		var depth: float = (hit.position - target).dot(n)
		if depth > worst_depth:
			worst_depth = depth
			worst_normal = n

	if worst_depth > 0.0:
		sphere.global_position += worst_normal * (worst_depth + body_collision_margin)
		var into_wall := sphere.linear_velocity.dot(worst_normal)
		if into_wall < 0.0:
			sphere.linear_velocity -= worst_normal * into_wall

# Handle input when vehicle is colliding with ground

func handle_input(delta):

	if raycast.is_colliding():
		input.x = Input.get_axis("left", "right")
		input.z = Input.get_axis("back", "forward")

	sphere.angular_velocity += vehicle_model.get_global_transform().basis.x * (linear_speed * 100 * speed_multiplier) * delta

func effect_body(delta):
	
	calculated_lean = lerp_angle(calculated_lean, -input.x / 5 * linear_speed, delta * 5)
	
	# Slightly tilt (and move) body based on acceleration and steering
	
	if vehicle_body != null:
		
		vehicle_body.rotation.x = lerp_angle(vehicle_body.rotation.x, -(linear_speed - acceleration) / 6, delta * 10)
		vehicle_body.rotation.z = calculated_lean
		
		vehicle_body.position = vehicle_body.position.lerp(Vector3(0, 0.2, 0), delta * 5)
	
func effect_wheels(delta):

	# Skip if base rotations not yet captured
	if wheel_base_quats.is_empty():
		return

	# Rolling: accumulate angle based on acceleration (same progression as vehicle speed)
	wheel_roll_angle += acceleration * delta * 20.0

	# Steering: smooth interpolation towards target (visual only, max ±45°)
	var max_steer_angle := deg_to_rad(45.0)
	var target_steer := -input.x * max_steer_angle
	current_steer_angle = lerp_angle(current_steer_angle, target_steer, delta * 10.0)

	# Build rotation quaternions in Car-local space:
	# The Car's rotation maps: local Z → World X (axle), local -X → World Y (vertical)
	#   - Rolling axis  = Car-local Z = Vector3.BACK  (maps to World X = left-right axle)
	#   - Steering axis = Car-local -X = Vector3.LEFT  (maps to World Y = vertical)
	var roll_quat := Quaternion(Vector3.BACK, wheel_roll_angle)
	var steer_quat := Quaternion(Vector3.LEFT, current_steer_angle)

	# Apply rolling to ALL 4 wheels (compose: base_orientation * roll)
	for wheel in [wheel_bl, wheel_br]:
		if wheel != null and wheel_base_quats.has(wheel):
			wheel.quaternion = wheel_base_quats[wheel] * roll_quat

	# Apply rolling + steering to FRONT wheels only (compose: base * steer * roll)
	for wheel in [wheel_fl, wheel_fr]:
		if wheel != null and wheel_base_quats.has(wheel):
			wheel.quaternion = wheel_base_quats[wheel] * steer_quat * roll_quat

# Engine sounds

func effect_engine(delta):

	var speed_factor = clamp(abs(linear_speed), 0.0, 1.0)
	var throttle_factor = clamp(abs(input.z), 0.0, 1.0)

	var target_volume = remap(speed_factor + (throttle_factor * 0.5), 0.0, 1.5, -15.0, -5.0)
	engine_sound.volume_db = lerp(engine_sound.volume_db, target_volume, delta * 5.0)

	var target_pitch = remap(speed_factor, 0.0, 1.0, 0.5, 3)
	if throttle_factor > 0.1: target_pitch += 0.2

	engine_sound.pitch_scale = lerp(engine_sound.pitch_scale, target_pitch, delta * 2.0)

# Show trails (and play skid sound)

func effect_trails():

	# Calculate slip angle on the vehicle's local plane
	# The vehicle's forward orientation in this model is +Z (see tools/validate_mountain.gd:54)
	var forward_dir: Vector3 = vehicle_model.global_basis.z
	var normal_up: Vector3 = vehicle_model.global_basis.y
	var vel_on_plane: Vector3 = linear_velocity - normal_up * linear_velocity.dot(normal_up)
	var speed: float = vel_on_plane.length()
	if speed > 1.5:
		# If going in reverse (linear_speed < 0), heading is -forward_dir
		var drive_dir: Vector3 = forward_dir if linear_speed >= 0 else -forward_dir
		var dot_val: float = clampf(drive_dir.dot(vel_on_plane.normalized()), -1.0, 1.0)
		drift_angle = rad_to_deg(acos(dot_val))
	else:
		drift_angle = 0.0

	var drift_intensity = abs(linear_speed - acceleration) + (abs(calculated_lean) * 2.0)
	var should_emit = drift_intensity > 0.25

	is_drifting = should_emit

	if trail_left != null: trail_left.emitting = should_emit
	if trail_right != null: trail_right.emitting = should_emit

	var target_volume = -80.0
	if should_emit: target_volume = remap(clamp(drift_intensity, 0.25, 2.0), 0.25, 2.0, -10.0, 0.0)

	screech_sound.pitch_scale = lerp(screech_sound.pitch_scale, clamp(abs(linear_speed), 1.0, 3.0), 0.1)
	screech_sound.volume_db = lerp(screech_sound.volume_db, target_volume, 10.0 * get_physics_process_delta_time())

# Align vehicle with normal

func align_with_y(xform, new_y):

	xform.basis.y = new_y
	xform.basis.x = -xform.basis.z.cross(new_y)
	xform.basis = xform.basis.orthonormalized()
	return xform

# Detect collisions and play impact sound

func _on_sphere_body_entered(_body: Node) -> void:
	
	if vehicle_body == null: return
	
	if not impact_sound.playing:
		var impact_velocity := absf(linear_velocity.dot(vehicle_body.global_basis.z))
		impact_sound.volume_db = clampf(remap(impact_velocity, 0.0, 6.0, -20.0, 0.0), -20.0, 0.0)
		impact_sound.play()
