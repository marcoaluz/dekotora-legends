class_name TollAtlas
extends RefCounted
## Atlas of the toll plaza (T-207): assets/textures/toll/toll_atlas.png, 1024 x 1024, drawn by
## tools_dev/make_toll_atlas.gd (needs a window: fonts). The generator and the game use the SAME map.
## Our own art: shapes drawn in code + Noto Sans JP (OFL, already in the project). No real operator logo.

const ATLAS := "res://assets/textures/toll/toll_atlas.png"
const SIZE: int = 1024
## id -> pixel rect
const RECTS: Dictionary = {
	"fascia": Rect2i(0, 0, 1024, 80),             # canopy front: panels, green band, 料金所 TOLL GATE plate
	"fascia_back": Rect2i(0, 80, 1024, 80),       # canopy back: panels, ありがとう band (thanks), no plate
	"panel": Rect2i(0, 160, 256, 128),            # canopy sides: panels with seams, green band, rain streaks
	"ceiling": Rect2i(256, 160, 256, 128),        # canopy underside: panel grid with 2 LED strips (off)
	"booth": Rect2i(512, 160, 256, 128),          # booth long side: wall, blue band, window (glass by day)
	"booth_lit": Rect2i(768, 160, 256, 128),      # same, warm lit window with the attendant (night)
	"sign_etc": Rect2i(0, 288, 256, 128),         # ETC 専用 (purple)
	"sign_mix": Rect2i(256, 288, 256, 128),       # ETC / 一般 (purple + green)
	"road_etc": Rect2i(512, 288, 256, 128),       # purple pavement with ETC (painted on the right passage)
	"road_general": Rect2i(768, 288, 256, 128),   # green pavement with 一般 (left passage)
	"booth_end": Rect2i(0, 416, 128, 128),        # booth front/back: door with a small window
	"chevron": Rect2i(128, 416, 128, 128),        # crash cushion front: black chevrons on yellow (pass both sides)
	"stripes": Rect2i(256, 416, 128, 128),        # yellow / black diagonal stripes (curb noses, bar, cushion)
	"keep_both": Rect2i(384, 416, 128, 128),      # blue round sign: pass on both sides
	"signal_go": Rect2i(512, 416, 128, 128),      # lane signal: green arrow down
	"signal_stop": Rect2i(640, 416, 128, 128),    # lane signal: red X
	"pillar": Rect2i(768, 416, 128, 128),         # painted steel (pale green-grey), darker foot
	"white": Rect2i(896, 416, 128, 128),          # plain white (paint, lamps)
	"steel": Rect2i(0, 544, 128, 128),            # galvanised steel (gantry, posts)
	"antenna": Rect2i(128, 544, 128, 128),        # ETC antenna box face
	"lamp": Rect2i(256, 544, 128, 128),           # LED panel (lit: glow material)
	"roof": Rect2i(384, 544, 128, 128),           # dark roof cap / canopy top
	"beacon": Rect2i(512, 544, 128, 128),         # amber warning lamp
	"dark": Rect2i(640, 544, 128, 128),           # near-black (signal boxes, frames)
	"curb": Rect2i(768, 544, 128, 128),           # island curb top: concrete with a yellow edge line
	"glass": Rect2i(896, 544, 128, 128),          # small glass (booth ends, office)
}


static func has(id: String) -> bool:
	return RECTS.has(id)


## UV 0..1 of the id (1.5 px inset against mipmap bleeding).
static func uv(id: String) -> Rect2:
	var r: Rect2i = RECTS.get(id, RECTS["white"])
	return Rect2((Vector2(r.position) + Vector2(1.5, 1.5)) / SIZE, (Vector2(r.size) - Vector2(3, 3)) / SIZE)


## UV of a sub-rectangle of the id (u0, v0, u1, v1 in 0..1 of the cell): pieces of the fascia, booth, ceiling...
static func sub(id: String, u0: float, v0: float, u1: float, v1: float) -> Rect2:
	var r: Rect2 = uv(id)
	return Rect2(r.position + r.size * Vector2(u0, v0), r.size * Vector2(u1 - u0, v1 - v0))
