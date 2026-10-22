extends TestCase
## T-189: quality Ultra (PC/Forward+) and colour grading by time of day.


func test_grade_moods() -> void:
	var grey := Color(0.45, 0.45, 0.45)
	var n: Color = ColorGrade.grade(grey, "night")
	var d: Color = ColorGrade.grade(grey, "day")
	check(n.b - n.r > d.b - d.r + 0.03, "night is bluer than day")
	var hi: Color = ColorGrade.grade(Color(0.85, 0.85, 0.85), "dusk")
	check(hi.r > hi.b + 0.05, "dusk highlights are orange")
	var gold: Color = ColorGrade.grade(Color(0.8, 0.8, 0.8), "dawn")
	check(gold.r > gold.b + 0.08 and gold.g > gold.b, "dawn highlights are golden")
	var dull := Color(0.5, 0.45, 0.4)
	var vivid: Color = ColorGrade.grade(dull, "day")
	check(vivid.r - vivid.b > dull.r - dull.b, "day is more saturated")


func test_grade_range() -> void:
	for look in ColorGrade.LOOKS:
		var k: Color = ColorGrade.grade(Color.BLACK, look)
		var w: Color = ColorGrade.grade(Color.WHITE, look)
		check(k.r < 0.04 and k.g < 0.04 and k.b < 0.04, "%s keeps black dark" % look)
		check(w.r > 0.9 and w.g > 0.9 and w.b > 0.8, "%s keeps white bright" % look)
		for c in [Color(1, 0, 0.6), Color(0, 1, 1), Color(0.2, 0.1, 0.9)]:
			var o: Color = ColorGrade.grade(c, look)
			check(o.r >= 0.0 and o.r <= 1.0 and o.g >= 0.0 and o.g <= 1.0 and o.b >= 0.0 and o.b <= 1.0, "%s in range" % look)
	check_eq(ColorGrade.look_of("nao_existe"), "day", "unknown time uses day")


func test_lut_cached() -> void:
	var a: ImageTexture3D = ColorGrade.lut("night")
	check_eq(a.get_width(), ColorGrade.SIZE, "LUT size")
	check_eq(a.get_depth(), ColorGrade.SIZE, "LUT depth")
	check(a == ColorGrade.lut("night"), "LUT is cached")


func test_tune_tod() -> void:
	var tod: TimeOfDay = TimeOfDay.by_id(&"night")
	check(UltraLook.tune_tod(tod, 1, false) == tod, "media without rain: same preset (phone unchanged)")
	var wet: TimeOfDay = UltraLook.tune_tod(tod, 1, true)
	check(wet != tod, "rain works on a copy")
	check(wet.road_roughness < tod.road_roughness, "rain: wetter road")
	check(wet.fog_density > tod.fog_density, "rain: more fog")
	check_near(TimeOfDay.by_id(&"night").road_roughness, tod.road_roughness, 0.0001, "preset untouched")
	check_eq(String(TimeOfDay.by_id(&"dawn").id), "dawn", "dawn preset exists")


func test_quality_clamp() -> void:
	check_eq(UltraLook.clamp_quality(9), UltraLook.max_quality(), "clamped to the max")
	check_eq(UltraLook.max_quality(), 3 if UltraLook.renderer() == "forward_plus" else 2, "Ultra only with Forward+")
	check(not UltraLook.active(2), "Alta is not Ultra")
	var env := Environment.new()
	UltraLook.apply_env(env, TimeOfDay.by_id(&"day"), 2)
	check(not env.sdfgi_enabled and not env.ssr_enabled and not env.volumetric_fog_enabled, "below Ultra nothing changes")
	check(UltraLook.intro_attributes(1) == null, "no depth of field below Ultra")


func test_viewport_table() -> void:
	var vp := SubViewport.new()
	UltraLook.apply_viewport(vp, 1)
	check_near(vp.scaling_3d_scale, 0.8, 0.001, "media renders at 80%")
	check_eq(vp.scaling_3d_mode, Viewport.SCALING_3D_MODE_BILINEAR, "media: bilinear")
	check_eq(vp.msaa_3d, Viewport.MSAA_2X, "media: MSAA 2x (T-195)")
	UltraLook.apply_viewport(vp, 2)
	check_eq(vp.msaa_3d, Viewport.MSAA_4X, "alta: MSAA 4x (T-195)")
	UltraLook.apply_viewport(vp, 0)
	check_eq(vp.msaa_3d, Viewport.MSAA_DISABLED, "baixa: no MSAA")
	if UltraLook.available():
		UltraLook.apply_viewport(vp, 3)
		check_eq(vp.scaling_3d_mode, Viewport.SCALING_3D_MODE_FSR2, "ultra: FSR2 native")
	vp.free()
