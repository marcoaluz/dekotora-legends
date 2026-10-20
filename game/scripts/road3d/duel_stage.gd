class_name DuelStage
extends Node3D
## Set of the face-to-face opening (T-156), far below the race world (nothing of the road is in view): the two
## real race trucks are parked nose to nose here. Built only from cheap pieces that already exist:
##   night / dusk -> highway rest area (parking area: wet asphalt, convenience store, vending machines, sodium
##                   lamps, neon signs, an outdoor of the T-146 kit)
##   day          -> toll plaza (2x toll_gate.glb, booths, ETC/一般 lane signs, jersey barriers, pines)
## Boxes are merged by material (MeshBatch): the whole set costs ~10-14 draw calls; at most 2 omni lights.
## Stage space: trucks along X (player on -X facing +X, rival on +X facing -X), noses GAP m apart around x = 0,
## camera side = +Z. The sky, fog and sun are the route's (same time of day as the race).

const ORIGIN := Vector3(0.0, -400.0, 0.0)
const GAP: float = 4.0                  # m between the two noses
const SODIUM := Color("#ffb060")
const WARM := Color("#fff1d6")

var rest_area: bool = true
var _tod: TimeOfDay
var _batch := MeshBatch.new(1000.0, 1200.0)
var _mats: Dictionary = {}


## Builds the set for the time of day (`tod.headlights` = night or dusk -> rest area).
func build(tod: TimeOfDay) -> void:
	position = ORIGIN
	_tod = tod
	rest_area = tod.headlights
	_ground(tod)
	if rest_area:
		_rest_area()
	else:
		_toll_plaza(tod)
	_batch.commit(self)


## Transform (stage -> world) for a truck of nose offset `front` (m from its rear to its nose) on side -1 (player,
## facing +X) or +1 (rival, facing -X). TruckNode: origin = rear of the box, front = -Z.
func truck_xform(side: float, front: float) -> Transform3D:
	var yaw: float = -PI * 0.5 if side < 0.0 else PI * 0.5
	var rear_x: float = side * (GAP * 0.5 + front)
	return Transform3D(Basis(Vector3.UP, yaw), ORIGIN + Vector3(rear_x, 0.0, 0.0))


# ---------------------------------------------------------------- pieces

func _mat(col: Color, emit: float = 0.0, rough: float = 0.6) -> StandardMaterial3D:
	var k: String = "%s|%.2f|%.2f" % [col.to_html(), emit, rough]
	if not _mats.has(k):
		_mats[k] = MenuBackdrop.mat(col, emit, rough)
	return _mats[k]


func _box(size: Vector3, pos: Vector3, col: Color, emit: float = 0.0, rough: float = 0.6) -> void:
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = _mat(col, emit, rough)
	_batch.add(bm, Transform3D(Basis(), pos), 0.0)


