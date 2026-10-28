class_name PlayBillingProvider
extends Node
## Provedor real de compras (plano 17.7): Google Play Billing pelo plugin oficial
## GodotGooglePlayBilling (addons/GodotGooglePlayBilling, MIT). Só no Android com o plugin.
## Sem Play Store (emulador sem Google Play, aparelho sem conta) a conexão falha e a compra
## responde "não concluída"; nada é liberado sem confirmação do Google.
## Vários produtos não consumíveis (remove_open_ad e unlock_speed): preço, compra, confirmação
## e reembolso por produto.

signal product_price_changed(product: String, price: String)
## state: "purchased", "pending", "failed", "refunded"
signal purchase_state(product: String, state: String)

const SINGLETON := "GodotGooglePlayBilling"

## product -> formatted_price (só os que a Play já respondeu).
var prices: Dictionary = {}
var _client: BillingClient
var _products: PackedStringArray = PackedStringArray()
## Produto da última compra aberta (cancelar ou falhar não traz o id na resposta).
var _buying: String = ""


static func is_supported() -> bool:
	return OS.get_name() == "Android" and Engine.has_singleton(SINGLETON)


func setup(products: PackedStringArray) -> void:
	_products = products
	_client = BillingClient.new()
	add_child(_client)
	_client.connected.connect(_on_connected)
	_client.connect_error.connect(func(code: int, message: String) -> void:
		push_warning("Billing: sem conexão (%d) %s" % [code, message]))
	_client.query_product_details_response.connect(_on_product_details)
	_client.query_purchases_response.connect(_on_purchases.bind(true))
	_client.on_purchase_updated.connect(_on_purchases.bind(false))
	_client.acknowledge_purchase_response.connect(func(response: Dictionary) -> void:
		if int(response.get("response_code", -1)) != BillingClient.BillingResponseCode.OK:
			push_warning("Billing: confirmação falhou %s" % response.get("debug_message", "")))
	_client.start_connection()


func price_of(product: String) -> String:
	return String(prices.get(product, ""))


func is_ready() -> bool:
	return _client != null and _client.is_ready()


func restore() -> void:
	if is_ready():
		_client.query_purchases(BillingClient.ProductType.INAPP)
	elif _client != null:
		_client.start_connection()


## Abre a tela de pagamento do Google Play. Falha na hora se o serviço não estiver pronto.
func purchase(product: String) -> void:
	_buying = product
	if not is_ready() or not product in _products:
		purchase_state.emit(product, "failed")
		return
	var response: Dictionary = _client.purchase(product)
	if int(response.get("response_code", BillingClient.BillingResponseCode.OK)) \
			!= BillingClient.BillingResponseCode.OK:
		purchase_state.emit(product, "failed")


func _on_connected() -> void:
	_client.query_product_details(_products, BillingClient.ProductType.INAPP)
	_client.query_purchases(BillingClient.ProductType.INAPP)


func _on_product_details(response: Dictionary) -> void:
	if int(response.get("response_code", -1)) != BillingClient.BillingResponseCode.OK:
		return
	for details: Variant in response.get("product_details", []):
		if not details is Dictionary:
			continue
		var product := String((details as Dictionary).get("product_id", ""))
		var text := _find_formatted_price(details)
		if product in _products and not text.is_empty():
			prices[product] = text
			product_price_changed.emit(product, text)


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
## Fora da consulta (compra em andamento), cancelar ou falhar responde pelo produto comprado.
func _on_purchases(response: Dictionary, from_query: bool) -> void:
	var code := int(response.get("response_code", -1))
	if code == BillingClient.BillingResponseCode.USER_CANCELED:
		if not from_query:
			purchase_state.emit(_buying, "failed")
		return
	if code != BillingClient.BillingResponseCode.OK:
		if not from_query:
			purchase_state.emit(_buying, "failed")
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
					purchase_state.emit(product, "purchased")
				BillingClient.PurchaseState.PENDING:
					purchase_state.emit(product, "pending")
		# Uma confirmação por compra (o token vale para todos os produtos dela).
		if int(purchase.get("purchase_state", 0)) == BillingClient.PurchaseState.PURCHASED \
				and not bool(purchase.get("is_acknowledged", false)) and ids.any(
				func(id: Variant) -> bool: return String(id) in _products):
			_client.acknowledge_purchase(String(purchase.get("purchase_token", "")))
	if from_query:
		for product: String in _products:
			if not found.has(product):
				purchase_state.emit(product, "refunded")
