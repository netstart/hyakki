class_name DialoguePanel
extends Control
## Diálogo antes de um chefe (plano: chefes das 10:00 e Guardiões do Limiar), sobre a luta
## parada: o mundo recua sob o véu (OverlayFx) e uma caixa de papel do Ninja Adventure
## (assets/art/ui/dialog/DialogueBoxSimple.png, CC0) sobe do pé da tela com o retrato 38x38 de quem fala
## na moldura FacesetBox.png: a guardiã ou o guardião e os companheiros (Tora, Hana, Rin) à
## esquerda, o chefe à direita, com o nome em dourado e a fala em tinta escura, letra a letra.
## - toque, clique ou "aceitar": completa a fala que ainda está aparecendo; depois, a próxima;
## - "Pular" encerra o diálogo inteiro; ao fim emite `finished` (a HUD repassa ao HyakkiGame,
##   que segue com a entrada do chefe e solta o relógio);
## - bloqueio contra toque acidental (LOCK_MS ao abrir, LINE_LOCK_MS a cada fala): quem estava
##   segurando o joystick não pula a abertura sem querer.
## Layout puro em box_layout(view, insets) (testes em todas as resoluções de
## tests/device_profiles.gd, com o furo da câmera dos dois lados). GfxQuality "ui_fx": 0 = sem
## subida da caixa nem seta balançando; "Reduzir clarões" também deixa a seta parada.
## Tempo real: igual em 1x, 2x e 3x; o bot fecha na hora (bot_finish).

signal finished

const BOX_PATH := "res://assets/art/ui/dialog/DialogueBoxSimple.png"
const FRAME_PATH := "res://assets/art/ui/dialog/FacesetBox.png"
## A caixa inteira como nine-patch (cantos arredondados de 8 px) e a moldura do retrato.
const BOX_REGION := Rect2(0, 0, 316, 60)
const BOX_EDGE := 8
const FRAME_EDGE := 5
## Folga até a área segura, folga interna da caixa e distância entre retrato e texto.
const MARGIN := 8.0
const PAD := 8.0
const GAP := 8.0
const MAX_W := 520.0
const FRAME := 48.0
const FACE := 38.0
const FONT_SIZE := 12
## Altura de linha usada quando a fonte do idioma não está à mão (testes puros).
const LINE_H := 14.0
## Linhas reservadas para a fala (a mais longa dos 11 idiomas cabe na tela mais estreita).
const TEXT_LINES := 4
const SKIP_W := 72.0
const SKIP_H := 26.0
const SKIP_GAP := 4.0
const LOCK_MS := 350
const LINE_LOCK_MS := 150
## Letras por segundo da fala aparecendo.
const TYPE_SPEED := 60.0
const FADE_IN := 0.22
const FADE_OUT := 0.18
const INK := Color("2a1a10")
const NAME_COLOR := Color("ffd166")

static var _faces: Dictionary = {}

var _open: bool = false
var _lines: Array[Dictionary] = []
var _index: int = -1
var _opened_at: int = 0
var _line_at: int = 0
var _shown: float = 0.0
var _time: float = 0.0
var _fx_level: int = 2
var _rects: Dictionary = {}
var _face: Texture2D
var _name: String = ""
var _side: String = "left"
var _rise: float = 0.0
var _tweens: Array[Tween] = []

var _fx: OverlayFx
var _box: Control
var _text: Label
var _skip: Button
var _box_style: StyleBoxTexture
var _frame_style: StyleBoxTexture


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_fx = OverlayFx.new()
	_fx.ray_color = Color(1.0, 0.8, 0.6)
	add_child(_fx)
	_box_style = _nine(BOX_PATH, BOX_REGION, BOX_EDGE)
	_frame_style = _nine(FRAME_PATH, Rect2(0, 0, 48, 48), FRAME_EDGE)
	_box = Control.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_box.draw.connect(_draw_box)
	add_child(_box)
	_text = Label.new()
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	# As palavras já ficam na linha final enquanto as letras aparecem (sem pular de linha).
	_text.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_text.add_theme_font_override("font", _font())
	_text.add_theme_font_size_override("font_size", FONT_SIZE)
	_text.add_theme_color_override("font_color", INK)
	_text.add_theme_constant_override("outline_size", 0)
	_text.add_theme_constant_override("line_spacing", 0)
	_text.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	_box.add_child(_text)
	_skip = Button.new()
	_skip.name = "DialogueSkip"
	_skip.focus_mode = Control.FOCUS_NONE
	ThemeFactory.apply_button_boxes(_skip, ThemeFactory.lacquer_button_boxes())
	_skip.add_theme_color_override("font_color", UiPaint.DIM)
	_skip.pressed.connect(skip)
	add_child(_skip)
	resized.connect(_layout)
	# Furo da câmera que troca de lado com a tela aberta (giro de 180°).
	MenuKit.on_insets_change(self, _layout)
	Settings.changed.connect(func(key: String) -> void:
		if key == GfxQuality.changed_signal_key():
			_apply_quality())
	_apply_quality()


