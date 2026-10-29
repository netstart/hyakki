extends RefCounted
## Números de dano coloridos (scripts/core/damage_palette.gd, scripts/systems/damage_numbers.gd):
##   - regras: golpe comum, alto (≥ HIGH_RATIO × média móvel), crítico, dano contínuo, recebido
##     comum e pesado (≥ HEAVY_FRACTION do HP máximo) e cura; a média ignora críticos e tiques;
##   - paleta: famílias "causado" (quentes, sobem) e "recebido" (violeta, "-", descem, tremem)
##     bem separadas; contorno escuro com contraste em todo tipo; paleta de daltonismo com
##     luminância separada dentro de cada família e a mesma forma por tipo, única para cada um;
##   - tamanho: degraus crescentes com o dano, com teto; recebido pela fração do HP;
##   - animação do crítico: HOLD → SLAM (escala inteira 3x/2x → 1x, inclinação) → HANG → SHATTER,
##     diferente do movimento de todos os outros tipos;
##   - opções por tipo e opção geral (DamagePalette.visible, padrões do Settings);
##   - no jogo: deal_damage (direto, crítico, área contínua, incenso), take_damage e heal criam
##     o número do tipo certo (e somam golpes seguidos), a opção "colorblind" troca a paleta ao
##     vivo e "damage_numbers" desligada não cria nada.
## Anel, limite na tela, soma, prioridade, Baixa, estresse, opções por tipo e a tela de Opções:
## tests/damage_number_flow_tests.gd.
## run_unit() roda sem autoloads (tests/run_tests.gd); run() precisa da árvore
## (tests/integration_tests.gd e tests/damage_number_runner.gd).

const K := DamagePalette.Kind
const GAME_SCENE := "res://scenes/game/Game.tscn"

var _check: Callable


func run_unit(check: Callable) -> void:
	_check = check
	_test_classify()
	_test_mean()
	_test_palette(DamagePalette.NORMAL, "normal")
	_test_palette(DamagePalette.COLORBLIND, "daltonismo")
	_test_families()
	_test_colorblind_luminance()
	_test_text()
	_test_sizes()
	_test_crit_motion()
	_test_other_motion()
	_test_visibility()


func _test_classify() -> void:
	_check.call(DamagePalette.classify_hit(10.0, false, false, 10.0) == K.HIT, "dano: golpe na média é comum")
	_check.call(DamagePalette.classify_hit(19.9, false, false, 10.0) == K.HIT, "dano: 1,99× a média ainda é comum")
	_check.call(DamagePalette.classify_hit(20.0, false, false, 10.0) == K.HIGH, "dano: 2× a média é alto")
	_check.call(DamagePalette.classify_hit(5.0, true, false, 10.0) == K.CRIT, "dano: crítico vence mesmo baixo")
	_check.call(DamagePalette.classify_hit(500.0, true, true, 10.0) == K.CRIT, "dano: crítico vence alto e contínuo")
	_check.call(DamagePalette.classify_hit(500.0, false, true, 10.0) == K.DOT, "dano: tique contínuo nunca é alto")
	_check.call(DamagePalette.classify_hit(500.0, false, false, 0.0) == K.HIT, "dano: sem média, primeiro golpe é comum")
	_check.call(DamagePalette.classify_taken(14.9, 100.0) == K.TAKEN, "recebido: 14,9% do HP é comum")
	_check.call(DamagePalette.classify_taken(15.0, 100.0) == K.TAKEN_HEAVY, "recebido: 15% do HP é pesado")
	_check.call(DamagePalette.classify_taken(99999.0, 100.0) == K.TAKEN_HEAVY, "recebido: golpe letal é pesado")


func _test_mean() -> void:
	var mean := DamagePalette.next_mean(0.0, 8.0, K.HIT)
	_check.call(is_equal_approx(mean, 8.0), "média: o primeiro golpe vira a média")
	_check.call(is_equal_approx(DamagePalette.next_mean(mean, 80.0, K.CRIT), mean), "média: crítico não entra")
	_check.call(is_equal_approx(DamagePalette.next_mean(mean, 1.0, K.DOT), mean), "média: tique contínuo não entra")
	var after := DamagePalette.next_mean(mean, 30.0, K.HIGH)
	_check.call(after > mean and after < 30.0, "média: golpe alto puxa a média devagar")
	# Começo de partida: Kunai (6) e Katana (10) se alternando; o Kaminari (30) se destaca.
	mean = 0.0
	for k: int in range(20):
		var amount := 6.0 if k % 2 == 0 else 10.0
		mean = DamagePalette.next_mean(mean, amount, DamagePalette.classify_hit(amount, false, false, mean))
	_check.call(DamagePalette.classify_hit(10.0, false, false, mean) == K.HIT, "média: Katana perto da Kunai é comum")
	_check.call(DamagePalette.classify_hit(30.0, false, false, mean) == K.HIGH, "média: Kaminari se destaca como alto")


