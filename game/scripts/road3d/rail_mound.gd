class_name RailMound
extends RefCounted
## Morro de grama (ou bloco de concreto na cidade) atras da boca de um tunel ferroviario (T-154).
## Frente vertical com um vao do tamanho da boca (rail_portal.glb: 15 x 10,6 m); o trem some la dentro.

const PORTAL_HALF: float = 7.5
const PORTAL_TOP: float = 10.6
const DEPTH: float = 55.0
const BACK: float = 30.0


## `o` = base da boca; `f` = para dentro do morro; `r` = direita de quem entra; `ground`/`top` = alturas (y do mundo);
## `hl`/`hr` = meia largura da base para a esquerda/direita. `city` = bloco de concreto de paredes retas.
static func add_mound(parent: Node3D, o: Vector3, f: Vector3, r: Vector3, ground: float, top: float, hl: float, hr: float,
		city: bool, tod: TimeOfDay) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tl: float = hl if city else minf(9.0, hl)
	var tr: float = hr if city else minf(9.0, hr)
	tl = maxf(tl, PORTAL_HALF + 0.5)
	tr = maxf(tr, PORTAL_HALF + 0.5)
	var P := func(lat: float, y: float, d: float) -> Vector3:
		return Vector3(o.x, y, o.z) + r * lat + f * d
	var py: float = o.y
	var hole_top: float = py + PORTAL_TOP
	# frente (em volta do vao da boca)
	_quad(st, P.call(-hl, ground, 0.0), P.call(-PORTAL_HALF, ground, 0.0), P.call(-PORTAL_HALF, top, 0.0), P.call(-tl, top, 0.0))
	_quad(st, P.call(PORTAL_HALF, ground, 0.0), P.call(hr, ground, 0.0), P.call(tr, top, 0.0), P.call(PORTAL_HALF, top, 0.0))
	if py > ground + 0.05:
		_quad(st, P.call(-PORTAL_HALF, ground, 0.0), P.call(PORTAL_HALF, ground, 0.0), P.call(PORTAL_HALF, py, 0.0), P.call(-PORTAL_HALF, py, 0.0))
	if top > hole_top:
		_quad(st, P.call(-PORTAL_HALF, hole_top, 0.0), P.call(PORTAL_HALF, hole_top, 0.0), P.call(PORTAL_HALF, top, 0.0), P.call(-PORTAL_HALF, top, 0.0))
	# lados e topo
	_quad(st, P.call(-hl, ground, 0.0), P.call(-tl, top, 0.0), P.call(-tl, top, DEPTH), P.call(-hl, ground, DEPTH))
	_quad(st, P.call(hr, ground, 0.0), P.call(hr, ground, DEPTH), P.call(tr, top, DEPTH), P.call(tr, top, 0.0))
	_quad(st, P.call(-tl, top, 0.0), P.call(tr, top, 0.0), P.call(tr, top, DEPTH), P.call(-tl, top, DEPTH))
	# fundo (rampa de grama ou parede reta)
	var back: float = DEPTH if city else DEPTH + BACK
	_quad(st, P.call(-tl, top, DEPTH), P.call(tr, top, DEPTH), P.call(hr, ground, back), P.call(-hl, ground, back))
	if not city:
		_quad(st, P.call(-hl, ground, DEPTH), P.call(-tl, top, DEPTH), P.call(-hl, ground, back), P.call(-hl, ground, back))
		_quad(st, P.call(hr, ground, DEPTH), P.call(hr, ground, back), P.call(tr, top, DEPTH), P.call(tr, top, DEPTH))
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = RailKit.material("rail_station" if city else "rail_ground", tod)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 700.0
	parent.add_child(mi)


## Quadrilatero com UV em metros (horizontal do plano, altura).
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var n: Vector3 = (b - a).cross(d - a)
	var ax: Vector3 = Vector3(-n.z, 0.0, n.x).normalized() if absf(n.y) < 0.95 * n.length() else Vector3.RIGHT
	for v in [a, b, c, a, c, d]:
		st.set_uv(Vector2(v.dot(ax), -v.y if absf(n.y) < 0.95 * n.length() else v.z))
		st.set_color(Color.WHITE)
		st.add_vertex(v)
