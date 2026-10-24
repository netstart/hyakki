extends RefCounted
## Som das armas: prioridade de canais no AudioManager (acertos não calam o golpe das armas),
## grupos de variações novos, Katana em camadas, farfalhar da Ofuda enquanto gira e um som
## de toda arma de data/weapons.json em poucos segundos de simulação.
## Chamado por tests/integration_tests.gd, que passa o nó da cena e o _check.

const GAME_SCENE := "res://scenes/game/Game.tscn"
const HIT_IDS := ["hit", "crit", "hit_blade", "hit_projectile", "hit_fire", "hit_thunder", "hit_wind",
		"hit_area", "hit_orbit", "hit_poison"]
const OTHER_IDS := ["slash", "whoosh", "katana", "paper_flutter", "bell", "ui_move", "ui_accept",
		"ofuda_cast", "zap", "thunder"]
const DT := 0.05
const SLOW_PITCH := 0.01
## Distância dos alvos: dentro do alcance de toda arma que só soa ao acertar (o Incenso
## alcança 30 + 5 px do raio do inimigo).
const TARGET_DIST := 24.0


func run(host: Node, check: Callable) -> void:
	_test_groups(check)
	_test_pool_priority(check)
	var scene := load(GAME_SCENE) as PackedScene
	var game := scene.instantiate() as HyakkiGame
	game.config = {"hero": "goro", "stage": "bamboo", "moon": 0, "mode": "normal", "seed": 13, "speed": 1}
	host.add_child(game)
	await host.get_tree().process_frame
	game.player.god_mode = true
	_test_katana(game, check)
	_test_ofuda(game, check)
	_test_every_weapon(game, check)
	AudioManager.stop_sfx()
	game.queue_free()
	GameClock.paused = false
	await host.get_tree().process_frame


## Grupos novos registrados, cada arquivo carrega como som e os ids de acerto são reconhecidos.
func _test_groups(check: Callable) -> void:
	for group: String in ["katana", "ofuda_fan", "paper_flutter", "paper_fold", "arrow", "bow", "slash", "whoosh"]:
		check.call(AudioManager.VARIANTS.has(group), "grupo de som %s registrado" % group)
		for file: String in AudioManager.VARIANTS.get(group, []):
			check.call(AudioManager._sfx(file) is AudioStream, "som %s do grupo %s carrega" % [file, group])
	for weak: String in ["slash", "whoosh"]:
		check.call(not (AudioManager.VARIANTS[weak] as Array).has(weak),
				"grupo %s sem o arquivo fraco %s.wav" % [weak, weak])
	for id: String in HIT_IDS:
		check.call(AudioManager.is_hit(id), "%s é som de acerto" % id)
	for id: String in OTHER_IDS + ["player_hurt", "alert"]:
		check.call(not AudioManager.is_hit(id), "%s não é som de acerto" % id)
	check.call(AudioManager.POOL_SIZE == 32, "pool de efeitos com 32 canais")


## Toca `id` ignorando o intervalo mínimo por id (30 ms reais), para encher o pool num quadro.
## Tom SLOW_PITCH: o som dura 100x mais, para nenhum acabar no servidor de áudio (em outra
## thread, em tempo real) no meio da contagem e soltar um canal ao acaso.
func _play_now(id: String) -> void:
	(AudioManager.get("_last_play_ms") as Dictionary).clear()
	AudioManager.play(id, SLOW_PITCH, 0.0, -40.0)


func _count_hits(ids: Array[String]) -> int:
	var count := 0
	for id: String in ids:
		if AudioManager.is_hit(id):
			count += 1
	return count


