class_name TollParts
extends RefCounted
## T-207: the structure of the toll plaza (TollPlaza3D), built with TollGeo in 4 materials: "atlas" (painted panels,
## signs by day: TollAtlas), "concrete" (curbs, barriers, plinths), "glow" (lamps, lit signs, lit booth windows,
## blinking beacons: unshaded, enters the bloom) and "paint" (TollPaint). Sizes in metres.
##  - centre island (the whole middle lane, = TollPlaza: physics) with a yellow/black crash cushion at the nose, the
##    "pass both sides" sign, the main booth (windows to both passages) and the canopy pillars;
##  - outer islands from TollPlaza.OUTER_FACE_M outwards, each with a booth (the driver sits on the right: the right
##    passage pays at the right island) and pillars; concrete barriers along the funnel (TollPlaza.outer_face_m);
##  - canopy 7 m above the road (lit LED strips underneath at night), front fascia 料金所 TOLL GATE, lane signs
##    (ETC/一般 on the left passage, ETC専用 on the right) with the green arrow signal beside them;
##  - ETC antenna gantry before the canopy. Gate bars: TollPlaza3D (they move).

const ISLAND_TOP: float = 0.25
const OUTER_W: float = 2.0                  # outer islands: OUTER_FACE_M .. + OUTER_W
const CANOPY_HALF: float = 9.4
const CANOPY_DZ: float = 8.0
const CANOPY_H0: float = 7.0              # high enough for the chase camera (RaceCamRig.TOLL_H_MAX keeps it below 5,6 m)
const CANOPY_H1: float = 8.4
const PILLAR_DZ: float = 5.5
const PILLAR_W: float = 0.62
const GANTRY_DZ: float = -13.0
const CUSHION_LEN: float = 2.4
const BAR_DZ: float = 6.9                   # gate bars, after the booth (TollPlaza3D)
const PASS_X: float = TollPaint.PASS_X
const NIGHT_SIGN: float = 0.6               # vertex tint of lit signs in the glow material (energy x this)
const NIGHT_WINDOW: float = 0.5


static func pillar_xs() -> Array[float]:
	var of: float = TollPlaza.OUTER_FACE_M + OUTER_W * 0.5
	return [-of, 0.0, of]


static func build(g: TollGeo, lit: bool) -> void:
	_islands(g)
	_cushion(g)
	_barriers(g, lit)
	var of: float = TollPlaza.OUTER_FACE_M
	booth(g, -0.8, 0.8, 2.2, 2, lit)                                # main booth: windows to both passages
	booth(g, of + 0.35, of + 1.6, 1.8, -1, lit)                     # right island: window to the right passage
	booth(g, -of - 1.6, -of - 0.35, 1.8, 1, lit)                    # left island: window to the left passage
	_pillars(g)
	_canopy(g, lit)
	_gantry(g)


# ---------------------------------------------------------------- islands
static func _islands(g: TollGeo) -> void:
	var p: TollPlaza = g.plaza
	var curb: Rect2 = TollAtlas.uv("curb")
	var stripes: Rect2 = TollAtlas.uv("stripes")
	var of: float = TollPlaza.OUTER_FACE_M
	var ih: float = TollPlaza.ISLAND_HALF_M
	var zz: float = p.nose_z()
	while zz < p.tail_z() - 0.01:                                   # tops in 4 m pieces (texture not stretched)
		var zn: float = minf(zz + 4.0, p.tail_z())
		g.road_quad("atlas", zz, zn, -ih, ih, -ih, ih, ISLAND_TOP, curb)
		for s in [-1.0, 1.0]:
			var a: float = s * of
			var b: float = s * (of + OUTER_W)
			g.road_quad("atlas", zz, zn, minf(a, b), maxf(a, b), minf(a, b), maxf(a, b), ISLAND_TOP, curb)
			var near_nose: bool = zz - p.nose_z() < 6.0 or p.tail_z() - zn < 3.0
			g.road_wall("atlas" if near_nose else "concrete", zz, zn, s * ih, s * ih, 0.0, ISLAND_TOP, s,
				stripes if near_nose else Rect2())                  # centre island sides
			g.road_wall("atlas" if near_nose else "concrete", zz, zn, a, a, 0.0, ISLAND_TOP, -s,
				stripes if near_nose else Rect2())                  # outer island face (to the passage)
			g.road_wall("concrete", zz, zn, b, b, 0.0, ISLAND_TOP, s, Rect2())
		zz = zn
	for s in [-1.0, 1.0]:                                           # outer island ends and the centre island tail
		var a: float = s * of
		var b: float = s * (of + OUTER_W)
		g.quad("atlas", g.rp(p.nose_z(), minf(a, b), 0.0), g.rp(p.nose_z(), maxf(a, b), 0.0),
			g.rp(p.nose_z(), maxf(a, b), ISLAND_TOP), g.rp(p.nose_z(), minf(a, b), ISLAND_TOP), stripes, Color.WHITE, -g.fwd)
		g.quad("atlas", g.rp(p.tail_z(), maxf(a, b), 0.0), g.rp(p.tail_z(), minf(a, b), 0.0),
			g.rp(p.tail_z(), minf(a, b), ISLAND_TOP), g.rp(p.tail_z(), maxf(a, b), ISLAND_TOP), stripes, Color.WHITE, g.fwd)
	g.quad("atlas", g.rp(p.tail_z(), ih, 0.0), g.rp(p.tail_z(), -ih, 0.0), g.rp(p.tail_z(), -ih, ISLAND_TOP),
		g.rp(p.tail_z(), ih, ISLAND_TOP), stripes, Color.WHITE, g.fwd)


