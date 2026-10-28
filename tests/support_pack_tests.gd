extends RefCounted
## Sem anúncio de abertura e "Apoie o jogo" (PurchaseManager.PRODUCT, id "remove_open_ad").
## - Não existe caminho de anúncio de abertura: nada de App Open no AdsManager nem no
##   AdMobProvider (só o bloco recompensado) e a abertura a frio vai direto para o título
##   (2ª abertura em diante, com anúncios ligados, consentimento já dado) ou para a introdução
##   (1ª vez), sem tela em branco e sem overlay de anúncio;
## - saves antigos com open_ads_seen, last_open_ad_unix e remove_ad_offer_shown carregam e
##   perdem esses campos; a compra antiga continua valendo;
## - com "Apoie o jogo" (comprado, restaurado ou de um save antigo) os recompensados opcionais
##   (Loja, Reviver, Dobrar ryō) chegam de presente, sem anúncio, com os anúncios ligados; a
##   compra dá a Lanterna Dourada; o reembolso faz as recompensas voltarem a pedir anúncio.
## Chamado por tests/integration_tests.gd, que passa o nó da cena e o _check.

const DeviceProfiles := preload("res://tests/device_profiles.gd")
const RESULTS_SCREEN := "res://scripts/app/screens/results_screen.gd"
const ResultsLayoutTests := preload("res://tests/results_layout_tests.gd")

var _host: Node
var _check: Callable


func run(host: Node, check: Callable) -> void:
	_host = host
	_check = check
	var was_enabled := AdsManager.ads_enabled
	var was_fill := AdsManager.mock_fill
	var was_auto := AdsManager.auto_answer
	AdsManager.ads_enabled = true
	AdsManager.mock_fill = true
	# Sem resposta automática: se algo abrir o anúncio simulado, o overlay fica e o teste percebe.
	AdsManager.auto_answer = false
	_test_no_app_open_api()
	_test_save_migration()
	await _test_cold_start()
	_test_purchase()
	await _test_gifts()
	await _test_results_and_revive_texts()
	AdsManager.ads_enabled = was_enabled
	AdsManager.mock_fill = was_fill
	AdsManager.auto_answer = was_auto
	SaveManager.data = SaveManager.default_profile()


func _ad_layers() -> int:
	var count := 0
	for child: Node in AdsManager.get_children():
		if child is CanvasLayer and not child.is_queued_for_deletion():
			count += 1
	return count


func _test_no_app_open_api() -> void:
	for method: String in ["should_show_app_open", "show_app_open", "_mark_open_ad_seen"]:
		_check.call(not AdsManager.has_method(method), "sem anúncio de abertura: AdsManager não tem %s" % method)
	var admob := AdMobProvider.new()
	for method: String in ["load_app_open", "show_app_open", "app_open_ready"]:
		_check.call(not admob.has_method(method), "sem anúncio de abertura: AdMobProvider não tem %s" % method)
	admob.free()
	_check.call(not AdMobProvider.TEST_UNITS.has("app_open") and not AdMobProvider.RELEASE_UNITS.has("app_open"),
			"sem anúncio de abertura: nenhum bloco app_open (teste nem produção)")
	var fresh := SaveManager.default_profile()
	for key: String in SaveManager.OBSOLETE_KEYS:
		_check.call(not fresh.has(key), "perfil novo sem o campo antigo %s" % key)
	_check.call(fresh["purchases"].has(PurchaseManager.PRODUCT) and PurchaseManager.PRODUCT == "remove_open_ad",
			"Apoie o jogo mantém o id de produto da Play (remove_open_ad)")


## Save antigo do tempo do anúncio de abertura: carrega, perde os campos e mantém a compra.
func _test_save_migration() -> void:
	var old := {"version": 1, "ryo": 77, "launches": 12, "last_open_ad_unix": 1700000000,
			"open_ads_seen": 6, "remove_ad_offer_shown": true,
			"purchases": {"remove_open_ad": true, "pending": false, "acknowledged": true}}
	var migrated: Dictionary = SaveManager.migrate(JSON.parse_string(JSON.stringify(old)))
	for key: String in SaveManager.OBSOLETE_KEYS:
		_check.call(not migrated.has(key), "migração: o campo antigo %s sai do save" % key)
	_check.call(int(migrated["ryo"]) == 77 and int(migrated["launches"]) == 12
			and bool(migrated["purchases"]["remove_open_ad"]), "migração: o resto do save antigo fica")
	SaveManager.data = migrated
	_check.call(PurchaseManager.owns() and AdsManager.rewards_are_gifts(),
			"quem comprou antes recebe as recompensas de presente sem fazer nada")
	SaveManager.data = SaveManager.default_profile()


