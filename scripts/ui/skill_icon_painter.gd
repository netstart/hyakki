class_name SkillIconPainter
extends RefCounted
## Desenha os ícones de habilidade (assets/art/ui/skill_icons, 24x24, moldura na própria arte)
## numa CanvasItem: selo de nível com dígitos em pixel 3x5, brilho pulsante nas evoluídas e
## lampejo ao subir de nível. Efeitos só com GfxQuality "ui_fx" >= 1 (Média/Alta); em Baixa o
## ícone é estático. Puramente visual: usa o relógio real, nunca a simulação.

const ICON := 24
const FLASH_SECONDS := 0.7
const PULSE_SECONDS := 1.6
const SHINE_SECONDS := 2.8
const BADGE_INK := Color("fff8e8")
const BADGE_BG := Color(0.06, 0.03, 0.09, 0.92)
const BADGE_MAX := Color("f2b23a")
const BADGE_MAX_INK := Color("2a1404")
const GLOW := Color("ffd166")
## Dígitos 3x5 (linhas de 3 bits, bit 2 = coluna da esquerda).
const DIGITS := [
	[7, 5, 5, 5, 7], [2, 6, 2, 2, 7], [7, 1, 7, 4, 7], [7, 1, 3, 1, 7], [5, 5, 7, 1, 1],
	[7, 4, 7, 1, 7], [7, 4, 7, 5, 7], [7, 1, 1, 2, 2], [7, 5, 7, 5, 7], [7, 5, 7, 1, 7],
]

## Estrela 5x5 (bit 4 = coluna da esquerda) e seu contorno 7x7.
const STAR := [4, 31, 14, 14, 27]
const STAR_OUTLINE := [8, 62, 127, 62, 62, 127, 54]

## Último nível visto por chave (ex.: "w:katana", "p:sake") e quando começou o lampejo.
var _levels: Dictionary = {}
var _flash_at: Dictionary = {}


## Nível de efeitos de UI atual (0 = estático, 1 = brilho, 2 = brilho e reflexo).
static func fx() -> int:
	return int(GfxQuality.budget("ui_fx"))


## Alfa do halo pulsante das evoluídas em `t` segundos (0 em Baixa).
static func glow_alpha(fx_level: int, t: float) -> float:
	if fx_level <= 0:
		return 0.0
	var wave := 0.5 + 0.5 * sin(t * TAU / PULSE_SECONDS)
	return (0.18 + 0.22 * wave) if fx_level >= 2 else (0.14 + 0.14 * wave)


## Registra o nível de `key`; devolve true se subiu (ou se a habilidade é nova depois do
## primeiro registro) e, com efeitos ligados, começa o lampejo.
func note(key: String, level: int, now: float) -> bool:
	var before: int = _levels.get(key, -1)
	_levels[key] = level
	var rose := before >= 0 and level > before
	if rose and fx() > 0:
		_flash_at[key] = now
	return rose


## 0..1 do lampejo de `key` (1 = acabou de subir).
func flash(key: String, now: float) -> float:
	if not _flash_at.has(key):
		return 0.0
	var left := 1.0 - (now - float(_flash_at[key])) / FLASH_SECONDS
	if left <= 0.0:
		_flash_at.erase(key)
		return 0.0
	return left


func reset() -> void:
	_levels.clear()
	_flash_at.clear()


