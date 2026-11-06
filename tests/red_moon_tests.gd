extends RefCounted
## Regras da Lua Vermelha (RedMoon), cumulativas, cada uma conferida na lua dela e logo abaixo:
## - I   mais elites: eventos de elite das fases (1, 2, 1, 2...) e a chance dos Altares do Selo;
## - II  Eclipse: entra no rodízio de todo chefe com padrões, avisa o disco e o anel na cor da lua,
##       o chefe prepara parado, acerta quem fica no disco e poupa quem está na faixa entre os dois;
## - III Sombras rápidas também na luz e parte delas já nascendo dentro dela (só as Sombras);
## - IV  nenhum onigiri das lanternas (o sushi continua), mão de comida/moedas só com moedas, a
##       escolha automática "Comida" e o baú pegando o ryō;
## - V   só RedMoon.PACTS Kami no santuário;
## - textos das regras com os números das constantes, somados até a lua escolhida.
## Chamado por tests/integration_tests.gd e por tests/red_moon_runner.gd (sozinho).

const GAME_SCENE := "res://scenes/game/Game.tscn"
const CONFIG := {"hero": "aki", "stage": "village", "mode": "normal", "seed": 29, "speed": 1}

var _host: Node
var _check: Callable


# --- Regras puras ------------------------------------------------------------------------

func run_unit(check: Callable) -> void:
	_check = check
	var stacked := RedMoon.RULES == HyakkiGame.MAX_MOON
	for moon: int in range(0, HyakkiGame.MAX_MOON + 1):
		for rule: int in range(1, RedMoon.RULES + 1):
			stacked = stacked and RedMoon.active(moon, rule) == (moon >= rule)
	_check.call(stacked, "Lua Vermelha: regras cumulativas (a Lua N aplica I..N)")
	var flat := true
	for k: int in range(12):
		flat = flat and RedMoon.elite_count(k, 0) == 1
	_check.call(flat and is_equal_approx(RedMoon.elite_mult(0), 1.0), "Lua 0: um elite por evento")
	var total := 0
	var each := true
	for k: int in range(10):
		var n := RedMoon.elite_count(k, RedMoon.ELITES)
		each = each and n >= 1
		total += n
	_check.call(each and total == floori(10 * RedMoon.ELITE_MULT) and RedMoon.elite_count(1, 1) == 2,
			"Lua I: %d elites em 10 eventos (×%.1f, sem sorteio)" % [total, RedMoon.ELITE_MULT])
	_check.call(not RedMoon.boss_extra(1) and RedMoon.boss_extra(2), "Eclipse só a partir da Lua II")
	_check.call(not RedMoon.shades_in_light(2) and RedMoon.shades_in_light(3), "Sombras na luz só a partir da Lua III")
	var food := RedMoon.FOOD_ITEM
	_check.call(RedMoon.item_weight(food, 40.0, 3) == 40.0 and RedMoon.item_weight(food, 40.0, 4) == 0.0
			and RedMoon.item_weight(&"sushi", 8.0, 5) == 8.0, "Lua IV: só o onigiri sai do sorteio (o sushi fica)")
	var meal := LevelUpSystem.fallback_cards(false)
	var coins := LevelUpSystem.fallback_cards(true)
	_check.call(meal.size() == 2 and coins.size() == 1 and String(coins[0]["kind"]) == "ryo"
			and LevelUpSystem.is_fallback(coins), "Lua IV: a mão de comida/moedas fica só com as moedas")
	_check.call(RedMoon.kami_offers(4, KamiSystem.OFFER_COUNT) == KamiSystem.OFFER_COUNT
			and RedMoon.kami_offers(5, KamiSystem.OFFER_COUNT) == RedMoon.PACTS, "Lua V: %d pactos" % RedMoon.PACTS)
	var texts := true
	for moon: int in range(0, HyakkiGame.MAX_MOON + 1):
		var lines := RedMoon.rules_text(moon)
		texts = texts and lines.size() == moon
		for line: String in lines:
			texts = texts and not line.is_empty() and not line.contains("%s") and not line.contains("%d")
	_check.call(texts and RedMoon.rule_text(RedMoon.FEW_PACTS).contains(str(RedMoon.PACTS))
			and RedMoon.rule_text(RedMoon.ELITES).contains("+%d%%" % roundi((RedMoon.ELITE_MULT - 1.0) * 100.0)),
			"Lua Vermelha: textos somados até a lua, com os números das constantes")


