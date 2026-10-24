class_name GfxMonitor
extends Node
## Monitor de FPS da qualidade "auto" (GfxQuality). A HUD da partida (hud.gd) o cria: só
## existe enquanto se joga, então menus e telas de carregamento não contam.
##
## A cada BUCKET segundos reais mede o FPS médio. Se ficar abaixo de RATIO do alvo por
## WINDOW segundos seguidos, rebaixa um nível (GfxQuality.auto_downgrade), no máximo uma vez
## a cada COOLDOWN segundos; nunca sobe sozinho na mesma sessão. Pausa, telas por cima
## (GameClock.paused) e opção fora de "auto" zeram a contagem. O alvo é a opção "fps",
## limitado pela taxa de atualização da tela. Usa o tempo real (Time.get_ticks_usec), não o
## delta, que a velocidade 2x/3x poderia distorcer. Desligado no modo headless (bots e testes
## de determinismo não rebaixam nada).

const BUCKET := 1.0
const WINDOW := 5.0
const RATIO := 0.8
const COOLDOWN := 20.0
## Segundos ignorados ao começar (carregamento e primeiros quadros).
const WARMUP := 3.0

var _bucket_time: float = 0.0
var _bucket_frames: int = 0
var _low_time: float = 0.0
var _since_drop: float = COOLDOWN
var _warmup: float = WARMUP
var _last_usec: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name() == "headless":
		set_process(false)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var real := 0.0 if _last_usec == 0 else (now - _last_usec) / 1000000.0
	_last_usec = now
	if real <= 0.0:
		return
	var active := GfxQuality.mode() == "auto" and not GameClock.paused
	if feed(real, target_fps(), active):
		GfxQuality.auto_downgrade()


## Um quadro de `real` segundos reais. Devolve true quando é hora de rebaixar.
func feed(real: float, target: float, active: bool) -> bool:
	_since_drop += real
	if not active:
		reset()
		return false
	if _warmup > 0.0:
		_warmup -= real
		return false
	_bucket_time += real
	_bucket_frames += 1
	if _bucket_time < BUCKET:
		return false
	var fps := _bucket_frames / _bucket_time
	if fps < target * RATIO:
		_low_time += _bucket_time
	else:
		_low_time = 0.0
	_bucket_time = 0.0
	_bucket_frames = 0
	if _low_time >= WINDOW and _since_drop >= COOLDOWN and GfxQuality.level() > GfxQuality.LOW:
		_low_time = 0.0
		_since_drop = 0.0
		return true
	return false


## Esquece a medição em curso (não o tempo desde o último rebaixamento).
func reset() -> void:
	_bucket_time = 0.0
	_bucket_frames = 0
	_low_time = 0.0
	_warmup = WARMUP


static func target_fps() -> float:
	var target := 60.0
	var tree := Engine.get_main_loop() as SceneTree
	var settings := tree.root.get_node_or_null(^"Settings") if tree != null else null
	if settings != null:
		target = float(settings.call("get_value", "fps"))
	var refresh := DisplayServer.screen_get_refresh_rate()
	if refresh > 0.0:
		target = minf(target, refresh)
	return maxf(target, 1.0)
