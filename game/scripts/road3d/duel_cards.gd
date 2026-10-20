class_name DuelCards
extends RefCounted
## Data of the bands of the face-to-face opening (T-156), all real: driver and truck names, crest, paint,
## destaque (decoration score of the parts actually on the truck) and a short taunt (pt-BR, i18n).
## No portrait art exists yet: the band shows a crest (circle in the paint colour + one kanji).

const PLAYER_CREST: String = "銀"          # from the player's andon (銀河丸)
const PLAYER_LINES: int = 4                # intro.player_line.1..4
const HUMAN_CRESTS: Array[String] = ["銀", "嵐", "星", "龍"]


## Card of the player (offline): name from the options, truck name, paint, destaque of the garage.
static func player(gs: Node, line_seed: int) -> Dictionary:
	var s: Node = gs.get_node("/root/Settings")
	var name: String = String(s.player_name) if s != null and String(s.player_name).strip_edges() != "" else Tr.t("lobby.default_name")
	return {"driver": name, "truck": String(gs.profile.get("truck_name", Tr.t("intro.player_truck"))), "crest": PLAYER_CREST,
		"color": Color(String(gs.profile.get("paint", "#e9eef5"))), "destaque": int(gs.destaque()),
		"line": Tr.t("intro.player_line.%d" % (posmod(line_seed, PLAYER_LINES) + 1))}


## Card of the route rival: its RivalDef (name, truck, crest, paint, taunt) and the destaque of its parts in the sim.
static func rival(rv: RivalDef, truck: TruckSim) -> Dictionary:
	return {"driver": rv.display_name, "truck": Tr.t(rv.truck_key) if rv.truck_key != "" else "", "crest": rv.crest,
		"color": rv.paint, "destaque": roundi(RaceRules.intact_fame(truck)),
		"line": Tr.t(rv.taunt_key) if rv.taunt_key != "" else ""}


## Card of a grid entry online (humans and bots): name, paint and the destaque of the truck in the sim.
static func online(entry: Dictionary, truck: TruckSim, seed_: int) -> Dictionary:
	var i: int = int(entry["idx"])
	var bot: bool = bool(entry["bot"])
	return {"driver": String(entry.get("name", "")), "truck": Tr.t("intro.bot_truck" if bot else "intro.player_truck"),
		"crest": HUMAN_CRESTS[i % HUMAN_CRESTS.size()], "color": Color(String(entry.get("paint", "#e9eef5"))),
		"destaque": roundi(RaceRules.intact_fame(truck)),
		"line": Tr.t("intro.player_line.%d" % (posmod(seed_ + i * 7, PLAYER_LINES) + 1))}


## Caption city of the route (first place of the route) for "ÁREA DE DESCANSO · Yokohama".
static func place_of(route: RouteDef) -> String:
	if route == null or route.places.is_empty():
		return "Kanto"
	return String(route.places[0])
