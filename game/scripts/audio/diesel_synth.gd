class_name DieselSynth
extends RefCounted
## T-220: procedural diesel engine, the EXCITATION part (pure GDScript, no nodes: tests and offline renders use it).
## Every combustion of every cylinder is placed at its real firing time: f = rpm / 60 * cylinders / (strokes / 2)
## (6 cyl 4-stroke: rpm / 20 -> 700 rpm = 35 Hz, 2500 rpm = 125 Hz). The rpm is ramped sample by sample inside each
## block, so the pitch follows the engine continuously (no steps, no loop seams). Per firing:
##   * exhaust pressure pulse (critically damped 2-pole = alpha pulse, width ~7% of the interval), weaker off load;
##   * sharp blowdown click (valve opening), noise burst (gas rush) and injector knock, all scaled by load;
##   * fixed per-cylinder strength bias + random variation + timing jitter (bigger at idle) -> the diesel "lope";
##   * slow governor wander of the rpm; misfires when the engine is damaged.
## Continuous turbulent flow noise is pushed by each firing. The exhaust resonances (boom, mid, muffler low-pass,
## grit, pipe echo) are NOT here: EngineSynthVoice runs them as bus effects in C++ (cheap on phones).

const NOISE_LEN: int = 32768           # power of two (mask)
const TAU_MIN_S: float = 0.00035
const TAU_MAX_S: float = 0.0022
const BLOW_TAU_S: float = 0.00028
const IDLE_RPM: float = 700.0

var mix_rate: float = 22050.0
var voice: EngineVoiceDef
var gain: float = 0.5                  # output scale (EngineSynthVoice keeps the bus in range)

var _ncyl: int = 6
var _revs: float = 2.0                 # revolutions per cycle (4-stroke = 2)
var _phases: PackedFloat32Array = PackedFloat32Array()
var _bank: PackedFloat32Array = PackedFloat32Array()
var _bias: PackedFloat32Array = PackedFloat32Array()
var _noise: PackedFloat32Array = PackedFloat32Array()
var _rng := RandomNumberGenerator.new()
# state
var _ni: int = 0
var _cyc: float = 0.0                  # position in the current cycle (0..1+)
var _k: int = 0                        # next firing index
var _next: float = 0.0                 # cycle position of the next firing (with jitter)
var _rpm: float = IDLE_RPM
var _load: float = 0.0
var _health: float = 1.0
var _wob: float = 0.0
var _wob_target: float = 0.0
var _p1: float = 0.0
var _q1: float = 0.0
var _p2: float = 0.0
var _q2: float = 0.0
var _be: float = 0.0                   # burst envelope
var _ce: float = 0.0                   # clatter envelope
var _fe: float = 0.0                   # flow push envelope
var _prev_n: float = 0.0
## Firings rendered so far (tests count them to check the firing frequency).
var fired: int = 0
var misfires: int = 0


func _init(v: EngineVoiceDef = null, rate: float = 22050.0) -> void:
	setup(v if v != null else EngineVoiceDef.new(), rate)


func setup(v: EngineVoiceDef, rate: float) -> void:
	voice = v
	mix_rate = rate
	_ncyl = maxi(v.cylinders, 1)
	_revs = 2.0 if v.strokes >= 4 else 1.0
	_rng.seed = v.seed
	_phases.resize(_ncyl)
	_bank.resize(_ncyl)
	_bias.resize(_ncyl)
	for k in _ncyl:
		_phases[k] = v.firing_phases[k] if v.firing_phases.size() == _ncyl else float(k) / float(_ncyl)
		_bank[k] = v.bank_gain[k] if v.bank_gain.size() == _ncyl else 1.0
		_bias[k] = maxf(0.3, 1.0 + v.cyl_bias * _rng.randfn())
	_noise.resize(NOISE_LEN)
	for i in NOISE_LEN:
		_noise[i] = _rng.randf_range(-1.0, 1.0)
	_k = 0
	_cyc = 0.0
	_next = _phases[0]
	fired = 0
	misfires = 0


## Firing (fundamental) frequency in Hz for an rpm: rpm / 60 * cylinders / revolutions per cycle.
static func firing_hz(rpm: float, cylinders: int, strokes: int = 4) -> float:
	return rpm / 60.0 * float(cylinders) / (2.0 if strokes >= 4 else 1.0)


