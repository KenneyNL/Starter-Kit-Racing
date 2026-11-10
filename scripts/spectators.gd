class_name Spectators extends Node3D

# Folla low-poly da touge: sagome 3D semplici, palette anni '90 e animazioni leggere.
# Tutto e' generato proceduralmente per non aggiungere asset pesanti.

@export var count: int = 16
@export var spread_radius: float = 12.0
@export var min_road_distance: float = 4.2
@export var forward_min: float = -4.0
@export var forward_max: float = 9.0
@export var person_height: float = 1.68
@export var rng_seed: int = 42

const SKIN_COLORS: Array[Color] = [
	Color(0.88, 0.72, 0.58),
	Color(0.76, 0.60, 0.46),
	Color(0.60, 0.44, 0.32),
	Color(0.42, 0.30, 0.22),
]
const JACKET_COLORS: Array[Color] = [
	Color(0.10, 0.13, 0.18),
	Color(0.16, 0.20, 0.26),
	Color(0.34, 0.08, 0.08),
	Color(0.08, 0.22, 0.28),
	Color(0.48, 0.42, 0.30),
	Color(0.74, 0.72, 0.66),
]
const PANTS_COLORS: Array[Color] = [
	Color(0.07, 0.08, 0.10),
	Color(0.12, 0.14, 0.20),
	Color(0.18, 0.20, 0.22),
	Color(0.22, 0.18, 0.15),
]
const HAIR_COLORS: Array[Color] = [
	Color(0.035, 0.03, 0.025),
	Color(0.12, 0.075, 0.045),
	Color(0.28, 0.18, 0.08),
]

var _actors: Array[Node3D] = []
var _left_arms: Array[Node3D] = []
var _right_arms: Array[Node3D] = []
var _anim_progress: PackedFloat32Array = PackedFloat32Array()
var _anim_duration: PackedFloat32Array = PackedFloat32Array()
var _anim_from: PackedFloat32Array = PackedFloat32Array()
var _anim_to: PackedFloat32Array = PackedFloat32Array()
var _anim_rng := RandomNumberGenerator.new()


