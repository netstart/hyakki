extends Node
## Compra única "Remover anúncio de abertura" (plano 17.7).
## Provedor SIMULADO enquanto o plugin Google Play Billing não estiver no build Gradle
## (o emulador deste projeto não tem Play Store, então compra real não é testável aqui).
## Regras implementadas: confirmação (acknowledge) após a entrega, restauração ao abrir,
## estado pendente não libera, reembolso faz o anúncio de abertura voltar.

signal purchase_finished(product: String, ok: bool)

const PRODUCT := "remove_open_ad"
const PRICE_TEXT := "US$ 2,99"

var provider: String = "mock"
## Para testes: simula pagamento pendente (boleto, dinheiro).
var mock_pending: bool = false


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--purchase-pending":
			mock_pending = true
	restore()


func owns(product: String = PRODUCT) -> bool:
	return bool(SaveManager.data["purchases"].get(product, false))


func price_text() -> String:
	return PRICE_TEXT


func purchase(product: String = PRODUCT) -> void:
	if owns(product):
		purchase_finished.emit(product, true)
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
	var purchases: Dictionary = SaveManager.data["purchases"]
	if bool(purchases.get("pending", false)) and not mock_pending:
		_deliver(PRODUCT)


## Simula um reembolso feito pelo Play Console (para o teste 14.2).
func mock_refund(product: String = PRODUCT) -> void:
	SaveManager.data["purchases"][product] = false
	SaveManager.save_profile()
