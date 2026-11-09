extends Node3D

# Genera da codice una strada di montagna: terreno, sede stradale, guardrail e collider.
# La linea centrale (centerline) puo' essere assegnata da fuori (futuro generatore
# procedurale); se e' vuota viene creata una salita di prova con tornanti.
# Convenzione: l'auto a rotazione zero guarda verso +Z, quindi il percorso parte verso +Z.

## Emesso una sola volta quando il veicolo (la sfera) attraversa il traguardo.
signal finish_reached(body: Node3D)

## Modello del tile traguardo delle mappe a tile: da qui si estrae solo l'arco.
const GATE_SCENE := preload("res://models/track-finish.glb")

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

@export_group("Arco partenza/arrivo")
## Piazza l'arco di track-finish sulla partenza e sul traguardo.
@export var enable_gates: bool = true
## Scala dell'arco (1.0 = dimensioni del tile originale: luce interna 10 m, alto 7 m).
@export var gate_scale: float = 1.0
## Di quanto i piedi dell'arco affondano sotto l'asfalto, per non farli "volare" sui pendii.
@export var gate_sink: float = 0.4

@export_group("Piazzali partenza/arrivo")
## Piazzale di cemento (stile parcheggio) dietro la partenza e oltre il traguardo.
@export var enable_lots: bool = true
## Lato del piazzale quadrato (metri).
@export var lot_size: float = 32.0
## Spessore visibile del bordo del piazzale sotto il piano (metri).
@export var lot_skirt: float = 3.0
@export var lot_color := Color(0.62, 0.62, 0.60)
@export var lot_line_color := Color(0.92, 0.92, 0.88)

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

@export_group("Guardrail")
## Sostituisce il muro pieno con un guardrail (barra a W + pali). Il collider resta quello
## del muro: la fisica non cambia, cambia solo l'aspetto.
@export var enable_guardrails: bool = true
## Un palo ogni N campioni della linea centrale (con step_length 2 m: 2 = un palo ogni 4 m).
@export var guard_post_every: int = 2
## Un catarifrangente ogni N pali.
@export var guard_reflector_every: int = 3
## Emissione dei catarifrangenti (la mappa notturna la alza).
@export var reflector_glow: float = 0.6
@export var post_color := Color(0.42, 0.43, 0.46)

@export_group("Nature Kit")
## Alberi, rocce e vegetazione del Kenney Nature Kit, in aggiunta agli alberi gia' presenti.
@export var enable_nature_kit: bool = true
@export_dir var nature_kit_dir: String = "res://assets/kenney_nature-kit/Models/GLTF format"
## Moltiplicatore della densita' di alberi e vegetazione del Nature Kit.
@export var nature_density: float = 1.0
@export var nature_seed: int = 777
## Distanza minima dal centro strada per gli oggetti del Nature Kit (metri).
@export var nk_min_road_distance: float = 5.5
@export var nk_tree_spacing: float = 3.0
## Profondita' della fascia di alberi ai lati della strada (metri, oltre il guardrail).
@export var nk_tree_band: float = 22.0
@export var nk_tree_chance: float = 0.8
## I modelli del kit sono piccoli (un pino e' ~1.5 m): qui si ingrandiscono.
@export var nk_tree_scale := Vector2(3.0, 5.5)
## Il kit e' esportato con colori non naturali e "unlit": qui i materiali vengono rimappati
## per nome con una palette da montagna (illuminata). Se false, restano quelli originali.
@export var nk_recolor: bool = true
## Rocce nell'interno dei tornanti.
@export var enable_rocks: bool = true
## Lunghezza di strada (metri) su cui si misura quanto si gira per riconoscere un tornante.
@export var hairpin_window: float = 50.0
## Un tratto conta come tornante se il suo raggio medio di curva e' sotto questo valore (metri).
@export var hairpin_max_radius: float = 40.0
## Probabilita' di una roccia per campione e per tentativo nei tornanti.
@export var rock_chance: float = 0.5
@export var rock_scale := Vector2(2.5, 4.5)
## Ciuffi di vegetazione bassa per campione e per lato.
@export var plant_per_sample: float = 3.0
@export var plant_band: float = 10.0

