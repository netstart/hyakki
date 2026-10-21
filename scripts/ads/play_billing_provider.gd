class_name PlayBillingProvider
extends Node
## Provedor real de compras (plano 17.7): Google Play Billing pelo plugin oficial
## GodotGooglePlayBilling (addons/GodotGooglePlayBilling, MIT). Só no Android com o plugin.
## Sem Play Store (emulador sem Google Play, aparelho sem conta) a conexão falha e a compra
## responde "não concluída"; nada é liberado sem confirmação do Google.

signal product_price_changed(price: String)
## state: "purchased", "pending", "failed", "refunded"
signal purchase_state(product: String, state: String)

const SINGLETON := "GodotGooglePlayBilling"

var price: String = ""
var _client: BillingClient
var _product: String


static func is_supported() -> bool:
	return OS.get_name() == "Android" and Engine.has_singleton(SINGLETON)


func setup(product: String) -> void:
	_product = product
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


func is_ready() -> bool:
	return _client != null and _client.is_ready()


func restore() -> void:
	if is_ready():
		_client.query_purchases(BillingClient.ProductType.INAPP)
	elif _client != null:
		_client.start_connection()


## Abre a tela de pagamento do Google Play. Falha na hora se o serviço não estiver pronto.
func purchase() -> void:
	if not is_ready():
		purchase_state.emit(_product, "failed")
		return
	var response: Dictionary = _client.purchase(_product)
	if int(response.get("response_code", BillingClient.BillingResponseCode.OK)) \
			!= BillingClient.BillingResponseCode.OK:
		purchase_state.emit(_product, "failed")


func _on_connected() -> void:
	_client.query_product_details(PackedStringArray([_product]), BillingClient.ProductType.INAPP)
	_client.query_purchases(BillingClient.ProductType.INAPP)


func _on_product_details(response: Dictionary) -> void:
	if int(response.get("response_code", -1)) != BillingClient.BillingResponseCode.OK:
		return
	for details: Variant in response.get("product_details", []):
		var text := _find_formatted_price(details)
		if not text.is_empty():
			price = text
			product_price_changed.emit(price)


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


## `from_query`: resposta de queryPurchases (lista completa; ausência = reembolsado).
func _on_purchases(response: Dictionary, from_query: bool) -> void:
	var code := int(response.get("response_code", -1))
	if code == BillingClient.BillingResponseCode.USER_CANCELED:
		purchase_state.emit(_product, "failed")
		return
	if code != BillingClient.BillingResponseCode.OK:
		if not from_query:
			purchase_state.emit(_product, "failed")
		return
	var found := false
	for item: Variant in response.get("purchases", []):
		var purchase: Dictionary = item
		if not _product in Array(purchase.get("product_ids", [])):
			continue
		found = true
		match int(purchase.get("purchase_state", 0)):
			BillingClient.PurchaseState.PURCHASED:
				purchase_state.emit(_product, "purchased")
				if not bool(purchase.get("is_acknowledged", false)):
					_client.acknowledge_purchase(String(purchase.get("purchase_token", "")))
			BillingClient.PurchaseState.PENDING:
				purchase_state.emit(_product, "pending")
	if from_query and not found:
		purchase_state.emit(_product, "refunded")
