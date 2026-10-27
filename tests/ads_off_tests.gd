extends RefCounted
## Modo "sem anúncios" (AdsManager.ads_enabled = false): build de release sem os IDs reais
## do AdMob, ou `--ads-off` no PC. Confere que o SDK/UMP não é usado, que não há anúncio de
## abertura nem consentimento, que cada recompensado entrega na hora sem tela nenhuma (Loja
## com a mesma espera de 6 h, Reviver e Dobrar ryō), que a compra "Remover anúncio de
## abertura" e "Privacidade e anúncios" somem e que os textos não prometem anúncio.
## Ao religar (`ads_enabled = true`) tudo volta ao comportamento com anúncios.
## Chamado por tests/integration_tests.gd, que passa o nó da cena e o _check.

const SHOP_SCREEN := "res://scripts/app/screens/shop_screen.gd"
const RESULTS_SCREEN := "res://scripts/app/screens/results_screen.gd"
const GAME_SCENE := "res://scenes/game/Game.tscn"
const SCREEN := Rect2(Vector2.ZERO, Vector2(678, 305))
const ShopLayoutTests := preload("res://tests/shop_layout_tests.gd")
const MenusLayoutTests := preload("res://tests/menus_layout_tests.gd")
const ResultsLayoutTests := preload("res://tests/results_layout_tests.gd")

var _host: Node
var _check: Callable


func run(host: Node, check: Callable) -> void:
	_host = host
	_check = check
	var was_enabled := AdsManager.ads_enabled
	var was_fill := AdsManager.mock_fill
	var was_auto := AdsManager.auto_answer
	AdsManager.ads_enabled = false
	# Nada de resposta automática do simulado: se algo pedir anúncio, o teste percebe.
	AdsManager.auto_answer = false
	AdsManager.mock_fill = false
	_test_manager()
	_test_shop_rewards()
	_test_purchase()
	await _test_shop_screen()
	await _test_results()
	await _test_options()
	await _test_boot()
	await _test_revive()
	AdsManager.ads_enabled = true
	AdsManager.mock_fill = true
	_test_back_to_ads()
	AdsManager.ads_enabled = was_enabled
	AdsManager.mock_fill = was_fill
	AdsManager.auto_answer = was_auto
	SaveManager.data = SaveManager.default_profile()
	Locale.set_language("pt_BR", false)


## Overlays que o AdsManager abriu (o simulado põe uma CanvasLayer filha dele).
func _ad_layers() -> int:
	var count := 0
	for child: Node in AdsManager.get_children():
		if child is CanvasLayer and not child.is_queued_for_deletion():
			count += 1
	return count


func _test_manager() -> void:
	SaveManager.data = SaveManager.default_profile()
	_check.call(not AdsManager.uses_google_consent(), "sem anúncios: nada do UMP do Google")
	_check.call(not AdsManager.open_privacy_options(func() -> void: pass),
			"sem anúncios: não abre o formulário de privacidade do AdMob")
	var started := {"done": false}
	AdsManager.start(func() -> void: started["done"] = true)
	_check.call(bool(started["done"]), "sem anúncios: start libera na hora (SDK não é iniciado)")
	SaveManager.data["launches"] = 9
	SaveManager.data["last_open_ad_unix"] = 0
	_check.call(not AdsManager.should_show_app_open(), "sem anúncios: nunca há anúncio de abertura")
	var layers := _ad_layers()
	var opened := {"done": false}
	AdsManager.show_app_open(func() -> void: opened["done"] = true)
	_check.call(bool(opened["done"]) and _ad_layers() == layers and int(SaveManager.data["open_ads_seen"]) == 0,
			"sem anúncios: show_app_open libera na hora, sem tela e sem contar anúncio visto")
	_check.call(AdsManager.rewarded_available(), "sem anúncios: a recompensa está sempre disponível")
	var got := {"rewarded": false, "calls": 0}
	AdsManager.show_rewarded("test", func(rewarded: bool) -> void:
		got["rewarded"] = rewarded
		got["calls"] = int(got["calls"]) + 1)
	_check.call(bool(got["rewarded"]) and int(got["calls"]) == 1, "sem anúncios: o recompensado entrega na hora")
	_check.call(_ad_layers() == layers, "sem anúncios: o recompensado não mostra tela nenhuma")
	_check.call(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")),
			"sem anúncios: o som do jogo não é silenciado")


