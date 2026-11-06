extends RefCounted
## Compra pela Google Play (PlayBillingProvider) com um BillingClient falso
## (tests/fake_billing_client.gd), que só responde quando o teste manda:
## - sem conexão, o pedido conecta, consulta os detalhes e abre a tela de pagamento;
## - conectado sem os detalhes do produto, consulta de novo e abre quando chegam;
## - produto fora da resposta (unfetched), detalhes com erro, erro de conexão e prazo esgotado
##   (PURCHASE_TIMEOUT, encurtado aqui, contado em quadros de simulação): "unavailable";
## - "productId not found" ao abrir: consulta os detalhes de novo uma vez e abre outra vez;
## - cancelar: "canceled"; erro da Play: "failed" ou "unavailable" pelo código;
## - ITEM_ALREADY_OWNED (ao abrir ou na resposta): restaura pela consulta e entrega;
## - compra normal entrega e confirma (acknowledge); a consulta segue marcando reembolsos;
## - um pedido por vez (o segundo é ignorado);
## - rede de segurança da tela aberta: voltar ao jogo (notificações de saída e volta) e a resposta
##   chegar dentro de RESUME_GRACE dá o resultado normal; sem resposta, a consulta das compras
##   entrega o comprado, cancela o ausente (sem "refunded" do pedido) e erro vira "unavailable";
##   resposta atrasada depois do fim ainda entrega; sem sair do jogo, a tela fica aberta sem prazo;
## - PurchaseManager: last_error e is_busy por motivo, com a Play e com o simulado;
## - Loja: com a compra esperando a Play, os botões de dinheiro ficam desativados com
##   "Abrindo a Google Play…" (toque duplo não pede de novo) e cada motivo tem o seu aviso.
## Chamado por tests/integration_tests.gd, que passa o nó da cena e o _check.

const FakeBillingClient := preload("res://tests/fake_billing_client.gd")
const SHOP_SCREEN := "res://scripts/app/screens/shop_screen.gd"
const DeviceProfiles := preload("res://tests/device_profiles.gd")
const CODE := BillingClient.BillingResponseCode
## Prazo do pedido nos testes (s de simulação) e o limite de quadros para esperá-lo.
const SHORT_TIMEOUT := 0.1
const MAX_FRAMES := 120

var _host: Node
var _check: Callable
var _products := PackedStringArray([PurchaseManager.PRODUCT, PurchaseManager.SPEED_PRODUCT])


func run(host: Node, check: Callable) -> void:
	_host = host
	_check = check
	var was_ads := AdsManager.ads_enabled
	AdsManager.ads_enabled = true
	_test_connects_first()
	_test_requery_details()
	_test_unavailable()
	await _test_timeout()
	_test_not_found_retry()
	_test_cancel_and_errors()
	_test_already_owned()
	_test_refund_query()
	_test_one_at_a_time()
	await _test_resume_safety_net()
	_test_manager_play()
	_test_manager_mock()
	await _test_shop()
	AdsManager.ads_enabled = was_ads
	SaveManager.data = SaveManager.default_profile()


## Provedor na árvore (o prazo é um Timer filho) com o cliente falso.
func _provider(fake: FakeBillingClient) -> PlayBillingProvider:
	var play := PlayBillingProvider.new()
	_host.add_child(play)
	play.setup(_products, fake)
	return play


func _states(play: PlayBillingProvider) -> Array:
	var states: Array = []
	play.purchase_state.connect(func(product: String, state: String) -> void: states.append([product, state]))
	return states


## Conectado e com os detalhes dos dois produtos (a consulta do início deu certo).
func _ready_provider(fake: FakeBillingClient) -> PlayBillingProvider:
	var play := _provider(fake)
	fake.connect_now()
	fake.answer_details(Array(_products))
	return play


func _done(play: PlayBillingProvider) -> void:
	play.get_parent().remove_child(play)
	play.free()


