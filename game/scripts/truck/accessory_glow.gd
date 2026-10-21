class_name AccessoryGlow
extends RefCounted
## Luz das pecas deluxe (T-172) que acompanha dia/noite, sem luz real (barato no celular):
## - materiais "glow_*" (quadrado no chao do neon de chao / luz de cortesia do estribo) viram um shader ADITIVO que
##   desenha a mancha de luz pela UV (sem textura); a cor vem da primeira lampada da peca (lamp_*), entao trocar o neon
##   para rosa na variante pinta o chao de rosa;
## - materiais "acrylic_*" (face do andon) mantem a textura e so mudam a forca da emissao.
## A forca segue TruckNode.set_lights_on (1 noite/tunel, 0,4 previa de dia, 0,12 apagadas). So muda uniformes: nada de
## recompilar shader no meio da corrida. Um por caminhao (TruckNode.glow).

const FLOOR_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 color : source_color = vec4(0.13, 0.9, 1.0, 1.0);
uniform float level = 1.0;
uniform float energy = 1.3;
void fragment() {
	float across = exp(-pow(UV.x - 0.5, 2.0) / (2.0 * 0.16 * 0.16));
	float along = clamp(min(UV.y, 1.0 - UV.y) * 6.0, 0.0, 1.0);
	ALBEDO = color.rgb * energy * across * along * level;
}
"""
## Forca minima da face de acrilico com as luzes apagadas (de dia ainda parece um letreiro de acrilico).
const ACRYLIC_MIN: float = 0.25
## De dia o chao quase nao mostra o neon (0,12 x 0,35).
const FLOOR_DAY_CUT: float = 0.35

static var _shader: Shader

var level: float = 1.0
var _floor_mats: Dictionary = {}        # cor html -> ShaderMaterial
var _acrylic: Array[StandardMaterial3D] = []
var _acrylic_base: Array[float] = []


static func is_glow(name: String) -> bool:
	return name.begins_with("glow_")


static func is_acrylic(name: String) -> bool:
	return name.begins_with("acrylic_")


## Troca os materiais glow_*/acrylic_* abaixo de `root` (chame DEPOIS da variante e ANTES do LightPatterns, que tira
## o nome dos materiais das lampadas).
func apply(root: Node) -> void:
	var lamp: Color = _lamp_color(root)
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		if m.mesh == null:
			continue
		for s in m.mesh.get_surface_count():
			var cur: Material = m.get_active_material(s)
			if cur == null:
				continue
			var n: String = cur.resource_name
			if is_glow(n):
				var col: Color = lamp
				if col.a <= 0.0:
					col = (cur as BaseMaterial3D).emission if cur is BaseMaterial3D else Color(0.13, 0.9, 1.0)
				m.set_surface_override_material(s, _floor_material(col))
				m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			elif is_acrylic(n) and cur is StandardMaterial3D:
				var dup: StandardMaterial3D = (cur as StandardMaterial3D).duplicate() as StandardMaterial3D
				dup.emission_enabled = true
				_acrylic.append(dup)
				_acrylic_base.append(maxf(dup.emission_energy_multiplier, 1.0))
				m.set_surface_override_material(s, dup)
	set_level(level)


func set_level(l: float) -> void:
	level = l
	var fl: float = l if l >= 0.39 else l * FLOOR_DAY_CUT
	for mat in _floor_mats.values():
		(mat as ShaderMaterial).set_shader_parameter("level", fl)
	for i in _acrylic.size():
		_acrylic[i].emission_energy_multiplier = _acrylic_base[i] * lerpf(ACRYLIC_MIN, 1.0, clampf(l, 0.0, 1.0))


func floor_level() -> float:
	if _floor_mats.is_empty():
		return -1.0
	return float((_floor_mats.values()[0] as ShaderMaterial).get_shader_parameter("level"))


func _floor_material(col: Color) -> ShaderMaterial:
	var key: String = col.to_html(false)
	if _floor_mats.has(key):
		return _floor_mats[key]
	if _shader == null:
		_shader = Shader.new()
		_shader.code = FLOOR_SHADER
	var sm := ShaderMaterial.new()
	sm.shader = _shader
	sm.resource_name = "glow_floor"
	sm.set_shader_parameter("color", col)
	_floor_mats[key] = sm
	return sm


## Cor da primeira lampada animada da peca (lamp_cyan, lamp_pink...); alfa 0 = nenhuma.
static func _lamp_color(root: Node) -> Color:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		if m.mesh == null:
			continue
		for s in m.mesh.get_surface_count():
			var cur: Material = m.get_active_material(s)
			if cur is BaseMaterial3D and LightPatterns.ANIMATED.has(cur.resource_name):
				var b: BaseMaterial3D = cur as BaseMaterial3D
				return b.emission if b.emission_enabled else b.albedo_color
	return Color(0, 0, 0, 0)
