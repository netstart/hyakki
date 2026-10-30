extends Screen
## Opções (plano 7.5 e 17.5), em seis seções com ícone: Áudio, Controles, Gráficos,
## Acessibilidade, Idioma e Outros. À esquerda, o trilho de abas (tocar rola até a seção;
## rolar acende a aba da seção visível); à direita, uma só rolagem por arraste com as seções
## em cartões de laca. Cada linha é rótulo (quebra linha, sem cortar) + controle estilizado:
## chave de laca (MenuKit.Toggle), barra de volume com puxador dourado, seletor segmentado,
## lista suspensa ou botões. A qualidade gráfica tem uma prévia do que cada nível muda,
## que acompanha a troca ao vivo (também a feita na pausa).
##
## Cada controle tem o nome "opt_<chave>" (os testes o acham por ele); nas
## chaves e na qualidade gráfica o rótulo é o primeiro filho da linha do controle.

const CONTENT_TOP := 42.0
const MARGIN := 8.0
const ROW_HEIGHT := 30.0
const ROW_GAP := 2
const SECTION_GAP := 8
const PERCENT_WIDTH := 34.0
const SCROLL_DEADZONE := 8
const SCROLL_TIME := 0.32
## Recuo e largura da amostra das linhas de números por tipo.
const DAMAGE_INDENT := 10.0
const DAMAGE_SAMPLE_WIDTH := 30.0
## Política de privacidade publicada (exigida pela política de Dados do Usuário do Google Play
## acessível dentro do app). Aberta no navegador pela linha "Política de privacidade".
const PRIVACY_POLICY_URL := "https://netstart.github.io/privacy-policy.html"
## Seções: [id, ícone Kenney (ou glifo), chave do texto].
const SECTIONS := [
	["audio", "audio_on"], ["controls", "gamepad"], ["display", "contrast"],
	["access", "person"], ["language", "あ"], ["other", "gear"],
]

## Seção a reabrir depois de trocar o idioma (a tela é recriada).
static var _restore_section := -1
## Quem abre links externos. Vazio: OS.shell_open. Os testes trocam por um registrador,
## para conferir a URL sem abrir o navegador.
static var url_opener: Callable = Callable()

var _scroll: ScrollContainer
var _content: VBoxContainer
var _rail: VBoxContainer
var _tabs: Array[Button] = []
var _headers: Array[Control] = []
var _sized: Array[Control] = []
var _language: GridContainer
var _quality: OptionButton
var _preview: QualityPreview
var _current := -1
## Linhas dos números por tipo (_damage_type_rows).
var _damage_types: VBoxContainer
var _scroll_tween: Tween


