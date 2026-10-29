extends RefCounted
## Densidade adaptativa dos números de dano (DamagePalette: raw_pressure, next_pressure,
## next_level, number_size, level_life, should_fold, insignificant, abbreviate; DamageNumbers):
##   - pressão: cresce com inimigos e números por segundo, sobe rápido e desce devagar, nível com
##     histerese (não pisca perto do limite);
##   - tamanho e vida: não crescem com o nível, comum vira dígitos 3×5, crítico e recebido não
##     encolhem nem encurtam, nada abaixo do legível;
##   - juntar perto e parecido (×N): só com pressão, só mesmo tipo, perto e de valor parecido;
##     nunca crítico, recebido nem cura;
##   - golpes pequenos somem só com pressão alta; crítico e recebido nunca;
##   - abreviação 12,3k / 1,2M com a vírgula do idioma;
##   - começo de partida (poucos inimigos) igual a antes;
##   - estresse de 500 inimigos: cobertura da tela e números vivos abaixo do alvo, críticos ainda
##     visíveis, e menos cobertura que sem a densidade adaptativa.
## run_unit() roda sem autoloads (tests/run_tests.gd); run() precisa da árvore.

const K := DamagePalette.Kind
const GAME_SCENE := "res://scenes/game/Game.tscn"
const STEP := 1.0 / 60.0
## Alvo de cobertura da tela (soma das caixas dos números / área visível) no fim de partida.
const COVERAGE_MAX := 0.05

var _check: Callable
var _host: Node


func run_unit(check: Callable) -> void:
	_check = check
	_test_pressure()
	_test_levels()
	_test_size_life()
	_test_fold_rule()
	_test_significance_rule()
	_test_abbreviation()


func _test_pressure() -> void:
	_check.call(DamagePalette.raw_pressure(20, 5.0) == 0.0, "pressão: começo de partida é zero")
	_check.call(DamagePalette.raw_pressure(500, 0.0) == 1.0, "pressão: 500 inimigos é o máximo")
	_check.call(DamagePalette.raw_pressure(0, 200.0) == 1.0, "pressão: chuva de números também conta")
	var up := true
	for e: int in range(0, 600, 20):
		up = up and DamagePalette.raw_pressure(e + 20, 0.0) >= DamagePalette.raw_pressure(e, 0.0)
	for r: int in range(0, 150, 5):
		up = up and DamagePalette.raw_pressure(0, r + 5.0) >= DamagePalette.raw_pressure(0, float(r))
	_check.call(up, "pressão: cresce com inimigos e com números por segundo")
	var rise := DamagePalette.next_pressure(0.0, 1.0, 0.1)
	var fall := 1.0 - DamagePalette.next_pressure(1.0, 0.0, 0.1)
	_check.call(rise > fall * 2.0, "pressão: sobe rápido e desce devagar (%.2f × %.2f)" % [rise, fall])


func _test_levels() -> void:
	var levels: Array[int] = []
	var level := 0
	var p := 0.0
	while p <= 1.0:
		var next := DamagePalette.next_level(p, level)
		if next != level:
			levels.append(next)
		level = next
		p += 0.01
	_check.call(levels == [1, 2], "nível: sobe 0 → 1 → 2 com a pressão (%s)" % [levels])
	var down: Array[float] = []
	while p >= 0.0:
		var next := DamagePalette.next_level(p, level)
		if next != level:
			down.append(snappedf(p, 0.01))
		level = next
		p -= 0.01
	_check.call(level == 0 and down.size() == 2 and down[0] < DamagePalette.LEVEL_UP[1]
			and down[1] < DamagePalette.LEVEL_UP[0], "nível: desce mais baixo do que subiu (%s)" % [down])
	# Perto do limite: oscila entre 0,3 e 0,4 sem trocar de nível depois da primeira subida.
	level = 1
	var flips := 0
	for k: int in range(40):
		var next := DamagePalette.next_level(0.3 if k % 2 == 0 else 0.4, level)
		flips += 1 if next != level else 0
		level = next
	_check.call(flips == 0, "nível: histerese não pisca perto do limite")


