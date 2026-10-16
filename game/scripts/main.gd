extends Node
## Ponto de entrada. Decide entre modo cliente (vai para o menu) e modo servidor (--server).
## Argumentos do servidor: --server [--port=24600]. Argumentos de teste do cliente:
##   --bot-client --join=<codigo> --ip=<ip> --port=<porta> --name=<nome> --create  (cliente automatico headless)

var is_server: bool = false


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	is_server = "--server" in args
	if is_server:
		var port: int = Protocol.DEFAULT_PORT
		for a in args:
			if a.begins_with("--port="):
				port = int(a.substr(7))
		var err: int = Net.start_server(port)
		if err != OK:
			get_tree().quit(1)
		return
	if "--bot-client" in args:
		var bot := BotClient.new()
		bot.name = "BotClient"
		add_child(bot)
		return
	get_tree().change_scene_to_file.call_deferred("res://scenes/menu/main_menu.tscn")
