extends RefCounted
## Economia da partida (medição do balanceamento):
## - ryō por fonte no RunTracker (abates, bolsas, altares, chefes, baús, 凶, carta de reserva,
##   outros): a soma das fontes é o ryō ganho (saldo + gasto no Rerrolar pago), o valor somado é o
##   que entra no saldo (já com ganância e lua), mover parte de uma fonte para outra não muda o
##   total, a partida suspensa guarda as fontes e a linha ECONOMIA do bot traz cada uma;
## - numa partida de verdade: moeda de abate, bolsa do chão, bolsa de altar, chefe, baú (com o 凶
##   separado do ryō do baú), carta de reserva e ganância maior caem cada um na sua fonte;
## - opção --meta do bot: "none" não aplica nada (igual ao bot de antes), "half" e "max" aplicam
##   os power-ups do Santuário pelo mesmo cálculo do jogo (MetaProgress.modifiers_for, o mesmo de
##   powerup_modifiers), sem gravar no save;
## - relatório do fim da partida do bot (BotPilot.report): DANO, HABILIDADES, ECONOMIA e VIDA, com a
##   cura registrada e a sobra acima da vida máxima;
## - Noite Sem Fim: só o ryō ganho depois do amanhecer vale ×MetaProgress.ENDLESS_GOLD (o saldo do
##   amanhecer fica em RunTracker.endless_ryo_start, guardado na partida suspensa).
## Chamado por tests/integration_tests.gd, que passa o nó da cena e o _check.

const GAME_SCENE := "res://scenes/game/Game.tscn"
const CONFIG := {"hero": "aki", "stage": "village", "moon": 0, "mode": "normal", "seed": 21, "speed": 1}

var _host: Node
var _check: Callable


func run(host: Node, check: Callable) -> void:
	_host = host
	_check = check
	_test_tracker_sources()
	_test_meta_presets()
	_test_endless_gold()
	await _test_game_sources()
	await _test_bot_meta()
	GameClock.paused = true


# --- RunTracker --------------------------------------------------------------------------

func _test_tracker_sources() -> void:
	var tracker := RunTracker.new()
	_check.call(tracker.ryo_earned() == 0 and tracker.ryo == 0, "tracker novo: nenhum ryō por fonte")
	var amounts := {}
	var value := 3
	for source: StringName in RunTracker.RYO_SOURCES:
		tracker.add_ryo(value, source)
		amounts[source] = value
		value += 4
	var total := 0
	for source: StringName in amounts:
		total += int(amounts[source])
		_check.call(tracker.ryo_from(source) == int(amounts[source]), "fonte %s soma o que entrou", source)
	_check.call(tracker.ryo == total and tracker.ryo_earned() == total, "soma das fontes = tracker.ryo (%d)", total)
	tracker.spend_ryo(10)
	_check.call(tracker.ryo_earned() == tracker.ryo + tracker.ryo_spent,
			"com Rerrolar pago: soma das fontes = saldo + gasto")
	tracker.move_ryo(&"chests", &"kyo", 2)
	_check.call(tracker.ryo_from(&"chests") == int(amounts[&"chests"]) - 2
			and tracker.ryo_from(&"kyo") == int(amounts[&"kyo"]) + 2 and tracker.ryo_earned() == total,
			"mover ryō de uma fonte para outra não muda o total")
	tracker.coins = 4
	tracker.ryo_bags = 2
	tracker.chests = 3
	var line := tracker.economy_line()
	_check.call(line.begins_with("ECONOMIA ryo=%d " % total), "linha ECONOMIA começa pelo ryō ganho: %s", line)
	for part: String in ["abates=%d" % tracker.ryo_from(&"kills"), "bolsas=%d" % tracker.ryo_from(&"bags"),
			"altares=%d" % tracker.ryo_from(&"altars"), "chefes=%d" % tracker.ryo_from(&"bosses"),
			"baus=%d" % tracker.ryo_from(&"chests"), "kyo=%d" % tracker.ryo_from(&"kyo"),
			"reserva=%d" % tracker.ryo_from(&"card"), "outros=%d" % tracker.ryo_from(&"other"),
			"gasto=10", "saldo=%d" % tracker.ryo, "baus_n=3", "moedas_n=4", "bolsas_n=2"]:
		_check.call((" " + part) in line, "linha ECONOMIA tem %s", part)
	# Partida suspensa: as fontes e as contagens voltam.
	var again := RunTracker.new()
	again.restore(JSON.parse_string(JSON.stringify(tracker.snapshot())))
	again.ryo = tracker.ryo
	_check.call(again.ryo_earned() == tracker.ryo_earned() and again.coins == 4 and again.ryo_bags == 2
			and again.ryo_from(&"card") == tracker.ryo_from(&"card"), "partida retomada mantém o ryō por fonte")


