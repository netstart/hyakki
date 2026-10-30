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
## Partida suspensa vale por 3 dias (plano 10.11).
const SUSPENDED_MAX_AGE := 3 * 24 * 3600
const SCENARIO_FILE := "user://scenario.txt"

var selection: Dictionary = {}
var last_result: Dictionary = {}
var game: HyakkiGame
var current: StringName = &""

var _layer: CanvasLayer
var _root: Control
var _backdrop: MenuBackdrop
var _screens: Dictionary = {}
var _after_story: Callable = Callable()
## Os scripts das telas já foram pedidos ao carregamento em segundo plano (_preload_screens).
var _preloading := false
## Melhor tempo da fase antes da partida atual (o MetaProgress.apply_run já o atualiza antes
## do fim): vai para last_result["prev_best_time"], para o selo de recorde dos Resultados.
var _prev_best_time: float = 0.0


func _ready() -> void:
	InputSetup.ensure_actions()
	# Listas roláveis rolam com o dedo começando em qualquer cartão ou botão (TouchScroll).
	TouchScroll.install(get_tree())
	get_tree().auto_accept_quit = false
	var args := OS.get_cmdline_user_args()
	if args.has("--bot") or args.has("--play"):
		_start_direct()
		return
	# Em execução pelo editor, libera os sete guardiões sem apagar o restante do save.
	if OS.is_debug_build() and SaveManager.unlock_all_heroes():
		SaveManager.save_profile()
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
	if OS.is_debug_build() and _scenario_from_args(args):
		return
	_show_splash()


## Abertura curta por cima de tudo; o resto do fluxo começa no fade de saída dela.
func _show_splash() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	var splash := SplashScreen.new()
	layer.add_child(splash)
	splash.finished.connect(_boot)
	splash.tree_exited.connect(layer.queue_free)


func _start_direct() -> void:
	game = load(GAME_SCENE).instantiate() as HyakkiGame
	add_child(game)


## Cenários de teste (debug): --scenario=chest|kami|revive|dawn|ending|secret abre uma partida
## já no ponto da tela a conferir à mão no aparelho (plano 14.2).
## No Android o cenário vem de user://scenario.txt (adb shell run-as ...; lido e apagado).
func _scenario_from_args(args: PackedStringArray) -> bool:
	var found: PackedStringArray = args.duplicate()
	if FileAccess.file_exists(SCENARIO_FILE):
		found.append("--scenario=" + FileAccess.get_file_as_string(SCENARIO_FILE).strip_edges())
		DirAccess.remove_absolute(SCENARIO_FILE)
	for arg: String in found:
		if not arg.begins_with("--scenario="):
			continue
		var name := arg.trim_prefix("--scenario=")
		if name.begins_with("hero:"):
			# Joga com um herói ainda bloqueado (ex.: hero:yuki), só para conferir no aparelho.
			selection["hero"] = name.trim_prefix("hero:")
		elif name == "ending":
			selection["stage"] = "yomi"
		elif name == "secret":
			selection["stage"] = "secret"
		AdsManager.start(func() -> void:
			start_run()
			await get_tree().create_timer(1.5).timeout
			# Reviver precisa do anúncio premiado já carregado (AdMob de teste demora alguns segundos).
			var waited := 0.0
			while name == "revive" and not AdsManager.rewarded_available() and waited < 15.0:
				await get_tree().create_timer(0.5).timeout
				waited += 0.5
			if game:
				game.apply_scenario(name))
		return true
	return false


## Sequência da abertura a frio: consentimento (onde exigido) → introdução (1ª vez) → título.
## Não há anúncio de abertura: nada de tela em branco esperando anúncio.
func _boot() -> void:
	if not AdsManager.ads_enabled:
		# Sem anúncios: nada a consentir (nenhum ID de publicidade é usado).
		AdsManager.start(after_consent)
		return
	if AdsManager.uses_google_consent():
		# AdMob: o formulário de consentimento é o UMP do Google (aparece só onde é exigido).
		_show_blank()
		AdsManager.start(after_consent)
		return
	if not bool(SaveManager.data["consent"]["asked"]):
		go(&"consent")
		return
	AdsManager.start(after_consent)


func after_consent() -> void:
	if not bool(SaveManager.data["story"]["intro_seen"]):
		play_story(&"intro", func() -> void:
			SaveManager.data["story"]["intro_seen"] = true
			SaveManager.save_profile()
			go(&"title"))
		return
	go(&"title")


func _show_blank() -> void:
	for screen: Screen in _screens.values():
		screen.visible = false


