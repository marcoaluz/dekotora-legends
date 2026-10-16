class_name ResultScreen
extends Control
## Tela de resultado da corrida (P33): posicao, tempo, carga, pagamento, Fama e lista de danos.
## Recebe o Dictionary de RaceSim.result_for(). Emite `continue_pressed` no botao.

signal continue_pressed

const PINK := Color("#ff2e88")
const GOLD := Color("#f5cc5a")

var _res: Dictionary = {}


func show_result(res: Dictionary) -> void:
	_res = res
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	for c in get_children():
		c.queue_free()
	var btn := Button.new()
	btn.text = "CONTINUAR"
	btn.position = Vector2(190, 232)
	btn.size = Vector2(100, 26)
	btn.add_theme_font_size_override("font_size", 12)
	btn.pressed.connect(func() -> void: continue_pressed.emit())
	add_child(btn)
	visible = true
	queue_redraw()


func _t(pos: Vector2, text: String, size: int, col: Color = Color.WHITE, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	var f: Font = ThemeDB.fallback_font
	draw_string(f, pos + Vector2(1, 1), text, align, width, size, Color(0, 0, 0, 0.8))
	draw_string(f, pos, text, align, width, size, col)


func _state_text(state: String) -> String:
	match state:
		"ok":
			return "inteira"
		"dent":
			return "amassada"
	return "QUEBRADA"


func _draw() -> void:
	if _res.is_empty():
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.07, 0.86))
	draw_rect(Rect2(60, 14, 360, 210), Color(0.07, 0.06, 0.16, 0.95))
	draw_rect(Rect2(60, 14, 360, 3), PINK)
	_t(Vector2(60, 46), "%do LUGAR" % int(_res["position"]), 30, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 360.0)
	var t: float = float(_res["time"])
	var line_y: float = 70.0
	var rows: Array = [
		["Tempo", "%d:%05.2f" % [int(t) / 60, fmod(t, 60.0)]],
		["Integridade da carga", "%d%%" % roundi(float(_res["cargo"]) * 100.0)],
		["Frete", "%d ¥" % int(_res["freight"])],
		["Bonus de posicao", "+%d ¥" % int(_res["position_bonus"])],
		["Ultrapassagens", "%d" % int(_res["overtakes"])],
		["Fama (Kirameki)", "+%d" % int(_res["fame"])],
	]
	for r in rows:
		_t(Vector2(80, line_y), String(r[0]), 11, Color(1, 1, 1, 0.8))
		_t(Vector2(80, line_y), String(r[1]), 11, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 160.0)
		line_y += 16.0
	_t(Vector2(80, line_y + 6), "PAGAMENTO", 12, PINK)
	_t(Vector2(80, line_y + 6), "%d ¥" % int(_res["pay"]), 14, GOLD, HORIZONTAL_ALIGNMENT_RIGHT, 160.0)
	# danos (coluna da direita)
	_t(Vector2(270, 70), "DANOS", 11, PINK)
	var y: float = 86.0
	for p in _res["parts"]:
		var st: String = String(p["state"])
		var col: Color = Color("#3fb26f") if st == "ok" else (Color("#f5cc5a") if st == "dent" else Color("#d1303f"))
		_t(Vector2(270, y), String(p["id"]), 9, Color.WHITE)
		_t(Vector2(270, y), _state_text(st), 9, col, HORIZONTAL_ALIGNMENT_RIGHT, 140.0)
		y += 13.0
	var sys: Dictionary = _res["systems"]
	for k in ["engine", "steering", "cargo"]:
		var label: String = {"engine": "motor", "steering": "direcao", "cargo": "carga"}[k]
		_t(Vector2(270, y + 4), label, 9, Color(1, 1, 1, 0.8))
		_t(Vector2(270, y + 4), "%d%%" % roundi(float(sys[k])), 9, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 140.0)
		y += 12.0
