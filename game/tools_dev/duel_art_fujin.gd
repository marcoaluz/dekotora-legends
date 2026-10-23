extends RefCounted
## T-204: FUJIN (wind god of Japanese folklore), our own drawing in ukiyo-e / Dekotora style, canvas 1024x1280.
## Front view on a blue cloud, green skin, dark wind-swept hair, a big cream wind bag held over the head (two
## inflated lobes tied with red rope, indigo wind curls), wave-pattern loincloth and wind lines. Nothing traced or
## copied from any existing artwork: every shape is placed by the coordinates below.

const K = preload("res://tools_dev/duel_art_kit.gd")
const CX: float = 512.0

const SKIN := Color("#2f9c74")
const SKIN_SH := Color("#19664a")
const SKIN_LT := Color("#6ccca2")
const HAIR := Color("#1f2748")
const HAIR_SH := Color("#0f1329")
const HAIR_LT := Color("#5466a8")
const BAG := Color("#f2e9d4")
const BAG_SH := Color("#b8a886")
const BAG_LT := Color("#fffbf2")
const WIND := Color("#2f4fa6")
const ROPE := Color("#cc2a30")
const ROPE_SH := Color("#7c1218")
const CLOTH := Color("#2b4a9a")
const CLOTH_SH := Color("#182c61")
const WAVE := Color("#d2e6ff")
const CLOUD := Color("#2c4e7c")
const CLOUD_SH := Color("#162c4c")
const CLOUD_LT := Color("#6aa2d2")
const CURL := Color("#a2cff2")
const GOLD := Color("#f2b63c")
const GOLD_SH := Color("#a26a18")
const BONE := Color("#f6ecd2")
const BONE_SH := Color("#c6b48a")
const EYE := Color("#fffbe8")
const IRIS := Color("#ff9a2a")
const MOUTH := Color("#3b0710")
const GUST := Color(0.82, 0.95, 1.0, 0.92)

const BAG_C := Vector2(512.0, 404.0)
const BAG_R: float = 262.0


static func paint(ci: CanvasItem) -> void:
	_bag_tails(ci)
	_bag(ci)
	_gusts(ci)
	_hair(ci)
	_cloud(ci)
	_legs(ci)
	for s in [-1.0, 1.0]:
		_arm(ci, s)
	_torso(ci)
	_loincloth(ci)
	_head(ci)
	for s2 in [-1.0, 1.0]:
		_hand(ci, s2)


static func _p(s: float, x: float, y: float) -> Vector2:
	return Vector2(CX + s * x, y)


static func _on_arc(deg: float, r: float = BAG_R) -> Vector2:
	var a: float = deg_to_rad(deg)
	return BAG_C + Vector2(cos(a), sin(a)) * r


# ---------------------------------------------------------------- the wind bag over the head
static func _bag(ci: CanvasItem) -> void:
	var degs: Array = [195.0, 212.0, 232.0, 252.0, 270.0, 288.0, 308.0, 328.0, 345.0]
	var radii := PackedFloat32Array([42.0, 78.0, 100.0, 92.0, 70.0, 94.0, 102.0, 80.0, 42.0])
	var spine := PackedVector2Array()
	for d in degs:
		spine.append(_on_arc(float(d)))
	var bag: PackedVector2Array = K.capsule(spine, radii)
	K.part(ci, bag, BAG, BAG_SH, BAG_LT, 9.0, Vector2(0, -26), Vector2(0, 14))
	for f in [[224.0, 0.86], [246.0, 1.12], [294.0, 0.9], [316.0, 1.1]]:     # cloth folds
		var a0: float = float(f[0])
		K.brush(ci, PackedVector2Array([_on_arc(a0 - 6.0, BAG_R * float(f[1])), _on_arc(a0, BAG_R * float(f[1]) + 6.0),
			_on_arc(a0 + 7.0, BAG_R * float(f[1]))]), 8.0, BAG_SH, 0.5)
	for w in [[236.0, 34.0], [302.0, 34.0], [258.0, 22.0], [280.0, 22.0]]:   # indigo wind curls on the cloth
		K.spiral(ci, _on_arc(float(w[0])), float(w[1]), 1.5, WIND, 8.0)
	var top: Vector2 = _on_arc(270.0)                                    # red rope tie between the two lobes
	var tie: PackedVector2Array = Geometry2D.intersect_polygons(K.ellipse(top, 15.0, 90.0, 0.0, 32), bag)[0]
	K.part(ci, tie, ROPE, ROPE_SH, Color(0, 0, 0, 0), 6.0, Vector2(-5, 0))
	K.part(ci, K.circle(top + Vector2(0, 52), 17.0), ROPE, ROPE_SH, Color(0, 0, 0, 0), 6.0, Vector2(-5, -5))
	for s in [-1.0, 1.0]:
		K.brush(ci, PackedVector2Array([top + Vector2(0, 56), top + Vector2(s * 26, 84), top + Vector2(s * 18, 112)]), 14.0, ROPE, 0.3, 0.6)


