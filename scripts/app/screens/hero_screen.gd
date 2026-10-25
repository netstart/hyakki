extends Screen
## Escolha do guardião (plano 3.4): palco à esquerda com o guardião ampliado (respira, olha
## de lado), aura e partículas do elemento dele e o kanji do nome ao fundo; fila de retratos
## em molduras embaixo (bloqueados em silhueta com cadeado); painel de laca à direita com
## nome, kanji, papel, história, atributos em barras, arma inicial, Golpe da Lanterna,
## lanterna (cosmético) e "Escolher fase" em destaque. Bloqueados mostram como liberar.
##
## Efeitos seguem GfxQuality.budget("ui_fx"): 0 = parado (sem partículas nem deslize),
## 1 = aura que pulsa e poucas partículas, 2 = raios de luz e partículas cheias.

const HEADER_H := 40.0
const MARGIN := 8.0
const GAP := 6.0
const PORTRAIT_GAP := 4.0
const ATTRS: Array[String] = ["max_hp", "might", "speed", "area"]
const PIPS := 5
const SWITCH_TIME := 0.22
## Visual de cada guardião: kanji do nome, cor da aura, partículas e ícone do Golpe.
const LOOK := {
	"aki": {"kanji": "灯", "color": Color("ffb45a"), "motes": "spark", "ult": "spell/OrbLight"},
	"kenta": {"kanji": "健太", "color": Color("a58cff"), "motes": "wisp", "ult": "spell/Camouflage"},
	"hana": {"kanji": "花", "color": Color("ff9ccf"), "motes": "petal", "ult": "spell/Heal"},
	"goro": {"kanji": "吾郎", "color": Color("9fe0a8"), "motes": "smoke", "ult": "spell/Counter"},
	"rin": {"kanji": "凛", "color": Color("8fe07a"), "motes": "leaf", "ult": "items/Arrow"},
	"tora": {"kanji": "虎", "color": Color("ff8a4a"), "motes": "ember", "ult": "spell/OrbFire"},
	"yuki": {"kanji": "雪", "color": Color("a8dcff"), "motes": "snow", "ult": "spell/OrbDarkness"},
}

var _grid: HBoxContainer
var _stage: HeroStage
var _motes: MenuKit.Motes
var _panel: PanelContainer
var _name: Label
var _kanji: Label
var _role: Label
var _scroll: ScrollContainer
var _lock_box: PanelContainer
var _lock_text: Label
var _story: Label
var _attr_rows: Array[Control] = []
var _attr_bars: Array[PipBar] = []
var _bonus: Label
var _weapon_icon: TextureRect
var _weapon_name: Label
var _ult_icon: TextureRect
var _ult_name: Label
var _ult_desc: Label
var _bottom: BoxContainer
var _cosmetic: OptionButton
var _go: Button
var _selected: StringName = &""
var _portraits: Dictionary = {}
var _switch: Tween


func _ready() -> void:
	var scrim := ColorRect.new()
	scrim.color = Color(0.02, 0.012, 0.04, 0.42)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)
	MenuKit.header(self, tr("heroes.title"), "守")
	_stage = HeroStage.new()
	_stage.name = "Stage"
	add_child(_stage)
	_motes = MenuKit.Motes.new()
	_motes.name = "Motes"
	_stage.add_child(_motes)
	_grid = HBoxContainer.new()
	_grid.name = "Roster"
	_grid.add_theme_constant_override("separation", int(PORTRAIT_GAP))
	add_child(_grid)
	_build_panel()
	add_child(back_button())
	resized.connect(_layout)
	MenuKit.on_quality_change(self, _apply_quality)


