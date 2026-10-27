class_name RearDoorLamps
extends RefCounted
## T-239 (pedido do Marco): a porta traseira do bau fica SEM luzes; as lanternas de tras ficam so no para-choque (o de
## fabrica ou o da oficina). Muda a decisao 1 da T-231. Feito no jogo, sem regerar os .glb: tira os triangulos das
## lampadas (lamp_*) que estao na face de tras do bau (zona protegida `rear_doors` dos encaixes, alargada ate a quina)
## e os suportes/aros cromados pequenos atras delas. O andon de cima, as luzinhas das laterais e do teto ficam.

## Suporte de lampada: peca pequena (maior lado ate isto), encostada numa lampada tirada e nao na frente dela
## (degrau de escada e trilho ficam).
const HOLDER_MAX: float = 0.75
const HOLDER_TOUCH: float = 0.02

static var _cache: Dictionary = {}          # malha + transform -> ArrayMesh sem as lampadas da porta


## Caixa da face de tras do bau onde nao pode haver luz (espaco do modelo), ou AABB vazia (bau aberto, sem porta).
static func zone(data: Dictionary) -> AABB:
	var prot: Dictionary = data.get("protected", {})
	if not prot.has("rear_doors"):
		return AABB()
	var doors: AABB = TruckSockets.aabb_of(prot["rear_doors"]["box"])
	var box: Dictionary = (data.get("measure", {}) as Dictionary).get("box", {})
	var hw: float = float(box.get("half_w", doors.end.x)) + 0.06
	var rz: float = float(box.get("rear_z", doors.position.z))
	var y0: float = float(box.get("bottom_y", doors.position.y)) - 0.05
	var y1: float = doors.end.y + 0.12            # ate a fileira de cima da porta; o andon fica acima
	return AABB(Vector3(-hw, y0, rz - 0.03), Vector3(2.0 * hw, y1 - y0, 0.45))


## Tira as luzes da porta de tras de `model` (todas as malhas, LODs inclusive; nao mexe nas pecas montadas).
## Devolve quantas pecas (lampadas + suportes) sairam. Chame uma vez, logo depois de instanciar o modelo.
static func strip(model: Node3D, data: Dictionary) -> int:
	var z: AABB = zone(data)
	if z.size == Vector3.ZERO:
		return 0
	var meshes: Array = []
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		if m.mesh != null and not FrameFit._in_part(m, model) and z.intersects(PartFit.rel_xform(m, model) * m.mesh.get_aabb()):
			meshes.append(m)
	# 1) lampadas inteiras dentro da zona
	var drop: Dictionary = {}                   # MeshInstance3D -> {surface: PackedInt32Array de triangulos}
	var lamps: Array[AABB] = []
	var lamp_back: float = -INF
	var count: int = 0
	for m in meshes:
		for s in (m as MeshInstance3D).mesh.get_surface_count():
			if not _is_lamp(m, s):
				continue
			for p in LampMesh.pieces(m, s, model, z):
				_mark(drop, m, s, p.tris)
				lamps.append(p.box)
				lamp_back = maxf(lamp_back, p.box.end.z)
				count += 1
	if lamps.is_empty():
		return 0
	# 2) suportes pequenos encostados nelas (aro, chapa da coluna), nunca na frente da lampada
	for m in meshes:
		for s in (m as MeshInstance3D).mesh.get_surface_count():
			if _is_lamp(m, s):
				continue
			for p in LampMesh.pieces(m, s, model, z):
				var sz: Vector3 = p.box.size
				if maxf(sz.x, maxf(sz.y, sz.z)) > HOLDER_MAX or p.box.end.z > lamp_back + 0.005:
					continue
				for lb in lamps:
					if lb.grow(HOLDER_TOUCH).intersects(p.box):
						_mark(drop, m, s, p.tris)
						count += 1
						break
	for m in drop:
		var mi: MeshInstance3D = m
		var key: String = "%d|%s" % [mi.mesh.get_rid().get_id(), str(PartFit.rel_xform(mi, model))]
		if not _cache.has(key):
			_cache[key] = _without(mi.mesh, drop[m])
		mi.mesh = _cache[key]
	return count


static func _is_lamp(m: MeshInstance3D, s: int) -> bool:
	var mat: Material = m.mesh.surface_get_material(s)
	return mat != null and mat.resource_name.begins_with("lamp_")


static func _mark(drop: Dictionary, m: MeshInstance3D, s: int, tris: PackedInt32Array) -> void:
	if not drop.has(m):
		drop[m] = {}
	var d: Dictionary = drop[m]
	if not d.has(s):
		d[s] = PackedInt32Array()
	var a: PackedInt32Array = d[s]
	a.append_array(tris)
	d[s] = a


static func _without(src: Mesh, by_surface: Dictionary) -> ArrayMesh:
	var am := ArrayMesh.new()
	for si in src.get_surface_count():
		var arr: Array = src.surface_get_arrays(si)
		if by_surface.has(si):
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if idx.is_empty():
				for k in (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size():
					idx.append(k)
			var gone: Dictionary = {}
			for k in by_surface[si]:
				gone[k] = true
			var keep := PackedInt32Array()
			for k in range(0, idx.size(), 3):
				if not gone.has(k):
					keep.append_array([idx[k], idx[k + 1], idx[k + 2]])
			if keep.is_empty():
				keep.append_array([0, 0, 0])           # (superficie vazia: um triangulo degenerado)
			arr[Mesh.ARRAY_INDEX] = keep
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		am.surface_set_material(am.get_surface_count() - 1, src.surface_get_material(si))
	return am


## Ainda ha luz na porta de tras (testes)? Conta as pecas de lampada inteiras dentro da zona.
static func lamps_left(model: Node3D, data: Dictionary) -> int:
	var z: AABB = zone(data)
	if z.size == Vector3.ZERO:
		return 0
	var n: int = 0
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		if m.mesh == null or FrameFit._in_part(m, model):
			continue
		for s in m.mesh.get_surface_count():
			if _is_lamp(m, s):
				for p in LampMesh.pieces(m, s, model, z):
					if p.box.size.length() > 0.001:
						n += 1
	return n
