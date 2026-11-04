extends Node3D

# Genera da codice una strada di montagna: terreno, sede stradale, guardrail e collider.
# La linea centrale (centerline) puo' essere assegnata da fuori (futuro generatore
# procedurale); se e' vuota viene creata una salita di prova con tornanti.
# Convenzione: l'auto a rotazione zero guarda verso +Z, quindi il percorso parte verso +Z.

## Emesso una sola volta quando il veicolo (la sfera) attraversa il traguardo.
signal finish_reached(body: Node3D)

@export_group("Percorso")
## Se assegnato, la linea centrale viene letta da questo Path3D (solo a runtime):
## il primo punto e' la partenza, l'ultimo il traguardo.
@export var path: Path3D

@export_group("Strada")
@export var road_width: float = 6.0
@export var road_lift: float = 0.03
## Di quanto l'asfalto visibile sta sotto la superficie fisica su cui rotola l'auto.
## 0.12 e' la differenza che c'e' nelle mappe a tile (ruote a filo dell'asfalto).
@export var asphalt_drop: float = 0.12
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

@export_group("Vegetazione")
## Se abilitata, popola la montagna con alberi e vegetazione
@export var enable_vegetation: bool = true
## Seed del generatore casuale: stesso seed = stessa disposizione degli alberi.
@export var vegetation_seed: int = 12345
## Densita' degli alberi (numero di tentativi di spawn per metro quadro)
@export var tree_density: float = 0.008
## Distanza minima degli alberi dal centro strada (metri)
@export var min_tree_road_distance: float = 6.0
## Distanza minima tra alberi vicini (metri)
@export var min_tree_spacing: float = 3.5
## Pendenza massima del terreno per posizionare alberi (0.0 = piano, 1.0 = 45 gradi)
@export var max_tree_slope: float = 0.8
## Texture colormap (usata per i modelli di vegetazione)
@export var colormap_texture: Texture2D = preload("res://models/Textures/colormap.png")

var centerline: PackedVector3Array = PackedVector3Array()
## Posizione e orientamento (asse +Z = direzione di marcia) del primo e dell'ultimo punto,
## nello spazio locale di questo nodo.
var start_transform := Transform3D.IDENTITY
var finish_transform := Transform3D.IDENTITY
var _finished := false

# Cache del terreno per la vegetazione
var _terrain_min_p := Vector2.ZERO
var _terrain_max_p := Vector2.ZERO
var _terrain_nx: int = 0
var _terrain_nz: int = 0
var _terrain_heights := PackedFloat32Array()


func build() -> void:
	var t0 := Time.get_ticks_msec()
	_finished = false
	if path != null:
		centerline = _centerline_from_path()
	if centerline.size() < 2:
		centerline = make_test_centerline()
	for c in get_children():
		c.queue_free()
	var last := centerline.size() - 1
	start_transform = Transform3D(basis_at(0), centerline[0])
	finish_transform = Transform3D(basis_at(last), centerline[last])
	_build_terrain()
	_build_road()
	_build_rails()
	_build_finish_area()
	if enable_vegetation:
		_build_vegetation()
	print("[MountainRoad] %d campioni, costruita in %d ms" % [centerline.size(), Time.get_ticks_msec() - t0])
	_print_stats()


# Legge la curva del Path3D (solo a runtime) e la campiona ogni step_length metri.
func _centerline_from_path() -> PackedVector3Array:
	var out := PackedVector3Array()
	if path.curve == null or path.curve.point_count < 2:
		push_warning("MountainRoad: il Path3D ha meno di 2 punti, uso il percorso di prova")
		return out
	var c: Curve3D = path.curve.duplicate()
	c.bake_interval = step_length
	var to_local := global_transform.affine_inverse() * path.global_transform
	for p in c.get_baked_points():
		var q := to_local * p
		if out.is_empty() or q.distance_to(out[out.size() - 1]) > 0.5:
			out.append(q)
	return out


# Orientamento nel campione i: l'asse +Z locale guarda nella direzione di marcia
# (l'auto, a rotazione zero, guarda verso +Z).
func basis_at(i: int) -> Basis:
	var a := centerline[maxi(i - 1, 0)]
	var b := centerline[mini(i + 1, centerline.size() - 1)]
	return Basis(Vector3.UP, atan2(b.x - a.x, b.z - a.z))