func _test_pool_priority(check: Callable) -> void:
	# Só acertos: param no teto de 2/3 do pool.
	AudioManager.stop_sfx()
	for k: int in range(AudioManager.POOL_SIZE + 8):
		_play_now(HIT_IDS[k % HIT_IDS.size()])
	var active := AudioManager.active_sounds()
	check.call(active.size() == AudioManager.MAX_HIT_PLAYERS,
			"acertos ocupam no máximo %d canais (%d)" % [AudioManager.MAX_HIT_PLAYERS, active.size()])
	# Completa o pool com outros sons: cabem nos canais livres.
	var k := 0
	while AudioManager.active_sounds().size() < AudioManager.POOL_SIZE and k < 80:
		_play_now(OTHER_IDS[k % OTHER_IDS.size()])
		k += 1
	active = AudioManager.active_sounds()
	check.call(active.size() == AudioManager.POOL_SIZE, "pool cheio de acertos e outros sons")
	# Pool cheio: o golpe da arma ainda toca, roubando um acerto.
	AudioManager.stop_sfx()
	for i: int in range(AudioManager.MAX_HIT_PLAYERS):
		_play_now(HIT_IDS[i % HIT_IDS.size()])
	k = 0
	while AudioManager.active_sounds().size() < AudioManager.POOL_SIZE and k < 80:
		_play_now(["ui_move", "ui_accept", "zap", "thunder"][k % 4])
		k += 1
	var hits_before := _count_hits(AudioManager.active_sounds())
	_play_now("katana")
	active = AudioManager.active_sounds()
	check.call(active.has("katana"), "pool cheio de acertos: o som da arma ainda toca")
	check.call(_count_hits(active) == hits_before - 1 and active.size() == AudioManager.POOL_SIZE,
			"o som da arma rouba exatamente um acerto (%d -> %d)" % [hits_before, _count_hits(active)])
	var counts := AudioManager.get("_playing_ids") as Dictionary
	var total := 0
	for id: String in counts:
		total += int(counts[id])
	check.call(total == AudioManager.POOL_SIZE, "contagem por id acompanha o roubo (%d)" % total)
	# Pool cheio só de outros sons: um acerto não rouba ninguém.
	AudioManager.stop_sfx()
	k = 0
	while AudioManager.active_sounds().size() < AudioManager.POOL_SIZE and k < 80:
		_play_now(OTHER_IDS[k % OTHER_IDS.size()])
		k += 1
	_play_now("hit")
	_play_now("crit")
	active = AudioManager.active_sounds()
	check.call(_count_hits(active) == 0 and active.size() == AudioManager.POOL_SIZE,
			"acerto não rouba canal de som que não é acerto")
	AudioManager.stop_sfx()


func _requests(id: String) -> int:
	return int(AudioManager.request_count.get(id, 0))


## Pedidos de som que não são de acerto (os acertos vêm do deal_damage, não da arma).
func _weapon_requests() -> int:
	var total := 0
	for id: String in AudioManager.request_count:
		if not AudioManager.is_hit(id):
			total += int(AudioManager.request_count[id])
	return total


func _test_katana(game: HyakkiGame, check: Callable) -> void:
	var origin := game.player.sim_pos
	var katana := game._make_weapon(&"katana")
	var before := {"katana": _requests("katana"), "slash": _requests("slash"),
			"whoosh": _requests("whoosh"), "bell": _requests("bell")}
	katana.fire(origin)
	check.call(_requests("katana") == int(before["katana"]) + 1, "Katana toca o shing metálico")
	check.call(_requests("slash") == int(before["slash"]) + 1, "Katana toca o swish do corte")
	check.call(_requests("whoosh") == int(before["whoosh"]) and _requests("bell") == int(before["bell"]),
			"Katana de um lado só: sem camada extra nem brilho")
	katana.level_up()
	check.call(katana.amount() >= 2, "Katana nível 2 corta dos dois lados")
	before["whoosh"] = _requests("whoosh")
	before["katana"] = _requests("katana")
	katana.fire(origin)
	check.call(_requests("whoosh") == int(before["whoosh"]) + 1 and _requests("katana") == int(before["katana"]) + 1,
			"dois lados: uma camada extra só, sem dobrar o shing")
	var dawn := game._make_weapon(&"dawn_blade")
	before["bell"] = _requests("bell")
	dawn.fire(origin)
	check.call(_requests("bell") == int(before["bell"]) + 1, "Lâmina do Amanhecer soma o brilho agudo")
	check.call(AudioManager.last_requested != "", "AudioManager guarda o último som pedido")


