extends Node3D

# Genera da codice una strada di montagna: terreno, sede stradale, guardrail e collider.
# La linea centrale (centerline) puo' essere assegnata da fuori (futuro generatore
# procedurale); se e' vuota viene creata una salita di prova con tornanti.
# Convenzione: l'auto a rotazione zero guarda verso +Z, quindi il percorso parte verso +Z.

@export_group("Strada")
@export var road_width: float = 6.0
@export var road_lift: float = 0.03
@export var rail_height: float = 0.9
@export var rail_offset: float = 0.4
@export var rail_thickness: float = 0.25
@export var rail_friction: float = 0.1
@export var road_friction: float = 1.0

@export_group("Terreno")
@export var terrain_cell: float = 4.0
@export var terrain_margin: float = 60.0
@export var shoulder: float = 2.0
@export var blend_width: float = 8.0
@export var fall_slope: float = 0.6
@export var bed_depth: float = 0.2
@export var skirt_step: int = 3

@export_group("Percorso di prova")
@export var step_length: float = 2.0
@export var flat_start_length: float = 20.0
@export var straight_length: float = 70.0
@export var hairpin_radius: float = 16.0
@export var hairpins: int = 3
@export var straight_grade: float = 0.08
@export var turn_grade: float = 0.05

@export_group("Aspetto")
@export var asphalt_color := Color(0.25, 0.26, 0.28)
@export var line_color := Color(0.9, 0.9, 0.85)
@export var grass_color := Color(0.36, 0.55, 0.28)
@export var rock_color := Color(0.5, 0.47, 0.43)
@export var rail_color := Color(0.8, 0.8, 0.82)

var centerline: PackedVector3Array = PackedVector3Array()


func build() -> void:
	var t0 := Time.get_ticks_msec()
	if centerline.is_empty():
		centerline = make_test_centerline()
	for c in get_children():
		c.queue_free()
	_build_terrain()
	_build_road()
	_build_rails()
	print("[MountainRoad] %d campioni, costruita in %d ms" % [centerline.size(), Time.get_ticks_msec() - t0])


# Percorso di prova: tratto piano, poi salita con tornanti alternati.
func make_test_centerline() -> PackedVector3Array:
	var pts := PackedVector3Array()
	var steps_straight := int(straight_length / step_length)
	var steps_turn := int(PI * hairpin_radius / step_length)
	var segments: Array = []
	var turn_dir := 1.0
	for leg in hairpins + 1:
		segments.append([steps_straight, 0.0, straight_grade])
		if leg < hairpins:
			# curvatura esatta per fare 180 gradi in steps_turn passi
			segments.append([steps_turn, turn_dir * PI / (float(steps_turn) * step_length), turn_grade])
			turn_dir = -turn_dir
	var pos := Vector3.ZERO
	var heading := 0.0
	var grade := 0.0
	var done := 0
	var flat_steps := int(flat_start_length / step_length)
	pts.append(pos)
	for seg in segments:
		for i in int(seg[0]):
			heading += float(seg[1]) * step_length
			var target := float(seg[2]) if done >= flat_steps else 0.0
			grade = lerpf(grade, target, 0.08)
			pos += Vector3(sin(heading) * step_length, grade * step_length, cos(heading) * step_length)
			pts.append(pos)
			done += 1
	return pts


# Versore orizzontale perpendicolare alla direzione di marcia nel campione i.
func _side(i: int) -> Vector3:
	var a := centerline[maxi(i - 1, 0)]
	var b := centerline[mini(i + 1, centerline.size() - 1)]
	var t := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
	return Vector3(-t.z, 0.0, t.x)


# Triangolo con la faccia visibile (e collidente) rivolta verso "facing".
# In Godot la faccia frontale e' quella con vertici in senso orario.
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, facing: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	var n := (c - a).cross(b - a)
	if n.dot(facing) < 0.0:
		var tmp := b
		b = c
		c = tmp
		var tc := cb
		cb = cc
		cc = tc
	st.set_color(ca)
	st.add_vertex(a)
	st.set_color(cb)
	st.add_vertex(b)
	st.set_color(cc)
	st.add_vertex(c)


# Quadrilatero con i 4 vertici in ordine ciclico lungo il perimetro.
func _quad(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, facing: Vector3, col: Color) -> void:
	_tri(st, p0, p1, p2, facing, col, col, col)
	_tri(st, p0, p2, p3, facing, col, col, col)


func _add_mesh_body(mesh: ArrayMesh, node_name: String, friction: float) -> void:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)

	var body := StaticBody3D.new()
	body.name = node_name + "Body"
	var pm := PhysicsMaterial.new()
	pm.friction = friction
	body.physics_material_override = pm
	var shape := mesh.create_trimesh_shape()
	shape.backface_collision = true
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	add_child(body)