## Crash cushion over the whole nose (the island is the whole middle lane): yellow, black chevrons, amber beacon.
static func _cushion(g: TollGeo) -> void:
	var p: TollPlaza = g.plaza
	var z0: float = p.nose_z() - 0.04
	var w: float = TollPlaza.ISLAND_HALF_M - 0.06
	var stripes: Rect2 = TollAtlas.uv("stripes")
	g.box("atlas", false, z0, z0 + CUSHION_LEN, -w, w, 0.0, 1.05, {"front": TollAtlas.uv("chevron"), "left": stripes,
		"right": stripes, "top": TollAtlas.uv("dark")})
	for k in 3:                                                     # module joints
		var zj: float = z0 + 0.6 + float(k) * 0.6
		g.box("atlas", false, zj, zj + 0.06, -w - 0.03, w + 0.03, 0.08, 1.0, {"left": TollAtlas.uv("dark"),
			"right": TollAtlas.uv("dark"), "top": TollAtlas.uv("dark")})
	var beacon: Rect2 = TollAtlas.uv("beacon")
	for x in [-w + 0.25, w - 0.25]:                                 # blinking amber lamps (alpha 0 = blink)
		g.box("glow", false, z0 + 0.2, z0 + 0.5, x - 0.15, x + 0.15, 1.05, 1.32, {"front": beacon, "left": beacon,
			"right": beacon, "top": beacon, "back": beacon}, Color(1.2, 1.2, 1.2, 0.0))
	var zs: float = z0 + CUSHION_LEN + 0.8                          # "pass both sides" sign on a post
	g.box("atlas", false, zs - 0.04, zs + 0.04, -0.04, 0.04, ISLAND_TOP, 1.5, {"front": TollAtlas.uv("steel"),
		"left": TollAtlas.uv("steel"), "right": TollAtlas.uv("steel")})
	g.quad("atlas", g.rp(zs - 0.06, -0.45, 1.45), g.rp(zs - 0.06, 0.45, 1.45), g.rp(zs - 0.06, 0.45, 2.35),
		g.rp(zs - 0.06, -0.45, 2.35), TollAtlas.uv("keep_both"), Color.WHITE, -g.fwd)


## Concrete barriers along the funnel (inner face = TollPlaza.outer_face_m) with amber reflectors on top.
static func _barriers(g: TollGeo, lit: bool) -> void:
	var p: TollPlaza = g.plaza
	var prof: Array = [[0.0, 0.0], [0.05, 0.25], [0.2, 0.85], [0.4, 0.85], [0.55, 0.25], [0.6, 0.0]]
	for run in [Vector2(p.zone_start(), p.nose_z()), Vector2(p.tail_z(), p.zone_end())]:
		var zz: float = run.x
		while zz < run.y - 0.01:
			var zn: float = minf(zz + 3.0, run.y)
			var fa: float = p.outer_face_m(zz)
			var fb: float = p.outer_face_m(zn)
			if minf(fa, fb) < LaneSections.OPEN_WALL_M - 0.15:       # not on top of the normal barrier
				for s in [-1.0, 1.0]:
					for k in prof.size() - 1:
						var p0: Array = prof[k]
						var p1: Array = prof[k + 1]
						var mid := Vector2((float(p0[0]) + float(p1[0])) * 0.5 - 0.3, (float(p0[1]) + float(p1[1])) * 0.5 - 0.4)
						var out: Vector3 = g.path.right_at(zz) * s * mid.x + Vector3.UP * mid.y
						g.quad("concrete", g.rp(zz, s * (fa + float(p0[0])), float(p0[1])), g.rp(zn, s * (fb + float(p0[0])), float(p0[1])),
							g.rp(zn, s * (fb + float(p1[0])), float(p1[1])), g.rp(zz, s * (fa + float(p1[0])), float(p1[1])),
							Rect2(Vector2(zz / TollGeo.TILE, 0.0), Vector2.ZERO), Color.WHITE, out)
					if int(zz / 3.0) % 2 == 0:                          # reflector on top
						var fr: float = s * (fa + 0.3)
						g.box("glow" if lit else "atlas", false, zz, zz + 0.12, fr - 0.06, fr + 0.06, 0.85, 1.0,
							{"front": TollAtlas.uv("beacon"), "top": TollAtlas.uv("beacon")}, Color(0.45, 0.45, 0.45) if lit else Color.WHITE)
			zz = zn


