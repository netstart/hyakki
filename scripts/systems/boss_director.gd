class_name BossDirector
extends Node2D
## Chefes (plano 6.3): barra de vida no topo, nome em letreiro, 2–3 padrões avisados
## no chão (≥ 0,7 s), fases por vida (Kuroe, Izanami) e fúria (Oni Vermelho).
## O chefe fica no array do EnemyManager (as armas acertam nele), mas é movido aqui.

const MOVE_TIME := 1.7
const ENTRY_DISTANCE := 1.15

var game: HyakkiGame
var bosses: Array[Dictionary] = []

var _near: Array[int] = []


func reset() -> void:
	bosses.clear()


func active_count() -> int:
	return bosses.size()


func spawn(id: StringName) -> void:
	var data: Dictionary = DB.bosses.get(id, {})
	if data.is_empty():
		return
	var at := game.spawner.edge_point() if id != &"shinigami" else \
			game.player.sim_pos + Vector2.from_angle(game.rng.randf() * TAU) * 260.0
	var index := game.enemies.spawn(id, at, game.boss_hp_mult(), game.enemy_damage_mult())
	if index < 0:
		return
	var boss := {"id": id, "index": index, "data": data, "state": "move", "timer": MOVE_TIME,
			"pattern": 0, "phase": -1, "sub": 0.0, "dir": Vector2.ZERO, "line": [],
			"spiral_angle": 0.0, "decoys": [], "enraged": false}
	bosses.append(boss)
	game.hud.show_boss(tr("boss.%s.name" % id), tr("boss.%s.line" % id))
	AudioManager.play_music(String(data.get("music", "boss_a")))
	AudioManager.play("alert3")
	AudioManager.play("taiko")
	Events.boss_spawned.emit(id)


func step(dt: float) -> void:
	for k: int in range(bosses.size() - 1, -1, -1):
		var boss := bosses[k]
		var i := int(boss["index"])
		var enemies := game.enemies
		if enemies.alive[i] == 0 or enemies.type_ids[enemies.kind[i]] != StringName(boss["id"]):
			# Sai da lista antes: on_boss_defeated volta à música da fase se não restar chefe.
			bosses.remove_at(k)
			_on_dead(boss)
			continue
		_update_phase(boss)
		_step_boss(boss, dt)
	game.hud.update_boss(_bar_fraction())


func _bar_fraction() -> float:
	if bosses.is_empty():
		return -1.0
	var i := int(bosses[0]["index"])
	if bool(bosses[0]["data"].get("invincible", false)):
		return 1.0
	return clampf(game.enemies.hp[i] / maxf(game.enemies.max_hp[i], 1.0), 0.0, 1.0)


func _patterns(boss: Dictionary) -> Array:
	var data: Dictionary = boss["data"]
	if data.has("phases"):
		var phases: Array = data["phases"]
		return phases[maxi(0, int(boss["phase"]))]["patterns"]
	return data.get("patterns", [])


func _update_phase(boss: Dictionary) -> void:
	var data: Dictionary = boss["data"]
	var i := int(boss["index"])
	var fraction := game.enemies.hp[i] / maxf(game.enemies.max_hp[i], 1.0)
	if data.has("phases"):
		var phases: Array = data["phases"]
		var phase := 0
		for p: int in range(phases.size()):
			if fraction <= float(phases[p]["below"]):
				phase = p
		if phase != int(boss["phase"]):
			boss["phase"] = phase
			boss["pattern"] = 0
			if phase > 0:
				game.hud.toast(tr("boss.%s.phase%d" % [boss["id"], phase]))
				game.fx.add_ring(game.enemies.pos[i], 140.0, Color(0.7, 0.6, 1.0))
				game.shake(3.0)
	var enrage: Dictionary = data.get("enrage", {})
	if not enrage.is_empty() and not bool(boss["enraged"]) and fraction <= float(enrage["below"]):
		boss["enraged"] = true
		game.hud.toast(tr("boss.enraged"))
		AudioManager.play("alert")


func _speed(boss: Dictionary) -> float:
	var s := float(boss["data"].get("speed", 30))
	if bool(boss["enraged"]):
		s *= float(boss["data"]["enrage"].get("speed", 1.5))
	return s * game.enemies.speed_mult


