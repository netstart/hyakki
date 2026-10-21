extends Node
## Anúncios (plano 17): abertura (App Open) e recompensados (Loja, Reviver, Dobrar ryō).
## O jogo só conversa com este autoload (plano 17.1). Hoje existe só o provedor SIMULADO,
## usado no PC, nos testes e enquanto o plugin AdMob não estiver instalado no build Gradle.
## Para ligar o AdMob real: instalar o plugin (17.1), implementar `_real_*` e trocar
## `provider` para "admob" quando o singleton do plugin existir.
##
## Regras do anúncio de abertura (17.2): nunca na 1ª abertura; só no início a frio; no
## mínimo 4 h entre um e outro; não aparece para quem comprou "Remover anúncio de
## abertura"; se não carregar em 4 s, o jogo libera do mesmo jeito.

signal ad_finished(placement: String, rewarded: bool)

const OPEN_AD_MIN_INTERVAL := 4 * 3600
const OPEN_AD_TIMEOUT := 4.0
const MOCK_AD_SECONDS := 3.0

var provider: String = "mock"
## Para testes: simula falta de anúncio (sem internet / sem preenchimento).
var mock_fill: bool = true
## Para testes automáticos: responde sozinho (assiste até o fim).
var auto_answer: bool = false

var _layer: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--ads-no-fill":
			mock_fill = false
		elif arg == "--ads-auto":
			auto_answer = true


func rewarded_available() -> bool:
	return mock_fill


func should_show_app_open() -> bool:
	var data := SaveManager.data
	if int(data["launches"]) < 2:
		return false
	if bool(data["purchases"]["remove_open_ad"]):
		return false
	var now := int(Time.get_unix_time_from_system())
	return now - int(data["last_open_ad_unix"]) >= OPEN_AD_MIN_INTERVAL


## Mostra o anúncio de abertura e chama `done` quando o jogador pode jogar.
func show_app_open(done: Callable) -> void:
	if not mock_fill:
		# Não carregou dentro do tempo: libera o jogo do mesmo jeito.
		await get_tree().create_timer(minf(OPEN_AD_TIMEOUT, 0.5)).timeout
		done.call()
		return
	SaveManager.data["last_open_ad_unix"] = int(Time.get_unix_time_from_system())
	SaveManager.data["open_ads_seen"] = int(SaveManager.data["open_ads_seen"]) + 1
	SaveManager.save_profile()
	_show_mock("open", false, func(_rewarded: bool) -> void: done.call())


## Anúncio recompensado. `done(rewarded)` só recebe true se assistido até o fim (17.3).
func show_rewarded(placement: String, done: Callable) -> void:
	if not rewarded_available():
		done.call(false)
		return
	_show_mock(placement, true, done)


func _show_mock(placement: String, rewarded_kind: bool, done: Callable) -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	var tree := get_tree()
	var was_paused := tree.paused
	_layer = CanvasLayer.new()
	_layer.layer = 100
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)
	var root := Panel.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.1, 0.97)
	root.add_theme_stylebox_override("panel", style)
	root.theme = ThemeFactory.build()
	_layer.add_child(root)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	center.add_child(box)
	var title := Label.new()
	title.text = tr("ads.mock_title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if Locale.font:
		title.add_theme_font_override("font", Locale.font)
	box.add_child(title)
	var counter := Label.new()
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if Locale.font:
		counter.add_theme_font_override("font", Locale.font)
	box.add_child(counter)
	var close_full := Button.new()
	close_full.text = tr("ads.continue") if not rewarded_kind else tr("ads.claim")
	close_full.disabled = true
	close_full.custom_minimum_size = Vector2(160, 32)
	box.add_child(close_full)
	var close_early := Button.new()
	close_early.text = tr("ads.close_early")
	close_early.custom_minimum_size = Vector2(160, 28)
	close_early.visible = rewarded_kind
	box.add_child(close_early)
	var state := {"done": false}
	var finish := func(rewarded: bool) -> void:
		if bool(state["done"]):
			return
		state["done"] = true
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), false)
		AudioManager.apply_volumes()
		tree.paused = was_paused
		_layer.queue_free()
		ad_finished.emit(placement, rewarded)
		done.call(rewarded)
	close_full.pressed.connect(func() -> void: finish.call(true))
	close_early.pressed.connect(func() -> void: finish.call(false))
	var left := MOCK_AD_SECONDS
	while left > 0.0 and not bool(state["done"]):
		counter.text = tr("ads.mock_counter") % ceili(left)
		await tree.create_timer(0.25, true, false, true).timeout
		left -= 0.25
		if auto_answer and left <= MOCK_AD_SECONDS - 0.5:
			break
	if bool(state["done"]):
		return
	counter.text = tr("ads.mock_ready")
	close_full.disabled = false
	if auto_answer:
		finish.call(true)
	# Nunca prende o jogador numa tela de anúncio: libera depois de 60 s (17.4).
	await tree.create_timer(60.0, true, false, true).timeout
	finish.call(true)
