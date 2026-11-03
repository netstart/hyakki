extends RefCounted
## Habilidades do Tora (scripts/systems/abilities/tora_abilities.gd) num cenário montado, no estilo
## de _check_aki (tests/ability_tests.gd, que empresta os ajudantes): Martelo na Bigorna (queda,
## dano, atordoamento, mira no mais próximo), Corrente Puxadora (dano, puxão, estouro depois do
## atraso), Têmpera (vapor que fere e empurra, armadura, cura, contorno) e a partida suspensa.

var _check: Callable
var _t: RefCounted


func run(host: Node, check: Callable, helpers: RefCounted) -> void:
	_check = check
	_t = helpers
	var game: HyakkiGame = await _t._new_game(host, "tora", 21)
	var ab := game.abilities
	_t._reset_abilities(game)
	var tora := ab.behavior as ToraAbilities
	_check.call(tora != null, "Tora: comportamento próprio (ToraAbilities)")
	if tora == null:
		game.queue_free()
		return
	game.level = 10
	_check_hammer(game, tora)
	_check_chain(game, tora)
	_check_quench(game, tora)
	await _check_save(host, game)
	game.queue_free()
	await host.get_tree().process_frame
	GameClock.paused = true


func _full(game: HyakkiGame) -> void:
	game.abilities.energy.value = game.abilities.energy_max()
	game.abilities.cooldowns.fill(0.0)


func _check_hammer(game: HyakkiGame, tora: ToraAbilities) -> void:
	var ab := game.abilities
	var mp := game.player.stats.get_stat("might") * ab.power()
	_t._clear(game)
	var target: int = _t._spawn(game, Vector2(0, 45))
	var far: int = _t._spawn(game, Vector2(-140, 0))
	game.enemies.speed[target] = 0.0
	game.enemies.speed[far] = 0.0
	_full(game)
	_check.call(ab.activate(0), "Martelo na Bigorna sai")
	_check.call(tora._hammers.size() == 1 and (tora._hammers[0]["pos"] as Vector2).distance_to(Vector2(0, 40)) < 1.0,
			"Martelo: cai 40 px à frente, rumo ao mais próximo")
	_t._tick(game, 6)
	_check.call(_t._lost(game, target) == 0.0, "Martelo: espera a queda")
	_t._tick(game, 8)
	var blow := 70.0 * mp
	_check.call(_t._lost(game, target) >= blow - 0.01 and _t._lost(game, target) <= blow * 2.0 + 0.01,
			"Martelo: %.0f no raio (veio %.1f)" % [blow, _t._lost(game, target)])
	_check.call(game.enemies.stun[target] > 0.5, "Martelo: atordoa ~0,8 s")
	_check.call(_t._lost(game, far) == 0.0 and tora._hammers.is_empty() and not tora._marks.is_empty(),
			"Martelo: longe fica; chão chamuscado")
	_check.call(game.tracker.damage_by_weapon.has(&"anvil_hammer"), "Martelo: dano registrado pela habilidade")