func _step_boss(boss: Dictionary, dt: float) -> void:
	var enemies := game.enemies
	var i := int(boss["index"])
	var me: Vector2 = enemies.pos[i]
	var target := game.player.sim_pos
	var to := target - me
	if enemies.freeze_time > 0.0 or enemies.stun[i] > 0.0:
		enemies.stun[i] = maxf(0.0, enemies.stun[i] - dt)
		return
	boss["timer"] = float(boss["timer"]) - dt
	match String(boss["state"]):
		"move":
			var v := to.normalized() * _speed(boss)
			enemies.vel[i] = v
			enemies.pos[i] = game.world.clamp_to_bounds(me + v * dt)
			enemies.facing[i] = SpriteSheet.dir_from_vector(v, enemies.facing[i])
			if float(boss["timer"]) <= 0.0 and not _patterns(boss).is_empty():
				_start_pattern(boss)
			elif float(boss["timer"]) <= 0.0:
				boss["timer"] = MOVE_TIME
		"windup":
			enemies.vel[i] = Vector2.ZERO
			if float(boss["timer"]) <= 0.0:
				_release(boss)
		"charge":
			var v: Vector2 = boss["dir"]
			enemies.vel[i] = v
			enemies.pos[i] = game.world.clamp_to_bounds(me + v * dt)
			if float(boss["timer"]) <= 0.0:
				_back_to_move(boss)
		"spiral":
			boss["sub"] = float(boss["sub"]) - dt
			var p: Dictionary = boss["current"]
			if float(boss["sub"]) <= 0.0:
				boss["sub"] = float(p.get("rate", 0.1))
				var arms := int(p.get("arms", 3))
				boss["spiral_angle"] = float(boss["spiral_angle"]) + 0.35
				for a: int in range(arms):
					var angle := float(boss["spiral_angle"]) + TAU * a / float(arms)
					game.enemy_shots.spawn(me, Vector2.from_angle(angle) * float(p.get("speed", 80)),
							float(p.get("damage", 7)) * game.enemy_damage_mult(), String(p.get("projectile", "spirit_orb")),
							5.0, 0.0, StringName(boss["id"]))
			if float(boss["timer"]) <= 0.0:
				_back_to_move(boss)
		"hidden":
			if float(boss["timer"]) <= 0.0:
				enemies.submerged[i] = 0
				_back_to_move(boss)
	_step_decoys(boss, dt)


