extends RefCounted
## Omikuji do baú (scripts/systems/omikuji.gd, chest_system.gd e scripts/ui/chest_panel.gd):
## - regras puras (run_unit, por tests/run_tests.gd): sorte pela contagem (吉 1, 中吉 3, 大吉 5),
##   凶 só em baú de 1 item e na chance certa, fluxo próprio pela semente (mesma semente = mesma
##   sequência), contador dos baús generosos e a migração do estado;
## - jogo (run, por tests/integration_tests.gd ou tests/omikuji_tests.tscn): save novo e antigo
##   (migração conta os baús já abertos), os 3 primeiros baús comuns com 中吉 garantido e
##   gravados no save, chefe e bot sem gastar, 凶 com o item e o consolo em ryō, a mesma
##   sequência de sortes em 1x, 2x e 3x (e no hash da partida), e a tela: omikuji antes do baú,
##   大吉 com clarão dourado (sem ele em "Reduzir flashes" e em Baixa) e chuva de moedas, 凶
##   amarrado no galho, roleta que para no item certo com estalos, pular a qualquer momento,
##   animação curta na metade do tempo e um baú inteiro aberto numa partida de verdade.
## O layout (papel, tubo, galho, roleta e linha da sorte) em todas as resoluções, idiomas e com
## o furo dos dois lados fica em tests/level_chest_tests.gd (check_omikuji_layout).

const GAME_SCENE := "res://scenes/game/Game.tscn"
const LevelChestTests := preload("res://tests/level_chest_tests.gd")

var _host: Node
var _check: Callable


# --- Regras puras ------------------------------------------------------------------------

func run_unit(check: Callable) -> void:
	_check = check
	_test_mapping()
	_test_stream()
	_test_generous_rules()


func _test_mapping() -> void:
	_check.call(Omikuji.fortune_for(1, 0.5) == Omikuji.KICHI, "omikuji: 1 item = 吉")
	_check.call(Omikuji.fortune_for(3, 0.5) == Omikuji.CHUKICHI, "omikuji: 3 itens = 中吉")
	_check.call(Omikuji.fortune_for(5, 0.5) == Omikuji.DAIKICHI, "omikuji: 5 itens = 大吉")
	_check.call(Omikuji.fortune_for(4, 0.5) == Omikuji.CHUKICHI and Omikuji.fortune_for(2, 0.5) == Omikuji.KICHI,
			"omikuji: contagens que sobraram (fim das cartas) caem na faixa de baixo")
	_check.call(Omikuji.fortune_for(1, 0.0) == Omikuji.KYO
			and Omikuji.fortune_for(1, Omikuji.KYO_CHANCE - 0.001) == Omikuji.KYO, "omikuji: 凶 abaixo da chance")
	_check.call(Omikuji.fortune_for(1, Omikuji.KYO_CHANCE) == Omikuji.KICHI, "omikuji: 吉 a partir da chance")
	var never := true
	for items: int in [3, 5]:
		for roll: float in [0.0, 0.01, 0.05]:
			never = never and Omikuji.fortune_for(items, roll) != Omikuji.KYO
	_check.call(never, "omikuji: 凶 nunca em baú de 3 ou 5 itens")
	_check.call(Omikuji.kanji(Omikuji.KICHI) == "吉" and Omikuji.kanji(Omikuji.CHUKICHI) == "中吉"
			and Omikuji.kanji(Omikuji.DAIKICHI) == "大吉" and Omikuji.kanji(Omikuji.KYO) == "凶", "omikuji: kanji de cada sorte")
	_check.call(Omikuji.items_of(Omikuji.KYO) == 1 and Omikuji.items_of(Omikuji.DAIKICHI) == 5
			and Omikuji.items_of(Omikuji.CHUKICHI) == 3, "omikuji: 凶 ainda entrega 1 item")
	_check.call(Omikuji.fortune_of_count(1) == Omikuji.KICHI and Omikuji.fortune_of_count(5) == Omikuji.DAIKICHI,
			"omikuji: sorte pela contagem não sorteia 凶")
	_check.call(Omikuji.KYO_RYO > 0 and Omikuji.KYO_CHANCE > 0.0 and Omikuji.KYO_CHANCE <= 0.1,
			"omikuji: consolo e chance pequenos")