var centerline: PackedVector3Array = PackedVector3Array()
## Posizione e orientamento (asse +Z = direzione di marcia) del primo e dell'ultimo punto,
## nello spazio locale di questo nodo.
var start_transform := Transform3D.IDENTITY
var finish_transform := Transform3D.IDENTITY
var _finished := false
## Piazzali: origine (punto della strada), dir (verso l'esterno), side (laterale).
var _lots: Array[Dictionary] = []

# Griglia di spaziatura degli alberi (condivisa tra vegetazione originale e Nature Kit).
var _veg_grid := {}
var _nk_cache := {}

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
	_setup_lots()
	_build_terrain()
	_build_road()
	_build_lots()
	_build_rails()
	_build_finish_area()
	if enable_gates:
		_build_gates()
	if enable_vegetation:
		_build_vegetation()
	if enable_nature_kit:
		_build_nature_kit()
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
			var hh := maxf(h, 0.0) if d > edge else h
			for lot in _lots:
				# piazzale piano; fuori dal bordo il terreno scende con fall_slope (come ai lati
				# della strada) invece di precipitare, poi si raccorda al terreno naturale
				var od := _lot_outside_distance(lot, p.x, p.y)
				if od < blend_width * 3.0:
					var pad_h: float = lot["origin"].y - bed_depth
					var line := pad_h - fall_slope * od
					var outer := hh
					if hh < line:
						outer = lerpf(line, hh, smoothstep(0.0, blend_width * 3.0, od))
					hh = lerpf(pad_h, outer, smoothstep(0.0, blend_width, od))
			heights[iz * nx + ix] = hh

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


# Archi di partenza e arrivo: stessa posizione delle strisce (partenza campione 1, traguardo
# penultimo campione). Il modello e' largo 14 m con i piedi a +-5..7 m dall'asse, quindi
# sta fuori dai guardrail (che arrivano a ~3.7 m) e non serve nessun collider.
func _build_gates() -> void:
	var mesh := _make_gate_mesh()
	if mesh == null:
		return
	var n := centerline.size()
	_add_gate("StartGate", mini(1, n - 1), mesh)
	_add_gate("FinishGate", maxi(n - 2, 0), mesh)


func _add_gate(node_name: String, i: int, mesh: ArrayMesh) -> void:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	var b := basis_at(i).scaled(Vector3.ONE * gate_scale)
	mi.transform = Transform3D(b, centerline[i] + Vector3(0.0, road_lift - asphalt_drop - gate_sink, 0.0))
	add_child(mi)


# track-finish.glb e' un tile intero (strada 10x10 m + arco). Qui si tengono solo i triangoli
# dell'arco, cosi' non compare il pezzo di strada piatta sopra la nostra strada in pendenza.
func _make_gate_mesh() -> ArrayMesh:
	var root := GATE_SCENE.instantiate()
	var src: MeshInstance3D = root as MeshInstance3D
	if src == null:
		var found := root.find_children("*", "MeshInstance3D", true, false)
		if not found.is_empty():
			src = found[0] as MeshInstance3D
	if src == null or src.mesh == null or src.mesh.get_surface_count() == 0:
		push_warning("MountainRoad: nessuna mesh in track-finish.glb, archi non creati")
		root.free()
		return null
	var arrays := src.mesh.surface_get_arrays(0)
	var material := src.mesh.surface_get_material(0)
	root.free()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var kept := PackedInt32Array()
	for t in range(0, idx.size() - 2, 3):
		if _is_gate_triangle(verts[idx[t]], verts[idx[t + 1]], verts[idx[t + 2]]):
			kept.append(idx[t])
			kept.append(idx[t + 1])
			kept.append(idx[t + 2])
	if kept.is_empty():
		push_warning("MountainRoad: filtro dell'arco senza triangoli, archi non creati")
		return null
	arrays[Mesh.ARRAY_INDEX] = kept
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	return mesh


# L'arco occupa |z| <= 1.5 (il tile arriva a 5) e, nella fascia |x| <= 5, sta sopra 0.8 m
# (l'asfalto del tile e' sotto 0.1 m, i bordi a 0.75 m). I piedi sono a |x| > 5.
func _is_gate_triangle(a: Vector3, b: Vector3, c: Vector3) -> bool:
	var max_z := maxf(absf(a.z), maxf(absf(b.z), absf(c.z)))
	if max_z > 1.6:
		return false
	var max_x := maxf(absf(a.x), maxf(absf(b.x), absf(c.x)))
	var max_y := maxf(a.y, maxf(b.y, c.y))
	return max_x > 5.05 or max_y > 0.8


