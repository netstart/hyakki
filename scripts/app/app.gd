class_name App
extends Node
## Roteador do jogo (plano 7.3): abertura → [consentimento na 1ª vez] → [anúncio de
## abertura, 17.2] → [introdução na 1ª vez] → título → heróis → fases → partida →
## resultados. Também trata o botão "voltar" do Android e o fim da história.
##
## Com argumentos de teste (`--bot`, `--play`), pula os menus e abre a partida direto.

const GAME_SCENE := "res://scenes/game/Game.tscn"
const SCREENS := {
	&"title": "res://scripts/app/screens/title_screen.gd",
	&"heroes": "res://scripts/app/screens/hero_screen.gd",
	&"stages": "res://scripts/app/screens/stage_screen.gd",
	&"results": "res://scripts/app/screens/results_screen.gd",
	&"sanctuary": "res://scripts/app/screens/sanctuary_screen.gd",
	&"shop": "res://scripts/app/screens/shop_screen.gd",
	&"codex": "res://scripts/app/screens/codex_screen.gd",
	&"options": "res://scripts/app/screens/options_screen.gd",
	&"credits": "res://scripts/app/screens/credits_screen.gd",
	&"licenses": "res://scripts/app/screens/licenses_screen.gd",
	&"story": "res://scripts/app/screens/story_screen.gd",
	&"consent": "res://scripts/app/screens/consent_screen.gd",
}

var selection: Dictionary = {}
var last_result: Dictionary = {}
var game: HyakkiGame
var current: StringName = &""

var _layer: CanvasLayer
var _root: Control
var _backdrop: MenuBackdrop
var _screens: Dictionary = {}
var _after_story: Callable = Callable()


func _ready() -> void:
	InputSetup.ensure_actions()
	get_tree().auto_accept_quit = false
	var args := OS.get_cmdline_user_args()
	if args.has("--bot") or args.has("--play"):
		_start_direct()
		return
	_layer = CanvasLayer.new()
	_layer.layer = 20
	add_child(_layer)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = ThemeFactory.build()
	_layer.add_child(_root)
	_backdrop = MenuBackdrop.new()
	_root.add_child(_backdrop)
	Locale.language_changed.connect(_on_language_changed)
	SaveManager.data["launches"] = int(SaveManager.data["launches"]) + 1
	SaveManager.save_profile()
	selection = (SaveManager.data["selected"] as Dictionary).duplicate()
	_boot()


func _start_direct() -> void:
	game = load(GAME_SCENE).instantiate() as HyakkiGame
	add_child(game)


## Sequência da abertura a frio.
func _boot() -> void:
	if not bool(SaveManager.data["consent"]["asked"]):
		go(&"consent")
		return
	after_consent()


func after_consent() -> void:
	if AdsManager.should_show_app_open():
		_show_blank()
		AdsManager.show_app_open(_after_open_ad)
	else:
		_after_open_ad()


func _after_open_ad() -> void:
	if not bool(SaveManager.data["story"]["intro_seen"]):
		play_story(&"intro", func() -> void:
			SaveManager.data["story"]["intro_seen"] = true
			SaveManager.save_profile()
			go(&"title"))
		return
	go(&"title")
	# Oferta discreta de remover o anúncio de abertura, uma única vez (17.7).
	if int(SaveManager.data["open_ads_seen"]) >= 5 and not bool(SaveManager.data["remove_ad_offer_shown"]) \
			and not PurchaseManager.owns():
		SaveManager.data["remove_ad_offer_shown"] = true
		SaveManager.save_profile()
		go(&"shop")


func _show_blank() -> void:
	for screen: Screen in _screens.values():
		screen.visible = false


func go(name: StringName) -> void:
	if not _screens.has(name):
		var script := load(SCREENS[name]) as GDScript
		var screen := script.new() as Screen
		screen.app = self
		screen.visible = false
		_root.add_child(screen)
		_screens[name] = screen
	for key: StringName in _screens:
		(_screens[key] as Screen).visible = key == name
	current = name
	_backdrop.visible = name != &"story"
	var shown := _screens[name] as Screen
	shown.on_show()
	if name in [&"title", &"heroes", &"stages", &"sanctuary", &"shop", &"codex", &"options", &"credits", &"licenses"]:
		AudioManager.play_music("sanctuary" if name == &"sanctuary" else ("codex" if name == &"codex" else "title"))