func _test_ofuda(game: HyakkiGame, check: Callable) -> void:
	var ofuda := game._make_weapon(&"ofuda") as Ofuda
	check.call(ofuda != null, "Ofuda nasce com o comportamento Ofuda")
	if ofuda == null:
		return
	var fan := _requests("ofuda_fan")
	var cast := _requests("ofuda_cast")
	ofuda.step(DT)
	check.call(_requests("ofuda_fan") == fan + 1 and _requests("ofuda_cast") == cast + 1,
			"Ofuda: leque de papel e selo ao aparecer")
	var flutter := _requests("paper_flutter")
	var fold := _requests("paper_fold")
	var steps := 0
	while ofuda.is_active() and steps < 2000:
		ofuda.step(DT)
		steps += 1
	var active_time := steps * DT
	var heard := _requests("paper_flutter") - flutter
	check.call(heard >= 2, "Ofuda farfalha enquanto gira (%d em %.1f s)" % [heard, active_time])
	check.call(heard <= ceili(active_time / Ofuda.FLUTTER_GAP) + 1, "farfalhar respeita o intervalo mínimo")
	check.call(_requests("paper_fold") == fold + 1, "Ofuda: papel recolhendo ao sumir")
	flutter = _requests("paper_flutter")
	for _i: int in range(20):
		ofuda.step(DT)
	check.call(not ofuda.is_active() and _requests("paper_flutter") == flutter, "Ofuda em pausa fica em silêncio")
	# Barreira de Amaterasu (permanente): farfalhar contínuo.
	var barrier := game._make_weapon(&"amaterasu_barrier") as Ofuda
	flutter = _requests("paper_flutter")
	for _i: int in range(int(10.0 / DT)):
		barrier.step(DT)
	heard = _requests("paper_flutter") - flutter
	check.call(heard >= 8, "Barreira de Amaterasu farfalha sem parar (%d em 10 s)" % heard)
	check.call(_requests("paper_fold") == fold + 1, "a Barreira permanente nunca recolhe")


## Toda arma (base, evolução e união) pede ao menos um som em 6 s de simulação, com
## inimigos por perto para as que só soam ao achar alvo.
func _test_every_weapon(game: HyakkiGame, check: Callable) -> void:
	var origin := game.player.sim_pos
	for i: int in range(EnemyManager.CAPACITY):
		if game.enemies.alive[i] == 1:
			game.enemies.despawn(i)
	var targets: Array[int] = []
	for k: int in range(8):
		targets.append(game.enemies.spawn(&"slime_rice", origin + Vector2.from_angle(TAU * k / 8.0) * TARGET_DIST,
				100000.0, 1.0))
	game.enemies.spatial.clear()
	for i: int in range(EnemyManager.CAPACITY):
		if game.enemies.alive[i] == 1:
			game.enemies.spatial.insert(i, game.enemies.pos[i])
	var ids := DB.ids("weapons")
	check.call(ids.size() >= 30, "todas as armas do weapons.json entram no teste (%d)" % ids.size())
	for id: StringName in ids:
		var weapon := game._make_weapon(id)
		if weapon == null:
			check.call(false, "%s nasce com comportamento" % id)
			continue
		var before := _weapon_requests()
		for _i: int in range(int(6.0 / DT)):
			weapon.step(DT)
		check.call(_weapon_requests() > before, "%s toca som próprio em 6 s" % id)
		weapon.on_removed()
	for j: int in targets:
		if j >= 0 and game.enemies.alive[j] == 1:
			game.enemies.despawn(j)
	game.areas.reset()
