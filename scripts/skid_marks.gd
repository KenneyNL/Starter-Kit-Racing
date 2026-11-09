class_name SkidMarks extends Node3D

# Segni delle gomme posteriori lasciati sull'asfalto durante il drift.
#
# Come funziona:
# - ogni ruota posteriore disegna un nastro di triangoli (mesh in coordinate mondo) mentre
#   il veicolo sta derapando (stessa condizione di fumo e stridio: Vehicle.is_drifting)
# - i nastri sono spezzati in "chunk" da points_per_chunk punti: un chunk intero viene
#   eliminato quando anche il suo ultimo punto e' piu' vecchio di `lifetime`
# - ogni vertice ricorda il suo istante di nascita (UV.x): lo shader calcola l'opacita' dall'eta'
#   e fa sfumare i segni negli ultimi `fade_time` secondi. Nessun costo per-frame sui chunk vecchi.
# - il punto di contatto col suolo si trova con un raycast sotto ogni ruota, quindi i segni
#   seguono pendii e tornanti della mappa Mountain.

const SHADER_CODE := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 mark_color : source_color = vec4(0.02, 0.02, 0.025, 1.0);
uniform float now = 0.0;
uniform float lifetime = 60.0;
uniform float fade_time = 8.0;
uniform float max_opacity = 0.85;

varying float birth;

void vertex() {
	birth = UV.x;
}

