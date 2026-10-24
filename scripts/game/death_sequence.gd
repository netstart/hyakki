class_name DeathSequence
extends Node
## Sequência de morte, antes de qualquer menu: o golpe letal congela o mundo (hit-stop), a
## guardiã tomba e fica no chão, a lanterna pisca e se apaga em fumaça, a música some, o mundo
## perde a cor e escurece, a câmera se aproxima do corpo e a HUD de jogo some. Com o reviver
## por anúncio disponível, a oferta aparece sobre a cena; sem ele (ou recusado), uma faixa de
## tinta sumi cruza a tela com o aviso da morte, e só então vêm os resultados.
## Tudo em tempo real: não depende da velocidade 1x/2x/3x nem do GameClock (o mundo fica parado).

## ~1 s depois do golpe: hora de oferecer o reviver (ou seguir para o aviso).
signal offer_due
## O aviso terminou (toque ou tempo): fim da partida. Emitido uma vez por morte.
signal finished

enum Phase { IDLE, DYING, NOTICE, RISING }

## Linha do tempo da morte (segundos desde o golpe letal).
const HITSTOP := 0.1
const FALL_START := 0.1
const FALL_TIME := 0.8
## Fração da queda em que o corpo toca o chão; depois, um quique pequeno e assenta.
const FALL_HIT := 0.62
const BOUNCE := 0.09
const CHILL_FROM := 0.15
const CHILL_TO := 1.0
const GONG_AT := 0.35
const LANTERN_FROM := 0.15
const LANTERN_OUT := 0.85
const GRADE_FROM := 0.1
const GRADE_TO := 1.4
## Aproximação da câmera: o corpo em pixel art precisa ler na tela do celular.
const ZOOM_TO := 1.75
const ZOOM_TIME := 2.0
const HUD_FADE := 0.5
const MUSIC_FADE := 0.8
const OFFER_AT := 1.0
const NOTICE_AT := 1.2
## Ponto da linha do tempo em que tudo já assentou (partida restaurada durante a morte).
const SETTLED := 2.0
## Enquadramento: o corpo fica no terço de cima (FOCUS_Y da altura), acima da faixa do aviso.
const FOCUS_Y := 0.4
## Raio (px de tela) da poça de luz que sobra em volta do corpo com a lanterna apagada.
const DARK_RADIUS := 64.0
## Levantar no reviver.
const RISE_TIME := 1.1
const RELIGHT_AT := 0.25
const WARM := Color(1.0, 0.82, 0.45)
## Aviso da morte (segundos desde o início do aviso).
const BAND_WIPE := 0.45
const NOTICE_GUARD := 0.6
const NOTICE_HINT := 1.2
const NOTICE_AUTO := 3.5
## Faixa de tinta: centro (fração da altura, terço de baixo), altura da imagem, meia altura do
## traço e a ponta translúcida do pincel.
const BAND_Y := 0.7
const BAND_IMAGE_H := 104
const BAND_HALF := 36.0
const BAND_LEAD := 14.0
const INK := Color(0.03, 0.025, 0.035, 0.97)
const INK_DRY := Color(0.13, 0.12, 0.14, 0.95)
## Fio vermelho-escuro nas bordas do traço: separa a tinta da noite sem brilho.
const INK_RIM := Color(0.38, 0.05, 0.05, 0.95)
## Título: fonte pixel 12 px em escala inteira (4×), branco-osso com sombra vermelho-sangue.
const TITLE_SIZE := 48
const TITLE_COLOR := Color(0.95, 0.92, 0.86)
const TITLE_SHADOW := Color(0.55, 0.05, 0.04)
## Selo 終: maior que a faixa, vermelho profundo, atrás e à direita do título.
const WATERMARK := "終"
const WATERMARK_SIZE := 120
const WATERMARK_COLOR := Color(0.62, 0.06, 0.05)
const WATERMARK_ALPHA := 0.26
const ASH_COUNT := 36
## Eventos que tocam uma vez por morte (bits de _fired).
const EV_GONG := 1
const EV_THUD := 2
const EV_SMOKE := 4
const EV_OFFER := 8
const EV_RELIGHT := 16
const GRADE_SHADER := "res://shaders/death_grade.gdshader"
const ResultsScreen := preload("res://scripts/app/screens/results_screen.gd")

