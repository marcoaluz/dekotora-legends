class_name RailKit
extends RefCounted
## Modelos e materiais da ferrovia (T-154; blender/scripts/build_railway_kit.py). Os .glb trazem so geometria + UV;
## os materiais sao feitos aqui pelo NOME (texturas comprimidas em assets/textures/rail/), uma copia por hora do dia.

const DIR := "res://assets/scenery/rail/"
const TEX := "res://assets/textures/rail/"
const BED_U_M: float = 4.8          # rail_bed.png: metros por repeticao ao longo da via
const BED_W_M: float = 11.0         # largura do lastro da via dupla (v 0..BED_V)
const BED_V: float = 0.75
## Faixas (v) da textura da via: [inicio, fim] (UV com v=0 embaixo, como no Blender).
const V_CONCRETE := Vector2(0.775, 0.865)
const V_RAIL_SIDE := Vector2(0.887, 0.898)
const V_RAIL_TOP := Vector2(0.902, 0.918)
const V_WIRE := Vector2(0.945, 0.96)
const V_UNDER := Vector2(0.978, 0.995)

static var _meshes: Dictionary = {}
static var _mats: Dictionary = {}


static func _tex(name: String) -> Texture2D:
	var p: String = TEX + name
	return load(p) as Texture2D if ResourceLoader.exists(p) else null


static func _key(tod: TimeOfDay) -> String:
	return "%.2f" % (tod.day_amount if tod != null else 1.0)


static func material(id: String, tod: TimeOfDay) -> Material:
	var k: String = id + "@" + _key(tod)
	if _mats.has(k):
		return _mats[k]
	var day: float = tod.day_amount if tod != null else 1.0
	var night: float = 1.0 - day
	var m := StandardMaterial3D.new()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	match id:
		"rail_bed":
			m.albedo_texture = _tex("rail_bed.png")
			m.vertex_color_use_as_albedo = true
			m.roughness = 0.9
		"rail_kit":
			m.albedo_texture = _tex("rail_atlas.png")
			m.roughness = 0.75
			m.metallic = 0.2
		"rail_train":
			m.albedo_texture = _tex("rail_atlas.png")
			m.roughness = 0.55
			m.metallic = 0.25
			m.emission_enabled = true
			m.emission_texture = _tex("rail_atlas_emit.png")
			m.emission_energy_multiplier = lerpf(0.5, 3.0, night)
		"lrt_body":
			m.albedo_texture = _tex("lrt_body.png")
			m.roughness = 0.4
			m.metallic = 0.3
		"lrt_door":
			m.albedo_texture = _tex("lrt_door.png")
			m.roughness = 0.45
			m.metallic = 0.3
		"lrt_window":                                   # vidro escuro de dia; a noite o salao aceso
			m.albedo_color = Color(0.1, 0.13, 0.17)
			m.roughness = 0.08
			m.metallic = 0.5
			m.emission_enabled = night > 0.3
			m.emission = Color(1.0, 0.93, 0.78)
			m.emission_energy_multiplier = 1.6 * night
		"lrt_light":
			m.albedo_color = Color(0.85, 0.86, 0.88)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.96, 0.86)
			m.emission_energy_multiplier = lerpf(0.3, 3.5, night)
		"rail_ground":                                  # morro da boca do tunel (mesma grama da pista)
			m.albedo_texture = load("res://assets/textures/grass.png") as Texture2D if ResourceLoader.exists("res://assets/textures/grass.png") else null
			m.albedo_color = Color(0.5, 0.58, 0.48)
			m.vertex_color_use_as_albedo = true
			m.roughness = 0.95
			m.uv1_scale = Vector3(0.125, 0.125, 1.0)
		"rail_station":                                 # cidade: o trem entra num predio de concreto
			var p: String = "res://assets/textures/concrete_streaks.png"
			m.albedo_texture = load(p) as Texture2D if ResourceLoader.exists(p) else null
			m.albedo_color = Color(0.62, 0.62, 0.64)
			m.roughness = 0.85
			m.uv1_scale = Vector3(0.25, 0.25, 1.0)
		_:
			m.albedo_color = Color(0.6, 0.6, 0.62)
	if id in ["rail_ground", "rail_station", "rail_bed"]:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED      # faces construidas sem ordem fixa (muro, fios, morro)
	if day < 0.5 and id in ["rail_bed", "rail_kit"]:
		m.albedo_color = Color(0.8, 0.8, 0.85)          # a noite o concreto nao "acende" com o ambiente
	_mats[k] = m
	return m


## Malha do modelo com os nossos materiais (todas as superficies). null se falta o .glb.
static func mesh(model: String, tod: TimeOfDay) -> ArrayMesh:
	var k: String = model + "@" + _key(tod)
	if _meshes.has(k):
		return _meshes[k]
	var path: String = DIR + model + ".glb"
	if not ResourceLoader.exists(path):
		push_warning("RailKit: falta " + path + " (rode blender/scripts/build_railway_kit.py)")
		_meshes[k] = null
		return null
	var src: ArrayMesh = GlbMesh.merged(path)
	var out := ArrayMesh.new()
	for s in src.get_surface_count():
		var mat: Material = src.surface_get_material(s)
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, src.surface_get_arrays(s))
		out.surface_set_material(out.get_surface_count() - 1, material(mat.resource_name if mat != null else "", tod))
	_meshes[k] = out
	return out


## Celula do atlas 8x8 (rail_atlas.png) -> faixa da textura da via (rail_bed.png). Assim as pecas fixas (portico,
## pilar, boca) entram no MESMO bloco/material do lastro: uma chamada de desenho por bloco em vez de duas.
const CELL_TO_BAND := {0: V_RAIL_TOP, 26: V_RAIL_TOP, 8: V_RAIL_TOP, 4: V_RAIL_SIDE, 1: V_CONCRETE, 25: V_CONCRETE,
	2: V_WIRE, 3: V_WIRE, 12: V_WIRE, 24: V_WIRE}


## Copia do modelo (uma superficie) com o UV apontando para as faixas da textura da via. Em cache.
static func bed_mesh(model: String) -> ArrayMesh:
	var k: String = model + "@bed"
	if _meshes.has(k):
		return _meshes[k]
	var path: String = DIR + model + ".glb"
	if not ResourceLoader.exists(path):
		_meshes[k] = null
		return null
	var src: ArrayMesh = GlbMesh.merged(path)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in src.get_surface_count():
		var arrays: Array = src.surface_get_arrays(s)
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var order: PackedInt32Array = idx if idx.size() > 0 else PackedInt32Array(range(verts.size()))
		for t in range(0, order.size(), 3):
			var c: Vector2 = (uv[order[t]] + uv[order[t + 1]] + uv[order[t + 2]]) / 3.0   # celula pelo centro do triangulo
			var cell: int = clampi(int(c.x * 8.0), 0, 7) + 8 * clampi(int(c.y * 8.0), 0, 7)
			var band: Vector2 = CELL_TO_BAND.get(cell, V_CONCRETE)
			for q in 3:
				var v: int = order[t + q]
				st.set_normal(norms[v])
				st.set_color(Color.WHITE)
				st.set_uv(Vector2(0.5 + verts[v].x * 0.1, 1.0 - lerpf(band.x, band.y, clampf(uv[v].y * 8.0 - floorf(c.y * 8.0), 0.0, 1.0))))
				st.add_vertex(verts[v])
	var out: ArrayMesh = st.commit()
	_meshes[k] = out
	return out


## Desligado por --no-rail (comparar/medir antes e depois).
static func enabled() -> bool:
	return not "--no-rail" in OS.get_cmdline_user_args()
