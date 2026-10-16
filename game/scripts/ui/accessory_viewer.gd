extends Node3D
## Cena de demonstracao dos acessorios 3D (validacao tecnica da biblioteca).
## Modos: [Espaco] alterna "Montado no caminhao" / "Pecas isoladas (vitrine)".
## [Tab] proxima categoria, [1][2][3][4] vistas frente/lado/traseira/3-4, setas/mouse giram a camera,
## [A] liga/desliga todas as pecas da categoria no caminhao, [M] troca a variante de material.
## Linha de comando para captura: -- --mode=mounted --cat=front --view=34

const CATEGORIES: Array[String] = ["front", "lighting", "sides", "rear"]
const VIEWS: Dictionary = {"front": Vector2(15, 8), "side": Vector2(90, 6), "rear": Vector2(180, 8), "34": Vector2(40, 16)}

var catalog: AccessoryCatalog
var cat_index: int = 0
var mounted_mode: bool = true
var _truck: Node3D
var _showcase: Node3D
var _cam: Camera3D
var _az: float = 40.0
var _el: float = 16.0
var _dist: float = 24.0
var _target: Vector3 = Vector3(0, 1.8, -6.0)
var _label: Label
var _attached: Array[Node3D] = []
var _variant: int = 0
var _spin: float = 0.0
var _view_forced: bool = false
## Enquadramento por categoria (alvo no mundo Godot: x, y, -z do Blender; distancia; vista inicial)
const CAT_FRAMING: Dictionary = {
	"front": {"target": Vector3(0, 1.1, -11.4), "dist": 8.0, "az": 25.0, "el": 10.0},
	"lighting": {"target": Vector3(0, 3.0, -8.0), "dist": 13.0, "az": 35.0, "el": 18.0},
	"sides": {"target": Vector3(1.2, 1.1, -6.5), "dist": 13.0, "az": 100.0, "el": 8.0},
	"rear": {"target": Vector3(0, 1.8, -0.3), "dist": 8.5, "az": 160.0, "el": 12.0},
}


func _ready() -> void:
	catalog = AccessoryCatalog.get_instance()
	WorldEnv.create(self)
	var floor_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	floor_mi.mesh = plane
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.05, 0.05, 0.08)
	fm.roughness = 0.35
	fm.metallic_specular = 0.8
	floor_mi.material_override = fm
	add_child(floor_mi)
	_cam = Camera3D.new()
	_cam.fov = 45.0
	add_child(_cam)
	_cam.make_current()
	_truck = (load(TruckNode.MODEL_PATH) as PackedScene).instantiate() as Node3D
	add_child(_truck)
	_showcase = Node3D.new()
	add_child(_showcase)
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(10, 8)
	_label.add_theme_font_size_override("font_size", 14)
	layer.add_child(_label)
	for a in OS.get_cmdline_user_args():
		if a == "--mode=showcase":
			mounted_mode = false
		elif a.begins_with("--cat="):
			cat_index = maxi(CATEGORIES.find(a.substr(6)), 0)
		elif a.begins_with("--view="):
			var v: Vector2 = VIEWS.get(a.substr(7), VIEWS["34"])
			_az = v.x
			_el = v.y
			_view_forced = true
	_rebuild()
	_update_camera()


func _clear() -> void:
	for n in _attached:
		if is_instance_valid(n):
			n.queue_free()
	_attached.clear()
	for c in _showcase.get_children():
		c.queue_free()


func _rebuild() -> void:
	_clear()
	var cat: String = CATEGORIES[cat_index]
	_truck.visible = mounted_mode
	if mounted_mode:
		var fr: Dictionary = CAT_FRAMING[cat]
		_target = fr["target"]
		_dist = float(fr["dist"])
		if not _view_forced:
			_az = float(fr["az"])
			_el = float(fr["el"])
		for e in catalog.in_category(cat):
			for side in (["R", "L"] if bool(e.get("mirror_for_left", false)) else ["R"]):
				var n: Node3D = catalog.attach(_truck, String(e["id"]), side)
				if n != null:
					_attached.append(n)
	else:
		_build_showcase(cat)
	_label.text = "%s  |  categoria: %s  |  modo: %s   [Tab] categoria  [Espaco] modo  [1-4] vistas  [A] pecas  [M] material" % [
		"ACESSORIOS DEKOTORA", String(catalog.categories().get(cat, cat)), "montado" if mounted_mode else "vitrine"]


