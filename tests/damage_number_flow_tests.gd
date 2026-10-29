extends RefCounted
## Números de dano no fluxo do jogo (scripts/systems/damage_numbers.gd, FxLayer.add_number, tela de
## Opções e Settings):
##   - anel: limite MAX_ON_SCREEN, comum/contínuo novo descartado com a tela cheia, crítico e
##     recebido só saem depois de todos os de prioridade menor, soma de golpes seguidos no mesmo
##     inimigo (comum e contínuo, com janela e idade máximas), alto e crítico nunca somam, vida
##     mais curta com a tela cheia, afastamento entre sobrepostos, dano nos inimigos fora de cima
##     da guardiã, versão Baixa e nenhum objeto novo por quadro;
##   - estresse: 500 inimigos e várias armas (com crítico) sem passar do limite;
##   - opções por tipo: cada uma esconde só o seu tipo nos caminhos reais (deal_damage,
##     take_damage, heal), a geral desligada vence todas, gravar/ler e save antigo sem as chaves;
##   - tela de Opções: uma linha por tipo com amostra na paleta em uso, travadas e apagadas com a
##     geral desligada, e a chave grava na hora.
## Rodado por tests/integration_tests.gd e tests/damage_number_runner.gd.

const K := DamagePalette.Kind
const GAME_SCENE := "res://scenes/game/Game.tscn"
const OPTIONS_SCREEN := "res://scripts/app/screens/options_screen.gd"
const STEP := 1.0 / 60.0
const MAX := DamagePalette.MAX_ON_SCREEN

var _check: Callable
var _host: Node


func run(host: Node, check: Callable) -> void:
	_check = check
	_host = host
	_all_on()
	await _test_pool()
	await _test_toggles()
	_test_persistence()
	await _test_options_screen()
	await _test_stress()
	_all_on()


func _all_on() -> void:
	Settings.set_value("damage_numbers", true)
	Settings.set_value("colorblind", false)
	for key: String in DamagePalette.SETTING_KEYS:
		Settings.set_value(key, true)


# --- Anel -----------------------------------------------------------------------------------

func _test_pool() -> void:
	var n := DamageNumbers.new()
	_host.add_child(n)
	await _host.get_tree().process_frame
	# Regras do anel sem a densidade adaptativa (testada em tests/damage_number_density_tests.gd).
	n.force_level(0, 0.0)
	_test_cap(n)
	_test_merge(n)
	_test_placement(n)
	# Nenhum objeto novo por quadro com a tela cheia (tudo em arrays fixos).
	n.reset()
	for k: int in range(MAX):
		n.add(Vector2(k * 13.0, 0.0), 10.0, K.CRIT if k % 5 == 0 else K.HIT)
	await _host.get_tree().process_frame
	await _host.get_tree().process_frame
	var objects := Performance.get_monitor(Performance.OBJECT_COUNT)
	for _f: int in range(20):
		n.step(0.001)
		await _host.get_tree().process_frame
	var grown := Performance.get_monitor(Performance.OBJECT_COUNT) - objects
	_check.call(grown <= 0.0, "números: nenhum objeto novo por quadro (+%d)" % grown)
	_check.call(n.get_child_count() == 0 and (n.get("_life") as PackedFloat32Array).size() == DamageNumbers.CAPACITY,
			"números: sem nós filhos e anel de tamanho fixo")
	# Baixa: o crítico reduzido desenha sem erro.
	n.low = true
	n.add(Vector2.ZERO, 50.0, K.CRIT)
	for _f: int in range(3):
		n.step(0.08)
		await _host.get_tree().process_frame
	n.queue_free()
	await _host.get_tree().process_frame