# Piazzali quadrati: il bordo vicino alla strada passa dal primo/ultimo campione e il piazzale
# si estende verso l'esterno (dietro la partenza, oltre il traguardo), centrato sull'asse.
func _setup_lots() -> void:
	_lots.clear()
	if not enable_lots:
		return
	var last := centerline.size() - 1
	for info in [["StartLot", 0, -1.0], ["FinishLot", last, 1.0]]:
		var dir: Vector3 = basis_at(info[1]).z * float(info[2])
		_lots.append({
			"name": info[0],
			"origin": centerline[info[1]],
			"dir": dir,
			"side": Vector3(-dir.z, 0.0, dir.x),
		})


# Distanza (in pianta) dal rettangolo del piazzale: 0 se il punto e' dentro.
func _lot_outside_distance(lot: Dictionary, x: float, z: float) -> float:
	var o: Vector3 = lot["origin"]
	var dir: Vector3 = lot["dir"]
	var side: Vector3 = lot["side"]
	var dx := x - o.x
	var dz := z - o.z
	var u := dx * dir.x + dz * dir.z
	var v := dx * side.x + dz * side.z
	var qu := maxf(maxf(-u, u - lot_size), 0.0)
	var qv := maxf(absf(v) - lot_size * 0.5, 0.0)
	return sqrt(qu * qu + qv * qv)


func _near_lot(x: float, z: float, margin: float) -> bool:
	for lot in _lots:
		if _lot_outside_distance(lot, x, z) < margin:
			return true
	return false


# Punto del piazzale: u metri verso l'esterno dalla strada, v metri di lato, quota y.
func _lot_point(lot: Dictionary, u: float, v: float, y: float) -> Vector3:
	var o: Vector3 = lot["origin"]
	var dir: Vector3 = lot["dir"]
	var side: Vector3 = lot["side"]
	return Vector3(o.x + dir.x * u + side.x * v, y, o.z + dir.z * u + side.z * v)


func _build_lots() -> void:
	for lot in _lots:
		_build_lot(lot)


func _build_lot(lot: Dictionary) -> void:
	var node_name: String = lot["name"]
	var dir: Vector3 = lot["dir"]
	var side: Vector3 = lot["side"]
	var y0: float = lot["origin"].y
	var yv := y0 + road_lift - asphalt_drop  # cemento visibile
	var yp := y0 + road_lift                 # superficie fisica, come la strada
	var h := lot_size * 0.5
	var down := Vector3(0.0, -lot_skirt, 0.0)

	var slab := SurfaceTool.new()
	slab.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c00 := _lot_point(lot, 0.0, -h, yv)
	var c10 := _lot_point(lot, lot_size, -h, yv)
	var c11 := _lot_point(lot, lot_size, h, yv)
	var c01 := _lot_point(lot, 0.0, h, yv)
	_quad(slab, c00, c10, c11, c01, Vector3.UP, lot_color)
	_quad(slab, c00, c10, c10 + down, c00 + down, -side, lot_color)
	_quad(slab, c01, c11, c11 + down, c01 + down, side, lot_color)
	_quad(slab, c10, c11, c11 + down, c10 + down, dir, lot_color)
	_quad(slab, c00, c01, c01 + down, c00 + down, -dir, lot_color)
	slab.generate_normals()
	_add_visual(slab.commit(), node_name)

	# stalli: file lungo i due lati e lungo il lato opposto alla strada
	var marks := SurfaceTool.new()
	marks.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ym := yv + 0.02
	var stall := 5.0
	var pitch := 3.0
	var margin := 4.0
	var rows := int(floor((lot_size - 2.0 * margin) / pitch))
	for sgn: float in [-1.0, 1.0]:
		for k in rows + 1:
			var u := margin + float(k) * pitch
			_lot_line(marks, lot, u, sgn * h, u, sgn * (h - stall), ym)
	var cols := int(floor((lot_size - 2.0 * (stall + 1.0)) / pitch))
	var v0 := -float(cols) * pitch * 0.5
	for k in cols + 1:
		var v := v0 + float(k) * pitch
		_lot_line(marks, lot, lot_size, v, lot_size - stall, v, ym)
	marks.generate_normals()
	_add_visual(marks.commit(), node_name + "Marks")

	# collider piatto alla quota fisica della strada (niente gradino all'ingresso)
	var flat := SurfaceTool.new()
	flat.begin(Mesh.PRIMITIVE_TRIANGLES)
	_quad(flat, _lot_point(lot, 0.0, -h, yp), _lot_point(lot, lot_size, -h, yp),
		_lot_point(lot, lot_size, h, yp), _lot_point(lot, 0.0, h, yp), Vector3.UP, lot_color)
	flat.generate_normals()
	_add_collider(flat.commit(), node_name, road_friction)


