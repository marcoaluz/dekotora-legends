extends TestCase
## Saias laterais GRANDES (T-265, capturas 085-094; pedido do Marco: "quase no chao, contornando as rodas e tambem atras
## da roda traseira"). As 8 saias (mesmos ids da T-233) agora sao montadas no jogo (SkirtFit) em TODOS os caminhoes:
## da frente do bau ate a traseira, ate quase o chao, recorte em arco em volta das rodas (nunca no pneu), nada entra no
## tanque/bateria/degraus de fabrica (raios na malha real), luzes com cor separada, LOD, quebrada sem buraco.

const SKIRTS: Array[String] = ["skirt_chrome_rails", "skirt_neon_twin", "skirt_neon_diamond", "skirt_neon_dash",
	"skirt_neon_arch", "skirt_neon_green", "skirt_neon_gems", "skirt_neon_arrows"]
const PF := preload("res://tests/test_part_fit.gd")
const FLOOR_MAX: float = 0.25          # m: o fundo da saia fica no maximo a isto do chao ("quase no chao")
const TIRE_CLEAR: float = 0.05         # m: nenhum ponto da saia a menos disto do pneu


func test_catalog_and_spec() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	var c := AccessoryCatalog.get_instance()
	for id in SKIRTS:
		var e: Dictionary = c.entry(id)
		var d: PartDef = gs.part(id)
		check(not e.is_empty() and d != null, "%s no catalogo e PartDef" % id)
		if e.is_empty() or d == null:
			continue
		check(SkirtFit.handles(e) and FrameFit.handles(e), "%s: fit skirt (SkirtFit)" % id)
		check(String(e["model"]).contains("skirt_t265"), "%s: .glb da T-265" % id)
		check((e.get("skirt", {}) as Dictionary).has("rows"), "%s: desenho no catalogo" % id)
		var lim: int = 6000 if String(d.rarity) == "lendaria" else 4500
		check(int(e.get("triangles", 0)) > 0 and int(e["triangles"]) <= lim, "%s: %d triangulos (pior caso, um lado)" % [id, e.get("triangles", 0)])
		check(int(e.get("triangles_lod", 99999)) <= int(e.get("triangles", 0)) * 0.35 + 1, "%s: LOD <= 35%%" % id)
		var mats: Array = e.get("materials_used", [])
		if id != "skirt_chrome_rails":                 # (cromado sem cor, como a captura 086-087: "De dia/De noite")
			check("deco_neon" in mats or "deco_led" in mats, "%s: luz com cor separada" % id)
		check(DecoColorDef.find(String(e["default_color"])) != null, "%s: cor de fabrica" % id)


func test_shape_math() -> void:
	var arcs: Array = [[-3.0, 0.52, 0.62]]
	check_near(SkirtShape.col_lo(-5.0, 0.22, arcs), 0.22, 1e-6, "longe da roda: fundo da saia")
	check_near(SkirtShape.col_lo(-3.0, 0.22, arcs), 1.14, 1e-6, "em cima da roda: topo do arco")
	check(SkirtShape.col_lo(-3.0 - 0.61, 0.22, arcs) > 0.52, "dentro do arco, abaixo do centro: sem saia (recorte reto)")
	var cols: Array = SkirtShape.columns(-4.5, -2.0, 0.22, 1.06, arcs)
	var dup: int = 0
	for i in cols.size() - 1:
		if absf(float(cols[i][0]) - float(cols[i + 1][0])) < 1e-6:
			dup += 1
	check_eq(dup, 2, "coluna dupla nas 2 laterais do arco (degrau vertical do recorte)")
	var sp: Array[Vector2] = SkirtShape.spans(-4.5, 0.0, 0.70, 0.75, arcs, 0.03, 0.05)
	check_eq(sp.size(), 2, "faixa cortada pelo arco em 2 trechos")
	check(sp[0].y < -3.0 - 0.62 and sp[1].x > -3.0 + 0.62 - 0.2, "trechos fora do arco")
	check_eq(SkirtShape.spread(0.0, 1.0, 0.2, 0.3).size(), 3, "enfeites espalhados por igual")
	# trecho que comeca DENTRO do arco (poste da lona em cima da roda): o friso do recorte nao sai do trecho
	var z0: float = -3.0 + 0.45
	var mesh := SkirtMesh.new()
	mesh.ribbon("chrome", SkirtShape.bottom(SkirtShape.columns(z0, -1.0, 0.22, 1.06, arcs)), 0.026, -0.014, -0.008, -1,
			true, false, true)
	var zmin: float = INF
	for v in (mesh.groups["chrome"]["v"] as PackedVector3Array):
		zmin = minf(zmin, v.z)
	check(zmin >= z0 - 1e-5, "friso do recorte dentro do trecho (z %.3f >= %.3f)" % [zmin, z0])


