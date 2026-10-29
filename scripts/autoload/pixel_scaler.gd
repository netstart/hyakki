extends Node
## Escala inteira da tela (plano 8.2): k = min(round(altura / 300), floor(largura / 480)), k ≥ 1.
## No Redmi (2712×1220) dá k = 4 e 678×305 pixels lógicos, nítidos.
## O segundo termo só pesa em telas quase quadradas (Galaxy Z Fold aberto, tablets 4:3): sem ele
## a tela lógica ficaria estreita demais (362×302, 409×307) para os menus e para a visão da
## partida; com ele o fator desce um passo inteiro e a tela fica mais alta (544×453, 512×384).
## Em todos os celulares 19.5:9 a 22:9 e nos tablets 16:10 os dois termos dão o mesmo k.
##
## Também é a fonte única da troca de área segura (recorte da câmera): girar o celular 180° leva
## o furo para o outro lado SEM redimensionar a janela, então o sinal safe_insets_changed sai de
## uma checagem barata (a cada INSET_POLL s, só no celular), do size_changed da raiz e, nos
## testes, na hora em que MenuKit.set_test_insets troca o recorte simulado. Quem usa liga por
## MenuKit.on_insets_change (desliga sozinho com o nó).

signal safe_insets_changed

const TARGET_HEIGHT := 300.0
## Largura lógica mínima: o fator nunca deixa a tela lógica mais estreita que isto (se k ≥ 1 der).
const MIN_WIDTH := 480.0
## Intervalo da checagem da área segura no celular (segundos).
const INSET_POLL := 0.25

var scale_factor: int = 1
## Última área segura vista: [área segura física, tamanho da tela, recorte simulado dos testes].
var _last_safe: Array = []
var _inset_wait := 0.0


func _ready() -> void:
	# Segue checando com o jogo pausado (giro do celular com a pausa aberta).
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.size_changed.connect(_on_size_changed)
	_apply()
	_last_safe = _safe_key()
	set_process(OS.has_feature("mobile"))


func _apply() -> void:
	var root := get_tree().root
	var window_size := root.size
	if window_size.y <= 0:
		return
	scale_factor = factor_for(window_size)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = Vector2i(
		floori(float(window_size.x) / scale_factor),
		floori(float(window_size.y) / scale_factor)
	)


## Fator inteiro para uma tela física: k = round(altura / 300), limitado para a largura lógica
## não ficar abaixo de MIN_WIDTH, e nunca menor que 1.
static func factor_for(physical: Vector2i) -> int:
	return maxi(1, mini(roundi(physical.y / TARGET_HEIGHT), floori(physical.x / MIN_WIDTH)))


func _process(delta: float) -> void:
	_inset_wait -= delta
	if _inset_wait > 0.0:
		return
	_inset_wait = INSET_POLL
	check_safe_insets()


func _on_size_changed() -> void:
	_apply()
	check_safe_insets()


## Emite safe_insets_changed se a área segura (ou o recorte simulado dos testes) mudou desde a
## última vez.
func check_safe_insets() -> void:
	var key := _safe_key()
	if key == _last_safe:
		return
	_last_safe = key
	safe_insets_changed.emit()


func _safe_key() -> Array:
	var simulated: Variant = MenuKit.test_insets if MenuKit.test_insets_enabled else null
	if not OS.has_feature("mobile"):
		return [null, null, simulated]
	return [DisplayServer.get_display_safe_area(), DisplayServer.screen_get_size(), simulated]
