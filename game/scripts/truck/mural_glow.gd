class_name MuralGlow
extends RefCounted
## Luz falsa no mural das laterais (T-155): a noite (e nos tuneis) o mural do bau e as tampas da graneleira ficavam
## quase pretos, porque so a lua os ilumina. Em vez de luzes reais (caras no celular), o material do mural ganha
## EMISSAO: a propria arte do mural, um pouco mais clara embaixo (as fileiras de LED da saia) e na borda de cima (a
## fileira do teto), tingida de branco quente. A forca vem da hora do dia (TimeOfDay.mural_glow): 0 de dia = nada
## muda. A textura de emissao e feita uma vez por arte (512x128, com mipmaps) e compartilhada por todos os caminhoes.

## Cor da "luz" das luzinhas sobre o mural (branco quente, como as lampadas ambar/brancas da saia).
const LIGHT := Color(1.0, 0.93, 0.84)
## Tamanho da textura de emissao (luz difusa nao precisa da resolucao da arte).
const SIZE := Vector2i(512, 128)
## Luz no alto (topo do mural) e embaixo (perto da saia) da faixa vertical; o meio fica com o minimo.
const TOP: float = 0.78
const MID: float = 0.62
const BOTTOM: float = 1.0
## Forca dentro de tunel de dia (as luzinhas acendem la dentro como a noite).
const TUNNEL: float = 0.75
## Forca extra da emissao pronta de um mural com neons (T-218: baú rosa).
const EMIT_GAIN: float = 2.2

static var _cache: Dictionary = {}      # id da textura do mural -> ImageTexture de emissao


## Liga a emissao no material do mural (uma vez, ao criar o material). Energia 0: igual a antes.
## `emit` (T-218): emissao pronta do mural proprio de um modelo (arte escurecida + neons fortes); usada no lugar da
## feita a partir da arte, com mais forca (EMIT_GAIN) para os neons acenderem de verdade.
static func setup(mat: StandardMaterial3D, albedo: Texture2D, emit: Texture2D = null) -> void:
	var tex: Texture2D = emit if emit != null else emission_texture(albedo)
	if tex == null:
		return
	mat.emission_enabled = true                     # sempre ligada (trocar depois recompila o shader no meio da corrida)
	mat.emission_texture = tex
	mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY   # cor x textura (o padrao SOMA a cor inteira)
	mat.emission = LIGHT
	mat.emission_energy_multiplier = 0.0
	mat.set_meta("glow_gain", EMIT_GAIN if emit != null else 1.0)


## Ajusta a forca (0 = sem luz) e o tom (cor do rival, igual ao tingido do mural).
static func set_level(mat: StandardMaterial3D, energy: float, tint: Color = Color.WHITE) -> void:
	if mat == null or not mat.emission_enabled:
		return
	mat.emission = LIGHT * tint
	mat.emission_energy_multiplier = maxf(energy, 0.0) * float(mat.get_meta("glow_gain", 1.0))


## Brilho da faixa vertical na linha `v` (0 = topo da arte, 1 = base, que fica junto da saia).
static func profile(v: float) -> float:
	var low: float = smoothstep(0.45, 1.0, v)
	var high: float = 1.0 - smoothstep(0.0, 0.25, v)
	return MID + (BOTTOM - MID) * low + (TOP - MID) * high


## Textura de emissao da arte `albedo` (cache por textura). Null se a imagem nao puder ser lida.
static func emission_texture(albedo: Texture2D) -> Texture2D:
	if albedo == null:
		return null
	var key: int = albedo.get_instance_id()
	if _cache.has(key):
		return _cache[key]
	var img: Image = albedo.get_image()
	if img == null or img.is_empty():
		return null
	img = img.duplicate() as Image
	if img.is_compressed():
		img.decompress()
	img.clear_mipmaps()
	img.convert(Image.FORMAT_RGB8)
	img.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_BILINEAR)
	for y in SIZE.y:
		var k: float = profile((float(y) + 0.5) / SIZE.y)
		for x in SIZE.x:
			img.set_pixel(x, y, img.get_pixel(x, y) * k)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
