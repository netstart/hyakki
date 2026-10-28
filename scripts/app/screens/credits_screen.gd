extends Screen
## Créditos (plano 12.1 e 18.4): todos os autores dos assets e do software, mesmo os CC0.
## Os dados vêm de licenses/index.json (LicenseIndex.entries()), gerado a partir do registro
## de licenças: um asset ou dependência nova aparece aqui sozinha, na seção da categoria.
##
## Layout (678x305): voltar e título fixos no topo; o resto rola na vertical até a borda de
## baixo. Abertura com o título HYAKKI entre duas lanternas, o selo 百鬼 e o crédito do
## criador; depois as seções (Arte, Música, Efeitos sonoros, Fontes, Tecnologia) em cartões
## de laca com nome, autor e o selo da licença; os agradecimentos; e, no fim, o amanhecer:
## o sol nasce conforme se chega ao fim da rolagem, com a frase de despedida e o 終.
##
## Movimento: as seções entram em sequência ao abrir, pétalas de sakura caem devagar e a
## rolagem anda sozinha (como créditos de filme) até o primeiro toque, roda ou tecla.
## Tudo que é desenhado por quadro usa arrays preparados no _ready (nada alocado no _process).
##
## Arrasto: todo nó dentro da área rolável deixa o toque passar (containers e painéis em
## PASS, textos e imagens em IGNORE), então arrastar em qualquer ponto rola o conteúdo.

const JA_FONT := "res://assets/fonts/fusion_pixel_12_ja.woff2"
const LANTERN_SHEET := "res://assets/art/actors/enemies/lantern_red/SpriteSheet.png"
const PETAL_SHEET := "res://assets/art/fx/particle/LeafPink.png"
const LANTERN_FRAME := 16.0
const LANTERN_FPS := 4.0
const SIDE_MARGIN := 12.0
## Folga mínima entre a área rolável e o recorte da câmera (MenuKit.safe_insets).
const INSET_MARGIN := 4.0
const TITLE_HALF := 150.0
const SCROLL_TOP := 42.0
const SCROLL_RIGHT := 4.0
const BAR_WIDTH := 6.0
const COLUMN_MARGIN := 14
const CARD_GAP := 6
const BLOCK_GAP := 16
const INTRO_STAGGER := 0.09
const INTRO_FADE := 0.45
## A rolagem automática começa depois de um respiro e anda devagar (px por segundo).
const AUTO_DELAY := 2.5
const AUTO_SPEED := 16.0
const PETAL_COUNT := 12
const DAWN_HEIGHT := 190.0

const VEIL := Color(0.03, 0.02, 0.05)
const CARD_BG := Color(0.075, 0.04, 0.065, 0.86)
const CARD_EDGE := Color(1.0, 0.82, 0.4, 0.18)
const MUTED := Color("d9c3a0")
const AUTHOR := Color("e8b783")
const SEAL_RED := Color("b3261e")
const SEAL_TEXT := Color("fbe6cf")
const SHADOW := Color(0.08, 0.03, 0.03)
const SAKURA := Color("f2a7bb")
const WARM := Color("ffb45a")
## Selo da licença por família: [fundo, texto].
const BADGES := {
	"CC0": [Color("1d3a2a"), Color("aeeabd")],
	"CC-BY": [Color("4a3316"), Color("ffd08a")],
	"OFL": [Color("33244a"), Color("d8c0ff")],
	"MIT": [Color("1b2a47"), Color("aecbff")],
	"Apache": [Color("1b2a47"), Color("aecbff")],
}
const BADGE_OTHER := [Color("40252a"), Color("f4bcae")]
const SECTION_ORDER: Array[StringName] = [&"art", &"music", &"sfx", &"fonts", &"tech"]
## Kanji do selo de cada seção: 絵 arte, 楽 música, 音 som, 字 letra, 技 técnica, 謝 gratidão.
const SEALS := {&"art": "絵", &"music": "楽", &"sfx": "音", &"fonts": "字", &"tech": "技", &"thanks": "謝"}

