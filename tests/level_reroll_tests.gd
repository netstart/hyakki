extends RefCounted
## Rerrolar sempre à mão e a escolha automática da mão de comida/moedas, numa partida de verdade:
## - regras: carga grátis primeiro, depois ryō com preço que sobe (REROLL_BASE_COST + REROLL_STEP),
##   sem ryō nada muda, a mão nova evita as cartas da mesa (e só as repete se faltar opção), a
##   contagem paga no save da partida suspensa (e saves antigos sem ela);
## - tela: Rerrolar pago com o preço, apagado e negado (tremida, som, cartas e ryō intactos) sem
##   ryō, escondido (com Banir) na mão de comida/moedas, com a caixa "Não perguntar mais";
## - escolha automática: sem pausa, tela, fanfarra nem vibração, um som só para vários níveis
##   pendentes, o rng gasto como na escolha manual, comida vira ryō com a vida cheia, "Perguntar"
##   ainda mostra a tela, marcar a caixa e escolher grava a opção, o bot ignora e o baú segue.
## O layout dos dois estados fica em tests/level_chest_tests.gd (check_level_layout).
## Chamado por tests/level_chest_tests.gd (e por ele, por tests/integration_tests.gd).

const GAME_SCENE := "res://scenes/game/Game.tscn"
const LevelChestTests := preload("res://tests/level_chest_tests.gd")
const MissionTests := preload("res://tests/mission_tests.gd")
const CONFIG := {"hero": "aki", "stage": "village", "moon": 2, "mode": "normal", "seed": 13, "speed": 1}
## Espera a entrada das cartas (leque inteiro e o bloqueio do toque acidental).
const DEAL_WAIT := 0.9

var _host: Node
var _check: Callable


func run(host: Node, check: Callable) -> void:
	_host = host
	_check = check
	Settings.set_value(LevelUpSystem.AUTO_SETTING, "")
	await _test_reroll_rules()
	await _test_reroll_panel()
	await _test_fallback_panel()
	await _test_auto_choice()
	await _test_chest_follows()
	Settings.set_value(LevelUpSystem.AUTO_SETTING, "")
	GameClock.paused = true


# --- Rerrolar ----------------------------------------------------------------------------

func _test_reroll_rules() -> void:
	var game := await _new_game()
	var lu := game.level_up
	lu.rerolls = 1
	lu.paid_rerolls = 0
	game.tracker.ryo = 35
	_check.call(lu.reroll_cost() == 0 and lu.can_reroll(), "carga grátis: rerrolar sem custo")
	_check.call(lu.spend_reroll() and lu.rerolls == 0 and game.tracker.ryo == 35 and lu.paid_rerolls == 0,
			"a carga grátis é gasta primeiro, sem tocar no ryō")
	var base := LevelUpSystem.REROLL_BASE_COST
	var step := LevelUpSystem.REROLL_STEP
	_check.call(lu.reroll_cost() == base, "sem carga: a 1ª rolagem paga custa %d" % base)
	_check.call(lu.spend_reroll() and game.tracker.ryo == 35 - base and lu.paid_rerolls == 1
			and lu.reroll_cost() == base + step, "paga com ryō e o preço sobe +%d" % step)
	_check.call(lu.spend_reroll() and game.tracker.ryo == 35 - base * 2 - step and lu.paid_rerolls == 2
			and lu.reroll_cost() == base + step * 2, "2ª paga e o preço sobe de novo (%d)" % lu.reroll_cost())
	_check.call(game.tracker.ryo_spent == base * 2 + step, "o gasto fica registrado à parte (%d)" % game.tracker.ryo_spent)
	var left := game.tracker.ryo
	_check.call(not lu.can_reroll() and not lu.spend_reroll() and game.tracker.ryo == left and lu.paid_rerolls == 2,
			"sem ryō para pagar: nada muda")
	# A mão nova evita as cartas da mesa enquanto houver outras.
	var first := lu.build_choices(game.rng)
	var second := lu.build_choices(game.rng, first)
	var overlap := _ids(first).filter(func(id: String) -> bool: return _ids(second).has(id))
	_check.call(second.size() == first.size() and overlap.is_empty(),
			"rerrolar traz só cartas novas (%s -> %s)" % [_ids(first), _ids(second)])
	# Com uma opção só (tudo banido), a mesma carta volta para encher a mão.
	for id: StringName in DB.ids("weapons") + DB.ids("passives"):
		lu.banished.append(id)
	var lone := lu.build_choices(game.rng)
	var again := lu.build_choices(game.rng, lone)
	_check.call(lone.size() == 1 and _ids(again) == _ids(lone), "sem outras opções, a carta da mesa volta")
	# Save da partida suspensa: a contagem paga volta, e saves antigos sem ela começam do zero.
	var snap: Dictionary = JSON.parse_string(JSON.stringify(game.snapshot()))
	_check.call(int(snap.get("paid_rerolls", -1)) == 2 and int(snap["tracker"].get("ryo_spent", -1)) == base * 2 + step,
			"save guarda as rolagens pagas e o ryō gasto")
	var restored := await _new_game()
	restored.restore_snapshot(snap)
	_check.call(restored.level_up.paid_rerolls == 2 and restored.level_up.reroll_cost() == base + step * 2
			and restored.tracker.ryo_spent == base * 2 + step, "partida retomada mantém o preço e o ryō gasto")
	# Fim da partida: o saldo vai para o perfil e o gasto conta no total ganho na vida (missões
	# "ryo_total"), sem descontar nada.
	var ryo_before := SaveManager.ryo()
	var total_before := int(SaveManager.data["ryo_total"])
	var tracker := RunTracker.new()
	tracker.ryo = 70
	tracker.spend_ryo(30)
	MetaProgress.apply_run(MissionTests._result({"victory": false, "time": 30.0}), tracker)
	_check.call(SaveManager.ryo() == ryo_before + 40 and int(SaveManager.data["ryo_total"]) == total_before + 70,
			"fim da partida: leva o saldo (+40) e o total ganho conta o gasto (+70)")
	snap.erase("paid_rerolls")
	var old := await _new_game()
	old.restore_snapshot(snap)
	_check.call(old.level_up.paid_rerolls == 0, "save antigo sem a contagem paga começa do zero")
	await _free(restored)
	await _free(old)
	await _free(game)


