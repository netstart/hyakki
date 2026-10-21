class_name HyakkiGame
extends Node2D
## Uma partida do Hyakki. Cria os sistemas e chama cada um, em ordem fixa, a cada passo
## do GameClock (plano 4.14 e 10). A mesma semente gera a mesma partida em 1x, 2x e 3x.
##
## Argumentos de linha de comando (depois de `--`), para testes automáticos:
##   --bot  --seed=N  --speed=1|2|3  --hero=ID  --stage=ID  --moon=0..5  --mode=normal|brisa
##   --endless  --hash-at=S  --quit-at=S  --log-every=S  --stress=N
##   --screenshot-at=S  --screenshot-frame=N  --screenshot=arquivo.png  --god

signal finished(result: Dictionary)

const RUN_LENGTH := 15.0 * 60.0
const FALLBACK_VIEW := Vector2(678.0, 305.0)
const DAWN_TINT := Color(1.0, 0.96, 0.9)
const LEVEL_UP_PUSH_RADIUS := 70.0
const LEVEL_UP_PUSH_FORCE := 160.0
const SPEED_GUARD_MS := 13.0
const SPEED_GUARD_SECONDS := 5.0
const BOT_SEED := 7
const BOT_TOO_CLOSE := 9.0
const BOT_STRIKE_OFFSET := 24.0
const BOT_SIGHT_RADIUS := 400.0
const MOON_HP := 0.25
const MOON_REWARD := 0.15

var config: Dictionary = {}
var stage: Dictionary = {}
var mode: String = "normal"
var moon: int = 0
var endless_enabled: bool = false
var endless_phase: bool = false

var rng := RandomNumberGenerator.new()
var player: Player
var camera: Camera2D
var world: WorldMap
var enemies: EnemyManager
var enemy_shots: EnemyShotManager
var projectiles: ProjectileManager
var areas: AreaEffects
var pickups: PickupManager
var spawner: Spawner
var bosses: BossDirector
var kami: KamiSystem
var lantern: LanternSystem
var fx: FxLayer
var level_up: LevelUpSystem
var chests: ChestSystem
var ultimate: UltimateSystem
var tracker: RunTracker
var hud: Hud
var weapons: Array[Weapon] = []
var level: int = 1
var xp: int = 0
var xp_needed: int = 5
var step_index: int = 0
var running: bool = false
var show_hitboxes: bool = false
## Teste de estresse: quantidade fixa de inimigos (0 = desligado).
var stress_count: int = 0
# Efeitos especiais dos Kami.
var no_revive: bool = false
var chest_min: int = 1
var extra_choices: int = 0
var _tag_amount: Dictionary = {}

var _choices: Array[Dictionary] = []
var _pending_levels: int = 0
var _pending_chests: Array[bool] = []
var _bot: bool = false
var _seed: int = 0
var _quit_at: float = -1.0
var _hash_at: float = -1.0
var _hash_done: bool = false
var _log_every: int = 0
var _finished: bool = false
var _shot_at: float = -1.0
var _shot_frame: int = -1
var _shot_path: String = "user://screenshot.png"
var _over_budget: float = 0.0
var _night: CanvasModulate
var _weapon_layer: Node2D
var _shake: float = 0.0
var _ad_revive_used: bool = false
var _speed_min: int = 3
var _speed_max: int = 1
var _perf_sum_ms: float = 0.0
var _perf_worst_ms: float = 0.0
var _perf_frames: float = 0.0
var _section_worst := PackedInt64Array([0, 0, 0, 0])
var _cli_god: bool = false


func _ready() -> void:
	InputSetup.ensure_actions()
	_parse_args()
	_build()
	GameClock.ticked.connect(_on_tick)
	Events.enemy_killed.connect(_on_enemy_killed)
	if config.is_empty():
		config = _cli_config()
	start_run(config)


func _parse_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var value := arg.get_slice("=", 1)
		if arg == "--bot":
			_bot = true
		elif arg == "--god":
			_cli_god = true
		elif arg.begins_with("--seed="):
			_seed = value.to_int()
		elif arg.begins_with("--quit-at="):
			_quit_at = value.to_float()
		elif arg.begins_with("--hash-at="):
			_hash_at = value.to_float()
		elif arg.begins_with("--stress="):
			stress_count = clampi(value.to_int(), 1, EnemyManager.CAPACITY - 40)
		elif arg.begins_with("--log-every="):
			_log_every = roundi(value.to_float() / GameClock.STEP)
		elif arg.begins_with("--screenshot-at="):
			_shot_at = value.to_float()
		elif arg.begins_with("--screenshot-frame="):
			_shot_frame = value.to_int()
		elif arg.begins_with("--screenshot="):
			_shot_path = value
	if _bot and _seed == 0:
		_seed = BOT_SEED


