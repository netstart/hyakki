class_name FramePacing
extends RefCounted
## Ritmo dos quadros no celular (opção "fps" de Settings: 30, 60 ou 120).
##
## Com o VSync ligado (padrão no Android) a tela já dita o ritmo. Pôr também o limitador do
## Godot (Engine.max_fps) no mesmo valor da taxa da tela faz os dois relógios brigarem: o
## limitador dorme pelo relógio da CPU e a troca de buffer espera o da tela, então de tempos em
## tempos um quadro perde a vez e o seguinte sai dobrado (tranco na rolagem e na partida). Por
## isso, quando a opção pede a taxa da tela ou mais, o limitador fica desligado (0) e só o VSync
## manda; abaixo da taxa da tela (60 FPS numa tela de 120 Hz, 30 FPS) o limitador continua, que
## é o único jeito de economizar bateria. No PC (ou VSync desligado) vale a opção como antes.


## Limite do Engine.max_fps para a opção, a taxa da tela (Hz; <= 0 = desconhecida) e se é celular.
static func max_fps_for(option: int, refresh: float, mobile: bool, vsync: bool = true) -> int:
	if not mobile or not vsync or refresh <= 0.0 or option <= 0:
		return option
	return 0 if option >= roundi(refresh) - 1 else option


## Aplica ao Engine a opção dada, com a taxa e o VSync da tela atual.
static func apply(option: int) -> void:
	var vsync := DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
	Engine.max_fps = max_fps_for(option, DisplayServer.screen_get_refresh_rate(), OS.has_feature("mobile"), vsync)
