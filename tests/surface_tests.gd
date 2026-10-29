extends RefCounted
## Superfícies lentas (data/surfaces.json, SurfaceField + SurfaceSystem), para guardiã, inimigo
## comum, elite e chefe, em cada tipo (lama, barro, pântano, óleo, piche, areia movediça):
##   (a) a velocidade fica reduzida enquanto o ator está sobre o solo;
##   (b) ao sair, sobe de forma monotônica e chega a EXATAMENTE 1.0 dentro do ease_out do tipo;
##   (c) depois fica em 1.0 por muitos passos;
##   (d) entrar e sair várias vezes não acumula lentidão;
##   (e) dois tipos em sequência: usa o tipo atual e depois recupera até 1.0.
## E ainda: entrada suave (ease_in), recuperação longa do piche, deslize do óleo, chefe grande
## resiste um pouco mas perde algo, posição determinística, zona segura do nascimento, limites
## da fase e o mesmo hash da partida em Baixa e Alta.
## Chamado por tests/integration_tests.gd.

const GAME_SCENE := "res://scenes/game/Game.tscn"
const STEP := 1.0 / 60.0
## Fase de cada tipo nos testes com atores.
const STAGE_OF := {"mud": "village", "clay": "village", "swamp": "bamboo", "oil": "temple",
		"quicksand": "dunes", "tar": "yomi"}
const ACTORS: Array[String] = ["player", "enemy", "elite", "boss"]

var _host: Node
var _check: Callable


func run(host: Node, check: Callable) -> void:
	_host = host
	_check = check
	_test_data()
	_test_placement()
	_test_caches()
	var game := (load(GAME_SCENE) as PackedScene).instantiate() as HyakkiGame
	game.config = {"hero": "aki", "stage": "village", "moon": 0, "mode": "normal", "seed": 5, "speed": 1}
	_host.add_child(game)
	await _host.get_tree().process_frame
	game.player.god_mode = true
	GameClock.paused = true
	for type_name: String in STAGE_OF:
		_restart(game, STAGE_OF[type_name])
		for actor: String in ACTORS:
			_test_actor(game, type_name, actor)
	_restart(game, "village")
	for actor: String in ACTORS:
		_test_sequence(game, actor)
	_test_oil_slide(game)
	_test_speed_integration(game)
	_test_model_fast_path(game)
	game.queue_free()
	await _host.get_tree().process_frame
	await _test_hash_low_high()
	GameClock.paused = false


func _test_data() -> void:
	var d := SurfaceField.data()
	var types: Dictionary = d.get("types", {})
	for name: String in ["mud", "clay", "swamp", "oil", "tar", "quicksand"]:
		_check.call(types.has(name), "solo: tipo %s existe" % name)
		var p: Dictionary = types.get(name, {})
		_check.call(float(p.get("slow", 1.0)) < 1.0 and float(p.get("ease_in", 0)) > 0.0
				and float(p.get("ease_out", 0)) > 0.0, "solo: %s tem slow < 1, ease_in e ease_out" % name)
	_check.call(float(types["tar"]["ease_out"]) >= float(types["mud"]["ease_out"]), "solo: piche recupera mais devagar")
	_check.call(float(types["oil"]["accel"]) < 1.0, "solo: óleo escorrega (accel < 1)")
	for id: StringName in DB.ids("stages"):
		_check.call((d.get("stages", {}) as Dictionary).has(String(id)), "solo: fase %s tem superfícies" % id)


