extends Node
## Compra única "Remover anúncio de abertura" (plano 17.7). Dois provedores:
## - "play": Google Play Billing (PlayBillingProvider), no Android com o plugin nativo;
## - "mock": compra simulada, no PC e nos testes.
## Regras: confirmação (acknowledge) após a entrega, restauração ao abrir, estado pendente
## não libera, reembolso faz o anúncio de abertura voltar.
## No modo "sem anúncios" (AdsManager.ads_enabled = false) a compra não faz sentido: fica
## indisponível (available() = false), as telas a escondem e o Play Billing nem é conectado.

signal purchase_finished(product: String, ok: bool)

const PRODUCT := "remove_open_ad"
const PRICE_TEXT := "US$ 2,99"

var provider: String = "mock"
## Para testes: simula pagamento pendente (boleto, dinheiro).
var mock_pending: bool = false

var _play: PlayBillingProvider


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--purchase-pending":
			mock_pending = true
	if not AdsManager.ads_enabled:
		provider = "off"
		return
	if PlayBillingProvider.is_supported():
		provider = "play"
		_play = PlayBillingProvider.new()
		add_child(_play)
		_play.purchase_state.connect(_on_play_state)
		_play.setup(PRODUCT)
	restore()


## A compra "Remover anúncio de abertura" existe só enquanto há anúncios.
func available() -> bool:
	return AdsManager.ads_enabled


func owns(product: String = PRODUCT) -> bool:
	return bool(SaveManager.data["purchases"].get(product, false))


func price_text() -> String:
	if _play != null and not _play.price.is_empty():
		return _play.price
	return PRICE_TEXT


func purchase(product: String = PRODUCT) -> void:
	if owns(product):
		purchase_finished.emit(product, true)
		return
	if not available():
		purchase_finished.emit(product, false)
		return
	if provider == "play":
		_play.purchase()
		return
	if mock_pending:
		SaveManager.data["purchases"]["pending"] = true
		SaveManager.save_profile()
		purchase_finished.emit(product, false)
		return
	_deliver(product)


## Entrega e confirma a compra (no Play real: acknowledgePurchase em até 3 dias).
func _deliver(product: String) -> void:
	SaveManager.data["purchases"][product] = true
	SaveManager.data["purchases"]["pending"] = false
	SaveManager.data["purchases"]["acknowledged"] = true
	SaveManager.unlock("cosmetics", &"golden_lantern")
	SaveManager.save_profile()
	purchase_finished.emit(product, true)


## Ao abrir: consulta as compras do usuário (no Play real: queryPurchases).
func restore() -> void:
	if not available():
		return
	if provider == "play":
		_play.restore()
		return
	var purchases: Dictionary = SaveManager.data["purchases"]
	if bool(purchases.get("pending", false)) and not mock_pending:
		_deliver(PRODUCT)


## Simula um reembolso feito pelo Play Console (para o teste 14.2).
func mock_refund(product: String = PRODUCT) -> void:
	SaveManager.data["purchases"][product] = false
	SaveManager.save_profile()


func _on_play_state(product: String, state: String) -> void:
	match state:
		"purchased":
			if not owns(product):
				_deliver(product)
			else:
				purchase_finished.emit(product, true)
		"pending":
			SaveManager.data["purchases"]["pending"] = true
			SaveManager.save_profile()
			purchase_finished.emit(product, false)
		"refunded":
			if owns(product):
				mock_refund(product)
		_:
			purchase_finished.emit(product, false)
