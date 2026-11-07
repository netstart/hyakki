extends Screen
## Jornada do Guardião (seleção de fase, plano 3.3, 4.13 e 15.3): à esquerda o mapa do
## arquipélago com os pontos de luta (JourneyMap); à direita o pergaminho do ponto
## escolhido, com região, chefes, narrativa, recordes e as opções da partida: modo
## (Brisa / Normal), Lua Vermelha I–V (liberada vencendo a anterior) e Noite Sem Fim
## (depois de vencer a fase). Fases bloqueadas podem ser lidas, mas não começadas.

## Layout pela tela de verdade (e pela área segura do furo da câmera): margem da borda, vão
## entre o mapa e o pergaminho e a largura do pergaminho, CARD_SHARE da largura útil (278 de
## 662 px na tela de referência, 678x305 sem recorte), entre CARD_MIN_WIDTH e CARD_WIDTH. O
## mapa fica com o resto e nunca menor que o pergaminho: com o furo da câmera numa tela
## estreita, o pergaminho cede até metade do espaço (os pontos do mapa precisam de lugar).
const MARGIN := 6.0
const GAP := 4.0
const CARD_WIDTH := 330.0
const CARD_MIN_WIDTH := 232.0
const CARD_SHARE := 0.42
## Pergaminho mais baixo que isto (telas de 270 de altura) ou mais estreito que COMPACT_WIDTH
## (tablets e telas quase quadradas, onde a narrativa quebra em mais linhas): os recordes e os
## avisos (bônus, sugestão do Brisa) entram na rolagem, acima da narrativa, para ela não sumir.
const COMPACT_HEIGHT := 280.0
const COMPACT_WIDTH := 266.0
## Largura mínima da Noite Sem Fim (chave e duas linhas de texto) ao lado do Começar, que fica
## sempre na mesma linha: sem espaço, a fonte do Começar desce de GO_FONT_SIZES em vez de quebrar.
const ENDLESS_MIN_WIDTH := 100.0
const GO_FONT_SIZES: Array[int] = [24, 22, 20, 18, 16]
## Esfumado cor de papel nas bordas da narrativa enquanto há texto acima ou abaixo.
const FADE := 10.0
## Nome da fase como manchete do pergaminho: a maior fonte que o deixa numa linha com o selo; no
## pergaminho baixo (telas de 270), até HEADLINE_COMPACT_SIZES, para não roubar linhas da
## narrativa; sem espaço nem assim, a fonte do texto.
const HEADLINE_FONT_SIZES: Array[int] = [24, 18, 16, 14]
const HEADLINE_COMPACT_SIZES: Array[int] = [18, 16, 14]
## Narrativa (jornada e crônica) na maior fonte em que cabe inteira sem rolar; senão a do texto.
## Até 1,5× a do texto: maior que isso a narrativa competiria com a manchete.
const STORY_FONT_SIZES: Array[int] = [18, 16, 14]
const PAPER := Color("eddcb4")
const INK := Color("2a1a10")
const INK_SOFT := Color("5a4030")
const RED_INK := Color("9e2a1e")

var _map: JourneyMap
var _card: PanelContainer
var _region: Label
var _name: Label
var _cleared: Label
## Fonte do kanji do selo (a mesma dos selos do mapa).
var _seal_font: Font
var _boss_icons: Array[TextureRect] = []
var _boss: Label
var _stats: Label
## Coluna ao lado dos retratos (chefes e, no pergaminho alto, os recordes), texto rolável e
## corpo do pergaminho (para os avisos voltarem acima das opções).
var _info: VBoxContainer
var _text: VBoxContainer
var _body: VBoxContainer
## Camada sobre a rolagem com o esfumado (texturas feitas uma vez, desenhadas só ao rolar).
var _fade: Control
var _fade_top: GradientTexture2D
var _fade_bottom: GradientTexture2D
## Ajuste da fonte da narrativa já pedido para o fim do quadro (um só por mudança).
var _story_fit_pending := false
## Largura, altura e texto da última medida (não mede de novo o que não mudou).
var _story_key := ""
var _options: HBoxContainer
var _compact := false
var _scroll: ScrollContainer
## Regras da Lua Vermelha escolhida (todas de I até ela, RedMoon.rules_text), no alto da rolagem.
var _rules: Label
var _journey: Label
var _chronicle: Label
var _mode: OptionButton
var _moon: OptionButton
var _endless: CheckButton
var _bonus: Label
var _go: Button
var _suggest: Label
## Fase mostrada no cartão (pode ser bloqueada; app.selection só guarda fases liberadas).
var _viewing: StringName = &"village"


