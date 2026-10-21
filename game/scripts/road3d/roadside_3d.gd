class_name Roadside3D
extends Node3D
## Objetos de beira de estrada em 3D (postes, arvores, placas, guard-rails, pedagio) usando os .glb do
## Blender (assets/scenery/) em MultiMesh: poucos draw calls. Le `track.objects` (mesma lista da versao 2D)
## e escolhe a vegetacao pelo cenario: litoral = palmeiras + arbustos + pedras na praia; montanha = pinheiros
## + pedras; cidade = arvores redondas/pinheiros + arbustos. Extras so visuais (semente fixa, sem mexer na sim).
## Postes acesos (TimeOfDay.lamps_on): "poca" de luz de sodio pintada no asfalto (quad aditivo, sem luz real:
## o Compatibility so aceita 8 luzes por objeto). De dia as lampadas ficam apagadas.

const DIR := "res://assets/scenery/"
const CHUNK_M: float = 150.0      # um MultiMesh por modelo e por trecho: o corte por distancia (visibility_range)
                                  # usa o centro do bloco; um bloco do tamanho da pista inteira sumia de vez
const POOL := "pool"              # chave dos grupos das pocas de luz

var path: TrackPath
var tod: TimeOfDay
var bridges: Array[Vector2] = []  # T-153 (RouteDef.bridges): nada de arvore/pedra em cima do mar
var pole_runs: Array = []         # T-163 (PowerLineLayout.corridors): arvores saem do caminho dos fios
var overpass_out: Array = []      # T-164 (OverpassLayout.keep_out): nada de poste/arvore/placa embaixo do viaduto
const WIRE_LANE: Vector2 = Vector2(14.5, 20.0)   # T-163: faixa lateral (m) dos fios; a arvore vai para fora dela
const TREE_LOD_M: float = 140.0   # T-186: arvore troca para o LOD1 a partir desta distancia (centro do bloco)
const VIEW_M: float = 450.0
const LAMPS: Array[String] = ["lamp_post", "lamp_bridge"]
const TOLL_ZONE: Vector2 = Vector2(0.0, 420.0)   # T-186: o poste antigo fica na praca do pedagio (z = 150)
var rails: Array = []             # T-186: Array[RailLine] (Railway3D.lines): arvore fora da ferrovia paralela
var route_seed: int = 0           # T-186: semente dos bosques (mesma rota -> mesmas arvores)
var tree_count: int = 0           # T-186: quantas arvores foram plantadas (testes/medidas)
var _pool_mesh: PlaneMesh
var _lamp_off: Dictionary = {}


func build(path_: TrackPath, kind: StringName = &"city", tod_: TimeOfDay = null, tunnels: Array[Vector2] = []) -> void:
	path = path_
	tod = tod_ if tod_ != null else TimeOfDay.by_id(&"night")
	var deck: float = RoadMesh.deck_height(kind)    # viaduto: o que fica alem da mureta esta la embaixo, no chao
	var groups: Dictionary = {}     # nome do modelo -> Array[Transform3D]
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for o in path.track.objects:
		var z: float = float(o["z"])
		var xu: float = float(o["x"])
		if RoadMesh.in_tunnel(z, tunnels, 6.0):
			continue                                  # dentro do tunel nao ha postes nem arvores
		var k: String = String(o["kind"])
		if RoadMesh.in_tunnel(z, bridges, 12.0) and k != "lamp_post":
			continue                                  # T-153: ponte (embaixo e o mar)
		if LaneSections.at(path.track.events, z, 4.0) != null:   # T-153: trecho de 2 faixas
			if k == "guardrail" or k == "sign_green" or (deck > 0.0 and k != "lamp_post" and absf(xu) * Track.ROAD_HALF_WIDTH_M < RoadMesh.BARRIER_IN + 2.0):
				continue
			if k == "lamp_post":                      # o poste vai para cima da mureta que estreitou
				var p: Vector3 = LaneSections.profile(path.track.events, z)
				xu = signf(xu) * ((p.x if xu < 0.0 else p.y) + 0.35) / Track.ROAD_HALF_WIDTH_M
		var outside: bool = absf(xu) * Track.ROAD_HALF_WIDTH_M > RoadMesh.BARRIER_IN
		var base: Vector3 = path.world_point(z, xu, -deck if outside else 0.0)
		if not overpass_out.is_empty() and k != "guardrail" and OverpassLayout.blocked(overpass_out, base, 1.5):
			continue
		var yaw: float = path.yaw_at(z)
		var model: String = k
		var b := Basis(Vector3.UP, yaw)
		match k:
			"lamp_post":
				model = lamp_model(z, deck, kind, bridges)
				if xu < 0.0:
					b = Basis(Vector3.UP, yaw + PI)   # o braco aponta para a pista
				if tod.lamps_on and tod.pool_energy > 0.0:
					_put(groups, POOL, Transform3D(Basis(Vector3.UP, yaw), path.world_point(z, xu * 0.6, 0.06)))
			"tree":
				if groves_enabled():                  # T-186: os bosques (RoadsideTrees) entram no lugar
					for _i in 4:
						rng.randf()                   # mesmos 4 sorteios de antes: pedras e arbustos nao mudam
					continue
				model = _tree_model(kind, rng, xu)
				base = _off_wires(z, xu, base, deck)
				var sc: float = rng.randf_range(0.8, 1.5)
				b = Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(sc, sc * rng.randf_range(0.9, 1.3), sc))
			"guardrail":
				if PontesKit.enabled():                   # T-163: guard-rail em W do kit (lamina para a pista)
					model = "guardrail_w"
					if xu < 0.0:
						b = Basis(Vector3.UP, yaw + PI)
			"sign_green":
				if deck > 0.0:
					continue                          # no viaduto as placas ficam nos porticos
				b = Basis(Vector3.UP, yaw + PI)       # o texto fica legivel para quem vem pela pista
		_put(groups, model, Transform3D(b, base))
	_extras(groups, kind, rng, deck, tunnels)
	if groves_enabled():
		var blocked: Callable = func(zz: float, lat: float, pos: Vector3) -> bool: return _tree_blocked(zz, lat, pos, tunnels)
		for t in RoadsideTrees.place(path, kind, 186 + route_seed, deck, blocked, rails):
			_put(groups, String(t[0]), t[1])
			tree_count += 1
	var pool_mat: StandardMaterial3D = _pool_material()
	for key in groups:
		var name: String = String(key).get_slice("#", 0)
		if name == POOL:
			_add_multi(_pool(), groups[key], pool_mat)
		elif name in LAMPS and not tod.lamps_on:
			_add_multi(_lamp_unlit(name), groups[key])
		elif name.begins_with("tree_leafy"):
			var far: ArrayMesh = BackdropKit.tree_mesh_of(name + "_lod1", tod) if ResourceLoader.exists("%s%s_lod1.glb" % [DIR, name]) else null
			_add_multi(BackdropKit.tree_mesh_of(name, tod), groups[key], null, far)
		elif name == "guardrail_w":
			_add_multi(PontesKit.mesh("guardrail_w", PontesKit.guardrail(tod)), groups[key])
		else:
			var lod1: String = "%s%s_lod1.glb" % [DIR, name]
			_add_multi(GlbMesh.merged("%s%s.glb" % [DIR, name]), groups[key], null,
				GlbMesh.merged(lod1) if ResourceLoader.exists(lod1) else null)