func _test_cap(n: DamageNumbers) -> void:
	n.reset()
	var events := n.events
	for k: int in range(MAX + 20):
		n.add(Vector2(k * 13.0, 0.0), 10.0, K.HIT)
	_check.call(n.live == MAX and n.count() == MAX, "limite: no máximo %d números vivos" % MAX)
	_check.call(n.events - events == MAX, "limite: comum novo descartado com a tela cheia")
	n.add(Vector2(0.0, 50.0), 30.0, K.CRIT)
	_check.call(n.live == MAX and n.count(K.CRIT) == 1 and n.count(K.HIT) == MAX - 1,
			"limite: crítico entra tirando um comum")
	for k: int in range(MAX - 1):
		n.add(Vector2(k * 13.0, 80.0), 5.0, K.TAKEN)
	_check.call(n.count(K.CRIT) == 1 and n.count(K.HIT) == 0 and n.live == MAX,
			"limite: crítico só sai depois de todos os comuns")
	events = n.events
	n.add(Vector2.ZERO, 5.0, K.HIT)
	n.add(Vector2.ZERO, 50.0, K.HIGH)
	_check.call(n.events == events and n.count(K.HIGH) == 0, "limite: comum e alto não tiram crítico nem recebido")
	n.add(Vector2.ZERO, 5.0, K.TAKEN)
	_check.call(n.live == MAX and n.count(K.CRIT) == 0, "limite: recebido novo tira o crítico mais velho")


func _test_merge(n: DamageNumbers) -> void:
	n.reset()
	n.add(Vector2.ZERO, 5.0, K.HIT, 10.0, 7)
	n.add(Vector2.ZERO, 5.0, K.HIT, 10.0, 7)
	_check.call(n.live == 1 and float(n.last()["amount"]) == 10.0, "soma: golpes seguidos no mesmo inimigo somam")
	n.add(Vector2.ZERO, 5.0, K.HIT, 10.0, 8)
	_check.call(n.live == 2, "soma: outro inimigo tem seu número")
	n.step(DamagePalette.MERGE_WINDOW + 0.05)
	n.add(Vector2.ZERO, 5.0, K.HIT, 10.0, 7)
	_check.call(n.live == 3, "soma: depois da janela vem número novo")
	n.add(Vector2.ZERO, 40.0, K.HIGH, 10.0, 9)
	n.add(Vector2.ZERO, 40.0, K.HIGH, 10.0, 9)
	n.add(Vector2.ZERO, 40.0, K.CRIT, 10.0, 9)
	n.add(Vector2.ZERO, 40.0, K.CRIT, 10.0, 9)
	_check.call(n.live == 7, "soma: alto e crítico nunca somam")
	n.reset()
	n.add(Vector2.ZERO, 3.0, K.DOT, 0.0, 4)
	n.step(0.4)
	n.add(Vector2.ZERO, 3.0, K.DOT, 0.0, 4)
	_check.call(n.live == 1 and float(n.last()["amount"]) == 6.0, "soma: tiques contínuos a 0,4 s somam")
	n.step(DamagePalette.DOT_MERGE_WINDOW + 0.05)
	n.add(Vector2.ZERO, 3.0, K.DOT, 0.0, 4)
	_check.call(n.count(K.DOT) >= 1 and float(n.last()["amount"]) == 3.0, "soma: tique depois da janela recomeça")
	# Um contador contínuo não sobe para sempre: passa da idade máxima e recomeça.
	n.reset()
	var events := n.events
	for k: int in range(8):
		n.add(Vector2.ZERO, 1.0, K.DOT, 0.0, 5)
		n.step(0.3)
	_check.call(n.events - events == 8 and float(n.last()["amount"]) < 8.0, "soma: idade máxima reinicia o contador")
	# Comum somado cresce de tamanho junto com o total.
	n.reset()
	n.add(Vector2.ZERO, 10.0, K.HIT, 10.0, 11)
	var small := int(n.last()["size"])
	for k: int in range(7):
		n.add(Vector2.ZERO, 10.0, K.HIT, 10.0, 11)
	_check.call(int(n.last()["size"]) > small, "soma: número que soma cresce")


