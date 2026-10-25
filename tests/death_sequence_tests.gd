extends RefCounted
## Sequência de morte (DeathSequence): o golpe letal congela o mundo, a guardiã cai e fica no
## chão em tempo real (mesmo em 3x), o aviso da morte aparece antes do fim da partida, que
## sai uma única vez (toque ou tempo); o reviver aceito faz o caminho inverso; o bot e o
## "desistir" pulam tudo; a partida salva durante a morte volta com o corpo já deitado.
## Chamado por tests/integration_tests.gd, que passa o nó da cena e o _check.

const GAME_SCENE := "res://scenes/game/Game.tscn"
const CONFIG := {"hero": "goro", "stage": "bamboo", "moon": 0, "mode": "normal", "seed": 23, "speed": 1}

var _host: Node
var _check: Callable


func run(host: Node, check: Callable) -> void:
	_host = host
	_check = check
	_test_fall_curve()
	var fill := AdsManager.mock_fill
	var auto := AdsManager.auto_answer
	await _test_death_to_notice()
	await _test_revive_rise()
	await _test_restore_and_timeout()
	await _test_bot_and_give_up()
	AdsManager.mock_fill = fill
	AdsManager.auto_answer = auto
	GameClock.paused = true


## Curva da queda: começa em pé, toca o chão, quica pouco e assenta deitada.
func _test_fall_curve() -> void:
	_check.call(DeathSequence.fall_curve(0.0) == 0.0 and DeathSequence.fall_curve(1.0) == 1.0,
			"queda vai de 0 (de pé) a 1 (deitada)")
	var rising := true
	for i: int in range(1, 20):
		var p := DeathSequence.FALL_HIT * i / 20.0
		rising = rising and DeathSequence.fall_curve(p) > DeathSequence.fall_curve(p - 0.01)
	_check.call(rising, "queda acelera até tocar o chão")
	var bounce := DeathSequence.fall_curve((1.0 + DeathSequence.FALL_HIT) * 0.5)
	_check.call(bounce < 1.0 and bounce > 0.85, "quique pequeno depois de tocar o chão (%.2f)" % bounce)


## Sem anúncio: golpe letal em 3x, queda em tempo real, aviso, trava de toque e fim único.
func _test_death_to_notice() -> void:
	AdsManager.mock_fill = false
	var game := await _new_game()
	var ends: Array[Dictionary] = []
	game.finished.connect(func(r: Dictionary) -> void:
		ends.append({"notice": game.death.notice_open(), "notice_time": game.death.notice_time,
				"victory": bool(r["victory"])}))
	GameClock.speed = 3
	var jingles := int(AudioManager.request_count.get("jingle_gameover", 0))
	var frozen := GameClock.game_time
	_kill(game)
	_check.call(game.death.is_active() and game.running and GameClock.paused,
			"golpe letal começa a sequência de morte com o mundo parado")
	_check.call(game.player.down == 0.0, "hit-stop: o corpo ainda não se mexeu no golpe")
	var started := Time.get_ticks_msec()
	await _seconds(0.5)
	var mid := game.player.down
	var mid_elapsed := game.death.elapsed
	_check.call(mid > 0.1 and mid < 1.0, "em 0,5 s a guardiã está caindo (%.2f)" % mid)
	await _wait_until(func() -> bool: return game.player.down >= 1.0, 2.0)
	var real := (Time.get_ticks_msec() - started) / 1000.0
	_check.call(game.player.down >= 1.0, "a queda chega a 1 (deitada)")
	_check.call(real >= 0.6 and real < 1.6,
			"a queda dura o mesmo tempo real em 3x (%.2f s, mundo parado)" % real)
	_check.call(mid_elapsed >= 0.35 and mid_elapsed <= 0.8,
			"a sequência anda em tempo real, não em tempo de jogo (%.2f s)" % mid_elapsed)
	_check.call(is_equal_approx(GameClock.game_time, frozen), "o tempo de jogo não anda durante a morte")
	await _wait_until(func() -> bool: return game.death.notice_open(), 2.0)
	var p := game.player
	_check.call(game.death.notice_open() and ends.is_empty(), "o aviso da morte aparece antes do fim da partida")
	_check.call(p.down == 1.0 and p.chill >= 0.99 and p.glow == 0.0,
			"o corpo fica deitado, frio e com a lanterna apagada")
	_check.call(game.camera.zoom.x > 1.05, "a câmera se aproxima do corpo (zoom %.2f)" % game.camera.zoom.x)
	_check.call(game.hud.gameplay_alpha() == 0.0 and not game.hud.joystick.is_processing_input(),
			"a HUD de jogo some e o joystick para de ler o toque")
	_check.call(game.death._grade_rect.visible, "o mundo perde a cor (shader de morte ligado)")
	_check.call(game.fx.wisps_alive() > 0, "a lanterna solta fiapos de fumaça")
	_check.call(AudioManager.music_volume_db() <= AudioManager.MUSIC_SILENT + 1.0, "a música some na morte")
	_check.call(game.death._sub.text.contains(Screen.format_time(GameClock.game_time)),
			"o aviso mostra o tempo resistido")
	# Toque antes da trava: ignorado.
	_tap(game)
	_check.call(ends.is_empty(), "toque logo no começo do aviso não pula (trava de %.1f s)" % DeathSequence.NOTICE_GUARD)
	await _wait_until(func() -> bool: return game.death.can_skip(), 2.0)
	_tap(game)
	_check.call(ends.size() == 1 and bool(ends[0]["notice"]) and not bool(ends[0]["victory"]),
			"toque depois da trava encerra a partida (derrota) uma vez")
	_check.call(float(ends[0]["notice_time"]) < DeathSequence.NOTICE_AUTO if not ends.is_empty() else false,
			"o toque pula antes do tempo do aviso acabar")
	_tap(game)
	game.open_pause()
	await _seconds(0.3)
	_check.call(ends.size() == 1 and not game.running, "mais toques e 'voltar' não encerram de novo")
	_check.call(int(AudioManager.request_count.get("jingle_gameover", 0)) == jingles + 1,
			"o jingle de derrota toca uma vez só")
	_check.call(AudioManager.music_id() == "defeat", "a música de derrota começa com os resultados")
	_check.call(game.player.down == 1.0, "o corpo continua no chão até a tela mudar")
	_test_framing(game)
	GameClock.speed = 1
	await _free(game)


