class_name MenuBackdrop
extends Control
## Fundo animado dos menus: vale de Kagerō à noite, torii, a guardiã com a lanterna e a
## procissão passando ao longe. Feito só com o Ninja Adventure (plano 8.6: "diorama").

var _floor: Texture2D
var _nature: Texture2D
var _house: Texture2D
var _hero: SpriteSheet
var _walkers: Array[SpriteSheet] = []
var _time: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_floor = load("res://assets/art/tilesets/floor.png") as Texture2D
	_nature = load("res://assets/art/tilesets/nature.png") as Texture2D
	_house = load("res://assets/art/tilesets/house.png") as Texture2D
	_hero = SpriteSheet.load_sheet("res://assets/art/actors/heroes/aki/SpriteSheet.png", "dir4", Vector2(16, 16), 4)
	for path: String in ["res://assets/art/actors/enemies/spirit/SpriteSheet.png",
			"res://assets/art/actors/enemies/lantern_red/SpriteSheet.png",
			"res://assets/art/actors/enemies/skeleton/SpriteSheet.png",
			"res://assets/art/actors/enemies/kappa_green/SpriteSheet.png",
			"res://assets/art/actors/enemies/oni_red/SpriteSheet.png"]:
		_walkers.append(SpriteSheet.load_sheet(path, "dir4", Vector2(16, 16), 4))


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	# Sob um pai que não é Control as âncoras não dão tamanho: usa a tela inteira.
	var area := size if size.x > 1.0 and size.y > 1.0 else get_viewport_rect().size
	var w := area.x
	var h := area.y
	# Chão de grama.
	var src := Rect2(0, 12 * 16, 16, 16)
	for y: int in range(0, int(h) + 16, 16):
		for x: int in range(0, int(w) + 16, 16):
			draw_texture_rect_region(_floor, Rect2(x, y, 16, 16), src)
	# Árvores ao fundo e o torii.
	for k: int in range(8):
		var tree := Rect2(16 * 16 if k % 2 == 0 else 0, 0, 32, 32)
		draw_texture_rect_region(_nature, Rect2(k * 90 - 20, 30 + (k % 3) * 10, 32, 32), tree)
	draw_texture_rect_region(_house, Rect2(w * 0.5 - 36, h * 0.52 - 48, 72, 48), Rect2(0, 80, 48, 32))
	# Procissão atravessando ao longe.
	for k: int in range(10):
		var sheet := _walkers[k % _walkers.size()]
		var x := fmod(_time * 18.0 + k * 34.0, w + 120.0) - 60.0
		var frame := int(_time * 6.0 + k)
		draw_texture_rect_region(sheet.texture, Rect2(x, h * 0.3 + sin(k * 1.7) * 6.0, 16, 16),
				sheet.region(frame, SpriteSheet.Dir.RIGHT), Color(0.7, 0.7, 0.9, 0.85))
	# Guardiã com a lanterna.
	var hero_at := Vector2(w * 0.5 - 8, h * 0.62)
	draw_texture_rect_region(_hero.texture, Rect2(hero_at, Vector2(32, 32)), _hero.region(0, SpriteSheet.Dir.DOWN))
	# Noite: escurece tudo, menos o círculo da lanterna.
	var glow := hero_at + Vector2(16, 14)
	draw_rect(Rect2(0, 0, w, h), Color(0.03, 0.02, 0.1, 0.55))
	var pulse := 1.0 + 0.04 * sin(_time * 5.0)
	for r: int in range(5):
		draw_circle(glow, (70.0 - r * 12.0) * pulse, Color(1.0, 0.8, 0.4, 0.05))
	draw_circle(glow + Vector2(10, 4), 3.0, Color(1.0, 0.9, 0.5, 0.9))
	# Vaga-lumes.
	for k: int in range(14):
		var p := Vector2(fmod(k * 97.0 + _time * 7.0 * (1 + k % 3), w), fmod(k * 53.0 + sin(_time + k) * 20.0, h))
		draw_circle(p, 1.0, Color(1.0, 0.95, 0.6, 0.5 + 0.5 * sin(_time * 3.0 + k)))