## The open ends of the bag flapping in the wind beyond the hands.
static func _bag_tails(ci: CanvasItem) -> void:
	var l: PackedVector2Array = K.capsule(PackedVector2Array([_on_arc(195.0), Vector2(196, 386), Vector2(150, 458), Vector2(96, 478), Vector2(58, 440)]),
		PackedFloat32Array([40.0, 48.0, 40.0, 26.0, 8.0]))
	var r: PackedVector2Array = K.capsule(PackedVector2Array([_on_arc(345.0), Vector2(840, 300), Vector2(900, 330), Vector2(950, 296), Vector2(984, 244)]),
		PackedFloat32Array([40.0, 46.0, 38.0, 24.0, 8.0]))
	for t in [l, r]:
		K.part(ci, t, BAG, BAG_SH, BAG_LT, 8.0, Vector2(0, -16), Vector2(0, 10))
	K.spiral(ci, Vector2(150, 446), 22.0, 1.3, WIND, 6.0)
	K.spiral(ci, Vector2(902, 318), 20.0, 1.3, WIND, 6.0)


static func _gusts(ci: CanvasItem) -> void:
	var lines: Array = [
		[Vector2(30, 760), Vector2(120, 700), Vector2(150, 620), Vector2(108, 584), Vector2(78, 620)],
		[Vector2(994, 760), Vector2(910, 690), Vector2(890, 600), Vector2(930, 566), Vector2(956, 600)],
		[Vector2(60, 250), Vector2(150, 200), Vector2(250, 190)],
		[Vector2(964, 520), Vector2(880, 470), Vector2(860, 420)],
		[Vector2(40, 900), Vector2(150, 870), Vector2(230, 900)]]
	for l in lines:
		K.brush(ci, PackedVector2Array(l), 14.0, GUST, 0.3, 0.3, 0.0)


# ---------------------------------------------------------------- hair blown to the right
static func _hair(ci: CanvasItem) -> void:
	var c := Vector2(CX, 392.0)
	var polys: Array = [K.circle(c, 118.0, 48)]
	var angs: Array = [-196.0, -176.0, -156.0, -136.0, -116.0, -96.0, -76.0, -56.0, -36.0, -16.0, 6.0, 26.0]
	for i in angs.size():
		var a: float = deg_to_rad(float(angs[i]))
		var bend: float = 0.55                                        # everything swept to the right by the wind
		var len_: float = 200.0 + 24.0 * sin(float(i) * 1.7) + (30.0 if angs[i] > -60.0 else 0.0)
		var pts := PackedVector2Array([c + Vector2(cos(a), sin(a)) * 70.0,
			c + Vector2(cos(a + bend * 0.35), sin(a + bend * 0.35)) * (len_ * 0.6),
			c + Vector2(cos(a + bend), sin(a + bend)) * len_])
		polys.append(K.brush_poly(pts, 74.0, 0.12, 0.6, 0.0))
	var hair: PackedVector2Array = K.union(polys)
	K.part(ci, hair, HAIR, HAIR_SH, HAIR_LT, 8.0, Vector2(0, -18), Vector2(-10, 12))
	for j in [-160.0, -125.0, -95.0, -65.0, -30.0]:
		var b: float = deg_to_rad(float(j))
		K.brush(ci, PackedVector2Array([c + Vector2(cos(b), sin(b)) * 118.0, c + Vector2(cos(b + 0.2), sin(b + 0.2)) * 168.0,
			c + Vector2(cos(b + 0.4), sin(b + 0.4)) * 196.0]), 8.0, HAIR_LT, 0.3)


