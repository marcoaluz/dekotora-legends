class_name StockRearLamps
extends RefCounted
## T-239: lanterna de fabrica do jogo para os caminhoes cujo para-choque de fabrica so tem a faixa vermelha fina (baus
## base/leve/longo/carreta): com as luzes da porta do bau fora (RearDoorLamps), eles ficariam sem seta e quase sem freio
## atras. Uma chapa preta em cada lado do para-choque de fabrica com 4 lanternas redondas (de fora para dentro: ambar =
## seta, vermelha, vermelha, branca = re), como as dos caminhoes de homenagem. Usa os materiais lamp_* do proprio modelo
## (acendem/piscam/ficam vermelhos igual as outras). Fica ATRAS do encaixe do para-choque da oficina (z < 0,205): com
## a peca montada ela some.

const NAME := "STOCK_rear_lamps"
const PITCH: float = 0.18                  # m entre lanternas
const RADIUS: float = 0.064
const OUTER_X: float = 1.08                # centro da lanterna de fora (ambar)
const ROLES: Array[String] = ["lamp_amber", "lamp_red", "lamp_red", "lamp_white"]


## Precisa? (nenhuma lanterna ambar virada para tras abaixo do bau, de fabrica).
static func needed(model: Node3D, data: Dictionary) -> bool:
	var meas: Dictionary = data.get("measure", {})
	if not meas.has("box"):
		return false
	for side in [-1, 1]:
		if TruckSignals._rear_factory(model, meas, side).is_empty():
			return true
	return false


## Monta as lanternas (uma vez) no no raiz do .glb. Altura logo acima da faixa vermelha de fabrica (rear_lamps).
static func build(model: Node3D, data: Dictionary) -> Node3D:
	var meas: Dictionary = data.get("measure", {})
	var rl: Dictionary = meas.get("rear_lamps", {})
	var strip_top: float = 0.45
	var face_z: float = 0.18
	if rl.has("l"):
		var b: AABB = TruckSockets.aabb_of(rl["l"])
		strip_top = b.end.y
		face_z = b.position.z
	var rb: Dictionary = TruckSockets.socket(data, "rear_bumper")
	var limit_z: float = TruckSockets.aabb_of(rb["box"]).position.z - 0.004 if rb.has("box") else face_z + 0.02
	var cy: float = strip_top + 0.03 + RADIUS + 0.025
	var host: Node = model.get_child(0) if model.get_child_count() >= 1 and model.get_child(0) is Node3D else model
	var root := Node3D.new()
	root.name = NAME
	(host as Node).add_child(root)
	# o no raiz do .glb pode ter transform: a lanterna e montada no espaco do modelo
	root.transform = PartFit.rel_xform(host as Node3D, model).affine_inverse() if host != model else Transform3D.IDENTITY
	var mats: Dictionary = _materials(model)
	var plate_mat: Material = mats.get("plastic_black", _dark())
	var lamp_z0: float = limit_z - 0.014
	for side in [-1.0, 1.0]:
		var plate := MeshInstance3D.new()
		var pm := BoxMesh.new()
		var x0: float = OUTER_X + RADIUS + 0.04
		var x1: float = OUTER_X - PITCH * 3.0 - RADIUS - 0.04
		pm.size = Vector3(x0 - x1, 2.0 * RADIUS + 0.05, 0.03)
		pm.material = plate_mat
		plate.mesh = pm
		plate.name = "plate_%s" % ("l" if side < 0 else "r")
		plate.position = Vector3(side * (x0 + x1) * 0.5, cy, lamp_z0 - 0.015)
		root.add_child(plate)
		for k in ROLES.size():
			var lamp := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = RADIUS
			cm.bottom_radius = RADIUS
			cm.height = 0.012
			cm.radial_segments = 14
			cm.rings = 1
			cm.material = mats.get(ROLES[k], _dark())
			lamp.mesh = cm
			lamp.name = "%s_%s_%d" % [ROLES[k], "l" if side < 0 else "r", k]
			lamp.rotation = Vector3(PI * 0.5, 0.0, 0.0)
			lamp.position = Vector3(side * (OUTER_X - PITCH * k), cy, lamp_z0 + 0.006)
			root.add_child(lamp)
	return root


## Materiais lamp_*/plastic_black do proprio modelo (o primeiro de cada nome).
static func _materials(model: Node3D) -> Dictionary:
	var out: Dictionary = {}
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		if m.mesh == null:
			continue
		for s in m.mesh.get_surface_count():
			var mat: Material = m.mesh.surface_get_material(s)
			if mat != null and not out.has(mat.resource_name):
				out[mat.resource_name] = mat
	return out


static func _dark() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.04, 0.04, 0.045)
	m.roughness = 0.5
	return m
