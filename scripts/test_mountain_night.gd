extends "res://scripts/test_mountain.gd"

# Versione notturna della mappa di montagna. La strada, il terreno, la vegetazione, il
# traguardo e la logica di gara sono quelli di test_mountain.gd (non vengono toccati):
# qui si cambiano solo ambiente e illuminazione e si aggiungono lampioni e luci dell'auto.

@export_group("Notte")
@export var sky_color := Color(0.015, 0.02, 0.05)
@export var ambient_color := Color(0.16, 0.2, 0.36)
@export var ambient_energy: float = 0.55
@export var moon_color := Color(0.55, 0.65, 1.0)
@export var moon_energy: float = 0.22
@export var fog_color := Color(0.03, 0.04, 0.09)
@export_range(0.0, 0.05, 0.001) var fog_density: float = 0.006

@export_group("Lampioni")
@export var enable_lampposts: bool = true
## Distanza tra un lampione e il successivo, lungo la strada (metri).
@export var lamp_spacing: float = 22.0
@export var lamp_height: float = 5.2
## Lunghezza del braccio che sporge sulla strada (metri).
@export var lamp_arm_length: float = 1.8
@export var lamp_color := Color(1.0, 0.8, 0.5)
@export var lamp_energy: float = 9.0
@export var lamp_range: float = 15.0
@export var lamp_cone_angle: float = 62.0
## Oltre questa distanza dall'auto (metri) la luce del lampione sfuma e si spegne (risparmia GPU).
@export var lamp_fade_distance: float = 70.0

@export_group("Luci auto")
@export var enable_car_lights: bool = true
@export var headlight_color := Color(1.0, 0.96, 0.82)
@export var headlight_energy: float = 12.0
@export var headlight_range: float = 38.0
@export var headlight_cone_angle: float = 28.0
## Inclinazione dei fari verso il basso (gradi).
@export var headlight_pitch: float = 6.0
@export var headlight_shadows: bool = false
@export var taillight_color := Color(1.0, 0.05, 0.03)
@export var taillight_energy: float = 1.4
## Se i fari risultano dietro invece che davanti, attiva questa opzione.
@export var flip_front_back: bool = false

var _halo_material_cache: Dictionary = {}


func _ready() -> void:
	super._ready()
	if enable_lampposts:
		_make_lampposts()
	if enable_car_lights:
		_make_car_lights()


# --- Ambiente notturno -------------------------------------------------------------

# Usa il mondo di test_mountain.gd (pavimento, ambiente, luce direzionale) e poi lo "spegne".
func _make_world() -> void:
	super._make_world()
	for c in get_children():
		if c is WorldEnvironment:
			var env: Environment = c.environment.duplicate()
			env.background_mode = Environment.BG_COLOR
			env.background_color = sky_color
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.ambient_light_color = ambient_color
			env.ambient_light_energy = ambient_energy
			env.tonemap_exposure = 1.0
			env.fog_enabled = true
			env.fog_light_color = fog_color
			env.fog_density = fog_density
			# il bagliore (glow) fa "bruciare" lampioni e fanali emissivi
			env.glow_enabled = true
			env.glow_hdr_threshold = 0.9
			env.glow_intensity = 0.9
			c.environment = env
		elif c is DirectionalLight3D:
			# la luna: debole e azzurrina
			c.light_color = moon_color
			c.light_energy = moon_energy


# --- Lampioni ----------------------------------------------------------------------

func _make_lampposts() -> void:
	var cl: PackedVector3Array = road.centerline
	if cl.size() < 2:
		return

	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.07
	pole_mesh.bottom_radius = 0.1
	pole_mesh.height = lamp_height + 0.3
	pole_mesh.radial_segments = 8
	pole_mesh.rings = 1

	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(0.08, 0.08, lamp_arm_length)

	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.38, 0.08, 0.7)

	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.16, 0.17, 0.19)
	metal.roughness = 0.7
	metal.metallic = 0.4

	var bulb := StandardMaterial3D.new()
	bulb.albedo_color = lamp_color
	bulb.emission_enabled = true
	bulb.emission = lamp_color
	bulb.emission_energy_multiplier = 6.0

	var step := maxi(1, roundi(lamp_spacing / road.step_length))
	var offset: float = road.road_width * 0.5 + road.rail_offset + road.rail_thickness + 0.35
	var root := Node3D.new()
	root.name = "Lampposts"
	add_child(root)

	var n := 0
	var i := maxi(1, step / 2)
	while i < cl.size() - 1:
		var t := Vector3(cl[i + 1].x - cl[i - 1].x, 0.0, cl[i + 1].z - cl[i - 1].z).normalized()
		var side := Vector3(-t.z, 0.0, t.x)
		if n % 2 == 1:
			side = -side
		var base := cl[i] + side * offset - Vector3(0.0, 0.3, 0.0)
		var toward_road := -side
		var lamp := Node3D.new()
		lamp.name = "Lamp%d" % n
		lamp.transform = Transform3D(Basis(Vector3.UP, atan2(toward_road.x, toward_road.z)), base)
		root.add_child(lamp)

		var top_y := lamp_height + 0.3
		_add_mesh(lamp, pole_mesh, metal, Vector3(0.0, top_y * 0.5, 0.0))
		_add_mesh(lamp, arm_mesh, metal, Vector3(0.0, top_y, lamp_arm_length * 0.5))
		var head_pos := Vector3(0.0, top_y - 0.07, lamp_arm_length)
		_add_mesh(lamp, head_mesh, bulb, head_pos)
		_add_halo(lamp, head_pos - Vector3(0.0, 0.1, 0.0), lamp_color, 2.2, 0.55)

		var spot := SpotLight3D.new()
		spot.position = head_pos - Vector3(0.0, 0.1, 0.0)
		spot.rotation_degrees = Vector3(-90.0, 0.0, 0.0)  # punta verso il basso
		spot.light_color = lamp_color
		spot.light_energy = lamp_energy
		spot.spot_range = lamp_range
		spot.spot_angle = lamp_cone_angle
		spot.spot_attenuation = 0.8
		spot.distance_fade_enabled = true
		spot.distance_fade_begin = lamp_fade_distance
		spot.distance_fade_length = 25.0
		lamp.add_child(spot)

		n += 1
		i += step
	print("[Notte] %d lampioni" % n)


