class_name UltimateSystem
extends RefCounted
## Golpe da Lanterna (plano 2.1): carrega com brasas (100 = cheio). O efeito depende do
## herói (plano 3.4). Também reacende a lanterna apagada por Kuroe (fase 3, plano 6.3).

const FULL := 100.0
const CHARGE_PER_XP := 0.45

var game: HyakkiGame
var charge: float = 0.0
var uses: int = 0
var forge_time: float = 0.0
var rain_time: float = 0.0

var _rain_timer: float = 0.0
var _rain_sound: float = 0.0


func _init(p_game: HyakkiGame) -> void:
	game = p_game


func reset() -> void:
	charge = 0.0
	uses = 0
	forge_time = 0.0
	rain_time = 0.0


func is_ready() -> bool:
	return charge >= FULL


func on_xp(xp: int) -> void:
	var was_ready := is_ready()
	charge = minf(FULL, charge + xp * CHARGE_PER_XP * game.player.stats.get_stat("ult_charge"))
	if is_ready() and not was_ready:
		AudioManager.play("bonus2", 1.2)
		Settings.vibrate(20)


func fill() -> void:
	charge = FULL


func step(dt: float) -> void:
	if forge_time > 0.0:
		forge_time -= dt
	if rain_time > 0.0:
		rain_time -= dt
		_rain_timer -= dt
		if _rain_timer <= 0.0:
			var ult: Dictionary = game.player.hero.get("ultimate", {})
			_rain_timer = float(ult.get("rate", 0.06))
			var target := game.enemies.random_alive(game.player.sim_pos, 300.0)
			if target >= 0:
				var at := game.enemies.pos[target]
				game.areas.blast(&"ultimate", at, float(ult.get("radius", 18)),
						float(ult.get("base_damage", 25)) * game.player.stats.get_stat("might"), 40.0)
				# Chuva de flechas: assobio baixo, no máximo ~6 por segundo.
				_rain_sound -= float(ult.get("rate", 0.06))
				if _rain_sound <= 0.0:
					_rain_sound = 0.16
					AudioManager.play("whoosh2", 1.5, 0.12, -14.0)
				game.fx.play_anim("spark", at, 0.8)


func activate() -> bool:
	if not is_ready() or not game.player.is_alive:
		return false
	charge = 0.0
	uses += 1
	var ult: Dictionary = game.player.hero.get("ultimate", {})
	var player := game.player
	var might := player.stats.get_stat("might")
	var at := player.sim_pos
	match String(ult.get("type", "")):
		"dawn_flash":
			game.enemies.stun_all(float(ult.get("stun", 2.0)), at, 420.0)
			game.areas.blast(&"ultimate", at, 420.0,
					float(ult.get("base_damage", 30)) * float(ult.get("damage_mult", 3.0)) * might, 120.0)
			game.hud.flash_screen(Color(1.0, 0.95, 0.7))
			AudioManager.play("explosion", 0.8, 0.0, -6.0)
		"shadow_clone":
			player.clone_time = float(ult.get("duration", 8.0))
			game.fx.play_anim("smoke", player.clone_position(), 1.2)
			AudioManager.play("whoosh2", 0.7, 0.0, -6.0)
		"kagura":
			player.heal(player.max_hp() * float(ult.get("heal_pct", 0.5)))
			game.enemies.push_from(at, float(ult.get("radius", 160)), float(ult.get("force", 420)))
			game.fx.add_ring(at, float(ult.get("radius", 160)), Color(0.7, 1.0, 0.8))
			AudioManager.play("heal", 1.0, 0.0, -4.0)
			AudioManager.play("wings", 0.9, 0.0, -8.0)
		"temple_bell":
			game.enemies.push_from(at, float(ult.get("radius", 220)), float(ult.get("force", 600)))
			game.areas.blast(&"ultimate", at, float(ult.get("radius", 220)),
					float(ult.get("base_damage", 40)) * might, 0.0)
			game.fx.add_ring(at, float(ult.get("radius", 220)), Color(1.0, 0.85, 0.4))
			game.shake(4.0)
			AudioManager.play("j_temple_bell")
		"arrow_rain":
			rain_time = float(ult.get("duration", 6.0))
			AudioManager.play("launch", 0.9, 0.0, -4.0)
		"oni_awakening":
			# Despertar Oni: onda vermelha que empurra e fere, e poder extra por alguns segundos.
			game.enemies.push_from(at, float(ult.get("radius", 150)), float(ult.get("force", 260)))
			game.areas.blast(&"ultimate", at, float(ult.get("radius", 150)),
					float(ult.get("base_damage", 35)) * might, 0.0)
			game.fx.add_ring(at, float(ult.get("radius", 150)), Color(1.0, 0.3, 0.25))
			game.fx.play_anim("boost", at, 1.2, 0.0, Color(1.0, 0.35, 0.3))
			forge_time = float(ult.get("duration", 6.0))
			game.shake(3.0)
			AudioManager.play("taiko")
		"living_forge":
			forge_time = float(ult.get("duration", 10.0))
			game.fx.play_anim("boost", at, 1.2, 0.0, Color(1.0, 0.6, 0.3))
			AudioManager.play("fire", 0.8, 0.0, -4.0)
	game.fx.play_anim("circle_spark", at, 3.0)
	AudioManager.play("magic4", 1.0, 0.0, 0.0)
	Settings.vibrate(120)
	# Reacende a lanterna apagada por Kuroe.
	game.lantern.extinguished = false
	Events.ultimate_used.emit()
	return true


func damage_bonus() -> float:
	if forge_time > 0.0:
		return 1.0 + float(game.player.hero.get("ultimate", {}).get("might", 0.5))
	return 1.0
