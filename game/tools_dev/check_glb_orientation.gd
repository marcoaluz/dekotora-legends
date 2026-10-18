extends SceneTree
## Checks that every vehicle .glb points along -Z with no stray yaw/roll (T-132).
## For each model: size of the mesh bounds, axle positions and the yaw (deg) of the line between
## the left and right wheel of each axle (0 = wheels side by side along X, as the road expects).
## Usage: godot --headless --path game -s res://tools_dev/check_glb_orientation.gd

const DIRS: Array[String] = ["res://assets/vehicles/dekotora/truck/", "res://assets/vehicles/traffic/"]


func _initialize() -> void:
	for d in DIRS:
		for f in DirAccess.get_files_at(d):
			if f.ends_with(".glb"):
				_check(d + f)
	quit(0)


func _check(path: String) -> void:
	var scene: PackedScene = load(path) as PackedScene
	if scene == null:
		print("%-70s  (nao carregou)" % path)
		return
	var root: Node3D = scene.instantiate() as Node3D
	var box := AABB()
	var first: bool = true
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		if m.mesh == null:
			continue
		var b: AABB = _rel(m, root) * m.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var wheels: Array[Vector3] = []
	for n in root.find_children("wheel_*", "Node3D", true, false):
		wheels.append(_rel(n as Node3D, root).origin)
	var worst: float = 0.0
	for a in wheels:
		for b in wheels:
			if a.x < -0.3 and b.x > 0.3 and absf(a.z - b.z) < 0.8:
				worst = maxf(worst, absf(rad_to_deg(atan2(b.z - a.z, b.x - a.x))))
	var zs: Array[float] = []
	for w in wheels:
		zs.append(snappedf(w.z, 0.1))
	print("%-70s size=(%.2f, %.2f, %.2f) z=[%.2f..%.2f] wheels=%d axle_z=%s yaw_err=%.2f deg" % [
		path.get_file(), box.size.x, box.size.y, box.size.z, box.position.z, box.end.z, wheels.size(), str(zs), worst])
	root.free()


func _rel(n: Node3D, root: Node3D) -> Transform3D:
	var t: Transform3D = n.transform
	var p: Node = n.get_parent()
	while p != null and p != root:
		if p is Node3D:
			t = (p as Node3D).transform * t
		p = p.get_parent()
	return root.transform * t
