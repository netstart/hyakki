class_name E2EDriver
extends Node
## Roteiro de testes de ponta a ponta no aparelho (só build de debug). Liga quando existe
## user://e2e.txt com o nome do roteiro; o tools\run_e2e.ps1 escreve o arquivo, abre o jogo e
## lê o logcat. O piloto não "aperta" nada por dentro: pede ao PC toques reais no emulador
## (adb input) e confere o efeito de cada um. Protocolo, uma linha por evento no logcat:
##   E2E BEGIN <roteiro> | E2E STEP <etapa> | E2E OK <texto> | E2E FALHOU <texto>
##   E2E HOST tap X Y | swipe X1 Y1 X2 Y2 MS | key BACK | home | shot NOME | relaunch ROTEIRO
##   E2E END <verificações> <falhas>

const FILE := "user://e2e.txt"
## Tempo para o PC ler o logcat e executar um pedido (adb é lento no emulador).
const HOST_DELAY := 1.2
const WAIT := 12.0

var app: App
var suite: String = ""

var _count: int = 0
var _failures: int = 0


static func requested() -> bool:
	return OS.is_debug_build() and FileAccess.file_exists(FILE)


func _init(owner_app: App) -> void:
	app = owner_app
	suite = FileAccess.get_file_as_string(FILE).strip_edges()
	DirAccess.remove_absolute(FILE)
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_emit("BEGIN %s" % suite)
	match suite:
		"full":
			await _suite_full()
		"resume":
			await _suite_resume()
		_:
			_check(false, "roteiro desconhecido: '%s'" % suite)
	_emit("END %d %d" % [_count, _failures])


# --- Roteiros -------------------------------------------------------------------------

