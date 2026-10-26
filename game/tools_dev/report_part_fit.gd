extends SceneTree
## Relatorio de encaixe (T-211): docs/REPORT_ENCAIXE.md com a matriz caminhao x peca (deque e viseira), a escala
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
	lines.append("**Total geral (lotes 1 e 2): %d de %d combinações cabem.**" % [total_ok, total])
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
	lines.append("placa próprias) para `rear_bumper`; rodas para `hubcaps`.")
	lines.append("")
	var fa := FileAccess.open(ProjectSettings.globalize_path(OUT), FileAccess.WRITE)
	fa.store_string("\n".join(lines) + "\n")
	fa.close()
	print("REPORT_ENCAIXE: %d/%d ok -> %s" % [total_ok, total, ProjectSettings.globalize_path(OUT)])
	quit(0 if fails.is_empty() else 1)
