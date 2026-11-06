class_name PlayBillingProvider
extends Node
## Provedor real de compras (plano 17.7): Google Play Billing pelo plugin oficial
## GodotGooglePlayBilling (addons/GodotGooglePlayBilling, MIT). Só no Android com o plugin.
## Sem Play Store (emulador sem Google Play, aparelho sem conta) a conexão falha e a compra
## responde "unavailable"; nada é liberado sem confirmação do Google.
## Vários produtos não consumíveis (remove_open_ad e unlock_speed): preço, compra, confirmação
## e reembolso por produto.
##
## Pedido de compra (um por vez, `_request`), que espera a Play em vez de falhar na hora:
## - "wait": sem conexão, conecta (start_connection) e, ao conectar, consulta os detalhes e abre a
##   compra; conectado mas sem os detalhes do produto (a consulta do início falhou ou não chegou),
##   consulta de novo e abre quando chegarem. Detalhes com erro ou produto em unfetched_products,
##   erro de conexão ou PURCHASE_TIMEOUT sem resposta: "unavailable";
## - "open": a tela de pagamento da Play está aberta; a resposta vem por on_purchase_updated
##   (sem prazo enquanto a tela está na frente: a pessoa pode demorar a pagar). Rede de segurança:
##   quando o jogo volta para a frente (NOTIFICATION_APPLICATION_RESUMED ou, na falta dele,
##   FOCUS_IN, depois de ter saído: PAUSED ou FOCUS_OUT), espera RESUME_GRACE pela resposta, que a
##   Play costuma mandar junto da volta; sem ela, passa a "check";
## - "check": a tela fechou sem resposta; consulta as compras (query_purchases, PURCHASE_TIMEOUT):
##   produto comprado ou pendente termina com esse estado (entrega normal); ausente, "canceled"
##   (saiu sem pagar; nunca "refunded" do produto pedido); erro ou sem resposta, "unavailable".
##   Uma resposta da tela que chegue depois do fim ainda entrega (sem pedido, vale como compra
##   avulsa) e não deixa nada preso;
## - "restore": a Play disse que o produto já é da pessoa (ITEM_ALREADY_OWNED, ao abrir ou na
##   resposta): consulta as compras (query_purchases) e entrega pelo caminho normal; sem o
##   produto na consulta, "failed"; sem resposta em PURCHASE_TIMEOUT, "unavailable".
## Abrir a compra respondendo "productId not found" (detalhes perdidos no plugin) consulta os
## detalhes de novo uma vez e tenta outra vez. Um purchase() com outro pedido em andamento é
## ignorado (sem resposta): a Loja desativa os botões enquanto busy_product() não é "".
## Todo estado final (`purchase_state`) limpa o pedido antes de ser emitido; cada falha vai para o
## logcat (push_warning) com o código e a debug_message da Play. Os avisos não usam "falhou": o
## tools/run_checks lê "FALHOU" (sem caixa) nos logs dos testes como verificação reprovada.

signal product_price_changed(product: String, price: String)
## state: "purchased", "pending", "refunded", "canceled" (a pessoa fechou a tela de pagamento),
## "unavailable" (a Play não respondeu, sem conexão ou produto indisponível) ou "failed" (outro erro).
signal purchase_state(product: String, state: String)

const SINGLETON := "GodotGooglePlayBilling"
## Prazo (s) para a Play conectar e mandar os detalhes (ou a consulta da restauração) de um pedido.
const PURCHASE_TIMEOUT := 12.0
## Espera (s) pela resposta da tela de pagamento depois que o jogo volta para a frente.
const RESUME_GRACE := 4.0
## Códigos de "a Play não está disponível agora" (rede, serviço, cobrança, produto inativo).
const UNAVAILABLE_CODES: Array[int] = [
	BillingClient.BillingResponseCode.SERVICE_UNAVAILABLE,
	BillingClient.BillingResponseCode.BILLING_UNAVAILABLE,
	BillingClient.BillingResponseCode.ITEM_UNAVAILABLE,
	BillingClient.BillingResponseCode.NETWORK_ERROR,
	BillingClient.BillingResponseCode.SERVICE_DISCONNECTED,
	BillingClient.BillingResponseCode.FEATURE_NOT_SUPPORTED,
	BillingClient.BillingResponseCode.SERVICE_TIMEOUT,
]

