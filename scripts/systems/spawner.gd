class_name Spawner
extends RefCounted
## Diretor de ondas (plano 5.2): mistura de inimigos por faixa de tempo, eventos marcados
## (enxame, cerco, elite, procissão, tambores), chefes e santuários Kami nos minutos
## definidos em data/stages.json, amanhecer aos 15:00 e Shinigami aos 20:00 (Noite Sem Fim).
## Os três níveis da fase (RiftPortal): na fase, o Guardião do Limiar ("midboss", hora fixa); no
## Kakuriyo, a Sombra do Guardião ("midboss2") em shadow_time, relativo à chegada; no Tokoyo, o
## último chefe da lista "bosses" em final_time, relativo à chegada (quem não chega ao Tokoyo
## não o vê). Os Guardiões vêm com um aviso RiftPortal.WARN_LEAD s antes, o último chefe com o
## "final.awakens" FINAL_WARN s antes; na entrada deles e em cada chegada, hush() segura os comuns
## por alguns segundos. O chefe dos 5:00, o Kami, os eventos e as ondas valem em todo nível.
##
## Nasce quem falta para o alvo, logo além da borda da tela e dentro de um orçamento
## por segundo (Progression.spawn_rate), para não virar uma torneira infinita de XP.

const INTERVAL := 0.25
const MAX_PER_TICK := 20
const MOVE_BIAS := 0.6
const EDGE_MARGIN_MIN := 16.0
const EDGE_MARGIN_MAX := 40.0
const BUDGET_MAX_SECONDS := 2.0
const SHINIGAMI_TIME := 1200.0
## No teste de estresse a horda não pode morrer, para medir sempre a horda cheia.
const STRESS_HP_MULT := 100000.0
## O último chefe nasce no Tokoyo pelo menos FINAL_AFTER s depois da chegada; o aviso dele vem
## FINAL_WARN s antes da entrada.
const FINAL_AFTER := 8.0
const FINAL_WARN := 4.0

var game: HyakkiGame
var cap: int = 500
## Teste de estresse: ignora a curva e mantém esta quantidade (0 = curva normal).
var fixed_target: int = 0
var drums: bool = false

var _timer: float = 0.0
var _budget: float = 0.0
var _events: Array[Dictionary] = []
var _shinigami_done: bool = false
## Segundos sem nascer inimigos comuns (entrada do Guardião, chegada ao outro mundo).
var _hush: float = 0.0


func _init(p_game: HyakkiGame) -> void:
	game = p_game


func reset() -> void:
	_timer = 0.0
	_budget = float(Progression.target_count(0.0, cap))
	drums = false
	_shinigami_done = false
	_hush = 0.0
	_events.clear()
	var stage := game.stage
	var elites := 0
	for e: Variant in stage.get("events", []):
		var event: Dictionary = (e as Dictionary).duplicate()
		event["done"] = false
		if String(event["type"]) == "elite":
			# Lua Vermelha I+: mais elites por evento (RedMoon.elite_count, sem sorteio).
			event["elites"] = RedMoon.elite_count(elites, game.moon)
			elites += 1
		_events.append(event)
	# O último chefe da lista (o das 10:00) só nasce no Tokoyo (on_arrival); os outros entram
	# calados na hora marcada (o Dragão de Cinzas aos 5:00 do Santuário Secreto também).
	var boss_list: Array = stage.get("bosses", [])
	for i: int in boss_list.size() - 1:
		var b: Dictionary = boss_list[i]
		_events.append({"t": float(b["t"]), "type": "boss", "boss": b["id"], "done": false, "dialogue": false})
	for t: Variant in stage.get("kami", []):
		_events.append({"t": float(t), "type": "kami", "done": false})
	var mid := RiftPortal.midboss_of(stage)
	if not mid.is_empty():
		_events.append({"t": float(mid["t"]) - RiftPortal.WARN_LEAD, "type": "midboss_warn", "done": false})
		_events.append({"t": float(mid["t"]), "type": "midboss", "boss": mid["id"], "done": false})
	_sort_events()


func _sort_events() -> void:
	_events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t"]) < float(b["t"]))


## Hora em que a Sombra do Guardião nasce no Kakuriyo para quem chegou em `arrived`:
## max(midboss2.t, chegada + midboss2.after).
static func shadow_time(stage: Dictionary, arrived: float) -> float:
	var mid2 := RiftPortal.midboss2_of(stage)
	return maxf(float(mid2.get("t", 0.0)), arrived + float(mid2.get("after", 0.0)))