## Posição determinística, zona segura do nascimento e limites (Templo e Yomi).
func _test_placement() -> void:
	var a := SurfaceField.new("village", 77)
	var b := SurfaceField.new("village", 77)
	var c := SurfaceField.new("village", 78)
	var same := true
	var differs := false
	for cy: int in range(-4, 5):
		for cx: int in range(-4, 5):
			var k := Vector2i(cx, cy)
			same = same and str(a.patches(k)) == str(b.patches(k))
			differs = differs or str(a.patches(k)) != str(c.patches(k))
	_check.call(same, "solo: mesma semente → mesmas manchas")
	_check.call(differs, "solo: outra semente → outras manchas")
	for stage_id: String in ["village", "bamboo", "temple", "dunes", "yomi", "secret"]:
		var stage := DB.stage(StringName(stage_id))
		var bb: Array = stage.get("bounds", [])
		var bounds := Vector2(float(bb[0]), float(bb[1])) if bb.size() == 2 else Vector2.ZERO
		var safe_ok := true
		var bounds_ok := true
		var count := 0
		for s: int in range(1, 6):
			var f := SurfaceField.new(stage_id, s * 101, WeatherModel.new(stage_id, s * 101, {}, WeatherModel.State.STORM),
					bounds)
			for cy: int in range(-3, 3):
				for cx: int in range(-3, 3):
					for p: Dictionary in f.patches(Vector2i(cx, cy)):
						count += 1
						var center: Vector2 = p["center"]
						safe_ok = safe_ok and center.length() >= f.safe_radius + float(p["bound"])
						if bounds.y > 0.0:
							bounds_ok = bounds_ok and absf(center.y) + float(p["bound"]) < bounds.y
						if bounds.x > 0.0:
							bounds_ok = bounds_ok and absf(center.x) + float(p["bound"]) < bounds.x
			for k: int in range(72):
				var at := Vector2.from_angle(TAU * k / 72.0) * (f.safe_radius - 1.0) * (0.3 + 0.7 * (k % 3) / 2.0)
				safe_ok = safe_ok and f.type_at(at, 300.0) < 0
		_check.call(count > 0, "solo: %s tem manchas (%d)" % [stage_id, count])
		_check.call(safe_ok, "solo: %s sem superfície na zona do nascimento" % stage_id)
		_check.call(bounds_ok, "solo: %s com manchas dentro dos limites da fase" % stage_id)


## Caches do passo (desempenho) dão o mesmo resultado bit a bit que a regra sem cache:
## lama por tempo (trocar o tempo invalida), parâmetros por tipo em arrays e advance sem Array.
func _test_caches() -> void:
	var cached := WeatherModel.new("village", 31)
	var times: Array[float] = [120.0, 120.0, 340.5, 120.0, 900.25, 900.25, 0.0]
	var mud_ok := true
	for t: float in times:
		var fresh := WeatherModel.new("village", 31)
		var ref := clampf(inverse_lerp(float(fresh.profile.get("mud_from", 0.3)),
				float(fresh.profile.get("mud_full", 0.85)), fresh.wetness_at(t)), 0.0, 1.0)
		mud_ok = mud_ok and cached.mud_level_at(t) == ref
	_check.call(mud_ok, "solo: cache da lama por tempo igual à conta sem cache (e invalida ao mudar t)")
	var f := SurfaceField.new("village", 31, WeatherModel.new("village", 31, {}, WeatherModel.State.STORM))
	var arrays_ok := true
	for t: int in range(f.types.size()):
		var p: Dictionary = f.types[t]
		arrays_ok = arrays_ok and f.slow_by_type[t] == float(p.get("slow", 1.0)) \
				and f.ease_in_by_type[t] == float(p.get("ease_in", 0.25)) \
				and f.ease_out_by_type[t] == float(p.get("ease_out", 0.4)) \
				and f.accel_by_type[t] == float(p.get("accel", 1.0)) \
				and (f.resist_by_type[t] == 1) == bool(p.get("resist_by_size", false))
	_check.call(arrays_ok and f.types.size() > 0, "solo: parâmetros por tipo em arrays iguais aos do JSON")
	var s := SurfaceSystem.new()
	s.field = f
	var rule_ok := true
	for t: int in range(f.types.size()):
		for radius: float in [8.0, 14.0, 40.0, 90.0]:
			var m := 1.0
			var remembered := -1
			var ref_m := 1.0
			var ref_rem := -1
			# Entra 40 passos, sai 60 (recuperação até 1.0 e o tipo esquecido).
			for k: int in range(100):
				var here := t if k < 40 else -1
				var arr := s.advance(m, remembered, here, radius, STEP)
				var r := _reference_advance(f, ref_m, ref_rem, here, radius, STEP)
				ref_m = r[0]
				ref_rem = r[1]
				var next := s.advance_mult(m, remembered, here, radius, STEP)
				remembered = s.next_type(next, remembered, here)
				m = next
				rule_ok = rule_ok and m == ref_m and remembered == ref_rem and float(arr[0]) == ref_m \
						and int(arr[1]) == ref_rem \
						and s.accel_for(m, remembered, radius) == _reference_accel(f, ref_m, ref_rem, radius)
	s.free()
	_check.call(rule_ok, "solo: advance_mult/next_type/accel_for iguais bit a bit à regra com Dictionary")


