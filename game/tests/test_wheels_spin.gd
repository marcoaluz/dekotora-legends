extends TestCase
## Rodas girando de verdade (T-133): em todos os modelos (3 baus x 4 cabines, Canter e carreta) a peca de roda escolhida
## (calota ou roda da loja) aparece em TODAS as rodas externas (frente, tras, cada eixo do rodado duplo, os dois lados),
## presa no pneu: a rotacao dela muda entre dois quadros com velocidade > 0 (angulo = v * dt / raio DA roda), nao muda
## parado, e nas dianteiras acompanha o esterçamento. Na garagem as rodas giram so na vista da roda.

const WHEEL_PARTS: Array[String] = ["hub_chrome", "jac_steel_rims", "fumi_sport_rims"]
const DT: float = 1.0 / 60.0


func _models() -> Array:
	var out: Array = []
	for body in ["base", "leve", "longo"]:
		for cab in CabCatalog.IDS:
			out.append([body, cab])
	out.append(["canter", "chata"])
	out.append(["carreta", "chata"])
	return out


func _truck(body: String, cab: String, part_id: String) -> TruckNode:
	var t := TruckNode.new()
	t.body_kind = body
	t.cab_kind = cab
	t._ready()                                  # fora da arvore: monta o modelo na hora (teste sincrono)
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	var defs: Array[PartDef] = [gs.part(part_id) as PartDef]
	t.apply_loadout(defs)
	return t


## Transform do no em relacao a raiz do caminhao (sem arvore de cena).
func _rel(n: Node, top: Node) -> Transform3D:
	var tr := Transform3D.IDENTITY
	while n != null and n != top and n is Node3D:
		tr = (n as Node3D).transform * tr
		n = n.get_parent()
	return tr


func _angle(a: Basis, b: Basis) -> float:
	return (a.inverse() * b).get_rotation_quaternion().get_angle()


func _parts(t: TruckNode) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for n in t.model.find_children("acc_*", "Node3D", true, false):
		if n.has_meta("wheel_part"):
			out.append(n as Node3D)
	return out


func _axles(body: String) -> int:
	return int({"leve": 1, "canter": 1, "longo": 3, "carreta": 5}.get(body, 2))   # eixos traseiros de cada modelo


func test_wheel_part_on_every_outer_wheel() -> void:
	var models: Array = _models()
	for i in models.size():
		var body: String = models[i][0]
		var cab: String = models[i][1]
		var pid: String = WHEEL_PARTS[i % WHEEL_PARTS.size()]
		var t: TruckNode = _truck(body, cab, pid)
		var tag: String = "%s/%s/%s" % [body, cab, pid]
		var parts: Array[Node3D] = _parts(t)
		var expect: int = 2 + 2 * _axles(body)
		check_eq(parts.size(), expect, tag + ": uma peca por roda externa")
		var front: int = 0
		var left: int = 0
		for p in parts:
			var host: Node = p.get_parent()
			check(String(host.name).begins_with("wheel_"), "%s: peca presa no pneu (%s)" % [tag, host.name])
			front += 1 if TruckWheels.is_front(host) else 0
			left += 1 if (host as Node3D).position.x < 0.0 else 0
			check((p.transform.basis.determinant() < 0.0) == ((host as Node3D).position.x < 0.0), tag + ": lado esquerdo espelhado")
		check_eq(front, 2, tag + ": duas dianteiras")
		check_eq(left, expect / 2, tag + ": metade de cada lado")
		for mn in ["MOUNT_WHEEL_FRONT_FACE_R", "MOUNT_WHEEL_FRONT_FACE_L", "MOUNT_WHEEL_REAR_FACE_R"]:
			var m: Node = t.model.find_child(mn, true, false)
			check(m != null and m.get_child_count() == 0, "%s: nada preso no ponto fixo %s" % [tag, mn])
		# em repouso a peca fica onde o ponto FACE manda (frente e 1o eixo de tras)
		for pair in [["wheel_f_R", "MOUNT_WHEEL_FRONT_FACE_R"], ["wheel_f_L", "MOUNT_WHEEL_FRONT_FACE_L"]]:
			for p in parts:
				if String(p.get_parent().name) == pair[0]:
					var mp: Vector3 = _rel(t.model.find_child(pair[1], true, false), t.model).origin
					check(_rel(p, t.model).origin.distance_to(mp) < 0.002, "%s: peca de %s no encaixe de fabrica" % [tag, pair[0]])
		t.free()


