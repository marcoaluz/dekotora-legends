class_name MenuBgHighway
extends MenuBackdrop
## Opcao B do fundo da tela inicial (T-138): o caminhao do jogador rodando numa via expressa a noite em camera
## lenta. O caminhao fica parado no mundo; a estrada (shader com faixas tracejadas e manchas de luz de sodio),
## as muretas, os postes e os farois da pista contraria correm para tras. As rodas giram na mesma velocidade e
## uma luz de sodio passa pelo caminhao a cada poste. ~15 chamadas de desenho alem do caminhao, 3 luzes.

const SLOWMO_SPEED: float = 7.0          # m/s na tela (~100 km/h em 1/4 da velocidade)
const POST_GAP: float = 40.0
const SODIUM := Color("#ffb060")
const ROAD_SHADER := """
shader_type spatial;
uniform float scroll = 0.0;
uniform int kind = 0;                 // 0 = asfalto com faixas, 1 = mureta de concreto
uniform float center_x = 0.0;         // eixo da pista (as faixas sao medidas a partir dele)
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float z = wp.z - scroll;
	float pz = (fract(z / 40.0 + 0.5) - 0.5) * 40.0;
	if (kind == 0) {
		vec3 col = texture(tex, vec2(wp.x, z) * 0.12).rgb * 0.32;
		float ax = abs(wp.x - center_x);
		float dash = step(fract(z / 20.0), 0.4);
		float lane = (1.0 - smoothstep(0.07, 0.09, abs(ax - 1.75))) * dash * step(ax, 3.0);
		float edge = 1.0 - smoothstep(0.07, 0.09, abs(ax - 5.4));
		col = mix(col, vec3(0.82, 0.82, 0.78), max(lane, edge) * 0.9);
		float pool = exp(-pz * pz / 70.0) * exp(-pow(ax - 4.5, 2.0) / 22.0);
		ALBEDO = col;
		ROUGHNESS = 0.34;
		SPECULAR = 0.7;
		EMISSION = vec3(1.0, 0.58, 0.22) * pool * 0.22;
	} else {
		float seam = smoothstep(0.96, 0.98, fract(z / 4.0));
		vec3 col = vec3(0.42, 0.41, 0.4) * (1.0 - seam * 0.6);
		float pool = exp(-pz * pz / 60.0);
		ALBEDO = col;
		ROUGHNESS = 0.8;
		EMISSION = vec3(1.0, 0.58, 0.22) * pool * 0.12;
	}
}
"""

var _scroll: float = 0.0
var _mats: Array[ShaderMaterial] = []
var _posts: Node3D
var _oncoming: Node3D
var _tail: Node3D
var _lights: Array[OmniLight3D] = []


func _build_scene() -> void:
	WorldEnv.create(self, false, TimeOfDay.by_id(&"night"))
	# o caminhao (x = 0) vai na faixa da esquerda; a camera anda na faixa da direita, a frente dele
	_strip(Vector3(3.5, 0, -100), Vector3(14.0, 0.02, 420), 0, 3.5)       # nossa pista (3 faixas)
	_strip(Vector3(-12.0, 0, -100), Vector3(13.0, 0.02, 420), 0, -12.0)   # pista contraria
	_strip(Vector3(-4.5, 0.45, -100), Vector3(2.0, 0.9, 420), 1)      # canteiro central
	_strip(Vector3(10.0, 0.45, -100), Vector3(0.5, 0.9, 420), 1)      # mureta da borda
	_posts = Node3D.new()
	add_child(_posts)
	_build_posts()
	_oncoming = Node3D.new()
	add_child(_oncoming)
	_tail = Node3D.new()
	add_child(_tail)
	_build_traffic()
	_skyline()
	for x in [8.5, -3.5]:                          # luz do poste que passa pelo caminhao
		_lights.append(omni(self, Vector3(x, 7.5, 0), SODIUM, 0.0, 18.0))


func hero_frame() -> Dictionary:
	return {"target": Vector3(-0.6, 1.7, -6.2), "dist": 15.0, "az": 33.0, "el": 4.0, "shift": 0.2}


