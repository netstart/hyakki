extends RefCounted
## Afixos dos Elites (scripts/systems/elite_affixes.gd):
##   - regras (sem autoloads): quantos afixos por tempo e Lua Vermelha, sorteio sem repetir e sem
##     par proibido, todos os 8 saem, vida por afixo, cores/kanji/ícones de todos;
##   - partida de verdade, um Elite por afixo perto da guardiã: cada poder dispara (Trovão marca
##     raios, Raposa solta o leque, Miragem reaparece atrás dela, Rocha bate no chão com aviso
##     em anel, Névoa chama lacaios até o teto, Diamante absorve e volta, Yomi deixa poças, Vento
##     investe em linha); vaga reusada não herda poderes; dano dos poderes escala com a partida.

const GAME_SCENE := "res://scenes/game/Game.tscn"
const STEP := 1.0 / 60.0

var _check: Callable
var _host: Node


func run_unit(check: Callable) -> void:
	_check = check
	_check.call(EliteAffixes.affix_count(60.0, 0) == 1 and EliteAffixes.affix_count(EliteAffixes.TWO_AFFIX_T, 0) == 2,
			"afixo: 1 antes dos 8 min, 2 depois")
	_check.call(EliteAffixes.affix_count(60.0, 3) == 2 and EliteAffixes.affix_count(900.0, 5) == EliteAffixes.MAX_AFFIXES,
			"afixo: Lua Vermelha alta soma 1 (máx. 3)")
	_check.call(is_equal_approx(EliteAffixes.hp_mult(1), 1.0) and is_equal_approx(EliteAffixes.hp_mult(3), 1.7),
			"afixo: vida × (1 + 0,35 por afixo extra)")
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var seen := {}
	var ok := true
	for _k: int in 600:
		var n := rng.randi_range(1, 3)
		var list := EliteAffixes.roll(rng, n)
		ok = ok and list.size() == n
		var unique := {}
		for id: StringName in list:
			unique[id] = true
			seen[id] = true
		ok = ok and unique.size() == list.size()
		for pair: Array in EliteAffixes.FORBIDDEN:
			ok = ok and not (list.has(pair[0]) and list.has(pair[1]))
	_check.call(ok, "afixo: sorteio sem repetir e sem par proibido")
	_check.call(seen.size() == EliteAffixes.IDS.size(), "afixo: os 8 afixos saem (%d)" % seen.size())
	var again := RandomNumberGenerator.new()
	again.seed = 5
	var other := RandomNumberGenerator.new()
	other.seed = 5
	_check.call(EliteAffixes.roll(again, 3) == EliteAffixes.roll(other, 3), "afixo: mesmo rng, mesmo sorteio")
	var complete := true
	for id: StringName in EliteAffixes.IDS:
		complete = complete and EliteAffixes.COLORS.has(id) and EliteAffixes.kanji_of(id).length() == 1
	_check.call(complete, "afixo: todos com cor e kanji")
	_check.call(not EliteAffixes.allowed([&"kagero"], &"kaze") and EliteAffixes.allowed([&"kagero"], &"kongo")
			and not EliteAffixes.allowed([&"iwa"], &"iwa"), "afixo: pares proibidos e repetição barrados")


# --- Partida -------------------------------------------------------------------------------

func run(host: Node, check: Callable) -> void:
	_host = host
	_check = check
	for id: StringName in EliteAffixes.IDS:
		await _test_affix(id)
	await _test_slot_reuse()
	await _test_names()
	await _test_held()
	await _test_shield_flash()
	GameClock.paused = false
	await _host.get_tree().process_frame


func _new_game() -> HyakkiGame:
	var game := (load(GAME_SCENE) as PackedScene).instantiate() as HyakkiGame
	game.config = {"hero": "aki", "stage": "village", "moon": 0, "mode": "normal", "seed": 321, "speed": 1}
	_host.add_child(game)
	await _host.get_tree().process_frame
	GameClock.paused = true
	game.player.god_mode = true
	game.spawner.hush(999.0)
	GameClock.game_time = 300.0
	game.spawner.skip_until(300.0)
	game.spawner.hush(999.0)
	return game


func _free(game: HyakkiGame) -> void:
	game.queue_free()
	GameClock.paused = false
	await _host.get_tree().process_frame


func _tick(game: HyakkiGame, count: int, hold: Vector2) -> void:
	for _k: int in count:
		game.player.sim_pos = hold
		game.player.velocity = Vector2.ZERO
		GameClock.game_time += STEP
		game._on_tick(STEP)
		if game.hud.overlay_open():
			game.hud.bot_answer()


