extends RefCounted
## T-204: RAIJIN (thunder god of Japanese folklore), our own drawing in ukiyo-e / Dekotora style, canvas 1024x1280.
## Front view in a wide guardian stance on a purple cloud, red skin, white flame hair, horns, tiger-skin loincloth,
## a ring of eight taiko drums (mitsudomoe on the heads) behind him and two drumsticks raised. Nothing traced or
## copied from any existing artwork: every shape is placed by the coordinates below.

const K = preload("res://tools_dev/duel_art_kit.gd")
const CX: float = 512.0

const SKIN := Color("#c8382b")
const SKIN_SH := Color("#8a1f1b")
const SKIN_LT := Color("#ee7a5a")
const HAIR := Color("#f4f0fa")
const HAIR_SH := Color("#aa98d2")
const GOLD := Color("#f2b63c")
const GOLD_SH := Color("#a26a18")
const DRUM := Color("#a41c28")
const DRUM_SH := Color("#5c0d18")
const HEAD := Color("#f5e8c8")
const HEAD_SH := Color("#cfb98e")
const TOMOE := Color("#a3121d")
const HOOP := Color("#3c1834")
const TIGER := Color("#f3a221")
const TIGER_SH := Color("#bf6810")
const SASH := Color("#6e3fa6")
const SASH_SH := Color("#3f2168")
const CLOUD := Color("#3e2c74")
const CLOUD_SH := Color("#22174a")
const CLOUD_LT := Color("#7e68c8")
const CURL := Color("#a996ea")
const BONE := Color("#f6ecd2")
const BONE_SH := Color("#c6b48a")
const EYE := Color("#fffbe8")
const IRIS := Color("#ffd23a")
const MOUTH := Color("#3b0710")
const TONGUE := Color("#d9505c")
const STICK := Color("#70401f")
const SPARK := Color("#ffeb5c")
const JADE := Color("#3fae6a")
const JADE_SH := Color("#1f6b3e")


static func paint(ci: CanvasItem) -> void:
	_drums(ci)
	_hair(ci)
	_cloud(ci)
	for s in [-1.0, 1.0]:
		_leg(ci, s)
	_sash_tails(ci)
	for s2 in [-1.0, 1.0]:
		_arm(ci, s2)
	_torso(ci)
	_loincloth(ci)
	for s3 in [-1.0, 1.0]:
		_fist(ci, s3)
	_head(ci)
	_necklace(ci)
	_sparks(ci)


static func _p(s: float, x: float, y: float) -> Vector2:   # x measured from the centre line, side s = -1 / +1
	return Vector2(CX + s * x, y)


# ---------------------------------------------------------------- drums
static func _drums(ci: CanvasItem) -> void:
	var c := Vector2(CX, 500.0)
	var ring: PackedVector2Array = K.ellipse(c, 440.0, 400.0, 0.0, 96)
	ring.append(ring[0])
	ci.draw_polyline(ring, K.INK, 40.0, true)
	ci.draw_polyline(ring, HOOP, 28.0, true)
	var inner: PackedVector2Array = K.ellipse(c, 432.0, 392.0, 0.0, 96)
	inner.append(inner[0])
	ci.draw_polyline(inner, GOLD, 4.0, true)
	for k in 8:
		var a: float = float(k) / 8.0 * TAU
		_drum(ci, c + Vector2(cos(a) * 440.0, sin(a) * 400.0), 66.0, a)


static func _drum(ci: CanvasItem, c: Vector2, r: float, rot: float) -> void:
	K.part(ci, K.circle(c, r, 48), DRUM, DRUM_SH, Color(0, 0, 0, 0), 8.0, Vector2(-10, -12))
	for i in 14:                                                     # studs of the drum skin
		var a: float = float(i) / 14.0 * TAU
		var p: Vector2 = c + Vector2(cos(a), sin(a)) * r * 0.86
		ci.draw_circle(p, 5.5, K.INK)
		ci.draw_circle(p, 3.8, GOLD)
	K.part(ci, K.circle(c, r * 0.7, 40), HEAD, HEAD_SH, Color(0, 0, 0, 0), 5.0, Vector2(-7, -8))
	K.tomoe(ci, c, r * 0.6, TOMOE, rot)


