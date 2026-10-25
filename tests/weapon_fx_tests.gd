extends RefCounted
## Efeitos das armas e do golpe da lanterna (scripts/systems/fx_layer.gd, projectile_manager.gd,
## area_effects.gd, ultimate_system.gd, scripts/core/weapon_style.gd):
## - cota de partículas por nível (Baixa/Média/Alta) e troca ao vivo pelo Settings.changed;
## - rastro dos projéteis só na Média/Alta, brilho e distorção só na Alta, com teto;
## - cada arma tem cor de efeito e tipo de impacto válidos, e o impacto solta partículas;
## - o golpe da lanterna abre o momento cinematográfico, desacelera só os efeitos e termina;
## - determinismo: a mesma partida (mesma semente, várias armas) dá o mesmo estado na Baixa e
##   na Alta.
## Chamado por tests/integration_tests.gd, que passa o nó da cena e o _check.

const GAME_SCENE := "res://scenes/game/Game.tscn"
const KEY := "graphics_quality"
## Arsenal da prova de determinismo: projéteis, áreas, raios, órbitas e lâminas.
const ARSENAL: Array[StringName] = [&"shuriken", &"kunai", &"yumi", &"raijin_fury", &"ofuda", &"kaminari",
		&"taiko", &"kusarigama", &"hitodama", &"poison_mist", &"inazuma", &"fujin_hurricane"]
const DET_STEPS := 900


func run(host: Node, check: Callable) -> void:
	_check_styles(check)
	var game := await _new_game(host, 13)
	_check_budgets(game, check)
	_check_live_switch(game, check)
	_check_projectile_fx(game, check)
	_check_waves(game, check)
	_check_impacts(game, check)
	_check_cinematic(game, check)
	game.queue_free()
	await host.get_tree().process_frame
	await _check_determinism(host, check)
	GfxQuality.clear_override()
	FxLayer.refresh_quality()
	GameClock.paused = false


func _new_game(host: Node, seed_value: int) -> HyakkiGame:
	var scene := load(GAME_SCENE) as PackedScene
	var game := scene.instantiate() as HyakkiGame
	game.config = {"hero": "aki", "stage": "bamboo", "moon": 0, "mode": "normal", "seed": seed_value, "speed": 1}
	host.add_child(game)
	await host.get_tree().process_frame
	game.player.god_mode = true
	return game


func _set_level(game: HyakkiGame, level: int) -> void:
	GfxQuality.set_override(level)
	Settings.changed.emit(KEY)
	game.fx.reset()


func _check_styles(check: Callable) -> void:
	for id: StringName in DB.ids("weapons"):
		var data := DB.weapon(id)
		var style := WeaponStyle.of(data)
		check.call(data.has("fx") and (data["fx"] as Dictionary).has("color"), "%s tem cor de efeito" % id)
		check.call(HitSounds.MIX.has(String(style["impact"])), "%s tem tipo de impacto válido" % id)
		check.call((style["color"] as Color).a > 0.0, "%s: cor de efeito visível" % id)
	# Evolução diferente da base (cor própria, mais forte).
	for id: StringName in DB.ids("weapons"):
		var data := DB.weapon(id)
		if String(data.get("kind", "")) == "evolution":
			var base := DB.weapon(StringName(data.get("from", "")))
			check.call(WeaponStyle.of(data)["color"] != WeaponStyle.of(base)["color"],
					"%s tem cor própria, diferente da base" % id)
	check.call(WeaponStyle.of({})["impact"] == "hit", "arma vazia: impacto genérico")


## Cota de partículas, rastros, brilho e detalhe por nível.
func _check_budgets(game: HyakkiGame, check: Callable) -> void:
	var fx := game.fx
	for level: int in [GfxQuality.LOW, GfxQuality.MEDIUM, GfxQuality.HIGH]:
		_set_level(game, level)
		var cap := int(GfxQuality.budget_at("particles_max", level))
		check.call(FxLayer.particles_max == cap, "nível %d: cota de partículas %d" % [level, cap])
		check.call(FxLayer.trail_points == int(GfxQuality.budget_at("trail_points", level)),
				"nível %d: pontos de rastro do orçamento" % level)
		check.call(FxLayer.glow == bool(GfxQuality.budget_at("glow", level)), "nível %d: brilho do orçamento" % level)
		check.call(FxLayer.wfx == int(GfxQuality.budget_at("weapon_fx", level)), "nível %d: detalhe das armas" % level)
		for _k: int in range(400):
			fx.sparks(Vector2.ZERO, Vector2.RIGHT, Color.WHITE, 8)
		var alive := fx.particles_alive()
		check.call(alive <= cap and alive >= cap - 8, "nível %d: partículas no teto (%d de %d)" % [level, alive, cap])


## Troca ao vivo: Alta cheia → Baixa apaga o excesso, o brilho e as distorções.
func _check_live_switch(game: HyakkiGame, check: Callable) -> void:
	var fx := game.fx
	_set_level(game, GfxQuality.HIGH)
	for _k: int in range(300):
		fx.embers(Vector2.ZERO, Color.WHITE, 8)
	fx.shockwave(Vector2.ZERO, 60.0, Color.WHITE)
	check.call(fx.particles_alive() > 1000 and fx.waves_alive() == 1, "Alta: muitas partículas e uma onda")
	GfxQuality.set_override(GfxQuality.LOW)
	Settings.changed.emit(KEY)
	var low_cap := int(GfxQuality.budget_at("particles_max", GfxQuality.LOW))
	check.call(fx.particles_alive() <= low_cap, "troca ao vivo para Baixa corta as partículas (%d)" % fx.particles_alive())
	check.call(fx.waves_alive() == 0 and not FxLayer.glow, "troca ao vivo para Baixa apaga brilho e distorção")
	fx.shockwave(Vector2.ZERO, 60.0, Color.WHITE)
	check.call(fx.waves_alive() == 0, "Baixa: onda de choque sem distorção")
	GfxQuality.set_override(GfxQuality.HIGH)
	Settings.changed.emit(KEY)
	check.call(FxLayer.glow and FxLayer.trail_points > 0, "troca ao vivo de volta para Alta religa brilho e rastro")