static func _cloud(ci: CanvasItem) -> void:
	var lobes: Array = [[190, 1100, 66], [290, 1062, 88], [410, 1086, 84], [540, 1066, 96], [662, 1060, 88],
		[790, 1094, 72], [260, 1152, 60], [420, 1164, 72], [600, 1160, 76], [744, 1150, 58], [870, 1124, 46], [128, 1134, 42]]
	K.cloud(ci, lobes, CLOUD, CLOUD_SH, CLOUD_LT, CURL)


# ---------------------------------------------------------------- legs: left knee up, right leg stepping out
static func _legs(ci: CanvasItem) -> void:
	var lt: PackedVector2Array = K.capsule(PackedVector2Array([Vector2(440, 774), Vector2(340, 800), Vector2(262, 852)]), PackedFloat32Array([80.0, 76.0, 58.0]))
	var ls: PackedVector2Array = K.capsule(PackedVector2Array([Vector2(258, 858), Vector2(240, 946), Vector2(286, 1010)]), PackedFloat32Array([56.0, 60.0, 34.0]))
	var lf: PackedVector2Array = K.union([K.ellipse(Vector2(268, 1034), 74.0, 28.0), K.circle(Vector2(208, 1042), 19.0), K.circle(Vector2(230, 1052), 17.0)])
	var rt: PackedVector2Array = K.capsule(PackedVector2Array([Vector2(584, 774), Vector2(668, 832), Vector2(716, 896)]), PackedFloat32Array([80.0, 74.0, 56.0]))
	var rs: PackedVector2Array = K.capsule(PackedVector2Array([Vector2(718, 900), Vector2(772, 958), Vector2(794, 1012)]), PackedFloat32Array([54.0, 56.0, 32.0]))
	var rf: PackedVector2Array = K.union([K.ellipse(Vector2(812, 1036), 76.0, 28.0), K.circle(Vector2(874, 1044), 19.0), K.circle(Vector2(852, 1054), 17.0)])
	for leg in [[ls, lf, lt, -1.0], [rs, rf, rt, 1.0]]:
		var s: float = float(leg[3])
		K.part(ci, leg[0], SKIN, SKIN_SH, SKIN_LT, 7.0, Vector2(16.0 * s, -14), Vector2(-12.0 * s, 10))
		K.part(ci, leg[1], SKIN, SKIN_SH, Color(0, 0, 0, 0), 7.0, Vector2(0, -12))
		K.part(ci, leg[2], SKIN, SKIN_SH, SKIN_LT, 7.0, Vector2(16.0 * s, -14), Vector2(-12.0 * s, 12))
	K.brush(ci, PackedVector2Array([Vector2(300, 822), Vector2(266, 862), Vector2(258, 900)]), 9.0, SKIN_SH)
	K.brush(ci, PackedVector2Array([Vector2(690, 868), Vector2(716, 910), Vector2(740, 930)]), 9.0, SKIN_SH)
	for a in [[Vector2(282, 996), 33.0], [Vector2(792, 998), 31.0]]:       # gold anklets
		ci.draw_arc(a[0], a[1], 0.0, TAU, 36, K.INK, 16.0, true)
		ci.draw_arc(a[0], a[1], 0.0, TAU, 36, GOLD, 9.0, true)


# ---------------------------------------------------------------- torso, arms
static func _torso(ci: CanvasItem) -> void:
	var body: PackedVector2Array = K.union([K.ellipse(Vector2(CX, 590), 164.0, 116.0), K.ellipse(Vector2(CX, 712), 134.0, 112.0),
		K.ellipse(Vector2(CX, 764), 118.0, 56.0), K.ellipse(Vector2(CX, 516), 90.0, 50.0)])
	K.part(ci, body, SKIN, SKIN_SH, SKIN_LT, 8.0, Vector2(0, -22), Vector2(0, 14))
	for s in [-1.0, 1.0]:
		K.part(ci, K.ellipse(_p(s, 150, 550), 56.0, 50.0, 0.5 * s, 40), SKIN, SKIN_SH, SKIN_LT, 7.0, Vector2(14.0 * s, -14), Vector2(-10.0 * s, 10))
		K.brush(ci, PackedVector2Array([_p(s, 118, 604), _p(s, 82, 638), _p(s, 30, 648), _p(s, 6, 634)]), 11.0, SKIN_SH, 0.5)
		K.brush(ci, PackedVector2Array([_p(s, 94, 526), _p(s, 58, 516), _p(s, 20, 520)]), 7.0, SKIN_SH)
	K.brush(ci, PackedVector2Array([Vector2(CX - 90, 712), Vector2(CX - 46, 752), Vector2(CX, 762), Vector2(CX + 46, 752), Vector2(CX + 90, 712)]), 9.0, SKIN_SH, 0.5)
	ci.draw_arc(Vector2(CX, 728), 8.0, 0.0, TAU, 20, SKIN_SH, 5.0, true)


