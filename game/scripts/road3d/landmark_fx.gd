class_name LandmarkFx
extends RefCounted
## T-217: shaders and small meshes of the route landmarks: falling water (scrolling streaks + foam), the pool with
## ripples, spray/mist sheets, the rotating lighthouse beam. Unshaded / additive where they are light; all cheap.

const WATER_TEX := "res://assets/textures/t217/water.png"
const MIST_TEX := "res://assets/textures/t217/mist.png"

const FALL := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform sampler2D water : source_color, filter_linear_mipmap, repeat_enable;
uniform float speed = 1.4;
uniform float level = 1.0;
void fragment() {
	vec4 a = texture(water, vec2(UV.x * 1.3, UV.y * 2.2 - TIME * speed));
	vec4 b = texture(water, vec2(UV.x * 0.7 + 0.37, UV.y * 1.3 - TIME * speed * 0.73));
	float edge = smoothstep(0.0, 0.12, UV.x) * smoothstep(1.0, 0.88, UV.x);
	ALBEDO = mix(a.rgb, b.rgb, 0.5) * level;
	ALPHA = clamp((a.a * 0.6 + b.a * 0.6) * edge, 0.0, 0.92);
}
"""

const POOL := """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D water : source_color, filter_linear_mipmap, repeat_enable;
uniform float level = 1.0;
void fragment() {
	vec2 c = UV - vec2(0.5);
	float r = length(c) * 2.0;
	float ring = sin(r * 28.0 - TIME * 4.0) * 0.5 + 0.5;
	vec4 f = texture(water, UV * 3.0 + vec2(TIME * 0.05, TIME * 0.11));
	float foam = clamp((1.0 - r) * 1.4, 0.0, 1.0) * mix(0.4, 1.0, ring) * f.a;
	ALBEDO = mix(vec3(0.06, 0.16, 0.16), vec3(0.85, 0.92, 0.95), foam) * level;
	ROUGHNESS = 0.08;
	METALLIC = 0.2;
	ALPHA = smoothstep(1.0, 0.85, r);
}
"""

const MIST := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform sampler2D mist : filter_linear_mipmap, repeat_disable;
uniform vec4 tint : source_color = vec4(0.85, 0.9, 0.95, 0.35);
uniform float drift = 0.004;
varying float fade;
void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float d = distance(w, CAMERA_POSITION_WORLD);
	fade = smoothstep(25.0, 90.0, d);                         // no hard edges right in front of the camera
}
void fragment() {
	vec2 uv = UV + vec2(sin(TIME * 0.05 + COLOR.r * 6.3) * 0.03, TIME * drift);
	float a = texture(mist, fract(uv)).a * texture(mist, UV).a;
	ALBEDO = tint.rgb;
	ALPHA = clamp(a * tint.a * fade * COLOR.a * 1.6, 0.0, 1.0);
}
"""

const BEAM := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
uniform float strength = 0.6;
void fragment() {
	float along = UV.x;                                       // 0 at the lantern, 1 at the far end
	float across = abs(UV.y - 0.5) * 2.0;
	ALBEDO = vec3(1.0, 0.95, 0.8) * strength * (1.0 - along) * (1.0 - across * across);
	ALPHA = 1.0;
}
"""

static var _cache: Dictionary = {}


static func material(key: String, code: String, params: Dictionary = {}) -> ShaderMaterial:
	var k: String = key + str(params)
	if _cache.has(k):
		return _cache[k]
	var sh := Shader.new()
	sh.code = code
	var m := ShaderMaterial.new()
	m.shader = sh
	for p in params:
		m.set_shader_parameter(p, params[p])
	_cache[k] = m
	return m


static func fall_mat(level: float) -> ShaderMaterial:
	return material("fall", FALL, {"water": load(WATER_TEX), "level": level})


static func pool_mat(level: float) -> ShaderMaterial:
	return material("pool", POOL, {"water": load(WATER_TEX), "level": level})


static func mist_mat(tint: Color) -> ShaderMaterial:
	return material("mist", MIST, {"mist": load(MIST_TEX), "tint": tint})


static func beam_mat(strength: float) -> ShaderMaterial:
	return material("beam", BEAM, {"strength": strength})


## Curved ribbon of falling water: from `top` going down along `down` (unit, mostly -Y) to `bottom_y`, `width` wide,
## facing `face` (horizontal unit vector towards the viewer side). UV.y = 0 at the top.
static func fall_ribbon(top: Vector3, bottom_y: float, width: float, face: Vector3, lean: float = 1.5) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var side: Vector3 = Vector3.UP.cross(face).normalized() * width * 0.5
	var n: int = 12
	var h: float = top.y - bottom_y
	var pts: Array[Vector3] = []
	for k in n + 1:
		var t: float = float(k) / float(n)
		pts.append(top + face * lean * sqrt(t) + Vector3.DOWN * h * t)    # the water leaves the lip and drops
	for k in n:
		var a: Vector3 = pts[k]
		var b: Vector3 = pts[k + 1]
		var v0: float = float(k) / float(n)
		var v1: float = float(k + 1) / float(n)
		var w0: float = 1.0 + 0.6 * v0
		var w1: float = 1.0 + 0.6 * v1
		var quad: Array = [[a - side * w0, Vector2(0, v0)], [a + side * w0, Vector2(1, v0)], [b + side * w1, Vector2(1, v1)],
			[b - side * w1, Vector2(0, v1)]]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_uv(quad[idx][1])
			st.add_vertex(quad[idx][0])
	return st.commit()