## Hora em que o último chefe nasce no Tokoyo para quem chegou em `arrived`:
## max(t do chefe, chegada + FINAL_AFTER).
static func final_time(stage: Dictionary, arrived: float) -> float:
	return maxf(float(RiftPortal.final_boss_of(stage).get("t", 0.0)), arrived + FINAL_AFTER)


## Chegada a um nível (RiftPortal.enter_realm, também na retomada): agenda o chefe do nível
## relativo à chegada (a Sombra no Kakuriyo, o último chefe no Tokoyo) com o aviso antes. O que
## a agenda de um nível anterior deixou pendente sai; o que já passou (retomada) conta como feito.
func on_arrival(depth: int, arrived: float) -> void:
	var stage := game.rift.base_stage if not game.rift.base_stage.is_empty() else game.stage
	_events.assign(_events.filter(func(e: Dictionary) -> bool: return not e.has("depth") or bool(e["done"])))
	var added: Array[Dictionary] = []
	if depth == RiftPortal.DEPTH_KAKURIYO:
		var mid2 := RiftPortal.midboss2_of(stage)
		if not mid2.is_empty():
			var t := shadow_time(stage, arrived)
			added.append({"t": t - RiftPortal.WARN_LEAD, "type": "midboss_warn", "tier": 2})
			added.append({"t": t, "type": "midboss", "boss": mid2["id"]})
	elif depth >= RiftPortal.DEPTH_TOKOYO:
		var last := RiftPortal.final_boss_of(stage)
		if not last.is_empty():
			var t := final_time(stage, arrived)
			added.append({"t": t - FINAL_WARN, "type": "final_warn"})
			added.append({"t": t, "type": "final", "boss": last["id"]})
	var now := GameClock.game_time
	for event: Dictionary in added:
		event["depth"] = depth
		event["done"] = float(event["t"]) < now
		_events.append(event)
	_sort_events()


func step(dt: float) -> void:
	var time := GameClock.game_time
	if fixed_target <= 0:
		for event: Dictionary in _events:
			if not bool(event["done"]) and time >= float(event["t"]):
				event["done"] = true
				_run_event(event)
		if game.endless_phase and not _shinigami_done and time >= SHINIGAMI_TIME:
			_shinigami_done = true
			game.bosses.spawn(&"shinigami")
			game.hud.toast(tr("endless.shinigami"))
	if _hush > 0.0:
		_hush -= dt
		return
	_timer -= dt
	if _timer > 0.0:
		return
	_timer += INTERVAL
	var minute := time / 60.0
	var stress := fixed_target > 0
	var target := fixed_target if stress else roundi(Progression.target_count(minute, cap) * game.spawn_mult())
	target = mini(target, cap)
	var missing := target - game.enemies.count_common
	var rate := Progression.spawn_rate(minute) * game.spawn_mult()
	_budget = minf(_budget + rate * INTERVAL, rate * BUDGET_MAX_SECONDS)
	if missing <= 0:
		return
	var count := mini(missing, MAX_PER_TICK)
	if not stress:
		count = mini(count, floori(_budget))
		_budget -= count
	var hp_mult := STRESS_HP_MULT if stress else game.enemy_hp_mult()
	var damage_mult := game.enemy_damage_mult()
	for _k: int in range(count):
		var id := _pick_type(time)
		game.enemies.spawn(id, RedMoon.spawn_point(game, id), hp_mult, damage_mult)


func _run_event(event: Dictionary) -> void:
	match String(event["type"]):
		"swarm":
			swarm(StringName(event["enemy"]), int(event.get("count", 16)))
		"ring":
			ring(StringName(event["enemy"]), int(event.get("count", 36)))
		"elite":
			for _k: int in range(int(event.get("elites", 1))):
				game.enemies.spawn(StringName(event["enemy"]), edge_point(), game.enemy_hp_mult(),
						game.enemy_damage_mult(), true)
		"procession":
			procession(StringName(event["enemy"]), int(event.get("count", 60)))
			game.hud.toast(tr("event.procession"))
			AudioManager.play("j_taiko_rim")
		"drums":
			drums = true
			game.hud.toast(tr("event.drums"))
			AudioManager.play("alert3", 0.7)
			AudioManager.play("taiko")
		"boss":
			game.bosses.spawn(StringName(event["boss"]), bool(event.get("dialogue", false)))
		"kami":
			game.kami.spawn_shrine()
		"midboss_warn":
			game.rift.warn_midboss(int(event.get("tier", 1)))
		"midboss":
			game.rift.spawn_midboss(StringName(event["boss"]))
		"final_warn":
			game.rift.warn_final()
		"final":
			game.rift.spawn_final(StringName(event["boss"]))