func _test_size_life() -> void:
	for kind: int in range(K.size()):
		var sizes: Array[int] = []
		var lives: Array[float] = []
		for level: int in range(3):
			sizes.append(DamagePalette.number_size(kind, 0, level))
			lives.append(DamagePalette.level_life(kind, level))
		var shrink := true
		for level: int in range(1, 3):
			var a := DamagePalette.LADDER.find(sizes[level])
			var b := DamagePalette.LADDER.find(sizes[level - 1])
			shrink = shrink and a <= b and lives[level] <= lives[level - 1]
		_check.call(shrink, "densidade %d: tamanho e vida não crescem com o nível (%s)" % [kind, sizes])
		_check.call(sizes[0] == DamagePalette.SIZES[0] and lives[0] == 1.0, "densidade %d: nível 0 igual a antes" % kind)
		var legible := true
		for size: int in sizes:
			legible = legible and (size == 0 or size >= 10)
		_check.call(legible, "densidade %d: nunca abaixo do legível (fonte ≥ 10 ou dígitos 3×5)" % kind)
	for kind: int in [K.CRIT, K.TAKEN, K.TAKEN_HEAVY]:
		_check.call(DamagePalette.number_size(kind, 1, 2) == DamagePalette.SIZES[1]
				and DamagePalette.level_life(kind, 2) == 1.0,
				"densidade %d: crítico e recebido não encolhem nem encurtam" % kind)
	_check.call(DamagePalette.number_size(K.HIT, 0, 1) == 10 and DamagePalette.number_size(K.HIT, 0, 2) == 0,
			"densidade: comum 12 → 10 → dígitos 3×5")
	_check.call(DamagePalette.number_size(K.HIGH, 1, 2) == 12, "densidade: alto encolhe só um degrau")


func _test_fold_rule() -> void:
	_check.call(not DamagePalette.should_fold(K.HIT, 0, 0.0, 10.0, 10.0), "juntar: desligado sem pressão")
	_check.call(DamagePalette.should_fold(K.HIT, 2, 10.0, 10.0, 12.0), "juntar: perto e parecido com pressão")
	_check.call(not DamagePalette.should_fold(K.HIT, 2, 80.0, 10.0, 10.0), "juntar: longe não junta")
	_check.call(not DamagePalette.should_fold(K.HIT, 2, 5.0, 10.0, 30.0), "juntar: valor diferente não junta")
	_check.call(DamagePalette.should_fold(K.HIT, 2, 30.0, 10.0, 10.0)
			and not DamagePalette.should_fold(K.HIT, 1, 30.0, 10.0, 10.0),
			"juntar: raio cresce com a pressão")
	for kind: int in [K.CRIT, K.TAKEN, K.TAKEN_HEAVY, K.HEAL]:
		_check.call(not DamagePalette.should_fold(kind, 2, 0.0, 10.0, 10.0), "juntar: tipo %d nunca junta" % kind)


func _test_significance_rule() -> void:
	_check.call(not DamagePalette.insignificant(K.HIT, 1.0, 10.0, 0), "pequenos: sem pressão aparecem")
	_check.call(DamagePalette.insignificant(K.HIT, 4.0, 10.0, 2), "pequenos: com pressão alta somem")
	_check.call(not DamagePalette.insignificant(K.HIT, 7.0, 10.0, 2), "pequenos: perto da média ficam")
	_check.call(DamagePalette.insignificant(K.HIT, 2.0, 10.0, 1) and not DamagePalette.insignificant(K.HIT, 5.0, 10.0, 1),
			"pequenos: corte cresce com a pressão")
	for kind: int in [K.HIGH, K.CRIT, K.DOT, K.TAKEN, K.TAKEN_HEAVY, K.HEAL]:
		_check.call(not DamagePalette.insignificant(kind, 0.1, 10.0, 2), "pequenos: tipo %d nunca some" % kind)


func _test_abbreviation() -> void:
	var cases := [[9999, ".", "9999"], [10000, ".", "10k"], [12345, ".", "12.3k"], [12345, ",", "12,3k"],
			[123456, ".", "123k"], [1234567, ",", "1,2M"], [25000000, ".", "25M"]]
	for c: Array in cases:
		_check.call(DamagePalette.abbreviate(int(c[0]), String(c[1])) == String(c[2]),
				"abreviação: %d → %s (%s)" % [c[0], c[2], DamagePalette.abbreviate(int(c[0]), String(c[1]))])
	_check.call(DamagePalette.decimal_for("pt_BR") == "," and DamagePalette.decimal_for("de") == ","
			and DamagePalette.decimal_for("en") == "." and DamagePalette.decimal_for("ja") == ".",
			"abreviação: vírgula do idioma")
	_check.call(DamagePalette.text(K.CRIT, 15400.0, ",") == "15,4k!", "abreviação: crítico grande com '!'")


# --- Nó e partida -------------------------------------------------------------------------