# ---------------------------------------------------------------- hair (white flames behind the head)
static func _hair(ci: CanvasItem) -> void:
	var c := Vector2(CX, 318.0)
	var polys: Array = [K.circle(c, 130.0, 48)]
	var angs: Array = [-206.0, -188.0, -170.0, -152.0, -134.0, -116.0, -98.0, -82.0, -64.0, -46.0, -28.0, -10.0, 8.0, 26.0]
	for i in angs.size():
		var a: float = deg_to_rad(float(angs[i]))
		var curl: float = 0.32 if a < -PI * 0.5 else -0.32           # tips curl away from the centre line
		var len_: float = 236.0 + 30.0 * sin(float(i) * 2.1) - (46.0 if absf(float(angs[i]) + 90.0) > 100.0 else 0.0)
		var pts := PackedVector2Array([c + Vector2(cos(a), sin(a)) * 70.0,
			c + Vector2(cos(a + curl * 0.3), sin(a + curl * 0.3)) * (len_ * 0.62),
			c + Vector2(cos(a + curl), sin(a + curl)) * len_])
		polys.append(K.brush_poly(pts, 84.0, 0.12, 0.6, 0.0))
	var hair: PackedVector2Array = K.union(polys)
	K.part(ci, hair, HAIR, HAIR_SH, Color(0, 0, 0, 0), 8.0, Vector2(0, -20))
	for j in [-150.0, -118.0, -90.0, -62.0, -30.0]:                 # strands inside the flames
		var b: float = deg_to_rad(float(j))
		K.brush(ci, PackedVector2Array([c + Vector2(cos(b), sin(b)) * 120.0, c + Vector2(cos(b + 0.12), sin(b + 0.12)) * 175.0,
			c + Vector2(cos(b + 0.2), sin(b + 0.2)) * 205.0]), 9.0, HAIR_SH, 0.3)


# ---------------------------------------------------------------- cloud under the feet
static func _cloud(ci: CanvasItem) -> void:
	var lobes: Array = [[205, 1095, 70], [300, 1050, 92], [420, 1078, 88], [540, 1060, 98], [660, 1052, 90],
		[780, 1088, 76], [270, 1150, 62], [420, 1160, 74], [600, 1158, 78], [750, 1146, 60], [880, 1118, 46], [140, 1130, 44]]
	K.cloud(ci, lobes, CLOUD, CLOUD_SH, CLOUD_LT, CURL)


# ---------------------------------------------------------------- legs (wide guardian stance, knees out)
static func _leg(ci: CanvasItem, s: float) -> void:
	var thigh: PackedVector2Array = K.capsule(PackedVector2Array([_p(s, 72, 712), _p(s, 152, 760), _p(s, 232, 832)]),
		PackedFloat32Array([80.0, 78.0, 60.0]))
	var shin: PackedVector2Array = K.capsule(PackedVector2Array([_p(s, 238, 836), _p(s, 252, 924), _p(s, 216, 1004)]),
		PackedFloat32Array([56.0, 62.0, 34.0]))
	var foot: PackedVector2Array = K.union([K.ellipse(_p(s, 236, 1030), 76.0, 30.0, 0.0, 40),
		K.circle(_p(s, 300, 1040), 20.0), K.circle(_p(s, 276, 1050), 18.0), K.circle(_p(s, 252, 1054), 17.0)])
	var sh := Vector2(16.0 * s, -14.0)
	K.part(ci, shin, SKIN, SKIN_SH, SKIN_LT, 7.0, sh, Vector2(-12.0 * s, 10.0))
	K.part(ci, foot, SKIN, SKIN_SH, Color(0, 0, 0, 0), 7.0, Vector2(0, -12))
	for t in [[300.0, 1040.0], [276.0, 1050.0], [252.0, 1054.0]]:   # claws
		var tp: Vector2 = _p(s, float(t[0]), float(t[1]))
		K.part(ci, PackedVector2Array([tp + Vector2(-9, 8), tp + Vector2(9, 8), tp + Vector2(4.0 * s, 26)]), BONE, BONE_SH, Color(0, 0, 0, 0), 4.0, Vector2(0, -5))
	K.part(ci, thigh, SKIN, SKIN_SH, SKIN_LT, 7.0, sh, Vector2(-12.0 * s, 12.0))
	K.brush(ci, PackedVector2Array([_p(s, 200, 800), _p(s, 226, 846), _p(s, 230, 880)]), 9.0, SKIN_SH)   # knee
	K.brush(ci, PackedVector2Array([_p(s, 240, 900), _p(s, 262, 940), _p(s, 240, 985)]), 8.0, SKIN_SH)   # calf
	ci.draw_arc(_p(s, 222, 994), 34.0, 0.0, TAU, 36, K.INK, 16.0, true)                                 # gold anklet
	ci.draw_arc(_p(s, 222, 994), 34.0, 0.0, TAU, 36, GOLD, 9.0, true)


