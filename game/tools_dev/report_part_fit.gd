extends SceneTree
## Relatorio de encaixe (T-211; lote 2 na T-231; pinturas na T-232; lote 5 na T-234): docs/REPORT_ENCAIXE.md com a matriz caminhao x peca (deque e viseira), a escala
## usada, os problemas de projeto dos encaixes e as zonas protegidas de cada caminhao.
## Uso (raiz do projeto): godot --headless --path game -s res://tools_dev/report_part_fit.gd

const OUT := "res://../docs/REPORT_ENCAIXE.md"
const SLOTS: Array = ["andon", "visor"]
const LOT2: Array = ["rear_bumper", "rocket_r", "box_light_r", "box_light_l", "box_light_top"]   # T-231


var _lot2_ok: int = 0
var _lot2_n: int = 0


## T-231: matriz caminhao x lote 2 (11 para-choques traseiros, 7 foguetes, 3 contornos do bau).
func _lot2(c: AccessoryCatalog, lines: PackedStringArray, fails: PackedStringArray) -> void:
	var ids: Array[String] = PartFit.socket_parts(c, LOT2)
	lines.append("## Matriz caminhão × lote 2 (T-231: 11 para-choques traseiros, 7 foguetes, 3 contornos do baú)")
	lines.append("")
	lines.append("| Caminhão | Para-choques OK | Escala | Foguetes OK | Faixa / comprimento do foguete | Contornos OK | Contorno (m: dir/esq/teto) | Falhas |")
	lines.append("| --- | --- | --- | --- | --- | --- | --- | --- |")
	var files: Array = Array(DirAccess.get_files_at(TruckSockets.DIR))
	files.sort()
	for f in files:
		if not String(f).ends_with(".json") or String(f).ends_with(".surf.json"):
			continue
		var stem: String = String(f).get_basename()
		var data: Dictionary = TruckSockets.for_model(stem + ".glb")
		var body: String = String(data.get("body", ""))
		var model: Node3D = PartFit.load_model(TruckNode.MODEL_DIR + stem + ".glb", body, String(data.get("cab", "")))
		var ok: Dictionary = {"rb": 0, "rk": 0, "bl": 0}
		var n: Dictionary = {"rb": 0, "rk": 0, "bl": 0}
		var here: int = 0
		var sc: float = 0.0
		for id in ids:
			var e: Dictionary = c.entry(id)
			var k: String = "rb" if String(e["socket"]) == "rear_bumper" else ("rk" if id.begins_with("rocket") else "bl")
			if TruckSockets.socket(data, String(e["socket"])).is_empty():
				continue                                    # so para bau fechado (graneleira, lona, tanque, cacamba)
			n[k] += 1
			if k == "rb":
				sc = TruckSockets.fit_scale(data, e)
			var probs: Array[String] = PartFit.check_part(model, data, c, id)
			if probs.is_empty():
				ok[k] += 1
			else:
				here += 1
				fails.append("- `%s` em `%s`: %s" % [id, stem, "; ".join(probs)])
		model.free()
		var rk: Dictionary = TruckSockets.socket(data, "rocket_r")
		var lens: PackedStringArray = []
		for k2 in ["box_light_r", "box_light_l", "box_light_top"]:
			var tot: float = 0.0
			for g in TruckSockets.socket(data, k2).get("strips", []):
				tot += StripFit._v(g["a"]).distance_to(StripFit._v(g["b"]))
			lens.append("%.1f" % tot)
		var name: String = stem.replace("dekotora_truck_", "") + (" (guardada)" if body == "carreta" else "")
		var only_box: String = "só baú fechado"
		lines.append("| %s | %d/%d | %.2f | %s | %s | %s | %s | %s |" % [name, ok["rb"], n["rb"], sc,
				("%d/%d" % [ok["rk"], n["rk"]]) if n["rk"] > 0 else only_box,
				("%.2f / %.2f m" % [float(rk["band"]), float(rk["length"])]) if not rk.is_empty() else "—",
				("%d/%d" % [ok["bl"], n["bl"]]) if n["bl"] > 0 else only_box,
				"/".join(lens) if n["bl"] > 0 else "—", "nenhuma" if here == 0 else str(here)])
		_lot2_ok += int(ok["rb"]) + int(ok["rk"]) + int(ok["bl"])
		_lot2_n += int(n["rb"]) + int(n["rk"]) + int(n["bl"])
	lines.append("")
	lines.append("Lote 2: **%d de %d** combinações cabem. Para-choque traseiro: largura do baú, atrás de tudo o que fica" % [_lot2_ok, _lot2_n])
	lines.append("embaixo dele (substitui o para-choque e as lanternas de fábrica de baixo: leva lanternas próprias e a caixa da")
	lines.append("placa), topo a 0,93 m (abaixo das setas). Foguete e contorno: faixas medidas por raios na lataria real")
	lines.append("(`truck_measure.box_edges`); conferidos vértice a vértice (`StripFit.problems`).")
	lines.append("")


