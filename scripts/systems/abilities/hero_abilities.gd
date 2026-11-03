class_name HeroAbilities
extends RefCounted
## Comportamento das 3 habilidades de um guardião (base). O AbilitySystem cuida de desbloqueio,
## custo, recarga, voz, letreiro, rastreio e save; aqui fica só o efeito de cada habilidade e
## os efeitos persistentes dela (zonas, barreiras, armadilhas), no passo fixo da simulação.
##
## Para um herói novo (scripts/systems/abilities/<herói>_abilities.gd, achado pelo id em
## AbilitySystem.BEHAVIOR_PATH), sobrescreva:
##   cast(slot, ability, power) -> bool  solta a habilidade (true = usou; false devolve o custo);
##   step(dt)                            efeitos persistentes (o AbilitySystem chama todo passo);
##   reset(), state(), load_state(s)     zera / salva / restaura os efeitos persistentes (JSON:
##                                       use vec()/to_vec() para Vector2);
##   has_visuals(), draw_ground/over/glow(canvas)  desenho (só leitura, nada da simulação);
##   bot_should_cast(slot, ability)      regra fixa do bot (padrão: "bot" do JSON);
##   hash_tag()                          estado persistente no hash de determinismo.
## Regras: só o rng da partida (game.rng) na simulação; efeitos visuais pelo game.fx (usa
## randf próprio, fora do hash); números de dano por `dmg()` (base × might × poder), raios por
## `area_of()` (atributo "area"), durações por `dur()` (atributo "duration"). Dano sempre por
## hit()/hit_circle()/hit_segment()/hit_cone() (passam por HyakkiGame.deal_damage: crítico,
## registro, número e som), com o id da habilidade como fonte.

## Sombra dos anéis fortes (bold_ring).
const RING_SHADOW := Color(0.04, 0.02, 0.03, 0.6)

var system: AbilitySystem
var game: HyakkiGame
var hero_id: StringName = &""

var _hits: Array[int] = []


func _init(p_system: AbilitySystem, p_hero: StringName) -> void:
	system = p_system
	game = p_system.game
	hero_id = p_hero


# --- Para sobrescrever ------------------------------------------------------------------

## Solta a habilidade `ability` (linha de data/abilities.json) do `slot` com o `power` do nível.
## Padrão (heróis ainda sem comportamento): só um anel na cor da energia; conta o uso.
func cast(_slot: int, _ability: Dictionary, _power: float) -> bool:
	var at := game.player.sim_pos
	game.fx.add_ring(at, 40.0, system.energy.color)
	game.fx.flash(at, 24.0, Color(system.energy.color, 0.7), 0.15)
	return true


func step(_dt: float) -> void:
	pass


func reset() -> void:
	pass


func state() -> Dictionary:
	return {}


func load_state(_s: Dictionary) -> void:
	pass


## Há algo para desenhar agora (a camada só redesenha enquanto for true).
func has_visuals() -> bool:
	return false


## Chão (abaixo dos inimigos), por cima de tudo, e camada aditiva (só na qualidade Alta).
func draw_ground(_canvas: CanvasItem) -> void:
	pass


func draw_over(_canvas: CanvasItem) -> void:
	pass


func draw_glow(_canvas: CanvasItem) -> void:
	pass


## Regra fixa do bot (já sabendo que a habilidade está pronta e paga): pelo menos "bot.near"
## inimigos a até "bot.radius" px do herói.
func bot_should_cast(_slot: int, ability: Dictionary) -> bool:
	var rule: Dictionary = ability.get("bot", {})
	var near := int(rule.get("near", 3))
	return game.enemies.count_in_circle(game.player.sim_pos, float(rule.get("radius", 80.0)), near) >= near


## Parte do hash de determinismo (efeitos persistentes); "" sem nada.
func hash_tag() -> String:
	return ""


# --- Ajudantes -----------------------------------------------------------------------

static func param(ability: Dictionary, key: String, default: float = 0.0) -> float:
	return float((ability.get("params", {}) as Dictionary).get(key, default))


## Dano do parâmetro `key`: base × might × poder (poder = 1 + 0,035 × (nível − 1)).
func dmg(ability: Dictionary, key: String, power: float) -> float:
	return param(ability, key) * game.player.stats.get_stat("might") * power


## Raio do parâmetro `key` × atributo "area".
func area_of(ability: Dictionary, key: String) -> float:
	return param(ability, key) * game.player.stats.get_stat("area")