func _test_stream() -> void:
	var seven := Omikuji.stream_seed(7)
	_check.call(seven == Omikuji.stream_seed(3 + 4) and seven != Omikuji.stream_seed(8) and seven != 7
			and Omikuji.stream_seed(0) != 0, "omikuji: semente do fluxo derivada da partida")
	var a := _sequence(7, 300)
	var b := _sequence(7, 300)
	_check.call(a == b, "omikuji: mesma semente, mesma sequência de sortes")
	_check.call(a != _sequence(8, 300), "omikuji: outra semente, outra sequência")
	var rng := RandomNumberGenerator.new()
	rng.seed = Omikuji.stream_seed(123)
	var kyo := 0
	var total := 20000
	for _i: int in range(total):
		if Omikuji.fortune_for(1, rng.randf()) == Omikuji.KYO:
			kyo += 1
	var rate := float(kyo) / total
	_check.call(rate > 0.065 and rate < 0.095, "omikuji: 凶 em ~8%% dos baús de 1 item (%.3f)" % rate)


func _sequence(run_seed: int, n: int) -> PackedStringArray:
	var rng := RandomNumberGenerator.new()
	rng.seed = Omikuji.stream_seed(run_seed)
	var out := PackedStringArray()
	for _i: int in range(n):
		out.append(String(Omikuji.fortune_for(1, rng.randf())))
	return out


func _test_generous_rules() -> void:
	var profile := {"omikuji": Omikuji.default_state()}
	_check.call(Omikuji.generous_left(profile) == Omikuji.GENEROUS_CHESTS, "generosos: 3 no save novo")
	for _i: int in range(Omikuji.GENEROUS_CHESTS + 2):
		Omikuji.use_generous(profile)
	_check.call(Omikuji.generous_left(profile) == 0
			and int(profile["omikuji"]["generous_used"]) == Omikuji.GENEROUS_CHESTS,
			"generosos: gastos param em 0 sem passar do limite")
	_check.call(Omikuji.min_items(false, 2) == 3 and Omikuji.min_items(false, 0) == 1 and Omikuji.min_items(true, 0) == 3,
			"generosos: mínimo de 3 itens só enquanto houver (chefe sempre 3)")
	_check.call(int(Omikuji.migrate_state({"stats": {"chests": 0}})["generous_used"]) == 0,
			"migração: quem nunca abriu baú ganha os 3")
	_check.call(int(Omikuji.migrate_state({"stats": {"chests": 2}})["generous_used"]) == 2,
			"migração: 2 baús abertos, sobra 1 generoso")
	var veteran := Omikuji.migrate_state({"stats": {"chests": 90}})
	_check.call(int(veteran["generous_used"]) == Omikuji.GENEROUS_CHESTS,
			"migração: veterano não ganha generosos")
	_check.call(int(Omikuji.migrate_state({})["generous_used"]) == 0
			and int(Omikuji.migrate_state({"stats": "x"})["generous_used"]) == 0,
			"migração: save sem estatísticas")
	var broken := {"omikuji": "estragado"}
	_check.call(Omikuji.generous_left(broken) == Omikuji.GENEROUS_CHESTS and broken["omikuji"] is Dictionary,
			"generosos: estado estragado volta ao padrão")


# --- Jogo --------------------------------------------------------------------------------

func run(host: Node, check: Callable) -> void:
	_host = host
	_check = check
	var original: Dictionary = SaveManager.data
	var flashes: Variant = Settings.get_value("reduce_flashes")
	var short: Variant = Settings.get_value("chest_short")
	Settings.set_value("reduce_flashes", false)
	Settings.set_value("chest_short", false)
	_test_save()
	await _test_generous_game()
	await _test_kyo_consolation()
	await _test_speeds()
	await _test_panel()
	await _test_full_open()
	Settings.set_value("reduce_flashes", flashes)
	Settings.set_value("chest_short", short)
	GfxQuality.clear_override()
	SaveManager.data = original
	GameClock.paused = true