void fragment() {
	float age = now - birth;
	float fade = 1.0 - smoothstep(lifetime - fade_time, lifetime, age);
	// bordi morbidi sul lato corto del nastro (UV.y) e dissolvenza a inizio/fine (COLOR.a)
	float edge = smoothstep(0.0, 0.25, UV.y) * (1.0 - smoothstep(0.75, 1.0, UV.y));
	ALBEDO = mark_color.rgb;
	ALPHA = mark_color.a * max_opacity * fade * edge * COLOR.a;
}
"""

@export_group("Properties")
@export var target: Vehicle
## Secondi per cui i segni restano visibili
@export var lifetime: float = 60.0
## Negli ultimi secondi di vita i segni sfumano
@export var fade_time: float = 8.0

@export_group("Look")
@export var mark_color: Color = Color(0.02, 0.02, 0.025, 1.0)
@export_range(0.0, 1.0) var max_opacity: float = 0.85
## Larghezza di ogni segno (metri)
@export var mark_width: float = 0.22
## Sollevamento dal suolo per evitare lo z-fighting (metri)
@export var surface_offset: float = 0.04

@export_group("Emission")
## Distanza minima tra due punti consecutivi del nastro (metri)
@export var min_point_distance: float = 0.2
## Sotto questa velocita' (m/s) non si lasciano segni
@export var min_speed: float = 1.5
## Angolo di derapata minimo (gradi). 0 = stessa condizione di fumo e stridio
@export var min_drift_angle: float = 0.0
## Punti per chunk: piu' basso = piu' chunk piccoli, piu' basso il costo di ricostruzione
@export var points_per_chunk: int = 96
## Layer fisici considerati "asfalto"
@export_flags_3d_physics var ground_mask: int = 1
## Se tra due campioni c'e' piu' di questa distanza (teletrasporto, salto) il nastro si interrompe
@export var max_gap: float = 3.0

class Strip:
	var mesh := ArrayMesh.new()
	var instance: MeshInstance3D
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var point_count: int = 0
	var last_time: float = 0.0

class WheelState:
	var strip: Strip = null
	var has_last: bool = false
	var in_mesh: bool = false
	var last_pos := Vector3.ZERO
	var last_normal := Vector3.UP
	var ramp: int = 0

var _material: ShaderMaterial
var _states: Array[WheelState] = [WheelState.new(), WheelState.new()]
var _finished: Array[Strip] = []
var _now: float = 0.0

func _ready() -> void:

	# I segni vivono in coordinate mondo, indipendenti dal movimento del veicolo
	top_level = true
	global_transform = Transform3D.IDENTITY

	var shader := Shader.new()
	shader.code = SHADER_CODE
	_material = ShaderMaterial.new()
	_material.shader = shader
	_update_material()

func _update_material() -> void:
	_material.set_shader_parameter("mark_color", mark_color)
	_material.set_shader_parameter("lifetime", lifetime)
	_material.set_shader_parameter("fade_time", minf(fade_time, lifetime))
	_material.set_shader_parameter("max_opacity", max_opacity)

func _process(_delta: float) -> void:
	_material.set_shader_parameter("now", _now)

func _physics_process(delta: float) -> void:

	_now += delta

	if target != null and is_instance_valid(target):
		if _should_mark():
			for i in 2:
				_sample_wheel(i)
		else:
			for i in 2:
				_end_strip(_states[i])

	_expire_old_chunks()

func _should_mark() -> bool:
	return target.is_drifting \
		and target.colliding \
		and target.drift_angle >= min_drift_angle \
		and target.linear_velocity.length() >= min_speed

# Posizione mondo della ruota posteriore: 0 = sinistra, 1 = destra
func _wheel_position(index: int) -> Vector3:
	var wheel: Node3D = target.wheel_bl if index == 0 else target.wheel_br
	if wheel != null and is_instance_valid(wheel):
		return wheel.global_position
	# Fallback: stesse posizioni degli emettitori di fumo (TrailLeft / TrailRight)
	var x := 0.25 if index == 0 else -0.25
	return target.vehicle_model.global_transform * Vector3(x, 0.05, -0.35)

func _ground_hit(from_wheel: Vector3) -> Dictionary:
	var up: Vector3 = target.vehicle_model.global_basis.y
	var query := PhysicsRayQueryParameters3D.create(from_wheel + up * 0.6, from_wheel - up * 1.5, ground_mask)
	return get_world_3d().direct_space_state.intersect_ray(query)

func _sample_wheel(index: int) -> void:

	var st: WheelState = _states[index]
	var hit := _ground_hit(_wheel_position(index))

	if hit.is_empty():
		_end_strip(st)
		return

	var normal: Vector3 = hit.normal
	var pos: Vector3 = hit.position + normal * surface_offset

	if !st.has_last:
		st.last_pos = pos
		st.last_normal = normal
		st.has_last = true
		st.in_mesh = false
		st.ramp = 0
		return

	var d := pos - st.last_pos
	var dist := d.length()

	if dist > max_gap:
		_end_strip(st)
		st.last_pos = pos
		st.last_normal = normal
		st.has_last = true
		return

	if dist < min_point_distance:
		return

	var dir := d / dist

	if st.strip == null:
		st.strip = _new_strip()

	# Il primo punto del nastro viene scritto solo ora che si conosce la direzione di marcia
	if !st.in_mesh:
		_push_pair(st.strip, st.last_pos, st.last_normal, dir, clampf(st.ramp / 3.0, 0.0, 1.0))
		st.in_mesh = true

	st.ramp += 1
	_push_pair(st.strip, pos, normal, dir, clampf(st.ramp / 3.0, 0.0, 1.0))
	st.last_pos = pos
	st.last_normal = normal
	_rebuild(st.strip)

	# Chunk pieno: lo si chiude e il nastro prosegue in uno nuovo, senza buchi
	if st.strip.point_count >= points_per_chunk:
		_finished.append(st.strip)
		st.strip = null
		st.in_mesh = false

func _new_strip() -> Strip:
	var strip := Strip.new()
	strip.instance = MeshInstance3D.new()
	strip.instance.mesh = strip.mesh
	strip.instance.material_override = _material
	strip.instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(strip.instance)
	return strip

func _push_pair(strip: Strip, pos: Vector3, normal: Vector3, dir: Vector3, intensity: float) -> void:
	var side := normal.cross(dir).normalized() * (mark_width * 0.5)
	var base := strip.verts.size()
	strip.verts.append(pos - side)
	strip.verts.append(pos + side)
	strip.uvs.append(Vector2(_now, 0.0))
	strip.uvs.append(Vector2(_now, 1.0))
	strip.colors.append(Color(1, 1, 1, intensity))
	strip.colors.append(Color(1, 1, 1, intensity))
	if base >= 2:
		strip.indices.append_array(PackedInt32Array([base - 2, base - 1, base, base - 1, base + 1, base]))
	strip.point_count += 1
	strip.last_time = _now

func _rebuild(strip: Strip) -> void:
	strip.mesh.clear_surfaces()
	if strip.indices.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = strip.verts
	arrays[Mesh.ARRAY_TEX_UV] = strip.uvs
	arrays[Mesh.ARRAY_COLOR] = strip.colors
	arrays[Mesh.ARRAY_INDEX] = strip.indices
	strip.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

# Fine del drift (o ruota in aria): il segno si assottiglia nell'ultimo tratto
func _end_strip(st: WheelState) -> void:
	if st.strip != null:
		var n := st.strip.colors.size()
		if n >= 2:
			for k in [n - 2, n - 1]:
				var c: Color = st.strip.colors[k]
				c.a = 0.0
				st.strip.colors[k] = c
			_rebuild(st.strip)
		_finished.append(st.strip)
		st.strip = null
	st.has_last = false
	st.in_mesh = false
	st.ramp = 0

func _expire_old_chunks() -> void:
	var i := _finished.size() - 1
	while i >= 0:
		var strip := _finished[i]
		if _now - strip.last_time > lifetime:
			strip.instance.queue_free()
			_finished.remove_at(i)
		i -= 1

## Cancella subito tutti i segni (es. a un restart della gara)
func clear() -> void:
	for st in _states:
		if st.strip != null:
			st.strip.instance.queue_free()
			st.strip = null
		st.has_last = false
		st.in_mesh = false
	for strip in _finished:
		strip.instance.queue_free()
	_finished.clear()
