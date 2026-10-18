class_name AtlasQuads
extends MultiMeshInstance3D
## Muitos quadrados texturizados com UM atlas e UMA chamada de desenho (MultiMesh): placas de transito,
## placas de veiculo, pintura no asfalto. Cada instancia guarda o retangulo do atlas (INSTANCE_CUSTOM).
## Sem luz por pixel (unshaded): a claridade vem de `level` (hora do dia) e nao paga passada extra por
## farol/poste no renderizador Compatibility. O alfa da textura recorta (pintura no chao).

const SHADER := """
shader_type spatial;
render_mode unshaded, cull_back;
uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float level = 1.0;
varying vec4 rect;
void vertex() {
	rect = INSTANCE_CUSTOM;
	UV = rect.xy + UV * rect.zw;
}
void fragment() {
	vec4 c = texture(atlas, UV);
	ALBEDO = c.rgb * level;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
"""

var _xforms: Array[Transform3D] = []
var _rects: Array[Rect2] = []
var _mat: ShaderMaterial


## `tex` = atlas; `level` = claridade (1 = dia).
func setup(tex: Texture2D, level: float = 1.0) -> void:
	var sh := Shader.new()                       # um por camada (sao 2 ou 3 na cena); static seguraria ate o fim
	sh.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.set_shader_parameter("atlas", tex)
	_mat.set_shader_parameter("level", level)
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	mm.mesh = q
	multimesh = mm


func set_level(level: float) -> void:
	if _mat != null:
		_mat.set_shader_parameter("level", level)


## Claridade das placas/sinais para uma hora do dia (refletivas: a noite ainda aparecem bem).
static func level_for(tod: TimeOfDay) -> float:
	if tod == null:
		return 1.0
	return clampf(lerpf(0.78, 0.95, tod.day_amount) + 0.15 * tod.line_emission * (1.0 - tod.day_amount), 0.3, 1.0)


## Acrescenta um quadrado (o quad mede 1 x 1 e olha para +Z; a escala do transform da o tamanho).
func add_quad(xform: Transform3D, uv: Rect2) -> int:
	_xforms.append(xform)
	_rects.append(uv)
	return _xforms.size() - 1


func quad_count() -> int:
	return _xforms.size()


## Grava as instancias no MultiMesh (chame depois de todos os add_quad).
func commit() -> void:
	multimesh.instance_count = _xforms.size()
	for i in _xforms.size():
		multimesh.set_instance_transform(i, _xforms[i])
		var r: Rect2 = _rects[i]
		multimesh.set_instance_custom_data(i, Color(r.position.x, r.position.y, r.size.x, r.size.y))


## Atualiza so o transform de uma instancia ja gravada (placas que andam com o veiculo).
func move_quad(i: int, xform: Transform3D) -> void:
	_xforms[i] = xform
	multimesh.set_instance_transform(i, xform)


func set_quad_uv(i: int, uv: Rect2) -> void:
	_rects[i] = uv
	if i < multimesh.instance_count:
		multimesh.set_instance_custom_data(i, Color(uv.position.x, uv.position.y, uv.size.x, uv.size.y))