var _lot3_ok: int = 0
var _lot3_n: int = 0


## T-232: matriz caminhao x pinturas (12 murais nos 2 lados, 12 traseiras, 9 tetos), com o tamanho de cada face medida.
func _lot3(c: AccessoryCatalog, lines: PackedStringArray, fails: PackedStringArray) -> void:
	var ids: Array[String] = []
	for e in c.data.get("accessories", []):
		# interior paint (T-234) is reported in _lot5
		if PaintFit.handles(e) and String(e.get("socket", "")) in ["mural_r", "rear_paint", "roof_paint"]:
			ids.append(String(e["id"]))
	lines.append("## Matriz caminhão × pinturas (T-232: 12 murais com os 2 lados, 12 traseiras, 9 tetos)")
	lines.append("")
	lines.append("| Caminhão | Murais OK | Lateral (m) | Traseiras OK | Traseira (m) | Tetos OK | Teto (m) | Falhas |")
	lines.append("| --- | --- | --- | --- | --- | --- | --- | --- |")
	var files: Array = Array(DirAccess.get_files_at(TruckSockets.DIR))
	files.sort()
	for f in files:
		if not String(f).ends_with(".json") or String(f).ends_with(".surf.json"):
			continue
		var stem: String = String(f).get_basename()
		var data: Dictionary = TruckSockets.for_model(stem + ".glb")
		var body: String = String(data.get("body", ""))
		var name: String = stem.replace("dekotora_truck_", "") + (" (guardada)" if body == "carreta" else "")
		if not TruckSockets.socket(data, "mural_r").has("rect"):
			lines.append("| %s | só baú fechado | — | só baú fechado | — | só baú fechado | — | nenhuma |" % name)
			continue
		var model: Node3D = PartFit.load_model(TruckNode.MODEL_DIR + stem + ".glb", body, String(data.get("cab", "")))
		var ok: Dictionary = {"mural_r": 0, "rear_paint": 0, "roof_paint": 0}
		var n: Dictionary = {"mural_r": 0, "rear_paint": 0, "roof_paint": 0}
		var here: int = 0
		for id in ids:
			var k: String = String(c.entry(id)["socket"])
			n[k] += 1
			var probs: Array[String] = PartFit.check_part(model, data, c, id)
			if probs.is_empty():
				ok[k] += 1
			else:
				here += 1
				fails.append("- `%s` em `%s`: %s" % [id, stem, "; ".join(probs)])
		model.free()
		var sz: Dictionary = {}
		for k in ["mural_r", "rear_paint", "roof_paint"]:
			var r: Dictionary = TruckSockets.socket(data, k)["rect"]
			sz[k] = "%.2f × %.2f" % [float(r["w"]), float(r["h"])]
		lines.append("| %s | %d/%d | %s | %d/%d | %s | %d/%d | %s | %s |" % [name, ok["mural_r"], n["mural_r"], sz["mural_r"],
				ok["rear_paint"], n["rear_paint"], sz["rear_paint"], ok["roof_paint"], n["roof_paint"], sz["roof_paint"],
				"nenhuma" if here == 0 else str(here)])
		for k in ok:
			_lot3_ok += int(ok[k])
			_lot3_n += int(n[k])
	lines.append("")
	lines.append("Pinturas: **%d de %d** combinações cabem (os murais contam os 2 lados numa combinação). Cada face é um retângulo" % [_lot3_ok, _lot3_n])
	lines.append("medido por raios no plano real da lataria (`blender/scripts/lib/paint_measure.py`), por dentro do contorno de LED;")
	lines.append("a arte nunca sai espelhada (u × v = normal) e fica fora das zonas protegidas (a traseira é tinta na porta: isenta só")
	lines.append("de `rear_doors`). Conferido por `PaintFit.problems`.")
	lines.append("")


