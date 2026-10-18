extends TestCase
## Bau premium (T-136): o bau medio (base) das 4 cabines usa a chapa ondulada com mapas gravados (normal, oclusao,
## rugosidade/metalico) do atlas compartilhado tex_box_*; o mural continua trocavel e por caminhao (cor do rival),
## mas ganha as normais/oclusao da chapa. Os outros modelos (leve, longo, Canter, carreta) seguem com o bau antigo.

const TEX_DIR := "res://assets/vehicles/dekotora/textures/"


func _truck(body: String, cab: String) -> TruckNode:
	var t := TruckNode.new()
	t.body_kind = body
	t.cab_kind = cab
	t._ready()                                  # fora da arvore: monta o modelo na hora
	return t


## Materiais ativos (depois do TruckNode) por nome de recurso.
func _mats(t: TruckNode) -> Dictionary:
	var out: Dictionary = {}
	for mi in t.model.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		for s in m.mesh.get_surface_count():
			var mat: StandardMaterial3D = m.get_active_material(s) as StandardMaterial3D
			if mat != null:
				out[mat.resource_name] = mat
	return out


func _path(tex: Texture2D) -> String:
	return tex.resource_path if tex != null else ""


func test_shared_box_maps_exist() -> void:
	for f in ["tex_box_albedo", "tex_box_orm", "tex_box_nrm", "tex_box_mural_orm", "tex_box_mural_nrm"]:
		check(ResourceLoader.exists(TEX_DIR + f + ".png"), "falta " + f)


func test_premium_box_on_every_cab() -> void:
	for cab in CabCatalog.IDS:
		var t: TruckNode = _truck("base", cab)
		var mats: Dictionary = _mats(t)
		for key in ["paint_white_box", "box_metal"]:
			check(mats.has(key), "%s: sem material %s" % [cab, key])
			if not mats.has(key):
				continue
			var m: StandardMaterial3D = mats[key]
			check_eq(_path(m.albedo_texture), TEX_DIR + "tex_box_albedo.png", cab + " " + key + " cor")
			check_eq(_path(m.normal_texture), TEX_DIR + "tex_box_nrm.png", cab + " " + key + " normal")
			check_eq(_path(m.roughness_texture), TEX_DIR + "tex_box_orm.png", cab + " " + key + " ORM")
			check(m.ao_enabled and _path(m.ao_texture) == TEX_DIR + "tex_box_orm.png", cab + " " + key + " oclusao")
			check(m.normal_enabled, cab + " " + key + " normal ligado")
		t.free()


func test_mural_keeps_png_and_gets_baked_maps() -> void:
	var a: TruckNode = _truck("base", "chata")
	var b: TruckNode = _truck("base", "jac")
	var ma: StandardMaterial3D = _mats(a)["mural"]
	var mb: StandardMaterial3D = _mats(b)["mural"]
	check(ma != mb, "mural e um material por caminhao (cor do rival)")
	check_eq(_path(ma.albedo_texture), TruckNode.MURAL_PATH, "cor = PNG trocavel do mural")
	check_eq(_path(ma.normal_texture), TEX_DIR + "tex_box_mural_nrm.png", "normais da chapa no mural")
	check_eq(_path(ma.ao_texture), TEX_DIR + "tex_box_mural_orm.png", "oclusao da chapa no mural")
	a.set_paint_color(Color(0.9, 0.2, 0.3))
	check(ma.albedo_color != mb.albedo_color, "tingir um rival nao mexe no mural do outro")
	a.free()
	b.free()


func test_other_bodies_keep_classic_box() -> void:
	for body in ["leve", "longo", "canter"]:
		var t: TruckNode = _truck(body, "chata")
		check(not _mats(t).has("box_metal"), body + ": bau antigo (premium so no medio)")
		t.free()
