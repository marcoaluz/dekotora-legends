class_name SceneFader
extends CanvasLayer
## Transicao suave entre telas: escurece, troca a cena e clareia de novo. Fica na raiz da arvore
## (sobrevive a troca de cena) e se apaga sozinho no fim. Uso: `SceneFader.go(get_tree(), "res://...tscn")`.
## T-208: a cena nova e lida numa thread (ResourceLoader.load_threaded_request) enquanto a tela escura mostra a
## neblina roxa da abertura (LoadingFog) se a leitura passar de FOG_AFTER_S; `prefetch()` comeca a leitura antes
## (o menu principal pede a corrida em segundo plano, entao o clique em Continuar ja encontra a cena lida).

const FADE_S: float = 0.18
const FOG_AFTER_S: float = 0.2
const FOG_IN_S: float = 0.35
## Cenas pesadas (montar leva segundos e a tela congela): fundo preto e neblina desde o clique, igual a abertura.
const HEAVY: Array[String] = ["res://scenes/race/race3d.tscn"]

static var _requested: Dictionary = {}          # path -> true: leitura em segundo plano pedida e ainda nao usada

var _root: Control
var _fog: Control
var _fog_a: float = 0.0
var _wait: float = -1.0                         # s esperando a leitura (-1 = nao esta esperando)


static func go(tree: SceneTree, path: String) -> void:
	if tree.root.has_node("SceneFader"):           # ja tem uma transicao em andamento
		return
	LoadClock.go()                                 # T-208: cronometro do clique ate o 1o quadro (LOAD_T208)
	var f := SceneFader.new()
	f.name = "SceneFader"
	f.layer = 100
	f.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child(f)
	f._run(path)


## T-208: comeca a ler `path` em segundo plano (sem travar a tela); o proximo go() para ela usa o resultado.
static func prefetch(path: String) -> void:
	if _requested.has(path) or ResourceLoader.has_cached(path):
		return
	if ResourceLoader.load_threaded_request(path, "PackedScene", true) == OK:
		_requested[path] = true


func _run(path: String) -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP     # bloqueia cliques durante a troca
	_root.modulate.a = 0.0
	add_child(_root)
	var heavy: bool = path in HEAVY
	if heavy:
		_fog_a = 1.0
	var rect := ColorRect.new()
	rect.color = Color.BLACK if heavy else UiTheme.NIGHT
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(rect)
	_fog = Control.new()
	_fog.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fog.draw.connect(func() -> void: LoadingFog.draw_on(_fog, _fog.size, LoadingFog.now(), _fog_a))
	_root.add_child(_fog)
	var tw: Tween = create_tween()
	tw.tween_property(_root, "modulate:a", 1.0, FADE_S)
	await tw.finished
	LoadClock.mark("fader_escuro")
	var packed: PackedScene = null
	if not _requested.has(path) and not ResourceLoader.has_cached(path):
		prefetch(path)
	if _requested.has(path):
		_wait = 0.0
		while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await get_tree().process_frame
		_requested.erase(path)
		packed = ResourceLoader.load_threaded_get(path) as PackedScene
		_wait = -1.0
	LoadClock.mark("cena_lida")
	if packed != null:
		get_tree().change_scene_to_packed(packed)
	else:
		get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	var tw2: Tween = create_tween()
	tw2.tween_property(_root, "modulate:a", 0.0, FADE_S * 1.5)
	await tw2.finished
	queue_free()


func _process(delta: float) -> void:
	if _wait >= 0.0:
		_wait += delta
		if _wait > FOG_AFTER_S:
			_fog_a = minf(_fog_a + delta / FOG_IN_S, 1.0)
	if _fog != null and _fog_a > 0.0:
		_fog.queue_redraw()