func _cli_config() -> Dictionary:
	var cfg := {"hero": "aki", "stage": "village", "moon": 0, "mode": "normal", "endless": false,
			"speed": 1, "seed": _seed}
	for arg: String in OS.get_cmdline_user_args():
		var value := arg.get_slice("=", 1)
		if arg.begins_with("--hero="):
			cfg["hero"] = value
		elif arg.begins_with("--stage="):
			cfg["stage"] = value
		elif arg.begins_with("--moon="):
			cfg["moon"] = clampi(value.to_int(), 0, 5)
		elif arg.begins_with("--mode="):
			cfg["mode"] = value
		elif arg.begins_with("--speed="):
			cfg["speed"] = clampi(value.to_int(), 1, 3)
		elif arg == "--endless":
			cfg["endless"] = true
	return cfg


func is_bot() -> bool:
	return _bot


func _build() -> void:
	_night = CanvasModulate.new()
	add_child(_night)
	world = WorldMap.new()
	world.game = self
	add_child(world)
	kami = KamiSystem.new()
	kami.game = self
	add_child(kami)
	areas = AreaEffects.new()
	areas.game = self
	areas.z_index = -4
	add_child(areas)
	pickups = PickupManager.new()
	pickups.game = self
	add_child(pickups)
	enemies = EnemyManager.new()
	enemies.game = self
	add_child(enemies)
	player = Player.new()
	add_child(player)
	player.died.connect(_on_player_died)
	camera = Camera2D.new()
	player.add_child(camera)
	_weapon_layer = Node2D.new()
	_weapon_layer.draw.connect(_draw_weapons)
	add_child(_weapon_layer)
	projectiles = ProjectileManager.new()
	projectiles.game = self
	add_child(projectiles)
	enemy_shots = EnemyShotManager.new()
	enemy_shots.game = self
	enemy_shots.z_index = 5
	add_child(enemy_shots)
	bosses = BossDirector.new()
	bosses.game = self
	bosses.z_index = -3
	add_child(bosses)
	fx = FxLayer.new()
	fx.z_index = 10
	add_child(fx)
	lantern = LanternSystem.new()
	lantern.game = self
	add_child(lantern)
	spawner = Spawner.new(self)
	level_up = LevelUpSystem.new(self)
	chests = ChestSystem.new(self)
	ultimate = UltimateSystem.new(self)
	hud = Hud.new()
	hud.game = self
	add_child(hud)
	hud.card_chosen.connect(_on_card_chosen)
	hud.reroll_pressed.connect(_on_reroll)
	hud.skip_pressed.connect(_on_skip)
	hud.banish_pressed.connect(_on_banish)
	hud.pause_pressed.connect(open_pause)
	hud.resume_pressed.connect(close_pause)
	hud.quit_pressed.connect(func() -> void: _end_run(false, true))
	hud.speed_pressed.connect(cycle_speed)
	hud.ultimate_pressed.connect(func() -> void: ultimate.activate())
	hud.kami_chosen.connect(_on_kami_chosen)
	hud.chest_closed.connect(_on_chest_closed)
	hud.revive_answered.connect(_on_revive_answered)


func start_run(cfg: Dictionary) -> void:
	config = cfg
	_finished = false
	stage = DB.stage(StringName(cfg.get("stage", "village")))
	if stage.is_empty():
		stage = DB.stage(&"village")
	mode = String(cfg.get("mode", "normal"))
	moon = int(cfg.get("moon", 0)) if mode != "brisa" else 0
	endless_enabled = bool(cfg.get("endless", false))
	endless_phase = false
	var run_seed := int(cfg.get("seed", 0))
	if run_seed != 0:
		rng.seed = run_seed
	else:
		rng.randomize()
	var hero_id := StringName(cfg.get("hero", "aki"))
	var hero: Dictionary = DB.heroes.get(hero_id, DB.heroes[&"aki"])
	player.setup(hero)
	player.stats.set_source("powerups", {} if _bot else MetaProgress.powerup_modifiers())
	player.stats.set_source("shop", cfg.get("shop_modifiers", {}))
	if mode == "brisa":
		player.stats.set_source("mode", {"revive": 1, "magnet": 0.5})
	player.reset()
	player.god_mode = _cli_god or stress_count > 0
	player.lantern_tint = _cosmetic_tint(String(cfg.get("cosmetic", "")))
	world.setup(stage, run_seed if run_seed != 0 else rng.randi())
	enemies.reset()
	enemy_shots.reset()
	projectiles.reset()
	areas.reset()
	pickups.reset()
	fx.reset()
	bosses.reset()
	kami.reset()
	lantern.reset()
	ultimate.reset()
	tracker = RunTracker.new()
	no_revive = false
	chest_min = 1
	extra_choices = 0
	_tag_amount.clear()
	for weapon: Weapon in weapons:
		weapon.on_removed()
	weapons.clear()
	add_weapon(StringName(hero.get("weapon", "katana")))
	level_up.reset()
	level = 1
	xp = 0
	xp_needed = Progression.xp_to_next(level)
	step_index = 0
	_pending_levels = 0
	_pending_chests.clear()
	_choices.clear()
	_hash_done = false
	_over_budget = 0.0
	_ad_revive_used = false
	_night.color = Color(String(stage.get("tint", "#ffffff")))
	spawner.reset()
	if stress_count > 0:
		spawner.fixed_target = stress_count
	if int(cfg.get("ult_start", 0)) > 0:
		ultimate.charge = float(cfg["ult_start"])
	for _k: int in range(int(cfg.get("start_chest", 0))):
		_pending_chests.append(false)
	hud.start_run()
	GameClock.reset()
	GameClock.speed = clampi(int(cfg.get("speed", Settings.get_value("speed"))), 1, 3)
	_speed_min = GameClock.speed
	_speed_max = GameClock.speed
	hud.refresh_speed()
	running = true
	AudioManager.play_music(String(stage.get("music", "stage_village")))
	hud.toast(tr("stage.%s.opening" % stage["id"]), 4.0)