func _lot_line(st: SurfaceTool, lot: Dictionary, u0: float, v0: float, u1: float, v1: float, y: float) -> void:
	var a := _lot_point(lot, u0, v0, y)
	var b := _lot_point(lot, u1, v1, y)
	var d := (b - a).normalized()
	var m := Vector3(-d.z, 0.0, d.x) * 0.06
	_quad(st, a - m, b - m, b + m, a + m, Vector3.UP, lot_line_color)


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
	if enable_guardrails:
		# muro invisibile (stesso collider di prima) + guardrail solo visivo
		_add_collider(st.commit(), "Rails", rail_friction)
		_build_guardrail_visual()
	else:
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
	_veg_grid.clear()
	var placed_trees := _veg_grid # key: Vector2i -> Array of Vector2
	
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
		
		# 1b. Niente alberi sui piazzali
		if _near_lot(x, z, 3.0):
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



# --- Guardrail ----------------------------------------------------------------------
# Barra a "W" su pali, al posto del muro pieno. Solo visivo: il muro (invisibile) resta
# il collider, quindi la fisica e le prestazioni di guida non cambiano.
func _build_guardrail_visual() -> void:
	var beam := SurfaceTool.new()
	beam.begin(Mesh.PRIMITIVE_TRIANGLES)
	beam.set_smooth_group(-1)
	var posts := SurfaceTool.new()
	posts.begin(Mesh.PRIMITIVE_TRIANGLES)
	posts.set_smooth_group(-1)
	var refl := SurfaceTool.new()
	refl.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := centerline.size()
	var base := road_width * 0.5 + rail_offset  # faccia della barra rivolta alla strada
	# profilo a W: x = distanza verso l'esterno, y = quota sopra la strada
	var prof: Array[Vector2] = [
		Vector2(0.0, 0.35), Vector2(0.07, 0.46), Vector2(0.0, 0.57),
		Vector2(0.07, 0.68), Vector2(0.0, 0.80)]
	var back_u := 0.10
	var top_h := prof[prof.size() - 1].y
	var bot_h := prof[0].y
	var dark := rail_color.darkened(0.25)
	var post_n := 0
	for sgn: float in [-1.0, 1.0]:
		var refl_col := Color(1.0, 0.95, 0.8) if sgn < 0.0 else Color(1.0, 0.55, 0.1)
		for i in n - 1:
			var s0 := _side(i) * sgn
			var s1 := _side(i + 1) * sgn
			var c0 := centerline[i]
			var c1 := centerline[i + 1]
			for k in prof.size() - 1:
				var a := prof[k]
				var b := prof[k + 1]
				# normale del segmento di profilo, rivolta verso la strada (u negativo)
				var nu := -(b.y - a.y)
				var nh := b.x - a.x
				var facing := s0 * nu + Vector3.UP * nh
				_quad(beam,
					c0 + s0 * (base + a.x) + Vector3.UP * a.y,
					c1 + s1 * (base + a.x) + Vector3.UP * a.y,
					c1 + s1 * (base + b.x) + Vector3.UP * b.y,
					c0 + s0 * (base + b.x) + Vector3.UP * b.y,
					facing, rail_color)
			# bordo superiore, inferiore e retro
			_quad(beam,
				c0 + s0 * (base + 0.0) + Vector3.UP * top_h, c1 + s1 * (base + 0.0) + Vector3.UP * top_h,
				c1 + s1 * (base + back_u) + Vector3.UP * top_h, c0 + s0 * (base + back_u) + Vector3.UP * top_h,
				Vector3.UP, rail_color.lightened(0.1))
			_quad(beam,
				c0 + s0 * (base + 0.0) + Vector3.UP * bot_h, c1 + s1 * (base + 0.0) + Vector3.UP * bot_h,
				c1 + s1 * (base + back_u) + Vector3.UP * bot_h, c0 + s0 * (base + back_u) + Vector3.UP * bot_h,
				Vector3.DOWN, dark)
			_quad(beam,
				c0 + s0 * (base + back_u) + Vector3.UP * bot_h, c1 + s1 * (base + back_u) + Vector3.UP * bot_h,
				c1 + s1 * (base + back_u) + Vector3.UP * top_h, c0 + s0 * (base + back_u) + Vector3.UP * top_h,
				s0, dark)
			if i % guard_post_every == 0:
				var t := Vector3(_side(i).z, 0.0, -_side(i).x)  # direzione di marcia
				var foot := c0 + s0 * (base + back_u + 0.07) + Vector3(0.0, -0.6, 0.0)
				_add_box(posts, foot, t, s0, 0.12, 0.12, 0.6 + 0.86, post_color)
				if post_n % guard_reflector_every == 0:
					# catarifrangente sulla faccia anteriore, a meta' del tratto piu' esterno
					var f := c0 + s0 * (base - 0.012) + Vector3.UP * 0.57
					var ht := t * 0.09
					var hv := Vector3.UP * 0.045
					_quad(refl, f - ht - hv, f + ht - hv, f + ht + hv, f - ht + hv, -s0, refl_col)
				post_n += 1
	beam.generate_normals()
	posts.generate_normals()
	refl.generate_normals()
	_add_visual(beam.commit(), "GuardrailBeam")
	_add_visual(posts.commit(), "GuardrailPosts")
	var rm := StandardMaterial3D.new()
	rm.vertex_color_use_as_albedo = true
	rm.cull_mode = BaseMaterial3D.CULL_DISABLED
	rm.emission_enabled = true
	rm.emission = Color(1.0, 0.7, 0.35)
	rm.emission_energy_multiplier = reflector_glow
	var rmi := MeshInstance3D.new()
	rmi.name = "GuardrailReflectors"
	rmi.mesh = refl.commit()
	rmi.material_override = rm
	rmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rmi)