## Instalação limpa: abertura, consentimento, introdução, menus, partida completa e suspensão.
func _suite_full() -> void:
	_step("abertura")
	var splash := await _wait_for(func() -> bool: return _find(SplashScreen) != null, 5.0)
	_check(splash, "abertura aparece")
	if splash:
		await _seconds(0.8)
		_shot("abertura")
		await _tap_control(_find(SplashScreen) as Control)
		_check(await _wait_for(func() -> bool: return _find(SplashScreen) == null, 3.0),
				"toque pula a abertura")

	_step("consentimento")
	if not await _expect_screen(&"consent", "1ª abertura pede consentimento"):
		return
	_shot("consentimento")
	await _tap_text("consent.accept")
	_check(bool(SaveManager.data["consent"]["asked"]), "resposta do consentimento fica salva")

	_step("introdução")
	if await _expect_screen(&"story", "introdução abre na 1ª vez"):
		_shot("introducao")
		await _tap_text("story.next")
		await _tap_text("story.skip")
	if not await _expect_screen(&"title", "título depois da introdução"):
		return
	_check(bool(SaveManager.data["story"]["intro_seen"]), "introdução marcada como vista")
	_shot("titulo")

	_step("menus")
	for item: Array in [["title.options", &"options"], ["title.codex", &"codex"],
			["title.sanctuary", &"sanctuary"], ["title.shop", &"shop"], ["title.credits", &"credits"]]:
		await _tap_text(String(item[0]), true)
		if await _expect_screen(item[1] as StringName, "título → %s" % item[1]):
			_shot(String(item[1]))
			if item[1] == &"options":
				await _options_tabs()
			elif item[1] == &"codex":
				await _codex_pages()
			await _tap_text("menu.back", true)
			await _expect_screen(&"title", "%s → voltar ao título" % item[1])
	_step("loja: reforço por ryō")
	await _shop_coin_item()
	await _tap_text("title.options", true)
	if await _expect_screen(&"options", "título → options (de novo)"):
		await _options_quality()
		_host("key BACK")
		await _expect_screen(&"title", "voltar do Android em options volta ao título")

	_step("seleção")
	await _start_run_from_title(true)
	if app.game == null:
		return
	var game := app.game
	_shot("partida")

	_step("controle por toque")
	game.player.god_mode = true
	var before := game.player.sim_pos
	var view := get_viewport().get_visible_rect().size
	var from := _to_screen(Vector2(view.x * 0.22, view.y * 0.7))
	var to := _to_screen(Vector2(view.x * 0.22 + 60.0, view.y * 0.7))
	_host("swipe %d %d %d %d 1500" % [from.x, from.y, to.x, to.y])
	await _seconds(HOST_DELAY + 1.8)
	_check(game.player.sim_pos.distance_to(before) > 20.0,
			"arrastar o dedo move o herói (%.0f px)" % game.player.sim_pos.distance_to(before))

	_step("nível novo")
	var weapons_before := game.weapons.size() + game.level_up.passive_levels.size()
	game.add_xp(game.xp_needed)
	if await _wait_for(func() -> bool: return game.hud.level_up_open(), 5.0):
		_check(true, "carta de nível novo aparece")
		_shot("nivel")
		await _seconds(0.5)
		_check(game.hud.level_cards().all(func(b: Button) -> bool: return b is LevelCard and (b as LevelCard).settled),
				"cartas pousadas em leque, prontas para o toque")
		await _tap_control(game.hud.level_cards()[0])
		_check(await _wait_for(func() -> bool: return not game.hud.level_up_open(), 4.0), "tocar a carta escolhe")
		var gained := game.weapons.size() + game.level_up.passive_levels.size() > weapons_before
		_check(gained or game.weapons.any(func(w: Weapon) -> bool: return w.level > 1), "escolha aplicada")
	else:
		_check(false, "carta de nível novo aparece")

	_step("baú")
	await _wait_for(func() -> bool: return not game.hud.overlay_open(), 5.0)
	game.apply_scenario("chest")
	if await _wait_for(func() -> bool: return game.hud.chest_open(), 5.0):
		_check(true, "baú abre")
		_check(game.hud.chest_animating(), "animação do baú começa")
		_check(not game.hud.chest_burst_active(), "sem explosão antes de o baú abrir")
		await _tap_text("chest.skip", true)
		_check(not game.hud.chest_animating() and game.hud.chest_lines_total() > 0
				and game.hud.chest_lines_shown() == game.hud.chest_lines_total(),
				"pular mostra todos os itens com texto")
		_check(not game.hud.chest_burst_active(), "pular apaga a explosão")
		_check(game.hud.chest_panel().ryo_shown() == game.hud.chest_panel().ryo_total(), "pular mostra o ryō completo")
		await _seconds(0.6)
		_shot("bau")
		await _tap_text("chest.close", true)
		_check(await _wait_for(func() -> bool: return not game.hud.chest_open(), 4.0), "baú fecha")
		# Sem pular: a animação termina sozinha e o botão vira "fechar".
		game.apply_scenario("chest")
		if await _wait_for(func() -> bool: return game.hud.chest_open(), 5.0):
			_check(await _wait_for(func() -> bool: return game.hud.chest_burst_active(), 4.0),
					"explosão atrás do baú ao abrir")
			var finished := await _wait_for(func() -> bool: return not game.hud.chest_animating(), 8.0)
			_check(finished and game.hud.chest_lines_shown() == game.hud.chest_lines_total(),
					"sem pular, a animação termina com todos os itens")
			_check(not game.hud.chest_burst_active(), "explosão some ao terminar")
			_check(_button(tr("chest.close"), false) != null, "botão vira fechar ao terminar")
			await _tap_text("chest.close", true)
			_check(await _wait_for(func() -> bool: return not game.hud.chest_open(), 4.0), "baú fecha de novo")
	else:
		_check(false, "baú abre")

	_step("armas de trovão")
	await _wait_for(func() -> bool: return not game.hud.overlay_open() and not GameClock.paused, 6.0)
	await _thunder_weapons(game)

	_step("chefe")
	await _boss_entrance(game)

	_step("pausa")
	await _wait_for(func() -> bool: return not game.hud.overlay_open() and not GameClock.paused, 6.0)
	_host("key BACK")
	_check(await _wait_for(func() -> bool: return game.hud.pause_open(), WAIT), "voltar do Android pausa a partida")
	_shot("pausa")
	await _pause_quality(game)
	var frozen := GameClock.game_time
	await _seconds(1.0)
	_check(is_equal_approx(frozen, GameClock.game_time), "tempo parado na pausa")
	await _tap_text("pause.resume", true)
	_check(await _wait_for(func() -> bool: return not game.hud.pause_open(), 4.0), "continuar fecha a pausa")
	_check(await _wait_for(func() -> bool: return GameClock.game_time > frozen + 0.5, 8.0), "tempo volta a correr")

	_step("derrota")
	game.player.god_mode = false
	game.player.revives_used = 99
	for i: int in range(60):
		if not game.player.is_alive:
			break
		game.player.invuln = 0.0
		game.player.take_damage(99999.0)
		await get_tree().process_frame
	_check(game.death.is_active() and app.current != &"results", "a morte começa a sequência (antes de qualquer menu)")
	if await _wait_for(func() -> bool: return game.hud.revive_open(), 3.0):
		_check(true, "oferta de reviver aparece")
		_check(game.player.down >= 1.0, "a oferta aparece com a guardiã caída no chão")
		_shot("reviver")
		await _tap_text("revive.results")
	# Aviso da morte (faixa de tinta): fica na tela até um toque, depois da trava.
	_check(await _wait_for(func() -> bool: return game.death.notice_open(), 4.0), "aviso da morte aparece")
	_check(app.current != &"results" and app.game != null, "resultados só depois do aviso")
	await _seconds(0.6)
	_shot("aviso_morte")
	await _wait_for(func() -> bool: return game.death.can_skip(), 3.0)
	await _tap_control(game.death.notice_control())
	if not await _expect_screen(&"results", "toque no aviso leva aos resultados"):
		return
	_check(app.game == null, "partida encerrada")
	_check(not bool(app.last_result.get("victory", true)), "resultado registra a derrota")
	_shot("resultados")
	await _tap_text("results.menu")
	await _expect_screen(&"title", "resultados → título")

	_step("suspensão")
	await _start_run_from_title()
	if app.game == null:
		return
	await _seconds(3.0)
	_host("home")
	await _seconds(HOST_DELAY + 2.0)
	_check(not (SaveManager.data.get("suspended", {}) as Dictionary).is_empty(),
			"ir para segundo plano guarda a partida")
	SaveManager.save_profile()
	_host("relaunch resume")


