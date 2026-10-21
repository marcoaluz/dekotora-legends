class_name BrakeFx
extends Node3D
## Freada forte (T-144): fumaca branca/cinza saindo das rodas traseiras e marcas escuras no asfalto.
## Le so o estado da simulacao (TruckSim.hard_braking / brake_intensity). Barato para o celular:
##  - fumaca: 1 CPUParticles3D por caminhao (2 pontos de emissao = as rodas de tras), criado na 1a freada e
##    escondido quando a fumaca some (sem chamada de desenho parado). Puff redondo de gradiente (sem textura em disco).
##  - marcas: UM MultiMesh com MARK_COUNT tracos reaproveitados em anel (1 chamada de desenho).
## Tudo junto: no maximo 1 + caminhoes freando ao mesmo tempo (<= 5 chamadas).
## T-141: o mesmo puff sai dos pneus de quem foi EMPURRADO de faixa por outro caminhao (TruckSim.shove_t; ATB:
## "fumaca/poeira branca nas rodas de quem raspa"). Chave "Faiscas, pedacos e fumaca" em Opcoes > Graficos;
## a qualidade grafica corta a quantidade de puffs (baixa 14, media 24, alta 34).

const SMOKE_AMOUNT: Array[int] = [14, 24, 34]

const MARK_COUNT: int = 360
const MARK_EVERY: float = 0.07           # s entre tracos
const MARK_WIDTH: float = 0.34           # m
const WHEEL_X: float = 1.02              # m do centro ate a roda de fora
const MAX_DIST: float = 160.0            # m da camera: mais longe nao solta fumaca nem marca
const SMOKE_LIFE: float = 1.8

var _smoke: Dictionary = {}              # indice -> CPUParticles3D
var _smoke_off_t: Dictionary = {}        # indice -> s desde que parou (esconde depois de SMOKE_LIFE)
var _marks: MultiMeshInstance3D
var _mm: MultiMesh
var _next: int = 0
var _mark_t: Dictionary = {}             # indice -> s ate o proximo traco
var _last_wheel: Dictionary = {}         # indice -> [pos roda esq., pos roda dir.]
var _puff_mat: StandardMaterial3D
var _puff_mesh: QuadMesh
var enabled: bool = true
var _amount: int = 26


func _ready() -> void:
	var st: Node = get_node("/root/Settings")
	enabled = bool(st.fx_impact)
	_amount = SMOKE_AMOUNT[clampi(int(st.quality), 0, 2)]
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.instance_count = MARK_COUNT
	_mm.visible_instance_count = 0
	var pm := PlaneMesh.new()
	pm.size = Vector2(MARK_WIDTH, 1.0)
	_mm.mesh = pm
	_marks = MultiMeshInstance3D.new()
	_marks.multimesh = _mm
	_marks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.03, 0.03, 0.035, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_marks.material_override = mat
	_marks.visible = false
	add_child(_marks)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	_puff_mat = StandardMaterial3D.new()
	_puff_mat.albedo_texture = tex
	_puff_mat.vertex_color_use_as_albedo = true
	_puff_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_puff_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_puff_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	# T-185: without keep_scale the billboard ignores each particle's scale, so the particles not born yet (scale 0,
	# default color = opaque black) were drawn full size at the emitter: the black disc left on the road after a
	# short brake. With it, scale_amount and the curve work; the 1 m quad keeps the old average size (~2 m).
	_puff_mat.billboard_keep_scale = true
	_puff_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_puff_mesh = QuadMesh.new()
	_puff_mesh.size = Vector2(1.0, 1.0)


## Compila os shaders da fumaca e das marcas na largada (desenhados escondidos embaixo do asfalto, ver ImpactFx.warmup).
func warmup(hidden_pos: Vector3) -> void:
	if not enabled:
		return
	var p: CPUParticles3D = _make_smoke()
	p.global_position = hidden_pos
	p.emitting = true
	_add_mark(hidden_pos, hidden_pos + Vector3(0, 0, 1))
	get_tree().create_timer(0.4).timeout.connect(func() -> void:
		p.queue_free()
		if _next == 1 and _mm.visible_instance_count == 1:      # ninguem freou ainda: apaga a marca de aquecimento
			_next = 0
			_mm.visible_instance_count = 0
			_marks.visible = false)


