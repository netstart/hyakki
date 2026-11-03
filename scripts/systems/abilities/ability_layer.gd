class_name AbilityLayer
extends Node2D
## Desenho das habilidades dos guardiões (só leitura da simulação): o chão dos efeitos (abaixo
## dos inimigos), o que fica por cima, a camada aditiva (só com brilho, qualidade Alta) e o
## letreiro curto acima do herói (kanji + nome traduzido) ao soltar. Redesenha só enquanto há
## algo na tela (e uma última vez para limpar). Sem draw_arc/draw_polyline por quadro: Stroke.

## Letreiro: tamanho da letra, subida e o tempo de entrada/saída (s de jogo).
const BANNER_FONT := 12
const BANNER_RISE := 6.0
const BANNER_FADE := 0.18
const BANNER_GAP := 10.0
const BANNER_OUTLINE := Color(0.08, 0.04, 0.02, 0.95)
## Faixa escura atrás do letreiro, folga lateral e o estalo da entrada (s de jogo).
const BANNER_PLATE := Color(0.06, 0.03, 0.05, 0.72)
const BANNER_PAD := 6.0
const BANNER_POP := 0.14
## Camada do letreiro: acima dos números de dano (FxLayer.NUMBER_LAYER = 8), abaixo da HUD (10).
const BANNER_LAYER := 9
## O kanji sai sempre na fonte japonesa (a latina não tem os ideogramas); o nome, na do idioma.
const KANJI_FONT := "res://assets/fonts/fusion_pixel_12_ja.woff2"

var system: AbilitySystem

var _over: Node2D
var _glow: Node2D
## Letreiro numa camada própria que segue a câmera, acima da escuridão da lanterna e dos números
## de dano (FxLayer.NUMBER_LAYER) e abaixo da HUD: lê no meio da horda e da noite.
var _banner: Node2D
var _font: Font
var _kanji_font: Font
var _drawing: bool = false


func _ready() -> void:
	z_index = -3
	_over = Node2D.new()
	_over.z_as_relative = false
	_over.z_index = 11
	_over.draw.connect(_draw_over)
	add_child(_over)
	_glow = Node2D.new()
	_glow.z_as_relative = false
	_glow.z_index = 11
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = additive
	_glow.draw.connect(_draw_glow)
	add_child(_glow)
	var banner_layer := CanvasLayer.new()
	banner_layer.layer = BANNER_LAYER
	banner_layer.follow_viewport_enabled = true
	add_child(banner_layer)
	_banner = Node2D.new()
	_banner.draw.connect(_draw_banner)
	banner_layer.add_child(_banner)
	_font = Locale.font if Locale.font else ThemeDB.fallback_font
	_kanji_font = load(KANJI_FONT) as Font if ResourceLoader.exists(KANJI_FONT) else _font


## A partida saiu da árvore e vai ser liberada: desfaz o ciclo sistema ↔ comportamento
## (RefCounted que se apontam não se liberam sozinhos).
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and system != null:
		system.release()


func _process(_delta: float) -> void:
	var behavior: HeroAbilities = system.behavior if system else null
	var active := (behavior != null and behavior.has_visuals()) or banner_visible()
	if active or _drawing:
		queue_redraw()
		_over.queue_redraw()
		_glow.queue_redraw()
		_banner.queue_redraw()
	_drawing = active


## O letreiro da última habilidade ainda está na tela.
func banner_visible() -> bool:
	return system != null and not system.banner.is_empty() \
			and GameClock.game_time - float(system.banner["at"]) < AbilitySystem.BANNER_TIME


func _draw() -> void:
	if system and system.behavior:
		system.behavior.draw_ground(self)


func _draw_over() -> void:
	if system == null:
		return
	if system.behavior:
		system.behavior.draw_over(_over)


func _draw_glow() -> void:
	if system and system.behavior and FxLayer.glow:
		system.behavior.draw_glow(_glow)