var game: HyakkiGame
var phase: Phase = Phase.IDLE
## Tempo real desde o golpe letal e desde o início do aviso.
var elapsed: float = 0.0
var notice_time: float = 0.0
## O jingle de derrota já tocou nesta morte (o fim da partida não toca de novo).
var jingle_played: bool = false

var _fired: int = 0
var _notice_wanted: bool = false
var _done: bool = false
var _lantern_from: float = 0.0
var _grade_amount: float = 0.0
var _hud_alpha: float = 1.0
var _rise_time: float = 0.0
var _rise_done: Callable
var _rise_from: Dictionary = {}
var _grade: CanvasLayer
var _grade_rect: ColorRect
var _grade_material: ShaderMaterial
var _notice: CanvasLayer
var _root: Control
var _band: Control
var _band_tex: ImageTexture
var _title: Label
var _sub: Label
var _hint: Label
var _ash: Control
var _ash_pos := PackedVector2Array()
var _ash_speed := PackedFloat32Array()


func _ready() -> void:
	set_process_input(false)
	_grade = CanvasLayer.new()
	# Acima da escuridão da lanterna (5) e abaixo da HUD (10): a oferta de reviver fica nítida.
	_grade.layer = 6
	add_child(_grade)
	_grade_rect = ColorRect.new()
	_grade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_grade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grade_material = ShaderMaterial.new()
	_grade_material.shader = load(GRADE_SHADER) as Shader
	_grade_rect.material = _grade_material
	_grade_rect.visible = false
	_grade.add_child(_grade_rect)
	_build_notice()
	_ash_pos.resize(ASH_COUNT)
	_ash_speed.resize(ASH_COUNT)


## Nova partida: tudo de volta ao normal, sem sons.
func reset() -> void:
	_clear()
	jingle_played = false
	_done = false


func is_active() -> bool:
	return phase != Phase.IDLE


func notice_open() -> bool:
	return phase == Phase.NOTICE


## O aviso já aceita o toque para seguir (passou a trava contra toque acidental).
func can_skip() -> bool:
	return phase == Phase.NOTICE and notice_time >= NOTICE_GUARD and not _done


## Nó do aviso (o roteiro E2E toca nele).
func notice_control() -> Control:
	return _root


## Começa a morte. `restored`: partida salva durante a morte; o corpo já aparece deitado e a
## oferta (ou o aviso) vem na hora, sem repetir os sons.
func begin(restored: bool = false) -> void:
	phase = Phase.DYING
	elapsed = 0.0
	notice_time = 0.0
	jingle_played = false
	_fired = 0
	_notice_wanted = false
	_done = false
	_lantern_from = game.lantern.radius
	game.hud.joystick.release()
	if _band_tex == null or _band_tex.get_width() != int(game.view_size().x):
		_build_band(int(game.view_size().x))
	if restored:
		_fired = EV_GONG | EV_THUD | EV_SMOKE
		elapsed = SETTLED
		AudioManager.fade_music(AudioManager.MUSIC_SILENT, 0.3)
		_apply()
		_events()
		return
	# Hit-stop: o clarão branco do golpe (Player._hit_flash), tremor forte, vibração e um
	# taiko grave. O mundo já está parado (GameClock.paused) e assim fica até o fim.
	if bool(Settings.get_value("reduce_flashes")):
		game.player.clear_flash()
	game.shake(3.0)
	Settings.vibrate(200)
	AudioManager.play("j_taiko_0", 0.7)
	AudioManager.fade_music(AudioManager.MUSIC_SILENT, MUSIC_FADE)
	_apply()


## Sem reviver (recusado, sem anúncio, falhou ou acabou o tempo): o aviso da morte. Antes de
## NOTICE_AT ele espera, para o corpo terminar de cair.
func show_notice() -> void:
	if phase != Phase.DYING:
		return
	_notice_wanted = true
	if elapsed >= NOTICE_AT:
		_start_notice()


## Toque, clique, tecla ou "voltar" no aviso: segue para os resultados (depois da trava).
func skip() -> void:
	if can_skip():
		_finish()