# --- Layout puro ---------------------------------------------------------------------------

## Retângulos do diálogo na tela `view` com o recorte `insets` (esquerda, direita): "box" (a caixa,
## no pé da área segura), "frame" (moldura do retrato), "portrait" (38x38), "name" (nome de quem
## fala), "text" (TEXT_LINES linhas da fala) e "skip" (botão Pular, acima da caixa, à direita).
## `side` "left" põe o retrato à esquerda (herói e companheiros); "right", à direita (chefe).
## `line_h` é a altura de linha da fonte do idioma e `skip_w` a largura do botão.
static func box_layout(view: Vector2, insets: Vector2, side: String = "left", line_h: float = LINE_H,
		skip_w: float = SKIP_W) -> Dictionary:
	var safe := Rect2(insets.x, 0.0, view.x - insets.x - insets.y, view.y).grow(-MARGIN)
	var w := floorf(minf(safe.size.x, MAX_W))
	var inner_h := maxf(FRAME, ceilf(line_h) * (TEXT_LINES + 1) + 2.0)
	var h := inner_h + PAD * 2.0
	var box := Rect2(floorf(safe.get_center().x - w * 0.5), floorf(safe.end.y - h), w, h)
	var frame := Rect2(box.position.x + PAD, box.position.y + PAD, FRAME, FRAME)
	var col_x := frame.end.x + GAP
	var col_w := box.end.x - PAD - col_x
	if side == "right":
		frame.position.x = box.end.x - PAD - FRAME
		col_x = box.position.x + PAD
		col_w = frame.position.x - GAP - col_x
	var inset := floorf((FRAME - FACE) * 0.5)
	var portrait := Rect2(frame.position + Vector2(inset, inset), Vector2(FACE, FACE))
	var name := Rect2(col_x, box.position.y + PAD, col_w, ceilf(line_h))
	var text := Rect2(col_x, name.end.y + 2.0, col_w, ceilf(line_h) * TEXT_LINES)
	var sw := minf(skip_w, w)
	var skip_rect := Rect2(box.end.x - sw, box.position.y - SKIP_GAP - SKIP_H, sw, SKIP_H)
	return {"box": box, "frame": frame, "portrait": portrait, "name": name, "text": text, "skip": skip_rect}


## Linhas que `value` ocupa com quebra de palavra na largura `width` (fonte do idioma, 12).
static func line_count(value: String, width: float, font: Font = null) -> int:
	var f := font if font != null else _font()
	var h := f.get_multiline_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, width, FONT_SIZE).y
	return maxi(1, roundi(h / f.get_height(FONT_SIZE)))


## A fala `value` cabe inteira na área de texto de largura `width` (nenhuma palavra maior que a
## linha, no máximo TEXT_LINES linhas).
static func text_fits(value: String, width: float, font: Font = null) -> bool:
	var f := font if font != null else _font()
	for word: String in value.split(" ", false):
		# Japonês e chinês não separam palavras: a quebra cai entre quaisquer caracteres.
		if _wraps_anywhere(word):
			continue
		if f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x > width + 0.5:
			return false
	return line_count(value, width, f) <= TEXT_LINES


## Trecho com kana ou ideogramas (U+3000 a U+9FFF, U+F900 a U+FAFF, U+FF00 a U+FFEF).
static func _wraps_anywhere(word: String) -> bool:
	for i: int in word.length():
		var code := word.unicode_at(i)
		if (code >= 0x3000 and code <= 0x9FFF) or (code >= 0xF900 and code <= 0xFAFF) \
				or (code >= 0xFF00 and code <= 0xFFEF):
			return true
	return false


static func _font() -> Font:
	return Locale.font if Locale.font != null else ThemeDB.fallback_font


static func line_height() -> float:
	return ceilf(_font().get_height(FONT_SIZE))


