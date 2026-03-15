class_name Vehicle extends Node3D

@export_category("Nodes")
@export var sphere: RigidBody3D
@export var raycast: RayCast3D

@export_category("Vehicle Elements")
@export var vehicle_model: Node3D
@export var vehicle_body: Node3D

@export_group("Wheels")
@export var wheel_fl: MeshInstance3D
@export var wheel_fr: MeshInstance3D
@export var wheel_bl: MeshInstance3D
@export var wheel_br: MeshInstance3D

@export_category("FX")
@export_group("Particles")
@export var trail_left: GPUParticles3D
@export var trail_right: GPUParticles3D

@export_group("Audio")
@export var screech_sound: AudioStreamPlayer3D
@export var engine_sound: AudioStreamPlayer3D


var input: Vector3
var normal: Vector3

var acceleration: float
var angular_speed: float
var linear_speed: float

var colliding: bool

# Public Functions

func get_vehicle_pos() -> Vector3:
	return vehicle_model.global_position

# Private Functions

func _physics_process(delta):
	
	_handle_input(delta)
	
	var direction = sign(linear_speed)
	if direction == 0: direction = sign(input.z) if abs(input.z) > 0.1 else 1
	
	var steering_grip = clamp(abs(linear_speed), 0.2, 1.0)
	
	var target_angular = -input.x * steering_grip * 4 * direction
	angular_speed = lerp(angular_speed, target_angular, delta * 4)
	
	vehicle_model.rotate_y(angular_speed * delta)

	# Ground alignment
	
	if raycast.is_colliding():
		if !colliding:
			vehicle_body.position = Vector3(0, 0.1, 0) # Bounce
			input.z = 0
		
		normal = raycast.get_collision_normal()
	
		# Orient model to colliding normal
		
		if normal.dot(vehicle_model.global_basis.y) > 0.5:
			var xform = _align_with_y(vehicle_model.global_transform, normal)
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
	
	acceleration = lerpf(acceleration, linear_speed + (abs(sphere.angular_velocity.length() * linear_speed) / 100), delta * 1)
	
	# Match vehicle model to physics sphere
	
	vehicle_model.position = sphere.position - Vector3(0, 0.65, 0)
	raycast.position = sphere.position
	
	# Visual and audio effects
	
	_effect_engine(delta)
	_effect_body(delta)
	_effect_wheels(delta)
	_effect_trails()

# Handle input when vehicle is colliding with ground

func _handle_input(delta):
	
	if raycast.is_colliding():
		input.x = Input.get_axis("left", "right")
		input.z = Input.get_axis("back", "forward")
	
	sphere.angular_velocity += vehicle_model.get_global_transform().basis.x * (linear_speed * 100) * delta

func _effect_body(delta):
	
	# Slightly tilt body based on acceleration and steering
	
	vehicle_body.rotation.x = lerp_angle(vehicle_body.rotation.x, -(linear_speed - acceleration) / 6, delta * 10)
	vehicle_body.rotation.z = lerp_angle(vehicle_body.rotation.z, -input.x / 5 * linear_speed, delta * 5)
	
	# Change the body position so wheels don't clip through the body when tilting
	
	vehicle_body.position = vehicle_body.position.lerp(Vector3(0, 0.2, 0), delta * 5)

# Spin and rotate wheels (based on direction)

func _effect_wheels(delta):
	
	# Rotate wheels based on acceleration
	
	for wheel in [wheel_fl, wheel_fr, wheel_bl, wheel_br]:
		wheel.rotation.x += acceleration
	
	# Rotate front wheels based on steering direction
	
	wheel_fl.rotation.y = lerp_angle(wheel_fl.rotation.y, -input.x / 1.5, delta * 10)
	wheel_fr.rotation.y = lerp_angle(wheel_fr.rotation.y, -input.x / 1.5, delta * 10)

# Engine sounds

func _effect_engine(delta):
	
	var speed_factor = clamp(abs(linear_speed), 0.0, 1.0)
	var throttle_factor = clamp(abs(input.z), 0.0, 1.0)
	
	var target_volume = remap(speed_factor + (throttle_factor * 0.5), 0.0, 1.5, -15.0, -5.0)
	engine_sound.volume_db = lerp(engine_sound.volume_db, target_volume, delta * 5.0)
	
	var target_pitch = remap(speed_factor, 0.0, 1.0, 0.5, 3)
	if throttle_factor > 0.1: target_pitch += 0.2
	
	engine_sound.pitch_scale = lerp(engine_sound.pitch_scale, target_pitch, delta * 2.0)

# Show trails (and play skid sound)

func _effect_trails():
	
	var drift_intensity = abs(linear_speed - acceleration) + (abs(vehicle_body.rotation.z) * 2.0)
	var should_emit = drift_intensity > 0.25
	
	trail_left.emitting = should_emit
	trail_right.emitting = should_emit
	
	var target_volume = -80.0
	if should_emit: target_volume = remap(clamp(drift_intensity, 0.25, 2.0), 0.25, 2.0, -10.0, 0.0)
	
	screech_sound.pitch_scale = lerp(screech_sound.pitch_scale, clamp(abs(linear_speed), 1.0, 3.0), 0.1)
	screech_sound.volume_db = lerp(screech_sound.volume_db, target_volume, 10.0 * get_physics_process_delta_time())

# Align vehicle with normal

func _align_with_y(xform, new_y):
	
	xform.basis.y = new_y
	xform.basis.x = -xform.basis.z.cross(new_y)
	xform.basis = xform.basis.orthonormalized()
	return xform
