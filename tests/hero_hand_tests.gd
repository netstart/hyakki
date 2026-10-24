extends RefCounted
## Yuki menor (draw_scale), com a mão de onde saem os poderes ("hand") e a pose de ataque;
## heróis sem "hand" continuam disparando de sim_pos.
## Chamado por tests/integration_tests.gd, que passa o nó da cena e o _check.

const GAME_SCENE := "res://scenes/game/Game.tscn"


func run(host: Node, check: Callable) -> void:
	var yuki_data: Dictionary = DB.heroes[&"yuki"]
	check.call(float(yuki_data.get("draw_scale", 1.0)) < 1.0, "Yuki tem draw_scale menor que 1")
	for hero_id: StringName in [&"yuki", &"goro"]:
		var scene := load(GAME_SCENE) as PackedScene
		var game := scene.instantiate() as HyakkiGame
		game.config = {"hero": hero_id, "stage": "bamboo", "moon": 0, "mode": "normal", "seed": 13, "speed": 1}
		host.add_child(game)
		await host.get_tree().process_frame
		var player := game.player
		player.god_mode = true
		for i: int in range(EnemyManager.CAPACITY):
			if game.enemies.alive[i] == 1:
				game.enemies.despawn(i)
		var origin := player.sim_pos
		if hero_id == &"yuki":
			check.call(player.has_hand(), "Yuki tem ponto da mão")
			var top := player.sprite_top()
			check.call(top >= -21.0 and top <= -15.0, "Yuki desenhada na altura dos outros heróis (topo %s)" % top)
			player.facing_x = 1.0
			var right := player.hand_position()
			check.call(right.y < origin.y, "mão da Yuki fica acima dos pés")
			check.call(right.x > origin.x, "mão da Yuki fica do lado para onde ela olha (direita)")
			player.facing_x = -1.0
			var left := player.hand_position()
			check.call(left.x < origin.x and is_equal_approx(left.y, right.y)
					and is_equal_approx(left.x - origin.x, origin.x - right.x),
					"mão da Yuki espelha quando ela olha para a esquerda")
			var clone := origin + Vector2(30, 5)
			check.call(player.hand_position(clone) - clone == left - origin, "clone usa a mesma mão")
			player.facing_x = 1.0
		else:
			check.call(not player.has_hand(), "%s não tem ponto da mão" % hero_id)
			player.facing_x = -1.0
			check.call(player.hand_position() == origin, "%s sem mão: origem dos disparos = sim_pos" % hero_id)
			player.facing_x = 1.0
		# Disparo do Raijin: começa a pose de ataque e, com mão, um raio sai dela até o alvo.
		var target := game.enemies.spawn(&"slime_rice", origin + Vector2(60, 0), 1000.0, 1.0)
		game.enemies.spatial.clear()
		for i: int in range(EnemyManager.CAPACITY):
			if game.enemies.alive[i] == 1:
				game.enemies.spatial.insert(i, game.enemies.pos[i])
		game.areas.reset()
		player.cast_time = 0.0
		player._cast_lock = 0.0
		var weapon := game._make_weapon(&"raijin")
		weapon.fire_all()
		check.call(player.cast_time > 0.0, "%s: disparar uma arma começa a pose de ataque" % hero_id)
		var from_hand := 0
		for b: Dictionary in game.areas.bolts:
			if (b["from"] as Vector2).is_equal_approx(player.hand_position()) and player.has_hand():
				from_hand += 1
		if hero_id == &"yuki":
			check.call(from_hand >= 1, "Yuki: o raio do Raijin sai da mão")
		else:
			var all_sky := true
			for b: Dictionary in game.areas.bolts:
				all_sky = all_sky and is_equal_approx((b["to"] - b["from"]).y, AreaEffects.BOLT_FALL)
			check.call(all_sky, "%s sem mão: o Raijin só cai do céu" % hero_id)
		# Várias armas seguidas não reiniciam a pose (trava contra piscar).
		player.cast_time = 0.01
		player.on_cast()
		check.call(is_equal_approx(player.cast_time, 0.01), "%s: pose de ataque com intervalo mínimo" % hero_id)
		await _check_slash(host, player, hero_id, check)
		var incense := game._make_weapon(&"incense")
		check.call(incense != null and not incense.from_hand(), "Incenso sai do corpo, não da mão")
		if target >= 0:
			game.enemies.despawn(target)
		game.queue_free()
		GameClock.paused = false
		await host.get_tree().process_frame