## Retrato de quem fala, 38x38 desenhado com filtro "nearest". Um Faceset que não é o quadrado de
## 38 (Onibi e Yomi-hebi usam a folha inteira) vira o recorte quadrado do que está desenhado,
## a partir do topo (a cabeça).
static func face_texture(path: String) -> Texture2D:
	if _faces.has(path):
		return _faces[path]
	var tex: Texture2D = null
	if not path.is_empty() and ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	if tex != null and tex.get_size() != Vector2(FACE, FACE):
		var image := tex.get_image()
		if image != null:
			if image.is_compressed():
				image.decompress()
			var used := image.get_used_rect()
			if used.size.x > 0 and used.size.y > 0:
				var side := mini(used.size.x, used.size.y)
				var region := Rect2(used.position.x + floori((used.size.x - side) * 0.5), used.position.y, side, side)
				var atlas := AtlasTexture.new()
				atlas.atlas = tex
				atlas.region = region
				tex = atlas
	_faces[path] = tex
	return tex


# --- API -----------------------------------------------------------------------------------

## Abre com as falas de DialogueScript.build (vazio: não abre).
func open(lines: Array[Dictionary]) -> void:
	_kill_tweens()
	if lines.is_empty():
		return
	_lines = lines.duplicate()
	_open = true
	_opened_at = Time.get_ticks_msec()
	visible = true
	modulate.a = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	_skip.text = tr("story.skip")
	_skip.disabled = false
	# A fonte segue o idioma atual (o painel pode ter nascido em outro).
	_text.add_theme_font_override("font", _font())
	_apply_quality()
	_show_line(0)
	_fx.power = 0.0
	_fx.rays = 0.0
	_rise = 0.0 if _fx_level == 0 else 1.0
	var t := _tween()
	t.tween_property(_fx, "power", 1.0, FADE_IN)
	t.parallel().tween_property(_fx, "rays", 0.35, FADE_IN * 2.0)
	if _fx_level > 0:
		t.parallel().tween_property(self, "_rise", 0.0, FADE_IN).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	AudioManager.play("paper_flutter", 1.0, 0.0, -8.0)


## Fecha na hora, sem animação nem sinal (nova partida).
func close_now() -> void:
	_kill_tweens()
	_open = false
	_lines.clear()
	_index = -1
	_fx.power = 0.0
	visible = false


func is_open() -> bool:
	return _open


## Pula a entrada e mostra a fala atual inteira (testes de layout).
func finish_intro() -> void:
	_kill_tweens()
	_fx.power = 1.0
	_fx.rays = 0.35
	_rise = 0.0
	_reveal_all()


## Bot de testes: termina o diálogo na hora (no mesmo quadro, antes do próximo passo).
func bot_finish() -> void:
	if not _open:
		return
	close_now()
	finished.emit()


## Toque ou "aceitar": completa a fala aparecendo, senão passa para a próxima.
func advance() -> void:
	if not _open:
		return
	var now := Time.get_ticks_msec()
	if now - _opened_at < LOCK_MS or now - _line_at < LINE_LOCK_MS:
		return
	if _text.visible_characters >= 0 and _text.visible_characters < _text.get_total_character_count():
		_reveal_all()
		return
	AudioManager.play_ui("ui_move")
	_show_line(_index + 1)


## "Pular": encerra o diálogo inteiro.
func skip() -> void:
	if not _open:
		return
	AudioManager.play_ui("ui_accept")
	_finish()


func lines() -> Array[Dictionary]:
	return _lines


func line_index() -> int:
	return _index


## Fala atual (traduzida) e o nome de quem fala.
func current_text() -> String:
	return _text.text


func speaker_name() -> String:
	return _name


func current_side() -> String:
	return _side


func portrait() -> Texture2D:
	return _face


func text_label() -> Label:
	return _text


func skip_button() -> Button:
	return _skip


func overlay() -> OverlayFx:
	return _fx


## Retângulos do layout atual, no espaço do painel (ver box_layout).
func layout_rects() -> Dictionary:
	return _rects


# --- Interno -------------------------------------------------------------------------------

func _show_line(index: int) -> void:
	if index >= _lines.size():
		_finish()
		return
	_index = index
	_line_at = Time.get_ticks_msec()
	var line := _lines[index]
	_side = String(line.get("side", "left"))
	_name = tr(DialogueScript.name_key(line))
	_face = face_texture(DialogueScript.face_path(line))
	_text.text = tr(String(line.get("text_key", "")))
	_shown = 0.0
	_text.visible_characters = 0
	_layout()


