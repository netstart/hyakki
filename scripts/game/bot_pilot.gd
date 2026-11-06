class_name BotPilot
extends RefCounted
## Piloto automático (plano 14.4), imitando um jogador simples: fica ao lado do inimigo
## mais próximo (a katana corta na horizontal), recua se algo encosta, pega o santuário e
## entra em qualquer portal aberto (scripts/systems/rift_portal.gd) assim que ele abre: o do
## Guardião do Limiar leva ao Kakuriyo e o torii dourado da Sombra ao Tokoyo, onde ele enfrenta
## o último chefe.
## Habilidades dos guardiões (ability_slot): solta a primeira pronta e paga, da mais forte para a
## mais fraca, cuja regra fixa aceita (HeroAbilities.bot_should_cast: N inimigos perto), guardando
## energia para a mais forte liberada (as mais fracas só saem se sobrar o custo dela).
## Altares do Selo (AltarSystem): com a vida acima de ALTAR_HEALTH e sem chefe vivo, vai até o
## altar dormente a menos de ALTAR_REACH px e fica no círculo até o selo quebrar.
## Função pura do estado da partida: o bot é determinístico em 1x, 2x e 3x.

const SEED := 7
const TOO_CLOSE := 9.0
const STRIKE_OFFSET := 24.0
const SIGHT_RADIUS := 400.0
const SHRINE_REACH := 300.0
const ALTAR_REACH := 600.0
const ALTAR_HEALTH := 0.6
## Fica parado quando já está a esta fração do raio do altar (o centro é sólido).
const ALTAR_STAY := 0.5
## O bot decide as habilidades a cada ABILITY_EVERY passos (0,1 s), como um jogador.
const ABILITY_EVERY := 6
## Linha PROGRESSO a cada 60 s da noite (3600 passos de 1/60 s).
const PROGRESS_STEPS := 3600


## Linhas do fim da partida do bot, depois da FIM (fora do hash): dano recebido, habilidades,
## ryō por fonte (RunTracker.economy_line) e a vida (atual, máxima, reviveres, cura e sobra, comida).
static func report(game: HyakkiGame) -> String:
	var p := game.player
	var vitals := "VIDA atual=%.2f max=%.2f reviveu=%d curado=%.0f sobra=%.0f onigiri=%d sushi=%d regen=%.2f" % [
		p.hp, p.max_hp(), p.revives_used, p.healed, p.overhealed, int(game.tracker.items.get(&"onigiri", 0)),
		int(game.tracker.items.get(&"sushi", 0)), p.stats.get_stat("regen")]
	return "\n".join([p.damage.report_line(), game.abilities.uses_line(), game.rift.journey_line(),
			game.tracker.economy_line(), vitals])


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
	if game.step_index > 0 and game.step_index % PROGRESS_STEPS == 0 and game.rift != null:
		# Só imprime (nada da simulação muda, o hash fica igual): o run_checks vê atividade na jornada longa.
		print("PROGRESSO t=%d reino=%d abates=%d" % [roundi(GameClock.game_time), game.rift.depth, game.tracker.kills])
	var t := GameClock.game_time
	var wander := Vector2(cos(t * 0.45), sin(t * 0.31)).normalized()
	var me := game.player.sim_pos
	if game.rift != null and game.rift.is_open():
		return (game.rift.portal_pos - me).normalized()
	if game.kami.has_shrine() and me.distance_to(game.kami.shrine_pos) < SHRINE_REACH:
		return (game.kami.shrine_pos - me).normalized()
	var altar := altar_goal(game)
	if altar != Vector2.INF:
		if me.distance_to(altar) > AltarSystem.RADIUS * ALTAR_STAY:
			return (altar - me).normalized()
		return Vector2.ZERO
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


## Altar que o bot quer ler agora (Vector2.INF se nenhum): saudável, sem chefe, o mais perto
## dormente ou em ritual a menos de ALTAR_REACH px.
static func altar_goal(game: HyakkiGame) -> Vector2:
	var altars := game.altars
	if altars == null or altars.is_blocked() or game.player.hp < game.player.max_hp() * ALTAR_HEALTH:
		return Vector2.INF
	var me := game.player.sim_pos
	var best := Vector2.INF
	var best_d := ALTAR_REACH
	for at: Vector2 in altars.altars_near():
		var state := altars.state_at(at)
		if state != AltarSystem.State.DORMANT and state != AltarSystem.State.CHANNELING:
			continue
		var d := me.distance_to(at)
		if d < best_d:
			best_d = d
			best = at
	return best