func _test_save() -> void:
	var fresh := SaveManager.default_profile()
	_check.call(fresh.get("omikuji") == Omikuji.default_state(), "save novo com o omikuji zerado")
	var settings := load("res://scripts/autoload/settings.gd") as GDScript
	var defaults: Dictionary = settings.get_script_constant_map()["DEFAULTS"]
	_check.call(defaults.get("chest_short") == false, "opção \"Animação curta do baú\" vem desligada")
	var old := SaveManager.default_profile()
	old.erase("omikuji")
	old["stats"]["chests"] = 2
	var migrated := SaveManager.migrate(old)
	_check.call(int(migrated["omikuji"]["generous_used"]) == 2 and Omikuji.generous_left(migrated) == 1,
			"save antigo sem omikuji migra contando os baús já abertos")
	var veteran := SaveManager.default_profile()
	veteran.erase("omikuji")
	veteran["stats"]["chests"] = 40
	_check.call(Omikuji.generous_left(SaveManager.migrate(veteran)) == 0, "save de veterano migra sem generosos")
	var kept := SaveManager.default_profile()
	kept["omikuji"]["generous_used"] = 1
	kept["stats"]["chests"] = 30
	_check.call(int(SaveManager.migrate(kept)["omikuji"]["generous_used"]) == 1, "migração não mexe num omikuji existente")
	# Ida e volta pelo disco (arquivos de teste).
	SaveManager.data = SaveManager.default_profile()
	Omikuji.use_generous(SaveManager.data)
	SaveManager.save_profile()
	SaveManager.load_profile()
	_check.call(Omikuji.generous_left(SaveManager.data) == Omikuji.GENEROUS_CHESTS - 1, "baú generoso gasto fica no disco")


func _test_generous_game() -> void:
	SaveManager.data = SaveManager.default_profile()
	var game := await _new_game({"seed": 31})
	_check.call(game.chests.generous_enabled, "partida normal usa os baús generosos")
	var fortunes: Array[StringName] = []
	for _i: int in range(Omikuji.GENEROUS_CHESTS):
		var rewards := game.chests.open(false)
		_check.call(rewards.size() - 1 >= 3, "baú generoso com 3 ou mais itens (%d)" % (rewards.size() - 1))
		fortunes.append(game.chests.last_fortune)
	_check.call(fortunes.all(func(f: StringName) -> bool: return f == Omikuji.CHUKICHI or f == Omikuji.DAIKICHI),
			"3 primeiros baús com 中吉 ou melhor (%s)" % [fortunes])
	_check.call(Omikuji.generous_left(SaveManager.data) == 0, "os 3 generosos gastos no save")
	# Chefe não gasta generoso.
	SaveManager.data = SaveManager.default_profile()
	game.chests.open(true)
	_check.call(Omikuji.generous_left(SaveManager.data) == Omikuji.GENEROUS_CHESTS, "baú de chefe não gasta generoso")
	# Bot (testes de determinismo) nunca usa nem gasta.
	game.set("_bot", true)
	game.start_run(game.config)
	_check.call(not game.chests.generous_enabled, "bot sem baús generosos")
	game.chests.open(false)
	_check.call(Omikuji.generous_left(SaveManager.data) == Omikuji.GENEROUS_CHESTS, "bot não gasta generoso")
	game.set("_bot", false)
	await _free(game)