var _scroll: ScrollContainer
var _title: Label
var _rule_line: ColorRect
var _column: VBoxContainer
## Blocos do conteúdo (abertura, seções, agradecimentos e amanhecer), na ordem da entrada.
var _blocks: Array[Control] = []
var _lanterns: Array[TextureRect] = []
var _lantern_frames: Array[AtlasTexture] = []
var _petals: Petals
var _dawn: Dawn
var _intro: Tween
var _clock: float = 0.0
var _auto: bool = false
var _auto_wait: float = 0.0
var _auto_pos: float = 0.0
var _ja: Font
## Fonte do idioma com a japonesa de reserva: nomes como 効果音ラボ e 甘茶 em qualquer idioma.
var _entry_font: FontVariation


func _ready() -> void:
	_ja = load(JA_FONT) as Font
	_entry_font = FontVariation.new()
	_entry_font.base_font = Locale.font
	_entry_font.fallbacks = [_ja]
	add_child(_veil())
	_petals = Petals.new()
	_petals.setup(load(PETAL_SHEET) as Texture2D, PETAL_COUNT)
	add_child(_petals)
	add_child(back_button())
	var title := title_label(tr("credits.title"))
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_left = -TITLE_HALF
	title.offset_right = TITLE_HALF
	title.offset_top = 6
	title.clip_text = true
	add_child(title)
	_title = title
	var rule := ColorRect.new()
	rule.color = Color(ThemeFactory.ACCENT, 0.22)
	rule.set_anchors_preset(Control.PRESET_TOP_WIDE)
	rule.offset_left = SIDE_MARGIN
	rule.offset_right = -SIDE_MARGIN
	rule.offset_top = SCROLL_TOP - 3
	rule.offset_bottom = SCROLL_TOP - 2
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rule)
	_rule_line = rule
	_build_scroll()
	resized.connect(_layout)
	# Furo da câmera que troca de lado com a tela aberta (giro de 180°).
	MenuKit.on_insets_change(self, _layout)
	_layout()
	visibility_changed.connect(func() -> void: set_process(is_visible_in_tree()))
	set_process(false)


func on_show() -> void:
	_layout()
	_scroll.scroll_vertical = 0
	_auto = true
	_auto_wait = AUTO_DELAY
	_auto_pos = 0.0
	_play_intro()
	set_process(is_visible_in_tree())


func on_back() -> void:
	app.go(&"title")


## Seção de cada entrada do índice. O que não é arte, áudio ou fonte (motor, Android,
## plugins e qualquer categoria nova) vai para Tecnologia: nenhuma entrada fica de fora.
static func section_of(entry: Dictionary) -> StringName:
	match String(entry.get("category", "")):
		"art":
			return &"art"
		"font":
			return &"fonts"
		"audio":
			var id := String(entry.get("id", "")).to_lower()
			return &"music" if id.contains("music") else &"sfx"
	return &"tech"


## "Papel: Nome" → ["Papel", "Nome"] (aceita os dois-pontos largos do chinês).
static func split_credit(text: String) -> PackedStringArray:
	var at := maxi(text.rfind(":"), text.rfind("："))
	if at < 0:
		return PackedStringArray(["", text.strip_edges()])
	return PackedStringArray([text.substr(0, at).strip_edges(), text.substr(at + 1).strip_edges()])


## Texto do selo: o SPDX ("CC0-1.0", "MIT"); licenças próprias do autor (LicenseRef-*)
## viram "Licença própria" (o texto completo fica na tela Licenças).
func badge_text(license_id: String) -> String:
	return tr("credits.license_custom") if license_id.begins_with("LicenseRef-") else license_id


## Para a rolagem automática (o jogador assumiu a rolagem).
func stop_auto_scroll() -> void:
	_auto = false


func _input(event: InputEvent) -> void:
	if not _auto or not is_visible_in_tree():
		return
	if (event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventScreenDrag
			or event is InputEventKey or event is InputEventJoypadButton or event is InputEventPanGesture):
		_auto = false


func _process(delta: float) -> void:
	_clock += delta
	var frame := int(_clock * LANTERN_FPS) % 4
	for i: int in _lanterns.size():
		var lantern := _lanterns[i]
		lantern.position.y = 6.0 + sin(_clock * 1.7 + i * 1.3) * 2.5
		_lantern_frames[i].region.position.y = ((frame + i * 2) % 4) * LANTERN_FRAME
	_petals.step(delta)
	_update_dawn()
	if not _auto:
		return
	if _auto_wait > 0.0:
		_auto_wait -= delta
		return
	var bar := _scroll.get_v_scroll_bar()
	var limit := bar.max_value - bar.page
	_auto_pos = minf(_auto_pos + AUTO_SPEED * delta, limit)
	_scroll.scroll_vertical = int(_auto_pos)
	if _auto_pos >= limit:
		_auto = false


## Termina a entrada na hora (testes e capturas).
func _finish_intro() -> void:
	if _intro != null and _intro.is_valid():
		_intro.kill()
	for block: Control in _blocks:
		block.modulate.a = 1.0


func _play_intro() -> void:
	if _intro != null and _intro.is_valid():
		_intro.kill()
	_intro = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for i: int in _blocks.size():
		_blocks[i].modulate.a = 0.0
		_intro.tween_property(_blocks[i], "modulate:a", 1.0, INTRO_FADE).set_delay(i * INTRO_STAGGER)


## Laterais pela área segura (furo da câmera): a área rolável e o filete entram só o que o
## recorte pede (sem recorte, as margens de sempre); o título centra no espaço livre.
func _layout() -> void:
	if _scroll == null:
		return
	var inset := MenuKit.safe_insets(self)
	var left := maxf(SIDE_MARGIN, inset.x + INSET_MARGIN)
	_scroll.offset_left = left
	_scroll.offset_right = -(SCROLL_RIGHT + inset.y)
	_rule_line.offset_left = left
	_rule_line.offset_right = -maxf(SIDE_MARGIN, inset.y + INSET_MARGIN)
	var shift := roundf((inset.x - inset.y) * 0.5)
	_title.offset_left = -TITLE_HALF + shift
	_title.offset_right = TITLE_HALF + shift


func _build_scroll() -> void:
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.offset_left = SIDE_MARGIN
	_scroll.offset_right = -SCROLL_RIGHT
	_scroll.offset_top = SCROLL_TOP
	_scroll.offset_bottom = 0
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	_scroll.scroll_deadzone = 8
	_style_scroll_bar(_scroll.get_v_scroll_bar())
	add_child(_scroll)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_left", COLUMN_MARGIN)
	pad.add_theme_constant_override("margin_right", COLUMN_MARGIN)
	pad.add_theme_constant_override("margin_top", 6)
	pad.add_theme_constant_override("margin_bottom", 0)
	_scroll.add_child(pad)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", BLOCK_GAP)
	pad.add_child(_column)
	_add_block(_hero())
	var groups := {}
	for id: StringName in SECTION_ORDER:
		groups[id] = []
	for entry: Dictionary in LicenseIndex.entries():
		(groups[section_of(entry)] as Array).append(entry)
	for id: StringName in SECTION_ORDER:
		if not (groups[id] as Array).is_empty():
			_add_block(_section(id, groups[id]))
	_add_block(_thanks())
	_dawn = Dawn.new()
	_add_block(_dawn_block())
	_let_drag_through(pad)


func _add_block(block: Control) -> void:
	_column.add_child(block)
	_blocks.append(block)


## Containers e painéis em PASS (o arrasto e a roda sobem até o ScrollContainer); textos,
## imagens e desenhos em IGNORE (não seguram o toque).
func _let_drag_through(node: Control) -> void:
	var passive := node is Label or node is TextureRect or node is ColorRect or node is Petals
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE if passive else Control.MOUSE_FILTER_PASS
	for child: Node in node.get_children():
		if child is Control:
			_let_drag_through(child as Control)