# --- Numa partida ------------------------------------------------------------------------

func run(host: Node, check: Callable) -> void:
	_host = host
	_check = check
	await _test_elites()
	await _test_eclipse()
	await _test_shades()
	await _test_no_food()
	await _test_pacts()
	Settings.set_value(LevelUpSystem.AUTO_SETTING, "")
	GameClock.paused = true


func _test_elites() -> void:
	var counts: Array[int] = []
	var chances: Array[float] = []
	for moon: int in [0, RedMoon.ELITES]:
		var game := await _new_game(moon)
		var total := 0
		var events := 0
		for event: Dictionary in game.spawner.get("_events"):
			if String(event["type"]) == "elite":
				total += int(event.get("elites", 1))
				events += 1
		counts.append(total)
		# Um evento de elite de 2 põe dois elites em campo.
		game.enemies.reset()
		game.spawner.call("_run_event", {"type": "elite", "enemy": "oni_small", "elites": 2})
		var alive := 0
		for i: int in range(EnemyManager.CAPACITY):
			alive += int(game.enemies.alive[i] == 1 and game.enemies.elite[i] == 1)
		_check.call(alive == 2, "Lua %d: evento com 2 elites põe 2 em campo" % moon)
		# Altares: chance da 1ª depois de um Elite (sem pena), no rng da partida.
		var altars := game.altars
		altars.awakened = 1
		altars.since_elite = 0
		altars.force_outcome = &""
		var elites := 0
		for k: int in range(600):
			elites += int(altars.roll_outcome() == &"elite")
		chances.append(elites / 600.0)
		_check.call(events > 0 and total == (events if moon == 0 else floori(events * RedMoon.ELITE_MULT)),
				"Lua %d: %d elites nos %d eventos da vila" % [moon, total, events])
		await _free(game)
	_check.call(counts[1] > counts[0], "Lua I: mais elites que sem lua (%d > %d)" % [counts[1], counts[0]])
	var base := AltarSystem.ELITE_BASE
	_check.call(absf(chances[0] - base) < 0.07 and absf(chances[1] - base * RedMoon.ELITE_MULT) < 0.07,
			"Lua I: Elite dos altares %.0f%% -> %.0f%%" % [chances[0] * 100.0, chances[1] * 100.0])


func _test_eclipse() -> void:
	for moon: int in [RedMoon.BOSS_ATTACK - 1, RedMoon.BOSS_ATTACK]:
		var game := await _new_game(moon)
		var director := game.bosses
		var bad: Array[String] = []
		var tested := 0
		for id: StringName in DB.ids("bosses"):
			game.areas.reset()
			director.spawn(id, false)
			if director.bosses.is_empty() or StringName(director.bosses[-1]["id"]) != id:
				bad.append("%s não entrou" % id)
				continue
			var boss: Dictionary = director.bosses[-1]
			var patterns: Array = director.call("_patterns", boss)
			if patterns.is_empty():
				# O Shinigami (invencível) não ataca: nada a somar.
				director.bosses.remove_at(director.bosses.size() - 1)
				continue
			tested += 1
			var eclipses := 0
			for k: int in range(patterns.size() + 1):
				director.call("_start_pattern", boss)
				if String((boss.get("current", {}) as Dictionary).get("type", "")) == "eclipse":
					eclipses += 1
					if k != patterns.size() or String(boss["state"]) != "windup" \
							or not is_equal_approx(float(boss["timer"]), RedMoon.ECLIPSE_WINDUP):
						bad.append("%s: Eclipse fora do lugar ou sem preparar" % id)
				director.call("_back_to_move", boss)
			if eclipses != (1 if moon >= RedMoon.BOSS_ATTACK else 0):
				bad.append("%s: %d Eclipses" % [id, eclipses])
			var marks := _eclipse_marks(game)
			if marks != (RedMoon.ECLIPSE_RING_COUNT + 1 if moon >= RedMoon.BOSS_ATTACK else 0):
				bad.append("%s: %d avisos carmesim" % [id, marks])
			director.bosses.remove_at(director.bosses.size() - 1)
		_check.call(bad.is_empty() and tested >= 10,
				"Lua %d: Eclipse %s no rodízio dos %d chefes %s" % [moon, "só uma vez" if moon >= 2 else "ausente",
				tested, bad.slice(0, 4)])
		if moon >= RedMoon.BOSS_ATTACK:
			_check_eclipse_hits(game)
		await _free(game)


