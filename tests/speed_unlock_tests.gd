extends RefCounted
## Ampulheta de Fūjin (velocidade 2x/3x como compra única, PurchaseManager.SPEED_PRODUCT):
## - compra com ryō: debita e libera; sem saldo falha sem debitar; não compra duas vezes;
## - compra com dinheiro (simulada): libera; pendente não libera e não mistura com o pendente do
##   "Remover anúncio"; restaurar entrega o pendente confirmado;
## - reembolso da Play revoga só a posse que veio da Play (a do ryō fica); ryō + Play vira Play;
## - Play Billing com vários produtos: preço, compra e reembolso por produto;
## - save antigo (sem as chaves novas) carrega sem erro e sem a posse;
## - na partida: sem a posse começa em 1x mesmo com 3x salvo nas opções e no config, e o toque
##   (HUD, pausa, teclado) não acelera: treme, toca o negado e avisa; com a posse cicla
##   1 → 2 → 3 → 1; comprar no meio da partida libera na hora e o reembolso volta a 1x; o bot
##   acelera sem a posse (determinismo e estresse).
## Chamado por tests/integration_tests.gd, que passa o nó da cena e o _check.

const GAME_SCENE := "res://scenes/game/Game.tscn"
const CONFIG := {"hero": "aki", "stage": "village", "moon": 0, "mode": "normal", "seed": 31, "speed": 3}

var _host: Node
var _check: Callable


func run(host: Node, check: Callable) -> void:
	_host = host
	_check = check
	var saved_speed: Variant = Settings.get_value("speed")
	_test_ryo_purchase()
	_test_money_purchase()
	_test_refund()
	_test_play_provider()
	_test_migration()
	_test_price_text()
	await _test_locked_run()
	await _test_owned_run()
	await _test_unlock_mid_run()
	await _test_bot_run()
	Settings.set_value("speed", saved_speed)
	GameClock.speed = 1
	GameClock.max_speed = GameClock.SPEEDS[-1]
	GameClock.free_speed = false
	GameClock.paused = true
	SaveManager.data = SaveManager.default_profile()


func _fresh() -> void:
	SaveManager.data = SaveManager.default_profile()
	PurchaseManager.mock_pending = false


func _test_ryo_purchase() -> void:
	_fresh()
	var price := PurchaseManager.SPEED_RYO_PRICE
	var events := {"unlocked": 0}
	var on_unlock := func() -> void: events["unlocked"] = int(events["unlocked"]) + 1
	PurchaseManager.speed_unlocked.connect(on_unlock)
	SaveManager.data["ryo"] = price - 1
	_check.call(not PurchaseManager.can_buy_speed_with_ryo() and not PurchaseManager.buy_speed_with_ryo(),
			"Ampulheta: sem ryō suficiente a compra falha")
	_check.call(SaveManager.ryo() == price - 1 and not PurchaseManager.owns_speed(),
			"Ampulheta: compra que falha não debita nem libera")
	SaveManager.data["ryo"] = price + 7
	_check.call(PurchaseManager.buy_speed_with_ryo(), "Ampulheta: com %d ryō a compra passa" % price)
	_check.call(SaveManager.ryo() == 7 and PurchaseManager.owns_speed() and PurchaseManager.speed_source() == "ryo",
			"Ampulheta: compra com ryō debita %d e libera com origem ryō" % price)
	_check.call(int(events["unlocked"]) == 1, "Ampulheta: speed_unlocked avisa a partida uma vez")
	SaveManager.data["ryo"] = price * 2
	_check.call(not PurchaseManager.buy_speed_with_ryo() and SaveManager.ryo() == price * 2,
			"Ampulheta: não compra duas vezes (nem debita)")
	_check.call(not PurchaseManager.speed_available_for_money(), "Ampulheta: liberada, some a compra com dinheiro")
	PurchaseManager.speed_unlocked.disconnect(on_unlock)
	# Reembolso do Santuário devolve só os power-ups: a Ampulheta não volta em ryō e fica.
	_fresh()
	SaveManager.data["ryo"] = price + 1000
	_check.call(MetaProgress.buy(&"pu_might"), "Ampulheta: compra um power-up antes")
	var after_powerup := SaveManager.ryo()
	PurchaseManager.buy_speed_with_ryo()
	var refunded := MetaProgress.refund_all()
	_check.call(refunded == price + 1000 - after_powerup and SaveManager.ryo() == price + 1000 - price,
			"Ampulheta: reembolso do Santuário não devolve os %d ryō dela (devolveu %d)" % [price, refunded])
	_check.call(PurchaseManager.owns_speed() and PurchaseManager.speed_source() == "ryo",
			"Ampulheta: depois do reembolso do Santuário a posse continua")
	_fresh()


