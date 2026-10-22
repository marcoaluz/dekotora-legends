class_name NeonSigns
extends MultiMeshInstance3D
## T-188: neon shop signs with kanji on the facades and roofs of the city blocks (atlas made by
## tools_dev/make_neon_atlas.gd with Noto Sans JP; fictional names). One MultiMesh, one draw call, unshaded:
## by day a painted board, at night the tubes glow (HDR above the glow threshold -> bloom) with a slow flicker.

const ATLAS := "res://assets/textures/scenic/neon_atlas.png"
const VERTICAL: PackedStringArray = ["中華そば", "居酒屋", "カラオケ", "ホテル", "焼肉", "寿司", "薬局", "珈琲",
	"酒場", "本屋", "銀河", "月光", "竜宮", "喫茶", "旅館", "麺処"]
const HORIZONTAL: PackedStringArray = ["月光ホテル", "居酒屋 竜宮", "カラオケ銀河", "焼肉 炎", "珈琲館", "ゲーム",
	"駐車場 P", "24時間"]
## T-193: signs of docs/Modelos/Letras Japones e neon (blender/scripts/build_t193_neon.py renders them with their own
## neon materials). Pixel rects in the 1024 x 1024 atlas, same as CELLS in the script. One sign in 3 uses this atlas.
const ATLAS_T193 := "res://assets/textures/scenic/neon_t193_atlas.png"
const T193_VERTICAL := Rect2(0, 320, 224, 704)                          # 幻想通り + か
const T193_WIDE := Rect2(0, 0, 1024, 320)                               # 大切に思ってる
const T193_SQUARES: Array[Rect2] = [Rect2(224, 320, 320, 320), Rect2(544, 320, 320, 320), Rect2(224, 640, 320, 320),
	Rect2(544, 640, 160, 160), Rect2(544, 800, 160, 160)]              # 夜空, 無限, 招き猫, 祈, 人

const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform float glow = 0.0;
uniform float day_level = 0.8;
varying vec4 rect;
varying float seed;
void vertex() {
	rect = INSTANCE_CUSTOM;
	seed = fract(sin(dot(MODEL_MATRIX[3].xz, vec2(12.9898, 78.233))) * 43758.5453);
	UV = rect.xy + UV * rect.zw;
}
void fragment() {
	vec4 c = texture(atlas, UV);
	float lum = max(c.r, max(c.g, c.b));
	float tube = smoothstep(0.25, 0.7, lum);
	float flick = (0.85 + 0.15 * sin(TIME * (2.0 + seed * 5.0))) * step(0.06, fract(TIME * 0.13 + seed));
	ALBEDO = c.rgb * day_level + c.rgb * tube * glow * (seed > 0.9 ? flick : 1.0);
}
"""

var count: int = 0
var count_t193: int = 0
var _xf: Array[Transform3D] = []
var _rc: Array[Rect2] = []
var _xf2: Array[Transform3D] = []      # T-193 atlas
var _rc2: Array[Rect2] = []


## UV rect of sign `i`: vertical (0-15) or horizontal (0-7).
static func cell_uv(i: int, vertical: bool) -> Rect2:
	var px: Rect2 = Rect2((i % 8) * 64, (i / 8) * 256, 64, 256) if vertical else Rect2(512 + (i % 2) * 256, (i / 2) * 128, 256, 128)
	return Rect2((px.position + Vector2(2, 2)) / Vector2(1024, 512), (px.size - Vector2(4, 4)) / Vector2(1024, 512))


## Sign of width x height metres, centred at `at`, facing the direction `face` (unit, horizontal).
func add(at: Vector3, face: Vector3, size: Vector2, idx: int, vertical: bool) -> void:
	var b := Basis.looking_at(-face, Vector3.UP)                 # quad front (+Z) toward `face`
	var n: int = _xf.size() + _xf2.size()
	if ResourceLoader.exists(ATLAS_T193) and (idx + n) % 3 == 0:   # T-193 (no extra random number: same layout)
		var r: Rect2 = T193_VERTICAL
		var sz: Vector2 = Vector2(size.y * r.size.x / r.size.y, size.y)
		if not vertical:
			r = T193_WIDE if (idx + n) % 2 == 0 else T193_SQUARES[(idx + n / 3) % T193_SQUARES.size()]
			sz = Vector2(size.x, size.x * r.size.y / r.size.x) if r == T193_WIDE else Vector2(size.y, size.y) * 1.3
		_xf2.append(Transform3D(b * Basis.from_scale(Vector3(sz.x, sz.y, 1.0)), at))
		_rc2.append(Rect2(r.position / 1024.0 + Vector2(1, 1) / 1024.0, r.size / 1024.0 - Vector2(2, 2) / 1024.0))
		return
	_xf.append(Transform3D(b * Basis.from_scale(Vector3(size.x, size.y, 1.0)), at))
	_rc.append(cell_uv(idx, vertical))


func commit(tod: TimeOfDay) -> void:
	count = _xf.size()
	count_t193 = _xf2.size()
	if count_t193 > 0:                                          # T-193: second atlas, one more draw call
		var extra := MultiMeshInstance3D.new()
		extra.name = "NeonT193"
		add_child(extra)
		_fill(extra, _xf2, _rc2, ATLAS_T193, tod)
	if count == 0 or not ResourceLoader.exists(ATLAS):
		visible = count_t193 > 0                                # an empty node (coast town without signs)
		return
	_fill(self, _xf, _rc, ATLAS, tod)


func _fill(mi: MultiMeshInstance3D, xfs: Array[Transform3D], rcs: Array[Rect2], atlas: String, tod: TimeOfDay) -> void:
	var n: int = xfs.size()
	var sh := Shader.new()
	sh.code = SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("atlas", load(atlas) as Texture2D)
	var day: float = tod.day_amount if tod != null else 0.0
	mat.set_shader_parameter("day_level", lerpf(0.35, 0.85, day))
	mat.set_shader_parameter("glow", (tod.neon_energy if tod != null else 1.0) * 2.6 * (1.0 - day))
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	mm.mesh = q
	mm.instance_count = n
	for i in n:
		mm.set_instance_transform(i, xfs[i])
		mm.set_instance_color(i, Color.WHITE)
		var r: Rect2 = rcs[i]
		mm.set_instance_custom_data(i, Color(r.position.x, r.position.y, r.size.x, r.size.y))
	mi.multimesh = mm
