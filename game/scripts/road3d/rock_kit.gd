class_name RockKit
extends RefCounted
## T-188: rock of the pilot stretch (in place of the grey 124-triangle block of rock.glb): a sphere bent by 3D noise,
## flat bottom and a flatter top (boulder), ~260 triangles; material with cracks from the terrain detail texture
## projected on the 3 axes, warm/cool colour variation per rock and moss/grass on the faces that look up.

const MODEL := "rock_t188"

const SHADER := """
shader_type spatial;
uniform sampler2D detail : filter_linear_mipmap, repeat_enable;
uniform vec3 stone : source_color = vec3(0.32, 0.31, 0.29);
uniform vec3 moss : source_color = vec3(0.12, 0.18, 0.07);
uniform float tint = 1.0;
uniform float moss_amount = 0.7;
uniform float night_lift = 0.0;
varying vec3 wpos;
varying vec3 wnrm;
varying float hue;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	hue = fract(sin(dot(MODEL_MATRIX[3].xz, vec2(12.9898, 78.233))) * 43758.5453);
}
void fragment() {
	vec3 w = pow(abs(wnrm), vec3(4.0));
	w /= (w.x + w.y + w.z);
	float k = texture(detail, wpos.yz * 0.45).b * w.x + texture(detail, wpos.xz * 0.45).b * w.y
		+ texture(detail, wpos.xy * 0.45).b * w.z;
	float g = texture(detail, wpos.xz * 0.9).r;
	vec3 base = stone * mix(vec3(1.06, 0.98, 0.9), vec3(0.88, 0.94, 1.04), hue) * mix(0.55, 1.12, k);
	float m = smoothstep(0.78, 0.97, wnrm.y + (g - 0.5) * 0.3) * moss_amount;
	vec3 col = mix(base, moss * mix(0.7, 1.2, g), m) * tint;
	ALBEDO = col;
	EMISSION = col * night_lift * vec3(0.55, 0.68, 1.0);
	ROUGHNESS = mix(0.85, 0.95, m);
	SPECULAR = 0.3;
}
"""

static var _mesh: ArrayMesh
static var _mats: Dictionary = {}


static func mesh() -> ArrayMesh:
	if _mesh != null:
		return _mesh
	var src := SphereMesh.new()
	src.radius = 0.6
	src.height = 1.2
	src.radial_segments = 14
	src.rings = 9
	var arr: Array = src.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n := FastNoiseLite.new()
	n.seed = 188
	n.frequency = 1.6
	n.fractal_octaves = 3
	for i in verts.size():
		var v: Vector3 = verts[i]
		var d: float = 1.0 + 0.32 * n.get_noise_3dv(v * 1.0) + 0.1 * n.get_noise_3dv(v * 3.1 + Vector3(7, 1, 3))
		v *= d
		v.y = maxf(v.y * 0.72, -0.12)                    # flatter, sits on a flat base
		if v.y > 0.3:
			v.y = 0.3 + (v.y - 0.3) * 0.6
		verts[i] = v + Vector3(0.0, 0.12, 0.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	for i in idx:
		st.add_vertex(verts[i])
	st.index()
	st.generate_normals()
	_mesh = st.commit()
	_mesh.resource_name = "rock_t188 (por codigo)"
	return _mesh


static func material(tod: TimeOfDay) -> ShaderMaterial:
	var day: float = tod.day_amount if tod != null else 0.0
	var k: String = "%.2f" % day
	if _mats.has(k):
		return _mats[k]
	var sh := Shader.new()
	sh.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	if ResourceLoader.exists(ScenicShaders.DETAIL):
		m.set_shader_parameter("detail", load(ScenicShaders.DETAIL) as Texture2D)
	m.set_shader_parameter("tint", lerpf(0.9, 1.0, day))
	m.set_shader_parameter("night_lift", 1.8 * (1.0 - day))
	_mats[k] = m
	return m