# ---------------------------------------------------------------- booths, pillars, canopy, gantry
## Booth on an island between lateral x0..x1 (m), dz -half..half around the booth centre. `windows`: 2 = both long
## sides, -1 = window on the left side (x0), 1 = on the right side (x1). Lit window at night (glow material).
static func booth(g: TollGeo, x0: float, x1: float, half: float, windows: int, lit: bool) -> void:
	var z0: float = g.plaza.z - half
	var z1: float = g.plaza.z + half
	var wall: Rect2 = TollAtlas.sub("booth", 0.0, 0.655, 1.0, 1.0)
	var win: Rect2 = TollAtlas.sub("booth_lit" if lit else "booth", 0.0, 0.0, 1.0, 0.655)
	var plain: Rect2 = TollAtlas.sub("booth_end", 0.05, 0.3, 0.2, 0.9)
	var end: Rect2 = TollAtlas.uv("booth_end")
	var hw: float = 1.3                                             # lower wall .. window
	g.box("atlas", false, z0, z1, x0, x1, ISLAND_TOP - 0.05, hw, {"left": wall if windows != 1 else plain,
		"right": wall if windows != -1 else plain, "front": TollAtlas.sub("booth_end", 0.0, 0.55, 1.0, 1.0),
		"back": TollAtlas.sub("booth_end", 0.0, 0.55, 1.0, 1.0)})
	var wk: String = "glow" if lit else "atlas"
	var wc: Color = Color(NIGHT_WINDOW, NIGHT_WINDOW, NIGHT_WINDOW) if lit else Color.WHITE
	var faces_w: Dictionary = {}
	var faces_p: Dictionary = {"front": TollAtlas.sub("booth_end", 0.0, 0.0, 1.0, 0.55), "back": TollAtlas.sub("booth_end", 0.0, 0.0, 1.0, 0.55)}
	if windows != 1:
		faces_w["left"] = win
	else:
		faces_p["left"] = plain
	if windows != -1:
		faces_w["right"] = win
	else:
		faces_p["right"] = plain
	g.box(wk, false, z0, z1, x0, x1, hw, 2.6, faces_w, wc)
	g.box("atlas", false, z0, z1, x0, x1, hw, 2.6, faces_p)
	var roof: Rect2 = TollAtlas.uv("roof")
	g.box("atlas", false, z0 - 0.2, z1 + 0.2, x0 - 0.15, x1 + 0.15, 2.6, 2.85, {"front": roof, "back": roof, "left": roof,
		"right": roof, "top": roof, "bottom": roof})


static func _pillars(g: TollGeo) -> void:
	var pil: Rect2 = TollAtlas.uv("pillar")
	var h_canopy: float = g.o.y + CANOPY_H0
	for x in pillar_xs():
		for dz in [-PILLAR_DZ, PILLAR_DZ]:
			var z: float = g.plaza.z + dz
			var top: float = h_canopy - g.rp(z, x, 0.0).y
			g.box("atlas", false, z - PILLAR_W * 0.5, z + PILLAR_W * 0.5, x - PILLAR_W * 0.5, x + PILLAR_W * 0.5, ISLAND_TOP, top,
				{"front": pil, "back": pil, "left": pil, "right": pil})
			g.box("concrete", false, z - 0.48, z + 0.48, x - 0.48, x + 0.48, ISLAND_TOP - 0.05, ISLAND_TOP + 0.45,
				{"front": Rect2(), "back": Rect2(), "left": Rect2(), "right": Rect2(), "top": Rect2()})