func _on_tick(dt: float) -> void:
	if not running:
		return
	step_index += 1
	var t0 := Time.get_ticks_usec()
	if _bot:
		player.move_input = _bot_input()
	player.step(dt)
	world.step(dt)
	spawner.step(dt)
	bosses.step(dt)
	var t1 := Time.get_ticks_usec()
	enemies.step(dt)
	var t2 := Time.get_ticks_usec()
	for weapon: Weapon in weapons.duplicate():
		weapon.step(dt)
	var t3 := Time.get_ticks_usec()
	projectiles.step(dt)
	enemy_shots.step(dt)
	areas.step(dt)
	pickups.step(dt)
	kami.step(dt)
	lantern.step(dt)
	ultimate.step(dt)
	fx.step(dt)
	tracker.step(dt, lantern.radius, player.damage_taken_time)
	var t4 := Time.get_ticks_usec()
	_note_section(0, t1 - t0)
	_note_section(1, t2 - t1)
	_note_section(2, t3 - t2)
	_note_section(3, t4 - t3)
	_logging()
	if not running:
		return
	if GameClock.game_time >= RUN_LENGTH and not endless_phase:
		_on_dawn()
		return
	if hud.overlay_open():
		return
	if not _pending_chests.is_empty():
		_open_chest(_pending_chests.pop_front())
	elif _pending_levels > 0:
		_open_level_up()


func _logging() -> void:
	if _log_every > 0 and step_index % _log_every == 0:
		print(state_summary("LOG"))
		if stress_count > 0:
			print("DESEMPENHO simulação média %.3f ms por passo, pior %.3f ms (%d passos)" % [
				_perf_sum_ms / maxf(1.0, _perf_frames), _perf_worst_ms, _perf_frames])
			print("  pior por sistema (ms): mapa+spawner+chefes %.2f | inimigos %.2f | armas %.2f | resto %.2f" % [
				_section_worst[0] / 1000.0, _section_worst[1] / 1000.0,
				_section_worst[2] / 1000.0, _section_worst[3] / 1000.0])
			_perf_sum_ms = 0.0
			_perf_worst_ms = 0.0
			_perf_frames = 0.0
			_section_worst.fill(0)
	if _hash_at > 0.0 and not _hash_done and GameClock.game_time >= _hash_at:
		_hash_done = true
		print(state_summary("ESTADO"))
	if _quit_at > 0.0 and GameClock.game_time >= _quit_at:
		_finish_headless()


func _process(delta: float) -> void:
	if not _bot:
		var wish := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
		if wish == Vector2.ZERO:
			wish = hud.joystick.vector
		player.move_input = wish
	else:
		hud.bot_answer()
		if not running and _quit_at > 0.0:
			_finish_headless()
	_handle_actions()
	_update_dawn_tint()
	_speed_guard(delta)
	_update_camera(delta)
	_weapon_layer.queue_redraw()
	AudioManager.set_low_health(running and player.is_alive and player.hp < player.max_hp() * 0.25)
	if GameClock.last_frame_steps > 0:
		var per_step := GameClock.last_sim_ms / GameClock.last_frame_steps
		_perf_sum_ms += per_step
		_perf_worst_ms = maxf(_perf_worst_ms, per_step)
		_perf_frames += 1.0
	var frame_shot := _shot_frame > 0 and Engine.get_process_frames() >= _shot_frame
	if frame_shot or (_shot_at > 0.0 and GameClock.game_time >= _shot_at):
		_shot_at = -1.0
		_shot_frame = -1
		get_viewport().get_texture().get_image().save_png(_shot_path)
		print("SCREENSHOT %s" % _shot_path)


