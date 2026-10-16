class_name Tr
extends RefCounted
## Textos de interface vindos de game/data/i18n/<idioma>.json (pt-BR primeiro). `Tr.t("chave")`.
## Chave ausente devolve a propria chave (facil de achar o que falta traduzir).

static var _dict: Dictionary = {}
static var _lang: String = ""


static func t(key: String, args: Array = []) -> String:
	var lang: String = "pt-BR"
	var settings: Node = Engine.get_main_loop().root.get_node_or_null("Settings") if Engine.get_main_loop() else null
	if settings != null:
		lang = String(settings.language)
	if lang != _lang:
		_load(lang)
	var text: String = String(_dict.get(key, key))
	if args.is_empty():
		return text
	return text % args


static func _load(lang: String) -> void:
	_lang = lang
	_dict = {}
	var path: String = "res://data/i18n/%s.json" % lang
	if not FileAccess.file_exists(path):
		path = "res://data/i18n/pt-BR.json"
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		_dict = parsed


## Texto formatado de dinheiro: 12345 -> "12.345 ¥".
static func yen(v: int) -> String:
	var s: String = str(absi(v))
	var out: String = ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += "."
		out += s[i]
	return ("-" if v < 0 else "") + out + " ¥"
