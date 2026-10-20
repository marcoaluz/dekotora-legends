extends SceneTree
## Executor de testes sem tela.
## Uso (na raiz do projeto):  godot --headless --path game -s res://tests/run_tests.gd
## Sai com código 0 se tudo passou, 1 se algo falhou.
## Arquivos com `const IN_TREE := true` rodam no 1o quadro (a arvore de cena ja existe: _ready das cenas roda,
## caminhos /root/... funcionam). Usado pelos testes que montam a corrida de verdade (T-156).

const TEST_DIR := "res://tests/"

var _total: int = 0
var _failed: int = 0
var _later: Array[String] = []


func _initialize() -> void:
	# os testes criam perfis novos: grava num arquivo separado para nunca apagar o perfil do jogador
	var gs: Node = root.get_node_or_null("GameState")
	if gs != null:
		gs.save_path = "user://test_profile.json"
	var files := DirAccess.get_files_at(TEST_DIR)
	files.sort()
	var only: String = ""                       # -- --only=test_lane_sections: roda so os arquivos com esse trecho no nome
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	for file in files:
		if not (file.begins_with("test_") and file.ends_with(".gd")) or file == "test_case.gd":
			continue
		if only != "" and not file.contains(only):
			continue
		var script: GDScript = load(TEST_DIR + file)
		if bool(script.get_script_constant_map().get("IN_TREE", false)):
			_later.append(file)
			continue
		_run_file(file, script)
	if _later.is_empty():
		_finish()


func _process(_delta: float) -> bool:
	if _later.is_empty():
		return false
	var files: Array[String] = _later.duplicate()
	_later.clear()
	for file in files:
		_run_file(file, load(TEST_DIR + file))
	_finish()
	return false


func _run_file(file: String, script: GDScript) -> void:
	for method in script.get_script_method_list():
		var name: String = method["name"]
		if not name.begins_with("test_"):
			continue
		_total += 1
		var case: TestCase = script.new()
		case.call(name)
		if case.failures.is_empty():
			print("  ok    %s :: %s" % [file, name])
		else:
			_failed += 1
			print("  FALHA %s :: %s" % [file, name])
			for f in case.failures:
				print("        - " + f)


func _finish() -> void:
	print("\n%d testes, %d falharam" % [_total, _failed])
	quit(1 if _failed > 0 else 0)
