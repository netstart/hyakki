extends RefCounted
## Voo das recompensas até a guardiã (scripts/ui/reward_flight.gd) e a tela do pacto com um Kami
## (scripts/ui/kami_panel.gd), numa partida de verdade:
## - voo: duração (~1 s com o baú cheio), escalonamento, pulinho, arco, alvo relido a cada quadro
##   (segue a guardiã), um pouso por item com o sinal, fim sozinho sem sobrar nada (sem nós
##   filhos, sem faíscas), congela com a pausa, Baixa sem faíscas e Alta com, e a simulação
##   intocada (mesmo estado com e sem voo, RNG da partida igual);
## - quem solta o voo: carta do nível novo, "Continuar" do baú (um ícone por cartão + o ryō) e o
##   pacto selado; o encaixe da HUD acende quando o ícone chega;
## - Kami: entrada com as placas caindo, bloqueio do toque acidental, escolha em dois toques,
##   "Selar o pacto" só com uma placa destacada, carimbo, a luta volta na hora, o pacto aplicado,
##   recusar, bot, nova partida, regras da bênção/preço e o fundo do santuário por qualidade.
## O layout do painel de Kami em cada resolução e idioma fica em tests/hud_layout_tests.gd.
## Chamado por tests/level_chest_tests.gd (e por ele, por tests/integration_tests.gd).

const GAME_SCENE := "res://scenes/game/Game.tscn"
const CONFIG := {"hero": "aki", "stage": "village", "moon": 2, "mode": "normal", "seed": 11, "speed": 1}
const LevelChestTests := preload("res://tests/level_chest_tests.gd")
## Espera a entrada das placas de Kami (atraso, 3 placas e a queda) com folga.
const DEAL_WAIT := 1.1

var _host: Node
var _check: Callable


func run(host: Node, check: Callable) -> void:
	_host = host
	_check = check
	_test_rules()
	await _test_flight_unit()
	await _test_simulation_untouched()
	await _test_sources()
	await _test_kami_flow()
	GfxQuality.clear_override()
	GameClock.paused = true


# --- Regras ------------------------------------------------------------------------------

func _test_rules() -> void:
	_check.call(RewardFlight.total_time(1) <= 1.0 and RewardFlight.total_time(1) >= 0.6,
			"voo de 1 item entre 0,6 e 1 s (%.2f)" % RewardFlight.total_time(1))
	_check.call(RewardFlight.total_time(6) <= 1.15, "baú cheio (6 ícones) em ~1 s (%.2f)" % RewardFlight.total_time(6))
	_check.call(LevelUpPanel.slot_key({"kind": "weapon_new", "id": &"kunai"}) == "w:kunai"
			and LevelUpPanel.slot_key({"kind": "passive", "id": &"sake"}) == "p:sake"
			and LevelUpPanel.slot_key({"kind": "evolution", "id": &"dawn_blade"}) == "w:dawn_blade"
			and LevelUpPanel.slot_key({"kind": "heal"}) == "", "encaixe da HUD de cada tipo de recompensa")
	# Bênção e preço: um item por atributo; o especial só sem atributo (sem repetir o efeito).
	_check.call(KamiPanel.blessing_lines(&"hachiman").size() == 1
			and KamiPanel.cost_lines(&"hachiman")[0] == tr("kami.hachiman.cost"), "Hachiman: crítico e sem renascer")
	_check.call(KamiPanel.blessing_lines(&"raijin")[0] == tr("kami.raijin.special")
			and KamiPanel.cost_lines(&"raijin")[0].contains("15"), "Raijin: raios (especial) e +15% de maldição")
	for id: StringName in DB.ids("kami"):
		var data: Dictionary = DB.kami[id]
		_check.call(not KamiPanel.blessing_lines(id).is_empty() and not KamiPanel.cost_lines(id).is_empty(),
				"Kami %s tem bênção e preço" % id)
		_check.call(not String(data.get("kanji", "")).is_empty() and tr("kami.%s.domain" % id) != "kami.%s.domain" % id,
				"Kami %s tem kanji e domínio" % id)


