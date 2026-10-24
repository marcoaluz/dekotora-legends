class_name DecoStyle
extends RefCounted
## Cor L/R e letreiro das pecas da oficina (T-211; catalog.json "style": "deco"). As pecas vem do Blender com
## materiais por PAPEL (deco_body, deco_trim, deco_led, deco_neon, acrylic_sign, acrylic_art; ver
## blender/scripts/accessories/t211_kit.py); aqui cada papel vira o material da cor escolhida (DecoColorDef) e o
## acrilico ganha o atlas compartilhado de letreiros. O nome do letreiro e uma lista pronta (decisao 9 do Marco):
## a escolha so desloca a UV (uv1_offset), sem textura nova. Chame ANTES do AccessoryGlow/ChromeMatcap/LightPatterns.

const ATLAS_PATH := "res://assets/vehicles/dekotora/textures/deck_signs.png"
const ATLAS_COLS: int = 4
const ATLAS_ROWS: int = 4
## Mesma ordem de blender/scripts/t211_atlas.py (SIGNS): celula i = nome i.
const SIGN_NAMES: Array[String] = ["銀河丸", "一番星", "爆走丸", "龍神丸", "桜吹雪", "天翔丸", "浪花節", "男一匹", "夜桜",
	"鳳凰丸", "雷神丸", "唐獅子"]
const ROLES: Array[String] = ["deco_body", "deco_trim", "deco_led", "deco_neon"]
## Peca quebrada: luzes apagadas (nunca some: "dano sem buraco", secao 13.6 do catalogo).
const BROKEN_TILT_DEG: float = 7.0

static var _sign_mats: Dictionary = {}       # "cell" -> StandardMaterial3D (acrylic_sign deslocado para a celula)
static var _art_mat: StandardMaterial3D
static var _lens_mats: Dictionary = {}       # "lamp_x@lens" -> StandardMaterial3D


static func is_deco(entry: Dictionary) -> bool:
	return String(entry.get("style", "")) == "deco"


## Luz de fabrica de um papel ("led" | "neon") para a cor `color_id` (id de DecoLightDef; "" se a cor usa uma luz fora
## da tabela).
static func default_light(color_id: String, role: String) -> String:
	var cd: DecoColorDef = DecoColorDef.find(color_id)
	if cd == null:
		return ""
	var ld: DecoLightDef = DecoLightDef.by_lamp(cd.led if role == "led" else cd.neon)
	return String(ld.id) if ld != null else ""


## Cor de fabrica da peca (id de DecoColorDef).
static func default_color(entry: Dictionary) -> String:
	return String(entry.get("default_color", "preto_ciano"))


## Celula do letreiro de fabrica da peca (-1 = sem letreiro).
static func default_sign(entry: Dictionary) -> int:
	return int(entry.get("sign_cell", -1))


## Aplica cor, letreiro e luzes numa peca montada. `color_id` "" = de fabrica; `sign` -1 = de fabrica; `led`/`neon`
## (T-214) = id de DecoLightDef ("" = a luz da cor escolhida). Estrutura e painel ganham a textura de detalhe; os LEDs
## usam o material com lente (LightPatterns.LENS_SUFFIX).
static func apply(node: Node3D, entry: Dictionary, color_id: String = "", sign: int = -1, led: String = "", neon: String = "") -> void:
	var cdef: DecoColorDef = DecoColorDef.find(color_id if color_id != "" else default_color(entry))
	if cdef == null:
		cdef = DecoColorDef.find(default_color(entry))
	var cell: int = sign if sign >= 0 and sign < SIGN_NAMES.size() else default_sign(entry)
	var roles: Dictionary = cdef.roles() if cdef != null else {}
	for pair in [["deco_led", led], ["deco_neon", neon]]:
		var ld: DecoLightDef = DecoLightDef.find(String(pair[1])) if String(pair[1]) != "" else null
		if ld != null:
			roles[pair[0]] = ld.lamp
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		if m.mesh == null:
			continue
		for s in m.mesh.get_surface_count():
			var cur: Material = m.mesh.surface_get_material(s)
			if cur == null:
				continue
			var n: String = cur.resource_name
			if roles.has(n):
				m.set_surface_override_material(s, role_material(n, String(roles[n])))
			elif n == "acrylic_sign" and cell >= 0:
				m.set_surface_override_material(s, sign_material(cell, default_sign(entry)))
			elif n == "acrylic_art":
				m.set_surface_override_material(s, art_material())