## Câmera na morte: zoom final e o corpo no terço de cima, acima da faixa do aviso.
func _test_framing(game: HyakkiGame) -> void:
	var view := game.view_size()
	var cam := game.camera
	var offset := game.death.corpse_center() - cam.get_screen_center_position()
	var corpse_y := offset.y * cam.zoom.y + view.y * 0.5
	_check.call(is_equal_approx(cam.zoom.x, DeathSequence.ZOOM_TO), "zoom final no corpo (%.2f)" % cam.zoom.x)
	# Em frações da tela (a janela dos testes não tem o tamanho do jogo).
	_check.call(absf(corpse_y / view.y - DeathSequence.FOCUS_Y) < 0.03,
			"o corpo fica a %.0f%% da altura (%.2f)" % [DeathSequence.FOCUS_Y * 100.0, corpse_y / view.y])
	var game_h := HyakkiGame.FALLBACK_VIEW.y
	_check.call(game_h * DeathSequence.FOCUS_Y + 16.0 < game_h * DeathSequence.BAND_Y - DeathSequence.BAND_HALF,
			"em 678x305 o corpo fica acima da faixa do aviso")


## Reviver aceito e recompensado: levanta, a cor, a câmera, a música e a HUD voltam.
func _test_revive_rise() -> void:
	AdsManager.mock_fill = true
	AdsManager.auto_answer = true
	var game := await _new_game()
	var ends := [0]
	game.finished.connect(func(_r: Dictionary) -> void: ends[0] += 1)
	_kill(game)
	await _seconds(0.3)
	_check.call(not game.hud.revive_open(), "a oferta de reviver não aparece durante a queda")
	await _wait_until(func() -> bool: return game.hud.revive_open(), 2.0)
	_check.call(game.hud.revive_open() and game.player.down == 1.0 and game.death.elapsed >= DeathSequence.OFFER_AT,
			"a oferta aparece com o corpo já no chão")
	_check.call(not game.death.notice_open(), "com a oferta, o aviso da morte espera a resposta")
	game.hud._revive_panel.visible = false
	game.hud.revive_answered.emit(true)
	await _wait_until(func() -> bool: return game.death.phase == DeathSequence.Phase.RISING, 3.0)
	_check.call(game.death.phase == DeathSequence.Phase.RISING, "anúncio recompensado: a guardiã se levanta")
	await _wait_until(func() -> bool: return not game.death.is_active(), 3.0)
	var p := game.player
	_check.call(p.is_alive and p.down == 0.0 and p.chill == 0.0 and p.glow == 1.0,
			"depois do reviver: de pé, com a cor e a lanterna de volta")
	_check.call(is_equal_approx(game.camera.zoom.x, 1.0) and game.camera.position == Vector2.ZERO
			and not game.death._grade_rect.visible,
			"depois do reviver: câmera e cores normais")
	_check.call(game.hud.gameplay_alpha() == 1.0 and game.hud.joystick.is_processing_input(),
			"depois do reviver: a HUD de jogo volta e o joystick responde")
	await _wait_until(func() -> bool: return not GameClock.paused, 3.0)
	_check.call(game.running and not GameClock.paused and ends[0] == 0, "a partida segue depois do reviver")
	await _seconds(0.9)
	_check.call(AudioManager.music_volume_db() > -3.0, "a música volta depois do reviver")
	await _free(game)


