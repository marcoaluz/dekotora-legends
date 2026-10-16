class_name SceneFader
extends CanvasLayer
## Transicao suave entre telas: escurece, troca a cena e clareia de novo. Fica na raiz da arvore
## (sobrevive a troca de cena) e se apaga sozinho no fim. Uso: `SceneFader.go(get_tree(), "res://...tscn")`.

const FADE_S: float = 0.18

var _rect: ColorRect


static func go(tree: SceneTree, path: String) -> void:
	if tree.root.has_node("SceneFader"):           # ja tem uma transicao em andamento
		return
	var f := SceneFader.new()
	f.name = "SceneFader"
	f.layer = 100
	tree.root.add_child(f)
	f._run(path)


func _run(path: String) -> void:
	_rect = ColorRect.new()
	_rect.color = Color(UiTheme.NIGHT, 0.0)
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP     # bloqueia cliques durante a troca
	add_child(_rect)
	var tw: Tween = create_tween()
	tw.tween_property(_rect, "color:a", 1.0, FADE_S)
	await tw.finished
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	var tw2: Tween = create_tween()
	tw2.tween_property(_rect, "color:a", 0.0, FADE_S * 1.5)
	await tw2.finished
	queue_free()