## Depois de o app ser fechado no meio da partida: "Continuar" retoma a partida salva.
func _suite_resume() -> void:
	_step("reabrir")
	var splash := await _wait_for(func() -> bool: return _find(SplashScreen) != null, 5.0)
	if splash:
		await _seconds(0.8)
		await _tap_control(_find(SplashScreen) as Control)
	if not await _expect_screen(&"title", "título na 2ª abertura (anúncio de abertura simulado)", 20.0):
		return
	_check(app.has_suspended_run(), "partida suspensa disponível")
	_shot("titulo_continuar")
	await _tap_text("title.continue")
	if not await _wait_for(func() -> bool: return app.game != null and app.game.running, WAIT):
		_check(false, "continuar retoma a partida")
		return
	_check(true, "continuar retoma a partida")
	var game := app.game
	_check(GameClock.game_time > 2.0, "tempo da partida restaurado (%.1f s)" % GameClock.game_time)
	_check(not app.has_suspended_run(), "partida suspensa consumida")
	_check(await _wait_for(func() -> bool: return game.hud.pause_open(), 3.0), "partida retomada começa pausada")
	_shot("partida_retomada")

	_step("desistir")
	_host("key BACK")
	if await _wait_for(func() -> bool: return game.hud.pause_open(), WAIT):
		await _tap_text("pause.quit", true)
		_check(await _wait_for(func() -> bool: return game.hud.pause_menu().confirm_open(), 3.0),
				"desistir pede confirmação")
		await _tap_text("pause.quit_confirm")
	await _expect_screen(&"results", "desistir leva aos resultados")
	_check(bool(app.last_result.get("gave_up", false)) or not bool(app.last_result.get("victory", true)),
			"resultado registra a desistência")
	await _tap_text("results.menu")
	await _expect_screen(&"title", "resultados → título")