## Kanji na cor da energia e o nome traduzido, centrados acima da cabeça, numa faixa escura
## (lê no meio da horda): entra com um estalo (um pouco maior e claro, assenta em BANNER_POP), sobe um
## pouco e sai em fade. Sombra de 1 px e contorno escuro grosso nas letras, fio na cor da
## energia embaixo e losangos nas pontas.
func _draw_banner() -> void:
	if not banner_visible():
		return
	var player := system.game.player
	var age := GameClock.game_time - float(system.banner["at"])
	var k := clampf(age / BANNER_FADE, 0.0, 1.0)
	var out := clampf((AbilitySystem.BANNER_TIME - age) / BANNER_FADE, 0.0, 1.0)
	var alpha := minf(k, out)
	var pop := 1.0 - clampf(age / BANNER_POP, 0.0, 1.0)
	var kanji := String(system.banner["kanji"])
	var title := tr("ability.%s.name" % system.banner["id"])
	if Locale.font and Locale.font != _font:
		_font = Locale.font
	var kanji_w := _kanji_font.get_string_size(kanji, HORIZONTAL_ALIGNMENT_LEFT, -1, BANNER_FONT).x
	var title_w := _font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, BANNER_FONT).x
	var gap := BANNER_GAP * 0.5 if not kanji.is_empty() else 0.0
	var width := kanji_w + gap + title_w
	var center := player.position + Vector2(0.0, player.sprite_top() - 12.0 - BANNER_RISE * smoothstep(0.0, 1.0, k))
	var energy := system.energy.color
	# Estalo: escala 1,15 → 1 em torno do centro da faixa.
	var scale := 1.0 + 0.15 * pop * pop
	_banner.draw_set_transform(center.round(), 0.0, Vector2(scale, scale))
	var half := roundf(width * 0.5 + BANNER_PAD)
	var plate := Rect2(-half, -8.0, half * 2.0, 13.0)
	_banner.draw_rect(plate.grow(1.0), Color(BANNER_OUTLINE, 0.55 * alpha))
	_banner.draw_rect(plate, Color(BANNER_PLATE, BANNER_PLATE.a * alpha))
	var rule := Rect2(plate.position.x + 2.0, plate.end.y - 1.0, plate.size.x - 4.0, 1.0)
	_banner.draw_rect(rule, Color(energy, 0.9 * alpha))
	_banner.draw_rect(Rect2(rule.position.x, plate.position.y, rule.size.x, 1.0), Color(energy, 0.35 * alpha))
	for side: float in [-1.0, 1.0]:
		var tip := Vector2(side * (half + 1.0), -1.5)
		Stroke.convex(_banner, PackedVector2Array([tip + Vector2(0, -3), tip + Vector2(side * 3.0, 0), tip + Vector2(0, 3),
				tip + Vector2(-side * 3.0, 0)]), Color(energy.lerp(Color.WHITE, 0.3), alpha))
	# Clarão branco que some no estalo.
	if pop > 0.0:
		_banner.draw_rect(plate, Color(1.0, 1.0, 1.0, 0.25 * pop * alpha))
	var base := Vector2(-width * 0.5, 3.0).round()
	var color := energy.lerp(Color.WHITE, 0.25)
	var shadow := Color(0.0, 0.0, 0.0, 0.8 * alpha)
	var rim := Color(BANNER_OUTLINE, BANNER_OUTLINE.a * alpha)
	if not kanji.is_empty():
		_banner.draw_string_outline(_kanji_font, base, kanji, HORIZONTAL_ALIGNMENT_LEFT, -1, BANNER_FONT, 4, rim)
		_banner.draw_string(_kanji_font, base + Vector2.ONE, kanji, HORIZONTAL_ALIGNMENT_LEFT, -1, BANNER_FONT, shadow)
		_banner.draw_string(_kanji_font, base, kanji, HORIZONTAL_ALIGNMENT_LEFT, -1, BANNER_FONT, Color(color, alpha))
	var at := base + Vector2(kanji_w + gap, 0.0)
	_banner.draw_string_outline(_font, at, title, HORIZONTAL_ALIGNMENT_LEFT, -1, BANNER_FONT, 4, rim)
	_banner.draw_string(_font, at + Vector2.ONE, title, HORIZONTAL_ALIGNMENT_LEFT, -1, BANNER_FONT, shadow)
	_banner.draw_string(_font, at, title, HORIZONTAL_ALIGNMENT_LEFT, -1, BANNER_FONT, Color(1.0, 0.97, 0.9, alpha))
	_banner.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
