class_name RaceHud
extends Control
## HUD of the race (T-202: Art Truck Battle feel, our own drawing). Layout in HUD units (480x270 on a 16:9 PC; the
## CanvasLayer scales 2x), decided by HudLayout:
##  - left edge: radar strip (RadarStrip); top left: POSITION + the camera icon (T-198);
##  - top right: 走行時間 / 残り時間 clocks + route progress with numbered markers + destination (RouteClocks);
##  - bottom right (phone: between the thumbs): analog gauge (SpeedGauge), green arrows + lamps (IndicatorStrip),
##    5 status segments with tap/mouse detail (DamageSegments);
##  - middle: countdown, banners, cargo notice before the start, curve warning; EventHud is placed by this layout.
## Only reads the simulation (TruckSim / RaceSim): the same online and offline. Texts from game/data/i18n.

var sim: RaceSim
var player: int = 0
var countdown: float = 0.0
var banner: String = ""
var banner_time: float = 0.0
var rival_idx: int = -1                  # route rival (gold marker / radar dot)
var cargo_notice: Array[String] = []     # cargo warning before the start (lines)
var amber: float = 0.0                   # gauge backlight: 0 day .. 1 night / tunnel (race scene)
var tunnel: float = 0.0                  # inside a tunnel 0..1 (radar turns amber)
var headlights: bool = false             # headlight lamp (race scene: night or tunnel)
var touch_layout: bool = false           # phone layout (touch buttons on screen)
var cam_button: Control                  # T-198 camera icon (placed by the layout)
var mirror: Control                      # T-198 rear mirror (top centre)
var event_hud: EventHud                  # T-139 warnings (placed by the layout)
var layout := HudLayout.new()

var gauge: SpeedGauge
var strip: IndicatorStrip
var segments: DamageSegments
var clocks: RouteClocks
var radar: RadarStrip
var _scale_override: float = -1.0
var _safe_override: Rect2 = Rect2(-1, -1, -1, -1)
var _layout_key: String = ""


func bind(sim_: RaceSim, player_: int) -> void:
	sim = sim_
	player = player_
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	size = Vector2(480, 270)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--hud-scale="):          # screenshots: phone scale without a phone
			_scale_override = float(a.substr(12))
		elif a.begins_with("--safe-area="):        # screenshots: notch insets in HUD units "L,T,R,B"
			var p: PackedStringArray = a.substr(12).split(",")
			if p.size() == 4:
				_safe_override = Rect2(float(p[0]), float(p[1]), float(p[2]), float(p[3]))
	radar = RadarStrip.new()
	clocks = RouteClocks.new()
	gauge = SpeedGauge.new()
	strip = IndicatorStrip.new()
	segments = DamageSegments.new()
	for c in [radar, clocks, strip, gauge, segments]:
		add_child(c)
	for c in [radar, clocks]:
		c.sim = sim
		c.player = player
	segments.truck = sim.trucks[player] if player < sim.trucks.size() else null


func show_banner(text: String, seconds: float = 1.6) -> void:
	banner = text
	banner_time = seconds


func _process(delta: float) -> void:
	var want: Vector2 = get_viewport_rect().size / 2.0   # T-138: long screen = wider HUD (corners at the edges)
	if size != want:
		size = want
	banner_time = maxf(banner_time - delta, 0.0)
	_apply_layout()
	if sim != null and player < sim.trucks.size():
		_feed(sim.trucks[player])
	queue_redraw()


