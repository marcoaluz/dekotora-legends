class_name ViaductPiers3D
extends Node3D
## Pilares do viaduto da cidade (T-163; antes eram 2 caixas no RoadFurniture): pilar em "T" da Ponte A (PierT) com a
## viga de topo (hammerhead das vias expressas de Toquio) e, no viaduto antigo da T-153, pilar mais velho e mais
## proximo. Concreto com textura (PontesKit.concrete); uma malha por bloco de pista = 1 chamada por bloco visivel.

const BLOCK_M: float = 300.0
const RANGE_M: float = 600.0
const EVERY: float = 32.0
const EVERY_OLD: float = 24.0
const CAP_H: float = 1.4                 # viga de topo (mesma medida da caixa antiga)
const CAP_D: float = 2.4
const COLOR_NEW := Color(0.8, 0.81, 0.84)
const COLOR_OLD := Color(0.72, 0.69, 0.64)
const SLAB_M: float = 10.0

var counts: Dictionary = {}
var tris: int = 0
var _cube: Array = TrackEvents3D.CUBE


func build(path: TrackPath, deck: float, tod: TimeOfDay) -> void:
	var sts: Dictionary = {}            # bloco -> SurfaceTool
	var L: float = path.track.length_m
	var z: float = 16.0
	while z < L:
		var p: Vector3 = LaneSections.profile(path.track.events, z)   # T-153: viaduto antigo mais estreito
		var w: float = p.x + p.y + 2.0 * RoadMesh.BARRIER_W
		var c: float = (p.y - p.x) * 0.5
		var old: bool = p.y < RoadMesh.BARRIER_IN - 0.01
		var bi: int = int(z / BLOCK_M)
		if not sts.has(bi):
			var s := SurfaceTool.new()
			s.begin(Mesh.PRIMITIVE_TRIANGLES)
			sts[bi] = s
		var st: SurfaceTool = sts[bi]
		var b := Basis(Vector3.UP, path.yaw_at(z))
		var top: Vector3 = path.world_point(z, c / Track.ROAD_HALF_WIDTH_M, 0.0)
		var col: Color = COLOR_OLD if old else COLOR_NEW
		var cap: float = CAP_H if not old else 1.1
		_box(st, b, top + Vector3.UP * (-1.6 - cap * 0.5), Vector3(w - 1.0, cap, CAP_D if not old else 2.0), col)
		var foot: Vector3 = top + Vector3.UP * -deck
		var h: float = deck - 1.6 - cap
		PierT.append(st, foot, b, h, minf(w * 0.42, 9.5) if not old else minf(w * 0.5, 6.0), col, 1.0 if not old else 0.85)
		counts["pier_old" if old else "pier"] = int(counts.get("pier_old" if old else "pier", 0)) + 1
		z += EVERY_OLD if old else EVERY
	_slab(path, sts)
	var mat: StandardMaterial3D = PontesKit.concrete(tod, 0.3)
	for bi in sts:
		var mesh: ArrayMesh = (sts[bi] as SurfaceTool).commit()
		if mesh == null or mesh.get_surface_count() == 0:
			continue
		tris += mesh.surface_get_array_len(0) / 3
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = RANGE_M
		add_child(mi)


## Laje por baixo do tabuleiro (antes, de baixo se via o ceu pelo viaduto): pedacos de SLAB_M que seguem a pista.
func _slab(path: TrackPath, sts: Dictionary) -> void:
	var L: float = path.track.length_m
	var z: float = 0.0
	while z < L - 0.5:
		var zm: float = minf(z + SLAB_M * 0.5, L - 0.5)
		var len_: float = minf(SLAB_M, L - z) + 0.05
		var p: Vector3 = LaneSections.profile(path.track.events, zm)
		var w: float = p.x + p.y + 2.0 * RoadMesh.BARRIER_W
		var c: float = (p.y - p.x) * 0.5
		var bi: int = int(zm / BLOCK_M)
		if not sts.has(bi):
			var s := SurfaceTool.new()
			s.begin(Mesh.PRIMITIVE_TRIANGLES)
			sts[bi] = s
		var col: Color = COLOR_OLD if p.y < RoadMesh.BARRIER_IN - 0.01 else COLOR_NEW
		_box(sts[bi], path.basis_at(zm), path.world_point(zm, c / Track.ROAD_HALF_WIDTH_M, -1.45), Vector3(w, 0.3, len_), col * 0.9)
		z += SLAB_M


func _box(st: SurfaceTool, b: Basis, c: Vector3, size: Vector3, col: Color) -> void:
	var half: Vector3 = size * 0.5
	for f in _cube:
		var n: Vector3 = (b * (f[0] as Vector3)).normalized()
		var q: Array = f[1]
		var p: Array[Vector3] = []
		for v in q:
			p.append(c + b * ((v as Vector3) * half))
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_color(col)
			st.set_normal(n)
			st.add_vertex(p[i])