## product -> formatted_price (só os que a Play já respondeu).
var prices: Dictionary = {}
## Prazo de um pedido em espera (os testes encurtam; o jogo usa PURCHASE_TIMEOUT).
var purchase_timeout: float = PURCHASE_TIMEOUT
## Espera depois da volta ao jogo com a tela aberta (os testes encurtam; o jogo usa RESUME_GRACE).
var resume_grace: float = RESUME_GRACE
var _client: BillingClient
var _products: PackedStringArray = PackedStringArray()
## Produtos com detalhes na última consulta que deu certo (o plugin só compra esses).
var _fetched: Dictionary = {}
## Produto do pedido em andamento ("" = nenhum) e a fase dele ("wait", "open", "check" ou "restore").
var _request: String = ""
var _phase: String = ""
## Com a tela aberta: o jogo saiu da frente (PAUSED/FOCUS_OUT) e a espera da volta já começou
## (RESUMED e FOCUS_IN chegam juntos; só o primeiro conta).
var _left_app: bool = false
var _grace_started: bool = false
## O pedido já consultou os detalhes de novo depois de um "productId not found".
var _retried: bool = false
var _timer: Timer


static func is_supported() -> bool:
	return OS.get_name() == "Android" and Engine.has_singleton(SINGLETON)


## `client`: o BillingClient do plugin (padrão) ou, nos testes, um falso que o estende.
func setup(products: PackedStringArray, client: BillingClient = null) -> void:
	_products = products
	_client = client if client != null else BillingClient.new()
	if _client.get_parent() == null:
		add_child(_client)
	_timer = Timer.new()
	_timer.name = "PurchaseTimeout"
	_timer.one_shot = true
	_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_timer.timeout.connect(_on_timeout)
	add_child(_timer)
	_client.connected.connect(_on_connected)
	_client.connect_error.connect(_on_connect_error)
	_client.query_product_details_response.connect(_on_product_details)
	_client.query_purchases_response.connect(_on_purchases.bind(true))
	_client.on_purchase_updated.connect(_on_purchases.bind(false))
	_client.acknowledge_purchase_response.connect(func(response: Dictionary) -> void:
		if int(response.get("response_code", -1)) != BillingClient.BillingResponseCode.OK:
			push_warning("Billing: erro na confirmação (%d) %s" % [
					int(response.get("response_code", -1)), response.get("debug_message", "")]))
	_client.start_connection()


func price_of(product: String) -> String:
	return String(prices.get(product, ""))


func is_ready() -> bool:
	return _client != null and _client.is_ready()


## Produto do pedido em andamento (esperando a Play, tela de pagamento aberta ou restaurando) ou "".
func busy_product() -> String:
	return _request


func restore() -> void:
	if is_ready():
		_client.query_purchases(BillingClient.ProductType.INAPP)
	elif _client != null:
		_client.start_connection()


## Pede a compra: abre a tela de pagamento da Play assim que houver conexão e detalhes do produto
## (veja o topo). Com outro pedido em andamento, não faz nada.
func purchase(product: String) -> void:
	if not _request.is_empty():
		return
	if _client == null or not product in _products:
		_request = product
		_finish("failed", -1, "produto desconhecido ou Billing sem cliente")
		return
	_request = product
	_phase = "wait"
	_retried = false
	_start_timer()
	if not is_ready():
		_client.start_connection()
	elif _fetched.has(product):
		_launch()
	else:
		_query_details()


