class_name DecoLightDef
extends Resource
## Cor das LUZES das pecas da oficina (T-214), separada da cor da estrutura (DecoColorDef): o jogador escolhe a cor
## dos LEDs e a do neon de cada peca. Tabela em game/data/deco_lights/*.tres. Trocar custa `price` (voltar para a luz
## de fabrica da cor da peca e de graca). Precos sao proposta (docs/BALANCEAMENTO.md, a confirmar pelo Marco).

const DIR := "res://data/deco_lights/"
## Papeis de luz de uma peca da oficina que podem ser trocados.
const ROLES: Array[String] = ["led", "neon"]

@export var id: StringName
@export var display_key: String = ""
@export var lamp: String = "lamp_cyan"          # nome em AccessoryMaterials (tem de piscar: LightPatterns.ANIMATED)
@export var price: int = 0
@export var order: int = 0                      # ordem na grade da garagem (arco-iris)
@export var swatch: Color = Color.CYAN

static var _all: Array[DecoLightDef] = []


static func all() -> Array[DecoLightDef]:
	if _all.is_empty():
		var files: Array = []
		for f in DirAccess.get_files_at(DIR):
			var n: String = f.trim_suffix(".remap")
			if n.ends_with(".tres"):
				files.append(n)
		files.sort()
		for f in files:
			var d: DecoLightDef = load(DIR + String(f)) as DecoLightDef
			if d != null:
				_all.append(d)
		_all.sort_custom(func(a: DecoLightDef, b: DecoLightDef) -> bool:
			return a.order < b.order if a.order != b.order else String(a.id) < String(b.id))
	return _all


static func find(lid: String) -> DecoLightDef:
	for d in all():
		if String(d.id) == lid:
			return d
	return null


## Luz cujo material e `lamp` (para achar a luz de fabrica de uma cor de peca).
static func by_lamp(lamp_name: String) -> DecoLightDef:
	for d in all():
		if d.lamp == lamp_name:
			return d
	return null
