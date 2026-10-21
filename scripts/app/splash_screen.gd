class_name SplashScreen
extends Control
## Abertura de 2,6 s antes de tudo (pedido de 21/10). O que os bons jogos fazem e foi
## seguido aqui:
## - curta e pulável: um toque encerra (depois de 0,3 s, para não pular sem querer);
## - continua a splash do sistema: mesmo fundo (application/boot_splash/bg_color), sem
##   piscar branco entre o motor e o jogo;
## - uma única imagem que já diz o tom: a chama da lanterna acendendo na noite, as brasas
##   subindo e o nome; nada de texto longo;
## - um só som marcante (sino do templo) e saída em fade direto no fundo do título.
## Com "reduzir flashes" a chama não tremula.

signal finished

const BG := Color("0d0b16")
const DURATION := 2.6
const FADE_OUT := 0.45
const SKIP_AFTER := 0.3
const EMBERS := 26

var _time: float = 0.0
var _done: bool = false
var _calm: bool = false
var _bell_played: bool = false
var _font: Font
var _embers: Array[Vector3] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_calm = bool(Settings.get_value("reduce_flashes"))
	_font = Locale.font if Locale.font else ThemeDB.fallback_font
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k: int in range(EMBERS):
		# x relativo ao centro, fase de subida, velocidade
		_embers.append(Vector3(rng.randf_range(-70.0, 70.0), rng.randf(), rng.randf_range(0.25, 0.6)))


func _process(delta: float) -> void:
	_time += delta
	if not _bell_played and _time >= 0.35:
		_bell_played = true
		AudioManager.play("j_temple_bell", 1.0, 0.0, -4.0)
	# O título nasce por baixo durante o fade de saída: a troca não tem corte.
	if not _done and _time >= DURATION - FADE_OUT:
		_done = true
		finished.emit()
	if _time >= DURATION:
		queue_free()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var tap: bool = (event is InputEventScreenTouch and event.pressed) \
			or (event is InputEventMouseButton and event.pressed)
	if tap and _time >= SKIP_AFTER and _time < DURATION - FADE_OUT:
		# Pular: vai direto para o fade de saída.
		_time = DURATION - FADE_OUT
		accept_event()


func _draw() -> void:
	var area := size if size.x > 1.0 and size.y > 1.0 else get_viewport_rect().size
	var fade_out := clampf((DURATION - _time) / FADE_OUT, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, area), Color(BG, fade_out))
	if fade_out <= 0.0:
		return
	var center := Vector2(area.x * 0.5, area.y * 0.42)
	# A chama acende (0–0,6 s) e o halo cresce até 1,2 s.
	var light := smoothstep(0.1, 0.7, _time)
	var halo := smoothstep(0.2, 1.2, _time)
	var flicker := 1.0 if _calm else 0.92 + 0.08 * sin(_time * 23.0) * sin(_time * 7.0)
	for ring: int in range(6, 0, -1):
		var r := (18.0 + ring * 16.0) * halo * flicker
		draw_circle(center, r, Color(1.0, 0.72, 0.3, 0.035 * light * fade_out))
	draw_circle(center, 7.0 * light * flicker, Color(1.0, 0.8, 0.4, 0.9 * fade_out))
	draw_circle(center + Vector2(0.0, -1.0), 3.5 * light, Color(1.0, 0.97, 0.85, fade_out))
	# Brasas subindo da lanterna.
	for e: Vector3 in _embers:
		var t := fmod(e.y + _time * e.z, 1.0)
		var at := center + Vector2(e.x * t + sin(t * 9.0 + e.x) * 4.0, -t * area.y * 0.4)
		var alpha := (1.0 - t) * light * fade_out
		draw_rect(Rect2(at.round(), Vector2.ONE * (2.0 if t < 0.3 else 1.0)), Color(1.0, 0.6, 0.25, alpha))
	# Nome e subtítulo entram depois da chama.
	var text_alpha := smoothstep(0.7, 1.3, _time) * fade_out
	var lift := (1.0 - smoothstep(0.7, 1.3, _time)) * 6.0
	_draw_centered("百鬼", Vector2(area.x * 0.5, center.y + 58.0 + lift), 24,
			Color(ThemeFactory.ACCENT, text_alpha * 0.8))
	_draw_centered("HYAKKI", Vector2(area.x * 0.5, center.y + 92.0 + lift), 36,
			Color(ThemeFactory.TEXT, text_alpha))
	_draw_centered(tr("title.subtitle"), Vector2(area.x * 0.5, center.y + 112.0 + lift), 12,
			Color(ThemeFactory.TEXT, text_alpha * 0.7))


func _draw_centered(text: String, baseline: Vector2, font_size: int, color: Color) -> void:
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var at := Vector2(roundf(baseline.x - width * 0.5), roundf(baseline.y))
	draw_string_outline(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0, 0, 0, color.a))
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
