class_name HornCatalog
extends RefCounted
## Horns the player can pick in the garage (T-173). Pure data: no nodes.
## musical = plays the melody once while held (stops when released); otherwise the horn is held by looping
## between `from` and `at` (seconds measured on the generated files, docs/AUDIO_ELEVENLABS.md).
## Profile key "horn" = one of IDS, or "" (AUTO) = the horn of an installed part, else the basic air horn.

const AUTO: String = ""
const BASIC: String = "horn_air_basic"
const IDS: Array[String] = ["horn_air_basic", "horn_ship_deep", "horn_dual_tone", "horn_musical_1", "horn_musical_2", "horn_musical_dekotora"]
const NEW_T173: Array[String] = ["horn_ship_deep", "horn_dual_tone", "horn_musical_dekotora"]
## Sustained horns: loop window (s). horn_air_basic only holds its tone for ~0.3 s (the old 0.35..1.45 window
## looped silence).
const LOOP: Dictionary = {
	"horn_air_basic": [0.08, 0.26],
	"horn_ship_deep": [0.25, 0.95],
	"horn_dual_tone": [0.3, 1.3],
}


static func is_valid(id: String) -> bool:
	return id in IDS


static func is_musical(id: String) -> bool:
	return not LOOP.has(id)


## [from, at] loop window of a sustained horn (fallback for unknown sounds: the old T-144 window).
static func loop_window(id: String) -> Array:
	return LOOP.get(id, [0.35, 1.45])


static func label_key(id: String) -> String:
	return "horn.auto" if id == AUTO else "horn." + id


## Horn actually played: the chosen one if valid, else the part's horn, else the basic one.
static func resolve(chosen: String, part_horn: String) -> String:
	if is_valid(chosen):
		return chosen
	return part_horn if part_horn != "" else BASIC


## Sound-only draw for an offline rival without a horn part.
static func rival_horn(seed: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return IDS[rng.randi_range(0, IDS.size() - 1)]
