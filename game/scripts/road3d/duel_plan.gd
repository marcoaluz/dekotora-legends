class_name DuelPlan
extends RefCounted
## Timeline of the face-to-face opening before the start (T-156). Pure presentation timing: the race simulation
## still starts at the end of the 3 s countdown, exactly as before. The server uses the same numbers to stretch
## its countdown (online, every client plays the same clock and nobody starts late).
##
## FULL  (1x1 duel, ~9.4 s): face-off · player details + band · rival details + band + taunt · VS · countdown
##        (the countdown opens with the alignment shot, then the side cut of the start).
## SHORT (rematch / 3-4 trucks, 3 s): only the countdown with the alignment shot.

const FULL: String = "full"
const SHORT: String = "short"
const NONE: String = "none"

## Phases of the full intro (seconds). Countdown = Protocol.COUNTDOWN_SECONDS after them.
const PHASES: Array = [["face", 1.4], ["player", 1.8], ["rival", 2.0], ["vs", 1.2]]
## Alignment shot at the start of the countdown (then RaceCinema's side cut, 1.6 s before the go).
const ALIGN_S: float = 1.4
## Detail shots inside each truck phase (cut every third of the phase).
const DETAILS_PLAYER: Array[String] = ["bumper", "visor", "mural"]
const DETAILS_RIVAL: Array[String] = ["visor", "bumper", "mural"]


## Seconds of intro BEFORE the countdown.
static func intro_seconds(kind: String) -> float:
	if kind != FULL:
		return 0.0
	var s: float = 0.0
	for p in PHASES:
		s += float(p[1])
	return s


## Total time from the scene start to the go (intro + countdown).
static func total_seconds(kind: String) -> float:
	return intro_seconds(kind) + Protocol.COUNTDOWN_SECONDS


## Phase at intro time `t`: [name, progress 0..1, index]. After the intro: ["count", 0, -1].
static func phase_at(t: float) -> Array:
	var acc: float = 0.0
	for i in PHASES.size():
		var len_s: float = float(PHASES[i][1])
		if t < acc + len_s:
			return [String(PHASES[i][0]), clampf((t - acc) / len_s, 0.0, 1.0), i]
		acc += len_s
	return ["count", 0.0, -1]


## Detail shot (bumper/visor/mural) and its own progress inside a truck phase.
static func detail_at(phase: String, progress: float) -> Array:
	var list: Array[String] = DETAILS_PLAYER if phase == "player" else DETAILS_RIVAL
	var f: float = clampf(progress, 0.0, 0.9999) * float(list.size())
	return [list[int(f)], f - floor(f)]


## Offline: campaign duel (route rival, 2 trucks) = full the first time, short on a rematch; quick race
## (no rival, 4 trucks) = short. `forced` = --intro=full|short|none (debug).
static func pick_offline(has_rival: bool, trucks: int, rematch: bool, forced: String = "") -> String:
	if forced in [FULL, SHORT, NONE]:
		return forced
	if has_rival and trucks == 2 and not rematch:
		return FULL
	return SHORT


## Online: 2 humans (or 1 human against a single bot) = the same duel scene; 3-4 humans or a fuller grid = short.
## `rematch` = same room, same route and same people as the last race.
static func pick_online(humans: int, trucks: int, rematch: bool) -> String:
	if rematch:
		return SHORT
	if humans == 2 or (humans == 1 and trucks == 2):
		return FULL
	return SHORT


## The two trucks of the duel scene online, seen by `me`: [me, other]. Prefers the other human; else the first bot.
static func online_pair(grid: Array, me: int) -> Array[int]:
	var other: int = -1
	for e in grid:
		var i: int = int(e["idx"])
		if i != me and not bool(e["bot"]):
			other = i
			break
	if other < 0:
		for e in grid:
			if int(e["idx"]) != me:
				other = int(e["idx"])
				break
	return [me, other]


## Online clock: seconds since the server started the countdown, from the moment the setup arrived and the ping.
## `setup_left` = countdown left when the server sent the setup; `total` = the whole countdown of the room.
static func online_elapsed(total: float, setup_left: float, setup_msec: int, now_msec: int, ping_ms: int) -> float:
	return (total - setup_left) + float(now_msec - setup_msec) / 1000.0 + float(ping_ms) * 0.0005


## Comboio (3-4 human players): traffic one level lighter than the room rule.
static func convoy_traffic(rule_traffic: int, humans: int) -> int:
	return maxi(rule_traffic - 1, 0) if humans >= 3 else rule_traffic
