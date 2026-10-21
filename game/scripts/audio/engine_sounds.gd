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
## Measured loudness of the generated files (docs/AUDIO_ELEVENLABS.md, T-173): exh_pop_high came out ~6 dB quieter.
const LAYER_GAIN_DB: Dictionary = {"exh_pop_high": 5.0, "exh_stack_idle": -2.0}
const EXHAUST_IDS: Array[String] = ["exh_std", "exh_straight", "exh_stack", "exh_chrome_cut"]
const TURBO_IDS: Array[String] = ["turbo_none", "turbo_single", "turbo_twin"]
const ENGINE_IDS: Array[String] = ["eng_i6_std", "eng_i6_tuned", "eng_v8"]
const AUDIO_ROOT: String = "res://assets/audio/engines/"


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


## Spec for an engine/turbo/exhaust combination. `check_files` = false skips the file fallback (pure tests).
static func spec(engine_id: String, turbo_id: String, exhaust_id: String, check_files: bool = true) -> Dictionary:
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


## Spec from a truck descriptor (GameState.truck_descriptor / online loadout).
static func from_descriptor(desc: Dictionary) -> Dictionary:
	return spec(String(desc.get("engine", "eng_i6_std")), String(desc.get("turbo", "turbo_none")), String(desc.get("exhaust", "exh_std")))


## Sound-only draw for an offline rival (the simulation is not changed): engine, turbo and exhaust by seed.
static func rival_loadout(seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return {"engine": ENGINE_IDS[rng.randi_range(0, ENGINE_IDS.size() - 1)],
		"turbo": TURBO_IDS[rng.randi_range(0, TURBO_IDS.size() - 1)],
		"exhaust": EXHAUST_IDS[rng.randi_range(0, EXHAUST_IDS.size() - 1)]}
