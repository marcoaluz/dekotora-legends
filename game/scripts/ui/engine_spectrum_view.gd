class_name EngineSpectrumView
extends Control
## T-220: live spectrum of the "Engine" bus (AudioEffectSpectrumAnalyzer added while this view exists) on a log axis
## 20 Hz..4 kHz, with the firing frequency a real diesel has at the current rpm (green, harmonics dimmer) and the
## strongest low peak measured now (red). Lets the Marco SEE whether the sound follows the engine.

const FMIN: float = 20.0
const FMAX: float = 4000.0
const COLS: int = 180
const BUS: String = "Engine"

var rpm: float = 700.0
var cylinders: int = 6
var strokes: int = 4
var _fx_idx: int = -1
var _bus_idx: int = -1
var _mags: PackedFloat32Array = PackedFloat32Array()
var _peak_hz: float = 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(440, 200)
	_mags.resize(COLS)
	_bus_idx = AudioServer.get_bus_index(BUS)
	if _bus_idx >= 0:
		var an := AudioEffectSpectrumAnalyzer.new()
		an.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_4096
		an.buffer_length = 1.0
		AudioServer.add_bus_effect(_bus_idx, an)
		_fx_idx = AudioServer.get_bus_effect_count(_bus_idx) - 1


func _exit_tree() -> void:
	if _bus_idx >= 0 and _fx_idx >= 0 and _fx_idx < AudioServer.get_bus_effect_count(_bus_idx):
		AudioServer.remove_bus_effect(_bus_idx, _fx_idx)
	_fx_idx = -1


static func x_of(hz: float, w: float) -> float:
	return (log(hz / FMIN) / log(FMAX / FMIN)) * w


func _process(_dt: float) -> void:
	if _fx_idx < 0:
		return
	var inst: AudioEffectSpectrumAnalyzerInstance = AudioServer.get_bus_effect_instance(_bus_idx, _fx_idx) as AudioEffectSpectrumAnalyzerInstance
	if inst == null:
		return
	var best: float = 0.0
	for i in COLS:
		var f0: float = FMIN * pow(FMAX / FMIN, float(i) / COLS)
		var f1: float = FMIN * pow(FMAX / FMIN, float(i + 1) / COLS)
		var m: Vector2 = inst.get_magnitude_for_frequency_range(f0, f1, AudioEffectSpectrumAnalyzerInstance.MAGNITUDE_MAX)
		var db: float = linear_to_db(maxf(m.length(), 1e-6))
		_mags[i] = lerpf(_mags[i], clampf((db + 72.0) / 72.0, 0.0, 1.0), 0.35)
		if f0 >= 25.0 and f1 <= 300.0 and m.length() > best:
			best = m.length()
			_peak_hz = sqrt(f0 * f1)
	queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y - 34.0
	draw_rect(Rect2(0, 0, w, size.y), Color(0.04, 0.05, 0.09))
	var font: Font = get_theme_default_font()
	for g in [20.0, 50.0, 100.0, 200.0, 500.0, 1000.0, 2000.0, 4000.0]:
		var gx: float = x_of(g, w)
		draw_line(Vector2(gx, 0), Vector2(gx, h), Color(1, 1, 1, 0.08))
		draw_string(font, Vector2(gx + 2, h + 12), str(int(g)) if g < 1000.0 else "%dk" % int(g / 1000.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.6, 0.6, 0.7))
	var fire: float = DieselSynth.firing_hz(rpm, cylinders, strokes)
	for k in range(1, 9):
		var fx: float = x_of(fire * k, w)
		if fire * k < FMAX:
			draw_line(Vector2(fx, 0), Vector2(fx, h), Color(0.25, 0.9, 0.45, 0.9 if k == 1 else 0.3), 2.0 if k == 1 else 1.0)
	var bw: float = w / COLS
	for i in COLS:
		var bh: float = _mags[i] * h
		draw_rect(Rect2(i * bw, h - bh, maxf(bw - 1.0, 1.0), bh), Color(0.35, 0.75, 1.0, 0.85))
	draw_line(Vector2(x_of(maxf(_peak_hz, FMIN), w), 0), Vector2(x_of(maxf(_peak_hz, FMIN), w), h), Color(1, 0.3, 0.3), 2.0)
	draw_string(font, Vector2(4, size.y - 4), "%d rpm: ignição esperada %.1f Hz (verde)   pico grave agora %.0f Hz (vermelho)" % [int(rpm), fire, _peak_hz],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.9, 0.9, 0.9))