## 凶: o mesmo item (1) e o consolo em ryō; os outros baús de 1 item sem consolo.
func _test_kyo_consolation() -> void:
	var game := await _new_game({"seed": 44})
	game.chests.generous_enabled = false
	var kyo := 0
	var ok := true
	for _i: int in range(160):
		var rewards := game.chests.open(false)
		var items := rewards.size() - 1
		if items != 1:
			continue
		var ryo := ChestPanel._ryo_amount(rewards.back())
		if game.chests.last_fortune == Omikuji.KYO:
			kyo += 1
			ok = ok and ryo == ChestSystem.RYO_PER_ITEM + Omikuji.KYO_RYO
		else:
			ok = ok and game.chests.last_fortune == Omikuji.KICHI and ryo == ChestSystem.RYO_PER_ITEM
	_check.call(kyo > 0, "凶 aparece em baús de 1 item (%d)" % kyo)
	_check.call(ok, "凶 entrega o item e +%d ryō de consolo; 吉 sem consolo" % Omikuji.KYO_RYO)
	await _free(game)


## Mesma semente: a mesma sequência de sortes e de itens em 1x, 2x e 3x, e a sorte no hash.
func _test_speeds() -> void:
	var tags: Array[String] = []
	var items: Array[String] = []
	for speed: int in [1, 2, 3]:
		var game := await _new_game({"seed": 77, "speed": speed})
		game.chests.generous_enabled = false
		var ids := PackedStringArray()
		for _i: int in range(40):
			for reward: Dictionary in game.chests.open(false):
				ids.append(String(reward.get("id", reward.get("kind", ""))))
		tags.append(game.chests.fortune_tag())
		items.append(",".join(ids))
		_check.call(game.state_summary("T").contains("sorte=" + game.chests.fortune_tag()),
				"%dx: sorte dos baús no hash da partida" % speed)
		await _free(game)
	_check.call(tags[0] == tags[1] and tags[1] == tags[2], "mesma semente: mesmas sortes em 1x, 2x e 3x (%s)" % tags[0])
	_check.call(items[0] == items[1] and items[1] == items[2], "mesma semente: mesmos itens em 1x, 2x e 3x")
	_check.call(tags[0].length() == 40, "uma sorte por baú")
	var other := await _new_game({"seed": 78, "speed": 1})
	other.chests.generous_enabled = false
	for _i: int in range(40):
		other.chests.open(false)
	_check.call(other.chests.fortune_tag() != tags[0], "outra semente, outra sequência")
	await _free(other)