## Elite com `list` afixos a `offset` da guardiã (sem o altar: direto pelo EliteAffixes).
func _elite(game: HyakkiGame, list: Array[StringName], offset: Vector2, id: StringName = &"kappa_young") -> int:
	var i := game.enemies.spawn(id, game.player.sim_pos + offset, game.enemy_hp_mult() * 50.0,
			game.enemy_damage_mult(), true)
	game.altars.affixes.attach(i, list, "")
	return i


func _telegraphs(game: HyakkiGame, source: StringName, radius: float = -1.0) -> int:
	var n := 0
	for e: Dictionary in game.areas.effects:
		if int(e["kind"]) == AreaEffects.Kind.TELEGRAPH and StringName(e["source"]) == source \
				and (radius < 0.0 or is_equal_approx(float(e["radius"]), radius)):
			n += 1
	return n


func _test_affix(id: StringName) -> void:
	var game := await _new_game()
	var me := game.player.sim_pos
	var offset := Vector2(90, 0) if id != &"iwa" else Vector2(40, 0)
	# Vento: um atirador (fica a meia distância, onde a investida sai); os outros, um investidor.
	var i := _elite(game, [id], offset, &"ghost_monk" if id == &"kaze" else &"kappa_young")
	var enemies := game.enemies
	var src := enemies.type_ids[enemies.kind[i]]
	var label := "afixo %s:" % id
	match id:
		&"raijin":
			var marks := 0
			for _s: int in 40:
				_tick(game, 6, me)
				marks = maxi(marks, _telegraphs(game, src, EliteAffixes.RAIJIN_RADIUS))
			_check.call(marks == EliteAffixes.RAIJIN_MARKS, "%s %d raios marcados perto da guardiã" % [label, marks])
		&"kitsunebi":
			var before := game.enemy_shots.count_alive
			_tick(game, roundi((EliteAffixes.FIRST_CAST + 0.1) / STEP), me)
			_check.call(game.enemy_shots.count_alive >= before + EliteAffixes.FOX_COUNT, "%s leque de fogos-fátuos" % label)
		&"kagero":
			var moved := false
			for _s: int in 60:
				_tick(game, 6, me)
				if enemies.alive[i] == 1 and absf(enemies.pos[i].distance_to(me) - EliteAffixes.KAGERO_BEHIND) < 12.0:
					moved = true
					break
			_check.call(moved, "%s reaparece atrás da guardiã" % label)
		&"iwa":
			var ring := 0
			var held := false
			for _s: int in 40:
				_tick(game, 6, me)
				ring = maxi(ring, _telegraphs(game, src, EliteAffixes.IWA_RADIUS))
				held = held or enemies.controlled[i] == 1
			_check.call(ring > 0 and held, "%s para e bate no chão com aviso em anel" % label)
		&"kasumi":
			var common := enemies.count_common
			_tick(game, roundi(30.0 / STEP), me + Vector2(-120, 0))
			var minions := (game.altars.affixes.record(i)["minions"] as Array).size()
			_check.call(enemies.count_common > common and minions <= EliteAffixes.KASUMI_CAP and minions > 0,
					"%s lacaios com teto (%d)" % [label, minions])
		&"kongo":
			var full := enemies.shield[i]
			_check.call(full > 0.0 and is_equal_approx(full, enemies.max_hp[i] * EliteAffixes.SHIELD_FRACTION),
					"%s escudo cheio" % label)
			var hp := enemies.hp[i]
			game.deal_damage(&"katana", i, full * 0.5, Vector2.RIGHT, 0.0)
			_check.call(is_equal_approx(enemies.hp[i], hp) and enemies.shield[i] < full, "%s escudo absorve o golpe" % label)
			game.deal_damage(&"katana", i, full, Vector2.RIGHT, 0.0)
			_check.call(enemies.shield[i] <= 0.0 and enemies.hp[i] < hp, "%s escudo quebra e o resto passa" % label)
			_tick(game, roundi((EliteAffixes.KONGO_REGEN + 0.2) / STEP), me + Vector2(-200, 0))
			_check.call(is_equal_approx(enemies.shield[i], full),
					"%s escudo volta depois de %.0f s" % [label, EliteAffixes.KONGO_REGEN])
		&"yomi":
			var pools := 0
			for _s: int in 30:
				_tick(game, 6, me)
				pools = 0
				for e: Dictionary in game.areas.effects:
					pools += 1 if int(e["kind"]) == AreaEffects.Kind.HAZARD_POOL else 0
			_check.call(pools >= 2, "%s poças de miasma pelo caminho (%d)" % [label, pools])
		&"kaze":
			var start := enemies.pos[i]
			var dashed := 0.0
			var warned := false
			for _s: int in 300:
				_tick(game, 1, me + Vector2(-60, 0))
				var rec := game.altars.affixes.record(i)
				warned = warned or (not rec.is_empty() and (rec["line"] as Array).size() == 2)
				dashed = maxf(dashed, enemies.vel[i].length())
			_check.call(warned and dashed >= EliteAffixes.KAZE_SPEED * 0.9 and enemies.pos[i] != start,
					"%s investida com aviso em linha (%s, %.0f px/s)" % [label, warned, dashed])
	_check.call(game.altars.affixes.hash_tag().contains(String(id)), "%s entra no hash" % label)
	await _free(game)


