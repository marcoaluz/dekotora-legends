class_name StoneWalls3D
extends Node3D
## T-217: stone retaining walls (石積み, 谷積み masonry) of the cuts in CutLayout: concrete U gutter at the foot, the
## battered stone face (texture + normal map: TexSlots "stone_wall", Marco's CC0 set if present), weep holes with
## PVC pipes in a grid, a concrete coping, a strip of grass on top and, on the tall walls, a green rock-fall fence.
## One MeshInstance3D per CHUNK_M per material (stone, concrete, grass, fence). Only visual.

const CHUNK_M: float = 120.0
const VIEW_M: float = 650.0
const WEEP_EVERY: float = 2.5

var path: TrackPath
var cuts: CutLayout
var tris: int = 0
var faces: int = 0
var _r: Ribbon
var _stone_tile: float = 3.0
var _flip: bool = false              # right-side walls: mirrored laterals, so the winding is reversed


func build(cuts_: CutLayout, tod: TimeOfDay, terrain: Material) -> void:
	cuts = cuts_
	path = cuts.path
	_r = Ribbon.new(path)
	_stone_tile = TexSlots.tile_m("stone_wall", 4.5)          # bigger stones read better from the road
	var stone: StandardMaterial3D = _stone_mat(tod)
	var conc: BaseMaterial3D = Ribbon.two_sided(PontesKit.concrete(tod, 0.3))
	var fence := StandardMaterial3D.new()
	fence.albedo_color = Color(0.22, 0.42, 0.3)
	fence.metallic = 0.3
	fence.roughness = 0.6
	fence.cull_mode = BaseMaterial3D.CULL_DISABLED
	for r in cuts.runs:
		var side: float = float(r[2])
		var z: float = float(r[0])
		while z < float(r[1]):
			var z1: float = minf(z + CHUNK_M, float(r[1]))
			var sts: Array[SurfaceTool] = []
			for k in 4:
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				sts.append(st)
			_flip = side > 0.0
			_piece(sts, z, z1, side, float(r[3]))
			tris += Ribbon.add_mesh(self, sts[0], stone, VIEW_M, true, true)
			tris += Ribbon.add_mesh(self, sts[1], conc, VIEW_M)
			tris += Ribbon.add_mesh(self, sts[2], terrain, VIEW_M)
			tris += Ribbon.add_mesh(self, sts[3], fence, 260.0)
			z = z1
		faces += 1


func _stone_mat(tod: TimeOfDay) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = TexSlots.albedo("stone_wall")
	m.normal_enabled = true
	m.normal_texture = TexSlots.normal("stone_wall")
	m.normal_scale = 1.4
	var rough: Texture2D = TexSlots.rough("stone_wall")
	if rough != null:
		m.roughness_texture = rough
	m.roughness = 0.92
	m.vertex_color_use_as_albedo = true
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(1.12, 1.05, 0.92)                  # warm granite (the sky ambient makes it blue otherwise)
	if tod != null and tod.lamps_on:
		m.albedo_color = Color(1.0, 0.97, 0.92)
	return m


