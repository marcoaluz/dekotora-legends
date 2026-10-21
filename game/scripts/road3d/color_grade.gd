class_name ColorGrade
extends RefCounted
## T-189: colour grading by time of day (a 3D LUT on Environment.adjustment_color_correction; Ultra only).
## The LUT is applied after the tonemapper, on sRGB values (x = red, y = green, z = blue).
##   dawn  -> golden: warm highlights, soft violet shadows
##   day   -> vivid and saturated: cool shadows, warm sun, more saturation in the dull colours (vibrance)
##   dusk  -> orange/pink sunset: orange highlights, pink midtones, purple shadows
##   night -> blue night with neon: blue shadows/midtones, saturated neon (vibrance), a bit more contrast
## `grade()` is pure (tests); `lut()` builds and caches the texture.

const SIZE: int = 33

## shadow / mid / high = colour multipliers by luminance band; sat = saturation; vib = vibrance (extra saturation for
## the dull colours); con = contrast around 0.5; lift = added to the shadows.
const LOOKS: Dictionary = {
	"dawn": {"shadow": Color(1.02, 0.96, 1.06), "mid": Color(1.05, 0.99, 0.92), "high": Color(1.08, 1.00, 0.84),
		"sat": 1.06, "vib": 0.20, "con": 1.03, "lift": Color(0.020, 0.012, 0.006)},
	"day": {"shadow": Color(0.95, 0.99, 1.07), "mid": Color(1.01, 1.01, 0.99), "high": Color(1.04, 1.02, 0.95),
		"sat": 1.12, "vib": 0.30, "con": 1.06, "lift": Color(0.0, 0.0, 0.006)},
	"dusk": {"shadow": Color(0.96, 0.86, 1.12), "mid": Color(1.07, 0.93, 0.98), "high": Color(1.12, 0.96, 0.84),
		"sat": 1.10, "vib": 0.25, "con": 1.05, "lift": Color(0.012, 0.0, 0.016)},
	"night": {"shadow": Color(0.90, 0.96, 1.12), "mid": Color(0.97, 0.98, 1.04), "high": Color(1.02, 1.00, 1.03),
		"sat": 1.02, "vib": 0.40, "con": 1.08, "lift": Color(0.0, 0.004, 0.018)},
}

static var _cache: Dictionary = {}


## Look id for a time-of-day id (unknown ids use the closest: day).
static func look_of(tod_id: String) -> String:
	return tod_id if LOOKS.has(tod_id) else "day"


## One colour through the grade (sRGB 0..1 in, sRGB 0..1 out).
static func grade(c: Color, look: String) -> Color:
	var p: Dictionary = LOOKS[look_of(look)]
	var l: float = _luma(c)
	var w_sh: float = 1.0 - smoothstep(0.0, 0.45, l)
	var w_hi: float = smoothstep(0.55, 1.0, l)
	var w_mid: float = maxf(1.0 - w_sh - w_hi, 0.0)
	var sh: Color = p["shadow"]
	var mi: Color = p["mid"]
	var hi: Color = p["high"]
	var mul := Color(sh.r * w_sh + mi.r * w_mid + hi.r * w_hi, sh.g * w_sh + mi.g * w_mid + hi.g * w_hi,
		sh.b * w_sh + mi.b * w_mid + hi.b * w_hi)
	var lift: Color = p["lift"]
	var r: float = c.r * mul.r + lift.r * w_sh
	var g: float = c.g * mul.g + lift.g * w_sh
	var b: float = c.b * mul.b + lift.b * w_sh
	# saturation + vibrance (dull colours gain more than the ones already saturated: neon does not clip)
	var l2: float = _luma(Color(r, g, b))
	var chroma: float = maxf(maxf(r, g), b) - minf(minf(r, g), b)
	var s: float = float(p["sat"]) + float(p["vib"]) * (1.0 - clampf(chroma * 2.0, 0.0, 1.0))
	r = l2 + (r - l2) * s
	g = l2 + (g - l2) * s
	b = l2 + (b - l2) * s
	# contrast: gentle S around the middle grey
	var k: float = float(p["con"])
	r = _contrast(r, k)
	g = _contrast(g, k)
	b = _contrast(b, k)
	return Color(clampf(r, 0.0, 1.0), clampf(g, 0.0, 1.0), clampf(b, 0.0, 1.0))


static func _luma(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


static func _contrast(x: float, k: float) -> float:
	var lin: float = 0.5 + (x - 0.5) * k
	return lerpf(x, lin, smoothstep(0.0, 0.15, x) * (1.0 - smoothstep(0.85, 1.0, x)))   # keep pure black/white


## The 3D LUT for a look (cached; ~36k texels, built once per look).
static func lut(look: String) -> ImageTexture3D:
	var id: String = look_of(look)
	if _cache.has(id):
		return _cache[id]
	var slices: Array[Image] = []
	var inv: float = 1.0 / float(SIZE - 1)
	for bz in SIZE:
		var data := PackedByteArray()
		data.resize(SIZE * SIZE * 3)
		var i: int = 0
		for gy in SIZE:
			for rx in SIZE:
				var o: Color = grade(Color(rx * inv, gy * inv, bz * inv), id)
				data[i] = roundi(o.r * 255.0)
				data[i + 1] = roundi(o.g * 255.0)
				data[i + 2] = roundi(o.b * 255.0)
				i += 3
		slices.append(Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RGB8, data))
	var tex := ImageTexture3D.new()
	tex.create(Image.FORMAT_RGB8, SIZE, SIZE, SIZE, false, slices)
	_cache[id] = tex
	return tex