func _test_panel() -> void:
	var game := await _new_game({"seed": 5})
	var hud := game.hud
	var panel := hud.chest_panel()
	GfxQuality.set_override(GfxQuality.HIGH)
	Settings.emit_signal("changed", GfxQuality.changed_signal_key())
	# Sorte pela contagem quando ninguém informa.
	for pair: Array in [[1, Omikuji.KICHI], [3, Omikuji.CHUKICHI], [5, Omikuji.DAIKICHI]]:
		hud.show_chest(LevelChestTests.sample_rewards(int(pair[0])))
		_check.call(panel.fortune() == pair[1], "tela: %d itens = %s" % [pair[0], pair[1]])
		panel.skip()
	# 大吉: omikuji antes do baú, clarão dourado e chuva de moedas na revelação.
	hud.show_chest(LevelChestTests.sample_rewards(5), Omikuji.DAIKICHI)
	await _host.get_tree().process_frame
	_check.call(panel.phase() == "omikuji" and not panel.chest().visible and not panel.fortune_sealed(),
			"大吉: começa pelo omikuji, sem baú")
	_check.call(await _wait(func() -> bool: return panel.gold_flashes() > 0, 3.0), "大吉: clarão dourado ao abrir o papel")
	_check.call(panel.coin_rains() == 1 and panel.coin_count() > 0, "大吉: chuva de moedas")
	_check.call(await _wait(panel.fortune_sealed, 2.0) and panel.phase() == "chest", "大吉: papel vira o selo e o baú cai")
	# Roleta: começa depois da abertura, estala e para no item de verdade (evolução gira mais).
	_check.call(await _wait(func() -> bool: return panel.phase() == "reel", 4.0) and panel.reel_row() == 0,
			"roleta gira o 1º item")
	var rows := panel.rows()
	_check.call(rows[0].special and panel.reel_time(0) > panel.reel_time(1) + ChestPanel.REEL_SPECIAL * 0.5,
			"evolução gira mais tempo na roleta")
	var ok := true
	for i: int in range(rows.size()):
		ok = ok and panel.reel_target(i) == rows[i].icon
	_check.call(ok, "roleta de cada cartão termina no item do cartão")
	_check.call(await _wait(func() -> bool: return panel.lines_shown() >= 1, 3.0), "item sai da roleta e pousa no cartão")
	_check.call(panel.reel_ticks() >= ChestPanel.REEL_SPINS[0], "estalos a cada ícone que passa (%d)" % panel.reel_ticks())
	_check.call(absf(panel.reel_offset(0) - float(ChestPanel.REEL_SPINS[0] + ChestPanel.REEL_SPINS[2])) < 0.01,
			"roleta parada exatamente no item")
	_check.call(panel.reel_global_rect().get_center().distance_to(panel.chest().get_global_rect().get_center()) < 80.0,
			"roleta sobre o baú")
	panel.skip()
	_check.call(panel.phase() == "done" and panel.lines_shown() == panel.lines_total(), "pular na roleta mostra tudo")
	panel.button().pressed.emit()
	# Reduzir flashes: sem clarão dourado (a chuva de moedas continua).
	Settings.set_value("reduce_flashes", true)
	hud.show_chest(LevelChestTests.sample_rewards(5), Omikuji.DAIKICHI)
	await _wait(func() -> bool: return panel.coin_rains() > 0, 3.0)
	_check.call(panel.gold_flashes() == 0 and panel.coin_rains() == 1, "Reduzir flashes: 大吉 sem clarão dourado")
	panel.skip()
	panel.button().pressed.emit()
	Settings.set_value("reduce_flashes", false)
	# Baixa: sem clarão e menos moedas.
	GfxQuality.set_override(GfxQuality.LOW)
	Settings.emit_signal("changed", GfxQuality.changed_signal_key())
	hud.show_chest(LevelChestTests.sample_rewards(5), Omikuji.DAIKICHI)
	await _wait(func() -> bool: return panel.coin_rains() > 0, 3.0)
	_check.call(panel.gold_flashes() == 0 and panel.coin_count() * 10 <= int(GfxQuality.budget("particles_max")),
			"Baixa: 大吉 sem clarão e moedas no orçamento")
	panel.skip()
	panel.button().pressed.emit()
	GfxQuality.set_override(GfxQuality.HIGH)
	Settings.emit_signal("changed", GfxQuality.changed_signal_key())
	# 凶: o papel voa até o galho e fica amarrado; o item continua lá.
	hud.show_chest(LevelChestTests.sample_rewards(1), Omikuji.KYO)
	_check.call(panel.fortune() == Omikuji.KYO and not panel.tied(), "凶: papel ainda solto no começo")
	_check.call(await _wait(panel.tied, 3.0) and panel.phase() == "chest", "凶: papel amarrado no galho antes do baú")
	_check.call(panel.lines_total() == 2, "凶: 1 item + ryō, nunca menos")
	await _wait(func() -> bool: return not panel.animating(), 6.0)
	_check.call(panel.lines_shown() == panel.lines_total() and panel.tied(), "凶: fim com o item e o papel no galho")
	panel.button().pressed.emit()
	# Pular no meio do omikuji: vai direto ao resultado (com o 凶 já amarrado).
	hud.show_chest(LevelChestTests.sample_rewards(1), Omikuji.KYO)
	await _seconds(0.3)
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	panel.call("_gui_input", tap)
	_check.call(not panel.animating() and panel.phase() == "done" and panel.fortune_sealed() and panel.tied()
			and panel.lines_shown() == panel.lines_total() and panel.chest().visible and panel.chest().lid == 1.0,
			"tocar no omikuji pula para o resultado")
	panel.button().pressed.emit()
	# Animação curta: a sequência inteira na metade do tempo.
	var full := 0.0
	hud.show_chest(LevelChestTests.sample_rewards(3), Omikuji.CHUKICHI)
	full = panel.real_duration()
	panel.skip()
	panel.button().pressed.emit()
	Settings.set_value("chest_short", true)
	hud.show_chest(LevelChestTests.sample_rewards(3), Omikuji.CHUKICHI)
	_check.call(panel.pace() == ChestPanel.SHORT_PACE
			and is_equal_approx(panel.real_duration() * ChestPanel.SHORT_PACE, full),
			"animação curta: metade do tempo (%.2f s de %.2f s)" % [panel.real_duration(), full])
	var t0 := Time.get_ticks_msec()
	await _wait(func() -> bool: return not panel.animating(), full)
	var took := (Time.get_ticks_msec() - t0) / 1000.0
	_check.call(not panel.animating() and took < full * 0.75,
			"animação curta acaba antes (%.2f s < %.2f s)" % [took, full])
	_check.call(panel.lines_shown() == panel.lines_total() and panel.fortune_sealed(), "animação curta mostra tudo")
	panel.button().pressed.emit()
	Settings.set_value("chest_short", false)
	GfxQuality.clear_override()
	await _free(game)