## Material de um papel: estrutura/painel com detalhe, LED com lente, neon liso.
static func role_material(role: String, mat_name: String) -> Material:
	if role == "deco_body" or role == "deco_trim":
		return AccessoryMaterials.make_detailed(mat_name)
	if role == "deco_led" and mat_name.begins_with("lamp_"):
		var key: String = mat_name + LightPatterns.LENS_SUFFIX
		if not _lens_mats.has(key):
			var dup: StandardMaterial3D = AccessoryMaterials.make(mat_name).duplicate() as StandardMaterial3D
			dup.resource_name = key
			_lens_mats[key] = dup
		return _lens_mats[key]
	return AccessoryMaterials.make(mat_name)


## Material do acrilico do letreiro mostrando a celula `cell`; a malha foi feita na celula `base`.
static func sign_material(cell: int, base: int) -> StandardMaterial3D:
	var key: String = "%d/%d" % [cell, base]
	if _sign_mats.has(key):
		return _sign_mats[key]
	var m := _atlas_base("acrylic_sign", 1.6)
	var d: Vector2 = cell_uv(cell) - cell_uv(base)
	m.uv1_offset = Vector3(d.x, d.y, 0.0)
	_sign_mats[key] = m
	return m


static func art_material() -> StandardMaterial3D:
	if _art_mat == null:
		_art_mat = _atlas_base("acrylic_art", 0.9)
	return _art_mat


## Canto de cima a esquerda da celula no atlas (UV do Godot: v para baixo).
static func cell_uv(cell: int) -> Vector2:
	return Vector2(float(cell % ATLAS_COLS) / ATLAS_COLS, float(cell / ATLAS_COLS) / ATLAS_ROWS)


## Acrilico aceso por dentro = material SEM luz (unshaded) com a textura. Nao usa emissao: no Compatibility a
## `emission_texture` e ignorada e a emissao lisa branquearia as cores do letreiro (armadilha da T-207). O nome
## deixa de comecar com "acrylic_" de proposito (o AccessoryGlow ligaria a emissao).
static func _atlas_base(name: String, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = name.replace("acrylic_", "deco_")
	m.albedo_texture = load(ATLAS_PATH) as Texture2D if ResourceLoader.exists(ATLAS_PATH) else null
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1, 1, 1) * minf(energy, 1.0)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


## Estado "quebrada" de uma peca da oficina: continua no lugar, torta, cromo vira aco e as luzes apagam.
static func set_broken(node: Node3D, catalog: AccessoryCatalog) -> void:
	node.visible = true
	if not node.has_meta("broken_tilt"):              # T-214: soma a inclinacao ao assento (nao apaga escala/cisalhamento)
		node.set_meta("broken_tilt", true)
		var tilt: float = deg_to_rad(BROKEN_TILT_DEG) * (1.0 if node.get_instance_id() % 2 == 0 else -1.0)
		node.transform.basis = node.transform.basis * Basis.from_euler(Vector3(deg_to_rad(3.0), 0.0, tilt))
	var off: StandardMaterial3D = AccessoryMaterials.make("lamp_off")
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		if m.mesh == null:
			continue
		for s in m.mesh.get_surface_count():
			var cur: Material = m.get_active_material(s)
			var src: Material = m.mesh.surface_get_material(s)
			var n: String = src.resource_name if src != null else ""
			if n in ["deco_led", "deco_neon", "acrylic_sign", "acrylic_art"] or (cur != null and cur.resource_name.begins_with("lamp_")):
				# (o letreiro "apaga" tambem: placa escura, como uma peca sem energia)
				m.set_surface_override_material(s, off)
	catalog.swap_material(node, "chrome", "steel")
