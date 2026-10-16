extends TestCase
## Testes dos perfis no servidor (P64): um JSON por jogador, escrita atomica, sincronizacao por `rev`
## e compras/reparos validados pelas mesmas regras do jogo.

const DIR := "user://test_profiles/"


func _fresh_store() -> ProfileStore:
	var d := DirAccess.open("user://")
	if d != null and d.dir_exists("test_profiles"):
		var sub := DirAccess.open(DIR)
		for f in sub.get_files():
			sub.remove(f)
	return ProfileStore.new(DIR)


func test_new_player_gets_default_profile_file() -> void:
	var store: ProfileStore = _fresh_store()
	var gs: Node = store.get_profile("AAAA2222")
	check_eq(gs.money(), 50000, "dinheiro inicial")
	check(FileAccess.file_exists(DIR + "AAAA2222.json"), "um arquivo JSON por jogador")
	check_eq(String(gs.profile["player_code"]), "AAAA2222", "codigo gravado no perfil")
	store.release_all()


func test_profile_persists_across_store_instances() -> void:
	var store: ProfileStore = _fresh_store()
	var gs: Node = store.get_profile("BBBB3333")
	gs.profile["money"] = 77777
	gs.save_profile()
	store.release_all()
	var store2 := ProfileStore.new(DIR)
	check_eq(store2.get_profile("BBBB3333").money(), 77777, "dinheiro voltou do disco")
	store2.release_all()


func test_server_validates_purchases_with_same_rules() -> void:
	var store: ProfileStore = _fresh_store()
	var gs: Node = store.get_profile("CCCC4444")
	check(not gs.apply_action("buy_part", "fb_gold_wing"), "peca cara e bloqueada por Fama/dinheiro")
	check(gs.apply_action("buy_part", "visor_basic"), "compra permitida")
	check_eq(gs.money(), 45000, "preco debitado no servidor")
	check(gs.apply_action("install", "visor_basic"), "instalou")
	check(not gs.apply_action("buy_part", "nao_existe"), "peca inexistente recusada")
	gs.profile["owned"]["fb_basic"]["dur"] = 40.0
	check(gs.apply_action("repair_part", "fb_basic"), "reparo online")
	check_eq(gs.money(), 43000, "reparo cobrado: 2.000")
	store.release_all()


func test_rev_based_sync_between_offline_and_server() -> void:
	var store: ProfileStore = _fresh_store()
	var server_gs: Node = store.get_profile("DDDD5555")
	var server_rev: int = int(server_gs.profile["rev"])
	# cliente jogou offline: perfil com rev MAIOR e mais dinheiro -> servidor adota
	var offline: Dictionary = server_gs.profile.duplicate(true)
	offline["money"] = 123456
	offline["rev"] = server_rev + 5
	var after: Node = store.sync_from_client("DDDD5555", offline)
	check_eq(after.money(), 123456, "perfil offline mais novo vence")
	# cliente com rev menor (copia antiga em outro aparelho) -> servidor mantem o seu
	var stale: Dictionary = after.profile.duplicate(true)
	stale["money"] = 1
	stale["rev"] = 0
	var kept: Node = store.sync_from_client("DDDD5555", stale)
	check_eq(kept.money(), 123456, "perfil antigo nao sobrescreve o do servidor")
	# perfil invalido e ignorado
	var bad: Dictionary = {"money": 9999999999, "rev": 9999}
	var still: Node = store.sync_from_client("DDDD5555", bad)
	check_eq(still.money(), 123456, "perfil mal formado e ignorado")
	store.release_all()


func test_same_player_code_gives_same_garage_on_two_devices() -> void:
	var store: ProfileStore = _fresh_store()
	var gs: Node = store.get_profile("EEEE6666")
	gs.profile["money"] = 200000
	gs.profile["fame"] = 100
	gs.save_profile()
	check(gs.apply_action("buy_part", "skirt_chrome"), "comprou no celular")
	check(gs.apply_action("install", "skirt_chrome"), "instalou no celular")
	# "PC": um aparelho novo, perfil vazio (rev 0), mesmo codigo
	var fresh_pc := {"money": 50000, "fame": 0, "owned": {}, "installed": {}, "engine": "eng_i6_std", "turbo": "turbo_none", "exhaust": "exh_std", "systems": {"engine": 100.0, "steering": 100.0}, "rev": 0}
	var served: Node = store.sync_from_client("EEEE6666", fresh_pc)
	check_eq(served.installed_id("side_skirts"), "skirt_chrome", "o PC recebe a mesma garagem")
	check_eq(served.money(), 200000 - gs.part("skirt_chrome").price, "mesmo dinheiro")
	store.release_all()


func test_code_cleaning() -> void:
	var store: ProfileStore = _fresh_store()
	check_eq(store.clean_code("ab/c-12"), "ABC12", "remove caracteres invalidos")
	check_eq(store.clean_code("../../etc/passwd").contains("/"), false, "sem caminhos relativos")
	store.release_all()
