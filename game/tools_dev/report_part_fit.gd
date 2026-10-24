extends SceneTree
## Relatorio de encaixe (T-211): docs/REPORT_ENCAIXE.md com a matriz caminhao x peca (deque e viseira), a escala
## usada, os problemas de projeto dos encaixes e as zonas protegidas de cada caminhao.
## Uso (raiz do projeto): godot --headless --path game -s res://tools_dev/report_part_fit.gd

const OUT := "res://../docs/REPORT_ENCAIXE.md"
const SLOTS: Array = ["andon", "visor"]


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
	lines.append("leva a seta junto) para `front_bumper`; `rear_plate` para `rear_bumper`; rodas para `hubcaps`.")
	lines.append("")
	var fa := FileAccess.open(ProjectSettings.globalize_path(OUT), FileAccess.WRITE)
	fa.store_string("\n".join(lines) + "\n")
	fa.close()
	print("REPORT_ENCAIXE: %d/%d ok -> %s" % [total_ok, total, ProjectSettings.globalize_path(OUT)])
	quit(0 if fails.is_empty() else 1)
