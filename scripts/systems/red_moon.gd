class_name RedMoon
extends RefCounted
## Regras da Lua Vermelha (紅月), cumulativas: a Lua N aplica as regras I..N. Os multiplicadores de
## vida, dano, surgimento e ryō de cada lua ficam em HyakkiGame (MOON_HP, MOON_REWARD); aqui ficam
## as cinco regras que mudam o jogo, com os números lidos pelo Guia e pela Jornada (rule_text):
##   I   mais elites: cada evento de elite das fases traz ELITE_MULT elites em média (1, 2, 1, 2...,
##       sem sorteio) e a chance de Elite dos Altares do Selo é multiplicada por ELITE_MULT;
##   II  chefes com um ataque extra: o Eclipse (eclipse), um disco carmesim onde a guardiã está e,
##       ECLIPSE_DELAY s depois, um anel de ECLIPSE_RING_COUNT círculos em volta (o lugar seguro é
##       a faixa entre os dois), entra no rodízio dos padrões de cada chefe (BossDirector);
##   III Sombras também na luz: o arquétipo Sombra fica rápido e translúcido dentro da luz da
##       lanterna, e SHADE_LIGHT_CHANCE delas já surgem dentro da luz (spawn_point);
##   IV  sem bolinhos de arroz: nenhum onigiri cai das lanternas e a mão de comida/moedas do nível
##       (e a escolha automática e os baús que a seguem) vira só moedas; o sushi e as outras curas
##       continuam;
##   V   os Kami oferecem só PACTS pactos (kami_offers).
## Abaixo de cada regra nada muda (nem o sorteio do rng): o bot com --moon=0 dá o mesmo hash.

const ELITES := 1
const BOSS_ATTACK := 2
const SHADES := 3
const NO_FOOD := 4
const FEW_PACTS := 5
## Quantas regras existem (igual a HyakkiGame.MAX_MOON).
const RULES := 5

const ELITE_MULT := 1.5
const PACTS := 2
## Sombras na luz: fração das Sombras que já nascem dentro da luz, entre estas frações do raio.
const SHADE_LIGHT_CHANCE := 0.3
const SHADE_LIGHT_MIN := 0.55
const SHADE_LIGHT_MAX := 0.9
## Item de comida que some na Lua IV.
const FOOD_ITEM := &"onigiri"

## Eclipse (Lua II): disco no lugar da guardiã, anel de círculos em volta e o dano de cada golpe
## (× HyakkiGame.enemy_damage_mult, como os outros padrões). O chefe para e prepara por
## ECLIPSE_WINDUP s (o aviso do disco) e o anel cai ECLIPSE_DELAY s depois.
const ECLIPSE_CORE := 40.0
const ECLIPSE_RING := 94.0
const ECLIPSE_RING_COUNT := 10
const ECLIPSE_RING_RADIUS := 16.0
const ECLIPSE_WINDUP := 1.1
const ECLIPSE_DELAY := 0.5
const ECLIPSE_DAMAGE := 12.0
const ECLIPSE_TINT := Color(0.86, 0.06, 0.24)


## A regra `rule` (1..RULES) vale na Lua `moon`: as regras se somam.
static func active(moon: int, rule: int) -> bool:
	return moon >= rule


## Multiplicador das elites (eventos das fases e chance dos Altares).
static func elite_mult(moon: int) -> float:
	return ELITE_MULT if active(moon, ELITES) else 1.0


## Quantas elites o evento de elite número `ordinal` (0, 1, 2... na ordem da fase) traz: a soma
## até ele é floor((ordinal + 1) × elite_mult), sem sorteio. Sem a regra, sempre 1.
static func elite_count(ordinal: int, moon: int) -> int:
	var m := elite_mult(moon)
	return floori((ordinal + 1) * m) - floori(ordinal * m)


static func boss_extra(moon: int) -> bool:
	return active(moon, BOSS_ATTACK)


static func shades_in_light(moon: int) -> bool:
	return active(moon, SHADES)


static func no_food(moon: int) -> bool:
	return active(moon, NO_FOOD)


## Quantos Kami o santuário oferece (`base` = KamiSystem.OFFER_COUNT).
static func kami_offers(moon: int, base: int) -> int:
	return mini(base, PACTS) if active(moon, FEW_PACTS) else base


## Peso do item `id` no sorteio das lanternas: o onigiri sai da conta na Lua IV.
static func item_weight(id: StringName, weight: float, moon: int) -> float:
	return 0.0 if id == FOOD_ITEM and no_food(moon) else weight


## Onde nasce um inimigo comum `id`: na borda da tela (Spawner.edge_point) ou, na Lua III, uma
## parte das Sombras dentro da luz. Sem a regra o rng é gasto exatamente como antes.
static func spawn_point(game: HyakkiGame, id: StringName) -> Vector2:
	if not shades_in_light(game.moon) or String(DB.enemy(id).get("archetype", "")) != "shade":
		return game.spawner.edge_point()
	if game.rng.randf() >= SHADE_LIGHT_CHANCE:
		return game.spawner.edge_point()
	var r := game.lantern.radius * game.rng.randf_range(SHADE_LIGHT_MIN, SHADE_LIGHT_MAX)
	var at := game.player.sim_pos + Vector2.from_angle(game.rng.randf() * TAU) * r
	return game.world.clamp_to_bounds(at)


## Eclipse do chefe em `from` contra a guardiã em `target`: avisos no chão (disco e anel), clarão
## carmesim no chefe e o som. Sem sorteio: o anel gira com a direção chefe -> guardiã.
static func eclipse(game: HyakkiGame, from: Vector2, target: Vector2, source: StringName) -> void:
	var damage := ECLIPSE_DAMAGE * game.enemy_damage_mult()
	game.areas.telegraph(target, ECLIPSE_CORE, ECLIPSE_WINDUP, damage, Callable(), ECLIPSE_TINT, source)
	var offset := (target - from).angle()
	for k: int in range(ECLIPSE_RING_COUNT):
		var at := target + Vector2.from_angle(offset + TAU * k / ECLIPSE_RING_COUNT) * ECLIPSE_RING
		game.areas.telegraph(at, ECLIPSE_RING_RADIUS, ECLIPSE_WINDUP + ECLIPSE_DELAY, damage, Callable(),
				ECLIPSE_TINT, source)
	game.fx.add_ring(from, 56.0, ECLIPSE_TINT)
	game.fx.add_ring(target, ECLIPSE_RING + ECLIPSE_RING_RADIUS, ECLIPSE_TINT)
	AudioManager.play("strange", 0.8, 0.0, -4.0)
	AudioManager.play("alert", 0.75, 0.0, -6.0)


## Texto da regra `rule` com os números das constantes.
static func rule_text(rule: int) -> String:
	var text := TranslationServer.translate("moon.rule%d" % rule)
	match rule:
		ELITES:
			return text % ("+%d%%" % roundi((ELITE_MULT - 1.0) * 100.0))
		SHADES:
			return text % ("%d%%" % roundi(SHADE_LIGHT_CHANCE * 100.0))
		FEW_PACTS:
			return text % str(PACTS)
	return text


## As regras que valem na Lua `moon` (I..moon), uma por linha.
static func rules_text(moon: int) -> PackedStringArray:
	var lines: PackedStringArray = []
	for rule: int in range(1, mini(moon, RULES) + 1):
		lines.append(rule_text(rule))
	return lines