# Parallelepipedo con la base centrata in "bottom", lati lungo t (size_t) e s (size_s).
func _add_box(st: SurfaceTool, bottom: Vector3, t: Vector3, s: Vector3, size_t: float, size_s: float, height: float, col: Color) -> void:
	var ht := t * size_t * 0.5
	var hs := s * size_s * 0.5
	var up := Vector3(0.0, height, 0.0)
	var c00 := bottom - ht - hs
	var c10 := bottom + ht - hs
	var c11 := bottom + ht + hs
	var c01 := bottom - ht + hs
	_quad(st, c00 + up, c10 + up, c11 + up, c01 + up, Vector3.UP, col)
	_quad(st, c00, c10, c10 + up, c00 + up, -s, col)
	_quad(st, c01, c11, c11 + up, c01 + up, s, col)
	_quad(st, c10, c11, c11 + up, c10 + up, t, col)
	_quad(st, c00, c01, c01 + up, c00 + up, -t, col)


# --- Kenney Nature Kit ----------------------------------------------------------------
# Modelli del kit (cartella GLTF). Hanno materiali a tinta unita incorporati e sono piccoli
# (un pino ~1.5 m, una roccia 0.3-1 m): vengono ingranditi con i parametri *_scale.
const NK_TREES: Array[String] = [
	"tree_pineTallA", "tree_pineTallB", "tree_pineTallC", "tree_pineTallD",
	"tree_pineDefaultA", "tree_pineDefaultB", "tree_pineRoundA", "tree_pineRoundB",
	"tree_pineRoundC", "tree_pineSmallA", "tree_pineSmallB"]
const NK_ROCKS: Array[String] = [
	"rock_largeA", "rock_largeB", "rock_largeC", "rock_largeD", "rock_tallA", "rock_tallB",
	"rock_tallC", "rock_tallD", "stone_largeA", "stone_largeB", "stone_tallA", "stone_tallB"]