static func _canopy(g: TollGeo, lit: bool) -> void:
	var sk: String = "glow" if lit else "atlas"
	var sc: Color = Color(NIGHT_SIGN, NIGHT_SIGN, NIGHT_SIGN) if lit else Color.WHITE
	var flood := Color(0.42, 0.42, 0.42) if lit else Color.WHITE  # at night the fascia is lit by floodlights
	g.box(sk, true, -CANOPY_DZ, CANOPY_DZ, -CANOPY_HALF, CANOPY_HALF, CANOPY_H0, CANOPY_H1, {"front": TollAtlas.uv("fascia"),
		"back": TollAtlas.uv("fascia_back"), "left": TollAtlas.uv("panel"), "right": TollAtlas.uv("panel")}, flood)
	g.box("atlas", true, -CANOPY_DZ, CANOPY_DZ, -CANOPY_HALF, CANOPY_HALF, CANOPY_H0, CANOPY_H1, {"top": TollAtlas.uv("roof")})
	var nx: int = 4
	var nz: int = 4
	var cw: float = CANOPY_HALF * 2.0 / nx
	var cd: float = CANOPY_DZ * 2.0 / nz
	for i in nx:                                                    # underside: panel grid, LED strips lit at night
		for k in nz:
			var xa: float = -CANOPY_HALF + i * cw
			var za: float = -CANOPY_DZ + k * cd
			g.quad(sk, g.fp(za, xa, CANOPY_H0), g.fp(za, xa + cw, CANOPY_H0), g.fp(za + cd, xa + cw, CANOPY_H0),
				g.fp(za + cd, xa, CANOPY_H0), TollAtlas.uv("ceiling"), Color(0.2, 0.2, 0.21) if lit else Color.WHITE, Vector3.DOWN)
			if lit:
				for v in [36.0 / 128.0, 92.0 / 128.0]:
					var zl: float = za + cd * v
					g.quad("glow", g.fp(zl - 0.09, xa + cw * 0.08, CANOPY_H0 - 0.03), g.fp(zl - 0.09, xa + cw * 0.92, CANOPY_H0 - 0.03),
						g.fp(zl + 0.09, xa + cw * 0.92, CANOPY_H0 - 0.03), g.fp(zl + 0.09, xa + cw * 0.08, CANOPY_H0 - 0.03),
						TollAtlas.uv("lamp"), Color.WHITE, Vector3.DOWN)
	var dark: Rect2 = TollAtlas.uv("dark")
	for s in [-1.0, 1.0]:                                           # lane sign + green arrow signal over each passage
		var sid: String = "sign_etc" if s > 0.0 else "sign_mix"
		var xs0: float = s * PASS_X - 0.95 - s * 0.45
		g.box("atlas", true, -CANOPY_DZ - 0.28, -CANOPY_DZ, xs0, xs0 + 1.9, CANOPY_H0 - 0.95, CANOPY_H0, {"left": dark,
			"right": dark, "bottom": dark})
		g.box(sk, true, -CANOPY_DZ - 0.28, -CANOPY_DZ, xs0, xs0 + 1.9, CANOPY_H0 - 0.95, CANOPY_H0, {"front": TollAtlas.uv(sid)}, sc)
		var xg: float = s * PASS_X + s * 1.05 - 0.42
		g.box("atlas", true, -CANOPY_DZ - 0.3, -CANOPY_DZ, xg, xg + 0.84, CANOPY_H0 - 0.88, CANOPY_H0 - 0.04, {"left": dark,
			"right": dark, "bottom": dark})
		g.box("glow", true, -CANOPY_DZ - 0.3, -CANOPY_DZ, xg, xg + 0.84, CANOPY_H0 - 0.88, CANOPY_H0 - 0.04,
			{"front": TollAtlas.uv("signal_go")})


static func _gantry(g: TollGeo) -> void:
	var steel: Rect2 = TollAtlas.uv("steel")
	var all: Dictionary = {"front": steel, "back": steel, "left": steel, "right": steel, "top": steel, "bottom": steel}
	var of: float = TollPlaza.OUTER_FACE_M + OUTER_W * 0.5
	var beam_h: float = 6.4
	for x in pillar_xs():
		var z: float = g.plaza.z + GANTRY_DZ
		var top: float = g.o.y + beam_h - g.rp(z, x, 0.0).y
		g.box("atlas", false, z - 0.14, z + 0.14, x - 0.14, x + 0.14, ISLAND_TOP, top, all)
	g.box("atlas", true, GANTRY_DZ - 0.18, GANTRY_DZ + 0.18, -of - 0.3, of + 0.3, beam_h, beam_h + 0.36, all)
	for s in [-1.0, 1.0]:                                           # antenna boxes over the passages
		var x: float = s * PASS_X
		g.box("atlas", true, GANTRY_DZ - 0.42, GANTRY_DZ - 0.18, x - 0.36, x + 0.36, beam_h - 0.5, beam_h + 0.02,
			{"front": TollAtlas.uv("antenna"), "left": steel, "right": steel, "bottom": steel, "back": steel})
