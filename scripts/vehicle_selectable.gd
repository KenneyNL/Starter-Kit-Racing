class_name VehicleSelectable
extends Vehicle

const VEHICLE_CATALOG := preload("res://scripts/vehicle_catalog.gd")
const AE86_SCENE: PackedScene = preload("res://models/vehicle-toyota-ae86.glb")
const RX7_SCENE: PackedScene = preload("res://models/vehicle-toyota-mazdarx7.glb")

## The RX-7 source uses a different export scale; normalize its longest horizontal
## dimension to a plausible road-car length rather than relying on importer defaults.
const RX7_TARGET_LENGTH := 4.15

var selected_vehicle_id: String = "ae86"
var _rx7_front_wheels: Array[Node3D] = []
var _rx7_rear_wheels: Array[Node3D] = []
var _rx7_roll_axes: Dictionary = {}


func _ready() -> void:
	selected_vehicle_id = VEHICLE_CATALOG.get_selected_id()
	_load_selected_model()
	super._ready()


func _load_selected_model() -> void:
	var packed_scene: PackedScene = RX7_SCENE if selected_vehicle_id == "rx7" else AE86_SCENE
	var model_instance := packed_scene.instantiate() as Node3D
	if model_instance == null:
		push_error("VehicleSelectable: selected vehicle scene could not be instantiated.")
		return

	model_instance.name = "SelectedModel"
	var visual_root := get_node_or_null("Container/Model") as Node3D
	if visual_root == null:
		push_error("VehicleSelectable: Container/Model visual root is missing.")
		return
	visual_root.add_child(model_instance)

	if selected_vehicle_id == "rx7":
		_fit_rx7_model(model_instance)
		_configure_rx7_nodes(model_instance)
	else:
		# Preserve the existing AE86 import scale and exact wheel/body bindings.
		model_instance.scale = Vector3.ONE * 0.346
		vehicle_body = model_instance.get_node_or_null("body")
		wheel_fl = model_instance.get_node_or_null("RootNode/Car/Wheel1")
		wheel_fr = model_instance.get_node_or_null("RootNode/Car/Wheel3")
		wheel_bl = model_instance.get_node_or_null("RootNode/Car/Wheel4")
		wheel_br = model_instance.get_node_or_null("RootNode/Car/Wheel2")


func _fit_rx7_model(model_instance: Node3D) -> void:
	var bounds := _measure_model_bounds(model_instance)
	var horizontal_length := maxf(bounds.size.x, bounds.size.z)
	if horizontal_length <= 0.001:
		push_warning("VehicleSelectable: could not measure RX-7 mesh bounds; using fallback scale.")
		model_instance.scale = Vector3.ONE * 0.346
		return

	var scale_factor := RX7_TARGET_LENGTH / horizontal_length
	var center := bounds.position + bounds.size * 0.5
	model_instance.scale = Vector3.ONE * scale_factor
	# Center the car over the physics body without changing its imported vertical origin.
	model_instance.position += Vector3(-center.x * scale_factor, 0.0, -center.z * scale_factor)


func _measure_model_bounds(root: Node3D) -> AABB:
	var found := false
	var result := AABB()
	var root_inverse := root.global_transform.affine_inverse()

	for item in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := item as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue

		var local_transform: Transform3D = root_inverse * mesh_instance.global_transform
		var mesh_bounds: AABB = mesh_instance.mesh.get_aabb()
		for x in 2:
			for y in 2:
				for z in 2:
					var corner := Vector3(
						mesh_bounds.position.x + (mesh_bounds.size.x if x == 1 else 0.0),
						mesh_bounds.position.y + (mesh_bounds.size.y if y == 1 else 0.0),
						mesh_bounds.position.z + (mesh_bounds.size.z if z == 1 else 0.0)
					)
					var point := local_transform * corner
					if not found:
						result = AABB(point, Vector3.ZERO)
						found = true
					else:
						result = result.expand(point)

	return result


func _configure_rx7_nodes(model_instance: Node3D) -> void:
	vehicle_body = _find_body_node(model_instance)

	var candidates := _find_wheel_nodes(model_instance)
	if candidates.size() < 4:
		push_warning(
			(
				"VehicleSelectable: RX-7 wheel discovery found %d wheel node(s), expected 4. "
				+ "The car remains drivable, but wheel animation/skid placement may need node-path tuning."
			) % candidates.size()
		)

	if candidates.size() > 4:
		candidates = _pick_best_four_wheels(candidates)

	# If the imported model labels front/rear wheels, use those labels to align it
	# with the game's +Z forward convention. Otherwise +Z is assumed to be forward.
	var named_front: Array[Node3D] = []
	var named_rear: Array[Node3D] = []
	for wheel in candidates:
		var lower_name := str(wheel.name).to_lower()
		if lower_name.contains("front"):
			named_front.append(wheel)
		elif lower_name.contains("rear") or lower_name.contains("back"):
			named_rear.append(wheel)

	if named_front.size() == 2 and named_rear.size() == 2:
		var front_center := _wheel_pair_center(model_instance, named_front)
		var rear_center := _wheel_pair_center(model_instance, named_rear)
		var forward := front_center - rear_center
		forward.y = 0.0
		if forward.length_squared() > 0.01:
			var yaw_correction := -atan2(forward.x, forward.z)
			model_instance.rotate_y(yaw_correction)

	var by_z := candidates.duplicate()
	by_z.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return _model_local_position(model_instance, a).z > _model_local_position(model_instance, b).z
	)

	var front_pair: Array[Node3D] = []
	var rear_pair: Array[Node3D] = []
	if named_front.size() == 2 and named_rear.size() == 2:
		front_pair.append_array(named_front)
		rear_pair.append_array(named_rear)
	else:
		for index in by_z.size():
			var wheel := by_z[index] as Node3D
			if wheel == null:
				continue
			if index < 2:
				front_pair.append(wheel)
			else:
				rear_pair.append(wheel)

	_sort_pair_by_lateral_position(model_instance, front_pair)
	_sort_pair_by_lateral_position(model_instance, rear_pair)

	_rx7_front_wheels = front_pair
	_rx7_rear_wheels = rear_pair
	wheel_fl = _rx7_front_wheels[0] if _rx7_front_wheels.size() > 0 else null
	wheel_fr = _rx7_front_wheels[1] if _rx7_front_wheels.size() > 1 else null
	wheel_bl = _rx7_rear_wheels[0] if _rx7_rear_wheels.size() > 0 else null
	wheel_br = _rx7_rear_wheels[1] if _rx7_rear_wheels.size() > 1 else null

	# Place the smoke emitters at the rear tyres when those nodes are available.
	if _rx7_rear_wheels.size() == 2:
		var left_rear := _rx7_rear_wheels[1]
		var right_rear := _rx7_rear_wheels[0]
		if trail_left != null:
			trail_left.position = vehicle_model.to_local(left_rear.global_position) + Vector3.UP * 0.05
		if trail_right != null:
			trail_right.position = vehicle_model.to_local(right_rear.global_position) + Vector3.UP * 0.05


func _find_body_node(root: Node3D) -> Node3D:
	for item in root.find_children("*", "Node3D", true, false):
		var lower_name := str(item.name).to_lower()
		if lower_name == "body" or lower_name == "carbody" or lower_name == "chassis":
			return item as Node3D
	return null


func _find_wheel_nodes(root: Node3D) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for item in root.find_children("*", "Node3D", true, false):
		var node := item as Node3D
		if node == null or not _has_wheel_token(str(node.name)):
			continue
		if _has_wheel_ancestor(node, root) or not _contains_mesh(node):
			continue
		result.append(node)

	if result.size() >= 4:
		return result

	# Poly Pizza exports do not always preserve semantic wheel names.
	# Fall back to geometry: wheel meshes are low in the car, compact, and have
	# one noticeably thinner axis compared with the tyre diameter.
	return _find_wheel_meshes_by_geometry(root)


func _find_wheel_meshes_by_geometry(root: Node3D) -> Array[Node3D]:
	var scored: Array = []
	var bounds := _measure_model_bounds(root)
	var car_bottom := bounds.position.y
	var car_height := maxf(bounds.size.y, 0.001)

	for item in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := item as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue

		var size := mesh_instance.mesh.get_aabb().size.abs()
		var dims := [size.x, size.y, size.z]
		dims.sort()
		var thin: float = dims[0]
		var diameter_a: float = dims[1]
		var diameter_b: float = dims[2]
		if diameter_b <= 0.001:
			continue

		var thin_ratio := thin / diameter_b
		var round_ratio := diameter_a / diameter_b
		if thin_ratio > 0.75 or round_ratio < 0.55:
			continue

		var local_pos := _model_local_position(root, mesh_instance)
		var height_ratio := (local_pos.y - car_bottom) / car_height
		if height_ratio > 0.65:
			continue

		var score := (1.0 - thin_ratio) + round_ratio + (1.0 - clampf(height_ratio, 0.0, 1.0))
		scored.append({"node": mesh_instance, "score": score})

	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["score"]) > float(b["score"])
	)

	var result: Array[Node3D] = []
	for entry in scored:
		var node := entry["node"] as Node3D
		if node != null:
			result.append(node)
		if result.size() == 4:
			break

	if result.size() < 4:
		push_warning("VehicleSelectable: RX-7 geometric wheel discovery found only %d candidate(s)." % result.size())
	return result


func _has_wheel_token(node_name: String) -> bool:
	var lower_name := node_name.to_lower()
	if lower_name in ["wheels", "wheelset", "wheel_group"]:
		return false
	if lower_name.contains("spare") or lower_name.contains("steering"):
		return false
	return lower_name.contains("wheel") or lower_name.contains("tyre") or lower_name.contains("tire")


