extends Control
## Cartão de recompensa: ícone, nome, selo (Novo / Nv / Evolução) e efeito. Usado pela tela do
## baú (scripts/ui/chest_panel.gd, como ChestPanel.RewardRow).

var reward: Dictionary = {}
var icon: Texture2D
var accent: Color = UiPaint.GOLD
var pill: String = ""
var special: bool = false
## 0 = vazio (encaixe esperando), 1 = item pousou.
var shown: float = 0.0
var flash: float = 0.0
var icon_scale: int = 1
var name_label: Label
var effect: RichTextLabel
var time: float = 0.0
## Texto do efeito sem BBCode e se precisou ser encurtado com "…".
var plain: String = ""
var shortened: bool = false

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	name_label = Label.new()
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_constant_override("line_spacing", -1)
	add_child(name_label)
	effect = RichTextLabel.new()
	effect.bbcode_enabled = true
	effect.scroll_active = false
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect.add_theme_constant_override("line_separation", -1)
	effect.add_theme_color_override("default_color", Color(0.86, 0.82, 0.78))
	add_child(effect)

## Lado do ícone desenhado: o nativo (24 px) em escala inteira, mais a folga do halo.
func icon_side() -> float:
	var native := 24.0 if icon == null else maxf(icon.get_width(), icon.get_height())
	return native * maxf(1.0, floorf(24.0 * icon_scale / native))

func icon_box() -> float:
	return icon_side() + 6.0

## Centro do ícone (alvo do voo), em coordenadas locais.
func icon_center() -> Vector2:
	return Vector2(4.0 + icon_box() * 0.5, size.y * 0.5).floor()

func layout_row(row_size: Vector2) -> void:
	size = row_size
	pivot_offset = row_size * 0.5
	icon_scale = 1
	var x := 4.0 + icon_box() + 6.0
	var pill_w := UiPaint.text_width(pill) + 10.0 if not pill.is_empty() else 0.0
	var lh := Locale.font.get_height(12) - 1.0
	# Nome que não cabe ao lado do selo (tela estreita com câmera, idioma longo) quebra
	# em duas linhas em vez de ganhar "…"; o efeito desce uma linha.
	var name_w := maxf(row_size.x - x - pill_w - 8.0, 10.0)
	var wrap := UiPaint.text_width(name_label.text) > name_w
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	var name_h := lh * (2.0 if wrap else 1.0)
	effect.size = Vector2(maxf(row_size.x - x - 4.0, 10.0), row_size.y)
	var need := float(effect.get_content_height()) if not effect.get_parsed_text().is_empty() else 0.0
	var room := row_size.y - 3.0 - name_h
	var effect_h := minf(need, room)
	var top := maxf(1.0, floorf((row_size.y - name_h - effect_h) * 0.5))
	name_label.position = Vector2(x, top - 1.0)
	name_label.size = Vector2(name_w, name_h + 1.0)
	effect.position = Vector2(x - 1.0, top + name_h)
	effect.size = Vector2(effect.size.x, maxf(row_size.y - 1.0 - effect.position.y, 4.0))
	# Último recurso: corta o efeito em palavras e termina com "…".
	var words := plain.split(" ", false)
	effect.text = UiPaint.highlight_numbers(plain)
	shortened = false
	while words.size() > 1 and not effect_fits():
		words.resize(words.size() - 1)
		effect.text = UiPaint.highlight_numbers(" ".join(words).trim_suffix(",").trim_suffix(";") + "…")
		shortened = true

## Linhas que o efeito precisa e as que cabem (testes de layout).
func effect_fits() -> bool:
	if effect.get_parsed_text().is_empty():
		return true
	return effect.position.y + effect.get_content_height() <= size.y

## Nome inteiro: numa linha, ou em até duas com cada palavra cabendo na largura.
func name_fits() -> bool:
	var w := name_label.size.x + 0.5
	if UiPaint.text_width(name_label.text) <= w:
		return true
	if name_label.autowrap_mode == TextServer.AUTOWRAP_OFF or name_label.get_line_count() > 2 \
			or name_label.get_visible_line_count() < name_label.get_line_count():
		return false
	for word: String in name_label.text.split(" ", false):
		if UiPaint.text_width(word) > w:
			return false
	return true

func _process(delta: float) -> void:
	time += delta
	if flash > 0.0:
		flash = maxf(0.0, flash - delta * 2.5)
	queue_redraw()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var k := clampf(shown, 0.0, 1.0)
	name_label.modulate.a = k
	effect.modulate.a = k
	if k <= 0.0:
		# Encaixe vazio: moldura tracejada esperando o item.
		draw_rect(r, Color(0, 0, 0, 0.25))
		for x: int in range(0, int(size.x), 6):
			draw_rect(Rect2(x, 0, 3, 1), Color(UiPaint.GOLD, 0.25))
			draw_rect(Rect2(x, size.y - 1.0, 3, 1), Color(UiPaint.GOLD, 0.25))
		var c := icon_center()
		draw_rect(Rect2(c - Vector2.ONE * icon_box() * 0.5, Vector2.ONE * icon_box()), Color(1, 1, 1, 0.05))
		return
	var top := Color(0.11, 0.07, 0.12, 0.95) if not special else Color(0.3, 0.2, 0.05, 0.96)
	UiPaint.vgradient(self, r, top, Color(0.03, 0.02, 0.05, 0.95))
	draw_rect(Rect2(0, 0, 3, size.y), accent)
	draw_rect(r, Color(0.05, 0.02, 0.02), false, 1.0)
	draw_rect(r.grow(-1.0), Color(accent, 0.6), false, 1.0)
	UiPaint.corners(self, r.grow(-1.0), Color(UiPaint.GOLD_HI, 0.8), 5.0)
	if special:
		var sweep := fmod(time * 0.7, 1.6) - 0.3
		var sx := sweep * size.x
		# Primitivas sem buffer próprio (Stroke), redesenhadas a cada quadro.
		Stroke.convex(self, PackedVector2Array([Vector2(sx, 1), Vector2(sx + 10, 1), Vector2(sx - 4, size.y - 1),
				Vector2(sx - 14, size.y - 1)]), Color(1, 1, 0.8, 0.12))
	var c := icon_center()
	var box := icon_box()
	draw_circle(c, box * 0.5 + 1.0, Color(accent, 0.18))
	Stroke.arc(self, c, box * 0.5 + 1.0, 0.0, TAU, 32, Color(accent, 0.6), 1.0)
	if icon:
		var native := icon.get_size()
		var s := native * (icon_side() / maxf(native.x, native.y))
		draw_texture_rect(icon, Rect2((c - s * 0.5).floor(), s), false)
	if not pill.is_empty():
		var w := UiPaint.text_width(pill) + 8.0
		var p := Rect2(size.x - w - 5.0, name_label.position.y + 1.0, w, Locale.font.get_height(12) - 1.0)
		draw_rect(p, accent.darkened(0.55))
		draw_rect(p, accent, false, 1.0)
		UiPaint.text(self, Vector2(p.position.x + 4.0, p.position.y + 10.0), pill, 12, accent.lerp(Color.WHITE, 0.6),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	if flash > 0.0:
		draw_rect(r, Color(1, 1, 0.9, 0.5 * flash))
		draw_rect(r.grow(1.0 + 3.0 * (1.0 - flash)), Color(accent, flash), false, 1.0)
