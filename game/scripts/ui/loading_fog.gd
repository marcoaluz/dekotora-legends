class_name LoadingFog
extends RefCounted
## T-208: purple ground fog drawn in 2D on a black screen while the race loads (SceneFader) and while the duel
## opening prepares (DuelBand): the same look as the studio fog, so the wait already looks like the opening.
## Cheap (8 soft blobs, one small texture) and drawn from any CanvasItem's _draw.

const BLOBS: int = 8
const COLOR_A := Color("#5b25b8")
const COLOR_B := Color("#a24de6")

static var _tex: Texture2D


static func _blob() -> Texture2D:
	if _tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_tex = t
	return _tex


## Common clock of the fog (s): the fader and the opening draw the same wisps at the same place (no jump between them).
static func now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


## Wisps drifting sideways along the bottom of a `size` screen at time `t` (s), faded by `alpha` (0..1).
static func draw_on(ci: CanvasItem, size: Vector2, t: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var tex: Texture2D = _blob()
	for i in BLOBS:
		var f: float = float(i) / float(BLOBS)
		var speed: float = (0.018 + 0.012 * fposmod(f * 7.3, 1.0)) * (1.0 if i % 2 == 0 else -1.0)
		var x: float = fposmod(f * 1.37 + speed * t, 1.4) - 0.2                  # wraps outside the screen
		var y: float = 0.80 + 0.13 * fposmod(f * 3.1, 1.0)
		var w: float = size.x * (0.34 + 0.18 * fposmod(f * 5.7, 1.0)) * (1.0 + 0.05 * sin(t * 0.9 + float(i)))
		var h: float = w * 0.28
		var c: Color = COLOR_A.lerp(COLOR_B, fposmod(f * 2.3, 1.0))
		c.a = alpha * (0.34 + 0.2 * fposmod(f * 4.1, 1.0))
		ci.draw_texture_rect(tex, Rect2(Vector2(x * size.x - w * 0.5, y * size.y - h * 0.5), Vector2(w, h)), false, c)