## Desenha o ícone em `at` (canto superior esquerdo, 24x24, sem escala: pixel perfeito).
func draw(ci: CanvasItem, at: Vector2, tex: Texture2D, key: String, level: int, max_level: int,
		evolved: bool, now: float) -> void:
	note(key, level, now)
	var level_fx := fx()
	if level_fx <= 0:
		# Troca ao vivo para Baixa: corta o lampejo em andamento (ícone fica estático).
		_flash_at.clear()
	var box := Rect2(at, Vector2(ICON, ICON))
	if evolved and level_fx > 0:
		var a := glow_alpha(level_fx, now)
		ci.draw_rect(box.grow(2.0), Color(GLOW, a * 0.45))
		ci.draw_rect(box.grow(1.0), Color(GLOW, a))
	if tex:
		ci.draw_texture_rect(tex, box, false)
	else:
		ci.draw_rect(box, Color(0, 0, 0, 0.5))
	if evolved and level_fx >= 2:
		_shine(ci, at, now)
	var f := flash(key, now)
	if f > 0.0:
		ci.draw_rect(box.grow(-3.0), Color(1, 1, 1, 0.55 * f * f))
		ci.draw_rect(box.grow(1.0 + (1.0 - f) * 4.0), Color(GLOW, f), false, 1.0)
	if max_level == 1:
		# Evolução/união de nível único: estrela dourada em vez de um "1" sem sentido.
		draw_star(ci, at + Vector2(ICON, ICON))
	else:
		draw_badge(ci, at + Vector2(ICON, ICON), level, max_level > 0 and level >= max_level)


## Reflexo diagonal que atravessa o ícone a cada SHINE_SECONDS (só em Alta).
func _shine(ci: CanvasItem, at: Vector2, now: float) -> void:
	var phase := fmod(now, SHINE_SECONDS) / SHINE_SECONDS
	if phase > 0.45:
		return
	var k := int(lerpf(-4.0, 40.0, phase / 0.45))
	for i: int in range(3, 21):
		var j := k - i
		if j >= 3 and j <= 20:
			ci.draw_rect(Rect2(at + Vector2(i, j), Vector2.ONE), Color(1, 1, 1, 0.4))
			if j + 1 <= 20:
				ci.draw_rect(Rect2(at + Vector2(i, j + 1), Vector2.ONE), Color(1, 1, 1, 0.18))


## Selo de nível com o canto inferior direito em `corner`: pílula escura com dígitos 3x5;
## dourada no nível máximo.
static func draw_badge(ci: CanvasItem, corner: Vector2, level: int, is_max: bool) -> void:
	var text := str(clampi(level, 0, 99))
	var w := text.length() * 4 + 3
	var rect := Rect2(corner - Vector2(w, 9) + Vector2(1, 1), Vector2(w, 9))
	var bg := BADGE_MAX if is_max else BADGE_BG
	var ink := BADGE_MAX_INK if is_max else BADGE_INK
	ci.draw_rect(Rect2(rect.position + Vector2(1, 0), rect.size - Vector2(2, 0)), Color(0, 0, 0, 0.9))
	ci.draw_rect(Rect2(rect.position + Vector2(0, 1), rect.size - Vector2(0, 2)), Color(0, 0, 0, 0.9))
	ci.draw_rect(rect.grow(-1.0), bg)
	var x := rect.position.x + 2.0
	for ch: String in text:
		_digit(ci, Vector2(x, rect.position.y + 2.0), int(ch), ink)
		x += 4.0


## Estrela dourada 5x5 com contorno escuro, canto inferior direito em `corner`.
static func draw_star(ci: CanvasItem, corner: Vector2) -> void:
	var o := corner - Vector2(6, 6)
	for y: int in range(7):
		var bits: int = STAR_OUTLINE[y]
		for x: int in range(7):
			if bits & (64 >> x):
				ci.draw_rect(Rect2(o + Vector2(x, y), Vector2.ONE), Color(0, 0, 0, 0.9))
	for y: int in range(5):
		var bits: int = STAR[y]
		for x: int in range(5):
			if bits & (16 >> x):
				ci.draw_rect(Rect2(o + Vector2(x + 1, y + 1), Vector2.ONE), BADGE_MAX if y > 0 or x != 2 else Color("fff6b8"))


static func _digit(ci: CanvasItem, at: Vector2, d: int, color: Color) -> void:
	var rows: Array = DIGITS[clampi(d, 0, 9)]
	for y: int in range(5):
		var bits: int = rows[y]
		for x: int in range(3):
			if bits & (4 >> x):
				ci.draw_rect(Rect2(at + Vector2(x, y), Vector2.ONE), color)