## A regra antiga (Array e Dictionary a cada passo), só para comparar nos testes.
func _reference_slow(f: SurfaceField, type: int, radius: float) -> float:
	var slow := float(f.types[type].get("slow", 1.0))
	if bool(f.types[type].get("resist_by_size", false)):
		var resist := clampf((radius - 10.0) / 60.0, 0.0, 0.3)
		slow = 1.0 - (1.0 - slow) * (1.0 - resist)
	return slow


func _reference_recover(f: SurfaceField, m: float, target: float, type: int, radius: float, dt: float) -> float:
	var depth := maxf(1.0 - _reference_slow(f, type, radius), SurfaceSystem.EPS * 2.0)
	var k := log(depth / SurfaceSystem.EPS) / maxf(float(f.types[type].get("ease_out", 0.4)), 0.01)
	m = target - (target - m) * exp(-k * dt)
	if absf(target - m) < SurfaceSystem.EPS * 1.5:
		m = target
	return m


func _reference_advance(f: SurfaceField, m: float, remembered: int, here: int, radius: float, dt: float) -> Array:
	if here >= 0:
		var target := _reference_slow(f, here, radius)
		if m > target:
			m = move_toward(m, target, (1.0 - target) / maxf(float(f.types[here].get("ease_in", 0.25)), 0.01) * dt)
		else:
			m = _reference_recover(f, m, target, here, radius, dt)
		return [m, here]
	if remembered < 0 or m >= 1.0:
		return [1.0, -1]
	m = _reference_recover(f, m, 1.0, remembered, radius, dt)
	return [m, remembered if m < 1.0 else -1]


func _reference_accel(f: SurfaceField, m: float, type: int, radius: float) -> float:
	if type < 0 or m >= 1.0:
		return 1.0
	var depth := clampf((1.0 - m) / maxf(1.0 - _reference_slow(f, type, radius), SurfaceSystem.EPS), 0.0, 1.0)
	return lerpf(1.0, float(f.types[type].get("accel", 1.0)), depth)


## Caminho rápido do WeatherSystem.ensure_model: mesmo modelo enquanto a chave não muda; refaz
## ao trocar o estado forçado, a semente ou a instância de game.stage (Kakuriyo).
func _test_model_fast_path(game: HyakkiGame) -> void:
	_restart(game, "village")
	var weather := WeatherSystem.of(game)
	var first := weather.ensure_model()
	_check.call(weather.ensure_model() == first, "solo: ensure_model reaproveita o modelo com a mesma chave")
	weather.force_state("drizzle")
	var drizzle := weather.ensure_model()
	_check.call(drizzle != first and drizzle.forced == WeatherModel.State.DRIZZLE,
			"solo: ensure_model refaz ao trocar o estado forçado")
	var old_seed := game.world.seed_value
	game.world.seed_value = old_seed + 1
	var reseeded := weather.ensure_model()
	_check.call(reseeded != drizzle and reseeded.seed_value == old_seed + 1,
			"solo: ensure_model refaz ao trocar a semente")
	game.world.seed_value = old_seed
	weather.ensure_model()
	var old_stage := game.stage
	var other := DB.stage(&"dunes")
	game.stage = other
	var dunes := weather.ensure_model()
	_check.call(dunes.stage_id == String(other.get("weather", other.get("id", "")))
			and weather.surfaces.field.weather == dunes,
			"solo: ensure_model refaz ao trocar a fase (instância de game.stage)")
	game.stage = old_stage
	weather.force_state("")
	_check.call(weather.ensure_model().stage_id == String(old_stage.get("weather", old_stage.get("id", ""))),
			"solo: ensure_model volta à fase original")


