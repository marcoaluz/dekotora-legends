class_name PlateCatalog
extends RefCounted
## Placas de veiculo japonesas FICTICIAS (formato real: cidade + classe em cima, kana + numero embaixo).
## As 64 placas ficam desenhadas num atlas so (assets/textures/plates_atlas.png, gerado por
## tools_dev/make_sign_atlases.gd); o texto de cada celula sai daqui, de forma deterministica.
## Estilos (cores reais do Japao): particular branca/verde, kei amarela, comercial verde/branca, kei comercial preta.

enum Style { WHITE, YELLOW, GREEN, BLACK }

const ATLAS := "res://assets/textures/plates_atlas.png"
const COLS: int = 8
const ROWS: int = 8
const CELL_PX := Vector2i(128, 64)
const COUNT: int = COLS * ROWS
## Primeira celula e quantidade de cada estilo (somam COUNT).
const RANGES: Array = [[0, 24], [24, 12], [36, 20], [56, 8]]
## Cidades de Kanto/Tokai (nomes de lugar; a combinacao com os numeros e inventada).
const REGIONS: PackedStringArray = ["品川", "練馬", "足立", "多摩", "横浜", "川崎", "湘南", "相模",
	"千葉", "習志野", "大宮", "所沢", "沼津", "富士山", "伊豆", "山梨"]
const CLASSES: Array = [["300", "330", "301", "500", "530", "501", "580"], ["580", "581", "50", "480", "40"],
	["100", "130", "800", "88", "200", "230", "11"], ["480", "40", "41", "480"]]
const KANA_PRIVATE := "さすせそたちつてとなにぬねのはひふほまみむめもやゆよらりるろ"
const KANA_BUSINESS := "あいうえかきくけこを"
## Cores: fundo, texto.
const COLORS: Array = [[Color("#f2f3ee"), Color("#0e5b33")], [Color("#f3c816"), Color("#1a1a1a")],
	[Color("#11603a"), Color("#f2f3ee")], [Color("#161616"), Color("#f0c419")]]
const SEED: int = 130


## Dados da placa da celula `cell`: {style, region, cls, kana, number, text}.
static func plate(cell: int) -> Dictionary:
	var c: int = posmod(cell, COUNT)
	var style: int = style_of(c)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED * 100003 + c
	var cls_list: Array = CLASSES[style]
	var kana_src: String = KANA_PRIVATE if style == Style.WHITE or style == Style.YELLOW else KANA_BUSINESS
	var region: String = REGIONS[rng.randi_range(0, REGIONS.size() - 1)]
	var cls: String = String(cls_list[rng.randi_range(0, cls_list.size() - 1)])
	var kana: String = kana_src[rng.randi_range(0, kana_src.length() - 1)]
	var n: int = rng.randi_range(1, 9999)
	if rng.randf() < 0.6:
		n = rng.randi_range(1000, 9999)             # a maioria tem 4 digitos
	var number: String = format_number(n)
	return {"style": style, "region": region, "cls": cls, "kana": kana, "number": number,
		"text": "%s %s %s %s" % [region, cls, kana, number]}


## 1234 -> "12-34"; 123 -> "・123"; 12 -> "・・12"; 1 -> "・・・1" (pontos no lugar dos digitos que faltam).
static func format_number(n: int) -> String:
	n = clampi(n, 1, 9999)
	if n >= 1000:
		return "%02d-%02d" % [n / 100, n % 100]
	var s: String = str(n)
	return "・".repeat(4 - s.length()) + s


static func style_of(cell: int) -> int:
	var c: int = posmod(cell, COUNT)
	for s in RANGES.size():
		if c >= int(RANGES[s][0]) and c < int(RANGES[s][0]) + int(RANGES[s][1]):
			return s
	return Style.WHITE


## Celula de um estilo a partir de uma chave qualquer (semente do veiculo); `used` evita repetir enquanto
## houver celula livre do estilo (o dicionario e atualizado).
static func pick(style: int, key: int, used: Dictionary) -> int:
	var r: Array = RANGES[clampi(style, 0, RANGES.size() - 1)]
	var first: int = int(r[0])
	var n: int = int(r[1])
	var start: int = posmod(hash(key) , n)
	for k in n:
		var c: int = first + (start + k * 7) % n             # 7 e primo com 8, 12 e 20: visita todas
		if not used.has(c):
			used[c] = true
			return c
	return first + start


## Retangulo da celula no atlas (UV 0..1), com meia margem de pixel para nao pegar a vizinha.
static func uv_rect(cell: int) -> Rect2:
	var c: int = posmod(cell, COUNT)
	var size := Vector2(COLS * CELL_PX.x, ROWS * CELL_PX.y)
	var px := Rect2(Vector2((c % COLS) * CELL_PX.x, (c / COLS) * CELL_PX.y), Vector2(CELL_PX))
	return Rect2((px.position + Vector2(1.5, 1.5)) / size, (px.size - Vector2(3, 3)) / size)


static func pixel_rect(cell: int) -> Rect2i:
	var c: int = posmod(cell, COUNT)
	return Rect2i(Vector2i((c % COLS) * CELL_PX.x, (c / COLS) * CELL_PX.y), CELL_PX)