const NK_SMALL_ROCKS: Array[String] = [
	"rock_smallA", "rock_smallB", "rock_smallC", "rock_smallD", "rock_smallE", "rock_smallFlatA",
	"stone_smallA", "stone_smallB", "stone_smallC", "stone_smallFlatA"]
const NK_BUSHES: Array[String] = [
	"plant_bush", "plant_bushLarge", "plant_bushSmall", "plant_bushTriangle", "plant_bushLargeTriangle"]
const NK_GRASS: Array[String] = [
	"grass", "grass_large", "grass_leafs", "grass_leafsLarge", "plant_flatShort", "plant_flatTall"]
const NK_FLOWERS: Array[String] = [
	"flower_purpleA", "flower_purpleB", "flower_redA", "flower_redB", "flower_yellowA", "flower_yellowB"]
const NK_DEBRIS: Array[String] = ["log", "log_large", "stump_old", "stump_round"]


func _nk_mesh(model: String) -> Mesh:
	if _nk_cache.has(model):
		return _nk_cache[model]
	var res := load("%s/%s.glb" % [nature_kit_dir, model])
	var mesh: Mesh = null
	if res is PackedScene:
		var root: Node = (res as PackedScene).instantiate()
		var found := root.find_children("*", "MeshInstance3D", true, false)
		if not found.is_empty():
			mesh = (found[0] as MeshInstance3D).mesh
			if nk_recolor and mesh != null:
				mesh = mesh.duplicate() as Mesh
				for si in mesh.get_surface_count():
					var old_mat := mesh.surface_get_material(si)
					var old_name := old_mat.resource_name if old_mat != null else ""
					mesh.surface_set_material(si, _nk_material(old_name, old_mat, model))
		root.free()
	if mesh == null:
		push_warning("MountainRoad: modello Nature Kit non trovato: %s/%s.glb" % [nature_kit_dir, model])
	_nk_cache[model] = mesh
	return mesh


# Palette da montagna per i materiali del kit (per nome del materiale originale).
func _nk_material(mat_name: String, old_mat: Material, model: String) -> Material:
	var key := mat_name + ("@rock" if model.begins_with("rock_") else "")
	if _nk_cache.has("mat:" + key):
		return _nk_cache["mat:" + key]
	var col := Color(0.4, 0.4, 0.4)
	match mat_name:
		"leafsDark": col = Color(0.11, 0.29, 0.15)
		"leafsGreen": col = Color(0.20, 0.42, 0.18)
		"leafsFall": col = Color(0.72, 0.38, 0.14)
		"grass": col = Color(0.30, 0.50, 0.22)
		"woodBark", "woodBarkDark", "woodDark", "wood": col = Color(0.33, 0.23, 0.15)
		"woodInner": col = Color(0.70, 0.55, 0.38)
		"woodBirch": col = Color(0.84, 0.82, 0.76)
		"dirt": col = rock_color if model.begins_with("rock_") else Color(0.42, 0.32, 0.22)
		"dirtDark": col = rock_color.darkened(0.2)
		"stone": col = Color(0.55, 0.55, 0.54)
		"stoneDark": col = Color(0.42, 0.42, 0.41)
		"colorRed", "colorRedDark": col = Color(0.78, 0.14, 0.14)
		"colorYellow": col = Color(0.95, 0.80, 0.20)
		"colorPurple": col = Color(0.55, 0.40, 0.80)
		"colorTan": col = Color(0.78, 0.64, 0.44)
		"colorWhite", "_defaultMat": col = Color(0.90, 0.88, 0.80)
		_:
			if old_mat is BaseMaterial3D:
				col = (old_mat as BaseMaterial3D).albedo_color
	var m := StandardMaterial3D.new()
	m.resource_name = mat_name
	m.albedo_color = col
	m.roughness = 0.9
	m.metallic = 0.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_nk_cache["mat:" + key] = m
	return m