# ---------------------------------------------------------------- torso
static func _torso(ci: CanvasItem) -> void:
	var body: PackedVector2Array = K.union([K.ellipse(Vector2(CX, 525), 168.0, 118.0), K.ellipse(Vector2(CX, 648), 130.0, 110.0),
		K.ellipse(Vector2(CX, 700), 118.0, 60.0), K.ellipse(Vector2(CX, 452), 92.0, 50.0)])
	K.part(ci, body, SKIN, SKIN_SH, SKIN_LT, 8.0, Vector2(0, -22), Vector2(0, 14))
	for s in [-1.0, 1.0]:
		K.part(ci, K.ellipse(_p(s, 150, 486), 58.0, 52.0, 0.5 * s, 40), SKIN, SKIN_SH, SKIN_LT, 7.0, Vector2(14.0 * s, -14), Vector2(-10.0 * s, 10))
		K.brush(ci, PackedVector2Array([_p(s, 120, 540), _p(s, 84, 574), _p(s, 30, 584), _p(s, 6, 570)]), 11.0, SKIN_SH, 0.5)   # chest
		K.brush(ci, PackedVector2Array([_p(s, 96, 462), _p(s, 60, 452), _p(s, 20, 456)]), 7.0, SKIN_SH)                          # collarbone
		K.brush(ci, PackedVector2Array([_p(s, 46, 610), _p(s, 40, 634), _p(s, 44, 658)]), 7.0, SKIN_SH)                          # abs
	K.brush(ci, PackedVector2Array([Vector2(CX - 84, 650), Vector2(CX - 44, 690), Vector2(CX, 698), Vector2(CX + 44, 690), Vector2(CX + 84, 650)]), 9.0, SKIN_SH, 0.5)
	ci.draw_arc(Vector2(CX, 664), 8.0, 0.0, TAU, 20, SKIN_SH, 5.0, true)


# ---------------------------------------------------------------- loincloth (tiger skin) and the rope belt
static func _loincloth(ci: CanvasItem) -> void:
	var cloth: PackedVector2Array = K.union([K.ellipse(Vector2(CX, 730), 142.0, 46.0),
		K.capsule(PackedVector2Array([Vector2(CX, 740), Vector2(CX + 6, 820), Vector2(CX - 4, 900)]), PackedFloat32Array([72.0, 60.0, 26.0]))])
	K.part(ci, cloth, TIGER, TIGER_SH, Color(0, 0, 0, 0), 8.0, Vector2(0, -16))
	var stripes: Array = [[400, 700, 418, 752], [446, 706, 456, 766], [494, 790, 520, 830], [470, 846, 508, 862],
		[560, 706, 552, 766], [610, 700, 596, 752], [530, 760, 550, 796]]
	for st in stripes:
		var sp: PackedVector2Array = K.brush_poly(PackedVector2Array([Vector2(st[0], st[1]), Vector2((st[0] + st[2]) * 0.5 + 6, (st[1] + st[3]) * 0.5),
			Vector2(st[2], st[3])]), 18.0, 0.3)
		for q in Geometry2D.intersect_polygons(sp, cloth):
			K.fill(ci, q, K.INK)
	var belt: PackedVector2Array = K.ellipse(Vector2(CX, 690), 136.0, 22.0, 0.0, 48)
	K.part(ci, belt, BONE, BONE_SH, Color(0, 0, 0, 0), 6.0, Vector2(0, -8))
	for i in 11:                                                     # rope twist
		var x: float = CX - 120.0 + float(i) * 24.0
		K.brush(ci, PackedVector2Array([Vector2(x - 6, 676), Vector2(x, 690), Vector2(x + 6, 704)]), 6.0, BONE_SH)
	K.part(ci, K.circle(Vector2(CX, 694), 24.0), BONE, BONE_SH, Color(0, 0, 0, 0), 6.0, Vector2(-6, -6))


## Purple sash ends flying out from the belt knot (behind the arms, in front of the legs).
static func _sash_tails(ci: CanvasItem) -> void:
	for s in [-1.0, 1.0]:
		var tail: PackedVector2Array = K.brush_poly(PackedVector2Array([_p(s, 30, 700), _p(s, 140, 726), _p(s, 240, 676),
			_p(s, 330, 640), _p(s, 400, 676), _p(s, 452, 640)]), 46.0, 0.18, 0.5, 0.05)
		K.part(ci, tail, SASH, SASH_SH, Color(0, 0, 0, 0), 6.0, Vector2(0, -12))


