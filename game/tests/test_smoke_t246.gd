extends TestCase
## T-246: olhando para tras na corrida, um quadrado cinza cobria o para-brisa do caminhao do jogador. Era a fumaca do
## motor ferido: saia de um ponto fixo (0; 2,4; -11) que no bau curto fica solto no ar na frente do vidro, e cada
## baforada era um quadrado cinza chapado. Agora sai da grade de cada caminhao (abaixo do vidro) e e uma baforada macia.

const PF := preload("res://tests/test_part_fit.gd")


func _truck(body: String, cab: String) -> TruckNode:
	var t := TruckNode.new()
	t.body_kind = body
	t.cab_kind = cab if cab != "" and cab != "x" else CabCatalog.DEFAULT
	t._ready()                                   # fora da arvore: monta o modelo na hora
	return t


func test_engine_smoke_comes_out_of_the_grille_of_every_truck() -> void:
	var n: int = 0
	for m in PF.models():
		var cab: Dictionary = (m["data"]["measure"] as Dictionary).get("cab", {})
		if not cab.has("windshield"):
			continue
		var t: TruckNode = _truck(String(m["body"]), String(m["cab"]))
		var tag: String = String(m["stem"])
		var glass: AABB = TruckSockets.aabb_of(cab["windshield"])
		var o: Vector3 = Fx3D.smoke_origin(t)
		check(o.is_equal_approx(t.smoke_origin()), "%s: Fx3D usa o ponto do caminhao" % tag)
		check(o.y < glass.position.y - 0.3, "%s: fumaca abaixo do para-brisa (y=%.2f, vidro %.2f)" % [tag, o.y, glass.position.y])
		var front: float = float(cab["front_z"])
		check(o.z > front and o.z < front + 0.6, "%s: fumaca na frente da cabine (z=%.2f, frente %.2f)" % [tag, o.z, front])
		check(absf(o.x) < 0.01, "%s: no meio" % tag)
		t.free()
		n += 1
	check(n >= 23, "%d caminhoes conferidos" % n)


func test_nothing_opaque_floats_in_front_of_the_windshield() -> void:
	# nenhuma malha do caminhao inteira dentro do "ar" na frente do vidro (ate 3 m), fora o proprio vidro
	var n: int = 0
	for m in PF.models():
		var cab: Dictionary = (m["data"]["measure"] as Dictionary).get("cab", {})
		if not cab.has("windshield"):
			continue
		var t: TruckNode = _truck(String(m["body"]), String(m["cab"]))
		var glass: AABB = TruckSockets.aabb_of(cab["windshield"])
		var air := AABB(Vector3(glass.position.x + 0.1, glass.position.y + 0.1, glass.position.z - 3.0),
				Vector3(glass.size.x - 0.2, glass.size.y - 0.2, 3.0 + glass.size.z * 0.5))
		for g in t.find_children("*", "GeometryInstance3D", true, false):
			var gi: GeometryInstance3D = g as GeometryInstance3D
			if String(gi.name).contains("glass") or not gi.visible:
				continue
			var b: AABB = PartFit.rel_xform(gi, t) * gi.get_aabb()
			check(not air.encloses(b), "%s: %s solto na frente do para-brisa" % [String(m["stem"]), gi.name])
		t.free()
		n += 1
	check(n >= 23, "%d caminhoes conferidos" % n)


func test_smoke_puff_is_soft_and_round() -> void:
	var mat: StandardMaterial3D = Fx3D.make_smoke_material()
	check(mat.albedo_texture != null, "baforada com textura (nao um quadrado chapado)")
	check(mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "transparente")
	check(mat.vertex_color_use_as_albedo, "a cor da particula (entra e some) vale")
	var gt: GradientTexture2D = mat.albedo_texture as GradientTexture2D
	check(gt != null and gt.fill == GradientTexture2D.FILL_RADIAL, "gradiente redondo")
	if gt != null:                              # (sem tela a textura nao vira imagem: confere o gradiente)
		check(gt.gradient.sample(1.0).a < 0.05, "borda transparente")
		check(gt.gradient.sample(0.0).a > 0.5, "miolo visivel")
		check(gt.fill_to.distance_to(gt.fill_from) <= 0.5 + 0.001, "some antes da borda do quadrado")
