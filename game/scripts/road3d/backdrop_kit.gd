class_name BackdropKit
extends RefCounted
## Pecas da T-169 tiradas dos modelos novos de docs/Modelos (liberados pelo Marco):
## - montanhas do horizonte (blender/scripts/build_backdrop_kit.py, "Fundo Montanha Gelo"): 4 macicos de ~900
##   triangulos (mountain_a..d.glb) com a neve marcada na cor por vertice (R = onde a neve pega, G = sombra das
##   ravinas); o shader decide quanta neve aparece (rota e hora do dia). Substituem os cones de CityBuilder;
## - ondas do mar (pacote "Agua"): mapa de normais repetivel (water_waves_nrm.png) no lugar do ruido gerado;
## - arvore de folhas (build_tree_kit.py, "Arvore"/Gleditsia): tree_leafy.glb, ~280 triangulos, tronco por cor de
##   vertice + 20 tufos em cartoes cruzados com recorte por alfa (tree_leafy_leaves.png).
## --no-backdrop volta aos cones, ao ruido e as arvores antigas (comparar e medir).

const GLB_DIR := "res://assets/scenery/backdrop/"
const TEX_DIR := "res://assets/textures/backdrop/"
const MOUNTAINS: Array[String] = ["mountain_a", "mountain_b", "mountain_c", "mountain_d"]
const TREE := "res://assets/scenery/tree_leafy.glb"
const WATER_NRM := TEX_DIR + "water_waves_nrm.png"
const LEAVES_TEX := TEX_DIR + "tree_leafy_leaves.png"

const MOUNTAIN_SHADER := """
shader_type spatial;
render_mode cull_back;
uniform vec3 rock : source_color = vec3(0.3, 0.3, 0.34);
uniform vec3 snow_col : source_color = vec3(0.9, 0.93, 1.0);
uniform float snow_amount = 1.0;     // 0 = sem neve, 1 = picos e encostas altas brancas
void fragment() {
	float thr = 1.0 - 0.62 * snow_amount;
	float s = snow_amount > 0.01 ? smoothstep(thr, thr + 0.06, COLOR.r) : 0.0;
	vec3 c = mix(rock * mix(0.7, 1.0, COLOR.b), snow_col, s);
	ALBEDO = c * COLOR.g;
	ROUGHNESS = mix(1.0, 0.75, s);
	SPECULAR = 0.2;
}
"""

static var _cache: Dictionary = {}


static func enabled() -> bool:
	return not "--no-backdrop" in OS.get_cmdline_user_args()


static func mountains_available() -> bool:
	return enabled() and ResourceLoader.exists(GLB_DIR + MOUNTAINS[0] + ".glb")


static func water_available() -> bool:
	return enabled() and ResourceLoader.exists(WATER_NRM)


static func tree_available() -> bool:
	return enabled() and ResourceLoader.exists(TREE) and ResourceLoader.exists(LEAVES_TEX)


## Malha de um macico (so a geometria; o material vem de mountain_material).
static func mountain_mesh(i: int) -> ArrayMesh:
	return GlbMesh.merged(GLB_DIR + MOUNTAINS[i % MOUNTAINS.size()] + ".glb")


## Quanta neve por cenario: montanha = cheia; litoral e cidade = so os picos.
static func snow_for(kind: StringName) -> float:
	return 1.0 if kind == &"mountain" else 0.45


static func mountain_material(tod: TimeOfDay, kind: StringName) -> ShaderMaterial:
	var day: float = tod.day_amount if tod != null else 0.0
	var k: String = "mount@%.2f@%s" % [day, kind]
	if _cache.has(k):
		return _cache[k]
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = MOUNTAIN_SHADER
	m.shader = sh
	var rock: Color = tod.mountain_color if tod != null else Color("#16143a")
	m.set_shader_parameter("rock", rock.lerp(Color(0.36, 0.37, 0.4), 0.35 * day))
	m.set_shader_parameter("snow_col", Color(0.32, 0.36, 0.52).lerp(Color(0.92, 0.94, 1.0), day))
	m.set_shader_parameter("snow_amount", snow_for(kind))
	_cache[k] = m
	return m


static func water_normal() -> Texture2D:
	return load(WATER_NRM) as Texture2D


## Arvore de folhas com os materiais do jogo (cache por hora do dia).
static func tree_mesh(tod: TimeOfDay) -> ArrayMesh:
	var day: float = tod.day_amount if tod != null else 0.0
	var k: String = "tree@%.2f" % day
	if _cache.has(k):
		return _cache[k]
	var src: ArrayMesh = GlbMesh.merged(TREE)
	var out := ArrayMesh.new()
	for s in src.get_surface_count():
		var name: String = src.surface_get_material(s).resource_name if src.surface_get_material(s) != null else ""
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, src.surface_get_arrays(s))
		out.surface_set_material(out.get_surface_count() - 1, _leaves(day) if name.begins_with("tree_leaves") else _bark(day))
	_cache[k] = out
	return out


static func _bark(day: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1, 1, 1).lerp(Color(1.2, 1.15, 1.1), day)
	m.roughness = 1.0
	return m


static func _leaves(day: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(LEAVES_TEX) as Texture2D
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(0.85, 0.9, 0.85).lerp(Color(1.05, 1.05, 1.0), day)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.95
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return m
