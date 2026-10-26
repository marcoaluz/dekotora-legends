extends SceneTree
## T-220: CPU cost of the procedural diesel (GDScript part, DieselSynth.render + the Vector2 copy of
## EngineSynthVoice._fill). Headless: godot --headless --path game -s res://tools_dev/bench_engine_synth.gd
## Prints ms per second of audio and ms per frame at 60 fps for the PC rate and the light (phone) rate,
## and the firing count check (fired / expected) on a 700 -> 2500 rpm ramp. The bus effects (C++) are not included.


func _init() -> void:
	var v: EngineVoiceDef = load("res://data/audio/voice_i6.tres")
	for rate in [22050, 11025]:
		var s := DieselSynth.new(v, float(rate))
		var block: int = rate / 60
		var secs: float = 10.0
		var blocks: int = int(secs * 60.0)
		var t0: int = Time.get_ticks_usec()
		var expected: float = 0.0
		var peak: float = 0.0
		var worst: int = 0
		for b in blocks:
			var rpm: float = lerpf(700.0, 2500.0, float(b) / float(blocks))
			var tb: int = Time.get_ticks_usec()
			var m: PackedFloat32Array = s.render(block, rpm, 1.0, 1.0)
			var buf := PackedVector2Array()
			buf.resize(block)
			for i in block:
				buf[i] = Vector2(m[i], m[i])
			worst = maxi(worst, Time.get_ticks_usec() - tb)
			expected += DieselSynth.firing_hz(rpm, 6) * float(block) / float(rate)
			for i in block:
				peak = maxf(peak, absf(m[i]))
		var us: float = float(Time.get_ticks_usec() - t0)
		print("SYNTH_BENCH rate=%d  %.1f ms por s de audio  %.3f ms por quadro (60 fps, media)  pior quadro %.3f ms  disparos %d/%.0f  pico %.2f"
			% [rate, us / 1000.0 / secs, us / 1000.0 / float(blocks), float(worst) / 1000.0, s.fired, expected, peak])
	quit()
