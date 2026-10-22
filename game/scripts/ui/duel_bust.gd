class_name DuelBust
extends RefCounted
## T-199: the driver portrait of the duel band (bust_base/bust_shirt.png, a faceless render of the scenery man) looked
## like a shop mannequin. Drawn on top, in the 256 px space of the bust art (follows the flip of the band):
## hachimaki headband with the knot at the back, sunglasses, eyebrow, nose shade, mouth, ear, a collar that hides the
## jagged skin of the neckline, sleeve hems and a couple of shirt folds. Only 2D draw calls (no texture memory).

const SKIN_SHADE := Color(0.55, 0.38, 0.3, 0.55)
const INK := Color(0.1, 0.08, 0.08, 0.9)


static func features(ci: CanvasItem, art: Rect2, shirt: Color) -> void:
	var k: float = art.size.x / 256.0
	var o: Vector2 = art.position
	var p := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * k
	var poly := func(pts: Array, col: Color) -> void:
		var arr := PackedVector2Array()
		for q in pts:
			arr.append(p.call(q.x, q.y))
		ci.draw_colored_polygon(arr, col)
	var dark: Color = shirt.darkened(0.3)
	# collar over the neckline + sleeve hems
	poly.call([Vector2(82, 111), Vector2(100, 103), Vector2(116, 113), Vector2(135, 116), Vector2(152, 106),
		Vector2(166, 100), Vector2(189, 112), Vector2(190, 125), Vector2(160, 119), Vector2(135, 128),
		Vector2(112, 127), Vector2(96, 121), Vector2(80, 125)], shirt.darkened(0.12))
	ci.draw_polyline(PackedVector2Array([p.call(82, 111), p.call(100, 103), p.call(116, 113), p.call(135, 116),
		p.call(152, 106), p.call(166, 100), p.call(189, 112)]), dark, 1.6 * k)
	ci.draw_line(p.call(116, 113), p.call(122, 136), dark, 1.2 * k)
	ci.draw_line(p.call(135, 116), p.call(128, 136), dark, 1.2 * k)
	ci.draw_line(p.call(46, 186), p.call(68, 196), dark, 2.0 * k)
	ci.draw_line(p.call(192, 196), p.call(220, 190), dark, 2.0 * k)
	ci.draw_line(p.call(150, 160), p.call(170, 200), Color(dark, 0.45), 1.2 * k)
	ci.draw_line(p.call(95, 170), p.call(110, 215), Color(dark, 0.4), 1.2 * k)
	# ear, nose shade, mouth
	ci.draw_circle(p.call(140, 84), 4.0 * k, SKIN_SHADE)
	ci.draw_polyline(PackedVector2Array([p.call(101, 85), p.call(98, 93), p.call(103, 94)]), SKIN_SHADE.darkened(0.2), 1.3 * k)
	ci.draw_line(p.call(100, 99), p.call(109, 98), Color(0.35, 0.18, 0.15, 0.85), 1.4 * k)
	ci.draw_line(p.call(112, 104), p.call(128, 101), Color(0.4, 0.28, 0.24, 0.3), 2.0 * k)   # jaw shadow
	# sunglasses (two lenses + bridge + arm to the ear) with a small glint
	poly.call([Vector2(95, 78), Vector2(106, 78), Vector2(105, 85), Vector2(97, 85)], INK)
	poly.call([Vector2(110, 78), Vector2(125, 78), Vector2(123, 86), Vector2(111, 86)], INK)
	ci.draw_line(p.call(106, 79), p.call(110, 79), INK, 1.2 * k)
	ci.draw_line(p.call(125, 79), p.call(139, 81), INK, 1.2 * k)
	ci.draw_line(p.call(113, 80), p.call(117, 79), Color(1, 1, 1, 0.55), 1.0 * k)
	ci.draw_line(p.call(102, 72), p.call(112, 71), INK, 1.6 * k)                               # eyebrow
	# hachimaki (twisted towel headband) and its knot at the back of the head
	var band: Color = Color(0.94, 0.93, 0.9) if shirt.get_luminance() < 0.75 else Color(0.82, 0.12, 0.12)
	poly.call([Vector2(93, 62), Vector2(157, 56), Vector2(159, 64), Vector2(94, 69)], band)
	for x in [104.0, 118.0, 132.0, 146.0]:
		ci.draw_line(p.call(x, 60.5 - (x - 93.0) * 0.09), p.call(x + 5.0, 67.5 - (x - 93.0) * 0.1), band.darkened(0.25), 1.0 * k)
	poly.call([Vector2(156, 57), Vector2(166, 58), Vector2(176, 72), Vector2(170, 74), Vector2(160, 64)], band.darkened(0.08))
	poly.call([Vector2(158, 62), Vector2(165, 66), Vector2(168, 82), Vector2(162, 80)], band.darkened(0.15))
