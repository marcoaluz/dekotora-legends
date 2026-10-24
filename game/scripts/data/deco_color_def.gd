class_name DecoColorDef
extends Resource
## Cor L/R das pecas da oficina (T-211, botao "Alterar cor - L/R" das capturas): um conjunto de materiais por PAPEL
## da peca (estrutura, painel, LED, neon). Tabela em game/data/deco_colors/*.tres (proposta: docs/REFERENCIA_PECAS.md,
## secao 18). Trocar para uma cor custa `price` (a cor de fabrica da peca e de graca).

const DIR := "res://data/deco_colors/"

@export var id: StringName
@export var display_key: String = ""
@export var tier: StringName = &"comum"         # comum | metalica | neon
@export var price: int = 0
@export var body: String = "deco_black"         # nomes de AccessoryMaterials
@export var trim: String = "deco_black"
@export var led: String = "lamp_green"
@export var neon: String = "lamp_cyan"
@export var swatch_a: Color = Color.BLACK       # amostra no botao (estrutura | luz)
@export var swatch_b: Color = Color.CYAN

static var _all: Array[DecoColorDef] = []


## Material de cada papel: deco_body, deco_trim, deco_led, deco_neon.
func roles() -> Dictionary:
	return {"deco_body": body, "deco_trim": trim, "deco_led": led, "deco_neon": neon}


static func all() -> Array[DecoColorDef]:
	if _all.is_empty():
		var ids: Array = []
		for f in DirAccess.get_files_at(DIR):
			var n: String = f.trim_suffix(".remap")
			if n.ends_with(".tres"):
				ids.append(n)
		ids.sort()
		for f in ids:
			var d: DecoColorDef = load(DIR + String(f)) as DecoColorDef
			if d != null:
				_all.append(d)
		_all.sort_custom(func(a: DecoColorDef, b: DecoColorDef) -> bool:
			return a.price < b.price if a.price != b.price else String(a.id) < String(b.id))
	return _all


static func find(cid: String) -> DecoColorDef:
	for d in all():
		if String(d.id) == cid:
			return d
	return null
