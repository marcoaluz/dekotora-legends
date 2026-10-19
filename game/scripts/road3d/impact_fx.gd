class_name ImpactFx
extends Node3D
## Impacto das batidas na corrida 3D (T-141). Le os eventos da simulacao ("truck", "traffic", "event_obstacle")
## e faz so a parte visual: faiscas no ponto de contato, pedacos de cromo/lanterna/vidro voando (pool num
## MultiMesh = 1 chamada de desenho), chacoalhada do caminhao atingido e pedido de tremor da camera.
## Chave em Opcoes > Graficos ("Faiscas, pedacos e fumaca"); a qualidade grafica corta a quantidade.
## T-152: o TRANCO da simulacao (TruckSim.jolt_t, depois de bater no transito) balanca o caminhao por ~0,6 s: arfagem
## (nariz afunda e volta) na batida de frente, rolagem para o lado no raspao. Le so o estado da sim (tambem online,
## onde o jolt_t vem no snapshot); o balanco corre no relogio da tela, entao fica suave entre snapshots. Nao depende
## da chave dos efeitos (e o aviso de jogo de que a batida custou velocidade); o tremor da camera depende.

const MAX_SHARDS: int = 64
const SHARD_LIFE: float = 2.6            # s ate sumir (some encolhendo no fim)
const SHARD_COLORS: Array[Color] = [Color("#e8edf5"), Color("#e8edf5"), Color("#cfd6e2"), Color("#ff3b2f"), Color("#ffb21e"),
	Color(0.75, 0.9, 1.0)]               # cromo, cromo, aco, lanterna, pisca, vidro
const JOLT_DECAY: float = 7.0            # 1/s
const JOLT_FREQ: float = 26.0            # rad/s
const QUALITY_SCALE: Array[float] = [0.4, 0.7, 1.0]
const SWAY_TAIL: float = 0.3             # s de balanco que sobra depois do tranco (some suave)
const SWAY_FREQ: float = 15.0            # rad/s (~2,4 balancos por segundo, suspensao de caminhao)
const SWAY_PITCH: float = 0.014          # rad: arfagem na batida de frente (pivo no meio: ~8 cm nas pontas de 12 m)
const SWAY_ROLL: float = 0.03            # rad: rolagem no raspao (topo do bau anda ~10 cm)
const SWAY_FRONT_ROLL: float = 0.012     # rad: na batida de frente tambem rebola um pouco de lado
const SWAY_CAM: float = 0.22             # m: quanto a camera do jogador acompanha o balanco

var enabled: bool = true
var amount: float = 1.0                  # fracao de faiscas/pedacos pela qualidade grafica
var fx: Fx3D
var trucks: Array[TruckNode] = []
var traffic3d: Traffic3D
var _mm: MultiMesh
var _mmi: MultiMeshInstance3D
var _shards: Array[Dictionary] = []      # {pos, vel, rot, spin, ttl, ground, size, slot}
var _free: Array[int] = []
var _jolt: Dictionary = {}               # indice do caminhao -> [amplitude rad, tempo, lado]
var _shake: float = 0.0                  # tremor pedido para a camera (a cena le com take_shake)
var _lengths: Array[float] = []
var sim: RaceSim                         # velocidade dos caminhoes (os pedacos saem com o embalo do caminhao)
var _sway: Dictionary = {}               # T-152: indice do caminhao -> [s desde o inicio do tranco, lado -1/0/+1]
var _prev_jolt: Dictionary = {}          # indice -> jolt_t visto no quadro anterior (detecta tranco novo)


