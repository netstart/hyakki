class_name TipBalloon
extends Control
## Balão de fala (fukidashi) da guardiã na tela de título, com as dicas 心得 (TipDeck/TipBook).
## Papel do Ninja Adventure (DialogueBoxSimple.png, o mesmo do DialoguePanel) com rabicho
## apontando para a cabeça da guardiã sob o torii (MenuBackdrop.hero_rect); selinho vermelho
## com 心得 e o rótulo da categoria; nas dicas de combo, os ícones da receita (arma + relíquia =
## evolução); a dica em tinta escura, letra a letra.
## - aparece APPEAR_DELAY s depois de o título abrir (a entrada já acabou), com um "pop" sutil;
## - tocar no balão completa o texto ou passa para a próxima dica; troca sozinha a cada
##   ROTATE_EVERY s; o "×" fecha até o título abrir de novo; some ao sair da tela;
## - não pega foco (Jogar continua com o foco do teclado e do controle);
## - tempo real (independe de 1x/2x/3x); "Reduzir clarões" e GfxQuality "ui_fx" 0 desligam o pop,
##   e "ui_fx" 0 também mostra o texto inteiro de uma vez;
## - o desenho do balão (papel, rabicho, selo, ícones, ×) fica assado (StaticBake), refeito só
##   quando a dica ou o layout mudam; nada é redesenhado enquanto ele está parado.
## Layout puro em balloon_layout() (testes em todas as resoluções de tests/device_profiles.gd, nos
## 11 idiomas, com a dica mais longa de cada um e o furo da câmera dos dois lados): entre a coluna
## do menu e o bloco de ação, abaixo do título e do saldo, dentro da área segura, sem cobrir
## nada; acima da cabeça da guardiã, ou ao lado dela quando não cabe em cima.

signal closed
## O balão só coube por cima de um retângulo "soft" do contexto (Próximas metas do título): quem o
## mostrou esconde o bloco enquanto o balão fala (covered = true) e o volta quando ele some.
signal soft_cover_changed(covered: bool)

## Estados: escondido, esperando para aparecer, letras aparecendo, parado e fechado pelo ×.
enum { HIDDEN, WAITING, TYPING, IDLE, DISMISSED }

const BOX_PATH := "res://assets/art/ui/dialog/DialogueBoxSimple.png"
const BOX_REGION := Rect2(0, 0, 316, 60)
const BOX_EDGE := 8
## Cores da DialogueBoxSimple.png: contorno, moldura e papel (o rabicho continua a caixa).
const OUTLINE := Color8(20, 27, 27)
const FRAME := Color8(150, 83, 64)
const PAPER := Color8(242, 234, 241)
const INK := Color("2a1a10")
const CAT_INK := Color("9e2a1e")
const SEAL_RED := Color("b3261e")
const SEAL_TEXT := Color("fbe6cf")
## Folga até a área segura e até o que não pode ser coberto; folgas internas do papel.
const MARGIN := 6.0
const GAP := 6.0
const PAD_X := 9.0
const PAD_Y := 8.0
const HEADER_H := 16.0
const HEADER_GAP := 3.0
const ICON := 16.0
const ICON_GAP := 2.0
## Largura do "+" e do "=" entre os ícones da receita.
const GLYPH_W := 7.0
## "×": lado do desenho (traço de 2 px, legível em escala 1 e nas capturas) e área de toque.
const CLOSE := 9.0
const CLOSE_HIT := 24.0
## Rabicho: comprimento mínimo, meia largura da base e folga até a cabeça.
const TAIL_H := 9.0
const TAIL_HALF := 6.0
const HEAD_GAP := 2.0
const MAX_W := 272.0
const MIN_W := 150.0
const WIDTH_STEP := 16.0
const MAX_LINES := 5
const FONT_SIZE := 12
## Altura de linha usada quando a fonte do idioma não está à mão (testes puros).
const LINE_H := 14.0
## Pontos a mais para o balão ao lado da guardiã (prefere o de cima).
const SIDE_PENALTY := 60.0
## Letras por segundo, espera antes de aparecer, troca automática e tempos do pop (s, reais).
const TYPE_SPEED := 45.0
const APPEAR_DELAY := 1.0
const ROTATE_EVERY := 14.0
const POP_TIME := 0.2
const FADE_TIME := 0.12
## Toques muito rápidos depois de aparecer não passam a dica (ms).
const TAP_LOCK_MS := 250