# --- Noite Sem Fim ----------------------------------------------------------------------

func _test_endless_gold() -> void:
	var t := RunTracker.new()
	t.add_ryo(200, &"kills")
	var normal := {"endless": false}
	var endless := {"endless": true}
	_check.call(MetaProgress.run_ryo(normal, t) == 200, "sem a Noite Sem Fim o ryō vai ×1")
	t.endless_ryo_start = t.ryo
	_check.call(MetaProgress.run_ryo(endless, t) == 200, "Noite Sem Fim: o ryō de antes do amanhecer vale ×1")
	t.add_ryo(100, &"kills")
	var bonus := roundi(100 * MetaProgress.ENDLESS_GOLD)
	_check.call(MetaProgress.run_ryo(endless, t) == 200 + bonus,
			"Noite Sem Fim: 200 antes do amanhecer ×1 + 100 depois ×%s = %d", [MetaProgress.ENDLESS_GOLD, 200 + bonus])
	var again := RunTracker.new()
	again.restore(JSON.parse_string(JSON.stringify(t.snapshot())))
	again.ryo = t.ryo
	_check.call(again.endless_ryo_start == 200 and MetaProgress.run_ryo(endless, again) == 200 + bonus,
			"partida suspensa guarda o ryō do amanhecer (o bônus não muda)")
	t.doubled_ryo = true
	_check.call(MetaProgress.run_ryo(endless, t) == (200 + bonus) * 2, "dobrar por anúncio vale sobre tudo")
	t.doubled_ryo = false
	t.spend_ryo(150)
	_check.call(MetaProgress.run_ryo(endless, t) == 150, "gasto depois do amanhecer: sem bônus, o saldo não cai abaixo")


# --- Santuário do bot (--meta) -----------------------------------------------------------

func _test_meta_presets() -> void:
	_check.call(MetaProgress.preset_levels("none").is_empty(), "--meta=none: nenhum nível")
	_check.call(MetaProgress.modifiers_for(MetaProgress.preset_levels("none")).is_empty(),
			"--meta=none: nenhum modificador (o bot de antes)")
	var top := MetaProgress.preset_levels("max")
	var half := MetaProgress.preset_levels("half")
	for id: StringName in DB.ids("powerups"):
		var cap := int(DB.powerups[id]["max"])
		_check.call(int(top.get(id, 0)) == cap, "--meta=max: %s no nível máximo", id)
		_check.call(int(half.get(id, 0)) == floori(cap / 2.0), "--meta=half: %s na metade (para baixo)", id)
	var mods := MetaProgress.modifiers_for(top)
	_check.call(is_equal_approx(float(mods.get("might", 0.0)), 0.25)
			and is_equal_approx(float(mods.get("revive", 0.0)), 1.0)
			and is_equal_approx(float(mods.get("greed", 0.0)), 0.5)
			and is_equal_approx(float(mods.get("cooldown", 0.0)), -0.05),
			"--meta=max: poder +25%%, 1 reviver, ganância +50%%, recarga -5%%")
	# O mesmo cálculo do jogo: um perfil com os níveis do "max" dá os mesmos modificadores.
	var original := SaveManager.data
	SaveManager.data = SaveManager.default_profile()
	for id: StringName in top:
		SaveManager.data["powerups"][String(id)] = int(top[id])
	_check.call(JSON.stringify(MetaProgress.powerup_modifiers()) == JSON.stringify(mods),
			"modifiers_for(níveis) = powerup_modifiers() do perfil com os mesmos níveis")
	SaveManager.data = original