## Recomputes the layout when the screen, the touch mode or the safe area change.
func _apply_layout() -> void:
	var ins: Rect2 = _insets()
	var sc: float = _wanted_scale()
	var key: String = "%s|%s|%s|%.2f|%.2f" % [size, ins, touch_layout, sc, Settings.touch_scale]
	if key == _layout_key:
		return
	_layout_key = key
	layout.size = size
	layout.inset_l = ins.position.x
	layout.inset_t = ins.position.y
	layout.inset_r = ins.size.x
	layout.inset_b = ins.size.y
	layout.touch = touch_layout
	layout.want_scale = sc
	layout.buttons = TouchControls.button_layout(size, Settings.touch_scale) if touch_layout else {}
	layout.compute()
	_place(clocks, layout.clocks_at, layout.clocks_s)
	_place(gauge, layout.gauge_at, layout.cluster_s)
	_place(strip, layout.strip_at, layout.cluster_s)
	_place(segments, layout.seg_at, layout.cluster_s)
	radar.position = layout.radar.position
	radar.size = layout.radar.size
	gauge.fancy = not touch_layout or Settings.quality >= 2
	if cam_button != null:
		_place(cam_button, layout.cam_at, layout.s)
	if mirror != null:
		mirror.position.y = layout.mirror_top
	if event_hud != null:
		event_hud.alert_cx = layout.event_cx
		event_hud.alert_top = layout.event_top
		event_hud.refused_at = layout.refused_at


static func _place(c: Control, at: Vector2, s: float) -> void:
	c.position = at.round()
	c.scale = Vector2(s, s)


func _wanted_scale() -> float:
	if _scale_override > 0.0:
		return _scale_override
	var scr: Vector2i = DisplayServer.screen_get_size()
	return HudLayout.scale_for(touch_layout, float(mini(scr.x, scr.y)), float(DisplayServer.screen_get_dpi()))


## Safe area (notch) in HUD units as Rect2(left, top, right, bottom). Only on phones: on a PC the "safe area" is
## the desktop work area, unrelated to the window.
func _insets() -> Rect2:
	if _safe_override.position.x >= 0.0:
		return _safe_override
	if not OS.has_feature("mobile"):
		return Rect2()
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var scr: Vector2i = DisplayServer.window_get_size()
	if safe.size.x <= 0 or scr.x <= 0:
		return Rect2()
	var k: float = size.x / float(scr.x)
	return Rect2(maxf(safe.position.x, 0) * k, maxf(safe.position.y, 0) * k,
			maxf(scr.x - safe.end.x, 0) * k, maxf(scr.y - safe.end.y, 0) * k)


## Copies the truck state into the components (they only draw).
func _feed(t: TruckSim) -> void:
	var racing: bool = countdown <= 0.0
	gauge.target_kmh = t.speed * 3.6
	gauge.speed_ms = t.speed
	gauge.rpm_frac = clampf((t.rpm - EngineModel.IDLE_RPM) / maxf(t.engine.redline_rpm - EngineModel.IDLE_RPM, 1.0), 0.0, 1.0)
	gauge.gear = t.gear
	gauge.amber = amber
	gauge.boost = t.boost
	gauge.passing_charge = t.passing_charge
	gauge.passing_active = t.passing_active
	gauge.draft = t.draft
	gauge.jolted = t.jolted()
	gauge.curve_safe_kmh = -1.0
	if racing and sim.track != null and t.curve_warning(sim.track) > 0.0:
		gauge.curve_safe_kmh = _curve_ahead_safe_kmh(t)
	var lim: float = sim.track.events.limit_at(t.z, t.z + t.length + 200.0) if sim.track != null else INF
	gauge.limit_kmh = -1.0 if is_inf(lim) else lim * 3.6
	strip.signal_dir = t.signal_dir
	strip.headlights = headlights
	strip.hazard = HudStatus.hazard(t, sim.time, racing)
	strip.horn = t.horn
	strip.brake_hard = t.hard_braking
	strip.brake_held = t.brake_held
	strip.lane = t.lane
	for i in 5:
		strip.blocked[i] = sim.track != null and Lanes.is_road_lane(i) \
				and sim.track.events.lane_blocked_between(i, t.z, t.z + t.length + 220.0)
	segments.truck = t
	clocks.rival = rival_idx
	radar.rival = rival_idx
	radar.tunnel = tunnel


