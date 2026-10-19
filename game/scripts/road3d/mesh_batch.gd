class_name MeshBatch
extends RefCounted
## Junta muitas copias de malhas pequenas (placas, postes, barreiras) numa malha so por BLOCO de pista e por material:
## uma chamada de desenho por material e por bloco visivel, com corte por distancia (visibility_range) no bloco.
## Diferente do MultiMesh, aceita varios modelos diferentes na mesma chamada (todos com o mesmo material).

var block_m: float = 400.0
var range_m: float = 520.0
var _blocks: Dictionary = {}        # indice do bloco -> Array de [Mesh, Transform3D]
var tris: int = 0                   # triangulos somados (depuracao)


func _init(block_m_: float = 400.0, range_m_: float = 520.0) -> void:
	block_m = block_m_
	range_m = range_m_


## Copia de `mesh` com o transform `xf`, guardada no bloco do ponto `z` da pista.
func add(mesh: Mesh, xf: Transform3D, z: float) -> void:
	if mesh == null:
		return
	var bi: int = int(floor(z / block_m))
	if not _blocks.has(bi):
		_blocks[bi] = []
	_blocks[bi].append([mesh, xf])


func is_empty() -> bool:
	return _blocks.is_empty()


## Cria os MeshInstance3D (um por bloco) como filhos de `parent`. Devolve quantos.
func commit(parent: Node3D) -> int:
	var n: int = 0
	for bi in _blocks:
		var sts: Dictionary = {}        # Material -> SurfaceTool
		for it in _blocks[bi]:
			var m: Mesh = it[0]
			for s in m.get_surface_count():
				var mat: Material = m.surface_get_material(s)
				if not sts.has(mat):
					var st := SurfaceTool.new()
					st.begin(Mesh.PRIMITIVE_TRIANGLES)
					sts[mat] = st
				(sts[mat] as SurfaceTool).append_from(m, s, it[1])
		var am := ArrayMesh.new()
		for mat in sts:
			var arrays: Array = (sts[mat] as SurfaceTool).commit_to_arrays()
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			am.surface_set_material(am.get_surface_count() - 1, mat)
			tris += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3 if arrays[Mesh.ARRAY_INDEX] == null \
				else (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		var mi := MeshInstance3D.new()
		mi.mesh = am
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = range_m
		parent.add_child(mi)
		n += 1
	return n