func _restart(game: HyakkiGame, stage_id: String) -> void:
	game.start_run({"hero": "aki", "stage": stage_id, "moon": 0, "mode": "normal", "seed": 5, "speed": 1})
	GameClock.paused = true
	game.player.god_mode = true
	game.enemies.reset()
	var weather := WeatherSystem.of(game)
	weather.force_state("storm")
	GameClock.game_time = 200.0


## Um ponto dentro de uma mancha do tipo e um ponto fora de qualquer superfície.
func _spot(game: HyakkiGame, type_name: String) -> Array:
	var surfaces := SurfaceSystem.of(game)
	var f := surfaces.field
	var t := f.type_index(type_name)
	for r: int in range(0, 6):
		for cy: int in range(-r, r + 1):
			for cx: int in range(-r, r + 1):
				for p: Dictionary in f.patches(Vector2i(cx, cy)):
					var center: Vector2 = p["center"]
					if int(p["type"]) == t and f.type_at(center, GameClock.game_time) == t:
						var out := center + Vector2(0, 70)
						while f.type_at(out, GameClock.game_time) >= 0:
							out += Vector2(0, 25)
						return [center, out, t]
	return []


## Passo fixo de um ator parado em `at`; devolve o multiplicador depois do passo.
func _step_actor(game: HyakkiGame, actor: String, index: int, at: Vector2) -> float:
	var surfaces := SurfaceSystem.of(game)
	game.step_index += 1
	match actor:
		"player":
			game.player.sim_pos = at
			game.player.move_input = Vector2.ZERO
			game.player.step(STEP)
			return surfaces.player_mult
		"boss":
			game.enemies.pos[index] = at
			return SurfaceSystem.boss_mult(game, index)
	game.enemies.pos[index] = at
	game.enemies.vel[index] = Vector2.ZERO
	game.player.sim_pos = at + Vector2(60, 0)
	game.enemies.step(STEP)
	return surfaces.enemy_mult(index)


func _spawn(game: HyakkiGame, actor: String, at: Vector2) -> int:
	match actor:
		"enemy":
			return game.enemies.spawn(&"slime_rice", at, 1000.0, 0.0)
		"elite":
			return game.enemies.spawn(&"skeleton_peasant", at, 1000.0, 0.0, true)
		"boss":
			return game.enemies.spawn(&"tanuki", at, 1000.0, 0.0)
	return -1