func test_wheel_part_spins_with_tire_and_radius() -> void:
	for mdl in [["base", "chata"], ["base", "jac"], ["leve", "americana"], ["longo", "curta"], ["canter", "chata"]]:
		var t: TruckNode = _truck(mdl[0], mdl[1], "hub_chrome")
		var tag: String = "%s/%s" % mdl
		var parts: Array[Node3D] = _parts(t)
		var before: Array[Basis] = []
		for p in parts:
			before.append(_rel(p, t.model).basis)
		t.animate(0.0, DT)
		for k in parts.size():
			check(_angle(before[k], _rel(parts[k], t.model).basis) < 1e-5, "%s: parado, a calota nao gira" % tag)
		var v: float = 12.0
		t.animate(v, DT)
		for k in parts.size():
			var host: Node3D = parts[k].get_parent() as Node3D
			var r: float = t.wheels.radii[t.wheels.wheels.find(host)]
			var got: float = _angle(before[k], _rel(parts[k], t.model).basis)
			check(got > 0.05, "%s: a calota de %s muda de rotacao entre dois quadros (%.3f rad)" % [tag, host.name, got])
			check_near(got, v * DT / r, 0.002, "%s: giro de %s = v*dt/raio (raio %.2f)" % [tag, host.name, r])
			# o eixo do giro e o eixo da roda (X do caminhao): o centro da calota nao sai do lugar
			var axis: Vector3 = (before[k].inverse() * _rel(parts[k], t.model).basis).get_rotation_quaternion().get_axis()
			check(absf((before[k] * axis).normalized().x) > 0.99, "%s: gira no eixo da roda" % tag)
		t.free()


func test_canter_and_big_front_wheels_use_their_own_radius() -> void:
	var t: TruckNode = _truck("canter", "chata", "hub_chrome")
	var w: TruckWheels = t.wheels
	for i in w.wheels.size():
		var r: float = w.radii[i]
		var expect: float = 0.45 if TruckWheels.is_front(w.wheels[i]) else 0.43
		check_near(r, expect, 0.01, "Canter: raio de %s" % w.wheels[i].name)
	t.free()
	var j: TruckNode = _truck("base", "jac", "hub_chrome")
	for i in j.wheels.wheels.size():
		var expect2: float = 0.55 if TruckWheels.is_front(j.wheels.wheels[i]) else 0.52
		check_near(j.wheels.radii[i], expect2, 0.01, "JAC: raio de %s" % j.wheels.wheels[i].name)
	j.free()


func test_front_wheel_parts_steer() -> void:
	var t: TruckNode = _truck("base", "chata", "jac_steel_rims")
	var parts: Array[Node3D] = _parts(t)
	var before: Array[Vector3] = []
	for p in parts:
		before.append(_rel(p, t.model).basis.x.normalized())
	t.animate(0.0, DT, 1.0)                     # so esterça, sem andar
	for k in parts.size():
		var host: Node = parts[k].get_parent()
		var now: Vector3 = _rel(parts[k], t.model).basis.x.normalized()
		var yaw: float = absf(before[k].signed_angle_to(now, Vector3.UP))
		if TruckWheels.is_front(host):
			check_near(yaw, TruckWheels.STEER_MAX, 0.01, "dianteira %s esterça com a calota" % host.name)
		else:
			check(yaw < 1e-4, "traseira %s nao esterça" % host.name)
	t.free()


func test_garage_spins_only_in_wheel_view() -> void:
	var stage := GarageStage.new()
	var t: TruckNode = _truck("base", "chata", "hub_chrome")
	stage.truck = t
	var p: Node3D = _parts(t)[0]
	var b0: Basis = _rel(p, t.model).basis
	stage.focus_view("side")
	stage.spin_wheels(0.5)
	check(_angle(b0, _rel(p, t.model).basis) < 1e-5, "garagem, vista lateral: rodas paradas")
	stage.focus_view("wheel")
	stage.spin_wheels(0.5)
	var a: float = _angle(b0, _rel(p, t.model).basis)
	check(a > 0.2 and a < 2.0, "garagem, vista da roda: gira devagar (%.2f rad em 0,5 s)" % a)
	stage.focus_slot("hubcaps")
	check_eq(stage.view, "wheel", "escolher calotas leva a vista da roda")
	stage.focus_default()
	check_eq(stage.view, "default", "voltar a vista geral para o giro")
	t.free()
	stage.free()
