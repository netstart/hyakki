class_name Weapon
extends RefCounted
## Base das armas (plano 4.5): lê os valores e os níveis em data/weapons.json e aplica os
## atributos da guardiã (Poder, Área, Recarga, Quantidade, Duração, Vel. de projétil).
## - Deltas "damage", "amount" e "pierce" somam direto.
## - Deltas "area", "speed", "duration" e "cooldown" são frações (+0,25 = +25%).
## Com a Sombra Dupla do Kenta, cada disparo também sai da posição do clone.

const FRACTION_KEYS := ["area", "speed", "duration", "cooldown"]

var id: StringName
var data: Dictionary = {}
var flags: Dictionary = {}
var tags: Array = []
var level: int = 1
var max_level: int = 8
var game: HyakkiGame

var _timer: float = 0.3
var _sums: Dictionary = {}


func _init(p_game: HyakkiGame, p_id: StringName) -> void:
	game = p_game
	id = p_id
	data = DB.weapon(p_id)
	flags = data.get("flags", {})
	tags = data.get("tags", [])
	max_level = maxi(1, (data.get("levels", [{}]) as Array).size())
	_recalculate()
	if game != null and game.elements != null and is_elemental():
		game.elements.register(self)


func is_evolved() -> bool:
	return String(data.get("kind", "base")) != "base"


func level_up() -> void:
	level = mini(level + 1, max_level)
	_recalculate()


func _recalculate() -> void:
	_sums.clear()
	var levels: Array = data.get("levels", [])
	for l: int in range(mini(level, levels.size())):
		var deltas: Dictionary = levels[l]
		for key: String in deltas:
			_sums[key] = float(_sums.get(key, 0.0)) + float(deltas[key])


## Valor da arma no nível atual, sem os atributos da guardiã.
func raw(key: String) -> float:
	var base := float((data.get("base", {}) as Dictionary).get(key, 0.0))
	var sum := float(_sums.get(key, 0.0))
	if FRACTION_KEYS.has(key):
		return base * (1.0 + sum)
	return base + sum


func stats() -> StatBlock:
	return game.player.stats


func damage() -> float:
	return raw("damage") * stats().get_stat("might") * game.damage_bonus()


func area() -> float:
	return raw("area") * stats().get_stat("area") if raw("area") > 0.0 else stats().get_stat("area")


func cooldown() -> float:
	return maxf(0.05, raw("cooldown") * stats().get_stat("cooldown"))


func amount() -> int:
	var tag_bonus := 0
	for tag: Variant in tags:
		tag_bonus += game.tag_amount_bonus(String(tag))
	return maxi(1, int(raw("amount")) + int(stats().get_stat("amount")) + game.hero_amount_bonus() + tag_bonus)


func duration() -> float:
	return raw("duration") * stats().get_stat("duration")


func proj_speed() -> float:
	return raw("speed") * stats().get_stat("proj_speed")


func knockback() -> float:
	return raw("knockback")


## Tamanho do projétil desta arma ("proj_size" em data/weapons.json, 1,0 se não houver): multiplica
## o desenho (sprite, rastro e brilho) e o raio de colisão juntos, para o que se vê bater com o que
## acerta. Não depende do atributo Área.
func proj_size() -> float:
	return float(data.get("proj_size", 1.0))


func step(dt: float) -> void:
	_timer -= dt
	if _timer <= 0.0:
		_timer += cooldown()
		fire_all()


## Com "hand" no herói, as armas que saem dele (projéteis, raios) partem da mão; auras,
## anéis e golpes em volta do corpo (from_hand() falso) continuam em sim_pos.
func fire_all() -> void:
	var player := game.player
	var hand := from_hand()
	fire(player.hand_position(player.sim_pos) if hand else player.sim_pos)
	if player.clone_time > 0.0:
		var clone := player.clone_position()
		fire(player.hand_position(clone) if hand else clone)
	if hand:
		player.on_cast()


## Diz se o disparo sai da mão do herói (e mostra a pose de ataque). Falso nas armas
## centradas no corpo.
func from_hand() -> bool:
	return true


## Implementado por cada arma. `origin` é a mão da guardiã (ou do clone), ou a posição dela.
func fire(_origin: Vector2) -> void:
	pass


## Desenho opcional da arma (órbitas, aura), chamado pela camada de armas.
func draw(_canvas: CanvasItem) -> void:
	pass


## Brilho aditivo opcional (só na Alta, FxLayer.glow), chamado pela camada de brilho.
func draw_glow(_canvas: CanvasItem) -> void:
	pass


## Cor do poder e cor quente do núcleo (data/weapons.json "fx").
func fx_color() -> Color:
	return game.fx.style(id)["color"] if game and game.fx else Color.WHITE


func fx_hot() -> Color:
	return game.fx.style(id)["hot"] if game and game.fx else Color.WHITE


func on_removed() -> void:
	if game != null and game.elements != null:
		game.elements.unregister(self)


## Gancho de abate (HyakkiGame._on_enemy_killed), chamado para toda arma da guardiã a cada inimigo
## comum morto em `at` (`j` = índice que ele ocupava). O estado dele na hora da morte (queimava,
## congelado, quem matou) está em EnemyManager.dying_*().
func on_kill(_at: Vector2, _j: int) -> void:
	pass


# --- Fogo e gelo (tags "fire" / "ice", chaves "burn", "burn_time", "chill") --------------

func is_fire() -> bool:
	return tags.has("fire")


func is_ice() -> bool:
	return tags.has("ice")


## Entra no Choque Térmico ou aplica estados: HyakkiGame.deal_damage chama element_hit e
## apply_status nos acertos (não contínuos) desta arma (registrada no ElementSystem).
func is_elemental() -> bool:
	return is_fire() or is_ice() or raw("burn") > 0.0 or raw("chill") > 0.0


## Dano por segundo da Queimadura desta arma (antes do atributo "burn", que o EnemyManager aplica).
func burn_dps() -> float:
	return raw("burn") * stats().get_stat("might") * game.damage_bonus()


## Antes do dano: Choque Térmico (fogo em congelado, gelo em quem queima). Devolve o dano extra.
func element_hit(j: int, amount: float) -> float:
	var e := game.enemies
	if is_fire() and e.frozen[j] > 0.0:
		return e.thermal_shock(j, amount, true)
	if is_ice() and e.burn_time[j] > 0.0:
		return e.thermal_shock(j, amount, false)
	return 0.0


## Depois do dano, com o inimigo vivo: Queimadura ("burn" dps por "burn_time" s) e frio ("chill").
func apply_status(j: int) -> void:
	if raw("burn") > 0.0:
		game.enemies.burn_one(j, burn_dps(), raw("burn_time"), id)
	if raw("chill") > 0.0:
		game.enemies.chill_one(j, int(raw("chill")))
