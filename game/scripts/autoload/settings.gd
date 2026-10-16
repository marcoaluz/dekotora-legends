extends Node
## Settings autoload: opcoes do jogador (controles, volumes, idioma). Salvas em user://settings.cfg.

const PATH := "user://settings.cfg"

var touch_scale: float = 1.0        # tamanho dos botoes de toque (0.7 .. 1.5)
var use_tilt: bool = false          # direcao por inclinacao (acelerometro)
var tilt_invert: bool = false
var music_volume: float = 0.8
var sfx_volume: float = 1.0
var language: String = "pt-BR"
var show_touch_controls: bool = false   # forca os botoes na tela (teste no PC)


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	touch_scale = clampf(float(cfg.get_value("controls", "touch_scale", touch_scale)), 0.7, 1.5)
	use_tilt = bool(cfg.get_value("controls", "use_tilt", use_tilt))
	tilt_invert = bool(cfg.get_value("controls", "tilt_invert", tilt_invert))
	music_volume = float(cfg.get_value("audio", "music_volume", music_volume))
	sfx_volume = float(cfg.get_value("audio", "sfx_volume", sfx_volume))
	language = String(cfg.get_value("general", "language", language))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("controls", "touch_scale", touch_scale)
	cfg.set_value("controls", "use_tilt", use_tilt)
	cfg.set_value("controls", "tilt_invert", tilt_invert)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("general", "language", language)
	cfg.save(PATH)


## Inclinacao do aparelho (paisagem) -> -1..+1. No Android o eixo y do acelerometro e o
## lado-a-lado quando o aparelho esta deitado; `tilt_invert` corrige se vier ao contrario.
func tilt_steer() -> float:
	if not use_tilt:
		return 0.0
	var v: float = clampf(Input.get_accelerometer().y / 4.0, -1.0, 1.0)
	if absf(v) < 0.08:
		return 0.0
	return -v if tilt_invert else v