func go(name: StringName) -> void:
	if not _screens.has(name):
		var script := _screen_script(name)
		var screen := script.new() as Screen
		screen.app = self
		screen.visible = false
		_root.add_child(screen)
		_screens[name] = screen
	for key: StringName in _screens:
		(_screens[key] as Screen).visible = key == name
	current = name
	if name == &"title":
		_preload_screens()
	var shown := _screens[name] as Screen
	# Telas que pintam o próprio fundo inteiro (história, resultados) cobrem o fundo animado:
	# escondido, ele nem anima nem desenha (era custo de cada quadro sem aparecer na tela).
	_backdrop.visible = name != &"story" and not shown.opaque_background
	shown.on_show()
	# Controles ajustados depois de entrar na árvore (on_show refaz listas) também rolam pelo dedo.
	TouchScroll.adopt_all.call_deferred(shown)
	if name in [&"title", &"heroes", &"stages", &"sanctuary", &"shop", &"codex", &"options", &"credits", &"licenses"]:
		var screen_music := {&"sanctuary": "sanctuary", &"codex": "codex", &"credits": "credits"}
		AudioManager.play_music(String(screen_music.get(name, "title")))


## Na 1ª vez no título, compila em segundo plano os scripts das outras telas (ResourceLoader em
## thread): a 1ª abertura de cada tela não paga mais a carga do script (70–150 ms no PC, várias
## vezes isso no celular), que era um tranco no toque. Só os scripts; as telas são montadas
## quando abrem, como antes.
func _preload_screens() -> void:
	if _preloading:
		return
	_preloading = true
	for key: StringName in SCREENS:
		var path := String(SCREENS[key])
		if not _screens.has(key) and not ResourceLoader.has_cached(path):
			ResourceLoader.load_threaded_request(path, "GDScript")


## Script da tela: o pré-carregado em segundo plano (espera terminar, se ainda estiver
## carregando) ou carregado agora.
func _screen_script(name: StringName) -> GDScript:
	var path := String(SCREENS[name])
	if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		var threaded := ResourceLoader.load_threaded_get(path) as GDScript
		if threaded != null:
			return threaded
	return load(path) as GDScript


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
	_remember_best(String(cfg["stage"]))
	_layer.visible = false
	game = load(GAME_SCENE).instantiate() as HyakkiGame
	game.config = cfg
	game.finished.connect(_on_run_finished)
	add_child(game)


## Fundo animado dos menus (a guardiã sob o torii; o balão de dicas do título aponta para ela).
func backdrop() -> MenuBackdrop:
	return _backdrop


func has_suspended_run() -> bool:
	var s: Dictionary = SaveManager.data.get("suspended", {})
	if s.is_empty() or int(s.get("version", 0)) != 1:
		return false
	var age := int(Time.get_unix_time_from_system()) - int(s.get("saved_unix", 0))
	return age >= 0 and age <= SUSPENDED_MAX_AGE and DB.stages.has(StringName(s["config"].get("stage", "")))


func clear_suspended_run() -> void:
	if not (SaveManager.data.get("suspended", {}) as Dictionary).is_empty():
		SaveManager.data["suspended"] = {}
		SaveManager.save_profile()


## Retoma a partida salva quando o app foi para segundo plano (plano 10.11).
func continue_run() -> void:
	if not has_suspended_run():
		return
	var s: Dictionary = (SaveManager.data["suspended"] as Dictionary).duplicate(true)
	clear_suspended_run()
	var cfg: Dictionary = s["config"]
	cfg["speed"] = int(s.get("speed", cfg.get("speed", 1)))
	_remember_best(String(cfg["stage"]))
	_layer.visible = false
	game = load(GAME_SCENE).instantiate() as HyakkiGame
	game.config = cfg
	game.finished.connect(_on_run_finished)
	add_child(game)
	game.restore_snapshot(s)


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


## Guarda o melhor tempo da fase antes de a partida começar (sem criar a entrada no save).
func _remember_best(stage_id: String) -> void:
	var best: Dictionary = (SaveManager.data["stage_best"] as Dictionary).get(stage_id, {})
	_prev_best_time = float(best.get("best_time", 0.0))


func _on_run_finished(result: Dictionary) -> void:
	last_result = result
	result["prev_best_time"] = _prev_best_time
	clear_suspended_run()
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
		# O Android pode encerrar o app em segundo plano: guarda a partida para continuar depois.
		if game and game.running and not game.is_bot():
			SaveManager.data["suspended"] = game.snapshot()
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
