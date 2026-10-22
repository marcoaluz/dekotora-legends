class_name LifeWind
extends RefCounted
## T-189 (vida): trees and bushes sway with the wind and the leaves flutter. Nothing is rebuilt: after the roadside is
## built, every tree MultiMesh gets a copy of its mesh (one per race and source mesh) whose materials are the same
## StandardMaterial3D settings rewritten as a shader with a vertex sway (`windy_material`). Turned off = untouched meshes.
## The sway grows with the height (VERTEX.y, tree base at 0) and has a phase per copy (world position), so the
## trees do not move in sync. Only visual (Settings.fx_life).

const NAMES: Array[String] = ["tree_", "palm", "bush"]
## sway = metres of bend per (metre of height)^2 / 10; flutter = leaf shiver in metres.
const PALM := {"sway": 0.035, "flutter": 0.05}
const TREE := {"sway": 0.020, "flutter": 0.035}
const BUSH := {"sway": 0.06, "flutter": 0.02}

const SHADER := """
shader_type spatial;
render_mode %s;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec4 albedo : source_color = vec4(1.0);
uniform bool use_tex = false;
uniform bool use_vcol = false;
uniform float scissor = -1.0;
uniform float rough = 1.0;
uniform float sway = 0.02;
uniform float flutter = 0.0;
uniform float strength = 1.0;
uniform vec2 wind_dir = vec2(0.8, 0.6);
void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	float ph = o.x * 0.11 + o.z * 0.07;
	float h = max(VERTEX.y, 0.0);
	float gust = 0.65 + 0.35 * sin(TIME * 0.21 + o.x * 0.004);
	float s = (sin(TIME * 1.15 + ph) * 0.7 + sin(TIME * 2.3 + ph * 1.9) * 0.3) * gust * strength;
	vec3 wl = normalize((inverse(MODEL_MATRIX) * vec4(wind_dir.x, 0.0, wind_dir.y, 0.0)).xyz);
	VERTEX += wl * (s + 0.35 * gust * strength) * sway * h * h * 0.1;
	VERTEX += NORMAL * sin(TIME * 7.0 + dot(VERTEX, vec3(3.1, 2.3, 1.7)) + ph) * flutter * clamp(h * 0.25, 0.0, 1.0) * strength;
}
void fragment() {
	vec4 c = albedo;
	if (use_tex) { c *= texture(albedo_tex, UV); }
	if (use_vcol) { c *= COLOR; }
	ALBEDO = c.rgb;
	if (scissor >= 0.0) {
		ALPHA = c.a;
		ALPHA_SCISSOR_THRESHOLD = scissor;
		ALPHA_ANTIALIASING_EDGE = 0.3;                       // T-195: alpha to coverage with MSAA
		if (use_tex) { ALPHA_TEXTURE_COORDINATE = UV * vec2(textureSize(albedo_tex, 0)); }
	}
	ROUGHNESS = rough;
	SPECULAR = 0.3;
}
"""

static var _shaders: Dictionary = {}


static func is_tree(mesh_name: String) -> bool:
	var base: String = mesh_name.get_file()
	for n in NAMES:
		if base.begins_with(n):
			return true
	return false


static func params_for(mesh_name: String) -> Dictionary:
	var base: String = mesh_name.get_file()
	if base.begins_with("palm"):
		return PALM
	if base.begins_with("bush"):
		return BUSH
	return TREE


## Every tree MultiMesh under `root` gets the swaying copy of its mesh. Returns how many nodes changed.
static func apply(root: Node, strength: float = 1.0) -> int:
	var done: Dictionary = {}           # source mesh -> swaying copy (one per race)
	var n: int = 0
	for mi in root.find_children("*", "MultiMeshInstance3D", true, false):
		var mm: MultiMesh = (mi as MultiMeshInstance3D).multimesh
		if mm == null or mm.mesh == null or not is_tree(mm.mesh.resource_name):
			continue
		if (mi as MultiMeshInstance3D).material_override != null:
			continue
		if not done.has(mm.mesh):
			done[mm.mesh] = windy_copy(mm.mesh as ArrayMesh, params_for(mm.mesh.resource_name), strength)
		if done[mm.mesh] != null:
			mm.mesh = done[mm.mesh]
			n += 1
	return n


## Copy of `src` with every StandardMaterial3D surface turned into the swaying shader (null if not an ArrayMesh).
static func windy_copy(src: ArrayMesh, p: Dictionary, strength: float) -> ArrayMesh:
	if src == null:
		return null
	var out := ArrayMesh.new()
	out.resource_name = src.resource_name
	for s in src.get_surface_count():
		out.add_surface_from_arrays(src.surface_get_primitive_type(s), src.surface_get_arrays(s))
		var m: Material = src.surface_get_material(s)
		out.surface_set_material(s, windy_material(m, p, strength) if m is BaseMaterial3D else m)
	out.custom_aabb = src.get_aabb().grow(1.5)       # the sway must not make it vanish at the screen border
	return out


## StandardMaterial3D -> swaying ShaderMaterial (albedo/texture/vertex colour/alpha scissor/cull/roughness).
static func windy_material(m: BaseMaterial3D, p: Dictionary, strength: float) -> ShaderMaterial:
	var cull: String = "cull_disabled" if m.cull_mode == BaseMaterial3D.CULL_DISABLED else "cull_back"
	if not _shaders.has(cull):
		var sh := Shader.new()
		sh.code = SHADER % cull
		_shaders[cull] = sh
	var out := ShaderMaterial.new()
	out.shader = _shaders[cull]
	out.resource_name = m.resource_name
	out.set_shader_parameter("albedo", m.albedo_color)
	out.set_shader_parameter("use_tex", m.albedo_texture != null)
	if m.albedo_texture != null:
		out.set_shader_parameter("albedo_tex", m.albedo_texture)
	out.set_shader_parameter("use_vcol", m.vertex_color_use_as_albedo)
	var leafy: bool = m.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	out.set_shader_parameter("scissor", m.alpha_scissor_threshold if leafy else -1.0)
	out.set_shader_parameter("rough", m.roughness)
	out.set_shader_parameter("sway", float(p["sway"]))
	out.set_shader_parameter("flutter", float(p["flutter"]) if leafy or String(m.resource_name).contains("leaf") else 0.0)
	out.set_shader_parameter("strength", strength)
	return out