## Vaga reusada não herda os poderes; o Elite que some (travessia, amanhecer) sai da lista.
func _test_slot_reuse() -> void:
	var game := await _new_game()
	var i := _elite(game, [&"raijin"], Vector2(100, 0))
	game.enemies.despawn(i)
	var j := game.enemies.spawn(&"slime_rice", game.player.sim_pos + Vector2(100, 0), 1.0, 1.0)
	_check.call(j == i and not game.altars.affixes.has(j) and game.altars.affixes.body_look(j) == Vector3(1, 0, 1),
			"afixo: vaga reusada não herda os poderes")
	_tick(game, 2, game.player.sim_pos)
	_check.call(game.altars.affixes.count() == 0, "afixo: registro do Elite sumido sai da lista")
	await _free(game)


func _test_names() -> void:
	var name := EliteAffixes.elite_name(&"kappa_young", [&"raijin", &"kagero"])
	var enemy := TranslationServer.translate("enemy.kappa_young.name")
	_check.call(name.contains(enemy) and name.contains(TranslationServer.translate("elite.affix.raijin"))
			and name.contains(" · " + TranslationServer.translate("elite.affix.kagero")), "afixo: nome \"%s\"" % name)
	_check.call(EliteAffixes.elite_name(&"kappa_young", []) == enemy, "afixo: sem afixo, só o nome do inimigo")


## Ampulheta e atordoamento seguram o poder em curso (investida do Vento, sumiço da Miragem).
func _test_held() -> void:
	var game := await _new_game()
	var me := game.player.sim_pos
	var i := _elite(game, [&"kaze"], Vector2(120, 0), &"ghost_monk")
	var rec := game.altars.affixes.record(i)
	rec["busy"] = &"kaze"
	rec["phase"] = &"dash"
	rec["t"] = EliteAffixes.KAZE_TIME
	rec["dir"] = Vector2.LEFT
	game.enemies.controlled[i] = 1
	game.enemies.freeze_time = 1.0
	var at := game.enemies.pos[i]
	_tick(game, 20, me)
	_check.call(game.enemies.pos[i] == at and float(rec["t"]) == EliteAffixes.KAZE_TIME,
			"afixo: congelado, o Vento não investe")
	game.enemies.freeze_time = 0.0
	_tick(game, 10, me)
	_check.call(game.enemies.pos[i] != at, "afixo: descongelado, a investida continua")
	var k := _elite(game, [&"kagero"], Vector2(-120, 0))
	var krec := game.altars.affixes.record(k)
	krec["busy"] = &"kagero"
	krec["t"] = EliteAffixes.KAGERO_WINDUP
	krec["dir"] = me + Vector2(0, 40)
	game.enemies.controlled[k] = 1
	game.enemies.stun[k] = 2.0
	var kat := game.enemies.pos[k]
	_tick(game, roundi((EliteAffixes.KAGERO_WINDUP + 0.2) / STEP), me)
	_check.call(game.enemies.pos[k] == kat and StringName(krec["busy"]) == &"kagero",
			"afixo: atordoada, a Miragem não termina")
	await _free(game)


## Golpes seguidos no escudo: um lampejo/som a cada AltarFx.SHIELD_HIT_GAP_MS, não um por golpe.
func _test_shield_flash() -> void:
	var game := await _new_game()
	var i := _elite(game, [&"kongo"], Vector2(100, 0))
	var before := game.altars.visuals.shield_hits_shown
	for _k: int in 12:
		game.deal_damage(&"katana", i, 1.0, Vector2.RIGHT, 0.0)
	_check.call(game.altars.visuals.shield_hits_shown - before <= 1, "afixo: lampejo do escudo limitado")
	await _free(game)
