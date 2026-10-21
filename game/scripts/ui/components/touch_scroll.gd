class_name TouchScroll
extends ScrollContainer
## Lista com rolagem que funciona arrastando o dedo EM CIMA dos botoes e cartoes (T-165).
##
## Por que existe: no Godot 4.7 o ScrollContainer so rola pelo toque quando recebe o toque (o Android manda
## o toque tambem como clique de mouse emulado). Botoes, cartoes e paineis vem com mouse_filter = STOP e
## seguram o evento so para eles: o arraste comecado sobre um cartao nunca chegava na lista, so nos
## vaos entre os cartoes ("as vezes vai, as vezes nao").
##
## O que faz:
##  - todo descendente com STOP (botao, cartao, painel) passa a PASS: o botao recebe o toque e o evento
##    continua subindo ate a lista. Vale tambem para o que for criado depois (as telas redesenham a lista).
##  - zona morta de DEADZONE unidades: um toque com o dedo tremendo um pouco continua sendo toque;
##    passou disso, a lista avisa os botoes (NOTIFICATION_SCROLL_BEGIN) e o botao NAO dispara ao soltar.
##  - a propria lista fica STOP: o toque nela nao vaza para o palco 3D/telas atras.
## Controles que tem arraste proprio (slider, barra, campo de texto, outra lista) continuam STOP.
## Mouse, roda do mouse, teclado e controle continuam iguais.

## Distancia (unidades da tela base 960x540, ~2 px fisicos no celular) antes de o arraste virar rolagem.
const DEADZONE: int = 10
## Classes que mantem STOP (tem arraste proprio) e cujo conteudo nao e mexido.
const KEEP_STOP: Array[String] = ["Range", "LineEdit", "TextEdit", "ScrollContainer", "ItemList", "Tree", "GraphEdit"]


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	scroll_deadzone = DEADZONE


func _enter_tree() -> void:
	var tree: SceneTree = get_tree()
	if not tree.node_added.is_connected(_on_node_added):
		tree.node_added.connect(_on_node_added)
	for c in get_children():
		_apply_tree(c)


func _exit_tree() -> void:
	var tree: SceneTree = get_tree()
	if tree.node_added.is_connected(_on_node_added):
		tree.node_added.disconnect(_on_node_added)


func _on_node_added(n: Node) -> void:
	if n is Control and is_ancestor_of(n) and _reachable(n):
		pass_touch(n as Control)


## Aplica em `n` e em todos os descendentes (o que ja existia antes de a lista entrar na arvore).
func _apply_tree(n: Node) -> void:
	if n is Window:
		return
	if n is Control:
		pass_touch(n as Control)
		if _keeps_stop(n):
			return
	for c in n.get_children():
		_apply_tree(c)


## true se nenhum ancestral entre `n` e a lista e janela ou controle com arraste proprio.
func _reachable(n: Node) -> bool:
	var p: Node = n.get_parent()
	while p != null and p != self:
		if p is Window or _keeps_stop(p):
			return false
		p = p.get_parent()
	return p == self


static func _keeps_stop(n: Node) -> bool:
	for k in KEEP_STOP:
		if n.is_class(k):
			return true
	return false


## STOP -> PASS (IGNORE e PASS ficam como estao). Publico para quem montar listas sem TouchScroll.
static func pass_touch(c: Control) -> void:
	if c.mouse_filter == Control.MOUSE_FILTER_STOP and not _keeps_stop(c):
		c.mouse_filter = Control.MOUSE_FILTER_PASS