var _lot4_ok: int = 0
var _lot4_n: int = 0
const LOT4: Array = ["front_bumper", "mirror_stay_r", "ladder_r", "side_skirts_r"]   # T-233


## T-233: matriz caminhao x lote 4 (11 para-choques da frente, 6 retrovisores, 3 escadas, 8 saias).
func _lot4(c: AccessoryCatalog, lines: PackedStringArray, fails: PackedStringArray) -> void:
	var ids: Array[String] = PartFit.socket_parts(c, LOT4)
	lines.append("## Matriz caminhão × lote 4 (T-233: 11 para-choques da frente, 6 retrovisores, 3 escadas, 8 saias)")
	lines.append("")
	lines.append("| Caminhão | Para-choques OK | Altura livre / faixa do meio | Retrovisores OK | Escadas OK | Saias OK | Trechos da saia (dir., m) | Falhas |")
	lines.append("| --- | --- | --- | --- | --- | --- | --- | --- |")
	var files: Array = Array(DirAccess.get_files_at(TruckSockets.DIR))
	files.sort()
	for f in files:
		if not String(f).ends_with(".json") or String(f).ends_with(".surf.json"):
			continue
		var stem: String = String(f).get_basename()
		var data: Dictionary = TruckSockets.for_model(stem + ".glb")
		var body: String = String(data.get("body", ""))
		var model: Node3D = PartFit.load_model(TruckNode.MODEL_DIR + stem + ".glb", body, String(data.get("cab", "")))
		var ok: Dictionary = {"front_bumper": 0, "mirror_stay": 0, "ladder": 0, "side_skirts": 0}
		var n: Dictionary = {"front_bumper": 0, "mirror_stay": 0, "ladder": 0, "side_skirts": 0}
		var here: int = 0
		for id in ids:
			var e: Dictionary = c.entry(id)
			var k: String = String(e["socket"]).trim_suffix("_r")
			if TruckSockets.socket(data, String(e["socket"])).is_empty():
				continue
			n[k] += 1
			var probs: Array[String] = PartFit.check_part(model, data, c, id)
			if probs.is_empty():
				ok[k] += 1
			else:
				here += 1
				fails.append("- `%s` em `%s`: %s" % [id, stem, "; ".join(probs)])
		model.free()
		var fb: Dictionary = TruckSockets.socket(data, "front_bumper")
		var sk: Dictionary = TruckSockets.socket(data, "side_skirts_r")
		var runs: PackedStringArray = []
		for r in sk.get("runs", []):
			runs.append("%.2f" % (float(r[1]) - float(r[0])))
		var sc: float = TruckSockets.fit_scale(data, {"socket": "front_bumper", "nominal_w": 2.3})
		var name: String = stem.replace("dekotora_truck_", "") + (" (guardada)" if body == "carreta" else "")
		var cell := func(k: String) -> String: return ("%d/%d" % [ok[k], n[k]]) if n[k] > 0 else "—"
		lines.append("| %s | %s | %.2f m / ×%.2f | %s | %s | %s | %s | %s |" % [name, cell.call("front_bumper"), float(fb.get("height", 0.0)),
				FrameFit.bumper_k(float(fb.get("height", 0.4)), sc, 0.13, 0.2, 0.09), cell.call("mirror_stay"),
				cell.call("ladder") if n["ladder"] > 0 else "sem lugar atrás da porta", cell.call("side_skirts"), " + ".join(runs) if runs.size() > 0 else "—",
				"nenhuma" if here == 0 else str(here)])
		if body != "carreta":
			for k in ok:
				_lot4_ok += int(ok[k])
				_lot4_n += int(n[k])
	lines.append("")
	lines.append("Lote 4: **%d de %d** combinações cabem (a carreta guardada não conta). Para-choque: encosta na frente do" % [_lot4_ok, _lot4_n])
	lines.append("nariz de fábrica, entre 0,16 m do chão e 3 cm abaixo do farol mais baixo; a faixa do meio estica/encolhe (coluna")
	lines.append("\"faixa do meio\", para o leque de 0,42 m). Retrovisor (T-263): base colada na coluna do para-brisa medida por")
	lines.append("raios (chapa + espaçador em cada ponto de fixação, sem vão, nunca no vidro nem na porta), até 0,50 m para fora; o")
	lines.append("espelho de fábrica some inteiro. Escada (T-263, capturas 111–113): na LATERAL da cabine, logo atrás da porta e do")
	lines.append("vidro dela, inclinada com a lateral, com espaçadores até a lataria, estribo embaixo e caixa de LED acima do teto")
	lines.append("(americana e Canter: sem lataria livre atrás da porta, sem escada). Saia: só nos trechos livres (tanque e bateria de fábrica ficam de")
	lines.append("fora). Conferido vértice a vértice (`FrameFit.problems`) e, no retrovisor e na escada, CONTATO por raios na malha")
	lines.append("real (`FrameContact`: haste ≤ 6 mm no ponto que encosta e canto solto ≤ 2,2 cm; espaçador da escada ≤ 1 cm).")
	lines.append("")


