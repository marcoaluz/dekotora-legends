class_name RoadsideKit
extends RefCounted
## Kit de beira de estrada da T-146 (modelos do Marco em docs/Novas Melhorias, reduzidos pelo
## blender/scripts/build_roadside_kit.py): barreiras de concreto listradas e cavaletes (eventos de pista e boca dos
## tuneis), chapas de placa e postes (RoadSigns), portico de trelica (RoadFurniture) e outdoors (KitProps3D).
## Os .glb trazem so geometria + UV; os materiais sao feitos aqui pelo NOME do material do .glb (texturas
## comprimidas em assets/textures/kit/). Uma copia da malha por (modelo, hora do dia), em cache.

const DIR := "res://assets/scenery/kit/"
const TEX := "res://assets/textures/kit/"
const ART_DIR := "res://assets/scenery/billboards/"
const ART_USER := "user://billboards/"
const ART_COUNT: int = 4
const MODELS: Array[String] = ["barrier_jersey", "barrier_jersey_fence", "barrier_wall", "barrier_aframe",
	"barrier_aframe_s", "debris_metal", "sign_plate_round", "sign_plate_tri", "sign_plate_diamond", "sign_plate_rect",
	"sign_post", "gantry_truss", "billboard_low", "billboard_tall"]
## Medidas (m) dos modelos: comprimento no sentido da pista (barreiras) / poste: altura 1 (o jogo estica).
const JERSEY_LEN: float = 1.74
const JERSEY_W: float = 0.67
const WALL_W: float = 0.51               # muro listrado (barrier_wall): 0,51 x 1,30 m de altura x 1,74 m
const AFRAME_LEN: float = 2.78
const GANTRY_HALF: float = 13.5
const GANTRY_BEAM_FRONT: float = 0.43    # meia secao da viga: as placas do portico ficam na frente disto
const BILL_ART := Vector2(9.6, 3.6)
const BILL_LEG := {"billboard_low": 7.0, "billboard_tall": 16.0}

static var _meshes: Dictionary = {}       # "modelo@nivel" -> ArrayMesh com os nossos materiais
static var _mats: Dictionary = {}         # "material@nivel" -> Material


static func _tex(name: String) -> Texture2D:
	var p: String = TEX + name
	return load(p) as Texture2D if ResourceLoader.exists(p) else null


## Nivel de luz da hora do dia (as barreiras listradas sao refletivas a noite).
static func _key(tod: TimeOfDay) -> String:
	return "%.2f" % (tod.day_amount if tod != null else 1.0)


static func material(id: String, tod: TimeOfDay) -> Material:
	var k: String = id + "@" + _key(tod)
	if _mats.has(k):
		return _mats[k]
	var day: float = tod.day_amount if tod != null else 1.0
	var m: Material
	match id:
		"kit_barrier":
			var o := ORMMaterial3D.new()
			o.albedo_texture = _tex("barrier_albedo.png")
			o.orm_texture = _tex("barrier_orm.png")
			o.normal_enabled = true
			o.normal_texture = _tex("barrier_nrm.png")
			o.albedo_color = Color(1.3, 1.27, 1.18)  # a textura original e escura (sujeira); no Compatibility ficava preta
			o.normal_scale = 0.6
			o.emission_enabled = true               # tinta refletiva: um pouco de brilho proprio, mais a noite
			o.emission_texture = o.albedo_texture
			o.emission = Color(1, 1, 1)
			o.emission_energy_multiplier = 0.25 + 0.6 * (1.0 - day)
			o.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			m = o
		"kit_sign_metal":
			var s := StandardMaterial3D.new()
			s.albedo_texture = _tex("sign_metal.png")
			s.albedo_color = Color(0.92, 0.93, 0.95) if day > 0.5 else Color(0.62, 0.64, 0.68)
			s.metallic = 0.45
			s.roughness = 0.5
			m = s
		"kit_truss":
			var t := StandardMaterial3D.new()
			t.albedo_texture = _tex("truss_fence.png")
			t.albedo_color = Color(1.0, 1.0, 1.0) if day > 0.5 else Color(0.7, 0.72, 0.78)
			t.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			t.alpha_scissor_threshold = 0.5
			t.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE   # T-195
			t.alpha_antialiasing_edge = 0.3
			t.cull_mode = BaseMaterial3D.CULL_DISABLED
			t.metallic = 0.35
			t.roughness = 0.6
			t.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			m = t
		_:
			var d := StandardMaterial3D.new()
			d.albedo_color = Color(0.6, 0.6, 0.62)
			m = d
	_mats[k] = m
	return m


