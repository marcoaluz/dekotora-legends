class_name TruckKit
extends RefCounted
## Cabine trocavel (T-240): cabine e carroceria vem em .glb separados (`assets/vehicles/dekotora/truck/kit/`, gerados por
## `blender/scripts/build_t240_kits.py`) e sao montados aqui, sem um .glb por combinacao:
##   kit/body_<modelo>.glb  chassi sem o eixo da frente + carroceria + decoracao + rodas de tras + MOUNT_* da carroceria
##   kit/cab_<cabine>.glb   cabine + eixo da frente + rodas da frente + "sobrancelha" de luzes + MOUNT_* da frente
## As malhas de mesmo material das duas partes viram UMA malha (cache por combinacao: o caminhao montado tem as mesmas
## chamadas de desenho de um .glb unico). Vale para os 5 caminhoes de homenagem (qualquer cabine) e para as cabines novas
## (flat_wide, flat_quad) nos baus antigos; as outras combinacoes continuam nos .glb de sempre.
## O caminho "virtual" da combinacao (TruckNode.model_path) e dekotora_truck_<modelo>_<cabine>.glb: so o nome conta
## (encaixes em truck/sockets/<nome>.json). Sem render no servidor: o servidor so usa os nomes (CabCatalog).

const DIR := "res://assets/vehicles/dekotora/truck/kit/"
const LOD_DIR := DIR + "lod/"
## Carrocerias de homenagem (T-218): aceitam todas as cabines.
const HOMAGE: Array[String] = ["alubox", "tarp", "pinkbox", "tanker", "dump"]
## Baus antigos: so as cabines novas vem do kit (as antigas continuam no .glb unico de cada combinacao).
const OLD_BODIES: Array[String] = ["base", "leve", "longo", "graneleira"]
## Cabines que so existem em kit (T-218, HAYATE).
const NEW_CABS: Array[String] = ["flat_wide", "flat_quad"]

static var _merged: Dictionary = {}          # "<modelo>_<cabine>[_lodN]/<no>" -> ArrayMesh (ou null = nao junta)


## Esta combinacao e montada pelo kit?
static func uses_kit(body: String, cab: String) -> bool:
	return (body in HOMAGE and cab in CabCatalog.IDS) or (body in OLD_BODIES and cab in NEW_CABS)


## Cabines que o modelo aceita (garagem). Vazio = cabine fixa (Canter, carreta).
static func cabs_for(body: String) -> Array[String]:
	if body in HOMAGE or body in OLD_BODIES:
		return CabCatalog.IDS.duplicate()
	return []


## Caminhao montado (mesma arvore de um .glb: raiz -> DekotoraTruckBase -> malhas, rodas, MOUNT_*). null se faltar arquivo.
static func instantiate(body: String, cab: String) -> Node3D:
	var root: Node3D = _inst(DIR + "body_%s.glb" % body)
	var cab_root: Node3D = _inst(DIR + "cab_%s.glb" % cab)
	if root == null or cab_root == null:
		if root != null:
			root.free()
		if cab_root != null:
			cab_root.free()
		return null
	root.name = "dekotora_truck_%s_%s" % [body, cab]
	_shift(cab_root, body)
	_graft(_host(root), _host(cab_root), "%s_%s" % [body, cab])
	cab_root.free()
	root.set_meta("kit", PackedStringArray([body, cab]))
	return root


## LOD `level` (1 ou 2) da combinacao (as duas partes juntas). null se uma das partes nao tiver LOD (os baus antigos nao
## tem: so o caminhao do jogador usa, sempre perto da camera; as malhas juntas nao deixam trocar so a cabine).
static func lod(body: String, cab: String, level: int) -> Node3D:
	var a: Node3D = _inst(LOD_DIR + "body_%s_lod%d.glb" % [body, level])
	var b: Node3D = _inst(LOD_DIR + "cab_%s_lod%d.glb" % [cab, level])
	if a == null or b == null:
		if a != null:
			a.free()
		if b != null:
			b.free()
		return null
	_shift(b, body)
	_graft(_host(a), _host(b), "%s_%s_lod%d" % [body, cab, level])
	b.free()
	return a


## Nos da parte da cabine que ficaram com nome proprio (sem malha da carroceria para juntar): testes.
static func cab_only_nodes(model: Node3D) -> Array[Node]:
	var out: Array[Node] = []
	for n in model.find_children("*", "", true, false):
		if n.has_meta("kit_cab"):
			out.append(n)
	return out


## A cabine anda junto com o comprimento do bau (leve -2,8 m, longo +1,6 m; TruckNode.LENGTH_DELTA): frente = -z.
static func _shift(cab_root: Node3D, body: String) -> void:
	_host(cab_root).position.z -= float(TruckNode.LENGTH_DELTA.get(body, 0.0))


