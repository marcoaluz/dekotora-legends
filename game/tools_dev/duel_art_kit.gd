extends RefCounted
## T-204: drawing kit of the duel art (our own ukiyo-e / Dekotora style: flat fills, ink outline, a shade crescent
## and a light crescent per part, tapered brush strokes). Tool only (tools_dev/make_duel_art.gd); not in the game.
## All shapes are built from circles/ellipses merged with Geometry2D, so every polygon is simple (no self crossing).

const INK := Color("#1b0f1e")


static func circle(c: Vector2, r: float, n: int = 36) -> PackedVector2Array:
	return ellipse(c, r, r, 0.0, n)


static func ellipse(c: Vector2, rx: float, ry: float, rot: float = 0.0, n: int = 48) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var a: float = float(i) / float(n) * TAU
		out.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return out


static func area(p: PackedVector2Array) -> float:
	var s: float = 0.0
	for i in p.size():
		var a: Vector2 = p[i]
		var b: Vector2 = p[(i + 1) % p.size()]
		s += a.x * b.y - b.x * a.y
	return absf(s) * 0.5


static func biggest(polys: Array) -> PackedVector2Array:
	var best := PackedVector2Array()
	var ba: float = -1.0
	for p in polys:
		var a: float = area(p)
		if a > ba:
			ba = a
			best = p
	return best


## Union of all polygons (keeps the outer outline; holes are dropped).
static func union(polys: Array) -> PackedVector2Array:
	if polys.is_empty():
		return PackedVector2Array()
	var acc: PackedVector2Array = polys[0]
	for i in range(1, polys.size()):
		acc = biggest(Geometry2D.merge_polygons(acc, polys[i]))
	return acc


