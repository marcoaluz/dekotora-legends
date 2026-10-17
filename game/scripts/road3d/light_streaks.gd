class_name LightStreaks
extends Node3D
## Luzes "de cinema" baratas para a noite e o fim de tarde (cada uma com chave em Opcoes > Graficos):
## - reflexo falso do asfalto molhado: faixa esticada e borrada da cor de cada lanterna e de cada poste,
##   desenhada no chao (quad aditivo), sem reflexo de tela (o Compatibility nao tem SSR);
## - rastro das lanternas traseiras dos rivais e do transito (fita curta aditiva, mais longa quanto mais rapido);
## - chuva opcional (particulas em volta da camera).
## Tudo em dois MultiMesh (dinamico e estatico): 2 draw calls.

const SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() {
	float along = 1.0 - UV.y;                      // forte na luz, some na ponta
	float across = 1.0 - abs(UV.x - 0.5) * 2.0;
	ALBEDO = tint.rgb * tint.a * pow(along, 1.6) * smoothstep(0.0, 0.7, across);
}
"""
const TAIL := Color(1.0, 0.12, 0.08)

var path: TrackPath
var _dyn: MultiMesh
var _mat: ShaderMaterial
var _trucks: Array[TruckNode] = []
var _player: int = 0
var _traffic: Traffic3D
var _speeds: Callable                    # func(i: int) -> float (velocidade do caminhao i)
var _reflect: bool = false
var _trails: bool = false
var _rain: CPUParticles3D


func setup(path_: TrackPath, tod: TimeOfDay, trucks: Array[TruckNode], player: int, traffic: Traffic3D,
		speeds: Callable, cam: Camera3D) -> void:
	path = path_
	_trucks = trucks
	_player = player
	_traffic = traffic
	_speeds = speeds
	var s: Node = get_node("/root/Settings")
	var lit: bool = tod.headlights                                      # noite / fim de tarde
	_reflect = lit and bool(s.fx_reflections)
	_trails = lit and bool(s.fx_trails)
	_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	_mat.shader = sh
	if _reflect or _trails:
		_dyn = _make_mm(maxi((trucks.size() + traffic.car_count()) * 4, 1))
	if _reflect and tod.lamps_on:
		_static_lamps(tod)
	if bool(s.fx_rain):
		_make_rain(cam)


func _make_mm(count: int) -> MultiMesh:
	var plane := PlaneMesh.new()                                         # 1x1 deitado; UV.y vai ao longo de Z
	plane.size = Vector2.ONE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = plane
	mm.instance_count = count
	mm.visible_instance_count = 0
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = _mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mm


## Quad deitado que comeca em `start` e vai `length` m na direcao `dir` (horizontal), com largura `width`.
func _quad(start: Vector3, dir: Vector3, length: float, width: float) -> Transform3D:
	var z_axis: Vector3 = dir.normalized()                               # UV.y = 0 no inicio (lado +Z do plano)
	var x_axis: Vector3 = Vector3.UP.cross(z_axis).normalized()
	var b := Basis(x_axis * width, Vector3.UP, z_axis * length)
	return Transform3D(b, start + z_axis * length * 0.5)


func _static_lamps(tod: TimeOfDay) -> void:
	var items: Array = []
	for o in path.track.objects:
		if String(o["kind"]) != "lamp_post":
			continue
		var z: float = float(o["z"])
		var p: Vector3 = path.world_point(z, float(o["x"]) * 0.62, 0.05)
		items.append(_quad(p, -path.forward_at(z), 11.0, 1.3))           # estica para tras (para a camera)
	if items.is_empty():
		return
	var mm: MultiMesh = _make_mm(items.size())
	mm.visible_instance_count = -1
	var c := Color(1.0, 0.58, 0.22, 0.55 * tod.pool_energy / 0.75)
	for i in items.size():
		mm.set_instance_transform(i, items[i])
		mm.set_instance_color(i, c)


func _process(_dt: float) -> void:
	if _dyn == null:
		return
	var n: int = 0
	for k in _trucks.size():                                         # o jogador tem reflexo, mas nao rastro
		n = _vehicle(n, _trucks[k].global_transform, 1.0, 0.95, float(_speeds.call(k)), k != _player)
	for t in _traffic.car_transforms():
		n = _vehicle(n, t, 0.62, 0.75, 20.0, true)
	_dyn.visible_instance_count = n


## Reflexo + rastro das duas lanternas de um veiculo (origem do no = traseira, frente = -Z).
func _vehicle(n: int, xf: Transform3D, half_w: float, height: float, speed: float, trail: bool) -> int:
	var back: Vector3 = xf.basis.z.normalized()                          # para tras
	back.y = 0.0
	for side in [-1.0, 1.0]:
		var lamp: Vector3 = xf * Vector3(side * half_w, height, 0.05)
		if _reflect and n < _dyn.instance_count:
			var floor_p := Vector3(lamp.x, xf.origin.y + 0.04, lamp.z)
			_dyn.set_instance_transform(n, _quad(floor_p, back, 6.5, 0.55))
			_dyn.set_instance_color(n, Color(TAIL.r, TAIL.g, TAIL.b, 0.55))
			n += 1
		if _trails and trail and n < _dyn.instance_count:
			_dyn.set_instance_transform(n, _quad(lamp, back, clampf(speed * 0.11, 0.3, 4.5), 0.16))
			_dyn.set_instance_color(n, Color(TAIL.r, TAIL.g, TAIL.b, 0.9))
			n += 1
	return n


func _make_rain(cam: Camera3D) -> void:
	_rain = CPUParticles3D.new()
	_rain.amount = 420
	_rain.lifetime = 0.7
	_rain.local_coords = false
	_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_rain.emission_box_extents = Vector3(18, 1, 26)
	_rain.direction = Vector3(0, -1, 0.15)
	_rain.spread = 4.0
	_rain.initial_velocity_min = 28.0
	_rain.initial_velocity_max = 34.0
	_rain.gravity = Vector3(0, -9.8, 0)
	var q := QuadMesh.new()
	q.size = Vector2(0.03, 0.9)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.8, 0.85, 1.0, 0.28)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.billboard_keep_scale = true
	q.material = m
	_rain.mesh = q
	_rain.position = Vector3(0, 9, -14)
	cam.add_child(_rain)