func spawn(anchor_pos: Vector3, road_dir: Vector3, road_side: Vector3, look_target: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	_anim_rng.seed = rng_seed + 7919
	var forward := road_dir.normalized()
	var side := road_side.normalized()

	for i in count:
		var actor := _make_person(rng)
		var side_sign := -1.0 if i % 2 == 0 else 1.0
		var lateral := rng.randf_range(min_road_distance, spread_radius) * side_sign
		var along := rng.randf_range(forward_min, forward_max)
		var jitter := side * rng.randf_range(-0.35, 0.35)
		actor.position = anchor_pos + side * lateral + forward * along + jitter
		actor.position.y = anchor_pos.y
		var toward_finish := look_target - actor.position
		toward_finish.y = 0.0
		if toward_finish.length_squared() < 0.01:
			toward_finish = forward
		toward_finish = toward_finish.normalized()
		# Il fronte del personaggio e' -Z (la visiera del cappellino sporge in quella direzione).
		actor.rotation.y = atan2(-toward_finish.x, -toward_finish.z) + rng.randf_range(-0.08, 0.08)
		actor.scale = Vector3.ONE * rng.randf_range(0.92, 1.08)
		add_child(actor)
		_actors.append(actor)
		_left_arms.append(actor.get_node("Body/LeftArm") as Node3D)
		_right_arms.append(actor.get_node("Body/RightArm") as Node3D)
		var initial_lift := rng.randf()
		_set_arm_lift(_left_arms.size() - 1, initial_lift)
		_anim_progress.append(rng.randf_range(0.0, 0.85))
		_anim_duration.append(rng.randf_range(0.65, 1.55))
		_anim_from.append(initial_lift)
		_anim_to.append(0.0 if initial_lift > 0.5 else 1.0)


func _make_person(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)

	var skin := _material(SKIN_COLORS[rng.randi_range(0, SKIN_COLORS.size() - 1)])
	var jacket := _material(JACKET_COLORS[rng.randi_range(0, JACKET_COLORS.size() - 1)])
	var pants := _material(PANTS_COLORS[rng.randi_range(0, PANTS_COLORS.size() - 1)])
	var hair := _material(HAIR_COLORS[rng.randi_range(0, HAIR_COLORS.size() - 1)])
	var shoe := _material(Color(0.035, 0.04, 0.045))

	_add_box(body, "Torso", Vector3(0.42, 0.58, 0.22), Vector3(0.0, 1.12, 0.0), jacket)
	_add_box(body, "Hips", Vector3(0.34, 0.20, 0.20), Vector3(0.0, 0.76, 0.0), pants)
	_add_leg(body, "LeftLeg", -0.11, pants, shoe)
	_add_leg(body, "RightLeg", 0.11, pants, shoe)

	var head := MeshInstance3D.new()
	head.name = "Head"
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.145
	head_mesh.height = 0.29
	head_mesh.radial_segments = 8
	head_mesh.rings = 4
	head.mesh = head_mesh
	head.material_override = skin
	head.position = Vector3(0.0, 1.57, 0.0)
	body.add_child(head)

	var hair_mesh := MeshInstance3D.new()
	hair_mesh.name = "Hair"
	var cap := SphereMesh.new()
	cap.radius = 0.152
	cap.height = 0.15
	cap.radial_segments = 8
	cap.rings = 2
	hair_mesh.mesh = cap
	hair_mesh.material_override = hair
	hair_mesh.position = Vector3(0.0, 1.66, 0.0)
	body.add_child(hair_mesh)

	_add_arm(body, "LeftArm", -0.27, jacket, skin, rng.randf() < 0.42)
	_add_arm(body, "RightArm", 0.27, jacket, skin, rng.randf() < 0.42)

	if rng.randf() < 0.28:
		_add_cap(body, rng)

	return root


func _add_leg(parent: Node3D, node_name: String, x: float, pants: Material, shoe: Material) -> void:
	var leg := Node3D.new()
	leg.name = node_name
	leg.position = Vector3(x, 0.68, 0.0)
	parent.add_child(leg)
	_add_cylinder(leg, "Pant", 0.075, 0.58, Vector3(0.0, -0.29, 0.0), pants, 6)
	_add_box(leg, "Shoe", Vector3(0.16, 0.09, 0.28), Vector3(0.0, -0.61, 0.055), shoe)


func _add_arm(parent: Node3D, node_name: String, x: float, jacket: Material, skin: Material, raised: bool) -> void:
	var arm := Node3D.new()
	arm.name = node_name
	arm.position = Vector3(x, 1.35, 0.0)
	arm.rotation.z = (-0.55 if x < 0.0 else 0.55) if raised else (-0.12 if x < 0.0 else 0.12)
	parent.add_child(arm)
	_add_cylinder(arm, "Sleeve", 0.062, 0.42, Vector3(0.0, -0.21, 0.0), jacket, 6)
	var hand := MeshInstance3D.new()
	hand.name = "Hand"
	var hand_mesh := SphereMesh.new()
	hand_mesh.radius = 0.072
	hand_mesh.height = 0.13
	hand_mesh.radial_segments = 6
	hand_mesh.rings = 3
	hand.mesh = hand_mesh
	hand.material_override = skin
	hand.position = Vector3(0.0, -0.45, 0.0)
	arm.add_child(hand)


func _add_cap(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var cap_mat := _material(JACKET_COLORS[rng.randi_range(0, JACKET_COLORS.size() - 1)])
	_add_box(parent, "Cap", Vector3(0.30, 0.07, 0.26), Vector3(0.0, 1.73, -0.01), cap_mat)
	_add_box(parent, "CapBrim", Vector3(0.24, 0.035, 0.18), Vector3(0.0, 1.70, -0.16), cap_mat)


func _add_box(parent: Node3D, node_name: String, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _add_cylinder(parent: Node3D, node_name: String, radius: float, height: float,
		pos: Vector3, mat: Material, sides: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.92
	mat.metallic = 0.0
	return mat


func _process(delta: float) -> void:
	for i in _actors.size():
		_anim_progress[i] += delta
		var duration := maxf(_anim_duration[i], 0.01)
		var t := clampf(_anim_progress[i] / duration, 0.0, 1.0)
		# Smoothstep: mani chiaramente giu -> su -> giu, senza scatti.
		var eased := t * t * (3.0 - 2.0 * t)
		var lift := lerpf(_anim_from[i], _anim_to[i], eased)
		_set_arm_lift(i, lift)

		if t >= 1.0:
			_anim_progress[i] = 0.0
			_anim_from[i] = _anim_to[i]
			_anim_to[i] = 0.0 if _anim_to[i] > 0.5 else 1.0
			# Durata diversa ad ogni ciclo: niente effetto sincronizzato anche dopo molti secondi.
			_anim_duration[i] = _anim_rng.randf_range(0.55, 1.75)


func _set_arm_lift(index: int, lift: float) -> void:
	if index < 0 or index >= _left_arms.size():
		return
	var amount := clampf(lift, 0.0, 1.0)
	var left_down := -0.12
	var left_up := -2.45
	var right_down := 0.12
	var right_up := 2.45
	_left_arms[index].rotation.z = lerpf(left_down, left_up, amount)
	_right_arms[index].rotation.z = lerpf(right_down, right_up, amount)
