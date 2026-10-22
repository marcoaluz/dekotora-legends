class_name Trains3D
extends Node3D
## Desenha os trens do RailTraffic (T-154): um MultiMesh por modelo (2 locomotivas, 8 vagoes, bonde) = uma chamada de
## desenho por modelo A VISTA (o MultiMesh sem copia fica invisivel), +1 do brilho dos farois a noite. Vagao a mais de
## CUT_M da camera nao entra. T-193: locomotiva e vagoes novos (RailTraffic.LOCOS / WAGON_POOL).
## A AABB do MultiMesh e recalculada a cada quadro: sem trem na tela, o Godot nem desenha.

const MODELS: Array[String] = ["train_loco", "train_loco_b", "train_wagon_a", "train_wagon_b", "train_wagon_c",
	"train_wagon_log", "train_wagon_flat", "train_wagon_semi", "train_wagon_box", "train_wagon_box_b", "train_lrt"]
const MAX_PER_MODEL: int = 12
const CUT_M: float = 700.0
const HALF_LEN := {"train_loco": 9.0, "train_loco_b": 9.45, "train_lrt": 17.5}

var traffic: RailTraffic
var tod: TimeOfDay
var visible_cars: int = 0
var _mm: Dictionary = {}           # modelo -> MultiMeshInstance3D
var _glow: MultiMeshInstance3D


func setup(traffic_: RailTraffic, tod_: TimeOfDay) -> void:
	traffic = traffic_
	tod = tod_
	for m in MODELS:
		var mesh: ArrayMesh = RailKit.mesh(m, tod)
		if mesh == null:
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = MAX_PER_MODEL
		mm.visible_instance_count = 0
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_mm[m] = mi
	if tod.headlights:
		_glow = _make_glow()


func refresh(cam: Vector3) -> void:
	var by_model: Dictionary = {}
	var glows: Array[Transform3D] = []
	visible_cars = 0
	for it in traffic.car_list():
		var xf: Transform3D = it[1]
		if xf.origin.distance_to(cam) > CUT_M:
			continue
		var model: String = it[0]
		if not by_model.has(model):
			by_model[model] = []
		if (by_model[model] as Array).size() < MAX_PER_MODEL:
			by_model[model].append(xf)
			visible_cars += 1
		if _glow != null and int(it[3]) == 0:            # farol na frente do 1o vagao
			var front: Vector3 = xf.origin - xf.basis.z * (float(HALF_LEN.get(model, 9.0)) + 0.3) + Vector3.UP * 1.9
			var to_cam: Vector3 = (cam - front).normalized()
			glows.append(Transform3D(Basis.looking_at(-to_cam, Vector3.UP).scaled(Vector3.ONE * 3.2), front + to_cam * 0.5))
	for m in _mm:
		var mi: MultiMeshInstance3D = _mm[m]
		var list: Array = by_model.get(m, [])
		_fill(mi, list, 22.0)
	if _glow != null:
		_fill(_glow, glows, 4.0)


func _fill(mi: MultiMeshInstance3D, list: Array, pad: float) -> void:
	var mm: MultiMesh = mi.multimesh
	if list.size() > mm.instance_count:
		list = list.slice(0, mm.instance_count)
	mm.visible_instance_count = list.size()
	mi.visible = not list.is_empty()
	if list.is_empty():
		return
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for k in list.size():
		var xf: Transform3D = list[k]
		mm.set_instance_transform(k, xf)
		lo = lo.min(xf.origin)
		hi = hi.max(xf.origin)
	mm.custom_aabb = AABB(lo - Vector3.ONE * pad, hi - lo + Vector3.ONE * pad * 2.0)


## Brilho dos farois: quadrado aditivo virado para a camera (a noite).
func _make_glow() -> MultiMeshInstance3D:
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.95, 0.8, 1.0))
	g.set_color(1, Color(1.0, 0.85, 0.6, 0.0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	var m := StandardMaterial3D.new()
	m.albedo_texture = t
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.no_depth_test = false
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	q.material = m
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = q
	mm.instance_count = 8
	mm.visible_instance_count = 0
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi
