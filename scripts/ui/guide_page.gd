class_name GuidePage
extends VBoxContainer
## Página da direita do Guia (Diário do Guardião, marcador "Guia"): desenha um capítulo do
## GuideBook com a linguagem visual do Diário, em tinta sobre papel:
## - títulos de seção em tinta vermelha com o traço do Diário;
## - parágrafos e linhas com chips (RichTextLabel com fit_content, quebra de linha por palavra
##   e CJK pelo TextServer): os valores que vêm dos dados em tinta vermelha, os itens como os
##   chips das receitas do Diário (InkChips: ícone 1:1, desconhecido "?" e "???"); tocar num
##   chip abre o item no Diário (ref_pressed);
## - dicas 心得 no papel do balão da guardiã (TipBalloon), com o selo, a categoria e os ícones;
## - botões "Ver no Diário" (link_pressed) com o visual do "Rever" das histórias.
## Tudo é estático: nada redesenha por quadro (o selo e o papel são desenhados uma vez e só
## voltam a desenhar quando o layout muda); a página rola no ScrollContainer do Diário
## (TouchScroll: os botões deixam o toque passar para a lista).
## ChapterRow: o capítulo na página da esquerda (ícone + número + título), cartão assado
## (StaticBake) como os do Diário.

signal link_pressed(category: StringName)
signal ref_pressed(category: StringName, id: String)

const FONT_SIZE := 12
const LINE_SEPARATION := 2
const TIP_PAD := Vector2(8, 6)

## Toque: distância máxima (px) entre apertar e soltar para um chip contar como toque.
const TAP_SLOP := 8.0
const SYNC_BLOCKS := 10
const BLOCKS_PER_FRAME := 6

static var _tip_box: StyleBoxTexture

var _chapter: Dictionary = {}
var _press_at := Vector2.ZERO
var _press_moved := false
var _pending: Array = []
var _first := true
var _build_id := 0


func _init() -> void:
	name = "GuidePage"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_theme_constant_override("separation", 4)


func chapter() -> Dictionary:
	return _chapter


## Troca o capítulo mostrado (refaz os blocos). Os primeiros SYNC_BLOCKS saem na hora (a tela
## inteira do capítulo); o resto entra BLOCKS_PER_FRAME por quadro, para o toque no capítulo
## longo (Dicas, ~90 cartões) não travar um quadro inteiro montando o que ainda está fora da tela.
func show_chapter(ch: Dictionary) -> void:
	_chapter = ch
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_first = true
	_pending = (ch.get("blocks", []) as Array).duplicate()
	_build_id += 1
	_build(SYNC_BLOCKS)
	if not _pending.is_empty() and is_inside_tree():
		_build_later(_build_id)


## Monta já o que falta (testes e capturas).
func complete() -> void:
	_build(_pending.size())


func is_complete() -> bool:
	return _pending.is_empty()


func _build(count: int) -> void:
	for _k: int in mini(count, _pending.size()):
		var node := _block(_pending.pop_front() as Dictionary, _first)
		if node != null:
			add_child(node)
			_first = false


func _build_later(id: int) -> void:
	while not _pending.is_empty():
		await get_tree().process_frame
		if id != _build_id or not is_inside_tree():
			return
		_build(BLOCKS_PER_FRAME)


func _block(block: Dictionary, first: bool) -> Control:
	match String(block["type"]):
		"h":
			return _heading(String(block["text"]), first)
		"p":
			return _rich([block["parts"]])
		"rich":
			return _rich(block["lines"] as Array)
		"tip":
			return TipNote.new(block["tip"] as Dictionary, String(block["text"]))
		"link":
			return _link(StringName(block["category"]), String(block["text"]))
	return null