# ---------------------------------------------------------------- arms raised with the drumsticks
static func _arm(ci: CanvasItem, s: float) -> void:
	var upper: PackedVector2Array = K.capsule(PackedVector2Array([_p(s, 156, 482), _p(s, 230, 420), _p(s, 278, 366)]),
		PackedFloat32Array([60.0, 56.0, 46.0]))
	var fore: PackedVector2Array = K.capsule(PackedVector2Array([_p(s, 278, 366), _p(s, 270, 302), _p(s, 244, 262)]),
		PackedFloat32Array([46.0, 42.0, 34.0]))
	K.part(ci, upper, SKIN, SKIN_SH, SKIN_LT, 7.0, Vector2(14.0 * s, -12), Vector2(-10.0 * s, 10))
	K.part(ci, fore, SKIN, SKIN_SH, SKIN_LT, 7.0, Vector2(14.0 * s, -10), Vector2(-10.0 * s, 8))
	K.brush(ci, PackedVector2Array([_p(s, 210, 452), _p(s, 240, 420), _p(s, 262, 386)]), 8.0, SKIN_SH)   # biceps line
	var band: PackedVector2Array = K.ellipse(_p(s, 252, 280), 40.0, 15.0, -0.5 * s, 32)
	K.part(ci, band, GOLD, GOLD_SH, Color(0, 0, 0, 0), 5.0, Vector2(0, -6))
	K.part(ci, K.ellipse(_p(s, 252, 396), 46.0, 13.0, 0.64 * s, 32), GOLD, GOLD_SH, Color(0, 0, 0, 0), 5.0, Vector2(0, -6))   # armlet


static func _fist(ci: CanvasItem, s: float) -> void:
	var stick: PackedVector2Array = K.capsule(PackedVector2Array([_p(s, 222, 268), _p(s, 266, 196), _p(s, 296, 142)]),
		PackedFloat32Array([10.0, 10.0, 9.0]))
	K.part(ci, stick, STICK, STICK.darkened(0.4), Color(0, 0, 0, 0), 5.0, Vector2(4.0 * s, -4))
	K.part(ci, K.circle(_p(s, 300, 134), 17.0), STICK, STICK.darkened(0.4), Color(0, 0, 0, 0), 5.0, Vector2(4.0 * s, -4))
	var fist: PackedVector2Array = K.union([K.circle(_p(s, 240, 244), 40.0, 36), K.ellipse(_p(s, 222, 236), 30.0, 36.0, 0.3 * s, 32)])
	K.part(ci, fist, SKIN, SKIN_SH, SKIN_LT, 7.0, Vector2(10.0 * s, -10), Vector2(-8.0 * s, 8))
	for i in 3:                                                      # knuckles
		var y: float = 222.0 + float(i) * 15.0
		K.brush(ci, PackedVector2Array([_p(s, 214, y), _p(s, 236, y + 4), _p(s, 258, y)]), 5.0, SKIN_SH)


