extends SceneTree
## T-219: graficos ANTES x DEPOIS do peso do caminhao (precisa de JANELA: desenha com a fonte do Godot e salva o PNG).
##   godot --path game -s res://tools_dev/plot_feel_t219.gd -- --out=ABS.png [--csv=ABS.csv] [--cargo=12000]
## Roteiro igual para os dois (simulacao pura, reta): acelera do zero por 12 s, troca de faixa para a direita (12 s) e
## volta (16 s), freada forte de 20 a 23 s, acelera de novo ate 28 s.
## ANTES = TruckFeel.legacy() na simulacao e a inclinacao antiga da tela (lean x 0,11 rad, sem cabeceio).
## DEPOIS = data/feel/truck_feel.tres + TruckMotion (balanco do bau).

const DT: float = 1.0 / 30.0
const T_END: float = 28.0
const W: int = 1400
const H: int = 1000
const C_OLD := Color(0.62, 0.66, 0.72)
const C_NEW := Color(1.0, 0.55, 0.12)

var _out: String = ""
var _csv: String = ""
var _cargo: float = TruckSim.DEFAULT_CARGO
var _data: Dictionary = {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--csv="):
			_csv = a.substr(6)
		elif a.begins_with("--cargo="):
			_cargo = float(a.substr(8))
	_data["old"] = _run(true)
	_data["new"] = _run(false)
	TruckFeel.use(null)
	if _csv != "":
		_write_csv()
	var view := Plot.new()
	view.data = _data
	view.cargo = _cargo
	view.size = Vector2(W, H)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED   # o projeto estica a tela; aqui 1 pixel = 1 pixel
	root.content_scale_factor = 1.0
	root.size = Vector2i(W, H)
	root.add_child(view)
	_save.call_deferred()


func _save() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	if _out != "":
		root.get_texture().get_image().save_png(_out)
		print("PLOT_T219: ", _out)
	quit()


func _cmd(t: float) -> Commands:
	var steer: float = 0.0
	for tap in [12.0, 12.4, 16.0, 16.4]:
		if t >= tap and t < tap + 0.12:
			steer = 1.0 if tap < 14.0 else -1.0
	if t >= 20.0 and t < 23.0:
		return Commands.make(0.0, 0.0, 1.0)
	return Commands.make(steer, 1.0, 0.0)


func _run(legacy: bool) -> Dictionary:
	TruckFeel.use(TruckFeel.legacy() if legacy else null)
	var tr := Track.new()
	tr.add_section(9000.0, 0.0)
	var t := TruckSim.new()
	var d: Dictionary = TruckConfig.basic_descriptor()
	d["cargo_kg"] = _cargo
	TruckConfig.apply(t, d)
	var m := TruckMotion.new()
	var feel: TruckFeel = load(TruckFeel.PATH) as TruckFeel
	var out := {"t": PackedFloat32Array(), "v": PackedFloat32Array(), "x": PackedFloat32Array(), "roll": PackedFloat32Array(),
		"pitch": PackedFloat32Array()}
	var time: float = 0.0
	while time < T_END:
		t.step(DT, _cmd(time), tr)
		time += DT
		for k in 2:                                  # a tela a 60 quadros por segundo
			m.step(DT * 0.5, feel, t.speed, t.lateral_vel * Track.ROAD_HALF_WIDTH_M, 0.0, 0.0)
		out["t"].append(time)
		out["v"].append(t.speed * 3.6)
		out["x"].append(t.x * Track.ROAD_HALF_WIDTH_M)
		out["roll"].append(rad_to_deg(t.lean() * 0.11) if legacy else rad_to_deg(m.roll))
		out["pitch"].append(0.0 if legacy else rad_to_deg(m.pitch))
	return out


func _write_csv() -> void:
	var f := FileAccess.open(_csv, FileAccess.WRITE)
	f.store_line("t,v_antes,v_depois,lateral_m_antes,lateral_m_depois,roll_antes,roll_depois,pitch_antes,pitch_depois")
	var o: Dictionary = _data["old"]
	var n: Dictionary = _data["new"]
	for i in (o["t"] as PackedFloat32Array).size():
		f.store_line("%.3f,%.2f,%.2f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f" % [o["t"][i], o["v"][i], n["v"][i], o["x"][i], n["x"][i],
			o["roll"][i], n["roll"][i], o["pitch"][i], n["pitch"][i]])
	f.close()


class Plot extends Control:
	var data: Dictionary
	var cargo: float

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.09, 0.11))
		var font: Font = ThemeDB.fallback_font
		draw_string(font, Vector2(30, 40), "T-219  peso do caminhao: ANTES (cinza) x DEPOIS (laranja)   carga %.0f t" % (cargo / 1000.0),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE)
		draw_string(font, Vector2(30, 70), "roteiro: acelera do zero · troca de faixa p/ direita (12 s) e volta (16 s) · freada forte 20-23 s · acelera",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.8, 0.8, 0.85))
		var panels: Array = [["v", "velocidade (km/h)", 0.0, 120.0], ["x", "posicao lateral (m)", -0.5, 4.5],
			["roll", "inclinacao do bau (graus; + = tomba p/ direita)", -5.0, 5.0], ["pitch", "cabeceio (graus; + = nariz sobe)", -3.0, 3.0]]
		var top: float = 95.0
		var ph: float = (size.y - top - 20.0) / panels.size()
		for i in panels.size():
			var p: Array = panels[i]
			var r := Rect2(90.0, top + i * ph + 26.0, size.x - 120.0, ph - 52.0)
			draw_rect(r, Color(0.13, 0.14, 0.17))
			draw_string(font, Vector2(r.position.x, r.position.y - 6.0), p[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(0.9, 0.9, 0.95))
			var lo: float = p[2]
			var hi: float = p[3]
			for g in 5:
				var val: float = lerpf(lo, hi, g / 4.0)
				var y: float = r.end.y - (val - lo) / (hi - lo) * r.size.y
				draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(1, 1, 1, 0.08))
				draw_string(font, Vector2(20.0, y + 6.0), "%.1f" % val, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.7, 0.7, 0.75))
			for s in range(0, 29, 4):
				var xx: float = r.position.x + s / 28.0 * r.size.x
				draw_line(Vector2(xx, r.position.y), Vector2(xx, r.end.y), Color(1, 1, 1, 0.06))
				if i == panels.size() - 1:
					draw_string(font, Vector2(xx - 8.0, r.end.y + 20.0), "%d s" % s, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.7, 0.7, 0.75))
			for key in ["old", "new"]:
				var d: Dictionary = data[key]
				var ts: PackedFloat32Array = d["t"]
				var vs: PackedFloat32Array = d[p[0]]
				var pts := PackedVector2Array()
				for k in ts.size():
					pts.append(Vector2(r.position.x + ts[k] / 28.0 * r.size.x, r.end.y - (clampf(vs[k], lo, hi) - lo) / (hi - lo) * r.size.y))
				draw_polyline(pts, C_OLD if key == "old" else C_NEW, 3.0 if key == "new" else 2.0, true)
