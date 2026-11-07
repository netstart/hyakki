extends Screen
## História em painéis (plano 3.2 e 3.6): cenas montadas com tiles e personagens do
## próprio pacote, ampliadas, com vinheta e texto ("diorama", plano 8.6). Toque avança;
## "Pular" encerra. Não interrompe o combate: só aparece nos menus. A sequência pode trazer a
## própria música (data/story.json "music"; sem ela, a da história).

const KUON_SHEET := "res://assets/art/actors/heroes/kuon/SpriteSheet.png"

var _panels: Array = []
var _index: int = 0
var _text: Label
var _face: TextureRect
var _scene: Control
var _box: PanelContainer
var _skip: Button
var _next: Button
var _scene_id: String = ""
var _time: float = 0.0
var _nature: Texture2D
var _house: Texture2D
var _floor: Texture2D
var _sheets: Dictionary = {}
## Folha do Osorezan (tools/gen_osorezan_art.py) e a Gashadokuro em silhueta (cenas "osorezan"/"sanzu").
var _oso: Texture2D
var _water: Texture2D
var _gasha: Texture2D
## Quadro da tira da Gashadokuro (data/bosses.json "sprite.frame").
var _gasha_frame := Vector2.ZERO


func _ready() -> void:
	_nature = load("res://assets/art/tilesets/nature.png") as Texture2D
	_house = load("res://assets/art/tilesets/house.png") as Texture2D
	_floor = load("res://assets/art/tilesets/floor.png") as Texture2D
	for key: String in ["aki", "tora"]:
		_sheets[key] = _sheet("res://assets/art/actors/heroes/%s/SpriteSheet.png" % key)
	_sheets["spirit"] = _sheet("res://assets/art/actors/enemies/spirit/SpriteSheet.png")
	_sheets["skeleton"] = _sheet("res://assets/art/actors/enemies/skeleton/SpriteSheet.png")
	_sheets["lantern"] = _sheet("res://assets/art/actors/enemies/lantern_red/SpriteSheet.png")
	if ResourceLoader.exists(KUON_SHEET):
		_sheets["kuon"] = _sheet(KUON_SHEET)
	_oso = load(TerrainArt.TILESETS["osorezan"]) as Texture2D
	_water = load(TerrainArt.TILESETS["water"]) as Texture2D
	var gasha: Dictionary = (DB.bosses.get(&"gashadokuro", {}) as Dictionary).get("sprite", {})
	if ResourceLoader.exists(String(gasha.get("path", ""))):
		_gasha = load(String(gasha["path"])) as Texture2D
		var frame: Array = gasha.get("frame", [_gasha.get_height(), _gasha.get_height()])
		_gasha_frame = Vector2(float(frame[0]), float(frame[1]))
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.01, 0.05)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_scene = Control.new()
	_scene.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene.draw.connect(_draw_scene)
	add_child(_scene)
	var box := PanelContainer.new()
	box.name = "TextBox"
	box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	box.offset_top = -92
	box.offset_bottom = -10
	_box = box
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_face = icon_rect("", Vector2(48, 48))
	row.add_child(_face)
	# Sem largura mínima: o texto ocupa o que sobra ao lado do retrato e quebra (telas de 480 px).
	_text = wrap_label("", 0)
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_text)
	box.add_child(row)
	add_child(box)
	_skip = button(tr("story.skip"), func() -> void: app.story_finished(), Vector2(80, 26))
	_skip.name = "Skip"
	_skip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_skip.offset_top = 8
	_skip.offset_bottom = 34
	add_child(_skip)
	_next = button(tr("story.next"), _advance, Vector2(80, 26))
	_next.name = "Next"
	_next.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_next.offset_top = -128
	_next.offset_bottom = -100
	add_child(_next)
	_apply_insets()
	MenuKit.on_insets_change(self, _apply_insets)


## Caixa do texto e botões fora do recorte da câmera (MenuKit.safe_insets, dos dois lados).
func _apply_insets() -> void:
	var inset := MenuKit.safe_insets(self)
	_box.offset_left = 20.0 + inset.x
	_box.offset_right = -20.0 - inset.y
	_skip.offset_left = -92.0 - inset.y
	_skip.offset_right = -10.0 - inset.y
	_next.offset_left = -112.0 - inset.y
	_next.offset_right = -28.0 - inset.y


func play(id: StringName) -> void:
	var data: Dictionary = DB.story.get(id, {})
	_panels = data.get("panels", [])
	_index = 0
	AudioManager.play_music(music_of(id))
	_show_panel()


func _show_panel() -> void:
	if _index >= _panels.size():
		app.story_finished()
		return
	var panel_data: Dictionary = _panels[_index]
	_text.text = tr(String(panel_data["text"]))
	var face := String(panel_data.get("face", ""))
	_face.texture = load(face) as Texture2D if not face.is_empty() and ResourceLoader.exists(face) else null
	_face.visible = _face.texture != null
	_scene_id = String(panel_data.get("scene", ""))


