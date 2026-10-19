extends TestCase
## Mural aceso a noite (T-155): o material do mural (bau e tampas da graneleira) ganha emissao com a propria arte;
## a forca vem da hora do dia (TimeOfDay.mural_glow) e e 0 de dia (nada muda).


func _truck(body: String) -> TruckNode:
	var t := TruckNode.new()
	t.body_kind = body
	t.cab_kind = "chata"
	t._ready()                                  # fora da arvore: monta o modelo na hora
	return t


func _mural_mat(t: TruckNode) -> StandardMaterial3D:
	for mi in t.model.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		for s in m.mesh.get_surface_count():
			var mat: StandardMaterial3D = m.get_active_material(s) as StandardMaterial3D
			if mat != null and mat.resource_name == "mural":
				return mat
	return null


func test_presets_dose_the_glow() -> void:
	var night: TimeOfDay = TimeOfDay.by_id(&"night")
	var dusk: TimeOfDay = TimeOfDay.by_id(&"dusk")
	var day: TimeOfDay = TimeOfDay.by_id(&"day")
	check_eq(day.mural_glow, 0.0, "de dia o mural nao muda")
	check(dusk.mural_glow > 0.0 and dusk.mural_glow < night.mural_glow, "fim de tarde mais fraco que a noite")
	check(night.mural_glow <= 1.0, "noite sem estourar")
	check(MuralGlow.TUNNEL > 0.0, "tunel de dia acende o mural")


func test_profile_brighter_near_the_skirt() -> void:
	check(MuralGlow.profile(1.0) > MuralGlow.profile(0.5), "embaixo (saia) mais claro que o meio")
	check(MuralGlow.profile(0.0) > MuralGlow.profile(0.5), "topo (fileira do teto) mais claro que o meio")
	check(MuralGlow.profile(0.5) > 0.3, "meio ainda aceso")


func test_mural_material_glows_by_level() -> void:
	for body in ["base", "graneleira", "leve"]:
		var t: TruckNode = _truck(body)
		var mat: StandardMaterial3D = _mural_mat(t)
		check(mat != null, body + ": tem mural")
		if mat == null:
			t.free()
			continue
		check(mat.emission_enabled, body + ": emissao ligada desde o inicio (sem recompilar no meio da corrida)")
		check(mat.emission_texture != null, body + ": textura de emissao")
		check_eq(mat.emission_operator, BaseMaterial3D.EMISSION_OP_MULTIPLY, body + ": cor x textura")
		check_eq(mat.emission_energy_multiplier, 0.0, body + ": sem chamar, nada muda (garagem e menu)")
		t.set_mural_glow(0.8)
		check_near(mat.emission_energy_multiplier, 0.8, 0.001, body + ": noite")
		t.set_paint_color(Color(1.0, 0.2, 0.2))
		check(mat.emission.g < mat.emission.r, body + ": luz tingida com a cor do rival")
		t.set_mural_glow(0.0)
		check_eq(mat.emission_energy_multiplier, 0.0, body + ": dia")
		t.free()


func test_emission_texture_is_shared() -> void:
	var a: TruckNode = _truck("base")
	var b: TruckNode = _truck("base")
	var ma: StandardMaterial3D = _mural_mat(a)
	var mb: StandardMaterial3D = _mural_mat(b)
	check(ma != mb, "material do mural e um por caminhao (cor do rival)")
	check(ma.emission_texture == mb.emission_texture, "textura de emissao compartilhada")
	check_eq(ma.emission_texture.get_size(), Vector2(MuralGlow.SIZE), "textura pequena (512x128)")
	a.free()
	b.free()