func _test_connects_first() -> void:
	var fake := FakeBillingClient.new()
	var play := _provider(fake)
	var states := _states(play)
	var connects := fake.count("start_connection")
	play.purchase(PurchaseManager.PRODUCT)
	_check.call(play.busy_product() == PurchaseManager.PRODUCT and states.is_empty()
			and fake.count("start_connection") == connects + 1 and fake.count("purchase") == 0,
			"Play sem conexão: o pedido espera e conecta (sem falhar na hora)")
	fake.connect_now()
	_check.call(fake.count("query_product_details") == 1 and fake.count("purchase") == 0,
			"Play sem conexão: ao conectar, consulta os detalhes antes de abrir")
	fake.answer_details(Array(_products))
	_check.call(fake.count("purchase") == 1 and fake.calls[-1][1] == PurchaseManager.PRODUCT
			and play.busy_product() == PurchaseManager.PRODUCT and states.is_empty(),
			"Play sem conexão: com os detalhes, abre a tela de pagamento do produto pedido")
	_check.call(play.price_of(PurchaseManager.PRODUCT) == "R$ 1,00", "Play: o preço chega com os detalhes")
	fake.purchase_update(CODE.OK, [FakeBillingClient.make_purchase(PurchaseManager.PRODUCT)])
	_check.call(states == [[PurchaseManager.PRODUCT, "purchased"]] and play.busy_product().is_empty(),
			"Play: compra concluída entrega e encerra o pedido")
	_check.call(fake.calls[-1] == ["acknowledge_purchase", "token_%s" % PurchaseManager.PRODUCT],
			"Play: compra concluída é confirmada (acknowledge)")
	_done(play)


func _test_requery_details() -> void:
	var fake := FakeBillingClient.new()
	var play := _provider(fake)
	var states := _states(play)
	fake.connect_now()
	# A consulta do início não trouxe nada (rede lenta): sem detalhes no plugin.
	fake.answer_details([], Array(_products), CODE.NETWORK_ERROR)
	var queries := fake.count("query_product_details")
	play.purchase(PurchaseManager.SPEED_PRODUCT)
	_check.call(fake.count("query_product_details") == queries + 1 and fake.count("purchase") == 0
			and play.busy_product() == PurchaseManager.SPEED_PRODUCT,
			"Play sem os detalhes: o pedido consulta de novo em vez de comprar")
	fake.answer_details(Array(_products))
	_check.call(fake.count("purchase") == 1 and fake.calls[-1][1] == PurchaseManager.SPEED_PRODUCT and states.is_empty(),
			"Play sem os detalhes: abre quando os detalhes chegam")
	# Com os detalhes guardados, o próximo pedido abre direto.
	fake.purchase_update(CODE.USER_CANCELED)
	queries = fake.count("query_product_details")
	play.purchase(PurchaseManager.PRODUCT)
	_check.call(fake.count("query_product_details") == queries and fake.count("purchase") == 2,
			"Play com os detalhes: abre a tela de pagamento direto")
	_done(play)


func _test_unavailable() -> void:
	var cases := [
		["fora da resposta (unfetched)", func(fake: FakeBillingClient) -> void:
			fake.answer_details([PurchaseManager.SPEED_PRODUCT], [PurchaseManager.PRODUCT])],
		["detalhes com erro", func(fake: FakeBillingClient) -> void:
			fake.answer_details([], [], CODE.SERVICE_UNAVAILABLE)],
		["erro de conexão", func(fake: FakeBillingClient) -> void:
			fake.play_ready = false
			fake.connect_error.emit(CODE.BILLING_UNAVAILABLE, "sem conta")],
	]
	for c: Array in cases:
		var fake := FakeBillingClient.new()
		var play := _provider(fake)
		var states := _states(play)
		fake.connect_now()
		play.purchase(PurchaseManager.PRODUCT)
		(c[1] as Callable).call(fake)
		_check.call(states == [[PurchaseManager.PRODUCT, "unavailable"]] and play.busy_product().is_empty()
				and fake.count("purchase") == 0, "Play: produto %s responde \"unavailable\" (%s)", [c[0], states])
		_done(play)