## Abertura: lanterna, HYAKKI com o selo 百鬼, lanterna; subtítulo entre filetes; o criador.
func _hero() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 10)
	top.add_child(_lantern())
	var title := label("HYAKKI", 36)
	title.add_theme_color_override("font_color", ThemeFactory.ACCENT)
	title.add_theme_color_override("font_outline_color", SHADOW)
	title.add_theme_constant_override("outline_size", 6)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.add_theme_constant_override("shadow_outline_size", 6)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(title)
	var seal := _seal("百\n鬼")
	seal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(seal)
	top.add_child(_lantern())
	box.add_child(top)
	var caption := HBoxContainer.new()
	caption.alignment = BoxContainer.ALIGNMENT_CENTER
	caption.add_theme_constant_override("separation", 8)
	caption.add_child(_rule(48, Color(ThemeFactory.ACCENT, 0.45)))
	var subtitle := label(tr("title.subtitle"))
	subtitle.add_theme_color_override("font_color", MUTED)
	subtitle.add_theme_color_override("font_outline_color", SHADOW)
	caption.add_child(subtitle)
	caption.add_child(_rule(48, Color(ThemeFactory.ACCENT, 0.45)))
	box.add_child(caption)
	box.add_child(_gap(10))
	var credit := split_credit(tr("credits.design"))
	if credit[0] != "":
		var role := _wrapped(credit[0], MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		role.name = "Role"
		box.add_child(role)
	var creator := label(credit[1], 24, HORIZONTAL_ALIGNMENT_CENTER)
	creator.name = "Creator"
	creator.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	creator.add_theme_color_override("font_color", ThemeFactory.TEXT)
	creator.add_theme_color_override("font_outline_color", SHADOW)
	creator.add_theme_constant_override("outline_size", 5)
	box.add_child(creator)
	return box


## Lanterna de papel (chōchin) que balança e pisca, com um halo quente atrás.
func _lantern() -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(32, 44)
	var glow := TextureRect.new()
	glow.texture = _radial([Color(WARM, 0.38), Color(WARM, 0.0)], [0.0, 1.0])
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.position = Vector2(-14, -6)
	glow.size = Vector2(60, 60)
	holder.add_child(glow)
	var frame := AtlasTexture.new()
	frame.atlas = load(LANTERN_SHEET) as Texture2D
	frame.region = Rect2(0, 0, LANTERN_FRAME, LANTERN_FRAME)
	var rect := TextureRect.new()
	rect.texture = frame
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.size = Vector2(32, 32)
	rect.position = Vector2(0, 6)
	holder.add_child(rect)
	_lanterns.append(rect)
	_lantern_frames.append(frame)
	return holder


## Seção: cabeçalho com selo, título e filete; cartões em duas colunas (o último sozinho
## ocupa a linha inteira).
func _section(id: StringName, entries: Array) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "Section_%s" % id
	box.add_theme_constant_override("separation", 7)
	box.add_child(_heading(id, _section_title(id)))
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", CARD_GAP)
	for i: int in range(0, entries.size(), 2):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", CARD_GAP)
		row.add_child(_card(entries[i]))
		if i + 1 < entries.size():
			row.add_child(_card(entries[i + 1]))
		rows.add_child(row)
	box.add_child(rows)
	return box


func _section_title(id: StringName) -> String:
	match id:
		&"art":
			return tr("credits.section.art")
		&"music":
			return tr("credits.section.music")
		&"sfx":
			return tr("credits.section.sfx")
		&"fonts":
			return tr("credits.section.fonts")
	return tr("credits.section.tech")


func _heading(id: StringName, text: String) -> HBoxContainer:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 7)
	head.add_child(_seal(String(SEALS[id])))
	var title := label(text)
	title.name = "Heading"
	title.add_theme_color_override("font_color", ThemeFactory.ACCENT)
	title.add_theme_color_override("font_outline_color", SHADOW)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(title)
	var line := _rule(0, Color(ThemeFactory.ACCENT, 0.32))
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(line)
	var dot := _rule(3, Color(ThemeFactory.ACCENT, 0.6), 3)
	head.add_child(dot)
	return head


