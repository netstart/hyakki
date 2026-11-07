extends RefCounted
## Habilidades da Kuon (scripts/systems/abilities/kuon_abilities.gd), num cenário montado com os
## ajudantes de tests/ability_tests.gd (rodado por ele): Tamashii-gari (puxa, estoura e levanta
## servos dos que morrem, no máximo raise_max), Kotsu-heki (anel de ossos que fere e prende só na
## faixa e apaga os tiros que cruzam, por `time` s), Yomigaeri (os caídos voltam, estouro e tempo
## intangível com o contorno), partida suspensa no meio do anel (mesmo estado e hash) e o bot (mesmo
## estado na Baixa e na Alta).

const AbilityTests := preload("res://tests/ability_tests.gd")

var _check: Callable
var _t: AbilityTests


func run(host: Node, check: Callable) -> void:
	_check = check
	_t = AbilityTests.new()
	_t._check = check
	var game := await _t._new_game(host, "kuon", 43)
	GameClock.paused = false
	_check.call(game.abilities.behavior is KuonAbilities, "Kuon usa o comportamento KuonAbilities")
	_check_harvest(game)
	_check_wall(game)
	_check_yomigaeri(game)
	await _check_save(host, game)
	game.queue_free()
	await host.get_tree().process_frame
	await _check_bot(host)
	GameClock.paused = true


func _fresh(game: HyakkiGame) -> KuonAbilities:
	_t._clear(game)
	_t._reset_abilities(game)
	game.minions.reset()
	game.level = 10
	game.abilities.energy.value = game.abilities.energy_max()
	return game.abilities.behavior as KuonAbilities


func _tick(game: HyakkiGame, steps: int) -> void:
	for _k: int in range(steps):
		_t._tick(game, 1)
		game.minions.step(AbilityTests.DT)


func _check_harvest(game: HyakkiGame) -> void:
	var kuon := _fresh(game)
	var ability: Dictionary = game.abilities.abilities[0]
	var far := _t._spawn(game, Vector2(110, 0))
	game.enemies.speed[far] = 0.0
	var weak: Array[int] = []
	for k: int in range(6):
		var i := game.enemies.spawn(&"slime_rice", Vector2.from_angle(k * 1.05) * 60.0, 0.0001, 1.0)
		game.enemies.speed[i] = 0.0
		weak.append(i)
	_t._reindex(game)
	var d0 := game.enemies.pos[far].length()
	_check.call(game.abilities.activate(0), "Tamashii-gari sai")
	_tick(game, 10)
	_check.call(game.enemies.pos[far].length() < d0 - 20.0, "Tamashii-gari: as almas são puxadas para ela")
	_tick(game, 30)
	var dead := 0
	for i: int in weak:
		dead += int(game.enemies.alive[i] == 0)
	var raise := int(HeroAbilities.param(ability, "raise_max"))
	_check.call(dead == 6 and game.enemies.max_hp[far] - game.enemies.hp[far] > 0.0,
			"Tamashii-gari: o estouro fere em volta")
	_check.call(game.minions.count() == mini(raise, game.minions.cap()), "Tamashii-gari: até %d viram servos (%d)",
			[raise, game.minions.count()])
	_check.call(kuon._harvests.is_empty(), "Tamashii-gari: o estouro sai uma vez")


func _check_wall(game: HyakkiGame) -> void:
	var kuon := _fresh(game)
	var ability: Dictionary = game.abilities.abilities[1]
	var r := HeroAbilities.param(ability, "radius") * game.player.stats.get_stat("area")
	var on_band := _t._spawn(game, Vector2(r, 0))
	var inside := _t._spawn(game, Vector2(10, 0))
	for i: int in [on_band, inside]:
		game.enemies.speed[i] = 0.0
		game.enemies.controlled[i] = 1
	_check.call(game.abilities.activate(1), "Kotsu-heki sai")
	_check.call(game.enemies.root[on_band] > 0.0 and game.enemies.hp[on_band] < game.enemies.max_hp[on_band],
			"Kotsu-heki: quem está na faixa leva dano e fica preso")
	_check.call(game.enemies.root[inside] <= 0.0 and game.enemies.hp[inside] == game.enemies.max_hp[inside],
			"Kotsu-heki: quem está dentro do anel não")
	game.enemy_shots.spawn(Vector2(r + 30.0, 20.0), Vector2(-120.0, 0.0), 5.0, "spirit_orb")
	game.enemy_shots.spawn(Vector2(20.0, 0.0), Vector2(0.0, 1.0), 5.0, "spirit_orb")
	_tick(game, 30)
	_check.call(game.enemy_shots.count_alive == 1, "Kotsu-heki: o tiro que cruza o anel some (o de dentro fica)")
	_tick(game, roundi(HeroAbilities.param(ability, "time") / AbilityTests.DT) + 10)
	_check.call(kuon._wall_time <= 0.0 and not kuon.has_visuals(), "Kotsu-heki: o anel acaba em %s s",
			HeroAbilities.param(ability, "time"))
	game.enemy_shots.clear_all()


