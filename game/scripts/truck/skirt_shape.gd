class_name SkirtShape
extends RefCounted
## Contas puras da saia lateral grande (T-265, capturas 085-094): em cada coluna z a saia vai de max(chao da saia, arco
## da roda) ate embaixo do bau. Arco = metade de cima do circulo do pneu + folga (`arcs` do encaixe: [zc, yc, raio]);
## abaixo do centro da roda o recorte desce reto ate o chao da saia (forma de caixa de roda). Igual a
## blender/scripts/lib/socket_rules.skirt_col_lo (as caixas do encaixe sao feitas com a mesma conta).
## Coordenadas do modelo (y cima, frente = -z).

const ARC_SEG: int = 18            # segmentos do meio circulo do arco (malha completa)
const ARC_SEG_LOD: int = 6         # e na malha de longe


## Topo do arco na coluna z (o que fica abaixo e a roda); -INF fora dos arcos.
static func arch_top(z: float, arcs: Array) -> float:
	var top: float = -INF
	for a in arcs:
		var d: float = z - float(a[0])
		var ra: float = float(a[2])
		if absf(d) < ra:
			top = maxf(top, float(a[1]) + sqrt(ra * ra - d * d))
	return top


## Fundo da saia na coluna z.
static func col_lo(z: float, floor_y: float, arcs: Array) -> float:
	return maxf(floor_y, arch_top(z, arcs))


## Colunas da malha de um trecho [z0, z1]: as pontas, os pontos do meio circulo de cada arco e, onde o arco encontra a
## lateral reta (z = zc +- raio), DUAS colunas iguais (a de fora vai ate o chao, a de dentro so ate o centro da roda).
## Devolve [[z, y_baixo], ...] em ordem de z.
static func columns(z0: float, z1: float, floor_y: float, y_hi: float, arcs: Array, seg: int = ARC_SEG) -> Array:
	var pts: Array = []
	var zs: Array[float] = [z0, z1]
	var sides: Array[float] = []
	for a in arcs:
		var zc: float = float(a[0])
		var ra: float = float(a[2])
		for k in range(1, seg):
			zs.append(zc - ra * cos(PI * k / seg))
		for e in [zc - ra, zc + ra]:
			if e > z0 + 1e-4 and e < z1 - 1e-4:
				sides.append(e)
	zs.sort()
	var last: float = -INF
	for z in zs:
		if z < z0 - 1e-6 or z > z1 + 1e-6 or z - last < 0.004:
			continue
		last = z
		pts.append([z, minf(col_lo(z, floor_y, arcs), y_hi)])
	for e in sides:                                 # degrau vertical do recorte: coluna dupla
		var i: int = 0
		while i < pts.size() and float(pts[i][0]) < e:
			i += 1
		var lo_out: float = floor_y
		var lo_in: float = minf(_inside_lo(e, arcs, floor_y), y_hi)
		var before: bool = _arc_center(e, arcs) > e      # o arco fica depois (z maior) desta lateral
		pts.insert(i, [e, lo_out if before else lo_in])
		pts.insert(i + 1, [e, lo_in if before else lo_out])
	return pts


static func _arc_center(e: float, arcs: Array) -> float:
	var best: float = e
	var dist: float = INF
	for a in arcs:
		var d: float = absf(absf(e - float(a[0])) - float(a[2]))
		if d < dist:
			dist = d
			best = float(a[0])
	return best


## Fundo logo dentro da lateral do arco (o centro da roda, ou mais alto se outro arco cobre).
static func _inside_lo(e: float, arcs: Array, floor_y: float) -> float:
	var lo: float = floor_y
	for a in arcs:
		var d: float = absf(e - float(a[0]))
		if d <= float(a[2]) + 1e-4:
			lo = maxf(lo, float(a[1]) + sqrt(maxf(float(a[2]) * float(a[2]) - d * d, 0.0)))
	return lo