# --- Partida de verdade ------------------------------------------------------------------

func _test_game_sources() -> void:
	var game := await _new_game(false, "none")
	var tracker := game.tracker
	var greed := game.player.stats.get_stat("greed") * game.reward_mult()
	game.collect_item({"id": &"coin", "effect": "ryo", "value": DB.items[&"coin"]["value"]})
	_check.call(tracker.ryo_from(&"kills") == roundi(int(DB.items[&"coin"]["value"]) * greed) and tracker.coins == 1,
			"moeda de abate vai para abates (e conta 1 moeda)")
	var bag := int(DB.items[&"ryo_bag"]["value"])
	game.collect_item({"id": &"ryo_bag", "effect": "ryo", "value": bag})
	_check.call(tracker.ryo_from(&"bags") == roundi(bag * greed) and tracker.ryo_bags == 1,
			"bolsa do chão vai para bolsas")
	game.collect_item({"id": &"ryo_bag", "effect": "ryo", "value": bag, "pop": [0.0, 0.0, 0.0]})
	_check.call(tracker.ryo_from(&"altars") == roundi(bag * greed) and tracker.ryo_bags == 2,
			"bolsa que saltou do altar vai para altares")
	var gained := game.add_run_ryo(BossDirector.BOSS_RYO, &"bosses")
	_check.call(tracker.ryo_from(&"bosses") == gained and gained == roundi(BossDirector.BOSS_RYO * greed),
			"ryō do chefe vai para chefes")
	game.level_up.apply({"kind": "ryo", "id": &"ryo_bag"})
	_check.call(tracker.ryo_from(&"card") == roundi(25 * greed), "carta de reserva vai para reserva")
	# Baús: o ryō do baú em baus e o consolo do 凶 em kyo.
	var kyo_seen := false
	for _k: int in range(400):
		var before_chests := tracker.ryo_from(&"chests")
		var before_kyo := tracker.ryo_from(&"kyo")
		var before := tracker.ryo
		game.chests.open(false)
		var delta_chest := tracker.ryo_from(&"chests") - before_chests
		var delta_kyo := tracker.ryo_from(&"kyo") - before_kyo
		if delta_chest + delta_kyo != tracker.ryo - before:
			_check.call(false, "baú: o ryō por fonte é o que entrou no saldo")
			break
		if game.chests.last_fortune == Omikuji.KYO:
			kyo_seen = true
			_check.call(delta_kyo == roundi(Omikuji.KYO_RYO * greed)
					and delta_chest == roundi(ChestSystem.RYO_PER_ITEM * greed),
					"凶: consolo em kyo (%d) e o ryō do baú em baus (%d)", [delta_kyo, delta_chest])
			break
		_check.call(delta_kyo == 0, "baú sem 凶 não põe nada em kyo")
	_check.call(kyo_seen, "algum baú de 1 item saiu 凶 em 400 aberturas")
	_check.call(tracker.chests > 0 and tracker.ryo_earned() == tracker.ryo + tracker.ryo_spent,
			"partida: soma das fontes = saldo + gasto (%d)", tracker.ryo)
	# Ganância maior: a fonte recebe o valor já multiplicado.
	game.player.stats.set_source("test_greed", {"greed": 1.0})
	var mult := game.player.stats.get_stat("greed") * game.reward_mult()
	var other_before := tracker.ryo_from(&"other")
	game.add_run_ryo(10)
	_check.call(tracker.ryo_from(&"other") - other_before == roundi(10 * mult),
			"sem fonte: outros, com a ganância aplicada")
	# Linha VIDA do bot: a cura que entrou e a que sobrou acima da vida máxima.
	var top := game.player.max_hp()
	game.player.hp = top - 30.0
	game.player.healed = 0.0
	game.player.overhealed = 0.0
	game.player.heal(20.0)
	game.player.heal(50.0)
	_check.call(is_equal_approx(game.player.healed, 30.0) and is_equal_approx(game.player.overhealed, 40.0)
			and is_equal_approx(game.player.hp, top), "cura registrada (30) e a sobra acima da vida máxima (40)")
	# Noite Sem Fim: o amanhecer guarda o saldo; o que vem depois é que ganha o bônus.
	game.endless_enabled = true
	game._on_dawn()
	var at_dawn := tracker.ryo
	_check.call(game.endless_phase and tracker.endless_ryo_start == at_dawn,
			"amanhecer da Noite Sem Fim guarda o saldo (%d)", at_dawn)
	game.add_run_ryo(40, &"kills")
	_check.call(int((game.snapshot()["tracker"] as Dictionary).get("endless_ryo_start", -1)) == at_dawn
			and MetaProgress.run_ryo({"endless": true}, tracker)
			== at_dawn + roundi((tracker.ryo - at_dawn) * MetaProgress.ENDLESS_GOLD),
			"partida suspensa na Noite Sem Fim leva o saldo do amanhecer; só o depois vale ×%s", MetaProgress.ENDLESS_GOLD)
	var report := BotPilot.report(game)
	for head: String in ["DANO total=", "HABILIDADES ", "ECONOMIA ryo=%d " % tracker.ryo_earned(),
			"VIDA atual=%.2f max=%.2f " % [top, top]]:
		_check.call(head in report, "relatório do bot tem a linha %s", head)
	await _free(game)