static var _box_style: StyleBoxTexture

## Devolve {view, insets, hero (Rect2), blockers (Array[Rect2]), soft (Array[Rect2], opcional:
## evitados se der)} no espaço do pai.
var context_provider: Callable = Callable()
var _tip: Dictionary = {}
var _text_value: String = ""
var _category: String = ""
var _icons: Array[Texture2D] = []
var _layout: Dictionary = {}
var _label: Label
var _bake: StaticBake
var _state := 0
var _wait := 0.0
var _shown := 0.0
var _idle := 0.0
var _shown_at := 0
var _dirty := false
var _tween: Tween
var _covering := false



func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false
	tooltip_text = tr("tip.next")
	_bake = StaticBake.new(_paint)
	_bake.name = "StaticBake"
	_bake.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bake)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	# As palavras já ficam na linha final enquanto as letras aparecem (sem pular de linha).
	_label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", INK)
	_label.add_theme_constant_override("outline_size", 0)
	_label.add_theme_constant_override("line_spacing", 0)
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	add_child(_label)
	set_process(false)
	visibility_changed.connect(func() -> void:
		if not visible:
			_set_covering(false))


# --- Layout puro ---------------------------------------------------------------------------

## Retângulos do balão na tela `view` com o recorte `insets` (esquerda, direita), para a guardiã em
## `hero` e sem cobrir nenhum retângulo de `blockers` (título, saldo, menu, bloco de ação...).
## `head_w` é a largura do selo + categoria, `chain_w` a dos ícones da receita (0 = sem ícones),
## `text` a dica no idioma atual (quebrada com `font`, altura de linha `line_h`).
## Devolve {ok, box, text, header, seal, chain, icons_row, close (toque), close_glyph (desenho do
## ×), tail (base 1, base 2, ponta),
## side ("above", "right" ou "left"), lines}; ok = false se não couber em lugar nenhum.
static func balloon_layout(view: Vector2, insets: Vector2, hero: Rect2, blockers: Array[Rect2], text: String,
		head_w: float, chain_w: float, font: Font = null, line_h: float = LINE_H) -> Dictionary:
	var safe := Rect2(insets.x, 0.0, view.x - insets.x - insets.y, view.y).grow(-MARGIN)
	var blocks: Array[Rect2] = blockers.duplicate()
	blocks.append(hero.grow(2.0))
	var best: Dictionary = {}
	var best_score := INF
	var w := floorf(minf(MAX_W, safe.size.x))
	var tried: Array[float] = []
	while w >= MIN_W:
		tried.append(w)
		w -= WIDTH_STEP
	if tried.is_empty() or tried.back() > MIN_W:
		tried.append(MIN_W)
	for width: float in tried:
		var inner := width - PAD_X * 2.0
		var lines := line_count(text, inner, font)
		if lines > MAX_LINES or not words_fit(text, inner, font):
			continue
		var icons_row := chain_w > 0.0 and head_w + GAP + chain_w + GAP + CLOSE + 4.0 > inner
		var height := PAD_Y * 2.0 + HEADER_H + HEADER_GAP + ceilf(line_h) * lines
		if icons_row:
			height += ICON + HEADER_GAP
		for side: String in ["above", "right", "left"]:
			var pick := _place(safe, blocks, hero, Vector2(width, height), side)
			if pick.is_empty():
				continue
			var score := float(pick["score"]) + lines * 2.0 + (SIDE_PENALTY if side != "above" else 0.0)
			if score < best_score:
				best_score = score
				best = {"box": pick["box"], "side": side, "lines": lines, "icons_row": icons_row}
	if best.is_empty():
		return {"ok": false}
	return _finish(best, hero, head_w, chain_w, line_h)


