class_name AdMobProvider
extends Node
## Provedor real de anúncios (plano 17.1): Google Mobile Ads + UMP pelo plugin Poing AdMob
## (addons/admob, MIT). Só é usado no Android quando o singleton nativo existe; no PC e nos
## testes o AdsManager usa o provedor simulado.
##
## IDs: em build de debug usa os IDs de TESTE oficiais do Google, que nunca geram receita
## nem infringem a política de cliques. Em build de release sem IDs reais o jogo fica no modo
## "sem anúncios" (AdsManager.ads_enabled = false): o SDK e o UMP nunca são iniciados e as
## recompensas são entregues de presente, sem anúncio. Só há o bloco recompensado: o jogo não
## tem anúncio de abertura (App Open).
##
## A conta de produção está configurada em `RELEASE_UNITS` e em
## `admob/general/android/app_id` no project.godot. Para mudar de conta, atualize os dois IDs;
## o exportador do Poing grava o ID do app no AndroidManifest.

signal ready_changed

const SINGLETON := "PoingGodotAdMob"
## Blocos de anúncio de teste do Google (developers.google.com/admob/android/test-ads).
const TEST_UNITS := {
	"rewarded": "ca-app-pub-3940256099942544/5224354917",
}
## IDs de produção dos blocos AdMob (plano 17.1).
const RELEASE_UNITS := {
	"rewarded": "ca-app-pub-6552169828297838/5734137356",
}
const RETRY_SECONDS := 20.0
## Configuração do Poing com o ID do app AdMob (vai para o AndroidManifest na exportação).
const APP_ID_SETTING := "admob/general/android/app_id"
## Conta de publisher dos IDs de teste do Google (blocos e app): nunca valem como "reais".
const TEST_PUBLISHER := "ca-app-pub-3940256099942544"

var initialized: bool = false
var _rewarded: RewardedAd
var _rewarded_loader: RewardedAdLoader
var _loading_rewarded: bool = false


static func is_supported() -> bool:
	return OS.get_name() == "Android" and Engine.has_singleton(SINGLETON)


## Os IDs reais do AdMob estão preenchidos (blocos em RELEASE_UNITS e ID do app no projeto).
static func has_release_ids() -> bool:
	return ids_configured(RELEASE_UNITS, String(ProjectSettings.get_setting(APP_ID_SETTING, "")))


## Regra pura (testável): todo bloco preenchido e o ID do app preenchido, nenhum de teste.
static func ids_configured(units: Dictionary, app_id: String) -> bool:
	if units.is_empty() or not _is_real_id(app_id, "~"):
		return false
	for kind: String in units:
		if not _is_real_id(String(units[kind]), "/"):
			return false
	return true


static func _is_real_id(id: String, separator: String) -> bool:
	id = id.strip_edges()
	return id.begins_with("ca-app-pub-") and id.contains(separator) and not id.begins_with(TEST_PUBLISHER)


## Anúncios ligados: build de debug (IDs de teste/simulado, como sempre) ou release com IDs reais.
static func ads_allowed() -> bool:
	return OS.is_debug_build() or has_release_ids()


static func unit(kind: String) -> String:
	var release := String(RELEASE_UNITS.get(kind, ""))
	if OS.is_debug_build() or release.is_empty():
		return String(TEST_UNITS[kind])
	return release


## Consentimento pelo formulário oficial do Google (UMP) e, depois, inicializa o SDK.
## `done()` é chamado sempre, mesmo se o UMP falhar ou estiver sem internet.
func start(done: Callable) -> void:
	var params := ConsentRequestParameters.new()
	UserMessagingPlatform.consent_information.update(params,
			func() -> void: _after_consent_info(done),
			func(_error: FormError) -> void: _initialize(done))


func _after_consent_info(done: Callable) -> void:
	var info := UserMessagingPlatform.consent_information
	if info.get_consent_status() == ConsentInformation.ConsentStatus.REQUIRED \
			and info.get_is_consent_form_available():
		UserMessagingPlatform.load_consent_form(
				func(form: ConsentForm) -> void:
					form.show(func(_error: FormError) -> void: _initialize(done)),
				func(_error: FormError) -> void: _initialize(done))
	else:
		_initialize(done)


func _initialize(done: Callable) -> void:
	var listener := OnInitializationCompleteListener.new()
	listener.on_initialization_complete = func(_status: InitializationStatus) -> void:
		initialized = true
		load_rewarded()
		done.call()
	var config := RequestConfiguration.new()
	# Jogo para público geral (13+): conteúdo de anúncio limitado a "T" (plano 17.5).
	config.max_ad_content_rating = RequestConfiguration.MAX_AD_CONTENT_RATING_T
	MobileAds.set_request_configuration(config)
	MobileAds.initialize(listener)


## O formulário de opções de privacidade do UMP (Opções › Privacidade e anúncios).
func privacy_options_required() -> bool:
	return UserMessagingPlatform.consent_information.get_privacy_options_requirement_status() \
			== ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED


func show_privacy_options(done: Callable) -> void:
	UserMessagingPlatform.show_privacy_options_form(func(_error: FormError) -> void: done.call())


# --- Recompensado -------------------------------------------------------------------

func rewarded_ready() -> bool:
	return _rewarded != null


func load_rewarded() -> void:
	if _loading_rewarded or _rewarded != null or not initialized:
		return
	_loading_rewarded = true
	_rewarded_loader = RewardedAdLoader.new()
	var callback := RewardedAdLoadCallback.new()
	callback.on_ad_loaded = func(ad: RewardedAd) -> void:
		_loading_rewarded = false
		_rewarded = ad
		ready_changed.emit()
	callback.on_ad_failed_to_load = func(error: LoadAdError) -> void:
		_loading_rewarded = false
		push_warning("AdMob: recompensado não carregou (%d) %s" % [error.code, error.message])
		get_tree().create_timer(RETRY_SECONDS, true).timeout.connect(load_rewarded)
	_rewarded_loader.load(unit("rewarded"), AdRequest.new(), callback)


## `done(rewarded)`: true só se o Google confirmar a recompensa (assistido até o fim).
func show_rewarded(done: Callable) -> void:
	if _rewarded == null:
		done.call(false)
		return
	var ad := _rewarded
	_rewarded = null
	var state := {"earned": false, "finished": false}
	var finish := func() -> void:
		if bool(state["finished"]):
			return
		state["finished"] = true
		ad.destroy()
		load_rewarded()
		done.call(bool(state["earned"]))
	var callbacks := FullScreenContentCallback.new()
	callbacks.on_ad_dismissed_full_screen_content = finish
	callbacks.on_ad_failed_to_show_full_screen_content = func(_error: AdError) -> void: finish.call()
	ad.full_screen_content_callback = callbacks
	var reward := OnUserEarnedRewardListener.new()
	reward.on_user_earned_reward = func(_item: RewardedItem) -> void: state["earned"] = true
	ad.show(reward)
