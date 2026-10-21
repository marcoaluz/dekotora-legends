class_name PierT
extends RefCounted
## Pilar em "T" das vias expressas japonesas (T-163), tirado da Ponte A (pier_t.glb, 302 triangulos): coluna
## arredondada (3,1 x 2,0 m) que abre em leque ate o topo. Cada pilar e uma copia DEFORMADA da malha, gravada num
## SurfaceTool do chamador (mesmo material de concreto = sem chamada de desenho a mais):
## - a coluna (ate FLARE_Z) estica ou encolhe ate a altura pedida;
## - o leque fica com `flare_h` m de altura e a largura do topo vai de TOP_W ate `top_w` (abre so no topo).
## Eixos do pilar: X = atravessando a pista, Y = altura, Z = ao longo da pista (Basis(UP, yaw) da pista).

const MODEL := "res://assets/scenery/kit/pier_t.glb"
const FLARE_Z: float = 7.6        # numeros do build_road_pontes_kit.py (linha PIER)
const TOP_Z: float = 12.5
const TOP_W: float = 5.48
const TOP_D: float = 2.468
const COL_W: float = 3.132
const COL_D: float = 1.971

static var _verts: PackedVector3Array = PackedVector3Array()
static var _norms: PackedVector3Array = PackedVector3Array()


static func _load() -> bool:
	if not _verts.is_empty():
		return true
	if not ResourceLoader.exists(MODEL):
		return false
	var m: ArrayMesh = GlbMesh.merged(MODEL)
	if m.get_surface_count() == 0:
		return false
	var a: Array = m.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if idx.is_empty():
		for i in v.size():
			idx.append(i)
	for i in idx:                                   # triangulos soltos (o SurfaceTool do chamador nao usa indices)
		_verts.append(v[i])
		_norms.append(n[i])
	return true


static func available() -> bool:
	return _load()


## Triangulos de um pilar (para medir).
static func tris() -> int:
	return _verts.size() / 3 if _load() else 0


## Altura padrao do leque para um pilar de `height` m (o original: 4,9 m em 12,5 m).
static func flare_for(height: float) -> float:
	return minf(TOP_Z - FLARE_Z, height * 0.42)


## Grava um pilar com o pe em `base` (mundo), girado por `b` (so o yaw da pista), `height` m de altura total e
## `top_w` m de largura no topo. `thick` escala a espessura (ao longo da pista). `col` = cor por vertice.
static func append(st: SurfaceTool, base: Vector3, b: Basis, height: float, top_w: float, col: Color,
		thick: float = 1.0, flare_h: float = -1.0) -> void:
	if not _load() or height <= 0.2:
		return
	var fh: float = flare_for(height) if flare_h < 0.0 else minf(flare_h, height * 0.8)
	var col_h: float = height - fh
	var sy_col: float = col_h / FLARE_Z
	var sy_fl: float = fh / (TOP_Z - FLARE_Z)
	var sx_top: float = top_w / TOP_W
	for i in _verts.size():
		var p: Vector3 = _verts[i]
		var n: Vector3 = _norms[i]
		var sx: float = 1.0
		var sy: float = sy_col
		var y: float
		if p.y <= FLARE_Z + 0.001:
			y = p.y * sy_col
		else:
			var t: float = (p.y - FLARE_Z) / (TOP_Z - FLARE_Z)
			y = col_h + (p.y - FLARE_Z) * sy_fl
			sx = lerpf(1.0, sx_top, t)
			sy = sy_fl
		var q := Vector3(p.x * sx, y, p.z * thick)
		var nn := Vector3(n.x / sx, n.y / maxf(sy, 0.05), n.z / thick).normalized()
		st.set_color(col)
		st.set_normal(b * nn)
		st.add_vertex(base + b * q)
