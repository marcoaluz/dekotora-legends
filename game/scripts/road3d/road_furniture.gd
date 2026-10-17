class_name RoadFurniture
extends Node3D
## "Mobiliario" de via expressa japonesa (Shuto/Tomei), so visual:
## - delineadores sobre a mureta (verde a esquerda, branco a direita) e "olhos de gato" nas linhas de borda,
##   que brilham a noite (emissao pela hora do dia: sem luz real);
## - porticos verdes sobre a pista com placas em kanji + romaji e distancia ate o destino;
## - viaduto (cidade): pilares de concreto sob o tabuleiro e montantes das barreiras de som;
## - marcacoes pintadas no asfalto (Label3D deitado): "80" e 速度落とせ antes das curvas fortes, setas nas faixas.
## Caixas num MultiMesh por bloco de pista (cor por instancia; alfa = forca do brilho): poucos draw calls.

const BLOCK_M: float = 150.0
const SIGN_FONT := "res://assets/fonts/NotoSansJP.ttf"
const KANJI: Dictionary = {
	"Yokohama": "横浜", "Fujisawa": "藤沢", "Chigasaki": "茅ヶ崎", "Odawara": "小田原", "Atami": "熱海",
	"Tóquio": "東京", "Kawasaki": "川崎", "Shinagawa": "品川", "Chiba": "千葉", "Saitama": "さいたま",
	"Hakone": "箱根", "Gotemba": "御殿場", "Fujinomiya": "富士宮", "Numazu": "沼津", "Kofu": "甲府",
}
const ROMAJI: Dictionary = {"Tóquio": "Tokyo"}
const SHARP_CURVE: float = 0.9          # curva a partir da qual a faixa vira amarela e aparece "reduza"

const BOX_SHADER := """
shader_type spatial;
uniform float glow = 0.0;
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() {
	ALBEDO = tint.rgb;
	ROUGHNESS = 0.55;
	EMISSION = tint.rgb * glow * tint.a;
}
"""

var path: TrackPath
var tod: TimeOfDay
var _blocks: Dictionary = {}            # indice do bloco -> Array [Transform3D, Color]
var _font: Font


func build(path_: TrackPath, kind: StringName, tod_: TimeOfDay, tunnels: Array[Vector2], places: PackedStringArray) -> void:
	path = path_
	tod = tod_
	_font = load(SIGN_FONT) as Font
	var L: float = path.track.length_m
	var bar: float = RoadMesh.BARRIER_IN + 0.3
	var edge: float = Track.ROAD_HALF_WIDTH_M - 0.35
	var deck: float = RoadMesh.deck_height(kind)
	var z: float = 6.0
	while z < L - 2.0:                                                    # delineadores (a cada 12 m)
		for side in [-1.0, 1.0]:
			_box(z, side * bar, 1.15, Vector3(0.08, 0.6, 0.08), Color("#9aa0a8", 0.0))
			_box(z - 0.06, side * bar, 1.38, Vector3(0.16, 0.16, 0.04), Color("#35e07a") if side < 0.0 else Color("#f2f2f2"))
		z += 12.0
	z = 3.0
	while z < L - 2.0:                                                    # olhos de gato (a cada 10 m)
		_box(z, -edge, 0.03, Vector3(0.16, 0.05, 0.1), Color("#ffb347"))
		_box(z, edge, 0.03, Vector3(0.16, 0.05, 0.1), Color("#f4f4ff"))
		z += 10.0
	if deck > 0.0:
		_viaduct(L, deck)
	var gz: float = 320.0
	var k: int = 0
	while gz < L - 120.0:                                                 # porticos com placas
		if not RoadMesh.in_tunnel(gz, tunnels, 40.0):
			_gantry(gz, places, k, L)
			k += 1
		gz += 650.0
	_markings(L, tunnels)
	_commit()


## Uma caixa (MultiMesh unitario) em (z, lateral em metros, altura) alinhada com a pista.
func _box(z: float, lat_m: float, y: float, size: Vector3, col: Color) -> void:
	var t := Transform3D(Basis(Vector3.UP, path.yaw_at(z)) * Basis.from_scale(size), path.world_point(z, lat_m / Track.ROAD_HALF_WIDTH_M, y))
	var bi: int = int(z / BLOCK_M)
	if not _blocks.has(bi):
		_blocks[bi] = []
	_blocks[bi].append([t, col])