static func _arm(ci: CanvasItem, s: float) -> void:
	var upper: PackedVector2Array = K.capsule(PackedVector2Array([_p(s, 150, 552), _p(s, 226, 520), _p(s, 270, 470)]), PackedFloat32Array([58.0, 54.0, 44.0]))
	var fore: PackedVector2Array = K.capsule(PackedVector2Array([_p(s, 272, 470), _p(s, 272, 412), _p(s, 256, 362)]), PackedFloat32Array([44.0, 40.0, 32.0]))
	K.part(ci, upper, SKIN, SKIN_SH, SKIN_LT, 7.0, Vector2(14.0 * s, -12), Vector2(-10.0 * s, 10))
	K.part(ci, fore, SKIN, SKIN_SH, SKIN_LT, 7.0, Vector2(14.0 * s, -10), Vector2(-10.0 * s, 8))
	K.part(ci, K.ellipse(_p(s, 264, 386), 38.0, 14.0, -0.35 * s, 32), GOLD, GOLD_SH, Color(0, 0, 0, 0), 5.0, Vector2(0, -6))


static func _hand(ci: CanvasItem, s: float) -> void:
	var p: Vector2 = _on_arc(195.0 if s < 0.0 else 345.0)
	var fist: PackedVector2Array = K.union([K.circle(p + Vector2(0, 8), 38.0, 36), K.ellipse(p + Vector2(6.0 * s, 20), 28.0, 34.0, 0.3 * s, 32)])
	K.part(ci, fist, SKIN, SKIN_SH, SKIN_LT, 7.0, Vector2(10.0 * s, -10), Vector2(-8.0 * s, 8))
	for i in 3:
		var y: float = p.y - 8.0 + float(i) * 14.0
		K.brush(ci, PackedVector2Array([Vector2(p.x - 22, y), Vector2(p.x, y + 4), Vector2(p.x + 22, y)]), 5.0, SKIN_SH)


# ---------------------------------------------------------------- loincloth with a wave (seigaiha) pattern
static func _loincloth(ci: CanvasItem) -> void:
	var cloth: PackedVector2Array = K.union([K.ellipse(Vector2(CX, 792), 140.0, 44.0),
		K.capsule(PackedVector2Array([Vector2(CX, 800), Vector2(CX - 8, 880), Vector2(CX + 6, 960)]), PackedFloat32Array([70.0, 58.0, 24.0]))])
	K.part(ci, cloth, CLOTH, CLOTH_SH, Color(0, 0, 0, 0), 8.0, Vector2(0, -16))
	for row in 6:
		for col in 7:
			var c := Vector2(CX - 150.0 + float(col) * 50.0 + (25.0 if row % 2 == 1 else 0.0), 780.0 + float(row) * 30.0)
			for rr in [22.0, 14.0]:
				var arc := PackedVector2Array()
				for k in 13:
					var a: float = PI + float(k) / 12.0 * PI
					arc.append(c + Vector2(cos(a), sin(a)) * rr)
				var band: PackedVector2Array = K.brush_poly(arc, 4.0, 0.5, 1.0, 1.0)
				for q in Geometry2D.intersect_polygons(band, cloth):
					K.fill(ci, q, WAVE)
	var belt: PackedVector2Array = K.ellipse(Vector2(CX, 756), 134.0, 20.0, 0.0, 48)
	K.part(ci, belt, ROPE, ROPE_SH, Color(0, 0, 0, 0), 6.0, Vector2(0, -8))
	K.part(ci, K.circle(Vector2(CX + 20, 760), 22.0), ROPE, ROPE_SH, Color(0, 0, 0, 0), 6.0, Vector2(-6, -6))