func _test_palette(pal: Array, label: String) -> void:
	_check.call(pal.size() == K.size(), "paleta %s: um estilo por tipo" % label)
	var signatures := {}
	for kind: int in range(pal.size()):
		var s: Dictionary = pal[kind]
		var fill: Color = s["fill"]
		var outline: Color = s["outline"]
		# Contorno escuro e texto claro: lê em bioma escuro (contorno) e claro (outro mundo).
		var ratio := (DamagePalette.luminance(fill) + 0.05) / (DamagePalette.luminance(outline) + 0.05)
		_check.call(ratio >= 4.5, "paleta %s: tipo %d com contraste %.1f:1 contra o contorno" % [label, kind, ratio])
		_check.call(DamagePalette.luminance(outline) < 0.03, "paleta %s: contorno do tipo %d é escuro" % [label, kind])
		_check.call(int(s["outline_px"]) >= 2, "paleta %s: tipo %d tem contorno" % [label, kind])
		_check.call(float(s["life"]) > 0.3 and float(s["life"]) <= 1.0, "paleta %s: tipo %d dura pouco" % [label, kind])
		_check.call(int(s["priority"]) == DamagePalette.priority(kind), "paleta %s: prioridade igual" % label)
		signatures[DamagePalette.style_signature(s)] = kind
	_check.call(signatures.size() == pal.size(), "paleta %s: cada tipo tem forma própria, sem depender da cor" % label)
	for kind: int in range(pal.size()):
		_check.call(DamagePalette.style_signature(pal[kind]) == DamagePalette.style_signature(DamagePalette.NORMAL[kind]),
				"paleta %s: tipo %d tem a mesma forma nas duas paletas" % [label, kind])
	var crit: Dictionary = pal[K.CRIT]
	_check.call(String(crit["suffix"]) == "!" and bool(crit["bold"]) and int(crit["anim"]) == DamagePalette.Anim.CRIT,
			"paleta %s: crítico com '!', negrito e animação própria" % label)
	var anims := {}
	for s: Dictionary in pal:
		anims[int(s["anim"])] = true
	_check.call(anims.size() == pal.size(), "paleta %s: cada tipo tem seu próprio movimento" % label)
	_check.call(float(pal[K.TAKEN_HEAVY]["shake"]) > float(pal[K.TAKEN]["shake"]) and bool(pal[K.TAKEN_HEAVY]["bold"]),
			"paleta %s: recebido pesado treme mais e é negrito" % label)
	_check.call(float(pal[K.DOT]["life"]) < float(pal[K.HIT]["life"]), "paleta %s: tique contínuo some antes" % label)


## Causado (quente, sobe, sem prefixo) × recebido (violeta, "-", desce) × cura (verde, "+").
func _test_families() -> void:
	var pal := DamagePalette.NORMAL
	for kind: int in [K.HIT, K.HIGH, K.CRIT, K.DOT]:
		var s: Dictionary = pal[kind]
		_check.call(DamagePalette.is_enemy(kind) and String(s["prefix"]) == "" and float(s["drift"]) <= 0.0,
				"causado %d: sem prefixo e não desce" % kind)
		for taken: int in [K.TAKEN, K.TAKEN_HEAVY]:
			var d := _rgb_distance(s["fill"], pal[taken]["fill"])
			_check.call(d >= 0.35, "cor do causado %d longe do recebido %d (%.2f)" % [kind, taken, d])
	for taken: int in [K.TAKEN, K.TAKEN_HEAVY]:
		var s: Dictionary = pal[taken]
		var hue := (s["fill"] as Color).h * 360.0
		_check.call(DamagePalette.is_taken(taken) and String(s["prefix"]) == "-" and float(s["drift"]) > 0.0
				and float(s["shake"]) > 0.0, "recebido %d: '-', desce e treme" % taken)
		_check.call(hue >= 260.0 and hue <= 310.0, "recebido %d na família violeta (%.0f°)" % [taken, hue])
	for kind: int in [K.HIGH, K.CRIT]:
		var hue := (pal[kind]["fill"] as Color).h * 360.0
		_check.call(hue <= 50.0 or hue >= 340.0, "causado %d na família quente (%.0f°)" % [kind, hue])
	var heal: Dictionary = pal[K.HEAL]
	var heal_hue := (heal["fill"] as Color).h * 360.0
	_check.call(String(heal["prefix"]) == "+" and heal_hue >= 100.0 and heal_hue <= 160.0, "cura verde com '+'")
	_check.call(_rgb_distance(pal[K.HIGH]["fill"], pal[K.CRIT]["fill"]) >= 0.3, "alto e crítico com cores distintas")
	_check.call(_rgb_distance(pal[K.HIT]["fill"], pal[K.HIGH]["fill"]) >= 0.3, "comum e alto com cores distintas")