## Avisos do Eclipse no chão (na cor da lua).
func _eclipse_marks(game: HyakkiGame) -> int:
	var n := 0
	for e: Dictionary in game.areas.effects:
		if int(e["kind"]) == AreaEffects.Kind.TELEGRAPH and e.get("tint", Color.BLACK) == RedMoon.ECLIPSE_TINT:
			n += 1
	return n


## No disco a guardiã leva o golpe; na faixa entre o disco e o anel, nada.
func _check_eclipse_hits(game: HyakkiGame) -> void:
	var player := game.player
	player.god_mode = false
	var center := player.sim_pos
	var from := center + Vector2(160.0, 0.0)
	for safe: bool in [false, true]:
		game.areas.reset()
		player.invuln = 0.0
		player.hp = player.max_hp()
		player.sim_pos = center
		RedMoon.eclipse(game, from, center, &"tanuki")
		if safe:
			# Entre dois círculos do anel, no meio da faixa livre.
			var band := (RedMoon.ECLIPSE_CORE + RedMoon.ECLIPSE_RING - RedMoon.ECLIPSE_RING_RADIUS) * 0.5
			var angle := (center - from).angle() + PI / RedMoon.ECLIPSE_RING_COUNT
			player.sim_pos = center + Vector2.from_angle(angle) * band
		var t := 0.0
		while t < RedMoon.ECLIPSE_WINDUP + RedMoon.ECLIPSE_DELAY + 0.1:
			game.areas.step(1.0 / 60.0)
			player.invuln = 0.0
			t += 1.0 / 60.0
		var hurt := player.hp < player.max_hp()
		_check.call(hurt != safe and _eclipse_marks(game) == 0,
				"Eclipse: %s" % ("faixa entre o disco e o anel é segura" if safe else "o disco acerta quem fica"))
	player.sim_pos = center
	player.hp = player.max_hp()


func _test_shades() -> void:
	var speeds: Array[float] = []
	for moon: int in [RedMoon.SHADES - 1, RedMoon.SHADES]:
		var game := await _new_game(moon)
		var me := game.player.sim_pos
		# Luz pequena (a janela do headless é mínima): a borda da tela fica bem fora dela.
		game.lantern.radius = 24.0
		var light := game.lantern.radius
		_check.call(game.view_size().y * 0.5 + Spawner.EDGE_MARGIN_MIN > light * 1.5,
				"Lua %d: borda da tela fora da luz" % moon)
		var inside := 0
		var other := 0
		for k: int in range(400):
			inside += int(RedMoon.spawn_point(game, &"shade_ghost").distance_to(me) < light)
			other += int(RedMoon.spawn_point(game, &"slime_rice").distance_to(me) < light)
		var expect := RedMoon.SHADE_LIGHT_CHANCE * 400.0 if moon >= RedMoon.SHADES else 0.0
		_check.call(absf(inside - expect) < 40.0 and other == 0,
				"Lua %d: %d de 400 Sombras nascem na luz (outros: %d)" % [moon, inside, other])
		# Uma Sombra dentro da luz: com a regra ela anda como no escuro (SHADE_DARK_SPEED).
		game.enemies.reset()
		var i := game.enemies.spawn(&"shade_ghost", me + Vector2(light * 0.4, 0.0), 1.0, 1.0)
		game.enemies.vel[i] = Vector2.ZERO
		game.enemies.push[i] = Vector2.ZERO
		game.enemies.step(1.0 / 60.0)
		speeds.append(game.enemies.vel[i].length() / game.enemies.speed[i])
		await _free(game)
	_check.call(speeds[0] > 0.0 and absf(speeds[1] / speeds[0] - EnemyManager.SHADE_DARK_SPEED) < 0.02,
			"Lua III: Sombra na luz %.1fx mais rápida (sem a regra, passo normal)" % (speeds[1] / maxf(speeds[0], 0.001)))


