class_name EngineSounds
extends RefCounted
## Which sound files a truck uses (T-173). Pure functions: no nodes, no playback (tests and server can call them).
## A "spec" is a Dictionary consumed by EngineAudio.setup_spec():
##   set      : prefix of the engine loops ("i6_std", "v8", "exh_stack"...)
##   bands    : loop suffixes present for that prefix (["idle","low","mid","high"] or ["idle","mid","high"])
##   pitch    : extra pitch multiplier (engine character when an exhaust profile replaces the engine loops)
##   turbo    : turbo whine loop ("" = no turbo layer); turbo_pitch / turbo_db tweak single vs twin
##   blowoffs : "pssh" one-shots, alternated
##   straight : true = add exhaust_straight_layer (old behaviour, only when the profile files are missing)
##   gains    : {layer name: extra dB} to even out loud/quiet generated files
## Exhaust -> profile comes from ExhaustDef.sound_profile (data/engines/exh_*.tres); "" = the engine's own loops.

const ENGINE_SETS: Dictionary = {"eng_i6_std": "i6_std", "eng_i6_tuned": "i6_tuned", "eng_v8": "v8"}
## Engine character on top of an exhaust profile (the profile replaces the engine loops).
const ENGINE_PITCH: Dictionary = {"eng_i6_std": 1.0, "eng_i6_tuned": 1.06, "eng_v8": 0.9}
const BANDS_4: Array[String] = ["idle", "low", "mid", "high"]
const BANDS_3: Array[String] = ["idle", "mid", "high"]
## Profiles generated in T-173 (3 loops each + turbo whine + blow-off). Order = garage / test tool order.
const PROFILES: Array[String] = ["exh_rasp", "exh_stack", "exh_pop"]
## Measured loudness of the generated files (docs/AUDIO_ELEVENLABS.md). T-178 files (RMS dBFS): exh_pop idle/mid/high
## -21.8/-17.6/-22.3 and exh_stack ~-16, quieter than the T-173 ones; these gains bring them back to the old level.
const LAYER_GAIN_DB: Dictionary = {"exh_pop_idle": 3.0, "exh_pop_mid": 2.0, "exh_pop_high": 5.0,
	"exh_stack_idle": 1.5, "exh_stack_mid": 1.5, "exh_stack_high": 1.5}
const EXHAUST_IDS: Array[String] = ["exh_std", "exh_straight", "exh_stack", "exh_chrome_cut"]
const TURBO_IDS: Array[String] = ["turbo_none", "turbo_single", "turbo_twin"]
const ENGINE_IDS: Array[String] = ["eng_i6_std", "eng_i6_tuned", "eng_v8"]
const AUDIO_ROOT: String = "res://assets/audio/engines/"
## T-197: synthesized diesel loops (tools/synth_truck_audio.py, DieselMix). Voice per engine; light bodies (Canter)
## use the 4-cylinder voice. Missing files or `--engine-sound=old` = the ElevenLabs loops above (legacy spec).
const SYN_VOICE: Dictionary = {"eng_i6_std": "i6", "eng_i6_tuned": "i6t", "eng_v8": "v8"}
const LIGHT_BODIES: Array[String] = ["canter"]
## Exhaust in the synthesized mode: open-pipe rasp layer (dB; -80 = none), overrun pops, overall gain.
const SYN_EXHAUST: Dictionary = {
	"exh_std": {"open_db": -80.0, "pops": false, "gain_db": 0.0},
	"exh_straight": {"open_db": -1.0, "pops": false, "gain_db": 1.0},
	"exh_stack": {"open_db": -6.0, "pops": false, "gain_db": 2.5},
	"exh_chrome_cut": {"open_db": -4.0, "pops": true, "gain_db": 1.0}}
static var legacy_default: bool = "--engine-sound=old" in OS.get_cmdline_user_args()


## Profile of an exhaust id ("" = engine loops). Reads the .tres (data drives the mapping).
static func exhaust_profile(exhaust_id: String) -> String:
	var path: String = "res://data/engines/%s.tres" % exhaust_id
	if not ResourceLoader.exists(path):
		return ""
	var d: Resource = load(path)
	return String(d.get("sound_profile")) if d != null and d.get("sound_profile") != null else ""


## Engine loops a profile needs (for tests / checks).
static func profile_layers(profile: String) -> Array[String]:
	var out: Array[String] = []
	for b in BANDS_3:
		out.append("%s_%s" % [profile, b])
	out.append(profile + "_turbo_whine")
	out.append(profile + "_blowoff")
	return out


static func has_engine_file(name: String) -> bool:
	for ext in [".mp3", ".ogg", ".wav"]:
		if ResourceLoader.exists(AUDIO_ROOT + name + ext):
			return true
	return false


## Voice of the synthesized loops for an engine and body.
static func voice_for(engine_id: String, body: String = "") -> String:
	return "i4" if body in LIGHT_BODIES else String(SYN_VOICE.get(engine_id, "i6"))


