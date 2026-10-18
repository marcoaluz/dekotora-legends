class_name ProfileStore
extends RefCounted
## Perfis dos jogadores no servidor: um arquivo JSON por codigo de jogador em user://profiles/,
## escrita atomica (arquivo temporario + renomear). Cada perfil e "um GameState" sem estar na arvore,
## entao compras, reparos e resultados usam exatamente as mesmas regras do jogo local.
## (O Godot nao traz SQLite; para poucos amigos JSON basta. Ver docs/DECISOES.md.)

const GAME_STATE_SCRIPT := preload("res://scripts/autoload/game_state.gd")

var dir: String = "user://profiles/"
var _cache: Dictionary = {}               # codigo -> instancia de GameState


func _init(dir_: String = "user://profiles/") -> void:
	dir = dir_
	DirAccess.make_dir_recursive_absolute(dir)


func clean_code(code: String) -> String:
	var out: String = ""
	for ch in code.to_upper():
		if Protocol.ROOM_CODE_ALPHABET.contains(ch) or ch in "01OI":
			out += ch
	return out.substr(0, 12)


func path_for(code: String) -> String:
	return "%s%s.json" % [dir, code]


func has_profile(code: String) -> bool:
	return _cache.has(code) or FileAccess.file_exists(path_for(code))


## Devolve o GameState (perfil) do codigo; cria um perfil novo se nao existir.
func get_profile(code: String) -> Node:
	code = clean_code(code)
	if _cache.has(code):
		return _cache[code]
	var gs: Node = GAME_STATE_SCRIPT.new()
	gs.save_path = path_for(code)
	if FileAccess.file_exists(gs.save_path):
		gs.load_profile()
	else:
		gs.new_profile()
		gs.profile["player_code"] = code
		gs.save_profile()
	_cache[code] = gs
	return gs


## Sincronizacao ao conectar: se o perfil do cliente tem `rev` maior (jogou offline depois da ultima
## sincronizacao), o servidor adota o dele; senao o servidor manda o seu. Devolve o perfil vencedor.
func sync_from_client(code: String, client_profile: Dictionary) -> Node:
	var gs: Node = get_profile(code)
	if _looks_valid(client_profile) and int(client_profile.get("rev", 0)) > int(gs.profile.get("rev", 0)):
		client_profile["player_code"] = code
		gs.profile = client_profile
		gs.migrate_profile()                     # cliente antigo pode mandar uma cabine retirada (T-129)
		gs.save_profile()
	return gs


func _looks_valid(p: Dictionary) -> bool:
	for k in ["money", "fame", "owned", "installed", "engine", "turbo", "exhaust", "systems"]:
		if not p.has(k):
			return false
	return int(p["money"]) >= 0 and int(p["money"]) < 100000000


func release(code: String) -> void:
	if _cache.has(code):
		(_cache[code] as Node).free()
		_cache.erase(code)


func release_all() -> void:
	for c in _cache.keys():
		release(c)
