extends TestCase
## Hora do dia: presets carregam, cada rota aponta para um preset que existe e o "dia" apaga farois e postes.


func test_presets_load() -> void:
	for tid in [&"night", &"dusk", &"day"]:
		var t: TimeOfDay = TimeOfDay.by_id(tid)
		check(t != null, "preset %s carrega" % tid)
		check_eq(t.id, tid, "id do preset %s" % tid)
	var day: TimeOfDay = TimeOfDay.by_id(&"day")
	check(not day.headlights and not day.lamps_on, "de dia farois e postes apagados")
	check_eq(day.window_energy, 0.0, "de dia janelas apagadas")
	check(TimeOfDay.by_id(&"night").stars > 0.0, "a noite tem estrelas")


func test_every_route_has_valid_time() -> void:
	for r in FreightMarket.all_routes():
		check(ResourceLoader.exists(TimeOfDay.DIR + String(r.time_of_day) + ".tres"), "rota %s usa preset existente" % r.id)
		var t: TimeOfDay = TimeOfDay.by_id(r.time_of_day)
		check_eq(r.night, t.headlights, "rota %s: musica noturna combina com farois acesos" % r.id)
