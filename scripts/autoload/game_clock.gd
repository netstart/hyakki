extends Node
## Tempo de jogo com passo fixo de 1/60 s (plano 4.14).
## Em 2x roda 2 passos de simulação por frame; em 3x, 3 passos. A mesma semente
## produz a mesma partida em qualquer velocidade, e projéteis não atravessam
## inimigos por causa de passos maiores.

signal ticked(dt: float)

const STEP := 1.0 / 60.0
const SPEEDS: Array[int] = [1, 2, 3]
## Teto de passos por frame (por velocidade) para o jogo nunca entrar em espiral
## de lentidão quando o aparelho não aguenta.
const MAX_STEPS_PER_SPEED := 3

var game_time: float = 0.0
var speed: int = 1
var paused: bool = true
## Fração entre o último passo e o próximo; usada para interpolar o desenho.
var alpha: float = 0.0
var last_frame_steps: int = 0
var last_sim_ms: float = 0.0

var _accumulator: float = 0.0


func reset() -> void:
	game_time = 0.0
	_accumulator = 0.0
	alpha = 0.0
	paused = false


func cycle_speed() -> int:
	var index := SPEEDS.find(speed)
	speed = SPEEDS[(index + 1) % SPEEDS.size()]
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