# --- Voo ---------------------------------------------------------------------------------

func _items(count: int, from: Vector2) -> Array[Dictionary]:
	var icon := load("res://assets/art/ui/skill_icons/kami/inari.png") as Texture2D
	var items: Array[Dictionary] = []
	for i: int in range(count):
		items.append({"from": from + Vector2(0, 30 * i), "icon": icon if i % 2 == 0 else null,
				"color": Color.from_hsv(i * 0.15, 0.6, 1.0), "scale": 2.0, "key": "w:shuriken"})
	return items


func _test_flight_unit() -> void:
	var area := Control.new()
	area.size = Vector2(678, 305)
	_host.add_child(area)
	var flight := RewardFlight.new()
	area.add_child(flight)
	flight.size = area.size
	var goal := [Vector2(339, 160)]
	flight.target = func() -> Vector2: return goal[0]
	var landed: Array[Dictionary] = []
	var finished := [0]
	flight.landed.connect(func(item: Dictionary) -> void: landed.append(item))
	flight.finished.connect(func() -> void: finished[0] += 1)
	flight.set_process(false)
	for level: int in [GfxQuality.HIGH, GfxQuality.LOW]:
		GfxQuality.set_override(level)
		landed.clear()
		finished[0] = 0
		flight.clear()
		var name := GfxQuality.level_name(level)
		flight.launch(_items(4, Vector2(500, 60)))
		_check.call(flight.active() and flight.visible and flight.flyer_count() == 4, "%s: 4 ícones no ar" % name)
		_check.call(flight.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s: o voo não pega toques" % name)
		flight.step(0.05)
		_check.call(flight.flyer_position(0).y < 60.0 and flight.flyer_position(3) == Vector2(500, 150),
				"%s: o primeiro já sobe, o último espera a vez no lugar" % name)
		var sparks := 0
		var t := 0.05
		var moved_goal := false
		var dt := 1.0 / 60.0
		while flight.active() and t < 3.0:
			if not moved_goal and t > 0.4:
				# A câmera andou: a guardiã mudou de lugar no meio do voo.
				goal[0] = Vector2(250, 200)
				moved_goal = true
			flight.step(dt)
			sparks = maxi(sparks, flight.spark_count())
			t += dt
		_check.call(not flight.active() and t <= RewardFlight.total_time(4) + 0.6,
				"%s: o voo acaba sozinho (%.2f s)" % [name, t])
		_check.call(landed.size() == 4 and flight.landed_count() == 4 and finished[0] == 1,
				"%s: um pouso por ícone e um fim (%d, %d)" % [name, landed.size(), finished[0]])
		_check.call(flight.burst_count() == 0 and flight.spark_count() == 0 and flight.flyer_count() == 0
				and flight.get_child_count() == 0 and not flight.visible, "%s: nada sobra (sem nós, faíscas ou anéis)" % name)
		if level == GfxQuality.LOW:
			_check.call(sparks == 0, "Baixa: sem faíscas")
		else:
			_check.call(sparks > 0 and sparks <= RewardFlight.MAX_SPARKS, "Alta: faíscas no orçamento (%d)" % sparks)
		goal[0] = Vector2(339, 160)
	# O fim do caminho é a guardiã de AGORA.
	var f := {"from": Vector2(600, 40), "side": 1.0}
	var end := flight.path_point(f, RewardFlight.LIFT_TIME + RewardFlight.FLY_TIME, Vector2(100, 250))
	_check.call(end.distance_to(Vector2(100, 250)) < 0.5, "o arco termina na guardiã (%s)" % end)
	var top := flight.path_point(f, RewardFlight.LIFT_TIME, Vector2(100, 250))
	_check.call(top.y < 40.0 and absf(top.x - 600.0) < 0.5, "pulinho para cima antes do arco")
	_check.call(flight.flyer_scale({"scale": 2.0}, RewardFlight.LIFT_TIME) > 2.0
			and flight.flyer_scale({"scale": 2.0}, RewardFlight.LIFT_TIME + RewardFlight.FLY_TIME) < 0.05,
			"pop de escala na subida e o ícone some na guardiã")
	# Pausa: congela e esconde.
	GfxQuality.set_override(GfxQuality.HIGH)
	var hold := [true]
	flight.hold = func() -> bool: return hold[0]
	flight.clear()
	flight.launch(_items(1, Vector2(500, 60)))
	flight.call("_process", 0.3)
	_check.call(flight.flyer_count() == 1 and flight.landed_count() == 0 and not flight.visible,
			"pausa aberta: o voo congela e some")
	hold[0] = false
	flight.call("_process", 0.3)
	_check.call(flight.visible and flight.active(), "pausa fechada: o voo segue")
	flight.clear()
	_check.call(not flight.active() and not flight.visible, "clear apaga tudo")
	area.queue_free()
	GfxQuality.clear_override()
	await _host.get_tree().process_frame


## Mesma semente, com e sem voo: o estado da simulação é idêntico (o voo só lê a guardiã).
func _test_simulation_untouched() -> void:
	var summaries: Array[String] = []
	for with_flight: bool in [false, true]:
		# Relógio parado desde o primeiro quadro: os passos são só os daqui (sem o tempo real).
		var game := (load(GAME_SCENE) as PackedScene).instantiate() as HyakkiGame
		game.config = CONFIG.duplicate()
		_host.add_child(game)
		GameClock.paused = true
		await _host.get_tree().process_frame
		var rng_state := game.rng.state
		var pos := game.player.sim_pos
		if with_flight:
			var items: Array[Dictionary] = []
			for r: Dictionary in LevelChestTests.sample_rewards(5):
				items.append({"from": Vector2(400, 80), "icon": LevelUpPanel._load(String(r.get("icon", ""))),
						"color": Color.GOLD, "key": LevelUpPanel.slot_key(r)})
			game.hud.fly_rewards(items)
			game.hud.reward_flight().step(0.3)
			_check.call(game.rng.state == rng_state and game.player.sim_pos == pos,
					"o voo não mexe no RNG nem na posição da guardiã")
		for i: int in range(240):
			GameClock.game_time += GameClock.STEP
			GameClock.ticked.emit(GameClock.STEP)
			if with_flight:
				game.hud.reward_flight().step(GameClock.STEP)
		var summary := game.state_summary("")
		summaries.append(summary.substr(summary.find("hash=")))
		await _free(game)
	_check.call(summaries[0] == summaries[1], "mesmo estado com e sem o voo (%s / %s)" % summaries)


# --- Quem solta o voo --------------------------------------------------------------------

func _test_sources() -> void:
	var game := await _new_game()
	var hud := game.hud
	var flight := hud.reward_flight()
	_check.call(flight.get_parent() != null and flight.get_index() > hud.chest_panel().get_index()
			and flight.get_index() > hud.kami_panel().get_index(), "voo por cima das telas")
	_check.call(flight.goal().distance_to(hud.guardian_point() + RewardFlight.GUARDIAN_OFFSET) < 0.5,
			"alvo do voo na guardiã")
	# Nível novo: a carta escolhida.
	game.call("_open_level_up")
	await _seconds(0.9)
	var landed_before := flight.landed_count()
	hud.level_cards()[0].pressed.emit()
	_check.call(flight.flyer_count() == 1 and not hud.overlay_open(), "carta escolhida: o ícone voa e a luta volta")
	var arrived := await _wait(func() -> bool: return not flight.active(), 2.0)
	_check.call(arrived and flight.landed_count() == landed_before + 1,
			"o ícone da carta chega na guardiã")
	# Baú: um ícone por cartão + o saco de ryō, no "Continuar".
	hud.show_chest(LevelChestTests.sample_rewards(5))
	var panel := hud.chest_panel()
	panel.skip()
	_check.call(not flight.active(), "o voo do baú só sai no Continuar")
	panel.button().pressed.emit()
	_check.call(flight.flyer_count() == panel.lines_total() and not hud.chest_open(),
			"Continuar: %d ícones voam (%d cartões + ryō)" % [flight.flyer_count(), panel.lines_total()])
	var t0 := Time.get_ticks_msec()
	_check.call(await _wait(func() -> bool: return not flight.active(), 3.0), "o voo do baú acaba sozinho")
	_check.call((Time.get_ticks_msec() - t0) / 1000.0 <= RewardFlight.total_time(6) + 0.4,
			"voo do baú em ~1 s (%.2f s)" % ((Time.get_ticks_msec() - t0) / 1000.0))
	# O encaixe da arma acende quando o ícone chega.
	var painter := hud.get("_skill_icons") as SkillIconPainter
	var key := "w:%s" % game.weapons[0].id
	flight.landed.emit({"key": key})
	_check.call(painter.flash(key, Time.get_ticks_msec() / 1000.0) > 0.5 or SkillIconPainter.fx() == 0,
			"o encaixe da HUD acende com a chegada")
	# Bot: sem voo.
	hud.show_chest(LevelChestTests.sample_rewards(3))
	hud.bot_answer()
	_check.call(not flight.active(), "bot fecha o baú sem voo")
	# Nova partida apaga o voo em andamento.
	hud.fly_rewards(_items(2, Vector2(300, 100)))
	hud.start_run()
	_check.call(not flight.active(), "nova partida apaga o voo")
	await _free(game)


# --- Kami --------------------------------------------------------------------------------

func _test_kami_flow() -> void:
	var game := await _new_game()
	var hud := game.hud
	var panel := hud.kami_panel()
	var flight := hud.reward_flight()
	var chosen: Array[StringName] = []
	hud.kami_chosen.connect(func(id: StringName) -> void: chosen.append(id))
	game.apply_scenario("kami")
	_check.call(hud.kami_open() and hud.overlay_open() and GameClock.paused, "o santuário abre o pacto e pausa a luta")
	_check.call(panel.cards().size() == 3 and panel.selected() == -1, "três placas, nenhuma destacada")
	_check.call(panel.confirm_button().disabled, "Selar o pacto desligado sem uma placa destacada")
	panel.cards()[1].pressed.emit()
	_check.call(panel.selected() == -1, "toque antes da placa parar é ignorado")
	await _seconds(DEAL_WAIT)
	_check.call(panel.cards().all(func(c: KamiPanel.KamiCard) -> bool: return c.settled), "as placas param no cordão")
	_check.call(panel.overlay().power >= 0.99, "fundo do santuário por inteiro")
	# Primeiro toque destaca; o segundo sela.
	var card := panel.cards()[1]
	card.pressed.emit()
	_check.call(panel.selected() == 1 and card.selected and panel.cards()[0].dimmed and chosen.is_empty(),
			"primeiro toque só destaca (as outras escurecem)")
	_check.call(not panel.confirm_button().disabled, "Selar o pacto liga")
	_check.call(panel.subtitle_text().contains(tr("kami.%s.name" % card.id)), "subtítulo mostra o Kami destacado")
	panel.cards()[2].pressed.emit()
	_check.call(panel.selected() == 2 and not card.selected, "trocar de placa")
	card = panel.cards()[2]
	var id := card.id
	card.pressed.emit()
	_check.call(chosen.is_empty() and hud.kami_open(), "o carimbo cai antes do pacto")
	card.pressed.emit()
	await _seconds(KamiPanel.STAMP_TIME + 0.25)
	_check.call(chosen.size() == 1 and chosen[0] == id and game.kami.accepted.has(id) and game.tracker.kami.has(id),
			"pacto selado uma vez e aplicado (%s)" % [chosen])
	_check.call(not hud.kami_open() and not hud.overlay_open() and not GameClock.paused, "a luta volta na hora")
	_check.call(flight.active() and panel.outro_playing(), "o ícone do Kami voa enquanto as placas saem")
	_check.call(await _wait(func() -> bool: return not flight.active() and not panel.visible, 2.0),
			"voo e saída acabam sozinhos")
	# Recusar.
	game.apply_scenario("kami")
	await _seconds(DEAL_WAIT)
	var accepted := game.kami.accepted.size()
	panel.decline_button().pressed.emit()
	_check.call(chosen.size() == 2 and chosen[1] == &"" and game.kami.accepted.size() == accepted
			and not hud.overlay_open(), "Ignorar o santuário recusa sem pacto")
	await _seconds(0.1)
	panel.decline_button().pressed.emit()
	_check.call(chosen.size() == 2, "a recusa não repete")
	await _wait(func() -> bool: return not panel.visible, 1.5)
	# Selar pelo botão.
	game.apply_scenario("kami")
	await _seconds(DEAL_WAIT)
	panel.select(0)
	var by_button := panel.cards()[0].id
	panel.confirm_button().pressed.emit()
	await _seconds(KamiPanel.STAMP_TIME + 0.25)
	_check.call(chosen.back() == by_button and game.kami.accepted.has(by_button), "Selar o pacto pelo botão")
	await _wait(func() -> bool: return not panel.visible and not flight.active(), 3.0)
	# Bot e nova partida.
	game.apply_scenario("kami")
	var offered := panel.offer()[0]
	# A luta segue em tempo real durante o teste: uma bênção de nível que abriu junto ficaria
	# na frente do pacto no bot_answer (depende de quanto XP caiu até aqui).
	while hud.level_up_open():
		hud.bot_answer()
	hud.bot_answer()
	_check.call(chosen.back() == offered and not panel.visible and flight.flyer_count() == 0,
			"bot aceita o primeiro, sem voo (%s/%s, tela %s, voo %d)" % [chosen.back(), offered, panel.visible,
			flight.flyer_count()])
	game.apply_scenario("kami")
	hud.start_run()
	_check.call(not hud.kami_open() and not panel.visible, "nova partida fecha o pacto")
	# Fundo do santuário por qualidade.
	for level: int in [GfxQuality.LOW, GfxQuality.HIGH]:
		GfxQuality.set_override(level)
		Settings.emit_signal("changed", GfxQuality.changed_signal_key())
		var two: Array[StringName] = [&"inari", &"fujin"]
		hud.show_kami(two)
		_check.call(panel.cards().size() == 2, "oferta de 2 Kami (Lua V)")
		_check.call(panel.fx_level() == GfxQuality.budget("ui_fx") and panel.petal_count() == KamiPanel.PETALS[level]
				and panel.smoke_count() == KamiPanel.SMOKE[level],
				"%s: pétalas e incenso no orçamento" % GfxQuality.level_name(level))
		_check.call(panel.overlay().blur_on() == (level == GfxQuality.HIGH) or panel.overlay().power == 0.0,
				"%s: desfoque só em Alta" % GfxQuality.level_name(level))
		panel.close_now()
	GfxQuality.clear_override()
	await _free(game)


# --- Utilidades --------------------------------------------------------------------------

func _new_game() -> HyakkiGame:
	var game := (load(GAME_SCENE) as PackedScene).instantiate() as HyakkiGame
	game.config = CONFIG.duplicate()
	_host.add_child(game)
	await _host.get_tree().process_frame
	await _host.get_tree().process_frame
	GameClock.paused = false
	return game


func _free(game: HyakkiGame) -> void:
	game.queue_free()
	GameClock.paused = false
	await _host.get_tree().process_frame


func _seconds(value: float) -> void:
	await _host.get_tree().create_timer(value).timeout


func _wait(condition: Callable, timeout: float) -> bool:
	var until := Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < until:
		if condition.call():
			return true
		await _host.get_tree().process_frame
	return bool(condition.call())