func _advance() -> void:
	_index += 1
	AudioManager.play_ui("ui_move")
	_show_panel()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		_advance()


func _process(delta: float) -> void:
	if visible:
		_time += delta
		_scene.queue_redraw()


func _draw_scene() -> void:
	var w := _scene.size.x
	var h := _scene.size.y - 100.0
	var dawn := _scene_id == "dawn" or _scene_id == "temple_lanterns"
	var grass := Rect2(0, 12 * 16, 16, 16) if _scene_id != "yomi_gate" else Rect2(11 * 16, 19 * 16, 16, 16)
	var ground := _floor
	if _scene_id == "osorezan" or _scene_id == "sanzu":
		ground = _oso
		grass = _oso_rect("ground_ash_a" if _scene_id == "osorezan" else "ground_pebbles")
	var s := 3.0
	for y: int in range(0, int(h / (16 * s)) + 1):
		for x: int in range(0, int(w / (16 * s)) + 1):
			_scene.draw_texture_rect_region(ground, Rect2(x * 16 * s, y * 16 * s, 16 * s, 16 * s), grass)
	match _scene_id:
		"osorezan":
			_draw_osorezan(w, h)
		"sanzu":
			_draw_sanzu(w, h)
		"village_night", "procession":
			for k: int in range(4):
				_scene.draw_texture_rect_region(_house, Rect2(40 + k * 150, 20, 64 * 1.5, 48 * 1.5), Rect2(k * 64 % 256, 0, 64, 48))
			if _scene_id == "procession":
				for k: int in range(9):
					var key: String = ["spirit", "skeleton", "lantern"][k % 3]
					var sheet: SpriteSheet = _sheets[key]
					var x := fmod(_time * 30.0 + k * 70.0, w + 100.0) - 50.0
					_scene.draw_texture_rect_region(sheet.texture, Rect2(x, h * 0.55, 48, 48),
							sheet.region(int(_time * 6.0 + k), SpriteSheet.Dir.RIGHT))
		"forge", "lantern":
			_scene.draw_texture_rect_region(_house, Rect2(w * 0.5 - 140, 10, 64 * 2, 48 * 2), Rect2(8 * 16, 0, 64, 48))
			var aki: SpriteSheet = _sheets["aki"]
			var tora: SpriteSheet = _sheets["tora"]
			_actor(aki, Vector2(w * 0.5 - 70, h * 0.5), SpriteSheet.Dir.RIGHT)
			_actor(tora, Vector2(w * 0.5 + 20, h * 0.5), SpriteSheet.Dir.LEFT)
		"yomi_gate":
			for k: int in range(5):
				_scene.draw_texture_rect_region(_house, Rect2(40 + k * 130, 30, 32 * 2, 48 * 2), Rect2(16, 19 * 16, 32, 48))
			var aki: SpriteSheet = _sheets["aki"]
			_actor(aki, Vector2(w * 0.5 - 24, h * 0.55), SpriteSheet.Dir.UP)
		"dawn", "temple_lanterns":
			_scene.draw_texture_rect_region(_house, Rect2(w * 0.5 - 72, h * 0.2, 48 * 3, 32 * 3), Rect2(0, 80, 48, 32))
			var aki: SpriteSheet = _sheets["aki"]
			_actor(aki, Vector2(w * 0.5 - 24, h * 0.62), SpriteSheet.Dir.DOWN)
	# Noite com a luz da lanterna, ou o amanhecer; nas margens do Sanzu, a luz violeta das almas.
	if dawn:
		_scene.draw_rect(Rect2(0, 0, w, h), Color(1.0, 0.75, 0.5, 0.18))
	else:
		_scene.draw_rect(Rect2(0, 0, w, h), Color(0.03, 0.02, 0.1, 0.55))
		var violet := _scene_id == "osorezan" or _scene_id == "sanzu"
		var glow := Color(0.72, 0.55, 1.0, 0.1) if violet else Color(1.0, 0.8, 0.4, 0.08)
		_scene.draw_circle(Vector2(w * 0.5, h * 0.6), 90.0 + sin(_time * 4.0) * 3.0, glow)
	# Vinheta.
	for k: int in range(6):
		var inset := k * 8.0
		_scene.draw_rect(Rect2(inset, inset, w - inset * 2, h - inset * 2), Color(0, 0, 0, 0.08), false, 8.0)


func on_back() -> void:
	app.story_finished()


## Música da sequência `id` (data/story.json "music"), ou a da história.
static func music_of(id: StringName) -> String:
	return String((DB.story.get(id, {}) as Dictionary).get("music", "story"))


## Retângulo (px) de um sprite da folha do Osorezan no catálogo de data/biomes.json.
static func _oso_rect(sprite: String) -> Rect2:
	var e: Array = (TerrainArt.data().get("sprites", {}) as Dictionary).get(sprite, ["osorezan", 0, 3, 1, 1])
	return Rect2(float(e[1]) * 16.0, float(e[2]) * 16.0, float(e[3]) * 16.0, float(e[4]) * 16.0)


