class_name RaceCamButton
extends Control
## T-198: small camera icon on the race HUD (under the position panel). Click/tap = next camera. When the camera
## changes, its name shows next to the icon for a moment. Drawn in the 480x270 HUD layer.

signal pressed

const ICON_SIZE := Vector2(26, 17)
const TOAST_S: float = 1.4
const GOLD := Color("#f5cc5a")

var label: String = ""
var _toast: float = 0.0
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = ICON_SIZE
	_font = UiTheme.heading_font(true)


func show_name(text: String) -> void:
	label = text
	_toast = TOAST_S
	queue_redraw()


func _process(delta: float) -> void:
	if _toast > 0.0:
		_toast = maxf(_toast - delta, 0.0)
		queue_redraw()


func _has_point(p: Vector2) -> bool:
	return Rect2(Vector2.ZERO, ICON_SIZE).grow(5.0).has_point(p)


func _gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton      # touch arrives as an emulated mouse click
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()
		accept_event()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, ICON_SIZE)
	draw_rect(r, Color(0.03, 0.04, 0.09, 0.5))
	draw_rect(r, Color(1, 1, 1, 0.35), false, 1.0)
	var c: Color = Color(1, 1, 1, 0.85)
	draw_rect(Rect2(5, 6, 12, 8), c, false, 1.5)                      # camera body
	draw_colored_polygon(PackedVector2Array([Vector2(17, 9), Vector2(22, 6), Vector2(22, 14), Vector2(17, 11)]), c)
	draw_circle(Vector2(8, 4.5), 1.6, c)                              # film reels
	draw_circle(Vector2(13, 4.5), 1.6, c)
	if _toast > 0.0 and label != "":
		var a: float = clampf(_toast / 0.4, 0.0, 1.0)
		var fs: int = 9
		var w: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_rect(Rect2(ICON_SIZE.x + 3, 2, w + 8, 13), Color(0.03, 0.04, 0.09, 0.6 * a))
		draw_string(_font, Vector2(ICON_SIZE.x + 7, 12), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(GOLD, a))
