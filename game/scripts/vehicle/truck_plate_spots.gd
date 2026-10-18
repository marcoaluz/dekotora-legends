class_name TruckPlateSpots
extends RefCounted
## Onde vao as placas de um caminhao (TruckNode): frente no para-choque, traseira no retangulo branco do bau
## (MOUNT_REAR_PLATE). A distancia ate a lataria sai de raios (PlateSpot), entao vale para qualquer cabine,
## bau e peca instalada. So a ALTURA da placa da frente depende da cabine (medida com tools_dev/measure_plates.gd).

## Altura (m) do centro da placa dianteira por cabine mostrada (TruckNode.shown_cab()).
const FRONT_Y: Dictionary = {"chata": 0.775, "jac": 0.70, "curta": 0.62, "americana": 0.50, "canter": 0.60}
const DEFAULT_FRONT_Y: float = 0.7


## [transform da placa da frente, transform da traseira, traseira visivel] no espaco de `truck`.
static func spots(truck: Node3D, model: Node3D, cab: String) -> Array:
	var fy: float = float(FRONT_Y.get(cab, DEFAULT_FRONT_Y))
	var rear_mount: Node3D = model.find_child("MOUNT_REAR_PLATE", true, false) as Node3D
	var ry: float = PlateSpot.rel_transform(rear_mount, truck).origin.y if rear_mount != null else 1.0
	var holder: Dictionary = _bumper_plate(truck, model)
	var lo: float = minf(fy, ry) if holder.is_empty() else minf(minf(fy, ry), (holder["box"] as AABB).get_center().y)
	var tms: Array = PlateSpot.triangle_meshes(model, lo - 0.25, maxf(fy, ry) + 0.25)
	for e in tms:                                           # malhas no espaco do TruckNode (o .glb e filho dele)
		e[1] = PlateSpot.rel_transform(model, truck) * (e[1] as Transform3D)
	var size: Vector2 = LicensePlates.SIZE_TRUCK
	var front: Transform3D
	if not holder.is_empty():                               # para-choque com retangulo branco de placa: em cima dele
		var box: AABB = holder["box"]
		var s: float = minf(minf(size.x, box.size.x * 0.92), box.size.y * 2.0 * 1.05)
		var c: Vector3 = box.get_center()
		var z: float = box.position.z
		var hit: float = PlateSpot.surface_z(tms, Vector2(c.x, c.y), s * 0.4, true, s * 0.17)
		if not is_nan(hit) and hit < z:                    # algo da peca (luzinhas) na frente do retangulo: passa na frente
			z = hit
		front = Transform3D(Basis(Vector3.UP, PI) * Basis.from_scale(Vector3(s, s * 0.5, 1.0)), Vector3(c.x, c.y, z - PlateSpot.GAP))
	else:
		var front_z: float = _front_fallback(truck, model)
		front = PlateSpot.plate_transform(tms, fy, size, true, front_z)
	var rear_on: bool = rear_mount == null or rear_mount.get_child_count() == 0   # placa decorativa (rear_plate_custom) toma o lugar
	var rear: Transform3D = PlateSpot.plate_transform(tms, ry, size, false, 0.06)
	return [front, rear, rear_on]


## Retangulo branco ("paint_white") de uma peca montada no para-choque dianteiro, se houver.
static func _bumper_plate(truck: Node3D, model: Node3D) -> Dictionary:
	var fb: Node = model.find_child("MOUNT_FRONT_BUMPER", true, false)
	if fb == null:
		return {}
	for mi in fb.find_children("*paint_white*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		if m.mesh == null or not m.visible or PlateSpot.dying(m, model):
			continue
		var box: AABB = PlateSpot.rel_transform(m, truck) * m.mesh.get_aabb()
		if box.size.x < 0.8 and box.size.y < 0.35:
			return {"box": box}
	return {}


static func _front_fallback(truck: Node3D, model: Node3D) -> float:
	var fb: Node3D = model.find_child("MOUNT_FRONT_BUMPER", true, false) as Node3D
	return PlateSpot.rel_transform(fb, truck).origin.z if fb != null else -11.6