func _test_no_food() -> void:
	for moon: int in [RedMoon.NO_FOOD - 1, RedMoon.NO_FOOD]:
		var game := await _new_game(moon)
		var seen := {}
		for k: int in range(800):
			var id := game.pickups.random_item_id()
			seen[id] = int(seen.get(id, 0)) + 1
		var gone := moon >= RedMoon.NO_FOOD
		_check.call(seen.has(RedMoon.FOOD_ITEM) != gone and seen.has(&"sushi"),
				"Lua %d: onigiri %s das lanternas, sushi continua (%s)" % [moon, "fora" if gone else "dentro", seen])
		# Tudo no máximo: a mão vira comida/moedas (só moedas na Lua IV).
		var lu := game.level_up
		for weapon: Weapon in game.weapons:
			weapon.level = weapon.max_level
		for id: StringName in DB.ids("weapons") + DB.ids("passives"):
			lu.banished.append(id)
		var hand := lu.build_choices(game.rng)
		var kinds := hand.map(func(c: Dictionary) -> String: return String(c["kind"]))
		_check.call(LevelUpSystem.is_fallback(hand) and kinds == (["ryo"] if gone else ["heal", "ryo"]),
				"Lua %d: mão de quem tem tudo no máximo %s" % [moon, kinds])
		# "Comida" na escolha automática, com a vida baixa: sem bolinho, pega as moedas.
		game.player.hp = game.player.max_hp() * 0.3
		Settings.set_value(LevelUpSystem.AUTO_SETTING, "heal")
		var auto := lu.auto_card(hand)
		_check.call(String(auto.get("kind", "")) == ("ryo" if gone else "heal"),
				"Lua %d: escolha automática Comida -> %s" % [moon, auto.get("kind", "")])
		Settings.set_value(LevelUpSystem.AUTO_SETTING, "")
		var ryo := game.tracker.ryo
		var reward := game.chests.call("_next_reward") as Dictionary
		_check.call(String(reward.get("kind", "")) == ("ryo" if gone else "heal")
				and (game.tracker.ryo > ryo) == gone, "Lua %d: baú do fim dá %s" % [moon, reward.get("kind", "")])
		await _free(game)


func _test_pacts() -> void:
	for moon: int in [RedMoon.FEW_PACTS - 1, RedMoon.FEW_PACTS]:
		var game := await _new_game(moon)
		var offer := game.kami.offer()
		var want := RedMoon.PACTS if moon >= RedMoon.FEW_PACTS else KamiSystem.OFFER_COUNT
		_check.call(offer.size() == want, "Lua %d: santuário com %d Kami" % [moon, offer.size()])
		await _free(game)


func _new_game(moon: int) -> HyakkiGame:
	var game := (load(GAME_SCENE) as PackedScene).instantiate() as HyakkiGame
	game.config = CONFIG.duplicate()
	game.config["moon"] = moon
	_host.add_child(game)
	await _host.get_tree().process_frame
	await _host.get_tree().process_frame
	# Passos à mão: a partida não anda sozinha.
	GameClock.paused = true
	return game


func _free(game: HyakkiGame) -> void:
	game.queue_free()
	GameClock.paused = false
	await _host.get_tree().process_frame
