class_name TruckNode
extends Node3D
## Caminhao 3D: instancia o .glb (PBR), gira as rodas conforme a velocidade, liga farois e
## lanternas. A origem do no e a TRASEIRA do bau no chao; a frente aponta para -Z (convencao Godot).
## Pecas (acessorios) entram nos nos MOUNT_* do modelo.

const MODEL_PATH := "res://assets/vehicles/dekotora/truck/dekotora_truck_base.glb"
const WHEEL_RADIUS: float = 0.52

var model: Node3D
var _wheels: Array[Node3D] = []
var _headlight: SpotLight3D
var _tail_glow: OmniLight3D
var _spin: float = 0.0
var tint: Color = Color.WHITE


func _ready() -> void:
	var scene: PackedScene = load(MODEL_PATH) as PackedScene
	if scene == null:
		push_warning("TruckNode: modelo nao encontrado: " + MODEL_PATH)
		return
	model = scene.instantiate() as Node3D
	add_child(model)
	for n in model.find_children("wheel_*", "Node3D", true, false):
		_wheels.append(n as Node3D)
	_headlight = SpotLight3D.new()
	_headlight.position = Vector3(0, 1.2, -11.6)
	_headlight.rotation_degrees = Vector3(-4, 0, 0)
	_headlight.spot_range = 70.0
	_headlight.spot_angle = 32.0
	_headlight.light_energy = 3.0
	_headlight.light_color = Color(1.0, 0.93, 0.78)
	_headlight.shadow_enabled = false
	add_child(_headlight)


## Gira as rodas e aplica a escala de velocidade; `dt` em segundos reais.
func animate(speed: float, dt: float, steer: float = 0.0) -> void:
	_spin += speed / WHEEL_RADIUS * dt
	for w in _wheels:
		var r: Basis = Basis(Vector3.RIGHT, -_spin)
		var base_yaw: float = 0.0
		if String(w.name).begins_with("wheel_f"):
			base_yaw = -steer * 0.35
		w.transform.basis = Basis(Vector3.UP, base_yaw) * r


func set_headlights(on: bool) -> void:
	if _headlight:
		_headlight.visible = on


## Tinge a pintura branca (rivais de cores diferentes) sem duplicar o modelo.
func set_paint_color(c: Color) -> void:
	tint = c
	if model == null:
		return
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		if String(m.name).contains("paint_white"):
			var mat: StandardMaterial3D = (m.get_active_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
			mat.albedo_color = c
			m.material_override = mat