func on_show() -> void:
	for child: Node in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_portraits.clear()
	for id: StringName in DB.ids("heroes"):
		var p := Portrait.new()
		p.setup(id, MetaProgress.is_hero_unlocked(id))
		p.pressed.connect(_select.bind(id))
		_grid.add_child(p)
		_portraits[id] = p
	_cosmetic.clear()
	_cosmetic.add_item(tr("cosmetic.default"))
	_cosmetic.set_item_metadata(0, "")
	for c: Variant in SaveManager.data["unlocked"]["cosmetics"]:
		_cosmetic.add_item(tr("cosmetic.%s" % c))
		_cosmetic.set_item_metadata(_cosmetic.item_count - 1, String(c))
		if String(c) == String(app.selection.get("cosmetic", "")):
			_cosmetic.selected = _cosmetic.item_count - 1
	# Só a lanterna comum: o seletor some (nada a escolher).
	_cosmetic.get_parent().visible = _cosmetic.item_count > 1
	_selected = &""
	var current := StringName(String(app.selection.get("hero", "aki")))
	_select(current if DB.heroes.has(current) and MetaProgress.is_hero_unlocked(current) else &"aki")
	_layout()
	_apply_quality()
	_go.grab_focus.call_deferred()


func _select(id: StringName) -> void:
	if not DB.heroes.has(id):
		return
	var previous := _selected
	_selected = id
	var data: Dictionary = DB.heroes[id]
	var unlocked := MetaProgress.is_hero_unlocked(id)
	var look: Dictionary = LOOK.get(String(id), LOOK["aki"])
	for key: StringName in _portraits:
		(_portraits[key] as Portrait).set_selected(key == id)
	var order := DB.ids("heroes")
	var direction := signf(order.find(id) - order.find(previous)) if previous != &"" else 0.0
	_stage.show_hero(id, data, unlocked, look, direction)
	_motes.configure(String(look["motes"]), Color(look["color"]), _mote_count() if unlocked else 0)
	_name.text = tr("hero.%s.name" % id)
	_kanji.text = String(look["kanji"])
	_role.text = tr("hero.%s.role" % id)
	_story.text = tr("hero.%s.story" % id)
	var mods: Dictionary = data.get("modifiers", {})
	for i: int in ATTRS.size():
		_attr_bars[i].setup(_attr_level(float(mods.get(ATTRS[i], 0.0))), Color(look["color"]))
	_bonus.text = tr("heroes.bonus") % _bonus_text(id, data)
	var weapon := String(data["weapon"])
	_weapon_icon.texture = UiIcons.skill_icon("weapons", weapon)
	_weapon_name.text = tr("weapon.%s.name" % weapon)
	var ult := String(data["ultimate"]["type"])
	_ult_icon.texture = _load("res://assets/art/ui/icons/%s.png" % look["ult"])
	_ult_name.text = tr("ultimate.%s.name" % ult)
	_ult_desc.text = tr("ultimate.%s.desc" % ult)
	_lock_box.visible = not unlocked
	_lock_text.text = tr("achievement.%s.desc" % data["unlock"]) if not unlocked else ""
	_go.disabled = not unlocked
	if unlocked:
		app.selection["hero"] = String(id)
	_scroll.scroll_vertical = 0
	if previous != &"" and previous != id:
		AudioManager.play_ui("ui_move")
		_animate_panel(direction)


## Barras de 5: 3 é o normal; cada 10% a mais ou a menos sobe ou desce uma.
static func _attr_level(mod: float) -> int:
	return clampi(3 + roundi(mod * 10.0), 1, PIPS)


## Bônus do herói: os modificadores em texto ("+10% Área") ou a descrição própria.
func _bonus_text(id: StringName, data: Dictionary) -> String:
	var mods: Dictionary = data.get("modifiers", {})
	return LevelUpSystem.describe_stats(mods) if not mods.is_empty() else tr("hero.%s.bonus" % id)


func selected_hero() -> StringName:
	return _selected


func _mote_count() -> int:
	return [0, 14, 36][clampi(MenuKit.ui_fx(), 0, 2)]


func _apply_quality() -> void:
	if _selected == &"":
		return
	var look: Dictionary = LOOK.get(String(_selected), LOOK["aki"])
	_motes.configure(String(look["motes"]), Color(look["color"]),
			_mote_count() if MetaProgress.is_hero_unlocked(_selected) else 0)
	_stage.fx = MenuKit.ui_fx()
	_stage.queue_redraw()


func _animate_panel(direction: float) -> void:
	if _switch != null and _switch.is_valid():
		_switch.kill()
	var content := _panel.get_child(0) as Control
	if MenuKit.ui_fx() == 0:
		content.modulate.a = 1.0
		return
	_switch = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_switch.tween_property(content, "modulate:a", 1.0, SWITCH_TIME).from(0.0)
	_switch.tween_property(_name, "position:x", 0.0, SWITCH_TIME).from(10.0 * direction)


