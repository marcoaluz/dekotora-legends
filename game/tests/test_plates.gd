extends TestCase
## T-130: placas de veiculo ficticias (texto, atlas, variacao por veiculo, posicao nos modelos, 1 chamada de desenho).


func test_plate_texts_unique_and_formatted() -> void:
	var seen: Dictionary = {}
	for c in PlateCatalog.COUNT:
		var p: Dictionary = PlateCatalog.plate(c)
		var t: String = String(p["text"])
		check(not seen.has(t), "placa repetida no atlas: " + t)
		seen[t] = true
		check(PlateCatalog.REGIONS.has(String(p["region"])), "cidade conhecida: " + t)
		check_eq(int(p["style"]), PlateCatalog.style_of(c), "estilo da celula %d" % c)
		check(String(p["kana"]).length() == 1, "um kana: " + t)
		check(String(p["number"]).length() == 5 or String(p["number"]).begins_with("・"), "numero com 4 posicoes: " + t)
	check_eq(PlateCatalog.plate(5)["text"], PlateCatalog.plate(5)["text"], "deterministico")
	check_eq(PlateCatalog.format_number(1234), "12-34", "4 digitos")
	check_eq(PlateCatalog.format_number(7), "・・・7", "1 digito")
	check_eq(PlateCatalog.format_number(56), "・・56", "2 digitos")
	var total: int = 0
	for r in PlateCatalog.RANGES:
		total += int(r[1])
	check_eq(total, PlateCatalog.COUNT, "estilos cobrem o atlas")


func test_plate_atlas_texture_and_uv() -> void:
	var tex: Texture2D = load(PlateCatalog.ATLAS) as Texture2D
	check(tex != null, "atlas de placas existe")
	if tex != null:
		check_eq(tex.get_width(), PlateCatalog.COLS * PlateCatalog.CELL_PX.x, "largura do atlas")
		check_eq(tex.get_height(), PlateCatalog.ROWS * PlateCatalog.CELL_PX.y, "altura do atlas")
	var a: Rect2 = PlateCatalog.uv_rect(0)
	var b: Rect2 = PlateCatalog.uv_rect(1)
	check(not a.intersects(b), "celulas vizinhas nao se sobrepoem")
	var last: Rect2 = PlateCatalog.uv_rect(PlateCatalog.COUNT - 1)
	check(last.end.x <= 1.0 and last.end.y <= 1.0 and a.position.x >= 0.0, "UV dentro de 0..1")


func test_pick_varies_and_does_not_repeat() -> void:
	var used: Dictionary = {}
	var cells: Dictionary = {}
	for i in 24:
		cells[PlateCatalog.pick(PlateCatalog.Style.WHITE, i * 7919, used)] = true
	check_eq(cells.size(), 24, "24 carros brancos = 24 placas diferentes")
	for c in cells:
		check_eq(PlateCatalog.style_of(int(c)), PlateCatalog.Style.WHITE, "celula do estilo pedido")
	var again: int = PlateCatalog.pick(PlateCatalog.Style.WHITE, 1, used)      # acabou: repete, mas nao quebra
	check(again >= 0 and again < 24, "estilo esgotado ainda devolve celula valida")


func test_traffic_plates_sit_on_every_model() -> void:
	for m in Traffic3D.all_models():
		var n: Node3D = (load("%s%s.glb" % [Traffic3D.DIR, m]) as PackedScene).instantiate() as Node3D
		var spots: Array = Traffic3D.plate_spots(m, n)
		var box := AABB()
		var first: bool = true
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var bb: AABB = PlateSpot.rel_transform(mi, n) * (mi as MeshInstance3D).mesh.get_aabb()
			box = bb if first else box.merge(bb)
			first = false
		var f: Vector3 = (spots[0] as Transform3D).origin
		var r: Vector3 = (spots[1] as Transform3D).origin
		check(f.z <= box.position.z + 0.45 and f.z >= box.position.z - 0.05, "%s: placa da frente na frente (z %.2f, carro %.2f)" % [m, f.z, box.position.z])
		check(r.z >= box.end.z - 0.45 and r.z <= box.end.z + 0.05, "%s: placa de tras atras (z %.2f, carro %.2f)" % [m, r.z, box.end.z])
		check(f.y > 0.2 and f.y < 1.0 and r.y > 0.2 and r.y < 1.0, m + ": altura de placa")
		check((spots[0] as Transform3D).basis.z.dot(Vector3.FORWARD) > 0.9, m + ": placa da frente olha para a frente")
		n.free()


func test_traffic_plates_vary_per_car_one_draw() -> void:
	var track: Track = Track.make_test_track()
	var path := TrackPath.new(track)
	var traffic := TrafficSim.new(1234, TrafficSim.Density.HEAVY)
	var plates := LicensePlates.new()
	var t3d := Traffic3D.new()
	t3d.setup(path, traffic, plates)
	check_eq(plates.plate_count(), traffic.cars.size() * 2, "2 placas por carro")
	var cells: Dictionary = {}
	for i in plates.plate_count():
		cells[plates._rects[i]] = true
	check(cells.size() >= mini(traffic.cars.size(), 20), "placas variadas (%d diferentes para %d carros)" % [cells.size(), traffic.cars.size()])
	check(plates is MultiMeshInstance3D and plates.get_child_count() == 0, "todas as placas num MultiMesh (1 chamada)")
	t3d.free()
	plates.free()


func test_truck_plates_front_and_rear() -> void:
	for cab in CabCatalog.IDS:
		var node := Node3D.new()                           # como o TruckNode: o .glb e filho direto
		var model: Node3D = TruckNode.instantiate_model("base", cab)
		node.add_child(model)
		var s: Array = TruckPlateSpots.spots(node, model, cab)
		var f: Vector3 = (s[0] as Transform3D).origin
		var r: Vector3 = (s[1] as Transform3D).origin
		check(f.z < -10.5 and f.z > -12.5, "%s: placa da frente no bico (z %.2f)" % [cab, f.z])
		check(r.z > 0.0 and r.z < 0.2, "%s: placa de tras no bau (z %.2f)" % [cab, r.z])
		check(f.y > 0.3 and f.y < 1.1 and absf(r.y - 1.0) < 0.05, cab + ": alturas das placas")
		check(bool(s[2]), cab + ": traseira visivel sem placa decorativa")
		node.free()
