import struct, json
from PIL import Image

with open('models/decoration-forest.glb', 'rb') as f:
    f.seek(12)
    chunk_len, chunk_type = struct.unpack('<I4s', f.read(8))
    data = json.loads(f.read(chunk_len).decode('utf-8'))
    chunk2_len, chunk2_type = struct.unpack('<I4s', f.read(8))
    bin_data = f.read(chunk2_len)

pos_acc = data['accessors'][0]
positions = [struct.unpack_from('<3f', bin_data, data['bufferViews'][pos_acc['bufferView']].get('byteOffset', 0) + i * 12) for i in range(pos_acc['count'])]
norm_acc = data['accessors'][1]
normals = [struct.unpack_from('<3f', bin_data, data['bufferViews'][norm_acc['bufferView']].get('byteOffset', 0) + i * 12) for i in range(norm_acc['count'])]
uv_acc = data['accessors'][3]
uvs = [struct.unpack_from('<2f', bin_data, data['bufferViews'][uv_acc['bufferView']].get('byteOffset', 0) + i * 8) for i in range(uv_acc['count'])]
ind_acc = data['accessors'][4]
indices = [struct.unpack_from('<H', bin_data, data['bufferViews'][ind_acc['bufferView']].get('byteOffset', 0) + i * 2)[0] for i in range(ind_acc['count'])]
triangles = [(indices[i], indices[i+1], indices[i+2]) for i in range(0, len(indices), 3)]

im = Image.open('models/Textures/colormap.png')

trees_info = [
    ('tree_pine_short', -3.46, -3.15, 0.85, 0.0),
    ('tree_pine_tall', 3.58, -3.86, 1.0, 0.0),
    ('tree_pine_giant', 0.74, 1.18, 1.0, 0.390987)
]

gd_script = '''# Generato automaticamente da decoration-forest.glb
class_name MountainTreeMeshes

static var _cached_meshes := {}

static func get_mesh(type_name: String) -> ArrayMesh:
\tif _cached_meshes.has(type_name):
\t\treturn _cached_meshes[type_name]
\tvar d = DATA.get(type_name)
\tif d == null:
\t\treturn null
\tvar arr := []
\tarr.resize(Mesh.ARRAY_MAX)
\tarr[Mesh.ARRAY_VERTEX] = d["verts"]
\tarr[Mesh.ARRAY_NORMAL] = d["normals"]
\tarr[Mesh.ARRAY_TEX_UV] = d["uvs"]
\tarr[Mesh.ARRAY_INDEX] = d["indices"]
\tvar am := ArrayMesh.new()
\tam.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
\t_cached_meshes[type_name] = am
\treturn am

const DATA := {
'''

for name, cx, cz, rad, y_base in trees_info:
    selected_tris = []
    for t in triangles:
        tcx = sum(positions[v][0] for v in t) / 3.0
        tcz = sum(positions[v][2] for v in t) / 3.0
        if (tcx - cx)**2 + (tcz - cz)**2 < rad**2:
            u = sum(uvs[v][0] for v in t) / 3.0
            v = sum(uvs[v][1] for v in t) / 3.0
            r, g, b = im.getpixel((int(u*512)%512, int(v*512)%512))[:3]
            is_trunk = (r > 150)
            pts = [positions[v] for v in t]
            if is_trunk or min(p[1] for p in pts) > y_base + 0.45:
                selected_tris.append(t)
    
    v_map = {}
    new_pos = []
    new_norm = []
    new_uv = []
    new_ind = []
    for t in selected_tris:
        for vi in t:
            if vi not in v_map:
                v_map[vi] = len(new_pos)
                p = positions[vi]
                new_pos.append(f'Vector3({p[0]-cx:.4f}, {p[1]-y_base:.4f}, {p[2]-cz:.4f})')
                new_norm.append(f'Vector3({normals[vi][0]:.4f}, {normals[vi][1]:.4f}, {normals[vi][2]:.4f})')
                new_uv.append(f'Vector2({uvs[vi][0]:.4f}, {uvs[vi][1]:.4f})')
            new_ind.append(str(v_map[vi]))
            
    gd_script += f'\t"{name}": {{\n'
    gd_script += f'\t\t"verts": PackedVector3Array([{ ", ".join(new_pos) }]),\n'
    gd_script += f'\t\t"normals": PackedVector3Array([{ ", ".join(new_norm) }]),\n'
    gd_script += f'\t\t"uvs": PackedVector2Array([{ ", ".join(new_uv) }]),\n'
    gd_script += f'\t\t"indices": PackedInt32Array([{ ", ".join(new_ind) }]),\n'
    gd_script += '\t},\n'

# Add mound/bush
bush_tris = []
for t in triangles:
    pts = [positions[v] for v in t]
    tcx = sum(p[0] for p in pts) / 3.0
    tcz = sum(p[2] for p in pts) / 3.0
    if (tcx - (-2.06))**2 + (tcz - 2.00)**2 < 1.4**2:
        if all(p[1] >= 0.0 for p in pts) and not any(abs(p[0]) >= 4.9 for p in pts):
            bush_tris.append(t)

v_map = {}
new_pos = []
new_norm = []
new_uv = []
new_ind = []
for t in bush_tris:
    for vi in t:
        if vi not in v_map:
            v_map[vi] = len(new_pos)
            p = positions[vi]
            new_pos.append(f'Vector3({p[0]-(-2.06):.4f}, {p[1]-0.10:.4f}, {p[2]-2.00:.4f})')
            new_norm.append(f'Vector3({normals[vi][0]:.4f}, {normals[vi][1]:.4f}, {normals[vi][2]:.4f})')
            new_uv.append(f'Vector2({uvs[vi][0]:.4f}, {uvs[vi][1]:.4f})')
        new_ind.append(str(v_map[vi]))

gd_script += f'\t"mound_bush": {{\n'
gd_script += f'\t\t"verts": PackedVector3Array([{ ", ".join(new_pos) }]),\n'
gd_script += f'\t\t"normals": PackedVector3Array([{ ", ".join(new_norm) }]),\n'
gd_script += f'\t\t"uvs": PackedVector2Array([{ ", ".join(new_uv) }]),\n'
gd_script += f'\t\t"indices": PackedInt32Array([{ ", ".join(new_ind) }]),\n'
gd_script += '\t},\n'

gd_script += '}\n'

with open('scripts/mountain_tree_meshes.gd', 'w') as f:
    f.write(gd_script)

print('Updated scripts/mountain_tree_meshes.gd successfully!')
