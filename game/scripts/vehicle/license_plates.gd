class_name LicensePlates
extends AtlasQuads
## Placas de veiculo de TODOS os veiculos de uma cena numa chamada de desenho so: cada placa segue um no
## (caminhao ou carro) com um transform local fixo. O texto vem de PlateCatalog (atlas de 64 placas);
## `pick()` nao repete placa enquanto houver celula livre do estilo.

const SIZE_TRUCK := Vector2(0.40, 0.20)       # placa grande (caminhao e onibus); a proporcao do atlas e 2:1
const SIZE_CAR := Vector2(0.33, 0.165)        # placa media japonesa (330 x 165 mm)

var _anchors: Array[Node3D] = []
var _local: Array[Transform3D] = []
var _on: Array[bool] = []
var _used: Dictionary = {}
var _dirty: bool = false
static var HIDDEN: Transform3D = Transform3D(Basis.from_scale(Vector3.ZERO), Vector3(0, -1000, 0))


func _init() -> void:
	setup(load(PlateCatalog.ATLAS) as Texture2D, 1.0)
	process_priority = 100                    # depois de quem move os veiculos
	extra_cull_margin = 16.0


## Celula para um veiculo do estilo `style` (PlateCatalog.Style) com a semente `key`.
func pick(style: int, key: int) -> int:
	return PlateCatalog.pick(style, key, _used)


## Placa nova presa a `anchor` (transform local do PlateSpot); devolve o indice.
func add_plate(anchor: Node3D, local: Transform3D, cell: int) -> int:
	_anchors.append(anchor)
	_local.append(local)
	_on.append(true)
	_used[posmod(cell, PlateCatalog.COUNT)] = true
	add_quad(HIDDEN, PlateCatalog.uv_rect(cell))
	_dirty = true
	return _anchors.size() - 1


## Troca posicao, visibilidade e (opcional) a celula de uma placa ja criada.
func set_plate(i: int, local: Transform3D, on: bool, cell: int = -1) -> void:
	_local[i] = local
	_on[i] = on
	if cell >= 0:
		set_quad_uv(i, PlateCatalog.uv_rect(cell))


func plate_count() -> int:
	return _anchors.size()


## Transform no mundo da placa `i` (para testes e capturas).
func plate_global(i: int) -> Transform3D:
	return _anchors[i].global_transform * _local[i]


func _process(_delta: float) -> void:
	if _dirty:
		_dirty = false
		commit()
	var inv: Transform3D = global_transform.affine_inverse()     # as instancias ficam no espaco deste no
	for i in _anchors.size():
		var a: Node3D = _anchors[i]
		var ok: bool = _on[i] and is_instance_valid(a) and a.is_inside_tree() and a.is_visible_in_tree()
		move_quad(i, inv * a.global_transform * _local[i] if ok else HIDDEN)