func run(host: Node, check: Callable) -> void:
	_check = check
	_host = host
	var n := DamageNumbers.new()
	host.add_child(n)
	await host.get_tree().process_frame
	_test_early(n)
	_test_levels_live(n)
	_test_fold_live(n)
	_test_significance_live(n)
	# Dígitos 3×5 com "×N" desenham sem erro.
	n.force_level(2, 1.0)
	n.reset()
	n.add(Vector2(100, 100), 12345.0, K.HIT, 10000.0, 1)
	n.add(Vector2(104, 100), 12000.0, K.HIT, 10000.0, 2)
	await host.get_tree().process_frame
	n.queue_free()
	await host.get_tree().process_frame
	await _test_stress()


func _test_early(n: DamageNumbers) -> void:
	n.force_level(0, 0.0, false)
	n.reset()
	n.enemies = 25
	for k: int in range(180):
		if k % 12 == 0:
			n.add(Vector2(k * 3.0, 0.0), 10.0, K.HIT, 10.0)
		n.step(STEP)
	_check.call(n.level == 0 and n.pressure < 0.1, "começo: poucos inimigos não ligam a densidade (%.2f)" % n.pressure)
	n.add(Vector2(500, 500), 10.0, K.HIT, 10.0, 3)
	var early := n.last()
	_check.call(int(early["size"]) == DamagePalette.SIZES[0] and int(early["count"]) == 1,
			"começo: comum no tamanho de sempre")


func _test_levels_live(n: DamageNumbers) -> void:
	n.force_level(0, 0.0, false)
	n.reset()
	n.enemies = 500
	for _k: int in range(60):
		n.step(STEP)
	_check.call(n.level == 2, "pressão ao vivo: 500 inimigos chegam ao nível 2 em 1 s (%d, %.2f)" % [n.level, n.pressure])
	n.enemies = 0
	for _k: int in range(30):
		n.step(STEP)
	_check.call(n.level >= 1, "pressão ao vivo: o fim de uma onda não derruba o nível na hora")
	for _k: int in range(600):
		n.step(STEP)
	_check.call(n.level == 0, "pressão ao vivo: sem inimigos volta ao nível 0")
	# Tamanho e vida na hora de nascer seguem o nível; crítico e recebido não mudam.
	var base := {}
	for level: int in [0, 2]:
		n.force_level(level, 0.0 if level == 0 else 1.0)
		n.reset()
		for kind: int in [K.HIT, K.CRIT, K.TAKEN]:
			n.add(Vector2(kind * 60.0, 0.0), 20.0 if kind == K.CRIT else 10.0, kind, 10.0 if kind != K.TAKEN else 100.0)
			base["%d_%d" % [level, kind]] = n.last()
	var dense: Dictionary = base["2_%d" % K.HIT]
	_check.call(int(dense["size"]) == 0 and float(dense["life"]) < float(base["0_%d" % K.HIT]["life"]),
			"nível 2: comum vira dígitos 3×5 e dura menos")
	for kind: int in [K.CRIT, K.TAKEN]:
		_check.call(base["2_%d" % kind]["size"] == base["0_%d" % kind]["size"]
				and is_equal_approx(float(base["2_%d" % kind]["life"]), float(base["0_%d" % kind]["life"])),
				"nível 2: tipo %d com o mesmo tamanho e vida" % kind)


func _test_fold_live(n: DamageNumbers) -> void:
	n.force_level(2, 1.0)
	n.reset()
	var p := Vector2(200, 200)
	n.add(p, 10.0, K.HIT, 0.0, 1)
	n.add(p + Vector2(10, 0), 11.0, K.HIT, 0.0, 2)
	_check.call(n.live == 1 and int(n.last()["count"]) == 2, "juntar ao vivo: perto e parecido vira ×2")
	n.add(p, 30.0, K.HIT, 0.0, 3)
	_check.call(n.live == 2, "juntar ao vivo: valor diferente aparece")
	n.add(p, 10.0, K.DOT, 0.0, 4)
	_check.call(n.live == 3, "juntar ao vivo: outro tipo aparece")
	n.add(p + Vector2(150, 0), 10.0, K.HIT, 0.0, 5)
	_check.call(n.live == 4, "juntar ao vivo: longe aparece")
	n.add(p, 10.0, K.CRIT)
	n.add(p, 10.0, K.CRIT)
	n.add(p, 3.0, K.TAKEN)
	_check.call(n.count(K.CRIT) == 2 and n.count(K.TAKEN) == 1, "juntar ao vivo: crítico e recebido nunca juntam")
	n.force_level(0, 0.0)
	n.reset()
	n.add(p, 10.0, K.HIT, 0.0, 1)
	n.add(p + Vector2(10, 0), 11.0, K.HIT, 0.0, 2)
	_check.call(n.live == 2, "juntar ao vivo: sem pressão os dois aparecem")


