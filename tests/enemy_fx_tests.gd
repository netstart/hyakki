extends RefCounted
## Apresentação de inimigos, onis, chefes e da guardiã (scripts/systems/enemy_fx.gd,
## enemy_look.gd, boss_fx.gd, scripts/ui/boss_panel.gd e scripts/game/guardian_fx.gd):
## - cotas por nível (Baixa < Média < Alta) e troca ao vivo pelo Settings.changed;
## - estilos de morte/entrada por tipo e glifos dos kanji dos chefes na fonte japonesa;
## - determinismo: a mesma partida (com chefe, elite e mortes) dá o mesmo estado em Baixa e Alta;
## - chefe: painel com a faixa em kanji, barra, pose de ataque, morte épica com chuva de almas;
## - guardiã: tremor e anel no golpe, coluna de luz no nível novo.
## Chamado por tests/integration_tests.gd e por tests/run_tests.gd (só run_unit).

const GAME_SCENE := "res://scenes/game/Game.tscn"
const KEY := "graphics_quality"
const JA_FONT := "res://assets/fonts/fusion_pixel_12_ja.woff2"

var _host: Node
var _check: Callable


## Regras puras (sem cena e sem autoloads).
static func run_unit(check: Callable) -> void:
	var low := EnemyFx.cap_for(GfxQuality.LOW)
	var med := EnemyFx.cap_for(GfxQuality.MEDIUM)
	var high := EnemyFx.cap_for(GfxQuality.HIGH)
	check.call(low < med and med < high and high <= EnemyFx.CAPACITY, "inimigos: cota de partículas Baixa < Média < Alta")
	check.call(low >= 16, "inimigos: Baixa ainda tem partículas (%d)" % low)
	check.call(EnemyFx.death_style({"id": "oni_small", "death": "embers"}) == "embers", "inimigos: oni morre em brasas")
	check.call(EnemyFx.death_style({"id": "slime_rice"}) == "splash", "inimigos: slime respinga (sem campo)")
	check.call(EnemyFx.death_style({"id": "yurei", "flying": true, "archetype": "shade"}) == "mist",
			"inimigos: fantasma se desfaz em névoa (sem campo)")
	check.call(EnemyFx.death_style({"id": "x", "death": "inventado"}) == "ash", "inimigos: estilo desconhecido vira cinza")
	check.call(EnemyFx.spawn_style({"flying": true}) == "wisp", "inimigos: quem voa entra como fogo-fátuo")
	check.call(EnemyFx.spawn_style({"archetype": "tank"}) == "portal", "inimigos: tanque entra por portal de névoa")
	var fx := EnemyFx.new()
	check.call(fx.alive_count() == 0, "inimigos: EnemyFx começa vazio")
	fx.free()


func run(host: Node, check: Callable) -> void:
	_host = host
	_check = check
	var saved: Variant = Settings.get_value(KEY)
	GfxQuality.clear_override()
	_test_data()
	var low_state := await _play("low")
	var high_state := await _play("high")
	_check.call(low_state != "" and low_state == high_state,
			"inimigos: mesma partida em Baixa e Alta dá o mesmo estado (%s)" % high_state.get_slice(" hash=", 1))
	await _test_live_and_boss()
	Settings.set_value(KEY, saved)
	GfxQuality.clear_override()


func _test_data() -> void:
	var ja := load(JA_FONT) as Font
	for id: StringName in DB.ids("bosses"):
		var data: Dictionary = DB.bosses[id]
		var kanji := String(data.get("kanji", ""))
		_check.call(kanji.length() >= 2, "chefe %s tem nome em kanji" % id)
		var missing := ""
		for c: int in range(kanji.length()):
			if ja and not ja.has_char(kanji.unicode_at(c)):
				missing += kanji[c]
		var note := (" (falta %s)" % missing) if missing else ""
		_check.call(missing == "", "kanji de %s existe na fonte japonesa%s" % [id, note])
		for key: String in ["walk_sprite", "attack_sprite"]:
			if data.has(key):
				_check.call(ResourceLoader.exists(String(data[key]["path"])), "%s.%s existe" % [id, key])
	for part: String in ["Head", "Body1", "Body2", "BodyEnd", "Wing"]:
		_check.call(ResourceLoader.exists(EnemyLook.DRAGON_DIR + part + ".png"), "Dragão de Cinza: parte %s" % part)
	for name: String in ["e_roar_0", "e_boss_fall_0", "e_die_ash_0", "e_die_ember_2", "e_die_mist_1", "e_die_splat_0",
			"e_die_bone_0"]:
		_check.call(ResourceLoader.exists("res://assets/audio/sfx/%s.wav" % name), "som %s existe" % name)


func _new_game() -> HyakkiGame:
	var scene := load(GAME_SCENE) as PackedScene
	var game := scene.instantiate() as HyakkiGame
	game.config = {"hero": "aki", "stage": "village", "moon": 0, "mode": "normal", "seed": 4242, "speed": 1}
	_host.add_child(game)
	return game