# ---------------------------------------------------------------- head
static func _head(ci: CanvasItem) -> void:
	for s in [-1.0, 1.0]:
		K.part(ci, K.ellipse(_p(s, 102, 342), 22.0, 36.0, 0.35 * s, 32), SKIN, SKIN_SH, Color(0, 0, 0, 0), 6.0, Vector2(8.0 * s, -6))
	var face: PackedVector2Array = K.union([K.ellipse(Vector2(CX, 330), 98.0, 108.0), K.ellipse(Vector2(CX, 388), 92.0, 68.0)])
	K.part(ci, face, SKIN, SKIN_SH, SKIN_LT, 8.0, Vector2(0, -18), Vector2(0, 12))
	for s2 in [-1.0, 1.0]:                                           # horns
		var horn: PackedVector2Array = K.capsule(PackedVector2Array([_p(s2, 40, 252), _p(s2, 66, 206), _p(s2, 72, 150)]),
			PackedFloat32Array([20.0, 14.0, 3.0]))
		K.part(ci, horn, BONE, BONE_SH, Color(0, 0, 0, 0), 6.0, Vector2(8.0 * s2, -4))
		K.brush(ci, PackedVector2Array([_p(s2, 10, 300), _p(s2, 40, 286), _p(s2, 74, 266), _p(s2, 98, 250)]), 30.0, K.INK, 0.35, 0.5)   # brow
		var eye: PackedVector2Array = K.ellipse(_p(s2, 44, 320), 31.0, 19.0, 0.3 * s2, 36)
		K.part(ci, eye, EYE, HEAD_SH, Color(0, 0, 0, 0), 5.0, Vector2(0, -6))
		ci.draw_circle(_p(s2, 40, 322), 14.0, K.INK)
		ci.draw_circle(_p(s2, 40, 322), 11.0, IRIS)
		ci.draw_circle(_p(s2, 38, 322), 5.5, K.INK)
		ci.draw_circle(_p(s2, 44, 317), 2.5, Color.WHITE)
		K.brush(ci, PackedVector2Array([_p(s2, 12, 312), _p(s2, 40, 300), _p(s2, 74, 310)]), 8.0, K.INK, 0.4, 0.5, 0.2)   # eyelid
		K.brush(ci, PackedVector2Array([_p(s2, 58, 352), _p(s2, 70, 372), _p(s2, 66, 396)]), 7.0, SKIN_SH)   # cheek fold
	var nose: PackedVector2Array = K.union([K.ellipse(Vector2(CX - 20, 372), 19.0, 14.0), K.ellipse(Vector2(CX + 20, 372), 19.0, 14.0), K.ellipse(Vector2(CX, 356), 12.0, 24.0)])
	K.part(ci, nose, SKIN, SKIN_SH, Color(0, 0, 0, 0), 5.0, Vector2(0, -8))
	for s3 in [-1.0, 1.0]:
		ci.draw_circle(_p(s3, 15, 376), 5.0, K.INK)
	var mouth: PackedVector2Array = K.union([K.ellipse(Vector2(CX, 428), 76.0, 36.0), K.ellipse(Vector2(CX, 446), 52.0, 26.0)])
	K.ink(ci, mouth, 7.0)
	K.fill(ci, mouth, MOUTH)
	for q in Geometry2D.intersect_polygons(K.ellipse(Vector2(CX, 458), 40.0, 16.0), mouth):
		K.fill(ci, q, TONGUE)
	for q2 in Geometry2D.intersect_polygons(PackedVector2Array([Vector2(CX - 90, 380), Vector2(CX + 90, 380), Vector2(CX + 90, 404), Vector2(CX - 90, 404)]), mouth):
		K.fill(ci, q2, BONE)                                         # upper teeth
	for s4 in [-1.0, 1.0]:
		K.part(ci, PackedVector2Array([_p(s4, 30, 398), _p(s4, 52, 398), _p(s4, 40, 438)]), BONE, BONE_SH, Color(0, 0, 0, 0), 3.0, Vector2(0, -4))   # fangs
		K.part(ci, PackedVector2Array([_p(s4, 50, 462), _p(s4, 64, 456), _p(s4, 60, 430)]), BONE, BONE_SH, Color(0, 0, 0, 0), 3.0, Vector2(0, 4))
		var stache: PackedVector2Array = K.brush_poly(PackedVector2Array([_p(s4, 8, 390), _p(s4, 48, 394), _p(s4, 92, 380), _p(s4, 116, 348)]), 24.0, 0.25, 0.6)
		K.part(ci, stache, HAIR, HAIR_SH, Color(0, 0, 0, 0), 5.0, Vector2(0, -6))


# ---------------------------------------------------------------- necklace of gold beads with a jade magatama
static func _necklace(ci: CanvasItem) -> void:
	for i in 11:
		var a: float = deg_to_rad(lerpf(20.0, 160.0, float(i) / 10.0))
		var p := Vector2(CX + cos(a) * 118.0, 466.0 + sin(a) * 74.0)
		if i == 5:
			continue
		ci.draw_circle(p, 15.0, K.INK)
		ci.draw_circle(p, 11.0, GOLD)
		ci.draw_circle(p + Vector2(-3, -3), 4.0, GOLD.lightened(0.5))
	var mg: PackedVector2Array = K.union([K.circle(Vector2(CX, 548), 22.0), K.brush_poly(PackedVector2Array([Vector2(CX - 4, 552),
		Vector2(CX - 22, 574), Vector2(CX - 6, 594)]), 30.0, 0.02, 1.0)])
	K.part(ci, mg, JADE, JADE_SH, Color(0, 0, 0, 0), 6.0, Vector2(6, -6))
	ci.draw_circle(Vector2(CX + 4, 544), 6.0, K.INK)


static func _sparks(ci: CanvasItem) -> void:
	var sp: Array = [[Vector2(150, 360), Vector2(96, 420)], [Vector2(880, 360), Vector2(936, 430)], [Vector2(300, 90), Vector2(250, 40)],
		[Vector2(730, 96), Vector2(790, 40)], [Vector2(120, 640), Vector2(60, 690)], [Vector2(910, 640), Vector2(970, 700)]]
	for i in sp.size():
		K.spark(ci, sp[i][0], sp[i][1], SPARK, 7.0, 204 + i)