func _test_significance_live(n: DamageNumbers) -> void:
	n.force_level(2, 1.0)
	n.reset()
	var dropped := n.dropped
	n.add(Vector2(0, 0), 4.0, K.HIT, 10.0)
	_check.call(n.live == 0 and n.dropped == dropped + 1, "pequenos ao vivo: golpe comum pequeno some com pressão")
	n.add(Vector2(100, 0), 2.0, K.CRIT, 10.0)
	n.add(Vector2(200, 0), 1.0, K.TAKEN, 100.0)
	_check.call(n.count(K.CRIT) == 1 and n.count(K.TAKEN) == 1, "pequenos ao vivo: crítico e recebido pequenos aparecem")
	n.force_level(0, 0.0)
	n.reset()
	n.add(Vector2(0, 0), 4.0, K.HIT, 10.0)
	_check.call(n.live == 1, "pequenos ao vivo: sem pressão aparece")
	n.force_level(0, 0.0, false)


## Fim de partida: 500 inimigos, armas diretas, de área e contínuas, com crítico. Mede a cobertura
## da tela com a densidade adaptativa e com ela travada no nível 0 (antes).
func _test_stress() -> void:
	var adaptive := await _stress_run(false)
	var before := await _stress_run(true)
	print("densidade: cobertura máx %.2f%% (antes %.2f%%), média %.2f%% (antes %.2f%%), vivos máx %d (antes %d)" % [
			adaptive["max"] * 100.0, before["max"] * 100.0, adaptive["avg"] * 100.0, before["avg"] * 100.0,
			adaptive["live"], before["live"]])
	_check.call(adaptive["max"] <= COVERAGE_MAX, "estresse: cobertura da tela ≤ %d%% (%.2f%%)" % [
			roundi(COVERAGE_MAX * 100.0), adaptive["max"] * 100.0])
	_check.call(adaptive["avg"] < before["avg"], "estresse: a densidade adaptativa cobre menos que antes")
	_check.call(int(adaptive["live"]) <= int(DamagePalette.LEVEL_CAP[2]) and int(adaptive["live"]) < int(before["live"]),
			"estresse: menos números vivos com pressão (%d, antes %d)" % [adaptive["live"], before["live"]])
	_check.call(int(adaptive["crits"]) > 0, "estresse: críticos continuam visíveis")
	_check.call(int(adaptive["level"]) == 2, "estresse: 500 inimigos levam ao nível 2")


func _stress_run(locked: bool) -> Dictionary:
	var game := (load(GAME_SCENE) as PackedScene).instantiate() as HyakkiGame
	game.config = {"hero": "goro", "stage": "bamboo", "moon": 1, "mode": "normal", "seed": 9, "speed": 1}
	game.stress_count = 500
	_host.add_child(game)
	await _host.get_tree().process_frame
	game.set("_ad_in_progress", true)
	for id: StringName in [&"kunai", &"shuriken", &"incense", &"smoke_bomb", &"raijin", &"taiko", &"steel_storm",
			&"poison_mist", &"fujin_hurricane", &"thousand_needles"]:
		if not game.has_weapon(id):
			game.add_weapon(id)
	game.player.stats.set_source("test_crit", {"crit": 0.25})
	game.player.stats.recalculate()
	var numbers := game.fx.numbers
	if locked:
		numbers.force_level(0, 0.0)
	var view := Vector2(678.0, 305.0)
	var worst := 0.0
	var total := 0.0
	var samples := 0
	var live := 0
	var crits := 0
	# Os números andam no mesmo passo da simulação (60 fps), não no relógio do teste headless.
	game.fx.set_process(false)
	for frame: int in range(150):
		GameClock.game_time += STEP
		game._on_tick(STEP)
		if game.hud.overlay_open():
			game.hud.bot_answer()
		numbers.enemies = game.enemies.count_alive
		numbers.guard = game.player.position
		numbers.step(STEP)
		if frame % 10 == 0:
			await _host.get_tree().process_frame
		if frame >= 60:
			var cover := numbers.screen_area() / (view.x * view.y)
			worst = maxf(worst, cover)
			total += cover
			samples += 1
			live = maxi(live, numbers.live)
			crits = maxi(crits, numbers.count(K.CRIT))
	var result := {"max": worst, "avg": total / maxf(1.0, samples), "live": live, "crits": crits, "level": numbers.level}
	numbers.force_level(0, 0.0, false)
	game.player.stats.remove_source("test_crit")
	game.queue_free()
	GameClock.paused = false
	await _host.get_tree().process_frame
	return result
