class_name AtmosTune
extends RefCounted
## T-188: light and air of the new scenery, applied on a COPY of the time-of-day preset (data/time/*.tres stay as
## they were; --t188=off uses them untouched).
## - aerial perspective: the fog takes the colour of the horizon and is a bit denser by day, so what is far gets
##   lighter and bluer (mountains in layers read near -> far);
## - day: deeper blue zenith, warm hazy horizon (no more "washed" sky), clouds with volume;
## - night: bluish MOONLIGHT and a horizon lit by the city (sodium glow) so the hills stand out as silhouettes; the
##   ground is dark blue-green instead of black.

static func tune(tod: TimeOfDay) -> TimeOfDay:
	if tod == null or not ScenicZone.enabled():
		return tod
	var t: TimeOfDay = tod.duplicate() as TimeOfDay
	match String(t.id):
		"day":
			t.sky_top = Color("#2563c4")
			t.sky_horizon = Color("#b4c9de")
			t.horizon_glow = Color("#e4e2d6")
			t.glow_falloff = 9.0
			t.cloud_color = Color("#fbfbf6")
			t.fog_color = Color("#b3c4d6")
			t.fog_density = 0.00062
			t.saturation = 1.08
			t.contrast = 1.06
			t.land_color = Color("#3c4c2a")
			t.mountain_color = Color("#56627a")
		"dawn":                                          # T-189: preset only for --time=dawn (no route uses it yet)
			t.fog_density = 0.0011
		"dusk":
			t.fog_color = t.sky_horizon.lerp(t.horizon_glow, 0.3).darkened(0.25)
			t.fog_density = 0.0016
			t.clouds = 0.7
			t.land_color = Color("#1a1620")
		_:
			t.sky_top = Color("#03050d")
			t.sky_horizon = Color("#1a2346")
			t.sky_ground = Color("#05070d")
			t.horizon_glow = Color("#6a3c1c")            # sodium glow of the city on the horizon
			t.glow_falloff = 7.0
			t.disk_color = Color("#e4ebff")              # moon
			t.disk_energy = 2.4
			t.disk_size_deg = 2.2
			t.halo = 0.35
			t.light_color = Color("#a6b8ff")             # bluish moonlight
			t.light_energy = 0.85
			t.light_rotation = Vector3(-34, 32, 0)
			t.ambient_energy = 1.25
			t.fog_color = Color("#1c2446")
			t.fog_density = 0.0015
			t.exposure = 1.1
			t.contrast = 1.12
			t.land_color = Color("#0d161c")
			t.mountain_color = Color("#2a3158")
	return t
