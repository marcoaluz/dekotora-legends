extends TestCase
## T-266: imagens "Praia" do Marco no grupo Wallpapers: 3 murais (um desenho por lado), 2 traseiras e 1 teto.
## O corte para a proporcao de cada bau segue o rosto (`focus`) e quase nao estica (`keep`); sem os campos a janela
## continua central (pinturas antigas iguais).

const MURALS: Array[String] = ["wall_praia_raposa_dourada", "wall_praia_raposa_tropical", "wall_praia_amigas"]
const REARS: Array[String] = ["wallrear_praia_verao", "wallrear_praia_amigas"]
const ROOFS: Array[String] = ["wallroof_praia_raposa"]
## Proporcoes reais das faces (w/h) nos baus fechados (truck/sockets/*.json).
const MURAL_RECTS: Array[float] = [2.565, 2.824, 3.206, 3.347, 3.551, 3.663, 3.966, 4.114, 4.468, 4.759, 5.412, 5.794, 6.132, 7.054]
const REAR_RECTS: Array[float] = [1.071, 1.151, 1.213, 1.263]
const ROOF_RECTS: Array[float] = [0.182, 0.22, 0.25, 0.276, 0.298, 0.373, 0.406, 0.466]


func _slot_rects(slot: String) -> Array[float]:
	return MURAL_RECTS if slot == "mural" else (REAR_RECTS if slot == "rear_paint" else ROOF_RECTS)


func test_pieces_in_wallpapers_with_origin() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	var c := AccessoryCatalog.get_instance()
	for list in [[MURALS, "mural"], [REARS, "rear_paint"], [ROOFS, "roof_paint"]]:
		for id in list[0]:
			var e: Dictionary = c.entry(id)
			var d: PartDef = gs.part(id)
			check(not e.is_empty() and d != null, "%s no catalogo e .tres" % id)
			if d == null:
				continue
			check_eq(String(d.slot), list[1], "%s: encaixe" % id)
			check_eq(PaintFit.group_of(e), "wallpapers", "%s: grupo Wallpapers" % id)
			check(String(e.get("license", "")).begins_with("arte do Marco"), "%s: origem = arte do Marco" % id)
			check(d.price > 0 and d.fame > 0 and d.weight_kg == 0.0, "%s: preco/fama, peso 0" % id)
			check(Tr.t(d.display_key) != d.display_key, "%s: nome pt-BR" % id)
	for id in MURALS:
		var e: Dictionary = c.entry(id)
		check(e["paint"].has("R") and e["paint"].has("L"), "%s: os 2 lados" % id)
		check(String(e["paint"]["R"][0]["tex"]) != String(e["paint"]["L"][0]["tex"]), "%s: um desenho por lado" % id)


func test_textures_compressed_with_mipmaps() -> void:
	for d in ["mural", "rear", "roof"]:
		var dir: String = "res://assets/vehicles/dekotora/paint_wall/%s/" % d
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".png.import"):
				continue
			var txt: String = FileAccess.get_file_as_string(dir + f)
			check(txt.contains("compress/mode=2") and txt.contains("mipmaps/generate=true"), "%s: VRAM + mipmaps" % f)


## Peso do APK: murais com 512 px de altura (mesma densidade dos murais da T-232) e o ETC2 (o que vai no APK Android)
## das 18 texturas da praia abaixo de 5 MB (medido: 4,42 MB; antes, com 2048 x 684, 7,16 MB).
func test_apk_weight_budget() -> void:
	var c := AccessoryCatalog.get_instance()
	for id in MURALS:
		for side in ["R", "L"]:
			var px: Array = c.entry(id)["paint"][side][0]["px"]
			check(int(px[1]) <= 512 and int(px[0]) <= 1536, "%s %s: no maximo 1536 x 512 (tem %s)" % [id, side, px])
	var total: int = 0
	for d in ["mural", "rear", "roof"]:
		var dir: String = "res://assets/vehicles/dekotora/paint_wall/%s/" % d
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".png.import"):
				continue
			var cfg := ConfigFile.new()
			cfg.load(dir + f)
			var p: String = String(cfg.get_value("remap", "path.etc2", ""))
			if p != "" and FileAccess.file_exists(p):
				total += FileAccess.open(p, FileAccess.READ).get_length()
	check(total > 0 and total < 5 * 1000 * 1000, "ETC2 da praia < 5 MB (tem %.2f MB)" % (total / 1.0e6))


func test_crop_keeps_the_face_and_barely_stretches() -> void:
	var c := AccessoryCatalog.get_instance()
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	for id in MURALS + REARS + ROOFS:
		var e: Dictionary = c.entry(id)
		var d: PartDef = gs.part(id)
		var slot: String = String(d.slot) if d != null else ""
		for side in (e["paint"] as Dictionary):
			var art: Dictionary = e["paint"][side][0]
			var f: Vector2 = Vector2(float(art["focus"][0]), float(art["focus"][1]))
			for ra in _slot_rects(slot):
				var w: Rect2 = PaintFit.art_window(art, ra)
				var shown: float = float(art["aspect"]) * w.size.x / w.size.y
				check(ra / shown <= 1.07 and ra / shown >= 0.95, "%s %s em %.2f: estica %.2f" % [id, side, ra, ra / shown])
				var m: Vector2 = w.size * 0.15                       # o rosto fica longe da borda do corte
				check(Rect2(w.position + m, w.size - 2.0 * m).has_point(f) or _edge_ok(w, f),
						"%s %s em %.2f: rosto dentro do corte" % [id, side, ra])


## O rosto pode ficar perto da borda so quando a janela ja encostou na borda da arte (nao da para centralizar mais).
func _edge_ok(w: Rect2, f: Vector2) -> bool:
	return w.has_point(f) and (w.position.x <= 0.0001 or w.end.x >= 0.9999 or w.position.y <= 0.0001 or w.end.y >= 0.9999)


func test_default_window_is_unchanged() -> void:
	for pair in [[4.0, 4.1], [4.0, 2.6], [4.0, 6.1], [1.25, 1.07], [0.25, 0.3]]:
		var a: Rect2 = PaintFit.uv_window(pair[0], pair[1])
		var b: Rect2 = PaintFit.art_window({"aspect": pair[0]}, pair[1])
		check(a.is_equal_approx(b), "sem focus/keep = janela de antes")
		check(absf(a.get_center().x - 0.5) < 0.001 and absf(a.get_center().y - 0.5) < 0.001, "janela central")
	var w: Rect2 = PaintFit.uv_window(3.0, 2.5, Vector2(0.9, 0.5), 0.45)
	check(w.end.x >= 0.9999 and w.position.x > 0.0, "foco a direita: corta a esquerda")
	w = PaintFit.uv_window(3.0, 7.0, Vector2(0.5, 0.1), 0.45)
	check(w.position.y <= 0.0001 and is_equal_approx(w.size.y, 0.45), "carreta: guarda 45%% da altura a partir do topo")