func _test_money_purchase() -> void:
	_fresh()
	_check.call(PurchaseManager.provider == "mock" and PurchaseManager.billing_available(),
			"Ampulheta: no PC a compra com dinheiro é simulada")
	var answers: Array = []
	var listener := func(product: String, ok: bool) -> void: answers.append([product, ok])
	PurchaseManager.purchase_finished.connect(listener)
	PurchaseManager.mock_pending = true
	PurchaseManager.buy_speed_with_money()
	_check.call(not PurchaseManager.owns_speed() and PurchaseManager.is_pending(PurchaseManager.SPEED_PRODUCT)
			and answers == [[PurchaseManager.SPEED_PRODUCT, false]], "Ampulheta: pagamento pendente não libera")
	_check.call(not PurchaseManager.is_pending(PurchaseManager.PRODUCT),
			"Ampulheta: o pendente dela não vira pendente do Remover anúncio")
	PurchaseManager.restore()
	_check.call(not PurchaseManager.owns_speed(), "Ampulheta: restaurar com o pagamento ainda pendente não libera")
	PurchaseManager.mock_pending = false
	PurchaseManager.restore()
	_check.call(PurchaseManager.owns_speed() and PurchaseManager.speed_source() == "play"
			and not PurchaseManager.is_pending(PurchaseManager.SPEED_PRODUCT),
			"Ampulheta: pagamento confirmado é entregue ao restaurar (origem Play)")
	_check.call(not PurchaseManager.owns(), "Ampulheta: liberar a velocidade não remove o anúncio de abertura")
	_fresh()
	answers.clear()
	PurchaseManager.purchase(PurchaseManager.SPEED_PRODUCT)
	_check.call(PurchaseManager.owns_speed() and answers == [[PurchaseManager.SPEED_PRODUCT, true]],
			"Ampulheta: compra simulada com dinheiro libera na hora")
	PurchaseManager.purchase("produto_que_nao_existe")
	_check.call(answers.back() == ["produto_que_nao_existe", false], "compra de produto desconhecido falha")
	PurchaseManager.purchase_finished.disconnect(listener)
	_fresh()


func _test_refund() -> void:
	var revoked := {"count": 0}
	var on_revoke := func() -> void: revoked["count"] = int(revoked["count"]) + 1
	PurchaseManager.speed_revoked.connect(on_revoke)
	_fresh()
	PurchaseManager.purchase(PurchaseManager.SPEED_PRODUCT)
	PurchaseManager.call("_on_play_state", PurchaseManager.SPEED_PRODUCT, "refunded")
	_check.call(not PurchaseManager.owns_speed() and int(revoked["count"]) == 1,
			"Ampulheta: reembolso da Play revoga a posse que veio da Play")
	_fresh()
	SaveManager.data["ryo"] = PurchaseManager.SPEED_RYO_PRICE
	PurchaseManager.buy_speed_with_ryo()
	PurchaseManager.call("_on_play_state", PurchaseManager.SPEED_PRODUCT, "refunded")
	PurchaseManager.mock_refund(PurchaseManager.SPEED_PRODUCT)
	_check.call(PurchaseManager.owns_speed() and PurchaseManager.speed_source() == "ryo" and int(revoked["count"]) == 1,
			"Ampulheta: quem comprou com ryō nunca perde (ausência na Play não revoga)")
	PurchaseManager.call("_on_play_state", PurchaseManager.SPEED_PRODUCT, "purchased")
	_check.call(PurchaseManager.owns_speed() and PurchaseManager.speed_source() == "play",
			"Ampulheta: com ryō e depois paga na Play, fica com origem Play")
	_check.call(SaveManager.ryo() == 0, "Ampulheta: a confirmação da Play não devolve nem cobra ryō")
	PurchaseManager.call("_on_play_state", PurchaseManager.SPEED_PRODUCT, "pending")
	_check.call(PurchaseManager.owns_speed(), "Ampulheta: um pendente depois da posse não revoga")
	# O "Remover anúncio" segue com a regra de antes (reembolso faz o anúncio voltar).
	_fresh()
	PurchaseManager.purchase(PurchaseManager.PRODUCT)
	PurchaseManager.call("_on_play_state", PurchaseManager.PRODUCT, "refunded")
	_check.call(not PurchaseManager.owns() and not PurchaseManager.owns_speed(),
			"reembolso do Remover anúncio não mexe na Ampulheta")
	PurchaseManager.speed_revoked.disconnect(on_revoke)
	_fresh()


