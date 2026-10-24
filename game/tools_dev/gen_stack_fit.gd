extends SceneTree
## Gera a tabela do deque de 2 niveis (T-215): para cada caminhao, as duplas (de baixo, de cima) que cabem pela conta
## geometrica (StackFit.problems). Rodar de novo depois de mudar pecas do deque, encaixes ou caminhoes.
## Uso (raiz do projeto): godot --headless --path game -s res://tools_dev/gen_stack_fit.gd


func _initialize() -> void:
	var c := AccessoryCatalog.new()
	c.reload()
	var pairs: Array = StackFit.shape_pairs(c)
	var fits: Dictionary = {}
	var files: Array = Array(DirAccess.get_files_at(TruckSockets.DIR))
	files.sort()
	var n_ok: int = 0
	var n_all: int = 0
	for f in files:
		if not String(f).ends_with(".json") or String(f).ends_with(".surf.json"):
			continue
		var stem: String = String(f).get_basename()
		var data: Dictionary = TruckSockets.for_model(stem + ".glb")
		var model: Node3D = PartFit.load_model(TruckNode.MODEL_DIR + stem + ".glb", String(data["body"]), String(data["cab"]))
		var ok: Array = []
		for pr in pairs:
			n_all += 1
			if StackFit.problems(model, data, c, pr[0], pr[1]).is_empty():
				ok.append(StackFit.key(pr[0], pr[1]))
		n_ok += ok.size()
		fits[stem] = ok
		print("%-40s %d de %d duplas" % [stem, ok.size(), pairs.size()])
		model.free()
	var out := FileAccess.open(StackFit.TABLE, FileAccess.WRITE)
	out.store_string(JSON.stringify({"version": 1, "note": "gerado por tools_dev/gen_stack_fit.gd (T-215); nao edite", "fits": fits}, " ", true) + "\n")
	out.close()
	print("OK gen_stack_fit: %d de %d duplas x caminhoes cabem -> %s" % [n_ok, n_all, StackFit.TABLE])
	quit()
