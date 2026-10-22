class_name TreeCrown
extends RefCounted
## T-199: thicker crowns for the Gleditsias (docs/Modelos/Arvore: the adult trees showed the sky through the crown).
## The leaf cards of the surface get one more copy, turned around the trunk axis and pulled toward the crown centre
## (fills the inside), a little darker (inner shade = volume). Same surface/material: no extra draw call.

const TURN_DEG: float = 67.0
const SHRINK: float = 0.84
const INNER_SHADE: float = 0.8


## `arrays` = Mesh.ARRAY_MAX arrays of the leaf surface; returns new arrays with the extra copy appended.
static func thicken(arrays: Array) -> Array:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n: int = verts.size()
	if n == 0:
		return arrays
	var box := AABB(verts[0], Vector3.ZERO)
	for v in verts:
		box = box.expand(v)
	var c: Vector3 = box.get_center()
	var axis := Vector3(c.x, 0.0, c.z)                       # trunk axis (vertical through the crown centre)
	var rot := Basis(Vector3.UP, deg_to_rad(TURN_DEG))
	var out: Array = arrays.duplicate()
	var nv := PackedVector3Array(verts)
	for v in verts:
		var q: Vector3 = rot * (v - axis) + axis
		nv.append(c + (q - c) * SHRINK)
	out[Mesh.ARRAY_VERTEX] = nv
	if arrays[Mesh.ARRAY_NORMAL] != null:
		var nn := PackedVector3Array(arrays[Mesh.ARRAY_NORMAL])
		for v in arrays[Mesh.ARRAY_NORMAL]:
			nn.append(rot * v)
		out[Mesh.ARRAY_NORMAL] = nn
	if arrays[Mesh.ARRAY_TANGENT] != null:
		var t: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		var nt := PackedFloat32Array(t)
		for i in range(0, t.size(), 4):
			var tv: Vector3 = rot * Vector3(t[i], t[i + 1], t[i + 2])
			nt.append_array(PackedFloat32Array([tv.x, tv.y, tv.z, t[i + 3]]))
		out[Mesh.ARRAY_TANGENT] = nt
	for k in [Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]:
		if arrays[k] != null:
			var uv := PackedVector2Array(arrays[k])
			uv.append_array(arrays[k])
			out[k] = uv
	if arrays[Mesh.ARRAY_COLOR] != null:
		var col := PackedColorArray(arrays[Mesh.ARRAY_COLOR])
		for cc in arrays[Mesh.ARRAY_COLOR]:
			col.append(Color(cc.r * INNER_SHADE, cc.g * INNER_SHADE, cc.b * INNER_SHADE, cc.a))
		out[Mesh.ARRAY_COLOR] = col
	if arrays[Mesh.ARRAY_INDEX] != null:
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var ni := PackedInt32Array(idx)
		for i in idx:
			ni.append(i + n)
		out[Mesh.ARRAY_INDEX] = ni
	for k in [Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS, Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
		out[k] = null                                         # not used by the tree models
	return out