## Partida salva durante a morte: o corpo já aparece deitado e o aviso vem na hora; sem
## toque, o aviso acaba sozinho e a partida termina uma vez.
func _test_restore_and_timeout() -> void:
	AdsManager.mock_fill = false
	var game := await _new_game()
	_kill(game)
	var snap: Dictionary = JSON.parse_string(JSON.stringify(game.snapshot()))
	await _free(game)
	var again := _spawn(snap["config"])
	await _host.get_tree().process_frame
	var ends := [0]
	again.finished.connect(func(_r: Dictionary) -> void: ends[0] += 1)
	again.restore_snapshot(snap)
	_check.call(again.player.down == 1.0 and not again.player.is_alive and again.death.notice_open(),
			"partida salva na morte volta com o corpo deitado e o aviso")
	_check.call(not again.hud.pause_open(), "partida salva na morte não abre a pausa")
	await _seconds(DeathSequence.NOTICE_AUTO - 0.6)
	_check.call(ends[0] == 0, "o aviso fica na tela até o tempo acabar")
	await _wait_until(func() -> bool: return ends[0] > 0, 2.0)
	_check.call(ends[0] == 1 and not again.running, "sem toque, o aviso acaba sozinho e encerra a partida")
	await _seconds(0.3)
	_check.call(ends[0] == 1, "o fim da partida sai uma vez só")
	await _free(again)


## O bot (testes sem cabeça) e o "desistir" da pausa vão direto ao fim, sem a sequência.
func _test_bot_and_give_up() -> void:
	AdsManager.mock_fill = false
	var game := await _new_game()
	game._bot = true
	var ends := [0]
	game.finished.connect(func(_r: Dictionary) -> void: ends[0] += 1)
	_kill(game)
	_check.call(not game.death.is_active() and not game.running, "bot: a morte encerra na hora, sem a sequência")
	await _host.get_tree().process_frame
	await _free(game)

	var quitter := await _new_game()
	var results: Array[Dictionary] = []
	quitter.finished.connect(func(r: Dictionary) -> void: results.append(r))
	quitter.open_pause()
	quitter.hud.quit_pressed.emit()
	_check.call(results.size() == 1 and bool(results[0]["gave_up"]) and not quitter.death.is_active(),
			"desistir vai direto aos resultados, sem a queda")
	_check.call(quitter.player.down == 0.0, "desistir não derruba a guardiã")
	await _free(quitter)


func _new_game() -> HyakkiGame:
	var game := _spawn(CONFIG)
	await _host.get_tree().process_frame
	game.player.god_mode = false
	game.player.revives_used = 99
	return game


func _spawn(cfg: Dictionary) -> HyakkiGame:
	var game := (load(GAME_SCENE) as PackedScene).instantiate() as HyakkiGame
	game.config = cfg.duplicate()
	_host.add_child(game)
	return game


func _kill(game: HyakkiGame) -> void:
	game.player.invuln = 0.0
	game.player.take_damage(99999.0, &"kappa")


## Toque de verdade no aviso (o mesmo caminho do dedo na tela).
func _tap(game: HyakkiGame) -> void:
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = game.view_size() * 0.5
	game.death._input(touch)


func _free(game: HyakkiGame) -> void:
	game.queue_free()
	GameClock.paused = false
	await _host.get_tree().process_frame


func _seconds(value: float) -> void:
	await _host.get_tree().create_timer(value).timeout


func _wait_until(condition: Callable, timeout: float) -> void:
	var waited := 0.0
	while not bool(condition.call()) and waited < timeout:
		await _host.get_tree().create_timer(0.05).timeout
		waited += 0.05
