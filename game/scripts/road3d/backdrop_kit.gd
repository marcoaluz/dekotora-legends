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
const FOLIAGE_TEX := TEX_DIR + "foliage_leaves.png"     # T-192: pine, cedar, round tree, bush, palms (atlas)
## T-192: code-made trees with layered card foliage (build_foliage_t192.py); materials by name like the Gleditsias.
const FOLIAGE: Array[String] = ["tree_pine", "tree_cedar", "tree_round", "bush", "palm", "palm_tall", "palm_bent"]

## T-179: as montanhas ficam a 1-4 km da pista. A neblina do jogo (feita para 300-600 m) apagava tudo isso na tarde e
## na noite, entao o shader tem a PROPRIA neblina leve (`haze`, pela distancia de verdade, com teto `haze_max`) e
## `fog_disabled`. A camera da corrida enxerga ate CAMERA_FAR (antes 900 m cortava o fundo dos macicos: "laminas").
const MOUNTAIN_SHADER := """
shader_type spatial;
render_mode cull_back, fog_disabled;
uniform vec3 rock : source_color = vec3(0.3, 0.3, 0.34);
uniform vec3 snow_col : source_color = vec3(0.9, 0.93, 1.0);
uniform float snow_amount = 1.0;     // 0 = sem neve, 1 = picos e encostas altas brancas
uniform vec3 haze_col : source_color = vec3(0.6, 0.68, 0.78);
uniform float haze_density = 0.0003; // por metro (distancia real ate a camera)
uniform float haze_max = 0.5;        // a montanha nunca some de todo
uniform float snow_glow = 0.0;       // noite: a neve reflete a lua (um pouco de brilho proprio)
varying float dist;
varying float hgt;
varying float up;
void vertex() {
	dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
	hgt = VERTEX.y / 0.36;           // 0 = pe, ~1 = cume (modelos com 0,30-0,39 de altura)
	up = NORMAL.y;
}
void fragment() {
	float thr = 1.0 - 0.62 * snow_amount;
	float line = mix(0.9, 0.42, snow_amount);                                // linha da neve (altura relativa)
	float s_h = smoothstep(line, line + 0.1, hgt) * smoothstep(0.2, 0.5, up); // encosta alta e pouco inclinada
	float s = snow_amount > 0.01 ? max(smoothstep(thr, thr + 0.06, COLOR.r), s_h) : 0.0;
	vec3 c = mix(rock * mix(0.7, 1.0, COLOR.b), snow_col, s);
	float h = min(haze_max, 1.0 - exp(-dist * haze_density));
	ALBEDO = c * COLOR.g * (1.0 - h);	EMISSION = haze_col * h + snow_col * s * snow_glow * (1.0 - h);
	ROUGHNESS = mix(1.0, 0.75, s);
	SPECULAR = 0.2;
}
"""
const CAMERA_FAR: float = 8000.0      # camera da corrida (RaceScene3D); do fim da rota o macico mais longe fica a ~6,2 km
const HAZE_MAX := {&"day": 0.35, &"dusk": 0.5, &"night": 0.35}

static var _cache: Dictionary = {}


static func enabled() -> bool:
	return not "--no-backdrop" in OS.get_cmdline_user_args()


static func mountains_available() -> bool:
	return enabled() and ResourceLoader.exists(GLB_DIR + MOUNTAINS[0] + ".glb")


static func water_available() -> bool:
	return enabled() and ResourceLoader.exists(WATER_NRM)


## T-192: tree model drawn with the built materials (Gleditsias and the redone code-made trees).
static func is_card_tree(name: String) -> bool:
	return name.begins_with("tree_leafy") or name.trim_suffix("_lod1") in FOLIAGE


static func tree_available() -> bool:
	return enabled() and ResourceLoader.exists(TREE) and ResourceLoader.exists(LEAVES_TEX)


## Malha de um macico (so a geometria; o material vem de mountain_material).
static func mountain_mesh(i: int) -> ArrayMesh:
	return GlbMesh.merged(GLB_DIR + MOUNTAINS[i % MOUNTAINS.size()] + ".glb")


## Quanta neve por cenario: montanha = cheia; litoral e cidade = picos e encostas altas (T-179: antes 0,45, so as
## pontas, e de longe nao se via neve nenhuma).
static func snow_for(kind: StringName) -> float:
	return 1.0 if kind == &"mountain" else 0.8


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
	m.set_shader_parameter("rock", rock.lerp(Color(0.4, 0.43, 0.5), 0.8 * day))   # dia: cinza-azulado de distancia
	m.set_shader_parameter("snow_col", Color(0.5, 0.56, 0.74).lerp(Color(0.92, 0.94, 1.0), day))
	m.set_shader_parameter("snow_amount", snow_for(kind))
	var fog_c: Color = tod.fog_color if tod != null else Color("#141a33")
	var fog_d: float = tod.fog_density if tod != null else 0.0028
	var tid: StringName = tod.id if tod != null else &"night"
	m.set_shader_parameter("haze_col", fog_c)
	m.set_shader_parameter("haze_density", minf(fog_d, 0.0004))   # leve: 1 km = ~1/3 de neblina
	m.set_shader_parameter("haze_max", float(HAZE_MAX.get(tid, 0.4)))
	m.set_shader_parameter("snow_glow", 0.45 * (1.0 - day))
	_cache[k] = m
	return m


static func water_normal() -> Texture2D:
	return load(WATER_NRM) as Texture2D


## Arvore de folhas com os materiais do jogo (cache por hora do dia).
static func tree_mesh(tod: TimeOfDay) -> ArrayMesh:
	return tree_mesh_of("tree_leafy", tod)


## T-186: qualquer das 6 Gleditsias (tree_leafy, tree_leafy_b.._f) e o LOD1 delas ("<nome>_lod1"); cada variacao
## tem o proprio atlas de tufos (`<nome>_leaves.png`, o LOD1 usa o da variacao). Malha vazia se faltar o arquivo.
static func tree_mesh_of(name: String, tod: TimeOfDay) -> ArrayMesh:
	var day: float = tod.day_amount if tod != null else 0.0
	var k: String = "%s@%.2f" % [name, day]
	if _cache.has(k):
		return _cache[k]
	var glb: String = "res://assets/scenery/%s.glb" % name
	var src: ArrayMesh = GlbMesh.merged(glb)
	var out := ArrayMesh.new()
	out.resource_name = glb                   # T-181: source shown by the explorer camera
	var base: String = name.trim_suffix("_lod1")
	var leaves: StandardMaterial3D = _leaves(day, FOLIAGE_TEX if base in FOLIAGE else TEX_DIR + base + "_leaves.png")
	var bark: StandardMaterial3D = _bark(day)
	for s in src.get_surface_count():
		var mname: String = src.surface_get_material(s).resource_name if src.surface_get_material(s) != null else ""
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, src.surface_get_arrays(s))
		out.surface_set_material(out.get_surface_count() - 1, leaves if mname.begins_with("tree_leaves") else bark)
	_cache[k] = out
	return out


static func _bark(day: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1, 1, 1).lerp(Color(1.2, 1.15, 1.1), day)
	m.roughness = 1.0
	return m


static func _leaves(day: float, tex: String = LEAVES_TEX) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(tex if ResourceLoader.exists(tex) else LEAVES_TEX) as Texture2D
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(0.85, 0.9, 0.85).lerp(Color(1.05, 1.05, 1.0), day)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.95
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return m
