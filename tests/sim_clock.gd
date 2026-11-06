extends Node
## Relógio de simulação dos testes: soma o delta de cada quadro (o tempo que o jogo vê). Com
## --fixed-fps cada quadro vale 1/60 s sem esperar a parede; sem ele, o delta é o tempo real. Medir
## duração por aqui (e não por Time.get_ticks_*) deixa o teste igual nos dois modos.
##   var clock := SimClock.new(); host.add_child(clock)  ...  clock.elapsed  ...  clock.queue_free()

## Segundos de simulação desde que entrou na árvore.
var elapsed: float = 0.0
## Também empurra o UiClock (o relógio da interface segue a simulação; tests/integration_tests.gd).
var drive_ui: bool = false


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Antes de qualquer outro nó: o quadro em que o relógio entra conta para todos igual.
	process_priority = -1000


func _process(delta: float) -> void:
	elapsed += delta
	if drive_ui:
		UiClock.drive(delta)

