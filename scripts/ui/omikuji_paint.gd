class_name OmikujiPaint
extends RefCounted
## Pincéis do omikuji do baú (ChestPanel): tubo hexagonal de madeira, vareta, papel da sorte com
## o kanji na vertical, leitura, selo da sorte, galho do 凶 com o papel amarrado e a janela da
## roleta. Só retângulos, círculos, texturas e texto (nada de draw_polygon/draw_arc a cada
## quadro); giro e escala por draw_set_transform.

## Papel: largura, altura por kanji, margem e as linhas de leitura embaixo.
const SLIP_W := 40.0
const SLIP_CHAR := 25.0
const SLIP_PAD := 14.0
const READ_LINE := 14.0
## Galho do 凶 (canto direito do palco, abaixo do título).
const BRANCH_SIZE := Vector2(44, 20)
const WOOD := Color("8a5a2b")
const WOOD_HI := Color("c08a4a")
const WOOD_SH := Color("4e2c12")
const LEAF := Color("4f7a3a")
const INK_RED := Color("a3221a")
const INK_DARK := Color("2a1c24")
## Selo do 凶: cinza-arroxeado (o vermelho é da boa sorte), legível sobre o fundo escuro.
const SEAL_KYO := Color("5b4a63")
const GOLD_BRIGHT := Color("ffd166")
## Ícone da fita da roleta (nativo 24 px).
const REEL_ICON := 24.0


## Altura do papel aberto (dois kanji).
static func slip_height() -> float:
	return SLIP_PAD * 2.0 + SLIP_CHAR * 2.0


## Tubo parado em `px` (2 ou 3): largura e altura sem a vareta.
static func tube_size(px: int) -> Vector2:
	return Vector2(12, 22) * px


static func seal_width(kanji: String) -> float:
	return UiPaint.text_width(kanji, 12, UiPaint.ja_font()) + 6.0


## Largura da linha da sorte (selo + leitura).
static func line_width(fortune: StringName) -> float:
	return seal_width(Omikuji.kanji(fortune)) + 6.0 + UiPaint.text_width(Omikuji.reading(fortune))


## Centro do selo da linha da sorte (alvo do papel quando encolhe).
static func seal_center(w: float, fortune: StringName) -> Vector2:
	var x := floorf((w - line_width(fortune)) * 0.5)
	return Vector2(x + seal_width(Omikuji.kanji(fortune)) * 0.5, 35.0)


## Selo (kanji da sorte, vermelho; 凶 em tinta escura) e a leitura, centrados embaixo do título.
static func fortune_line(ci: CanvasItem, w: float, fortune: StringName, color: Color, a: float) -> void:
	var kanji := Omikuji.kanji(fortune)
	var sw := seal_width(kanji)
	var x := floorf((w - line_width(fortune)) * 0.5)
	var kyo := fortune == Omikuji.KYO
	var r := Rect2(x, 28.0, sw, 15.0)
	var fill := SEAL_KYO if kyo else UiPaint.SEAL_RED
	ci.draw_rect(r.grow(1.0), Color(fill.darkened(0.5), a))
	ci.draw_rect(r, Color(fill, a))
	ci.draw_rect(r.grow(-1.5), Color(UiPaint.SEAL_TEXT, 0.35 * a), false, 1.0)
	UiPaint.text(ci, Vector2(x + 3.0, 40.0), kanji, 12, Color(UiPaint.SEAL_TEXT, a), HORIZONTAL_ALIGNMENT_LEFT,
			-1, 0, UiPaint.OUTLINE, UiPaint.ja_font())
	UiPaint.text(ci, Vector2(x + sw + 6.0, 40.0), Omikuji.reading(fortune), 12, Color(UiPaint.DIM if kyo else color, a))