func _test_placement(n: DamageNumbers) -> void:
	n.reset()
	var life := n.get("_life") as PackedFloat32Array
	n.add(Vector2(500, 500), 5.0, K.HIT)
	var calm := (n.get("_life") as PackedFloat32Array)[int(n.get("_last_slot"))]
	for k: int in range(MAX - 5):
		n.add(Vector2(k * 13.0, 0.0), 5.0, K.HIT)
	n.add(Vector2(500, 400), 5.0, K.HIT)
	var dense := (n.get("_life") as PackedFloat32Array)[int(n.get("_last_slot"))]
	n.add(Vector2(500, 300), 50.0, K.CRIT)
	var crit := (n.get("_life") as PackedFloat32Array)[int(n.get("_last_slot"))]
	_check.call(dense < calm * 0.75, "vida: mais curta com a tela cheia (%.2f × %.2f)" % [dense, calm])
	_check.call(is_equal_approx(crit, DamagePalette.CRIT_LIFE), "vida: crítico sempre inteiro")
	_check.call(life.size() == DamageNumbers.CAPACITY, "vida: anel não muda de tamanho")
	n.reset()
	n.add(Vector2(100, 100), 5.0, K.HIT, 0.0, 1)
	var first: Vector2 = n.last()["pos"]
	n.add(Vector2(100, 100), 5.0, K.HIT, 0.0, 2)
	var second: Vector2 = n.last()["pos"]
	_check.call(second.y <= first.y - DamagePalette.SPREAD_PX + 0.01, "afastamento: sobrepostos não se cobrem")
	n.reset()
	n.guard = Vector2(200, 200)
	n.add(Vector2(200, 206), 5.0, K.HIT)
	var moved: Vector2 = n.last()["pos"]
	_check.call(absf(moved.x - 200.0) >= DamagePalette.GUARD_CLEAR.x - 0.01,
			"guardiã: dano no inimigo não cobre a guardiã")
	n.add(Vector2(200, 180), 5.0, K.TAKEN)
	_check.call(absf((n.last()["pos"] as Vector2).x - 200.0) <= 3.01, "guardiã: o recebido fica sobre ela")
	n.guard = Vector2.INF
	# Lugar cheio: comum/contínuo a mais ali é descartado; o crítico ainda entra.
	n.reset()
	for k: int in range(10):
		n.add(Vector2(300, 300), 5.0, K.HIT if k % 2 == 0 else K.DOT, 0.0, 100 + k)
	_check.call(n.live == DamagePalette.LOCAL_MAX,
			"densidade: no máximo %d comuns no mesmo lugar" % DamagePalette.LOCAL_MAX)
	n.add(Vector2(300, 300), 50.0, K.CRIT)
	n.add(Vector2(300, 300), 5.0, K.TAKEN)
	_check.call(n.count(K.CRIT) == 1 and n.count(K.TAKEN) == 1,
			"densidade: crítico e recebido entram mesmo no lugar cheio")
	n.reset()
	for k: int in range(8):
		n.add(Vector2(300, 300), 50.0, K.CRIT)
	_check.call(n.count(K.CRIT) == DamagePalette.LOCAL_MAX, "densidade: críticos também não empilham num lugar só")
	# Chuva de críticos: só CRIT_BIG_MAX fazem o SLAM grande ao mesmo tempo.
	n.reset()
	var big := 0
	for k: int in range(6):
		n.add(Vector2(k * 40.0, 0.0), 50.0, K.CRIT)
		big += 1 if bool(n.last()["big"]) else 0
	_check.call(big == DamagePalette.CRIT_BIG_MAX,
			"críticos: só %d com o SLAM grande juntos (%d)" % [DamagePalette.CRIT_BIG_MAX, big])
	n.step(DamagePalette.CRIT_SLAM_END + 0.01)
	n.add(Vector2(0.0, 100.0), 50.0, K.CRIT)
	_check.call(bool(n.last()["big"]), "críticos: passado o SLAM, o próximo volta a ser grande")
	n.reset()
	for k: int in range(DamagePalette.MAX_CRITS + 6):
		n.add(Vector2(k * 40.0, 0.0), 50.0, K.CRIT)
	_check.call(n.count(K.CRIT) == DamagePalette.MAX_CRITS and n.live_kind[K.CRIT] == DamagePalette.MAX_CRITS,
			"críticos: no máximo %d na tela" % DamagePalette.MAX_CRITS)
	n.step(DamagePalette.CRIT_LIFE + 0.01)
	_check.call(n.live == 0 and n.live_kind[K.CRIT] == 0, "críticos: contadores zeram quando somem")