func _strip(pos: Vector3, size: Vector3, kind: int, center_x: float = 0.0) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = ROAD_SHADER
	m.shader = sh
	m.set_shader_parameter("kind", kind)
	m.set_shader_parameter("center_x", center_x)
	m.set_shader_parameter("tex", load("res://assets/textures/asphalt_albedo.png"))
	mi.material_override = m
	mi.position = pos - Vector3(0, size.y * 0.5, 0) if kind == 0 else pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_mats.append(m)


## Postes de sodio dos dois lados (3 MultiMesh: haste, braco e lampada), repetidos a cada POST_GAP.
func _build_posts() -> void:
	var xs: Array[float] = [10.6, -4.5]
	var parts: Array = [[Vector3(0.2, 8.5, 0.2), Vector3(0, 4.25, 0), Color(0.32, 0.32, 0.34), 0.0],
			[Vector3(2.2, 0.14, 0.14), Vector3(-1.0, 8.4, 0), Color(0.32, 0.32, 0.34), 0.0],
			[Vector3(0.8, 0.12, 0.35), Vector3(-1.9, 8.3, 0), SODIUM, 6.0]]
	for p in parts:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var bm := BoxMesh.new()
		bm.size = p[0]
		bm.material = mat(p[2], float(p[3]), 0.5)
		mm.mesh = bm
		mm.instance_count = 12 * xs.size()
		var i: int = 0
		for x in xs:
			var off: Vector3 = p[1]
			off.x *= signf(x)                       # braco aponta para a pista
			for k in 12:
				mm.set_instance_transform(i, Transform3D(Basis(), Vector3(x, 0, -float(k) * POST_GAP + 80.0) + off))
				i += 1
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_posts.add_child(mmi)


## A camera fica na frente do caminhao olhando para tras: os carros da pista contraria se afastam rapido
## mostrando as lanternas vermelhas; um carro mais lento na faixa da direita fica para tras mostrando os farois.
func _build_traffic() -> void:
	for k in 7:
		var z: float = -float(k) * 55.0 + 60.0
		var x: float = -10.25 - 3.5 * float(k % 2)
		for s in [-0.75, 0.75]:
			box(_oncoming, Vector3(0.3, 0.14, 0.1), Vector3(x + s, 0.8, z), Color(1.0, 0.08, 0.1), 7.0)
	for s in [-0.7, 0.7]:
		box(_tail, Vector3(0.3, 0.16, 0.08), Vector3(3.5 + s, 0.7, -60.1), Color(1.0, 0.95, 0.85), 8.0)
	box(_tail, Vector3(1.75, 1.3, 4.2), Vector3(3.5, 0.75, -58.0), Color(0.05, 0.05, 0.06))


## Silhueta de predios longe, com luz de aviacao vermelha (estatica: fica no horizonte).
func _skyline() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 9:
		var h: float = rng.randf_range(18.0, 55.0)
		var pos := Vector3(-140.0 - rng.randf_range(0, 40), h * 0.5, -260.0 + i * 45.0)
		box(self, Vector3(18, h, 16), pos, Color(0.04, 0.045, 0.07))
		box(self, Vector3(0.6, 0.6, 0.6), pos + Vector3(8.0, h * 0.5 + 0.4, 0), Color(1, 0.15, 0.1), 6.0)


func _animate(delta: float) -> void:
	_scroll += SLOWMO_SPEED * delta
	for m in _mats:
		m.set_shader_parameter("scroll", _scroll)
	_posts.position.z = fmod(_scroll, POST_GAP)
	_oncoming.position.z = fmod(_scroll * 2.6, 385.0)            # vem de frente: mais rapido
	_tail.position.z = fmod(_scroll * 0.35, 280.0)              # carro mais lento sendo ultrapassado (some na neblina)
	if truck != null:
		truck.animate(SLOWMO_SPEED, delta)
		truck.position.y = sin(_t * 9.0) * 0.012                # suspensao
	var mid: float = float(TruckNode.LENGTH_DELTA.get(truck.body_kind, 0.0)) * -0.5 - 6.0 if truck != null else -6.0
	for l in _lights:                            # o poste mais perto do meio do caminhao ilumina a cabine e o bau
		var zl: float = fmod(_scroll, POST_GAP) + 80.0
		zl -= roundf((zl - mid) / POST_GAP) * POST_GAP
		l.position.z = zl
		l.light_energy = 1.3 * exp(-pow((zl - mid) / 14.0, 2.0))