## Sem resposta da Play no prazo: "unavailable" (prazo encurtado, contado em quadros).
func _test_timeout() -> void:
	_check.call(PlayBillingProvider.PURCHASE_TIMEOUT >= 5.0 and PlayBillingProvider.PURCHASE_TIMEOUT <= 30.0,
			"Play: prazo do pedido de %.0f s", PlayBillingProvider.PURCHASE_TIMEOUT)
	for restore: bool in [false, true]:
		var fake := FakeBillingClient.new()
		var play := _provider(fake)
		play.purchase_timeout = SHORT_TIMEOUT
		var states := _states(play)
		if restore:
			fake.connect_now()
			fake.answer_details(Array(_products))
			fake.launch_results.append({"response_code": CODE.ITEM_ALREADY_OWNED, "debug_message": "owned"})
		play.purchase(PurchaseManager.PRODUCT)
		var frames := 0
		while states.is_empty() and frames < MAX_FRAMES:
			await _host.get_tree().process_frame
			frames += 1
		_check.call(states == [[PurchaseManager.PRODUCT, "unavailable"]] and play.busy_product().is_empty(),
				"Play: sem resposta no prazo (%s) responde \"unavailable\" (%s em %d quadros)", [
				"restaurando" if restore else "conectando", states, frames])
		# Resposta atrasada depois do prazo não muda nada.
		fake.connect_now()
		fake.answer_details(Array(_products))
		_check.call(states.size() == 1 and fake.count("purchase") == (1 if restore else 0),
				"Play: resposta depois do prazo não abre a compra")
		_done(play)


func _test_not_found_retry() -> void:
	var fake := FakeBillingClient.new()
	var play := _ready_provider(fake)
	var states := _states(play)
	var not_found := {"response_code": CODE.DEVELOPER_ERROR,
			"debug_message": "productId not found! You must query the product details and wait for the result"
			+ " before purchasing."}
	fake.launch_results.append(not_found)
	var queries := fake.count("query_product_details")
	play.purchase(PurchaseManager.PRODUCT)
	_check.call(fake.count("purchase") == 1 and fake.count("query_product_details") == queries + 1
			and states.is_empty() and play.busy_product() == PurchaseManager.PRODUCT,
			"Play: \"productId not found\" consulta os detalhes de novo")
	fake.answer_details(Array(_products))
	_check.call(fake.count("purchase") == 2 and states.is_empty(), "Play: com os detalhes de novo, abre outra vez")
	fake.purchase_update(CODE.USER_CANCELED)
	# Uma vez só: o segundo "not found" seguido falha.
	fake.launch_results.append(not_found)
	fake.launch_results.append(not_found)
	states.clear()
	play.purchase(PurchaseManager.PRODUCT)
	fake.answer_details(Array(_products))
	_check.call(fake.count("purchase") == 4 and states == [[PurchaseManager.PRODUCT, "failed"]]
			and play.busy_product().is_empty(), "Play: o segundo \"not found\" seguido responde \"failed\"")
	_done(play)


func _test_cancel_and_errors() -> void:
	var fake := FakeBillingClient.new()
	var play := _ready_provider(fake)
	var states := _states(play)
	var cases := [[CODE.USER_CANCELED, "canceled"], [CODE.SERVICE_UNAVAILABLE, "unavailable"],
			[CODE.NETWORK_ERROR, "unavailable"], [CODE.SERVICE_DISCONNECTED, "unavailable"],
			[CODE.ERROR, "failed"]]
	for c: Array in cases:
		for at_launch: bool in [false, true]:
			states.clear()
			if at_launch:
				fake.launch_results.append({"response_code": c[0], "debug_message": "teste"})
			play.purchase(PurchaseManager.SPEED_PRODUCT)
			if not at_launch:
				fake.purchase_update(int(c[0]))
			_check.call(states == [[PurchaseManager.SPEED_PRODUCT, c[1]]] and play.busy_product().is_empty(),
					"Play: código %d (%s) responde \"%s\" (%s)", [c[0], "ao abrir" if at_launch else "na resposta",
					c[1], states])
	_done(play)


