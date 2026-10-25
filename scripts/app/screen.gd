class_name Screen
extends Control
## Base das telas de menu (plano 7.3 e 7.4): uma ação por tela, botão primário sempre no
## canto inferior direito, botão "voltar" no canto superior esquerdo, alvos ≥ 48 dp.

var app: App


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)


## Chamada pelo App sempre que a tela aparece (para atualizar valores).
func on_show() -> void:
	pass


## Botão "voltar" do Android ou Esc.
func on_back() -> void:
	app.go(&"title")


func title_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", ThemeFactory.ACCENT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func label(text: String, size: int = 12, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	if size != 12:
		l.add_theme_font_size_override("font_size", size)
	return l


func wrap_label(text: String, width: float) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	return l


func button(text: String, on_press: Callable, min_size: Vector2 = Vector2(150, 30)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func() -> void: AudioManager.play_ui("ui_accept"))
	# Callable() vazio: quem chama conecta a ação depois (ex.: confirmação em dois toques).
	if on_press.is_valid():
		b.pressed.connect(on_press)
	return b


## "Voltar" único das telas (MenuKit.BackButton): placa de laca com medalhão e seta, alvo de
## toque de BACK_HEIGHT (≥ 48 dp), som de voltar e anel dourado ao tocar. Mesma ação do
## botão "voltar" do Android e do Esc (on_back).
func back_button() -> Button:
	var b := MenuKit.BackButton.new(tr("menu.back"))
	b.pressed.connect(on_back)
	b.position = Vector2(4, 2)
	b.size = b.get_combined_minimum_size()
	# Os painéis de tela cheia adicionados depois cobririam o botão e engoliriam o toque.
	b.tree_entered.connect(b.move_to_front, CONNECT_DEFERRED | CONNECT_ONE_SHOT)
	return b


func icon_rect(path: String, size: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	if ResourceLoader.exists(path):
		rect.texture = load(path)
	rect.custom_minimum_size = size
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return rect


func panel() -> PanelContainer:
	return PanelContainer.new()


## Área de conteúdo com margem abaixo do botão "voltar".
func content_box(top: float = 40.0) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", int(top))
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)
	return margin


static func format_time(seconds: float) -> String:
	var s := floori(seconds)
	return "%02d:%02d" % [floori(s / 60.0), s % 60]
