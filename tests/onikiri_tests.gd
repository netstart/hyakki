extends RefCounted
## Onikiri (鬼切) e Dōjigiri (童子切), a espada da Yuki: arma inicial dela, combo 0→1→2→0,
## meia-lua só à frente (Quantidade 2 corta atrás), golpe final mais forte, rastro só de
## desenho com teto, e a onda do Dōjigiri que viaja e fere cada inimigo uma vez.
## Chamado por tests/integration_tests.gd, que passa o nó da cena e o _check.

const GAME_SCENE := "res://scenes/game/Game.tscn"
## Multiplicador de vida dos alvos de teste (não morrem com os golpes).
const HP_MULT := 1000.0


func run(host: Node, check: Callable) -> void:
	_check_data(check)
	var scene := load(GAME_SCENE) as PackedScene
	var game := scene.instantiate() as HyakkiGame
	game.config = {"hero": "yuki", "stage": "bamboo", "moon": 0, "mode": "normal", "seed": 13, "speed": 1}
	host.add_child(game)
	await host.get_tree().process_frame
	check.call(game.has_weapon(&"onikiri"), "Yuki começa com o Onikiri")
	check.call(not game.has_weapon(&"raijin"), "Yuki não começa mais com o Tambor de Raijin")
	check.call(game.get_weapon(&"onikiri") is Onikiri, "Onikiri nasce com o comportamento Onikiri")
	var player := game.player
	player.god_mode = true
	player.facing_x = 1.0
	_clear(game)
	var weapon := game._make_weapon(&"onikiri") as Onikiri
	check.call(weapon != null and not weapon.from_hand(), "Onikiri sai do corpo, não da mão")
	if weapon == null:
		game.queue_free()
		return
	_check_combo(game, weapon, check)
	_check_arc(game, weapon, check)
	_check_finisher(game, weapon, check)
	_check_trails(game, weapon, check)
	_check_wave(game, check)
	game.queue_free()
	GameClock.paused = false
	await host.get_tree().process_frame


func _check_data(check: Callable) -> void:
	check.call(String(DB.heroes[&"yuki"]["weapon"]) == "onikiri", "heroes.json: arma da Yuki é o Onikiri")
	var base := DB.weapon(&"onikiri")
	var evo := DB.weapon(&"dojigiri")
	check.call(String(base.get("evolution", "")) == "dojigiri" and String(evo.get("from", "")) == "onikiri",
			"Onikiri evolui para Dōjigiri e o Dōjigiri vem do Onikiri")
	check.call(DB.passives.has(StringName(base.get("evolves_with", ""))), "Onikiri evolui com passiva existente")
	check.call(String(evo.get("behavior", "")) == "onikiri" and bool((evo.get("flags", {}) as Dictionary).get(
			"combo_wave", false)), "Dōjigiri usa o comportamento onikiri com a onda")
	check.call(String(base.get("unlock", "")) == String(DB.heroes[&"yuki"]["unlock"]),
			"Onikiri libera com a mesma conquista da Yuki")
	check.call(String(DB.achievements[&"ach_boss_red_oni"]["reward"]).contains("weapon:onikiri"),
			"vencer o Oni Vermelho libera o Onikiri para as outras guardiãs")
	check.call(HitSounds.for_weapon(base) == "hit_blade", "Onikiri acerta com som de lâmina")
	check.call(ResourceLoader.exists(String(base["icon"])) and ResourceLoader.exists(String(evo["icon"])),
			"ícones do Onikiri e do Dōjigiri existem")
	for key: String in ["weapon.onikiri.name", "weapon.onikiri.desc", "weapon.dojigiri.name",
			"weapon.dojigiri.desc"]:
		check.call(TranslationServer.translate(key) != key, "texto %s existe" % key)


func _check_combo(game: HyakkiGame, weapon: Onikiri, check: Callable) -> void:
	var steps: Array[int] = []
	for _k: int in range(4):
		steps.append(weapon.combo)
		weapon.fire_all()
	check.call(steps == [0, 1, 2, 0], "combo do Onikiri: 0 → 1 → 2 → 0 (%s)" % [steps])
	check.call(weapon.radius(Onikiri.FINISHER) > weapon.radius(0) * 1.2, "golpe final tem raio maior")
	check.call(weapon.half_angle(Onikiri.FINISHER) > weapon.half_angle(0), "golpe final é mais aberto")
	weapon.combo = 0
	weapon.trails.clear()
	_clear(game)