func _has_wheel_ancestor(node: Node3D, root: Node3D) -> bool:
	var parent := node.get_parent()
	while parent != null and parent != root:
		if parent is Node3D and _has_wheel_token(str(parent.name)):
			return true
		parent = parent.get_parent()
	return false


func _contains_mesh(node: Node3D) -> bool:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		return true
	return not node.find_children("*", "MeshInstance3D", true, false).is_empty()


func _pick_best_four_wheels(candidates: Array[Node3D]) -> Array[Node3D]:
	candidates.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return _wheel_name_score(str(a.name)) > _wheel_name_score(str(b.name))
	)
	var result: Array[Node3D] = []
	for index in mini(4, candidates.size()):
		result.append(candidates[index])
	push_warning("VehicleSelectable: more than four RX-7 wheel candidates found; using the four best name matches.")
	return result


func _wheel_name_score(node_name: String) -> int:
	var lower_name := node_name.to_lower()
	var score := 0
	if lower_name.contains("wheel"):
		score += 10
	if lower_name.contains("front") or lower_name.contains("rear") or lower_name.contains("back"):
		score += 5
	if lower_name.contains("left") or lower_name.contains("right"):
		score += 3
	return score


func _model_local_position(root: Node3D, node: Node3D) -> Vector3:
	return root.global_transform.affine_inverse() * node.global_position


func _wheel_pair_center(root: Node3D, wheels: Array[Node3D]) -> Vector3:
	var center := Vector3.ZERO
	for wheel in wheels:
		center += _model_local_position(root, wheel)
	return center / float(wheels.size())


func _sort_pair_by_lateral_position(root: Node3D, wheels: Array[Node3D]) -> void:
	wheels.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return _model_local_position(root, a).x < _model_local_position(root, b).x
	)


func _store_wheel_base_rotations() -> void:
	super._store_wheel_base_rotations()
	if selected_vehicle_id != "rx7":
		return

	_rx7_roll_axes.clear()
	for wheel in _rx7_front_wheels + _rx7_rear_wheels:
		if wheel != null:
			_rx7_roll_axes[wheel] = _infer_wheel_axle_axis(wheel)


func _infer_wheel_axle_axis(wheel: Node3D) -> Vector3:
	var mesh_instance: MeshInstance3D = wheel as MeshInstance3D
	if mesh_instance == null or mesh_instance.mesh == null:
		var meshes := wheel.find_children("*", "MeshInstance3D", true, false)
		if meshes.is_empty():
			return Vector3.RIGHT
		mesh_instance = meshes[0] as MeshInstance3D
	if mesh_instance == null or mesh_instance.mesh == null:
		return Vector3.RIGHT

	var size := mesh_instance.mesh.get_aabb().size
	var axis_index := 0
	if size.y < size.x and size.y <= size.z:
		axis_index = 1
	elif size.z < size.x and size.z < size.y:
		axis_index = 2

	var mesh_axis := Vector3.RIGHT if axis_index == 0 else (Vector3.UP if axis_index == 1 else Vector3.BACK)
	var wheel_to_mesh := wheel.global_transform.affine_inverse() * mesh_instance.global_transform
	var axis := (wheel_to_mesh.basis * mesh_axis).normalized()
	return axis if axis.length_squared() > 0.5 else Vector3.RIGHT


func effect_wheels(delta: float) -> void:
	if selected_vehicle_id != "rx7":
		super.effect_wheels(delta)
		return
	if wheel_base_quats.is_empty():
		return

	wheel_roll_angle += acceleration * delta * 20.0
	var max_steer_angle := deg_to_rad(45.0)
	var target_steer := -input.x * max_steer_angle
	current_steer_angle = lerp_angle(current_steer_angle, target_steer, delta * 10.0)

	for wheel in _rx7_rear_wheels:
		_rotate_rx7_wheel(wheel, 0.0)
	for wheel in _rx7_front_wheels:
		_rotate_rx7_wheel(wheel, current_steer_angle)


func _rotate_rx7_wheel(wheel: Node3D, steer_angle: float) -> void:
	if wheel == null or not wheel_base_quats.has(wheel):
		return

	var base_quat: Quaternion = wheel_base_quats[wheel]
	var parent := wheel.get_parent() as Node3D
	if parent == null:
		return

	var steer_axis_parent := (parent.global_basis.inverse() * vehicle_model.global_basis.y).normalized()
	var roll_axis: Vector3 = _rx7_roll_axes.get(wheel, Vector3.RIGHT)
	var steer_quat := Quaternion(steer_axis_parent, steer_angle)
	var roll_quat := Quaternion(roll_axis, wheel_roll_angle)
	# Steering happens in the parent/car frame; rolling happens in the wheel's
	# own imported frame. Preserve the model's original wheel orientation.
	wheel.quaternion = steer_quat * base_quat * roll_quat