# ---------------------------------------------------------------- head: grinning, round bulging eyes looking aside
static func _head(ci: CanvasItem) -> void:
	K.part(ci, K.ellipse(Vector2(CX, 506), 66.0, 44.0), SKIN, SKIN_SH, Color(0, 0, 0, 0), 7.0, Vector2(0, -10))   # neck
	for s in [-1.0, 1.0]:
		K.part(ci, K.ellipse(_p(s, 100, 410), 20.0, 40.0, 0.5 * s, 32), SKIN, SKIN_SH, Color(0, 0, 0, 0), 6.0, Vector2(8.0 * s, -6))
	var face: PackedVector2Array = K.union([K.ellipse(Vector2(CX, 400), 100.0, 104.0), K.ellipse(Vector2(CX, 452), 96.0, 64.0)])
	K.part(ci, face, SKIN, SKIN_SH, SKIN_LT, 8.0, Vector2(0, -18), Vector2(0, 12))
	for s2 in [-1.0, 1.0]:
		var brow: PackedVector2Array = K.brush_poly(PackedVector2Array([_p(s2, 12, 362), _p(s2, 44, 346), _p(s2, 82, 344), _p(s2, 108, 326)]), 30.0, 0.4, 0.5)
		K.part(ci, brow, HAIR, HAIR_SH, Color(0, 0, 0, 0), 4.0, Vector2(0, -6))
		var eye: PackedVector2Array = K.circle(_p(s2, 44, 388), 27.0, 36)
		K.part(ci, eye, EYE, BONE_SH, Color(0, 0, 0, 0), 5.0, Vector2(0, -6))
		var look := Vector2(9, 2)                                     # both eyes look to the right (towards the duel)
		ci.draw_circle(_p(s2, 44, 388) + look, 15.0, K.INK)
		ci.draw_circle(_p(s2, 44, 388) + look, 12.0, IRIS)
		ci.draw_circle(_p(s2, 44, 388) + look * 1.2, 6.0, K.INK)
		ci.draw_circle(_p(s2, 44, 388) + look + Vector2(4, -5), 2.6, Color.WHITE)
		K.brush(ci, PackedVector2Array([_p(s2, 14, 376), _p(s2, 44, 358), _p(s2, 76, 372)]), 8.0, K.INK, 0.4, 0.5, 0.2)
		K.brush(ci, PackedVector2Array([_p(s2, 60, 424), _p(s2, 76, 450), _p(s2, 78, 476)]), 7.0, SKIN_SH)
	var nose: PackedVector2Array = K.union([K.ellipse(Vector2(CX - 18, 434), 17.0, 13.0), K.ellipse(Vector2(CX + 18, 434), 17.0, 13.0), K.ellipse(Vector2(CX, 418), 12.0, 22.0)])
	K.part(ci, nose, SKIN, SKIN_SH, Color(0, 0, 0, 0), 5.0, Vector2(0, -8))
	for s3 in [-1.0, 1.0]:
		ci.draw_circle(_p(s3, 14, 440), 4.5, K.INK)
	var grin := PackedVector2Array()                                  # wide grin with the corners up
	for k in 25:
		var u: float = float(k) / 24.0
		grin.append(Vector2(CX - 80.0 + 160.0 * u, 470.0 - 22.0 * pow(absf(u - 0.5) * 2.0, 2.0)))
	for k2 in 25:
		var u2: float = 1.0 - float(k2) / 24.0
		grin.append(Vector2(CX - 80.0 + 160.0 * u2, 470.0 - 22.0 * pow(absf(u2 - 0.5) * 2.0, 2.0) + 30.0 * sin(PI * u2)))
	K.ink(ci, grin, 7.0)
	K.fill(ci, grin, MOUTH)
	for q in Geometry2D.intersect_polygons(K.moved(grin, Vector2(0, -3)), grin):
		K.fill(ci, q, BONE)
	for i in 7:                                                       # teeth gaps
		var x: float = CX - 60.0 + float(i) * 20.0
		K.brush(ci, PackedVector2Array([Vector2(x, 462), Vector2(x, 476), Vector2(x, 492)]), 4.0, BONE_SH)
	K.brush(ci, PackedVector2Array([Vector2(CX - 70, 480), Vector2(CX, 486), Vector2(CX + 70, 480)]), 4.0, BONE_SH)
	for s4 in [-1.0, 1.0]:                                            # cheek dimples of the grin
		K.brush(ci, PackedVector2Array([_p(s4, 78, 448), _p(s4, 92, 466), _p(s4, 86, 486)]), 7.0, SKIN_SH)
