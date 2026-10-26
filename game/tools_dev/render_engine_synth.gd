extends SceneTree
## T-220: offline render of the procedural diesel EXCITATION (DieselSynth only, without the bus effects) on the same
## ramp as the test scene (--ramp): idle 2 s, 700 -> 2400 rpm in 8 s full throttle, hold 1 s, lift 4 s, idle 2 s.
## godot --headless --path game -s res://tools_dev/render_engine_synth.gd -- --out=ABS.wav [--rate=22050]
##   [--set=campo:valor,campo:valor] muda numeros do voice_i6.tres so nesta gravacao (ex.: --set=flow:0.4,amp_sigma:0.12)
## Used to tune the irregularity quickly (tools/audio_t220_compare.py measures it); the real sound = Movie Maker.

const RAMP: Array[float] = [2.0, 10.0, 11.0, 15.0, 17.0]


func _init() -> void:
	var out: String = ""
	var rate: int = 22050
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--rate="):
			rate = int(a.substr(7))
	var v: EngineVoiceDef = (load("res://data/audio/voice_i6.tres") as EngineVoiceDef).duplicate()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--set="):
			for kv in a.substr(6).split(","):
				var p: PackedStringArray = kv.split(":")
				v.set(p[0], float(p[1]))
	var s := DieselSynth.new(v, float(rate))
	var block: int = rate / 60
	var data := PackedByteArray()
	var t: float = 0.0
	while t < RAMP[4]:
		var r: float = 0.0
		var thr: float = 0.0
		if t >= RAMP[0] and t < RAMP[1]:
			r = (t - RAMP[0]) / (RAMP[1] - RAMP[0])
			thr = 1.0
		elif t >= RAMP[1] and t < RAMP[2]:
			r = 1.0
			thr = 1.0
		elif t >= RAMP[2] and t < RAMP[3]:
			r = 1.0 - (t - RAMP[2]) / (RAMP[3] - RAMP[2])
		var m: PackedFloat32Array = s.render(block, lerpf(700.0, 2400.0, r), thr, 1.0)
		for x in m:
			var i: int = clampi(int(x * 0.5 * 32767.0), -32768, 32767)
			data.append(i & 0xff)
			data.append((i >> 8) & 0xff)
		t += float(block) / float(rate)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	print("RENDER ", out, " ", w.save_to_wav(out))
	quit()