func _print_stats() -> void:
	var length := 0.0
	var max_grade := 0.0
	for i in range(1, centerline.size()):
		length += Vector2(centerline[i].x - centerline[i - 1].x, centerline[i].z - centerline[i - 1].z).length()
	for i in range(0, centerline.size() - 3):
		var run := Vector2(centerline[i + 3].x - centerline[i].x, centerline[i + 3].z - centerline[i].z).length()
		if run > 0.1:
			max_grade = maxf(max_grade, absf(centerline[i + 3].y - centerline[i].y) / run)
	print("[MountainRoad] percorso: %.2f km, dislivello %.0f m, pendenza max %.0f%%" % [
		length / 1000.0, centerline[centerline.size() - 1].y - centerline[0].y, max_grade * 100.0])


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


func _add_visual(mesh: ArrayMesh, node_name: String) -> void:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)


func _add_collider(mesh: ArrayMesh, node_name: String, friction: float) -> void:
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


func _add_mesh_body(mesh: ArrayMesh, node_name: String, friction: float) -> void:
	_add_visual(mesh, node_name)
	_add_collider(mesh, node_name, friction)


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
	_terrain_min_p = min_p
	_terrain_max_p = max_p
	_terrain_nx = nx
	_terrain_nz = nz
	_terrain_heights = heights
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
	var hw := road_width * 0.5
	var n := centerline.size()
	# l/r: bordi dell'asfalto VISIBILE; pl/pr: bordi della superficie FISICA (collider)
	var vis := Vector3(0.0, road_lift - asphalt_drop, 0.0)
	var phys := Vector3(0.0, road_lift, 0.0)
	var l := PackedVector3Array()
	var r := PackedVector3Array()
	var pl := PackedVector3Array()
	var pr := PackedVector3Array()
	for i in n:
		var s := _side(i)
		l.append(centerline[i] + vis - s * hw)
		r.append(centerline[i] + vis + s * hw)
		pl.append(centerline[i] + phys - s * hw)
		pr.append(centerline[i] + phys + s * hw)
	var down := Vector3(0.0, -0.5, 0.0)

	var asphalt := SurfaceTool.new()
	asphalt.begin(Mesh.PRIMITIVE_TRIANGLES)
	var marks := SurfaceTool.new()
	marks.begin(Mesh.PRIMITIVE_TRIANGLES)
	var flat := SurfaceTool.new()
	flat.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n - 1:
		var s := _side(i)
		_quad(asphalt, l[i], l[i + 1], r[i + 1], r[i], Vector3.UP, asphalt_color)
		_quad(asphalt, l[i], l[i + 1], l[i + 1] + down, l[i] + down, -s, asphalt_color)
		_quad(asphalt, r[i], r[i + 1], r[i + 1] + down, r[i] + down, s, asphalt_color)
		_quad(flat, pl[i], pl[i + 1], pr[i + 1], pr[i], Vector3.UP, asphalt_color)
		if i % 8 < 4:
			# linea di mezzeria tratteggiata (solo visiva, niente collider: niente gradini)
			var lift := Vector3(0.0, 0.02, 0.0)
			var a := centerline[i] + vis + lift
			var b := centerline[i + 1] + vis + lift
			var m := s * 0.08
			_quad(marks, a - m, b - m, b + m, a + m, Vector3.UP, line_color)
	# partenza: striscia verde; traguardo: scacchiera
	_checker(marks, mini(1, n - 1), 0.8, 1, 1, Color(0.2, 0.75, 0.3), Color(0.2, 0.75, 0.3), 0.02)
	_checker(marks, maxi(n - 2, 0), 2.0, 8, 2, Color.WHITE, Color(0.08, 0.08, 0.08), 0.025)
	asphalt.generate_normals()
	marks.generate_normals()
	flat.generate_normals()
	_add_visual(asphalt.commit(), "Road")
	_add_visual(marks.commit(), "RoadMarks")
	_add_collider(flat.commit(), "Road", road_friction)


# Griglia di celle (cols x rows) sulla carreggiata, centrata nel campione i e lunga "length" metri.
func _checker(st: SurfaceTool, i: int, length: float, cols: int, rows: int, col_a: Color, col_b: Color, lift: float) -> void:
	var c0 := centerline[i] + Vector3(0.0, road_lift - asphalt_drop + lift, 0.0)
	var t := (centerline[mini(i + 1, centerline.size() - 1)] - centerline[maxi(i - 1, 0)]).normalized()
	var s := _side(i)
	var hw := road_width * 0.5
	for r in rows:
		var a0 := -length * 0.5 + length * float(r) / float(rows)
		var a1 := -length * 0.5 + length * float(r + 1) / float(rows)
		for k in cols:
			var l0 := -hw + road_width * float(k) / float(cols)
			var l1 := -hw + road_width * float(k + 1) / float(cols)
			var col := col_a if (r + k) % 2 == 0 else col_b
			_quad(st, c0 + t * a0 + s * l0, c0 + t * a1 + s * l0, c0 + t * a1 + s * l1, c0 + t * a0 + s * l1, Vector3.UP, col)