## Daltonismo: dentro de cada família os tipos se separam pela luminância, não pelo matiz.
func _test_colorblind_luminance() -> void:
	var pal := DamagePalette.COLORBLIND
	var lum := func(kind: int) -> float: return DamagePalette.luminance(pal[kind]["fill"])
	_check.call(lum.call(K.HIT) - lum.call(K.HIGH) >= 0.1 and lum.call(K.HIGH) - lum.call(K.CRIT) >= 0.1,
			"daltonismo: comum > alto > crítico em luminância")
	_check.call(absf(lum.call(K.HIT) - lum.call(K.DOT)) >= 0.1, "daltonismo: comum e contínuo separados na luminância")
	_check.call(lum.call(K.TAKEN) - lum.call(K.TAKEN_HEAVY) >= 0.1, "daltonismo: recebido comum mais claro que o pesado")


func _test_text() -> void:
	_check.call(DamagePalette.text(K.HIT, 12.4) == "12", "texto: comum arredonda")
	_check.call(DamagePalette.text(K.CRIT, 24.6) == "25!", "texto: crítico com '!'")
	_check.call(DamagePalette.text(K.TAKEN, 3.0) == "-3", "texto: recebido com '-'")
	_check.call(DamagePalette.text(K.HEAL, 10.0) == "+10", "texto: cura com '+'")
	_check.call(DamagePalette.text(K.DOT, 0.2) == "1", "texto: nunca mostra 0")


## Tamanho: não diminui com o dano, começa no tamanho de sempre e para no teto.
func _test_sizes() -> void:
	for kind: int in [K.HIT, K.HIGH, K.CRIT]:
		var prev := -1
		var monotonic := true
		var amount := 1.0
		while amount < 1.0e6:
			var step := DamagePalette.size_step(kind, amount, 10.0)
			monotonic = monotonic and step >= prev and step >= 0 and step <= DamagePalette.MAX_STEP
			prev = step
			amount *= 1.15
		_check.call(monotonic, "tamanho %d: cresce com o dano, sem passar do teto" % kind)
		_check.call(prev == DamagePalette.MAX_STEP, "tamanho %d: golpe enorme chega ao teto" % kind)
	_check.call(DamagePalette.size_step(K.HIT, 10.0, 10.0) == 0, "tamanho: golpe na média é o de sempre")
	_check.call(DamagePalette.size_step(K.HIGH, 20.0, 10.0) == 1, "tamanho: 2× a média sobe um degrau")
	_check.call(DamagePalette.size_step(K.HIGH, 40.0, 10.0) == 2, "tamanho: 4× a média sobe dois")
	_check.call(DamagePalette.size_step(K.HIGH, 10.0, 0.0) == 0, "tamanho: sem média fica no de sempre")
	_check.call(DamagePalette.size_step(K.DOT, 999.0, 1.0) == 0 and DamagePalette.size_step(K.HEAL, 999.0, 1.0) == 0,
			"tamanho: contínuo e cura sempre no de sempre")
	_check.call(DamagePalette.size_step(K.TAKEN, 5.0, 100.0) == 0, "tamanho: recebido comum no de sempre")
	_check.call(DamagePalette.size_step(K.TAKEN_HEAVY, 20.0, 100.0) == 1, "tamanho: recebido pesado sobe um degrau")
	_check.call(DamagePalette.size_step(K.TAKEN_HEAVY, 9999.0, 100.0) == 2, "tamanho: recebido letal para em 2")
	var sizes_up := true
	for step: int in range(1, DamagePalette.SIZES.size()):
		sizes_up = sizes_up and DamagePalette.font_size(step) > DamagePalette.font_size(step - 1)
	_check.call(sizes_up and DamagePalette.font_size(0) == 12 and DamagePalette.font_size(99) == DamagePalette.SIZES[-1],
			"tamanho: fontes crescentes, base 12 e teto %d" % DamagePalette.SIZES[-1])
	_check.call(float(DamagePalette.SIZES[-1]) <= 2.0 * DamagePalette.SIZES[0], "tamanho: teto de 2× o normal")