func _check_yomigaeri(game: HyakkiGame) -> void:
	var kuon := _fresh(game)
	var ability: Dictionary = game.abilities.abilities[2]
	game.minions.fallen = 7
	var e := _t._spawn(game, Vector2(40, 0))
	game.enemies.speed[e] = 0.0
	_check.call(game.abilities.activate(2), "Yomigaeri sai")
	_check.call(game.minions.count() == 7 and game.minions.fallen == 0, "Yomigaeri: os 7 caídos voltam")
	_check.call(game.player.invuln >= HeroAbilities.param(ability, "invuln") - 0.01
			and game.player.ability_rim.a <= 1.0, "Yomigaeri: intangível")
	_check.call(game.enemies.hp[e] < game.enemies.max_hp[e], "Yomigaeri: o estouro fere")
	_tick(game, 30)
	_check.call(game.player.ability_rim.a > 0.0 and kuon.has_visuals(), "Yomigaeri: contorno de alma")
	_tick(game, roundi(HeroAbilities.param(ability, "invuln") / AbilityTests.DT) + 5)
	_check.call(game.player.ability_rim.a == 0.0, "Yomigaeri: o contorno some no fim")
	_t._clear(game)
	var hp := game.player.hp
	game.player.hp = game.player.max_hp() * 0.3
	_check.call(kuon.bot_should_cast(2, ability), "Yomigaeri: o bot usa com a vida baixa, mesmo sem horda")
	game.player.hp = game.player.max_hp()
	_check.call(not kuon.bot_should_cast(2, ability), "Yomigaeri: com a vida cheia e sem horda, o bot espera")
	game.player.hp = hp


## Partida suspensa no meio do anel de ossos: mesmo estado e hash.
func _check_save(host: Node, game: HyakkiGame) -> void:
	_fresh(game)
	game.abilities.activate(1)
	game.abilities.energy.value = game.abilities.energy_max()
	game.abilities.activate(0)
	_tick(game, 6)
	var snap: Dictionary = JSON.parse_string(JSON.stringify(game.snapshot()))
	var before := JSON.stringify(game.abilities.state())
	var hash_before := game.abilities.hash_tag()
	var second := await _t._new_game(host, "kuon", 43)
	second.restore_snapshot(snap)
	_check.call(JSON.stringify(second.abilities.state()) == before, "Kuon: partida retomada no meio do anel")
	_check.call(second.abilities.hash_tag() == hash_before, "Kuon: partida retomada com o mesmo hash")
	second.queue_free()
	await host.get_tree().process_frame
	GameClock.paused = false


func _check_bot(host: Node) -> void:
	var summaries: Array[String] = []
	var uses: Array[String] = []
	for level: int in [GfxQuality.LOW, GfxQuality.HIGH]:
		GfxQuality.set_override(level)
		FxLayer.refresh_quality()
		var game := await _t._new_game(host, "kuon", 7, true)
		game.start_run(game.config)
		GameClock.paused = true
		game.player.god_mode = true
		game.level = 10
		# Meio da partida: as almas (Tamashii) enchem com os abates, e no começo há poucos.
		GameClock.game_time = AbilityTests.BOT_HERO_START
		game.spawner.skip_until(AbilityTests.BOT_HERO_START)
		# Almas cheias: o bot guarda energia para a 3ª (65) e, sem isso, 15 s não bastam para juntar.
		game.abilities.energy.value = game.abilities.energy_max()
		for _k: int in range(AbilityTests.BOT_STEPS):
			GameClock.paused = false
			GameClock.game_time += AbilityTests.DT
			game._on_tick(AbilityTests.DT)
		summaries.append(game.state_summary("BOT"))
		uses.append(str(Array(game.abilities.uses_by_slot)))
		_check.call(game.abilities.uses > 0 and game.minions.raised_total > 0,
				"Kuon: bot usa as habilidades e levanta servos (%s)", uses[-1])
		game.queue_free()
		await host.get_tree().process_frame
	GfxQuality.clear_override()
	FxLayer.refresh_quality()
	_check.call(summaries[0] == summaries[1] and uses[0] == uses[1], "Kuon: bot com o mesmo estado na Baixa e na Alta")
