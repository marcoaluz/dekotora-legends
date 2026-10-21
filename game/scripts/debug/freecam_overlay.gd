class_name FreecamOverlay
extends Control
## Overlay of the explorer camera (T-181): stats in the corner (FPS, draw calls, visible objects, km of the camera,
## route, time of day), crosshair with the object under it (+ source .glb), toast, "go to km" field and the
## SAIR / KM / FOTO / HUD buttons. On touch screens it also owns the sticks (FreecamTouch).
## Texts from data/i18n/pt-BR.json ("freecam.*").

signal exit_pressed
signal km_pressed
signal shot_pressed
signal hud_pressed
signal km_submitted(km: float)

const TEXT_REFRESH_S: float = 0.1

var cam: Freecam
var touch: FreecamTouch              # null on PC
var _info: Label
var _aim: Label
var _toast: Label
var _help: Label
var _buttons: HBoxContainer
var _hud_btn: Button
var _km_box: PanelContainer
var _km_edit: LineEdit
var _km_error: Label
var _hud_on: bool = true
var _text_t: float = 0.0
var _toast_t: float = 0.0


func _ready() -> void:
	theme = UiTheme.make()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.box(Color(0, 0, 0, 0.55), Color(1, 1, 1, 0.12), 1, 6, 8))
	panel.position = Vector2(10, 10)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	_info = _label(15, UiTheme.TEXT)
	panel.add_child(_info)
	_aim = _label(16, UiTheme.GOLD)
	_aim.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aim.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_aim.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_aim.offset_left = -360
	_aim.offset_right = 360
	_aim.offset_top = 16
	_aim.offset_bottom = 80
	_aim.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_aim)
	_toast = _label(18, UiTheme.CYAN)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.offset_left = -440
	_toast.offset_right = 440
	_toast.offset_top = -74
	_toast.offset_bottom = -44
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_toast)
	_help = _label(14, UiTheme.TEXT_DIM)
	_help.text = Tr.t("freecam.help")
	_help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_help.offset_left = 12
	_help.offset_top = -30
	_help.offset_bottom = -8
	_help.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_help)
	_build_buttons()
	_build_km_box()
	if _touch_screen():
		touch = FreecamTouch.new()
		add_child(touch)
		move_child(touch, 0)                          # under the buttons
		_help.visible = false


func _label(size_: int, color: Color) -> Label:
	var l: Label = UiTheme.label("", size_, color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build_buttons() -> void:
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 6)
	_buttons.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_buttons.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_buttons.offset_right = -10
	_buttons.offset_top = 10
	add_child(_buttons)
	for b in [["freecam.btn_exit", exit_pressed], ["freecam.btn_km", km_pressed], ["freecam.btn_shot", shot_pressed],
			["freecam.btn_hud", hud_pressed]]:
		var btn: Button = UiTheme.button(Tr.t(String(b[0])), Vector2(74, 40))
		btn.add_theme_font_size_override("font_size", 15)
		btn.focus_mode = Control.FOCUS_NONE                # keyboard stays with the camera
		var sig: Signal = b[1]
		btn.pressed.connect(func() -> void: sig.emit())
		_buttons.add_child(btn)
		_hud_btn = btn


