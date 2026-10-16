class_name ParallaxBg
extends Node2D
## Ceu, montanhas e duas camadas de skyline. Cada camada anda lateralmente conforme a curva da
## pista (mais devagar quanto mais longe), com textura repetivel na horizontal.

const DIR := "res://assets/backgrounds/kanto/"
const HORIZON: float = SpriteProjector.HORIZON_Y

var _layers: Array[Dictionary] = []   # {tex, factor, bottom_y, scroll}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_add("sky", 0.0, HORIZON + 2.0)
	_add("mountains", 0.15, HORIZON + 4.0)
	_add("city_far", 0.35, HORIZON + 4.0)
	_add("city_near", 0.7, HORIZON + 4.0)


func _add(id: String, factor: float, bottom_y: float) -> void:
	var path: String = "%s%s.png" % [DIR, id]
	if ResourceLoader.exists(path):
		_layers.append({"tex": load(path), "factor": factor, "bottom": bottom_y, "scroll": 0.0})


## `turn` = quanto a pista virou neste frame (curva x velocidade x dt).
func advance(turn: float) -> void:
	for l in _layers:
		l["scroll"] = fposmod(float(l["scroll"]) - turn * float(l["factor"]) * 40.0, float((l["tex"] as Texture2D).get_width()))
	queue_redraw()


func _draw() -> void:
	for l in _layers:
		var tex: Texture2D = l["tex"]
		var w: float = float(tex.get_width())
		var h: float = float(tex.get_height())
		var y: float = float(l["bottom"]) - h
		var x: float = -float(l["scroll"])
		while x < SpriteProjector.SCREEN_W:
			draw_texture(tex, Vector2(roundf(x), roundf(y)))
			x += w
