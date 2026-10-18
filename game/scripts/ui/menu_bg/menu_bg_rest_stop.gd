class_name MenuBgRestStop
extends MenuBackdrop
## Opcao A do fundo da tela inicial (T-138): o caminhao do jogador estacionado num posto de estrada japones
## (drive-in / parking area) a noite: asfalto molhado, vagas pintadas, loja de conveniencia acesa, fileira de
## maquinas de bebida, cobertura do posto com luz branca, postes de sodio e letreiros de neon (rosa, ciano,
## dourado) com kanji. Tudo em caixas simples e texto 3D: ~30 chamadas de desenho alem do caminhao, 4 luzes.

const SODIUM := Color("#ffb060")
const WARM := Color("#fff1d6")


func _build_scene() -> void:
	WorldEnv.create(self, false, TimeOfDay.by_id(&"night"))
	_ground()
	_store()
	_vending()
	_canopy()
	_lamps()
	_signs()


func hero_frame() -> Dictionary:
	return {"target": Vector3(-0.8, 1.8, -6.0), "dist": 16.0, "az": 36.0, "el": 6.5, "shift": 0.2}


func _ground() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(160, 160)
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/textures/asphalt_albedo.png") as Texture2D
	m.albedo_color = Color(0.32, 0.32, 0.34)
	m.uv1_scale = Vector3(40, 40, 1)
	m.roughness = 0.32                               # molhado: as luzes viram manchas no chao
	m.metallic_specular = 0.7
	mi.material_override = m
	add_child(mi)
	for x in [-2.5, 2.5, -7.5, 7.5]:                 # vagas de caminhao
		box(self, Vector3(0.14, 0.012, 16.0), Vector3(x, 0.006, -6.0), Color(0.85, 0.85, 0.8), 0.15, 0.5)
	box(self, Vector3(15.0, 0.012, 0.25), Vector3(0, 0.006, 2.2), Color(0.85, 0.85, 0.8), 0.15, 0.5)
	for i in 6:                                      # setas de mao unica pintadas
		box(self, Vector3(0.3, 0.012, 1.6), Vector3(11.0, 0.006, -14.0 + i * 5.0), Color(0.8, 0.8, 0.72), 0.1, 0.5)


## Loja de conveniencia atras do caminhao (lado esquerdo da tela): parede escura, vitrine acesa, faixa de neon.
func _store() -> void:
	box(self, Vector3(9.0, 4.4, 30.0), Vector3(-17.0, 2.2, -4.0), Color(0.09, 0.09, 0.1))
	box(self, Vector3(0.12, 2.5, 20.0), Vector3(-12.45, 1.45, -6.0), Color(0.62, 0.55, 0.42), 0.1, 0.2)   # vitrine (fraca: nao estourar o branco)
	for z in range(-15, 5, 4):                                                                 # caixilhos
		box(self, Vector3(0.16, 2.6, 0.14), Vector3(-12.4, 1.45, float(z)), Color(0.15, 0.15, 0.16))
	box(self, Vector3(0.4, 0.8, 30.2), Vector3(-12.4, 4.0, -4.0), Color(0.16, 0.16, 0.2), 0.0)     # testeira escura (o neon ciano destaca)
	box(self, Vector3(0.08, 0.08, 30.0), Vector3(-12.15, 3.55, -4.0), UiTheme.CYAN, 5.0)       # neon ciano
	omni(self, Vector3(-10.0, 2.6, -6.0), WARM, 1.0, 11.0)


## Maquinas de bebida (jidohanbaiki): o simbolo de qualquer parada japonesa a noite.
func _vending() -> void:
	var fronts: Array[Color] = [Color("#e8f2ff"), Color("#ff4060"), Color("#e8f2ff"), Color("#40a0ff"), Color("#ffe080")]
	for i in fronts.size():
		var z: float = 7.0 + i * 1.05
		box(self, Vector3(0.9, 1.9, 1.0), Vector3(-12.0, 0.95, z), Color(0.75, 0.76, 0.8), 0.0, 0.4)
		box(self, Vector3(0.05, 1.3, 0.8), Vector3(-11.53, 1.15, z), fronts[i], 2.2, 0.3)
		box(self, Vector3(0.05, 0.22, 0.8), Vector3(-11.53, 0.35, z), Color(0.05, 0.05, 0.06))