## Melhor posição de um balão `size` do lado `side` da guardiã: {box, score} ou {}.
static func _place(safe: Rect2, blocks: Array[Rect2], hero: Rect2, size: Vector2, side: String) -> Dictionary:
	var head := Vector2(hero.get_center().x, hero.position.y)
	var xs: Array[float] = [safe.position.x, safe.end.x - size.x]
	var ys: Array[float] = [safe.position.y, safe.end.y - size.y]
	for b: Rect2 in blocks:
		xs.append_array([b.end.x + GAP, b.position.x - GAP - size.x])
		ys.append_array([b.end.y + GAP, b.position.y - GAP - size.y])
	var bottom_max := INF
	match side:
		"above":
			bottom_max = head.y - HEAD_GAP - TAIL_H
			xs.append(head.x - size.x * 0.5)
			ys.append(bottom_max - size.y)
		"right":
			xs.append(hero.end.x + TAIL_H + GAP)
			ys.append(hero.get_center().y - size.y * 0.5)
		"left":
			xs.append(hero.position.x - TAIL_H - GAP - size.x)
			ys.append(hero.get_center().y - size.y * 0.5)
	var best: Dictionary = {}
	var best_score := INF
	for x: float in xs:
		for y: float in ys:
			var box := Rect2(roundf(x), roundf(y), size.x, size.y)
			if not safe.encloses(box):
				continue
			if side == "above" and box.end.y > bottom_max:
				continue
			if side == "right" and box.position.x < hero.end.x + TAIL_H:
				continue
			if side == "left" and box.end.x > hero.position.x - TAIL_H:
				continue
			var free := true
			for b: Rect2 in blocks:
				if box.intersects(b):
					free = false
					break
			if not free:
				continue
			var anchor := _anchor(box, hero, side)
			var score := anchor.distance_to(_tip_point(hero, side))
			if score < best_score:
				best_score = score
				best = {"box": box, "score": score}
	return best


## Ponto da borda do balão onde nasce o rabicho.
static func _anchor(box: Rect2, hero: Rect2, side: String) -> Vector2:
	if side == "above":
		return Vector2(clampf(hero.get_center().x, box.position.x + 14.0, box.end.x - 14.0), box.end.y)
	var y := clampf(hero.position.y + 10.0, box.position.y + 12.0, box.end.y - 12.0)
	return Vector2(box.position.x if side == "right" else box.end.x, y)


## Ponta do rabicho: logo acima da cabeça, ou ao lado do rosto.
static func _tip_point(hero: Rect2, side: String) -> Vector2:
	match side:
		"right":
			return Vector2(hero.end.x + 1.0, hero.position.y + 10.0)
		"left":
			return Vector2(hero.position.x - 1.0, hero.position.y + 10.0)
	return Vector2(hero.get_center().x, hero.position.y - HEAD_GAP)


static func _finish(best: Dictionary, hero: Rect2, head_w: float, chain_w: float, line_h: float) -> Dictionary:
	var box: Rect2 = best["box"]
	var side := String(best["side"])
	var inner := Rect2(box.position + Vector2(PAD_X, PAD_Y), box.size - Vector2(PAD_X, PAD_Y) * 2.0)
	var header := Rect2(inner.position, Vector2(inner.size.x, HEADER_H))
	var seal_w := minf(head_w, inner.size.x - CLOSE - GAP)
	var chain := Rect2()
	var y := header.end.y + HEADER_GAP
	if chain_w > 0.0:
		if bool(best["icons_row"]):
			chain = Rect2(inner.position.x, y, chain_w, ICON)
			y += ICON + HEADER_GAP
		else:
			chain = Rect2(header.end.x - CLOSE - GAP - chain_w, header.position.y, chain_w, ICON)
	var lines := int(best["lines"])
	var text := Rect2(inner.position.x, y, inner.size.x, ceilf(line_h) * lines)
	var close := Rect2(box.end.x - CLOSE_HIT, box.position.y, CLOSE_HIT, CLOSE_HIT)
	var glyph := Rect2(Vector2(box.end.x - PAD_X - CLOSE, box.position.y + PAD_Y + 3.0).round(), Vector2(CLOSE, CLOSE))
	var base := _anchor(box, hero, side)
	var along := Vector2(1, 0) if side == "above" else Vector2(0, 1)
	var tail := PackedVector2Array([base - along * TAIL_HALF, base + along * TAIL_HALF, _tip_point(hero, side)])
	return {"ok": true, "box": box, "text": text, "header": header,
			"seal": Rect2(header.position, Vector2(seal_w, HEADER_H)),
			"chain": chain, "icons_row": bool(best["icons_row"]), "close": close, "close_glyph": glyph,
			"tail": tail, "side": side,
			"lines": lines}


## Linhas que `value` ocupa com quebra de palavra na largura `width` (fonte do idioma, 12).
static func line_count(value: String, width: float, font: Font = null) -> int:
	var f := font if font != null else _font()
	var h := f.get_multiline_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, width, FONT_SIZE).y
	return maxi(1, roundi(h / f.get_height(FONT_SIZE)))