func _test_bot_meta() -> void:
	var plain := await _new_game(true, "none")
	_check.call(is_equal_approx(plain.player.stats.get_stat("might"), 1.0)
			and is_equal_approx(plain.player.stats.get_stat("revive"), 0.0), "bot --meta=none: sem power-ups")
	await _free(plain)
	SaveManager.data["powerups"]["pu_might"] = 2  # o bot ignora o save
	var none_again := await _new_game(true, "none")
	_check.call(is_equal_approx(none_again.player.stats.get_stat("might"), 1.0),
			"bot --meta=none ignora o Santuário do save")
	await _free(none_again)
	SaveManager.data["powerups"].erase("pu_might")
	var veteran := await _new_game(true, "max")
	var mods := MetaProgress.modifiers_for(MetaProgress.preset_levels("max"))
	_check.call(is_equal_approx(veteran.player.stats.get_stat("might"), 1.0 + float(mods["might"]))
			and is_equal_approx(veteran.player.stats.get_stat("revive"), float(mods["revive"]))
			and is_equal_approx(veteran.player.stats.get_stat("greed"), 1.0 + float(mods["greed"])),
			"bot --meta=max: poder, reviver e ganância do Santuário no máximo")
	_check.call(int(SaveManager.data["powerups"].get("pu_might", 0)) == 0, "bot --meta=max não grava no save")
	await _free(veteran)


func _new_game(bot: bool, meta: String) -> HyakkiGame:
	var game := (load(GAME_SCENE) as PackedScene).instantiate() as HyakkiGame
	game.config = CONFIG.duplicate()
	game.set("_bot", bot)
	game.bot_meta = meta
	_host.add_child(game)
	await _host.get_tree().process_frame
	GameClock.paused = true
	return game


func _free(game: HyakkiGame) -> void:
	game.queue_free()
	GameClock.paused = false
	await _host.get_tree().process_frame
	GameClock.paused = true
