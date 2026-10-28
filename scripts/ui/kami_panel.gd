class_name KamiPanel
extends Control
## "UM KAMI OFERECE UM PACTO" (plano 2.1 e 4.9), sobre a luta parada, no clima de um santuário:
## - fundo: o mundo recua (OverlayFx: desfoque, vinheta e raios), um torii de vermelhão surge
##   atrás das placas, fumaça de incenso sobe do chão e pétalas de cerejeira caem no vento;
## - cada Kami é uma placa votiva (ema) de laca pendurada num cordão vermelho e branco: o telhado
##   pintado na cor do Kami, o ícone num medalhão com raios, o nome em kanji numa tira de ofuda,
##   o nome, o domínio ("Arroz e prosperidade"), a BÊNÇÃO (verde, 恵) e o PREÇO (vermelho, 代);
## - entrada: o título desce com o selo 契, o sino de vento toca e as placas caem uma a uma no
##   cordão, balançando até parar (cada uma com o estalo da madeira);
## - escolha em dois passos: tocar uma placa a destaca (sobe, aro na cor do Kami, as outras
##   escurecem, os raios tomam a cor dela); tocar de novo ou "Selar o pacto" confirma: o selo 契
##   carimba a placa com o taiko, as outras sobem com o vento, e o ícone voa até a guardiã
##   (`claimed` -> RewardFlight da HUD). "Ignorar o santuário" recusa (as placas voam no vento);
## - bloqueio contra toque acidental (LOCK_MS depois de abrir e só com a placa já parada).
## GfxQuality "ui_fx": 0 = placas paradas, sem fumaça, poucas pétalas; 1 = sem balanço ocioso;
## 2 = completo. Tempo real: igual em 1x, 2x e 3x. Cabe em toda resolução de
## tests/device_profiles.gd, com o furo da câmera dos dois lados, nos 11 idiomas
## (tests/hud_layout_tests.gd). Quem aplica o pacto é o HyakkiGame: a tela só emite `chosen`.

## Pacto selado (`id`) ou recusado (&"").
signal chosen(id: StringName)
## O ícone do Kami escolhido, pronto para o voo até a guardiã (ver RewardFlight.launch).
signal claimed(items: Array[Dictionary])

const MARGIN := 8.0
const GAP := 8.0
const HEADER_H := 44.0
## Linhas de base do título (fonte 24 ou 12) e do subtítulo no cabeçalho.
const TITLE_BASE := 22.0
const TITLE_BASE_SMALL := 16.0
const SUB_BASE := 42.0
const FOOTER_H := 26.0
## Cordão acima de cada placa (de onde ela pende).
const CORD := 9.0
const CARD_MIN_W := 104.0
const CARD_MAX_W := 168.0
const CARD_MAX_H := 216.0
const BUTTON_GAP := 10.0
const LOCK_MS := 350
## Entrada, queda de cada placa, intervalo entre elas, carimbo e saída (segundos).
const FADE_IN := 0.3
const DEAL_DELAY := 0.16
const DEAL_STEP := 0.11
const DEAL_TIME := 0.42
const STAMP_TIME := 0.36
const OUTRO := 0.45
const PETALS := [6, 14, 26]
const SMOKE := [0, 4, 7]
const TORII := Color("c23b22")
const PETAL := Color("ffc4d6")
const SEAL_KANJI := "契"
## Arranjos das placas, do mais rico ao mais compacto: [escala do ícone, legendas].
const MODES := [[2, true], [1, true], [1, false]]