func _reveal_all() -> void:
	_text.visible_characters = -1
	_shown = float(_text.get_total_character_count())


## Fim: deixa de contar como aberto na hora (a luta volta já) e some num instante.
func _finish() -> void:
	_kill_tweens()
	_open = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skip.disabled = true
	var t := _tween()
	t.tween_property(_fx, "power", 0.0, FADE_OUT)
	t.parallel().tween_property(self, "modulate:a", 0.0, FADE_OUT)
	t.tween_callback(func() -> void:
		if not _open:
			visible = false
			modulate.a = 1.0)
	finished.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		advance()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if _open and event.is_action_pressed(&"ui_accept"):
		advance()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	if _open and _text.visible_characters >= 0:
		_shown += delta * TYPE_SPEED
		var total := _text.get_total_character_count()
		if _shown >= total:
			_reveal_all()
		else:
			_text.visible_characters = int(_shown)
	# A seta "continua" balança (só redesenha a caixa enquanto há o que animar).
	if _rise > 0.0 or _bob_on():
		_box.queue_redraw()
	_text.position = _rects.get("text", Rect2()).position + Vector2(0.0, _rise_offset())


func _bob_on() -> bool:
	return _open and _fx_level > 0 and not _calm() and _text.visible_characters < 0


func _rise_offset() -> float:
	return roundf(_rise * 14.0)


func _calm() -> bool:
	return bool(Settings.get_value("reduce_flashes"))


func _layout() -> void:
	var view := size
	if view.x <= 0.0:
		return
	var skip_w := maxf(SKIP_W, ceilf(_skip.get_combined_minimum_size().x))
	_rects = box_layout(view, MenuKit.safe_insets(self), _side, line_height(), skip_w)
	var text: Rect2 = _rects["text"]
	_text.position = text.position + Vector2(0.0, _rise_offset())
	_text.size = text.size
	var skip_rect: Rect2 = _rects["skip"]
	_skip.position = skip_rect.position
	_skip.size = skip_rect.size
	var box: Rect2 = _rects["box"]
	_fx.ray_origin = Vector2(box.get_center().x, box.position.y)
	_box.queue_redraw()


func _draw_box() -> void:
	if _rects.is_empty() or _index < 0:
		return
	var dy := Vector2(0.0, _rise_offset())
	var box: Rect2 = _rects["box"]
	_box.draw_style_box(_box_style, Rect2(box.position + dy, box.size))
	var frame: Rect2 = _rects["frame"]
	_box.draw_style_box(_frame_style, Rect2(frame.position + dy, frame.size))
	if _face != null:
		var p: Rect2 = _rects["portrait"]
		_box.draw_texture_rect(_face, Rect2(p.position + dy, p.size), false)
	var name_rect: Rect2 = _rects["name"]
	var align := HORIZONTAL_ALIGNMENT_RIGHT if _side == "right" else HORIZONTAL_ALIGNMENT_LEFT
	var base := name_rect.position + dy + Vector2(0.0, _font().get_ascent(FONT_SIZE))
	UiPaint.text(_box, base, _name, FONT_SIZE, NAME_COLOR, align, name_rect.size.x, 2, UiPaint.OUTLINE, _font())
	# Seta "continua" no canto de baixo da caixa quando a fala já apareceu inteira.
	if _open and _text.visible_characters < 0:
		var bob := roundf(sin(_time * 6.0)) if _bob_on() else 0.0
		var tip := Vector2(box.end.x - PAD - 6.0, box.end.y - 4.0 + bob) + dy
		for row: int in 3:
			_box.draw_rect(Rect2(tip.x - 2.0 + row, tip.y - 3.0 + row, 5.0 - row * 2.0, 1.0), INK)


func _apply_quality() -> void:
	_fx_level = int(GfxQuality.budget("ui_fx"))
	if _fx:
		_fx.apply_quality()


static func _nine(path: String, region: Rect2, edge: int) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	if ResourceLoader.exists(path):
		box.texture = load(path) as Texture2D
	box.region_rect = region
	box.set_texture_margin_all(edge)
	box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	return box


func _tween() -> Tween:
	var t := create_tween()
	_tweens.append(t)
	return t


func _kill_tweens() -> void:
	for t: Tween in _tweens:
		if t.is_valid():
			t.kill()
	_tweens.clear()