func _viaduct(L: float, deck: float) -> void:
	var bo: float = RoadMesh.BARRIER_IN + RoadMesh.BARRIER_W
	var concrete := Color("#8d9099", 0.0)
	var z: float = 16.0
	while z < L:                                                          # pilar em T sob o tabuleiro
		_box(z, 0.0, -(deck + 1.6) * 0.5, Vector3(3.0, deck - 1.6, 2.4), concrete)
		_box(z, 0.0, -2.3, Vector3(bo * 2.0 - 1.0, 1.4, 2.4), concrete)
		z += 32.0
	z = 0.0
	while z < L:                                                          # montantes das barreiras de som
		if RoadMesh.sound_wall_at(z):
			for side in [-1.0, 1.0]:
				_box(z, side * (RoadMesh.BARRIER_IN + 0.45), 2.45, Vector3(0.14, 3.2, 0.14), Color("#5c636e", 0.0))
		z += 4.0


func _gantry(z: float, places: PackedStringArray, k: int, L: float) -> void:
	var span: float = RoadMesh.BARRIER_IN + 0.5
	var steel := Color("#7d838d", 0.0)
	for side in [-1.0, 1.0]:
		_box(z, side * span, 3.8, Vector3(0.45, 7.6, 0.45), steel)
	_box(z, 0.0, 7.25, Vector3(span * 2.0, 0.45, 0.45), steel)
	_box(z, 0.0, 4.95, Vector3(span * 2.0, 0.25, 0.25), steel)
	var n: int = maxi(places.size(), 1)
	var km: float = maxf((L - z) / 1000.0, 0.5)
	for b in 2:
		var lat: float = -4.6 if b == 0 else 4.6
		var place: String = String(places[(k + b + 1) % n]) if places.size() > 0 else "Tokyo"
		_box(z - 0.35, lat, 6.6, Vector3(6.8, 2.7, 0.14), Color("#0d6a3b", 0.12))   # na frente da viga (lado de quem chega)
		_box(z - 0.43, lat, 6.6, Vector3(6.5, 2.4, 0.02), Color("#e8f0ea", 0.12))   # borda branca
		_box(z - 0.45, lat, 6.6, Vector3(6.3, 2.2, 0.02), Color("#0d6a3b", 0.12))
		var kanji: String = String(KANJI.get(place, place))
		var romaji: String = String(ROMAJI.get(place, place))
		_label(kanji, z - 0.48, lat, 7.0, 110, 0.011)
		_label("%s  %d km" % [romaji, roundi(km + 6.0 * b)], z - 0.48, lat, 5.95, 56, 0.011)


func _label(text: String, z: float, lat_m: float, y: float, size: int, px: float) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = _font
	l.font_size = size
	l.pixel_size = px
	l.outline_size = 0
	l.modulate = Color(0.95, 0.97, 0.95)
	l.shaded = false
	l.double_sided = false
	l.visibility_range_end = 380.0
	l.transform = Transform3D(Basis(Vector3.UP, path.yaw_at(z)), path.world_point(z, lat_m / Track.ROAD_HALF_WIDTH_M, y))
	add_child(l)


## Pintura no asfalto deitada e esticada no sentido da pista (como no Japao), legivel para quem vem atras.
func _road_text(text: String, z: float, lane_x: float, size: int, stretch: float) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = _font
	l.font_size = size
	l.pixel_size = 0.02
	l.outline_size = 0
	l.modulate = Color(0.82, 0.82, 0.8) if tod.day_amount < 0.5 else Color(0.92, 0.92, 0.9)
	l.shaded = false
	l.double_sided = false
	l.visibility_range_end = 170.0
	var b: Basis = Basis(Vector3.UP, path.yaw_at(z)) * Basis(Vector3.RIGHT, -PI * 0.5) * Basis.from_scale(Vector3(1.0, stretch, 1.0))
	l.transform = Transform3D(b, path.world_point(z, lane_x, 0.035))
	add_child(l)


func _markings(L: float, tunnels: Array[Vector2]) -> void:
	var lanes: Array[float] = Lanes.ROAD
	var prev_sharp: bool = false
	var z: float = 0.0
	while z < L:                                                          # antes de cada curva forte
		var sharp: bool = absf(path.track.curve_at(z)) >= SHARP_CURVE
		if sharp and not prev_sharp and z > 140.0:
			for lx in lanes:
				_road_text("速度落とせ", z - 110.0, lx, 64, 3.2)
				_road_text("80", z - 60.0, lx, 96, 2.6)
		prev_sharp = sharp
		z += 10.0
	z = 260.0
	while z < L - 60.0:                                                   # setas a cada 420 m
		if not RoadMesh.in_tunnel(z, tunnels, 0.0):
			for lx in lanes:
				_road_text("↑", z, lx, 170, 2.2)
		z += 420.0


func _commit() -> void:
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = BOX_SHADER
	mat.shader = sh
	mat.set_shader_parameter("glow", tod.line_emission * 2.2)
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	for bi in _blocks:
		var items: Array = _blocks[bi]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = box
		mm.instance_count = items.size()
		for i in items.size():
			mm.set_instance_transform(i, items[i][0])
			mm.set_instance_color(i, items[i][1])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 600.0
		add_child(mi)