## Placa votiva (ema) de um Kami: desenho próprio; nome, domínio, bênção e preço em Labels.
class KamiCard:
	extends Button

	const ROOF := 9.0
	const PAD := 7.0
	const BLESS := Color("9fe0a8")
	const COST := Color("ff8f7a")
	const BLESS_SEAL := "恵"
	const COST_SEAL := "代"
	const SEAL := 11.0
	const PACT := "契"
	const CORD_H := 9.0

	var id: StringName = &""
	var color: Color = Color.WHITE
	var kanji: String = ""
	var settled: bool = false
	var selected: bool = false
	var dimmed: bool = false
	## 0..1: o selo 契 caindo na placa (pacto selado).
	var stamp: float = 0.0
	## Balanço no cordão: amplitude (rad) e o tempo desde o empurrão.
	var swing: float = 0.0
	var swing_t: float = 0.0
	var base_position: Vector2 = Vector2.ZERO
	var fx_level: int = 2
	var order: int = 0

	var _icon: Texture2D
	var _icon_scale: int = 2
	var _medal_c := Vector2.ZERO
	var _medal_r: float = 16.0
	var _captions: bool = true
	var _bless_y: float = 0.0
	var _cost_y: float = 0.0
	var _content_end: float = 0.0
	var _bless_lines: PackedStringArray = []
	var _cost_lines: PackedStringArray = []
	## Textos em RichTextLabel (um Label com quebra de linha guarda a altura da largura antiga).
	var _name: RichTextLabel
	var _domain: RichTextLabel
	var _bless: RichTextLabel
	var _cost: RichTextLabel
	var _bless_caption: RichTextLabel
	var _cost_caption: RichTextLabel
	var _lift: float = 0.0
	var _time: float = 0.0

	func _init() -> void:
		text = ""
		flat = true
		focus_mode = Control.FOCUS_NONE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		_name = _rich()
		_domain = _rich()
		_domain.add_theme_color_override("default_color", UiPaint.DIM)
		_bless_caption = _rich()
		_bless_caption.add_theme_color_override("default_color", BLESS)
		_cost_caption = _rich()
		_cost_caption.add_theme_color_override("default_color", COST)
		_bless = _rich()
		_cost = _rich()

	func _rich() -> RichTextLabel:
		var r := RichTextLabel.new()
		r.bbcode_enabled = true
		r.scroll_active = false
		r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.add_theme_constant_override("line_separation", -1)
		add_child(r)
		return r

	## Preenche a placa com o Kami `kami_id` (DB.kami).
	func setup(kami_id: StringName) -> void:
		id = kami_id
		var data: Dictionary = DB.kami[kami_id]
		color = Color(String(data.get("color", "#ffd166")))
		kanji = String(data.get("kanji", ""))
		var path := String(data.get("icon", ""))
		_icon = load(path) as Texture2D if not path.is_empty() and ResourceLoader.exists(path) else null
		_set_text(_name, tr("kami.%s.name" % kami_id), true)
		_name.add_theme_color_override("default_color", color.lerp(Color.WHITE, 0.45))
		_set_text(_domain, tr("kami.%s.domain" % kami_id), true)
		_bless_lines = KamiPanel.blessing_lines(kami_id)
		_cost_lines = KamiPanel.cost_lines(kami_id)
		var bless_text := UiPaint.highlight_numbers("\n".join(_bless_lines), BLESS.lerp(Color.WHITE, 0.25))
		_bless.text = "[center]%s[/center]" % bless_text
		_bless.add_theme_color_override("default_color", BLESS)
		var cost_text := UiPaint.highlight_numbers("\n".join(_cost_lines), COST.lerp(Color.WHITE, 0.25))
		_cost.text = "[center]%s[/center]" % cost_text
		_cost.add_theme_color_override("default_color", COST)
		_set_text(_bless_caption, tr("kami.blessing"), false)
		_set_text(_cost_caption, tr("kami.price"), false)
		selected = false
		dimmed = false
		stamp = 0.0
		settled = false
		_lift = 0.0
		queue_redraw()

	func icon_texture() -> Texture2D:
		return _icon

	func icon_scale() -> int:
		return _icon_scale

	## Centro do medalhão (de onde sai o voo), em coordenadas locais.
	func medal_center() -> Vector2:
		return _medal_c

	func captions_shown() -> bool:
		return _captions

	## Nome do Kami como aparece na placa (sem as marcas de formatação).
	func name_text() -> String:
		return _name.get_parsed_text()

	func _set_text(rich: RichTextLabel, value: String, centered: bool) -> void:
		var safe := value.replace("[", "[lb]")
		rich.text = "[center]%s[/center]" % safe if centered else safe

	## Textos da placa (testes de layout: cada um inteiro dentro dela, sem sobrepor).
	func text_controls() -> Array[Control]:
		var list: Array[Control] = [_name, _domain, _bless, _cost]
		if _captions:
			list.append_array([_bless_caption, _cost_caption])
		return list

	## Arranja a placa no tamanho dado, com o ícone em escala `icon_scale_wanted` e as legendas
	## "Bênção"/"Preço" (ou só os selos 恵 e 代 na margem); true se tudo coube. A tela escolhe o
	## mesmo arranjo para todas as placas (KamiPanel.MODES).
	func layout_content(card_size: Vector2, icon_scale_wanted: int = 2, captions: bool = true) -> bool:
		size = card_size
		pivot_offset = Vector2(floorf(card_size.x * 0.5), -CORD_H)
		return _try_layout(card_size, icon_scale_wanted, captions)

	## Altura que o conteúdo ocupa no arranjo atual (do topo ao fim do preço, com a folga de baixo).
	func content_height() -> float:
		return _content_end + 6.0

	func _line_h() -> float:
		return Locale.font.get_height(12) - 1.0

	func _place(control: Control, at: Vector2, wanted: Vector2) -> void:
		control.position = at
		control.size = wanted

	func _lines(value: String, width: float) -> int:
		if value.is_empty():
			return 0
		var total := 0
		for line: String in value.split("\n"):
			var h := Locale.font.get_multiline_string_size(line, HORIZONTAL_ALIGNMENT_CENTER, width, 12).y
			total += maxi(1, roundi(h / Locale.font.get_height(12)))
		return total

	func _try_layout(s: Vector2, scale: int, captions: bool) -> bool:
		_icon_scale = scale
		_captions = captions
		var inner := s.x - PAD * 2.0
		var native := 24.0 if _icon == null else maxf(_icon.get_width(), _icon.get_height())
		var box := native * scale
		_medal_r = floorf(box * 0.5) + 4.0
		var y := ROOF + 4.0
		_medal_c = Vector2(floorf(s.x * 0.5), y + _medal_r)
		y += _medal_r * 2.0 + 3.0
		var lh := _line_h()
		var name_n := clampi(_lines(_name.get_parsed_text(), inner), 1, 2)
		_place(_name, Vector2(PAD, y - 1.0), Vector2(inner, name_n * lh + 2.0))
		y += name_n * lh + 1.0
		var domain_n := clampi(_lines(_domain.get_parsed_text(), inner), 1, 2)
		_place(_domain, Vector2(PAD, y - 1.0), Vector2(inner, domain_n * lh + 2.0))
		y += domain_n * lh + 7.0
		# Sem legendas, os selos 恵 e 代 viram abas na borda esquerda da placa (meio para fora) e o
		# texto quase não perde largura.
		var gutter := 0.0 if captions else 2.0
		var text_w := inner - gutter
		_bless_caption.visible = captions
		_cost_caption.visible = captions
		_bless_y = y
		if captions:
			_place(_bless_caption, Vector2(PAD + SEAL + 5.0, y - 1.0), Vector2(inner - SEAL - 5.0, lh + 2.0))
			y += lh + 1.0
		var bless_n := _lines("\n".join(_bless_lines), text_w)
		_place(_bless, Vector2(PAD + gutter - 1.0, y), Vector2(text_w + 2.0, bless_n * lh + 3.0))
		y += bless_n * lh + 5.0
		_cost_y = y
		if captions:
			_place(_cost_caption, Vector2(PAD + SEAL + 5.0, y - 1.0), Vector2(inner - SEAL - 5.0, lh + 2.0))
			y += lh + 1.0
		var cost_n := _lines("\n".join(_cost_lines), text_w)
		_place(_cost, Vector2(PAD + gutter - 1.0, y), Vector2(text_w + 2.0, cost_n * lh + 3.0))
		y += cost_n * lh + 3.0
		_content_end = y
		return y <= s.y - 4.0 and UiPaint.text_width(_bless_caption.get_parsed_text()) <= inner - SEAL - 5.0 \
				and UiPaint.text_width(_cost_caption.get_parsed_text()) <= inner - SEAL - 5.0

	## Todo o texto cabe na placa (nome e domínio em até 2 linhas, bênção e preço inteiros).
	func fits() -> bool:
		for control: Control in text_controls():
			if not Rect2(Vector2.ZERO, size).grow(0.5).encloses(Rect2(control.position, control.size)):
				return false
		for label: RichTextLabel in [_name, _domain]:
			var plain := label.get_parsed_text()
			if _lines(plain, label.size.x) > 2:
				return false
			for word: String in plain.split(" ", false):
				if UiPaint.text_width(word) > label.size.x + 0.5:
					return false
		return _cost.position.y + _cost.size.y <= size.y - 2.0

	func _process(delta: float) -> void:
		_time += delta
		var hot := settled and not disabled and (selected or get_draw_mode() != DRAW_NORMAL)
		_lift = move_toward(_lift, 1.0 if hot else 0.0, delta * 8.0)
		swing_t += delta
		var sway := swing * exp(-swing_t * 2.6) * sin(swing_t * 8.5)
		if fx_level >= 2 and settled:
			sway += 0.008 * sin(_time * 1.3 + order * 1.7)
		# Fora do lugar (entrando ou saindo), quem anima é o tween da tela.
		if settled:
			rotation = sway if fx_level > 0 else 0.0
			position = base_position - Vector2(0.0, roundf(5.0 * _lift))
			scale = Vector2.ONE * (1.0 + 0.03 * _lift)
			modulate = Color(0.55, 0.52, 0.58, modulate.a) if dimmed else Color(1, 1, 1, modulate.a)
		queue_redraw()

	## Empurrão no cordão (entrada, seleção).
	func nudge(amount: float) -> void:
		swing = amount
		swing_t = 0.0

	func _draw() -> void:
		var s := size
		var w := s.x
		var h := s.y
		_draw_cord(w)
		var outline := PackedVector2Array([Vector2(0, ROOF), Vector2(ROOF, 0), Vector2(w - ROOF, 0), Vector2(w, ROOF),
				Vector2(w, h), Vector2(0, h)])
		# Aro de seleção (fora da placa) na cor do Kami, respirando.
		if selected:
			var pulse := 0.6 + 0.4 * sin(_time * 5.0) if fx_level > 0 else 1.0
			_poly_outline(_grow_shape(w, h, 2.0), Color(color.lerp(Color.WHITE, 0.3), pulse), 2.0)
			_poly_outline(_grow_shape(w, h, 4.0), Color(color, 0.35 * pulse), 1.0)
		# Corpo de laca com veios de madeira.
		draw_colored_polygon(outline, Color(0.13, 0.075, 0.07, 0.97))
		UiPaint.vgradient(self, Rect2(1, ROOF, w - 2.0, h - ROOF - 1.0), Color(0.2, 0.12, 0.09, 0.0),
				Color(0.03, 0.02, 0.04, 0.75))
		for gy: int in range(int(ROOF) + 6, int(h) - 4, 7):
			var wobble := sin(gy * 0.37 + order) * 3.0
			draw_line(Vector2(4, gy), Vector2(w - 4.0, gy + wobble * 0.3), Color(0.35, 0.2, 0.12, 0.08), 1.0)
		# Telhado pintado na cor do Kami, com o furo do cordão.
		var roof := PackedVector2Array([Vector2(0, ROOF), Vector2(ROOF, 0), Vector2(w - ROOF, 0), Vector2(w, ROOF),
				Vector2(w, ROOF + 3.0), Vector2(0, ROOF + 3.0)])
		draw_colored_polygon(roof, color.darkened(0.45))
		draw_line(Vector2(1, ROOF + 3.0), Vector2(w - 1.0, ROOF + 3.0), Color(UiPaint.GOLD, 0.8), 1.0)
		draw_circle(Vector2(floorf(w * 0.5), 4.0), 1.5, Color(0.03, 0.01, 0.02))
		# Bordas: escura por fora, filete dourado tingido por dentro, cantoneiras embaixo.
		_poly_outline(outline, Color(0.04, 0.015, 0.02), 1.0)
		_poly_outline(_grow_shape(w, h, -2.0), Color(UiPaint.GOLD.lerp(color, 0.35), 0.55), 1.0)
		var foot := Rect2(2, h - 12.0, w - 4.0, 10.0)
		UiPaint.corners(self, foot, Color(UiPaint.GOLD_HI, 0.7), 5.0)
		_draw_medal()
		_draw_ofuda()
		_draw_blocks(w)
		if stamp > 0.0:
			var k := clampf(stamp, 0.0, 1.0)
			# O selo cai grande e assenta sobre o medalhão (o carimbo do pacto).
			var side := roundf(lerpf(48.0, 24.0, 1.0 - pow(1.0 - k, 3.0)))
			UiPaint.seal(self, _medal_c, PACT, side, Color(UiPaint.SEAL_RED, 0.95), UiPaint.SEAL_TEXT, -0.18, k)

	## Cordão trançado vermelho e branco do topo da placa até o prego, com o nó.
	func _draw_cord(w: float) -> void:
		var x := floorf(w * 0.5)
		for i: int in range(int(CORD_H) + 4):
			var c := Color("d33a2c") if (i / 2) % 2 == 0 else Color("f4e9dc")
			draw_rect(Rect2(x - (0.0 if i % 2 == 0 else 1.0), 4.0 - i, 1, 1), c)
			draw_rect(Rect2(x + (1.0 if i % 2 == 0 else 0.0), 4.0 - i, 1, 1), c.darkened(0.25))
		draw_circle(Vector2(x + 0.5, -CORD_H), 2.0, Color("b3261e"))
		draw_rect(Rect2(x, -CORD_H - 1.0, 1, 1), Color(1, 0.9, 0.85))

	func _draw_medal() -> void:
		var c := _medal_c
		var r := _medal_r
		if fx_level >= 1:
			# Raios girando devagar atrás do medalhão.
			var count := 10
			for i: int in range(count):
				var a := TAU * i / count + _time * 0.35
				var tip := c + Vector2.from_angle(a) * (r + 9.0 + 2.0 * sin(_time * 2.0 + i))
				draw_colored_polygon(PackedVector2Array([c + Vector2.from_angle(a - 0.14) * r, tip,
						c + Vector2.from_angle(a + 0.14) * r]), Color(color, 0.16 + (0.1 if selected else 0.0)))
			draw_texture_rect(MenuKit.glow_texture(), Rect2(c - Vector2.ONE * r * 1.6, Vector2.ONE * r * 3.2), false,
					Color(color, 0.32))
		draw_circle(c, r, Color(0.05, 0.03, 0.06))
		draw_circle(c, r - 1.0, Color(color.darkened(0.7), 0.95))
		draw_arc(c, r, 0.0, TAU, 32, Color(UiPaint.GOLD, 0.9), 1.0)
		draw_arc(c, r - 2.0, 0.0, TAU, 32, Color(color, 0.7), 1.0)
		if _icon != null:
			var shown := _icon.get_size() * _icon_scale
			draw_texture_rect(_icon, Rect2((c - shown * 0.5).floor(), shown), false)

	## Kanji do nome numa tira de ofuda (papel com tinta vermelha), em colunas verticais da direita
	## para a esquerda, ao lado do medalhão.
	func _draw_ofuda() -> void:
		if kanji.is_empty():
			return
		var font := UiPaint.ja_font()
		var chars := kanji.length()
		var rows := clampi(floori((_medal_r * 2.0 - 4.0) / 12.0), 1, 4)
		var cols := ceili(float(chars) / rows)
		var strip := Vector2(cols * 12.0 + 3.0, mini(rows, chars) * 12.0 + 5.0)
		var at := Vector2(size.x - PAD - strip.x, ROOF + 6.0).floor()
		if at.x < _medal_c.x + _medal_r + 2.0:
			return
		draw_rect(Rect2(at + Vector2(1, 1), strip), Color(0, 0, 0, 0.4))
		draw_rect(Rect2(at, strip), Color("efe2c4"))
		draw_rect(Rect2(at, strip), Color("b89a6a"), false, 1.0)
		for i: int in range(chars):
			var col := floori(float(i) / rows)
			var row := i % rows
			var x := at.x + strip.x - 2.0 - (col + 1) * 12.0
			var y := at.y + 3.0 + row * 12.0 + font.get_ascent(12)
			draw_string(font, Vector2(x, y).round(), kanji[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("a3241a"))

	## Blocos da bênção e do preço: selos 恵 e 代 (com a legenda, quando cabe) e um fio entre eles.
	func _draw_blocks(w: float) -> void:
		var lh := _line_h()
		var seal_x := PAD + SEAL * 0.5 if _captions else 3.0
		var bless_seal := Vector2(seal_x, _bless_y + floorf(lh * 0.5))
		var cost_seal := Vector2(seal_x, _cost_y + floorf(lh * 0.5))
		UiPaint.seal(self, bless_seal, BLESS_SEAL, SEAL, Color("2f6b45"), Color("e9ffe9"))
		UiPaint.seal(self, cost_seal, COST_SEAL, SEAL, UiPaint.SEAL_RED, UiPaint.SEAL_TEXT)
		# Fio tracejado separando o que se ganha do que se paga.
		var y := floorf(_cost_y - 3.0)
		for x: int in range(int(PAD) + 14, int(w - PAD), 4):
			draw_rect(Rect2(x, y, 2, 1), Color(COST, 0.35))
		UiPaint.ornament(self, Vector2(w * 0.5, _bless_y - 4.0), minf(w * 0.28, 40.0), 0.7)

	func _grow_shape(w: float, h: float, by: float) -> PackedVector2Array:
		return PackedVector2Array([Vector2(-by, ROOF), Vector2(ROOF - by * 0.4, -by), Vector2(w - ROOF + by * 0.4, -by),
				Vector2(w + by, ROOF), Vector2(w + by, h + by), Vector2(-by, h + by)])

	func _poly_outline(points: PackedVector2Array, c: Color, width: float) -> void:
		var closed := points.duplicate()
		closed.append(points[0])
		draw_polyline(closed, c, width)


var _open: bool = false
var _busy: bool = false
var _opened_at: int = 0
var _selected: int = -1
var _offer: Array[StringName] = []
var _cards: Array[KamiCard] = []
var _fx_level: int = 2
var _intro: float = 0.0
var _tweens: Array[Tween] = []
var _time: float = 0.0
var _rng := RandomNumberGenerator.new()
## Pétalas: x, y, giro; e a velocidade/fase de cada uma.
var _petals: Array[Vector4] = []
## Fumaça de incenso: (x de origem, fase, velocidade).
var _smoke: Array[Vector3] = []

var _fx: OverlayFx
var _backdrop: Control
var _header: Control
var _row: Control
var _decline: Button
var _confirm: Button
var _row_rect := Rect2()
var _mode: Array = MODES[0]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_rng.seed = 37
	_fx = OverlayFx.new()
	_fx.ray_color = Color(1.0, 0.86, 0.55)
	add_child(_fx)
	_backdrop = Control.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.draw.connect(_draw_backdrop)
	add_child(_backdrop)
	_header = Control.new()
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header.draw.connect(_draw_header)
	add_child(_header)
	_row = Control.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_row)
	_decline = _button(func() -> void: decline())
	_decline.name = "KamiDecline"
	ThemeFactory.apply_button_boxes(_decline, ThemeFactory.lacquer_button_boxes())
	_decline.add_theme_color_override("font_color", UiPaint.DIM)
	_confirm = _button(func() -> void: confirm())
	_confirm.name = "KamiConfirm"
	ThemeFactory.apply_button_boxes(_confirm, ThemeFactory.primary_button_boxes())
	_confirm.add_theme_color_override("font_color", UiPaint.PAPER)
	_confirm.add_theme_color_override("font_disabled_color", Color(UiPaint.DIM, 0.55))
	resized.connect(_layout)
	# Furo da câmera que troca de lado com a tela aberta (giro de 180°).
	MenuKit.on_insets_change(self, _layout)
	Settings.changed.connect(func(key: String) -> void:
		if key == GfxQuality.changed_signal_key():
			_apply_quality())
	_apply_quality()