# Zona invisibile sul traguardo: rileva la sfera del veicolo (layer 4 = valore 8).
func _build_finish_area() -> void:
	var i := maxi(centerline.size() - 2, 0)
	var area := Area3D.new()
	area.name = "FinishArea"
	area.collision_layer = 0
	area.collision_mask = 8
	area.transform = Transform3D(basis_at(i), centerline[i] + Vector3(0.0, 2.0, 0.0))
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(road_width + 2.0, 4.0, 1.0)
	cs.shape = box
	area.add_child(cs)
	area.body_entered.connect(_on_finish_body_entered)
	add_child(area)


func _on_finish_body_entered(body: Node3D) -> void:
	if _finished or not (body is RigidBody3D):
		return
	_finished = true
	finish_reached.emit(body)


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


func _sample_terrain_height(x: float, z: float) -> float:
	if _terrain_nx < 2 or _terrain_nz < 2 or _terrain_heights.is_empty():
		return 0.0
	var fx := (x - _terrain_min_p.x) / terrain_cell
	var fz := (z - _terrain_min_p.y) / terrain_cell
	var ix := clampi(int(floor(fx)), 0, _terrain_nx - 2)
	var iz := clampi(int(floor(fz)), 0, _terrain_nz - 2)
	var rx := clampf(fx - float(ix), 0.0, 1.0)
	var rz := clampf(fz - float(iz), 0.0, 1.0)
	var h00 := _terrain_heights[iz * _terrain_nx + ix]
	var h10 := _terrain_heights[iz * _terrain_nx + ix + 1]
	var h01 := _terrain_heights[(iz + 1) * _terrain_nx + ix]
	var h11 := _terrain_heights[(iz + 1) * _terrain_nx + ix + 1]
	var h0 := lerpf(h00, h10, rx)
	var h1 := lerpf(h01, h11, rx)
	return lerpf(h0, h1, rz)


func _sample_terrain_slope(x: float, z: float) -> float:
	if _terrain_nx < 2 or _terrain_nz < 2:
		return 0.0
	var delta := 1.0
	var hx1 := _sample_terrain_height(x + delta, z)
	var hx0 := _sample_terrain_height(x - delta, z)
	var hz1 := _sample_terrain_height(x, z + delta)
	var hz0 := _sample_terrain_height(x, z - delta)
	var gx := (hx1 - hx0) / (2.0 * delta)
	var gz := (hz1 - hz0) / (2.0 * delta)
	return Vector2(gx, gz).length()


