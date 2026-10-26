class_name TunnelTwin
extends RefCounted
## T-217: the twin bore of every tunnel (the other carriageway, OppositeLayout) and the modern portal details:
## second arch in the portal wall, its own tube with orange sodium lamps, a short concrete hood (bell-mouth) around
## each arch, jet fans hanging from the ceiling, red fire-extinguisher boxes and green emergency-phone boxes on the
## walls, and a white glare plane in each exit (the bright hole ahead while the eyes are used to the dark).
## Static helpers called by Tunnel3D (they use its _edge / _face / _lit); only visual.

const OPP_ARCH: Array = [[5.6, 0.0], [5.6, 4.2], [4.6, 6.0], [2.5, 6.9], [0.0, 7.1]]
const HOOD_LEN: float = 1.8               # concrete hood in front of each arch (m along the road)
const HOOD_T: float = 0.7                 # thickness of the hood ring
const FAN_EVERY: float = 110.0
const BOX_EVERY: float = 48.0


## Full profile of the twin bore (left -> right), centred on the other carriageway.
static func opp_arch() -> Array:
	var out: Array = []
	var c: float = OppositeLayout.CENTER
	for k in OPP_ARCH.size():
		out.append([c - float(OPP_ARCH[k][0]), float(OPP_ARCH[k][1])])
	for k in range(OPP_ARCH.size() - 2, -1, -1):
		out.append([c + float(OPP_ARCH[k][0]), float(OPP_ARCH[k][1])])
	return out


## Right foot of the twin arch (lateral m).
static func opp_right() -> float:
	return OppositeLayout.CENTER + float(OPP_ARCH[0][0])


## Portal wall to the right of our arch with the second hole (replaces the plain right slab of Tunnel3D._portal).
static func portal_right(t3d: Tunnel3D, st: SurfaceTool, z: float, facing: float, x0: float, x1: float, top: float,
		col: Color) -> void:
	var arch: Array = opp_arch()
	var lf: float = float(arch[0][0])
	var rf: float = float(arch[arch.size() - 1][0])
	t3d._side(st, z, facing, x0, lf, top, col)
	for k in arch.size() - 1:
		var p0: Array = arch[k]
		var p1: Array = arch[k + 1]
		t3d._face(st, z, facing, [Vector2(p0[0], p0[1]), Vector2(p1[0], p1[1]), Vector2(p1[0], top), Vector2(p0[0], top)], col)
	t3d._side(st, z, facing, rf, x1, top, col)


## Tube of the twin bore (pre-lit like ours, Tunnel3D._lit).
static func tube(t3d: Tunnel3D, st: SurfaceTool, t: Vector2) -> void:
	var arch: Array = opp_arch()
	var z: float = t.x
	while z < t.x + t.y:
		var z1: float = minf(z + Track.SEG_LEN * 2.0, t.x + t.y)
		for k in arch.size() - 1:
			var p0: Array = arch[k]
			var p1: Array = arch[k + 1]
			var a: Vector3 = t3d._edge(z, float(p0[0]), float(p0[1]))
			var b: Vector3 = t3d._edge(z, float(p1[0]), float(p1[1]))
			var c: Vector3 = t3d._edge(z1, float(p1[0]), float(p1[1]))
			var d: Vector3 = t3d._edge(z1, float(p0[0]), float(p0[1]))
			for v in [a, c, b, a, d, c]:
				var vz: float = z if (v == a or v == b) else z1
				st.set_color(t3d._lit(vz, v.y - t3d.path.center_at(vz).y))
				st.add_vertex(v)
		z = z1


## Sodium lamps of the twin bore (2 rows), for Tunnel3D._add_lamps.
static func lamps(t3d: Tunnel3D, t: Vector2, out: Array) -> void:
	var z: float = t.x + 2.0
	while z < t.x + t.y - 1.0:
		for side in [-1.0, 1.0]:
			out.append([t3d._xf(z, OppositeLayout.CENTER + side * 2.2, 6.85, Vector3(0.3, 0.1, 1.3)), Color(1.0, 0.62, 0.22)])
		z += Tunnel3D.LAMP_EVERY