# --- Regras (também usadas pelo Códex e pelos testes) -------------------------------------

## Linhas da bênção: cada atributo; o especial só quando não há atributo (senão repete o mesmo
## efeito em outras palavras, como em Hachiman e Bishamonten).
static func blessing_lines(id: StringName) -> PackedStringArray:
	var data: Dictionary = DB.kami[id]
	var lines: PackedStringArray = []
	var blessing: Dictionary = data.get("blessing", {})
	for stat: String in blessing:
		lines.append(LevelUpSystem.describe_stats({stat: blessing[stat]}))
	if lines.is_empty() and data.has("special"):
		lines.append(TranslationServer.translate("kami.%s.special" % id))
	return lines


## Linhas do preço: cada atributo que cai; sem atributo, o custo especial (sem renascer, sem
## regeneração).
static func cost_lines(id: StringName) -> PackedStringArray:
	var data: Dictionary = DB.kami[id]
	var lines: PackedStringArray = []
	var cost: Dictionary = data.get("cost", {})
	for stat: String in cost:
		lines.append(LevelUpSystem.describe_stats({stat: cost[stat]}))
	if lines.is_empty():
		lines.append(TranslationServer.translate("kami.%s.cost" % id))
	return lines


# --- API ---------------------------------------------------------------------------------