func _add_mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


# Alone luminoso: quad sempre rivolto alla camera, additivo, con sfumatura radiale.
func _add_halo(parent: Node3D, pos: Vector3, color: Color, size: float, alpha: float) -> void:
	var key := "%s_%s" % [color.to_html(), alpha]
	var mat: StandardMaterial3D = _halo_material_cache.get(key)
	if mat == null:
		var grad := Gradient.new()
		grad.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
		grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.22), Color(1, 1, 1, 0)])
		var tex := GradientTexture2D.new()
		tex.gradient = grad
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 128
		tex.height = 128
		mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.albedo_texture = tex
		mat.albedo_color = Color(color.r, color.g, color.b, alpha)
		mat.disable_receive_shadows = true
		_halo_material_cache[key] = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	_add_mesh(parent, quad, mat, pos)


# --- Luci dell'auto ----------------------------------------------------------------

# L'auto guarda verso +Z del nodo Container (vedi vehicle.gd: forward_dir = basis.z).
# Le posizioni dei fanali si ricavano dall'ingombro reale del modello (stesso calcolo
# usato per le collisioni del corpo), cosi' restano giuste se cambi modello o scala.
func _make_car_lights() -> void:
	var container: Node3D = vehicle.vehicle_model
	var minp := Vector3(INF, INF, INF)
	var maxp := Vector3(-INF, -INF, -INF)
	var inv: Transform3D = container.global_transform.affine_inverse()
	for mi in container.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var verts: PackedVector3Array = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			var xf: Transform3D = inv * mi.global_transform
			for v in verts:
				var q: Vector3 = xf * v
				minp = minp.min(q)
				maxp = maxp.max(q)
	if minp.x == INF:
		push_warning("[Notte] modello auto senza mesh: luci non create")
		return

	var sign_z := -1.0 if flip_front_back else 1.0
	var front_z: float = maxp.z if sign_z > 0.0 else minp.z
	var rear_z: float = minp.z if sign_z > 0.0 else maxp.z
	var width := maxp.x - minp.x
	var cx := (minp.x + maxp.x) * 0.5
	var y := minp.y + (maxp.y - minp.y) * 0.32

	var head_mat := StandardMaterial3D.new()
	head_mat.albedo_color = headlight_color
	head_mat.emission_enabled = true
	head_mat.emission = headlight_color
	head_mat.emission_energy_multiplier = 8.0
	var tail_mat := StandardMaterial3D.new()
	tail_mat.albedo_color = taillight_color
	tail_mat.emission_enabled = true
	tail_mat.emission = taillight_color
	tail_mat.emission_energy_multiplier = 7.0

	var lens := SphereMesh.new()
	lens.radius = 0.07
	lens.height = 0.14
	lens.radial_segments = 12
	lens.rings = 6
	var tail_lens := BoxMesh.new()
	tail_lens.size = Vector3(0.2, 0.07, 0.04)

	var lights := Node3D.new()
	lights.name = "CarLights"
	container.add_child(lights)

	for side in [-1.0, 1.0]:
		var x: float = cx + side * width * 0.3

		# fari anteriori: lente emissiva + cono di luce + alone
		var hp := Vector3(x, y, front_z + sign_z * 0.03)
		_add_mesh(lights, lens, head_mat, hp)
		_add_halo(lights, hp + Vector3(0.0, 0.0, sign_z * 0.1), headlight_color, 0.9, 0.5)
		var spot := SpotLight3D.new()
		spot.position = hp
		var dir := Vector3(0.0, -sin(deg_to_rad(headlight_pitch)), sign_z * cos(deg_to_rad(headlight_pitch)))
		spot.basis = Basis.looking_at(dir, Vector3.UP)
		spot.light_color = headlight_color
		spot.light_energy = headlight_energy
		spot.spot_range = headlight_range
		spot.spot_angle = headlight_cone_angle
		spot.spot_attenuation = 1.0
		spot.shadow_enabled = headlight_shadows
		lights.add_child(spot)

		# fanali posteriori: pannello rosso emissivo + luce rossa + alone
		var tp := Vector3(x, y, rear_z - sign_z * 0.02)
		_add_mesh(lights, tail_lens, tail_mat, tp)
		_add_halo(lights, tp - Vector3(0.0, 0.0, sign_z * 0.08), taillight_color, 0.8, 0.55)
		var omni := OmniLight3D.new()
		omni.position = tp - Vector3(0.0, 0.0, sign_z * 0.15)
		omni.light_color = taillight_color
		omni.light_energy = taillight_energy
		omni.omni_range = 4.5
		omni.omni_attenuation = 1.2
		lights.add_child(omni)