## O catalogo guarda a maior saia montada (um lado) num caminhao jogavel, igual aos encaixes medidos.
func test_catalog_size_matches_sockets() -> void:
	var z: float = 0.0
	var y: float = 0.0
	for m in PF.models():
		var s: Dictionary = TruckSockets.socket(m["data"], "side_skirts_r")
		if m["body"] == "carreta" or s.is_empty():
			continue
		var lo: float = INF
		var hi: float = -INF
		for r in s.get("runs", []):
			lo = minf(lo, float(r[0]))
			hi = maxf(hi, float(r[1]))
		z = maxf(z, hi - lo)
		y = maxf(y, float(s.get("height", 0.0)))
	var c := AccessoryCatalog.get_instance()
	for id in SKIRTS:
		var d: Dictionary = c.entry(id).get("dimensions_m", {})
		check_near(float(d.get("z", 0.0)), z, 0.01, "%s: comprimento no catalogo = maior saia montada" % id)
		check_near(float(d.get("y", 0.0)), y, 0.01, "%s: altura no catalogo = maior saia montada" % id)


## Encaixe medido: da frente do bau ate a traseira (atras da ultima roda), fundo quase no chao, arcos de todas as rodas.
func test_socket_reaches_floor_and_behind_rear_wheel() -> void:
	var n: int = 0
	for m in PF.models():
		if m["body"] == "carreta":
			continue
		var data: Dictionary = m["data"]
		for side in ["r", "l"]:
			var s: Dictionary = TruckSockets.socket(data, "side_skirts_" + side)
			check(not s.is_empty() and String(s.get("fit", "")) == "skirt", "%s: saia %s (fit skirt)" % [m["stem"], side])
			if s.is_empty():
				continue
			check(float(s["floor_y"]) <= FLOOR_MAX, "%s: fundo a %.2f m do chao" % [m["stem"], float(s["floor_y"])])
			var arcs: Array = s.get("arcs", [])
			check(arcs.size() >= 1, "%s: arcos das rodas" % m["stem"])
			var last: float = -INF
			for a in arcs:
				last = maxf(last, float(a[0]) + float(a[2]))
			var behind: bool = false
			for r in s["runs"]:
				if float(r[1]) > last + 0.2:
					behind = true
			check(behind, "%s %s: saia atras da roda de tras" % [m["stem"], side])
			n += 1
	check(n >= 2 * 54, "%d lados conferidos" % n)


## Malha montada: nenhum ponto perto do pneu (cilindro medido), nenhum ponto dentro da lataria/tanque (raio de fora para
## dentro na espessura da saia), fundo no chao da saia; dos dois lados (o esquerdo espelhado).
func test_mesh_clears_tires_and_stock_parts() -> void:
	var c := AccessoryCatalog.get_instance()
	for stem in ["dekotora_truck_base_chata", "dekotora_truck_canter", "dekotora_truck_dump_chata",
			"dekotora_truck_leve_jac", "dekotora_truck_longo_curta", "dekotora_truck_tarp_chata", "dekotora_truck_tanker_americana"]:
		var data: Dictionary = TruckSockets.for_model(stem + ".glb")
		var model: Node3D = PartFit.load_model(TruckNode.MODEL_DIR + stem + ".glb", String(data["body"]), String(data["cab"]))
		var tm: TriangleMesh = FrameContact.truck_mesh(model, data)
		var wheels: Dictionary = data["measure"]["wheels"]
		for id in ["skirt_neon_arch", "skirt_chrome_rails"]:
			for side in ["R", "L"]:
				var node: Node3D = c.attach(model, id, side)
				check(node != null, "%s em %s %s: montou" % [id, stem, side])
				if node == null:
					continue
				var near_tire: int = 0
				var lo: float = INF
				var xs: float = 0.0
				for mi in StripFit._meshes(node):
					if mi.has_meta("part_lod"):
						continue
					var t: Transform3D = PartFit.rel_xform(mi, model)
					for v in mi.mesh.get_faces():
						var w: Vector3 = t * v
						lo = minf(lo, w.y)
						xs += w.x
						for wn in wheels:
							var b: Array = wheels[wn]
							if (float(b[0][0]) + float(b[1][0])) * w.x <= 0.0:
								continue
							var zc: float = (float(b[0][2]) + float(b[1][2])) * 0.5
							var yc: float = (float(b[0][1]) + float(b[1][1])) * 0.5
							var r: float = maxf(float(b[1][2]) - float(b[0][2]), float(b[1][1]) - float(b[0][1])) * 0.5
							if Vector2(w.z - zc, w.y - yc).length() < r + TIRE_CLEAR:
								near_tire += 1
				check_eq(near_tire, 0, "%s em %s %s: longe do pneu" % [id, stem, side])
				check((xs > 0.0) == (side == "R"), "%s em %s: lado %s certo" % [id, stem, side])
				var s: Dictionary = TruckSockets.socket(data, "side_skirts_" + side.to_lower())
				check(lo <= float(s["floor_y"]) + 0.02 or id == "skirt_chrome_rails", "%s em %s: desce ate %.2f m" % [id, stem, lo])
				node.get_parent().remove_child(node)
				node.free()
		# raios na espessura da saia: nada da lataria (tanque, bateria, degrau, para-lama) dentro do volume da saia
		var hits: int = 0
		for side in ["r", "l"]:
			var s2: Dictionary = TruckSockets.socket(data, "side_skirts_" + side)
			var sx: float = 1.0 if side == "r" else -1.0
			var x_out: float = absf(float(s2["anchor"][0]))
			var x_in: float = x_out - float(s2["depth"])
			for r in s2["runs"]:
				var z: float = float(r[0]) + 0.01
				while z < float(r[1]) - 0.01:
					var y0: float = SkirtShape.col_lo(z, float(s2["floor_y"]), s2["arcs"]) + 0.03
					var y: float = y0
					while y < float(s2["anchor"][1]) - 0.01:
						var hit: Variant = tm.intersect_segment(Vector3(sx * (x_out + 0.002), y, z), Vector3(sx * (x_in + 0.006), y, z))
						if hit is Dictionary and not (hit as Dictionary).is_empty():
							hits += 1
						y += 0.06
					z += 0.05
		check_eq(hits, 0, "%s: nada da lataria/tanque dentro da saia" % stem)
		model.free()