## T-186: bosques novos ligados (padrao); `--old-trees` volta as arvores enfileiradas de antes (comparar e medir).
static func groves_enabled() -> bool:
	return not "--old-trees" in OS.get_cmdline_user_args()


## T-186: os 2 postes de luz. O da ponte (Ponte A, mais alto, braco curto) nas pontes, no viaduto da cidade e na
## serra; o antigo (lamp_post) na praca do pedagio e no trecho urbano do litoral.
static func lamp_model(z: float, deck: float, kind: StringName, bridges_: Array[Vector2]) -> String:
	if not ResourceLoader.exists(DIR + "lamp_bridge.glb") or "--old-lamps" in OS.get_cmdline_user_args():
		return "lamp_post"
	if z >= TOLL_ZONE.x and z <= TOLL_ZONE.y:
		return "lamp_post"
	if deck > 0.0 or kind == &"mountain" or RoadMesh.in_tunnel(z, bridges_, 12.0):
		return "lamp_bridge"
	return "lamp_post"


## T-186: lugar proibido para arvore: tunel, ponte (mar embaixo), embaixo do viaduto, no caminho dos fios.
func _tree_blocked(z: float, lat: float, pos: Vector3, tunnels: Array[Vector2]) -> bool:
	if RoadMesh.in_tunnel(z, tunnels, 6.0) or RoadMesh.in_tunnel(z, bridges, 14.0):
		return true
	if not overpass_out.is_empty() and OverpassLayout.blocked(overpass_out, pos, 3.0):
		return true
	if absf(lat) >= WIRE_LANE.x - 1.0 and absf(lat) <= WIRE_LANE.y + 1.0:
		for r in pole_runs:
			if z >= float(r[0]) - 20.0 and z <= float(r[1]) + 20.0 and signf(lat) == float(r[2]):
				return true
	return false


## T-163: arvore no caminho dos fios dos postes de energia vai 6 m para fora (mesmo sorteio, so muda o lugar).
func _off_wires(z: float, xu: float, base: Vector3, deck: float) -> Vector3:
	var lat: float = absf(xu) * Track.ROAD_HALF_WIDTH_M
	if lat < WIRE_LANE.x or lat > WIRE_LANE.y:
		return base
	for r in pole_runs:
		if z >= float(r[0]) - 20.0 and z <= float(r[1]) + 20.0 and signf(xu) == float(r[2]):
			return path.world_point(z, signf(xu) * (lat + 6.0) / Track.ROAD_HALF_WIDTH_M, -deck)
	return base


