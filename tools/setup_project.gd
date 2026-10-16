extends SceneTree
## Uso unico (P01): grava Input Map e autoloads em project.godot.
## godot --headless --path game -s res://../tools/setup_project.gd  (copiado para game/ ao rodar)

func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e

func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	return e

func _btn(b: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	return e

func _initialize() -> void:
	var actions := {
		"steer_left": [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)],
		"steer_right": [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)],
		"throttle": [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)],
		"brake": [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_TRIGGER_LEFT, 1.0)],
		"passing": [_key(KEY_SPACE), _btn(JOY_BUTTON_A)],
		"pause": [_key(KEY_ESCAPE), _btn(JOY_BUTTON_START)],
	}
	for a in actions:
		ProjectSettings.set_setting("input/" + a, {"deadzone": 0.2, "events": actions[a]})
	ProjectSettings.set_setting("autoload/GameState", "*res://scripts/autoload/game_state.gd")
	ProjectSettings.set_setting("autoload/Settings", "*res://scripts/autoload/settings.gd")
	ProjectSettings.set_setting("autoload/Net", "*res://scripts/autoload/net.gd")
	ProjectSettings.set_setting("autoload/AudioBus", "*res://scripts/autoload/audio_bus.gd")
	print("save: ", ProjectSettings.save())
	quit()
