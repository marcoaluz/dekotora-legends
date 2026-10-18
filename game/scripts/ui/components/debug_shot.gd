class_name DebugShot
extends RefCounted
## Capturas de depuracao de qualquer tela (T-138): `-- --shot=C:/pasta/x.png [--shot-delay=3]` salva a imagem
## da janela depois do atraso e fecha o jogo. Use com `--resolution 960x540` ou `--resolution 2400x1080`.
## Sem `--shot=` nao faz nada (custo zero no jogo normal).


## Arma a captura para a tela `node` (chame no _ready). `delay` = segundos ate salvar (o --shot-delay manda).
static func arm(node: Node, delay: float = 3.0) -> void:
	var path: String = ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			path = a.substr(7)
		elif a.begins_with("--shot-delay="):
			delay = float(a.substr(13))
	if path == "":
		return
	node.get_tree().create_timer(delay, true).timeout.connect(func() -> void: _save(node, path))


static func _save(node: Node, path: String) -> void:
	if not is_instance_valid(node):
		return
	await RenderingServer.frame_post_draw
	node.get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURA: ", path)
	node.get_tree().quit()
