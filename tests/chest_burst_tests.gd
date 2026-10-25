extends RefCounted
## Explosão atrás do baú (scripts/ui/chest_burst.gd) dentro da tela do baú (chest_panel.gd):
## nasce na abertura (depois da queda e do tremor), fica atrás do baú e na boca dele, na cor
## da raridade, some sozinha sem esperar os itens, e pular, fechar, abrir outro baú ou começar
## outra partida apagam a explosão sem deixar nós sobrando.
## Chamado por tests/integration_tests.gd, que passa o nó da cena e o _check.

const REWARD := {"kind": "weapon_new", "id": &"katana", "level": 1, "title": "Katana", "text": "+5", "icon": ""}


func run(host: Node, check: Callable) -> void:
	var hud := Hud.new()
	host.add_child(hud)
	await host.get_tree().process_frame
	var panel := hud.chest_panel()
	var chest := panel.chest()
	var burst := panel.burst()
	check.call(burst != null and burst.get_parent() == chest, "explosão é filha do baú")
	check.call(burst.show_behind_parent, "explosão desenha atrás do baú")
	check.call(burst.mouse_filter == Control.MOUSE_FILTER_IGNORE, "explosão não pega toques")
	check.call(int(burst.get("_frames")) == 9, "folha da explosão recortada em 9 quadros de 40 px")
	check.call(not hud.chest_burst_active(), "sem baú, sem explosão")

	var rewards: Array[Dictionary] = [REWARD, REWARD, REWARD]
	hud.show_chest(rewards)
	await host.get_tree().process_frame
	check.call(hud.chest_animating() and not hud.chest_burst_active(), "queda e tremor do baú ainda sem explosão")
	check.call(await _wait(host, hud.chest_burst_active, 3.0), "baú abre com explosão atrás")
	await host.get_tree().process_frame
	check.call(burst.color == panel.rarity_color() and burst.color == ChestPanel.RARITIES[1][1],
			"explosão na cor da raridade (3 itens = raro)")
	check.call(burst.position.distance_to(chest.mouth()) < 1.0, "explosão centrada na boca do baú")
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
	check.call(chest.get_child_count() == 1, "um nó de explosão só, reaproveitado a cada baú")
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