static func redline_of(engine_id: String) -> float:
	var path: String = "res://data/engines/%s.tres" % engine_id
	var d: Resource = load(path) if ResourceLoader.exists(path) else null
	return float(d.get("redline_rpm")) if d != null and d.get("redline_rpm") != null else 2400.0


## Spec for an engine/turbo/exhaust combination. `check_files` = false skips the file fallback (pure tests).
## T-197: synthesized diesel by default; `legacy` = the ElevenLabs loops (also used when the synth files are missing).
static func spec(engine_id: String, turbo_id: String, exhaust_id: String, check_files: bool = true, body: String = "",
		legacy: bool = legacy_default) -> Dictionary:
	var voice: String = voice_for(engine_id, body)
	if use_synth(voice, check_files, legacy):
		return synth_spec(engine_id, turbo_id, exhaust_id, voice)
	var profile: String = exhaust_profile(exhaust_id)
	var use_profile: bool = profile != "" and (not check_files or has_engine_file(profile + "_idle"))
	var out: Dictionary = {"set": String(ENGINE_SETS.get(engine_id, "i6_std")), "bands": BANDS_4, "pitch": 1.0,
		"turbo": "", "turbo_pitch": 1.0, "turbo_db": 0.0, "blowoffs": ["turbo_blowoff_1", "turbo_blowoff_2"],
		"straight": false, "gains": LAYER_GAIN_DB, "profile": ""}
	if use_profile:
		out["set"] = profile
		out["bands"] = BANDS_3
		out["pitch"] = float(ENGINE_PITCH.get(engine_id, 1.0))
		out["profile"] = profile
		if not check_files or has_engine_file(profile + "_blowoff"):
			out["blowoffs"] = [profile + "_blowoff"]
	elif exhaust_id == "exh_straight":
		out["straight"] = true                        # profile files missing: old straight-pipe layer
	if turbo_id == "turbo_single" or turbo_id == "turbo_twin":
		var own: String = profile + "_turbo_whine"
		if use_profile and (not check_files or has_engine_file(own)):
			out["turbo"] = own
			out["turbo_pitch"] = 1.1 if turbo_id == "turbo_twin" else 1.0
			out["turbo_db"] = 2.0 if turbo_id == "turbo_twin" else 0.0
		else:
			out["turbo"] = "turbo_twin_whine" if turbo_id == "turbo_twin" else "turbo_single_whine"
	return out


## Synthesized loops for this voice? (legacy asked, or the files are missing = ElevenLabs loops.)
static func use_synth(voice: String, check_files: bool = true, legacy: bool = legacy_default) -> bool:
	return not legacy and (not check_files or has_engine_file(DieselMix.layer(voice, "on", DieselMix.IDLE_RPM)))


## T-197 spec: "voice" set = synthesized diesel (EngineAudio reads voice/redline/open_db/pops/gain_db).
static func synth_spec(engine_id: String, turbo_id: String, exhaust_id: String, voice: String) -> Dictionary:
	var ex: Dictionary = SYN_EXHAUST.get(exhaust_id, SYN_EXHAUST["exh_std"])
	var out: Dictionary = {"set": "syn_" + voice, "voice": voice, "bands": [], "pitch": 1.0, "turbo": "",
		"turbo_pitch": 1.0, "turbo_db": 0.0, "blowoffs": ["turbo_blowoff_1", "turbo_blowoff_2"], "straight": false,
		"gains": {}, "profile": exhaust_profile(exhaust_id), "exhaust": exhaust_id, "redline": redline_of(engine_id),
		"open_db": float(ex["open_db"]), "pops": bool(ex["pops"]), "gain_db": float(ex["gain_db"])}
	if turbo_id == "turbo_single" or turbo_id == "turbo_twin":
		out["turbo"] = "turbo_twin_whine" if turbo_id == "turbo_twin" else "turbo_single_whine"
		out["turbo_pitch"] = 1.0
	return out


## Spec from a truck descriptor (GameState.truck_descriptor / online loadout).
static func from_descriptor(desc: Dictionary, legacy: bool = legacy_default) -> Dictionary:
	return spec(String(desc.get("engine", "eng_i6_std")), String(desc.get("turbo", "turbo_none")),
		String(desc.get("exhaust", "exh_std")), true, String(desc.get("body", "")), legacy)


## Sound-only draw for an offline rival (the simulation is not changed): engine, turbo and exhaust by seed.
static func rival_loadout(seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return {"engine": ENGINE_IDS[rng.randi_range(0, ENGINE_IDS.size() - 1)],
		"turbo": TURBO_IDS[rng.randi_range(0, TURBO_IDS.size() - 1)],
		"exhaust": EXHAUST_IDS[rng.randi_range(0, EXHAUST_IDS.size() - 1)]}