## Kaminari e Inazuma na partida de verdade: com inimigos por perto, as duas ferem dentro
## de alguns segundos (o raio do céu cai depois do aviso; o raio do corpo salta entre eles).
## Escolha do guardião: toque real no retrato da Hana troca o guardião (palco e painel);
## toque no da Aki volta, e é com ela que a partida segue.
func _hero_pick() -> void:
	var screen := _visible_screen("hero_screen.gd")
	if screen == null:
		_check(false, "tela dos guardiões encontrada")
		return
	var portraits: Dictionary = screen.get("_portraits")
	for id: StringName in [&"hana", &"aki"]:
		await _tap_control(portraits[id] as Control)
		_check(await _wait_for(func() -> bool: return screen.call("selected_hero") == id, 4.0)
				and String(app.selection["hero"]) == String(id), "tocar no retrato escolhe %s" % id)
		if id == &"hana":
			await _seconds(0.5)
			_shot("herois_hana")


## Opções: toque real na aba Gráficos rola até a seção e a acende; Áudio volta ao topo.
func _options_tabs() -> void:
	var screen := _visible_screen("options_screen.gd")
	if screen == null:
		_check(false, "tela de opções encontrada")
		return
	var tabs: Array = screen.get("_tabs")
	await _tap_control(tabs[2] as Control)
	_check(await _wait_for(func() -> bool: return screen.call("current_section") == 2, 4.0)
			and (screen.get("_scroll") as ScrollContainer).scroll_vertical > 0, "aba Gráficos rola até a seção")
	_shot("opcoes_graficos")
	await _tap_control(tabs[0] as Control)
	_check(await _wait_for(func() -> bool: return screen.call("current_section") == 0, 4.0), "aba Áudio volta ao topo")


## Diário: toque real no marcador Chefes vira a página; toque num cartão abre a entrada.
func _codex_pages() -> void:
	var screen := _visible_screen("codex_screen.gd")
	if screen == null:
		_check(false, "tela do diário encontrada")
		return
	var tabs: Array = screen.get("_tabs")
	await _tap_control(tabs[1] as Control)
	_check(await _wait_for(func() -> bool: return screen.call("category") == &"bosses", 4.0),
			"marcador Chefes vira a página")
	await _seconds(0.5)
	var cards: Array = screen.call("cards")
	if cards.size() > 1:
		await _tap_control(cards[1] as Control)
		_check(await _wait_for(func() -> bool: return (cards[1] as Control).call("is_selected"), 4.0),
				"tocar no cartão abre a entrada")
	_shot("diario_chefes")


## Qualidade gráfica nas Opções: toque real abre a lista; a escolha (Baixa) vai pelo próprio
## menu da lista (id_pressed), como o toque no item faria. Volta ao valor de antes.
func _options_quality() -> void:
	var key := GfxQuality.changed_signal_key()
	var before: Variant = Settings.get_value(key)
	var option := get_tree().root.find_child("opt_%s" % key, true, false) as OptionButton
	_check(option != null, "Opções têm a escolha de qualidade gráfica")
	if option == null:
		return
	var scroll := option.get_parent()
	while scroll != null and not scroll is ScrollContainer:
		scroll = scroll.get_parent()
	if scroll != null:
		(scroll as ScrollContainer).ensure_control_visible(option)
		await _seconds(0.3)
	await _tap_control(option)
	_check(await _wait_for(func() -> bool: return option.get_popup().visible, 3.0), "toque abre a lista de qualidade")
	option.get_popup().id_pressed.emit(option.get_item_id(1))
	_check(await _wait_for(func() -> bool: return Settings.get_value(key) == "low", 3.0)
			and GfxQuality.level() == GfxQuality.LOW, "escolher Baixa nas Opções vale na hora")
	option.get_popup().hide()
	Settings.set_value(key, before)


