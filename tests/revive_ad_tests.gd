extends RefCounted
## Reviver por anúncio: uma morte, uma oferta, um anúncio só. Toques repetidos no botão
## "Reviver", o sinal revive_answered emitido de novo, o tempo da oferta acabando com o anúncio
## na tela e pedidos ao AdsManager com um anúncio já aberto nunca mostram um segundo anúncio;
## a recompensa ainda levanta a guardiã e fechar antes do fim leva ao aviso da morte.
## Usa um provedor AdMob falso (FakeAdMob) que conta cada anúncio mostrado e segura o fim dele
## até o teste decidir, como o SDK real com o anúncio em tela cheia, e o simulado na tela.
## Chamado por tests/integration_tests.gd, que passa o nó da cena e o _check.

const GAME_SCENE := "res://scenes/game/Game.tscn"
const CONFIG := {"hero": "goro", "stage": "bamboo", "moon": 0, "mode": "normal", "seed": 29, "speed": 1}


## Provedor AdMob de mentira: sempre com anúncio carregado; cada show_rewarded conta um
## anúncio na tela, que só fecha quando o teste chama close().
class FakeAdMob extends AdMobProvider:
	var shows: int = 0
	var _pending: Callable

	func rewarded_ready() -> bool:
		return true

	func show_rewarded(done: Callable) -> void:
		shows += 1
		_pending = done

	func is_open() -> bool:
		return _pending.is_valid()

	func close(rewarded: bool) -> void:
		var done := _pending
		_pending = Callable()
		done.call(rewarded)


var _host: Node
var _check: Callable
var _fake: FakeAdMob


func run(host: Node, check: Callable) -> void:
	_host = host
	_check = check
	var saved := {"provider": AdsManager.provider, "admob": AdsManager._admob, "enabled": AdsManager.ads_enabled,
			"fill": AdsManager.mock_fill, "auto": AdsManager.auto_answer}
	SaveManager.data = SaveManager.default_profile()
	AdsManager.ads_enabled = true
	AdsManager.mock_fill = true
	AdsManager.auto_answer = false
	_fake = FakeAdMob.new()
	AdsManager.provider = "admob"
	AdsManager._admob = _fake
	_test_manager_reentry()
	await _test_revive_taps()
	await _test_revive_closed_early()
	AdsManager.provider = String(saved["provider"])
	AdsManager._admob = saved["admob"]
	_fake.free()
	await _test_mock_overlay_once()
	AdsManager.ads_enabled = bool(saved["enabled"])
	AdsManager.mock_fill = bool(saved["fill"])
	AdsManager.auto_answer = bool(saved["auto"])
	_host.get_tree().paused = false
	SaveManager.data = SaveManager.default_profile()


## AdsManager: com um anúncio na tela, outro pedido não abre nada nem responde por ele.
func _test_manager_reentry() -> void:
	var calls: Array[bool] = []
	var second: Array[bool] = []
	AdsManager.show_rewarded("test", func(rewarded: bool) -> void: calls.append(rewarded))
	_check.call(_fake.shows == 1 and AdsManager.is_showing(), "AdsManager: o pedido abre um anúncio")
	AdsManager.show_rewarded("test", func(rewarded: bool) -> void: second.append(rewarded))
	AdsManager.show_rewarded("revive", func(rewarded: bool) -> void: second.append(rewarded))
	_check.call(_fake.shows == 1 and second.is_empty(),
			"AdsManager: pedidos com o anúncio na tela são ignorados (%d anúncio(s))" % _fake.shows)
	_fake.close(true)
	_check.call(calls == [true] and second.is_empty() and not AdsManager.is_showing(),
			"AdsManager: o anúncio responde uma vez só, e só para quem pediu")
	_check.call(not _host.get_tree().paused, "AdsManager: o jogo sai da pausa ao fechar o anúncio")
	AdsManager.show_rewarded("test", func(rewarded: bool) -> void: calls.append(rewarded))
	_check.call(_fake.shows == 2, "AdsManager: depois de fechar, o próximo pedido abre outro anúncio")
	_fake.close(false)
	_check.call(calls == [true, false] and not AdsManager.is_showing(),
			"AdsManager: fechar antes do fim responde sem recompensa e libera o próximo")
	_fake.shows = 0


