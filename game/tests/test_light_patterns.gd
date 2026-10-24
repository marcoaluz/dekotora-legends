extends TestCase
## Luzes com padroes de pisca (ATB-2): as luzinhas do modelo ganham o material animado e obedecem padrao e nivel.


func _truck() -> TruckNode:
	var t := TruckNode.new()
	t._ready()                              # fora da arvore: monta o modelo na hora (o teste e sincrono)
	return t


func test_marker_lamps_get_the_animated_material() -> void:
	var t := _truck()
	check(t._lamp_mats.size() >= 2, "as luzinhas do modelo trocaram de material (%d tipos)" % t._lamp_mats.size())
	for key in t._lamp_mats:
		check(LightPatterns.ANIMATED.has(String(key)), "so cores de marcacao piscam: " + String(key))
		check(not (t._lamp_mats[key] as ShaderMaterial).shader == null, "tem shader")
	check(not t._lamp_mats.has("lamp_red") and not t._lamp_mats.has("lamp_white"), "lanterna e farol ficam fixos")
	t.free()


func test_pattern_and_level_reach_the_shader() -> void:
	var t := _truck()
	t.set_light_pattern("sequential")
	for m in t._lamp_mats.values():
		check_eq(int((m as ShaderMaterial).get_shader_parameter("pattern")), 1, "padrao sequencial = 1")
	t.set_light_pattern("nao_existe")
	for m in t._lamp_mats.values():
		check_eq(int((m as ShaderMaterial).get_shader_parameter("pattern")), 0, "padrao invalido volta para fixas")
	t.set_lights_on(false)
	var off: float = float((t._lamp_mats.values()[0] as ShaderMaterial).get_shader_parameter("level"))
	t.set_lights_on(true, true)
	var day: float = float((t._lamp_mats.values()[0] as ShaderMaterial).get_shader_parameter("level"))
	t.set_lights_on(true)
	var night: float = float((t._lamp_mats.values()[0] as ShaderMaterial).get_shader_parameter("level"))
	check(off < day and day < night, "apagadas < previa de dia < noite (%.2f < %.2f < %.2f)" % [off, day, night])
	t.free()


func test_part_lamps_also_follow_the_pattern() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	gs.new_profile()
	var t := _truck()
	var defs: Array[PartDef] = []
	for id in ["deck_led_box", "visor_lamp_row", "skirt_light_bar"]:
		var d: PartDef = gs.part(id)
		if d != null:
			defs.append(d)
	t.apply_loadout(defs)
	t.set_light_pattern("breathing")
	var found: int = 0
	for mi in t.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		for s in m.mesh.get_surface_count():
			if m.get_surface_override_material(s) is ShaderMaterial:
				found += 1
	check(found >= 3, "as pecas tambem usam o material animado (%d superficies)" % found)
	t.free()
	gs.new_profile()


func test_patterns_list_matches_translations() -> void:
	for id in LightPatterns.IDS:
		check(Tr.t(LightPatterns.label_key(id)) != LightPatterns.label_key(id), "traducao de " + id)