func _piece(sts: Array[SurfaceTool], z0: float, z1: float, side: float, _h: float) -> void:
	var i0: int = int(z0 / Track.SEG_LEN)
	var i1: int = int(ceil(z1 / Track.SEG_LEN))
	var f: float = cuts.foot(side)
	for i in range(i0, i1):
		var j: int = i + 1
		var za: float = float(i) * Track.SEG_LEN
		var zb: float = float(j) * Track.SEG_LEN
		var ha: float = cuts.height(za, side)
		var hb: float = cuts.height(zb, side)
		if ha <= 0.02 and hb <= 0.02:
			continue
		var ta: float = f + ha * CutLayout.BATTER
		var tb: float = f + hb * CutLayout.BATTER
		# gutter (U channel) in front of the wall
		_quad(sts[1], [_p(i, side, f - CutLayout.GUTTER_W, 0.02), _p(i, side, f - CutLayout.GUTTER_W, -0.25),
			_p(j, side, f - CutLayout.GUTTER_W, -0.25), _p(j, side, f - CutLayout.GUTTER_W, 0.02)], Color(0.62, 0.62, 0.6))
		_quad(sts[1], [_p(i, side, f - CutLayout.GUTTER_W, -0.25), _p(i, side, f, -0.25),
			_p(j, side, f, -0.25), _p(j, side, f - CutLayout.GUTTER_W, -0.25)], Color(0.35, 0.35, 0.33))
		# stone face: two bands (darker and greener at the bottom, rain-washed at the top)
		var slant_a: float = ha * sqrt(1.0 + CutLayout.BATTER * CutLayout.BATTER)
		var slant_b: float = hb * sqrt(1.0 + CutLayout.BATTER * CutLayout.BATTER)
		var ua: float = za / _stone_tile
		var ub: float = zb / _stone_tile
		for band in [[0.0, 0.35, Color(0.78, 0.8, 0.74), Color(0.95, 0.95, 0.93)], [0.35, 1.0, Color(0.95, 0.95, 0.93), Color(1.0, 1.0, 1.0)]]:
			var k0: float = float(band[0])
			var k1: float = float(band[1])
			var a: Vector3 = _p(i, side, f + ha * k0 * CutLayout.BATTER, ha * k0 - 0.25 * (1.0 - k0))
			var b: Vector3 = _p(i, side, f + ha * k1 * CutLayout.BATTER, ha * k1)
			var c: Vector3 = _p(j, side, f + hb * k1 * CutLayout.BATTER, hb * k1)
			var d: Vector3 = _p(j, side, f + hb * k0 * CutLayout.BATTER, hb * k0 - 0.25 * (1.0 - k0))
			var uv := [Vector2(ua, -slant_a * k0 / _stone_tile), Vector2(ua, -slant_a * k1 / _stone_tile),
				Vector2(ub, -slant_b * k1 / _stone_tile), Vector2(ub, -slant_b * k0 / _stone_tile)]
			var cols := [band[2], band[3], band[3], band[2]]
			var vs := [a, b, c, d]
			for n in ([0, 2, 1, 0, 3, 2] if _flip else [0, 1, 2, 0, 2, 3]):
				sts[0].set_color(cols[n])
				sts[0].set_uv(uv[n])
				sts[0].add_vertex(vs[n])
		# coping (concrete cap) and the grass strip on top
		_quad(sts[1], [_p(i, side, ta - 0.05, ha), _p(i, side, ta - 0.05, ha + 0.28), _p(j, side, tb - 0.05, hb + 0.28),
			_p(j, side, tb - 0.05, hb)], Color(0.8, 0.8, 0.77))
		_quad(sts[1], [_p(i, side, ta - 0.05, ha + 0.28), _p(i, side, ta + 0.45, ha + 0.28), _p(j, side, tb + 0.45, hb + 0.28),
			_p(j, side, tb - 0.05, hb + 0.28)], Color(0.86, 0.86, 0.83))
		var back_a: float = ta + 0.45 + 3.6
		var back_b: float = tb + 0.45 + 3.6
		_quad(sts[2], [_p(i, side, ta + 0.45, ha + 0.26), _p(i, side, back_a, ha + 0.26 + 3.6 * CutLayout.TERRACE_SLOPE),
			_p(j, side, back_b, hb + 0.26 + 3.6 * CutLayout.TERRACE_SLOPE), _p(j, side, tb + 0.45, hb + 0.26)], Color(0, 0, 0, 1))
		# weep holes with PVC pipe stubs, staggered rows every ~2 m of height
		if fmod(za + 0.01, WEEP_EVERY) < Track.SEG_LEN and ha > 1.8:
			var row: int = 0
			var y: float = 0.9
			while y < ha - 0.8:
				var zz: float = za + (WEEP_EVERY * 0.5 if row % 2 == 1 else 0.0)
				var lat: float = f + y * CutLayout.BATTER - 0.06
				var b := Basis(Vector3.UP, path.yaw_at(zz))
				Ribbon.box(sts[1], b, path.world_point(zz, side * lat / Track.ROAD_HALF_WIDTH_M, y), Vector3(0.12, 0.12, 0.12),
					Color(0.12, 0.12, 0.12), true)
				y += 2.0
				row += 1
		# rock-fall fence on the tall walls: posts every 3 m and 4 wires
		if ha > 7.0:
			if fmod(za + 0.01, 3.0) < Track.SEG_LEN:
				var b2 := Basis(Vector3.UP, path.yaw_at(za))
				Ribbon.box(sts[3], b2, path.world_point(za, side * (ta + 0.2) / Track.ROAD_HALF_WIDTH_M, ha + 1.1),
					Vector3(0.08, 1.7, 0.08), Color.WHITE, true)
			for wy in [0.6, 1.0, 1.4, 1.85]:
				_quad(sts[3], [_p(i, side, ta + 0.2, ha + wy), _p(i, side, ta + 0.2, ha + wy + 0.03),
					_p(j, side, tb + 0.2, hb + wy + 0.03), _p(j, side, tb + 0.2, hb + wy)], Color.WHITE)


func _p(i: int, side: float, lat: float, h: float) -> Vector3:
	return _r.edge(i, side * lat, h)


func _quad(st: SurfaceTool, v: Array, col: Color) -> void:
	for n in ([0, 2, 1, 0, 3, 2] if _flip else [0, 1, 2, 0, 2, 3]):
		st.set_color(col)
		st.set_uv(Vector2((v[n] as Vector3).x + (v[n] as Vector3).y, (v[n] as Vector3).z) * 0.25)
		st.add_vertex(v[n])