## Toques repetidos no "Reviver", o sinal de novo e o tempo esgotado: um anúncio só; a
## recompensa levanta a guardiã e um sinal tardio depois do reviver não abre nada.
func _test_revive_taps() -> void:
	var game := await _dead_game()
	_check.call(game.hud.revive_open(), "reviver: a oferta aparece com o provedor AdMob")
	var watch := game.hud.get("_revive_watch") as Button
	for i: int in range(3):
		watch.pressed.emit()
	game.hud.revive_answered.emit(true)
	game.hud.revive_answered.emit(true)
	await _host.get_tree().process_frame
	_check.call(_fake.shows == 1 and _fake.is_open(),
			"reviver: 3 toques e 2 sinais extras mostram 1 anúncio (%d)" % _fake.shows)
	# O tempo da oferta acabando (ou "Ver resultados") com o anúncio na tela não corta o anúncio.
	game.hud.revive_answered.emit(false)
	game.hud.set("_revive_left", 0.0)
	await _host.get_tree().process_frame
	_check.call(not game.death.notice_open() and game.death.phase == DeathSequence.Phase.DYING
			and _fake.shows == 1, "reviver: recusa e tempo esgotado durante o anúncio são ignorados")
	_fake.close(true)
	await _wait_until(func() -> bool: return game.death.phase == DeathSequence.Phase.RISING, 3.0)
	_check.call(game.death.phase == DeathSequence.Phase.RISING and game.tracker.revived_by_ad,
			"reviver: a recompensa levanta a guardiã")
	await _wait_until(func() -> bool: return not game.death.is_active(), 3.0)
	_check.call(game.player.is_alive and game.running, "reviver: a partida segue depois do anúncio")
	game.hud.revive_answered.emit(true)
	watch.pressed.emit()
	await _host.get_tree().process_frame
	_check.call(_fake.shows == 1 and not _fake.is_open(),
			"reviver: sinal ou toque depois do reviver não abrem outro anúncio")
	await _free(game)
	_fake.shows = 0


## Fechar antes do fim: sem recompensa, vai ao aviso da morte, e nada abre outro anúncio.
func _test_revive_closed_early() -> void:
	var game := await _dead_game()
	var ends := [0]
	game.finished.connect(func(_r: Dictionary) -> void: ends[0] += 1)
	var watch := game.hud.get("_revive_watch") as Button
	watch.pressed.emit()
	watch.pressed.emit()
	_fake.close(false)
	await _host.get_tree().process_frame
	watch.pressed.emit()
	game.hud.revive_answered.emit(true)
	await _wait_until(func() -> bool: return game.death.notice_open(), 3.0)
	_check.call(_fake.shows == 1 and not _fake.is_open() and game.death.notice_open()
			and not game.player.is_alive and not game.tracker.revived_by_ad,
			"reviver: fechar antes do fim mostra o aviso da morte, sem segundo anúncio")
	_check.call(not game.hud.revive_open(), "reviver: a oferta não volta depois de fechar o anúncio")
	await _free(game)
	_fake.shows = 0


## Simulado (PC e testes): 3 toques no "Reviver" abrem uma tela de anúncio só.
func _test_mock_overlay_once() -> void:
	AdsManager.auto_answer = true
	var game := await _dead_game()
	var layers := _ad_layers()
	var watch := game.hud.get("_revive_watch") as Button
	for i: int in range(3):
		watch.pressed.emit()
	game.hud.revive_answered.emit(true)
	_check.call(_ad_layers() == layers + 1,
			"simulado: 3 toques abrem uma tela de anúncio só (%d)" % (_ad_layers() - layers))
	await _wait_until(func() -> bool:
		return game.player.is_alive and not game.death.is_active(), 6.0)
	_check.call(game.player.is_alive and game.tracker.revived_by_ad and _ad_layers() == layers,
			"simulado: a recompensa revive e a tela do anúncio fecha")
	await _free(game)


func _ad_layers() -> int:
	var count := 0
	for child: Node in AdsManager.get_children():
		if child is CanvasLayer and not child.is_queued_for_deletion():
			count += 1
	return count


## Partida nova com a guardiã morta e a oferta de reviver aberta.
func _dead_game() -> HyakkiGame:
	var game := (load(GAME_SCENE) as PackedScene).instantiate() as HyakkiGame
	game.config = CONFIG.duplicate()
	_host.add_child(game)
	await _host.get_tree().process_frame
	game.player.god_mode = false
	game.player.revives_used = 99
	game.player.invuln = 0.0
	game.player.take_damage(99999.0, &"kappa")
	await _wait_until(func() -> bool: return game.hud.revive_open(), 3.0)
	return game


func _free(game: HyakkiGame) -> void:
	game.queue_free()
	GameClock.paused = false
	_host.get_tree().paused = false
	await _host.get_tree().process_frame


func _wait_until(condition: Callable, timeout: float) -> void:
	var waited := 0.0
	while not bool(condition.call()) and waited < timeout:
		await _host.get_tree().create_timer(0.05).timeout
		waited += 0.05
