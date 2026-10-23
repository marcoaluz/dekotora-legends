class_name LoadClock
extends RefCounted
## T-208: stopwatch of the way into a race (menu click -> scene load -> world build -> first frame of the duel
## opening) and of the hitches of the first frames. Debug only: prints one `LOAD_T208` line per mark and a summary.
## `go()` is called where the scene change starts (SceneFader, main.gd --goto); the race marks its build steps.

static var _go_msec: int = -1
static var _last_msec: int = -1
static var _lines: PackedStringArray = []


## The click (or --goto): the stopwatch starts here.
static func go() -> void:
	_go_msec = Time.get_ticks_msec()
	_last_msec = _go_msec
	_lines = PackedStringArray()


## Milliseconds since go() (-1 if nobody started it: the race scene opened straight from the command line).
static func since_go() -> int:
	return Time.get_ticks_msec() - _go_msec if _go_msec >= 0 else -1


## A step: prints the time since the click and since the previous mark.
static func mark(what: String) -> void:
	var now: int = Time.get_ticks_msec()
	if _go_msec < 0:                                 # opened from the command line: count from the engine start
		_go_msec = 0
		_last_msec = 0
	var line: String = "LOAD_T208 %-28s +%5d ms  (total %5d ms)" % [what, now - _last_msec, now - _go_msec]
	_lines.append(line)
	print(line)
	_last_msec = now
