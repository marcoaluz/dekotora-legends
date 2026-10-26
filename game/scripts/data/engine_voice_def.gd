class_name EngineVoiceDef
extends Resource
## T-220: voice of the procedural diesel (DieselSynth + EngineSynthVoice). One .tres per engine sound in
## game/data/audio/voice_<voice>.tres (voice = EngineSounds.voice_for: i6, i6t, v8, i4). Missing file = that engine
## keeps the loops. Excitation numbers are used by DieselSynth (GDScript, per sample); the exhaust resonances run as
## bus effects (C++), set up by EngineSynthVoice.

@export var id: String = "i6"
@export_group("Engine")
@export var cylinders: int = 6
## 4 = four-stroke (every cylinder fires once per 2 revolutions), 2 = two-stroke.
@export var strokes: int = 4
## Firing times inside one cycle (0..1, sorted). Empty = evenly spaced (k / cylinders).
@export var firing_phases: PackedFloat32Array = PackedFloat32Array()
## Strength per firing event (e.g. V8 cross-plane: the near bank louder). Empty = all 1.0.
@export var bank_gain: PackedFloat32Array = PackedFloat32Array()
@export_group("Irregularity")
## Fixed strength difference between cylinders (std, 0.1 = 10%): the low "lope" repeating every cycle.
@export var cyl_bias: float = 0.10
## Random strength change per combustion (std) at idle and under way.
@export var amp_sigma_idle: float = 0.15
@export var amp_sigma: float = 0.14
## Timing jitter per combustion (std, fraction of the firing interval) at idle and under way.
@export var jitter_idle: float = 0.014
@export var jitter: float = 0.01
## Slow RPM wander of the governor (std, fraction of rpm).
@export var rpm_wobble: float = 0.004
@export_group("Combustion")
## Width of the exhaust pressure pulse (fraction of the firing interval), clamped to 0.35..2.2 ms.
@export var pulse_width: float = 0.07
## Random change of that width per combustion (std): no two explosions sound exactly alike.
@export var width_sigma: float = 0.2
## Sharp blowdown click per firing (exhaust valve opening), scaled by load.
@export var blowdown: float = 0.9
## Combustion noise burst per firing (gas rushing out) and its decay (ms).
@export var burst: float = 0.85
@export var burst_ms: float = 6.0
## Injector / diesel knock click (high, short) and its decay (ms).
@export var clatter: float = 0.30
@export var clatter_ms: float = 0.9
## Continuous turbulent flow noise, pushed by each firing (the "roar" between pulses).
@export var flow: float = 0.5
@export_group("Exhaust (bus effects)")
@export var boom_hz: float = 105.0
@export var boom_db: float = 6.0
@export var mid_hz: float = 520.0
@export var mid_db: float = 7.0
## Small-speaker presence (keeps the growl audible on phones).
@export var presence_hz: float = 900.0
@export var presence_db: float = 5.0
## Muffler low-pass: cutoff at idle and at the redline (opens with rpm and load).
@export var lp_idle_hz: float = 1900.0
@export var lp_high_hz: float = 3400.0
## Grit (AudioEffectDistortion drive 0..1).
@export var drive: float = 0.35
## Pipe echo (feedback delay); PC only.
@export var echo_ms: float = 7.5
@export var echo_db: float = -9.0
@export_group("Level")
@export var level_db: float = 0.0
@export var seed: int = 11