func _test_actor(game: HyakkiGame, type_name: String, actor: String) -> void:
	var spot := _spot(game, type_name)
	var label := "solo %s/%s" % [type_name, actor]
	_check.call(not spot.is_empty(), "%s: achou mancha do tipo" % label)
	if spot.is_empty():
		return
	var inside: Vector2 = spot[0]
	var outside: Vector2 = spot[1]
	var surfaces := SurfaceSystem.of(game)
	game.enemies.reset()
	surfaces.reset()
	var index := _spawn(game, actor, outside)
	if actor != "player":
		_check.call(index >= 0, "%s: ator nasceu" % label)
		if index < 0:
			return
	var p: Dictionary = surfaces.field.types[int(spot[2])]
	var radius := Player.RADIUS if actor == "player" else game.enemies.radius[index]
	var target := surfaces.slow_for(int(spot[2]), radius)
	var first := _step_actor(game, actor, index, inside)
	_check.call(first < 1.0 and first > target, "%s: entrada suave (1º passo %.3f, alvo %.3f)" % [label, first, target])
	var in_steps := int(ceil(float(p["ease_in"]) / STEP)) + 6
	var m := first
	for _k: int in range(in_steps):
		m = _step_actor(game, actor, index, inside)
	_check.call(is_equal_approx(m, target) and m < 1.0, "%s: (a) reduzida dentro (%.3f)" % [label, m])
	if actor == "boss":
		_check.call(target < 1.0 and target >= surfaces.field.slow_of(int(spot[2])),
				"%s: chefe sempre perde velocidade (%.3f; base %.3f)" % [label, target, surfaces.field.slow_of(int(spot[2]))])
	var out_steps := int(ceil(float(p["ease_out"]) / STEP)) + 1
	var mono := true
	var prev := m
	var reached := -1
	for k: int in range(out_steps):
		var v := _step_actor(game, actor, index, outside)
		mono = mono and v >= prev
		prev = v
		if v == 1.0 and reached < 0:
			reached = k + 1
	_check.call(mono and reached > 0,
			"%s: (b) recupera monotônica até 1.0 em %d passos (limite %d)" % [label, reached, out_steps])
	if type_name == "tar":
		_check.call(reached * STEP > 0.45, "%s: piche segura a recuperação mais tempo (%.2f s)" % [label, reached * STEP])
	var stays := true
	for _k: int in range(300):
		stays = stays and _step_actor(game, actor, index, outside) == 1.0
	_check.call(stays, "%s: (c) fica em exatamente 1.0 por 300 passos" % label)
	# (d) entra e sai várias vezes: nunca abaixo do alvo, e no fim volta a 1.0.
	var lowest := 1.0
	for cycle: int in range(6):
		for _k: int in range(10 + cycle * 3):
			lowest = minf(lowest, _step_actor(game, actor, index, inside))
		for _k: int in range(8):
			lowest = minf(lowest, _step_actor(game, actor, index, outside))
	var final := 0.0
	for _k: int in range(out_steps):
		final = _step_actor(game, actor, index, outside)
	_check.call(lowest >= target - 0.0001 and final == 1.0,
			"%s: (d) entrar/sair não acumula (mínimo %.3f, alvo %.3f, fim %.3f)" % [label, lowest, target, final])
	game.enemies.reset()


## (e) lama e depois barro (vila): usa o tipo atual e depois recupera até 1.0.
func _test_sequence(game: HyakkiGame, actor: String) -> void:
	var mud := _spot(game, "mud")
	var clay := _spot(game, "clay")
	if mud.is_empty() or clay.is_empty():
		_check.call(false, "solo seq/%s: lama e barro na vila" % actor)
		return
	var surfaces := SurfaceSystem.of(game)
	game.enemies.reset()
	surfaces.reset()
	var index := _spawn(game, actor, mud[1])
	var radius := Player.RADIUS if actor == "player" else game.enemies.radius[index]
	for _k: int in range(60):
		_step_actor(game, actor, index, mud[0])
	var m := 0.0
	for _k: int in range(90):
		m = _step_actor(game, actor, index, clay[0])
	var clay_target := surfaces.slow_for(int(clay[2]), radius)
	_check.call(is_equal_approx(m, clay_target), "solo seq/%s: (e) no barro vale o barro (%.3f)" % [actor, m])
	var steps := int(ceil(float(surfaces.field.types[int(clay[2])]["ease_out"]) / STEP)) + 1
	for _k: int in range(steps):
		m = _step_actor(game, actor, index, clay[1])
	_check.call(m == 1.0, "solo seq/%s: (e) depois recupera até 1.0" % actor)
	game.enemies.reset()


## Óleo: aceleração/frenagem menores sobre ele; ao sair, volta a 1.0 junto com a velocidade.
func _test_oil_slide(game: HyakkiGame) -> void:
	_restart(game, "temple")
	var spot := _spot(game, "oil")
	if spot.is_empty():
		_check.call(false, "solo óleo: mancha no templo")
		return
	var surfaces := SurfaceSystem.of(game)
	surfaces.reset()
	var player := game.player
	for _k: int in range(30):
		_step_actor(game, "player", -1, spot[0])
	_check.call(surfaces.player_accel() < 0.5, "solo óleo: aceleração cai (%.2f)" % surfaces.player_accel())
	var gain_in := _first_gain(game, spot[0])
	for _k: int in range(60):
		_step_actor(game, "player", -1, spot[1])
	_check.call(surfaces.player_accel() == 1.0 and surfaces.player_mult == 1.0, "solo óleo: deslize acaba ao recuperar")
	var gain_out := _first_gain(game, spot[1])
	_check.call(gain_in < gain_out * 0.5,
			"solo óleo: escorrega (ganho %.1f vs %.1f px/s no 1º passo)" % [gain_in, gain_out])
	player.velocity = Vector2.ZERO