## Loja: as vagas entregam de presente e mantêm a espera de 6 h (economia igual).
func _test_shop_rewards() -> void:
	SaveManager.data = SaveManager.default_profile()
	var before := SaveManager.ryo()
	var value := ShopManager.ryo_value()
	var result := {"ok": false}
	ShopManager.claim(&"slot_ryo", func(ok: bool) -> void: result["ok"] = ok)
	_check.call(bool(result["ok"]) and SaveManager.ryo() == before + value,
			"sem anúncios: a vaga de ryō entrega %d ryō na hora" % value)
	_check.call(ShopManager.seconds_left(&"slot_ryo") > ShopManager.COOLDOWN - 5,
			"sem anúncios: a vaga entra na mesma espera de 6 h")
	result["ok"] = true
	ShopManager.claim(&"slot_ryo", func(ok: bool) -> void: result["ok"] = ok)
	_check.call(not bool(result["ok"]) and SaveManager.ryo() == before + value,
			"sem anúncios: vaga em espera não entrega de novo")
	ShopManager.claim(&"slot_luck", func(ok: bool) -> void: result["ok"] = ok)
	_check.call(bool(result["ok"]) and ShopManager.pending_next_run().has("slot_luck"),
			"sem anúncios: a vaga de reforço fica guardada para a próxima partida")
	_check.call(ShopManager.is_ready(&"slot_lantern"), "sem anúncios: as outras vagas continuam prontas")
	SaveManager.data = SaveManager.default_profile()


## A compra "Remover anúncio de abertura" fica indisponível e nunca entrega.
func _test_purchase() -> void:
	SaveManager.data = SaveManager.default_profile()
	_check.call(not PurchaseManager.available(), "sem anúncios: a compra de remover anúncio não existe")
	var answers: Array = []
	var listener := func(_p: String, ok: bool) -> void: answers.append(ok)
	PurchaseManager.purchase_finished.connect(listener)
	PurchaseManager.purchase()
	PurchaseManager.purchase_finished.disconnect(listener)
	_check.call(not PurchaseManager.owns() and answers == [false],
			"sem anúncios: comprar não cobra nem entrega")
	SaveManager.data["purchases"]["pending"] = true
	PurchaseManager.restore()
	_check.call(not PurchaseManager.owns(), "sem anúncios: restaurar não entrega nada")
	SaveManager.data = SaveManager.default_profile()


## Loja em cada idioma: "Receber grátis" nas vagas, subtítulo de presente, sem "Apoie o
## jogo" e layout íntegro; um toque entrega na hora.
func _test_shop_screen() -> void:
	var layout := ShopLayoutTests.new()
	layout.set("_host", _host)
	layout.set("_check", _check)
	var view := Rect2(Vector2.ZERO, Vector2(678, 305 - 8))
	for lang: String in Locale.SUPPORTED:
		Locale.set_language(lang, false)
		SaveManager.data = SaveManager.default_profile()
		var screen := await _open_shop()
		var cards: Dictionary = screen.get("_cards")
		var all_free := true
		for id: StringName in cards:
			var state := cards[id]["state"] as Label
			var b := cards[id]["button"] as Button
			all_free = all_free and not b.disabled and state.text == "> %s" % tr("shop.claim_free")
		_check.call(all_free, "%s: sem anúncios as vagas dizem \"%s\"" % [lang, tr("shop.claim_free")])
		var hint := screen.get("_offer_hint") as Label
		_check.call(hint.text == tr("shop.hint_free"), "%s: subtítulo das Oferendas fala de presente" % lang)
		var buy := screen.get("_buy") as Button
		var restore := screen.get("_restore") as Button
		_check.call(not buy.is_visible_in_tree() and not restore.is_visible_in_tree(),
				"%s: sem anúncios a compra e a restauração somem da Loja" % lang)
		layout.check_layout(screen, view, "%s, sem anúncios" % lang)
		if lang == "pt_BR":
			var before := SaveManager.ryo()
			screen.call("_claim", &"slot_ryo")
			await _host.get_tree().process_frame
			_check.call(SaveManager.ryo() > before and not ShopManager.is_ready(&"slot_ryo"),
					"Loja sem anúncios: tocar na vaga entrega na hora e põe em espera")
			_check.call((screen.get("_status") as Label).text == tr("shop.received") % tr("shop.slot_ryo.name"),
					"Loja sem anúncios: o aviso mostra o recebido")
		screen.get_parent().queue_free()
		await _host.get_tree().process_frame
	Locale.set_language("pt_BR", false)