## Concrete hood around an arch (outer surface, top and the front ring), `facing` = +1 entrance, -1 exit.
static func hood(t3d: Tunnel3D, st: SurfaceTool, z: float, facing: float, arch: Array, col: Color) -> void:
	var z_out: float = z - facing * HOOD_LEN
	var c: float = (float(arch[0][0]) + float(arch[arch.size() - 1][0])) * 0.5
	var outer: Array = []
	for p in arch:                                   # push each arch point out from a centre 2 m above the road
		var dx: float = float(p[0]) - c
		var h: float = float(p[1])
		var dir := Vector2(signf(dx), 0.0) if h <= 2.0 else Vector2(dx, h - 2.0).normalized()
		outer.append([float(p[0]) + dir.x * HOOD_T, h + dir.y * HOOD_T])
	for k in arch.size() - 1:
		var a0: Array = arch[k]
		var a1: Array = arch[k + 1]
		var o0: Array = outer[k]
		var o1: Array = outer[k + 1]
		_quad(t3d, st, [[z_out, a0], [z_out, a1], [z_out, o1], [z_out, o0]], col * 1.05)        # front ring
		_quad(t3d, st, [[z_out, o0], [z_out, o1], [z, o1], [z, o0]], col)                       # outside of the hood
		_quad(t3d, st, [[z_out, a0], [z, a0], [z, a1], [z_out, a1]], col * 0.8)                 # inside of the hood


static func _quad(t3d: Tunnel3D, st: SurfaceTool, pts: Array, col: Color) -> void:
	var v: Array = []
	for p in pts:
		v.append(t3d._edge(float(p[0]), float(p[1][0]), float(p[1][1])))
	for k in [0, 1, 2, 0, 2, 3]:
		st.set_normal(Vector3.UP)
		st.set_color(col)
		st.set_uv(Vector2((v[k] as Vector3).x + (v[k] as Vector3).z, (v[k] as Vector3).y) / 4.0)
		st.add_vertex(v[k])


## Jet fans (pairs of cylinders under the ceiling) and wall boxes (red extinguisher, green phone): pre-lit fixtures.
static func fixtures(t3d: Tunnel3D, st: SurfaceTool, t: Vector2, centre: float, ceiling: float, wall_left: float,
		lit: bool = true) -> void:
	var z: float = t.x + 40.0
	while z < t.x + t.y - 30.0:
		for side in [-1.0, 1.0]:
			_fan(t3d, st, z, centre + side * 3.2, ceiling - 1.3)
		z += FAN_EVERY
	z = t.x + 20.0
	var n: int = 0
	while z < t.x + t.y - 10.0:
		var red: bool = n % 2 == 0
		var col: Color = Color(0.75, 0.12, 0.1) if red else Color(0.2, 0.55, 0.35)
		var b := Basis(Vector3.UP, t3d.path.yaw_at(z))
		Ribbon.box(st, b, t3d._edge(z, wall_left + 0.12, 1.75), Vector3(0.22, 1.0, 0.75), col * (1.25 if lit else 1.0), true)
		Ribbon.box(st, b, t3d._edge(z, wall_left + 0.13, 2.33), Vector3(0.22, 0.16, 0.75), Color(0.92, 0.92, 0.88), true)
		z += BOX_EVERY
		n += 1


static func _fan(t3d: Tunnel3D, st: SurfaceTool, z: float, lat: float, h: float) -> void:
	var seg: int = 8
	var r: float = 0.6
	var length: float = 4.0
	var f: Vector3 = t3d.path.forward_at(z)
	var rt: Vector3 = t3d.path.right_at(z)
	var c0: Vector3 = t3d._edge(z - length * 0.5, lat, h)
	var c1: Vector3 = t3d._edge(z + length * 0.5, lat, h)
	for s in seg:
		var a0: float = TAU * float(s) / float(seg)
		var a1: float = TAU * float(s + 1) / float(seg)
		var d0: Vector3 = rt * cos(a0) * r + Vector3.UP * sin(a0) * r
		var d1: Vector3 = rt * cos(a1) * r + Vector3.UP * sin(a1) * r
		var shade: float = 0.55 + 0.35 * maxf(sin((a0 + a1) * 0.5), 0.0)
		var col := Color(0.62, 0.62, 0.6) * shade
		for v in [c0 + d0, c1 + d0, c1 + d1, c0 + d0, c1 + d1, c0 + d1]:
			st.set_color(col)
			st.set_uv(Vector2.ZERO)
			st.add_vertex(v)
		for cap in [[c0, -f], [c1, f]]:                       # dark intakes at both ends
			for v in [cap[0], cap[0] + d0, cap[0] + d1]:
				st.set_color(Color(0.2, 0.2, 0.22))
				st.set_uv(Vector2.ZERO)
				st.add_vertex(v)
	var b := Basis(Vector3.UP, t3d.path.yaw_at(z))            # hanger bracket to the ceiling
	Ribbon.box(st, b, t3d._edge(z, lat, h + r + 0.35), Vector3(0.12, 0.7, 2.0), Color(0.4, 0.4, 0.4), true)