## Qualidade gráfica na pausa: cada toque real avança o ciclo Auto → Baixa → Média → Alta.
func _pause_quality(game: HyakkiGame) -> void:
	var key := GfxQuality.changed_signal_key()
	var before: Variant = Settings.get_value(key)
	var quality := game.hud.pause_menu().find_child("PauseQuality", true, false) as Button
	_check(quality != null and quality.is_visible_in_tree(), "pausa mostra a qualidade gráfica")
	if quality == null:
		return
	var mode := GfxQuality.mode()
	for i: int in range(GfxQuality.MODES.size()):
		var want := GfxQuality.next_mode(mode)
		await _tap_control(quality)
		_check(await _wait_for(func() -> bool: return GfxQuality.mode() == want, 3.0),
				"toque na pausa troca a qualidade para %s" % want)
		mode = GfxQuality.mode()
	_check(GfxQuality.mode() == str(before), "quatro toques voltam à qualidade de antes")
	Settings.set_value(key, before)


## Chefe: entrada com a faixa em kanji, barra no topo e o chefe em campo (despachado depois).
func _boss_entrance(game: HyakkiGame) -> void:
	game.bosses.spawn(&"tanuki")
	var panel := game.hud.boss_panel()
	_check(panel.intro_active() and panel.kanji != "", "chefe entra com a faixa do nome em kanji")
	await _seconds(0.8)
	_shot("chefe_entrada")
	_check(await _wait_for(func() -> bool: return not panel.intro_active(), 6.0) and panel.fraction > 0.0,
			"barra de vida do chefe fica no topo")
	for boss: Dictionary in game.bosses.bosses.duplicate():
		game.enemies.damage(int(boss["index"]), 1e9, Vector2.ZERO, 0.0)
	_check(await _wait_for(func() -> bool: return game.bosses.active_count() == 0, 4.0), "chefe vencido sai de cena")
	await _seconds(0.6)
	_shot("chefe_morte")
	await _wait_for(func() -> bool: return not game.hud.overlay_open() and not GameClock.paused, 6.0)


func _thunder_weapons(game: HyakkiGame) -> void:
	for id: StringName in [&"kaminari", &"inazuma"]:
		if not game.has_weapon(id):
			game.add_weapon(id)
		_check(game.has_weapon(id), "%s entra na partida" % id)
	var damaged := func() -> bool:
		var origin := game.player.sim_pos
		if game.enemies.nearest(origin, 120.0) < 0:
			for k: int in range(6):
				game.enemies.spawn(&"slime_rice", origin + Vector2.from_angle(TAU * k / 6.0) * 70.0, 50.0, 0.0)
		return float(game.tracker.damage_by_weapon.get(&"kaminari", 0.0)) > 0.0 \
				and float(game.tracker.damage_by_weapon.get(&"inazuma", 0.0)) > 0.0
	_check(await _wait_for(damaged, WAIT), "Kaminari e Inazuma ferem inimigos")
	_shot("armas_trovao")


