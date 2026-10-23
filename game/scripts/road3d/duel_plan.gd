class_name DuelPlan
extends RefCounted
## Timeline of the duel opening before the start (T-156, redone in T-204). Pure presentation timing: the race
## simulation still starts at the end of the 3 s countdown, exactly as before. The server uses the same numbers to
## stretch its countdown (online, every client plays the same clock and nobody starts late).
##
## FULL (1x1 duel, 8 s in all = 5 s of opening + 3 s of countdown), in a black studio with purple ground fog:
##   enter  0.0-2.1  the two real race trucks drive in from each side at an angle and stop side by side, facing the
##                   camera, headlights and neon on
##   guard  2.1-2.8  the guardians rise behind them inside their auras (Raijin over the player, Fujin over the rival)
##   title  2.8-3.7  対決 slams in with a taiko hit; the band of each driver slides in at the bottom
##   bolt   3.7-4.2  a lightning bolt strikes between them: ONE white flash of 0.15 s (soft violet glow instead with
##                   "reduce flashes" on) and thunder
##   launch 4.2-5.0  cut: the trucks charge at the low camera; then the countdown on the track (alignment shot)
## SHORT (rematch / 3-4 trucks, 3 s): only the countdown with the alignment shot.

const FULL: String = "full"
const SHORT: String = "short"
const NONE: String = "none"

## Phases of the full intro (seconds). Countdown = Protocol.COUNTDOWN_SECONDS after them.
const PHASES: Array = [["enter", 2.1], ["guard", 0.7], ["title", 0.9], ["bolt", 0.5], ["launch", 0.8]]
## Alignment shot at the start of the countdown (then RaceCinema's side cut, 1.6 s before the go).
const ALIGN_S: float = 1.4
## Lightning strike (intro time, s) and the single flash: white, 0.15 s, peak below full white.
const BOLT_AT: float = 3.78
const FLASH_S: float = 0.15
const FLASH_PEAK: float = 0.85
## "Reduce flashes" on: no white screen; a soft violet glow rising and falling over SOFT_S.
const SOFT_S: float = 0.7
const SOFT_PEAK: float = 0.22
## The bolt itself: the leader comes down in LEADER_S, stays bright HOLD_S and fades in FADE_S.
const LEADER_S: float = 0.06
const HOLD_S: float = 0.1
const FADE_S: float = 0.32
## Captures (--shots=) at these intro times (the countdown ones are taken by the race scene).
const SHOT_TIMES: Array[float] = [0.5, 1.5, 2.45, 3.0, 3.8, 4.05, 4.6]
const COUNT_SHOT_TIMES: Array[float] = [5.5, 6.5, 7.5]


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


## Intro time where phase `name` starts (-1 if unknown).
static func phase_start(name: String) -> float:
	var acc: float = 0.0
	for p in PHASES:
		if String(p[0]) == name:
			return acc
		acc += float(p[1])
	return -1.0


static func phase_len(name: String) -> float:
	for p in PHASES:
		if String(p[0]) == name:
			return float(p[1])
	return 0.0


# ---------------------------------------------------------------- pure curves of the overlay (tested)

## White full-screen flash at intro time `t`: one pulse of FLASH_S right at the strike; 0 with "reduce flashes".
static func flash_alpha(t: float, reduced: bool) -> float:
	var d: float = t - BOLT_AT
	if reduced or d < 0.0 or d >= FLASH_S:
		return 0.0
	var k: float = 1.0 - d / FLASH_S
	return FLASH_PEAK * k * k


## Soft violet glow that replaces the flash with "reduce flashes" on (a slow bump, never white).
static func soft_alpha(t: float, reduced: bool) -> float:
	var d: float = t - BOLT_AT
	if not reduced or d < 0.0 or d >= SOFT_S:
		return 0.0
	return SOFT_PEAK * sin(PI * d / SOFT_S)


## The bolt: [growth 0..1 of the leader from the sky, brightness 0..1]. Dimmer with "reduce flashes".
static func bolt_state(t: float, reduced: bool) -> Vector2:
	var d: float = t - (BOLT_AT - LEADER_S)
	if d < 0.0 or d > LEADER_S + HOLD_S + FADE_S:
		return Vector2.ZERO
	var grow: float = clampf(d / LEADER_S, 0.0, 1.0)
	var after: float = d - LEADER_S - HOLD_S
	var lum: float = 1.0 if after <= 0.0 else 1.0 - after / FADE_S
	return Vector2(grow, lum * (0.6 if reduced else 1.0))


## Black over the whole screen: fade in from black at the start, dip to black right before the cut to the track.
static func black_alpha(t: float) -> float:
	var a: float = 1.0 - clampf(t / 0.35, 0.0, 1.0)
	var end_: float = intro_seconds(FULL)
	return maxf(a, clampf((t - (end_ - 0.1)) / 0.1, 0.0, 1.0))


## Title 対決: [scale, alpha]. Slams in at the taiko (title start), stays through the bolt, fades in the launch.
static func title_state(t: float) -> Vector2:
	var t0: float = phase_start("title")
	var d: float = t - t0
	if d < 0.0:
		return Vector2.ZERO
	var hit: float = clampf(d / 0.16, 0.0, 1.0)
	var k: float = lerpf(2.3, 1.0, 1.0 - pow(1.0 - hit, 3.0))
	var a: float = clampf(d / 0.06, 0.0, 1.0) * (1.0 - clampf((t - phase_start("launch")) / 0.3, 0.0, 1.0))
	return Vector2(k, a)


## The two driver bands at the bottom: 0 = out, 1 = in place (slide in after the taiko, out at the launch).
static func bands_in(t: float) -> float:
	var d: float = t - (phase_start("title") + 0.1)
	if d < 0.0:
		return 0.0
	var e: float = 1.0 - pow(1.0 - clampf(d / 0.22, 0.0, 1.0), 3.0)
	return e * (1.0 - clampf((t - phase_start("launch")) / 0.2, 0.0, 1.0))


## Guardians and auras: 0..1 visibility (rise in the guard phase, gone during the launch).
static func guard_in(t: float) -> float:
	var d: float = t - phase_start("guard")
	if d < 0.0:
		return 0.0
	return clampf(d / 0.55, 0.0, 1.0) * (1.0 - clampf((t - phase_start("launch")) / 0.25, 0.0, 1.0))


# ---------------------------------------------------------------- who sees what

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