## Nenhuma palavra é maior que a linha (japonês e chinês quebram em qualquer caractere).
static func words_fit(value: String, width: float, font: Font = null) -> bool:
	var f := font if font != null else _font()
	for word: String in value.split(" ", false):
		if DialoguePanel._wraps_anywhere(word):
			continue
		if f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x > width + 0.5:
			return false
	return true


## Largura do selo 心得 + rótulo da categoria, e a da fileira de ícones (com + e = na receita).
static func head_width(category: String, font: Font = null) -> float:
	var f := font if font != null else _font()
	return seal_width() + 4.0 + ceilf(f.get_string_size(category, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x)


static func chain_width(count: int, recipe: bool) -> float:
	if count <= 0:
		return 0.0
	var gaps := (count - 1) * (GLYPH_W + ICON_GAP * 2.0 if recipe else ICON_GAP)
	return count * ICON + gaps


static func seal_width() -> float:
	var f := UiPaint.ja_font()
	return ceilf(f.get_string_size(TipDeck.KANJI, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x) + 6.0


static func _font() -> Font:
	return Locale.font if Locale.font != null else ThemeDB.fallback_font


static func line_height() -> float:
	return ceilf(_font().get_height(FONT_SIZE))


## Recorte 16x16 do ícone: o miolo dos ícones de habilidade 24x24 (como os chips do Diário), o
## primeiro quadro das folhas 32x16 (baú) e o ícone inteiro nos de 16x16.
static func icon_region(tex: Texture2D) -> Rect2:
	var s := tex.get_size()
	if s == Vector2(24, 24):
		return Rect2(4, 4, 16, 16)
	if s.y == 16.0 and s.x >= 16.0:
		return Rect2(0, 0, 16, 16)
	return Rect2(Vector2.ZERO, s)


# --- API -----------------------------------------------------------------------------------

## Título abriu: some o que havia e agenda a primeira dica (nada se as dicas estão desligadas).
func restart() -> void:
	_kill_tween()
	visible = false
	_tip = {}
	if not TipDeck.enabled():
		_state = HIDDEN
		set_process(false)
		return
	_state = WAITING
	_wait = APPEAR_DELAY
	set_process(true)


## Título saiu (ou outra tela abriu): para tudo e grava as dicas vistas.
func stop() -> void:
	_kill_tween()
	visible = false
	_state = HIDDEN
	set_process(false)
	if _dirty:
		_dirty = false
		SaveManager.save_profile()


## Mostra a próxima dica do TipDeck agora (pula a espera).
func next_tip(animate: bool = true) -> void:
	var tip := TipDeck.next_tip()
	_dirty = _dirty or not tip.is_empty()
	show_tip(tip, animate)


## Mostra `tip` (do catálogo do TipDeck). {} esconde.
func show_tip(tip: Dictionary, animate: bool = true) -> void:
	_kill_tween()
	_tip = tip
	if tip.is_empty():
		visible = false
		_state = HIDDEN
		set_process(false)
		return
	_text_value = TipDeck.text(tip)
	_category = TipDeck.category_text(tip)
	_icons = TipDeck.icons(tip)
	_label.add_theme_font_override("font", _font())
	_label.text = _text_value
	# Acessibilidade: tocar passa a dica; o "×" no canto fecha.
	tooltip_text = "%s · × %s" % [tr("tip.next"), tr("tip.close")]
	if "accessibility_name" in self:
		set("accessibility_name", "%s %s: %s" % [TipDeck.KANJI, _category, _text_value])
	relayout()
	if not bool(_layout.get("ok", false)):
		visible = false
		_state = HIDDEN
		return
	visible = true
	_shown_at = Time.get_ticks_msec()
	_idle = 0.0
	var fx := MenuKit.ui_fx()
	if fx == 0:
		_label.visible_characters = -1
		_state = IDLE
	else:
		_shown = 0.0
		_label.visible_characters = 0
		_state = TYPING
	set_process(true)
	scale = Vector2.ONE
	modulate.a = 1.0
	if animate and fx > 0 and not bool(Settings.get_value("reduce_flashes")):
		pivot_offset = (_layout["tail"] as PackedVector2Array)[2] - position
		_tween = create_tween().set_parallel()
		_tween.tween_property(self, "scale", Vector2.ONE, POP_TIME).from(Vector2(0.86, 0.86)) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.tween_property(self, "modulate:a", 1.0, POP_TIME * 0.7).from(0.0)


## Completa o texto que está aparecendo (testes e toque).
func reveal() -> void:
	_label.visible_characters = -1
	if _state == TYPING:
		_state = IDLE
		_idle = 0.0


## Fecha até o título abrir de novo.
func dismiss() -> void:
	_kill_tween()
	_state = DISMISSED
	set_process(false)
	if MenuKit.ui_fx() == 0 or bool(Settings.get_value("reduce_flashes")):
		visible = false
	else:
		_tween = create_tween()
		_tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
		_tween.tween_callback(func() -> void: visible = false)
	AudioManager.play_ui("ui_move")
	closed.emit()


## Recalcula o lugar do balão (o título chama a cada mudança de tamanho ou de recorte).
func relayout() -> void:
	if _tip.is_empty() or not context_provider.is_valid():
		return
	var ctx: Dictionary = context_provider.call()
	if ctx.is_empty():
		_layout = {"ok": false}
		return
	var font := _font()
	var blockers: Array[Rect2] = []
	for r: Variant in ctx.get("blockers", []):
		blockers.append(r as Rect2)
	var soft: Array[Rect2] = []
	for r: Variant in ctx.get("soft", []):
		soft.append(r as Rect2)
	var head := head_width(_category, font)
	var chain := chain_width(_icons.size(), bool(_tip.get("recipe", false)))
	var all: Array[Rect2] = blockers.duplicate()
	all.append_array(soft)
	_layout = balloon_layout(ctx["view"], ctx["insets"], ctx["hero"], all, _text_value, head, chain, font, line_height())
	var covering := false
	if not bool(_layout.get("ok", false)) and not soft.is_empty():
		# Sem lugar livre: pode cobrir o que é "soft" (quem o mostrou o esconde enquanto o balão fala).
		_layout = balloon_layout(ctx["view"], ctx["insets"], ctx["hero"], blockers, _text_value, head, chain, font,
				line_height())
		covering = bool(_layout.get("ok", false))
	if not bool(_layout.get("ok", false)):
		visible = false
		return
	_set_covering(covering)
	# O nó cobre o papel e o rabicho; o desenho e o texto ficam no espaço dele.
	var box: Rect2 = _layout["box"]
	var bounds := box
	for p: Vector2 in _layout["tail"] as PackedVector2Array:
		bounds = bounds.expand(p)
	bounds = bounds.grow(1.0)
	position = bounds.position
	size = bounds.size
	var text: Rect2 = _layout["text"]
	_label.position = text.position - position
	# A altura mínima do texto quebrado vale para a largura antiga: põe a largura nova, refaz o
	# mínimo e só então a altura (senão o rótulo fica com a altura de uma coluna estreita).
	_label.size = Vector2(text.size.x, _label.size.y)
	_label.update_minimum_size()
	_label.size = text.size
	_bake.invalidate()


## O balão atual só coube por cima de um retângulo "soft" do contexto.
func covers_soft() -> bool:
	return _covering


func _set_covering(on: bool) -> void:
	if on != _covering:
		_covering = on
		soft_cover_changed.emit(on)


func is_showing() -> bool:
	return visible and (_state == TYPING or _state == IDLE)


func is_dismissed() -> bool:
	return _state == DISMISSED


func current_tip() -> Dictionary:
	return _tip


func current_text() -> String:
	return _text_value


func text_label() -> Label:
	return _label


## Retângulos do layout atual, no espaço do pai (ver balloon_layout).
func layout_rects() -> Dictionary:
	return _layout


# --- Interno -------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not is_visible_in_tree() and _state != WAITING:
		return
	match _state:
		WAITING:
			if get_parent() is CanvasItem and not (get_parent() as CanvasItem).is_visible_in_tree():
				return
			_wait -= delta
			if _wait <= 0.0:
				next_tip()
		TYPING:
			_shown += delta * TYPE_SPEED
			var total := _label.get_total_character_count()
			if _shown >= total:
				reveal()
			else:
				_label.visible_characters = int(_shown)
		IDLE:
			_idle += delta
			if _idle >= ROTATE_EVERY:
				_rotate()


func _rotate() -> void:
	_idle = 0.0
	if MenuKit.ui_fx() == 0 or bool(Settings.get_value("reduce_flashes")):
		next_tip(false)
		return
	_kill_tween()
	_state = HIDDEN
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	_tween.tween_callback(next_tip)


func _gui_input(event: InputEvent) -> void:
	var pressed := (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) \
			or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
	if not pressed or not is_showing():
		return
	accept_event()
	var at := (event as InputEventScreenTouch).position if event is InputEventScreenTouch \
			else (event as InputEventMouseButton).position
	tap(at + position)


## Toque no ponto `at` (espaço do pai): no "×" fecha; senão completa o texto ou passa a dica.
func tap(at: Vector2) -> void:
	if not is_showing():
		return
	if (_layout.get("close", Rect2()) as Rect2).has_point(at):
		dismiss()
		return
	if Time.get_ticks_msec() - _shown_at < TAP_LOCK_MS:
		return
	if _state == TYPING:
		reveal()
		return
	AudioManager.play_ui("ui_move")
	_rotate()


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null
	modulate.a = 1.0
	scale = Vector2.ONE


static func _style() -> StyleBoxTexture:
	if _box_style == null:
		_box_style = StyleBoxTexture.new()
		if ResourceLoader.exists(BOX_PATH):
			_box_style.texture = load(BOX_PATH) as Texture2D
		_box_style.region_rect = BOX_REGION
		_box_style.set_texture_margin_all(BOX_EDGE)
	return _box_style


## Pintor do StaticBake (coordenadas do próprio nó): papel, rabicho, selo, categoria, ícones e ×.
func _paint(c: CanvasItem) -> void:
	if not bool(_layout.get("ok", false)):
		return
	var o := position
	var box: Rect2 = _layout["box"]
	box.position -= o
	c.draw_style_box(_style(), box)
	_paint_tail(c, _layout["tail"] as PackedVector2Array, o, String(_layout["side"]))
	var seal: Rect2 = _layout["seal"]
	seal.position -= o
	var sw := seal_width()
	var seal_rect := Rect2(seal.position, Vector2(sw, HEADER_H))
	c.draw_rect(seal_rect.grow(1.0), SEAL_RED.darkened(0.45))
	c.draw_rect(seal_rect, SEAL_RED)
	var ja := UiPaint.ja_font()
	var base_y := seal_rect.position.y + roundf((HEADER_H - ja.get_height(FONT_SIZE)) * 0.5 + ja.get_ascent(FONT_SIZE))
	c.draw_string(ja, Vector2(seal_rect.position.x + 3.0, base_y), TipDeck.KANJI, HORIZONTAL_ALIGNMENT_LEFT, -1,
			FONT_SIZE, SEAL_TEXT)
	var f := _font()
	var cat_x := seal_rect.end.x + 4.0
	var cat_w := maxf(0.0, (box.end.x - PAD_X - CLOSE - GAP) - cat_x)
	var cat_y := seal_rect.position.y + roundf((HEADER_H - f.get_height(FONT_SIZE)) * 0.5 + f.get_ascent(FONT_SIZE))
	c.draw_string(f, Vector2(cat_x, cat_y), _category, HORIZONTAL_ALIGNMENT_LEFT, cat_w, FONT_SIZE, CAT_INK)
	var chain: Rect2 = _layout["chain"]
	if chain.size.x > 0.0:
		chain.position -= o
		_paint_chain(c, chain, bool(_tip.get("recipe", false)))
	_paint_close(c, (_layout["close_glyph"] as Rect2).position - o)


## "×" de traço com 2 px (diagonais de pares de pixels), em tinta cheia: com 1 px a 75%
## ele quase sumia em escala 1 e nas capturas reduzidas.
func _paint_close(c: CanvasItem, at: Vector2) -> void:
	var n := int(CLOSE)
	for i: int in n - 1:
		c.draw_rect(Rect2(at + Vector2(i, i), Vector2(2, 1)), INK)
		c.draw_rect(Rect2(at + Vector2(n - 2 - i, i), Vector2(2, 1)), INK)


func _paint_chain(c: CanvasItem, chain: Rect2, recipe: bool) -> void:
	var x := chain.position.x
	for i: int in _icons.size():
		var tex := _icons[i]
		c.draw_texture_rect_region(tex, Rect2(x, chain.position.y, ICON, ICON), icon_region(tex))
		x += ICON
		if i == _icons.size() - 1:
			break
		if recipe:
			x += ICON_GAP
			var mid := Vector2(x + 3.0, chain.position.y + 8.0).round()
			if i == _icons.size() - 2:
				# "=" antes do resultado.
				c.draw_rect(Rect2(mid.x - 3.0, mid.y - 2.0, 7.0, 1.0), INK)
				c.draw_rect(Rect2(mid.x - 3.0, mid.y + 1.0, 7.0, 1.0), INK)
			else:
				c.draw_rect(Rect2(mid.x - 3.0, mid.y, 7.0, 1.0), INK)
				c.draw_rect(Rect2(mid.x, mid.y - 3.0, 1.0, 7.0), INK)
			x += GLYPH_W + ICON_GAP
		else:
			x += ICON_GAP


## Rabicho: contorno, moldura e o papel por dentro, abrindo a borda da caixa na base.
func _paint_tail(c: CanvasItem, tail: PackedVector2Array, o: Vector2, side: String) -> void:
	var a := tail[0] - o
	var b := tail[1] - o
	var tip := tail[2] - o
	var inward := Vector2(0, -1) if side == "above" else (Vector2(1, 0) if side == "right" else Vector2(-1, 0))
	var along := (b - a).normalized()
	var dir := (tip - (a + b) * 0.5).normalized()
	Stroke.convex(c, PackedVector2Array([a - along + inward * 6.0, b + along + inward * 6.0, tip + dir]), OUTLINE)
	Stroke.convex(c, PackedVector2Array([a + inward * 6.0, b + inward * 6.0, tip - dir]), FRAME)
	Stroke.convex(c, PackedVector2Array([a + along * 3.0 + inward * 7.0, b - along * 3.0 + inward * 7.0,
			tip - dir * 5.0]), PAPER)


## Selo 心得 desenhado num Control (cartão dos Resultados).
class Seal extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(TipBalloon.seal_width(), TipBalloon.HEADER_H)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, TipBalloon.SEAL_RED)
		draw_rect(r, TipBalloon.SEAL_RED.darkened(0.45), false, 1.0)
		var ja := UiPaint.ja_font()
		var y := roundf((size.y - ja.get_height(TipBalloon.FONT_SIZE)) * 0.5 + ja.get_ascent(TipBalloon.FONT_SIZE))
		draw_string(ja, Vector2(3.0, y), TipDeck.KANJI, HORIZONTAL_ALIGNMENT_LEFT, -1, TipBalloon.FONT_SIZE,
				TipBalloon.SEAL_TEXT)


## Cartão 心得 dos Resultados, compacto para caber sem rolar: à esquerda o selo e, embaixo dele, os
## ícones da dica (a receita das dicas de combo, um sob o outro); à direita a dica. A categoria
## vai na dica de toque e no nome de acessibilidade.
class Card extends HBoxContainer:
	var seal: Control
	var icons: VBoxContainer
	var text: Label
	var category: String = ""

	func _init() -> void:
		name = "TipCard"
		add_theme_constant_override("separation", 5)
		var gutter := VBoxContainer.new()
		gutter.add_theme_constant_override("separation", 2)
		gutter.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		gutter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(gutter)
		seal = TipBalloon.Seal.new()
		gutter.add_child(seal)
		icons = VBoxContainer.new()
		icons.name = "TipIcons"
		icons.add_theme_constant_override("separation", 1)
		icons.alignment = BoxContainer.ALIGNMENT_BEGIN
		gutter.add_child(icons)
		text = Label.new()
		text.name = "TipText"
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_theme_color_override("font_color", Color("e8dccb"))
		add_child(text)

	## Preenche com a dica (TipDeck): até 3 ícones (a receita inteira das dicas de combo).
	func set_tip(tip: Dictionary) -> void:
		category = TipDeck.category_text(tip)
		text.text = TipDeck.text(tip)
		tooltip_text = "%s · %s" % [TipDeck.KANJI, category]
		if "accessibility_name" in self:
			set("accessibility_name", "%s %s: %s" % [TipDeck.KANJI, category, text.text])
		for child: Node in icons.get_children():
			icons.remove_child(child)
			child.queue_free()
		var list := TipDeck.icons(tip)
		for i: int in mini(list.size(), 3):
			var atlas := AtlasTexture.new()
			atlas.atlas = list[i]
			atlas.region = TipBalloon.icon_region(list[i])
			var rect := TextureRect.new()
			rect.texture = atlas
			rect.custom_minimum_size = Vector2(TipBalloon.ICON, TipBalloon.ICON)
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icons.add_child(rect)
		icons.visible = icons.get_child_count() > 0