# --- Opções por tipo -------------------------------------------------------------------------

func _test_toggles() -> void:
	var game := (load(GAME_SCENE) as PackedScene).instantiate() as HyakkiGame
	game.config = {"hero": "goro", "stage": "bamboo", "moon": 1, "mode": "normal", "seed": 5, "speed": 1}
	_host.add_child(game)
	await _host.get_tree().process_frame
	game.set("_ad_in_progress", true)
	game.player.stats.set_source("test_no_crit", {"crit": -10.0})
	game.player.stats.recalculate()
	var foe := game.enemies.spawn(&"slime_rice", game.player.sim_pos + Vector2(80, 0), 100000.0, 1.0)
	_check.call(foe >= 0, "opções por tipo: inimigo de teste nasceu")
	if foe >= 0:
		for off: int in range(K.size()):
			Settings.set_value(DamagePalette.SETTING_KEYS[off], false)
			var shown := ""
			var ok := true
			for kind: int in range(K.size()):
				var seen := _trigger(game, foe, kind)
				ok = ok and seen == (kind != off)
				shown += "1" if seen else "0"
			_check.call(ok, "opções por tipo: %s desligada esconde só o seu tipo (%s)"
					% [DamagePalette.SETTING_KEYS[off], shown])
			Settings.set_value(DamagePalette.SETTING_KEYS[off], true)
		var all := true
		for kind: int in range(K.size()):
			all = all and _trigger(game, foe, kind)
		_check.call(all, "opções por tipo: todas ligadas mostram tudo")
		Settings.set_value("damage_numbers", false)
		var none := true
		for kind: int in range(K.size()):
			none = none and not _trigger(game, foe, kind)
		_check.call(none, "opções por tipo: a geral desligada vence as ligadas")
		Settings.set_value("damage_numbers", true)
	game.player.stats.remove_source("test_no_crit")
	game.queue_free()
	GameClock.paused = false
	await _host.get_tree().process_frame


## Dispara um número do tipo `kind` pelo caminho real e diz se apareceu um número desse tipo.
func _trigger(game: HyakkiGame, foe: int, kind: int) -> bool:
	game.fx.numbers.reset()
	game.fx.set("_hit_mean", 10.0)
	var player := game.player
	player.damage.reset()
	player.invuln = 0.0
	player.hp = player.max_hp() * 0.5
	var armor := player.stats.get_stat("armor")
	var events := game.fx.numbers.events
	match kind:
		K.HIT:
			game.deal_damage(&"katana", foe, 10.0, Vector2.RIGHT, 0.0)
		K.HIGH:
			game.deal_damage(&"kaminari", foe, 40.0, Vector2.RIGHT, 0.0)
		K.CRIT:
			game.deal_damage(&"katana", foe, 10.0, Vector2.RIGHT, 0.0, true)
		K.DOT:
			game.deal_damage(&"incense", foe, 4.0, Vector2.RIGHT, 0.0, false, true)
		K.TAKEN:
			player.take_damage(2.0 + armor)
		K.TAKEN_HEAVY:
			player.take_damage(player.max_hp() * 0.3 + armor)
		K.HEAL:
			player.heal(10.0, true)
	player.hp = player.max_hp()
	return game.fx.numbers.events > events and int(game.fx.last_number().get("kind", -1)) == kind


func _test_persistence() -> void:
	Settings.set_value("damage_show_crit", false)
	Settings.set_value("damage_show_dot", false)
	Settings.load_settings()
	_check.call(Settings.get_value("damage_show_crit") == false and Settings.get_value("damage_show_dot") == false
			and Settings.get_value("damage_show_hit") == true, "opções por tipo: gravar e ler mantém cada uma")
	# Save antigo (versão 2, sem as chaves por tipo): todas visíveis.
	var config := ConfigFile.new()
	config.set_value("settings", "damage_numbers", true)
	config.set_value("settings", "colorblind", false)
	config.set_value("meta", "version", 2)
	config.save(Settings.path)
	Settings.load_settings()
	var all := true
	for key: String in DamagePalette.SETTING_KEYS:
		all = all and Settings.get_value(key) == true
	_check.call(all, "opções por tipo: save antigo sem as chaves mostra todos os tipos")
	_all_on()


