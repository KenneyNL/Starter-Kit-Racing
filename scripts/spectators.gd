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
var _phases: PackedFloat32Array = PackedFloat32Array()
var _speeds: PackedFloat32Array = PackedFloat32Array()
var _amplitudes: PackedFloat32Array = PackedFloat32Array()


func spawn(anchor_pos: Vector3, road_dir: Vector3, road_side: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
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
		actor.rotation.y = atan2(-side_sign * side.x, -side_sign * side.z) + rng.randf_range(-0.24, 0.24)
		actor.scale = Vector3.ONE * rng.randf_range(0.92, 1.08)
		add_child(actor)
		_actors.append(actor)
		_left_arms.append(actor.get_node("Body/LeftArm") as Node3D)
		_right_arms.append(actor.get_node("Body/RightArm") as Node3D)
		_phases.append(rng.randf_range(0.0, TAU))
		_speeds.append(rng.randf_range(1.5, 3.1))
		_amplitudes.append(rng.randf_range(0.16, 0.42))


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
	var t := Time.get_ticks_msec() * 0.001
	for i in _actors.size():
		var wave := sin(t * _speeds[i] + _phases[i])
		var bob := sin(t * (_speeds[i] * 0.55) + _phases[i]) * 0.018
		var actor := _actors[i]
		actor.position.y += (bob - actor.get_meta("last_bob", 0.0))
		actor.set_meta("last_bob", bob)
		var amp := _amplitudes[i]
		_left_arms[i].rotation.z += (-0.22 + wave * amp - _left_arms[i].rotation.z) * minf(delta * 5.0, 1.0)
		_right_arms[i].rotation.z += (0.22 - wave * amp - _right_arms[i].rotation.z) * minf(delta * 5.0, 1.0)
