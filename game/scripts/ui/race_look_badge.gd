class_name RaceLookBadge
extends Control
## T-241: small "OLHANDO PARA TRAS / A ESQUERDA / A DIREITA" tag at the top centre (where the rear mirror is; the
## mirror hides while looking) so the player always knows the view is not the normal one. Eye icon (Lucide).
## Drawn in the 480x270 HUD layer; RaceCamView centres it and feeds the direction.

const H: float = 15.0
const PINK := Color("#ff2e88")

var dir: int = RaceLook.Dir.NONE
var alpha: float = 0.0
var _font: Font
var _eye: Texture2D
var _text: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = UiTheme.heading_font(true)
	_eye = UiKit.icon("eye")


## `d` = direction shown, `w` = look weight 0..1 (fades with the camera move).
func show_dir(d: int, w: float) -> void:
	var a: float = clampf((w - 0.25) / 0.5, 0.0, 1.0) if d != RaceLook.Dir.NONE else 0.0
	if d != RaceLook.Dir.NONE and d != dir:
		dir = d
		_text = Tr.t("look." + RaceLook.IDS[d])
	if absf(a - alpha) > 0.01 or (a == 0.0) != (alpha == 0.0):
		alpha = a
		visible = alpha > 0.0
		queue_redraw()


func text_width() -> float:
	return (_font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x if _font != null else 60.0) + 26.0


func _draw() -> void:
	if alpha <= 0.0 or _text == "":
		return
	var w: float = text_width()
	var r := Rect2(-w * 0.5, 0.0, w, H)
	draw_rect(r, Color(0.02, 0.03, 0.07, 0.62 * alpha))
	draw_rect(Rect2(r.position, Vector2(w, 1.5)), Color(PINK, alpha))
	if _eye != null:
		draw_texture_rect(_eye, Rect2(r.position + Vector2(5, 2.5), Vector2(11, 11)), false, Color(1, 1, 1, alpha))
	draw_string(_font, r.position + Vector2(20, 11.5), _text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 1, 1, alpha))