func _ready() -> void:
	var scrim := ColorRect.new()
	scrim.color = Color(0.02, 0.012, 0.04, 0.5)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)
	MenuKit.header(self, tr("options.title"), "設")
	_rail = VBoxContainer.new()
	_rail.name = "Rail"
	_rail.add_theme_constant_override("separation", 3)
	add_child(_rail)
	_scroll = ScrollContainer.new()
	_scroll.name = "opt_scroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.scroll_deadzone = SCROLL_DEADZONE
	ThemeFactory.style_scrollbar(_scroll.get_v_scroll_bar())
	_scroll.get_v_scroll_bar().value_changed.connect(func(_v: float) -> void: _spy())
	add_child(_scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", SECTION_GAP)
	_scroll.add_child(_content)
	var titles := [tr("options.tab_audio"), tr("options.tab_controls"), tr("options.tab_display"),
			tr("options.tab_access"), tr("options.language"), tr("options.tab_other")]
	for i: int in SECTIONS.size():
		_tabs.append(_rail_tab(i, titles[i]))
	_build_audio(_section(0, titles[0]))
	_build_controls(_section(1, titles[1]))
	_build_display(_section(2, titles[2]))
	_build_access(_section(3, titles[3]))
	_build_language(_section(4, titles[4]))
	_build_other(_section(5, titles[5]))
	var tail := Control.new()
	tail.custom_minimum_size.y = 4
	tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(tail)
	_let_drag_through(_content)
	add_child(back_button())
	resized.connect(_layout)
	# Furo da câmera que troca de lado com a tela aberta (giro de 180°).
	MenuKit.on_insets_change(self, _layout)
	MenuKit.on_quality_change(self, _refresh_quality)
	_layout()


func on_show() -> void:
	_layout()
	_refresh_quality()
	if _restore_section >= 0:
		var section := _restore_section
		_restore_section = -1
		show_section.call_deferred(section, false)
	else:
		_set_current(0)


## Rola até a seção `index` (deslizando, se os efeitos de UI estiverem ligados).
func show_section(index: int, animate: bool = true) -> void:
	index = clampi(index, 0, _headers.size() - 1)
	_set_current(index)
	var bar := _scroll.get_v_scroll_bar()
	var target := clampf(_headers[index].position.y, 0.0, maxf(0.0, bar.max_value - bar.page))
	if _scroll_tween != null and _scroll_tween.is_valid():
		_scroll_tween.kill()
	if not animate or MenuKit.ui_fx() == 0 or not is_inside_tree():
		_scroll.scroll_vertical = int(target)
		_set_current(index)
		return
	_scroll_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_scroll_tween.tween_property(_scroll, "scroll_vertical", int(target), SCROLL_TIME)
	_scroll_tween.finished.connect(_set_current.bind(index))


func current_section() -> int:
	return _current


# --- Seções ---------------------------------------------------------------------------

func _build_audio(card: VBoxContainer) -> void:
	for key: String in ["music_volume", "sfx_volume", "ui_volume"]:
		card.add_child(_slider_row(key))
	card.add_child(_toggle_row("damage_sounds", tr("options.damage_sounds")))
	card.add_child(_toggle_row("hurt_sounds", tr("options.hurt_sounds")))


func _build_controls(card: VBoxContainer) -> void:
	card.add_child(_segment_row("joystick_mode", tr("options.joystick_mode"),
			[["floating", tr("options.joystick_floating")], ["fixed", tr("options.joystick_fixed")]]))
	card.add_child(_segment_row("joystick_side", tr("options.joystick_side"),
			[["left", tr("options.side_left")], ["right", tr("options.side_right")]]))
	card.add_child(_toggle_row("vibration", tr("options.vibration")))


func _build_display(card: VBoxContainer) -> void:
	card.add_child(_quality_row())
	_preview = QualityPreview.new()
	_preview.name = "QualityPreview"
	card.add_child(_preview)
	var hints := {30: tr("options.fps30"), 60: tr("options.fps60"), 120: tr("options.fps120")}
	var fps := _segment_row("fps", tr("options.fps"), [[30, "30"], [60, "60"], [120, "120"]])
	var hint := MenuKit.text(String(hints.get(int(Settings.get_value("fps")), "")), 12, ThemeFactory.MUTED)
	hint.name = "opt_fps_hint"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var label_col := VBoxContainer.new()
	label_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_col.alignment = BoxContainer.ALIGNMENT_CENTER
	label_col.add_theme_constant_override("separation", 0)
	var first := fps.get_child(0)
	fps.remove_child(first)
	label_col.add_child(first)
	label_col.add_child(hint)
	fps.add_child(label_col)
	fps.move_child(label_col, 0)
	(fps.find_child("opt_fps", false, false) as MenuKit.Segmented).value_changed.connect(func(v: Variant) -> void:
		hint.text = String(hints.get(int(v), "")))
	card.add_child(fps)
	card.add_child(_toggle_row("damage_numbers", tr("options.damage_numbers")))
	card.add_child(_damage_type_rows())
	card.add_child(_toggle_row("hp_bar_below", tr("options.hp_bar_below")))


## Números por tipo (DamagePalette.SETTING_KEYS), recuados sob "Números de dano": cada linha
## com uma amostra do número na paleta em uso (daltonismo incluído). Com a opção geral
## desligada, as linhas ficam apagadas e as chaves travadas (o valor de cada uma é mantido).
func _damage_type_rows() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "opt_damage_types"
	box.add_theme_constant_override("separation", ROW_GAP)
	var labels := [tr("options.damage_show_hit"), tr("options.damage_show_high"), tr("options.damage_show_crit"),
			tr("options.damage_show_dot"), tr("options.damage_show_taken"),
			tr("options.damage_show_taken_heavy"), tr("options.damage_show_heal")]
	for kind: int in DamagePalette.SETTING_KEYS.size():
		var row := _toggle_row(DamagePalette.SETTING_KEYS[kind], labels[kind])
		row.custom_minimum_size.y = ROW_HEIGHT - 4.0
		var indent := Control.new()
		indent.custom_minimum_size.x = DAMAGE_INDENT
		indent.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(indent)
		row.move_child(indent, 0)
		var sample := MenuKit.text(DamagePalette.text(kind, DamagePalette.SAMPLE_AMOUNTS[kind]), 12, Color.WHITE)
		sample.name = "sample_%d" % kind
		sample.custom_minimum_size.x = DAMAGE_SAMPLE_WIDTH
		sample.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sample.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		sample.size_flags_vertical = Control.SIZE_FILL
		row.add_child(sample)
		row.move_child(sample, 1)
		box.add_child(row)
	_damage_types = box
	_refresh_damage_types()
	Settings.changed.connect(_on_setting_changed)
	return box


func _on_setting_changed(key: String) -> void:
	if key == "damage_numbers" or key == "colorblind":
		_refresh_damage_types()


## Cor das amostras (paleta em uso) e estado das linhas conforme a opção geral.
func _refresh_damage_types() -> void:
	var on := bool(Settings.get_value("damage_numbers"))
	var colorblind := bool(Settings.get_value("colorblind"))
	for kind: int in _damage_types.get_child_count():
		var row := _damage_types.get_child(kind) as HBoxContainer
		var style := DamagePalette.style(kind, colorblind)
		var sample := row.get_node("sample_%d" % kind) as Label
		sample.add_theme_color_override("font_color", style["fill"])
		sample.add_theme_color_override("font_outline_color", style["outline"])
		sample.add_theme_constant_override("outline_size", int(style["outline_px"]) + 1)
		(row.get_node("opt_%s" % DamagePalette.SETTING_KEYS[kind]) as BaseButton).disabled = not on
		row.modulate.a = 1.0 if on else 0.4


func _build_access(card: VBoxContainer) -> void:
	card.add_child(_toggle_row("colorblind", tr("options.colorblind")))
	card.add_child(_toggle_row("reduce_flashes", tr("options.reduce_flashes")))


## Idioma: um chip por idioma, com o nome escrito nele mesmo; o atual em vermelhão.
func _build_language(card: VBoxContainer) -> void:
	_language = GridContainer.new()
	_language.name = "opt_language"
	_language.add_theme_constant_override("h_separation", 4)
	_language.add_theme_constant_override("v_separation", 4)
	for code: String in Locale.SUPPORTED:
		var chip := Button.new()
		chip.name = "lang_%s" % code
		chip.text = Locale.NATIVE_NAMES[code]
		chip.custom_minimum_size = Vector2(0, 28)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		chip.focus_mode = Control.FOCUS_ALL
		chip.set_meta("code", code)
		if code == Locale.current:
			MenuKit.apply_primary(chip, 12)
			chip.add_theme_constant_override("outline_size", 3)
		else:
			MenuKit.apply_lacquer(chip)
		chip.pressed.connect(func() -> void:
			if code == Locale.current:
				return
			AudioManager.play_ui("ui_accept")
			_restore_section = 4
			Locale.set_language(code))
		_language.add_child(chip)
	card.add_child(_language)


func _build_other(card: VBoxContainer) -> void:
	card.add_child(_toggle_row("notifications", tr("options.notifications")))
	card.add_child(_toggle_row("dialogues_always", tr("options.dialogues_always")))
	# Dicas 心得: balão da guardiã no título e cartão nos Resultados (ligadas por padrão).
	card.add_child(_toggle_row("tips", tr("options.tips")))
	# Sem anúncios (AdsManager.ads_enabled = false) não há consentimento a rever. "Restaurar
	# compras" fica sempre que há loja de dinheiro (Play Billing ou o simulado): a Ampulheta de
	# Fūjin (velocidade 2x/3x) é vendida com ou sem anúncios.
	if AdsManager.ads_enabled:
		card.add_child(_button_row("privacy", tr("options.privacy"),
				[_small_button(tr("options.privacy_open"), _open_privacy)]))
	if PurchaseManager.billing_available():
		card.add_child(_button_row("restore", tr("options.purchases"),
				[_small_button(tr("shop.restore"), func() -> void: PurchaseManager.restore())]))
	var credits := _small_button(tr("title.credits"), func() -> void: app.go(&"credits"))
	credits.name = "opt_credits"
	var licenses := _small_button(tr("options.licenses"), func() -> void: app.go(&"licenses"))
	licenses.name = "opt_licenses"
	card.add_child(_button_row("about", tr("options.about"), [credits, licenses]))
	# Visível com e sem anúncios (política de Dados do Usuário do Google Play).
	card.add_child(_button_row("privacy_policy", tr("options.privacy_policy"),
			[_small_button(tr("options.privacy_policy_open"), open_privacy_policy)]))
	card.add_child(_reset_row())


# --- Linhas ---------------------------------------------------------------------------

## Título da seção (ícone + nome + filete) e o cartão de laca onde vão as linhas.
func _section(index: int, title: String) -> VBoxContainer:
	var head := HBoxContainer.new()
	head.name = "Section_%s" % SECTIONS[index][0]
	head.add_theme_constant_override("separation", 6)
	head.custom_minimum_size.y = 20
	head.add_child(_icon(index, 16))
	var l := MenuKit.text(title, 12, ThemeFactory.ACCENT)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(l)
	var rule := ColorRect.new()
	rule.color = Color(ThemeFactory.ACCENT, 0.3)
	rule.custom_minimum_size = Vector2(0, 1)
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(rule)
	_content.add_child(head)
	_headers.append(head)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", ThemeFactory.lacquer_panel(0.78))
	_content.add_child(card)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", ROW_GAP)
	card.add_child(rows)
	return rows


func _row(text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = ROW_HEIGHT
	row.add_theme_constant_override("separation", 8)
	var l := MenuKit.text(text, 12, ThemeFactory.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_FILL
	row.add_child(l)
	return row


## Caixa da coluna dos controles (largura ajustada em _layout).
func _holder(control: Control) -> Control:
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_sized.append(control)
	return control


func _toggle_row(key: String, text: String) -> HBoxContainer:
	var row := _row(text)
	var toggle := MenuKit.Toggle.new()
	toggle.name = "opt_%s" % key
	toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	toggle.button_pressed = bool(Settings.get_value(key))
	toggle.toggled.connect(func(on: bool) -> void: Settings.set_value(key, on))
	row.add_child(toggle)
	return row


func _slider_row(key: String) -> HBoxContainer:
	var row := _row(_volume_text(key))
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var slider := HSlider.new()
	slider.name = "opt_%s" % key
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = float(Settings.get_value(key))
	slider.custom_minimum_size = Vector2(60, 26)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	MenuKit.apply_slider(slider)
	box.add_child(slider)
	var percent := MenuKit.text("%d%%" % roundi(slider.value * 100.0), 12, ThemeFactory.ACCENT)
	percent.name = "opt_%s_value" % key
	percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	percent.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	percent.custom_minimum_size.x = PERCENT_WIDTH
	percent.size_flags_vertical = Control.SIZE_FILL
	box.add_child(percent)
	slider.value_changed.connect(func(v: float) -> void:
		percent.text = "%d%%" % roundi(v * 100.0)
		Settings.set_value(key, v))
	slider.drag_ended.connect(func(_changed: bool) -> void: AudioManager.play_ui("ui_move"))
	row.add_child(_holder(box))
	return row


func _volume_text(key: String) -> String:
	match key:
		"music_volume":
			return tr("options.music_volume")
		"sfx_volume":
			return tr("options.sfx_volume")
	return tr("options.ui_volume")


func _segment_row(key: String, text: String, options: Array) -> HBoxContainer:
	var row := _row(text)
	var seg := MenuKit.Segmented.new()
	seg.name = "opt_%s" % key
	seg.setup(options, Settings.get_value(key))
	seg.value_changed.connect(func(v: Variant) -> void:
		Settings.set_value(key, v)
		seg.set_value(v))
	row.add_child(_holder(seg))
	return row


## Qualidade gráfica (GfxQuality): Auto (com o nível detectado), Baixa, Média e Alta. Vale
## na hora: os sistemas visuais ouvem Settings.changed. A prévia logo abaixo descreve o nível.
func _quality_row() -> HBoxContainer:
	var key := GfxQuality.changed_signal_key()
	var row := _row(tr("options.graphics_quality"))
	_quality = OptionButton.new()
	_quality.name = "opt_%s" % key
	_quality.custom_minimum_size.y = 28
	_quality.fit_to_longest_item = true
	for mode: String in GfxQuality.MODES:
		_quality.add_item(GfxQuality.mode_label(mode))
		_quality.set_item_metadata(_quality.item_count - 1, mode)
		if mode == GfxQuality.mode():
			_quality.selected = _quality.item_count - 1
	MenuKit.apply_option(_quality)
	_quality.item_selected.connect(func(index: int) -> void:
		AudioManager.play_ui("ui_accept")
		Settings.set_value(key, _quality.get_item_metadata(index)))
	row.add_child(_holder(_quality))
	return row


func _small_button(text: String, action: Callable) -> Button:
	var b := button(text, action, Vector2(0, 28))
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	MenuKit.apply_lacquer(b)
	return b


func _button_row(key: String, text: String, buttons: Array) -> HBoxContainer:
	var row := _row(text)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	for b: Button in buttons:
		if not String(b.name).begins_with("opt_"):
			b.name = "opt_%s" % key
		box.add_child(b)
	row.add_child(_holder(box))
	return row


## Apagar o progresso (dois toques, botão de perigo) e a versão do jogo.
func _reset_row() -> HBoxContainer:
	var row := _row(tr("options.reset"))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var reset := button(tr("options.reset_button"), Callable(), Vector2(0, 28))
	reset.name = "opt_reset"
	reset.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var danger: Array[StyleBoxFlat] = [
		ThemeFactory.flat_box(Color(0.32, 0.05, 0.04, 0.9), Color("e07a5f"), 1, 3, Vector2(8, 2)),
		ThemeFactory.flat_box(Color(0.5, 0.08, 0.05, 0.95), Color("ffb199"), 1, 3, Vector2(8, 2)),
		ThemeFactory.flat_box(Color(0.22, 0.03, 0.03, 0.95), Color("ffb199"), 1, 3, Vector2(8, 2)),
		ThemeFactory.flat_box(Color(0.2, 0.08, 0.07, 0.6), Color("e07a5f", 0.4), 1, 3, Vector2(8, 2)),
	]
	ThemeFactory.apply_button_boxes(reset, danger)
	reset.add_theme_color_override("font_color", Color("ffd6c9"))
	reset.pressed.connect(func() -> void:
		if reset.has_meta("armed"):
			SaveManager.reset_profile()
			reset.text = tr("options.reset_done")
			reset.remove_meta("armed")
		else:
			reset.set_meta("armed", true)
			reset.text = tr("options.reset_confirm"))
	box.add_child(reset)
	var version := MenuKit.text("%s %s" % [tr("options.version"),
			String(ProjectSettings.get_setting("application/config/version", "0.1.0"))], 12, ThemeFactory.MUTED)
	version.name = "opt_version"
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(version)
	row.add_child(_holder(box))
	return row


## Abre a política de privacidade no navegador (ou no `url_opener` dos testes).
func open_privacy_policy() -> void:
	if url_opener.is_valid():
		url_opener.call(PRIVACY_POLICY_URL)
	else:
		OS.shell_open(PRIVACY_POLICY_URL)


## AdMob: formulário de privacidade do Google (UMP); simulado: a tela própria.
func _open_privacy() -> void:
	if not AdsManager.open_privacy_options(func() -> void: pass):
		app.go(&"consent")


# --- Trilho e layout ------------------------------------------------------------------

func _rail_tab(index: int, title: String) -> Button:
	var b := Button.new()
	b.name = "Tab_%s" % SECTIONS[index][0]
	b.text = title
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(0, 30)
	var icon := _icon(index, 14)
	icon.position = Vector2(8, 8)
	icon.size = Vector2(14, 14)
	b.add_child(icon)
	# Aceso = pressionado (toggle): trocar a aba atual durante a rolagem (scroll-spy) só muda o estado
	# do botão, sem trocar overrides de tema (cada troca refazia o layout e a quebra de linha do
	# trilho e engasgava a rolagem ao cruzar uma seção).
	b.toggle_mode = true
	b.pressed.connect(func() -> void:
		AudioManager.play_ui("ui_move")
		show_section(index)
		_sync_tabs())
	_rail.add_child(b)
	_style_tab(b)
	return b


## Estilo único da aba (uma vez, na criação): apagada no normal, acesa quando pressionada.
func _style_tab(b: Button) -> void:
	var normal := ThemeFactory.flat_box(Color(0.05, 0.03, 0.05, 0.55), Color(ThemeFactory.GOLD, 0.25), 1, 3,
			Vector2(28, 2))
	normal.content_margin_right = 4
	var lit := ThemeFactory.flat_box(Color(0.55, 0.12, 0.08, 0.9), ThemeFactory.ACCENT, 1, 3, Vector2(28, 2))
	lit.content_margin_right = 4
	lit.border_width_left = 3
	var hover := ThemeFactory.flat_box(Color(0.22, 0.07, 0.06, 0.85), Color(ThemeFactory.ACCENT, 0.8), 1, 3,
			Vector2(28, 2))
	hover.content_margin_right = 4
	b.begin_bulk_theme_override()
	var boxes: Array[StyleBoxFlat] = [normal, hover, lit, normal]
	ThemeFactory.apply_button_boxes(b, boxes)
	b.add_theme_color_override("font_color", ThemeFactory.MUTED)
	b.add_theme_color_override("font_hover_color", ThemeFactory.ACCENT)
	b.add_theme_color_override("font_focus_color", ThemeFactory.ACCENT)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
	b.add_theme_constant_override("outline_size", 3)
	b.end_bulk_theme_override()
	(b.get_child(0) as CanvasItem).modulate = ThemeFactory.MUTED


## Acende a aba atual e apaga as outras (só o estado pressionado e a cor do ícone).
func _sync_tabs() -> void:
	for i: int in _tabs.size():
		var on := i == _current
		if _tabs[i].button_pressed != on:
			_tabs[i].set_pressed_no_signal(on)
			(_tabs[i].get_child(0) as CanvasItem).modulate = ThemeFactory.ACCENT if on else ThemeFactory.MUTED


func _set_current(index: int) -> void:
	if index == _current:
		return
	_current = index
	_sync_tabs()


## Aba da seção cujo título já passou do topo da rolagem (a última, no fim da rolagem).
func _spy() -> void:
	if _scroll_tween != null and _scroll_tween.is_running():
		return
	var y := float(_scroll.scroll_vertical) + 12.0
	var bar := _scroll.get_v_scroll_bar()
	var index := 0
	for i: int in _headers.size():
		if _headers[i].position.y <= y:
			index = i
	if bar.value >= bar.max_value - bar.page - 1.0 and bar.max_value > bar.page:
		var view_end := float(_scroll.scroll_vertical) + _scroll.size.y
		for i: int in _headers.size():
			if _headers[i].position.y < view_end - 40.0 and i > index and i == _headers.size() - 1:
				index = i
	_set_current(index)


func _icon(index: int, px: int) -> Control:
	var name := String(SECTIONS[index][1])
	if name.length() == 1:
		var glyph := MenuKit.text(name, 12, ThemeFactory.ACCENT)
		glyph.add_theme_font_override("font", MenuKit.ja_font())
		glyph.add_theme_constant_override("outline_size", 0)
		glyph.custom_minimum_size = Vector2(px, px)
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		return glyph
	var rect := TextureRect.new()
	rect.texture = UiIcons.get_icon(name, px)
	rect.custom_minimum_size = Vector2(px, px)
	rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	rect.modulate = ThemeFactory.ACCENT
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _layout() -> void:
	if _scroll == null:
		return
	var inset := MenuKit.safe_insets(self)
	var w := size.x - inset.x - inset.y
	var rail_w := 132.0 if w >= 600.0 else 112.0
	_rail.position = Vector2(inset.x + MARGIN, CONTENT_TOP + 2)
	_rail.size = Vector2(rail_w, 0)
	# Âncoras e margens: a rolagem acompanha a tela mesmo se o mínimo mudar depois.
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.offset_left = inset.x + MARGIN + rail_w + 8
	_scroll.offset_top = CONTENT_TOP
	_scroll.offset_right = -(inset.y + MARGIN)
	_scroll.offset_bottom = -4
	var pane := size.x - _scroll.offset_left - inset.y - MARGIN - 8.0
	var control_w := roundf(clampf(pane * 0.5, 140.0, 240.0))
	for c: Control in _sized:
		c.custom_minimum_size.x = control_w
	_language.columns = 3 if pane >= 330.0 else 2


## Containers deixam o arrasto chegar à rolagem; textos e imagens não seguram o toque.
func _let_drag_through(node: Control) -> void:
	if node is Label or node is TextureRect:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	elif node is Container or node.get_class() == "Control":
		node.mouse_filter = Control.MOUSE_FILTER_PASS
	for child: Node in node.get_children():
		if child is Control:
			_let_drag_through(child as Control)


func _refresh_quality() -> void:
	if _quality == null:
		return
	for i: int in _quality.item_count:
		var mode := String(_quality.get_item_metadata(i))
		_quality.set_item_text(i, GfxQuality.mode_label(mode))
		if mode == GfxQuality.mode():
			_quality.select(i)
	_preview.refresh()


## Prévia da qualidade: os três níveis (o que vale agora aceso), a descrição dele e o que
## muda: partículas, clima, brilho e efeitos de tela, em barras de 3.
class QualityPreview extends PanelContainer:
	var _levels: Array[Label] = []
	var _desc: Label
	var _bars: Array[Bars] = []

	func _init() -> void:
		add_theme_stylebox_override("panel", ThemeFactory.flat_box(Color(0.02, 0.01, 0.03, 0.7),
				Color(ThemeFactory.GOLD, 0.3), 1, 3, Vector2(8, 5)))
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 4)
		add_child(col)
		var levels := HBoxContainer.new()
		levels.add_theme_constant_override("separation", 4)
		for lvl: int in 3:
			var l := MenuKit.text(GfxQuality.level_name(lvl), 12, ThemeFactory.MUTED)
			l.name = "Level%d" % lvl
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.custom_minimum_size.y = 18
			levels.add_child(l)
			_levels.append(l)
		col.add_child(levels)
		_desc = MenuKit.text("", 12, ThemeFactory.TEXT)
		_desc.name = "Description"
		_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(_desc)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 1)
		var names := [TranslationServer.translate("options.gfx_feat_particles"),
				TranslationServer.translate("options.gfx_feat_weather"),
				TranslationServer.translate("options.gfx_feat_glow"),
				TranslationServer.translate("options.gfx_feat_effects")]
		for n: String in names:
			var cell := HBoxContainer.new()
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cell.add_theme_constant_override("separation", 4)
			var l := MenuKit.text(n, 12, ThemeFactory.MUTED)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			cell.add_child(l)
			var bars := Bars.new()
			cell.add_child(bars)
			_bars.append(bars)
			grid.add_child(cell)
		col.add_child(grid)
		mouse_filter = Control.MOUSE_FILTER_PASS

	func level_shown() -> int:
		return int(get_meta("level", -1))

	func refresh() -> void:
		var lvl := GfxQuality.level()
		set_meta("level", lvl)
		for i: int in 3:
			var on := i == lvl
			var l := _levels[i]
			l.add_theme_color_override("font_color", Color.WHITE if on else Color(ThemeFactory.MUTED, 0.6))
			l.add_theme_stylebox_override("normal", ThemeFactory.flat_box(Color("b8322a"), ThemeFactory.ACCENT, 1, 3,
					Vector2(4, 0)) if on else StyleBoxEmpty.new())
		var descs := [TranslationServer.translate("options.gfx_desc_low"),
				TranslationServer.translate("options.gfx_desc_medium"),
				TranslationServer.translate("options.gfx_desc_high")]
		_desc.text = descs[lvl]
		var values := [lvl + 1, int(GfxQuality.budget_at("weather_layers", lvl)),
				3 if bool(GfxQuality.budget_at("glow", lvl)) else 0,
				int(GfxQuality.budget_at("post_fx", lvl)) * 2 + int(bool(GfxQuality.budget_at("soft_shadows", lvl)))]
		for i: int in _bars.size():
			_bars[i].value = clampi(values[i], 0, 3)
			_bars[i].queue_redraw()


	## Três barrinhas crescentes (como sinal de celular).
	class Bars extends Control:
		var value := 0

		func _init() -> void:
			custom_minimum_size = Vector2(16, 14)
			mouse_filter = Control.MOUSE_FILTER_IGNORE

		func _draw() -> void:
			for i: int in 3:
				var hgt := 4 + i * 3
				var r := Rect2(i * 5 + 1, size.y - 2 - hgt, 3, hgt)
				draw_rect(r.grow(1), Color(0, 0, 0, 0.6))
				draw_rect(r, ThemeFactory.ACCENT if i < value else Color(0.25, 0.2, 0.22))