# Un punto (x, z) e' utilizzabile se e' lontano dalla strada e dai piazzali e non troppo
# ripido. (Il terreno e' piano a quota 0 appena fuori dalla strada: li si puo' piantare.)
func _nk_valid(p2: Vector2, road_xz: PackedVector2Array, clearance: float, max_slope: float) -> bool:
	if _near_lot(p2.x, p2.y, 3.0):
		return false
	var c2 := clearance * clearance
	for rp in road_xz:
		if p2.distance_squared_to(rp) < c2:
			return false
	return _sample_terrain_slope(p2.x, p2.y) <= max_slope


# Aggiunge un'istanza (rotazione casuale, affondata nel terreno) al gruppo del suo modello.
# collider: "" nessuno, "box" per le rocce, "trunk" per gli alberi.
func _nk_add(rng: RandomNumberGenerator, buckets: Dictionary, colliders: StaticBody3D, model: String,
		p2: Vector2, scale_range: Vector2, shadows: bool, collider: String, near_road: bool) -> void:
	var mesh := _nk_mesh(model)
	if mesh == null:
		return
	var sc := rng.randf_range(scale_range.x, scale_range.y)
	var rot := rng.randf_range(0.0, TAU)
	var y := _sample_terrain_height(p2.x, p2.y) - 0.05 * sc
	var basis := Basis(Vector3.UP, rot).scaled(Vector3.ONE * sc)
	if not buckets.has(model):
		buckets[model] = {"xf": [], "shadows": shadows}
	buckets[model]["xf"].append(Transform3D(basis, Vector3(p2.x, y, p2.y)))
	if not near_road or collider == "":
		return
	var cs := CollisionShape3D.new()
	if collider == "box":
		var bb := mesh.get_aabb()
		var box := BoxShape3D.new()
		box.size = Vector3(bb.size.x * sc * 0.85, bb.size.y * sc, bb.size.z * sc * 0.85)
		cs.shape = box
		cs.transform = Transform3D(Basis(Vector3.UP, rot), Vector3(p2.x, y + bb.size.y * sc * 0.5, p2.y))
	else:
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.3 * sc / 4.0
		cyl.height = 4.0 * sc / 4.0
		cs.shape = cyl
		cs.position = Vector3(p2.x, y + cyl.height * 0.5, p2.y)
	colliders.add_child(cs)


