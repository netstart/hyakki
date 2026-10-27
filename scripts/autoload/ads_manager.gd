extends Node
## Anúncios (plano 17): abertura (App Open) e recompensados (Loja, Reviver, Dobrar ryō).
## O jogo só conversa com este autoload (plano 17.1). Dois provedores:
## - "admob": Google Mobile Ads + UMP (AdMobProvider), no Android com o plugin nativo;
## - "mock": overlay de teste, no PC, nos testes automáticos e se o plugin faltar.
##
## Modo "sem anúncios" (`ads_enabled = false`): build de release sem os IDs reais do AdMob
## (AdMobProvider.has_release_ids()), ou forçado com `--ads-off`. Nele o SDK e o UMP nunca são
## iniciados (sem consentimento, sem pedido de anúncio, sem ID de publicidade), não há anúncio
## de abertura e cada recompensado entrega a recompensa na hora, de presente, sem mostrar nada.
## As telas trocam "ver anúncio" por textos de presente e escondem a compra "Remover anúncio
## de abertura" e "Privacidade e anúncios". Ao preencher os IDs reais tudo volta sozinho.
##
## Regras do anúncio de abertura (17.2): nunca na 1ª abertura; só no início a frio; no
## mínimo 4 h entre um e outro; não aparece para quem comprou "Remover anúncio de
## abertura"; se não carregar em 4 s, o jogo libera do mesmo jeito.

signal ad_finished(placement: String, rewarded: bool)

const OPEN_AD_MIN_INTERVAL := 4 * 3600
const OPEN_AD_TIMEOUT := 4.0
const MOCK_AD_SECONDS := 3.0

var provider: String = "mock"
## false no modo "sem anúncios" (ver acima). Os testes podem trocar em tempo de execução.
var ads_enabled: bool = true
## Para testes: simula falta de anúncio (sem internet / sem preenchimento).
var mock_fill: bool = true
## Para testes automáticos: responde sozinho (assiste até o fim).
var auto_answer: bool = false

var _layer: CanvasLayer
var _admob: AdMobProvider


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ads_enabled = AdMobProvider.ads_allowed()
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--ads-no-fill":
			mock_fill = false
		elif arg == "--ads-auto":
			auto_answer = true
		elif arg == "--ads-mock":
			provider = "forced_mock"
		elif arg == "--ads-off":
			ads_enabled = false
	if not ads_enabled:
		# Nada do SDK: nem o provedor real é criado.
		provider = "off"
		return
	# Roteiro E2E no emulador: anúncio simulado que responde sozinho (o AdMob abre outra Activity).
	if OS.is_debug_build() and FileAccess.file_exists(E2EDriver.FILE):
		provider = "forced_mock"
		auto_answer = true
	if provider == "mock" and AdMobProvider.is_supported():
		provider = "admob"
		_admob = AdMobProvider.new()
		_admob.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_admob)
	elif provider == "forced_mock":
		provider = "mock"


func uses_google_consent() -> bool:
	return ads_enabled and provider == "admob"


## Consentimento + inicialização do SDK. No AdMob o formulário é o UMP do Google (exigido
## para o Espaço Econômico Europeu); no simulado não há nada a fazer aqui.
func start(done: Callable) -> void:
	if ads_enabled and provider == "admob":
		_admob.start(func() -> void:
			SaveManager.data["consent"]["asked"] = true
			SaveManager.save_profile()
			done.call())
	else:
		done.call()


## Opções › Privacidade e anúncios. Devolve false se a tela própria deve ser usada.
func open_privacy_options(done: Callable) -> bool:
	if not ads_enabled or provider != "admob":
		return false
	_admob.show_privacy_options(done)
	return true


## Sem anúncios a recompensa é sempre um presente disponível.
func rewarded_available() -> bool:
	if not ads_enabled:
		return true
	if provider == "admob":
		return _admob.rewarded_ready()
	return mock_fill


func should_show_app_open() -> bool:
	if not ads_enabled:
		return false
	var data := SaveManager.data
	if int(data["launches"]) < 2:
		return false
	if bool(data["purchases"]["remove_open_ad"]):
		return false
	var now := int(Time.get_unix_time_from_system())
	return now - int(data["last_open_ad_unix"]) >= OPEN_AD_MIN_INTERVAL


## Mostra o anúncio de abertura e chama `done` quando o jogador pode jogar.
func show_app_open(done: Callable) -> void:
	if not ads_enabled:
		done.call()
		return
	if provider == "admob":
		var waited := 0.0
		while not _admob.app_open_ready() and waited < OPEN_AD_TIMEOUT:
			await get_tree().create_timer(0.1, true).timeout
			waited += 0.1
		if not _admob.app_open_ready():
			done.call()
			return
		_mark_open_ad_seen()
		_muted(true)
		_admob.show_app_open(func() -> void:
			_muted(false)
			ad_finished.emit("open", false)
			done.call())
		return
	if not mock_fill:
		# Não carregou dentro do tempo: libera o jogo do mesmo jeito.
		await get_tree().create_timer(minf(OPEN_AD_TIMEOUT, 0.5)).timeout
		done.call()
		return
	_mark_open_ad_seen()
	_show_mock("open", false, func(_rewarded: bool) -> void: done.call())


func _mark_open_ad_seen() -> void:
	SaveManager.data["last_open_ad_unix"] = int(Time.get_unix_time_from_system())
	SaveManager.data["open_ads_seen"] = int(SaveManager.data["open_ads_seen"]) + 1
	SaveManager.save_profile()


## Anúncio recompensado. `done(rewarded)` só recebe true se assistido até o fim (17.3).
## Sem anúncios: entrega na hora (done(true)), sem tela nenhuma.
func show_rewarded(placement: String, done: Callable) -> void:
	if not ads_enabled:
		ad_finished.emit(placement, true)
		done.call(true)
		return
	if not rewarded_available():
		done.call(false)
		return
	if provider == "admob":
		var tree := get_tree()
		var was_paused := tree.paused
		tree.paused = true
		_muted(true)
		_admob.show_rewarded(func(rewarded: bool) -> void:
			_muted(false)
			tree.paused = was_paused
			ad_finished.emit(placement, rewarded)
			done.call(rewarded))
		return
	_show_mock(placement, true, done)


func _muted(on: bool) -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), on)
	if not on:
		AudioManager.apply_volumes()


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