func _start_pattern(boss: Dictionary) -> void:
	var patterns := _patterns(boss)
	var p: Dictionary = patterns[int(boss["pattern"]) % patterns.size()]
	boss["pattern"] = int(boss["pattern"]) + 1
	boss["current"] = p
	var enemies := game.enemies
	var i := int(boss["index"])
	var me: Vector2 = enemies.pos[i]
	var target := game.player.sim_pos
	var dmg_mult := game.enemy_damage_mult()
	var src := StringName(boss["id"])
	match String(p["type"]):
		"charge":
			boss["state"] = "windup"
			boss["timer"] = float(p.get("windup", 0.8))
			boss["dir"] = (target - me).normalized()
			boss["line"] = [me, me + (boss["dir"] as Vector2) * float(p.get("speed", 200)) * float(p.get("duration", 1.0))]
			AudioManager.play("alert", 1.2, 0.0, -4.0)
		"slam":
			boss["state"] = "windup"
			boss["timer"] = float(p.get("windup", 0.9))
			boss["slam_at"] = target
			game.areas.telegraph(target, float(p.get("radius", 70)), float(p.get("windup", 0.9)),
					float(p.get("damage", 12)) * dmg_mult, Callable(), Color(1.0, 0.25, 0.25), src)
		"dive":
			boss["state"] = "hidden"
			enemies.submerged[i] = 1
			var windup := float(p.get("windup", 1.0))
			boss["timer"] = windup + 0.1
			game.fx.play_anim("water_pillar" if StringName(boss["id"]) == &"kappa_elder" else "smoke", me, 1.5)
			game.areas.telegraph(target, float(p.get("radius", 34)), windup,
					float(p.get("damage", 12)) * dmg_mult, _land.bind(i), Color(1.0, 0.25, 0.25), src)
		"summon":
			for k: int in range(int(p.get("count", 4))):
				var at := me + Vector2.from_angle(TAU * k / float(p.get("count", 4))) * 30.0
				enemies.spawn(StringName(p["enemy"]), at, game.enemy_hp_mult(), dmg_mult)
			game.fx.play_anim("smoke", me, 2.0)
			_back_to_move(boss)
		"fan":
			var aim := (target - me).normalized()
			var count := int(p.get("count", 5))
			var spread := float(p.get("spread", 1.0))
			for k: int in range(count):
				var t := 0.0 if count == 1 else (float(k) / (count - 1) - 0.5)
				game.enemy_shots.spawn(me, aim.rotated(t * spread) * float(p.get("speed", 100)),
						float(p.get("damage", 7)) * dmg_mult, String(p.get("projectile", "energy_ball")), 5.0, 0.0, src)
			AudioManager.play("fireball", 1.0, 0.1, -6.0)
			_back_to_move(boss)
		"radial":
			var count := int(p.get("count", 12))
			var offset := game.rng.randf() * TAU
			for k: int in range(count):
				game.enemy_shots.spawn(me, Vector2.from_angle(offset + TAU * k / count) * float(p.get("speed", 85)),
						float(p.get("damage", 7)) * dmg_mult, String(p.get("projectile", "energy_ball")), 5.0, 0.0, src)
			AudioManager.play("magic1", 0.9, 0.1, -6.0)
			_back_to_move(boss)
		"homing":
			var count := int(p.get("count", 6))
			for k: int in range(count):
				game.enemy_shots.spawn(me, Vector2.from_angle(TAU * k / count) * float(p.get("speed", 70)),
						float(p.get("damage", 7)) * dmg_mult, String(p.get("projectile", "fox_fire")),
						float(p.get("duration", 4.5)), float(p.get("turn", 2.0)), src)
			_back_to_move(boss)
		"spiral":
			boss["state"] = "spiral"
			boss["timer"] = float(p.get("duration", 3.0))
			boss["sub"] = 0.0
		"pools":
			for _k: int in range(int(p.get("count", 4))):
				var at := target + Vector2.from_angle(game.rng.randf() * TAU) * game.rng.randf_range(0.0, 80.0)
				game.areas.hazard_pool(at, float(p.get("radius", 28)), float(p.get("damage", 3)) * dmg_mult,
						float(p.get("duration", 4.0)), float(p.get("slow", 0.5)), float(p.get("windup", 0.8)), src)
			_back_to_move(boss)
		"rain":
			var area := float(p.get("area", 120))
			for k: int in range(int(p.get("count", 10))):
				var at := target + Vector2.from_angle(game.rng.randf() * TAU) * game.rng.randf_range(0.0, area)
				game.areas.telegraph(at, float(p.get("radius", 18)), float(p.get("windup", 0.9)) + k * 0.08,
						float(p.get("damage", 10)) * dmg_mult, Callable(), Color(1.0, 0.25, 0.25), src)
			_back_to_move(boss)
		"spikes_line":
			var dir := (target - me).normalized()
			for k: int in range(int(p.get("count", 8))):
				var at := me + dir * (24.0 + k * float(p.get("spacing", 22)))
				game.areas.telegraph(at, float(p.get("radius", 13)), float(p.get("windup", 0.8)) + k * 0.07,
						float(p.get("damage", 10)) * dmg_mult, Callable(), Color(1.0, 0.25, 0.25), src)
			_back_to_move(boss)
		"beam":
			var start_angle := (target - me).angle() - float(p.get("sweep", 1.5)) * 0.5
			game.areas.beam(me, start_angle, float(p.get("sweep", 1.5)), float(p.get("length", 220)),
					float(p.get("width", 10)), float(p.get("windup", 1.0)), float(p.get("duration", 2.0)),
					float(p.get("damage", 14)) * dmg_mult, src)
			boss["state"] = "windup"
			boss["timer"] = float(p.get("windup", 1.0)) + float(p.get("duration", 2.0))
			boss["line"] = []
		"illusions":
			var decoys: Array = boss["decoys"]
			for k: int in range(int(p.get("count", 2))):
				var at := target + Vector2.from_angle(TAU * k / float(p.get("count", 2)) + 1.0) * 90.0
				var d := enemies.spawn(StringName(boss["id"]), at, 0.0001, 0.0)
				if d >= 0:
					enemies.decoy[d] = 1
					enemies.hp[d] = 1.0
					enemies.max_hp[d] = 1.0
					decoys.append([d, float(p.get("duration", 8.0))])
			game.fx.play_anim("spirit", me, 2.0)
			_back_to_move(boss)
		"swarm":
			game.spawner.swarm(StringName(p["enemy"]), int(p.get("count", 12)))
			_back_to_move(boss)
		"procession":
			game.spawner.procession(StringName(p["enemy"]), int(p.get("count", 24)))
			_back_to_move(boss)
		"darken":
			game.lantern.darken(float(p.get("duration", 4.0)), float(p.get("light", 0.35)))
			game.hud.toast(tr("boss.darken"))
			_back_to_move(boss)
		"extinguish":
			game.lantern.extinguished = true
			game.hud.toast(tr("boss.extinguish"))
			AudioManager.play("strange")
			_back_to_move(boss)
		_:
			_back_to_move(boss)


