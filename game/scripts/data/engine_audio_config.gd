class_name EngineAudioConfig
extends Resource
## T-220: which engine sound the player's truck uses (game/data/audio/engine_audio.tres). Options > Audio and
## `-- --engine-sound=loops|synth|mix` override it; `--engine-sound=old` = ElevenLabs loops (T-197).
##   loops = recorded/synthesized loops mixed by RPM (T-197; recordings rec_* win over syn_* when present)
##   synth = procedural diesel (DieselSynth) for the engine core; turbo, jake brake, pops and rattle stay loops
##   mix   = procedural below `crossover_hz` + loops above it (body from the synth, texture from the loops)
## Rivals and other trucks always use loops (cost).

@export_enum("loops", "synth", "mix") var mode: String = "loops"
@export_enum("loops", "synth", "mix") var mode_mobile: String = "loops"
@export var crossover_hz: float = 300.0
## Synth sample rate on PC and in the light version (phones).
@export var rate_pc: int = 22050
@export var rate_light: int = 11025
## Light version on phones (lower rate, fewer bus effects, no pipe echo).
@export var light_on_mobile: bool = true
## Generator buffer (s). Longer = safer against hitches, slower reaction.
@export var buffer_s: float = 0.08
## Synth level against the loops (dB), measured with tools/render_t220_audio.sh.
@export var synth_db: float = 0.0