## Segura os comuns por `seconds` (eventos e chefes seguem): um respiro para uma entrada.
func hush(seconds: float) -> void:
	_hush = maxf(_hush, seconds)


## Ponto logo além da borda visível da tela, numa direção sorteada (com viés para
## onde a guardiã está indo). A borda da tela, e não um círculo pela diagonal,
## importa numa tela larga 20:9: senão quem nasce acima ou abaixo demora a chegar.
func edge_point() -> Vector2:
	var rng := game.rng
	var moving := game.player.velocity
	var angle: float
	if moving.length() > 1.0 and rng.randf() < MOVE_BIAS:
		angle = moving.angle() + rng.randf_range(-0.9, 0.9)
	else:
		angle = rng.randf() * TAU
	var p := _edge_in_direction(Vector2.from_angle(angle),
			rng.randf_range(EDGE_MARGIN_MIN, EDGE_MARGIN_MAX))
	return game.world.clamp_to_bounds(p)


func _edge_in_direction(dir: Vector2, margin: float) -> Vector2:
	var half := game.view_size() * 0.5 + Vector2.ONE * margin
	var tx := INF if absf(dir.x) < 0.0001 else half.x / absf(dir.x)
	var ty := INF if absf(dir.y) < 0.0001 else half.y / absf(dir.y)
	return game.player.sim_pos + dir * minf(tx, ty)


## Enxame: atravessa a tela em linha reta, sem perseguir (plano 6.1).
func swarm(id: StringName, count: int) -> void:
	var dir := Vector2.from_angle(game.rng.randf() * TAU)
	var start := _edge_in_direction(-dir, 30.0)
	var side := dir.orthogonal()
	for k: int in range(count):
		var at := start + side * (k - count * 0.5) * 10.0 - dir * game.rng.randf_range(0.0, 40.0)
		var i := game.enemies.spawn(id, at, game.enemy_hp_mult(), game.enemy_damage_mult())
		if i >= 0:
			game.enemies.ai_dir[i] = dir
			game.enemies.marching[i] = 1


## Cerco: um anel fechado que se aperta em volta da guardiã (plano 5.2).
func ring(id: StringName, count: int) -> void:
	var r := game.view_size().y * 0.5 + 40.0
	for k: int in range(count):
		var at := game.player.sim_pos + Vector2.from_angle(TAU * k / count) * r
		game.enemies.spawn(id, game.world.clamp_to_bounds(at), game.enemy_hp_mult(), game.enemy_damage_mult())


## Procissão: uma coluna maciça atravessa o mapa — fuja ou corte (plano 5.2).
func procession(id: StringName, count: int) -> void:
	var dir := Vector2.RIGHT if game.rng.randf() < 0.5 else Vector2.LEFT
	var start := _edge_in_direction(-dir, 30.0)
	var rows := 6
	for k: int in range(count):
		var row := k % rows
		var col := k / rows
		var at := start + Vector2(0, (row - rows * 0.5) * 12.0) - dir * col * 14.0
		var i := game.enemies.spawn(id, at, game.enemy_hp_mult(), game.enemy_damage_mult())
		if i >= 0:
			game.enemies.ai_dir[i] = dir
			game.enemies.marching[i] = 1


## Inimigo comum da onda de `time` (sorteio com game.rng): emboscada dos altares.
func pick_type(time: float) -> StringName:
	return _pick_type(time)


func _pick_type(time: float) -> StringName:
	var waves: Array = game.stage.get("waves", [])
	var mix: Dictionary = {}
	for wave: Variant in waves:
		var w: Dictionary = wave
		if time >= float(w["from"]) and time < float(w["to"]):
			mix = w["mix"]
			break
	if mix.is_empty() and not waves.is_empty():
		mix = (waves[waves.size() - 1] as Dictionary)["mix"]
	var total := 0.0
	for id: String in mix:
		total += float(mix[id])
	var roll := game.rng.randf() * total
	for id: String in mix:
		roll -= float(mix[id])
		if roll <= 0.0:
			return StringName(id)
	return &"slime_rice"


## Partida retomada (plano 10.11): eventos anteriores ao tempo salvo contam como feitos.
func skip_until(time: float) -> void:
	for event: Dictionary in _events:
		if float(event["t"]) < time:
			event["done"] = true
	_budget = float(Progression.target_count(time / 60.0, cap))