func _ready() -> void:
	_map = JourneyMap.new()
	_map.stage_selected.connect(_select)
	add_child(_map)
	_build_card()
	add_child(back_button())
	resized.connect(_layout)
	# Furo da câmera que troca de lado com a tela aberta (giro de 180°).
	MenuKit.on_insets_change(self, _layout)
	_layout()


## Mapa à esquerda e pergaminho à direita, dentro da área segura; o pergaminho tem o mesmo
## tamanho para todo ponto (não cresce com o texto).
func _layout() -> void:
	if size.x < 10.0 or size.y < 10.0:
		return
	var insets := MenuKit.safe_insets(self)
	var left := MARGIN + insets.x
	var right := size.x - MARGIN - insets.y
	var height := size.y - MARGIN * 2.0
	var room := right - left - GAP
	# Proporção pela largura da tela inteira: o recorte da câmera sai do mapa, não do pergaminho.
	var card_w := clampf(roundf((size.x - MARGIN * 2.0 - GAP) * CARD_SHARE), CARD_MIN_WIDTH, CARD_WIDTH)
	card_w = minf(card_w, floorf(room * 0.5))
	_set_compact(height < COMPACT_HEIGHT or card_w < COMPACT_WIDTH)
	_fit_go(card_w - 20.0)
	_scroll_auto()
	_card.custom_minimum_size = Vector2(card_w, height)
	_fit_headline()
	_card.position = Vector2(right - card_w, MARGIN)
	_card.size = _card.custom_minimum_size
	_map.position = Vector2(left, MARGIN)
	_map.size = Vector2(room - card_w, height)