## Reviver aceito e recompensado: o caminho inverso (levanta, a lanterna reacende com um anel
## quente, cor, câmera, música e HUD voltam). `done` é chamado no fim, com tudo normal.
func rise(done: Callable) -> void:
	if phase == Phase.IDLE:
		done.call()
		return
	phase = Phase.RISING
	_notice_wanted = false
	_rise_time = 0.0
	_rise_done = done
	_fired &= ~EV_RELIGHT
	var p := game.player
	_rise_from = {"down": p.down, "chill": p.chill, "grade": _grade_amount, "zoom": game.camera.zoom.x,
			"push": smoothstep(0.0, ZOOM_TIME, elapsed),
			"hud": _hud_alpha, "radius": game.lantern.radius}
	AudioManager.fade_music(0.0, MUSIC_FADE)


## Avança a sequência (o _process chama com o delta real; os testes podem chamar direto).
func advance(delta: float) -> void:
	match phase:
		Phase.DYING, Phase.NOTICE:
			elapsed += delta
			if elapsed > HITSTOP:
				# Efeitos já no ar terminam; a fumaça da lanterna sobe.
				game.fx.step(delta)
			_events()
			_apply()
			if phase == Phase.NOTICE:
				_advance_notice(delta)
			elif _notice_wanted and elapsed >= NOTICE_AT:
				_start_notice()
		Phase.RISING:
			_advance_rise(delta)


## Queda do corpo (0 → 1): acelera como quem tomba, toca o chão em FALL_HIT e dá um quique
## pequeno antes de assentar (ease-out com quique).
static func fall_curve(p: float) -> float:
	if p <= 0.0:
		return 0.0
	if p >= 1.0:
		return 1.0
	if p < FALL_HIT:
		var q := p / FALL_HIT
		return q * q
	var b := (p - FALL_HIT) / (1.0 - FALL_HIT)
	return 1.0 - BOUNCE * 4.0 * b * (1.0 - b)


func _process(delta: float) -> void:
	if phase != Phase.IDLE:
		advance(delta)


func _input(event: InputEvent) -> void:
	if phase != Phase.NOTICE:
		return
	var pressed := (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
			or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) \
			or (event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo)
	if pressed:
		get_viewport().set_input_as_handled()
		skip()


# --- Morte ----------------------------------------------------------------------------

func _events() -> void:
	if elapsed >= GONG_AT and _once(EV_GONG):
		AudioManager.play("j_gong", 0.8, 0.0, -2.0)
	if elapsed >= FALL_START + FALL_TIME * FALL_HIT and _once(EV_THUD):
		# O corpo bate no chão: baque surdo, poeira e um tremor curto.
		var p := game.player
		AudioManager.play("j_taiko_1", 0.55, 0.0, -8.0)
		game.shake(1.5)
		Settings.vibrate(40)
		game.fx.burst(p.sim_pos + Vector2(p.facing_x * p.body_height() * 0.6, 2.0), Color(0.55, 0.52, 0.5), 6)
	if elapsed >= LANTERN_OUT and _once(EV_SMOKE):
		var at := game.player.sim_pos + game.player.lantern_offset()
		game.fx.add_wisp(at, 9)
		game.fx.play_anim("smoke", at + Vector2(0.0, -12.0), 0.4, 0.0, Color(0.6, 0.62, 0.7, 0.45), 8.0)
	if elapsed >= OFFER_AT and _once(EV_OFFER):
		offer_due.emit()


## Estado de cada canal a partir do tempo (determinístico; a restauração pula para SETTLED).
func _apply() -> void:
	var p := game.player
	p.down = fall_curve((elapsed - FALL_START) / FALL_TIME)
	p.chill = smoothstep(CHILL_FROM, CHILL_TO, elapsed)
	p.glow = _lantern_glow(elapsed)
	_set_grade(smoothstep(GRADE_FROM, GRADE_TO, elapsed))
	var push := smoothstep(0.0, ZOOM_TIME, elapsed)
	_set_zoom(lerpf(1.0, ZOOM_TO, push))
	_frame(push)
	_set_hud(1.0 - clampf(elapsed / HUD_FADE, 0.0, 1.0))
	var dark := minf(DARK_RADIUS, _lantern_from)
	game.lantern.radius = lerpf(_lantern_from, dark, smoothstep(0.3, LANTERN_OUT + 0.3, elapsed))


