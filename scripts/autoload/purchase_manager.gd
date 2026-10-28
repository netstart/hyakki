extends Node
## Compras únicas (plano 17.7), ambas permanentes (não consumíveis):
## - "remove_open_ad" (PRODUCT): "Apoie o jogo". O id é o da Play Console (não pode mudar) e vem
##   do tempo em que a compra removia o anúncio de abertura, que saiu do jogo. Dá a Lanterna
##   Dourada e faz as recompensas opcionais (Loja, Reviver, Dobrar ryō) chegarem de presente,
##   sem assistir anúncio (AdsManager.rewards_are_gifts()). Quem já tinha comprado recebe tudo
##   pela restauração, sem fazer nada. Só existe com anúncios;
## - "unlock_speed" (SPEED_PRODUCT): Ampulheta de Fūjin, libera a velocidade 2x/3x. Vale com ou
##   sem anúncios e pode ser comprada de dois jeitos: com ryō (SPEED_RYO_PRICE) ou com dinheiro.
## Dois provedores de dinheiro:
## - "play": Google Play Billing (PlayBillingProvider), no Android com o plugin nativo;
## - "mock": compra simulada, no PC e nos testes.
## Regras: confirmação (acknowledge) após a entrega, restauração ao abrir, estado pendente
## (por produto) não libera, reembolso revoga. A velocidade guarda a origem da posse
## ("ryo" | "play"): o reembolso só revoga a posse que veio da Play; quem pagou com ryō nunca perde.
## No modo "sem anúncios" (AdsManager.ads_enabled = false) "Apoie o jogo" fica indisponível
## (available() = false; as recompensas já são presentes) e as telas a escondem; o Play Billing
## conecta assim mesmo, pela Ampulheta.

signal purchase_finished(product: String, ok: bool)
## A Ampulheta passou a valer (compra com ryō, Play ou restauração): a partida libera 2x/3x na hora.
signal speed_unlocked
## A Ampulheta comprada na Play foi reembolsada: a partida volta a 1x.
signal speed_revoked

const PRODUCT := "remove_open_ad"
const PRICE_TEXT := "US$ 2,99"
const SPEED_PRODUCT := "unlock_speed"
## Preço em ryō: ~7 partidas boas de 15 min (cerca de 450 ryō cada, sem Loja nem Dobrar).
const SPEED_RYO_PRICE := 3000
## Preço de referência enquanto a Play não responde (o formatted_price real tem prioridade).
const SPEED_PRICE_BRL := "R$ 4,99"
const SPEED_PRICE_USD := "US$ 1,99"
const SOURCE_RYO := "ryo"
const SOURCE_PLAY := "play"
const PRODUCTS: Array[String] = [PRODUCT, SPEED_PRODUCT]

## "play", "mock" (PC e testes) ou "off" (sem loja de dinheiro: nada a comprar com dinheiro).
var provider: String = "mock"
## Para testes: simula pagamento pendente (boleto, dinheiro).
var mock_pending: bool = false

var _play: PlayBillingProvider


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--purchase-pending":
			mock_pending = true
	if PlayBillingProvider.is_supported():
		provider = "play"
		_play = PlayBillingProvider.new()
		add_child(_play)
		_play.purchase_state.connect(_on_play_state)
		_play.setup(PackedStringArray(PRODUCTS))
	elif OS.get_name() == "Android" and not OS.is_debug_build():
		# Build de release sem o plugin: não há como cobrar (a Ampulheta segue à venda por ryō).
		provider = "off"
	restore()


## "Apoie o jogo" existe só enquanto há anúncios (sem eles as recompensas já são presentes).
func available() -> bool:
	return AdsManager.ads_enabled


## Há como comprar com dinheiro (Play Billing ou o simulado do PC e dos testes).
func billing_available() -> bool:
	return provider == "play" or provider == "mock"


func owns(product: String = PRODUCT) -> bool:
	return bool(SaveManager.data["purchases"].get(product, false))


func price_text() -> String:
	if _play != null and not _play.price_of(PRODUCT).is_empty():
		return _play.price_of(PRODUCT)
	return PRICE_TEXT


func purchase(product: String = PRODUCT) -> void:
	if not product in PRODUCTS:
		purchase_finished.emit(product, false)
		return
	if owns(product):
		purchase_finished.emit(product, true)
		return
	if (product == PRODUCT and not available()) or not billing_available():
		purchase_finished.emit(product, false)
		return
	if provider == "play":
		_play.purchase(product)
		return
	if mock_pending:
		_set_pending(product, true)
		SaveManager.save_profile()
		purchase_finished.emit(product, false)
		return
	_deliver(product)


func is_pending(product: String = PRODUCT) -> bool:
	return bool(SaveManager.data["purchases"].get(_pending_key(product), false))