static func _inst(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var ps: PackedScene = load(path) as PackedScene
	return ps.instantiate() as Node3D if ps != null else null


## No raiz do .glb (o empty exportado) ou a propria raiz.
static func _host(root: Node3D) -> Node3D:
	return root.get_child(0) as Node3D if root.get_child_count() == 1 and root.get_child(0) is Node3D else root


## Passa os filhos de `src` para `dst`: malha com o mesmo nome (mesmo material) vira uma so; o resto muda de pai.
static func _graft(dst: Node3D, src: Node3D, key: String) -> void:
	var to_dst: Transform3D = dst.transform.affine_inverse() * src.transform     # raizes fora da arvore, na origem
	for c in src.get_children():
		var name: String = String(c.name)
		var other: Node = dst.get_node_or_null(NodePath(name))
		if c is MeshInstance3D and other is MeshInstance3D and not name.begins_with("wheel_"):
			var mesh: Mesh = _merge(key + "/" + name, other as MeshInstance3D, c as MeshInstance3D, to_dst)
			if mesh != null:
				(other as MeshInstance3D).mesh = mesh
				continue
		_set_owner(c, null)
		src.remove_child(c)
		if other != null:
			c.name = "cab_" + name
		if c is Node3D:
			(c as Node3D).transform = to_dst * (c as Node3D).transform
		c.set_meta("kit_cab", true)
		dst.add_child(c)
		_set_owner(c, dst.owner if dst.owner != null else dst)


static func _set_owner(n: Node, o: Node) -> void:
	n.owner = o
	for k in n.get_children():
		_set_owner(k, o)


## Junta a malha `b` (da cabine) na malha `a` (da carroceria), no espaco de `a`. null = formatos diferentes (nao junta).
static func _merge(ck: String, a: MeshInstance3D, b: MeshInstance3D, to_dst: Transform3D) -> Mesh:
	if _merged.has(ck):
		return _merged[ck]
	var out: Mesh = null
	var am: Mesh = a.mesh
	var bm: Mesh = b.mesh
	if am != null and bm != null and am.get_surface_count() == 1 and bm.get_surface_count() == 1:
		var xf: Transform3D = a.transform.affine_inverse() * to_dst * b.transform
		var arr: Array = _join(am.surface_get_arrays(0), bm.surface_get_arrays(0), xf)
		if not arr.is_empty():
			var m := ArrayMesh.new()
			m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			m.surface_set_material(0, am.surface_get_material(0))
			m.resource_name = am.resource_name
			out = m
	_merged[ck] = out
	return out


static func _join(a: Array, b: Array, xf: Transform3D) -> Array:
	_fill_missing(a, b)
	_fill_missing(b, a)
	for i in Mesh.ARRAY_MAX:
		if (a[i] == null) != (b[i] == null):
			return []
	for i in [Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS, Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
		if a[i] != null:
			return []
	if a[Mesh.ARRAY_INDEX] == null:
		return []
	var out: Array = []
	out.resize(Mesh.ARRAY_MAX)
	var va: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var vb: PackedVector3Array = b[Mesh.ARRAY_VERTEX]
	var n0: int = va.size()
	var v := va.duplicate()
	for p in vb:
		v.append(xf * p)
	out[Mesh.ARRAY_VERTEX] = v
	var basis: Basis = xf.basis
	var nb: Basis = basis.inverse().transposed()
	if a[Mesh.ARRAY_NORMAL] != null:
		var nn: PackedVector3Array = (a[Mesh.ARRAY_NORMAL] as PackedVector3Array).duplicate()
		for p in (b[Mesh.ARRAY_NORMAL] as PackedVector3Array):
			nn.append((nb * p).normalized())
		out[Mesh.ARRAY_NORMAL] = nn
	if a[Mesh.ARRAY_TANGENT] != null:
		var t: PackedFloat32Array = (a[Mesh.ARRAY_TANGENT] as PackedFloat32Array).duplicate()
		var tb: PackedFloat32Array = b[Mesh.ARRAY_TANGENT]
		for k in range(0, tb.size(), 4):
			var d: Vector3 = (basis * Vector3(tb[k], tb[k + 1], tb[k + 2])).normalized()
			t.append_array([d.x, d.y, d.z, tb[k + 3]])
		out[Mesh.ARRAY_TANGENT] = t
	for i in [Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]:
		if a[i] != null:
			var c: Variant = a[i].duplicate()
			c.append_array(b[i])
			out[i] = c
	var idx: PackedInt32Array = (a[Mesh.ARRAY_INDEX] as PackedInt32Array).duplicate()
	for k in (b[Mesh.ARRAY_INDEX] as PackedInt32Array):
		idx.append(k + n0)
	out[Mesh.ARRAY_INDEX] = idx
	return out


## UV/UV2/cor que so uma das malhas tem (ex.: o cromo da cabine tem UV e o da carroceria nao): a outra ganha zeros/branco.
## O material nao usa a UV quando nao tem textura, entao a aparencia nao muda.
static func _fill_missing(a: Array, has: Array) -> void:
	var n: int = (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	for i in [Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]:
		if a[i] == null and has[i] != null:
			var uv := PackedVector2Array()
			uv.resize(n)
			a[i] = uv
	if a[Mesh.ARRAY_COLOR] == null and has[Mesh.ARRAY_COLOR] != null:
		var c := PackedColorArray()
		c.resize(n)
		c.fill(Color.WHITE)
		a[Mesh.ARRAY_COLOR] = c