## Crítico: fases em ordem, escala inteira descendo no SLAM, inclinação só no SLAM, parado no HANG.
func _test_crit_motion() -> void:
	var phases: Array[int] = []
	var slam_scales: Array[float] = []
	var integer_steps := true
	var tilt_only_in_slam := true
	var hang_still := true
	var shatter_up := true
	var last_dy := 0.0
	var age := 0.0
	while age < DamagePalette.CRIT_LIFE + 0.05:
		var phase := DamagePalette.crit_phase(age)
		if phases.is_empty() or phases[-1] != phase:
			phases.append(phase)
		var m := DamagePalette.crit_motion(age, 0)
		integer_steps = integer_steps and is_equal_approx(m.x, roundf(m.x))
		if phase == DamagePalette.CritPhase.SLAM:
			slam_scales.append(m.x)
		elif not is_zero_approx(m.y):
			tilt_only_in_slam = false
		if phase == DamagePalette.CritPhase.HANG:
			hang_still = hang_still and is_zero_approx(m.z) and is_equal_approx(m.x, 1.0) and is_equal_approx(m.w, 1.0)
		if phase == DamagePalette.CritPhase.SHATTER:
			shatter_up = shatter_up and m.z <= last_dy
			last_dy = m.z
		age += 1.0 / 120.0
	var cp := DamagePalette.CritPhase
	_check.call(phases == [cp.HOLD, cp.SLAM, cp.HANG, cp.SHATTER, cp.DONE],
			"crítico: HOLD → SLAM → HANG → SHATTER (%s)" % [phases])
	_check.call(DamagePalette.crit_motion(0.0, 0).x == 0.0, "crítico: congela invisível no HOLD")
	_check.call(integer_steps, "crítico: escala sempre inteira (pixel nítido)")
	_check.call(slam_scales[0] == 3.0 and slam_scales[-1] == 1.0, "crítico: SLAM bate de 3x até 1x (%s)" % [slam_scales])
	var down := true
	for k: int in range(1, slam_scales.size()):
		down = down and slam_scales[k] <= slam_scales[k - 1]
	_check.call(down and slam_scales.has(2.0), "crítico: SLAM desce em degraus 3 → 2 → 1")
	_check.call(DamagePalette.crit_motion(DamagePalette.CRIT_HOLD + 0.001, 2).x == 2.0,
			"crítico: número grande bate só de 2x (sem cobrir a tela)")
	_check.call(DamagePalette.crit_motion(DamagePalette.CRIT_HOLD + 0.001, 0, false).x == 1.0
			and not is_zero_approx(DamagePalette.crit_motion(DamagePalette.CRIT_HOLD + 0.001, 0, false).y)
			and DamagePalette.crit_motion(0.0, 0, false).x == 0.0, "crítico mini: congela e inclina, sem crescer")
	_check.call(not is_zero_approx(DamagePalette.crit_motion(DamagePalette.CRIT_HOLD + 0.001, 0).y),
			"crítico: entra inclinado")
	_check.call(tilt_only_in_slam, "crítico: endireita antes do HANG")
	_check.call(hang_still, "crítico: parado e inteiro no HANG")
	_check.call(shatter_up and last_dy < -10.0, "crítico: dispara para cima no SHATTER")
	_check.call(DamagePalette.crit_motion(DamagePalette.CRIT_LIFE - 0.01, 0).w < 0.1, "crítico: some no fim")
	_check.call(DamagePalette.CRIT_LIFE >= 0.6 and DamagePalette.CRIT_LIFE <= 0.8, "crítico: dura entre 0,6 e 0,8 s")
	_check.call(DamagePalette.crit_flash(DamagePalette.CRIT_HOLD) == 1.0
			and DamagePalette.crit_flash(DamagePalette.CRIT_SLAM_END) == 0.0, "crítico: branco vira carmim no SLAM")


