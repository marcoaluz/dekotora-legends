class_name TollGeo
extends RefCounted
## T-207: small mesh builder for the toll plaza (TollPlaza3D). One SurfaceTool per material key; quads with their own
## flat normal, atlas UV (TollAtlas) or metric UV (size zero Rect2 = metres / TILE, for the concrete texture) and a
## vertex colour (tint; in the "glow" material an alpha < 0,5 makes the lamp blink).
## Two ways to place points: `fp` = rigid frame at the booth centre (canopy, booth, pillars: level, square to the road)
## and `rp` = on the road at z (paint, curbs, barriers follow the road, also on the 3 % slope of the mountain).

const TILE: float = 1.6                     # metres per repeat of the concrete texture
const M: float = Track.ROAD_HALF_WIDTH_M

var path: TrackPath
var plaza: TollPlaza
var o: Vector3                              # frame origin: road centre at the booth
var fwd: Vector3                            # along the road (level)
var right: Vector3                          # to the right of the road (level)
var tris: int = 0
var _sts: Dictionary = {}


func _init(path_: TrackPath, plaza_: TollPlaza) -> void:
	path = path_
	plaza = plaza_
	o = path.world_point(plaza.z, 0.0)
	var f: Vector3 = path.forward_at(plaza.z)
	fwd = Vector3(f.x, 0.0, f.z).normalized()
	right = fwd.cross(Vector3.UP).normalized()


## Point of the rigid frame: `dz` metres along the road from the booth centre, `lat` metres to the right, `h` up.
func fp(dz: float, lat: float, h: float) -> Vector3:
	return o + fwd * dz + right * lat + Vector3.UP * h


## Point on the road at absolute z (metres along the track), `lat` metres to the right, `h` above the asphalt.
func rp(z: float, lat: float, h: float) -> Vector3:
	return path.world_point(z, lat / M, h)


func st(key: String) -> SurfaceTool:
	if not _sts.has(key):
		var s := SurfaceTool.new()
		s.begin(Mesh.PRIMITIVE_TRIANGLES)
		_sts[key] = s
	return _sts[key]


func has(key: String) -> bool:
	return _sts.has(key)


## Quad a-b (bottom edge, left to right seen from outside), c-d (top edge, right and left). `outward` (optional) fixes
## the facing: if the corners came in the other order they are mirrored. `uv` from TollAtlas; Rect2() = metric UV.
func quad(key: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, uv: Rect2, col: Color = Color.WHITE,
		outward: Vector3 = Vector3.ZERO) -> void:
	var n: Vector3 = (b - a).cross(d - a)
	if outward != Vector3.ZERO and n.dot(outward) < 0.0:
		var t: Vector3 = a
		a = b
		b = t
		t = c
		c = d
		d = t
		n = -n
	n = n.normalized()
	var ua: Vector2
	var ub: Vector2
	var uc: Vector2
	var ud: Vector2
	if uv.size == Vector2.ZERO:                 # metric: u along the bottom edge, v = 0 at the top edge
		var w: float = a.distance_to(b) / TILE
		var h: float = a.distance_to(d) / TILE
		var u0: float = uv.position.x
		ua = Vector2(u0, h)
		ub = Vector2(u0 + w, h)
		uc = Vector2(u0 + w, 0.0)
		ud = Vector2(u0, 0.0)
	else:
		ua = Vector2(uv.position.x, uv.end.y)
		ub = Vector2(uv.end.x, uv.end.y)
		uc = Vector2(uv.end.x, uv.position.y)
		ud = Vector2(uv.position.x, uv.position.y)
	var s: SurfaceTool = st(key)
	for k in [[a, ua], [d, ud], [c, uc], [a, ua], [c, uc], [b, ub]]:
		s.set_normal(n)
		s.set_color(col)
		s.set_uv(k[1])
		s.add_vertex(k[0])
	tris += 2


## Box in the rigid frame (`rigid`) or on the road (z0..z1 absolute): faces = {front, back, left, right, top, bottom}
## -> Rect2 (missing face = not drawn). front = the face the traffic sees coming (smaller z).
func box(key: String, rigid: bool, z0: float, z1: float, x0: float, x1: float, h0: float, h1: float, faces: Dictionary,
		col: Color = Color.WHITE) -> void:
	var P: Callable = fp if rigid else rp
	var c000: Vector3 = P.call(z0, x0, h0)
	var c010: Vector3 = P.call(z0, x1, h0)
	var c001: Vector3 = P.call(z0, x0, h1)
	var c011: Vector3 = P.call(z0, x1, h1)
	var c100: Vector3 = P.call(z1, x0, h0)
	var c110: Vector3 = P.call(z1, x1, h0)
	var c101: Vector3 = P.call(z1, x0, h1)
	var c111: Vector3 = P.call(z1, x1, h1)
	var f: Vector3 = (c100 - c000).normalized()
	var r: Vector3 = (c010 - c000).normalized()
	if faces.has("front"):
		quad(key, c000, c010, c011, c001, faces["front"], col, -f)
	if faces.has("back"):
		quad(key, c110, c100, c101, c111, faces["back"], col, f)
	if faces.has("left"):
		quad(key, c100, c000, c001, c101, faces["left"], col, -r)
	if faces.has("right"):
		quad(key, c010, c110, c111, c011, faces["right"], col, r)
	if faces.has("top"):
		quad(key, c001, c011, c111, c101, faces["top"], col, Vector3.UP)
	if faces.has("bottom"):
		quad(key, c100, c110, c010, c000, faces["bottom"], col, Vector3.DOWN)


## Flat piece on the road between z0 and z1, from lateral l0 to l1 (at z0) and m0 to m1 (at z1), at height h.
func road_quad(key: String, z0: float, z1: float, l0: float, l1: float, m0: float, m1: float, h: float, uv: Rect2,
		col: Color = Color.WHITE) -> void:
	quad(key, rp(z0, l0, h), rp(z0, l1, h), rp(z1, m1, h), rp(z1, m0, h), uv, col, Vector3.UP)


## Vertical face along the road: lateral lat0 at z0 to lat1 at z1, heights h0..h1, facing `side` (-1 left, +1 right).
func road_wall(key: String, z0: float, z1: float, lat0: float, lat1: float, h0: float, h1: float, side: float, uv: Rect2,
		col: Color = Color.WHITE) -> void:
	var out: Vector3 = path.right_at((z0 + z1) * 0.5) * side
	var u: Rect2 = uv
	if uv.size == Vector2.ZERO:
		u = Rect2(Vector2(z0 / TILE, 0.0), Vector2.ZERO)
	quad(key, rp(z0, lat0, h0), rp(z1, lat1, h0), rp(z1, lat1, h1), rp(z0, lat0, h1), u, col, out)


## One MeshInstance3D per material (`mats`: key -> Material), all in one ArrayMesh would share the culling; separate
## nodes let the glow/paint skip shadows. Returns the nodes by key.
func commit(parent: Node3D, mats: Dictionary, range_m: float) -> Dictionary:
	var out: Dictionary = {}
	for key in _sts:
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, (_sts[key] as SurfaceTool).commit_to_arrays())
		am.surface_set_material(0, mats[key])
		var mi := MeshInstance3D.new()
		mi.name = "Toll_" + String(key)
		mi.mesh = am
		mi.visibility_range_end = range_m
		if key != "atlas" and key != "concrete":
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
		out[key] = mi
	return out