## Maior fonte do Começar (GO_FONT_SIZES) que cabe ao lado da Noite Sem Fim em `inner` px.
func _fit_go(inner: float) -> void:
	var font := _go.get_theme_font("font")
	var pad := _go.get_theme_stylebox("normal").get_minimum_size().x
	var room := inner - ENDLESS_MIN_WIDTH - 4.0
	var pick: int = GO_FONT_SIZES[-1]
	for s: int in GO_FONT_SIZES:
		if font.get_string_size(_go.text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x + pad <= room:
			pick = s
			break
	_go.add_theme_font_size_override("font_size", pick)


## Manchete (nome da fase) e selo de vencida numa linha só: a maior fonte de HEADLINE_FONT_SIZES
## (HEADLINE_COMPACT_SIZES no pergaminho baixo) com a palavra do selo; sem espaço, o kanji do selo do mapa
## (a palavra fica na dica), para o nome não quebrar e roubar uma linha da narrativa.
func _fit_headline() -> void:
	var word := tr("stages.cleared")
	_cleared.tooltip_text = word
	var kanji := tr("stages.seal_kanji")
	if kanji == "stages.seal_kanji" or kanji.is_empty():
		kanji = JourneyMap.SEAL_FALLBACK
	var font := _name.get_theme_font("font")
	var base := ThemeFactory.FONT_SIZE
	var room := _card.custom_minimum_size.x - 20.0
	var sizes: Array[int] = HEADLINE_FONT_SIZES
	if _compact:
		sizes = HEADLINE_COMPACT_SIZES
	var seals: Array[String] = [""]
	if _cleared.visible:
		seals = [word, kanji]
	var widths: Array[float] = []
	for seal: String in seals:
		var seal_font := _seal_font if seal == kanji and _seal_font else font
		widths.append(0.0 if seal.is_empty() else seal_font.get_string_size(seal, HORIZONTAL_ALIGNMENT_LEFT, -1, base).x
				+ _cleared.get_theme_stylebox("normal").get_minimum_size().x + 4.0)
	# Fonte maior primeiro; em cada fonte, a palavra do selo antes do kanji.
	var pick := base
	var stamp: String = seals[-1]
	var found := false
	for px: int in sizes:
		var name_w := font.get_string_size(_name.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		for k: int in seals.size():
			if name_w + widths[k] <= room:
				pick = px
				stamp = seals[k]
				found = true
				break
		if found:
			break
	_name.add_theme_font_size_override("font_size", pick)
	if _cleared.visible:
		_cleared.text = stamp
		if stamp == kanji and stamp != word and _seal_font:
			_cleared.add_theme_font_override("font", _seal_font)
		else:
			_cleared.remove_theme_font_override("font")


## Pede o ajuste da fonte da narrativa para o fim do quadro (depois que os contêineres acertam as
## larguras); vários pedidos no mesmo quadro viram um só.
func _queue_story_fit() -> void:
	if _story_fit_pending:
		return
	_story_fit_pending = true
	_fit_story.call_deferred()


## Maior fonte de STORY_FONT_SIZES em que jornada e crônica cabem inteiras na rolagem, medida pela
## fonte (sem mexer nos rótulos) na largura atual do texto: com a barra reservada ela é menor, então
## o que cabe nela cabe sem a barra. Só mede de novo se largura, altura ou texto mudaram.
func _fit_story() -> void:
	_story_fit_pending = false
	var key := "%d|%d|%d|%s" % [_journey.size.x, _scroll.size.y, int(_compact),
			_rules.text + _journey.text + _chronicle.text]
	if _scroll.size.y < 1.0 or _journey.size.x < 1.0 or key == _story_key:
		return
	_story_key = key
	var sep := float(_text.get_theme_constant("separation"))
	var fixed := -sep
	for l: Control in _text.get_children():
		if l.visible and l != _journey and l != _chronicle:
			fixed += l.get_minimum_size().y + sep
	var pick := ThemeFactory.FONT_SIZE
	for px: int in STORY_FONT_SIZES:
		var h := fixed
		for l: Label in [_journey, _chronicle]:
			if l.visible:
				h += _wrapped_height(l, px) + sep
		if h <= _scroll.size.y:
			pick = px
			break
	for l: Label in [_journey, _chronicle]:
		if l.get_theme_font_size("font_size") != pick:
			l.add_theme_font_size_override("font_size", pick)


## Altura do rótulo com quebra de linha na largura atual e na fonte `px` (com o espaço entre linhas).
func _wrapped_height(l: Label, px: int) -> float:
	var font := l.get_theme_font("font")
	var flags := TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	var h := font.get_multiline_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, l.size.x, px, -1, flags).y
	var lines := maxf(1.0, roundf(h / font.get_height(px)))
	return h + lines * float(l.get_theme_constant("line_spacing"))


## Fonte da narrativa em uso (para os testes).
func story_font_size() -> int:
	return _journey.get_theme_font_size("font_size")


## Pergaminho baixo: recordes e avisos passam para o alto da rolagem (e região e chefes ficam
## centrados ao lado dos retratos); alto: recordes ao lado dos retratos e avisos acima das opções.
func _set_compact(on: bool) -> void:
	if on == _compact:
		return
	_compact = on
	_info.alignment = BoxContainer.ALIGNMENT_CENTER if on else BoxContainer.ALIGNMENT_BEGIN
	if on:
		for k: int in range(3):
			var l: Label = [_stats, _bonus, _suggest][k]
			l.reparent(_text, false)
			_text.move_child(l, k)
	else:
		_stats.reparent(_info, false)
		for l: Label in [_bonus, _suggest]:
			l.reparent(_body, false)
			_body.move_child(l, _options.get_index())


func _build_card() -> void:
	_card = PanelContainer.new()
	var paper := StyleBoxFlat.new()
	paper.bg_color = PAPER
	paper.border_color = Color("6b4a2a")
	paper.set_border_width_all(1)
	paper.content_margin_left = 10
	paper.content_margin_right = 10
	paper.content_margin_top = 9
	paper.content_margin_bottom = 8
	_card.add_theme_stylebox_override("panel", paper)
	_card.draw.connect(_draw_scroll_ends)
	add_child(_card)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 3)
	_card.add_child(body)
	_body = body
	# Cabeçalho em duas linhas: nome (e o selo de vencida) e, ao lado dos dois retratos, a
	# região em tinta vermelha sobre os chefes (e os recordes, no pergaminho alto).
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 4)
	_name = _ink(label(""), INK)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_name)
	_cleared = _ink(label(""), Color("fff1d6"))
	_cleared.add_theme_stylebox_override("normal", _stamp_box())
	_cleared.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_cleared.mouse_filter = Control.MOUSE_FILTER_PASS
	if ResourceLoader.exists(JourneyMap.SEAL_FONT):
		_seal_font = load(JourneyMap.SEAL_FONT) as Font
	name_row.add_child(_cleared)
	body.add_child(name_row)
	var boss_row := HBoxContainer.new()
	boss_row.add_theme_constant_override("separation", 3)
	for k: int in range(2):
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(26, 26)
		icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_PASS
		icon.draw.connect(_draw_boss_rim.bind(icon))
		boss_row.add_child(icon)
		_boss_icons.append(icon)
	var info := VBoxContainer.new()
	_info = info
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	_region = _ink(label(""), RED_INK)
	_region.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_region)
	_boss = _ink(label(""), INK)
	# Uma linha só (nomes longos com reticências; o nome inteiro fica na dica).
	_boss.clip_text = true
	_boss.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_boss.mouse_filter = Control.MOUSE_FILTER_PASS
	info.add_child(_boss)
	_stats = _ink(label(""), INK_SOFT)
	_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_stats)
	boss_row.add_child(info)
	body.add_child(boss_row)
	var rule := ColorRect.new()
	rule.color = Color(0.42, 0.29, 0.16, 0.45)
	rule.custom_minimum_size = Vector2(0, 1)
	body.add_child(rule)
	# Rolagem e, por cima dela (mesmo retângulo), a camada do esfumado.
	var story := MarginContainer.new()
	story.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(story)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.resized.connect(_queue_story_fit)
	# Narrativa no limite da altura: a barra aparece, o texto estreita e cresce, a barra some, o
	# texto alarga... (laço sem fim de reordenação). Quando a barra aparece, a largura dela fica
	# reservada até o próximo texto ou layout (_scroll_auto), então o texto não pula de largura.
	_scroll.get_v_scroll_bar().visibility_changed.connect(func() -> void:
		if _scroll.get_v_scroll_bar().visible:
			_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_RESERVE)
	var text := VBoxContainer.new()
	_text = text
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Se a narrativa couber, fica centrada no espaço livre do pergaminho.
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 4)
	_scroll.add_child(text)
	_rules = _ink(label(""), RED_INK)
	_rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(_rules)
	_journey = _ink(label(""), INK)
	_journey.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_journey.resized.connect(_queue_story_fit)
	text.add_child(_journey)
	_chronicle = _ink(label(""), RED_INK)
	_chronicle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(_chronicle)
	story.add_child(_scroll)
	_fade = Control.new()
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_top = _fade_texture(true)
	_fade_bottom = _fade_texture(false)
	_fade.draw.connect(_draw_fade)
	story.add_child(_fade)
	var bar := _scroll.get_v_scroll_bar()
	bar.value_changed.connect(func(_v: float) -> void: _fade.queue_redraw())
	bar.changed.connect(_fade.queue_redraw)
	bar.visibility_changed.connect(_fade.queue_redraw)
	_bonus = _ink(label(""), Color("2f5a22"))
	_bonus.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_bonus)
	_suggest = _ink(label(""), Color("1f5a5a"))
	_suggest.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_suggest)
	_build_options(body)