func test_lod_lights_and_broken() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	var t := TruckNode.new()
	t._ready()
	var defs: Array[PartDef] = [gs.part("skirt_neon_gems")]
	t.apply_loadout(defs)
	t.set_lights_on(true)
	var nodes: Array = t._acc_nodes.get("skirt_neon_gems", [])
	check_eq(nodes.size(), 2, "saia nos dois lados")
	for n in nodes:
		var node: Node3D = n
		var near: int = 0
		var far: int = 0
		var lit: int = 0
		for mi in node.find_children("*", "MeshInstance3D", true, false):
			var m: MeshInstance3D = mi as MeshInstance3D
			if m.visibility_range_begin > 0.0:
				far += 1
			elif m.visibility_range_end > 0.0:
				near += 1
			for k in m.mesh.get_surface_count():
				if m.get_active_material(k) is ShaderMaterial:
					lit += 1
		check(near > 0 and far > 0, "LOD: perto (%d) e longe (%d)" % [near, far])
		check(lit > 0, "neon/LED acende a noite (%d)" % lit)
	t.set_part_state("skirt_neon_gems", "broken")
	for n in nodes:
		var node2: Node3D = n
		check(node2.visible, "quebrada continua no lugar (sem buraco)")
		var lit2: int = 0
		for mi in node2.find_children("*", "MeshInstance3D", true, false):
			var m2: MeshInstance3D = mi as MeshInstance3D
			for k in m2.mesh.get_surface_count():
				if m2.get_active_material(k) is ShaderMaterial:
					lit2 += 1
		check_eq(lit2, 0, "quebrada: luzes apagadas")
	t.free()


## Cor do neon separada (perfil part_style.neon): troca so o material do neon, o painel fica.
func test_neon_color_separate() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	var other: DecoLightDef = null
	for ld in DecoLightDef.all():
		if String(ld.id) != DecoStyle.default_light("preto_ciano", "neon"):
			other = ld
			break
	check(other != null, "outra cor de neon na tabela")
	if other == null:
		return
	var mats: Array = []
	for st in [{}, {"skirt_neon_twin": {"neon": String(other.id)}}]:
		var t := TruckNode.new()
		t._ready()
		var defs: Array[PartDef] = [gs.part("skirt_neon_twin")]
		t.apply_loadout(defs, st)
		var node: Node3D = t._acc_nodes["skirt_neon_twin"][0]
		var neon: Array = node.find_children("*_deco_neon", "MeshInstance3D", true, false)
		var body: Array = node.find_children("*_deco_body", "MeshInstance3D", true, false)
		check(not neon.is_empty() and not body.is_empty(), "malhas do neon e do painel")
		if neon.is_empty() or body.is_empty():
			t.free()
			return
		mats.append([(neon[0] as MeshInstance3D).get_active_material(0), (body[0] as MeshInstance3D).get_active_material(0)])
		t.free()
	check(mats[0][0] != mats[1][0], "neon com outra cor (%s)" % other.lamp)
	check(mats[0][1] == mats[1][1], "painel continua igual")
