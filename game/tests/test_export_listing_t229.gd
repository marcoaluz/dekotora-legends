extends TestCase
## T-229: no APK exportado os .tres viram ".tres.remap", entao DirAccess.get_files_at nao acha "*.tres" e a lista vem
## vazia (a garagem do celular ficou sem encaixes de pecas). Todo script que lista uma pasta de recursos precisa
## tirar o ".remap" do nome. Aqui: (1) as pecas e os encaixes aparecem; (2) nenhum script lista pasta sem tratar ".remap".

const SCRIPT_DIRS: Array[String] = ["res://scripts/"]


func test_parts_and_slots_found() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	check(gs.all_parts().size() > 20, "GameState.all_parts acha as pecas (%d)" % gs.all_parts().size())
	check("front_bumper" in gs.slots(), "encaixe do para-choque aparece")
	check("visor" in gs.slots(), "encaixe da viseira aparece")


func _scan(dir: String, out: Array[String]) -> void:
	for d in DirAccess.get_directories_at(dir):
		_scan(dir + d + "/", out)
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir + f)


func test_every_listing_handles_remap() -> void:
	var files: Array[String] = []
	for d in SCRIPT_DIRS:
		_scan(d, files)
	for path in files:
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			if not lines[i].contains("DirAccess.get_files_at("):
				continue
			var window: String = "\n".join(lines.slice(i, mini(i + 4, lines.size())))
			check(window.contains(".remap"), "%s:%d lista pasta sem tirar \".remap\" (quebra no APK)" % [path, i + 1])