func _build_options(body: VBoxContainer) -> void:
	var options := HBoxContainer.new()
	_options = options
	options.add_theme_constant_override("separation", 4)
	_mode = OptionButton.new()
	_mode.add_item(tr("mode.normal"))
	_mode.add_item(tr("mode.brisa"))
	_mode.custom_minimum_size = Vector2(0, 28)
	_mode.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mode.clip_text = true
	_mode.fit_to_longest_item = false
	_mode.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_mode.item_selected.connect(func(index: int) -> void:
		app.selection["mode"] = "brisa" if index == 1 else "normal"
		_refresh())
	options.add_child(_mode)
	_moon = OptionButton.new()
	_moon.custom_minimum_size = Vector2(0, 28)
	_moon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_moon.clip_text = true
	_moon.fit_to_longest_item = false
	_moon.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_moon.item_selected.connect(func(index: int) -> void:
		app.selection["moon"] = index
		_refresh())
	options.add_child(_moon)
	body.add_child(options)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 4)
	_endless = CheckButton.new()
	_endless.text = tr("stages.endless")
	# Em pergaminho estreito o texto quebra em duas linhas em vez de empurrar o Começar para baixo
	# (que encolhe a fonte, _fit_go, para nunca descer para outra linha).
	_endless.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_endless.custom_minimum_size = Vector2(ENDLESS_MIN_WIDTH, 32)
	_endless.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_endless.toggled.connect(func(on: bool) -> void: app.selection["endless"] = on)
	bottom.add_child(_endless)
	_go = button(tr("stages.start"), func() -> void: app.start_run(), Vector2(80, 32))
	_go.add_theme_font_size_override("font_size", 24)
	bottom.add_child(_go)
	body.add_child(bottom)