## Os outros tipos nunca fazem o que o crítico faz: aparecem na hora, escala 1, sem inclinação e
## derivam desde o começo; o inchaço é só um degrau de fonte por pouco tempo.
func _test_other_motion() -> void:
	for kind: int in range(K.size()):
		if kind == K.CRIT:
			continue
		var s: Dictionary = DamagePalette.NORMAL[kind]
		var life := float(s["life"])
		var same := true
		var age := 0.0
		while age < life:
			var m := DamagePalette.motion(kind, age, life)
			same = same and m.x == 1.0 and m.y == 0.0 and is_equal_approx(m.z, float(s["drift"]) * age)
			age += 1.0 / 120.0
		_check.call(same, "movimento %d: escala 1, sem inclinação, deriva constante" % kind)
		_check.call(DamagePalette.motion(kind, 0.0, life).w > 0.9, "movimento %d: aparece na hora (sem congelar)" % kind)
	_check.call(DamagePalette.pop_steps(DamagePalette.Anim.POP, 0.0) == 1
			and DamagePalette.pop_steps(DamagePalette.Anim.POP, DamagePalette.POP_TIME) == 0,
			"alto: inchaço curto de um degrau")
	_check.call(DamagePalette.pop_steps(DamagePalette.Anim.RISE, 0.0) == 0
			and DamagePalette.pop_steps(DamagePalette.Anim.CRIT, 0.0) == 0, "comum e crítico sem o inchaço do alto")


func _test_visibility() -> void:
	_check.call(DamagePalette.SETTING_KEYS.size() == K.size(), "opções: uma por tipo")
	for kind: int in range(K.size()):
		_check.call(DamagePalette.visible(kind, {}), "opções: save antigo sem chaves mostra o tipo %d" % kind)
		_check.call(not DamagePalette.visible(kind, {"damage_numbers": false}), "opções: geral desligada esconde %d" % kind)
		var off := {DamagePalette.SETTING_KEYS[kind]: false}
		var only := true
		for other: int in range(K.size()):
			only = only and DamagePalette.visible(other, off) == (other != kind)
		_check.call(only, "opções: desligar %s esconde só aquele tipo" % DamagePalette.SETTING_KEYS[kind])
	var settings := load("res://scripts/autoload/settings.gd") as GDScript
	var defaults: Dictionary = settings.get_script_constant_map()["DEFAULTS"]
	for key: String in DamagePalette.SETTING_KEYS:
		_check.call(defaults.get(key) == true, "opções: %s existe no Settings e vem ligada" % key)


static func _rgb_distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


# --- No jogo (com autoloads) --------------------------------------------------------------

func run(host: Node, check: Callable) -> void:
	_check = check
	Settings.set_value("damage_numbers", true)
	Settings.set_value("colorblind", false)
	var game := (load(GAME_SCENE) as PackedScene).instantiate() as HyakkiGame
	game.config = {"hero": "goro", "stage": "bamboo", "moon": 1, "mode": "normal", "seed": 5, "speed": 1}
	host.add_child(game)
	await host.get_tree().process_frame
	game.set("_ad_in_progress", true)
	game.player.stats.set_source("test_no_crit", {"crit": -10.0})
	game.player.stats.recalculate()
	var foes: Array[int] = []
	for k: int in range(4):
		foes.append(game.enemies.spawn(&"slime_rice", game.player.sim_pos + Vector2(60 + 40 * k, 0), 100000.0, 1.0))
	_check.call(not foes.has(-1), "números: inimigos de teste nasceram")
	if not foes.has(-1):
		_enemy_numbers(game, foes)
	_player_numbers(game)
	# Desenho de todos os tipos vivos ao mesmo tempo (crítico, tremor, negrito) sem erro.
	for kind: int in range(K.size()):
		game.fx.add_number(game.player.sim_pos + Vector2(kind * 12.0, 0.0), 10.0, kind)
	await host.get_tree().process_frame
	Settings.set_value("colorblind", true)
	await host.get_tree().process_frame
	_check.call(game.fx.last_number().get("fill") == DamagePalette.COLORBLIND[K.HEAL]["fill"],
			"números: opção colorblind troca a paleta ao vivo")
	Settings.set_value("colorblind", false)
	await host.get_tree().process_frame
	_check.call(game.fx.last_number().get("fill") == DamagePalette.NORMAL[K.HEAL]["fill"],
			"números: paleta normal volta ao desligar colorblind")
	Settings.set_value("damage_numbers", false)
	var n_before := int(game.fx.get("_n_next"))
	game.player.hp = 10.0
	game.player.heal(50.0, true)
	if not foes.has(-1):
		game.deal_damage(&"katana", foes[0], 10.0, Vector2.RIGHT, 0.0)
	_check.call(int(game.fx.get("_n_next")) == n_before, "números: damage_numbers desligado não cria cura nem dano")
	Settings.set_value("damage_numbers", true)
	game.player.stats.remove_source("test_no_crit")
	game.queue_free()
	GameClock.paused = false
	await host.get_tree().process_frame