func _test_reroll_panel() -> void:
	var game := await _new_game()
	var hud := game.hud
	var panel := hud.level_up_panel()
	var lu := game.level_up
	lu.rerolls = 0
	lu.paid_rerolls = 0
	game.tracker.ryo = 0
	var rerolled := [0]
	hud.reroll_pressed.connect(func() -> void: rerolled[0] += 1)
	var reroll := panel.action_buttons()[0]
	# Sem ryō: botão apagado com o preço; tocar só treme e nega.
	game.call("_open_level_up")
	await _seconds(DEAL_WAIT)
	_check.call(reroll.visible and reroll.price == LevelUpSystem.REROLL_BASE_COST and reroll.poor
			and reroll.modulate.a < 1.0, "Rerrolar sempre visível: preço em ryō, apagado sem ryō")
	_check.call(reroll.text == tr("lvchest.reroll") and reroll.get_combined_minimum_size().x
			>= UiPaint.text_width(reroll.text) + LevelUpPanel.price_margin(reroll.price), "preço cabe ao lado do nome")
	var before := _ids(_shown(panel))
	var requests := int(AudioManager.request_count.get("ui_cancel", 0))
	reroll.pressed.emit()
	_check.call(panel.reroll_denied() == 1 and rerolled[0] == 0 and _ids(_shown(panel)) == before
			and game.tracker.ryo == 0 and lu.paid_rerolls == 0, "sem ryō: negado, as cartas e o ryō ficam")
	_check.call(int(AudioManager.request_count.get("ui_cancel", 0)) == requests + 1, "som de negado")
	await _seconds(0.1)
	_check.call(not is_equal_approx(reroll.position.x, float(panel.get("_deny_x"))), "o botão treme")
	await _seconds(LevelUpPanel.DENY_TIME)
	_check.call(is_equal_approx(reroll.position.x, float(panel.get("_deny_x"))), "e volta para o lugar")
	hud.bot_answer()
	# Com ryō: paga, troca por cartas novas e o próximo preço aparece.
	game.tracker.ryo = 100
	game.call("_open_level_up")
	await _seconds(DEAL_WAIT)
	_check.call(reroll.visible and not reroll.poor and reroll.modulate.a == 1.0, "com ryō: botão aceso")
	before = _ids(_shown(panel))
	reroll.pressed.emit()
	var after := _ids(_shown(panel))
	var base := LevelUpSystem.REROLL_BASE_COST
	_check.call(rerolled[0] == 1 and game.tracker.ryo == 100 - base and lu.paid_rerolls == 1,
			"rerrolar pago gasta %d ryō" % base)
	_check.call(after.filter(func(id: String) -> bool: return before.has(id)).is_empty(),
			"rolagem paga mostra cartas novas (%s -> %s)" % [before, after])
	_check.call(reroll.price == base + LevelUpSystem.REROLL_STEP and hud.level_up_open(), "o preço da próxima sobe")
	await _seconds(DEAL_WAIT)
	reroll.pressed.emit()
	_check.call(game.tracker.ryo == 100 - base * 2 - LevelUpSystem.REROLL_STEP and lu.paid_rerolls == 2,
			"2ª rolagem paga")
	# A carga grátis aparece com o contador, sem preço.
	hud.bot_answer()
	lu.rerolls = 2
	game.call("_open_level_up")
	_check.call(reroll.visible and reroll.price == -1 and reroll.count == 2 and not reroll.poor,
			"com carga grátis: contador, sem preço")
	hud.bot_answer()
	await _free(game)