# --- Ampulheta de Fūjin (velocidade 2x/3x) ----------------------------------------------

func owns_speed() -> bool:
	return owns(SPEED_PRODUCT)


## "ryo", "play" ou "" (sem a posse).
func speed_source() -> String:
	return String(SaveManager.data["purchases"].get("unlock_speed_source", "")) if owns_speed() else ""


## A compra com dinheiro aparece na Loja: Play Billing real ou o simulado.
func speed_available_for_money() -> bool:
	return billing_available() and not owns_speed()


## Preço em dinheiro: o da Play (formatted_price) ou, enquanto ela não responde, o de referência
## do idioma (R$ 4,99 em pt_BR; US$ 1,99 nos outros).
func speed_price_text() -> String:
	if _play != null and not _play.price_of(SPEED_PRODUCT).is_empty():
		return _play.price_of(SPEED_PRODUCT)
	return SPEED_PRICE_BRL if TranslationServer.get_locale().begins_with("pt") else SPEED_PRICE_USD


func can_buy_speed_with_ryo() -> bool:
	return not owns_speed() and SaveManager.ryo() >= SPEED_RYO_PRICE


## Compra com ryō: debita e libera na hora. Sem saldo ou já liberada, não faz nada.
func buy_speed_with_ryo() -> bool:
	if not can_buy_speed_with_ryo():
		return false
	# Fora do "spent" (base do reembolso do Santuário), como os reforços: não se devolve.
	SaveManager.add_ryo(-SPEED_RYO_PRICE)
	_grant_speed(SOURCE_RYO)
	SaveManager.save_profile()
	purchase_finished.emit(SPEED_PRODUCT, true)
	return true


## Compra com dinheiro (Play ou simulada).
func buy_speed_with_money() -> void:
	purchase(SPEED_PRODUCT)


func _grant_speed(source: String) -> void:
	var purchases: Dictionary = SaveManager.data["purchases"]
	var was := owns_speed()
	purchases[SPEED_PRODUCT] = true
	# Quem já tinha pelo ryō e depois paga na Play passa a constar como Play (a posse fica igual).
	if not was or source == SOURCE_PLAY:
		purchases["unlock_speed_source"] = source
	purchases[_pending_key(SPEED_PRODUCT)] = false
	if not was:
		speed_unlocked.emit()


# --- Entrega, restauração e reembolso --------------------------------------------------

## Entrega e confirma a compra em dinheiro (no Play real: acknowledgePurchase em até 3 dias).
func _deliver(product: String) -> void:
	if product == SPEED_PRODUCT:
		_grant_speed(SOURCE_PLAY)
	else:
		SaveManager.data["purchases"][product] = true
		_set_pending(product, false)
		SaveManager.data["purchases"]["acknowledged"] = true
		SaveManager.unlock("cosmetics", &"golden_lantern")
	SaveManager.save_profile()
	purchase_finished.emit(product, true)


## Ao abrir e no botão "Restaurar compras": consulta as compras do usuário (no Play real:
## queryPurchases, que traz os dois produtos).
func restore() -> void:
	if provider == "play":
		_play.restore()
		return
	if provider != "mock" or mock_pending:
		return
	if available() and is_pending(PRODUCT):
		_deliver(PRODUCT)
	if is_pending(SPEED_PRODUCT):
		_deliver(SPEED_PRODUCT)


## Reembolso feito pelo Play Console (também simula o teste 14.2). A Ampulheta só é revogada
## se veio da Play: a comprada com ryō fica.
func mock_refund(product: String = PRODUCT) -> void:
	var purchases: Dictionary = SaveManager.data["purchases"]
	if product == SPEED_PRODUCT:
		if not owns_speed() or speed_source() != SOURCE_PLAY:
			return
		purchases["unlock_speed_source"] = ""
	purchases[product] = false
	SaveManager.save_profile()
	if product == SPEED_PRODUCT:
		speed_revoked.emit()


## Chave do estado pendente de cada produto ("pending" é a de "Apoie o jogo", nome dos saves antigos).
func _pending_key(product: String) -> String:
	return "pending" if product == PRODUCT else "%s_pending" % product


func _set_pending(product: String, value: bool) -> void:
	SaveManager.data["purchases"][_pending_key(product)] = value


func _on_play_state(product: String, state: String) -> void:
	if not product in PRODUCTS:
		return
	match state:
		"purchased":
			if product == SPEED_PRODUCT and speed_source() != SOURCE_PLAY:
				_deliver(product)
			elif not owns(product):
				_deliver(product)
			else:
				purchase_finished.emit(product, true)
		"pending":
			_set_pending(product, true)
			SaveManager.save_profile()
			purchase_finished.emit(product, false)
		"refunded":
			if owns(product):
				mock_refund(product)
		_:
			purchase_finished.emit(product, false)