func _handle_actions() -> void:
	if Input.is_action_just_pressed(&"pause"):
		if hud.pause_open():
			close_pause()
		elif running and not hud.overlay_open():
			open_pause()
	if Input.is_action_just_pressed(&"speed"):
		cycle_speed()
	if Input.is_action_just_pressed(&"ultimate") and running and not GameClock.paused:
		ultimate.activate()
	if Input.is_action_just_pressed(&"debug_overlay"):
		hud.toggle_debug()
	if Input.is_action_just_pressed(&"debug_hitbox"):
		show_hitboxes = not show_hitboxes
		player.show_hitbox = show_hitboxes


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and running and not _bot and not hud.overlay_open():
		open_pause()


# --- Multiplicadores (plano 4.11 e 15.3) ------------------------------------------

func minute() -> float:
	return GameClock.game_time / 60.0


func curse() -> float:
	return player.stats.get_stat("curse")


func enemy_hp_mult() -> float:
	# stage.difficulty: degrau leve por fase (os inimigos de cada fase já vêm em escala).
	var mult := Progression.enemy_hp_mult(minute()) * curse() * (1.0 + MOON_HP * moon) \
			* stage_difficulty()
	if endless_phase:
		mult *= 1.0 + 0.15 * (minute() - 15.0)
	return mult


func enemy_damage_mult() -> float:
	return Progression.enemy_damage_mult(minute()) * (1.0 + MOON_HP * 0.5 * moon) \
			* sqrt(stage_difficulty())


## Degrau da fase (data/stages.json "difficulty"), aplicado aos poucos nos primeiros
## 5 minutos para o começo de cada fase continuar jogável sem upgrades.
func stage_difficulty() -> float:
	var full := float(stage.get("difficulty", 1.0))
	return 1.0 + (full - 1.0) * clampf(minute() / 5.0, 0.0, 1.0)


func boss_hp_mult() -> float:
	return curse() * (1.0 + MOON_HP * moon) * (0.7 if mode == "brisa" else 1.0)


func spawn_mult() -> float:
	return curse() * (0.85 if mode == "brisa" else 1.0) * (1.0 + 0.05 * moon)


func reward_mult() -> float:
	return 1.0 + MOON_REWARD * moon


func damage_bonus() -> float:
	return ultimate.damage_bonus()


func hero_amount_bonus() -> int:
	var per := int(player.hero.get("amount_per_10_levels", 0))
	return per * floori(level / 10.0)


func tag_amount_bonus(tag: String) -> int:
	return int(_tag_amount.get(tag, 0))


func dawn_time() -> float:
	return RUN_LENGTH


func view_size() -> Vector2:
	var view := get_viewport_rect().size
	if view.x < 16.0:
		view = FALLBACK_VIEW
	return view


func view_half_diagonal() -> float:
	return view_size().length() * 0.5


func is_weapon_available(id: StringName) -> bool:
	return _bot or MetaProgress.is_content_available("weapons", id, DB.weapon(id))


func is_passive_available(id: StringName) -> bool:
	return _bot or MetaProgress.is_content_available("passives", id, DB.passives[id])


# --- Armas ---------------------------------------------------------------------

func add_weapon(id: StringName) -> void:
	var weapon := _make_weapon(id)
	if weapon:
		weapons.append(weapon)
		tracker.weapon_level[id] = 1


func has_weapon(id: StringName) -> bool:
	return get_weapon(id) != null


func get_weapon(id: StringName) -> Weapon:
	for weapon: Weapon in weapons:
		if weapon.id == id:
			return weapon
	return null


func evolve_weapon(id: StringName) -> void:
	var weapon := get_weapon(id)
	if weapon == null:
		return
	var evolved_id := StringName(weapon.data["evolution"])
	var index := weapons.find(weapon)
	weapon.on_removed()
	var evolved := _make_weapon(evolved_id)
	weapons[index] = evolved
	tracker.evolutions.append(evolved_id)
	tracker.weapon_level[evolved_id] = 1
	Events.weapon_evolved.emit(evolved_id)
	AudioManager.play("jingle_unlock")


func apply_union(union_id: StringName) -> void:
	var data := DB.weapon(union_id)
	var first_index := weapons.size()
	for need: Variant in data.get("requires", []):
		var weapon := get_weapon(StringName(need))
		if weapon:
			first_index = mini(first_index, weapons.find(weapon))
			weapon.on_removed()
			weapons.erase(weapon)
	var union := _make_weapon(union_id)
	weapons.insert(mini(first_index, weapons.size()), union)
	tracker.unions.append(union_id)
	AudioManager.play("jingle_unlock")


