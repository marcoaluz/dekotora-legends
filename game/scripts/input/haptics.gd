class_name Haptics
extends RefCounted
## T-219: vibracao do celular num lugar so. Respeita Opcoes > Controles > "Vibracao do celular" (Settings.haptics)
## e a forca do TruckFeel (haptic_strength multiplica a duracao, haptic_amplitude e a forca do motor).
## No PC o Input.vibrate_handheld nao faz nada.

static var last_ms: int = 0        # ultima duracao pedida (testes)


## Duracao final (ms) de um pulso de `ms` com estas opcoes; 0 = nao vibra.
static func duration(ms: float, enabled: bool, feel: TruckFeel) -> int:
	if not enabled or ms <= 0.0:
		return 0
	return clampi(roundi(ms * feel.haptic_strength), 0, 600)


static func pulse(ms: float) -> void:
	var s: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Settings")
	var on: bool = s == null or bool(s.get("haptics"))
	var feel: TruckFeel = TruckFeel.current()
	var d: int = duration(ms, on, feel)
	last_ms = d
	if d > 0:
		Input.vibrate_handheld(d, feel.haptic_amplitude)