var _lot5_ok: int = 0
var _lot5_n: int = 0
const LOT5: Array = ["grille", "exhaust_stacks_r", "horn_r", "hubcaps", "interior"]   # T-234 (T-256: buzina nas pontas da viseira)


## T-234: matriz caminhao x lote 5 (grades, escapamentos, buzinas, calotas e interiores).
func _lot5(c: AccessoryCatalog, lines: PackedStringArray, fails: PackedStringArray) -> void:
	var ids: Array[String] = PartFit.socket_parts(c, LOT5)
	lines.append("## Matriz caminhão × lote 5 (T-234: grades, escapamentos, buzinas, calotas e interiores)")
	lines.append("")
	lines.append("| Caminhão | Grades OK | Escapamentos OK | Buzinas OK | Calotas OK | Interiores OK | Falhas |")
	lines.append("| --- | --- | --- | --- | --- | --- | --- |")
	var files: Array = Array(DirAccess.get_files_at(TruckSockets.DIR))
	files.sort()
	for f in files:
		if not String(f).ends_with(".json") or String(f).ends_with(".surf.json"):
			continue
		var stem: String = String(f).get_basename()
		var data: Dictionary = TruckSockets.for_model(stem + ".glb")
		var body: String = String(data.get("body", ""))
		var model: Node3D = PartFit.load_model(TruckNode.MODEL_DIR + stem + ".glb", body, String(data.get("cab", "")))
		var ok: Dictionary = {}
		var n: Dictionary = {}
		for k in LOT5:
			ok[k] = 0
			n[k] = 0
		var here: int = 0
		for id in ids:
			var e: Dictionary = c.entry(id)
			var k: String = String(e["socket"])
			if TruckSockets.socket(data, k).is_empty():
				continue                                    # so o caminhao que nao tem esse encaixe
			n[k] += 1
			var probs: Array[String] = PartFit.check_part(model, data, c, id)
			if probs.is_empty():
				ok[k] += 1
			else:
				here += 1
				fails.append("- `%s` em `%s`: %s" % [id, stem, "; ".join(probs)])
		model.free()
		var cells: PackedStringArray = []
		for k in LOT5:
			cells.append(("%d/%d" % [ok[k], n[k]]) if n[k] > 0 else "—")
		var name: String = stem.replace("dekotora_truck_", "") + (" (guardada)" if body == "carreta" else "")
		lines.append("| %s | %s | %s | %s | %s | %s | %s |" % [name, cells[0], cells[1], cells[2], cells[3], cells[4],
				"nenhuma" if here == 0 else str(here)])
		if body != "carreta":
			for k in LOT5:
				_lot5_ok += int(ok[k])
				_lot5_n += int(n[k])
	lines.append("")
	lines.append("Lote 5: **%d de %d** combinações cabem (a carreta guardada não conta). Grade: encosta na frente da cabine entre os" % [_lot5_ok, _lot5_n])
	lines.append("faróis e estica na caixa de cada cabine. Escapamento: no vão entre a cabine e a carga. Buzina: no topo da carga")
	lines.append("(caçamba sem topo plano não tem). Calota: em cada roda de fora. Interior: pintura no retângulo do para-brisa (`PaintFit`).")
	lines.append("Conferido vértice a vértice (`Lot5Fit.problems`, `Lot5Fit.wheel_problems`).")
	lines.append("")