func on_show() -> void:
	_map.refresh(StringName(String(app.selection.get("hero", "aki"))))
	_mode.selected = 1 if String(app.selection.get("mode", "normal")) == "brisa" else 0
	var current := StringName(String(app.selection.get("stage", "")))
	if current == &"" or not MetaProgress.is_stage_unlocked(current):
		current = first_open_stage()
	_map.select(current, false)
	_select(current)
	_map.focus_selected.call_deferred()


## Primeira fase liberada e ainda não vencida (na ordem da jornada); senão a última liberada.
static func first_open_stage() -> StringName:
	var last: StringName = &"village"
	for id: StringName in _ordered_stages():
		if not MetaProgress.is_stage_unlocked(id):
			continue
		if not bool(SaveManager.stage_best(id)["won"]):
			return id
		last = id
	return last


static func _ordered_stages() -> Array[StringName]:
	var ids := DB.ids("stages")
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return int(DB.stage(a)["order"]) < int(DB.stage(b)["order"]))
	return ids


func _select(id: StringName) -> void:
	_viewing = id
	var unlocked := MetaProgress.is_stage_unlocked(id)
	if unlocked:
		app.selection["stage"] = String(id)
	var best := SaveManager.stage_best(id)
	_moon.clear()
	_moon.add_item(tr("moon.none"))
	var max_moon := mini(HyakkiGame.MAX_MOON, int(best["max_moon"]) + 1) if bool(best["won"]) else 0
	for m: int in range(1, max_moon + 1):
		_moon.add_item(tr("moon.level") % _roman(m))
	var moon := mini(int(app.selection.get("moon", 0)), max_moon)
	_moon.selected = moon
	if unlocked:
		app.selection["moon"] = moon
	_endless.disabled = not bool(best["won"])
	if _endless.disabled:
		_endless.set_pressed_no_signal(false)
		if unlocked:
			app.selection["endless"] = false
	else:
		_endless.set_pressed_no_signal(bool(app.selection.get("endless", false)))
	_refresh()


## Rolagem do pergaminho de volta ao automático (barra só se o texto novo não couber).
func _scroll_auto() -> void:
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO


func _refresh() -> void:
	_scroll_auto()
	var id := _viewing
	var best := SaveManager.stage_best(id)
	var unlocked := MetaProgress.is_stage_unlocked(id)
	var hidden := JourneyGeo.HIDDEN.has(id) and not unlocked
	_region.text = "???" if hidden else tr("stage.%s.region" % id)
	_name.text = "???" if hidden else tr("stage.%s.name" % id)
	_cleared.visible = bool(best["won"])
	_fit_headline()
	_refresh_bosses(id)
	var lines: PackedStringArray = []
	if not unlocked:
		lines.append(tr("stages.locked"))
	else:
		if float(best["best_time"]) > 0.0:
			lines.append(tr("stages.best") % format_time(float(best["best_time"])))
		# Vencida sem Lua Vermelha (max_moon 0) não tem recorde de lua para mostrar.
		if int(best["max_moon"]) >= 1:
			lines.append(tr("stages.moon_best") % _roman(int(best["max_moon"])))
	# As regras se somam: com a Lua N escolhida aparecem todas, de I até N (nada no modo Brisa).
	var brisa := String(app.selection.get("mode", "normal")) == "brisa"
	var moon := int(app.selection.get("moon", 0)) if unlocked and not brisa else 0
	_rules.text = "\n".join(RedMoon.rules_text(moon))
	_rules.visible = not _rules.text.is_empty()
	_stats.text = "\n".join(lines)
	# Sem recordes, a linha some (no pergaminho baixo ela abriria um vão acima da narrativa).
	_stats.visible = not lines.is_empty()
	_journey.text = tr("stages.secret_hint") if hidden else tr("stage.%s.journey" % id)
	_chronicle.text = _format(tr("stages.chronicle"), tr("stage.%s.dawn" % id)) if bool(best["won"]) else ""
	_chronicle.visible = bool(best["won"])
	_scroll.scroll_vertical = 0
	_moon.disabled = String(app.selection.get("mode", "normal")) == "brisa" or not unlocked
	_endless.disabled = not bool(best["won"])
	_go.disabled = not unlocked
	var pending := ShopManager.pending_next_run()
	var names := pending.map(func(s: Variant) -> String: return tr("shop.%s.name" % s))
	_bonus.text = tr("stages.bonus") % ", ".join(names) if not pending.is_empty() else ""
	_bonus.visible = not _bonus.text.is_empty()
	# Depois de 5 derrotas seguidas na mesma fase, sugere o modo Brisa (plano 15.3).
	var streak := int((SaveManager.data["defeat_streak"] as Dictionary).get(String(id), 0))
	_suggest.text = tr("stages.suggest_brisa") if streak >= 5 and String(app.selection.get("mode", "")) != "brisa" else ""
	_suggest.visible = not _suggest.text.is_empty()
	_queue_story_fit()


## Os dois chefes da fase: coloridos se já derrotados, senão em silhueta.
func _refresh_bosses(id: StringName) -> void:
	var defeated: Dictionary = SaveManager.data["stats"]["bosses_defeated"]
	var bosses: Array = DB.stage(id).get("bosses", [])
	for k: int in range(_boss_icons.size()):
		var icon := _boss_icons[k]
		icon.visible = k < bosses.size()
		if not icon.visible:
			continue
		var boss := StringName(String((bosses[k] as Dictionary)["id"]))
		var known := defeated.has(String(boss))
		icon.set_meta("face", JourneyMap.face_texture(boss, 24))
		icon.set_meta("shape", JourneyMap.silhouette_texture(boss, 21))
		icon.tooltip_text = tr("boss.%s.name" % boss) if known else "???"
		icon.set_meta("known", known)
		icon.queue_redraw()
	# Nomes dos chefes já derrotados ("???" para os outros); nenhum conhecido: "Chefes: ???".
	var names: PackedStringArray = []
	for boss_data: Dictionary in bosses:
		var boss := String(boss_data["id"])
		names.append(tr("boss.%s.name" % boss) if defeated.has(boss) else "???")
	var known_count := names.size() - names.count("???")
	var shown := ", ".join(names) if known_count > 0 else "???"
	_boss.text = (tr("stages.bosses") if names.size() > 1 else tr("stages.boss")) % shown
	_boss.tooltip_text = _boss.text


