class_name TunnelLightPools
extends RefCounted
## Pocas de luz no asfalto embaixo das lampadas do tunel antigo 湯坂隧道 (T-155): dentro do tunel o sol e o ambiente
## apagam, e o asfalto ficava preto (so a luz que pisca sobre o caminhao iluminava). Sem luz real (celular): um
## MultiMesh de quadrados com gradiente radial laranja SOMADO ao asfalto, uma chamada de desenho para o tunel todo.
## Fracas de proposito (tunel velho, lampadas espacadas): a poca so marca o chao perto de cada lampada.

const SIZE := Vector2(7.0, 9.0)           # m: lateral x ao longo da pista
const ENERGY: float = 0.42                # alfa da poca (somada): 0 = nada
const COLOR := Color(1.0, 0.6, 0.24)

static var _mat: StandardMaterial3D


## Cria o MultiMesh das pocas (uma por transform; o plano fica deitado no chao) como filho de `parent`.
static func build(parent: Node3D, xfs: Array[Transform3D]) -> MultiMeshInstance3D:
	if xfs.is_empty():
		return null
	var plane := PlaneMesh.new()
	plane.size = SIZE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = plane
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func material() -> StandardMaterial3D:
	if _mat != null:
		return _mat
	var g := Gradient.new()
	g.set_color(0, Color(COLOR, 1.0))
	g.set_color(1, Color(COLOR, 0.0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	_mat = StandardMaterial3D.new()
	_mat.albedo_texture = t
	_mat.albedo_color = Color(1, 1, 1, ENERGY)
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return _mat