## Golpe de espada (on_slash): pose só de desenho, virada para o corte, que acaba sozinha.
func _check_slash(host: Node, player: Player, hero_id: StringName, check: Callable) -> void:
	player.cast_time = 0.0
	player._cast_lock = 0.0
	player.facing_x = 1.0
	var pos := player.sim_pos
	player.on_slash(-1.0, 0)
	check.call(player.is_slashing() and is_equal_approx(player.slash_time, Player.SLASH_TIME),
			"%s: on_slash começa o golpe" % hero_id)
	check.call(player.sim_pos == pos and player.facing_x == 1.0, "%s: on_slash não mexe na simulação" % hero_id)
	check.call(player.visual_facing_x() == -1.0, "%s: no golpe o corpo vira para o lado do corte" % hero_id)
	player.on_cast()
	check.call(player.cast_time == 0.0, "%s: disparo no meio do golpe não reinicia a pose de ataque" % hero_id)
	# Preparo recua, o corte avança além do repouso e inclina para a frente.
	player.slash_time = Player.SLASH_TIME - Player.SLASH_WINDUP
	check.call(float(player.slash_pose()["lunge"]) < 0.0, "%s: o preparo recua o corpo" % hero_id)
	player.slash_time = Player.SLASH_TIME - Player.SLASH_WINDUP - Player.SLASH_STRIKE * 0.99
	var hit := player.slash_pose()
	check.call(float(hit["lunge"]) >= 1.5 and float(hit["tilt"]) > 0.1, "%s: o corte avança e inclina" % hero_id)
	# Desenha no meio do golpe (com o clone sombra) para exercitar o caminho de desenho.
	player.clone_time = 0.5
	player.queue_redraw()
	await host.get_tree().process_frame
	player.clone_time = 0.0
	pos = player.sim_pos
	player.slash_time = Player.SLASH_TIME
	for i: int in range(12):
		player._process(0.025)
	check.call(player.sim_pos == pos and player.facing_x == 1.0, "%s: o golpe não mexe na simulação" % hero_id)
	var rest := player.slash_pose()
	check.call(not player.is_slashing() and float(rest["lunge"]) == 0.0 and float(rest["tilt"]) == 0.0
			and rest["scale"] == Vector2.ONE, "%s: o golpe acaba em repouso" % hero_id)
	check.call(player.visual_facing_x() == 1.0, "%s: depois do golpe o corpo volta a olhar para facing_x" % hero_id)
	# Passos do combo: o 1 corta de outro jeito; o arremate (2) dura mais.
	player.on_slash(1.0, 0)
	player.slash_time -= Player.SLASH_WINDUP + Player.SLASH_STRIKE
	var cut0 := player.slash_pose()
	player.on_slash(1.0, 1)
	player.slash_time -= Player.SLASH_WINDUP + Player.SLASH_STRIKE
	check.call(player.slash_pose() != cut0, "%s: os passos 0 e 1 do combo são cortes diferentes" % hero_id)
	player.on_slash(1.0, 2)
	check.call(player.slash_time > Player.SLASH_TIME and is_equal_approx(player.slash_time, Player.SLASH_FINISHER_TIME),
			"%s: o arremate dura mais que o golpe comum" % hero_id)
	player.queue_redraw()
	await host.get_tree().process_frame
	player.reset()
	check.call(player.slash_time == 0.0 and not player.is_slashing(), "%s: reset() limpa o golpe" % hero_id)
	player.is_alive = false
	player.on_slash(1.0, 0)
	check.call(not player.is_slashing(), "%s: sem golpe quando caída/morta" % hero_id)
	player.is_alive = true
	player.sim_pos = pos
	player.prev_pos = pos
	player.hp = player.max_hp()