# --- Montagem ------------------------------------------------------------------------

func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.add_theme_stylebox_override("panel", ThemeFactory.lacquer_panel(0.9))
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	_panel.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	col.add_child(head)
	var name_box := Control.new()
	name_box.custom_minimum_size.y = 26
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.clip_contents = true
	head.add_child(name_box)
	_name = MenuKit.text("", 24, Color.WHITE)
	_name.add_theme_constant_override("outline_size", 6)
	_name.add_theme_color_override("font_outline_color", MenuKit.SHADOW)
	name_box.add_child(_name)
	_name.resized.connect(func() -> void: name_box.custom_minimum_size.x = _name.size.x)
	var seal := MenuKit.seal("")
	seal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_kanji = seal.get_child(0) as Label
	head.add_child(seal)
	_role = MenuKit.text("", 12, ThemeFactory.GOLD)
	_role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_role)
	col.add_child(_rule())
	_scroll = ScrollContainer.new()
	_scroll.name = "InfoScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.scroll_deadzone = 6
	ThemeFactory.style_scrollbar(_scroll.get_v_scroll_bar())
	col.add_child(_scroll)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 5)
	_scroll.add_child(info)
	_lock_box = PanelContainer.new()
	_lock_box.add_theme_stylebox_override("panel", ThemeFactory.flat_box(Color(0.35, 0.06, 0.05, 0.75),
			Color(ThemeFactory.ACCENT, 0.7), 1, 3, Vector2(6, 3)))
	var lock_row := HBoxContainer.new()
	lock_row.add_theme_constant_override("separation", 6)
	var lock_icon := LockIcon.new()
	lock_icon.custom_minimum_size = Vector2(10, 14)
	lock_row.add_child(lock_icon)
	var lock_col := VBoxContainer.new()
	lock_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lock_col.add_theme_constant_override("separation", 0)
	lock_col.add_child(MenuKit.text(tr("heroes.unlock_label"), 12, ThemeFactory.ACCENT))
	_lock_text = MenuKit.text("", 12, ThemeFactory.TEXT)
	_lock_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lock_col.add_child(_lock_text)
	lock_row.add_child(lock_col)
	_lock_box.add_child(lock_row)
	info.add_child(_lock_box)
	_story = MenuKit.text("", 12, Color(ThemeFactory.TEXT, 0.88))
	_story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_story)
	var features := HBoxContainer.new()
	features.name = "Features"
	features.add_theme_constant_override("separation", 8)
	info.add_child(features)
	var weapon := _feature(tr("heroes.weapon_label"))
	_weapon_icon = weapon[0]
	_weapon_name = weapon[1]
	features.add_child(weapon[2])
	var ult := _feature(tr("heroes.ultimate_label"))
	_ult_icon = ult[0]
	_ult_name = ult[1]
	features.add_child(ult[2])
	_ult_desc = MenuKit.text("", 12, Color(ThemeFactory.TEXT, 0.7))
	_ult_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_ult_desc)
	var attrs := GridContainer.new()
	attrs.name = "Attributes"
	attrs.columns = 2
	attrs.add_theme_constant_override("h_separation", 12)
	attrs.add_theme_constant_override("v_separation", 2)
	info.add_child(attrs)
	var attr_names := [tr("heroes.attr_hp"), tr("heroes.attr_might"), tr("heroes.attr_speed"), tr("heroes.attr_area")]
	for i: int in ATTRS.size():
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 4)
		var l := MenuKit.text(attr_names[i], 12, ThemeFactory.MUTED)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var bar := PipBar.new()
		row.add_child(bar)
		attrs.add_child(row)
		_attr_rows.append(row)
		_attr_bars.append(bar)
	_bonus = MenuKit.text("", 12, Color("9fe0a8"))
	_bonus.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_bonus)
	_bottom = HBoxContainer.new()
	_bottom.name = "Bottom"
	_bottom.add_theme_constant_override("separation", 6)
	col.add_child(_bottom)
	var lantern := HBoxContainer.new()
	lantern.add_theme_constant_override("separation", 4)
	lantern.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lantern_label := MenuKit.text(tr("heroes.lantern_label"), 12, ThemeFactory.MUTED)
	lantern.add_child(lantern_label)
	_cosmetic = OptionButton.new()
	_cosmetic.name = "Lantern"
	_cosmetic.custom_minimum_size = Vector2(0, 30)
	_cosmetic.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cosmetic.fit_to_longest_item = false
	MenuKit.apply_option(_cosmetic)
	_cosmetic.item_selected.connect(func(index: int) -> void:
		app.selection["cosmetic"] = String(_cosmetic.get_item_metadata(index)))
	lantern.add_child(_cosmetic)
	_bottom.add_child(lantern)
	_go = button(tr("heroes.next"), func() -> void: app.go(&"stages"), Vector2(0, 32))
	_go.name = "Go"
	_go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	MenuKit.apply_primary(_go, 16)
	_bottom.add_child(_go)