## Sprite da folha do Osorezan ampliado `k` vezes com a base em `foot`.
func _oso_draw(sprite: String, foot: Vector2, k: float = 2.0, tint: Color = Color.WHITE) -> void:
	var r := _oso_rect(sprite)
	_scene.draw_texture_rect_region(_oso, Rect2(foot - Vector2(r.size.x * k * 0.5, r.size.y * k), r.size * k), r, tint)


## Osorezan: os campos de enxofre com cata-ventos e pilhas de pedras, a sombra da Gashadokuro
## atrás do vapor e Kuon de pé entre as pedras.
func _draw_osorezan(w: float, h: float) -> void:
	if _gasha != null:
		# Silhueta da Gashadokuro (1º quadro da tira) bem grande, escurecida, respirando no fundo.
		var k := h * 0.95 / _gasha_frame.y * (1.0 + sin(_time * 1.3) * 0.01)
		_scene.draw_texture_rect_region(_gasha, Rect2(Vector2(w * 0.5 - _gasha_frame.x * k * 0.5, h * 0.02),
				_gasha_frame * k), Rect2(Vector2.ZERO, _gasha_frame), Color(0.42, 0.34, 0.6, 0.55))
	for k: int in range(6):
		_oso_draw("sulfur_patch" if k % 2 == 0 else "sulfur_crust", Vector2(60 + k * 120, h * 0.9), 2.0)
	for k: int in range(7):
		var x := 40.0 + k * (w - 80.0) / 6.0
		_oso_draw(["cairn_m", "cairn_l", "cairn_s"][k % 3], Vector2(x, h * 0.78 + (k % 2) * 14.0), 2.0)
		var sway := sin(_time * 3.0 + k) * 0.04
		_oso_draw("kazaguruma_a" if (int(_time * 4.0) + k) % 2 == 0 else "kazaguruma_a_spin",
				Vector2(x + 26.0, h * 0.8 + (k % 2) * 14.0 + sway), 2.0)
	_oso_draw("jizo_a", Vector2(w * 0.18, h * 0.66), 2.0)
	_oso_draw("sotoba_b", Vector2(w * 0.84, h * 0.66), 2.0)
	if _sheets.has("kuon"):
		_actor(_sheets["kuon"], Vector2(w * 0.5 - 24, h * 0.52), SpriteSheet.Dir.DOWN)


## Sanzu: a margem de seixos, a água negra com as luzes violeta das almas, o torii da travessia e
## Kuon olhando a outra margem.
func _draw_sanzu(w: float, h: float) -> void:
	var water := Rect2(0, 0, w, h * 0.46)
	var cell := 16.0 * 3.0
	for y: int in range(0, int(water.size.y / cell) + 1):
		for x: int in range(0, int(w / cell) + 1):
			_scene.draw_texture_rect_region(_water, Rect2(x * cell, y * cell, cell, cell), Rect2(16, 16, 16, 16),
					Color(0.22, 0.2, 0.38))
	for k: int in range(10):
		# Almas atravessando: luzes violeta descendo o rio devagar.
		var x := fmod(_time * (12.0 + k % 3 * 5.0) + k * 97.0, w + 40.0) - 20.0
		var y := h * (0.08 + 0.035 * float(k % 9)) + sin(_time * 2.0 + k) * 3.0
		_scene.draw_circle(Vector2(x, y), 5.0, Color(0.75, 0.6, 1.0, 0.35))
		_scene.draw_circle(Vector2(x, y), 2.0, Color(0.95, 0.9, 1.0, 0.9))
	_scene.draw_rect(Rect2(0, water.end.y - 4.0, w, 6.0), Color(0.1, 0.08, 0.18, 0.8))
	_oso_draw("sanzu_torii", Vector2(w * 0.5, h * 0.62), 3.0)
	for k: int in range(8):
		var x := 30.0 + k * (w - 60.0) / 7.0
		_oso_draw(["sai_pebbles_c", "cairn_s", "sai_pebbles_a", "cairn_m"][k % 4], Vector2(x, h * 0.86 + (k % 3) * 8.0), 2.0)
	_oso_draw("kazaguruma_b", Vector2(w * 0.22, h * 0.74), 2.0)
	_oso_draw("jizo_c", Vector2(w * 0.78, h * 0.74), 2.0)
	if _sheets.has("kuon"):
		_actor(_sheets["kuon"], Vector2(w * 0.5 - 24, h * 0.6), SpriteSheet.Dir.UP)


static func _sheet(path: String) -> SpriteSheet:
	return SpriteSheet.load_sheet(path, "dir4", Vector2(16, 16), 4)


## Desenha um personagem 2× (48 px) no painel da história.
func _actor(sheet: SpriteSheet, at: Vector2, dir: SpriteSheet.Dir) -> void:
	_scene.draw_texture_rect_region(sheet.texture, Rect2(at, Vector2(48, 48)), sheet.region(0, dir))
