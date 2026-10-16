class_name SpriteProjector
extends RefCounted
## Converte posicoes do mundo (z em metros, x lateral em unidades -1..+1, altura em metros)
## em posicao e escala na tela, no estilo OutRun. Usado pelo RoadRenderer e por tudo que fica
## na pista (transito, rivais, objetos de beira de estrada).
##
## A camera fica CAM_BEHIND metros atras da traseira do caminhao do jogador. Com FOCAL = 260 px,
## o caminhao (2,5 m) a 12 m de distancia ocupa o tamanho dos sprites renderizados no Blender.

const SCREEN_W: float = 480.0
const SCREEN_H: float = 270.0
const FOCAL: float = 260.0
const HORIZON_Y: float = 118.0
const CAM_BEHIND: float = 12.0
const CAM_HEIGHT: float = 4.5
const NEAR_Z: float = 0.6
const VIS_CURVE: float = 0.0035   # deslocamento lateral visual (m) por segmento^2 por unidade de curva
const VIS_HILL: float = 3.0       # exagero visual das subidas

var draw_dist: int = 120          # segmentos desenhados
var cam_z: float = 0.0
var cam_lat_m: float = 0.0        # posicao lateral da camera (m)
var cam_y: float = 0.0
var base_index: int = 0
var frac: float = 0.0
# por linha de segmento i (0..draw_dist): profundidade, deslocamento lateral da pista e altura
var zr: PackedFloat32Array = PackedFloat32Array()
var off_m: PackedFloat32Array = PackedFloat32Array()
var y_m: PackedFloat32Array = PackedFloat32Array()
var track: Track


func update(track_: Track, player_z: float, player_x: float) -> void:
	track = track_
	cam_z = player_z - CAM_BEHIND
	cam_lat_m = player_x * Track.ROAD_HALF_WIDTH_M
	cam_y = track.height_at(maxf(cam_z, 0.0)) * VIS_HILL + CAM_HEIGHT
	var cz: float = maxf(cam_z, 0.0)
	base_index = int(cz / Track.SEG_LEN)
	frac = (cz - float(base_index) * Track.SEG_LEN) / Track.SEG_LEN
	var n: int = draw_dist + 1
	zr.resize(n)
	off_m.resize(n)
	y_m.resize(n)
	# linha 0 = inicio do segmento base (pode estar atras da camera: limitado por NEAR_Z na hora de projetar)
	var x: float = 0.0
	var dx: float = -track.curve_at(float(base_index) * Track.SEG_LEN) * VIS_CURVE * frac
	for i in n:
		var s: int = base_index + i
		var z_world: float = float(s) * Track.SEG_LEN
		zr[i] = z_world - cam_z
		off_m[i] = x
		y_m[i] = track.height_at(z_world) * VIS_HILL
		x += dx
		dx += track.curve_at(z_world) * VIS_CURVE


## Projeta uma linha: devolve Vector3(screen_x_centro_da_pista, screen_y, escala px/m).
func project_line(i: int) -> Vector3:
	var z: float = maxf(zr[i], NEAR_Z)
	var scale: float = FOCAL / z
	var sx: float = SCREEN_W * 0.5 + (off_m[i] - cam_lat_m) * scale
	var sy: float = HORIZON_Y + (cam_y - y_m[i]) * scale
	return Vector3(sx, sy, scale)


## Projeta um ponto qualquer do mundo (para sprites): x em unidades, z absoluto em metros,
## altura h acima do chao em metros. Devolve Vector3(sx, sy, escala px/m); escala <= 0 = atras da camera.
func project(x_units: float, z_abs: float, h: float = 0.0) -> Vector3:
	var rel: float = z_abs - cam_z
	if rel < NEAR_Z or track == null:
		return Vector3(0.0, 0.0, 0.0)
	# desloca lateral/altura interpolando entre as linhas do renderizador
	var rel_seg: float = (z_abs - float(base_index) * Track.SEG_LEN) / Track.SEG_LEN
	var i0: int = clampi(int(rel_seg), 0, draw_dist - 1)
	var t: float = clampf(rel_seg - float(i0), 0.0, 1.0)
	var off: float = lerpf(off_m[i0], off_m[i0 + 1], t)
	var yy: float = lerpf(y_m[i0], y_m[i0 + 1], t)
	var scale: float = FOCAL / rel
	var sx: float = SCREEN_W * 0.5 + (off + x_units * Track.ROAD_HALF_WIDTH_M - cam_lat_m) * scale
	var sy: float = HORIZON_Y + (cam_y - (yy + h)) * scale
	return Vector3(sx, sy, scale)