## Linha "ícone emoldurado + legenda + nome": [ícone, nome, linha, coluna de texto].
func _feature(caption: String) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", ThemeFactory.flat_box(Color(0.02, 0.01, 0.02, 0.9),
			Color(ThemeFactory.GOLD, 0.7), 1, 3, Vector2(2, 2)))
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(24, 24)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.add_child(icon)
	row.add_child(frame)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	var cap := MenuKit.text(caption, 12, ThemeFactory.MUTED)
	cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(cap)
	var value := MenuKit.text("", 12, ThemeFactory.ACCENT)
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(value)
	row.add_child(col)
	return [icon, value, row, col]


func _rule() -> Control:
	var line := ColorRect.new()
	line.color = Color(ThemeFactory.ACCENT, 0.35)
	line.custom_minimum_size = Vector2(0, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


## Posições: palco e retratos à esquerda, painel à direita; tudo cabe de 480x270 a 678x305.
func _layout() -> void:
	if _stage == null:
		return
	var w := size.x
	var h := size.y
	var left_w := roundf(clampf(w * 0.44, 200.0, 320.0))
	var count := maxi(1, _grid.get_child_count())
	var frame := floorf((left_w - MARGIN * 2.0 - PORTRAIT_GAP * (count - 1)) / count)
	frame = clampf(frame, 26.0, 36.0)
	var roster_w := frame * count + PORTRAIT_GAP * (count - 1)
	_grid.position = Vector2(roundf((left_w - roster_w) * 0.5), h - MARGIN - frame)
	_grid.size = Vector2(roster_w, frame)
	for child: Node in _grid.get_children():
		(child as Control).custom_minimum_size = Vector2(frame, frame)
	_stage.position = Vector2(0, HEADER_H - 4)
	_stage.size = Vector2(left_w, _grid.position.y - _stage.position.y - 2)
	_motes.position = Vector2.ZERO
	_motes.size = _stage.size
	_panel.position = Vector2(left_w + 2, HEADER_H + 2)
	_panel.size = Vector2(w - left_w - 2 - MARGIN, h - HEADER_H - 2 - MARGIN)
	var narrow := _panel.size.x < 300.0
	_name.add_theme_font_size_override("font_size", 16 if narrow else 24)
	_go.add_theme_font_size_override("font_size", 12 if narrow else 16)
	_stage.queue_redraw()


func _load(path: String) -> Texture2D:
	return load(path) as Texture2D if path != "" and ResourceLoader.exists(path) else null


# --- Peças desenhadas ----------------------------------------------------------------

## Palco do guardião: kanji gigante ao fundo, raios e aura na cor do herói, pedestal de
## pedra com aro de ouro e o sprite ampliado (respira e olha para os lados). Bloqueado:
## silhueta escura com contorno de luz e um cadeado.
class HeroStage extends Control:
	var fx := 2
	var _sheet: SpriteSheet
	var _side := Vector2.ZERO
	var _idle_frames := 1
	var _color := Color.WHITE
	var _kanji := ""
	var _unlocked := true
	var _time := 0.0
	var _slide := 0.0
	var _alpha := 1.0
	var _tween: Tween
	var _silhouette: Array[Texture2D] = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func show_hero(id: StringName, data: Dictionary, unlocked: bool, look: Dictionary, direction: float) -> void:
		var path := String(data.get("sprite", ""))
		if String(data.get("layout", "dir4")) == "side":
			var frame: Array = data.get("frame", [16, 16])
			_sheet = SpriteSheet.load_sheet(path, "side", Vector2(float(frame[0]), float(frame[1])), 1, false,
					float(data.get("draw_scale", 1.0)))
			_side = _sheet.frame_size
			_idle_frames = maxi(1, int(data.get("idle_frames", 1)))
		else:
			_sheet = SpriteSheet.load_sheet(path, "dir4", Vector2(16, 16), 4)
			_side = Vector2.ZERO
			_idle_frames = 1
		_silhouette = MenuKit.silhouette_pair(_sheet.texture, Color(0.05, 0.04, 0.09), Color(1.0, 0.95, 0.8, 0.85))
		_color = Color(look["color"])
		_kanji = String(look["kanji"])
		_unlocked = unlocked
		set_meta("hero", id)
		if _tween != null and _tween.is_valid():
			_tween.kill()
		if fx == 0 or direction == 0.0:
			_slide = 0.0
			_alpha = 1.0
		else:
			_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_tween.tween_property(self, "_slide", 0.0, 0.26).from(26.0 * direction)
			_tween.tween_property(self, "_alpha", 1.0, 0.2).from(0.0)
		queue_redraw()

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func scale_factor() -> float:
		return clampf(floorf(size.y / 42.0), 3.0, 5.0)

	## Retângulo do sprite desenhado (para os testes).
	func hero_rect() -> Rect2:
		var k := scale_factor()
		var cell := _side if _side != Vector2.ZERO else Vector2(16, 16)
		var feet := Vector2(roundf(size.x * 0.5), roundf(size.y * 0.76))
		return Rect2(feet.x - cell.x * k * 0.5, feet.y - cell.y * k, cell.x * k, cell.y * k)

	func _draw() -> void:
		if _sheet == null:
			return
		var w := size.x
		var h := size.y
		var k := scale_factor()
		var feet := Vector2(roundf(w * 0.5), roundf(h * 0.76))
		var pulse := 0.5 + 0.5 * sin(_time * 2.2) if fx >= 1 else 0.5
		var light := _color if _unlocked else Color(0.55, 0.5, 0.75)
		# Kanji gigante ao fundo.
		var font := MenuKit.ja_font()
		var ks := 96 if h >= 170.0 else 72
		var kw := font.get_string_size(_kanji, HORIZONTAL_ALIGNMENT_LEFT, -1, ks).x
		var kanji_alpha := 0.07 + (0.03 * pulse if fx >= 2 else 0.0)
		draw_string(font, Vector2(roundf((w - kw) * 0.5), roundf(h * 0.18 + ks * 0.8)), _kanji,
				HORIZONTAL_ALIGNMENT_LEFT, -1, ks, Color(light, kanji_alpha))
		# Aura e raios (aditivos no desenho com alfa baixo).
		var glow := MenuKit.glow_texture()
		var aura := 70.0 + 6.0 * pulse
		draw_texture_rect(glow, Rect2(feet.x - aura, feet.y - aura * 1.15, aura * 2.0, aura * 1.8), false,
				Color(light, 0.28 + 0.1 * pulse))
		if fx >= 2 and _unlocked:
			for i: int in 7:
				var ang := -PI * 0.5 + (i - 3) * 0.24 + sin(_time * 0.4 + i) * 0.03
				var tip := feet + Vector2(cos(ang), sin(ang)) * (h * 0.85)
				var perp := Vector2(-sin(ang), cos(ang))
				var a := 0.05 + 0.03 * sin(_time * 1.3 + i * 1.7)
				draw_colored_polygon(PackedVector2Array([feet + perp * 2.0, feet - perp * 2.0, tip - perp * 10.0,
						tip + perp * 10.0]), Color(light, maxf(a, 0.0)))
		# Pedestal: disco de pedra com aro dourado e sombra.
		var ped := Rect2(feet.x - 46, feet.y - 6, 92, 18)
		_ellipse(ped.grow(3).position + Vector2(0, 4), ped.grow(3).size, Color(0, 0, 0, 0.45))
		_ellipse(ped.position + Vector2(0, 5), ped.size, Color("2a2030"))
		_ellipse(ped.position, ped.size, Color("4a3c4e"))
		_ellipse(ped.position + Vector2(6, 2), ped.size - Vector2(12, 5), Color("5c4c5e"))
		_ellipse_outline(ped.position, ped.size, Color(ThemeFactory.ACCENT, 0.75))
		_ellipse_outline(ped.position + Vector2(10, 3), ped.size - Vector2(20, 6),
				Color(light, 0.35 + 0.25 * pulse))
		# Guardião.
		var bob := 0.0 if fx == 0 else (1.0 if fposmod(_time, 1.2) >= 0.6 else 0.0)
		var cell := _side if _side != Vector2.ZERO else Vector2(16, 16)
		var dest := Rect2(feet.x - cell.x * k * 0.5 + _slide, feet.y - cell.y * k + bob, cell.x * k, cell.y * k)
		dest.position = dest.position.round()
		var src := Rect2(Vector2.ZERO, cell)
		var flip := false
		if _side != Vector2.ZERO:
			var frame := posmod(int(_time * 7.0), _idle_frames) if fx >= 1 else 0
			src = Rect2(Vector2(frame * _side.x, 0), _side)
			flip = true
		else:
			src = _sheet.region(0, _look_dir())
		var tint := Color(1, 1, 1, _alpha)
		var tex := _sheet.texture if _unlocked else _silhouette[0]
		if flip:
			draw_set_transform(dest.position + Vector2(dest.size.x, 0), 0.0, Vector2(-k, k))
			_sprite(tex, src, tint, Vector2.ZERO)
			draw_set_transform(Vector2.ZERO)
		else:
			draw_texture_rect_region(tex, dest, src, tint)
		if not _unlocked:
			if flip:
				draw_set_transform(dest.position + Vector2(dest.size.x, 0), 0.0, Vector2(-k, k))
				_sprite(_silhouette[1], src, Color(1, 1, 1, 0.75 * _alpha), Vector2.ZERO)
				draw_set_transform(Vector2.ZERO)
			else:
				draw_texture_rect_region(_silhouette[1], dest, src, Color(1, 1, 1, 0.75 * _alpha))
			var lock_at := Vector2(feet.x - 9, dest.position.y + dest.size.y * 0.35).round()
			draw_circle(lock_at + Vector2(9, 6), 13.0, Color(0, 0, 0, 0.55))
			draw_set_transform(lock_at, 0.0, Vector2(2, 2))
			MenuKit.draw_lock(self, Vector2.ZERO)
			draw_set_transform(Vector2.ZERO)

	func _sprite(tex: Texture2D, src: Rect2, tint: Color, at: Vector2) -> void:
		draw_texture_rect_region(tex, Rect2(at, src.size), src, tint)

	## Olha para a frente; de tempos em tempos vira para um lado e volta.
	func _look_dir() -> int:
		if fx == 0:
			return SpriteSheet.Dir.DOWN
		var t := fposmod(_time, 7.0)
		if t > 4.0 and t < 4.9:
			return SpriteSheet.Dir.LEFT
		if t > 5.6 and t < 6.4:
			return SpriteSheet.Dir.RIGHT
		return SpriteSheet.Dir.DOWN

	func _ellipse(at: Vector2, box: Vector2, color: Color) -> void:
		var pts := PackedVector2Array()
		var c := at + box * 0.5
		for i: int in 20:
			var a := TAU * i / 20.0
			pts.append(c + Vector2(cos(a) * box.x * 0.5, sin(a) * box.y * 0.5))
		draw_colored_polygon(pts, color)

	func _ellipse_outline(at: Vector2, box: Vector2, color: Color) -> void:
		var pts := PackedVector2Array()
		var c := at + box * 0.5
		for i: int in 25:
			var a := TAU * i / 24.0
			pts.append(c + Vector2(cos(a) * box.x * 0.5, sin(a) * box.y * 0.5))
		draw_polyline(pts, color, 1.0)


## Retrato do guardião na fila: moldura de laca com o rosto em 1:1 (pixel nítido). Escolhido:
## aro de ouro, sobe 2 px e ganha brilho. Bloqueado: silhueta com contorno e cadeado.
class Portrait extends Button:
	var hero_id: StringName
	var unlocked := true
	var _face: Texture2D
	var _pair: Array[Texture2D] = []
	var _selected := false
	var _lift := 0.0
	var _tween: Tween

	func setup(id: StringName, p_unlocked: bool) -> void:
		hero_id = id
		unlocked = p_unlocked
		name = "Portrait_%s" % id
		focus_mode = Control.FOCUS_ALL
		tooltip_text = TranslationServer.translate("hero.%s.name" % id)
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		_face = load(String(DB.heroes[id]["face"])) as Texture2D
		if not unlocked:
			_pair = MenuKit.silhouette_pair(_face, Color(0.2, 0.17, 0.3), Color(0.85, 0.8, 1.0, 0.9))
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)

	func set_selected(on: bool) -> void:
		if on == _selected:
			return
		_selected = on
		if _tween != null and _tween.is_valid():
			_tween.kill()
		if MenuKit.ui_fx() == 0 or not is_inside_tree():
			_lift = 2.0 if on else 0.0
			queue_redraw()
			return
		_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.tween_method(func(v: float) -> void:
			_lift = v
			queue_redraw(), _lift, 2.0 if on else 0.0, 0.18)

	func is_selected() -> bool:
		return _selected

	func _draw() -> void:
		var r := Rect2(Vector2(0, -roundf(_lift)), size)
		var hot := is_hovered() or has_focus()
		var border := ThemeFactory.ACCENT if _selected else Color(ThemeFactory.GOLD, 0.85 if hot else 0.45)
		if _selected:
			draw_texture_rect(MenuKit.glow_texture(), r.grow(8), false, Color(1.0, 0.75, 0.35, 0.35))
		var bg := Color("2c1a22") if unlocked else Color(0.05, 0.04, 0.08)
		draw_style_box(ThemeFactory.flat_box(bg, border, 2 if _selected else 1, 3), r)
		if _face != null:
			var inner := r.grow(-3)
			var fs := _face.get_size()
			var k := 1.0 if fs.x <= 40.0 else 0.5
			var crop := inner.size / k
			var src := Rect2((fs - crop) * 0.5 + Vector2(0, -1), crop)
			var dest := Rect2(inner.position, inner.size)
			if unlocked:
				draw_texture_rect_region(_face, dest, src, Color.WHITE if (_selected or hot) else Color(0.82, 0.8, 0.86))
			else:
				draw_texture_rect_region(_pair[0], dest, src)
				draw_texture_rect_region(_pair[1], dest, src)
				draw_set_transform(r.end - Vector2(12, 14), 0.0, Vector2.ONE)
				MenuKit.draw_lock(self, Vector2.ZERO)
				draw_set_transform(Vector2.ZERO)
		if _selected:
			draw_rect(Rect2(r.position + Vector2(r.size.x * 0.5 - 3, r.size.y + 1), Vector2(6, 2)), ThemeFactory.ACCENT)


## Barra de 5 segmentos; acima do normal (3) na cor do guardião, abaixo em vermelhão.
class PipBar extends Control:
	const COUNT := 5
	var level := 3
	var color := Color.WHITE

	func _init() -> void:
		custom_minimum_size = Vector2(COUNT * 8 - 2, 14)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func setup(p_level: int, p_color: Color) -> void:
		level = p_level
		color = p_color
		queue_redraw()

	func _draw() -> void:
		var y := roundf(size.y * 0.5 - 2)
		for i: int in COUNT:
			var r := Rect2(i * 8, y, 6, 4)
			draw_rect(r.grow(1), Color(0, 0, 0, 0.6))
			var on := i < level
			var c := Color(0.2, 0.16, 0.18)
			if on:
				c = Color("d9452f") if level < 3 else (color if i >= 3 else ThemeFactory.GOLD)
			draw_rect(r, c)
			if on:
				draw_rect(Rect2(r.position, Vector2(6, 1)), Color(1, 1, 1, 0.35))


class LockIcon extends Control:
	func _draw() -> void:
		MenuKit.draw_lock(self, Vector2(0, 1))
