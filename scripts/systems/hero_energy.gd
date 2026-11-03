class_name HeroEnergy
extends RefCounted
## Energia própria do guardião (Chama da Ordem, Sombra, Prece, Penitência, Foco, Calor da
## Forja, Sangue Oni), movida só por eventos da simulação: o passo (com movimento e luz), o
## dano recebido, os acertos das armas e os abates. As regras vêm de data/abilities.json
## ("energy") e todas são opcionais; o que não está lá não conta:
##   max, start          teto e valor no começo da partida;
##   regen               ganho por segundo (base);
##   regen_moving / regen_still  substituem `regen` andando / parado;
##   regen_per_stat      {"atributo": fator}: soma fator × atributo (Hana: 2 × "regen");
##   light_mult / dark_mult      multiplicam o ganho por segundo dentro / fora da luz;
##   regen_in_light / regen_out_light  somam (ou tiram, se negativos) por segundo na luz / fora;
##   per_hp_lost, per_hit, per_kill    ganho por ponto de vida perdido, por acerto, por abate;
##   decay, decay_after  depois de `decay_after` s sem ganho por evento (dano, acerto ou abate),
##                       o ganho por segundo para e a energia cai `decay` por segundo;
##   hp_price, hp_floor  falta de energia paga com vida: `hp_price` de vida por ponto que falta,
##                       só se a vida depois do pagamento ficar ≥ hp_floor × vida máxima (Yuki).
## Função pura do que recebe (sem nó, sem autoload, sem relógio real): determinística.

var id: StringName = &""
var color := Color.WHITE
var max_value: float = 100.0
var value: float = 0.0
var rules: Dictionary = {}
## Segundos desde o último ganho por evento (dano recebido, acerto, abate).
var since_gain: float = 0.0
## Ganho/perda por segundo do último passo (a UI mostra a seta de enchendo/esvaziando).
var rate: float = 0.0


func _init(p_rules: Dictionary = {}) -> void:
	setup(p_rules)


func setup(p_rules: Dictionary) -> void:
	rules = p_rules
	id = StringName(String(rules.get("id", "")))
	color = Color(String(rules.get("color", "ffffff")))
	max_value = maxf(1.0, float(rules.get("max", 100.0)))
	reset()


func reset() -> void:
	value = clampf(float(rules.get("start", max_value)), 0.0, max_value)
	since_gain = 0.0
	rate = 0.0


func fraction() -> float:
	return value / max_value


func rule(key: String, default: float = 0.0) -> float:
	return float(rules.get(key, default))


## Um passo da simulação. `moving`: o jogador pede movimento; `in_light`: o herói está na luz
## da lanterna (AbilitySystem.hero_in_light); `stats`: atributos para "regen_per_stat"
## (StatBlock ou null).
func step(dt: float, moving: bool, in_light: bool, stats: StatBlock = null) -> void:
	since_gain += dt
	var decaying := rules.has("decay") and since_gain >= rule("decay_after", 0.0)
	var per_s := 0.0
	if decaying:
		per_s = -rule("decay")
	else:
		per_s = rule("regen")
		if moving and rules.has("regen_moving"):
			per_s = rule("regen_moving")
		elif not moving and rules.has("regen_still"):
			per_s = rule("regen_still")
		var per_stat: Dictionary = rules.get("regen_per_stat", {})
		if stats != null:
			for stat: String in per_stat:
				per_s += float(per_stat[stat]) * stats.get_stat(stat)
		per_s *= rule("light_mult", 1.0) if in_light else rule("dark_mult", 1.0)
	per_s += rule("regen_in_light") if in_light else rule("regen_out_light")
	rate = per_s
	value = clampf(value + per_s * dt, 0.0, max_value)


## Ganho por evento (zera o tempo do "esfriar" se ganhou algo).
func _gain(amount: float) -> void:
	if amount <= 0.0:
		return
	since_gain = 0.0
	value = minf(max_value, value + amount)


func on_damage_taken(hp_lost: float) -> void:
	_gain(rule("per_hp_lost") * maxf(0.0, hp_lost))


func on_hit(count: int = 1) -> void:
	_gain(rule("per_hit") * count)


func on_kill(count: int = 1) -> void:
	_gain(rule("per_kill") * count)


func pays_with_hp() -> bool:
	return rule("hp_price") > 0.0


## Vida que o herói pagaria por `cost` agora (0 se a energia basta; INF se não pode pagar).
func hp_cost(cost: float, hp: float, max_hp: float) -> float:
	if value >= cost:
		return 0.0
	if not pays_with_hp():
		return INF
	var price := (cost - value) * rule("hp_price")
	if hp - price < rule("hp_floor") * max_hp or hp - price <= 0.0:
		return INF
	return price


func can_afford(cost: float, hp: float = 0.0, max_hp: float = 1.0) -> bool:
	return hp_cost(cost, hp, max_hp) < INF


## Paga o custo: tira da energia e devolve a vida a descontar (0 se a energia bastou; -1 se não
## pôde pagar, sem mexer em nada).
func pay(cost: float, hp: float = 0.0, max_hp: float = 1.0) -> float:
	var price := hp_cost(cost, hp, max_hp)
	if price == INF:
		return -1.0
	value = maxf(0.0, value - cost)
	return price


func state() -> Dictionary:
	return {"value": value, "since_gain": since_gain}


func load_state(s: Dictionary) -> void:
	value = clampf(float(s.get("value", value)), 0.0, max_value)
	since_gain = float(s.get("since_gain", 0.0))
