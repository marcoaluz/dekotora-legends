extends Node
## AudioBus (autoload): barramentos (Music / SFX / Engine / UI), carregamento de sons com loop,
## musica por tela com troca suave e efeitos pontuais. Volumes vem de Settings (Opcoes).
## Os arquivos ficam em game/assets/audio/ (gerados por tools/gen_audio.py, MP3).

const ROOT := "res://assets/audio/"
const FOLDERS: Array[String] = ["engines/", "sfx/truck/", "sfx/crash/", "sfx/ambient/", "sfx/ui/", "sfx/net/", "music/"]
const LOOP_HINTS: Array[String] = ["_loop", "_idle", "_low", "_mid", "_high", "_whine", "_layer", "_rattle", "jake_brake", "engine_damaged"]

var _streams: Dictionary = {}
var _music: AudioStreamPlayer
var _music_name: String = ""
var _sfx_pool: Array[AudioStreamPlayer] = []
var _ui_pool: Array[AudioStreamPlayer] = []
var _missing_warned: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_pool.append(p)
	for i in 3:
		var u := AudioStreamPlayer.new()
		u.bus = "UI"
		add_child(u)
		_ui_pool.append(u)
	apply_settings()


func _setup_buses() -> void:
	for name in ["Music", "SFX", "Engine", "UI"]:
		if AudioServer.get_bus_index(name) < 0:
			AudioServer.add_bus()
			var idx: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, name)
			AudioServer.set_bus_send(idx, "Master")


func apply_settings() -> void:
	var s: Node = get_node_or_null("/root/Settings")
	if s == null:
		return
	_set_bus("Music", float(s.music_volume))
	_set_bus("SFX", float(s.sfx_volume))
	_set_bus("Engine", float(s.sfx_volume))
	_set_bus("UI", float(s.sfx_volume))


func _set_bus(name: String, linear: float) -> void:
	var idx: int = AudioServer.get_bus_index(name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
		AudioServer.set_bus_mute(idx, linear <= 0.001)


## Carrega um som pelo nome (sem extensao) em qualquer pasta de audio. Loops sao ligados pelo nome.
func stream(name: String) -> AudioStream:
	if _streams.has(name):
		return _streams[name]
	var found: AudioStream = null
	for folder in FOLDERS:
		for ext in [".mp3", ".ogg", ".wav"]:
			var path: String = ROOT + folder + name + ext
			if ResourceLoader.exists(path):
				found = load(path) as AudioStream
				break
		if found != null:
			break
	if found == null:
		if not _missing_warned.has(name):
			_missing_warned[name] = true
			push_warning("AudioBus: som nao encontrado: " + name)
	else:
		var looping: bool = name.begins_with("music_") or _is_music(name)
		for h in LOOP_HINTS:
			if name.contains(h):
				looping = true
		if found is AudioStreamMP3:
			(found as AudioStreamMP3).loop = looping
		elif found is AudioStreamOggVorbis:
			(found as AudioStreamOggVorbis).loop = looping
	_streams[name] = found
	return found


func _is_music(name: String) -> bool:
	return ResourceLoader.exists(ROOT + "music/" + name + ".mp3") and not name.begins_with("results_")


func play_sfx(name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var s: AudioStream = stream(name)
	if s == null:
		return
	for p in _sfx_pool:
		if not p.playing:
			p.stream = s
			p.volume_db = volume_db
			p.pitch_scale = pitch
			p.play()
			return
	_sfx_pool[0].stream = s       # sem player livre: reaproveita o primeiro
	_sfx_pool[0].volume_db = volume_db
	_sfx_pool[0].pitch_scale = pitch
	_sfx_pool[0].play()


func play_ui(name: String) -> void:
	var s: AudioStream = stream(name)
	if s == null:
		return
	for p in _ui_pool:
		if not p.playing:
			p.stream = s
			p.play()
			return


## Musica de fundo com troca suave. `name` = arquivo em music/ (sem extensao).
func play_music(name: String, fade: float = 0.8) -> void:
	if name == _music_name and _music.playing:
		return
	_music_name = name
	var s: AudioStream = stream(name)
	if s == null:
		return
	var tw := create_tween()
	if _music.playing:
		tw.tween_property(_music, "volume_db", -40.0, fade * 0.5)
	tw.tween_callback(func() -> void:
		_music.stream = s
		_music.volume_db = -40.0
		_music.play())
	tw.tween_property(_music, "volume_db", -4.0, fade)


func stop_music(fade: float = 0.6) -> void:
	_music_name = ""
	if not _music.playing:
		return
	var tw := create_tween()
	tw.tween_property(_music, "volume_db", -40.0, fade)
	tw.tween_callback(_music.stop)


## Jingle curto (vitoria/derrota): para a musica e toca uma vez.
func play_jingle(name: String) -> void:
	stop_music(0.3)
	play_sfx(name, -2.0)