## Abertura a frio com anúncios ligados (provedor simulado do PC) e consentimento já dado:
## 2ª abertura vai direto ao título no mesmo quadro; 1ª vez, à introdução. Sem overlay.
func _test_cold_start() -> void:
	for intro_seen: bool in [true, false]:
		SaveManager.data = SaveManager.default_profile()
		SaveManager.data["launches"] = 2 if intro_seen else 1
		SaveManager.data["consent"]["asked"] = true
		SaveManager.data["story"]["intro_seen"] = intro_seen
		var vp := SubViewport.new()
		vp.size = Vector2i(DeviceProfiles.main_view())
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_host.add_child(vp)
		var app := App.new()
		vp.add_child(app)
		await _host.get_tree().process_frame
		var layers := _ad_layers()
		app.call("_boot")
		var expected := &"title" if intro_seen else &"story"
		_check.call(app.current == expected,
				"abertura com anúncios (introdução vista: %s): vai direto para %s, sem esperar (foi %s)" % [
				intro_seen, expected, app.current])
		await _host.get_tree().create_timer(0.6).timeout
		_check.call(app.current == expected and _ad_layers() == layers,
				"abertura com anúncios (introdução vista: %s): nenhum anúncio de abertura aparece" % intro_seen)
		_check.call(app.current != &"shop", "abertura com anúncios: não leva à Loja")
		app.queue_free()
		vp.queue_free()
		await _host.get_tree().process_frame
	SaveManager.data = SaveManager.default_profile()


## Compra simulada: Lanterna Dourada + recompensas de presente; reembolso volta ao anúncio.
func _test_purchase() -> void:
	SaveManager.data = SaveManager.default_profile()
	_check.call(PurchaseManager.available() and not AdsManager.rewards_are_gifts(),
			"com anúncios e sem a compra: recompensas pedem anúncio")
	PurchaseManager.purchase()
	_check.call(PurchaseManager.owns() and SaveManager.is_unlocked("cosmetics", &"golden_lantern"),
			"Apoie o jogo: a compra dá a Lanterna Dourada")
	_check.call(AdsManager.rewards_are_gifts() and AdsManager.rewarded_available(),
			"Apoie o jogo: recompensas de presente, sempre disponíveis")
	PurchaseManager.call("_on_play_state", PurchaseManager.PRODUCT, "refunded")
	_check.call(not PurchaseManager.owns() and not AdsManager.rewards_are_gifts(),
			"Apoie o jogo reembolsado: as recompensas voltam a pedir anúncio")
	# Pendente confirmado chega pela restauração (quem já tinha comprado).
	SaveManager.data = SaveManager.default_profile()
	SaveManager.data["purchases"]["pending"] = true
	PurchaseManager.restore()
	_check.call(PurchaseManager.owns() and AdsManager.rewards_are_gifts(),
			"Apoie o jogo restaurado: recompensas de presente")
	SaveManager.data = SaveManager.default_profile()


## Recompensados com a compra: entregam na hora, sem overlay e sem silenciar o som, mesmo sem
## anúncio carregado (mock_fill = false).
func _test_gifts() -> void:
	SaveManager.data = SaveManager.default_profile()
	SaveManager.data["purchases"][PurchaseManager.PRODUCT] = true
	AdsManager.mock_fill = false
	var layers := _ad_layers()
	var got := {"rewarded": false, "calls": 0}
	AdsManager.show_rewarded("test", func(rewarded: bool) -> void:
		got["rewarded"] = rewarded
		got["calls"] = int(got["calls"]) + 1)
	_check.call(bool(got["rewarded"]) and int(got["calls"]) == 1 and _ad_layers() == layers,
			"Apoie o jogo: o recompensado entrega na hora, sem tela de anúncio")
	_check.call(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")),
			"Apoie o jogo: o som do jogo não é silenciado")
	var before := SaveManager.ryo()
	var result := {"ok": false}
	ShopManager.claim(&"slot_ryo", func(ok: bool) -> void: result["ok"] = ok)
	_check.call(bool(result["ok"]) and SaveManager.ryo() == before + ShopManager.ryo_value() and _ad_layers() == layers,
			"Apoie o jogo: a vaga de ryō da Loja entrega de presente")
	_check.call(not ShopManager.is_ready(&"slot_ryo"), "Apoie o jogo: a vaga mantém a espera de 6 h")
	# Sem a compra e sem anúncio carregado: nada é entregue (o anúncio é obrigatório para a recompensa).
	SaveManager.data = SaveManager.default_profile()
	got["calls"] = 0
	got["rewarded"] = true
	AdsManager.show_rewarded("test", func(rewarded: bool) -> void:
		got["rewarded"] = rewarded
		got["calls"] = int(got["calls"]) + 1)
	_check.call(not bool(got["rewarded"]) and int(got["calls"]) == 1,
			"sem a compra e sem anúncio carregado: o recompensado não entrega")
	AdsManager.mock_fill = true
	await _host.get_tree().process_frame
	SaveManager.data = SaveManager.default_profile()


## Resultados e Reviver dizem "(presente)" com a compra e "(anúncio)" sem ela.
func _test_results_and_revive_texts() -> void:
	var hud := load("res://scripts/ui/hud.gd") as GDScript
	var results := load(RESULTS_SCREEN) as GDScript
	for owned: bool in [false, true]:
		SaveManager.data = SaveManager.default_profile()
		SaveManager.data["purchases"][PurchaseManager.PRODUCT] = owned
		var screen := results.new() as Node
		var h := hud.new() as Node
		_check.call(String(screen.call("double_text")) == (tr("results.double_free") if owned else tr("results.double")),
				"Resultados (Apoie o jogo: %s): texto do Dobrar ryō" % owned)
		_check.call(String(h.call("revive_text")) == (tr("revive.free") if owned else tr("revive.watch")),
				"Reviver (Apoie o jogo: %s): texto do botão" % owned)
		screen.free()
		h.free()
	SaveManager.data = SaveManager.default_profile()
