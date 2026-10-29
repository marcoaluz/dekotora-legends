class_name SideLadder
extends RefCounted
## Escada na LATERAL da cabine (T-263, correcao do Marco: "do lado da cabine, tipo do lado da porta"). T-267: na
## americana e no Canter ela vai na lateral da CARGA logo atras da quina da frente (encaixe com "on": "cargo", medido por
## `truck_measure.ladder_cargo`; mesma montagem, espacadores so em `sp_free`). O encaixe
## ladder_* (blender/scripts/lib/truck_measure.py `ladder_side`) da o ponto na lataria logo atras da porta, a largura
## livre (`width`), a inclinacao da lateral (`lean`, dx/dy: a cabine afina para cima) e o vao de cada altura (`gaps`,
## passo `gap_dy`). A escada fica em pe virada para fora, inclinada com a lateral, e leva ESPACADORES no meio, a cada
## SPACING, ate a lataria (encosta de verdade; acima do teto ela fica livre, como um pega-mao).

const SPACING: float = 0.45          # m: um espacador a cada isto, da base ate onde ha lataria medida
const SP_W: float = 0.03             # m: secao do espacador
const EMBED: float = 0.003           # m: o espacador entra isto na lataria (sem fresta)


## Transformacao da escada no espaco do ponto de encaixe: largura ao longo do caminhao, em pe com a lateral, frente da
## peca (-z local) para fora. `sx` = 1 direita, -1 esquerda.
static func basis(s: Dictionary, entry: Dictionary, sx: float) -> Basis:
	var lean: float = float(s.get("lean", 0.0))
	var sw: float = clampf(float(s.get("width", entry.get("nominal_w", 0.3))) / float(entry.get("nominal_w", 0.3)), 0.6, 1.0)
	var up := Vector3(sx * lean, 1.0, 0.0).normalized()
	var outward := Vector3(sx, -lean, 0.0).normalized()
	return Basis(Vector3(0.0, 0.0, sx) * sw, up, -outward)


## Vao (m) entre as costas da escada e a lataria na altura `y` (do modelo); -1 = sem lataria medida ali.
static func gap_at(s: Dictionary, y: float) -> float:
	var gaps: Array = s.get("gaps", [])
	var dy: float = float(s.get("gap_dy", 0.05))
	var y0: float = float((s.get("anchor", [0, 0, 0]) as Array)[1])
	var t: float = (y - y0) / dy
	if gaps.is_empty() or t < -0.5 or t > gaps.size() - 0.5:
		return -1.0
	var i: int = clampi(floori(t), 0, gaps.size() - 1)
	var j: int = mini(i + 1, gaps.size() - 1)
	if s.has("sp_free"):
		# T-267 (carga): vao medido a cada 1 cm; sem lataria (-1) ou degrau de mais de 1 cm (friso, nervura) = sem espacador
		var lo: float = minf(float(gaps[maxi(i - 1, 0)]), float(gaps[mini(j + 1, gaps.size() - 1)]))
		var hi: float = maxf(float(gaps[maxi(i - 1, 0)]), float(gaps[mini(j + 1, gaps.size() - 1)]))
		for k in range(maxi(i - 1, 0), mini(j + 1, gaps.size() - 1) + 1):
			lo = minf(lo, float(gaps[k]))
			hi = maxf(hi, float(gaps[k]))
		if lo < 0.0 or hi - lo > 0.01:
			return -1.0
	return lerpf(float(gaps[i]), float(gaps[j]), clampf(t - i, 0.0, 1.0))


## T-267 (escada na quina da frente da carga): o espacador so fica nas faixas de altura `sp_free` (entre as faixas do
## contorno de LED do bau, que passa por tras da escada). Sem `sp_free` (escada da cabine) vale qualquer altura.
static func in_free(s: Dictionary, y: float) -> bool:
	if not s.has("sp_free"):
		return true
	for f in s["sp_free"]:
		if y - SP_W * 0.5 >= float(f[0]) and y + SP_W * 0.5 <= float(f[1]):
			return true
	return false


## Espacadores (uma malha, material de acabamento da peca) do pe ate o topo da lataria medida. Grava a meta "contacts"
## (ponta de cada espacador na lataria e a normal para fora, no espaco do modelo) para o teste de contato.
static func add_spacers(node: Node3D, s: Dictionary, height: float) -> void:
	var mat: Material = null
	for mi in StripFit._meshes(node):
		for k in mi.mesh.get_surface_count():
			var m: Material = mi.mesh.surface_get_material(k)
			if m != null and String(m.resource_name).contains("trim"):
				mat = m
	var anchor: Vector3 = (node.get_parent() as Node3D).position
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var contacts: Array = []
	var yl: float = 0.06
	var n: int = 0
	while yl <= height:
		var world: Vector3 = anchor + node.transform * Vector3(0.0, yl, 0.0)
		var g: float = gap_at(s, world.y) if in_free(s, world.y) else -1.0
		if g >= 0.0:
			var len: float = g + EMBED
			_box(st, Vector3(0.0, yl, len * 0.5), Vector3(SP_W, SP_W, len))
			var out_n: Vector3 = -(node.transform.basis.z.normalized())
			contacts.append({"p": anchor + node.transform * Vector3(0.0, yl, g), "n": out_n})
			n += 1
			yl += SPACING
		elif s.has("sp_free"):
			yl += 0.03                      # T-267: (friso/faixa de LED aqui) tenta um pouco mais acima
		else:
			yl += SPACING
	if n == 0:
		return
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "%s_spacers" % node.name
	mi.mesh = st.commit()
	if mat != null:
		mi.mesh.surface_set_material(0, mat)
	node.add_child(mi)
	node.set_meta("contacts", contacts)


static func _box(st: SurfaceTool, c: Vector3, size: Vector3) -> void:
	var h: Vector3 = size * 0.5
	var p: Array[Vector3] = []
	for k in 8:
		p.append(c + Vector3(h.x if k & 1 else -h.x, h.y if k & 2 else -h.y, h.z if k & 4 else -h.z))
	for f in [[0, 2, 3, 1], [4, 5, 7, 6], [0, 1, 5, 4], [2, 6, 7, 3], [0, 4, 6, 2], [1, 3, 7, 5]]:
		st.add_vertex(p[f[0]])
		st.add_vertex(p[f[1]])
		st.add_vertex(p[f[2]])
		st.add_vertex(p[f[0]])
		st.add_vertex(p[f[2]])
		st.add_vertex(p[f[3]])
