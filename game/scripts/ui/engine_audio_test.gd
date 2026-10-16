extends Control
## Cena de teste do som do motor (P51): sliders de RPM, acelerador, boost e dano; escolha de motor/turbo.
## Abra: godot --path game res://scenes/tools/engine_audio_test.tscn

var _audio: EngineAudio
var _rpm: float = 0.2
var _throttle: float = 0.5
var _boost: float = 0.0
var _health: float = 1.0
var _engine_set: String = "i6_std"
var _turbo: String = "turbo_none"
var _straight: bool = false
var _jake: bool = false


func _ready() -> void:
	theme = UiTheme.make()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UiTheme.NIGHT
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var v := VBoxContainer.new()
	v.position = Vector2(30, 20)
	v.custom_minimum_size = Vector2(700, 0)
	add_child(v)
	v.add_child(UiTheme.label("Teste do som do motor", 30, UiTheme.PINK))
	var row := HBoxContainer.new()
	v.add_child(row)
	for e in [["i6_std", "6 cil. padrão"], ["i6_tuned", "6 cil. preparado"], ["v8", "V8"]]:
		var b: Button = UiTheme.button(String(e[1]), Vector2(170, 44))
		b.pressed.connect(func() -> void:
			_engine_set = String(e[0])
			_rebuild())
		row.add_child(b)
	var row2 := HBoxContainer.new()
	v.add_child(row2)
	for t in [["turbo_none", "Sem turbo"], ["turbo_single", "Turbo simples"], ["turbo_twin", "Turbo duplo"]]:
		var b2: Button = UiTheme.button(String(t[1]), Vector2(170, 44))
		b2.pressed.connect(func() -> void:
			_turbo = String(t[0])
			_rebuild())
		row2.add_child(b2)
	var ex := CheckButton.new()
	ex.text = "Escape direto"
	ex.toggled.connect(func(on: bool) -> void:
		_straight = on
		_rebuild())
	v.add_child(ex)
	var jk := CheckButton.new()
	jk.text = "Freio-motor"
	jk.toggled.connect(func(on: bool) -> void:
		_jake = on
		_rebuild())
	v.add_child(jk)
	_slider(v, "RPM", 0.0, 1.0, _rpm, func(x: float) -> void: _rpm = x)
	_slider(v, "Acelerador", 0.0, 1.0, _throttle, func(x: float) -> void: _throttle = x)
	_slider(v, "Boost do turbo", 0.0, 1.0, _boost, func(x: float) -> void: _boost = x)
	_slider(v, "Saúde do motor", 0.0, 1.0, _health, func(x: float) -> void: _health = x)
	var pop: Button = UiTheme.button("PSSH (blow-off)", Vector2(220, 44))
	pop.pressed.connect(func() -> void: _audio.blowoff())
	v.add_child(pop)
	_rebuild()


func _slider(parent: Control, label: String, lo: float, hi: float, val: float, cb: Callable) -> void:
	parent.add_child(UiTheme.label(label, 16))
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.01
	s.value = val
	s.custom_minimum_size = Vector2(500, 24)
	s.value_changed.connect(cb)
	parent.add_child(s)


func _rebuild() -> void:
	if _audio != null:
		_audio.queue_free()
	_audio = EngineAudio.new()
	add_child(_audio)
	_audio.setup(_engine_set, _turbo, _straight, _jake)


func _process(delta: float) -> void:
	_audio.update(delta, _rpm, _throttle, _boost, _health, 20.0)
