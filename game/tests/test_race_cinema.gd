extends TestCase
## Largada e chegada com clima (ATB-2): corte lateral de 1-2 s, clarao na saida do tunel, resultado depois do corte.


func test_cut_lasts_between_one_and_two_seconds() -> void:
	check(RaceCinema.START_CUT_S >= 1.0 and RaceCinema.START_CUT_S <= 2.0, "corte da largada de 1 a 2 s")
	check(RaceCinema.FINISH_CUT_S >= 1.0 and RaceCinema.FINISH_CUT_S <= 2.0, "corte da chegada de 1 a 2 s")
	check(RaceCinema.START_CUT_BEFORE < RaceCinema.START_CUT_S, "o corte da largada passa um pouco do 'larga'")


func test_cut_places_the_camera_beside_the_truck_and_ends() -> void:
	var cin := RaceCinema.new()
	var cam := Camera3D.new()
	var truck := Node3D.new()
	var root: Node = Engine.get_main_loop().root
	root.add_child(cam)
	root.add_child(truck)
	truck.position = Vector3(0, 0, -100)
	cin.start_cut("start", 1.0, 1.0)
	check(cin.active(), "corte ativo")
	check(cin.apply_cut(0.1, cam, truck), "durante o corte a camera e do corte")
	check(cam.position.x > 10.0, "camera do lado direito (x=%.1f)" % cam.position.x)
	check(cam.position.y > 3.0, "e alta o bastante para ver por cima das outras carretas")
	cin.start_cut("finish", 1.0, -1.0)
	cin.apply_cut(0.1, cam, truck)
	check(cam.position.x < -10.0, "lado esquerdo quando pedido")
	for n in 12:
		cin.apply_cut(0.1, cam, truck)
	check(not cin.active() and not cin.apply_cut(0.1, cam, truck), "acabou: devolve a camera normal")
	cam.free()
	truck.free()


func test_tunnel_flash_is_stronger_by_day_and_fades() -> void:
	var cin := RaceCinema.new()
	var holder := Node.new()
	cin.build(holder)
	cin.tunnel_flash(0.0)
	var night_peak: float = cin._flash_peak
	cin.tunnel_flash(1.0)
	check(cin._flash_peak > night_peak, "de dia o clarao e mais forte")
	cin.update_flash(0.01)
	var a0: float = cin._flash_rect.color.a
	check(a0 > 0.3, "logo apos a saida o clarao esta forte (%.2f)" % a0)
	for n in 20:
		cin.update_flash(0.05)
	check_near(cin._flash_rect.color.a, 0.0, 0.001, "some em menos de 1 s")
	holder.free()