func _test_already_owned() -> void:
	for at_launch: bool in [true, false]:
		var fake := FakeBillingClient.new()
		var play := _ready_provider(fake)
		var states := _states(play)
		if at_launch:
			fake.launch_results.append({"response_code": CODE.ITEM_ALREADY_OWNED, "debug_message": "owned"})
		var queries := fake.count("query_purchases")
		play.purchase(PurchaseManager.PRODUCT)
		if not at_launch:
			fake.purchase_update(CODE.ITEM_ALREADY_OWNED)
		var tag := "ao abrir" if at_launch else "na resposta"
		_check.call(fake.count("query_purchases") == queries + 1 and states.is_empty()
				and play.busy_product() == PurchaseManager.PRODUCT,
				"Play: já é seu (%s) restaura pela consulta das compras", tag)
		fake.answer_purchases([FakeBillingClient.make_purchase(PurchaseManager.PRODUCT,
				BillingClient.PurchaseState.PURCHASED, true)])
		_check.call(states.has([PurchaseManager.PRODUCT, "purchased"]) and play.busy_product().is_empty()
				and not states.has([PurchaseManager.PRODUCT, "failed"]),
				"Play: já é seu (%s) entrega o produto (%s)", [tag, states])
		_check.call(fake.count("acknowledge_purchase") == 0, "Play: compra já confirmada não é confirmada de novo")
		_done(play)
	# A consulta não trouxe o produto: "failed" (e nada de reembolso falso do pedido).
	var fake := FakeBillingClient.new()
	var play := _ready_provider(fake)
	var states := _states(play)
	fake.launch_results.append({"response_code": CODE.ITEM_ALREADY_OWNED, "debug_message": "owned"})
	play.purchase(PurchaseManager.PRODUCT)
	fake.answer_purchases([])
	_check.call(states.has([PurchaseManager.PRODUCT, "failed"]) and not states.has([PurchaseManager.PRODUCT, "refunded"])
			and play.busy_product().is_empty(), "Play: já é seu sem a compra na consulta responde \"failed\" (%s)", [states])
	_done(play)


func _test_refund_query() -> void:
	var fake := FakeBillingClient.new()
	var play := _ready_provider(fake)
	var states := _states(play)
	fake.answer_purchases([FakeBillingClient.make_purchase(PurchaseManager.SPEED_PRODUCT)])
	_check.call(states.has([PurchaseManager.SPEED_PRODUCT, "purchased"])
			and states.has([PurchaseManager.PRODUCT, "refunded"])
			and fake.calls[-1] == ["acknowledge_purchase", "token_%s" % PurchaseManager.SPEED_PRODUCT],
			"Play: a consulta entrega, confirma e marca o ausente como reembolsado (%s)", [states])
	states.clear()
	fake.answer_purchases([])
	_check.call(states == [[PurchaseManager.PRODUCT, "refunded"], [PurchaseManager.SPEED_PRODUCT, "refunded"]],
			"Play: consulta vazia reembolsa os dois")
	# Consulta com a tela de pagamento aberta: entrega, mas o pedido segue até a resposta da tela.
	states.clear()
	play.purchase(PurchaseManager.SPEED_PRODUCT)
	fake.answer_purchases([FakeBillingClient.make_purchase(PurchaseManager.SPEED_PRODUCT,
			BillingClient.PurchaseState.PURCHASED, true)])
	_check.call(states.has([PurchaseManager.SPEED_PRODUCT, "purchased"])
			and play.busy_product() == PurchaseManager.SPEED_PRODUCT,
			"Play: consulta com a tela aberta não encerra o pedido")
	fake.purchase_update(CODE.OK, [FakeBillingClient.make_purchase(PurchaseManager.SPEED_PRODUCT,
			BillingClient.PurchaseState.PENDING)])
	_check.call(states[-1] == [PurchaseManager.SPEED_PRODUCT, "pending"] and play.busy_product().is_empty(),
			"Play: pagamento pendente encerra o pedido como \"pending\"")
	_done(play)


func _test_one_at_a_time() -> void:
	var fake := FakeBillingClient.new()
	var play := _provider(fake)
	var states := _states(play)
	play.purchase(PurchaseManager.PRODUCT)
	var connects := fake.count("start_connection")
	play.purchase(PurchaseManager.PRODUCT)
	play.purchase(PurchaseManager.SPEED_PRODUCT)
	_check.call(play.busy_product() == PurchaseManager.PRODUCT and states.is_empty()
			and fake.count("start_connection") == connects, "Play: com um pedido em andamento, outro é ignorado")
	play.purchase("produto_que_nao_existe")
	_check.call(states.is_empty() and play.busy_product() == PurchaseManager.PRODUCT,
			"Play: produto desconhecido com pedido em andamento também é ignorado")
	_done(play)
	fake = FakeBillingClient.new()
	play = _provider(fake)
	states = _states(play)
	play.purchase("produto_que_nao_existe")
	_check.call(states == [["produto_que_nao_existe", "failed"]] and play.busy_product().is_empty(),
			"Play: produto desconhecido responde \"failed\"")
	_done(play)


## Saída e volta do jogo com a tela de pagamento aberta (como no Android ao fechar a tela da Play).
func _leave_and_return(play: PlayBillingProvider) -> void:
	play.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	play.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	play.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	play.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)