## Cartão de laca: nome da obra, autor e o selo da licença no canto.
func _card(entry: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "Entry_%s" % entry.get("id", "")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_BG
	style.border_color = CARD_EDGE
	style.set_border_width_all(1)
	style.border_width_left = 2
	style.set_corner_radius_all(3)
	style.content_margin_left = 9
	style.content_margin_right = 7
	style.content_margin_top = 4
	style.content_margin_bottom = 5
	card.add_theme_stylebox_override("panel", style)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	card.add_child(col)
	var title := _wrapped(String(entry.get("name", "")), ThemeFactory.TEXT)
	title.name = "Name"
	col.add_child(title)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 6)
	col.add_child(foot)
	var author := _wrapped(String(entry.get("author", "")), AUTHOR)
	author.name = "Author"
	author.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(author)
	var badge := _badge(String(entry.get("license_id", "")))
	badge.size_flags_vertical = Control.SIZE_SHRINK_END
	foot.add_child(badge)
	return card


func _badge(license_id: String) -> PanelContainer:
	var colors: Array = BADGE_OTHER
	for family: String in BADGES:
		if license_id.begins_with(family):
			colors = BADGES[family]
	var pill := PanelContainer.new()
	pill.name = "License"
	var style := StyleBoxFlat.new()
	style.bg_color = colors[0]
	style.border_color = Color(colors[1] as Color, 0.4)
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 0
	style.content_margin_bottom = 1
	pill.add_theme_stylebox_override("panel", style)
	var text := label(badge_text(license_id))
	text.add_theme_color_override("font_color", colors[1])
	text.add_theme_constant_override("outline_size", 0)
	pill.add_child(text)
	return pill


