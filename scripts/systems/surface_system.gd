class_name SurfaceSystem
extends Node
## Lentidão das superfícies (data/surfaces.json) para TODOS os atores: guardiã, inimigos comuns,
## elites e chefes. Regra:
##   - a lentidão vale só enquanto o ator está sobre o solo: o multiplicador do ator vai até o
##     "slow" do tipo em "ease_in" segundos;
##   - ao sair, recupera suave (ease-out exponencial) e chega a EXATAMENTE 1.0 em até "ease_out"
##     segundos do tipo (prende em 1.0 a menos de EPS); longe do solo é sempre 1.0, sem resto;
##   - o deslize do óleo ("accel" < 1) acompanha a mesma recuperação e também volta a 1.0;
##   - chefes grandes ("resist_by_size") perdem um pouco menos, mas sempre perdem algo.
##
## Tudo no passo fixo (GameClock.ticked → Player.step / EnemyManager.step / BossDirector), a
## partir da semente, do chunk e do tempo de simulação: o mesmo em 1x/2x/3x e em qualquer nível
## gráfico. hash_tag() entra no hash de determinismo (HyakkiGame.state_summary).
##
## Nó "Surfaces" filho do "Weather" (scenes/game/Game.tscn).

const NODE_PATH := "Weather/Surfaces"
const EPS := 0.004
## Passos sem consulta depois dos quais o estado do índice é considerado de outro inimigo.
const STALE_STEPS := 20
const MAX_CATCH_UP := 120
const PLAYER := -1

var weather: WeatherSystem
var field: SurfaceField
## Estado da guardiã: multiplicador, tipo lembrado na recuperação e se está sobre o solo.
var player_mult: float = 1.0
var player_type: int = -1
var player_inside: bool = false

# Estado por índice do EnemyManager (comuns, elites e chefes).
var _mult := PackedFloat32Array()
var _type := PackedInt32Array()
var _inside := PackedByteArray()
var _last_step := PackedInt32Array()
var _player_step: int = -1


## Sistema da partida (ou null fora dela).
static func of(p_game: Node) -> SurfaceSystem:
	if p_game == null:
		return null
	return p_game.get_node_or_null(NodePath(NODE_PATH)) as SurfaceSystem


## Parte do hash da partida (HyakkiGame.state_summary); "" fora de uma partida montada pela cena.
static func hash_tag_of(p_game: Node) -> String:
	var s := of(p_game)
	return "" if s == null else s.hash_tag()


## Atalho do BossDirector: multiplicador do chefe no índice `i` (atualiza no passo).
static func boss_mult(p_game: HyakkiGame, i: int) -> float:
	var s := of(p_game)
	if s == null:
		return 1.0
	return s.enemy_factor(i, p_game.enemies.pos[i], p_game.enemies.radius[i])


func _ready() -> void:
	name = "Surfaces"
	reset()


func reset() -> void:
	var cap := EnemyManager.CAPACITY
	_mult.resize(cap)
	_mult.fill(1.0)
	_type.resize(cap)
	_type.fill(-1)
	_inside.resize(cap)
	_inside.fill(0)
	_last_step.resize(cap)
	_last_step.fill(-1000000)
	player_mult = 1.0
	player_type = -1
	player_inside = false
	_player_step = -1


func set_field(p_field: SurfaceField) -> void:
	field = p_field
	reset()


func _ensure() -> bool:
	if weather == null:
		return false
	weather.ensure_model()
	return field != null


func _step_index() -> int:
	return weather.game.step_index if weather.game != null else 0


# --- Regra (pura) ------------------------------------------------------------------------

## "slow" efetivo do tipo para um ator de raio `radius` (chefes grandes resistem até 30%).
func slow_for(type: int, radius: float) -> float:
	var slow := field.slow_by_type[type]
	if field.resist_by_type[type] == 1:
		var resist := clampf((radius - 10.0) / 60.0, 0.0, 0.3)
		slow = 1.0 - (1.0 - slow) * (1.0 - resist)
	return slow


## Um passo de `dt` do multiplicador `m`: entra linear (ease_in), sai em ease-out exponencial
## que chega a exatamente 1.0 em até ease_out segundos. Devolve [m, tipo lembrado].
## (Os passos por inimigo usam advance_mult + next_type, sem alocar o Array.)
func advance(m: float, remembered: int, here: int, radius: float, dt: float) -> Array:
	var next := advance_mult(m, remembered, here, radius, dt)
	return [next, next_type(next, remembered, here)]


## Só o multiplicador de advance().
func advance_mult(m: float, remembered: int, here: int, radius: float, dt: float) -> float:
	if here >= 0:
		var target := slow_for(here, radius)
		if m > target:
			m = move_toward(m, target, (1.0 - target) / maxf(field.ease_in_by_type[here], 0.01) * dt)
		else:
			m = _recover_toward(m, target, here, radius, dt)
		return m
	if remembered < 0 or m >= 1.0:
		return 1.0
	return _recover_toward(m, 1.0, remembered, radius, dt)