func _open_shop() -> Control:
	var host := Control.new()
	host.size = SCREEN.size
	_host.add_child(host)
	var screen := (load(SHOP_SCREEN) as GDScript).new() as Control
	host.add_child(screen)
	screen.on_show()
	await _host.get_tree().process_frame
	await _host.get_tree().process_frame
	return screen


## Resultados: "Dobrar ryō (presente)" dobra na hora, uma vez, com o layout íntegro.
func _test_results() -> void:
	var layout := ResultsLayoutTests.new()
	layout.set("_host", _host)
	layout.set("_check", _check)
	for lang: String in Locale.SUPPORTED:
		Locale.set_language(lang, false)
		SaveManager.data = SaveManager.default_profile()
		var r := ResultsLayoutTests.make_result("victory", 3)
		var screen := await _open_results(r)
		var double := screen.get("_double") as Button
		_check.call(double.is_visible_in_tree() and double.text == tr("results.double_free"),
				"%s: sem anúncios o botão é \"%s\"" % [lang, tr("results.double_free")])
		layout.check_layout(screen, "%s, Dobrar ryō de presente" % lang)
		if lang == "pt_BR":
			var before := SaveManager.ryo()
			var earned := int(r["ryo_earned"])
			double.pressed.emit()
			await _host.get_tree().process_frame
			_check.call(bool(r.get("doubled", false)) and SaveManager.ryo() == before + earned
					and int(r["ryo_earned"]) == earned * 2, "Resultados sem anúncios: dobra o ryō na hora")
			_check.call(not double.visible, "Resultados sem anúncios: o botão some depois de usado")
		_close_results(screen)
		await _host.get_tree().process_frame
	Locale.set_language("pt_BR", false)


func _open_results(r: Dictionary) -> Control:
	var host := Control.new()
	host.size = SCREEN.size
	host.theme = ThemeFactory.build()
	_host.add_child(host)
	var app := ResultsLayoutTests.StubApp.new()
	app.last_result = r
	var screen := (load(RESULTS_SCREEN) as GDScript).new() as Screen
	screen.app = app
	host.add_child(screen)
	screen.on_show()
	await _host.get_tree().process_frame
	screen.call("skip_intro")
	await _host.get_tree().process_frame
	await _host.get_tree().process_frame
	return screen


func _close_results(screen: Control) -> void:
	(screen.get("app") as Node).free()
	screen.get_parent().queue_free()


## Opções: sem "Privacidade e anúncios" e sem "Compras" (restaurar); o resto continua,
## inclusive a Política de privacidade (abre a URL publicada).
func _test_options() -> void:
	SaveManager.data = SaveManager.default_profile()
	var menus := MenusLayoutTests.new()
	var screen := await menus.open_screen(_host, SCREEN.size, &"options")
	_check.call(screen.find_child("opt_privacy", true, false) == null,
			"Opções sem anúncios: sem \"Privacidade e anúncios\"")
	_check.call(screen.find_child("opt_restore", true, false) == null,
			"Opções sem anúncios: sem \"Restaurar compras\"")
	for key: String in ["notifications", "credits", "licenses", "privacy_policy", "reset", "version"]:
		_check.call(screen.find_child("opt_%s" % key, true, false) != null,
				"Opções sem anúncios: opt_%s continua" % key)
	var opened: Array[String] = []
	var options_script := load(MenusLayoutTests.SCREENS[&"options"]) as GDScript
	options_script.set("url_opener", func(url: String) -> void: opened.append(url))
	(screen.find_child("opt_privacy_policy", true, false) as Button).pressed.emit()
	options_script.set("url_opener", Callable())
	_check.call(opened == ["https://netstart.github.io/privacy-policy.html"],
			"Opções sem anúncios: Política de privacidade pede a URL publicada (%s)" % [opened])
	menus.close_screen(screen)
	await _host.get_tree().process_frame
	# Layout completo (sem as duas linhas) em cada idioma e tamanho, com a política visível.
	for lang: String in Locale.SUPPORTED:
		Locale.set_language(lang, false)
		for view: Vector2 in MenusLayoutTests.SIZES:
			SaveManager.data = SaveManager.default_profile()
			await menus.run_options(_host, _check, view, "sem anúncios %s %dx%d" % [lang, view.x, view.y])
	Locale.set_language("pt_BR", false)


