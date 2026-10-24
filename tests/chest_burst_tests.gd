extends RefCounted
## Explosão atrás do baú da fase: nasce na abertura (depois do tremor), fica atrás da imagem
## do baú e centrada nela, some sozinha sem esperar os itens, e pular, fechar, abrir outro baú
## ou começar outra partida apagam a explosão sem deixar nós sobrando.
## Chamado por tests/integration_tests.gd, que passa o nó da cena e o _check.

const REWARD := {"kind": "weapon", "title": "Katana", "icon": ""}


func run(host: Node, check: Callable) -> void:
	var hud := Hud.new()
	host.add_child(hud)
	await host.get_tree().process_frame
	var image := hud.get("_chest_image") as TextureRect
	var burst := hud.get("_chest_burst") as ChestBurst
	check.call(burst != null and burst.get_parent() == image, "explosão é filha da imagem do baú")
	check.call(burst.show_behind_parent, "explosão desenha atrás do baú")
	check.call(burst.mouse_filter == Control.MOUSE_FILTER_IGNORE, "explosão não pega toques")
	check.call(int(burst.get("_frames")) == 9, "folha da explosão recortada em 9 quadros de 40 px")
	check.call(not hud.chest_burst_active(), "sem baú, sem explosão")

	var rewards: Array[Dictionary] = [REWARD, REWARD, REWARD]
	hud.show_chest(rewards)
	await host.get_tree().process_frame
	check.call(hud.chest_animating() and not hud.chest_burst_active(), "tremor do baú ainda sem explosão")
	check.call(await _wait(host, hud.chest_burst_active, 3.0), "baú abre com explosão atrás")
	await host.get_tree().process_frame
	check.call(is_equal_approx(image.size.x, 48.0), "imagem do baú com 48 px (pivô no centro)")
	var center := image.get_global_rect().get_center()
	check.call(burst.get_global_transform().origin.distance_to(center) < 1.0,
			"explosão centrada no baú (%s, %s)" % [burst.get_global_transform().origin, center])
	check.call(is_zero_approx(image.rotation), "explosão sem a rotação do tremor")
	check.call(burst.size == Vector2.ZERO, "explosão não ocupa espaço no layout")
	check.call(await _wait(host, func() -> bool: return not hud.chest_burst_active(), 1.5)
			and hud.chest_animating(), "explosão some sozinha sem esperar os itens")
	await _wait(host, func() -> bool: return not hud.chest_animating(), 4.0)
	check.call(not hud.chest_burst_active(), "fim natural sem explosão")

	hud.show_chest(rewards)
	await _wait(host, hud.chest_burst_active, 3.0)
	hud.call("_chest_skip")
	check.call(not hud.chest_burst_active() and not burst.visible, "pular apaga a explosão")

	hud.show_chest(rewards)
	await _wait(host, hud.chest_burst_active, 3.0)
	hud.show_chest(rewards)
	check.call(not hud.chest_burst_active(), "novo baú recomeça sem a explosão do anterior")
	await _wait(host, hud.chest_burst_active, 3.0)
	hud.start_run()
	check.call(not hud.chest_burst_active() and not burst.visible, "nova partida apaga a explosão")
	check.call(image.get_child_count() == 1, "um nó de explosão só, reaproveitado a cada baú")
	hud.queue_free()
	await host.get_tree().process_frame


## Espera a condição por até `timeout` segundos reais, quadro a quadro.
func _wait(host: Node, condition: Callable, timeout: float) -> bool:
	var until := Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < until:
		if condition.call():
			return true
		await host.get_tree().process_frame
	return bool(condition.call())
