class_name FloatingNotice
extends PanelContainer
## Aviso flutuante (toast) na base da tela, centrado na área segura (fora do furo da câmera):
## laca escura com borda dourada, texto que quebra em linhas, some sozinho com um esmaecer.
## Não recebe toque. Usado pela pausa (ex.: velocidade 2x/3x bloqueada sem a Ampulheta de Fūjin).

const MAX_WIDTH := 360.0
const MARGIN := 10.0
const TIME := 3.0
const FADE := 0.3

var label: Label
var _left: float = 0.0


func _init() -> void:
	name = "Notice"
	anchor_left = 0.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_top = -MARGIN
	offset_bottom = -MARGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.07, 0.03, 0.05, 0.95)
	box.border_color = ThemeFactory.ACCENT
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	box.anti_aliasing = false
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	box.shadow_color = Color(0, 0, 0, 0.45)
	box.shadow_size = 4
	add_theme_stylebox_override("panel", box)
	label = Label.new()
	label.name = "NoticeLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", ThemeFactory.ACCENT)
	add_child(label)


## Mostra o texto (de novo, mesmo que seja igual ao anterior) por TIME segundos.
func show_text(text: String) -> void:
	label.text = text
	_left = TIME
	modulate.a = 1.0
	visible = true


func hide_now() -> void:
	_left = 0.0
	visible = false


func is_open() -> bool:
	return visible and _left > 0.0


## Largura de até MAX_WIDTH, centrada entre os recortes (esquerda, direita) da tela de `width`.
func place(width: float, insets: Vector2) -> void:
	var safe_w := width - insets.x - insets.y
	var w := minf(MAX_WIDTH, safe_w - MARGIN * 2.0)
	var side := (safe_w - w) * 0.5
	offset_left = insets.x + side
	offset_right = -insets.y - side
	label.custom_minimum_size.x = w - 20.0


func _process(delta: float) -> void:
	if _left <= 0.0:
		return
	_left = maxf(0.0, _left - delta)
	modulate.a = clampf(_left / FADE, 0.0, 1.0)
	visible = _left > 0.0
