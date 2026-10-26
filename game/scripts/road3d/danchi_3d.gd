class_name Danchi3D
extends Node3D
## T-217: draws DanchiLayout: 5-floor concrete apartment slabs (団地) with balconies facing the expressway (parapets
## with rain stains, sliding windows lit at night, laundry hanging, AC units), antennas on the roof and the block
## number painted on the end wall (N号棟); small 2-4 floor buildings with a shop front below. Texture atlas made by
## code (build_t217_textures.py: danchi_atlas.png). One MeshInstance3D per run, 2 surfaces (walls + laundry).

const ATLAS := "res://assets/textures/t217/danchi_atlas.png"
const BAY: float = 3.6
const BALCONY: float = 1.2
const VIEW_M: float = 900.0
const TINTS: Array[Color] = [Color(1.0, 1.0, 1.0), Color(0.93, 0.95, 0.92), Color(1.0, 0.96, 0.9), Color(0.9, 0.92, 0.95)]
const SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform float night = 0.0;
varying vec3 wpos;
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec4 c = texture(atlas, UV);
	ALBEDO = c.rgb * COLOR.rgb;
	float glass = step(0.5, c.a) * COLOR.a;
	float cell = h21(floor(wpos.xz / 3.4) + floor(wpos.y / 2.8) * 7.31);
	float on = step(0.58, cell);
	vec3 warm = mix(vec3(1.0, 0.72, 0.42), vec3(0.75, 0.88, 1.0), step(0.86, cell));
	float curtain = mix(0.55, 1.0, step(0.75, c.a));       // curtains glow softer
	EMISSION = glass * on * night * warm * curtain * mix(0.55, 0.95, fract(cell * 13.7));
	ROUGHNESS = mix(0.92, 0.25, glass);
}
"""

var path: TrackPath
var layout: DanchiLayout
var counts: Dictionary = {}
var tris: int = 0
var _deck: float = 0.0
var _st: SurfaceTool
var _wash: SurfaceTool
var _night: float = 0.0


func build(layout_: DanchiLayout, kind: StringName, tod: TimeOfDay) -> void:
	layout = layout_
	path = layout.path
	_deck = RoadMesh.deck_height(kind)
	_night = 1.0 - tod.day_amount if tod != null else 0.0
	var tex: Texture2D = load(ATLAS) as Texture2D
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	mat.shader = sh
	mat.set_shader_parameter("atlas", tex)
	mat.set_shader_parameter("night", _night)
	var wash := StandardMaterial3D.new()
	wash.albedo_texture = tex
	wash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	wash.alpha_scissor_threshold = 0.5
	wash.cull_mode = BaseMaterial3D.CULL_DISABLED
	wash.vertex_color_use_as_albedo = true
	var group: int = -1
	for b in layout.blocks:
		var g: int = int(float(b[0]) / 300.0)
		if g != group:
			_flush(mat, wash)
			group = g
			_st = SurfaceTool.new()
			_st.begin(Mesh.PRIMITIVE_TRIANGLES)
			_wash = SurfaceTool.new()
			_wash.begin(Mesh.PRIMITIVE_TRIANGLES)
		if int(b[6]) == 0:
			_slab(b)
		else:
			_small(b)
	_flush(mat, wash)


func _flush(mat: Material, wash: Material) -> void:
	if _st == null:
		return
	tris += Ribbon.add_mesh(self, _st, mat, VIEW_M)
	tris += Ribbon.add_mesh(self, _wash, wash, 320.0)
	_st = null


## Local frame of a block: origin on the ground at the middle of the road-side face, x along the road, z away
## from the road (towards the back of the building).
func _frame(b: Array) -> Transform3D:
	var zm: float = (float(b[0]) + float(b[1])) * 0.5
	var side: float = float(b[2])
	var f: Vector3 = path.forward_at(zm)
	var away: Vector3 = path.right_at(zm) * side
	var o: Vector3 = path.world_point(zm, side * float(b[3]) / Track.ROAD_HALF_WIDTH_M, -_deck)
	return Transform3D(Basis(f, Vector3.UP, away), o)


func _uv(cx: int, cy: int) -> Rect2:
	return Rect2(Vector2(cx * 0.25, cy * 0.5) + Vector2(0.003, 0.006), Vector2(0.25, 0.5) - Vector2(0.006, 0.012))


## Quad from 4 local points (bottom-left, bottom-right, top-right, top-left) with an atlas cell; a = 1 marks glass.
func _q(st: SurfaceTool, xf: Transform3D, p: Array, cell: Rect2, col: Color) -> void:
	var uv: Array = [cell.position + Vector2(0, cell.size.y), cell.position + cell.size, cell.position + Vector2(cell.size.x, 0),
		cell.position]
	for k in [0, 1, 2, 0, 2, 3]:
		st.set_color(col)
		st.set_uv(uv[k])
		st.add_vertex(xf * (p[k] as Vector3))


func _box(st: SurfaceTool, xf: Transform3D, lo: Vector3, hi: Vector3, cell: Rect2, col: Color) -> void:
	var c: Array = [Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(lo.x, hi.y, lo.z),
		Vector3(lo.x, lo.y, hi.z), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z)]
	for f in [[0, 1, 2, 3], [5, 4, 7, 6], [4, 0, 3, 7], [1, 5, 6, 2], [3, 2, 6, 7]]:
		_q(st, xf, [c[f[0]], c[f[1]], c[f[2]], c[f[3]]], cell, col)


func _slab(b: Array) -> void:
	var xf: Transform3D = _frame(b)
	var L: float = float(b[1]) - float(b[0])
	var D: float = float(b[4]) - float(b[3])
	var floors: int = int(b[5])
	var H: float = DanchiLayout.FLOOR_H
	var top: float = H * float(floors)
	var tint: Color = TINTS[int(b[7]) % TINTS.size()]
	var wall := Color(tint.r, tint.g, tint.b, 0.0)
	var bays: int = maxi(int(L / BAY), 4)
	var bw: float = L / float(bays)
	var x0: float = -L * 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = int(b[7]) * 7919 + int(float(b[0]))
	for k in floors:
		var y: float = float(k) * H
		for i in bays:
			var xa: float = x0 + float(i) * bw
			var xb: float = xa + bw
			# window / sliding door wall behind the balcony (a = 1: the shader lights the glass at night)
			_q(_st, xf, [Vector3(xa, y + 0.2, BALCONY), Vector3(xb, y + 0.2, BALCONY), Vector3(xb, y + H, BALCONY),
				Vector3(xa, y + H, BALCONY)], _uv(2, 0), Color(tint.r, tint.g, tint.b, 1.0))
			# balcony slab (top and its edge) and the parapet with stains
			_q(_st, xf, [Vector3(xa, y + 0.2, 0.0), Vector3(xb, y + 0.2, 0.0), Vector3(xb, y + 0.2, BALCONY),
				Vector3(xa, y + 0.2, BALCONY)], _uv(2, 1), wall * 0.9)
			_q(_st, xf, [Vector3(xa, y, 0.0), Vector3(xb, y, 0.0), Vector3(xb, y + 1.25, 0.0), Vector3(xa, y + 1.25, 0.0)],
				_uv(1, 0), wall)
			if i % 2 == 0:                               # partition between two flats
				_q(_st, xf, [Vector3(xa, y + 0.2, 0.0), Vector3(xa, y + 0.2, BALCONY), Vector3(xa, y + H, BALCONY),
					Vector3(xa, y + H, 0.0)], _uv(0, 0), wall * 0.92)
			if rng.randf() < 0.42:                      # laundry on the balcony pole
				var lx: float = xa + rng.randf_range(0.1, 0.6)
				_q(_wash, xf, [Vector3(lx, y + H - 1.45, 0.55), Vector3(lx + bw * 0.75, y + H - 1.45, 0.55),
					Vector3(lx + bw * 0.75, y + H - 0.25, 0.55), Vector3(lx, y + H - 0.25, 0.55)], _uv(3, 0), Color.WHITE)
			if rng.randf() < 0.3:                       # air-conditioner outdoor unit on the balcony floor
				_box(_st, xf, Vector3(xb - 1.0, y + 0.2, 0.35), Vector3(xb - 0.25, y + 0.8, 0.85), _uv(1, 0), Color(0.95, 0.95, 0.93, 0.0))
	# end walls (the one seen by the drivers gets the block number), back wall, roof with parapet
	for e in [[x0, -1.0], [-x0, 1.0]]:
		var ex: float = float(e[0])
		_q(_st, xf, [Vector3(ex, 0, 0), Vector3(ex, 0, D), Vector3(ex, top + 0.6, D), Vector3(ex, top + 0.6, 0)], _uv(1, 1), wall)
	_q(_st, xf, [Vector3(-x0, 0, D), Vector3(x0, 0, D), Vector3(x0, top + 0.6, D), Vector3(-x0, top + 0.6, D)], _uv(0, 0), wall * 0.85)
	_q(_st, xf, [Vector3(x0, top, 0), Vector3(-x0, top, 0), Vector3(-x0, top, D), Vector3(x0, top, D)], _uv(2, 1), Color(1, 1, 1, 0))
	_q(_st, xf, [Vector3(x0, top, 0), Vector3(-x0, top, 0), Vector3(-x0, top + 0.6, 0), Vector3(x0, top + 0.6, 0)], _uv(0, 0), wall)
	for a in rng.randi_range(2, 4):                      # TV antennas on the roof
		var ax: float = rng.randf_range(x0 + 3.0, -x0 - 3.0)
		_box(_st, xf, Vector3(ax - 0.04, top, D * 0.6), Vector3(ax + 0.04, top + 2.6, D * 0.6 + 0.08), _uv(0, 1), Color(0.5, 0.5, 0.5, 0.0))
		_box(_st, xf, Vector3(ax - 0.9, top + 2.2, D * 0.6), Vector3(ax + 0.9, top + 2.26, D * 0.6 + 0.06), _uv(0, 1), Color(0.5, 0.5, 0.5, 0.0))
	_box(_st, xf, Vector3(-x0 - 6.0, top, D * 0.3), Vector3(-x0 - 3.0, top + 2.2, D * 0.7), _uv(1, 1), wall * 0.95)   # stair/lift hut
	_number(xf, x0, D, top, int(b[7]))
	counts["danchi"] = int(counts.get("danchi", 0)) + 1


## Block number painted on the end wall seen by the drivers (Label3D, dark grey, ~2 m tall).
func _number(xf: Transform3D, x0: float, D: float, top: float, n: int) -> void:
	var l := Label3D.new()
	l.text = "%d号棟" % n
	l.font = load(RoadFurniture.SIGN_FONT) as Font
	l.font_size = 128
	l.pixel_size = 0.016
	l.modulate = Color(0.25, 0.27, 0.32)
	l.outline_size = 0
	l.shaded = true
	l.double_sided = false
	l.visibility_range_end = 420.0
	var back: Vector3 = -xf.basis.x.normalized()           # faces the drivers coming along the road
	l.transform = Transform3D(Basis(Vector3.UP.cross(back), Vector3.UP, back), xf * Vector3(x0 - 0.05, top - 2.6, D * 0.5))
	add_child(l)


func _small(b: Array) -> void:
	var xf: Transform3D = _frame(b)
	var L: float = float(b[1]) - float(b[0])
	var D: float = float(b[4]) - float(b[3])
	var floors: int = int(b[5])
	var H: float = 3.0
	var top: float = H * float(floors)
	var x0: float = -L * 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = int(float(b[0]) * 13.0)
	var tint: Color = TINTS[rng.randi_range(0, TINTS.size() - 1)] * Color(0.92, 0.9, 0.86)
	var wall := Color(tint.r, tint.g, tint.b, 0.0)
	_q(_st, xf, [Vector3(x0, 0, 0), Vector3(-x0, 0, 0), Vector3(-x0, H, 0), Vector3(x0, H, 0)], _uv(3, 1), wall)   # shop front
	for k in range(1, floors):
		var y: float = float(k) * H
		var n: int = maxi(int(L / 3.2), 2)
		for i in n:
			var xa: float = x0 + L * float(i) / float(n)
			var xb: float = x0 + L * float(i + 1) / float(n)
			_q(_st, xf, [Vector3(xa, y, 0), Vector3(xb, y, 0), Vector3(xb, y + H, 0), Vector3(xa, y + H, 0)], _uv(2, 0),
				Color(tint.r, tint.g, tint.b, 1.0))
	for e in [x0, -x0]:
		_q(_st, xf, [Vector3(e, 0, 0), Vector3(e, 0, D), Vector3(e, top + 0.5, D), Vector3(e, top + 0.5, 0)], _uv(0, 0), wall)
	_q(_st, xf, [Vector3(-x0, 0, D), Vector3(x0, 0, D), Vector3(x0, top + 0.5, D), Vector3(-x0, top + 0.5, D)], _uv(0, 0), wall)
	_q(_st, xf, [Vector3(x0, top, 0), Vector3(-x0, top, 0), Vector3(-x0, top, D), Vector3(x0, top, D)], _uv(2, 1), Color(1, 1, 1, 0))
	_q(_st, xf, [Vector3(x0, top, 0), Vector3(-x0, top, 0), Vector3(-x0, top + 0.5, 0), Vector3(x0, top + 0.5, 0)], _uv(0, 0), wall)
	var sign_col: Color = [Color(0.85, 0.15, 0.15, 0.0), Color(0.15, 0.4, 0.8, 0.0), Color(0.95, 0.75, 0.1, 0.0)][rng.randi_range(0, 2)]
	_box(_st, xf, Vector3(x0 + 1.0, H + 0.4, -0.5), Vector3(x0 + 1.6, top - 0.2, -0.1), _uv(0, 1), sign_col)   # vertical sign
	counts["small"] = int(counts.get("small", 0)) + 1