func _test_fallback_panel() -> void:
	var game := await _new_game()
	var hud := game.hud
	var panel := hud.level_up_panel()
	_max_out(game)
	game.level_up.rerolls = 3
	game.level_up.banishes = 2
	game.level_up.skips = 1
	game.tracker.ryo = 500
	var hand := game.level_up.build_choices(game.rng)
	_check.call(LevelUpSystem.is_fallback(hand) and hand.size() == 2, "tudo no máximo: mão de comida/moedas")
	_check.call(not LevelUpSystem.is_fallback(LevelChestTests.sample_cards()) and not LevelUpSystem.is_fallback([]),
			"mão normal não é de comida/moedas")
	game.call("_open_level_up")
	await _seconds(DEAL_WAIT)
	var buttons := panel.action_buttons()
	_check.call(hud.level_up_open() and GameClock.paused, "\"Perguntar\": a mão de comida/moedas abre a tela")
	_check.call(not buttons[0].visible and not buttons[2].visible and buttons[1].visible,
			"comida/moedas: sem Rerrolar nem Banir (Pular fica)")
	var toggle := panel.auto_toggle()
	_check.call(toggle.visible and toggle.toggle_mode and not toggle.button_pressed
			and toggle.text == tr("levelup.auto_pick"), "caixa \"Não perguntar mais\", desmarcada")
	var ryo := game.tracker.ryo
	game.call("_on_reroll")
	game.call("_on_banish", 0)
	_check.call(game.level_up.rerolls == 3 and game.level_up.banishes == 2 and game.tracker.ryo == ryo,
			"rerrolar e banir não valem na mão de comida/moedas")
	hud.bot_answer()
	await _free(game)


# --- Escolha automática ------------------------------------------------------------------

func _test_auto_choice() -> void:
	var game := await _new_game()
	var hud := game.hud
	var panel := hud.level_up_panel()
	var lu := game.level_up
	var player := game.player
	_max_out(game)
	var bag := roundi(25 * player.stats.get_stat("greed") * game.reward_mult())
	# Moedas, três níveis pendentes: tudo no mesmo quadro, sem pausa nem tela, um som só.
	Settings.set_value(LevelUpSystem.AUTO_SETTING, "ryo")
	player.hp = player.max_hp() * 0.5
	var hp := player.hp
	var ryo := game.tracker.ryo
	var probe := RandomNumberGenerator.new()
	probe.seed = game.rng.seed
	probe.state = game.rng.state
	for _i: int in 3:
		probe.randf()
	var sounds := _sounds(["magic1", "jingle_levelup", "ui_accept"])
	game.set("_pending_levels", 3)
	GameClock.paused = false
	game.call("_open_level_up")
	_check.call(not hud.level_up_open() and not panel.visible and not hud.overlay_open() and not GameClock.paused,
			"escolha automática: sem pausa e sem tela")
	_check.call(int(game.get("_pending_levels")) == 0 and game.tracker.ryo == ryo + bag * 3 and player.hp == hp,
			"três níveis pendentes resolvidos juntos (+%d ryō)" % (game.tracker.ryo - ryo))
	var now := _sounds(["magic1", "jingle_levelup", "ui_accept"])
	_check.call(now[0] == sounds[0] + 1 and now[1] == sounds[1] and now[2] == sounds[2],
			"um som de escolha só, sem fanfarra (%s -> %s)" % [sounds, now])
	_check.call(game.rng.state == probe.state, "o rng gasta igual à escolha manual (um sorteio por nível)")
	# Comida com vida cheia vira ryō; sem vida cheia, cura.
	Settings.set_value(LevelUpSystem.AUTO_SETTING, "heal")
	player.hp = player.max_hp()
	ryo = game.tracker.ryo
	game.set("_pending_levels", 1)
	game.call("_open_level_up")
	_check.call(game.tracker.ryo == ryo + bag and player.hp == player.max_hp() and not hud.level_up_open(),
			"comida com a vida cheia pega o ryō")
	player.hp = 10.0
	ryo = game.tracker.ryo
	game.set("_pending_levels", 1)
	game.call("_open_level_up")
	_check.call(player.hp > 10.0 and game.tracker.ryo == ryo and not hud.level_up_open(), "comida sem a vida cheia cura")
	# O bot ignora a opção (determinismo).
	game.set("_bot", true)
	_check.call(lu.auto_card(lu.build_choices(game.rng)).is_empty(), "o bot ignora a escolha automática")
	game.set("_bot", false)
	# "Perguntar": a tela abre; marcar a caixa e escolher moedas grava a opção, e o nível
	# pendente seguinte já sai sozinho.
	Settings.set_value(LevelUpSystem.AUTO_SETTING, "")
	ryo = game.tracker.ryo
	game.set("_pending_levels", 2)
	game.call("_open_level_up")
	_check.call(hud.level_up_open() and GameClock.paused, "\"Perguntar\" ainda mostra a tela")
	await _seconds(DEAL_WAIT)
	var toggle := panel.auto_toggle()
	toggle.button_pressed = true
	var coins: LevelCard = null
	for card: LevelCard in panel.level_cards():
		if String(card.data["kind"]) == "ryo":
			coins = card
	coins.pressed.emit()
	_check.call(String(Settings.get_value(LevelUpSystem.AUTO_SETTING)) == "ryo", "marcar e escolher moedas grava a opção")
	_check.call(not hud.level_up_open() and int(game.get("_pending_levels")) == 0 and game.tracker.ryo == ryo + bag * 2,
			"o nível pendente seguinte sai sozinho")
	# Sem marcar, escolher não grava nada.
	Settings.set_value(LevelUpSystem.AUTO_SETTING, "")
	game.set("_pending_levels", 1)
	game.call("_open_level_up")
	await _seconds(DEAL_WAIT)
	panel.level_cards()[0].pressed.emit()
	_check.call(String(Settings.get_value(LevelUpSystem.AUTO_SETTING)) == "" and not hud.level_up_open(),
			"sem marcar a caixa, a opção fica em \"Perguntar\"")
	await _seconds(0.8)
	await _free(game)


