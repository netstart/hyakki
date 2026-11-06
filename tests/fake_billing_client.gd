extends BillingClient
## BillingClient falso para os testes do PlayBillingProvider (tests/play_billing_tests.gd): no PC
## não há o singleton do plugin, então BillingClient._init não toca em nada. Guarda cada chamada
## em `calls` e só responde quando o teste manda (connect_now, answer_details, answer_purchases,
## purchase_update), como a Play, que responde depois por sinal.

## isReady() da Play.
var play_ready: bool = false
## Chamadas recebidas, em ordem: ["start_connection"], ["query_product_details", ids],
## ["query_purchases"], ["purchase", id], ["acknowledge_purchase", token].
var calls: Array = []
## Respostas de purchase() (launchBillingFlow), uma por chamada; vazia = OK.
var launch_results: Array[Dictionary] = []


func is_ready() -> bool:
	return play_ready


func start_connection() -> void:
	calls.append(["start_connection"])


func query_product_details(product_list: PackedStringArray, product_type: ProductType) -> void:
	calls.append(["query_product_details", Array(product_list), product_type])


func query_purchases(product_type: ProductType, include_suspended_subs: bool = false) -> void:
	calls.append(["query_purchases", product_type, include_suspended_subs])


func purchase(product_id: String, purchase_option_id: String = "", offer_id: String = "",
		is_offer_personalized: bool = false) -> Dictionary:
	calls.append(["purchase", product_id, purchase_option_id, offer_id, is_offer_personalized])
	if launch_results.is_empty():
		return {"response_code": BillingResponseCode.OK, "debug_message": ""}
	return launch_results.pop_front()


func acknowledge_purchase(purchase_token: String) -> void:
	calls.append(["acknowledge_purchase", purchase_token])


## Quantas chamadas de `method` chegaram.
func count(method: String) -> int:
	return calls.filter(func(entry: Array) -> bool: return entry[0] == method).size()


## A conexão com a Play fica pronta (onBillingSetupFinished OK).
func connect_now() -> void:
	play_ready = true
	connected.emit()


## Resposta de queryProductDetails: `ids` com detalhes (preço "R$ 1,00"), `missing` em unfetched.
func answer_details(ids: Array, missing: Array = [], code: int = BillingResponseCode.OK) -> void:
	var details: Array = []
	for id: Variant in ids:
		details.append({"product_id": String(id),
				"one_time_purchase_offer_details": {"formatted_price": "R$ 1,00"}})
	query_product_details_response.emit({"response_code": code, "debug_message": "",
			"product_details": details, "unfetched_products": missing})


## Resposta de queryPurchases com estas compras (make_purchase).
func answer_purchases(purchases: Array, code: int = BillingResponseCode.OK) -> void:
	query_purchases_response.emit({"response_code": code, "debug_message": "", "purchases": purchases})


## onPurchasesUpdated da tela de pagamento.
func purchase_update(code: int, purchases: Array = []) -> void:
	on_purchase_updated.emit({"response_code": code, "debug_message": "teste", "purchases": purchases})


static func make_purchase(product: String, state: int = PurchaseState.PURCHASED,
		acknowledged: bool = false) -> Dictionary:
	return {"product_ids": [product], "purchase_state": state, "is_acknowledged": acknowledged,
			"purchase_token": "token_%s" % product}