func _enemy_numbers(game: HyakkiGame, foes: Array[int]) -> void:
	game.fx.reset()
	game.deal_damage(&"katana", foes[0], 10.0, Vector2.RIGHT, 0.0)
	_expect(game, K.HIT, "10", "deal_damage comum")
	# Golpes seguidos no mesmo inimigo somam num número só (que cresce).
	var live := game.fx.numbers.live
	for k: int in range(5):
		game.deal_damage(&"katana", foes[0], 10.0, Vector2.RIGHT, 0.0)
	_expect(game, K.HIT, "60", "golpes seguidos no mesmo inimigo somam")
	_check.call(game.fx.numbers.live == live, "números: a soma não cria números novos")
	game.deal_damage(&"kaminari", foes[1], 30.0, Vector2.RIGHT, 0.0)
	_expect(game, K.HIGH, "30", "deal_damage alto (3× a média)")
	_check.call(int(game.fx.last_number()["size"]) > DamagePalette.SIZES[0], "números: golpe alto vem maior")
	game.deal_damage(&"katana", foes[1], 10.0, Vector2.RIGHT, 0.0, true)
	_expect(game, K.CRIT, "20!", "deal_damage crítico (dobra e '!')")
	game.deal_damage(&"incense", foes[2], 40.0, Vector2.RIGHT, 0.0, false, true)
	_expect(game, K.DOT, "40", "deal_damage contínuo nunca vira alto")
	# Poça (Bomba de Fumaça): o tique passa pela área como contínuo e soma no mesmo inimigo.
	game.areas.reset()
	game.enemies.spatial.clear()
	game.enemies.spatial.insert(foes[2], game.enemies.pos[foes[2]])
	game.areas.pool(&"smoke_bomb", game.enemies.pos[foes[2]], 30.0, 7.0, 0.5, 1.0)
	game.areas.step(1.0 / 60.0)
	_expect(game, K.DOT, "47", "tique da poça é contínuo e soma no mesmo inimigo")
	game.areas.reset()
	# Explosão instantânea (blast sem dot) é golpe direto.
	game.enemies.spatial.clear()
	game.enemies.spatial.insert(foes[3], game.enemies.pos[foes[3]])
	game.areas.blast(&"kaminari", game.enemies.pos[foes[3]], 30.0, 10.0, 0.0)
	_expect(game, K.HIT, "10", "explosão instantânea é golpe direto")


func _player_numbers(game: HyakkiGame) -> void:
	var player := game.player
	player.hp = player.max_hp()
	player.damage.reset()
	player.invuln = 0.0
	player.take_damage(3.0 + player.stats.get_stat("armor"))
	var taken := game.fx.last_number()
	_check.call(int(taken.get("kind", -1)) == K.TAKEN and String(taken.get("text", "")).begins_with("-"),
			"take_damage comum: violeta com '-' (%s)" % taken)
	player.damage.reset()
	player.invuln = 0.0
	player.take_damage(player.max_hp() * 0.3 + player.stats.get_stat("armor"))
	var heavy := game.fx.last_number()
	_check.call(int(heavy.get("kind", -1)) == K.TAKEN_HEAVY and int(heavy.get("size", 0)) > DamagePalette.SIZES[0],
			"take_damage pesado (30% do HP), maior")
	player.hp = player.max_hp() - 20.0
	player.heal(10.0, true)
	_expect(game, K.HEAL, "+10", "heal com número")
	var n_before := int(game.fx.get("_n_next"))
	player.heal(5.0)
	_check.call(int(game.fx.get("_n_next")) == n_before, "heal contínuo (roubo de vida) não cria número")
	player.hp = player.max_hp()
	player.heal(10.0, true)
	_check.call(int(game.fx.get("_n_next")) == n_before, "heal com HP cheio não cria número")
	player.hp = player.max_hp()
	player.damage.reset()


func _expect(game: HyakkiGame, kind: int, text: String, label: String) -> void:
	var n := game.fx.last_number()
	_check.call(int(n.get("kind", -1)) == kind and String(n.get("text", "")) == text
			and n.get("fill") == DamagePalette.NORMAL[kind]["fill"], "números: %s (%s)" % [label, n])