func setup(fx_: Fx3D, trucks_: Array[TruckNode], lengths: Array[float], traffic3d_: Traffic3D) -> void:
	fx = fx_
	trucks = trucks_
	_lengths = lengths
	traffic3d = traffic3d_
	var s: Node = get_node("/root/Settings")
	enabled = bool(s.fx_impact)
	amount = QUALITY_SCALE[clampi(int(s.quality), 0, 2)]
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.instance_count = MAX_SHARDS
	_mm.visible_instance_count = MAX_SHARDS
	var bm := BoxMesh.new()
	bm.size = Vector3(1.0, 0.12, 0.6)    # lasca chata (escala por pedaco)
	_mm.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.metallic = 0.7
	mat.roughness = 0.18
	mat.emission_enabled = true          # aparece tambem a noite (o cromo de verdade e por matcap no caminhao)
	mat.emission = Color(0.35, 0.36, 0.4)
	mat.emission_energy_multiplier = 0.9
	_mmi = MultiMeshInstance3D.new()
	_mmi.multimesh = _mm
	_mmi.material_override = mat
	_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mmi.visible = false
	add_child(_mmi)
	for k in MAX_SHARDS:
		_mm.set_instance_transform(k, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
		_free.append(k)


## Desenha uma faisca e um pedaco escondidos (embaixo do asfalto, na frente da camera) no 1o quadro: o shader
## e compilado na largada, e nao no meio da 1a batida (evita o soluco, principalmente no celular).
func warmup(hidden_pos: Vector3) -> void:
	if not enabled:
		return
	if fx != null:
		fx.sparks(hidden_pos, 1.0, 0.1)
		fx.flash(hidden_pos, 0.01)
		fx.debris(hidden_pos, Vector3.ZERO, Vector3(0.1, 0.1, 0.1), 0.3)
	var slot: int = _free.pop_back()
	_shards.append({"pos": hidden_pos, "vel": Vector3.ZERO, "rot": Basis(), "spin": Vector3.ZERO, "ttl": 0.3,
		"ground": hidden_pos.y - 5.0, "size": 0.2, "slot": slot})
	_mm.set_instance_color(slot, SHARD_COLORS[0])
	_mmi.visible = true


## Tremor da camera pedido pelas batidas desde a ultima leitura (0..1).
func take_shake() -> float:
	var s: float = _shake
	_shake = 0.0
	return s


func on_event(e: Dictionary, player: int) -> void:
	match String(e["type"]):
		"truck":
			var f: float = float(e["force"])
			var ia: int = int(e["a"])
			var ib: int = int(e["b"])
			var pa: Vector3 = zone_point(ia, String(e["zone_a"]))
			var pb: Vector3 = zone_point(ib, String(e["zone_b"]))
			var contact: Vector3 = (pa + pb) * 0.5
			if String(e["zone_a"]) in ["left", "right"]:
				_sparks(contact, f)
			else:
				_sparks_zone(ia, String(e["zone_a"]), f)
			_burst(contact, Vector3.UP, f, ia, ib, String(e["zone_a"]))
			var side: float = -1.0 if String(e["zone_a"]) == "left" else 1.0
			_kick(ia, f, side)
			_kick(ib, f, -side)
			if ia == player or ib == player:
				_shake = maxf(_shake, clampf(f / 10.0, 0.18, 1.0))
		"traffic", "event_obstacle":
			var ti: int = int(e["truck"])
			var f2: float = float(e["force"])
			var p: Vector3 = zone_point(ti, String(e["zone"]))
			_sparks_zone(ti, String(e["zone"]), f2 * 0.8)
			_burst(p, Vector3.UP, f2 * (1.2 if bool(e.get("thrown", false)) else 0.7), ti, -1, String(e["zone"]))
			_kick(ti, f2 * 0.5, -1.0 if String(e["zone"]) == "left" else 1.0)
			if ti == player:
				_shake = maxf(_shake, clampf(f2 / 14.0, 0.12, 0.8))


## Ponto da zona na carroceria do caminhao `i` (usa o comprimento real: o Canter tem 7 m).
func zone_point(i: int, zone: String) -> Vector3:
	var len: float = _lengths[i] if i < _lengths.size() else Collision.LEN
	var off := Vector3(0, 1.0, -len * 0.5)
	match zone:
		"front": off = Vector3(0, 0.9, -len + 0.4)
		"rear": off = Vector3(0, 0.9, -0.1)
		"left": off = Vector3(-1.25, 1.0, -len * 0.55)
		"right": off = Vector3(1.25, 1.0, -len * 0.55)
	return trucks[i].global_transform * off


## `follow`: as faiscas andam junto com este caminhao (soltas no mundo ficariam para tras, escondidas pelo bau).
func _sparks(pos: Vector3, force: float, follow: Node3D = null) -> void:
	if enabled and fx != null:
		fx.sparks(pos, force, amount, follow)
		if force >= 4.0:
			fx.flash(pos, clampf(1.2 + force * 0.12, 1.2, 3.2), follow)


## Batida de frente/traseira: faiscas nos DOIS cantos (a camera atras do bau so ve o que sai pelos lados).
func _sparks_zone(i: int, zone: String, force: float) -> void:
	if zone != "front" and zone != "rear":
		_sparks(zone_point(i, zone), force, trucks[i])
		return
	var c: Vector3 = zone_point(i, zone)
	var r: Vector3 = trucks[i].global_transform.basis.x * 1.15
	_sparks(c + r, force * 0.6, trucks[i])
	_sparks(c - r, force * 0.6, trucks[i])


## Pedacos voando: quantos pela forca (e pela qualidade). Saem do ponto, para cima e para o lado da zona.
func _burst(pos: Vector3, up: Vector3, force: float, ia: int, ib: int, zone: String) -> void:
	if not enabled or force < 3.0:
		return
	var n: int = clampi(int((force - 2.0) * 1.5 * amount), 2, 24)
	var node: Node3D = trucks[ia]
	var basis: Basis = node.global_transform.basis
	var out: Vector3 = basis * Vector3(-1.0 if zone == "left" else (1.0 if zone == "right" else 0.0), 0.0, -1.0 if zone == "front" else 0.0)
	var fwd: Vector3 = -basis.z
	var ground: float = node.global_position.y
	var carry: float = sim.trucks[ia].speed if sim != null and ia < sim.trucks.size() else 0.0
	for k in n:
		if _free.is_empty():
			_recycle_oldest()
		var slot: int = _free.pop_back()
		# para cima e para os lados: passa por cima/do lado do bau e cai atras (a camera do jogador ve)
		var lateral: Vector3 = basis.x * (randf_range(0.5, 1.3) * (1.0 if randf() < 0.5 else -1.0))
		var dir: Vector3 = (up * randf_range(0.9, 1.6) + out * randf_range(0.2, 0.9) + lateral).normalized()
		var v: Vector3 = dir * randf_range(6.0, 9.0 + force * 0.4) + fwd * carry * randf_range(0.55, 0.95)
		var size: float = randf_range(0.28, 0.65)
		_shards.append({"pos": pos, "vel": v, "rot": Basis.from_euler(Vector3(randf() * TAU, randf() * TAU, 0)),
			"spin": Vector3(randf_range(-14, 14), randf_range(-14, 14), randf_range(-14, 14)), "ttl": SHARD_LIFE,
			"ground": ground + 0.02, "size": size, "slot": slot})
		_mm.set_instance_color(slot, SHARD_COLORS[randi() % SHARD_COLORS.size()])
	_mmi.visible = true


func _recycle_oldest() -> void:
	var d: Dictionary = _shards.pop_front()
	_free.append(int(d["slot"]))


## Chacoalhada do caminhao `i`: balanco que some rapido (aplicado em jolt()).
func _kick(i: int, force: float, side: float) -> void:
	if not enabled or i < 0:
		return
	var amp: float = clampf(force * 0.006, 0.01, 0.07)
	var cur: Array = _jolt.get(i, [0.0, 0.0, side])
	if amp >= float(cur[0]) * exp(-JOLT_DECAY * float(cur[1])):
		_jolt[i] = [amp, 0.0, side]


## Transform do caminhao `i` com a chacoalhada (rolagem para o lado do golpe + arfagem) e o balanco do tranco (T-152).
func jolt(i: int, xf: Transform3D) -> Transform3D:
	xf = _apply_sway(i, xf)
	var j: Array = _jolt.get(i, [])
	if j.is_empty():
		return xf
	var t: float = float(j[1])
	var a: float = float(j[0]) * exp(-JOLT_DECAY * t)
	if a < 0.001:
		_jolt.erase(i)
		return xf
	var w: float = sin(t * JOLT_FREQ)
	var rot := Basis(Vector3.BACK, a * w * float(j[2])) * Basis(Vector3.RIGHT, a * 0.5 * cos(t * JOLT_FREQ * 0.8))
	return Transform3D(xf.basis * rot, xf.origin + xf.basis.y * absf(w) * a * 1.2)


## T-152: angulos do balanco do caminhao `i` agora: Vector2(arfagem, rolagem) em rad (0 se nao esta em tranco).
## Le o jolt_t da sim: subiu = tranco novo (comeca o balanco do zero).
func sway_angles(i: int) -> Vector2:
	if sim != null and i < sim.trucks.size():
		var st: TruckSim = sim.trucks[i]
		if st.jolt_t > float(_prev_jolt.get(i, 0.0)) + 0.05:
			_sway[i] = [0.0, float(st.jolt_side)]
		_prev_jolt[i] = st.jolt_t
	var w: Array = _sway.get(i, [])
	if w.is_empty():
		return Vector2.ZERO
	var e: float = float(w[0])
	var total: float = Collision.JOLT_TIME + SWAY_TAIL
	if e >= total:
		_sway.erase(i)
		return Vector2.ZERO
	var env: float = pow(1.0 - e / total, 1.5) * clampf(e / 0.05, 0.0, 1.0)   # entra rapido, some suave
	var osc: float = sin(e * SWAY_FREQ)
	var side: float = float(w[1])
	if side == 0.0:          # de frente: o nariz afunda primeiro e o corpo rebola um pouco
		return Vector2(-SWAY_PITCH * env * osc, SWAY_FRONT_ROLL * env * sin(e * SWAY_FREQ * 0.7))
	return Vector2(-SWAY_PITCH * 0.4 * env * osc, -side * SWAY_ROLL * env * osc)


## Balanco do tranco aplicado ao transform: arfagem em volta do meio do caminhao, rolagem em volta da linha no chao.
func _apply_sway(i: int, xf: Transform3D) -> Transform3D:
	var a: Vector2 = sway_angles(i)
	if a == Vector2.ZERO:
		return xf
	var len: float = _lengths[i] if i < _lengths.size() else Collision.LEN
	var pivot := Vector3(0.0, 0.0, -len * 0.5)
	var rot := Basis(Vector3.RIGHT, a.x) * Basis(Vector3.BACK, a.y)
	return xf * Transform3D(rot, pivot - rot * pivot)


## Deslocamento local da camera do jogador acompanhando o balanco (m): para o lado e para baixo. So com os efeitos ligados.
func sway_camera(i: int) -> Vector3:
	var w: Array = _sway.get(i, [])
	if not enabled or w.is_empty():
		return Vector3.ZERO
	var a: Vector2 = sway_angles(i)
	return Vector3(-a.y * 3.5, a.x * 4.0 - absf(a.x) * 2.0, 0.0) * (SWAY_CAM / 0.1)


func _process(delta: float) -> void:
	for i in _sway:
		(_sway[i] as Array)[0] = float((_sway[i] as Array)[0]) + delta
	for i in _jolt:
		(_jolt[i] as Array)[1] = float((_jolt[i] as Array)[1]) + delta
	if _shards.is_empty():
		if _mmi != null and _mmi.visible:
			_mmi.visible = false
		return
	var keep: Array[Dictionary] = []
	for d in _shards:
		var v: Vector3 = d["vel"]
		var p: Vector3 = d["pos"]
		v.y -= 16.0 * delta
		p += v * delta
		var rolling: bool = true
		if p.y < float(d["ground"]):
			p.y = float(d["ground"])
			v = Vector3(v.x * 0.55, absf(v.y) * 0.3 if absf(v.y) > 1.5 else 0.0, v.z * 0.55)
			rolling = v.length() > 0.4
		d["vel"] = v
		d["pos"] = p
		if rolling:
			d["rot"] = (d["rot"] as Basis) * Basis.from_euler((d["spin"] as Vector3) * delta)
		d["ttl"] = float(d["ttl"]) - delta
		var slot: int = d["slot"]
		if float(d["ttl"]) <= 0.0:
			_mm.set_instance_transform(slot, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
			_free.append(slot)
			continue
		var sc: float = float(d["size"]) * clampf(float(d["ttl"]) / 0.4, 0.0, 1.0)
		_mm.set_instance_transform(slot, Transform3D((d["rot"] as Basis).scaled(Vector3.ONE * sc), p))
		keep.append(d)
	_shards = keep