## Trechos de z (Vector2(a, b)) onde uma faixa horizontal de y0 a y1 cabe na saia do trecho [z0, z1]: fora de cada arco
## com `gap` de folga (em volta do circulo) e `end` das pontas do trecho.
static func spans(z0: float, z1: float, y0: float, y1: float, arcs: Array, gap: float, end: float) -> Array[Vector2]:
	var cuts: Array[Vector2] = []
	for a in arcs:
		var zc: float = float(a[0])
		var yc: float = float(a[1])
		var r: float = float(a[2]) + gap
		var half: float = -1.0
		if y0 < yc:
			half = r                                 # abaixo do centro: o recorte desce reto
		elif y0 < yc + r:
			half = sqrt(r * r - (y0 - yc) * (y0 - yc))
		if half > 0.0:
			cuts.append(Vector2(zc - half, zc + half))
	cuts.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
	var out: Array[Vector2] = []
	var cur: float = z0 + end
	for c in cuts:
		if c.x > cur:
			out.append(Vector2(cur, minf(c.x, z1 - end)))
		cur = maxf(cur, c.y)
	if z1 - end > cur:
		out.append(Vector2(cur, z1 - end))
	return out.filter(func(v: Vector2) -> bool: return v.y - v.x > 0.005)


## Contorno do fundo do trecho (de z0 a z1), para o friso: lista de Vector2(z, y).
static func bottom(cols: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for c in cols:
		out.append(Vector2(float(c[0]), float(c[1])))
	return out


## Linha do neon do arco (capturas 091): meio circulo de raio (arco + off) e as pernas retas ate o chao + `foot`, so onde
## fica dentro do trecho e abaixo de `y_max`. Devolve uma lista de polilinhas (PackedVector2Array de (z, y)).
static func arch_lines(z0: float, z1: float, floor_y: float, y_max: float, arcs: Array, off: float, end: float,
		seg: int = ARC_SEG) -> Array:
	var out: Array = []
	for a in arcs:
		var zc: float = float(a[0])
		var yc: float = float(a[1])
		var r: float = float(a[2]) + off
		var raw := PackedVector2Array()
		raw.append(Vector2(zc - r, floor_y))
		for k in seg + 1:
			var t: float = PI - PI * k / seg
			raw.append(Vector2(zc + r * cos(t), yc + r * sin(t)))
		raw.append(Vector2(zc + r, floor_y))
		var cur := PackedVector2Array()
		for p in raw:
			var ok: bool = p.x >= z0 + end and p.x <= z1 - end and p.y <= y_max and p.y >= floor_y - 1e-4
			for b in arcs:                         # (nao entra no arco de outra roda)
				if b != a and Vector2(p.x - float(b[0]), p.y - float(b[1])).length() < float(b[2]) + off * 0.5:
					ok = false
			if ok:
				cur.append(p)
			elif cur.size() >= 2:
				out.append(cur)
				cur = PackedVector2Array()
			else:
				cur = PackedVector2Array()
		if cur.size() >= 2:
			out.append(cur)
	return out


## Posicoes (centro em z) de `n` enfeites iguais num trecho, espalhados por igual com passo perto de `pitch`.
static func spread(a: float, b: float, w: float, pitch: float) -> Array[float]:
	var out: Array[float] = []
	var ln: float = b - a
	if ln < w + 0.01:
		return out
	var n: int = maxi(1, floori(ln / pitch))
	var step: float = ln / n
	for i in n:
		out.append(a + step * (i + 0.5))
	return out


## Tracos de comprimento ~`ln` com vao `gap` num trecho [a, b] (o ultimo nao passa de b); `shift` (0-1) desloca o
## comeco em fracao do passo (fileira de baixo intercalada, captura 090).
static func dashes(a: float, b: float, ln: float, gap: float, shift: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var period: float = ln + gap
	var n: int = maxi(1, floori((b - a + gap) / period))
	var l2: float = (b - a + gap) / n - gap                 # (estica de leve para fechar o trecho)
	var p: float = a + shift * (l2 + gap)
	if shift > 0.0 and p - gap - a >= l2 * 0.5:
		out.append(Vector2(a, p - gap))
	while p + l2 * 0.5 <= b:
		out.append(Vector2(p, minf(p + l2, b)))
		p += l2 + gap
	return out
