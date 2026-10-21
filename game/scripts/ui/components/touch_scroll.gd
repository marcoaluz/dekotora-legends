class_name TouchScroll
extends ScrollContainer
## Lista com rolagem que funciona arrastando o dedo (ou o mouse com o botao apertado) EM CIMA dos botoes e
## cartoes (T-165, refeita na T-177).
##
## Por que existe: no Godot 4.7 o ScrollContainer so rola pelo toque quando recebe o toque (o Android manda
## o toque tambem como clique de mouse emulado). Botoes, cartoes e paineis vem com mouse_filter = STOP e
## seguram o evento so para eles: o arraste comecado sobre um cartao nunca chegava na lista.
##
## T-177: o arraste do proprio ScrollContainer ficava PRESO quando o botao clicado redesenhava a lista (a garagem
## faz isso em todo clique): o "soltar" morria junto com o botao e a lista passava a seguir a seta do mouse sem
## botao apertado, desfazendo ate a roda do mouse. Agora o arraste e feito aqui:
##  - so rola com o botao esquerdo/dedo apertado (o movimento sem botao encerra um arraste que perdeu o "soltar");
##  - vale no PC com mouse e no celular (o toque chega como mouse emulado), sem depender da "tela de toque";
##  - zona morta de DEADZONE: dedo tremendo continua sendo toque; passou disso, a lista avisa os botoes
##    (NOTIFICATION_SCROLL_BEGIN) e o botao NAO dispara ao soltar; `scrolling()` diz isso para os cartoes;
##  - soltar com o dedo correndo da um embalo (FLING); tocar durante o embalo so para a lista;
##  - roda do mouse rola PAGE_WHEEL da altura visivel por clique e fica com o evento (nao vaza para a camera 3D).
## Todo descendente com STOP (botao, cartao, painel) passa a PASS (vale tambem para o que for criado depois).
## Controles com arraste proprio (slider, barra, campo de texto, outra lista) continuam STOP.

## Distancia (unidades da tela base 960x540, ~2 px fisicos no celular) antes de o arraste virar rolagem.
const DEADZONE: int = 10
## Embalo ao soltar: perde FLING_DECEL unidades/s por segundo; abaixo de FLING_MIN nao embala; teto FLING_MAX.
const FLING_DECEL: float = 2600.0
const FLING_MIN: float = 120.0
const FLING_MAX: float = 3200.0
## Fracao da altura visivel rolada por clique da roda do mouse (o ScrollContainer do Godot usa 1/8).
const PAGE_WHEEL: float = 0.125
## Classes que mantem STOP (tem arraste proprio) e cujo conteudo nao e mexido.
const KEEP_STOP: Array[String] = ["Range", "LineEdit", "TextEdit", "ScrollContainer", "ItemList", "Tree", "GraphEdit"]

var _down: bool = false            # botao/dedo apertado que comecou nesta lista
var _beyond: bool = false          # passou da zona morta: e rolagem, nao toque
var _from: Vector2 = Vector2.ZERO  # rolagem no inicio do arraste
var _accum: Vector2 = Vector2.ZERO # quanto o dedo andou (sinal da rolagem)
var _vel: Vector2 = Vector2.ZERO   # velocidade da rolagem (unidades/s), para o embalo
var _last_us: int = 0
var _fling: Vector2 = Vector2.ZERO


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	scroll_deadzone = DEADZONE
	set_process(false)


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
	_stop()


## true enquanto o dedo/mouse esta rolando a lista (ou ela corre no embalo): um cartao nao deve tratar como toque.
func scrolling() -> bool:
	return _beyond


# ---------------------------------------------------------------- entrada

## Roda antes do ScrollContainer do motor: clique esquerdo e movimento ficam aqui (o arraste nativo nunca comeca,
## entao nunca fica preso); a roda tambem (rola sempre e nao vaza para tras da lista).
func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb: InputEventMouseButton = ev
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				accept_event()
				if mb.pressed:
					_press()
				else:
					_release()
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT:
				accept_event()
				if mb.pressed:
					_wheel(mb)
	elif ev is InputEventMouseMotion and _down:
		var mm: InputEventMouseMotion = ev
		accept_event()
		if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			_cancel()                      # o "soltar" se perdeu (botao redesenhado): sem botao, a lista nao anda
			return
		_motion(mm.relative)


