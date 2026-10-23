class_name HudDemo
extends RefCounted
## T-202 debug / screenshots only (`-- --hud-demo`, offline): the player's truck starts damaged (front critical,
## left side damaged, rear destroyed, cargo shaken) and the left signal stays on, so one print shows the status
## segments, the detail popup and the blinking arrow. Never used in a normal race.


static func wanted(args: PackedStringArray) -> bool:
	return "--hud-demo" in args


static func damage(t: TruckSim) -> void:
	var share: Dictionary = {"front": 0.22, "left": 0.5, "rear": 0.0}
	for p in t.loadout:
		for z in share:
			if z in p["zones"]:
				p["dur"] = float(p["max"]) * float(share[z])
				p["broken"] = float(share[z]) <= 0.0
	t.systems["engine"] = 28.0                      # zones without parts show their system
	t.systems["steering"] = 55.0
	t.systems["cargo"] = 70.0
	t.cargo_penalty = TruckSim.MAX_CARGO_LOSS * 0.25
	t.refresh_damage_effects()


## Called every frame: keeps the left signal on (the 2nd tap window never closes).
static func hold_signal(t: TruckSim) -> void:
	t.signal_dir = -1
	t.signal_time = TruckSim.LANE_SIGNAL_WINDOW