## Loja: rola o meio com um arrasto de verdade (adb swipe) e compra um reforço com ryō
## tocando no cartão; confere o desconto, a fila da próxima partida e o saldo na tela.
func _shop_coin_item() -> void:
	await _tap_text("title.shop", true)
	if not await _expect_screen(&"shop", "título → loja (reforços)"):
		return
	var screen := _visible_screen("shop_screen.gd")
	if screen == null:
		_check(false, "tela da loja encontrada")
		return
	var scroll := screen.get("_scroll") as ScrollContainer
	var item := &"coin_bag"
	# Build de debug: garante ryō e o reforço livre para a compra.
	(SaveManager.data["shop"]["next_run"] as Dictionary).erase(String(item))
	SaveManager.data["ryo"] = maxi(SaveManager.ryo(), 1000)
	screen.call("_update_coin_cards")
	var area := scroll.get_global_rect()
	var from := _to_screen(Vector2(area.get_center().x, area.end.y - 12.0))
	var to := _to_screen(Vector2(area.get_center().x, area.position.y + 12.0))
	_host("swipe %d %d %d %d 600" % [from.x, from.y, to.x, to.y])
	await _seconds(HOST_DELAY + 1.0)
	_check(scroll.scroll_vertical > 0, "arrastar o dedo rola a loja (%d px)" % scroll.scroll_vertical)
	var card := (screen.get("_coin_cards")[item] as Dictionary)["button"] as Button
	if not area.encloses(card.get_global_rect()):
		scroll.ensure_control_visible(card)
		await _seconds(0.3)
	_shot("loja_rolada")
	var before := SaveManager.ryo()
	await _tap_control(card)
	var price := ShopManager.coin_price(item)
	_check(await _wait_for(func() -> bool: return ShopManager.is_queued(item), 4.0),
			"tocar o cartão compra o reforço")
	_check(SaveManager.ryo() == before - price, "a compra desconta %d ryō" % price)
	_check((screen.get("_ryo") as Label).text.contains(Locale.format_number(SaveManager.ryo())),
			"o saldo na tela atualiza")
	_shot("loja_reforco")
	await _tap_text("menu.back", true)
	await _expect_screen(&"title", "loja → voltar ao título")


## Mapa da jornada na tela de fases, com toques reais nos pontos. Na 1ª abertura (instalação
## limpa): vila liberada, bambuzal bloqueado; tocar no bambuzal mostra o cartão mas não libera
## o Começar nem muda a fase escolhida; tocar na vila liga de novo. Depois da derrota na vila
## (suspensão) só confere que ela segue liberada e não vencida.
func _journey_map(first: bool) -> void:
	var screen := _visible_screen("stage_screen.gd")
	var map := screen.get("_map") as JourneyMap if screen != null else null
	if map == null:
		_check(false, "mapa da jornada na tela de fases")
		return
	var go := screen.get("_go") as Button
	# A guardiã anda até o ponto escolhido e o foco é posto no quadro seguinte.
	await _seconds(0.6)
	if not first:
		_check(map.node_state(&"village") == &"open", "derrota não marca a vila como vencida")
		return
	_shot("mapa_jornada")
	_check(map.node_state(&"village") == &"open", "vila liberada no mapa (instalação limpa)")
	_check(map.node_state(&"bamboo") == &"locked", "bambuzal bloqueado no mapa (instalação limpa)")
	_check(map.selected == &"village" and not go.disabled and String(app.selection["stage"]) == "village",
			"mapa abre na vila com Começar liberado")
	var area := map.get_global_rect()
	for id: StringName in [&"bamboo", &"village"]:
		_check(area.encloses((map.nodes[id] as Control).get_global_rect()), "ponto %s inteiro no mapa" % id)
	await _tap_control(map.nodes[&"bamboo"] as Control)
	_check(await _wait_for(func() -> bool: return map.selected == &"bamboo", 4.0),
			"tocar no bambuzal o escolhe no mapa")
	_check(go.disabled, "Começar desliga na fase bloqueada")
	_check(String(app.selection["stage"]) == "village", "fase bloqueada não vira a escolhida")
	await _tap_control(map.nodes[&"village"] as Control)
	_check(await _wait_for(func() -> bool: return map.selected == &"village", 4.0),
			"tocar na vila a escolhe de novo")
	_check(not go.disabled, "Começar volta a ligar na vila")
	_check(String(app.selection["stage"]) == "village", "vila segue a fase escolhida")