func _build_nature_kit() -> void:
	if _terrain_heights.is_empty() or centerline.size() < 3:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = nature_seed
	var n := centerline.size()
	var road_xz := PackedVector2Array()
	for p in centerline:
		road_xz.append(Vector2(p.x, p.z))
	var rail_out := road_width * 0.5 + rail_offset + rail_thickness
	var buckets := {}
	var colliders := StaticBody3D.new()
	colliders.name = "NatureKitColliders"
	var near2 := 15.0 * 15.0  # collider solo per quello che sta vicino alla strada
	var rock_count := 0
	var hairpin_samples := 0

	# 1) rocce nell'interno dei tornanti
	if enable_rocks:
		var k := maxi(1, int(round(hairpin_window * 0.5 / step_length)))
		var min_turn := hairpin_window / maxf(hairpin_max_radius, 1.0)  # radianti
		for i in range(k, n - k):
			var t_in := basis_at(i - k).z
			var t_out := basis_at(i + k).z
			var turn := t_in.signed_angle_to(t_out, Vector3.UP)  # > 0 = curva a sinistra
			if absf(turn) < min_turn:
				continue
			hairpin_samples += 1
			# _side() e' il lato destro: l'interno e' dalla parte verso cui si gira
			var inner := -_side(i) if turn > 0.0 else _side(i)
			for _a in 2:
				if rng.randf() > rock_chance * nature_density:
					continue
				var d := rail_out + 1.2 + rng.randf() * 7.0
				var pos := centerline[i] + inner * d
				var p2 := Vector2(pos.x, pos.z)
				if not _nk_valid(p2, road_xz, nk_min_road_distance, 1.2):
					continue
				var pool := NK_ROCKS if rng.randf() < 0.7 else NK_SMALL_ROCKS
				var scale_range := rock_scale if pool == NK_ROCKS else rock_scale * 0.8
				var near := _min_d2(p2, road_xz) < near2
				_nk_add(rng, buckets, colliders, pool[rng.randi() % pool.size()], p2, scale_range, true, "box", near)
				rock_count += 1

	# 2) fascia di alberi ai lati della strada + vegetazione bassa
	for i in range(0, n, 2):
		var side := _side(i)
		var tan := Vector3(side.z, 0.0, -side.x)
		for sgn: float in [-1.0, 1.0]:
			if rng.randf() < nk_tree_chance * nature_density:
				var d := rail_out + 3.0 + rng.randf() * nk_tree_band
				var pos := centerline[i] + side * sgn * d + tan * rng.randf_range(-2.0, 2.0)
				var p2 := Vector2(pos.x, pos.z)
				if _nk_valid(p2, road_xz, nk_min_road_distance, max_tree_slope) and _nk_spacing_ok(p2):
					_nk_register(p2)
					var near := _min_d2(p2, road_xz) < near2
					_nk_add(rng, buckets, colliders, NK_TREES[rng.randi() % NK_TREES.size()], p2, nk_tree_scale, true, "trunk", near)
			var count := int(plant_per_sample * nature_density)
			if rng.randf() < plant_per_sample * nature_density - float(count):
				count += 1
			for _b in count:
				var d2 := rail_out + 0.8 + rng.randf() * plant_band
				var pos2 := centerline[i] + side * sgn * d2 + tan * rng.randf_range(-2.0, 2.0)
				var q2 := Vector2(pos2.x, pos2.z)
				if not _nk_valid(q2, road_xz, rail_out + 0.8, 1.2):
					continue
				var roll := rng.randf()
				if roll < 0.35:
					_nk_add(rng, buckets, colliders, NK_BUSHES[rng.randi() % NK_BUSHES.size()], q2, Vector2(3.5, 6.0), false, "", false)
				elif roll < 0.8:
					_nk_add(rng, buckets, colliders, NK_GRASS[rng.randi() % NK_GRASS.size()], q2, Vector2(3.0, 5.0), false, "", false)
				elif roll < 0.92:
					_nk_add(rng, buckets, colliders, NK_FLOWERS[rng.randi() % NK_FLOWERS.size()], q2, Vector2(3.0, 5.0), false, "", false)
				elif roll < 0.97:
					_nk_add(rng, buckets, colliders, NK_SMALL_ROCKS[rng.randi() % NK_SMALL_ROCKS.size()], q2, Vector2(2.5, 4.5), false, "", false)
				else:
					_nk_add(rng, buckets, colliders, NK_DEBRIS[rng.randi() % NK_DEBRIS.size()], q2, Vector2(3.0, 4.5), false, "", false)

	# 3) un MultiMesh per modello (materiali originali del kit)
	var root := Node3D.new()
	root.name = "NatureKit"
	var total := 0
	for model: String in buckets:
		var xf: Array = buckets[model]["xf"]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _nk_mesh(model)
		mm.instance_count = xf.size()
		for j in xf.size():
			mm.set_instance_transform(j, xf[j])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "NK_" + model
		mmi.multimesh = mm
		if not buckets[model]["shadows"]:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.visibility_range_end = 140.0
		root.add_child(mmi)
		total += xf.size()
	if colliders.get_child_count() > 0:
		root.add_child(colliders)
	add_child(root)
	print("[MountainRoad] Nature Kit: %d istanze, %d rocce in %d campioni di tornante, %d collider" % [
		total, rock_count, hairpin_samples, colliders.get_child_count()])


func _min_d2(p2: Vector2, road_xz: PackedVector2Array) -> float:
	var best := INF
	for rp in road_xz:
		best = minf(best, p2.distance_squared_to(rp))
	return best


# Spaziatura tra alberi: usa la stessa griglia della vegetazione originale.
func _nk_spacing_ok(p2: Vector2) -> bool:
	var gx := int(floor(p2.x / min_tree_spacing))
	var gz := int(floor(p2.y / min_tree_spacing))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var key := Vector2i(gx + dx, gz + dz)
			if _veg_grid.has(key):
				for other: Vector2 in _veg_grid[key]:
					if p2.distance_squared_to(other) < nk_tree_spacing * nk_tree_spacing:
						return false
	return true


func _nk_register(p2: Vector2) -> void:
	var key := Vector2i(int(floor(p2.x / min_tree_spacing)), int(floor(p2.y / min_tree_spacing)))
	if not _veg_grid.has(key):
		_veg_grid[key] = []
	_veg_grid[key].append(p2)