func _heading(text: String, first: bool) -> Control:
	var box := VBoxContainer.new()
	box.name = "Heading"
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", 1)
	if not first:
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 3)
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(gap)
	var label := ink_label(text, ThemeFactory.RED_INK)
	box.add_child(label)
	var rule := ColorRect.new()
	rule.color = Color(ThemeFactory.RED_INK, 0.3)
	rule.custom_minimum_size = Vector2(0, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(rule)
	return box


func _rich(lines: Array) -> RichTextLabel:
	var rtl := ink_rich()
	for i: int in lines.size():
		if i > 0:
			rtl.newline()
		for part: Dictionary in lines[i]:
			_write(rtl, part)
	return rtl


func _write(rtl: RichTextLabel, part: Dictionary) -> void:
	if part.has("t"):
		rtl.add_text(String(part["t"]))
	elif part.has("n"):
		rtl.push_color(ThemeFactory.RED_INK)
		rtl.add_text(String(part["n"]))
		rtl.pop()
	elif part.has("seal"):
		# Selo vermelho com o kanji (fonte japonesa em todo idioma), como o selo 心得.
		rtl.push_font(UiPaint.ja_font(), FONT_SIZE)
		rtl.push_bgcolor(TipBalloon.SEAL_RED)
		rtl.push_color(TipBalloon.SEAL_TEXT)
		rtl.add_text(" %s " % String(part["seal"]))
		rtl.pop()
		rtl.pop()
		rtl.pop()
	elif part.has("ref"):
		InkChips.add_ref(rtl, part["ref"] as Dictionary)
	elif part.has("chip"):
		var path := String(part["chip"])
		var known := bool(part.get("known", true))
		match String(part.get("kind", "skill")):
			"face":
				rtl.add_image(InkChips.face_chip(path, known), InkChips.CHIP, InkChips.CHIP, Color.WHITE,
						INLINE_ALIGNMENT_CENTER)
			"plain":
				var tex := InkChips.plain_icon(path, known)
				var region := TipBalloon.icon_region(tex) if known else Rect2()
				var s := region.size if known else Vector2(InkChips.CHIP, InkChips.CHIP)
				rtl.add_image(tex, int(s.x), int(s.y), Color.WHITE, INLINE_ALIGNMENT_CENTER, region)
			_:
				rtl.add_image(InkChips.recipe_chip(path, known), InkChips.CHIP, InkChips.CHIP, Color.WHITE,
						INLINE_ALIGNMENT_CENTER)


func _link(category: StringName, text: String) -> Button:
	var b := Button.new()
	b.name = "Link_%s" % category
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(0, 28)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	MenuKit.apply_primary(b, 12)
	b.add_theme_constant_override("outline_size", 3)
	b.pressed.connect(func() -> void:
		AudioManager.play_ui("ui_accept")
		link_pressed.emit(category))
	return b


## Toque num chip: só vale parado. O RichTextLabel avisa o link ao soltar o dedo, então o fim de
## uma rolagem que começou em cima de um chip (lista andando, TouchScroll.busy, ou dedo que andou
## mais que a zona morta) não abre o item.
func _on_meta(meta: Variant) -> void:
	if TouchScroll.busy() or _press_moved:
		return
	if meta is Dictionary:
		AudioManager.play_ui("ui_accept")
		ref_pressed.emit(StringName(String(meta["category"])), String(meta["id"]))


## Texto rico em tinta (mesmo estilo da receita do Diário), da altura do conteúdo.
func ink_rich() -> RichTextLabel:
	var rtl := RichTextLabel.new()
	rtl.name = "Text"
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rtl.mouse_filter = Control.MOUSE_FILTER_PASS
	rtl.meta_underlined = false
	rtl.add_theme_color_override("default_color", ThemeFactory.PAPER_INK)
	rtl.add_theme_constant_override("outline_size", 0)
	rtl.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.25))
	rtl.add_theme_constant_override("shadow_offset_x", 0)
	rtl.add_theme_constant_override("shadow_offset_y", 1)
	rtl.add_theme_constant_override("line_separation", LINE_SEPARATION)
	rtl.meta_clicked.connect(_on_meta)
	rtl.gui_input.connect(_track_press)
	return rtl


func _track_press(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if (event as InputEventMouseButton).pressed:
			_press_at = (event as InputEventMouseButton).global_position
			_press_moved = false
	elif event is InputEventMouseMotion:
		if _press_at.distance_to((event as InputEventMouseMotion).global_position) > TAP_SLOP:
			_press_moved = true


## Papel do balão com a folga das dicas (uma caixa só para todas).
static func tip_box() -> StyleBoxTexture:
	if _tip_box == null:
		_tip_box = TipBalloon.box_style().duplicate() as StyleBoxTexture
		_tip_box.content_margin_left = TIP_PAD.x
		_tip_box.content_margin_right = TIP_PAD.x
		_tip_box.content_margin_top = TIP_PAD.y
		_tip_box.content_margin_bottom = TIP_PAD.y
	return _tip_box


static func ink_label(text: String, color: Color, font_size: int = FONT_SIZE) -> Label:
	var l := MenuKit.text(text, font_size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_constant_override("outline_size", 0)
	l.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.25))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 1)
	return l


