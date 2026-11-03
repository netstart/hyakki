class_name BotPilot
extends RefCounted
## Piloto automático (plano 14.4), imitando um jogador simples: fica ao lado do inimigo
## mais próximo (a katana corta na horizontal), recua se algo encosta, pega o santuário e
## entra no portal do Guardião do Limiar (scripts/systems/rift_portal.gd) assim que ele abre.
## Habilidades dos guardiões (ability_slot): solta a primeira pronta e paga, da mais forte para a
## mais fraca, cuja regra fixa aceita (HeroAbilities.bot_should_cast: N inimigos perto), guardando
## energia para a mais forte liberada (as mais fracas só saem se sobrar o custo dela).
## Função pura do estado da partida: o bot é determinístico em 1x, 2x e 3x.

const SEED := 7
const TOO_CLOSE := 9.0
const STRIKE_OFFSET := 24.0
const SIGHT_RADIUS := 400.0
const SHRINE_REACH := 300.0
## O bot decide as habilidades a cada ABILITY_EVERY passos (0,1 s), como um jogador.
const ABILITY_EVERY := 6


## Slot da habilidade que o bot solta neste passo (-1 = nenhuma). Chamado no passo fixo.
static func ability_slot(game: HyakkiGame) -> int:
	if game.step_index % ABILITY_EVERY != 0:
		return -1
	var abilities := game.abilities
	# Energia guardada para a habilidade mais alta liberada e fora da recarga: as mais baratas só
	# saem se sobrar o custo dela (senão a 1ª, barata e frequente, nunca deixa juntar para a 3ª).
	var reserve := 0.0
	for slot: int in range(abilities.slot_count() - 1, -1, -1):
		var fail := abilities.check(slot)
		if fail == AbilitySystem.Fail.NONE and abilities.energy_value() - abilities.cost(slot) >= reserve \
				and abilities.behavior.bot_should_cast(slot, abilities.ability(slot)):
			return slot
		if reserve == 0.0 and (fail == AbilitySystem.Fail.NONE or fail == AbilitySystem.Fail.NO_ENERGY):
			reserve = abilities.cost(slot)
	return -1


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
