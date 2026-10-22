class_name CityLook
extends RefCounted
## T-188: materials and meshes of the city blocks (CityBlocks).
## FACADE: unit box per building (MultiMesh). The shader reads the building size from the instance transform and
## maps the facade atlas (8 styles of 12 m x 14 m, blender/scripts/build_t188_textures.py) in METRES from the corner,
## so the windows match the floors (3,5 m) and bays (3 m). Instance COLOR: rgb = wall tint, a = style/16 (+0.5 =
## shop fronts on the ground floor). Windows: glass reflecting the sky by day, lit at random by night (energy from
## TimeOfDay.window_energy). Roof: concrete with stains and a parapet line.

const ATLAS := "res://assets/textures/scenic/facade_atlas.png"

const FACADE := """
shader_type spatial;
render_mode cull_back;
uniform sampler2D facade : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float energy = 2.0;
uniform float day = 0.0;
uniform vec3 sky_tint : source_color = vec3(0.55, 0.65, 0.8);
varying vec3 lp;
varying vec3 ln;
varying vec3 sz;
varying vec4 tint;
varying float bid;
float hh(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hh(i), hh(i + vec2(1.0, 0.0)), f.x), mix(hh(i + vec2(0.0, 1.0)), hh(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() {
	sz = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	lp = VERTEX * sz;
	ln = NORMAL;
	tint = COLOR;
	bid = hh(MODEL_MATRIX[3].xz * 0.013);
}
void fragment() {
	if (abs(ln.y) > 0.5) {
		vec2 e = sz.xz * 0.5 - abs(lp.xz);
		float parapet = 1.0 - step(0.7, min(e.x, e.y));
		float stain = hh(floor(lp.xz * 0.5) + bid * 50.0);
		vec3 roof = vec3(0.36, 0.36, 0.35) * (0.85 + 0.15 * stain) * (1.0 + 0.25 * parapet);
		ALBEDO = ln.y > 0.0 ? roof : vec3(0.1);
		ROUGHNESS = 0.9;
	} else {
		float u = (abs(ln.x) > 0.5 ? lp.z + sz.z * 0.5 : lp.x + sz.x * 0.5) + (ln.x + ln.z < 0.0 ? 1.5 : 0.0);
		float v = lp.y + sz.y * 0.5;
		float st = floor(fract(tint.a * 2.0) * 8.0 + 0.01);
		bool shop = tint.a >= 0.5 && v < 4.0;
		vec2 cell = shop ? vec2(1.0, 1.0) : vec2(mod(st, 4.0), floor(st / 4.0));
		float vv = shop ? v * 0.875 : v;
		vec2 cont = vec2(u / 12.0, -vv / 14.0);
		vec2 auv = (cell + vec2(fract(cont.x), 1.0 - fract(-cont.y))) * vec2(0.25, 0.5);
		vec4 t = textureGrad(facade, auv, dFdx(cont) * vec2(0.25, 0.5), dFdy(cont) * vec2(0.25, 0.5));
		vec3 wall = t.rgb * mix(vec3(1.0), tint.rgb * 1.6, 0.55) * mix(0.3, 1.0, day);   // night: the moon must not light walls white
		float glass = t.a;
		// T-199: weathering without textures: rain streaks hanging from the parapet (length per 0.6 m column),
		// grime at the foot, soft blotches; stronger on some buildings (bid).
		float col_h = hh(vec2(floor(u * 1.7), bid * 13.0));
		float drip = smoothstep(0.62, 1.0, col_h) * (1.0 - smoothstep(0.0, 3.0 + 14.0 * hh(vec2(floor(u * 1.7), 3.0)), sz.y - v));
		float foot = 1.0 - smoothstep(0.2, 2.4, v);
		float blot = vn(vec2(u, v) * 0.22 + bid * 40.0);
		float dirt = clamp(drip * 0.32 + foot * 0.3 + smoothstep(0.55, 0.95, blot) * 0.16, 0.0, 0.55) * (0.55 + 0.45 * bid);
		wall *= 1.0 - dirt;
		float floor_i = floor(vv / 3.5);
		float bay = floor(u / 3.0);
		float on = step(0.62, hh(vec2(floor_i, bay) + bid * 91.0)) * step(0.18, hh(vec2(floor_i, bid * 17.0)));
		vec3 warm = mix(vec3(1.0, 0.78, 0.45), vec3(0.8, 0.9, 1.0), step(0.7, hh(vec2(bay, floor_i) + bid)));
		ALBEDO = mix(wall, sky_tint * (0.55 + 0.3 * hh(vec2(bay, floor_i))), glass * 0.65 * day);
		EMISSION = warm * glass * (shop ? 1.0 : on) * energy * (0.6 + 0.6 * hh(vec2(floor_i, bay) * 1.3));
		ROUGHNESS = mix(0.85, 0.12, glass * day);
		METALLIC = glass * day * 0.4;
	}
}
"""

## Pitched roof of the low houses (triangular prism): clay or metal sheet in lines.
const ROOF := """
shader_type spatial;
varying vec3 lp;
varying vec4 tint;
void vertex() { lp = VERTEX * vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz)); tint = COLOR; }
void fragment() {
	float rib = 0.8 + 0.2 * step(0.5, fract(lp.x * 3.0));
	ALBEDO = tint.rgb * rib;
	ROUGHNESS = 0.7;
	METALLIC = 0.2;
}
"""

## T-199: darker toward the foot of each box (soft contact shadow) and a little noise per metre (dirt/paint).
const PROPS := """
shader_type spatial;
varying vec4 tint;
varying float ly;
varying vec3 wp;
void vertex() { tint = COLOR; ly = VERTEX.y; wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float n = fract(sin(dot(floor(wp.xz * 1.3) + floor(wp.y * 0.8), vec2(12.9898, 78.233))) * 43758.5453);
	ALBEDO = tint.rgb * (0.8 + 0.2 * smoothstep(-0.5, 0.5, ly)) * (0.93 + 0.07 * n);
	ROUGHNESS = 0.8;
}
"""

static var _prism: ArrayMesh


static func facade(tod: TimeOfDay) -> ShaderMaterial:
	var m: ShaderMaterial = _mat(FACADE)
	m.set_shader_parameter("facade", load(ATLAS) as Texture2D)
	m.set_shader_parameter("energy", tod.window_energy if tod != null else 2.0)
	m.set_shader_parameter("day", tod.day_amount if tod != null else 0.0)
	if tod != null:
		m.set_shader_parameter("sky_tint", tod.sky_horizon.lerp(tod.sky_top, 0.4))
	return m


static func roof() -> ShaderMaterial:
	return _mat(ROOF)


static func props() -> ShaderMaterial:
	return _mat(PROPS)


static func _mat(code: String) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = code
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


## Unit triangular prism: base 1 x 1 (x across, z along the ridge) on y = 0, ridge at y = 1.
static func prism() -> ArrayMesh:
	if _prism != null:
		return _prism
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := Vector3(-0.5, 0, -0.5)
	var b := Vector3(0.5, 0, -0.5)
	var c := Vector3(0.5, 0, 0.5)
	var d := Vector3(-0.5, 0, 0.5)
	var r0 := Vector3(0, 1, -0.5)
	var r1 := Vector3(0, 1, 0.5)
	for tri in [[a, r0, r1], [a, r1, d], [b, c, r1], [b, r1, r0], [a, b, r0], [d, r1, c]]:
		for v in tri:
			st.add_vertex(v)
	st.generate_normals()
	_prism = st.commit()
	return _prism
