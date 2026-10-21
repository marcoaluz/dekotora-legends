class_name PontesKit
extends RefCounted
## Pecas da T-163, tiradas dos modelos de docs/Modelos/Road_pontes (Royalty Free, no AI) pelo
## blender/scripts/build_road_pontes_kit.py: pilar em "T" (Ponte A), guard-rail em "W" e poste de energia (kit road).
## Aqui ficam as chaves de depuracao, os materiais (feitos no codigo, um por hora do dia) e o perfil do guard-rail.
## --no-pontes-kit volta ao visual antigo (pilares de caixa, guard-rail de lamina, sem postes): comparar e medir.
## --no-poles tira so os postes de energia.

const DIR := "res://assets/scenery/kit/"
const CONCRETE_TEX := "res://assets/textures/concrete_streaks.png"
const GUARDRAIL_TEX := "res://assets/textures/kit/guardrail_albedo.png"
const PROFILE_JSON := "res://assets/scenery/kit/guardrail_w_profile.json"
## Perfil em W de reserva (= o .json gerado): [profundidade para a pista, altura, v da textura], de baixo para cima.
const PROFILE_FALLBACK: Array = [[0.0174, 0.4214, 0.4973], [0.0654, 0.4757, 0.4185], [0.0654, 0.4999, 0.3924],
	[0.018, 0.5547, 0.3136], [0.0185, 0.6769, 0.1821], [0.0654, 0.7307, 0.1043], [0.0654, 0.7548, 0.0783],
	[0.0174, 0.8091, 0.0]]
const GR_LEN: float = 4.36               # um painel do guard-rail (uma repeticao da textura)
const GR_POST_TOP: float = 0.87          # topo dos postes
const GR_POST_EVERY: float = 4.0         # m entre postes na lamina continua
const GR_POST_V := Vector2(0.55, 0.95)   # faixa das costas da lamina na textura (postes)

static var _mats: Dictionary = {}
static var _profile: Array = []
static var _meshes: Dictionary = {}


static func enabled() -> bool:
	return not "--no-pontes-kit" in OS.get_cmdline_user_args()


static func poles_enabled() -> bool:
	return enabled() and not "--no-poles" in OS.get_cmdline_user_args()


static func _key(tod: TimeOfDay) -> String:
	return "%.2f" % (tod.day_amount if tod != null else 1.0)


## Concreto dos pilares e postes: cor por vertice x textura de manchas de chuva (triplanar, sem UV).
static func concrete(tod: TimeOfDay, scale: float = 0.25) -> StandardMaterial3D:
	var k: String = "concrete@%s@%.2f" % [_key(tod), scale]
	if _mats.has(k):
		return _mats[k]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.9
	if ResourceLoader.exists(CONCRETE_TEX):
		m.albedo_texture = load(CONCRETE_TEX) as Texture2D
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3(scale, scale, scale)
	if tod != null and tod.lamps_on:
		m.albedo_color = Color(0.85, 0.85, 0.9)
	_mats[k] = m
	return m


## Aco galvanizado do guard-rail (textura do kit sem a faixa amarela) e dos corrimaos das pontes; duas faces.
static func guardrail(tod: TimeOfDay) -> StandardMaterial3D:
	var k: String = "guardrail@" + _key(tod)
	if _mats.has(k):
		return _mats[k]
	var m := StandardMaterial3D.new()
	var day: float = tod.day_amount if tod != null else 1.0
	if ResourceLoader.exists(GUARDRAIL_TEX):
		m.albedo_texture = load(GUARDRAIL_TEX) as Texture2D
		m.albedo_color = Color(1.15, 1.15, 1.18) if day > 0.5 else Color(1.0, 1.02, 1.08)
	else:
		m.albedo_color = Color("#c4ccd8")
	m.metallic = 0.45
	m.roughness = 0.45
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mats[k] = m
	return m


## Perfil em W (lido do .json do Blender; o de reserva se faltar).
static func profile() -> Array:
	if not _profile.is_empty():
		return _profile
	if FileAccess.file_exists(PROFILE_JSON):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_JSON))
		if d is Dictionary and (d as Dictionary).has("points"):
			_profile = (d as Dictionary)["points"]
	if _profile.is_empty():
		_profile = PROFILE_FALLBACK
	return _profile


## Malha de um .glb do kit com `mat` em todas as superficies (cache por material).
static func mesh(model: String, mat: Material) -> ArrayMesh:
	var k: String = "%s@%d" % [model, mat.get_instance_id()]
	if _meshes.has(k):
		return _meshes[k]
	var path: String = DIR + model + ".glb"
	if not ResourceLoader.exists(path):
		push_warning("PontesKit: falta " + path + " (rode blender/scripts/build_road_pontes_kit.py)")
		_meshes[k] = null
		return null
	var src: ArrayMesh = GlbMesh.merged(path)
	var out := ArrayMesh.new()
	for s in src.get_surface_count():
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, src.surface_get_arrays(s))
		out.surface_set_material(out.get_surface_count() - 1, mat)
	_meshes[k] = out
	return out