## Tubo hexagonal de madeira visto de frente, com a base em `base` e girado `tilt`: faces laterais
## escuras, face do meio clara, tampa e fundo chanfrados, faixa de papel com 籤, o furo e a
## vareta saindo `stick` pixels.
static func tube(ci: CanvasItem, base: Vector2, tilt: float, stick: float, alpha: float, px_scale: int) -> void:
	var px := float(px_scale)
	var s := tube_size(px_scale)
	ci.draw_set_transform(base.round(), tilt, Vector2.ONE)
	var body := Rect2(-s.x * 0.5, -s.y, s.x, s.y)
	if stick > 0.0:
		ci.draw_rect(Rect2(-px * 0.5, -s.y - px - stick, px, stick + px), Color(WOOD_HI, alpha))
		ci.draw_rect(Rect2(-px * 0.5, -s.y - px - stick, px, 2.0 * px), Color(INK_RED, alpha))
	ci.draw_rect(body.grow(1.0), Color(LacquerChest.OUT, alpha))
	var third := floorf(s.x / 3.0)
	var mid := s.x - 2.0 * third
	ci.draw_rect(Rect2(body.position, Vector2(third, s.y)), Color(WOOD_SH, alpha))
	ci.draw_rect(Rect2(body.position + Vector2(third, 0), Vector2(mid, s.y)), Color(WOOD, alpha))
	ci.draw_rect(Rect2(body.position + Vector2(s.x - third, 0), Vector2(third, s.y)),
			Color(WOOD_SH.lerp(WOOD, 0.4), alpha))
	ci.draw_rect(Rect2(body.position + Vector2(third + px, 0), Vector2(px, s.y)), Color(WOOD_HI, 0.7 * alpha))
	# Tampa e fundo chanfrados (o hexágono visto de frente) e o furo da vareta.
	ci.draw_rect(Rect2(-s.x * 0.5 + px, -s.y - px, s.x - 2.0 * px, px), Color(WOOD_HI, alpha))
	ci.draw_rect(Rect2(-px * 0.5, -s.y - px, px, px), Color(LacquerChest.OUT, alpha))
	ci.draw_rect(Rect2(-s.x * 0.5 + px, 0, s.x - 2.0 * px, px), Color(WOOD_SH, alpha))
	# Faixa de papel com o kanji do sorteio.
	var band := Rect2(-s.x * 0.5, -s.y * 0.66, s.x, s.y * 0.32)
	ci.draw_rect(band, Color(UiPaint.PAPER, alpha))
	ci.draw_rect(Rect2(band.position, Vector2(band.size.x, 1)), Color(INK_RED, alpha))
	ci.draw_rect(Rect2(band.position + Vector2(0, band.size.y - 1.0), Vector2(band.size.x, 1)), Color(INK_RED, alpha))
	var f := UiPaint.ja_font()
	var kw := UiPaint.text_width("籤", 12, f)
	ci.draw_string(f, Vector2(roundf(-kw * 0.5), roundf(band.get_center().y + 5.0)), "籤",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(INK_RED, alpha))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Papel da sorte centrado em `center`, `size` do papel aberto, `open` 0..1 (desenrola de cima
## para baixo, com o rolo embaixo) e os kanji na vertical aparecendo conforme abre.
static func slip(ci: CanvasItem, center: Vector2, size: Vector2, zoom: float, tilt: float, open: float,
		fortune: StringName, alpha: float) -> void:
	var h := size.y * (1.0 - pow(1.0 - open, 2.0))
	ci.draw_set_transform(center.round(), tilt, Vector2.ONE * zoom)
	var local := Rect2(-size.x * 0.5, -size.y * 0.5, size.x, h)
	ci.draw_rect(local.grow(1.0), Color(UiPaint.OUTLINE, alpha))
	ci.draw_rect(local, Color(UiPaint.PAPER, alpha))
	var ink := INK_DARK if fortune == Omikuji.KYO else INK_RED
	var rule := Vector2(local.size.x - 6.0, 1)
	ci.draw_rect(Rect2(local.position + Vector2(3, 3), rule), Color(ink, 0.6 * alpha))
	if h > 8.0:
		ci.draw_rect(Rect2(local.position + Vector2(3, h - 4.0), rule), Color(ink, 0.6 * alpha))
	if open < 1.0:
		ci.draw_rect(Rect2(local.position + Vector2(-2, h - 3.0), Vector2(local.size.x + 4.0, 5.0)),
				Color(UiPaint.DIM, alpha))
	var f := UiPaint.ja_font()
	var kanji := Omikuji.kanji(fortune)
	var n := kanji.length()
	var top := local.position.y + SLIP_PAD + (2 - n) * SLIP_CHAR * 0.5
	for i: int in range(n):
		var ch := kanji.substr(i, 1)
		var y := top + i * SLIP_CHAR
		if y + SLIP_CHAR > local.position.y + h:
			break
		var cw := UiPaint.text_width(ch, 24, f)
		ci.draw_string(f, Vector2(roundf(-cw * 0.5), roundf(y + f.get_ascent(24) - 1.0)), ch,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(ink, alpha))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Leitura (na cor da sorte) e significado, centrados em `w`, com a 1ª linha de base em `y0`.
static func reading(ci: CanvasItem, w: float, y0: float, fortune: StringName, color: Color, alpha: float) -> void:
	UiPaint.text(ci, Vector2(0, y0), Omikuji.reading(fortune), 12, Color(color, alpha), HORIZONTAL_ALIGNMENT_CENTER, w)
	UiPaint.text(ci, Vector2(0, y0 + READ_LINE), Omikuji.meaning(fortune), 12, Color(UiPaint.PAPER, alpha),
			HORIZONTAL_ALIGNMENT_CENTER, w)


## Onde o papel do 凶 fica amarrado no galho `branch`.
static func knot_point(branch: Rect2) -> Vector2:
	return branch.position + Vector2(branch.size.x * 0.5, 5.0)


## Galho da árvore do templo (alfa `a`) e, se `tied`, o papel do 凶 dobrado e amarrado.
static func branch(ci: CanvasItem, b: Rect2, a: float, tied: bool) -> void:
	ci.draw_rect(Rect2(b.position + Vector2(0, 3), Vector2(b.size.x, 3)), Color(WOOD_SH, a))
	ci.draw_rect(Rect2(b.position + Vector2(0, 3), Vector2(b.size.x, 1)), Color(WOOD, a))
	ci.draw_rect(Rect2(b.position + Vector2(6, 0), Vector2(8, 3)), Color(WOOD_SH, a))
	ci.draw_rect(Rect2(b.position + Vector2(b.size.x - 12, 6), Vector2(6, 3)), Color(WOOD_SH, a))
	ci.draw_circle(b.position + Vector2(4, 1), 2.0, Color(LEAF, a))
	ci.draw_circle(b.position + Vector2(b.size.x - 4, 8), 2.0, Color(LEAF, a))
	if tied:
		var knot := knot_point(b).round()
		ci.draw_rect(Rect2(knot + Vector2(-4, -2), Vector2(8, 4)), UiPaint.OUTLINE)
		ci.draw_rect(Rect2(knot + Vector2(-3, -1), Vector2(6, 2)), UiPaint.PAPER)
		ci.draw_rect(Rect2(knot + Vector2(-2, 2), Vector2(5, 12)), UiPaint.OUTLINE)
		ci.draw_rect(Rect2(knot + Vector2(-1, 2), Vector2(3, 11)), UiPaint.PAPER)
		ci.draw_rect(Rect2(knot + Vector2(0, 5), Vector2(1, 5)), INK_DARK)


## Janela da roleta (`size`): laca escura, a fita `strip` na posição `offset` (em ícones, `cell`
## pixels cada), sombras em cima e embaixo (cilindro), filete dourado, marcas da linha de parada
## e o brilho da parada (`flash`). Fita vazia = só a janela.
static func reel(ci: CanvasItem, size: Vector2, strip: Array, offset: float, cell: float, special: bool,
		flash: float) -> void:
	var r := Rect2(Vector2.ZERO, size)
	ci.draw_rect(r, Color(0.05, 0.03, 0.06, 0.92))
	if not strip.is_empty():
		var first := int(floorf(offset)) - 1
		for j: int in range(first, first + 4):
			if j < 0 or j >= strip.size() or strip[j] == null:
				continue
			var y := size.y * 0.5 + (j - offset) * cell
			var at := Vector2((size.x - REEL_ICON) * 0.5, y - REEL_ICON * 0.5).floor()
			ci.draw_texture_rect(strip[j] as Texture2D, Rect2(at, Vector2.ONE * REEL_ICON), false)
		UiPaint.vgradient(ci, Rect2(0, 0, size.x, 8), Color(0, 0, 0, 0.8), Color(0, 0, 0, 0))
		UiPaint.vgradient(ci, Rect2(0, size.y - 8.0, size.x, 8), Color(0, 0, 0, 0), Color(0, 0, 0, 0.8))
	var gold := GOLD_BRIGHT if special else UiPaint.GOLD
	ci.draw_rect(r, Color(gold, 0.9), false, 1.0)
	ci.draw_rect(r.grow(-1.0), Color(0, 0, 0, 0.6), false, 1.0)
	ci.draw_rect(Rect2(1, size.y * 0.5 - 1.0, 3, 2), gold)
	ci.draw_rect(Rect2(size.x - 4.0, size.y * 0.5 - 1.0, 3, 2), gold)
	if flash > 0.0:
		ci.draw_rect(r, Color(1, 1, 0.85, 0.45 * flash))