## A lanterna esmorece, falha três vezes e se apaga em LANTERN_OUT. Com "reduce_flashes",
## só esmorece, sem piscar.
func _lantern_glow(t: float) -> float:
	if t >= LANTERN_OUT:
		return 0.0
	if t < LANTERN_FROM:
		return 1.0
	if not bool(Settings.get_value("reduce_flashes")):
		if (t > 0.24 and t < 0.29) or (t > 0.43 and t < 0.48) or (t > 0.62 and t < 0.66):
			return 0.08
	return (1.0 - 0.5 * smoothstep(LANTERN_FROM, 0.7, t)) * (1.0 - smoothstep(0.7, LANTERN_OUT, t))


func _once(bit: int) -> bool:
	if _fired & bit:
		return false
	_fired |= bit
	return true


func _set_grade(amount: float) -> void:
	_grade_amount = amount
	_grade_rect.visible = amount > 0.001
	if _grade_rect.visible:
		var view := game.view_size()
		_grade_material.set_shader_parameter("amount", amount)
		_grade_material.set_shader_parameter("aspect", view.x / maxf(view.y, 1.0))


func _set_zoom(z: float) -> void:
	game.camera.zoom = Vector2(z, z)


## Centro do corpo no mundo: entre os pés e a cabeça, que deitada fica para o lado da queda.
func corpse_center() -> Vector2:
	var p := game.player
	return p.sim_pos + Vector2(p.facing_x * p.body_height() * 0.45 * p.down, -2.0 - 6.0 * (1.0 - p.down))


## Enquadra o corpo (k = 0 normal, 1 = corpo no terço de cima, centrado na largura) e leva a
## poça de luz do shader até ele.
func _frame(k: float) -> void:
	var p := game.player
	var view := game.view_size()
	var zoom := game.camera.zoom.x
	var drop := view.y * (0.5 - FOCUS_Y) / zoom
	game.camera.position = (corpse_center() - p.sim_pos + Vector2(0.0, drop)) * k
	if _grade_rect.visible:
		var center := game.camera.get_screen_center_position()
		var uv := (corpse_center() - center) * zoom / view + Vector2(0.5, 0.5)
		_grade_material.set_shader_parameter("focus", uv)


func _set_hud(alpha: float) -> void:
	if not is_equal_approx(alpha, _hud_alpha):
		_hud_alpha = alpha
		game.hud.set_gameplay_alpha(alpha)


## Tudo de volta ao normal (fim do reviver ou nova partida).
func _clear() -> void:
	phase = Phase.IDLE
	_notice_wanted = false
	set_process_input(false)
	_notice.visible = false
	if game == null:
		return
	var p := game.player
	p.down = 0.0
	p.chill = 0.0
	p.glow = 1.0
	_set_grade(0.0)
	_set_zoom(1.0)
	game.camera.position = Vector2.ZERO
	_hud_alpha = -1.0
	_set_hud(1.0)


# --- Reviver ----------------------------------------------------------------------------

func _advance_rise(delta: float) -> void:
	_rise_time += delta
	game.fx.step(delta)
	var k := clampf(_rise_time / RISE_TIME, 0.0, 1.0)
	var p := game.player
	p.down = float(_rise_from["down"]) * (1.0 - smoothstep(0.0, 0.7, k))
	p.chill = float(_rise_from["chill"]) * (1.0 - smoothstep(0.0, 0.8, k))
	p.glow = smoothstep(RELIGHT_AT, RELIGHT_AT + 0.2, k)
	if k >= RELIGHT_AT and _once(EV_RELIGHT):
		# A lanterna reacende: anel quente e um sino claro.
		var at := p.sim_pos + p.lantern_offset()
		game.fx.add_ring(at, 36.0, WARM)
		game.fx.play_anim("circle_spark", at, 0.6, 0.0, WARM)
		AudioManager.play("j_temple_bell", 1.15, 0.0, -6.0)
	_set_grade(float(_rise_from["grade"]) * (1.0 - smoothstep(0.0, 0.9, k)))
	var back := smoothstep(0.0, 1.0, k)
	_set_zoom(lerpf(float(_rise_from["zoom"]), 1.0, back))
	_frame(float(_rise_from["push"]) * (1.0 - back))
	_set_hud(lerpf(float(_rise_from["hud"]), 1.0, smoothstep(0.4, 1.0, k)))
	game.lantern.radius = lerpf(float(_rise_from["radius"]), _lantern_from, smoothstep(0.2, 0.8, k))
	if k >= 1.0:
		_clear()
		var done := _rise_done
		_rise_done = Callable()
		if done.is_valid():
			done.call()