func _test_chest_follows() -> void:
	var game := await _new_game()
	_max_out(game)
	game.player.hp = game.player.max_hp() * 0.5
	Settings.set_value(LevelUpSystem.AUTO_SETTING, "")
	_check.call(String(game.chests.call("_next_reward")["kind"]) == "heal", "baú sem escolha automática: a comida")
	Settings.set_value(LevelUpSystem.AUTO_SETTING, "ryo")
	_check.call(String(game.chests.call("_next_reward")["kind"]) == "ryo", "baú segue a escolha automática (moedas)")
	Settings.set_value(LevelUpSystem.AUTO_SETTING, "heal")
	game.player.hp = game.player.max_hp()
	_check.call(String(game.chests.call("_next_reward")["kind"]) == "ryo", "baú: comida com a vida cheia vira ryō")
	game.set("_bot", true)
	Settings.set_value(LevelUpSystem.AUTO_SETTING, "ryo")
	_check.call(String(game.chests.call("_next_reward")["kind"]) == "heal", "baú do bot ignora a opção")
	game.set("_bot", false)
	Settings.set_value(LevelUpSystem.AUTO_SETTING, "")
	await _free(game)


# --- Utilidades --------------------------------------------------------------------------

## Tudo no máximo: armas no último nível e o resto banido, então a mão vira comida/moedas.
static func _max_out(game: HyakkiGame) -> void:
	for weapon: Weapon in game.weapons:
		while weapon.level < weapon.max_level:
			weapon.level_up()
	for id: StringName in DB.ids("weapons") + DB.ids("passives"):
		game.level_up.banished.append(id)


static func _ids(cards: Array[Dictionary]) -> Array[String]:
	var list: Array[String] = []
	for card: Dictionary in cards:
		list.append("%s:%s" % [card["kind"], card["id"]])
	return list


static func _shown(panel: LevelUpPanel) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for card: LevelCard in panel.level_cards():
		list.append(card.data)
	return list


static func _sounds(ids: Array[String]) -> Array[int]:
	var list: Array[int] = []
	for id: String in ids:
		list.append(int(AudioManager.request_count.get(id, 0)))
	return list


func _new_game() -> HyakkiGame:
	var game := (load(GAME_SCENE) as PackedScene).instantiate() as HyakkiGame
	game.config = CONFIG.duplicate()
	_host.add_child(game)
	await _host.get_tree().process_frame
	await _host.get_tree().process_frame
	GameClock.paused = false
	return game


func _free(game: HyakkiGame) -> void:
	game.queue_free()
	GameClock.paused = false
	await _host.get_tree().process_frame


func _seconds(value: float) -> void:
	await _host.get_tree().create_timer(value).timeout