## Malha do modelo (todas as superficies juntas) com os nossos materiais. null se o .glb nao existe.
static func mesh(model: String, tod: TimeOfDay) -> ArrayMesh:
	var k: String = model + "@" + _key(tod)
	if _meshes.has(k):
		return _meshes[k]
	var path: String = DIR + model + ".glb"
	if not ResourceLoader.exists(path):
		push_warning("RoadsideKit: falta " + path + " (rode blender/scripts/build_roadside_kit.py)")
		_meshes[k] = null
		return null
	var src: ArrayMesh = GlbMesh.merged(path)
	var out := ArrayMesh.new()
	out.resource_name = path                  # T-181: source shown by the explorer camera
	for s in src.get_surface_count():
		var mat: Material = src.surface_get_material(s)
		var name: String = mat.resource_name if mat != null else ""
		if name == "kit_art":
			continue                              # a arte do outdoor e um quadrado a parte (KitProps3D)
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, src.surface_get_arrays(s))
		out.surface_set_material(out.get_surface_count() - 1, material(name, tod))
	_meshes[k] = out
	return out


## Chapa (com borda e cantos arredondados) atras da face de uma placa do SignAtlas e quanto ela ocupa da face:
## [modelo, escala x, escala y, de cabeca para baixo]. As formas seguem o desenho do atlas (make_sign_atlases.gd).
static func plate_for(id: String) -> Array:
	if id.begins_with("spd_"):
		return ["sign_plate_round", 0.97, 0.97, false]
	if id.begins_with("warn_"):
		return ["sign_plate_diamond", 0.985, 0.985, false]
	if id == "stop":                               # 止まれ: triangulo de ponta para baixo
		return ["sign_plate_tri", 0.97, 0.91, true]
	return ["sign_plate_rect", 1.0, 1.0, false]


## Transform da chapa: `b`/`c` = base e centro da face (+Z para quem vem); a chapa fica 1 cm atras.
static func plate_xform(b: Basis, c: Vector3, size: Vector2, id: String) -> Array:
	var p: Array = plate_for(id)
	var bs: Basis = b * Basis.from_scale(Vector3(size.x * float(p[1]), size.y * float(p[2]), 1.0))
	if bool(p[3]):
		bs = bs * Basis(Vector3.BACK, PI)
	return [String(p[0]), Transform3D(bs, c - b.z * 0.012)]


## Poste redondo com base (o modelo mede 1 m): de `base` ate a altura `h`.
static func post_xform(base: Vector3, h: float) -> Transform3D:
	return Transform3D(Basis.from_scale(Vector3(1.3, h, 1.3)), base)


## Arte do outdoor `i` (1..ART_COUNT): user://billboards/ad_0i.png tem prioridade (trocar sem reimportar).
static func art(i: int) -> Texture2D:
	var name: String = "ad_%02d.png" % i
	var user: String = ART_USER + name
	if FileAccess.file_exists(user):
		var img := Image.load_from_file(ProjectSettings.globalize_path(user))
		if img != null and not img.is_empty():
			img.generate_mipmaps()
			return ImageTexture.create_from_image(img)
	var p: String = ART_DIR + name
	return load(p) as Texture2D if ResourceLoader.exists(p) else null


## Desligado por --no-kit (depuracao: medir o custo, comparar antes/depois).
static func enabled() -> bool:
	return not "--no-kit" in OS.get_cmdline_user_args()
