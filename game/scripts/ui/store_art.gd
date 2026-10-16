extends Node3D
## Gera as imagens da loja (icone e banner) com o caminhao decorado, via captura de tela:
##   godot --path game res://scenes/tools/store_art.tscn --write-movie out.png --resolution 512x512 --quit-after 20 -- --art=icon
##   ... --resolution 1024x500 -- --art=banner

var stage: GarageStage


func _ready() -> void:
	var gs: Node = get_node("/root/GameState")
	gs.save_path = "user://store_art_profile.json"
	gs.apply_demo_profile()
	stage = GarageStage.new()
	add_child(stage)
	var art: String = "icon"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--art="):
			art = a.substr(6)
	stage.auto_rotate = false
	var layer := CanvasLayer.new()
	add_child(layer)
	if art == "icon":
		stage._goal = {"target": Vector3(0, 1.5, -10.0), "dist": 9.5, "az": 28.0, "el": 9.0}
		stage._target = stage._goal["target"]
		stage._dist = 9.5
		stage._az = 28.0
		stage._el = 9.0
	else:
		stage._goal = {"target": Vector3(-3.4, 1.7, -12.4), "dist": 19.0, "az": 52.0, "el": 11.0}
		stage._target = stage._goal["target"]
		stage._dist = 19.0
		stage._az = 52.0
		stage._el = 11.0
		var root := Control.new()
		root.theme = UiTheme.make()
		root.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.add_child(root)
		var t1 := UiTheme.label("KAIDŌ BAKUSŌ", 50, UiTheme.PINK)
		t1.position = Vector2(430, 170)
		root.add_child(t1)
		var t2 := UiTheme.label("Chrome Legends", 30, UiTheme.CYAN)
		t2.position = Vector2(436, 236)
		root.add_child(t2)
		var t3 := UiTheme.label("Corrida de caminhões decorados", 18, UiTheme.TEXT)
		t3.position = Vector2(438, 282)
		root.add_child(t3)