## PlayBillingProvider com os dois produtos, sem o plugin: preços, consulta e falhas por produto.
func _test_play_provider() -> void:
	var play := PlayBillingProvider.new()
	play.set("_products", PackedStringArray([PurchaseManager.PRODUCT, PurchaseManager.SPEED_PRODUCT]))
	var states: Array = []
	play.purchase_state.connect(func(product: String, state: String) -> void: states.append([product, state]))
	var ok := BillingClient.BillingResponseCode.OK
	play.call("_on_product_details", {"response_code": ok, "product_details": [
			{"product_id": PurchaseManager.SPEED_PRODUCT, "one_time_purchase_offer_details": {"formatted_price": "R$ 4,99"}},
			{"product_id": PurchaseManager.PRODUCT, "one_time_purchase_offer_details": {"formatted_price": "R$ 14,90"}}]})
	_check.call(play.price_of(PurchaseManager.SPEED_PRODUCT) == "R$ 4,99"
			and play.price_of(PurchaseManager.PRODUCT) == "R$ 14,90", "Play: preço de cada produto")
	play.call("_on_purchases", {"response_code": ok, "purchases": [{"product_ids": [PurchaseManager.SPEED_PRODUCT],
			"purchase_state": BillingClient.PurchaseState.PURCHASED, "is_acknowledged": true}]}, true)
	_check.call(states.has([PurchaseManager.SPEED_PRODUCT, "purchased"])
			and states.has([PurchaseManager.PRODUCT, "refunded"])
			and not states.has([PurchaseManager.SPEED_PRODUCT, "refunded"]),
			"Play: a consulta entrega o que veio e marca como reembolsado só o produto ausente")
	states.clear()
	play.call("_on_purchases", {"response_code": ok, "purchases": [{"product_ids": [PurchaseManager.SPEED_PRODUCT],
			"purchase_state": BillingClient.PurchaseState.PENDING}]}, false)
	_check.call(states == [[PurchaseManager.SPEED_PRODUCT, "pending"]], "Play: pendente por produto")
	states.clear()
	play.purchase(PurchaseManager.SPEED_PRODUCT)
	play.call("_on_purchases", {"response_code": BillingClient.BillingResponseCode.USER_CANCELED}, false)
	_check.call(states.size() == 2 and states.all(func(e: Array) -> bool:
			return e == [PurchaseManager.SPEED_PRODUCT, "failed"]),
			"Play: sem conexão e cancelada, a compra falha pelo produto pedido")
	play.free()


## Save antigo (antes da Ampulheta): carrega sem erro, sem a posse e com o resto intacto.
func _test_migration() -> void:
	var old := {"version": 1, "ryo": 1234, "purchases": {"remove_open_ad": true, "pending": true,
			"acknowledged": true}}
	var migrated: Dictionary = SaveManager.migrate(JSON.parse_string(JSON.stringify(old)))
	var purchases: Dictionary = migrated["purchases"]
	_check.call(purchases.has("unlock_speed") and not bool(purchases["unlock_speed"])
			and String(purchases["unlock_speed_source"]) == "" and not bool(purchases["unlock_speed_pending"]),
			"migração: save antigo ganha a Ampulheta sem posse e sem pendente")
	_check.call(bool(purchases["remove_open_ad"]) and bool(purchases["pending"]) and int(migrated["ryo"]) == 1234,
			"migração: compra e pendente antigos do Remover anúncio ficam")
	SaveManager.data = migrated
	_check.call(not PurchaseManager.owns_speed() and PurchaseManager.speed_source() == ""
			and not PurchaseManager.is_pending(PurchaseManager.SPEED_PRODUCT), "migração: sem posse da velocidade")
	_fresh()


func _test_price_text() -> void:
	Locale.set_language("pt_BR", false)
	_check.call(PurchaseManager.speed_price_text() == PurchaseManager.SPEED_PRICE_BRL,
			"Ampulheta: preço de referência em pt_BR é %s" % PurchaseManager.SPEED_PRICE_BRL)
	Locale.set_language("en", false)
	_check.call(PurchaseManager.speed_price_text() == PurchaseManager.SPEED_PRICE_USD,
			"Ampulheta: preço de referência nos outros idiomas é %s" % PurchaseManager.SPEED_PRICE_USD)
	Locale.set_language("pt_BR", false)


# --- Partida -----------------------------------------------------------------------------

