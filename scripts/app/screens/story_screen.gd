extends Screen
## História em painéis (plano 3.2 e 3.6): cenas montadas com tiles e personagens do
## próprio pacote, ampliadas, com vinheta e texto ("diorama", plano 8.6). Toque avança;
## "Pular" encerra. Não interrompe o combate: só aparece nos menus.

var _panels: Array = []
var _index: int = 0
var _text: Label
var _face: TextureRect
var _scene: Control
var _scene_id: String = ""
var _time: float = 0.0
var _nature: Texture2D
var _house: Texture2D
var _floor: Texture2D
var _sheets: Dictionary = {}


func _ready() -> void:
	_nature = load("res://assets/art/tilesets/nature.png") as Texture2D
	_house = load("res://assets/art/tilesets/house.png") as Texture2D
	_floor = load("res://assets/art/tilesets/floor.png") as Texture2D
	for key: String in ["aki", "tora"]:
		_sheets[key] = _sheet("res://assets/art/actors/heroes/%s/SpriteSheet.png" % key)
	_sheets["spirit"] = _sheet("res://assets/art/actors/enemies/spirit/SpriteSheet.png")
	_sheets["skeleton"] = _sheet("res://assets/art/actors/enemies/skeleton/SpriteSheet.png")
	_sheets["lantern"] = _sheet("res://assets/art/actors/enemies/lantern_red/SpriteSheet.png")
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
	box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	box.offset_top = -92
	box.offset_left = 20
	box.offset_right = -20
	box.offset_bottom = -10
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_face = icon_rect("", Vector2(48, 48))
	row.add_child(_face)
	_text = wrap_label("", 520)
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_text)
	box.add_child(row)
	add_child(box)
	var skip := button(tr("story.skip"), func() -> void: app.story_finished(), Vector2(80, 26))
	skip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip.offset_left = -92
	skip.offset_right = -10
	skip.offset_top = 8
	skip.offset_bottom = 34
	add_child(skip)
	var next := button(tr("story.next"), _advance, Vector2(80, 26))
	next.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	next.offset_left = -112
	next.offset_right = -28
	next.offset_top = -128
	next.offset_bottom = -100
	add_child(next)


func play(id: StringName) -> void:
	var data: Dictionary = DB.story.get(id, {})
	_panels = data.get("panels", [])
	_index = 0
	AudioManager.play_music("story")
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
	var s := 3.0
	for y: int in range(0, int(h / (16 * s)) + 1):
		for x: int in range(0, int(w / (16 * s)) + 1):
			_scene.draw_texture_rect_region(_floor, Rect2(x * 16 * s, y * 16 * s, 16 * s, 16 * s), grass)
	match _scene_id:
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
	# Noite com a luz da lanterna, ou o amanhecer.
	if dawn:
		_scene.draw_rect(Rect2(0, 0, w, h), Color(1.0, 0.75, 0.5, 0.18))
	else:
		_scene.draw_rect(Rect2(0, 0, w, h), Color(0.03, 0.02, 0.1, 0.55))
		_scene.draw_circle(Vector2(w * 0.5, h * 0.6), 90.0 + sin(_time * 4.0) * 3.0, Color(1.0, 0.8, 0.4, 0.08))
	# Vinheta.
	for k: int in range(6):
		var inset := k * 8.0
		_scene.draw_rect(Rect2(inset, inset, w - inset * 2, h - inset * 2), Color(0, 0, 0, 0.08), false, 8.0)


func on_back() -> void:
	app.story_finished()


static func _sheet(path: String) -> SpriteSheet:
	return SpriteSheet.load_sheet(path, "dir4", Vector2(16, 16), 4)


## Desenha um personagem 2× (48 px) no painel da história.
func _actor(sheet: SpriteSheet, at: Vector2, dir: SpriteSheet.Dir) -> void:
	_scene.draw_texture_rect_region(sheet.texture, Rect2(at, Vector2(48, 48)), sheet.region(0, dir))
