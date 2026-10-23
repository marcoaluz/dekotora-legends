class_name HudStatus
extends RefCounted
## T-202: what the 5 status segments of the HUD show (front, left side, right side, rear, cargo/box) and the hazard
## lamp rule. Pure reads of TruckSim (no nodes): the same online (predicted truck) and offline.
## The 4 zones use DamageModel.zone_health (the same number the garage shows: parts of the zone, or the zone's
## system when it has no parts); the cargo uses TruckSim.cargo_integrity (hits + contacts).

enum Level { OK, DAMAGED, CRITICAL, DESTROYED }

const SEGMENTS: Array[String] = ["front", "left", "right", "rear", "cargo"]
const DAMAGED_BELOW: float = 0.66          # same limits as the old HUD diagram and the garage colours
const CRITICAL_BELOW: float = 0.33
const DESTROYED_AT: float = 0.001
const SYSTEM_KEY: Dictionary = {"engine": "hud.seg.sys.engine", "steering": "hud.seg.sys.steering", "cargo": "hud.seg.sys.cargo"}
const HAZARD_STOP_MS: float = 4.0          # m/s: slower than this in the race = stopped (hazard on)
const HAZARD_AFTER_S: float = 6.0          # ... but not right after the start


## Health 0..1 of a segment.
static func value(t: TruckSim, seg: String) -> float:
	if seg == "cargo":
		return t.cargo_integrity()
	return clampf(DamageModel.zone_health(t, seg), 0.0, 1.0)


static func level_of(v: float) -> int:
	if v <= DESTROYED_AT:
		return Level.DESTROYED
	if v < CRITICAL_BELOW:
		return Level.CRITICAL
	if v < DAMAGED_BELOW:
		return Level.DAMAGED
	return Level.OK


static func level(t: TruckSim, seg: String) -> int:
	return level_of(value(t, seg))


## Levels of the 5 segments, in SEGMENTS order.
static func levels(t: TruckSim) -> Array[int]:
	var out: Array[int] = []
	for s in SEGMENTS:
		out.append(level(t, s))
	return out


## Intact / total parts mounted on a zone (Vector2i(intact, total)).
static func parts(t: TruckSim, zone: String) -> Vector2i:
	var total: int = 0
	var intact: int = 0
	for p in t.loadout:
		if zone in p["zones"] and float(p["max"]) > 0.0:
			total += 1
			if not bool(p.get("broken", false)):
				intact += 1
	return Vector2i(intact, total)


## Lines of the detail popup (tap / mouse over a segment): title, state + %, parts, system behind the zone.
static func detail(t: TruckSim, seg: String) -> PackedStringArray:
	var v: float = value(t, seg)
	var lv: int = level_of(v)
	var out := PackedStringArray()
	out.append(Tr.t("hud.seg.name." + seg))
	out.append("%s  %d%%" % [Tr.t("hud.seg.state.%d" % lv), roundi(v * 100.0)])
	if seg == "cargo":
		out.append(Tr.t("hud.seg.cargo_loss", [roundi(t.cargo_loss() * 100.0)]))
		return out
	var pc: Vector2i = parts(t, seg)
	if pc.y > 0:
		out.append(Tr.t("hud.seg.parts", [pc.x, pc.y]))
	else:
		out.append(Tr.t("hud.seg.no_parts"))
	var sys: String = String(DamageModel.ZONE_SYSTEM.get(seg, "cargo"))
	out.append("%s %d%%" % [Tr.t(String(SYSTEM_KEY[sys])), roundi(float(t.systems[sys]))])
	return out


## Hazard lamp (pisca-alerta): the truck is in trouble on the road. Presentation only.
##  - escaping a curve (lost the lane), or
##  - stopped / crawling in the middle of the race (after a crash, behind a closure), or
##  - out of time.
static func hazard(t: TruckSim, race_time: float, racing: bool) -> bool:
	if not racing or t.finish_time >= 0.0:
		return false
	if t.timed_out or t.escaping:
		return true
	return race_time > HAZARD_AFTER_S and t.speed < HAZARD_STOP_MS
