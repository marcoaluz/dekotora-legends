extends Node
## Ponto de entrada. Decide entre modo cliente (vai para o menu) e modo servidor (--server).

var is_server: bool = false


func _ready() -> void:
	is_server = "--server" in OS.get_cmdline_user_args()
	if is_server:
		print("modo servidor")        # server_main.gd entra na P60
		return
	get_tree().change_scene_to_file.call_deferred("res://scenes/menu/main_menu.tscn")