## Duração do parâmetro `key` × atributo "duration".
func dur(ability: Dictionary, key: String) -> float:
	return param(ability, key) * game.player.stats.get_stat("duration")


func hit(id: StringName, enemy: int, amount: float, dir: Vector2, force: float, dot: bool = false) -> void:
	game.deal_damage(id, enemy, amount, dir, force, false, dot)


## Dano em círculo (para fora do centro); `stun` atordoa os comuns (chefes: × BOSS_STUN).
func hit_circle(id: StringName, center: Vector2, r: float, amount: float, force: float,
		dot: bool = false, stun: float = 0.0) -> int:
	var enemies := game.enemies
	enemies.query_circle(center, r, _hits)
	var count := 0
	for j: int in _hits.duplicate():
		if enemies.alive[j] == 0 or enemies.is_prop(j):
			continue
		hit(id, j, amount, (enemies.pos[j] - center).normalized(), force, dot)
		if stun > 0.0:
			enemies.stun_one(j, stun * (EnemyManager.BOSS_STUN if enemies.is_boss(j) else 1.0))
		count += 1
	return count


## Dano em linha a→b com meia-largura `width`, empurrando no sentido a→b. `once` guarda quem já
## levou (um golpe por inimigo ao longo de vários passos, ex.: um avanço).
func hit_segment(id: StringName, a: Vector2, b: Vector2, width: float, amount: float, force: float,
		once: Dictionary = {}) -> int:
	var enemies := game.enemies
	enemies.query_segment(a, b, width, _hits)
	var push := (b - a).normalized()
	var count := 0
	for j: int in _hits.duplicate():
		if once.has(j) or enemies.alive[j] == 0:
			continue
		once[j] = true
		hit(id, j, amount, push, force)
		count += 1
	return count


## Dano em leque (abertura total 2 × `half_angle` rad), empurrando para fora do centro.
func hit_cone(id: StringName, center: Vector2, dir: Vector2, half_angle: float, reach: float,
		amount: float, force: float) -> int:
	var enemies := game.enemies
	enemies.query_cone(center, dir, half_angle, reach, _hits)
	var count := 0
	for j: int in _hits.duplicate():
		if enemies.alive[j] == 0:
			continue
		hit(id, j, amount, (enemies.pos[j] - center).normalized(), force)
		count += 1
	return count


## Cue de WeaponSfx só se existir (os sons das habilidades chegam aos poucos).
static func play_sfx(cue: String, pitch: float = 1.0, db: float = 0.0) -> bool:
	return WeaponSfx.CUES.has(cue) and WeaponSfx.play(cue, pitch, db)


## Som de impacto/fim da habilidade ("ab_<id>_hit"), se existir.
static func impact_sfx(ability: Dictionary) -> bool:
	return play_sfx(String(ability.get("sfx", "")) + "_hit")


## Tremor leve (cota "screen_shake" do nível gráfico) e vibração curta.
func punch(shake: float, vibrate_ms: int) -> void:
	game.shake(shake * FxLayer.shake_mult)
	Settings.vibrate(vibrate_ms)


## Anel forte que lê no meio da horda (Stroke, sem buffer por quadro): sombra escura larga por
## baixo, faixa na cor da habilidade e fio claro por dentro. `alpha` 0..1 (entrada/saída).
static func bold_ring(canvas: CanvasItem, center: Vector2, r: float, color: Color, hot: Color, alpha: float,
		width: float = 3.0) -> void:
	if r < 2.0 or alpha <= 0.0:
		return
	var segments := clampi(int(r * 0.7), 20, 64)
	Stroke.arc(canvas, center, r, 0.0, TAU, segments, Color(RING_SHADOW, RING_SHADOW.a * alpha), width + 2.0)
	Stroke.arc(canvas, center, r, 0.0, TAU, segments, Color(color, color.a * alpha), width)
	Stroke.arc(canvas, center, r - floorf(width * 0.5), 0.0, TAU, segments, Color(hot, hot.a * alpha), 1.0)


## Vector2 ↔ [x, y] para o save (JSON).
static func vec(v: Vector2) -> Array:
	return [v.x, v.y]


static func to_vec(a: Variant) -> Vector2:
	var list: Array = a if a is Array else []
	return Vector2(float(list[0]), float(list[1])) if list.size() >= 2 else Vector2.ZERO
