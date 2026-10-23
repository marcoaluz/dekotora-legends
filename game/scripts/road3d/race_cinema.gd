class_name RaceCinema
extends RefCounted
## Clima da largada e da chegada (ATB-2): corte de camera lateral de 1-2 s e clarao na saida do tunel.
## A camera e posta direto (sem suavizar) enquanto o corte dura; quando acaba, a camera normal volta a seguir.

const START_CUT_S: float = 1.9           # comeca 1,6 s antes do "larga" e dura um pouco depois dele
const START_CUT_BEFORE: float = 1.6
const FINISH_CUT_S: float = 1.9
const FLASH_S: float = 0.75

var cut_t: float = 0.0
var _cut_len: float = 1.0
var _side: float = 1.0                   # +1 = lado direito do caminhao, -1 = esquerdo
var _kind: String = "start"
var _flash_rect: ColorRect
var _flash_t: float = 0.0
var _flash_peak: float = 0.6
var _flash_color: Color = Color(1.0, 0.93, 0.8)


## Cria a camada do clarao (acima do mundo, abaixo do HUD).
func build(parent: Node) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 4
	parent.add_child(layer)
	_flash_rect = ColorRect.new()
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.color = Color(1, 1, 1, 0)
	layer.add_child(_flash_rect)


func start_cut(kind: String, length: float, side: float) -> void:
	_kind = kind
	cut_t = length
	_cut_len = length
	_side = side


func active() -> bool:
	return cut_t > 0.0


## Clarao na saida do tunel: forte de dia (olho acostumado ao escuro), mais suave a noite.
func tunnel_flash(day_amount: float) -> void:
	_flash_t = FLASH_S
	_flash_peak = lerpf(0.4, 0.8, clampf(day_amount, 0.0, 1.0))
	var st: Node = Engine.get_main_loop().root.get_node_or_null("Settings")
	if st != null and bool(st.get("fx_reduce_flash")):        # T-204: "reduzir claroes" = so um toque de luz
		_flash_peak *= 0.25
	_flash_color = Color(1.0, 0.93, 0.8).lerp(Color(1.0, 0.98, 0.95), day_amount)


## Chame todo quadro: apaga o clarao.
func update_flash(dt: float) -> void:
	if _flash_rect == null:
		return
	if _flash_t > 0.0:
		_flash_t = maxf(_flash_t - dt, 0.0)
		var k: float = _flash_t / FLASH_S
		_flash_rect.color = Color(_flash_color.r, _flash_color.g, _flash_color.b, _flash_peak * k * k)
	elif _flash_rect.color.a > 0.0:
		_flash_rect.color.a = 0.0


## Posiciona a camera do corte (lateral, olhando o centro do caminhao, deslizando devagar junto com ele).
## Devolve true enquanto o corte esta ativo.
func apply_cut(dt: float, cam: Camera3D, truck: Node3D) -> bool:
	if cut_t <= 0.0:
		return false
	cut_t = maxf(cut_t - dt, 0.0)
	var prog: float = 1.0 - cut_t / _cut_len
	var in_tree: bool = cam.is_inside_tree() and truck.is_inside_tree()      # (os testes rodam fora da arvore)
	var basis: Basis = truck.global_transform.basis if in_tree else truck.basis
	var right: Vector3 = basis.x
	var fwd: Vector3 = -basis.z
	var center: Vector3 = (truck.global_position if in_tree else truck.position) + fwd * 6.0
	var ahead: float = lerpf(-3.0, 3.0, prog) if _kind == "start" else lerpf(4.0, -2.0, prog)
	var pos: Vector3 = center + right * (_side * 15.0) + fwd * ahead + Vector3.UP * (5.2 + 0.8 * prog)
	if in_tree:
		cam.global_position = pos
		cam.look_at(center + Vector3.UP * 1.5, Vector3.UP)
	else:
		cam.position = pos
	cam.fov = 36.0
	return true
