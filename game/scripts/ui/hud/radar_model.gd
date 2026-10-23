class_name RadarModel
extends RefCounted
## T-202: what the vertical radar strip on the left of the HUD shows (like the original's translucent band).
## Pure reads of RaceSim: the player, the other trucks (route rival apart), traffic cars close by, wrecked cars and the
## track events ahead (accident, works, narrowing, 2-lane section). Each blip is a Dictionary:
##   {kind: Kind, x0: float, x1: float, z0: float, z1: float}
## x = track lateral (-1..1, like TruckSim.x) and z = metres relative to the player's rear (+ ahead).
## The strip maps z with `y_frac` (square root ahead: far events still fit; linear behind).

enum Kind { ME, RIVAL, TRUCK, CAR, WRECK, ACCIDENT, WORKS, NARROW, SECTION }

const AHEAD_M: float = 360.0               # top of the strip
const BEHIND_M: float = 60.0               # bottom of the strip
const ME_FRAC: float = 0.22                # player's rear sits at 22% from the bottom
const CAR_AHEAD_M: float = 220.0           # traffic cars are only shown this close
const EVENT_AHEAD_M: float = 900.0         # events further than AHEAD_M are pinned at the top edge
const X_RANGE: float = 1.0                 # |x| shown (shoulders included)
const EVENT_KIND: Dictionary = {
	TrackEvents.Kind.ACCIDENT: Kind.ACCIDENT, TrackEvents.Kind.WORKS: Kind.WORKS,
	TrackEvents.Kind.NARROW: Kind.NARROW, TrackEvents.Kind.SECTION: Kind.SECTION,
}


## 0 (bottom) .. 1 (top) for a relative z. Clamped.
static func y_frac(z_rel: float) -> float:
	if z_rel >= 0.0:
		return ME_FRAC + (1.0 - ME_FRAC) * sqrt(clampf(z_rel / AHEAD_M, 0.0, 1.0))
	return ME_FRAC * (1.0 - clampf(-z_rel / BEHIND_M, 0.0, 1.0))


## 0 (left edge) .. 1 (right edge) for a track x.
static func x_frac(x: float) -> float:
	return clampf((x + X_RANGE) / (2.0 * X_RANGE), 0.0, 1.0)


static func blips(sim: RaceSim, player: int, rival: int = -1) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if sim == null or player < 0 or player >= sim.trucks.size():
		return out
	var me: TruckSim = sim.trucks[player]
	var w: float = TruckSim.WIDTH_X * 0.5
	if sim.track != null and sim.track.events != null:
		for ev in sim.track.events.list:
			_event(out, ev, me.z)
	if sim.traffic != null:
		for c in sim.traffic.cars:
			var dz: float = c.z - me.z
			if dz > CAR_AHEAD_M or dz + c.length < -BEHIND_M:
				continue
			var hw: float = c.width_x * 0.5
			out.append(_blip(Kind.WRECK if c.wrecked else Kind.CAR, c.x - hw, c.x + hw, dz, dz + c.length))
	for k in sim.trucks.size():
		if k == player:
			continue
		var t: TruckSim = sim.trucks[k]
		var dz2: float = t.z - me.z
		if dz2 > AHEAD_M or dz2 + t.length < -BEHIND_M:
			continue
		out.append(_blip(Kind.RIVAL if k == rival else Kind.TRUCK, t.x - w, t.x + w, dz2, dz2 + t.length))
	out.append(_blip(Kind.ME, me.x - w, me.x + w, 0.0, me.length))
	return out


static func _event(out: Array[Dictionary], ev: TrackEvents.Event, me_z: float) -> void:
	var end_z: float = ev.reopen_end() if ev.kind == TrackEvents.Kind.NARROW else ev.end_z()
	var z0: float = ev.z - me_z
	var z1: float = end_z - me_z
	if z1 < -BEHIND_M or z0 > EVENT_AHEAD_M:
		return
	var lo: int = mini(ev.lo, ev.hi)
	var hi: int = maxi(ev.lo, ev.hi)
	var x0: float = Lanes.X[lo] - Lanes.SPACING * 0.5
	var x1: float = Lanes.X[hi] + Lanes.SPACING * 0.5
	if ev.kind == TrackEvents.Kind.SECTION:
		x1 = X_RANGE                                     # the right lane and its shoulder end
	out.append(_blip(int(EVENT_KIND.get(ev.kind, Kind.WORKS)), x0, x1, z0, z1))


static func _blip(kind: int, x0: float, x1: float, z0: float, z1: float) -> Dictionary:
	return {"kind": kind, "x0": x0, "x1": x1, "z0": z0, "z1": z1}