func _make_weapon(id: StringName) -> Weapon:
	var data := DB.weapon(id)
	if data.is_empty():
		return null
	match String(data.get("behavior", "")):
		"katana":
			return Katana.new(self, id)
		"shuriken":
			return Shuriken.new(self, id)
		"kunai":
			return Kunai.new(self, id)
		"ofuda":
			return Ofuda.new(self, id)
		"incense":
			return Incense.new(self, id)
		"kusarigama":
			return Kusarigama.new(self, id)
		"smoke_bomb":
			return SmokeBomb.new(self, id)
		"raijin":
			return Raijin.new(self, id)
		"fujin_fan":
			return FujinFan.new(self, id)
		"hurricane":
			return HurricaneWeapon.new(self, id)
		"yumi":
			return Yumi.new(self, id)
		"taiko":
			return Taiko.new(self, id)
		"hitodama":
			return Hitodama.new(self, id)
		"typhoon":
			return Typhoon.new(self, id)
		"blade_cyclone":
			return BladeCyclone.new(self, id)
	push_error("Arma sem comportamento: %s" % id)
	return null


func _draw_weapons() -> void:
	for weapon: Weapon in weapons:
		weapon.draw(_weapon_layer)


## Todo dano passa por aqui: crítico, registro por arma e número na tela.
func deal_damage(weapon_id: StringName, enemy: int, amount: float, dir: Vector2, force: float,
		force_crit: bool = false) -> void:
	if enemies.alive[enemy] == 0:
		return
	var crit_chance := player.stats.get_stat("crit")
	var crit := force_crit or (crit_chance > 0.0 and rng.randf() < crit_chance)
	if crit:
		amount *= 2.0
	var at := enemies.pos[enemy]
	var prop := enemies.is_prop(enemy)
	enemies.damage(enemy, amount, dir, force)
	if prop:
		return
	tracker.on_damage(weapon_id, amount)
	fx.add_number(at, amount, crit)
	AudioManager.play("hit%d" % (1 + rng.randi_range(0, 2)), 1.0, 0.08, -14.0)


# --- XP, itens e baús --------------------------------------------------------

func add_xp(amount: int) -> void:
	var gained := maxi(1, roundi(amount * player.stats.get_stat("growth") * reward_mult()))
	xp += gained
	lantern.on_ember(amount)
	ultimate.on_xp(amount)
	while xp >= xp_needed:
		xp -= xp_needed
		level += 1
		xp_needed = Progression.xp_to_next(level)
		_pending_levels += 1
		tracker.max_level = level
		Events.player_leveled.emit(level)


func add_run_ryo(amount: int) -> void:
	var gained := roundi(amount * player.stats.get_stat("greed") * reward_mult())
	tracker.ryo += gained
	AudioManager.play("gold", 1.0, 0.05, -6.0)


func collect_item(item: Dictionary) -> void:
	var id := StringName(item["id"])
	tracker.items[id] = int(tracker.items.get(id, 0)) + 1
	Events.item_collected.emit(id)
	match String(item["effect"]):
		"heal":
			player.heal(float(item["value"]))
			AudioManager.play("heal")
			fx.play_anim("aura", player.sim_pos, 1.2, 0.0, Color(0.7, 1.0, 0.7))
		"ryo":
			add_run_ryo(int(item["value"]))
		"magnet":
			pickups.magnet_all()
			AudioManager.play("magic1", 1.3)
		"bell":
			_purify_screen()
		"freeze":
			enemies.freeze_time = float(item["value"])
			AudioManager.play("strange", 1.4)
			hud.toast(tr("item.hourglass.toast"))
		"solar":
			lantern.solar_time = float(item["value"])
			ultimate.fill()
			AudioManager.play("powerup", 1.2)
		"chest":
			_pending_chests.append(bool(item.get("boss", false)))
	AudioManager.play("bonus", 1.0, 0.05, -6.0)


## Sino Purificador: elimina todos os inimigos comuns visíveis (recompensa normal).
func _purify_screen() -> void:
	var half := view_size() * 0.5 + Vector2(20, 20)
	var me := player.sim_pos
	for i: int in range(EnemyManager.CAPACITY):
		if enemies.alive[i] == 0 or enemies.is_boss(i) or enemies.is_prop(i):
			continue
		var d := enemies.pos[i] - me
		if absf(d.x) <= half.x and absf(d.y) <= half.y:
			enemies.damage(i, 999999.0, Vector2.ZERO, 0.0)
	fx.add_ring(me, half.x, Color(1.0, 1.0, 0.85))
	hud.flash_screen(Color(1.0, 1.0, 0.9))
	AudioManager.play("magic4", 1.2)