func _press() -> void:
	var was_flinging: bool = _fling != Vector2.ZERO
	_fling = Vector2.ZERO
	set_process(false)
	_down = true
	_from = _scroll()
	_accum = Vector2.ZERO
	_vel = Vector2.ZERO
	_last_us = Time.get_ticks_usec()
	if was_flinging:                       # tocar na lista correndo so para a lista: nao seleciona o cartao
		_beyond = true
		propagate_notification(NOTIFICATION_SCROLL_BEGIN)
	else:
		_beyond = false


func _motion(rel: Vector2) -> void:
	var d: Vector2 = -_axes(rel)
	if d == Vector2.ZERO:
		return
	var now: int = Time.get_ticks_usec()
	var dt: float = float(now - _last_us) / 1000000.0
	_last_us = now
	_accum += d
	if not _beyond:
		if _accum.length() < float(scroll_deadzone):
			return
		_beyond = true
		_from = _scroll() - _accum         # comeca a rolar daqui: a lista nao pula a zona morta
		scroll_started.emit()
		propagate_notification(NOTIFICATION_SCROLL_BEGIN)
	var target: Vector2 = (_from + _accum).clamp(Vector2.ZERO, _max_scroll())
	_accum = target - _from                # passou do fim e voltou: responde na hora
	_set_scroll(target)
	if dt > 0.0:
		_vel = _vel.lerp((d / dt).limit_length(FLING_MAX), 0.5)


func _release() -> void:
	if not _down:
		return
	_down = false
	var idle: float = float(Time.get_ticks_usec() - _last_us) / 1000000.0
	if _beyond and idle < 0.1 and _vel.length() >= FLING_MIN:
		_fling = _vel
		set_process(true)
	else:
		_stop()


## Arraste perdido ou interrompido: para tudo, sem embalo.
func _cancel() -> void:
	_down = false
	_stop()


func _stop() -> void:
	_fling = Vector2.ZERO
	set_process(false)
	if _beyond:
		_beyond = false
		scroll_ended.emit()
		propagate_notification(NOTIFICATION_SCROLL_END)


func _process(delta: float) -> void:
	if _fling == Vector2.ZERO:
		_stop()
		return
	var before: Vector2 = _scroll()
	var target: Vector2 = (before + _fling * delta).clamp(Vector2.ZERO, _max_scroll())
	_set_scroll(target)
	var speed: float = _fling.length() - FLING_DECEL * delta
	if speed <= 0.0 or target.is_equal_approx(before):
		_stop()
	else:
		_fling = _fling.normalized() * speed


func _wheel(mb: InputEventMouseButton) -> void:
	_fling = Vector2.ZERO
	var horiz: bool = mb.button_index in [MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT] or mb.shift_pressed \
			or vertical_scroll_mode == SCROLL_MODE_DISABLED
	var sgn: float = -1.0 if mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT] else 1.0
	var f: float = mb.factor if mb.factor > 0.0 else 1.0
	var step: Vector2 = Vector2(sgn * size.x * PAGE_WHEEL * f, 0.0) if horiz else Vector2(0.0, sgn * size.y * PAGE_WHEEL * f)
	_set_scroll((_scroll() + _axes(step)).clamp(Vector2.ZERO, _max_scroll()))


# ---------------------------------------------------------------- rolagem

## Zera o eixo desligado (lista so vertical nao anda de lado).
func _axes(v: Vector2) -> Vector2:
	return Vector2(v.x if horizontal_scroll_mode != SCROLL_MODE_DISABLED else 0.0,
			v.y if vertical_scroll_mode != SCROLL_MODE_DISABLED else 0.0)


func _scroll() -> Vector2:
	return Vector2(get_h_scroll_bar().value, get_v_scroll_bar().value)


func _max_scroll() -> Vector2:
	var h: ScrollBar = get_h_scroll_bar()
	var v: ScrollBar = get_v_scroll_bar()
	return Vector2(maxf(h.max_value - h.page, 0.0), maxf(v.max_value - v.page, 0.0))


func _set_scroll(p: Vector2) -> void:
	if horizontal_scroll_mode != SCROLL_MODE_DISABLED:
		get_h_scroll_bar().value = p.x
	if vertical_scroll_mode != SCROLL_MODE_DISABLED:
		get_v_scroll_bar().value = p.y


# ---------------------------------------------------------------- toque passa pelos filhos

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


## Lista TouchScroll que contem `c` (ou null): os cartoes perguntam se o dedo estava rolando.
static func of(c: Node) -> TouchScroll:
	var p: Node = c.get_parent()
	while p != null:
		if p is TouchScroll:
			return p as TouchScroll
		p = p.get_parent()
	return null