## Safe speed (km/h) of the tightest curve within the warning look-ahead.
func _curve_ahead_safe_kmh(t: TruckSim) -> float:
	var worst: float = INF
	var d: float = 0.0
	while d <= t.speed * CurveGrip.WARN_LOOK_S:
		worst = minf(worst, CurveGrip.safe_speed(sim.track.curve_at(t.z + t.length + d), t.grip()))
		d += 10.0
	return worst * 3.6


func _draw() -> void:
	if sim == null or sim.trucks.is_empty():
		return
	var t: TruckSim = sim.trucks[player]
	var w: float = size.x
	_draw_position(t)
	if Settings.show_fps:
		var fp: Vector2 = layout.pos_at + Vector2(HudLayout.POS.x * layout.s + 5.0, 9.0)   # right of POSITION (T-202)
		HudStyle.lbl(self, fp, "FPS %d" % Engine.get_frames_per_second(), 8, Color(1, 1, 1, 0.6))
	if countdown > 0.0:
		HudStyle.num(self, Vector2(0, size.y * 0.47), "%d" % int(ceil(countdown)), 56, HudStyle.GOLD, HORIZONTAL_ALIGNMENT_CENTER, w)
		HudStyle.num(self, Vector2(0, size.y * 0.57), Tr.t("hud.lane_hint"), 11, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_CENTER, w)
		_draw_cargo_notice(w)
	elif banner_time > 0.0:
		HudStyle.num(self, Vector2(0, size.y * 0.36), banner, 26, HudStyle.PINK, HORIZONTAL_ALIGNMENT_CENTER, w)
	else:
		_draw_curve_warning(t, w * 0.5, layout.curve_y)


func _draw_position(t: TruckSim) -> void:
	var pos: int = 1
	for k in sim.trucks.size():
		if k != player and sim.trucks[k].z > t.z:
			pos += 1
	var s: float = layout.s
	draw_set_transform(layout.pos_at, 0.0, Vector2(s, s))
	HudStyle.panel(self, Rect2(Vector2.ZERO, HudLayout.POS), HudStyle.PINK)
	HudStyle.lbl(self, Vector2(8, 11), Tr.t("hud.position"), 7)
	HudStyle.num(self, Vector2(8, 33), "%d" % pos, 26, HudStyle.GOLD)
	HudStyle.num(self, Vector2(26, 33), "/ %d" % sim.trucks.size(), 12, Color.WHITE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Cargo warning before the start: name, weight and what it changes (fragile / heavy / perishable).
func _draw_cargo_notice(w: float) -> void:
	if cargo_notice.is_empty():
		return
	var h: float = 14.0 + 13.0 * cargo_notice.size()
	var r := Rect2(w * 0.5 - HudLayout.NOTICE_W * 0.5, layout.notice_y, HudLayout.NOTICE_W, h)
	HudStyle.panel(self, r, HudStyle.GOLD)
	for i in cargo_notice.size():
		HudStyle.num(self, Vector2(r.position.x, r.position.y + 15.0 + 13.0 * i), cargo_notice[i], 11 if i == 0 else 9,
				HudStyle.GOLD if i == 0 else Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


## Curve warning (T-132): yellow "CURVA! ALIVIE" when the speed is over the limit of the curve ahead (the amber
## wedge on the gauge shows that limit); red blinking "DERRAPANDO!" when the truck lost the lane (over +30%).
func _draw_curve_warning(t: TruckSim, cx: float, y: float) -> void:
	var warn: float = t.curve_warning(sim.track)
	if not t.escaping and warn <= 0.0:
		return
	var blink: bool = int(Time.get_ticks_msec() / 140) % 2 == 0
	var col: Color = (HudStyle.BAD_COL if blink else Color.WHITE) if t.escaping else Color(HudStyle.WARN_COL, 0.55 + 0.45 * warn)
	var text: String = Tr.t("hud.curve_escape") if t.escaping else Tr.t("hud.curve_warn")
	var r := Rect2(cx - 60, y, 120, 15)
	HudStyle.panel(self, r, col)
	HudStyle.num(self, Vector2(r.position.x, r.position.y + 12), text, 11, col, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