func _first_gain(game: HyakkiGame, at: Vector2) -> float:
	var player := game.player
	player.sim_pos = at
	player.velocity = Vector2.ZERO
	player.move_input = Vector2.RIGHT
	game.step_index += 1
	player.step(STEP)
	var v := player.velocity.length()
	player.move_input = Vector2.ZERO
	player.velocity = Vector2.ZERO
	game.step_index += 1
	player.sim_pos = at
	player.step(STEP)
	return v


## A lentidão chega mesmo na velocidade: herói, inimigo (EnemyManager) e chefe (BossDirector).
func _test_speed_integration(game: HyakkiGame) -> void:
	_restart(game, "yomi")
	var spot := _spot(game, "tar")
	if spot.is_empty():
		return
	var surfaces := SurfaceSystem.of(game)
	surfaces.reset()
	var player := game.player
	var top := player.stats.get_stat("speed")
	for _k: int in range(60):
		_step_actor(game, "player", -1, spot[0])
	# Andando para a direita dentro do piche até a velocidade assentar.
	player.move_input = Vector2.RIGHT
	for _k: int in range(90):
		game.step_index += 1
		player.sim_pos = spot[0]
		player.step(STEP)
	_check.call(player.velocity.length() < top * 0.75, "solo: herói no piche anda mais devagar (%.1f de %.1f)" % [
			player.velocity.length(), top])
	player.move_input = Vector2.ZERO
	var boss := game.enemies.spawn(&"tanuki", spot[0], 1000.0, 0.0)
	if boss >= 0:
		var data: Dictionary = DB.bosses[&"tanuki"]
		var fake := {"data": data, "enraged": false, "index": boss}
		var slowed := 0.0
		for _k: int in range(60):
			game.step_index += 1
			slowed = game.bosses._speed(fake)
		_check.call(slowed < float(data.get("speed", 30)) * game.enemies.speed_mult * 0.9,
				"solo: BossDirector usa a lentidão no chefe (%.1f)" % slowed)
	game.enemies.reset()


## Mesmo hash da partida (com a parte "solo=") em Baixa e Alta, com o herói passando pela lama.
func _test_hash_low_high() -> void:
	var hashes: Array[String] = []
	var summaries: Array[String] = []
	for lv: int in [GfxQuality.LOW, GfxQuality.HIGH]:
		GfxQuality.set_override(lv)
		var game := (load(GAME_SCENE) as PackedScene).instantiate() as HyakkiGame
		game.config = {"hero": "aki", "stage": "village", "moon": 0, "mode": "normal", "seed": 9, "speed": 1}
		_host.add_child(game)
		await _host.get_tree().process_frame
		GameClock.paused = true
		game.player.god_mode = true
		WeatherSystem.of(game).force_state("storm")
		GameClock.game_time = 0.0
		var spot := _spot(game, "mud")
		if not spot.is_empty():
			game.player.sim_pos = (spot[0] as Vector2) - Vector2(30, 0)
		for _k: int in range(240):
			game.player.move_input = Vector2.RIGHT
			GameClock.game_time += STEP
			GameClock.ticked.emit(STEP)
		var summary := game.state_summary("H")
		hashes.append(summary.get_slice("hash=", 1))
		summaries.append(summary)
		_check.call(summary.contains("solo="), "solo: hash da partida inclui as superfícies (%s)" % summary.right(40))
		game.queue_free()
		await _host.get_tree().process_frame
	GfxQuality.clear_override()
	_check.call(hashes.size() == 2 and hashes[0] == hashes[1], "solo: hash igual em Baixa e Alta (%s)" % [summaries])