# --- Ajudantes ----------------------------------------------------------------------

## Da tela de título até a partida. Com check_map, confere o mapa da 1ª abertura das fases.
func _start_run_from_title(check_map: bool = false) -> void:
	await _tap_text("title.play", true)
	if not await _expect_screen(&"heroes", "jogar → heróis"):
		return
	for id: StringName in DB.ids("heroes"):
		_check(MetaProgress.is_hero_unlocked(id), "build de debug libera o guardião %s" % id)
	_shot("herois")
	if check_map:
		await _hero_pick()
	await _tap_text("heroes.next", true)
	if not await _expect_screen(&"stages", "heróis → fases"):
		return
	await _journey_map(check_map)
	await _tap_text("stages.start", true)
	var started := await _wait_for(func() -> bool: return app.game != null and app.game.running, WAIT)
	_check(started, "começar abre a partida")
	if started:
		await _seconds(1.5)


func _expect_screen(name: StringName, label: String, timeout: float = WAIT) -> bool:
	var ok := await _wait_for(func() -> bool: return app.current == name and app.game == null, timeout)
	_check(ok, label + ("" if ok else " (tela atual: %s)" % app.current))
	return ok


## Toca no botão visível com o texto traduzido da chave (ou que começa com ele).
func _tap_text(key: String, prefix: bool = false) -> void:
	var text := tr(key)
	var found := await _wait_for(func() -> bool: return _button(text, prefix) != null, WAIT)
	if not found:
		_check(false, "botão '%s' visível" % text)
		return
	await _tap_control(_button(text, prefix))


func _tap_control(control: Control) -> void:
	if control == null:
		return
	var at := _to_screen(control.get_global_transform_with_canvas() * (control.size * 0.5))
	_host("tap %d %d" % [at.x, at.y])
	await _seconds(HOST_DELAY)


## Pixels da tela do aparelho de um ponto da tela base (678×305), com a escala do stretch.
func _to_screen(point: Vector2) -> Vector2i:
	var at := get_viewport().get_final_transform() * point + Vector2(DisplayServer.window_get_position())
	return Vector2i(at.round())


## Tela visível cujo script termina com o nome dado (ex. "shop_screen.gd").
func _visible_screen(script_name: String) -> Control:
	for node: Node in get_tree().root.find_children("*", "Control", true, false):
		var script := node.get_script() as Script
		if script != null and script.resource_path.ends_with(script_name) and (node as Control).is_visible_in_tree():
			return node as Control
	return null


func _button(text: String, prefix: bool) -> Button:
	for node: Node in get_tree().root.find_children("*", "Button", true, false):
		var b := node as Button
		if not b.is_visible_in_tree() or b.disabled:
			continue
		var shown := b.text.strip_edges().trim_prefix("< ")
		if shown == text or (prefix and shown.begins_with(text)):
			return b
	return null


func _find(type: Variant) -> Node:
	for node: Node in get_tree().root.find_children("*", "", true, false):
		if is_instance_of(node, type):
			return node
	return null


func _wait_for(condition: Callable, timeout: float) -> bool:
	var left := timeout
	while left > 0.0:
		if condition.call():
			return true
		await _seconds(0.1)
		left -= 0.1
	return bool(condition.call())


func _seconds(value: float) -> void:
	await get_tree().create_timer(value, true, false, true).timeout


func _step(name: String) -> void:
	_emit("STEP " + name)


func _shot(name: String) -> void:
	_host("shot " + name)


func _host(command: String) -> void:
	_emit("HOST " + command)


func _check(condition: bool, label: String) -> void:
	_count += 1
	if condition:
		_emit("OK " + label)
	else:
		_failures += 1
		_emit("FALHOU " + label)


func _emit(line: String) -> void:
	print("E2E " + line)