func _query_details() -> void:
	_client.query_product_details(_products, BillingClient.ProductType.INAPP)


func _start_timer() -> void:
	if _timer != null and _timer.is_inside_tree():
		_timer.start(purchase_timeout)


## Abre a tela de pagamento do pedido; o resultado do lançamento já pode ser a resposta final.
func _launch() -> void:
	_phase = "open"
	_left_app = false
	_grace_started = false
	if _timer != null:
		_timer.stop()
	var response: Dictionary = _client.purchase(_request)
	var code := int(response.get("response_code", BillingClient.BillingResponseCode.OK))
	var message := String(response.get("debug_message", ""))
	if code == BillingClient.BillingResponseCode.OK:
		return
	if code == BillingClient.BillingResponseCode.DEVELOPER_ERROR \
			and message.to_lower().contains("not found") and not _retried:
		push_warning("Billing: %s sem detalhes no plugin (%d) %s; consultando de novo" % [
				_request, code, message])
		_retried = true
		_fetched.erase(_request)
		_phase = "wait"
		_start_timer()
		_query_details()
		return
	if code == BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED:
		_restore_owned()
		return
	_finish(_state_for(code), code, message)


## A Play diz que o produto já é da pessoa: consulta as compras e entrega pelo caminho normal.
func _restore_owned() -> void:
	_phase = "restore"
	_start_timer()
	restore()


## "canceled", "unavailable" ou "failed" para um código de erro da Play.
static func _state_for(code: int) -> String:
	if code == BillingClient.BillingResponseCode.USER_CANCELED:
		return "canceled"
	if code in UNAVAILABLE_CODES:
		return "unavailable"
	return "failed"


## Estado final do pedido: limpa o pedido (busy_product() == "" ao emitir), avisa no logcat e emite.
func _finish(state: String, code: int, message: String) -> void:
	var product := _request
	_clear_request()
	if state != "purchased" and state != "pending":
		push_warning("Billing: compra de %s %s (%d) %s" % [product, state, code, message])
	if not product.is_empty():
		purchase_state.emit(product, state)


func _clear_request() -> void:
	_request = ""
	_phase = ""
	_retried = false
	_left_app = false
	_grace_started = false
	if _timer != null:
		_timer.stop()


## Rede de segurança da tela de pagamento: saiu do jogo e voltou com a fase "open" (veja o topo).
func _notification(what: int) -> void:
	if _phase != "open":
		return
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			_left_app = true
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			if _left_app and not _grace_started and _timer != null and _timer.is_inside_tree():
				_grace_started = true
				_timer.start(resume_grace)


func _on_timeout() -> void:
	if _phase == "open":
		# Voltou ao jogo e a tela não respondeu: confere nas compras.
		push_warning("Billing: %s sem resposta da tela de pagamento %.1f s depois da volta; consultando" % [
				_request, resume_grace])
		_phase = "check"
		_start_timer()
		restore()
	elif _phase == "wait" or _phase == "restore" or _phase == "check":
		_finish("unavailable", BillingClient.BillingResponseCode.SERVICE_TIMEOUT,
				"sem resposta da Play em %.1f s (%s)" % [purchase_timeout, _phase])


func _on_connect_error(code: int, message: String) -> void:
	push_warning("Billing: sem conexão (%d) %s" % [code, message])
	if _phase == "wait" or _phase == "restore" or _phase == "check":
		_finish("unavailable", code, message)


func _on_connected() -> void:
	_query_details()
	_client.query_purchases(BillingClient.ProductType.INAPP)