## Só o tipo lembrado de advance(), dado o multiplicador `next` que advance_mult devolveu.
func next_type(next: float, remembered: int, here: int) -> int:
	if here >= 0:
		return here
	# Sem tipo lembrado (ou já em 1.0) advance_mult devolve 1.0, então cai no -1 também.
	return remembered if next < 1.0 else -1


func _recover_toward(m: float, target: float, type: int, radius: float, dt: float) -> float:
	var depth := maxf(1.0 - slow_for(type, radius), EPS * 2.0)
	var k := log(depth / EPS) / maxf(field.ease_out_by_type[type], 0.01)
	m = target - (target - m) * exp(-k * dt)
	if absf(target - m) < EPS * 1.5:
		m = target
	return m


## Aceleração relativa (óleo escorrega): 1 fora do solo; no solo, a do tipo, proporcional a
## quanto o ator ainda está "dentro" (volta a 1 junto com a recuperação).
func accel_for(m: float, type: int, radius: float) -> float:
	if type < 0 or m >= 1.0:
		return 1.0
	var depth := clampf((1.0 - m) / maxf(1.0 - slow_for(type, radius), EPS), 0.0, 1.0)
	return lerpf(1.0, field.accel_by_type[type], depth)


# --- Guardiã -----------------------------------------------------------------------------

## Multiplicador de velocidade da guardiã em `p` (uma atualização por passo fixo).
func player_factor(p: Vector2) -> float:
	if not _ensure():
		return 1.0
	var step := _step_index()
	if step != _player_step:
		_player_step = step
		var here := field.type_at(p, GameClock.game_time)
		player_inside = here >= 0
		var m := advance_mult(player_mult, player_type, here, Player.RADIUS, GameClock.STEP)
		player_type = next_type(m, player_type, here)
		player_mult = m
	return player_mult


func player_accel() -> float:
	return accel_for(player_mult, player_type, Player.RADIUS)


# --- Inimigos e chefes -------------------------------------------------------------------

## Multiplicador do inimigo `i` em `p` (raio `radius`). Chamado uma vez por passo pelo
## EnemyManager (andantes) ou pelo BossDirector (chefes). Passos sem consulta (atordoado,
## congelado) são recuperados aqui; índice parado há muito tempo = outro inimigo, começa em 1.
func enemy_factor(i: int, p: Vector2, radius: float) -> float:
	if not _ensure() or i < 0 or i >= _mult.size():
		return 1.0
	var step := _step_index()
	var gap := step - _last_step[i]
	if gap == 0:
		return _mult[i]
	if gap > STALE_STEPS or gap < 0:
		_mult[i] = 1.0
		_type[i] = -1
		gap = 1
	_last_step[i] = step
	var here := field.type_at(p, GameClock.game_time)
	_inside[i] = 1 if here >= 0 else 0
	if here < 0 and _type[i] < 0:
		_mult[i] = 1.0
		return 1.0
	var m := _mult[i]
	var remembered := _type[i]
	for _k: int in range(mini(gap, MAX_CATCH_UP)):
		var next := advance_mult(m, remembered, here, radius, GameClock.STEP)
		remembered = next_type(next, remembered, here)
		m = next
	_mult[i] = m
	_type[i] = remembered
	return m


func enemy_accel(i: int) -> float:
	if i < 0 or i >= _mult.size() or _type[i] < 0:
		return 1.0
	return accel_for(_mult[i], _type[i], weather.game.enemies.radius[i])


## Multiplicador atual (só leitura, para desenho e testes).
func enemy_mult(i: int) -> float:
	return _mult[i] if i >= 0 and i < _mult.size() else 1.0


func enemy_type(i: int) -> int:
	return _type[i] if i >= 0 and i < _type.size() else -1


func enemy_inside(i: int) -> bool:
	return i >= 0 and i < _inside.size() and _inside[i] == 1


## Afundamento visual em px (0..2) de quem está no solo; some quando o multiplicador volta a 1.
func sink_px(m: float) -> float:
	return roundf(clampf((1.0 - m) / 0.25, 0.0, 1.0) * 2.0)


func enemy_sink(i: int) -> float:
	return sink_px(enemy_mult(i))


## Resumo determinístico para o hash da partida (soma dos multiplicadores de quem está vivo).
func hash_tag() -> String:
	if field == null or weather.game == null:
		return ""
	var total := player_mult
	var enemies := weather.game.enemies
	if enemies != null:
		for i: int in range(mini(_mult.size(), enemies.alive.size())):
			if enemies.alive[i] == 1:
				total += _mult[i]
	return " solo=%.4f" % total