func _check_chain(game: HyakkiGame, tora: ToraAbilities) -> void:
	var ab := game.abilities
	var mp := game.player.stats.get_stat("might") * ab.power()
	_t._clear(game)
	var a: int = _t._spawn(game, Vector2(150, 0))
	var b: int = _t._spawn(game, Vector2(0, -120))
	# Fora do alcance de verdade da corrente (170 × área do herói), com folga.
	var out_at := Vector2(0, tora.area_of(ab.ability(1), "radius") + 50.0)
	var out: int = _t._spawn(game, out_at)
	for j: int in [a, b, out]:
		game.enemies.speed[j] = 0.0
	# Preso: longe da tela o EnemyManager recicla o inimigo para a borda.
	game.enemies.root_one(out, 99.0)
	_full(game)
	_check.call(ab.activate(1), "Corrente Puxadora sai")
	var lash := 30.0 * mp
	_check.call(_t._lost(game, a) >= lash - 0.01 and _t._lost(game, b) >= lash - 0.01 and _t._lost(game, out) == 0.0,
			"Corrente: %.0f em todos do raio" % lash)
	_check.call(tora._trails.size() == 2 and tora._blasts.size() == 1, "Corrente: rastros e estouro pendente")
	_t._tick(game, 20)
	_check.call(game.enemies.pos[a].length() < 45.0 and game.enemies.pos[b].length() < 45.0,
			"Corrente: puxa para perto (%.0f, %.0f)" % [game.enemies.pos[a].length(), game.enemies.pos[b].length()])
	_check.call(game.enemies.pos[out].distance_to(out_at) < 1.0, "Corrente: fora do raio não é puxado")
	_t._tick(game, 10)
	_check.call(tora._blasts.is_empty() and _t._lost(game, a) >= lash + 60.0 * mp - 0.01,
			"Corrente: estouro de brasa 0,4 s depois")


func _check_quench(game: HyakkiGame, tora: ToraAbilities) -> void:
	var ab := game.abilities
	var player := game.player
	var mp := player.stats.get_stat("might") * ab.power()
	_t._clear(game)
	var e: int = _t._spawn(game, Vector2(50, 0))
	player.hp = player.max_hp() * 0.5
	var hp := player.hp
	_full(game)
	_check.call(ab.activate(2), "Têmpera sai")
	_check.call(_t._lost(game, e) >= 90.0 * mp - 0.01, "Têmpera: vapor fere no raio")
	_check.call(is_equal_approx(player.hp, hp + player.max_hp() * 0.1), "Têmpera: cura 10% da vida")
	_check.call(is_equal_approx(player.armor_bonus, 5.0) and player.armor_time > 5.9, "Têmpera: +5 de armadura por 6 s")
	_t._tick(game, 12)
	_check.call(game.enemies.pos[e].length() > 90.0, "Têmpera: empurra para longe (%.0f)" % game.enemies.pos[e].length())
	_check.call(player.ability_rim.a > 0.0, "Têmpera: Tora brilha em laranja")
	_t._clear(game)
	_t._tick(game, 360)
	_check.call(tora._quench_time <= 0.0 and player.armor_time <= 0.0 and player.ability_rim.a == 0.0,
			"Têmpera: acaba em 6 s e apaga o brilho")
	player.hp = player.max_hp()


## Partida suspensa com o martelo no ar, o estouro pendente e a Têmpera correndo.
func _check_save(host: Node, game: HyakkiGame) -> void:
	var ab := game.abilities
	_t._clear(game)
	_t._spawn(game, Vector2(60, 0))
	_full(game)
	ab.activate(2)
	_full(game)
	ab.activate(1)
	_full(game)
	ab.activate(0)
	var snap: Dictionary = JSON.parse_string(JSON.stringify(game.snapshot()))
	var before := JSON.stringify(ab.state())
	var hash_before := ab.hash_tag()
	var second: HyakkiGame = await _t._new_game(host, "tora", 21)
	second.restore_snapshot(snap)
	var tora2 := second.abilities.behavior as ToraAbilities
	_check.call(JSON.stringify(second.abilities.state()) == before, "Tora: partida retomada mantém os efeitos")
	_check.call(second.abilities.hash_tag() == hash_before, "Tora: partida retomada, mesmo hash")
	_check.call(tora2._hammers.size() == 1 and tora2._blasts.size() == 1 and tora2._quench_time > 5.0,
			"Tora: retomada com o martelo no ar, o estouro e a Têmpera")
	_check.call(is_equal_approx(second.player.armor_bonus, 5.0) and second.player.armor_time > 5.0,
			"Tora: retomada reaplica a armadura")
	second.queue_free()
	await host.get_tree().process_frame
	GameClock.paused = false
	_t._reset_abilities(game)
