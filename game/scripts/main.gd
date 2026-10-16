extends Node2D
## Ponto de entrada. Decide entre modo cliente e modo servidor (--server).
## Na Fase 0 tambem mostra a tela de teste da P02 (titulo, FPS, quadrado que segue o dedo/mouse).

var is_server: bool = false

@onready var _fps: Label = $Fps
@onready var _marker: ColorRect = $Marker


func _ready() -> void:
	is_server = "--server" in OS.get_cmdline_user_args()
	if is_server:
		print("modo servidor")


func _process(_delta: float) -> void:
	_fps.text = "FPS: %d" % Engine.get_frames_per_second()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventScreenDrag or event is InputEventScreenTouch:
		var p: Vector2 = event.position
		_marker.position = (p - _marker.size * 0.5).round()