# --- Tela de Opções ---------------------------------------------------------------------------

func _test_options_screen() -> void:
	var host := Control.new()
	host.size = Vector2(678, 305)
	_host.add_child(host)
	var screen := (load(OPTIONS_SCREEN) as GDScript).new() as Control
	host.add_child(screen)
	await _host.get_tree().process_frame
	await _host.get_tree().process_frame
	var box := screen.find_child("opt_damage_types", true, false) as Control
	_check.call(box != null, "Opções: bloco dos números por tipo")
	if box != null:
		_check.call(box.get_parent() == screen.find_child("opt_damage_numbers", true, false).get_parent().get_parent(),
				"Opções: números por tipo logo abaixo da opção geral")
		for kind: int in range(K.size()):
			var key: String = DamagePalette.SETTING_KEYS[kind]
			var toggle := screen.find_child("opt_%s" % key, true, false) as BaseButton
			var row := toggle.get_parent() if toggle else null
			var sample := row.find_child("sample_%d" % kind, false, false) as Label if row else null
			_check.call(toggle != null and toggle.button_pressed and sample != null, "Opções: linha de %s" % key)
			if sample == null:
				continue
			_check.call(sample.text == DamagePalette.text(kind, DamagePalette.SAMPLE_AMOUNTS[kind])
					and sample.get_theme_color("font_color") == DamagePalette.NORMAL[kind]["fill"],
					"Opções: amostra de %s na cor do tipo" % key)
		Settings.set_value("colorblind", true)
		var sample0 := box.find_child("sample_%d" % K.CRIT, true, false) as Label
		_check.call(sample0.get_theme_color("font_color") == DamagePalette.COLORBLIND[K.CRIT]["fill"],
				"Opções: amostras seguem a paleta de daltonismo na hora")
		Settings.set_value("colorblind", false)
		Settings.set_value("damage_numbers", false)
		var locked := true
		for key: String in DamagePalette.SETTING_KEYS:
			var t := screen.find_child("opt_%s" % key, true, false) as BaseButton
			locked = locked and t.disabled and t.get_parent().modulate.a < 0.6
		_check.call(locked, "Opções: geral desligada trava e apaga as linhas por tipo")
		Settings.set_value("damage_numbers", true)
		var crit := screen.find_child("opt_damage_show_crit", true, false) as BaseButton
		_check.call(not crit.disabled and crit.get_parent().modulate.a == 1.0, "Opções: geral ligada destrava as linhas")
		crit.button_pressed = false
		_check.call(Settings.get_value("damage_show_crit") == false, "Opções: a chave do crítico grava na hora")
		crit.button_pressed = true
	host.queue_free()
	await _host.get_tree().process_frame
	_all_on()


# --- Estresse -----------------------------------------------------------------------------

## 500 inimigos, armas diretas, de área e contínuas, com crítico: nunca passa do limite.
func _test_stress() -> void:
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
	game.player.stats.set_source("test_crit", {"crit": 0.3})
	game.player.stats.recalculate()
	var worst := 0
	var crits := 0
	var events := game.fx.numbers.events
	for frame: int in range(90):
		for _k: int in range(4):
			GameClock.game_time += STEP
			game._on_tick(STEP)
			if game.hud.overlay_open():
				game.hud.bot_answer()
			worst = maxi(worst, game.fx.numbers.live)
		crits = maxi(crits, game.fx.numbers.count(K.CRIT))
		await _host.get_tree().process_frame
	_check.call(worst <= MAX, "estresse: no máximo %d números vivos com 500 inimigos (pior %d)" % [MAX, worst])
	_check.call(game.fx.numbers.events - events > MAX, "estresse: os números continuam aparecendo")
	_check.call(crits > 0, "estresse: críticos aparecem com a tela cheia")
	game.player.stats.remove_source("test_crit")
	game.queue_free()
	GameClock.paused = false
	await _host.get_tree().process_frame
