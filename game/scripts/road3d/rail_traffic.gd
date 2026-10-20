class_name RailTraffic
extends RefCounted
## Quando e onde passam os trens (T-154). So visual: nao toca na simulacao nem na rede; relogio proprio (dt da tela).
## Determinístico: mesma semente + mesma sequencia de (dt, z do jogador, velocidade) => mesmos trens nas mesmas posicoes.
## - Linha paralela: de tempos em tempos (FIRST_PASS s depois da largada, depois a cada 22-40 s) um trem e marcado para
##   CRUZAR COM O JOGADOR daqui a MEET_S segundos, no mesmo sentido (o caminhao ultrapassa ou e ultrapassado) ou no
##   contrario. Cada sentido usa a via da esquerda (mao inglesa, como no Japao).
## - Viaduto que cruza a pista: o trem e marcado uma vez por corrida para estar em cima da pista quando o jogador passar.

enum Type { FREIGHT, LRT }

const FIRST_PASS: float = 3.0
const MEET_S: float = 7.0
const GAP_MIN: float = 22.0
const GAP_MAX: float = 40.0
const MAX_TRAINS: int = 3
const SPEED := {Type.FREIGHT: 21.0, Type.LRT: 18.0}
const LOCO_LEN: float = 18.0
const WAGON_LEN: float = 20.4
const LRT_LEN: float = 35.0
const COUPLER: float = 0.6
const WAGONS: Array[String] = ["train_wagon_a", "train_wagon_b", "train_wagon_c", "train_wagon_a", "train_wagon_c",
	"train_wagon_b", "train_wagon_a", "train_wagon_b"]
const DESPAWN_M: float = 900.0


class Train:
	extends RefCounted
	var line: int = 0
	var type: int = Type.FREIGHT
	var dir: float = 1.0            # +1 = s crescente
	var track: float = -1.0         # via (-1 / +1 em relacao ao eixo)
	var center: float = 0.0         # s do centro do trem
	var speed: float = 20.0
	var models: Array[String] = []
	var lens: PackedFloat32Array = PackedFloat32Array()
	var length: float = 0.0
	var age: float = 0.0


var lines: Array[RailLine] = []
var trains: Array[Train] = []
var time: float = 0.0
var main_type: int = Type.FREIGHT
var force_type: int = -1          # depuracao/capturas: --train=freight|lrt
var force_dir: float = 0.0        # --train-dir=same|opposite (+1 / -1)
var passes: int = 0
var _rng := RandomNumberGenerator.new()
var _next_pass: float = FIRST_PASS
var _crossed: Dictionary = {}


func _init(lines_: Array[RailLine], seed_: int, main_type_: int = Type.FREIGHT) -> void:
	lines = lines_
	_rng.seed = seed_
	main_type = main_type_


static func make_train(type: int) -> Train:
	var t := Train.new()
	t.type = type
	t.speed = float(SPEED[type])
	if type == Type.LRT:                                   # 2 bondes engatados
		t.models.assign(["train_lrt", "train_lrt"])
		t.lens = PackedFloat32Array([LRT_LEN, LRT_LEN])
	else:
		t.models.assign(["train_loco"] + WAGONS)
		t.lens.append(LOCO_LEN)
		for w in WAGONS:
			t.lens.append(WAGON_LEN)
	var total: float = 0.0
	for l in t.lens:
		total += l
	t.length = total + COUPLER * float(t.lens.size() - 1)
	return t


func update(dt: float, player_z: float, player_speed: float) -> void:
	time += dt
	for t in trains:
		t.center += t.dir * t.speed * dt
		t.age += dt
	var keep: Array[Train] = []
	for t in trains:
		var l: RailLine = lines[t.line]
		var gone: bool = t.center - t.length > l.length() + 50.0 or t.center + t.length < -50.0
		var far: bool = t.age > 20.0 and absf(l.z_at(t.center) - player_z) > DESPAWN_M
		if not gone and not far:
			keep.append(t)
	trains = keep
	_crossings(player_z, player_speed)
	if time >= _next_pass:
		_parallel_pass(player_z, player_speed)


## Trem na paralela marcado para cruzar com o jogador daqui a MEET_S s.
func _parallel_pass(player_z: float, player_speed: float) -> void:
	var meet_z: float = player_z + player_speed * MEET_S
	var li: int = -1
	for i in lines.size():
		var l: RailLine = lines[i]
		if l.kind == RailLine.Kind.PARALLEL and meet_z >= l.z0 + 60.0 and meet_z <= l.z1 - 60.0:
			li = i
	if li < 0 or trains.size() >= MAX_TRAINS:
		_next_pass = time + 3.0                           # ninguem por perto: tenta de novo daqui a pouco
		return
	var type: int = main_type if passes == 0 or _rng.randf() < 0.7 else (Type.LRT if main_type == Type.FREIGHT else Type.FREIGHT)
	var dir: float = 1.0 if _rng.randf() < 0.5 else -1.0
	if force_type >= 0:
		type = force_type
	if force_dir != 0.0:
		dir = force_dir
	var t: Train = make_train(type)
	t.line = li
	t.dir = dir
	t.track = -dir                                         # anda pela via da esquerda
	if dir > 0.0 and player_speed < 12.0:
		t.speed = 22.0                                     # jogador parado/devagar: o trem e que ultrapassa
	var l: RailLine = lines[li]
	t.center = l.s_at_z(meet_z) - dir * t.speed * MEET_S
	trains.append(t)
	passes += 1
	_next_pass = time + _rng.randf_range(GAP_MIN, GAP_MAX)


## Viaduto sobre a pista: o meio do trem fica em cima da pista quando o jogador chega (uma vez por corrida).
func _crossings(player_z: float, player_speed: float) -> void:
	for i in lines.size():
		var l: RailLine = lines[i]
		if l.kind != RailLine.Kind.CROSSING or _crossed.has(i):
			continue
		var d: float = l.z_cross - player_z
		if d < 40.0 or d > 420.0:
			continue
		var arrive: float = clampf(d / maxf(player_speed, 1.0), 4.0, 12.0)
		if d / maxf(player_speed, 1.0) > 12.0 and d > 160.0:
			continue                                       # ainda longe/devagar: espera chegar mais perto
		_crossed[i] = true
		var t: Train = make_train(Type.FREIGHT if force_type < 0 else force_type)
		t.line = i
		t.dir = 1.0 if _rng.randf() < 0.5 else -1.0
		t.track = -t.dir
		t.speed = 18.0
		t.center = l.length() * 0.5 - t.dir * t.speed * arrive
		trains.append(t)


## Cada vagao: [modelo, Transform3D]. Os vagoes saem da frente (head) para tras.
func car_list() -> Array:
	var out: Array = []
	for t in trains:
		var l: RailLine = lines[t.line]
		var s: float = t.center + t.dir * t.length * 0.5          # frente do trem
		for k in t.models.size():
			var c: float = s - t.dir * t.lens[k] * 0.5
			if c > -2.0 and c < l.length() + 2.0:                # fora da linha = dentro do tunel / fora do mapa
				out.append([t.models[k], l.car_transform(c, t.lens[k], t.dir, t.track), t, k])
			s -= t.dir * (t.lens[k] + COUPLER)
	return out