func _build_terrain() -> void:
	var n := centerline.size()
	var xz := PackedVector2Array()
	var ys := PackedFloat32Array()
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for p in centerline:
		xz.append(Vector2(p.x, p.z))
		ys.append(p.y)
		min_p = Vector2(minf(min_p.x, p.x), minf(min_p.y, p.z))
		max_p = Vector2(maxf(max_p.x, p.x), maxf(max_p.y, p.z))
	min_p -= Vector2.ONE * terrain_margin
	max_p += Vector2.ONE * terrain_margin

	var nx := int(ceil((max_p.x - min_p.x) / terrain_cell)) + 1
	var nz := int(ceil((max_p.y - min_p.y) / terrain_cell)) + 1
	var edge := road_width * 0.5 + shoulder
	var heights := PackedFloat32Array()
	heights.resize(nx * nz)

	for iz in nz:
		for ix in nx:
			var p := Vector2(min_p.x + ix * terrain_cell, min_p.y + iz * terrain_cell)
			var best_d2 := INF
			var best_y := 0.0
			for i in n:
				var d2 := p.distance_squared_to(xz[i])
				if d2 < best_d2:
					best_d2 = d2
					best_y = ys[i]
			var d := sqrt(best_d2)
			var road_h := best_y - bed_depth
			var h := road_h
			if d > edge:
				# fuori dalla sede: pendio che scende dalla strada, media pesata
				# tra i campioni vicini per evitare salti tra un ramo e l'altro
				var wsum := 0.0
				var hsum := 0.0
				for i in range(0, n, skirt_step):
					var di := p.distance_to(xz[i])
					var q := di * di + 1.0
					var w := 1.0 / (q * q)
					wsum += w
					hsum += w * (ys[i] - fall_slope * maxf(0.0, di - edge))
				var skirt := maxf(hsum / wsum, 0.0)
				h = lerpf(road_h, skirt, smoothstep(edge, edge + blend_width, d))
			heights[iz * nx + ix] = maxf(h, 0.0) if d > edge else h

	# vertici e colori (erba -> roccia in base alla pendenza)
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	verts.resize(nx * nz)
	cols.resize(nx * nz)
	for iz in nz:
		for ix in nx:
			var ixl := maxi(ix - 1, 0)
			var ixr := mini(ix + 1, nx - 1)
			var izd := maxi(iz - 1, 0)
			var izu := mini(iz + 1, nz - 1)
			var gx := (heights[iz * nx + ixr] - heights[iz * nx + ixl]) / (terrain_cell * (ixr - ixl))
			var gz := (heights[izu * nx + ix] - heights[izd * nx + ix]) / (terrain_cell * (izu - izd))
			var rock := clampf((Vector2(gx, gz).length() - 0.45) / 0.5, 0.0, 1.0)
			verts[iz * nx + ix] = Vector3(min_p.x + ix * terrain_cell, heights[iz * nx + ix], min_p.y + iz * terrain_cell)
			cols[iz * nx + ix] = grass_color.lerp(rock_color, rock)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in nz - 1:
		for ix in nx - 1:
			var i00 := iz * nx + ix
			var i10 := i00 + 1
			var i01 := i00 + nx
			var i11 := i01 + 1
			_tri(st, verts[i00], verts[i10], verts[i01], Vector3.UP, cols[i00], cols[i10], cols[i01])
			_tri(st, verts[i10], verts[i11], verts[i01], Vector3.UP, cols[i10], cols[i11], cols[i01])
	st.generate_normals()
	_add_mesh_body(st.commit(), "Terrain", road_friction)


func _build_road() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := road_width * 0.5
	var n := centerline.size()
	var l := PackedVector3Array()
	var r := PackedVector3Array()
	for i in n:
		var c := centerline[i] + Vector3(0.0, road_lift, 0.0)
		var s := _side(i)
		l.append(c - s * hw)
		r.append(c + s * hw)
	var down := Vector3(0.0, -0.5, 0.0)
	for i in n - 1:
		var s := _side(i)
		_quad(st, l[i], l[i + 1], r[i + 1], r[i], Vector3.UP, asphalt_color)
		_quad(st, l[i], l[i + 1], l[i + 1] + down, l[i] + down, -s, asphalt_color)
		_quad(st, r[i], r[i + 1], r[i + 1] + down, r[i] + down, s, asphalt_color)
		if i % 8 < 4:
			# linea di mezzeria tratteggiata
			var lift := Vector3(0.0, 0.02, 0.0)
			var a := centerline[i] + Vector3(0.0, road_lift, 0.0) + lift
			var b := centerline[i + 1] + Vector3(0.0, road_lift, 0.0) + lift
			var m := _side(i) * 0.08
			_quad(st, a - m, b - m, b + m, a + m, Vector3.UP, line_color)
	st.generate_normals()
	_add_mesh_body(st.commit(), "Road", road_friction)


func _build_rails() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)  # ombreggiatura piatta
	var n := centerline.size()
	var in_off := road_width * 0.5 + rail_offset
	var out_off := in_off + rail_thickness
	for sgn: float in [-1.0, 1.0]:
		var prof: Array = []
		for i in n:
			var c := centerline[i]
			var s := _side(i) * sgn
			var lo := c.y - 0.3
			var hi := c.y + rail_height
			var cin := c + s * in_off
			var cout := c + s * out_off
			prof.append([
				Vector3(cin.x, lo, cin.z), Vector3(cin.x, hi, cin.z),
				Vector3(cout.x, hi, cout.z), Vector3(cout.x, lo, cout.z)])
		for i in n - 1:
			var p: Array = prof[i]
			var q: Array = prof[i + 1]
			var s_out := _side(i) * sgn
			_quad(st, p[0], p[1], q[1], q[0], -s_out, rail_color)
			_quad(st, p[1], p[2], q[2], q[1], Vector3.UP, rail_color)
			_quad(st, p[2], p[3], q[3], q[2], s_out, rail_color)
	st.generate_normals()
	_add_mesh_body(st.commit(), "Rails", rail_friction)