## Agradecimento especial: cartão com borda de sakura e pétalas dos dois lados.
func _thanks() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "Section_thanks"
	box.add_theme_constant_override("separation", 7)
	box.add_child(_heading(&"thanks", tr("credits.section.thanks")))
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_BG
	style.border_color = Color(SAKURA, 0.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 7
	style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	row.add_child(_petal_icon(0))
	var text := _wrapped(tr("credits.special_thanks"), ThemeFactory.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	text.name = "SpecialThanks"
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	row.add_child(_petal_icon(3))
	box.add_child(card)
	return box


## Fim: o céu clareia e o sol nasce com a rolagem; a despedida e o 終 ("fim").
func _dawn_block() -> Dawn:
	_dawn.name = "Dawn"
	_dawn.custom_minimum_size = Vector2(0, DAWN_HEIGHT)
	_dawn.clip_contents = true
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_top = 28
	col.alignment = BoxContainer.ALIGNMENT_BEGIN
	col.add_theme_constant_override("separation", 6)
	_dawn.add_child(col)
	var line := label(tr("credits.thanks"), 24, HORIZONTAL_ALIGNMENT_CENTER)
	line.name = "Thanks"
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_theme_color_override("font_color", ThemeFactory.TEXT)
	line.add_theme_color_override("font_outline_color", Color("2a0f1c"))
	line.add_theme_constant_override("outline_size", 6)
	col.add_child(line)
	var end := label("— 終 —", 24, HORIZONTAL_ALIGNMENT_CENTER)
	end.name = "End"
	end.add_theme_font_override("font", _ja)
	end.add_theme_color_override("font_color", ThemeFactory.ACCENT)
	end.add_theme_color_override("font_outline_color", Color("2a0f1c"))
	end.add_theme_constant_override("outline_size", 6)
	col.add_child(end)
	return _dawn


func _update_dawn() -> void:
	if _dawn == null or not _dawn.is_inside_tree():
		return
	var view := _scroll.get_global_rect()
	var rect := _dawn.get_global_rect()
	_dawn.set_rise(clampf((view.end.y - rect.position.y) / maxf(rect.size.y, 1.0), 0.0, 1.0))


## Selo vermelho com kanji (fonte japonesa em qualquer idioma).
func _seal(text: String) -> PanelContainer:
	var seal := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = SEAL_RED
	box.border_color = SEAL_RED.darkened(0.45)
	box.set_border_width_all(1)
	box.set_corner_radius_all(2)
	box.content_margin_left = 3
	box.content_margin_right = 2
	box.content_margin_top = 0
	box.content_margin_bottom = 1
	seal.add_theme_stylebox_override("panel", box)
	var kanji := Label.new()
	kanji.text = text
	kanji.add_theme_font_override("font", _ja)
	kanji.add_theme_color_override("font_color", SEAL_TEXT)
	kanji.add_theme_constant_override("outline_size", 0)
	kanji.add_theme_constant_override("line_spacing", -2)
	seal.add_child(kanji)
	return seal


func _petal_icon(frame: int) -> TextureRect:
	var atlas := AtlasTexture.new()
	atlas.atlas = load(PETAL_SHEET) as Texture2D
	atlas.region = Rect2(frame * Petals.FRAME.x, 0, Petals.FRAME.x, Petals.FRAME.y)
	var rect := TextureRect.new()
	rect.texture = atlas
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.custom_minimum_size = Petals.FRAME * 2.0
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return rect


func _wrapped(text: String, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := label(text, 12, align)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", _entry_font)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 0)
	return l


## Filete fino centrado na vertical (largura 0 = ocupa o que sobrar na linha).
func _rule(width: float, color: Color, height: float = 1.0) -> VBoxContainer:
	var holder := VBoxContainer.new()
	holder.alignment = BoxContainer.ALIGNMENT_CENTER
	var line := ColorRect.new()
	line.color = color
	line.custom_minimum_size = Vector2(width, height)
	if width == 0:
		holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.add_child(line)
	return holder


func _gap(height: float) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, height)
	return gap


## Véu escuro mais denso no centro: o texto lê bem sobre o desfile do fundo.
func _veil() -> TextureRect:
	var veil := TextureRect.new()
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.18, 0.82, 1.0])
	gradient.colors = PackedColorArray([Color(VEIL, 0.5), Color(VEIL, 0.74), Color(VEIL, 0.74), Color(VEIL, 0.5)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 128
	texture.height = 1
	veil.texture = texture
	veil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	veil.stretch_mode = TextureRect.STRETCH_SCALE
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return veil


func _style_scroll_bar(bar: VScrollBar) -> void:
	var track := _flat(Color(0, 0, 0, 0.3))
	track.content_margin_left = BAR_WIDTH / 2
	track.content_margin_right = BAR_WIDTH / 2
	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("scroll_focus", track)
	bar.add_theme_stylebox_override("grabber", _flat(Color(ThemeFactory.ACCENT, 0.55)))
	bar.add_theme_stylebox_override("grabber_highlight", _flat(ThemeFactory.ACCENT))
	bar.add_theme_stylebox_override("grabber_pressed", _flat(ThemeFactory.ACCENT))


func _flat(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(3)
	return box


static func _radial(colors: Array[Color], offsets: Array[float]) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array(offsets)
	gradient.colors = PackedColorArray(colors)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 64
	texture.height = 64
	return texture


## Pétalas de sakura caindo devagar, balançando e girando (quadros da folha LeafPink).
## Posições em arrays preparados no setup; o _draw só desenha.
class Petals extends Control:
	const FRAME := Vector2(12, 7)
	const FRAMES := 6

	var _texture: Texture2D
	var _pos := PackedVector2Array()
	var _speed := PackedVector2Array()
	var _phase := PackedFloat32Array()
	var _time: float = 0.0
	var _rng := RandomNumberGenerator.new()

	func setup(texture: Texture2D, count: int) -> void:
		_texture = texture
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rng.seed = 100
		_pos.resize(count)
		_speed.resize(count)
		_phase.resize(count)
		for i: int in count:
			_pos[i] = Vector2(_rng.randf_range(0, 678), _rng.randf_range(-20, 305))
			_speed[i] = Vector2(_rng.randf_range(-9, -3), _rng.randf_range(9, 17))
			_phase[i] = _rng.randf_range(0, TAU)

	func step(delta: float) -> void:
		_time += delta
		var area := size if size.x > 0 else Vector2(678, 305)
		for i: int in _pos.size():
			var p := _pos[i] + _speed[i] * delta
			p.x += sin(_time * 1.3 + _phase[i]) * 8.0 * delta
			if p.y > area.y + 10 or p.x < -16:
				p = Vector2(_rng.randf_range(40, area.x + 40), -10)
			_pos[i] = p
		queue_redraw()

	func _draw() -> void:
		if _texture == null:
			return
		for i: int in _pos.size():
			var frame := int(_time * 3.0 + _phase[i] * 2.0) % FRAMES
			var src := Rect2(frame * FRAME.x, 0, FRAME.x, FRAME.y)
			var alpha := 0.35 + 0.25 * sin(_phase[i] + _time * 0.5)
			draw_texture_rect_region(_texture, Rect2(_pos[i].round(), FRAME), src, Color(1, 1, 1, alpha))


## Céu do amanhecer: brilho rosado/laranja a partir do horizonte e o sol que sobe conforme
## `rise` (0 = escondido, 1 = nascido). Texturas montadas uma vez.
class Dawn extends Control:
	const SUN := Color("ffe3b0")
	const GLOW := Color("ffa45e")
	const ROSE := Color("b8435e")
	## Faixas de névoa: (altura acima da borda de baixo, largura em raios do sol).
	const BANDS: Array[Vector2] = [Vector2(12, 2.6), Vector2(22, 2.1), Vector2(32, 1.3)]

	var rise: float = 0.0
	var _sky: GradientTexture2D
	var _sun: GradientTexture2D

	func _init() -> void:
		var sky := Gradient.new()
		sky.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		sky.colors = PackedColorArray([Color(GLOW, 0.62), Color(ROSE, 0.32), Color(ROSE, 0.0)])
		_sky = GradientTexture2D.new()
		_sky.gradient = sky
		_sky.fill = GradientTexture2D.FILL_RADIAL
		_sky.fill_from = Vector2(0.5, 1.0)
		_sky.fill_to = Vector2(0.5, 0.0)
		_sky.width = 128
		_sky.height = 64
		var sun := Gradient.new()
		sun.offsets = PackedFloat32Array([0.0, 0.3, 0.34, 0.6, 1.0])
		sun.colors = PackedColorArray([SUN, SUN, Color(GLOW, 0.55), Color(GLOW, 0.18), Color(GLOW, 0.0)])
		_sun = GradientTexture2D.new()
		_sun.gradient = sun
		_sun.fill = GradientTexture2D.FILL_RADIAL
		_sun.fill_from = Vector2(0.5, 0.5)
		_sun.fill_to = Vector2(0.5, 0.0)
		_sun.width = 96
		_sun.height = 96

	func set_rise(value: float) -> void:
		if is_equal_approx(value, rise):
			return
		rise = value
		queue_redraw()

	func _draw() -> void:
		var glow := Rect2(Vector2(0, size.y * (1.0 - 0.75 - 0.25 * rise)), Vector2(size.x, size.y * (0.75 + 0.25 * rise)))
		draw_texture_rect(_sky, glow, false, Color(1, 1, 1, 0.45 + 0.55 * rise))
		var radius := 44.0
		var center := Vector2(size.x * 0.5, size.y + radius * 0.5 - rise * radius * 1.1)
		draw_texture_rect(_sun, Rect2(center - Vector2.ONE * radius * 2.6, Vector2.ONE * radius * 5.2), false)
		# Faixas de névoa (kasumi) cruzando o sol, como nas gravuras do nascer do sol.
		for band: Vector2 in BANDS:
			var y := size.y - band.x
			var width := radius * band.y
			draw_rect(Rect2(center.x - width * 0.5, y, width, 2), Color(ROSE.darkened(0.2), 0.75))
		draw_rect(Rect2(0, size.y - 1, size.x, 1), Color(SUN, 0.5))