## Cobertura do posto atras do caminhao: teto com painel de luz por baixo e borda de neon rosa.
func _canopy() -> void:
	var c := Vector3(3.0, 0, 16.0)
	box(self, Vector3(12.0, 0.7, 9.0), c + Vector3(0, 5.6, 0), Color(0.88, 0.88, 0.9), 0.0, 0.5)
	box(self, Vector3(11.4, 0.05, 8.4), c + Vector3(0, 5.22, 0), Color(1, 1, 1), 2.0)
	box(self, Vector3(12.1, 0.1, 0.1), c + Vector3(0, 5.3, -4.55), UiTheme.PINK, 5.0)
	box(self, Vector3(0.1, 0.1, 9.1), c + Vector3(-6.05, 5.3, 0), UiTheme.PINK, 5.0)
	for p in [Vector3(-4.5, 0, -3.2), Vector3(4.5, 0, -3.2), Vector3(-4.5, 0, 3.2), Vector3(4.5, 0, 3.2)]:
		box(self, Vector3(0.45, 5.3, 0.45), c + p + Vector3(0, 2.65, 0), Color(0.8, 0.8, 0.82))
	for x in [-2.0, 2.0]:                                      # bombas
		box(self, Vector3(0.9, 1.7, 0.6), c + Vector3(x, 0.85, 0), Color(0.9, 0.9, 0.92))
		box(self, Vector3(0.7, 0.4, 0.05), c + Vector3(x, 1.35, -0.33), Color("#7cf0ff"), 1.8)
	omni(self, c + Vector3(0, 4.4, -1.0), Color(1, 1, 1), 1.4, 13.0)


## Postes de sodio: um bem perto do caminhao (luz laranja no cromo e no asfalto molhado).
func _lamps() -> void:
	for p in [Vector3(6.0, 0, 5.0), Vector3(-6.0, 0, 6.0), Vector3(9.0, 0, -30.0), Vector3(-8.0, 0, -32.0)]:
		box(self, Vector3(0.22, 8.0, 0.22), p + Vector3(0, 4.0, 0), Color(0.3, 0.3, 0.32))
		box(self, Vector3(1.4, 0.14, 0.14), p + Vector3(-0.6 * signf(p.x), 7.9, 0), Color(0.3, 0.3, 0.32))
		box(self, Vector3(0.7, 0.12, 0.35), p + Vector3(-1.2 * signf(p.x), 7.8, 0), SODIUM, 6.0)
	omni(self, Vector3(4.8, 7.0, 3.0), SODIUM, 1.4, 18.0)
	omni(self, Vector3(7.0, 6.0, -16.0), SODIUM, 1.2, 16.0)        # luz quente vinda de um poste fora do quadro (frente da cabine)


## Letreiros: torre com "爆走" dourado, "ドライブイン" rosa na loja e "24H" ciano.
func _signs() -> void:
	var tower := Vector3(-7.0, 0, 13.0)
	box(self, Vector3(0.5, 10.0, 0.5), tower + Vector3(0, 5.0, 0), Color(0.25, 0.25, 0.28))
	box(self, Vector3(0.6, 3.6, 2.2), tower + Vector3(0, 9.6, 0), Color(0.08, 0.06, 0.1))
	box(self, Vector3(0.62, 3.7, 0.08), tower + Vector3(0, 9.6, -1.1), UiTheme.PINK, 4.0)
	box(self, Vector3(0.62, 3.7, 0.08), tower + Vector3(0, 9.6, 1.1), UiTheme.PINK, 4.0)
	neon(self, "爆\n走", tower + Vector3(0.33, 9.6, 0), UiTheme.GOLD, 0.016, 96, 90.0)
	neon(self, "ドライブイン", Vector3(-12.15, 5.3, -2.0), UiTheme.PINK, 0.022, 96, 90.0)
	neon(self, "24H", Vector3(-12.15, 5.3, -10.5), UiTheme.CYAN, 0.02, 72, 90.0)
	omni(self, tower + Vector3(2.0, 8.0, 0), UiTheme.PINK, 1.8, 14.0)