## `night`: a fumaca fica mais escura/acinzentada (sem brilhar no escuro).
func update_truck(index: int, node: Node3D, t: TruckSim, cam_pos: Vector3, dt: float, night: bool) -> void:
	if not enabled:
		return
	var near: bool = node.global_position.distance_to(cam_pos) < MAX_DIST
	var braking: bool = t.hard_braking and t.brake_intensity > 0.05
	var on: bool = near and (braking or t.shove_t > 0.0)
	var rear: float = -t.length * TrackPath.REAR_AXLE
	var p: CPUParticles3D = _smoke.get(index)
	if on and p == null:
		p = _make_smoke()
		_smoke[index] = p
	if p != null:
		if on:
			p.visible = true
			p.emitting = true
			_smoke_off_t[index] = 0.0
			var k: float = t.brake_intensity if braking else 0.55      # empurrao: puff medio
			var shade: float = 0.82 if night else 0.95
			p.color = Color(shade, shade, shade * 1.02, 0.55 + 0.45 * k)
			p.scale_amount_min = 1.1 + 1.0 * k
			p.scale_amount_max = 2.2 + 2.6 * k
			p.global_transform = node.global_transform * Transform3D(Basis.IDENTITY, Vector3(0, 0.9, rear))   # alto: o puff nao corta no asfalto
		else:
			p.emitting = false
			var off: float = float(_smoke_off_t.get(index, 0.0)) + dt
			_smoke_off_t[index] = off
			if off > SMOKE_LIFE and p.visible:
				p.visible = false
	_update_marks(index, node, rear, on and t.speed > 4.0, dt)


func _make_smoke() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.mesh = _puff_mesh
	p.material_override = _puff_mat
	p.amount = _amount
	p.lifetime = SMOKE_LIFE
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
	p.emission_points = PackedVector3Array([Vector3(-WHEEL_X, 0, 0), Vector3(WHEEL_X, 0, 0)])
	p.direction = Vector3(0, 0.5, 1.0)            # para tras (+Z local) e para cima
	p.spread = 35.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 3.2
	p.gravity = Vector3(0, 0.9, 0)
	p.damping_min = 1.5
	p.damping_max = 3.0
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.35))
	curve.add_point(Vector2(1.0, 1.0))
	p.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.9))
	ramp.set_color(1, Color(1, 1, 1, 0.0))
	p.color_ramp = ramp
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p


## Tracos escuros entre a posicao anterior e a atual de cada roda traseira (so freando forte e andando).
func _update_marks(index: int, node: Node3D, rear: float, on: bool, dt: float) -> void:
	var wl: Vector3 = node.global_transform * Vector3(-WHEEL_X, 0.035, rear)
	var wr: Vector3 = node.global_transform * Vector3(WHEEL_X, 0.035, rear)
	if not on:
		_last_wheel.erase(index)
		return
	var tl: float = float(_mark_t.get(index, 0.0)) - dt
	if _last_wheel.has(index) and tl <= 0.0:
		var prev: Array = _last_wheel[index]
		_add_mark(prev[0], wl)
		_add_mark(prev[1], wr)
		tl = MARK_EVERY
		_last_wheel[index] = [wl, wr]
	elif not _last_wheel.has(index):
		_last_wheel[index] = [wl, wr]
		tl = MARK_EVERY
	_mark_t[index] = tl


func _add_mark(a: Vector3, b: Vector3) -> void:
	var d: Vector3 = b - a
	var len: float = d.length()
	if len < 0.05 or len > 8.0:
		return
	var z: Vector3 = d / len
	var x: Vector3 = Vector3.UP.cross(z).normalized()
	var y: Vector3 = z.cross(x).normalized()
	var basis := Basis(x * 1.0, y, z * len)
	_mm.set_instance_transform(_next, Transform3D(basis, (a + b) * 0.5))
	_next = (_next + 1) % MARK_COUNT
	_mm.visible_instance_count = mini(_mm.visible_instance_count + 1, MARK_COUNT)
	_marks.visible = true
