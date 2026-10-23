extends SceneTree
## T-208: mede o caminho de verdade "menu -> Continuar -> abertura do duelo" (LOAD_T208 no terminal).
## Abre o menu principal, espera --wait=S segundos (o menu le a corrida em segundo plano) e chama Continuar.
## Usa um perfil de teste (nao mexe no perfil do Marco) com a 1a rota da campanha.
## Uso: godot --path game --rendering-method gl_compatibility --resolution 1280x576 -s res://tools_dev/measure_load_t208.gd
##          -- --wait=3 [--no-prefetch] --quality=1 --life=off --quit-at=20

var _wait: float = 3.0
var _quit_at: float = 22.0
var _t: float = 0.0
var _clicked: bool = false
var _menu: Node


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--wait="):
			_wait = float(a.substr(7))
		elif a.begins_with("--quit-at="):
			_quit_at = float(a.substr(10))
	var gs: Node = root.get_node("GameState")
	gs.save_path = "user://test_profile_t208.json"
	gs.new_profile()
	gs.last_duel_key = ""
	change_scene_to_file("res://scenes/menu/main_menu.tscn")


func _process(delta: float) -> bool:
	_t += minf(delta, 0.25)
	if not _clicked and _t >= _wait and current_scene != null and current_scene.has_method("_continue"):
		_clicked = true
		print("MEASURE_T208 clique em Continuar (%.1f s no menu)" % _t)
		current_scene.call("_continue")
	return _t >= _quit_at
