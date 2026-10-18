class_name DecalPlacer
extends RefCounted
## Coloca os adesivos (quads com PNG) nas laterais do bau, na traseira e nas portas da cabine. O Decal do Godot nao
## existe no renderizador Compatibility (usado no celular), entao cada adesivo e um quad colado na superficie.
## A area do bau vem da caixa do mural do proprio modelo (serve para todos os modelos de bau).
## Cada adesivo: {id, slot, x, y, size, color}: x e y de -1 a 1 dentro da area do lugar, size = altura em fracao da area.

const LIFT: float = 0.02                 # m a frente da superficie (evita z-fighting)
const FALLBACK_BAU: AABB = AABB(Vector3(-1.27, 0.95, -8.3), Vector3(2.54, 1.5, 8.0))


## Area do bau (caixa) no espaco do TruckNode, a partir do mesh "mural" do modelo.
static func bau_box(root: Node3D, model: Node3D) -> AABB:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		for s in m.mesh.get_surface_count():
			var cur: Material = m.get_active_material(s)
			if cur != null and cur.resource_name == "mural":
				var xf := Transform3D.IDENTITY
				var n: Node = m
				while n != null and n != root:
					xf = (n as Node3D).transform * xf
					n = n.get_parent()
				return xf * m.get_aabb()
	return FALLBACK_BAU


## Cria os quads dos adesivos como filhos de `parent` e devolve a lista de nos criados.
static func build(parent: Node3D, model: Node3D, decals: Array, front_z: float, cab: String = CabCatalog.DEFAULT) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var box: AABB = bau_box(parent, model)
	var cx: float = box.position.x + box.size.x * 0.5
	var half_w: float = box.size.x * 0.5
	var cy: float = box.position.y + box.size.y * 0.5
	var half_h: float = box.size.y * 0.5
	var cz: float = box.position.z + box.size.z * 0.5
	var half_l: float = box.size.z * 0.5
	for raw in decals:
		var d: Dictionary = raw
		var tex: Texture2D = DecalCatalog.texture(String(d.get("id", "")))
		if tex == null:
			continue
		var slot: String = String(d.get("slot", ""))
		var px: float = clampf(float(d.get("x", 0.0)), -1.0, 1.0)
		var py: float = clampf(float(d.get("y", 0.0)), -1.0, 1.0)
		var size: float = clampf(float(d.get("size", 0.5)), 0.1, 1.2)
		var aspect: float = float(tex.get_width()) / maxf(float(tex.get_height()), 1.0)
		var color := Color(String(d.get("color", "#ffffff")))
		match slot:
			"side_l", "side_r":
				var h: float = size * box.size.y
				var w: float = minf(h * aspect, box.size.z * 0.95)
				var sx: float = 1.0 if slot == "side_r" else -1.0
				var z: float = cz - px * (half_l - w * 0.5)       # x = +1 = frente (z negativo)
				var pos := Vector3(cx + sx * (half_w + LIFT), cy + py * (half_h - h * 0.5), z)
				out.append(_quad(parent, tex, color, Vector2(w, h), pos, 90.0 * sx))
			"rear":
				var h2: float = size * box.size.y
				var w2: float = minf(h2 * aspect, box.size.x * 0.95)
				var pos2 := Vector3(cx + px * (half_w - w2 * 0.5), cy + py * (half_h - h2 * 0.5), REAR_Z + LIFT)
				out.append(_quad(parent, tex, color, Vector2(w2, h2), pos2, 0.0))
			"cab":
				var h3: float = size * 0.9
				var w3: float = minf(h3 * aspect, 1.9)
				var spot: Array = CAB_SPOT.get(cab, CAB_SPOT[CabCatalog.DEFAULT])
				var door_z: float = front_z + float(spot[1]) - px * 0.6
				for sx2 in [-1.0, 1.0]:
					var pos3 := Vector3(float(sx2) * (float(spot[0]) + LIFT), float(spot[2]) + py * float(spot[3]), door_z)
					out.append(_quad(parent, tex, color, Vector2(w3, h3), pos3, 90.0 * float(sx2)))
	return out


const REAR_Z: float = 0.0                  # a origem do TruckNode e a traseira do bau
## Lugar do adesivo "cab" por cabine: [meia largura, distancia da frente ate o centro, altura do centro, folga em y].
## A chata (T-119) tem a lateral em 1,153 m e o painel livre e o do dormitorio (entre a faixa rosa e a janela).
## A curta (JAC, T-125) tem a porta curta: o adesivo fica na chapa embaixo da janela; o Canter e a mesma em escala 0,88
## e a jac (T-129) em 0,95 x 0,88. A americana (Kenworth, T-129) tem a porta bem atras do capo.
const CAB_SPOT: Dictionary = {"chata": [1.157, 2.4, 1.76, 0.15], "jac": [1.255, 1.07, 1.22, 0.14],
		"curta": [1.2, 0.95, 1.08, 0.12], "canter": [1.06, 0.84, 0.95, 0.1], "americana": [0.97, 2.6, 1.5, 0.12]}


static func _quad(parent: Node3D, tex: Texture2D, color: Color, size: Vector2, pos: Vector3, yaw_deg: float) -> Node3D:
	var q := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.5
	mat.emission_enabled = true
	mat.emission_texture = tex
	mat.emission = color
	mat.emission_energy_multiplier = 0.35          # fica visivel no escuro sem parecer neon
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mesh.material = mat
	q.mesh = mesh
	q.position = pos
	q.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(q)
	return q