## Um baú inteiro numa partida de verdade: sorteio, omikuji com a sorte sorteada, roleta,
## cartões, Continuar e a luta de volta.
func _test_full_open() -> void:
	SaveManager.data = SaveManager.default_profile()
	var game := await _new_game({"seed": 12})
	var hud := game.hud
	var panel := hud.chest_panel()
	var closed := [0]
	hud.chest_closed.connect(func() -> void: closed[0] += 1)
	var ryo_before := game.tracker.ryo
	game.call("_open_chest", false)
	_check.call(hud.chest_open() and GameClock.paused and panel.phase() == "omikuji",
			"partida: baú abre pelo omikuji e pausa")
	_check.call(panel.fortune() == game.chests.last_fortune and game.chests.fortunes.size() == 1,
			"partida: a tela mostra a sorte sorteada (%s)" % panel.fortune())
	_check.call(panel.fortune() == Omikuji.CHUKICHI or panel.fortune() == Omikuji.DAIKICHI,
			"partida: 1º baú do save é generoso")
	_check.call(game.tracker.ryo > ryo_before and game.tracker.chests == 1, "partida: ryō e baú contados")
	_check.call(await _wait(func() -> bool: return not hud.chest_animating(), 14.0),
			"partida: sequência inteira acaba sozinha")
	_check.call(hud.chest_lines_shown() == hud.chest_lines_total() and panel.fortune_sealed(),
			"partida: todos os cartões e o selo")
	panel.button().pressed.emit()
	_check.call(closed[0] == 1 and not hud.chest_open(), "partida: Continuar fecha o baú")
	await _host.get_tree().process_frame
	_check.call(not GameClock.paused, "partida: a luta volta")
	await _free(game)


# --- Utilidades --------------------------------------------------------------------------

func _new_game(extra: Dictionary) -> HyakkiGame:
	var game := (load(GAME_SCENE) as PackedScene).instantiate() as HyakkiGame
	var config := {"hero": "aki", "stage": "village", "moon": 0, "mode": "normal", "seed": 5, "speed": 1}
	config.merge(extra, true)
	game.config = config
	_host.add_child(game)
	await _host.get_tree().process_frame
	await _host.get_tree().process_frame
	GameClock.paused = false
	game.player.god_mode = true
	return game


func _free(game: HyakkiGame) -> void:
	game.hud.chest_panel().cancel()
	game.queue_free()
	GameClock.paused = false
	await _host.get_tree().process_frame


func _seconds(value: float) -> void:
	await _host.get_tree().create_timer(value).timeout


func _wait(condition: Callable, timeout: float) -> bool:
	var until := Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < until:
		if condition.call():
			return true
		await _host.get_tree().process_frame
	return bool(condition.call())