## Abertura a frio: sem tela de consentimento e sem anúncio de abertura.
func _test_boot() -> void:
	for intro_seen: bool in [false, true]:
		SaveManager.data = SaveManager.default_profile()
		SaveManager.data["launches"] = 9
		SaveManager.data["open_ads_seen"] = 9
		SaveManager.data["story"]["intro_seen"] = intro_seen
		var vp := SubViewport.new()
		vp.size = Vector2i(SCREEN.size)
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_host.add_child(vp)
		var app := App.new()
		vp.add_child(app)
		await _host.get_tree().process_frame
		var layers := _ad_layers()
		app.call("_boot")
		await _host.get_tree().process_frame
		var expected := &"title" if intro_seen else &"story"
		_check.call(app.current == expected,
				"abertura sem anúncios (introdução vista: %s): vai direto para %s (foi %s)" % [
				intro_seen, expected, app.current])
		_check.call(not bool(SaveManager.data["consent"]["asked"]) and _ad_layers() == layers
				and int(SaveManager.data["open_ads_seen"]) == 9,
				"abertura sem anúncios: sem consentimento e sem anúncio de abertura")
		_check.call(not bool(SaveManager.data["remove_ad_offer_shown"]),
				"abertura sem anúncios: não oferece remover o anúncio de abertura")
		app.queue_free()
		vp.queue_free()
		await _host.get_tree().process_frame
	SaveManager.data = SaveManager.default_profile()


## Reviver: o botão diz "Reviver (presente)" e aceitar revive na hora, sem anúncio.
func _test_revive() -> void:
	var game := (load(GAME_SCENE) as PackedScene).instantiate() as HyakkiGame
	game.config = {"hero": "goro", "stage": "bamboo", "moon": 0, "mode": "normal", "seed": 91, "speed": 1}
	_host.add_child(game)
	await _host.get_tree().process_frame
	GameClock.game_time = 42.0
	game.player.god_mode = false
	game.player.revives_used = 99
	game.player.invuln = 0.0
	game.player.take_damage(99999.0)
	var waited := 0.0
	while not game.hud.revive_open() and waited < 3.0:
		await _host.get_tree().create_timer(0.05).timeout
		waited += 0.05
	_check.call(game.hud.revive_open(), "sem anúncios: morrer oferece reviver de presente")
	var watch := game.hud.get("_revive_watch") as Button
	_check.call(watch != null and watch.text == tr("revive.free"),
			"sem anúncios: o botão é \"%s\"" % tr("revive.free"))
	var layers := _ad_layers()
	game.hud._revive_panel.visible = false
	game.hud.revive_answered.emit(true)
	_check.call(game.player.is_alive and game.tracker.revived_by_ad and _ad_layers() == layers,
			"sem anúncios: aceitar revive na hora, sem tela de anúncio")
	waited = 0.0
	while GameClock.paused and waited < 8.0:
		await _host.get_tree().create_timer(0.1).timeout
		waited += 0.1
	_check.call(game.running and not GameClock.paused, "sem anúncios: depois de reviver a partida segue")
	game.queue_free()
	await _host.get_tree().process_frame
	GameClock.paused = true


## Religando os anúncios (IDs reais preenchidos): tudo volta ao comportamento de antes.
func _test_back_to_ads() -> void:
	SaveManager.data = SaveManager.default_profile()
	SaveManager.data["launches"] = 3
	_check.call(AdsManager.should_show_app_open(), "com anúncios: o anúncio de abertura volta")
	_check.call(PurchaseManager.available(), "com anúncios: a compra de remover anúncio volta")
	SaveManager.data = SaveManager.default_profile()