## Espera `states` ganhar uma entrada ou o pedido mudar de fase (prazo em quadros de simulação).
func _await_change(play: PlayBillingProvider, states: Array, phase: String) -> int:
	var frames := 0
	while states.is_empty() and String(play.get("_phase")) == phase and frames < MAX_FRAMES:
		await _host.get_tree().process_frame
		frames += 1
	return frames


func _open_provider(fake: FakeBillingClient) -> PlayBillingProvider:
	var play := _ready_provider(fake)
	play.purchase_timeout = SHORT_TIMEOUT
	play.resume_grace = SHORT_TIMEOUT
	return play


func _test_resume_safety_net() -> void:
	var grace := PlayBillingProvider.RESUME_GRACE
	_check.call(grace >= 1.0 and grace < PlayBillingProvider.PURCHASE_TIMEOUT,
			"Play: espera da volta de %.0f s", PlayBillingProvider.RESUME_GRACE)
	# Sem sair do jogo: a tela fica aberta sem prazo (nem a volta sozinha conta).
	var fake := FakeBillingClient.new()
	var play := _open_provider(fake)
	var states := _states(play)
	play.purchase(PurchaseManager.PRODUCT)
	play.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	for i: int in MAX_FRAMES:
		await _host.get_tree().process_frame
	_check.call(states.is_empty() and String(play.get("_phase")) == "open"
			and play.busy_product() == PurchaseManager.PRODUCT and fake.count("query_purchases") == 1,
			"Play: sem sair do jogo a tela de pagamento fica aberta, sem prazo (%s)", [states])
	# Volta com a resposta dentro da espera: resultado normal, sem consulta.
	_leave_and_return(play)
	_leave_and_return(play)
	fake.purchase_update(CODE.OK, [FakeBillingClient.make_purchase(PurchaseManager.PRODUCT)])
	_check.call(states == [[PurchaseManager.PRODUCT, "purchased"]] and play.busy_product().is_empty(),
			"Play: voltou e a resposta chegou na espera: compra normal")
	for i: int in MAX_FRAMES:
		await _host.get_tree().process_frame
	_check.call(states.size() == 1 and fake.count("query_purchases") == 1,
			"Play: a espera da volta para com a resposta (nenhuma consulta depois)")
	_done(play)
	# Volta sem resposta: consulta das compras.
	var cases := [
		["comprado", func(f: FakeBillingClient) -> void:
			f.answer_purchases([FakeBillingClient.make_purchase(PurchaseManager.PRODUCT)]), "purchased"],
		["pendente", func(f: FakeBillingClient) -> void:
			f.answer_purchases([FakeBillingClient.make_purchase(PurchaseManager.PRODUCT,
					BillingClient.PurchaseState.PENDING)]), "pending"],
		["ausente", func(f: FakeBillingClient) -> void: f.answer_purchases([]), "canceled"],
		["consulta com erro", func(f: FakeBillingClient) -> void: f.answer_purchases([], CODE.ERROR), "unavailable"],
		["consulta sem resposta", Callable(), "unavailable"],
	]
	for c: Array in cases:
		fake = FakeBillingClient.new()
		play = _open_provider(fake)
		states = _states(play)
		play.purchase(PurchaseManager.PRODUCT)
		var queries := fake.count("query_purchases")
		_leave_and_return(play)
		var frames := await _await_change(play, states, "open")
		_check.call(states.is_empty() and String(play.get("_phase")) == "check"
				and fake.count("query_purchases") == queries + 1,
				"Play: voltou sem resposta (%s): consulta as compras depois da espera (%d quadros)", [c[0], frames])
		if (c[1] as Callable).is_valid():
			(c[1] as Callable).call(fake)
		else:
			await _await_change(play, states, "check")
		_check.call(states.has([PurchaseManager.PRODUCT, c[2]]) and play.busy_product().is_empty()
				and not states.has([PurchaseManager.PRODUCT, "refunded"]),
				"Play: voltou sem resposta, %s: \"%s\" (%s)", [c[0], c[2], states])
		if c[2] == "canceled":
			_check.call(states.has([PurchaseManager.SPEED_PRODUCT, "refunded"]),
					"Play: na consulta da volta o outro produto ausente segue como reembolsado")
		# Resposta da tela atrasada, depois do fim: ainda entrega e nada fica preso.
		states.clear()
		fake.purchase_update(CODE.OK, [FakeBillingClient.make_purchase(PurchaseManager.PRODUCT)])
		fake.purchase_update(CODE.USER_CANCELED)
		_check.call(states == [[PurchaseManager.PRODUCT, "purchased"]] and play.busy_product().is_empty(),
				"Play: resposta atrasada depois de \"%s\" ainda entrega (%s)", [c[2], states])
		_done(play)


