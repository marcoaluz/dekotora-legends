extends SceneTree
## Sonda dos para-choques grandes (T-264): monta uma peca num caminhao e mostra o encaixe (abas, tampas), a caixa da peca,
## os problemas e ate 16 vertices fora das caixas (com a malha de origem), agrupados por malha.
## Uso: godot --headless --path game -s res://tools_dev/probe_t264.gd -- --model=base_curta --part=fb_wrap_lamps


func _initialize() -> void:
	var stem: String = "base_chata"
	var pid: String = "fb_wrap_lamps"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--model="):
			stem = a.get_slice("=", 1)
		elif a.begins_with("--part="):
			pid = a.get_slice("=", 1)
	var data: Dictionary = TruckSockets.for_model("dekotora_truck_" + stem + ".glb")
	var c := AccessoryCatalog.get_instance()
	var model: Node3D = PartFit.load_model(TruckNode.MODEL_DIR + "dekotora_truck_" + stem + ".glb", String(data["body"]), String(data["cab"]))
	var s: Dictionary = TruckSockets.socket(data, "front_bumper")
	print("encaixe: anchor=", s["anchor"], " altura=", s.get("height"), " largura=", s.get("width"), " escala=",
			TruckSockets.fit_scale(data, c.entry(pid)))
	for side in ["r", "l"]:
		var w: Dictionary = s.get("wrap", {}).get(side, {})
		print("  aba ", side, ": x=", w.get("x"), " len=", w.get("len"), " perfil=", w.get("prof"))
	for b in s.get("boxes", [s["box"]]):
		print("  caixa ", b)
	print("problemas: ", PartFit.check_part(model, data, c, pid))
	var acc: Node3D = c.attach(model, pid, "R")
	if acc != null:
		print("  caixa da peca: ", PartFit.aabb_in(acc, model), " k=", acc.get_meta("bumper_k", -1.0))
		var boxes: Array[AABB] = []
		for b in s.get("boxes", [s["box"]]):
			boxes.append(TruckSockets.aabb_of(b).grow(PartFit.TOL))
		var per: Dictionary = {}
		for mi in StripFit._meshes(acc):
			var t: Transform3D = PartFit.rel_xform(mi, model)
			var lo := Vector3(INF, INF, INF)
			var hi := -lo
			var n: int = 0
			for v in mi.mesh.get_faces():
				var wv: Vector3 = t * v
				var ok: bool = false
				for b in boxes:
					if b.has_point(wv):
						ok = true
						break
				if not ok:
					n += 1
					lo = lo.min(wv)
					hi = hi.max(wv)
			if n > 0:
				per[String(mi.name)] = [n, lo, hi]
		for k in per:
			print("  fora: ", k, " n=", per[k][0], " de ", per[k][1], " a ", per[k][2])
	model.free()
	quit(0)
