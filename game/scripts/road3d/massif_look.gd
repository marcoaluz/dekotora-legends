class_name MassifLook
extends RefCounted
## T-188: new look of the snowy massifs of the horizon (BackdropKit, T-169/T-179), the FAR layer of the mountains.
## Before they were flat-shaded grey/white "paper" equal by day and night. Now:
## - smooth normals (the faceted low-poly shading is gone; the silhouette stays the same, already jagged);
## - rock with strata and detail, forest on the low slopes, snow by height/slope (same rules as before);
## - aerial perspective toward the HORIZON colour of the sky (far = lighter and bluer, up to `haze_max`), so the
##   three layers (hills, ridges, massifs) separate by value; at night the moonlit snow glows a little.

const SHADER := """
shader_type spatial;
render_mode cull_back, fog_disabled;
uniform sampler2D detail : filter_linear_mipmap, repeat_enable;
uniform vec3 rock : source_color = vec3(0.4, 0.41, 0.45);
uniform vec3 forest : source_color = vec3(0.1, 0.17, 0.12);
uniform vec3 snow_col : source_color = vec3(0.92, 0.94, 1.0);
uniform float snow_amount = 1.0;
uniform vec3 haze_col : source_color = vec3(0.7, 0.78, 0.86);
uniform float haze_density = 0.00035;
uniform float haze_max = 0.7;
uniform float snow_glow = 0.0;
varying float dist;
varying float hgt;
varying vec3 wpos;
varying vec3 wnrm;
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() {
	dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
	hgt = VERTEX.y / 0.36;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	float up = wnrm.y;
	float n = vnoise(wpos.xz * 0.004) * 0.6 + vnoise(wpos.xz * 0.017) * 0.4;
	float thr = 1.0 - 0.62 * snow_amount;
	float line = mix(0.9, 0.42, snow_amount) + (n - 0.5) * 0.12;
	float s_h = smoothstep(line, line + 0.08, hgt) * smoothstep(0.2, 0.5, up);
	float s = snow_amount > 0.01 ? max(smoothstep(thr, thr + 0.06, COLOR.r), s_h) : 0.0;
	vec4 d = texture(detail, wpos.xz * 0.0018);
	vec3 r = rock * mix(0.55, 1.15, d.b) * (0.86 + 0.14 * sin(wpos.y * 0.07 + n * 6.0)) * mix(0.75, 1.0, COLOR.b);
	float f = (1.0 - smoothstep(0.16, 0.4, hgt + (n - 0.5) * 0.25)) * smoothstep(0.35, 0.65, up);
	vec3 c = mix(r, forest * mix(0.5, 1.25, d.a), f);
	c = mix(c, snow_col, s) * COLOR.g;
	float h = min(haze_max, 1.0 - exp(-dist * haze_density));
	ALBEDO = c * (1.0 - h);
	EMISSION = haze_col * h + snow_col * s * snow_glow * (1.0 - h);
	ROUGHNESS = mix(1.0, 0.75, s);
	SPECULAR = 0.2;
}
"""
const HAZE_MAX := {&"day": 0.62, &"dusk": 0.6, &"night": 0.5}

static var _cache: Dictionary = {}


static func material(tod: TimeOfDay, kind: StringName) -> ShaderMaterial:
	var day: float = tod.day_amount if tod != null else 0.0
	var tid: StringName = tod.id if tod != null else &"night"
	var k: String = "%s@%.2f@%s" % [tid, day, kind]
	if _cache.has(k):
		return _cache[k]
	var sh := Shader.new()
	sh.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	if ResourceLoader.exists(ScenicShaders.DETAIL):
		m.set_shader_parameter("detail", load(ScenicShaders.DETAIL) as Texture2D)
	var horizon: Color = tod.sky_horizon if tod != null else Color("#1a2346")
	var fog: Color = tod.fog_color if tod != null else Color("#1c2446")
	m.set_shader_parameter("haze_col", horizon.lerp(fog, 0.35))
	m.set_shader_parameter("rock", (tod.mountain_color if tod != null else Color("#2a3158")).lerp(Color(0.42, 0.43, 0.47), 0.6 * day))
	m.set_shader_parameter("forest", Color(0.09, 0.15, 0.12).lerp(Color(0.05, 0.08, 0.1), 1.0 - day))
	m.set_shader_parameter("snow_col", Color(0.55, 0.62, 0.8).lerp(Color(0.94, 0.95, 1.0), day))
	m.set_shader_parameter("snow_amount", 1.0 if kind == &"mountain" else 0.5)   # litoral/cidade: so os picos (ver a floresta)
	m.set_shader_parameter("haze_max", float(HAZE_MAX.get(tid, 0.6)))
	m.set_shader_parameter("snow_glow", 0.55 * (1.0 - day))
	_cache[k] = m
	return m


## Same massif with smooth normals (vertices with the same position and colour are merged before the normals).
static func smooth(src: ArrayMesh) -> ArrayMesh:
	var key: int = src.get_instance_id()
	if _cache.has(key):
		return _cache[key]
	var out := ArrayMesh.new()
	out.resource_name = src.resource_name
	for s in src.get_surface_count():
		var arr: Array = src.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if idx.is_empty():
			idx.resize(verts.size())
			for i in verts.size():
				idx[i] = i
		var flat: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var acc: Dictionary = {}                      # rounded position -> sum of the flat normals of its corners
		for t in range(0, idx.size() - 2, 3):
			var a: Vector3 = verts[idx[t]]
			var area: float = (verts[idx[t + 2]] - a).cross(verts[idx[t + 1]] - a).length()
			for k in 3:
				var key2: Vector3i = Vector3i((verts[idx[t + k]] * 1000.0).round())
				acc[key2] = acc.get(key2, Vector3.ZERO) + flat[idx[t + k]] * area
		var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR] if arr[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var csum: Dictionary = {}                     # rounded position -> [sum of corner colours, count]
		for i in cols.size():
			var kc: Vector3i = Vector3i((verts[i] * 1000.0).round())
			var e: Array = csum.get(kc, [Color(0, 0, 0, 0), 0])
			csum[kc] = [e[0] + cols[i], int(e[1]) + 1]
		var nrm := PackedVector3Array()
		nrm.resize(verts.size())
		for i in verts.size():
			var kv: Vector3i = Vector3i((verts[i] * 1000.0).round())
			var sum: Vector3 = acc.get(kv, Vector3.UP)
			nrm[i] = sum.normalized() if sum.length_squared() > 0.0 else Vector3.UP
			if not cols.is_empty():                   # the ravine shading was per face too (facets)
				var e2: Array = csum[kv]
				cols[i] = e2[0] / float(e2[1])
		arr[Mesh.ARRAY_NORMAL] = nrm
		if not cols.is_empty():
			arr[Mesh.ARRAY_COLOR] = cols
		arr[Mesh.ARRAY_TANGENT] = null
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		out.surface_set_material(out.get_surface_count() - 1, src.surface_get_material(s))
	_cache[key] = out
	return out