## PurchaseManager com a Play (cliente falso): is_busy e last_error de cada motivo.
func _test_manager_play() -> void:
	SaveManager.data = SaveManager.default_profile()
	var fake := FakeBillingClient.new()
	var play := PlayBillingProvider.new()
	PurchaseManager.call("_attach_play", play)
	play.setup(_products, fake)
	fake.connect_now()
	fake.answer_details(Array(_products))
	var answers: Array = []
	var listener := func(product: String, ok: bool) -> void:
		answers.append([product, ok, PurchaseManager.last_error, PurchaseManager.is_busy(product)])
	PurchaseManager.purchase_finished.connect(listener)
	var cases := [[CODE.USER_CANCELED, "canceled"], [CODE.NETWORK_ERROR, "unavailable"], [CODE.ERROR, "failed"]]
	for c: Array in cases:
		answers.clear()
		PurchaseManager.purchase()
		_check.call(PurchaseManager.is_busy() and PurchaseManager.is_busy("")
				and not PurchaseManager.is_busy(PurchaseManager.SPEED_PRODUCT) and answers.is_empty(),
				"Compras: com a tela da Play aberta, is_busy() do produto pedido")
		PurchaseManager.purchase()
		_check.call(fake.count("purchase") == 1 + cases.find(c),
				"Compras: outro toque na compra em andamento não pede de novo")
		fake.purchase_update(int(c[0]))
		_check.call(answers == [[PurchaseManager.PRODUCT, false, c[1], false]] and not PurchaseManager.is_busy(""),
				"Compras: código %d vira last_error \"%s\" e libera is_busy (%s)", [c[0], c[1], answers])
	answers.clear()
	PurchaseManager.buy_speed_with_money()
	fake.purchase_update(CODE.OK, [FakeBillingClient.make_purchase(PurchaseManager.SPEED_PRODUCT,
			BillingClient.PurchaseState.PENDING)])
	_check.call(answers == [[PurchaseManager.SPEED_PRODUCT, false, "pending", false]]
			and PurchaseManager.is_pending(PurchaseManager.SPEED_PRODUCT),
			"Compras: pagamento pendente vira last_error \"pending\" (%s)", [answers])
	answers.clear()
	PurchaseManager.purchase()
	fake.purchase_update(CODE.OK, [FakeBillingClient.make_purchase(PurchaseManager.PRODUCT)])
	_check.call(answers == [[PurchaseManager.PRODUCT, true, "", false]] and PurchaseManager.owns(),
			"Compras: compra concluída entrega com last_error vazio (%s)", [answers])
	# Já é seu na Play (comprou em outro aparelho): a restauração entrega.
	SaveManager.data = SaveManager.default_profile()
	answers.clear()
	fake.launch_results.append({"response_code": CODE.ITEM_ALREADY_OWNED, "debug_message": "owned"})
	PurchaseManager.purchase()
	_check.call(PurchaseManager.is_busy() and answers.is_empty(), "Compras: já é seu espera a restauração")
	fake.answer_purchases([FakeBillingClient.make_purchase(PurchaseManager.PRODUCT,
			BillingClient.PurchaseState.PURCHASED, true)])
	_check.call(answers.has([PurchaseManager.PRODUCT, true, "", false]) and PurchaseManager.owns()
			and not PurchaseManager.is_busy(""), "Compras: já é seu entrega pela restauração (%s)", [answers])
	PurchaseManager.purchase_finished.disconnect(listener)
	PurchaseManager.call("_detach_play")
	play.free()
	SaveManager.data = SaveManager.default_profile()


