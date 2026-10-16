class_name TrafficView
extends Node2D
## Desenha o transito como retangulos coloridos (provisorio ate os sprites do Blender, P46):
## corpo, vidro e lanternas, projetados pela camera da estrada.

const BODY_COLORS: Array[Color] = [
	Color("#3a73d6"), Color("#d1303f"), Color("#3fb26f"), Color("#d29a2e"), Color("#aeb8c8"), Color("#b14cff")]
const GLASS := Color("#1e1b3d")
const TAIL := Color("#ff4d4d")

var projector: SpriteProjector
var traffic: TrafficSim


func update_view(proj: SpriteProjector, traffic_: TrafficSim) -> void:
	projector = proj
	traffic = traffic_
	queue_redraw()


func _draw() -> void:
	if projector == null or traffic == null or projector.track == null:
		return
	var sorted: Array[TrafficSim.Car] = traffic.cars.duplicate()
	sorted.sort_custom(func(a: TrafficSim.Car, b: TrafficSim.Car) -> bool: return a.z > b.z)   # longe primeiro
	for c in sorted:
		if c.z < projector.cam_z + SpriteProjector.NEAR_Z or c.z > projector.cam_z + 240.0:
			continue
		var p: Vector3 = projector.project(c.x, c.z, 0.0)
		if p.z <= 0.0:
			continue
		var s: float = p.z
		var w: float = 1.9 * s
		var h: float = 1.5 * s
		var body: Rect2 = Rect2(Vector2(p.x - w * 0.5, p.y - h).round(), Vector2(w, h * 0.7).round())
		draw_rect(body, BODY_COLORS[c.color_id])
		draw_rect(Rect2(body.position + Vector2(w * 0.1, -h * 0.28).round(), Vector2(w * 0.8, h * 0.3).round()), BODY_COLORS[c.color_id].darkened(0.2))
		draw_rect(Rect2(body.position + Vector2(w * 0.17, -h * 0.22).round(), Vector2(w * 0.66, h * 0.2).round()), GLASS)
		var lamp: Vector2 = Vector2(maxf(w * 0.16, 1.0), maxf(h * 0.1, 1.0)).round()
		draw_rect(Rect2(body.position + Vector2(w * 0.06, h * 0.12).round(), lamp), TAIL)
		draw_rect(Rect2(body.position + Vector2(w * 0.78, h * 0.12).round(), lamp), TAIL)
		draw_rect(Rect2(Vector2(p.x - w * 0.45, p.y - h * 0.3).round(), Vector2(w * 0.9, maxf(h * 0.3, 1.0)).round()), Color("#121214"))