## Partida curta com chefe, elite e mortes, passo a passo, desenhando entre os passos no nível
## `level`. Devolve o resumo do estado (com hash).
func _play(level: String) -> String:
	Settings.set_value(KEY, level)
	var game := _new_game()
	# Relógio parado já no add_child (start_run o solta): só os passos manuais abaixo contam,
	# então as duas rodadas fazem exatamente o mesmo número de passos.
	GameClock.paused = true
	game.player.god_mode = true
	await _host.get_tree().process_frame
	GameClock.paused = true
	var start_steps := game.step_index
	var summary := ""
	for tick: int in range(900):
		GameClock.game_time += GameClock.STEP
		game._on_tick(GameClock.STEP)
		if tick == 60:
			game.bosses.spawn(&"tanuki")
			game.enemies.spawn(&"oni_small", game.player.sim_pos + Vector2(40, 0), 1.0, 1.0, true)
		if tick % 90 == 45:
			# Mata quem está perto: dispara mortes, poeira e almas (desenho), igual nos dois níveis.
			var near: Array[int] = []
			game.enemies.query_circle(game.player.sim_pos, 120.0, near)
			for j: int in near:
				if not game.enemies.is_boss(j):
					game.enemies.damage(j, 99999.0, Vector2.RIGHT, 60.0)
		if tick % 30 == 0:
			await _host.get_tree().process_frame
	summary = "%d|%s" % [game.step_index - start_steps, game.state_summary("GFX")]
	game.queue_free()
	GameClock.paused = false
	await _host.get_tree().process_frame
	return summary


func _test_live_and_boss() -> void:
	Settings.set_value(KEY, "high")
	var game := _new_game()
	await _host.get_tree().process_frame
	var enemies := game.enemies
	_check.call(enemies.fx.cap == EnemyFx.cap_for(GfxQuality.HIGH) and enemies.look.soft_shadows,
			"inimigos: Alta tem cota cheia e sombra suave")
	Settings.set_value(KEY, "low")
	_check.call(enemies.fx.cap == EnemyFx.cap_for(GfxQuality.LOW) and not enemies.look.soft_shadows
			and enemies.look.detail == 0, "inimigos: troca ao vivo para Baixa (cota, sombra dura, detalhe 0)")
	enemies.fx.death(game.player.sim_pos, "embers", Color.RED, 1.0, true, false)
	_check.call(enemies.fx.alive_count() > 0 and enemies.fx.alive_count() <= enemies.fx.cap,
			"inimigos: morte em Baixa respeita a cota")
	_check.call(not game.player._fx.draws_shadow(), "guardiã: em Baixa fica a sombra simples do Player")
	Settings.set_value(KEY, "medium")
	_check.call(enemies.fx.cap == EnemyFx.cap_for(GfxQuality.MEDIUM) and enemies.look.detail == 1,
			"inimigos: troca ao vivo para Média")
	Settings.set_value(KEY, "high")
	_check.call(game.player._fx.draws_shadow(), "guardiã: sombra suave em Alta")
	# Guardiã: golpe e nível novo.
	var calm: Variant = Settings.get_value("reduce_flashes")
	Settings.set_value("reduce_flashes", false)
	game.player.invuln = 0.0
	game.player.take_damage(1.0, &"test")
	_check.call(game.player._fx.hurt_active(), "guardiã: golpe recebido liga o tremor")
	Events.player_leveled.emit(2)
	_check.call(game.player._fx.level_active(), "guardiã: nível novo acende a coluna de luz")
	Settings.set_value("reduce_flashes", calm)
	# Chefe: painel, pose e morte épica.
	game.bosses.spawn(&"red_oni")
	var panel := game.hud.boss_panel()
	_check.call(panel.visible and panel.intro_active() and panel.kanji == "赤鬼",
			"chefe: entrada mostra a faixa com o kanji")
	_check.call(panel.marks.size() == 1 and is_equal_approx(panel.marks[0], 0.3), "chefe: barra marca a fúria em 30%")
	var i := int(game.bosses.bosses[0]["index"])
	GameClock.paused = true
	for _t: int in range(10):
		GameClock.game_time += GameClock.STEP
		game._on_tick(GameClock.STEP)
	enemies.damage(i, enemies.max_hp[i] * 0.8, Vector2.ZERO, 0.0)
	GameClock.game_time += GameClock.STEP
	game._on_tick(GameClock.STEP)
	_check.call(bool(game.bosses.bosses[0]["enraged"]) and panel.enraged, "chefe: fúria chega ao painel")
	enemies.damage(i, 1e9, Vector2.ZERO, 0.0)
	GameClock.game_time += GameClock.STEP
	game._on_tick(GameClock.STEP)
	_check.call(game.bosses.fx.deaths_active() == 1, "chefe: morte épica começa")
	_check.call(enemies.fx.time_scale < 1.0, "chefe: câmera lenta só dos efeitos")
	_check.call(panel.fraction < 0.0, "chefe: barra some na morte")
	GameClock.paused = false
	await _host.get_tree().create_timer(2.8).timeout
	_check.call(game.bosses.fx.deaths_active() == 0 and enemies.fx.time_scale == 1.0,
			"chefe: sequência da morte termina e o tempo dos efeitos volta")
	game.queue_free()
	await _host.get_tree().process_frame
