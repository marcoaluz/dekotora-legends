extends SceneTree
## Gera res://assets/fonts/ui_font.tres: Noto Sans JP (fonte variavel) com peso 500, para toda a interface.
## A fonte variavel abre no peso minimo (fina demais); aqui fixamos um peso legivel.

func _initialize() -> void:
	var base: FontFile = load("res://assets/fonts/NotoSansJP.ttf") as FontFile
	var fv := FontVariation.new()
	fv.base_font = base
	fv.variation_opentype = {2003265652: 500}     # tag 'wght' = 0x77676874
	var err: int = ResourceSaver.save(fv, "res://assets/fonts/ui_font.tres")
	print("fonte salva: ", err)
	quit()