func _on_product_details(response: Dictionary) -> void:
	var code := int(response.get("response_code", -1))
	if code == BillingClient.BillingResponseCode.OK:
		for details: Variant in response.get("product_details", []):
			if not details is Dictionary:
				continue
			var product := String((details as Dictionary).get("product_id", ""))
			if not product in _products:
				continue
			_fetched[product] = true
			var text := _find_formatted_price(details)
			if not text.is_empty():
				prices[product] = text
				product_price_changed.emit(product, text)
	else:
		push_warning("Billing: detalhes dos produtos falharam (%d) %s" % [code, response.get("debug_message", "")])
	if _phase != "wait":
		return
	if code != BillingClient.BillingResponseCode.OK:
		_finish("unavailable", code, String(response.get("debug_message", "")))
	elif _fetched.has(_request):
		_launch()
	else:
		_finish("unavailable", code, "produto fora da resposta da Play (unfetched_products: %s)" %
				str(response.get("unfetched_products", [])))


## O preço vem aninhado (one_time_purchase_offer_details.formatted_price); procura a chave.
static func _find_formatted_price(value: Variant) -> String:
	if value is Dictionary:
		var dict: Dictionary = value
		if dict.has("formatted_price"):
			return String(dict["formatted_price"])
		for key: Variant in dict:
			var found := _find_formatted_price(dict[key])
			if not found.is_empty():
				return found
	elif value is Array:
		for item: Variant in value:
			var found := _find_formatted_price(item)
			if not found.is_empty():
				return found
	return ""


## `from_query`: resposta de queryPurchases (lista completa; produto ausente = reembolsado).
## Fora da consulta (resposta da tela de pagamento), cancelar, já possuir ou falhar responde pelo
## produto do pedido.
func _on_purchases(response: Dictionary, from_query: bool) -> void:
	var code := int(response.get("response_code", -1))
	var message := String(response.get("debug_message", ""))
	if code != BillingClient.BillingResponseCode.OK:
		if from_query:
			push_warning("Billing: erro na consulta das compras (%d) %s" % [code, message])
			if _phase == "restore":
				_finish("unavailable" if code in UNAVAILABLE_CODES else "failed", code, message)
			elif _phase == "check":
				_finish("unavailable", code, message)
		elif code == BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED and not _request.is_empty():
			_restore_owned()
		else:
			_finish(_state_for(code), code, message)
		return
	var found: Dictionary = {}
	for item: Variant in response.get("purchases", []):
		var purchase: Dictionary = item
		var ids := Array(purchase.get("product_ids", []))
		for product: String in _products:
			if not product in ids:
				continue
			found[product] = true
			match int(purchase.get("purchase_state", 0)):
				BillingClient.PurchaseState.PURCHASED:
					_emit_state(product, "purchased", from_query)
				BillingClient.PurchaseState.PENDING:
					_emit_state(product, "pending", from_query)
		# Uma confirmação por compra (o token vale para todos os produtos dela).
		if int(purchase.get("purchase_state", 0)) == BillingClient.PurchaseState.PURCHASED \
				and not bool(purchase.get("is_acknowledged", false)) and ids.any(
				func(id: Variant) -> bool: return String(id) in _products):
			_client.acknowledge_purchase(String(purchase.get("purchase_token", "")))
	if from_query:
		for product: String in _products:
			if found.has(product):
				continue
			if product == _request and _phase == "check":
				_finish("canceled", code, "a tela de pagamento fechou sem resposta e a compra não está na consulta")
			elif product == _request and _phase == "restore":
				_finish("failed", BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED,
						"a Play disse que já é seu, mas a consulta não trouxe a compra")
			else:
				purchase_state.emit(product, "refunded")
	elif _phase == "open":
		# Resposta OK sem o produto pedido: a tela fechou sem compra conhecida.
		_finish("failed", code, "resposta da compra sem o produto pedido")


## Estado de um produto de uma compra; se é o do pedido, ele termina aqui. Uma consulta com a tela
## de pagamento aberta entrega o produto mas não encerra o pedido (a resposta da tela vem depois).
func _emit_state(product: String, state: String, from_query: bool) -> void:
	if product == _request and not (from_query and _phase == "open"):
		_finish(state, BillingClient.BillingResponseCode.OK, "")
	else:
		purchase_state.emit(product, state)