# --- Aviso da morte ---------------------------------------------------------------------

func _start_notice() -> void:
	phase = Phase.NOTICE
	notice_time = 0.0
	_notice_wanted = false
	if not jingle_played:
		jingle_played = true
		AudioManager.play("jingle_gameover")
	# O pincel atravessa a tela.
	AudioManager.play("whoosh", 0.55, 0.0, -6.0)
	var cause := String(game.player.damage.summary().get("cause", ""))
	_title.text = tr("death.title")
	_sub.text = "%s   ·   %s" % [tr("death.cause") % ResultsScreen.source_name(cause),
			tr("death.survived") % Screen.format_time(GameClock.game_time)]
	_hint.text = tr("death.tap")
	var view := game.view_size()
	for i: int in range(ASH_COUNT):
		_ash_pos[i] = Vector2(randf() * view.x, randf_range(-view.y, view.y))
		_ash_speed[i] = randf_range(7.0, 16.0)
	_notice.visible = true
	set_process_input(true)
	_paint_notice()


func _advance_notice(delta: float) -> void:
	notice_time += delta
	var view := game.view_size()
	for i: int in range(ASH_COUNT):
		var at := _ash_pos[i]
		at.y += _ash_speed[i] * delta
		at.x += sin(notice_time * 1.3 + i) * 6.0 * delta
		if at.y > view.y + 2.0:
			at = Vector2(randf() * view.x, -3.0)
		_ash_pos[i] = at
	_paint_notice()
	if notice_time >= NOTICE_AUTO:
		_finish()


func _paint_notice() -> void:
	var n := notice_time
	var rise := smoothstep(0.3, 0.9, n)
	_title.modulate.a = rise
	_title.pivot_offset = _title.size * 0.5
	_title.scale = Vector2.ONE * lerpf(1.12, 1.0, rise)
	_sub.modulate.a = smoothstep(0.65, 1.15, n)
	_hint.visible = n >= NOTICE_HINT
	_hint.modulate.a = 0.35 + 0.65 * (0.5 + 0.5 * cos((n - NOTICE_HINT) * 5.0))
	_band.queue_redraw()
	_ash.queue_redraw()


func _finish() -> void:
	if _done:
		return
	_done = true
	set_process_input(false)
	finished.emit()


func _build_notice() -> void:
	_notice = CanvasLayer.new()
	# Acima da HUD (10) e abaixo do anúncio simulado (100).
	_notice.layer = 12
	_notice.visible = false
	add_child(_notice)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.theme = ThemeFactory.build()
	_notice.add_child(_root)
	_band = _full_rect(Control.new())
	_band.draw.connect(_draw_band)
	_root.add_child(_band)
	_title = _centered_label(TITLE_SIZE, TITLE_COLOR, -40.0, 14.0)
	_title.add_theme_color_override("font_shadow_color", TITLE_SHADOW)
	_title.add_theme_constant_override("shadow_offset_x", 4)
	_title.add_theme_constant_override("shadow_offset_y", 4)
	_title.add_theme_constant_override("shadow_outline_size", 0)
	_sub = _centered_label(12, Color(0.76, 0.75, 0.78), 14.0, 28.0)
	_hint = _centered_label(12, Color(0.88, 0.86, 0.82), 0.0, 0.0)
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_top = -28.0
	_hint.offset_bottom = -12.0
	_ash = _full_rect(Control.new())
	_ash.draw.connect(_draw_ash)
	_root.add_child(_ash)


func _centered_label(font_size: int, color: Color, top: float, bottom: float) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.anchor_right = 1.0
	label.anchor_top = BAND_Y
	label.anchor_bottom = BAND_Y
	label.offset_top = top
	label.offset_bottom = bottom
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 0)
	_root.add_child(label)
	return label


func _full_rect(control: Control) -> Control:
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return control