## Simulado do PC: nunca fica ocupado; last_error de cada resposta.
func _test_manager_mock() -> void:
	SaveManager.data = SaveManager.default_profile()
	PurchaseManager.mock_pending = false
	_check.call(PurchaseManager.provider == "mock" and not PurchaseManager.is_busy(""),
			"Compras: o simulado volta depois da Play e não fica ocupado")
	var answers: Array = []
	var listener := func(product: String, ok: bool) -> void:
		answers.append([product, ok, PurchaseManager.last_error, PurchaseManager.is_busy("")])
	PurchaseManager.purchase_finished.connect(listener)
	PurchaseManager.mock_pending = true
	PurchaseManager.purchase()
	PurchaseManager.mock_pending = false
	PurchaseManager.purchase("produto_que_nao_existe")
	PurchaseManager.purchase()
	_check.call(answers == [[PurchaseManager.PRODUCT, false, "pending", false],
			["produto_que_nao_existe", false, "failed", false], [PurchaseManager.PRODUCT, true, "", false]],
			"Compras simuladas: pendente, produto desconhecido e concluída (%s)", [answers])
	PurchaseManager.purchase_finished.disconnect(listener)
	SaveManager.data = SaveManager.default_profile()


## Loja com a Play falsa: botões ocupados durante o pedido e o aviso de cada motivo.
func _test_shop() -> void:
	SaveManager.data = SaveManager.default_profile()
	Locale.set_language("pt_BR", false)
	var fake := FakeBillingClient.new()
	var play := PlayBillingProvider.new()
	PurchaseManager.call("_attach_play", play)
	play.setup(_products, fake)
	fake.connect_now()
	fake.answer_details(Array(_products))
	var host := Control.new()
	host.size = DeviceProfiles.main_view()
	_host.add_child(host)
	var screen := (load(SHOP_SCREEN) as GDScript).new() as Control
	host.add_child(screen)
	screen.call("on_show")
	await _host.get_tree().process_frame
	var buy := screen.get("_buy") as Button
	var money := screen.get("_speed_money") as Button
	var status := screen.get("_status") as Label
	var support_text := tr("shop.support") % PurchaseManager.price_text()
	_check.call(buy.text == support_text and not buy.disabled and not money.disabled,
			"Loja com a Play: \"Apoiar o jogo\" com o preço da Play, ativo")
	var cases := [[CODE.USER_CANCELED, "shop.canceled"], [CODE.NETWORK_ERROR, "shop.unavailable"],
			[CODE.ERROR, "shop.failed"]]
	for c: Array in cases:
		screen.call("_on_buy")
		_check.call(buy.disabled and buy.text == tr("shop.opening") and money.disabled
				and money.text == PurchaseManager.speed_price_text(),
				"Loja: esperando a Play, \"Apoiar o jogo\" diz \"%s\" e os botões de dinheiro ficam desativados",
				tr("shop.opening"))
		var launches := fake.count("purchase")
		buy.pressed.emit()
		_check.call(fake.count("purchase") == launches, "Loja: toque duplo na compra em andamento não pede de novo")
		fake.purchase_update(int(c[0]))
		_check.call(status.text == tr(c[1]) and not buy.disabled and buy.text == support_text and not money.disabled,
				"Loja: código %d mostra \"%s\" e devolve os botões (%s)", [c[0], tr(c[1]), status.text])
	# Ampulheta com dinheiro: o mesmo caminho.
	screen.call("_buy_speed_money")
	_check.call(money.disabled and money.text == tr("shop.opening") and buy.disabled and buy.text == support_text,
			"Loja: Ampulheta esperando a Play diz \"%s\" e desativa os dois botões", tr("shop.opening"))
	fake.purchase_update(CODE.USER_CANCELED)
	_check.call(status.text == tr("shop.canceled") and not money.disabled
			and money.text == PurchaseManager.speed_price_text(), "Loja: Ampulheta cancelada avisa e volta ao preço")
	screen.call("_buy_speed_money")
	fake.purchase_update(CODE.OK, [FakeBillingClient.make_purchase(PurchaseManager.SPEED_PRODUCT,
			BillingClient.PurchaseState.PENDING)])
	_check.call(status.text == tr("shop.pending"), "Loja: Ampulheta pendente mostra \"%s\"", tr("shop.pending"))
	# Sem resposta da Play (conexão caiu, prazo): aviso de indisponível.
	fake.play_ready = false
	screen.call("_on_buy")
	fake.connect_error.emit(CODE.SERVICE_UNAVAILABLE, "teste")
	_check.call(status.text == tr("shop.unavailable") and not buy.disabled,
			"Loja: sem conexão com a Play mostra \"%s\"", tr("shop.unavailable"))
	host.queue_free()
	await _host.get_tree().process_frame
	PurchaseManager.call("_detach_play")
	play.free()
	SaveManager.data = SaveManager.default_profile()
