class_name TollPaint
extends RefCounted
## T-207: paint of the toll plaza on the asphalt (material "paint" of TollPlaza3D): the middle lane closes as a zebra
## (inverted V stripes inside a white outline) up to the island nose and opens again after the tail; the lane lines
## become solid (no lane change) around it; deceleration marks and a coloured band with the passage name: purple ETC
## on the right passage, green 一般 on the left one (keep left: the cash lane). RoadMesh leaves out the dashed lines
## in `lines_span` so they do not cross the zebra.

const H: float = 0.026                      # above the road lines (0,02)
const LINE_W: float = 0.16
const LANE_LINE_M: float = 1.8              # lane lines (RoadMesh LANE_W / 2)
const GORE_EDGE_M: float = 1.62             # zebra outline: just inside the solid lane lines
const STRIPE_EVERY: float = 3.0
const STRIPE_W: float = 0.55
const BAND_LEN: float = 30.0                # coloured band ahead of the nose
const BAND_TINT: float = 0.8                # a little darker than the sign colours (worn paint)
const TEXT_LEN: float = 9.0                 # elongated text (seen from a low angle)
const PASS_W: float = 3.3
const PASS_X: float = 3.7                   # passage centre (between the island at 1,8 and the outer island at 5,6)


## Dashed lane lines are left out here (RoadMesh): z range.
static func lines_span(p: TollPlaza) -> Vector2:
	return Vector2(p.nose_z() - TollPlaza.GORE_M - 22.0, p.tail_z() + TollPlaza.REJOIN_M + 6.0)


static func build(g: TollGeo) -> void:
	var p: TollPlaza = g.plaza
	var white: Rect2 = TollAtlas.uv("white")
	var span: Vector2 = lines_span(p)
	for s in [-1.0, 1.0]:                                          # solid lane lines (around the island too)
		_strip(g, span.x, p.nose_z(), s * LANE_LINE_M, white)
		_strip(g, p.tail_z(), span.y, s * LANE_LINE_M, white)
	_gore(g, p.nose_z() - TollPlaza.GORE_M, p.nose_z(), true)
	_gore(g, p.tail_z(), p.tail_z() + TollPlaza.REJOIN_M, false)
	for s in [-1.0, 1.0]:                                          # passage: band + name + deceleration marks
		var etc: bool = s > 0.0
		var id: String = "road_etc" if etc else "road_general"
		var plain: Rect2 = TollAtlas.sub(id, 0.02, 0.04, 0.10, 0.16)
		var x0: float = s * PASS_X - PASS_W * 0.5
		var x1: float = s * PASS_X + PASS_W * 0.5
		var z_end: float = p.nose_z() + 10.0
		var z_text: float = z_end - BAND_LEN * 0.55
		var tint := Color(BAND_TINT, BAND_TINT, BAND_TINT)
		g.road_quad("band", z_end - BAND_LEN, z_text, x0, x1, x0, x1, H - 0.002, plain, tint)
		g.road_quad("band", z_text, z_text + TEXT_LEN, x0, x1, x0, x1, H - 0.002, TollAtlas.uv(id), tint)
		g.road_quad("band", z_text + TEXT_LEN, z_end, x0, x1, x0, x1, H - 0.002, plain, tint)
		var zz: float = p.nose_z() - 70.0
		while zz < p.nose_z() - BAND_LEN - 2.0:                    # 減速 marks: short transverse bars at both edges
			for e in [x0 + 0.1, x1 - 0.75]:
				g.road_quad("paint", zz, zz + 0.45, e, e + 0.65, e, e + 0.65, H, white)
			zz += 3.5


## Solid line along the road at lateral `lat`.
static func _strip(g: TollGeo, z0: float, z1: float, lat: float, uv: Rect2) -> void:
	var zz: float = z0
	while zz < z1 - 0.01:
		var zn: float = minf(zz + 6.0, z1)
		g.road_quad("paint", zz, zn, lat - LINE_W * 0.5, lat + LINE_W * 0.5, lat - LINE_W * 0.5, lat + LINE_W * 0.5, H, uv)
		zz = zn


## Zebra in the middle lane between z0 and z1: closes from a point (opening = true: point at z0, full width at z1).
static func _gore(g: TollGeo, z0: float, z1: float, opening: bool) -> void:
	var white: Rect2 = TollAtlas.uv("white")
	var half: Callable = func(zz: float) -> float:
		var t: float = clampf((zz - z0) / (z1 - z0), 0.0, 1.0)
		return GORE_EDGE_M * (t if opening else 1.0 - t)
	var n: int = 12
	for s in [-1.0, 1.0]:                                          # outline: the two edges of the closed area
		for k in n:
			var za: float = lerpf(z0, z1, float(k) / n)
			var zb: float = lerpf(z0, z1, float(k + 1) / n)
			var la: float = s * half.call(za)
			var lb: float = s * half.call(zb)
			g.road_quad("paint", za, zb, la - LINE_W * 0.5, la + LINE_W * 0.5, lb - LINE_W * 0.5, lb + LINE_W * 0.5, H, white)
	var zs: float = z0 + 2.0                                       # inverted V stripes (the tip points at the traffic)
	var arm_dz: float = 1.4
	while zs < z1 - 0.5:
		for s in [-1.0, 1.0]:
			var e0: float = half.call(zs + arm_dz) - 0.12
			if e0 <= 0.2:
				continue
			g.quad("paint", g.rp(zs, 0.0, H), g.rp(zs + STRIPE_W, 0.0, H),
				g.rp(zs + STRIPE_W + arm_dz, s * e0, H), g.rp(zs + arm_dz, s * e0, H), white, Color.WHITE, Vector3.UP)
		zs += STRIPE_EVERY