func on_prop_destroyed(index: int, at: Vector2) -> void:
	world.on_prop_destroyed(index)
	fx.burst(at, Color(0.8, 0.75, 0.6), 7)
	AudioManager.play("impact", 1.4, 0.1, -8.0)
	pickups.spawn_item(pickups.random_item_id(), at)


func _on_enemy_killed(at: Vector2, xp_value: int, color: Color, enemy_id: StringName,
		was_elite: bool, ai: int) -> void:
	if ai == EnemyManager.AI.BOSS:
		return
	tracker.on_kill(enemy_id, GameClock.game_time)
	pickups.spawn(at, xp_value)
	fx.burst(at, color)
	if was_elite:
		pickups.spawn_item(&"chest", at)
		fx.play_anim("explosion", at, 1.0)
	elif rng.randf() < 0.012 * player.stats.get_stat("luck"):
		pickups.spawn_item(&"coin", at + Vector2(4, 0))
	for weapon: Weapon in weapons:
		if weapon is Hitodama:
			(weapon as Hitodama).on_kill(at)


func on_boss_defeated(id: StringName, at: Vector2) -> void:
	tracker.bosses.append(id)
	Events.boss_defeated.emit(id)
	pickups.spawn_item(&"chest", at, {"boss": true})
	add_run_ryo(100)
	fx.play_anim("explosion", at, 3.0)
	fx.add_ring(at, 160.0, Color(1.0, 0.9, 0.6))
	shake(5.0)
	Settings.vibrate(120)
	hud.hide_boss()
	hud.toast(tr("boss.defeated") % tr("boss.%s.name" % id))
	AudioManager.play("jingle_success")
	if bosses.active_count() == 0:
		AudioManager.play_music("endless" if endless_phase else String(stage.get("music", "stage_village")))


# --- Telas sobrepostas --------------------------------------------------------

func _open_level_up() -> void:
	GameClock.paused = true
	_choices = level_up.build_choices(rng)
	hud.show_level_up(_choices, level_up.rerolls, level_up.skips, level_up.banishes)
	AudioManager.play("jingle_levelup", 1.0, 0.0, -4.0)
	AudioManager.duck(6.0, 1.2)
	Settings.vibrate(20)


func _on_card_chosen(index: int) -> void:
	if index < 0 or index >= _choices.size():
		return
	level_up.apply(_choices[index])
	_after_level_choice()


func _after_level_choice() -> void:
	_pending_levels -= 1
	# Anel de luz e empurrão nos inimigos próximos: um respiro (plano 8.5).
	enemies.push_from(player.sim_pos, LEVEL_UP_PUSH_RADIUS, LEVEL_UP_PUSH_FORCE)
	fx.add_ring(player.sim_pos, LEVEL_UP_PUSH_RADIUS)
	AudioManager.play("ui_accept")
	if _pending_levels > 0:
		_choices = level_up.build_choices(rng)
		hud.show_level_up(_choices, level_up.rerolls, level_up.skips, level_up.banishes)
		return
	hud.hide_level_up()
	_resume_if_clear()


func _on_reroll() -> void:
	if level_up.rerolls <= 0:
		return
	level_up.rerolls -= 1
	_choices = level_up.build_choices(rng)
	hud.show_level_up(_choices, level_up.rerolls, level_up.skips, level_up.banishes)


func _on_skip() -> void:
	if level_up.skips <= 0:
		return
	level_up.skips -= 1
	_after_level_choice()


func _on_banish(index: int) -> void:
	if level_up.banishes <= 0 or index < 0 or index >= _choices.size():
		return
	level_up.banish(_choices[index])
	_choices = level_up.build_choices(rng)
	hud.show_level_up(_choices, level_up.rerolls, level_up.skips, level_up.banishes)


func _open_chest(from_boss: bool) -> void:
	GameClock.paused = true
	var rewards := chests.open(from_boss)
	hud.show_chest(rewards)
	AudioManager.duck(6.0, 3.0)
	Settings.vibrate(30)


func _on_chest_closed() -> void:
	_resume_if_clear()


func open_kami(offer: Array[StringName]) -> void:
	if offer.is_empty():
		return
	GameClock.paused = true
	hud.show_kami(offer)


func _on_kami_chosen(id: StringName) -> void:
	if id != &"":
		kami.accept(id)
		tracker.kami.append(id)
	_resume_if_clear()


