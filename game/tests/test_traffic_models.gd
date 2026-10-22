extends TestCase
## Modelos 3D do transito (T-121/T-124): todos carregam com pintura trocavel; os modelos de terceiros
## respeitam o orcamento (triangulos, superficies), tem rodas wheel_f/wheel_r com pivo no eixo, chao em 0,
## origem na traseira e cabem no comprimento do tipo na simulacao.

# modelo: [tipo, triangulos maximos]
const NEW_MODELS: Dictionary = {
	"car_van01": [TrafficSim.Kind.CAR, 7000],
	"car_ascona": [TrafficSim.Kind.CAR, 6000],
	"car_falcon": [TrafficSim.Kind.CAR, 6000],
	"car_suv": [TrafficSim.Kind.CAR, 6000],
	"car_jeep": [TrafficSim.Kind.CAR, 6000],
	"car_fumi": [TrafficSim.Kind.SPORT, 6000],
	"car_bus": [TrafficSim.Kind.BUS, 9000],
	"car_lp_coupe": [TrafficSim.Kind.CAR, 6000],      # T-193
	"car_lp_hatch": [TrafficSim.Kind.CAR, 6000],
}
const MAX_SURFACES: int = 4      # pintura + atlas no corpo, 1 por eixo de roda


func _stats(n: Node) -> Dictionary:
	var tris: int = 0
	var surfaces: int = 0
	var paint: bool = false
	var aabb := AABB()
	var first: bool = true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var inst: MeshInstance3D = mi as MeshInstance3D
		var am: ArrayMesh = inst.mesh as ArrayMesh
		for s in inst.mesh.get_surface_count():
			surfaces += 1
			if am != null:
				tris += am.surface_get_array_index_len(s) / 3
			var m: Material = inst.mesh.surface_get_material(s)
			if m != null and m.resource_name == "paint_white":
				paint = true
		var box: AABB = inst.transform * inst.mesh.get_aabb()
		aabb = box if first else aabb.merge(box)
		first = false
	return {"tris": tris, "surfaces": surfaces, "paint": paint, "aabb": aabb}


func test_all_traffic_models_load_with_paint() -> void:
	for m in Traffic3D.all_models():
		var ps: PackedScene = load("%s%s.glb" % [Traffic3D.DIR, m]) as PackedScene
		check(ps != null, "modelo carrega: " + m)
		if ps == null:
			continue
		var n: Node = ps.instantiate()
		check(_stats(n)["paint"], "tem material paint_white (cor por carro): " + m)
		n.free()


func test_new_models_budget_wheels_and_size() -> void:
	for m in NEW_MODELS:
		var kind: int = int(NEW_MODELS[m][0])
		check(Traffic3D.MODELS_BY_KIND[kind].has(m), "%s esta na lista do tipo %d" % [m, kind])
		var ps: PackedScene = load(Traffic3D.DIR + m + ".glb") as PackedScene
		check(ps != null, m + " carrega")
		if ps == null:
			continue
		var n: Node = ps.instantiate()
		var st: Dictionary = _stats(n)
		var tris: int = int(st["tris"])
		check(tris >= 3000 and tris <= int(NEW_MODELS[m][1]), "%s: triangulos no orcamento (%d)" % [m, tris])
		check(int(st["surfaces"]) <= MAX_SURFACES, "%s: chamadas de desenho por carro (%d)" % [m, int(st["surfaces"])])
		var wheels: Array[Node] = n.find_children("wheel_*", "Node3D", true, false)
		check_eq(wheels.size(), 2, m + ": um no de roda por eixo (wheel_f, wheel_r)")
		for w in wheels:
			var p: Vector3 = (w as Node3D).position
			check(p.y > 0.25 and p.y < 0.65, "%s: pivo da roda %s na altura do eixo (%.2f)" % [m, w.name, p.y])
			check_near(p.x, 0.0, 0.01, m + ": pivo da roda no meio do eixo")
		var box: AABB = st["aabb"]
		var length: float = TrafficSim.KIND_LEN[kind]
		check(box.size.z <= length + 0.05, "%s: comprimento cabe no hitbox do tipo (%.2f <= %.2f)" % [m, box.size.z, length])
		check(box.size.z >= length * 0.88, "%s: comprimento real (%.2f)" % [m, box.size.z])
		check_near(box.position.y, 0.0, 0.05, m + ": chao em y = 0")
		check(box.position.z >= -length - 0.05 and box.end.z <= 0.05, m + ": origem na traseira, frente para -Z")
		n.free()


func test_model_choice_deterministic_and_uses_all() -> void:
	var seen: Dictionary = {}
	for seed_ in [7, 8, 9, 10]:
		var t := TrafficSim.new(seed_, TrafficSim.Density.HEAVY)
		var t2 := TrafficSim.new(seed_, TrafficSim.Density.HEAVY)
		for i in t.cars.size():
			var m: String = Traffic3D.model_for(t.cars[i].kind, i, t.cars[i].color_id)
			check(Traffic3D.MODELS_BY_KIND[t.cars[i].kind].has(m), "modelo do tipo certo")
			check_eq(Traffic3D.model_for(t2.cars[i].kind, i, t2.cars[i].color_id), m, "mesma semente, mesmo modelo")
			seen[m] = true
	for m in Traffic3D.all_models():
		check(seen.has(m), m + " aparece no transito pesado")