func play_story(id: StringName, then: Callable) -> void:
	_after_story = then
	go(&"story")
	(_screens[&"story"] as Screen).call("play", id)


func story_finished() -> void:
	var then := _after_story
	_after_story = Callable()
	if then.is_valid():
		then.call()
	else:
		go(&"title")


func remember_selection() -> void:
	SaveManager.data["selected"] = selection.duplicate()
	SaveManager.save_profile()


## Monta a configuração da partida (com as recompensas da Loja guardadas) e começa.
func start_run(daily: bool = false) -> void:
	remember_selection()
	var cfg := {"hero": selection.get("hero", "aki"), "stage": selection.get("stage", "village"),
			"moon": int(selection.get("moon", 0)), "mode": selection.get("mode", "normal"),
			"endless": bool(selection.get("endless", false)), "speed": Settings.get_value("speed"),
			"cosmetic": selection.get("cosmetic", ""), "seed": 0}
	if daily:
		_apply_daily(cfg)
	else:
		var bonus := ShopManager.take_next_run_bonuses()
		cfg["shop_modifiers"] = bonus["modifiers"]
		cfg["ult_start"] = bonus["ult_start"]
		cfg["start_chest"] = bonus["start_chest"]
	_layer.visible = false
	game = load(GAME_SCENE).instantiate() as HyakkiGame
	game.config = cfg
	game.finished.connect(_on_run_finished)
	add_child(game)


## Desafio Diário: semente fixa pela data; herói e fase sorteados entre os liberados (4.13).
func _apply_daily(cfg: Dictionary) -> void:
	var date := Time.get_date_string_from_system()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("hyakki-daily-" + date)
	var heroes: Array[StringName] = []
	for id: StringName in DB.ids("heroes"):
		if MetaProgress.is_hero_unlocked(id):
			heroes.append(id)
	var stages: Array[StringName] = []
	for id: StringName in DB.ids("stages"):
		if MetaProgress.is_stage_unlocked(id):
			stages.append(id)
	cfg["hero"] = heroes[rng.randi_range(0, heroes.size() - 1)]
	cfg["stage"] = stages[rng.randi_range(0, stages.size() - 1)]
	cfg["seed"] = rng.randi()
	cfg["moon"] = 0
	cfg["mode"] = "normal"
	cfg["endless"] = false
	cfg["daily"] = true
	cfg["daily_date"] = date


func _on_run_finished(result: Dictionary) -> void:
	last_result = result
	if game:
		game.queue_free()
		game = null
	_layer.visible = true
	var story: Dictionary = SaveManager.data["story"]
	if bool(result["victory"]) and String(result["stage"]) == "yomi" and not bool(story["ending_seen"]):
		play_story(&"ending", func() -> void:
			story["ending_seen"] = true
			SaveManager.save_profile()
			go(&"results"))
		return
	if bool(result["victory"]) and String(result["stage"]) == "secret" and not bool(story["secret_ending_seen"]):
		play_story(&"secret_ending", func() -> void:
			story["secret_ending_seen"] = true
			SaveManager.save_profile()
			go(&"results"))
		return
	go(&"results")


func play_again() -> void:
	start_run(bool(last_result.get("daily", false)))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if game and game.running:
			game.open_pause()
			return
		if what == NOTIFICATION_WM_CLOSE_REQUEST or current == &"title":
			SaveManager.save_profile()
			get_tree().quit()
			return
		if _screens.has(current):
			(_screens[current] as Screen).on_back()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		SaveManager.save_profile()


func _unhandled_input(event: InputEvent) -> void:
	if game == null and event.is_action_pressed(&"pause") and _screens.has(current):
		(_screens[current] as Screen).on_back()


func _on_language_changed(_code: String) -> void:
	# Recria as telas para que todos os textos e a fonte regional sejam refeitos na hora.
	if _root == null:
		return
	_root.theme = ThemeFactory.build()
	var keep := current
	for screen: Screen in _screens.values():
		screen.queue_free()
	_screens.clear()
	go(keep if keep != &"" else &"title")