func _build_vegetation() -> void:
	if _terrain_heights.is_empty() or centerline.size() < 2:
		return
	
	# Precarichiamo i mesh da MountainTreeMeshes
	var mesh_short := MountainTreeMeshes.get_mesh("tree_pine_short")
	var mesh_tall := MountainTreeMeshes.get_mesh("tree_pine_tall")
	var mesh_giant := MountainTreeMeshes.get_mesh("tree_pine_giant")
	var mesh_bush := MountainTreeMeshes.get_mesh("mound_bush")
	
	if mesh_short == null or mesh_tall == null:
		push_warning("MountainRoad: impossibile caricare i mesh degli alberi")
		return
	
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = colormap_texture
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.9
	
	# Array di MultiMeshInstance3D per ciascuna categoria
	var tree_types: Array[Dictionary] = [
		{"name": "TreesTall", "mesh": mesh_tall, "transforms": []},
		{"name": "TreesShort", "mesh": mesh_short, "transforms": []},
		{"name": "TreesGiant", "mesh": mesh_giant, "transforms": []},
		{"name": "Bushes", "mesh": mesh_bush, "transforms": []}
	]
	
	var width := _terrain_max_p.x - _terrain_min_p.x
	var depth := _terrain_max_p.y - _terrain_min_p.y
	var area := width * depth
	var num_candidates := int(area * tree_density)
	
	# Coordinate 2D della centerline per controllo rapido vicinanza alla strada
	var road_xz := PackedVector2Array()
	for p in centerline:
		road_xz.append(Vector2(p.x, p.z))
	var min_road_d2 := min_tree_road_distance * min_tree_road_distance
	
	# Griglia spaziale per evitare sovrapposizioni tra alberi
	var grid_cell := min_tree_spacing
	var placed_trees := {} # key: Vector2i -> Array of Vector2
	
	var rng := RandomNumberGenerator.new()
	rng.seed = vegetation_seed
	
	# StaticBody per collisioni dei tronchi principali (vicini alla strada)
	var coll_body := StaticBody3D.new()
	coll_body.name = "VegetationColliders"
	var coll_margin := min_tree_road_distance + 15.0 # Mettiamo collider solo per alberi entro 15m dalla strada
	var coll_margin_d2 := coll_margin * coll_margin
	
	for _attempt in num_candidates:
		var x := rng.randf_range(_terrain_min_p.x + 5.0, _terrain_max_p.x - 5.0)
		var z := rng.randf_range(_terrain_min_p.y + 5.0, _terrain_max_p.y - 5.0)
		var p2 := Vector2(x, z)
		
		# 1. Distanza dalla strada
		var closest_d2 := INF
		for rp in road_xz:
			var d2 := p2.distance_squared_to(rp)
			if d2 < closest_d2:
				closest_d2 = d2
				if closest_d2 < min_road_d2:
					break
		if closest_d2 < min_road_d2:
			continue
		
		# 2. Quota e pendenza del terreno
		var y := _sample_terrain_height(x, z)
		if y <= 0.05: # sotto o a filo pavimento di base
			continue
		var slope := _sample_terrain_slope(x, z)
		if slope > max_tree_slope: # roccia troppo ripida per alberi
			continue
		
		# 3. Spaziatura dagli altri alberi (griglia)
		var gx := int(floor(x / grid_cell))
		var gz := int(floor(z / grid_cell))
		var too_close := false
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				var key := Vector2i(gx + dx, gz + dz)
				if placed_trees.has(key):
					for other: Vector2 in placed_trees[key]:
						if p2.distance_squared_to(other) < min_tree_spacing * min_tree_spacing:
							too_close = true
							break
				if too_close:
					break
			if too_close:
				break
		if too_close:
			continue
		
		var cell_key := Vector2i(gx, gz)
		if not placed_trees.has(cell_key):
			placed_trees[cell_key] = []
		placed_trees[cell_key].append(p2)
		
		# 4. Selezione tipo di vegetazione e scala/rotazione
		var rand_val := rng.randf()
		var type_idx: int
		var scale_y: float
		var scale_xz: float
		
		if rand_val < 0.40:
			# Pino alto
			type_idx = 0
			scale_y = rng.randf_range(0.85, 1.25)
			scale_xz = scale_y * rng.randf_range(0.9, 1.1)
		elif rand_val < 0.72:
			# Pino basso
			type_idx = 1
			scale_y = rng.randf_range(0.8, 1.2)
			scale_xz = scale_y * rng.randf_range(0.9, 1.1)
		elif rand_val < 0.88:
			# Pino gigante
			type_idx = 2
			scale_y = rng.randf_range(0.9, 1.3)
			scale_xz = scale_y * rng.randf_range(0.95, 1.05)
		else:
			# Cespuglio / vegetazione bassa
			type_idx = 3
			scale_y = rng.randf_range(0.7, 1.5)
			scale_xz = rng.randf_range(0.8, 1.6)
		
		var rot_y := rng.randf_range(0.0, TAU)
		var basis := Basis(Vector3.UP, rot_y).scaled(Vector3(scale_xz, scale_y, scale_xz))
		# Affondiamo leggermente il modello (0.1m) nel terreno per non avere tronchi volanti su pendenze
		var tree_pos := Vector3(x, y - 0.1, z)
		var xform := Transform3D(basis, tree_pos)
		tree_types[type_idx]["transforms"].append(xform)
		
		# Se l'albero e' un pino ed e' vicino alla strada, aggiungiamo collider cilindrico per il tronco
		if type_idx < 3 and closest_d2 <= coll_margin_d2:
			var trunk_h := 3.5 * scale_y
			var trunk_r := 0.25 * scale_xz
			var cs := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.height = trunk_h
			cyl.radius = trunk_r
			cs.shape = cyl
			cs.position = Vector3(x, y + trunk_h * 0.5 - 0.1, z)
			coll_body.add_child(cs)
	
	# Creazione dei nodi MultiMeshInstance3D
	var veg_root := Node3D.new()
	veg_root.name = "Vegetation"
	
	for tinfo in tree_types:
		var xforms: Array = tinfo["transforms"]
		if xforms.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = tinfo["mesh"]
		mm.instance_count = xforms.size()
		for i in xforms.size():
			mm.set_instance_transform(i, xforms[i])
		
		var mmi := MultiMeshInstance3D.new()
		mmi.name = tinfo["name"]
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		veg_root.add_child(mmi)
	
	if coll_body.get_child_count() > 0:
		veg_root.add_child(coll_body)
	
	add_child(veg_root)