## T-169: com o kit, a arvore de folhas (Gleditsia, BackdropKit) entra no lugar da redonda na cidade, em 35% da
## montanha (entre os pinheiros) e em 35% do litoral do lado da terra (T-179: eram 25% e 20%, quase nao se notava).
## Um sorteio so (a sequencia nao muda).
func _tree_model(kind: StringName, rng: RandomNumberGenerator, xu: float = 0.0) -> String:
	var r: float = rng.randf()
	var leafy: bool = BackdropKit.tree_available()
	match kind:
		&"coast":
			if leafy and xu < 0.0 and r >= 0.65:
				return "tree_leafy"
			return "palm" if r < 0.7 else "bush"
		&"mountain":
			if leafy and r >= 0.45 and r < 0.8:
				return "tree_leafy"
			return "tree_pine" if r < 0.8 else "rock"
	return "tree_pine" if r < 0.45 else (("tree_leafy" if leafy else "tree_round") if r < 0.85 else "bush")


func _put(groups: Dictionary, model: String, t: Transform3D) -> void:
	var key: String = "%s#%d_%d" % [model, int(floor(t.origin.x / CHUNK_M)), int(floor(t.origin.z / CHUNK_M))]
	if not groups.has(key):
		groups[key] = []
	groups[key].append(t)


## Vegetacao extra fora da pista (arbustos ao pe da mureta, pedras na praia/encosta).
func _extras(groups: Dictionary, kind: StringName, rng: RandomNumberGenerator, deck: float, tunnels: Array[Vector2]) -> void:
	var z: float = 10.0
	var hw: float = Track.ROAD_HALF_WIDTH_M
	while z < path.track.length_m - 5.0:
		var yaw: float = path.yaw_at(z)
		var sc: float = rng.randf_range(0.6, 1.3)
		var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3.ONE * sc)
		var left: Vector3 = path.world_point(z, -rng.randf_range(14.5, 19.0) / hw, -deck)
		if RoadMesh.in_tunnel(z, tunnels, 6.0) or RoadMesh.in_tunnel(z, bridges, 14.0):
			z += 20.0
			continue
		_put(groups, "bush" if kind != &"mountain" else "rock", Transform3D(b, left))
		if kind == &"coast":                     # pedras na areia, perto do mar
			var beach: Vector3 = path.world_point(z + 6.0, rng.randf_range(27.0, 36.0) / hw, -1.0)
			_put(groups, "rock", Transform3D(Basis(Vector3.UP, yaw + rng.randf()) * Basis.from_scale(Vector3.ONE * rng.randf_range(0.7, 1.8)), beach))
		z += rng.randf_range(14.0, 30.0)


## Um MultiMesh por modelo e bloco. Com `far` (T-186: LOD1), dois: o detalhado ate TREE_LOD_M e o leve dali ate
## VIEW_M (a troca e por bloco: o centro do bloco decide).
func _add_multi(mesh: Mesh, xforms: Array, mat: Material = null, far: Mesh = null) -> void:
	if xforms.is_empty() or mesh == null or mesh.get_surface_count() == 0:
		return
	var use_far: bool = far != null and far.get_surface_count() > 0 and not "--no-tree-lod" in OS.get_cmdline_user_args()
	_multi_node(mesh, xforms, mat, 0.0, TREE_LOD_M if use_far else VIEW_M)
	if use_far:
		_multi_node(far, xforms, mat, TREE_LOD_M, VIEW_M)


func _multi_node(mesh: Mesh, xforms: Array, mat: Material, begin: float, end: float) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.visibility_range_begin = begin
	mi.visibility_range_end = end
	if begin > 0.0:
		mi.visibility_range_begin_margin = 8.0
	if end < VIEW_M:
		mi.visibility_range_end_margin = 8.0
	if mat != null:
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _pool() -> PlaneMesh:
	if _pool_mesh == null:
		_pool_mesh = PlaneMesh.new()
		_pool_mesh.size = Vector2(16, 22)
	return _pool_mesh


## Gradiente radial laranja (sodio) somado ao asfalto; a forca vem do preset de hora do dia.
func _pool_material() -> StandardMaterial3D:
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.62, 0.25, 1.0))
	g.set_color(1, Color(1.0, 0.5, 0.15, 0.0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	var m := StandardMaterial3D.new()
	m.albedo_texture = t
	m.albedo_color = Color(1, 1, 1, tod.pool_energy)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m


## Poste com a lampada apagada (copia da malha sem emissao): usado de dia (os 2 modelos, T-186).
func _lamp_unlit(name: String = "lamp_post") -> ArrayMesh:
	if not _lamp_off.has(name):
		var off_mesh: ArrayMesh = GlbMesh.merged(DIR + name + ".glb").duplicate() as ArrayMesh
		for s in off_mesh.get_surface_count():
			var m: StandardMaterial3D = off_mesh.surface_get_material(s) as StandardMaterial3D
			if m != null and m.emission_enabled:
				var off: StandardMaterial3D = m.duplicate() as StandardMaterial3D
				off.emission_enabled = false
				off.albedo_color = Color("#d8dde4")
				off_mesh.surface_set_material(s, off)
		_lamp_off[name] = off_mesh
	return _lamp_off[name]