## Renders `frames` mono samples. The rpm / load / health move linearly from the last block's values to these.
func render(frames: int, rpm: float, load: float, health: float = 1.0) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(frames)
	if frames <= 0:
		return out
	var sr: float = mix_rate
	var r0: float = _rpm
	var dr: float = (maxf(rpm, 100.0) - r0) / float(frames)
	var l0: float = _load
	var dl: float = (clampf(load, 0.0, 1.0) - l0) / float(frames)
	_health = clampf(health, 0.0, 1.0)
	var kc: float = 1.0 / (60.0 * _revs * sr)
	# pulse shapes (per block; the width follows the firing interval)
	var interval_s: float = 1.0 / maxf(firing_hz(rpm, _ncyl, voice.strokes), 1.0)
	var tau1: float = clampf(voice.pulse_width * interval_s, TAU_MIN_S, TAU_MAX_S) * sr
	var a1: float = exp(-1.0 / tau1)
	var tau2: float = maxf(BLOW_TAU_S * sr, 0.6)
	var a2: float = exp(-1.0 / tau2)
	var n2: float = 2.7182818 / tau2
	var bd: float = exp(-1.0 / (voice.burst_ms * 0.001 * sr))
	var cd: float = exp(-1.0 / (voice.clatter_ms * 0.001 * sr))
	var fd: float = exp(-1.0 / (0.6 * interval_s * sr))
	var flow_k: float = voice.flow * (0.35 + 0.65 * clampf(rpm / 2400.0, 0.0, 1.0))
	var mask: int = NOISE_LEN - 1
	var noise: PackedFloat32Array = _noise
	var p1: float = _p1
	var q1: float = _q1
	var p2: float = _p2
	var q2: float = _q2
	var be: float = _be
	var ce: float = _ce
	var fe: float = _fe
	var ni: int = _ni
	var prev_n: float = _prev_n
	var cyc: float = _cyc
	var nxt: float = _next
	var r: float = r0
	var l: float = l0
	var g: float = gain
	var wob: float = _wob
	for i in frames:
		r += dr
		l += dl
		cyc += r * (1.0 + wob) * kc
		var imp1: float = 0.0
		var imp2: float = 0.0
		if cyc >= nxt:
			var f: Vector4 = _fire(r, l)          # x main, y blowdown, z burst, w clatter
			var tw: float = tau1 * maxf(0.5, 1.0 + voice.width_sigma * _rng.randfn())   # every combustion a bit different
			a1 = exp(-1.0 / tw)
			imp1 = f.x * 2.7182818 / tw
			imp2 = f.y * n2
			be = maxf(be, f.z)
			ce = f.w
			fe = 1.0
			if _k == 0:
				cyc -= 1.0
			nxt = _next
			wob = _wob
		p1 = a1 * p1 + imp1
		q1 = a1 * q1 + p1
		p2 = a2 * p2 + imp2
		q2 = a2 * q2 + p2
		var nz: float = noise[ni]
		var nz2: float = noise[(ni + 9973) & mask]
		ni = (ni + 1) & mask
		be *= bd
		ce *= cd
		fe *= fd
		out[i] = g * (q1 + q2 + nz * be + (nz2 - prev_n) * ce + nz2 * flow_k * (0.35 + fe) * (0.3 + 0.7 * l))
		prev_n = nz2
	_p1 = p1
	_q1 = q1
	_p2 = p2
	_q2 = q2
	_be = be
	_ce = ce
	_fe = fe
	_ni = ni
	_prev_n = prev_n
	_cyc = cyc
	_rpm = r0 + dr * float(frames)
	_load = l0 + dl * float(frames)
	return out


## One combustion: strengths of (main pulse, blowdown, noise burst, clatter); schedules the next firing.
func _fire(rpm: float, load: float) -> Vector4:
	var k: int = _k
	var idle: bool = rpm < IDLE_RPM + 80.0
	var sigma: float = voice.amp_sigma_idle if idle else voice.amp_sigma
	var amp: float = _bank[k] * _bias[k] * maxf(0.2, 1.0 + sigma * _rng.randfn())
	var ld: float = maxf(load, 0.22) if idle else load                  # idle still burns fuel
	fired += 1
	if _health < 0.65 and _rng.randf() < (0.65 - _health) * 0.25:     # damaged: misfire (weak pumping pulse only)
		misfires += 1
		amp *= 0.12
		ld = 0.0
	var main: float = amp * (0.13 + 0.87 * ld)
	var blow: float = amp * voice.blowdown * (0.25 + 0.9 * ld) if ld > 0.0 else amp * 0.08
	var rate: float = pow(maxf(rpm, 300.0) / 1400.0, 0.6)
	var bst: float = amp * voice.burst * (0.12 + 0.6 * ld) * rate
	var clt: float = amp * voice.clatter * (0.25 + 0.75 * ld) * (1.0 + 0.35 * _rng.randfn())
	# next firing
	_k = (k + 1) % _ncyl
	var jit: float = (voice.jitter_idle if idle else voice.jitter) * _rng.randfn() / float(_ncyl)
	_next = _phases[_k] + jit              # on wrap (_k == 0) the caller subtracts 1 from the cycle position
	if _k == 0:
		_wob_target = voice.rpm_wobble * _rng.randfn()
	_wob = lerpf(_wob, _wob_target, 0.15)
	return Vector4(main, blow, bst, clt)