## Rastro do projétil: nenhum na Baixa, curto na Média, longo na Alta; nunca passa do teto.
func _check_projectile_fx(game: HyakkiGame, check: Callable) -> void:
	var pm := game.projectiles
	for level: int in [GfxQuality.LOW, GfxQuality.MEDIUM, GfxQuality.HIGH]:
		_set_level(game, level)
		pm.reset()
		var i := pm.spawn(&"shuriken", "shuriken", game.player.sim_pos + Vector2(0, -200), Vector2(0, -60),
				1.0, 2.0, -1, 5.0)
		for _k: int in range(30):
			pm.step(GameClock.STEP)
		var n := int((pm.get("_trail_n") as PackedInt32Array)[i])
		if level == GfxQuality.LOW:
			check.call(n == 0, "Baixa: projétil sem rastro")
		else:
			check.call(n >= FxLayer.trail_points and n <= ProjectileManager.TRAIL_MAX,
					"nível %d: projétil com rastro (%d pontos)" % [level, n])
	pm.reset()
	check.call(ProjectileManager.KINDS.has("steel_shuriken") and ProjectileManager.KINDS.has("reaper_hook"),
			"evoluções com projétil próprio (Tempestade de Aço, Corrente do Ceifador)")


func _check_waves(game: HyakkiGame, check: Callable) -> void:
	_set_level(game, GfxQuality.HIGH)
	var fx := game.fx
	for _k: int in range(FxLayer.MAX_WAVES + 4):
		fx.shockwave(Vector2.ZERO, 40.0, Color.WHITE)
	check.call(fx.waves_alive() == FxLayer.MAX_WAVES, "distorções ficam no teto (%d)" % fx.waves_alive())
	fx.step(1.0)
	check.call(fx.waves_alive() == 0, "distorções somem")
	for _k: int in range(FxLayer.FLASHES_PER_STEP + 10):
		fx.flash(Vector2.ZERO, 10.0, Color.WHITE)
	check.call((fx.get("_flashes") as Array).size() == FxLayer.FLASHES_PER_STEP, "clarões por passo têm teto")


## Todo tipo de impacto solta partículas em todos os níveis (na Baixa, poucas).
func _check_impacts(game: HyakkiGame, check: Callable) -> void:
	var fx := game.fx
	for level: int in [GfxQuality.LOW, GfxQuality.HIGH]:
		_set_level(game, level)
		var low_total := 0
		for id: StringName in DB.ids("weapons"):
			fx.reset()
			fx.impact(id, Vector2.ZERO, Vector2.RIGHT)
			var n := fx.particles_alive()
			check.call(n >= 1, "nível %d: impacto de %s solta partículas (%d)" % [level, id, n])
			low_total += n
		if level == GfxQuality.LOW:
			check.call(low_total <= DB.ids("weapons").size() * 2, "Baixa: impactos com partículas mínimas")
	fx.reset()


func _check_cinematic(game: HyakkiGame, check: Callable) -> void:
	_set_level(game, GfxQuality.HIGH)
	var fx := game.fx
	game.ultimate.fill()
	var before := int(AudioManager.request_count.get("ult_burst", 0))
	WeaponSfx.reset_gaps()
	check.call(game.ultimate.activate(), "golpe da lanterna ativa")
	check.call(fx.cinematic_active(), "golpe da lanterna abre o momento cinematográfico")
	check.call(int(AudioManager.request_count.get("ult_burst", 0)) == before + 1, "golpe da lanterna toca o impacto")
	check.call(fx.waves_alive() >= 1, "Alta: golpe da lanterna distorce a tela")
	fx.step(GameClock.STEP)
	check.call(fx.time_scale < 1.0, "câmera lenta só dos efeitos")
	for _k: int in range(120):
		fx.step(GameClock.STEP)
	check.call(not fx.cinematic_active() and is_equal_approx(fx.time_scale, 1.0), "o momento cinematográfico termina")


## Mesma semente e mesmo arsenal: estado idêntico na Baixa e na Alta (efeitos não mexem na
## simulação).
func _check_determinism(host: Node, check: Callable) -> void:
	var hashes: Array[String] = []
	for level: int in [GfxQuality.LOW, GfxQuality.HIGH]:
		GfxQuality.set_override(level)
		FxLayer.refresh_quality()
		var game := await _new_game(host, 77)
		GameClock.paused = true
		for id: StringName in ARSENAL:
			game.add_weapon(id)
		for weapon: Weapon in game.weapons:
			while weapon.level < weapon.max_level:
				weapon.level_up()
		for _k: int in range(DET_STEPS):
			GameClock.game_time += GameClock.STEP
			game._on_tick(GameClock.STEP)
		hashes.append(game.state_summary("DET"))
		game.queue_free()
		await host.get_tree().process_frame
	GameClock.paused = false
	check.call(hashes[0] == hashes[1], "mesmo estado na Baixa e na Alta com %d armas" % ARSENAL.size())
