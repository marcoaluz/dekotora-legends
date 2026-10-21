extends Node
## Settings autoload: opcoes do jogador (controles, volumes, idioma). Salvas em user://settings.cfg.

const PATH := "user://settings.cfg"

var touch_scale: float = 1.0        # tamanho dos botoes de toque (0.7 .. 1.5)
var use_tilt: bool = false          # direcao por inclinacao (acelerometro)
var tilt_invert: bool = false
var music_volume: float = 0.8
var sfx_volume: float = 1.0
var language: String = "pt-BR"
var player_name: String = "Jogador"
var server_address: String = "127.0.0.1:24600"   # IP:porta do servidor (campo manual de depuracao)
var show_touch_controls: bool = false   # forca os botoes na tela (teste no PC)
var quality: int = 2                    # 0 baixa, 1 media, 2 alta (celular comeca em media)
var show_fps: bool = false
var fx_speed: bool = true               # linhas de velocidade, tremor, FOV e clarao do Passing
var fx_reflections: bool = true         # reflexo falso das luzes no asfalto (noite/fim de tarde)
var fx_trails: bool = true              # rastro das lanternas traseiras
var fx_rain: bool = false               # chuva (opcional)
var fx_impact: bool = true              # faiscas, pedacos de cromo, chacoalhada e fumaca/marcas dos pneus (T-141/T-144)
var menu_bg: String = "a"               # fundo da tela inicial: "a" posto a noite, "b" rodovia (T-138; MenuBackdrop)
var explorer_mode: bool = false         # T-181: camera livre (F1 / pausa) tambem fora da build de debug


func _ready() -> void:
	if OS.has_feature("mobile"):
		quality = 1
	load_settings()
	for a in OS.get_cmdline_user_args():          # depuracao: --quality=0|1|2 (nao grava)
		if a.begins_with("--quality="):
			quality = clampi(int(a.substr(10)), 0, 2)
		elif a == "--no-impact-fx":                   # depuracao: mede o custo das faiscas/fumaca (nao grava)
			fx_impact = false


func load_settings(path: String = PATH) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	touch_scale = clampf(float(cfg.get_value("controls", "touch_scale", touch_scale)), 0.7, 1.5)
	use_tilt = bool(cfg.get_value("controls", "use_tilt", use_tilt))
	tilt_invert = bool(cfg.get_value("controls", "tilt_invert", tilt_invert))
	music_volume = float(cfg.get_value("audio", "music_volume", music_volume))
	sfx_volume = float(cfg.get_value("audio", "sfx_volume", sfx_volume))
	language = String(cfg.get_value("general", "language", language))
	player_name = String(cfg.get_value("net", "player_name", player_name))
	server_address = String(cfg.get_value("net", "server_address", server_address))
	quality = clampi(int(cfg.get_value("graphics", "quality", quality)), 0, 2)
	show_fps = bool(cfg.get_value("graphics", "show_fps", show_fps))
	fx_speed = bool(cfg.get_value("graphics", "fx_speed", fx_speed))
	fx_reflections = bool(cfg.get_value("graphics", "fx_reflections", fx_reflections))
	fx_trails = bool(cfg.get_value("graphics", "fx_trails", fx_trails))
	fx_rain = bool(cfg.get_value("graphics", "fx_rain", fx_rain))
	fx_impact = bool(cfg.get_value("graphics", "fx_impact", fx_impact))
	menu_bg = String(cfg.get_value("graphics", "menu_bg", menu_bg))
	explorer_mode = bool(cfg.get_value("advanced", "explorer_mode", explorer_mode))


func save_settings(path: String = PATH) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("controls", "touch_scale", touch_scale)
	cfg.set_value("controls", "use_tilt", use_tilt)
	cfg.set_value("controls", "tilt_invert", tilt_invert)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("general", "language", language)
	cfg.set_value("net", "player_name", player_name)
	cfg.set_value("net", "server_address", server_address)
	cfg.set_value("graphics", "quality", quality)
	cfg.set_value("graphics", "show_fps", show_fps)
	cfg.set_value("graphics", "fx_speed", fx_speed)
	cfg.set_value("graphics", "fx_reflections", fx_reflections)
	cfg.set_value("graphics", "fx_trails", fx_trails)
	cfg.set_value("graphics", "fx_rain", fx_rain)
	cfg.set_value("graphics", "fx_impact", fx_impact)
	cfg.set_value("graphics", "menu_bg", menu_bg)
	cfg.set_value("advanced", "explorer_mode", explorer_mode)
	cfg.save(path)


## Inclinacao do aparelho (paisagem) -> -1..+1. No Android o eixo y do acelerometro e o
## lado-a-lado quando o aparelho esta deitado; `tilt_invert` corrige se vier ao contrario.
func tilt_steer() -> float:
	if not use_tilt:
		return 0.0
	var v: float = clampf(Input.get_accelerometer().y / 4.0, -1.0, 1.0)
	if absf(v) < 0.08:
		return 0.0
	return -v if tilt_invert else v
