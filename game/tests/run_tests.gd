extends SceneTree
## Executor de testes sem tela.
## Uso (na raiz do projeto):  godot --headless --path game -s res://tests/run_tests.gd
## Sai com código 0 se tudo passou, 1 se algo falhou.

const TEST_DIR := "res://tests/"


func _initialize() -> void:
	var total := 0
	var failed := 0
	var files := DirAccess.get_files_at(TEST_DIR)
	files.sort()
	for file in files:
		if not (file.begins_with("test_") and file.ends_with(".gd")) or file == "test_case.gd":
			continue
		var script: GDScript = load(TEST_DIR + file)
		for method in script.get_script_method_list():
			var name: String = method["name"]
			if not name.begins_with("test_"):
				continue
			total += 1
			var case: TestCase = script.new()
			case.call(name)
			if case.failures.is_empty():
				print("  ok    %s :: %s" % [file, name])
			else:
				failed += 1
				print("  FALHA %s :: %s" % [file, name])
				for f in case.failures:
					print("        - " + f)
	print("\n%d testes, %d falharam" % [total, failed])
	quit(1 if failed > 0 else 0)