func _glb(path: String, xf: Transform3D) -> void:
	var s: PackedScene = load(path) as PackedScene
	if s == null:
		return
	var n: Node3D = s.instantiate() as Node3D
	n.transform = xf
	add_child(n)
	for m in n.find_children("*", "GeometryInstance3D", true, false):
		(m as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _ground(tod: TimeOfDay) -> void:
	var asphalt := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(150, 150)
	asphalt.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/textures/asphalt_albedo.png") as Texture2D
	m.albedo_color = Color(0.32, 0.32, 0.34) if rest_area else Color(0.62, 0.62, 0.62)
	m.uv1_scale = Vector3(36, 36, 1)
	m.roughness = 0.34 if rest_area else 0.85          # rest area at night: wet, the lights become streaks
	m.metallic_specular = 0.7 if rest_area else 0.4
	asphalt.material_override = m
	asphalt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(asphalt)
	var field := MeshInstance3D.new()                   # far ground up to the fog (hides the edge of the set)
	var fm := PlaneMesh.new()
	fm.size = Vector2(1600, 1600)
	field.mesh = fm
	var g := StandardMaterial3D.new()
	g.albedo_texture = load("res://assets/textures/grass.png") as Texture2D
	g.uv1_scale = Vector3(220, 220, 1)
	g.albedo_color = Color(0.5, 0.56, 0.45).lerp(Color(0.9, 0.95, 0.85), tod.day_amount)
	field.material_override = g
	field.position.y = -0.04
	field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(field)
	var line := Color(0.86, 0.86, 0.8)
	for zz in [-3.6, 3.6]:                             # lane edges of the aisle where the trucks stand
		_box(Vector3(46.0, 0.012, 0.18), Vector3(0, 0.006, zz), line, 0.15, 0.5)
	_box(Vector3(0.3, 0.013, 7.0), Vector3(0, 0.007, 0), Color(0.95, 0.85, 0.2), 0.3, 0.5)   # yellow line between the noses


## Parking area at night: store with lit windows behind the trucks, vending machines, lamps, neon, outdoor.
func _rest_area() -> void:
	var dark := Color(0.09, 0.09, 0.1)
	var fz: float = -14.0                                                             # store front (behind the trucks)
	_box(Vector3(48.0, 6.4, 9.0), Vector3(0, 3.2, fz - 4.5), dark)                    # store
	_box(Vector3(30.0, 2.6, 0.12), Vector3(-5.0, 1.6, fz + 0.06), Color(0.62, 0.55, 0.42), 0.14, 0.2)   # shop window
	for x in range(-20, 12, 4):
		_box(Vector3(0.16, 2.7, 0.16), Vector3(float(x), 1.6, fz + 0.1), Color(0.15, 0.15, 0.16))
	_box(Vector3(48.2, 1.2, 0.4), Vector3(0, 5.4, fz + 0.1), Color(0.16, 0.16, 0.2))
	_box(Vector3(48.0, 0.09, 0.09), Vector3(0, 4.75, fz + 0.32), UiTheme.CYAN, 5.0)   # cyan neon strip
	var fronts: Array[Color] = [Color("#e8f2ff"), Color("#ff4060"), Color("#e8f2ff"), Color("#40a0ff"), Color("#ffe080"), Color("#e8f2ff")]
	for i in fronts.size():                                                           # vending machines
		var x: float = 12.5 + float(i) * 1.05
		_box(Vector3(1.0, 1.9, 0.9), Vector3(x, 0.95, fz + 0.5), Color(0.75, 0.76, 0.8), 0.0, 0.4)
		_box(Vector3(0.8, 1.3, 0.05), Vector3(x, 1.15, fz + 0.97), fronts[i], 2.2, 0.3)
	for i in 7:                                                                       # stalls of the truck parking (camera side)
		_box(Vector3(0.14, 0.012, 9.0), Vector3(-21.0 + float(i) * 7.0, 0.006, 10.0), Color(0.85, 0.85, 0.8), 0.15, 0.5)
	for p in [Vector3(-12.0, 0, -8.0), Vector3(12.0, 0, -8.0), Vector3(-10.0, 0, 15.0), Vector3(14.0, 0, 15.0)]:
		_lamp(p, SODIUM, 6.0)
	var tower := Vector3(21.0, 0, -10.0)                                              # tall sign with 爆走
	_box(Vector3(0.5, 12.0, 0.5), tower + Vector3(0, 6.0, 0), Color(0.25, 0.25, 0.28))
	_box(Vector3(4.6, 2.2, 0.5), tower + Vector3(0, 12.0, 0), Color(0.08, 0.06, 0.1))
	for e in [Vector3(0, 1.12, 0), Vector3(0, -1.12, 0)]:                            # thin pink frame
		_box(Vector3(4.7, 0.1, 0.1), tower + Vector3(0, 12.0, 0.28) + e, UiTheme.PINK, 4.0)
	for e2 in [Vector3(2.32, 0, 0), Vector3(-2.32, 0, 0)]:
		_box(Vector3(0.1, 2.3, 0.1), tower + Vector3(0, 12.0, 0.28) + e2, UiTheme.PINK, 4.0)
	MenuBackdrop.neon(self, "爆走", tower + Vector3(0, 12.0, 0.32), UiTheme.GOLD, 0.02, 96, 0.0)
	MenuBackdrop.neon(self, "ドライブイン 街道", Vector3(-7.0, 7.2, fz + 0.4), UiTheme.PINK, 0.03, 96, 0.0)
	MenuBackdrop.neon(self, "24H", Vector3(12.0, 7.2, fz + 0.4), UiTheme.CYAN, 0.026, 72, 0.0)
	_billboard(Vector3(-30.0, 0.0, -10.0), 2)
	for i in 11:                                                                      # barrier far behind the camera
		_glb_jersey(Vector3(-17.5 + float(i) * 3.5, 0.0, 30.0))
	MenuBackdrop.omni(self, Vector3(0.0, 7.5, 5.0), SODIUM, 1.5, 24.0)               # sodium light over the trucks
	MenuBackdrop.omni(self, Vector3(-4.0, 3.0, fz + 3.0), WARM, 1.0, 14.0)           # shop light from behind


## Toll plaza by day: two canopies of the track's toll gate behind the trucks, booths, lane signs, pines.
func _toll_plaza(tod: TimeOfDay) -> void:
	var path: String = "res://assets/scenery/toll_gate.glb"
	for x in [-9.6, 9.6]:
		_glb(path, Transform3D(Basis(), Vector3(x, 0.0, -17.0)))
	var concrete := Color(0.78, 0.77, 0.74)
	for i in 5:                                                                       # booths with lit windows
		var x: float = -16.0 + float(i) * 8.0
		_box(Vector3(1.6, 0.25, 9.0), Vector3(x, 0.12, -17.0), Color(0.95, 0.75, 0.1), 0.0, 0.7)   # island kerb
		_box(Vector3(1.3, 2.4, 2.4), Vector3(x, 1.45, -17.0), concrete, 0.0, 0.7)
		_box(Vector3(1.32, 0.9, 1.6), Vector3(x, 1.9, -17.0), Color(0.45, 0.6, 0.7), 0.25, 0.2)
		_box(Vector3(0.14, 1.1, 0.14), Vector3(x + 0.9, 0.55, -12.8), Color(0.2, 0.2, 0.2))
		_box(Vector3(0.1, 0.1, 3.0), Vector3(x + 0.9, 1.05, -11.3), Color(0.95, 0.95, 0.95), 0.2)   # gate arm
	for i in 4:                                                                       # lane signs under the canopy: ETC / 一般
		var x2: float = -12.0 + float(i) * 8.0
		var etc: bool = i % 2 == 0
		_box(Vector3(2.0, 0.8, 0.12), Vector3(x2, 4.75, -13.5), Color("#6a2fa0") if etc else Color("#17703c"), 0.0, 0.5)
		_day_text("ETC" if etc else "一般", Vector3(x2, 4.75, -13.42), 0.011)
	for px in [-6.6, 6.6]:                                                            # green gantry sign above the plaza
		_box(Vector3(0.3, 9.2, 0.3), Vector3(px, 4.6, -12.6), Color(0.55, 0.57, 0.6), 0.0, 0.5)
	_box(Vector3(13.6, 2.0, 0.16), Vector3(0.0, 8.3, -12.5), Color("#17703c"), 0.0, 0.5)
	_box(Vector3(13.8, 2.2, 0.1), Vector3(0.0, 8.3, -12.6), Color(0.92, 0.92, 0.92), 0.0, 0.5)   # white border
	_day_text("料金所  TOLL GATE", Vector3(0.0, 8.3, -12.4), 0.016)
	for i in 11:
		_glb_jersey(Vector3(-17.5 + float(i) * 3.5, 0.0, 30.0))
	for p in [Vector3(-12.0, 0, 8.5), Vector3(12.0, 0, 8.5)]:
		_lamp(p, Color(0.9, 0.95, 1.0), 1.2)
	var pine: String = "res://assets/scenery/tree_pine.glb"
	for i in 12:                                                                      # tree line closing the view
		var ang: float = float(i) / 12.0 * TAU
		var r: float = 38.0 + float(i % 3) * 6.0
		_glb(pine if i % 2 == 0 else "res://assets/scenery/tree_round.glb",
			Transform3D(Basis(Vector3.UP, ang).scaled(Vector3.ONE * (1.8 + 0.3 * float(i % 3))), Vector3(sin(ang) * r, 0.0, cos(ang) * r)))
	_billboard(Vector3(26.0, 0.0, -24.0), 1)


## White painted text of a road sign (daylight: no glow, no outline).
func _day_text(text: String, pos: Vector3, px: float) -> void:
	var t: Label3D = MenuBackdrop.neon(self, text, pos, Color.WHITE, px, 96, 0.0)
	t.modulate = Color(0.95, 0.95, 0.95)
	t.outline_size = 0


func _lamp(p: Vector3, col: Color, emit: float) -> void:
	var s: float = -signf(p.x)
	_box(Vector3(0.22, 8.0, 0.22), p + Vector3(0, 4.0, 0), Color(0.3, 0.3, 0.32))
	_box(Vector3(1.4, 0.14, 0.14), p + Vector3(0.6 * s, 7.9, 0), Color(0.3, 0.3, 0.32))
	_box(Vector3(0.7, 0.12, 0.35), p + Vector3(1.2 * s, 7.8, 0), col, emit)


func _glb_jersey(p: Vector3) -> void:
	_batch.add(RoadsideKit.mesh("barrier_jersey", _tod), Transform3D(Basis(Vector3.UP, PI * 0.5), p), 0.0)


## Outdoor of the T-146 kit with one of its (fictional, swappable) arts.
func _billboard(p: Vector3, art: int) -> void:
	_batch.add(RoadsideKit.mesh("billboard_tall", _tod), Transform3D(Basis(), p), 0.0)
	var tex: Texture2D = RoadsideKit.art(art)
	if tex == null:
		return
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = RoadsideKit.BILL_ART
	q.mesh = qm
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.85, 0.85, 0.85) if rest_area else Color.WHITE
	q.material_override = m
	q.position = p + Vector3(0.0, float(RoadsideKit.BILL_LEG["billboard_tall"]) + RoadsideKit.BILL_ART.y * 0.5, 0.02)
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(q)
