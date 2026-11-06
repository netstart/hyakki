class_name UiClock
extends RefCounted
## Relógio da interface, em milissegundos: no jogo é o tempo real (Time.get_ticks_msec). Nos
## testes (tests/sim_clock.gd com drive_ui), passa a ser o tempo de simulação, a soma dos deltas
## dos quadros: com --fixed-fps o quadro não espera a parede, e as travas de toque, intervalos de
## som e lampejos medidos "em tempo real" andam junto com os timers e as animações do teste.

## Ligado pelos testes: o relógio só anda com drive().
static var _driven: bool = false
static var _sim_ms: float = 0.0


static func msec() -> int:
	return int(_sim_ms) if _driven else Time.get_ticks_msec()


## Testes: avança o relógio `delta` segundos (chamado a cada quadro). Na primeira chamada parte do
## tempo real atual, para não voltar no tempo o que já foi marcado antes.
static func drive(delta: float) -> void:
	if not _driven:
		_driven = true
		_sim_ms = Time.get_ticks_msec()
	_sim_ms += delta * 1000.0