func boss_icon_known(index: int) -> bool:
	return _boss_icons[index].visible and bool(_boss_icons[index].get_meta("known", false))


## Retrato redondo do chefe no cartão: colorido e com aro dourado se ele já caiu; senão
## silhueta com "?".
func _draw_boss_rim(icon: TextureRect) -> void:
	var c := icon.size * 0.5
	var known := bool(icon.get_meta("known", false))
	icon.draw_circle(c, 13.0, Color("3a2a12"))
	icon.draw_circle(c, 12.0, Color("f6ead0") if known else Color("e9dcb8"))
	var image := icon.get_meta("face" if known else "shape") as Texture2D if icon.has_meta("shape") else null
	if image:
		var side := image.get_size()
		icon.draw_texture_rect(image, Rect2((c - side * 0.5).floor(), side), false)
	icon.draw_arc(c, 13.0, 0.0, TAU, 28, Color("b8862a") if known else Color("6a5a4a"), 1.5)


func _ink(l: Label, color: Color) -> Label:
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 0)
	return l


func _stamp_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("b8322a")
	box.border_color = Color("6e1a12")
	box.set_border_width_all(1)
	box.content_margin_left = 3
	box.content_margin_right = 3
	box.content_margin_top = 0
	box.content_margin_bottom = 0
	return box


## Pontas do pergaminho (bastões de madeira em cima e embaixo) e fibras do papel.
func _draw_scroll_ends() -> void:
	var w := _card.size.x
	var h := _card.size.y
	for k: int in range(9):
		var y := 14.0 + k * 31.0 + (k % 3) * 5.0
		_card.draw_line(Vector2(6, y), Vector2(w - 6, y + 1), Color(0.55, 0.42, 0.25, 0.08), 1.0)
	for y: float in [0.0, h - 4.0]:
		_card.draw_rect(Rect2(-1, y, w + 2, 4), Color("4a2e1a"))
		_card.draw_rect(Rect2(-1, y, w + 2, 1), Color("7a5232"))
		_card.draw_rect(Rect2(-1, y, 3, 4), ThemeFactory.ACCENT)
		_card.draw_rect(Rect2(w - 2, y, 3, 4), ThemeFactory.ACCENT)


## Degradê vertical da cor do papel: opaco na borda (em cima ou embaixo), transparente para dentro.
func _fade_texture(top: bool) -> GradientTexture2D:
	var gradient := Gradient.new()
	var clear := Color(PAPER, 0.0)
	gradient.set_color(0, PAPER if top else clear)
	gradient.set_color(1, clear if top else PAPER)
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 1
	tex.height = int(FADE)
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	return tex


## Esfumado da narrativa (fora da barra de rolagem): embaixo enquanto há texto abaixo, em cima
## depois de rolar.
func _draw_fade() -> void:
	var state := fade_state()
	var w := _fade.size.x - (_scroll.get_v_scroll_bar().size.x if _scroll.get_v_scroll_bar().visible else 0.0)
	if state.x:
		_fade.draw_texture_rect(_fade_top, Rect2(0, 0, w, FADE), false)
	if state.y:
		_fade.draw_texture_rect(_fade_bottom, Rect2(0, _fade.size.y - FADE, w, FADE), false)


## Esfumado ligado (1) ou não (0) em cima e embaixo da narrativa.
func fade_state() -> Vector2i:
	var bar := _scroll.get_v_scroll_bar()
	return Vector2i(int(bar.value > 0.5), int(bar.max_value - bar.page - bar.value > 0.5))


## "%s" com o texto, ou os dois juntos se a tradução ainda não tem marcador.
static func _format(template: String, value: String) -> String:
	return template % value if template.contains("%s") else "%s %s" % [template, value]


static func _roman(n: int) -> String:
	return ["", "I", "II", "III", "IV", "V"][clampi(n, 0, 5)]
