class_name MountainTreeMeshes

static var _cached_meshes := {}
static var _raw_data := {}

static func _ensure_loaded() -> void:
	if not _raw_data.is_empty():
		return
	var file := FileAccess.open("res://models/trees_mesh_data.json", FileAccess.READ)
	if file == null:
		push_error("MountainTreeMeshes: impossibile aprire res://models/trees_mesh_data.json")
		return
	var json_str := file.get_as_text()
	var test_json_conv := JSON.new()
	var parse_err := test_json_conv.parse(json_str)
	if parse_err == OK:
		_raw_data = test_json_conv.data
	else:
		push_error("MountainTreeMeshes: errore nel parsing JSON: %s" % test_json_conv.get_error_message())


static func get_mesh(type_name: String) -> ArrayMesh:
	if _cached_meshes.has(type_name):
		return _cached_meshes[type_name]
	_ensure_loaded()
	var d = _raw_data.get(type_name)
	if d == null:
		return null
	
	var raw_verts: Array = d["verts"]
	var raw_normals: Array = d["normals"]
	var raw_uvs: Array = d["uvs"]
	var raw_indices: Array = d["indices"]
	
	var verts := PackedVector3Array()
	verts.resize(raw_verts.size())
	for i in raw_verts.size():
		var p: Array = raw_verts[i]
		verts[i] = Vector3(p[0], p[1], p[2])
	
	var normals := PackedVector3Array()
	normals.resize(raw_normals.size())
	for i in raw_normals.size():
		var n: Array = raw_normals[i]
		normals[i] = Vector3(n[0], n[1], n[2])
		
	var uvs := PackedVector2Array()
	uvs.resize(raw_uvs.size())
	for i in raw_uvs.size():
		var u: Array = raw_uvs[i]
		uvs[i] = Vector2(u[0], u[1])
		
	var indices := PackedInt32Array()
	indices.resize(raw_indices.size())
	for i in raw_indices.size():
		indices[i] = int(raw_indices[i])
		
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = indices
	
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_cached_meshes[type_name] = am
	return am
