class_name ExhaustDef
extends Resource
## Escape: bonus de torque e de Fama.

@export var id: StringName
@export var display_key: String = ""
@export var torque_bonus: float = 0.0          # 0.03 = +3%
@export var fame: int = 0
@export var price: int = 0
## T-173: prefix of this exhaust's own engine sound (loops <profile>_idle/_mid/_high, <profile>_turbo_whine,
## <profile>_blowoff in assets/audio/engines/). "" = the engine's own loops (EngineSounds).
@export var sound_profile: String = ""
