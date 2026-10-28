class_name BotPilot
extends RefCounted
## Piloto automático (plano 14.4), imitando um jogador simples: fica ao lado do inimigo
## mais próximo (a katana corta na horizontal), recua se algo encosta, pega o santuário e
## entra no portal do Guardião do Limiar (scripts/systems/rift_portal.gd) assim que ele abre.
## Função pura do estado da partida: o bot é determinístico em 1x, 2x e 3x.

const SEED := 7
const TOO_CLOSE := 9.0
const STRIKE_OFFSET := 24.0
const SIGHT_RADIUS := 400.0
const SHRINE_REACH := 300.0


static func input(game: HyakkiGame) -> Vector2:
	var t := GameClock.game_time
	var wander := Vector2(cos(t * 0.45), sin(t * 0.31)).normalized()
	var me := game.player.sim_pos
	if game.rift != null and game.rift.is_open():
		return (game.rift.portal_pos - me).normalized()
	if game.kami.has_shrine() and me.distance_to(game.kami.shrine_pos) < SHRINE_REACH:
		return (game.kami.shrine_pos - me).normalized()
	var enemies := game.enemies
	var nearest := enemies.nearest(me, SIGHT_RADIUS)
	if nearest < 0:
		return wander
	var target := enemies.pos[nearest]
	var dist := me.distance_to(target)
	if dist < TOO_CLOSE + enemies.radius[nearest]:
		return (me - target).normalized()
	var side := signf(me.x - target.x)
	if side == 0.0:
		side = 1.0
	var goal := target + Vector2(side * (STRIKE_OFFSET + enemies.radius[nearest]), 0.0)
	var to_goal := goal - me
	if to_goal.length() < 3.0:
		return Vector2(-side * 0.3, 0.0)
	return to_goal.normalized()