## Inimigo à frente leva o corte; atrás não (Quantidade 1); com Quantidade 2, leva.
func _check_arc(game: HyakkiGame, weapon: Onikiri, check: Callable) -> void:
	var origin := game.player.sim_pos
	var front := _spawn(game, origin + Vector2(20, 0))
	var back := _spawn(game, origin + Vector2(-26, 0))
	var far := _spawn(game, origin + Vector2(0, 90))
	weapon.fire(origin)
	check.call(_lost(game, front) > 0.0, "Onikiri acerta o inimigo à frente, dentro do raio")
	check.call(is_zero_approx(_lost(game, back)), "Onikiri com Quantidade 1 não acerta atrás")
	check.call(is_zero_approx(_lost(game, far)), "Onikiri não acerta fora do raio")
	check.call(absf(_lost(game, front) - weapon.swing_damage(0)) < 0.05,
			"cada inimigo leva um único acerto por golpe (%.2f)" % _lost(game, front))
	weapon.level_up()
	check.call(weapon.amount() >= 2, "Onikiri nível 2 tem Quantidade 2")
	weapon.fire(origin)
	check.call(_lost(game, back) > 0.0, "Onikiri com Quantidade 2 também corta atrás")
	weapon.level = 1
	weapon._recalculate()
	_clear(game)
	# Sem inimigos, o corte vai para onde a guardiã olha.
	game.player.facing_x = -1.0
	check.call(weapon.aim(origin) == Vector2.LEFT, "sem alvo, o Onikiri corta para onde a Yuki olha")
	game.player.facing_x = 1.0
	var below := _spawn(game, origin + Vector2(0, 30))
	check.call(weapon.aim(origin).is_equal_approx(Vector2.DOWN), "com alvo, o Onikiri mira no inimigo mais próximo")
	game.enemies.despawn(below)


func _check_finisher(game: HyakkiGame, weapon: Onikiri, check: Callable) -> void:
	var origin := game.player.sim_pos
	var target := _spawn(game, origin + Vector2(18, 0))
	weapon.combo = 0
	weapon.fire(origin)
	var normal := _lost(game, target)
	game.enemies.despawn(target)
	target = _spawn(game, origin + Vector2(18, 0))
	weapon.combo = Onikiri.FINISHER
	weapon.fire(origin)
	var final := _lost(game, target)
	check.call(normal > 0.0 and final > normal * 1.4, "golpe final dá mais dano (%.1f > %.1f)" % [final, normal])
	weapon.combo = 0
	_clear(game)


## Rastro é só desenho: varre, some sozinho e respeita o teto.
func _check_trails(game: HyakkiGame, weapon: Onikiri, check: Callable) -> void:
	weapon.trails.clear()
	for _k: int in range(Onikiri.MAX_TRAILS + 4):
		weapon.fire(game.player.sim_pos)
	check.call(weapon.trails.size() == Onikiri.MAX_TRAILS, "rastros do Onikiri ficam no teto")
	weapon._advance_trails(Onikiri.SWEEP_TIME + Onikiri.FADE_TIME + 0.01)
	check.call(weapon.trails.is_empty(), "rastros do Onikiri somem depois de varrer e apagar")
	check.call(is_equal_approx(Onikiri.stepped_alpha(0.0), 1.0) and is_equal_approx(Onikiri.stepped_alpha(1.0), 0.0),
			"rastro apaga em degraus, de 1 até 0")
	check.call(weapon.waves.is_empty(), "Onikiri sem evolução não solta onda")


## Dōjigiri: o golpe final solta uma onda que viaja e fere uma vez um inimigo longe do corte.
func _check_wave(game: HyakkiGame, check: Callable) -> void:
	var evo := game._make_weapon(&"dojigiri") as Onikiri
	check.call(evo != null and evo.amount() >= 2, "Dōjigiri nasce com o comportamento Onikiri e Quantidade 2")
	if evo == null:
		return
	var origin := game.player.sim_pos
	var far := _spawn(game, origin + Vector2(100, 0))
	evo.combo = 0
	evo.fire(origin)
	check.call(evo.waves.is_empty(), "Dōjigiri: só o golpe final solta a onda")
	evo.combo = Onikiri.FINISHER
	evo.fire(origin)
	check.call(not evo.waves.is_empty(), "Dōjigiri: o golpe final solta a onda")
	check.call(is_zero_approx(_lost(game, far)), "inimigo longe não leva o corte em si")
	var hits := 0
	var last := game.enemies.hp[far]
	for _k: int in range(int(Onikiri.WAVE_TIME / 0.016) + 10):
		evo._advance_waves(1.0 / 60.0)
		if game.enemies.hp[far] < last:
			hits += 1
			last = game.enemies.hp[far]
		game.enemies.pos[far] = origin + Vector2(100, 0)
	check.call(hits == 1, "a onda do Dōjigiri fere o inimigo distante uma única vez (%d)" % hits)
	check.call(evo.waves.is_empty(), "a onda do Dōjigiri some depois de %.1f s" % Onikiri.WAVE_TIME)
	evo.on_removed()
	_clear(game)


func _spawn(game: HyakkiGame, at: Vector2) -> int:
	var i := game.enemies.spawn(&"slime_rice", at, HP_MULT, 1.0)
	game.enemies.spatial.clear()
	for j: int in range(EnemyManager.CAPACITY):
		if game.enemies.alive[j] == 1:
			game.enemies.spatial.insert(j, game.enemies.pos[j])
	return i


## Vida perdida pelo alvo desde que nasceu.
func _lost(game: HyakkiGame, i: int) -> float:
	return game.enemies.max_hp[i] - game.enemies.hp[i]


func _clear(game: HyakkiGame) -> void:
	for i: int in range(EnemyManager.CAPACITY):
		if game.enemies.alive[i] == 1:
			game.enemies.despawn(i)
	game.enemies.spatial.clear()
