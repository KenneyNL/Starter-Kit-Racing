extends Node3D

const ROAD_SIDE_ANGLE := deg_to_rad(32.0)
const ROAD_FOLLOW_RATE := 6.0
const START_VIEW_DISTANCE := 8.0
const START_BLEND_END := 24.0
const ROAD_MAX_YAW_RATE := deg_to_rad(135.0)

@export_group("Properties")
@export var target: Vehicle
## When assigned, orient the camera along the upcoming course.
@export var road_path: Path3D

@onready var camera: Camera3D = $Camera
@onready var _start_yaw := global_rotation.y

var _road_view_blend := 0.0

func _ready() -> void:
	if _has_road():
		_follow_road(1.0, 0.0, PI)


func _physics_process(delta: float) -> void:
	var speed_factor := clampf(absf(target.linear_speed), 0.0, 1.0)
	if _has_road():
		_follow_road(1.0 - exp(-ROAD_FOLLOW_RATE * delta), speed_factor, ROAD_MAX_YAW_RATE * delta)
	else:
		position = position.lerp(target.get_vehicle_position(), delta * 4.0)

	var target_z := lerpf(10.0, 20.0, speed_factor)
	camera.position.z = lerpf(camera.position.z, target_z, delta * 0.5)


func _has_road() -> bool:
	return road_path != null and road_path.curve != null and road_path.curve.point_count >= 2


func _follow_road(weight: float, speed_factor: float, max_yaw_step: float) -> void:
	var car_position := target.get_vehicle_position()
	var curve := road_path.curve
	var length := curve.get_baked_length()
	var offset := curve.get_closest_offset(road_path.to_local(car_position))
	# Keep the front view through the gate. Once the chase view takes over,
	# backing up does not spin the camera back around.
	_road_view_blend = maxf(_road_view_blend, smoothstep(START_VIEW_DISTANCE, START_BLEND_END, offset))
	var look_ahead := lerpf(6.0, 11.0, speed_factor)
	var start := minf(offset, maxf(length - 1.0, 0.0))
	var end := minf(offset + look_ahead, length)
	var ahead := road_path.global_basis * (curve.sample_baked(end, true) - curve.sample_baked(start, true))

	# Frame the upcoming road and orbit around it without following the car's drift yaw.
	global_position = global_position.lerp(car_position + ahead * (0.55 * _road_view_blend), weight)
	if Vector2(ahead.x, ahead.z).length_squared() > 0.001:
		var yaw := atan2(-ahead.x, -ahead.z) + ROAD_SIDE_ANGLE
		var target_yaw := yaw
		if _road_view_blend < 1.0:
			target_yaw = lerp_angle(_start_yaw, yaw, _road_view_blend)
		var eased_yaw := lerp_angle(global_rotation.y, target_yaw, weight)
		global_rotation.y = rotate_toward(global_rotation.y, eased_yaw, max_yaw_step)