func _test_locked_run() -> void:
	_fresh()
	SaveManager.data["stats"]["runs"] = 3
	Settings.set_value("speed", 3)
	var game := await _new_game(CONFIG)
	_check.call(GameClock.speed == 1 and GameClock.max_speed == 1,
			"sem a Ampulheta a partida começa em 1x mesmo com 3x salvo e no config")
	_check.call(int(Settings.get_value("speed")) == 1, "sem a Ampulheta o 3x salvo nas opções volta a 1x")
	var hud := game.hud
	var button := hud.get("_speed_button") as Button
	_check.call(button.visible and hud.speed_locked() and hud.speed_shown() == 1,
			"sem a Ampulheta o botão aparece (a partir da 2ª partida) com o cadeado e 1x")
	_check.call(button.tooltip_text == tr("speed.locked"), "o botão bloqueado diz onde liberar")
	button.pressed.emit()
	_check.call(GameClock.speed == 1 and not GameClock.paused, "toque no botão bloqueado não acelera nem pausa")
	_check.call(hud.speed_denied() and is_equal_approx(button.scale.x, 1.0),
			"toque bloqueado treme (negado) em vez do soco de escala")
	var toast := hud.get("_toast") as Label
	_check.call(toast.visible and toast.text == tr("speed.locked"), "toque bloqueado avisa \"%s\"" % tr("speed.locked"))
	_check.call(not hud.overlay_open() and game.running, "toque bloqueado não abre tela nenhuma")
	game.cycle_speed()
	_check.call(GameClock.speed == 1, "teclado (Tab) sem a Ampulheta não acelera")
	await _seconds(0.45)
	_check.call(not hud.speed_denied(), "a tremida de negado é curta")
	game.open_pause()
	var menu := hud.pause_menu()
	_check.call((menu.get("_speed_lock") as Control).is_visible_in_tree(),
			"a pausa mostra o cadeado na velocidade")
	(menu.get("_speed") as Button).pressed.emit()
	_check.call(GameClock.speed == 1 and (menu.get("_speed_value") as Label).text == "1x"
			and hud.pause_open(), "velocidade bloqueada na pausa fica em 1x e a pausa continua")
	var notice := menu.get("_notice") as FloatingNotice
	_check.call(notice.is_open() and notice.label.text == tr("speed.locked"),
			"a pausa avisa onde liberar")
	await _free(game)
	_fresh()


func _test_owned_run() -> void:
	_fresh()
	SaveManager.data["purchases"]["unlock_speed"] = true
	SaveManager.data["purchases"]["unlock_speed_source"] = "ryo"
	Settings.set_value("speed", 1)
	var cfg := CONFIG.duplicate()
	cfg["speed"] = 1
	var game := await _new_game(cfg)
	_check.call(not game.hud.speed_locked() and GameClock.max_speed == 3, "com a Ampulheta o botão fica livre")
	var seen: Array[int] = []
	for i: int in 3:
		game.cycle_speed()
		seen.append(GameClock.speed)
	_check.call(seen == [2, 3, 1], "com a Ampulheta a velocidade cicla 1 → 2 → 3 → 1 (%s)" % [seen])
	await _free(game)
	cfg["speed"] = 3
	game = await _new_game(cfg)
	_check.call(GameClock.speed == 3, "com a Ampulheta o 3x salvo vale ao começar")
	await _free(game)
	_fresh()


## Compra no meio da partida (ex.: a Play confirma ao abrir): libera sem reiniciar; reembolso
## da Play no meio da partida volta a 1x e tranca de novo.
func _test_unlock_mid_run() -> void:
	_fresh()
	var game := await _new_game(CONFIG)
	_check.call(game.hud.speed_locked(), "partida começa bloqueada")
	SaveManager.data["ryo"] = PurchaseManager.SPEED_RYO_PRICE
	PurchaseManager.buy_speed_with_ryo()
	_check.call(not game.hud.speed_locked() and not (game.hud.pause_menu().get("_speed_lock") as Control).visible,
			"comprar libera o botão na hora, sem reiniciar")
	game.cycle_speed()
	_check.call(GameClock.speed == 2, "depois da compra o toque acelera para 2x")
	await _free(game)
	_fresh()
	PurchaseManager.purchase(PurchaseManager.SPEED_PRODUCT)
	game = await _new_game(CONFIG)
	_check.call(GameClock.speed == 3, "comprada na Play, a partida começa no 3x pedido")
	PurchaseManager.call("_on_play_state", PurchaseManager.SPEED_PRODUCT, "refunded")
	_check.call(GameClock.speed == 1 and game.hud.speed_locked(), "reembolso no meio da partida volta a 1x e tranca")
	await _free(game)
	_fresh()


## Bot (determinismo e estresse): acelera sem a compra.
func _test_bot_run() -> void:
	_fresh()
	var game := (load(GAME_SCENE) as PackedScene).instantiate() as HyakkiGame
	game.config = CONFIG.duplicate()
	game.set("_bot", true)
	_host.add_child(game)
	await _host.get_tree().process_frame
	_check.call(GameClock.can_accelerate() and GameClock.speed == 3, "o bot acelera para 3x sem a Ampulheta")
	game.cycle_speed()
	_check.call(GameClock.speed == 1, "o bot cicla a velocidade sem a Ampulheta")
	await _free(game)
	_fresh()


func _new_game(cfg: Dictionary) -> HyakkiGame:
	var game := (load(GAME_SCENE) as PackedScene).instantiate() as HyakkiGame
	game.config = cfg.duplicate()
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
