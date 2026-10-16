class_name Fx3D
extends Node3D
## Efeitos de batida em 3D (P35): faiscas no contato, fumaca quando o motor esta ferido e pecas
## quebradas caindo e ficando para tras na pista. Tudo com CPUParticles3D / nos simples
## (funciona no renderizador Compatibility e no celular).

const ZONE_OFFSETS: Dictionary = {
	"front": Vector3(0, 0.9, -11.5), "rear": Vector3(0, 0.9, -0.1),
	"left": Vector3(-1.25, 0.9, -6.0), "right": Vector3(1.25, 0.9, -6.0), "roof": Vector3(0, 3.2, -10.0),
}

var _spark_mesh: SphereMesh
var _spark_mat: StandardMaterial3D
var _smoke_mat: StandardMaterial3D
var _debris: Array[Dictionary] = []     # {node, vel, spin, ttl}
var _smoke: Dictionary = {}             # indice do caminhao -> CPUParticles3D


func _ready() -> void:
	_spark_mesh = SphereMesh.new()
	_spark_mesh.radius = 0.07
	_spark_mesh.height = 0.14
	_spark_mesh.radial_segments = 6
	_spark_mesh.rings = 3
	_spark_mat = StandardMaterial3D.new()
	_spark_mat.albedo_color = Color("#fff35c")
	_spark_mat.emission_enabled = true
	_spark_mat.emission = Color("#ffb347")
	_spark_mat.emission_energy_multiplier = 6.0
	_spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_smoke_mat = StandardMaterial3D.new()
	_smoke_mat.albedo_color = Color(0.25, 0.25, 0.28, 0.55)
	_smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_smoke_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED


func zone_point(truck: Node3D, zone: String) -> Vector3:
	return truck.global_transform * (ZONE_OFFSETS.get(zone, Vector3(0, 1, -6)) as Vector3)


## Rajada de faiscas; `force` 1..15 (m/s de impacto) define a quantidade.
func sparks(world_pos: Vector3, force: float) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = clampi(int(8.0 + force * 3.0), 8, 60)
	p.lifetime = 0.6
	p.mesh = _spark_mesh
	p.material_override = _spark_mat
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 8.0 + force * 0.4
	p.gravity = Vector3(0, -14, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	add_child(p)
	p.global_position = world_pos
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)


## Peca quebrada: um bloco cromado que cai e fica na pista (o caminhao segue em frente).
func debris(world_pos: Vector3, vel: Vector3, size: Vector3 = Vector3(0.9, 0.4, 0.5)) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#d8dee8")
	m.metallic = 1.0
	m.roughness = 0.12
	mi.material_override = m
	add_child(mi)
	mi.global_position = world_pos
	_debris.append({"node": mi, "vel": vel + Vector3(randf_range(-2, 2), randf_range(2, 5), 0), "spin": Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6)), "ttl": 8.0, "ground": world_pos.y})


## Fumaca continua no capo; `level` 0 (nada) .. 1 (muita).
func set_smoke(index: int, truck: Node3D, level: float) -> void:
	var p: CPUParticles3D = _smoke.get(index)
	if level <= 0.05:
		if p != null:
			p.emitting = false
		return
	if p == null:
		p = CPUParticles3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(1.0, 1.0)
		p.mesh = q
		p.material_override = _smoke_mat
		p.lifetime = 1.6
		p.direction = Vector3(0, 1, 0.6)
		p.spread = 20.0
		p.initial_velocity_min = 1.5
		p.initial_velocity_max = 3.0
		p.gravity = Vector3(0, 0.6, 0)
		p.scale_amount_min = 0.8
		p.scale_amount_max = 2.2
		p.local_coords = false
		add_child(p)
		_smoke[index] = p
	p.amount = int(6 + level * 26.0)
	p.emitting = true
	p.global_position = truck.global_transform * Vector3(0, 2.4, -11.0)


func _process(delta: float) -> void:
	for i in range(_debris.size() - 1, -1, -1):
		var d: Dictionary = _debris[i]
		var n: Node3D = d["node"]
		var v: Vector3 = d["vel"]
		v.y -= 18.0 * delta
		n.global_position += v * delta
		if n.global_position.y < float(d["ground"]) - 0.3 + 0.2:
			n.global_position.y = float(d["ground"]) - 0.1
			v = Vector3(v.x * 0.5, absf(v.y) * 0.25 if absf(v.y) > 2.0 else 0.0, v.z * 0.7)
		d["vel"] = v
		n.rotation += (d["spin"] as Vector3) * delta * (1.0 if v.length() > 0.5 else 0.0)
		d["ttl"] = float(d["ttl"]) - delta
		if float(d["ttl"]) <= 0.0:
			n.queue_free()
			_debris.remove_at(i)
