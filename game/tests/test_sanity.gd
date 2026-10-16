extends TestCase
## Teste de exemplo: garante que o executor funciona. Pode apagar quando houver testes reais.


func test_math_basics() -> void:
	check_eq(2 + 2, 4, "soma")
	check_near(1.0 / 3.0, 0.333, 0.001, "divisão")


func test_project_settings() -> void:
	check_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 960, "largura base")
	check_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 540, "altura base")
