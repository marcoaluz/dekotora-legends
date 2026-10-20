class_name StartGrid
extends RefCounted
## Start grid (T-156): trucks start SIDE BY SIDE, up to 3 per row (center, left, right lanes).
## 1x1 campaign = player in the center lane, rival in the left lane, side by side.
## Rows behind (4 trucks) start GAP metres back. The last row starts at START_Z (not at 0): there is no road
## before z = 0 and the camera behind the truck needs ~15 m of asphalt (before T-156 the trucks behind the line were
## all drawn at z = 0, on top of each other). Same rule offline, on the server and in the client prediction.

const ROW: Array[float] = [0.0, -0.5, 0.5]     # lane x of each slot in a row (center, left, right)
const PER_ROW: int = 3
const GAP: float = 14.0                         # metres between rows (a truck is 7-12 m long)
const START_Z: float = 30.0                     # rear of the last row (m from the start of the road)
const CAMPAIGN_TRUCKS: int = 2                  # campaign = always 1x1 (player x route rival), Marco T-156
const QUICK_TRUCKS: int = 4                     # quick race = player + 3 bots


## (z, x) of slot `i` in a grid of `n` trucks.
static func slot(i: int, n: int) -> Vector2:
	var rows: int = maxi(1, ceili(float(maxi(n, 1)) / float(PER_ROW)))
	var row: int = i / PER_ROW
	return Vector2(START_Z + float(rows - 1 - row) * GAP, ROW[i % PER_ROW])


## Lane x of slot `i` (bots use it as their preferred lane).
static func lane_x(i: int) -> float:
	return ROW[i % PER_ROW]