## Fim do aviso: solta o golpe preparado (investida ou salto).
func _release(boss: Dictionary) -> void:
	var p: Dictionary = boss.get("current", {})
	var enemies := game.enemies
	var i := int(boss["index"])
	match String(p.get("type", "")):
		"charge":
			boss["state"] = "charge"
			boss["timer"] = float(p.get("duration", 1.0))
			boss["dir"] = (boss["dir"] as Vector2) * float(p.get("speed", 200)) * enemies.speed_mult
			boss["line"] = []
			AudioManager.play("whoosh2", 0.6)
		"slam":
			enemies.pos[i] = game.world.clamp_to_bounds(boss["slam_at"])
			enemies.prev[i] = enemies.pos[i]
			game.areas.ring(&"boss", enemies.pos[i], float(p.get("radius", 70)) * 1.2, 0.0, 0.4, 0.0)
			AudioManager.play("impact3")
			_back_to_move(boss)
		_:
			_back_to_move(boss)


## Fim do mergulho: o chefe aparece onde estava o aviso.
func _land(at: Vector2, index: int) -> void:
	if game.enemies.alive[index] == 0:
		return
	game.enemies.pos[index] = at
	game.enemies.prev[index] = at
	game.enemies.submerged[index] = 0


func _back_to_move(boss: Dictionary) -> void:
	boss["state"] = "move"
	boss["timer"] = MOVE_TIME * (0.7 if bool(boss["enraged"]) else 1.0)
	boss["line"] = []


func _step_decoys(boss: Dictionary, dt: float) -> void:
	var decoys: Array = boss["decoys"]
	var enemies := game.enemies
	for k: int in range(decoys.size() - 1, -1, -1):
		var entry: Array = decoys[k]
		var d := int(entry[0])
		entry[1] = float(entry[1]) - dt
		if enemies.alive[d] == 0 or enemies.decoy[d] == 0:
			decoys.remove_at(k)
			continue
		if float(entry[1]) <= 0.0:
			enemies.despawn(d)
			decoys.remove_at(k)
			continue
		var around := game.player.sim_pos + (enemies.pos[d] - game.player.sim_pos).normalized().rotated(dt * 0.6) * 90.0
		enemies.vel[d] = (around - enemies.pos[d]) / maxf(dt, 0.001) * 0.1
		enemies.pos[d] = enemies.pos[d].lerp(around, 0.1)


func _on_dead(boss: Dictionary) -> void:
	var id := StringName(boss["id"])
	var at: Vector2 = game.enemies.pos[int(boss["index"])]
	for entry: Array in boss["decoys"]:
		if game.enemies.alive[int(entry[0])] == 1:
			game.enemies.despawn(int(entry[0]))
	game.on_boss_defeated(id, at)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	for boss: Dictionary in bosses:
		var line: Array = boss["line"]
		if line.size() == 2:
			var pulse := 0.5 + 0.5 * sin(GameClock.game_time * 20.0)
			draw_line(line[0], line[1], Color(1.0, 0.2, 0.2, 0.35 + 0.3 * pulse), 10.0)
			draw_line(line[0], line[1], Color(1.0, 0.6, 0.6, 0.6), 1.0)
