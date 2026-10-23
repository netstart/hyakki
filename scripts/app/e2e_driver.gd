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
			await _tap_text("menu.back", true)
			await _expect_screen(&"title", "%s → voltar ao título" % item[1])
	await _tap_text("title.options", true)
	if await _expect_screen(&"options", "título → options (de novo)"):
		_host("key BACK")
		await _expect_screen(&"title", "voltar do Android em options volta ao título")

	_step("seleção")
	await _start_run_from_title()
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
		await _tap_text("chest.skip", true)
		_check(not game.hud.chest_animating() and game.hud.chest_lines_total() > 0
				and game.hud.chest_lines_shown() == game.hud.chest_lines_total(),
				"pular mostra todos os itens com texto")
		await _seconds(0.6)
		_shot("bau")
		await _tap_text("chest.close", true)
		_check(await _wait_for(func() -> bool: return not game.hud.chest_open(), 4.0), "baú fecha")
		# Sem pular: a animação termina sozinha e o botão vira "fechar".
		game.apply_scenario("chest")
		if await _wait_for(func() -> bool: return game.hud.chest_open(), 5.0):
			var finished := await _wait_for(func() -> bool: return not game.hud.chest_animating(), 8.0)
			_check(finished and game.hud.chest_lines_shown() == game.hud.chest_lines_total(),
					"sem pular, a animação termina com todos os itens")
			_check(_button(tr("chest.close"), false) != null, "botão vira fechar ao terminar")
			await _tap_text("chest.close", true)
			_check(await _wait_for(func() -> bool: return not game.hud.chest_open(), 4.0), "baú fecha de novo")
	else:
		_check(false, "baú abre")

	_step("pausa")
	await _wait_for(func() -> bool: return not game.hud.overlay_open() and not GameClock.paused, 6.0)
	_host("key BACK")
	_check(await _wait_for(func() -> bool: return game.hud.pause_open(), WAIT), "voltar do Android pausa a partida")
	_shot("pausa")
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
	if await _wait_for(func() -> bool: return game.hud.revive_open(), 3.0):
		_check(true, "oferta de reviver aparece")
		_shot("reviver")
		await _tap_text("revive.results")
	if not await _expect_screen(&"results", "derrota leva aos resultados"):
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
	await _expect_screen(&"results", "desistir leva aos resultados")
	_check(bool(app.last_result.get("gave_up", false)) or not bool(app.last_result.get("victory", true)),
			"resultado registra a desistência")
	await _tap_text("results.menu")
	await _expect_screen(&"title", "resultados → título")


# --- Ajudantes ----------------------------------------------------------------------

func _start_run_from_title() -> void:
	await _tap_text("title.play", true)
	if not await _expect_screen(&"heroes", "jogar → heróis"):
		return
	_shot("herois")
	await _tap_text("heroes.next", true)
	if not await _expect_screen(&"stages", "heróis → fases"):
		return
	_shot("fases")
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
