extends Node2D
## Cena da corrida (P21): liga simulacao -> estrada pseudo-3D + caminhao do jogador em camadas.
## A simulacao roda em passo fixo (30/s); aqui interpolamos para 60 FPS.

const GROUND_MARGIN: float = 0.0

var sim: RaceSim
var player: int = -1
var input := LocalInput.new()
var _acc: float = 0.0
var _prev_z: float = 0.0
var _prev_x: float = 0.0
var _steer_smooth: float = 0.0
var _road: RoadRenderer
var _bg: ParallaxBg
var _roadside: RoadsideLayer
var _truck: TruckView
var _hud: Label
var _fps_timer: float = 0.0
var autoplay: bool = false          # usado em testes/capturas: acelera sozinho


func _ready() -> void:
	scale = Vector2(2, 2)   # layout legado em 480x270 sobre a base 960x540
	sim = RaceSim.new(Track.make_test_track())
	player = sim.add_truck()
	_bg = ParallaxBg.new()
	add_child(_bg)
	_road = RoadRenderer.new()
	_road.draw_sky = false
	add_child(_road)
	_roadside = RoadsideLayer.new()
	add_child(_roadside)
	_truck = TruckView.new()
	add_child(_truck)
	_hud = Label.new()
	_hud.position = Vector2(6, 4)
	_hud.add_theme_font_size_override("font_size", 10)
	add_child(_hud)
	if DisplayServer.is_touchscreen_available() or Settings.show_touch_controls or "--touch" in OS.get_cmdline_user_args():
		var layer := CanvasLayer.new()
		layer.layer = 10
		var tc := TouchControls.new()
		tc.target = input
		layer.add_child(tc)
		add_child(layer)
	autoplay = "--autoplay" in OS.get_cmdline_user_args()
	for a in OS.get_cmdline_user_args():     # depuracao: --start=600 comeca a 600 m ja em movimento
		if a.begins_with("--start="):
			sim.trucks[player].z = float(a.substr(8))
			sim.trucks[player].speed = 30.0
	_prev_z = sim.trucks[player].z
	_prev_x = sim.trucks[player].x


func _process(delta: float) -> void:
	var cmd: Commands = input.poll()
	if autoplay:
		cmd = Commands.make(0.0, 1.0, 0.0)
	sim.set_command(player, cmd)
	_acc += minf(delta, 0.1)
	while _acc >= RaceSim.FIXED_DT:
		_prev_z = sim.trucks[player].z
		_prev_x = sim.trucks[player].x
		sim.step()
		_acc -= RaceSim.FIXED_DT
	var a: float = _acc / RaceSim.FIXED_DT
	var t: TruckSim = sim.trucks[player]
	var vz: float = lerpf(_prev_z, t.z, a)
	var vx: float = lerpf(_prev_x, t.x, a)
	_road.update_view(sim.track, vz, vx)
	_roadside.update_view(_road.projector)
	_bg.advance(sim.track.curve_at(vz) * t.speed * delta * 0.05)
	# caminhao: ancora na traseira, a CAM_BEHIND metros da camera
	var p: Vector3 = _road.projector.project(vx, vz, 0.0)
	_truck.position = Vector2(SpriteProjector.SCREEN_W * 0.5, roundf(p.y))
	_steer_smooth = lerpf(_steer_smooth, cmd.steer, minf(8.0 * delta, 1.0))
	_truck.set_angle_index(clampi(roundi(_steer_smooth * 2.0) + 2, 0, 4))
	_fps_timer += delta
	_hud.text = "%d km/h   x=%.2f   FPS %d   %.0f / %.0f m" % [
		roundi(t.speed * 3.6), t.x, Engine.get_frames_per_second(), t.z, sim.track.length_m]
	if autoplay and _fps_timer > 3.0 and _fps_timer - delta <= 3.0:
		print("FPS_MEDIDO: ", Engine.get_frames_per_second())
