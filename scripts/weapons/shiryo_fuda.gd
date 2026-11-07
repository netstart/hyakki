class_name ShiryoFuda
extends Weapon
## Shiryō-fuda 死霊符 (arma inicial da Kuon) e Hyakki-shō 百鬼将 (evolução com o Sino da Itako): ofudas
## dos mortos que saem rumo ao yōkai à vista mais próximo (EnemyManager.nearest_in_sight), num leque
## estreito, e o perseguem (ProjectileManager HOMING, "turn"); param em casas, árvores e rochas como
## todo projétil (WorldMap.solid_hit).
## O abate de uma ofuda (ou de um servo dela) tem "raise_chance" de levantar um servo espectral no lugar
## (MinionSystem.raise): "minion_damage", "minion_life" e "minion_speed"; o teto é o "minion_cap" + o
## atributo "minions". Com "minion_kind": "samurai" (Hyakki-shō) os servos são samurais espectrais, e os
## que já estavam de pé se transformam quando a evolução chega.

## Alcance da mira e abertura entre duas ofudas do leque (rad).
const AIM_RANGE := 260.0
const FAN := 0.3


func _init(p_game: HyakkiGame, p_id: StringName) -> void:
	super(p_game, p_id)
	if game != null and game.minions != null and minion_kind() == MinionSystem.Kind.SAMURAI:
		game.minions.promote_all(MinionSystem.Kind.SAMURAI, id)


## Tipo de servo desta arma (flag "minion_kind").
func minion_kind() -> int:
	return MinionSystem.Kind.SAMURAI if String(flags.get("minion_kind", "")) == "samurai" else MinionSystem.Kind.SPIRIT


func fire(origin: Vector2) -> void:
	var enemies := game.enemies
	var target := enemies.nearest_in_sight(origin, AIM_RANGE)
	var aim := game.player.facing if game.player.facing != Vector2.ZERO else Vector2.RIGHT
	if target >= 0 and enemies.pos[target].distance_squared_to(origin) > 0.01:
		aim = (enemies.pos[target] - origin).normalized()
	var n := amount()
	var kind_name := "war_fuda" if is_evolved() else "soul_fuda"
	for k: int in range(n):
		var dir := aim.rotated((k - (n - 1) * 0.5) * FAN)
		var p := game.projectiles.spawn(id, kind_name, origin, dir * proj_speed(), damage(), 4.0, int(raw("pierce")),
				duration(), knockback(), ProjectileManager.Move.HOMING, raw("turn"))
		game.projectiles.set_size(p, proj_size())
		if p >= 0 and target >= 0:
			game.projectiles.target[p] = target
	if game.fx != null:
		game.fx.muzzle(id, origin, aim)
		if FxLayer.wfx > 0:
			game.fx.motes(origin, fx_color(), FxLayer.wfx, 3.0, 14.0)
	WeaponSfx.launch(self)


## Abate desta arma (ofuda ou servo dela): chance de o yōkai voltar como servo da Kuon.
func on_kill(at: Vector2, _j: int) -> void:
	var minions := game.minions
	if minions == null or game.enemies.dying_killer() != id or minions.count() >= minions.cap():
		return
	var chance := raw("raise_chance")
	if chance <= 0.0 or (chance < 1.0 and game.rng.randf() >= chance):
		return
	minions.raise(at, id, raw("minion_damage"), raw("minion_life"), minion_kind(), raw("minion_speed"))
