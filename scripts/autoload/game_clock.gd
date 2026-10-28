extends Node
## Tempo de jogo com passo fixo de 1/60 s (plano 4.14).
## Em 2x roda 2 passos de simulação por frame; em 3x, 3 passos. A mesma semente
## produz a mesma partida em qualquer velocidade, e projéteis não atravessam
## inimigos por causa de passos maiores.
## 2x e 3x são da Ampulheta de Fūjin (compra na Loja, com ryō ou dinheiro): sem ela o teto é 1x
## e o ciclo só avisa que está bloqueado (speed_denied). O bot e o `--speed=N` da linha de
## comando (build de debug: determinismo, estresse e testes) aceleram sem a compra.

signal ticked(dt: float)
## Tentou acelerar sem a Ampulheta de Fūjin (a HUD treme o botão, toca o negado e avisa).
signal speed_denied
## O teto mudou (compra ou reembolso no meio da partida): a HUD redesenha o botão.
signal speed_lock_changed

const STEP := 1.0 / 60.0
const SPEEDS: Array[int] = [1, 2, 3]
## Teto de passos por frame (por velocidade) para o jogo nunca entrar em espiral
## de lentidão quando o aparelho não aguenta.
const MAX_STEPS_PER_SPEED := 3

var game_time: float = 0.0
var speed: int = 1
## Teto da velocidade nesta partida: 1 sem a Ampulheta de Fūjin, 3 com ela (ver can_accelerate).
var max_speed: int = 3
## Partida que acelera sem a compra: bot ou `--speed=N` (debug), definido em start_speed.
var free_speed: bool = false
var paused: bool = true
## Fração entre o último passo e o próximo; usada para interpolar o desenho.
var alpha: float = 0.0
var last_frame_steps: int = 0
var last_sim_ms: float = 0.0

var _accumulator: float = 0.0
var _cli_speed: bool = false


func _ready() -> void:
	_cli_speed = OS.is_debug_build() and Array(OS.get_cmdline_user_args()).any(
			func(arg: String) -> bool: return arg.begins_with("--speed="))
	# Comprar ou perder a Ampulheta com a partida aberta vale na hora (o PurchaseManager carrega
	# depois deste autoload).
	(func() -> void:
		PurchaseManager.speed_unlocked.connect(apply_speed_lock)
		PurchaseManager.speed_revoked.connect(apply_speed_lock)).call_deferred()


func reset() -> void:
	game_time = 0.0
	_accumulator = 0.0
	alpha = 0.0
	paused = false


## Começo da partida: a velocidade pedida (opções, config ou snapshot) até o teto da posse.
func start_speed(wanted: int, bot: bool) -> void:
	free_speed = bot or _cli_speed
	speed = clampi(wanted, SPEEDS[0], SPEEDS[-1])
	apply_speed_lock()


func can_accelerate() -> bool:
	return free_speed or PurchaseManager.owns_speed()


## Teto conforme a posse; sem ela, volta a 1x (e o 2x/3x salvo nas opções também).
func apply_speed_lock() -> void:
	max_speed = SPEEDS[-1] if can_accelerate() else SPEEDS[0]
	speed = mini(speed, max_speed)
	if max_speed == SPEEDS[0] and int(Settings.get_value("speed")) != SPEEDS[0]:
		Settings.set_value("speed", SPEEDS[0])
	speed_lock_changed.emit()


## Próxima velocidade do ciclo 1 → 2 → 3 → 1. Sem a Ampulheta fica em 1x e avisa (speed_denied).
func cycle_speed() -> int:
	if not can_accelerate():
		max_speed = SPEEDS[0]
		speed = SPEEDS[0]
		speed_denied.emit()
		return speed
	max_speed = SPEEDS[-1]
	speed = speed + 1 if speed < max_speed else SPEEDS[0]
	return speed


func _process(delta: float) -> void:
	last_frame_steps = 0
	if paused:
		return
	_accumulator += minf(delta, 0.1) * speed
	var max_steps := speed * MAX_STEPS_PER_SPEED
	var start := Time.get_ticks_usec()
	while _accumulator >= STEP and last_frame_steps < max_steps:
		_accumulator -= STEP
		game_time += STEP
		last_frame_steps += 1
		ticked.emit(STEP)
		if paused:
			break
	if last_frame_steps >= max_steps:
		_accumulator = minf(_accumulator, STEP)
	alpha = clampf(_accumulator / STEP, 0.0, 1.0)
	last_sim_ms = (Time.get_ticks_usec() - start) / 1000.0