static func moved(p: PackedVector2Array, off: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in p:
		out.append(v + off)
	return out


static func mirrored(p: PackedVector2Array, cx: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(p.size() - 1, -1, -1):
		out.append(Vector2(2.0 * cx - p[i].x, p[i].y))
	return out


## Catmull-Rom through `pts` (`n` samples per span).
static func smooth(pts: PackedVector2Array, n: int = 8) -> PackedVector2Array:
	if pts.size() < 3:
		return pts
	var out := PackedVector2Array()
	for i in pts.size() - 1:
		var p0: Vector2 = pts[maxi(i - 1, 0)]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[i + 1]
		var p3: Vector2 = pts[mini(i + 2, pts.size() - 1)]
		for k in n:
			var t: float = float(k) / float(n)
			var t2: float = t * t
			var t3: float = t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(pts[pts.size() - 1])
	return out


## Limb / tube: union of circles along a smoothed spine, radius interpolated between the given radii.
static func capsule(spine: PackedVector2Array, radii: PackedFloat32Array) -> PackedVector2Array:
	var s: PackedVector2Array = smooth(spine, 10)
	var polys: Array = []
	var total: float = 0.0
	var lens: PackedFloat32Array = [0.0]
	for i in range(1, s.size()):
		total += s[i].distance_to(s[i - 1])
		lens.append(total)
	var last_d: float = -999.0
	for i in s.size():
		var u: float = lens[i] / maxf(total, 0.001)
		var f: float = u * float(radii.size() - 1)
		var k: int = mini(int(f), radii.size() - 2)
		var r: float = lerpf(radii[k], radii[k + 1], f - float(k))
		if lens[i] - last_d >= maxf(r * 0.35, 2.0) or i == s.size() - 1:
			polys.append(circle(s[i], maxf(r, 1.0), 28))
			last_d = lens[i]
	return union(polys)


## Brush stroke polygon (tapered at both ends, fattest at `peak` 0..1) along a smoothed path.
static func brush_poly(pts: PackedVector2Array, w: float, peak: float = 0.4, tip0: float = 0.15, tip1: float = 0.0) -> PackedVector2Array:
	var s: PackedVector2Array = smooth(pts, 8)
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in s.size():
		var u: float = float(i) / float(s.size() - 1)
		var d: Vector2 = (s[mini(i + 1, s.size() - 1)] - s[maxi(i - 1, 0)]).normalized()
		var nrm := Vector2(-d.y, d.x)
		var prof: float = sin(PI * clampf(u / peak * 0.5, 0.0, 0.5)) if u < peak else cos(PI * 0.5 * (u - peak) / maxf(1.0 - peak, 0.001))
		var hw: float = w * 0.5 * maxf(prof, tip0 if u < peak else tip1)
		left.append(s[i] + nrm * hw)
		right.append(s[i] - nrm * hw)
	right.reverse()
	return left + right


static func brush(ci: CanvasItem, pts: PackedVector2Array, w: float, col: Color, peak: float = 0.4, tip0: float = 0.15, tip1: float = 0.0) -> void:
	var p: PackedVector2Array = brush_poly(pts, w, peak, tip0, tip1)
	if Geometry2D.triangulate_polygon(p).is_empty():
		ci.draw_polyline(smooth(pts, 8), col, w * 0.5, true)        # fallback for a too sharp bend
		return
	ci.draw_colored_polygon(p, col)


static func fill(ci: CanvasItem, p: PackedVector2Array, col: Color) -> void:
	if p.size() >= 3 and not Geometry2D.triangulate_polygon(p).is_empty():
		ci.draw_colored_polygon(p, col)


static func ink(ci: CanvasItem, p: PackedVector2Array, w: float) -> void:
	if w <= 0.0:
		return
	fill(ci, biggest(Geometry2D.offset_polygon(p, w, Geometry2D.JOIN_ROUND)), INK)


## One part: ink outline, base colour, shade crescent (the part minus itself moved by `shade_off`), light crescent.
static func part(ci: CanvasItem, p: PackedVector2Array, base: Color, shade: Color, light: Color = Color(0, 0, 0, 0),
		ink_w: float = 7.0, shade_off: Vector2 = Vector2(-16, -14), light_off: Vector2 = Vector2(10, 12)) -> void:
	ink(ci, p, ink_w)
	fill(ci, p, base)
	if shade.a > 0.0:
		for q in Geometry2D.clip_polygons(p, moved(p, shade_off)):
			fill(ci, q, shade)
	if light.a > 0.0:
		for q2 in Geometry2D.clip_polygons(p, moved(p, light_off)):
			fill(ci, q2, light)


## Ukiyo-e cloud ("kumo"): merged lobes, shaded underside and spiral curls on the top lobes.
static func cloud(ci: CanvasItem, lobes: Array, base: Color, shade: Color, light: Color, curl: Color) -> void:
	var polys: Array = []
	for l in lobes:
		polys.append(circle(Vector2(l[0], l[1]), float(l[2]), 40))
	var p: PackedVector2Array = union(polys)
	part(ci, p, base, shade, light, 8.0, Vector2(0, -22), Vector2(0, 14))
	for l2 in lobes:
		var c := Vector2(l2[0], l2[1])
		var r: float = float(l2[2])
		if r < 60.0:
			continue
		spiral(ci, c + Vector2(r * 0.05, -r * 0.12), r * 0.62, 1.6, curl, 9.0)


## Spiral curl (clouds, wind, drum tomoe tails): from the outside in, `turns` turns, tapered brush.
static func spiral(ci: CanvasItem, c: Vector2, r: float, turns: float, col: Color, w: float, start: float = PI) -> void:
	var pts := PackedVector2Array()
	var n: int = int(turns * 14.0)
	for i in n + 1:
		var u: float = float(i) / float(n)
		var a: float = start + u * turns * TAU
		pts.append(c + Vector2(cos(a), sin(a)) * r * (1.0 - u * 0.82))
	brush(ci, pts, w, col, 0.25, 0.4, 0.1)


## Mitsudomoe (three commas), traditional motif, drawn by us: heads on a ring, tails sweeping outward.
static func tomoe(ci: CanvasItem, c: Vector2, r: float, col: Color, rot: float = 0.0) -> void:
	for k in 3:
		var a0: float = rot + float(k) * TAU / 3.0
		var head: Vector2 = c + Vector2(cos(a0), sin(a0)) * r * 0.38
		var tail := PackedVector2Array()
		for i in 9:
			var u: float = float(i) / 8.0
			var a: float = a0 + u * 2.4
			tail.append(c + Vector2(cos(a), sin(a)) * r * lerpf(0.38, 0.96, u))
		var tp: PackedVector2Array = brush_poly(tail, r * 0.62, 0.02, 1.0, 0.0)
		fill(ci, union([circle(head, r * 0.31, 28), tp]), col)


## Zig-zag spark (lightning crackle around the drums).
static func spark(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, w: float, seed_: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var pts := PackedVector2Array([a])
	var d: Vector2 = b - a
	var nrm := Vector2(-d.y, d.x).normalized()
	for i in range(1, 5):
		pts.append(a + d * (float(i) / 5.0) + nrm * rng.randf_range(-1.0, 1.0) * d.length() * 0.18 * (1.0 if i % 2 == 0 else -1.0))
	pts.append(b)
	ci.draw_polyline(pts, INK, w + 6.0, true)
	ci.draw_polyline(pts, col, w, true)