## Dica 心得 no papel do balão da guardiã: selo vermelho e, embaixo, os ícones da dica (a receita
## das dicas de combo); ao lado, a dica em tinta escura (a categoria é o título da seção e a dica
## de toque).
class TipNote extends PanelContainer:
	var tip: Dictionary
	var text: Label

	func _init(p_tip: Dictionary, value: String) -> void:
		tip = p_tip
		name = "TipNote"
		mouse_filter = Control.MOUSE_FILTER_PASS
		add_theme_stylebox_override("panel", GuidePage.tip_box())
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_theme_constant_override("separation", 5)
		add_child(row)
		var gutter := VBoxContainer.new()
		gutter.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		gutter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gutter.add_theme_constant_override("separation", 2)
		row.add_child(gutter)
		gutter.add_child(TipBalloon.Seal.new())
		var icons := TipDeck.icons(tip)
		for i: int in mini(icons.size(), 3):
			var atlas := AtlasTexture.new()
			atlas.atlas = icons[i]
			atlas.region = TipBalloon.icon_region(icons[i])
			var rect := TextureRect.new()
			rect.texture = atlas
			rect.custom_minimum_size = Vector2(TipBalloon.ICON, TipBalloon.ICON)
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			gutter.add_child(rect)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.mouse_filter = Control.MOUSE_FILTER_PASS
		col.add_theme_constant_override("separation", 0)
		row.add_child(col)
		text = GuidePage.ink_label(value, TipBalloon.INK)
		text.name = "TipText"
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(text)
		tooltip_text = "%s · %s" % [TipDeck.KANJI, TipDeck.category_text(tip)]


## Capítulo na página esquerda: cartão de papel assado (StaticBake) com marca vermelha quando
## escolhido; por cima, o ícone e o título (quebra de linha nos idiomas longos).
class ChapterRow extends Button:
	const MIN_HEIGHT := 26.0
	var entry: Dictionary
	var title: Label
	var _icon: TextureRect
	var _margin: MarginContainer
	var _bake: StaticBake
	var _selected := false

	func setup(p_entry: Dictionary) -> void:
		entry = p_entry
		name = "Chapter_%s" % String(entry.get("id", ""))
		focus_mode = Control.FOCUS_ALL
		tooltip_text = String(entry["title"])
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		_bake = StaticBake.new(_paint)
		_bake.name = "Bake"
		add_child(_bake)
		_margin = MarginContainer.new()
		_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for side: String in ["left", "right"]:
			_margin.add_theme_constant_override("margin_" + side, 5)
		for side: String in ["top", "bottom"]:
			_margin.add_theme_constant_override("margin_" + side, 3)
		add_child(_margin)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 4)
		_margin.add_child(row)
		_icon = TextureRect.new()
		var path := String(entry.get("icon", ""))
		if ResourceLoader.exists(path):
			var tex := load(path) as Texture2D
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = TipBalloon.icon_region(tex)
			_icon.texture = atlas
		_icon.custom_minimum_size = Vector2(16, 16)
		_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(_icon)
		title = GuidePage.ink_label("%d. %s" % [int(entry.get("number", 0)), String(entry["title"])],
				ThemeFactory.PAPER_INK)
		title.name = "ChapterTitle"
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(title)
		# Button não usa _get_minimum_size: a altura vem do conteúdo (título que quebra linha).
		_margin.minimum_size_changed.connect(_fit_height)
		resized.connect(_fit_height)
		_fit_height()
		mouse_entered.connect(_bake.invalidate)
		mouse_exited.connect(_bake.invalidate)
		focus_entered.connect(_bake.invalidate)
		focus_exited.connect(_bake.invalidate)

	func _fit_height() -> void:
		var want := maxf(MIN_HEIGHT, ceilf(_margin.get_combined_minimum_size().y))
		if not is_equal_approx(custom_minimum_size.y, want):
			custom_minimum_size.y = want

	func set_selected(on: bool) -> void:
		_selected = on
		if title != null:
			title.add_theme_color_override("font_color", ThemeFactory.RED_INK if on else ThemeFactory.PAPER_INK)
		if _bake != null:
			_bake.invalidate()

	func is_selected() -> bool:
		return _selected

	func _paint(c: CanvasItem) -> void:
		var r := Rect2(Vector2.ZERO, size)
		var hot := is_hovered() or has_focus()
		var border := ThemeFactory.RED_INK if _selected else Color("6b4a2a", 0.9 if hot else 0.5)
		var bg := Color("f6ead0") if _selected or hot else Color("efe0bc")
		c.draw_style_box(ThemeFactory.flat_box(bg, border, 1, 3), r)
		if _selected:
			c.draw_rect(Rect2(1, 2, 2, size.y - 4), ThemeFactory.RED_INK)
