class_name EngineSoundMode
extends RefCounted
## T-220: which engine sound the player's truck uses: "loops" (T-197 loops; recordings rec_* when present),
## "synth" (procedural diesel, DieselSynth) or "mix" (synth below the crossover + loops above). Order of priority:
## `-- --engine-sound=loops|synth|mix` > Options > Audio (Settings.engine_sound, "" = default) > data file
## game/data/audio/engine_audio.tres (mode on PC, mode_mobile on phones). Pure helpers (tests, no playback).

## T-260: "rec" = gravacoes reais (rec_*, tools/rec_engine_t260.py) onde existem, senao os loops sintetizados;
## "loops" = so os loops sintetizados da T-197 (comparar).
const MODES: Array[String] = ["rec", "loops", "synth", "mix"]
const CONFIG_PATH: String = "res://data/audio/engine_audio.tres"
const VOICE_PATH: String = "res://data/audio/voice_%s.tres"

static var _cfg: EngineAudioConfig = null


static func config() -> EngineAudioConfig:
	if _cfg == null:
		_cfg = load(CONFIG_PATH) as EngineAudioConfig if ResourceLoader.exists(CONFIG_PATH) else null
		if _cfg == null:
			_cfg = EngineAudioConfig.new()
	return _cfg


## Mode from the command line ("" = none given; "old" is the ElevenLabs switch handled by EngineSounds).
static func cmdline_mode(args: PackedStringArray = OS.get_cmdline_user_args()) -> String:
	for a in args:
		if a.begins_with("--engine-sound="):
			var m: String = a.substr(15)
			if m in MODES:
				return m
	return ""


## Resolved mode. `setting` = Settings.engine_sound ("" = default of the data file).
static func resolve(cmd: String, setting: String, mobile: bool, cfg: EngineAudioConfig) -> String:
	if cmd in MODES:
		return cmd
	if setting in MODES:
		return setting
	var m: String = cfg.mode_mobile if mobile else cfg.mode
	return m if m in MODES else "loops"


static func current() -> String:
	var setting: String = ""
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var s: Node = tree.root.get_node_or_null("Settings") if tree != null else null
	if s != null and s.get("engine_sound") != null:
		setting = String(s.get("engine_sound"))
	return resolve(cmdline_mode(), setting, OS.has_feature("mobile"), config())


## Light synth (phones; `--synth-light` forces it on the PC to measure).
static func light() -> bool:
	return "--synth-light" in OS.get_cmdline_user_args() or (OS.has_feature("mobile") and config().light_on_mobile)


## Voice data of the procedural synth for a voice id (i6, i6t, v8, i4); null = not made yet (keeps the loops).
static func voice_def(voice: String) -> EngineVoiceDef:
	var p: String = VOICE_PATH % voice
	return load(p) as EngineVoiceDef if ResourceLoader.exists(p) else null