func apply_kami_specials(specials: Dictionary) -> void:
	no_revive = bool(specials.get("no_revive", false))
	chest_min = int(specials.get("chest_min", 1))
	extra_choices = int(specials.get("extra_choice", 0))
	player.no_regen = bool(specials.get("no_regen", false))
	var tag: Dictionary = specials.get("tag_amount", {})
	_tag_amount.clear()
	if not tag.is_empty():
		_tag_amount[String(tag["tag"])] = int(tag["value"])


func open_pause() -> void:
	if not running or hud.overlay_open():
		return
	GameClock.paused = true
	hud.show_pause()


func close_pause() -> void:
	hud.hide_pause()
	_resume_if_clear()


func _resume_if_clear() -> void:
	if running and not hud.overlay_open():
		GameClock.paused = false
		hud.countdown()


func cycle_speed() -> void:
	GameClock.cycle_speed()
	Settings.set_value("speed", GameClock.speed)
	_speed_min = mini(_speed_min, GameClock.speed)
	_speed_max = maxi(_speed_max, GameClock.speed)
	_over_budget = 0.0
	hud.refresh_speed()
	if GameClock.speed == 3 and not bool(SaveManager.data.get("speed3_hint", false)):
		SaveManager.data["speed3_hint"] = true
		hud.toast(tr("speed.hint3"))


# --- Fim da partida --------------------------------------------------------------

func _on_player_died() -> void:
	if not running:
		return
	# Reviver por anúncio: 1× por partida, só depois do Revive do Santuário, fora do
	# Desafio Diário e nunca contra o Shinigami (plano 17.6).
	var offer := not _ad_revive_used and not _bot and not bool(config.get("daily", false)) \
			and not _shinigami_present() and AdsManager.rewarded_available()
	if offer:
		GameClock.paused = true
		hud.show_revive_offer()
	else:
		_end_run(false)


func _shinigami_present() -> bool:
	for boss: Dictionary in bosses.bosses:
		if StringName(boss["id"]) == &"shinigami":
			return true
	return false


func _on_revive_answered(accept: bool) -> void:
	if not accept:
		_end_run(false)
		return
	_ad_revive_used = true
	AdsManager.show_rewarded("revive", func(rewarded: bool) -> void:
		if rewarded:
			tracker.revived_by_ad = true
			SaveManager.data["stats"]["revives_by_ad"] = int(SaveManager.data["stats"]["revives_by_ad"]) + 1
			player.revive(0.5)
			player.invuln = 3.0
			_resume_if_clear()
		else:
			_end_run(false))


func _on_dawn() -> void:
	# Amanhecer: inimigos viram cinza, vitória (plano 5.2).
	for i: int in range(EnemyManager.CAPACITY):
		if enemies.alive[i] == 1 and not enemies.is_prop(i):
			fx.burst(enemies.pos[i], Color(0.6, 0.6, 0.6), 3)
			enemies.despawn(i)
	enemy_shots.clear_all()
	bosses.reset()
	hud.hide_boss()
	AudioManager.play("jingle_success")
	if endless_enabled:
		endless_phase = true
		_record_dawn_victory()
		hud.toast(tr("endless.started"), 4.0)
		AudioManager.play_music("endless")
		return
	_end_run(true)


## Na Noite Sem Fim, a vitória da fase conta ao amanhecer, mesmo que a partida continue.
func _record_dawn_victory() -> void:
	var best := SaveManager.stage_best(StringName(stage["id"]))
	if mode == "brisa":
		best["won_brisa"] = true
	else:
		best["won"] = true
		best["max_moon"] = maxi(int(best["max_moon"]), moon)


func _end_run(victory: bool, gave_up: bool = false) -> void:
	if not running:
		return
	running = false
	GameClock.paused = true
	AudioManager.set_low_health(false)
	var result := build_result(victory or endless_phase, gave_up)
	if _bot:
		if _quit_at <= 0.0:
			print(state_summary("FIM"))
			# Reinicia no próximo quadro, fora do passo que matou a guardiã.
			start_run.call_deferred(config)
		return
	var applied := MetaProgress.apply_run(result, tracker)
	result["ryo_earned"] = applied["ryo"]
	result["new_achievements"] = applied["achievements"]
	AudioManager.play("jingle_success" if result["victory"] else "jingle_gameover")
	AudioManager.play_music("dawn" if result["victory"] else "defeat")
	finished.emit(result)