## Traço de tinta sumi pintado uma vez numa imagem (bordas irregulares, começo arredondado,
## ponta seca à direita, falhas do pincel seco e respingos). O aviso só revela a imagem: uma
## chamada de desenho por quadro, sem montar polígonos no Android.
func _build_band(width: int) -> void:
	width = maxi(width, 16)
	var img := Image.create_empty(width, BAND_IMAGE_H, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1909
	var c := BAND_IMAGE_H * 0.5
	var ph := PackedFloat32Array([rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU])
	for x: int in range(width):
		var edge := sqrt(minf(1.0, x / 14.0) * minf(1.0, (width - 1 - x) / 70.0))
		var half := BAND_HALF * edge
		var wave_top := 2.2 * sin(x * 0.029 + ph[0]) + 1.3 * sin(x * 0.091 + ph[1])
		var wave_bottom := 2.0 * sin(x * 0.034 + ph[2]) + 1.2 * sin(x * 0.077 + ph[3])
		var top := roundi(c - half + wave_top + rng.randf_range(-0.6, 0.6))
		var bottom := roundi(c + half + wave_bottom + rng.randf_range(-0.6, 0.6))
		if bottom > top + 2:
			img.fill_rect(Rect2i(x, top, 1, bottom - top), INK)
			img.set_pixel(x, top, INK_RIM)
			img.set_pixel(x, bottom - 1, INK_RIM)
	for k: int in range(22):
		var y := roundi(c) + rng.randi_range(-int(BAND_HALF) + 4, int(BAND_HALF) - 4)
		var x0 := rng.randi_range(20, maxi(21, width - 140))
		img.fill_rect(Rect2i(x0, y, rng.randi_range(20, 120), 1), INK_DRY)
	for k: int in range(18):
		var side := 1 if rng.randf() < 0.5 else -1
		var y := roundi(c) + side * (int(BAND_HALF) + rng.randi_range(4, 10))
		var s := rng.randi_range(1, 2)
		img.fill_rect(Rect2i(rng.randi_range(0, width - 2), y, s, s), INK)
	_band_tex = ImageTexture.create_from_image(img)


func _draw_band() -> void:
	var size := _band.size
	var n := notice_time
	_band.draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.12 * smoothstep(0.0, 0.5, n)))
	if _band_tex == null:
		return
	var w := float(_band_tex.get_width())
	var h := float(_band_tex.get_height())
	var y0 := roundf(size.y * BAND_Y - h * 0.5)
	var wipe := clampf(n / BAND_WIPE, 0.0, 1.0)
	var reveal := (1.0 - (1.0 - wipe) * (1.0 - wipe)) * (w + BAND_LEAD)
	var shown := roundf(minf(reveal, w))
	if shown > 0.0:
		_band.draw_texture_rect_region(_band_tex, Rect2(0.0, y0, shown, h), Rect2(0.0, 0.0, shown, h))
	var lead := minf(BAND_LEAD, w - shown)
	if lead > 0.0 and wipe < 1.0:
		# Ponta do pincel: a tinta ainda chegando, translúcida.
		_band.draw_texture_rect_region(_band_tex, Rect2(shown, y0, lead, h), Rect2(shown, 0.0, lead, h),
				Color(1.0, 1.0, 1.0, 0.45))
	var mark := smoothstep(0.2, 0.9, n) * WATERMARK_ALPHA
	if mark > 0.0:
		# Selo: à direita do título, um pouco acima, maior que a faixa.
		var font := _root.get_theme_default_font()
		var title_w := font.get_string_size(_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE).x
		var mark_w := font.get_string_size(WATERMARK, HORIZONTAL_ALIGNMENT_LEFT, -1, WATERMARK_SIZE).x
		var x := minf(size.x * 0.5 + title_w * 0.5 - mark_w * 0.15, size.x - mark_w - 4.0)
		var baseline := size.y * BAND_Y + (font.get_ascent(WATERMARK_SIZE) - font.get_descent(WATERMARK_SIZE)) * 0.5 - 8.0
		_band.draw_string(font, Vector2(roundf(x), roundf(baseline)), WATERMARK, HORIZONTAL_ALIGNMENT_LEFT, -1,
				WATERMARK_SIZE, Color(WATERMARK_COLOR.r, WATERMARK_COLOR.g, WATERMARK_COLOR.b, mark))


## Cinzas caindo devagar sobre o aviso.
func _draw_ash() -> void:
	var fade := smoothstep(0.0, 0.6, notice_time)
	for i: int in range(ASH_COUNT):
		var s := 2.0 if i % 3 == 0 else 1.0
		_ash.draw_rect(Rect2(_ash_pos[i].round(), Vector2(s, s)), Color(0.78, 0.78, 0.8, (0.35 + 0.3 * (i % 2)) * fade))