func _build_showcase(cat: String) -> void:
	var items: Array = catalog.in_category(cat)
	var x: float = -float(items.size() - 1) * 1.6
	for e in items:
		var node: Node3D = catalog.instantiate(String(e["id"]))
		if node == null:
			continue
		var dim: Dictionary = e["dimensions_m"]
		var big: float = maxf(float(dim["x"]), maxf(float(dim["y"]), float(dim["z"])))
		var s: float = clampf(2.2 / maxf(big, 0.1), 0.2, 3.0)
		node.scale = Vector3(s, s, s)
		node.position = Vector3(x, 1.2, 0.0)
		_showcase.add_child(node)
		var lbl := Label3D.new()
		lbl.text = String(e["name"])
		lbl.font_size = 22
		lbl.pixel_size = 0.004
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.position = Vector3(x, -0.2, 0.0)
		_showcase.add_child(lbl)
		x += 3.2
	_target = Vector3(0, 1.0, 0)
	_dist = 8.0 + float(items.size()) * 1.25
	if not _view_forced:
		_az = 12.0
		_el = 12.0


func _update_camera() -> void:
	var a: float = deg_to_rad(_az)
	var e: float = deg_to_rad(_el)
	# az=0: camera na FRENTE do caminhao (que aponta para -Z); az=180: atras
	var dir := Vector3(sin(a) * cos(e), sin(e), -cos(a) * cos(e))
	_cam.global_position = _target + dir * _dist
	_cam.look_at(_target, Vector3.UP)


func _process(delta: float) -> void:
	if not mounted_mode:
		_spin += delta * 0.6
		for c in _showcase.get_children():
			if c is Node3D and not (c is Label3D):
				c.rotation.y = _spin
	var k: float = 60.0 * delta
	if Input.is_key_pressed(KEY_LEFT):
		_az -= k
	if Input.is_key_pressed(KEY_RIGHT):
		_az += k
	if Input.is_key_pressed(KEY_UP):
		_el = clampf(_el + k * 0.5, -5.0, 80.0)
	if Input.is_key_pressed(KEY_DOWN):
		_el = clampf(_el - k * 0.5, -5.0, 80.0)
	_update_camera()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_az -= event.relative.x * 0.4
		_el = clampf(_el + event.relative.y * 0.3, -5.0, 80.0)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = maxf(_dist - 1.0, 3.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = minf(_dist + 1.0, 60.0)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_TAB:
				cat_index = (cat_index + 1) % CATEGORIES.size()
				_rebuild()
			KEY_SPACE:
				mounted_mode = not mounted_mode
				_rebuild()
			KEY_1:
				_set_view("front")
			KEY_2:
				_set_view("side")
			KEY_3:
				_set_view("rear")
			KEY_4:
				_set_view("34")
			KEY_A:
				for n in _attached:
					n.visible = not n.visible
			KEY_M:
				_cycle_variant()


func _set_view(v: String) -> void:
	var vv: Vector2 = VIEWS[v]
	_az = vv.x
	_el = vv.y


## Troca o material "principal" de cada peca montada pela proxima variante permitida no catalogo.
func _cycle_variant() -> void:
	_variant += 1
	for n in _attached:
		var id: String = String(n.name).substr(4, String(n.name).length() - 6)
		var e: Dictionary = catalog.entry(id)
		var opts: Array = e.get("materials_available", {}).get("main", [])
		var used: Array = e.get("materials_used", [])
		if opts.is_empty():
			continue
		var to_name: String = String(opts[_variant % opts.size()])
		for u in used:
			if String(u) in opts:
				catalog.swap_material(n, String(u), to_name)
				break