func build_result(victory: bool, gave_up: bool) -> Dictionary:
	var weapon_rows: Array[Dictionary] = []
	for weapon: Weapon in weapons:
		var total := float(tracker.damage_by_weapon.get(weapon.id, 0.0))
		weapon_rows.append({"id": weapon.id, "level": weapon.level, "damage": total,
				"dps": total / maxf(GameClock.game_time, 1.0)})
	return {"victory": victory, "gave_up": gave_up, "hero": String(player.hero["id"]),
			"stage": String(stage["id"]), "mode": mode, "moon": moon, "time": GameClock.game_time,
			"level": level, "kills": tracker.kills, "ryo_run": tracker.ryo, "weapons": weapon_rows,
			"endless": endless_phase, "daily": bool(config.get("daily", false)),
			"daily_date": String(config.get("daily_date", "")), "speed_min": _speed_min,
			"speed_max": _speed_max}


func _finish_headless() -> void:
	if _finished:
		return
	_finished = true
	print(state_summary("FIM"))
	running = false
	GameClock.paused = true
	get_tree().quit()


## Resumo do estado da simulação; o hash permite comparar partidas (plano 15.1).
func state_summary(tag: String) -> String:
	var body := "t=%.3f nivel=%d xp=%d abates=%d inimigos=%d brasas=%d vida=%.2f pos=(%.3f, %.3f) passos=%d armas=%s" % [
		GameClock.game_time, level, xp, tracker.kills, enemies.count_alive, pickups.count_alive,
		player.hp, player.sim_pos.x, player.sim_pos.y, step_index, _weapon_summary(),
	]
	return "%s %s hash=%d" % [tag, body, hash(body)]


func _weapon_summary() -> String:
	var parts: PackedStringArray = []
	for weapon: Weapon in weapons:
		parts.append("%s%d" % [weapon.id, weapon.level])
	return ",".join(parts)


# --- Câmera, amanhecer, velocidade ------------------------------------------------

func shake(amount: float) -> void:
	if bool(Settings.get_value("reduce_flashes")):
		return
	_shake = minf(3.0, maxf(_shake, amount))


func _update_camera(delta: float) -> void:
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 12.0)
		camera.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake)).round()
	else:
		camera.offset = Vector2.ZERO


func _update_dawn_tint() -> void:
	var left := RUN_LENGTH - GameClock.game_time
	var base := Color(String(stage.get("tint", "#ffffff")))
	if left < 30.0 and not endless_phase:
		_night.color = base.lerp(DAWN_TINT, clampf(1.0 - left / 30.0, 0.0, 1.0))
	elif endless_phase:
		_night.color = base.darkened(0.15)
	else:
		_night.color = base


## Se a velocidade acelerada passar do orçamento por 5 s, reduz uma velocidade (plano 4.14).
func _speed_guard(delta: float) -> void:
	if _bot or not running or GameClock.paused or GameClock.speed <= 1:
		_over_budget = 0.0
		return
	if GameClock.last_sim_ms > SPEED_GUARD_MS:
		_over_budget += delta
	else:
		_over_budget = maxf(0.0, _over_budget - delta)
	if _over_budget >= SPEED_GUARD_SECONDS:
		_over_budget = 0.0
		GameClock.speed -= 1
		hud.refresh_speed()
		hud.toast(tr("speed.reduced"))


func _note_section(index: int, usec: int) -> void:
	if usec > _section_worst[index]:
		_section_worst[index] = usec


func _cosmetic_tint(id: String) -> Color:
	match id:
		"golden_lantern":
			return Color(1.0, 0.85, 0.2)
		"crimson_lantern":
			return Color(1.0, 0.3, 0.3)
		"jade_lantern":
			return Color(0.4, 1.0, 0.6)
		"azure_lantern":
			return Color(0.4, 0.7, 1.0)
		"violet_lantern":
			return Color(0.8, 0.5, 1.0)
	return Color(1.0, 0.8, 0.3)


## Piloto automático (plano 14.4), imitando um jogador simples: fica ao lado do inimigo
## mais próximo (a katana corta na horizontal), recua se algo encosta, pega o santuário.
func _bot_input() -> Vector2:
	var t := GameClock.game_time
	var wander := Vector2(cos(t * 0.45), sin(t * 0.31)).normalized()
	var me := player.sim_pos
	if kami.has_shrine() and me.distance_to(kami.shrine_pos) < 300.0:
		return (kami.shrine_pos - me).normalized()
	var nearest := enemies.nearest(me, BOT_SIGHT_RADIUS)
	if nearest < 0:
		return wander
	var target := enemies.pos[nearest]
	var dist := me.distance_to(target)
	if dist < BOT_TOO_CLOSE + enemies.radius[nearest]:
		return (me - target).normalized()
	var side := signf(me.x - target.x)
	if side == 0.0:
		side = 1.0
	var goal := target + Vector2(side * (BOT_STRIKE_OFFSET + enemies.radius[nearest]), 0.0)
	var to_goal := goal - me
	if to_goal.length() < 3.0:
		return Vector2(-side * 0.3, 0.0)
	return to_goal.normalized()