func _build_km_box() -> void:
	_km_box = PanelContainer.new()
	_km_box.add_theme_stylebox_override("panel", UiTheme.box(Color(0.05, 0.06, 0.11, 0.92), UiTheme.PINK, 1, 10, 14))
	_km_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_km_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_km_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_km_box.visible = false
	add_child(_km_box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_km_box.add_child(col)
	col.add_child(UiTheme.label(Tr.t("freecam.km_prompt"), 18))
	_km_edit = LineEdit.new()
	_km_edit.placeholder_text = Tr.t("freecam.km_placeholder")
	_km_edit.custom_minimum_size = Vector2(260, 44)
	_km_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL
	_km_edit.text_submitted.connect(_on_km_text)
	col.add_child(_km_edit)
	_km_error = UiTheme.label(Tr.t("freecam.km_hint"), 14, UiTheme.TEXT_DIM)
	col.add_child(_km_error)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	var go: Button = UiTheme.button(Tr.t("freecam.km_go"), Vector2(120, 42))
	go.pressed.connect(func() -> void: _on_km_text(_km_edit.text))
	row.add_child(go)
	var cancel: Button = UiTheme.button(Tr.t("freecam.km_cancel"), Vector2(120, 42))
	cancel.pressed.connect(close_km)
	row.add_child(cancel)


func _touch_screen() -> bool:
	# not DisplayServer.is_touchscreen_available(): the project emulates touch from the mouse, so it is true on PC too
	return OS.has_feature("mobile") or "--touch" in OS.get_cmdline_user_args() or bool(Settings.show_touch_controls)


func open_km() -> void:
	_km_box.visible = true
	_km_error.text = Tr.t("freecam.km_hint")
	_km_edit.text = ""
	_km_edit.grab_focus()


func close_km() -> void:
	if _km_box == null:
		return
	_km_box.visible = false
	_km_edit.release_focus()


func km_open() -> bool:
	return _km_box != null and _km_box.visible


func _on_km_text(text: String) -> void:
	var km: float = FreecamMath.parse_km(text)
	if is_nan(km):
		_km_error.text = Tr.t("freecam.km_invalid")
		return
	close_km()
	km_submitted.emit(km)


## H: everything but the HUD button (touch only, otherwise there is no way back) disappears.
func set_hud(on: bool) -> void:
	_hud_on = on
	for n in [_info.get_parent(), _aim, _help]:
		(n as CanvasItem).visible = on and (n != _help or touch == null)
	for b in _buttons.get_children():
		(b as Control).visible = on or (b == _hud_btn and touch != null)
	_buttons.visible = on or touch != null
	if touch != null:
		touch.visible = on
	queue_redraw()


func toast(text: String) -> void:
	_toast.text = text
	_toast_t = 3.0


## Called every frame by the camera with its current speed (m/s).
func refresh(speed_now: float) -> void:
	var dt: float = get_process_delta_time()
	if _toast_t > 0.0:
		_toast_t -= dt
		if _toast_t <= 0.0:
			_toast.text = ""
	_text_t += dt
	if _text_t < TEXT_REFRESH_S or cam == null or not _hud_on:
		return
	_text_t = 0.0
	var tr3: Vector3 = cam.cam_track()
	var lines: PackedStringArray = [
		Tr.t("freecam.title"),
		Tr.t("freecam.stats", [int(Engine.get_frames_per_second()), int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))]),
		Tr.t("freecam.where", [FreecamMath.format_km(tr3.x), _dec(tr3.y), _dec(tr3.z)]),
		Tr.t("freecam.route", [cam.route_name, cam.route_id]),
		Tr.t("freecam.time", [Tr.t("freecam.tod_" + cam.time_id) if cam.time_id != "" else "-"]),
		Tr.t("freecam.speed", [_dec(speed_now)]),
	]
	_info.text = "\n".join(lines)
	var p: Dictionary = cam.picked
	if p.is_empty():
		_aim.text = Tr.t("freecam.aim_none")
	else:
		var file: String = String(p.get("file", ""))
		var mat: String = String(p.get("material", ""))
		_aim.text = "%s%s · %s m\n%s" % [String(p["label"]), (" [%s]" % mat) if mat != "" else "", _dec(float(p["distance"])),
			file if file != "" else Tr.t("freecam.no_glb")]


func _dec(v: float) -> String:
	return ("%.1f" % v).replace(".", ",")


func _draw() -> void:
	if not _hud_on:
		return
	var c: Vector2 = size / 2.0
	var col := Color(1, 1, 1, 0.9)
	for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		draw_line(c + d * 4.0, c + d * 12.0, Color(0, 0, 0, 0.8), 4.0)
		draw_line(c + d * 4.0, c + d * 12.0, col, 2.0)
	draw_circle(c, 1.5, col)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