func _initialize() -> void:
	var c := AccessoryCatalog.new()
	c.reload()
	var ids: Array[String] = PartFit.socket_parts(c, SLOTS)
	var lines: PackedStringArray = []
	lines.append("# Relatório de encaixe das peças da oficina (gerado)")
	lines.append("")
	lines.append("Gerado por `godot --headless --path game -s res://tools_dev/report_part_fit.gd` (T-211). Não edite à mão.")
	lines.append("Regras: `game/scripts/truck/part_fit.gd`; encaixes e zonas: `game/assets/vehicles/dekotora/truck/sockets/*.json`")
	lines.append("(gerados por `blender/scripts/build_sockets.py`). Teste automático: `game/tests/test_part_fit.gd`.")
	lines.append("")
	lines.append("## Matriz caminhão × lote 1 (17 deques + 14 viseiras)")
	lines.append("")
	lines.append("| Caminhão | Deques OK | Viseiras OK | Escala deque | Escala viseira | Encaixes que se cruzam / entram em zona | Falhas |")
	lines.append("| --- | --- | --- | --- | --- | --- | --- |")
	var fails: PackedStringArray = []
	var zones_txt: PackedStringArray = []
	var total_ok: int = 0
	var total: int = 0
	var files: Array = Array(DirAccess.get_files_at(TruckSockets.DIR))
	files.sort()
	for f in files:
		if not String(f).ends_with(".json") or String(f).ends_with(".surf.json"):
			continue
		var stem: String = String(f).get_basename()
		var data: Dictionary = TruckSockets.for_model(stem + ".glb")
		var body: String = String(data.get("body", ""))
		var model: Node3D = PartFit.load_model(TruckNode.MODEL_DIR + stem + ".glb", body, String(data.get("cab", "")))
		var ok: Dictionary = {"andon": 0, "visor": 0}
		var n: Dictionary = {"andon": 0, "visor": 0}
		var sc: Dictionary = {"andon": [9.0, 0.0], "visor": [9.0, 0.0]}
		var here: int = 0
		for id in ids:
			var e: Dictionary = c.entry(id)
			var slot: String = String(e["socket"])
			n[slot] += 1
			var s: float = TruckSockets.fit_scale(data, e)
			sc[slot] = [minf(sc[slot][0], s), maxf(sc[slot][1], s)]
			var probs: Array[String] = PartFit.check_part(model, data, c, id)
			if probs.is_empty():
				ok[slot] += 1
			else:
				here += 1
				fails.append("- `%s` em `%s`: %s" % [id, stem, "; ".join(probs)])
		model.free()
		var design: Array[String] = PartFit.design_problems(data)
		total_ok += int(ok["andon"]) + int(ok["visor"])
		total += int(n["andon"]) + int(n["visor"])
		var name: String = stem.replace("dekotora_truck_", "") + (" (guardada)" if body == "carreta" else "")
		lines.append("| %s | %d/%d | %d/%d | %.2f–%.2f | %.2f–%.2f | %s | %s |" % [name, ok["andon"], n["andon"], ok["visor"], n["visor"],
				sc["andon"][0], sc["andon"][1], sc["visor"][0], sc["visor"][1],
				"nenhum" if design.is_empty() else "; ".join(design), "nenhuma" if here == 0 else str(here)])
		if stem in ["dekotora_truck_base_chata", "dekotora_truck_canter"]:
			zones_txt.append("**%s**: %s" % [name, ", ".join(PackedStringArray((data.get("protected", {}) as Dictionary).keys()))])
			var socks: PackedStringArray = []
			for k in data.get("sockets", {}):
				var sd: Dictionary = data["sockets"][k]
				socks.append("%s (%s)" % [k, String(sd.get("fit", ""))])
			zones_txt.append("encaixes: " + ", ".join(socks))
	lines.append("")
	lines.append("**Total: %d de %d combinações cabem** (peça dentro da caixa, fora da lataria e de toda zona protegida)." % [total_ok, total])
	lines.append("")
	_lot2(c, lines, fails)
	total_ok += _lot2_ok
	total += _lot2_n
	_lot3(c, lines, fails)
	total_ok += _lot3_ok
	total += _lot3_n
	_lot4(c, lines, fails)
	total_ok += _lot4_ok
	total += _lot4_n
	_lot5(c, lines, fails)
	total_ok += _lot5_ok
	total += _lot5_n
	lines.append("**Total geral (lotes 1, 2, 4, 5 e pinturas): %d de %d combinações cabem.**" % [total_ok, total])
	lines.append("")
	lines.append("## Falhas")
	lines.append("")
	if fails.is_empty():
		lines.append("Nenhuma. (Na 1ª rodada o teste reprovou ~70 combinações: deques 2–3 cm mais largos que a caixa e canhões fundos")
		lines.append("demais na cabine americana; corrigido no Blender: largura nominal = largura real da peça; canhões medidos pela")
		lines.append("largura do teto. Imagem das caixas e zonas: `docs/capturas_t211/encaixes_zonas.png`.)")
	else:
		lines.append_array(fails)
	lines.append("")
	lines.append("## Zonas protegidas e encaixes (exemplos)")
	lines.append("")
	lines.append_array(zones_txt)
	lines.append("")
	lines.append("Isenções declaradas: `front_plate` (a placa fica em cima do para-choque) e `blinker_front_*` (o para-choque novo")
	lines.append("leva a seta junto) para `front_bumper`; `rear_plate` e `rear_lamp_*` (T-231: a peça leva lanternas e caixa da")
	lines.append("placa próprias) para `rear_bumper`; rodas para `hubcaps`; `rear_doors` para `rear_paint` (T-232: tinta na porta).")
	lines.append("T-233: o para-choque da frente leva a seta (pontos SIGNAL_L/R) e a caixa da placa; o espelho de fábrica (caixa")
	lines.append("`hide` do encaixe `mirror_stay_*`) some enquanto a haste está montada.")
	lines.append("")
	var fa := FileAccess.open(ProjectSettings.globalize_path(OUT), FileAccess.WRITE)
	fa.store_string("\n".join(lines) + "\n")
	fa.close()
	print("REPORT_ENCAIXE: %d/%d ok -> %s" % [total_ok, total, ProjectSettings.globalize_path(OUT)])
	quit(0 if fails.is_empty() else 1)
