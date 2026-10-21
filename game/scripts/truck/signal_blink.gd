class_name SignalBlink
extends RefCounted
## Turn signal flasher timing (T-170), presentation only: the lamp is lit for HALF_S, dark for HALF_S (~1.5 Hz),
## and the cycle starts LIT at the moment the signal turns on (instant feedback, also for the very short bot signals).
## Used by TruckNode (amber lamps), RaceHud (arrows) and TurnSignalAudio (relay tick on each edge), each with its own
## instance fed with the same TruckSim.signal_dir in the same frame, so they stay in step.

const HALF_S: float = 0.33          # s lit, then s dark (1 / 0.66 s = ~1.5 Hz, like a real flasher)
enum Edge { NONE, LIT, DARK }       # what changed in the last update()

var dir: int = 0                    # side being shown: -1 left, +1 right, 0 off
var lit: bool = false
var _start_s: float = 0.0


## Feed the current signal side and the clock (s). Returns the edge of the lamp in this call.
func update(signal_dir: int, now_s: float) -> int:
	if signal_dir != dir:
		dir = signal_dir
		_start_s = now_s
	var was: bool = lit
	lit = dir != 0 and is_lit_at(now_s - _start_s)
	if lit == was:
		return Edge.NONE
	return Edge.LIT if lit else Edge.DARK


## Lit `elapsed` seconds after the signal turned on?
static func is_lit_at(elapsed: float) -> bool:
	return int(floorf(maxf(elapsed, 0.0) / HALF_S)) % 2 == 0


static func now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0
