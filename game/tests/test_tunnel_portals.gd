extends TestCase
## Tuneis (T-155): perfil do arco sobe pela esquerda e desce pela direita (boca aberta, sem chapa atravessando o tunel),
## lampadas do tunel antigo nas paredes (nao no meio da pista) com pocas de luz, muros listrados das bocas maiores.

const ROUTES: Array[String] = ["kanto_2_viaduct", "kanto_3_mountain"]


func _setup(r: String) -> Array:
	var route: RouteDef = load("res://data/routes/%s.tres" % r) as RouteDef
	var track: Track = route.build_track()
	var path := TrackPath.new(track)
	var tun := Tunnel3D.new()
	tun.build(path, route.tunnels, route.scenery, null, null)
	return [route, path, tun]


func test_arch_profile_is_open_and_ordered() -> void:
	for r in ROUTES:
		var s: Array = _setup(r)
		var route: RouteDef = s[0]
		var tun: Tunnel3D = s[2]
		for t in route.tunnels:
			var a: Array = tun._arch_of(t)
			var first: Array = a[0]
			var last: Array = a[a.size() - 1]
			check_near(float(first[1]), 0.0, 0.001, r + ": comeca no pe esquerdo")
			check_near(float(last[1]), 0.0, 0.001, r + ": termina no pe direito")
			check(float(first[0]) < float(last[0]) - 6.0, r + ": pe esquerdo bem a esquerda do direito (boca aberta)")
			for k in a.size() - 1:
				var dx: float = float(a[k + 1][0]) - float(a[k][0])
				check(dx >= -0.001, r + ": o perfil so anda para a direita (sem chapa voltando pelo meio)")
		tun.free()


func test_old_tunnel_lamps_sit_on_the_walls_with_light_pools() -> void:
	var s: Array = _setup("kanto_3_mountain")
	var route: RouteDef = s[0]
	var tun: Tunnel3D = s[2]
	check(tun.narrow[0], "o 1o tunel da montanha e o antigo")
	var t: Vector2 = route.tunnels[0]
	var a: Array = tun._arch_of(t)
	var lf: float = float(a[0][0])
	var rf: float = float(a[a.size() - 1][0])
	check(tun._pools.size() > 10, "pocas de luz no tunel antigo (%d)" % tun._pools.size())
	var lamps: Array = []
	tun._arch = a                                    # o build deixa o arco do ultimo tunel
	tun._old_lamps(t, lamps)
	var n: int = 0
	for l in lamps:
		if (l[1] as Color) != Tunnel3D.OLD_LAMP:
			continue
		var z: float = t.x + 4.0 + n * Tunnel3D.OLD_LAMP_EVERY * 0.5     # mesma ordem do _old_lamps
		var wall: float = (lf + 0.24) if n % 2 == 0 else (rf - 0.24)
		var p: Vector3 = (l[0] as Transform3D).origin
		check(p.distance_to(tun._edge(z, wall, 3.4)) < 0.05, "lampada %d na parede (lado %s)" % [n, "esq" if n % 2 == 0 else "dir"])
		check(p.distance_to(tun._edge(z, (lf + rf) * 0.5, 3.4)) > 2.0, "lampada %d longe do meio da pista" % n)
		n += 1
	check(n > 10, "lampadas do tunel antigo (%d)" % n)
	tun.free()


func test_portal_walls_are_bigger() -> void:
	check(KitProps3D.PORTAL_STEPS.size() >= 3, "fila de pecas na boca")
	check(KitProps3D.PORTAL_STEPS[0] * 1.3 > 2.0, "a peca da boca passa de 2 m (a mureta tem 0,85)")
	check(KitProps3D.PORTAL_OUT > 0.0, "a face listrada fica na frente da mureta")
