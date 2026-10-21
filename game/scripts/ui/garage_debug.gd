class_name GarageDebug
extends RefCounted
## Argumentos de depuracao da garagem (capturas): --demo (monta um caminhao cheio de pecas; --noparts = sem pecas;
## --cab=<estilo>; --body=<modelo>; --parts=a,b), --damage, --decals, --lights=<padrao>, --hideui, --day,
## --view=<vista>, --spin (rodas em movimento), --zoom=<z>, --tab=model|parts|mech|repair, --slot=<slot>,
## --deco=parts|paint|lights|decals (secao da DECORACAO, T-177),
## --shot=ARQUIVO.png (depois de 6 s; --shot-pair = mais um quadro seguido), --preview=<peca> e
## --preview-paint=<#hex> (T-171: previa antes de comprar).
## O --demo grava em user://demo_profile.json, NUNCA no perfil real do jogador.

const DEMO_PARTS: Array[String] = ["fb_gold_wing", "visor_gold_lights", "roof_lights_crown", "skirt_light_bar", "andon_kanji",
		"rb_chrome", "mural_lightning", "hub_chrome", "grille_frame_chrome", "aux_round_lamps_pair", "front_crest_ornament",
		"roof_torii_ornament", "fender_extension", "side_ornament_wave", "rear_lamp_cluster", "mudflap_designed"]


## Aplica os argumentos na tela da garagem. Devolve {"tab": ..., "slot": ...} quando pedidos.
static func apply(screen: Node, gs: Node, stage: GarageStage, ui_layer: CanvasLayer) -> Dictionary:
	var out: Dictionary = {}
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--demo" in args:
		gs.save_path = "user://demo_profile.json"
		gs.new_profile()
		gs.profile["money"] = 900000
		gs.profile["fame"] = 500
		if not ("--noparts" in args):                 # sem pecas: so o caminhao de fabrica (capturas da cabine)
			for id in DEMO_PARTS:
				var d: PartDef = gs.part(id)
				if d != null and gs.buy(d):
					gs.install(id)
	for a in args:
		if a.begins_with("--fame=") and "--demo" in args:    # T-171: Fama baixa (cores travadas)
			gs.profile["fame"] = int(a.substr(7))
	if "--damage" in args:
		for id in gs.profile["owned"]:
			var d2: PartDef = gs.part(String(id))
			if d2.durability > 0.0:
				gs.profile["owned"][id]["dur"] = d2.durability * 0.4
		if gs.profile["owned"].has("rb_chrome"):
			gs.profile["owned"]["rb_chrome"]["broken"] = true
		gs.profile["systems"]["engine"] = 55.0
	for a in args:
		if a == "--decals":
			gs.profile["decals"] = [
				{"id": "kanji_bakusou", "slot": "side_l", "x": -0.5, "y": 0.0, "size": 0.5, "color": "#f5cc5a"},
				{"id": "estrela", "slot": "side_r", "x": 0.3, "y": 0.0, "size": 0.45, "color": "#ff2e88"},
				{"id": "raio", "slot": "rear", "x": 0.0, "y": 0.0, "size": 0.7, "color": "#21e6ff"},
				{"id": "sol", "slot": "cab", "x": 0.0, "y": 0.1, "size": 0.5, "color": "#ffffff"}]
			stage.refresh_truck()
		elif a.begins_with("--lights="):
			gs.profile["light_pattern"] = a.substr(9)
			stage.refresh_truck()
			stage.truck.set_light_pattern(a.substr(9))
		elif a == "--hideui":
			ui_layer.visible = false
		elif a == "--day":
			stage.set_daytime(true)
		elif a.begins_with("--view="):
			stage.focus_view(a.substr(7))
		elif a.begins_with("--cab=") and "--demo" in args:    # so com --demo (perfil de teste, nunca o real)
			stage.set_cab(a.substr(6))
		elif a.begins_with("--body=") and "--demo" in args:   # --body=canter (T-125)
			stage.set_body(a.substr(7))
		elif a.begins_with("--parts=") and "--demo" in args:  # --parts=kw_bumper,fumi_wing (T-126): compra e instala
			for pid in a.substr(8).split(","):
				var pd: PartDef = gs.part(pid)
				if pd != null and (gs.owns(pid) or gs.buy(pd)):
					gs.install(pid)
			stage.refresh_truck()
		elif a.begins_with("--zoom="):                      # aproxima a camera (capturas de detalhe)
			var z: float = float(a.substr(7))
			screen.get_tree().create_timer(1.0).timeout.connect(func() -> void: stage.set_zoom(z))   # depois do layout
		elif a.begins_with("--shot="):          # captura de tela depois de 6 s (camera assentada) e fecha
			var path: String = a.substr(7)
			screen.get_tree().create_timer(6.0).timeout.connect(func() -> void: _take_shot(screen, path))
		elif a.begins_with("--preview=") and screen.has_method("preview_part"):   # T-171: peca em previa
			out["tab"] = "parts"
			var pp: PartDef = gs.part(a.substr(10))
			if pp != null:
				out["slot"] = String(pp.slot)
				screen.preview_part(a.substr(10))
		elif a.begins_with("--preview-paint=") and screen.has_method("preview_paint"):   # cor travada so para ver
			out["tab"] = "parts"
			screen.preview_paint(a.substr(16))
		elif a.begins_with("--tab="):
			out["tab"] = a.substr(6)
		elif a.begins_with("--deco="):                     # T-177: secao da DECORACAO (parts|paint|lights|decals)
			out["tab"] = "parts"
			out["deco"] = a.substr(7)
		elif a.begins_with("--slot="):
			out["tab"] = "parts"
			out["slot"] = a.substr(7)
			stage.focus_slot(a.substr(7))
	if "--spin" in args:                            # rodas em movimento (depois da vista: trocar de vista desliga)
		stage.set_wheel_spin(true)
	return out


static func _take_shot(screen: Node, path: String) -> void:
	await RenderingServer.frame_post_draw
	screen.get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURA: ", path)
	if "--shot-pair" in OS.get_cmdline_user_args():     # T-133: mais um quadro seguido (rodas girando)
		await RenderingServer.frame_post_draw
		var p2: String = path.get_basename() + "_2.png"
		screen.get_viewport().get_texture().get_image().save_png(p2)
		print("CAPTURA: ", p2)
	screen.get_tree().quit()