## Abre com as placas de `offer` (1 a 3 Kami).
func open(offer: Array[StringName]) -> void:
	_kill_tweens()
	_offer = offer.duplicate()
	_open = true
	_busy = false
	_selected = -1
	_opened_at = Time.get_ticks_msec()
	visible = true
	modulate.a = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_quality()
	for card: KamiCard in _cards:
		card.queue_free()
	_cards.clear()
	for i: int in range(_offer.size()):
		var card := KamiCard.new()
		card.order = i
		card.setup(_offer[i])
		card.pressed.connect(_on_card.bind(i))
		card.mouse_entered.connect(func() -> void:
			if card.settled and _open and not _busy:
				AudioManager.play("ui_move", 1.0 + 0.05 * i, 0.0, -9.0))
		_row.add_child(card)
		_cards.append(card)
	_decline.text = tr("kami.ignore")
	_confirm.text = tr("kami.seal")
	_decline.modulate.a = 1.0
	_confirm.modulate.a = 1.0
	_sync_buttons()
	_layout()
	_seed_ambience()
	_fx.power = 0.0
	_fx.rays = 0.0
	_fx.ray_color = Color(1.0, 0.86, 0.55)
	_intro = 0.0
	var t := _tween()
	t.tween_property(_fx, "power", 1.0, FADE_IN)
	t.parallel().tween_property(_fx, "rays", 0.8, FADE_IN * 2.0)
	t.parallel().tween_property(self, "_intro", 1.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_fx.flash_color = Color(1.0, 0.9, 0.7)
	_fx.flash = 0.35
	AudioManager.play("j_furin", 1.0, 0.0, -4.0)
	AudioManager.play("magic2", 0.9, 0.0, -12.0)
	_deal()


## Fecha na hora, sem animação nem sinal (bot, nova partida).
func close_now() -> void:
	_kill_tweens()
	_open = false
	_busy = false
	_selected = -1
	_fx.power = 0.0
	visible = false


func is_open() -> bool:
	return _open


## A saída (placas voando, fundo sumindo) ainda está tocando.
func outro_playing() -> bool:
	return not _open and visible


func cards() -> Array[KamiCard]:
	return _cards


func offer() -> Array[StringName]:
	return _offer


func selected() -> int:
	return _selected


func confirm_button() -> Button:
	return _confirm


func decline_button() -> Button:
	return _decline


func overlay() -> OverlayFx:
	return _fx


func fx_level() -> int:
	return _fx_level


## Pula a entrada: placas paradas no lugar, título e botões à vista (testes de layout).
func finish_intro() -> void:
	_kill_tweens()
	_fx.power = 1.0
	_fx.rays = 0.8
	_intro = 1.0
	_decline.modulate.a = 1.0
	_confirm.modulate.a = 1.0
	for card: KamiCard in _cards:
		card.modulate.a = 1.0
		card.position = card.base_position
		card.settled = true


func petal_count() -> int:
	return _petals.size()


func smoke_count() -> int:
	return _smoke.size()


## Arranjo atual das placas: [escala do ícone, legendas] (testes de layout).
func layout_mode() -> Array:
	return _mode


## Faixa das placas (testes de layout).
func row_rect() -> Rect2:
	return _row_rect


func title_text() -> String:
	return tr("kami.title")


func subtitle_text() -> String:
	if _selected >= 0 and _selected < _offer.size():
		return tr("kami.%s.name" % _offer[_selected]) + " · " + tr("kami.%s.domain" % _offer[_selected])
	return tr("kami.subtitle")


## Fonte do título: 24 se couber na área segura, senão 12.
func title_size() -> int:
	var room := size.x - MenuKit.safe_insets(self).x - MenuKit.safe_insets(self).y - MARGIN * 2.0
	return 24 if UiPaint.text_width(title_text(), 24) + 26.0 <= room else 12


## Retângulos do selo + título e do subtítulo, no espaço da tela (testes de layout).
func header_rects() -> Array[Rect2]:
	var big := title_size() == 24
	var title_w := UiPaint.text_width(title_text(), title_size()) + (26.0 if big else 20.0)
	var sub_w := UiPaint.text_width(subtitle_text())
	var font := Locale.font
	var cx := _safe_center_x()
	var top := _header.position.y
	var base := TITLE_BASE if big else TITLE_BASE_SMALL
	return [Rect2(floorf(cx - title_w * 0.5), top + base - font.get_ascent(title_size()), title_w,
			font.get_height(title_size())),
			Rect2(floorf(cx - sub_w * 0.5), top + SUB_BASE - font.get_ascent(12), sub_w, font.get_height(12))]


## Destaca a placa `index` (primeiro toque).
func select(index: int) -> void:
	if index < 0 or index >= _cards.size() or _busy:
		return
	if _selected == index:
		return
	_selected = index
	for i: int in range(_cards.size()):
		_cards[i].selected = i == index
		_cards[i].dimmed = i != index
	var card := _cards[index]
	card.nudge(0.07)
	var t := _tween()
	t.tween_property(_fx, "ray_color", card.color.lerp(Color.WHITE, 0.25), 0.3)
	AudioManager.play("j_koto", [1.0, 1.122, 1.335][index % 3], 0.0, -5.0)
	AudioManager.play("paper_fold", 1.1, 0.0, -10.0)
	_sync_buttons()
	_header.queue_redraw()


## Sela o pacto com a placa destacada: carimbo, as outras voam, o ícone segue para a guardiã.
func confirm() -> void:
	if not _accepting() or _selected < 0:
		return
	_busy = true
	var index := _selected
	var card := _cards[index]
	var id := card.id
	_sync_buttons()
	AudioManager.play_ui("ui_confirm")
	var t := _tween()
	t.tween_property(card, "stamp", 1.0, STAMP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_callback(func() -> void:
		AudioManager.play("j_taiko_rim", 0.85, 0.0, -2.0)
		AudioManager.play("paper_fold", 0.7, 0.0, -4.0)
		card.nudge(0.12)).set_delay(STAMP_TIME * 0.85)
	t.tween_interval(0.14)
	t.tween_callback(func() -> void:
		var item := {"from": card.get_global_transform_with_canvas() * card.medal_center(), "icon": card.icon_texture(),
				"color": card.color, "scale": float(card.icon_scale()), "key": ""}
		_leave(index)
		var items: Array[Dictionary] = [item]
		claimed.emit(items)
		chosen.emit(id))


## Recusa: as placas voam com o vento e a luta volta.
func decline() -> void:
	if not _open or _busy:
		return
	_busy = true
	AudioManager.play("paper_flutter", 1.0, 0.05, -4.0)
	_leave(-1)
	chosen.emit(&"")


## Bot de testes: aceita o primeiro Kami na hora, sem animação nem voo.
func bot_choose() -> StringName:
	var id: StringName = _offer[0] if not _offer.is_empty() else &""
	close_now()
	return id


# --- Toque -------------------------------------------------------------------------------

func _accepting() -> bool:
	return _open and not _busy and Time.get_ticks_msec() - _opened_at >= LOCK_MS


func _on_card(index: int) -> void:
	if not _accepting() or not _cards[index].settled:
		return
	if _selected == index:
		confirm()
	else:
		select(index)


func _sync_buttons() -> void:
	_confirm.disabled = _selected < 0 or _busy
	_decline.disabled = _busy


# --- Entrada e saída ---------------------------------------------------------------------

## Placas caem do alto, uma a uma, penduradas no cordão; ao parar, balançam até sossegar.
func _deal() -> void:
	for i: int in range(_cards.size()):
		var card := _cards[i]
		card.settled = false
		card.position = card.base_position - Vector2(0.0, card.base_position.y + card.size.y + CORD + 12.0)
		card.modulate.a = 0.0
		var t := _tween()
		t.tween_interval(DEAL_DELAY + DEAL_STEP * i)
		t.tween_callback(func() -> void: AudioManager.play("paper_flutter", 1.05 + 0.06 * i, 0.03, -9.0))
		t.tween_property(card, "position", card.base_position, DEAL_TIME).set_trans(Tween.TRANS_BACK) \
				.set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(card, "modulate:a", 1.0, DEAL_TIME * 0.4)
		t.tween_callback(func() -> void:
			card.settled = true
			card.nudge(0.09 if i % 2 == 0 else -0.09)
			AudioManager.play("bow", 1.4 + 0.08 * i, 0.03, -10.0))
	_decline.modulate.a = 0.0
	_confirm.modulate.a = 0.0
	var b := _tween()
	b.tween_interval(DEAL_DELAY + DEAL_STEP * _cards.size())
	b.tween_property(_decline, "modulate:a", 1.0, 0.2)
	b.parallel().tween_property(_confirm, "modulate:a", 1.0, 0.2)


## Saída: as placas (menos a escolhida, que some num lampejo) sobem com o vento e o fundo se
## desfaz. A tela deixa de contar como aberta na hora (a luta volta já).
func _leave(chosen_index: int) -> void:
	_open = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i: int in range(_cards.size()):
		var card := _cards[i]
		card.settled = false
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var t := _tween()
		if i == chosen_index:
			t.tween_property(card, "modulate", Color(2.0, 2.0, 1.7, 0.0), OUTRO * 0.6)
			t.parallel().tween_property(card, "scale", Vector2.ONE * 1.12, OUTRO * 0.6)
		else:
			var side := -1.0 if i < maxi(chosen_index, 1) else 1.0
			t.tween_property(card, "position", card.position + Vector2(side * 30.0, -60.0), OUTRO) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			t.parallel().tween_property(card, "rotation", 0.4 * side, OUTRO)
			t.parallel().tween_property(card, "modulate:a", 0.0, OUTRO)
	var f := _tween()
	f.tween_property(_fx, "power", 0.0, OUTRO)
	f.parallel().tween_property(self, "_intro", 0.0, OUTRO * 0.7)
	f.parallel().tween_property(_decline, "modulate:a", 0.0, OUTRO * 0.4)
	f.parallel().tween_property(_confirm, "modulate:a", 0.0, OUTRO * 0.4)
	f.tween_callback(func() -> void:
		if not _open:
			visible = false)


func _tween() -> Tween:
	var t := create_tween()
	_tweens.append(t)
	return t


func _kill_tweens() -> void:
	for t: Tween in _tweens:
		if t.is_valid():
			t.kill()
	_tweens.clear()


# --- Layout ------------------------------------------------------------------------------

func _safe_center_x() -> float:
	var insets := MenuKit.safe_insets(self)
	return floorf(insets.x + (size.x - insets.x - insets.y) * 0.5)


func _layout() -> void:
	var view := size
	if view.x <= 0.0:
		return
	var insets := MenuKit.safe_insets(self)
	var left := MARGIN + insets.x
	var width := view.x - left - MARGIN - insets.y
	_header.position = Vector2(0, MARGIN)
	_header.size = Vector2(view.x, HEADER_H)
	# Botões: Ignorar (laca) e Selar (vermelhão), lado a lado, centrados na área segura.
	var bw := maxf(_decline.get_combined_minimum_size().x, 120.0)
	var cw := maxf(_confirm.get_combined_minimum_size().x, 132.0)
	var total_b := bw + BUTTON_GAP + cw
	var bx := floorf(left + (width - total_b) * 0.5)
	var by := view.y - MARGIN - FOOTER_H
	_decline.size = Vector2(bw, FOOTER_H)
	_decline.position = Vector2(bx, by)
	_confirm.size = Vector2(cw, FOOTER_H)
	_confirm.position = Vector2(bx + bw + BUTTON_GAP, by)
	# Placas: o que couber entre o título e os botões (com o cordão acima).
	var n := maxi(_cards.size(), 1)
	var top := MARGIN + HEADER_H + CORD + 2.0
	var avail := by - 6.0 - top
	var card_w := clampf(floorf((width - GAP * (n - 1)) / n), CARD_MIN_W, CARD_MAX_W)
	var card_h := minf(avail, CARD_MAX_H)
	# O mesmo arranjo para todas: o mais rico em que todas cabem; a altura encolhe até o conteúdo
	# da placa mais cheia, e a fileira fica centrada no espaço.
	_mode = MODES[MODES.size() - 1]
	for mode: Array in MODES:
		var size_now := Vector2(card_w, card_h)
		if _cards.all(func(c: KamiCard) -> bool: return c.layout_content(size_now, mode[0], mode[1])):
			_mode = mode
			break
	var need := 0.0
	for card: KamiCard in _cards:
		card.layout_content(Vector2(card_w, card_h), _mode[0], _mode[1])
		need = maxf(need, card.content_height())
	card_h = minf(card_h, ceilf(need))
	var row_w := card_w * n + GAP * (n - 1)
	var x0 := floorf(left + (width - row_w) * 0.5)
	var y0 := floorf(top + maxf(0.0, (avail - card_h) * 0.45))
	_row_rect = Rect2(x0, y0, row_w, card_h)
	for i: int in range(_cards.size()):
		var card := _cards[i]
		card.layout_content(Vector2(card_w, card_h), _mode[0], _mode[1])
		card.base_position = Vector2(x0 + i * (card_w + GAP), y0)
		card.fx_level = _fx_level
		if card.settled or not _open:
			card.position = card.base_position
	_fx.ray_origin = Vector2(_safe_center_x(), y0 + card_h * 0.35)
	_seed_ambience()


func _apply_quality() -> void:
	_fx_level = int(GfxQuality.budget("ui_fx"))
	if _fx:
		_fx.apply_quality()
	for card: KamiCard in _cards:
		card.fx_level = _fx_level
	_seed_ambience()


func _button(on_press: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(on_press)
	b.pressed.connect(func() -> void: AudioManager.play_ui("ui_accept"))
	add_child(b)
	return b


# --- Fundo do santuário ------------------------------------------------------------------

func _seed_ambience() -> void:
	var view := size if size.x > 0.0 else Vector2(678, 305)
	var petals: int = PETALS[_fx_level]
	if _petals.size() != petals:
		_petals.clear()
		for i: int in range(petals):
			_petals.append(Vector4(_rng.randf() * view.x, _rng.randf() * view.y, _rng.randf() * TAU,
					_rng.randf_range(0.6, 1.4)))
	var smoke: int = SMOKE[_fx_level]
	if _smoke.size() != smoke:
		_smoke.clear()
		for i: int in range(smoke):
			_smoke.append(Vector3(_rng.randf(), _rng.randf() * TAU, _rng.randf_range(0.7, 1.3)))


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	var view := size
	for i: int in range(_petals.size()):
		var p := _petals[i]
		p.y += (16.0 + 10.0 * p.w) * delta
		p.x += (10.0 + 6.0 * sin(_time * 0.9 + i)) * delta * p.w
		p.z += delta * (2.0 + p.w)
		if p.y > view.y + 4.0 or p.x > view.x + 4.0:
			p = Vector4(_rng.randf_range(-40.0, view.x * 0.8), -4.0, _rng.randf() * TAU, p.w)
		_petals[i] = p
	_backdrop.queue_redraw()
	_header.queue_redraw()


func _draw_backdrop() -> void:
	var a := _fx.power
	if a <= 0.0:
		return
	var view := _backdrop.size
	_draw_torii(a)
	# Fumaça de incenso: fios que sobem ondulando do chão, quase transparentes.
	var glow := MenuKit.glow_texture()
	for s: Vector3 in _smoke:
		var x0 := view.x * (0.1 + 0.8 * s.x)
		for k: int in range(7):
			var rise := fmod(_time * 14.0 * s.z + k * 22.0, 150.0)
			var p := Vector2(x0 + sin(_time * 0.7 + s.y + rise * 0.04) * (4.0 + rise * 0.12), view.y - rise)
			var fade := (1.0 - rise / 150.0) * 0.1 * a
			var r := 6.0 + rise * 0.1
			_backdrop.draw_texture_rect(glow, Rect2(p - Vector2.ONE * r, Vector2.ONE * r * 2.0), false,
					Color(0.8, 0.76, 0.9, fade))
	# Pétalas de cerejeira girando ao cair.
	for p: Vector4 in _petals:
		var flip := absf(cos(p.z))
		var at := Vector2(p.x, p.y).floor()
		_backdrop.draw_rect(Rect2(at, Vector2(maxf(1.0, roundf(2.0 * flip)), 1.0)), Color(PETAL, 0.85 * a))
		if flip > 0.5:
			_backdrop.draw_rect(Rect2(at + Vector2(0, 1), Vector2(1, 1)), Color(PETAL.darkened(0.15), 0.7 * a))


## Torii de vermelhão atrás das placas: kasagi curvo, nuki, a placa do meio e os dois pilares.
func _draw_torii(a: float) -> void:
	var rise := (1.0 - clampf(_intro, 0.0, 1.0)) * 10.0
	var row := _row_rect
	if row.size.x <= 0.0:
		return
	var cx := _safe_center_x()
	var half := minf(row.size.x * 0.5 + 26.0, _backdrop.size.x * 0.5)
	var top := floorf(_header.position.y + 30.0 + rise)
	var c := Color(TORII, 0.32 * a)
	var dark := Color(0.25, 0.05, 0.04, 0.4 * a)
	var kasagi := PackedVector2Array([Vector2(cx - half - 10.0, top - 6.0), Vector2(cx - half + 6.0, top),
			Vector2(cx + half - 6.0, top), Vector2(cx + half + 10.0, top - 6.0), Vector2(cx + half + 6.0, top + 5.0),
			Vector2(cx - half - 6.0, top + 5.0)])
	_backdrop.draw_colored_polygon(kasagi, c)
	_backdrop.draw_rect(Rect2(cx - half - 4.0, top + 5.0, half * 2.0 + 8.0, 2.0), dark)
	var nuki_y := top + 16.0
	_backdrop.draw_rect(Rect2(cx - half + 2.0, nuki_y, half * 2.0 - 4.0, 4.0), c)
	_backdrop.draw_rect(Rect2(cx - 5.0, top + 7.0, 10.0, nuki_y - top - 7.0), c)
	var pillar_w := 8.0
	var bottom := _backdrop.size.y
	for side: float in [-1.0, 1.0]:
		var px := cx + side * (half - 16.0) - pillar_w * 0.5
		_backdrop.draw_rect(Rect2(px, top + 7.0, pillar_w, bottom - top - 7.0), c)
		_backdrop.draw_rect(Rect2(px, bottom - 10.0, pillar_w, 10.0), dark)


func _draw_header() -> void:
	var k := clampf(_intro, 0.0, 1.2)
	if k <= 0.0:
		return
	var alpha := clampf(k, 0.0, 1.0)
	var drop := (1.0 - minf(k, 1.0)) * -14.0
	var cx := _safe_center_x()
	var title := title_text()
	var font_size := title_size()
	var big := font_size == 24
	var seal_side := 20.0 if big else 14.0
	var total := UiPaint.text_width(title, font_size) + seal_side + 6.0
	var x := floorf(cx - total * 0.5)
	var base := (TITLE_BASE if big else TITLE_BASE_SMALL) + drop
	if _fx_level >= 1:
		_header.draw_circle(Vector2(cx, 14.0 + drop), 50.0, Color(1.0, 0.75, 0.45, 0.06 * alpha))
	UiPaint.seal(_header, Vector2(x + seal_side * 0.5, base - (8.0 if big else 4.0)), SEAL_KANJI, seal_side,
			UiPaint.SEAL_RED, UiPaint.SEAL_TEXT, -0.08, alpha)
	UiPaint.text(_header, Vector2(x + seal_side + 6.0, base), title, font_size, Color(UiPaint.PAPER, alpha),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 4 if big else 3, Color(0.12, 0.03, 0.03))
	var sub := subtitle_text()
	var color := UiPaint.DIM
	if _selected >= 0 and _selected < _cards.size():
		color = _cards[_selected].color.lerp(Color.WHITE, 0.4)
	var sub_w := UiPaint.text_width(sub)
	UiPaint.text(_header, Vector2(floorf(cx - sub_w * 0.5), SUB_BASE + drop), sub, 12, Color(color, alpha))
