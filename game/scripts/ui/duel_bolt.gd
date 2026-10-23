class_name DuelBolt
extends RefCounted
## Lightning bolt of the duel opening (T-204): a jagged main channel from the sky to the strike point between the
## trucks plus a few short branches. Pure and seeded (the same bolt on every client and every run).


## [main, branch, branch...] polylines from `from` (sky) to `to` (ground), in the caller's 2D space.
static func paths(from: Vector2, to: Vector2, seed_: int = 204) -> Array[PackedVector2Array]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var main := PackedVector2Array([from, to])
	var spread: float = from.distance_to(to) * 0.16
	for level in 4:                                              # midpoint displacement, 4 levels = 17 points
		var next := PackedVector2Array()
		for i in main.size() - 1:
			var a: Vector2 = main[i]
			var b: Vector2 = main[i + 1]
			var d: Vector2 = b - a
			var nrm := Vector2(-d.y, d.x).normalized()
			next.append(a)
			next.append((a + b) * 0.5 + nrm * rng.randf_range(-1.0, 1.0) * spread)
		next.append(main[main.size() - 1])
		main = next
		spread *= 0.55
	var out: Array[PackedVector2Array] = [main]
	for k in 3:                                                  # short forks going down and out
		var i0: int = 3 + k * 4 + rng.randi_range(0, 2)
		var p: Vector2 = main[i0]
		var dir: Vector2 = (main[mini(i0 + 2, main.size() - 1)] - p).normalized().rotated(rng.randf_range(0.45, 0.9) * (1.0 if k % 2 == 0 else -1.0))
		var len_: float = from.distance_to(to) * rng.randf_range(0.12, 0.22)
		var br := PackedVector2Array([p])
		for j in range(1, 5):
			br.append(p + dir * len_ * float(j) / 4.0 + Vector2(-dir.y, dir.x) * rng.randf_range(-1.0, 1.0) * len_ * 0.12)
		out.append(br)
	return out


## The part of `line` already drawn when the leader has grown `grow` (0..1) from its first point.
static func grown(line: PackedVector2Array, grow: float) -> PackedVector2Array:
	if grow >= 1.0 or line.size() < 2:
		return line
	var n: float = grow * float(line.size() - 1)
	var k: int = int(n)
	var out := PackedVector2Array()
	for i in k + 1:
		out.append(line[i])
	if k < line.size() - 1:
		out.append(line[k].lerp(line[k + 1], n - float(k)))
	return out
