class_name AbilitySheet
extends VBoxContainer
## Energia e as três habilidades de um guardião (data/abilities.json pelo DB), para a tela do
## guardião (laca escura, Style.LACQUER) e a ficha do Diário (papel, Style.PAPER):
## - "Energia": glifo emoldurado, nome na cor da energia e como ela enche e esvazia;
## - "Habilidades": por habilidade, o ícone emoldurado, o kanji, o nome, a linha "Nv 5 · 40 de
##   Sangue Oni · Recarga 13 s" (nível de liberação na partida, custo e recarga base) e a
##   descrição; a Yuki ganha o aviso do preço em vida.
## Tudo em rótulos com quebra de linha (cabe em qualquer largura e idioma); show_hero só remonta
## quando o herói ou o idioma mudam.

enum Style { LACQUER, PAPER }

const ICON := 24.0
const GLYPH := 12.0
## Idiomas com vírgula decimal (os mesmos números das descrições: "0,8 s").
const COMMA_LANGS: Array[String] = ["pt_BR", "es", "de", "fr", "ru", "id"]

var style := Style.LACQUER
var _shown := ""


func _init(p_style: Style = Style.LACQUER) -> void:
	style = p_style
	name = "AbilitySheet"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_theme_constant_override("separation", 3)


## Monta a seção do herói `id` (vazio se ele não tem habilidades).
func show_hero(id: StringName) -> void:
	var key := "%s|%s" % [id, TranslationServer.get_locale()]
	if key == _shown:
		return
	_shown = key
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	var data := DB.hero_abilities(id)
	visible = not data.is_empty()
	if data.is_empty():
		return
	var energy: Dictionary = data["energy"]
	var color := Color(String(energy.get("color", "ffffff")))
	var energy_name := TranslationServer.translate("energy.%s.name" % energy["id"])
	add_child(_caption(TranslationServer.translate("heroes.energy_label")))
	add_child(_row(String(energy.get("icon", "")), GLYPH, "", energy_name, "",
			TranslationServer.translate("energy.%s.desc" % energy["id"]), color, "Energy"))
	if float(energy.get("hp_price", 0.0)) > 0.0:
		var blood := _label(TranslationServer.translate("ability.blood_price"), _blood())
		blood.name = "BloodPrice"
		add_child(blood)
	add_child(_caption(TranslationServer.translate("heroes.abilities_label")))
	for row: Variant in data.get("abilities", []):
		var a: Dictionary = row
		var aid := String(a["id"])
		add_child(_row(String(a.get("icon", "")), ICON, String(a.get("kanji", "")),
				TranslationServer.translate("ability.%s.name" % aid), meta_line(a, energy_name),
				TranslationServer.translate("ability.%s.desc" % aid), color, "Ability_%s" % aid))


## "Nv 5 · 40 de Sangue Oni · Recarga 13 s" de uma habilidade.
static func meta_line(a: Dictionary, energy_name: String) -> String:
	return " · ".join([TranslationServer.translate("ability.locked") % int(a.get("level", 1)),
			TranslationServer.translate("ability.cost") % [int(roundf(float(a.get("cost", 0)))), energy_name],
			TranslationServer.translate("ability.cooldown") % seconds(float(a.get("cooldown", 0)))])


## Segundos sem casa inútil e com a vírgula do idioma (3,5 / 3.5 / 12).
static func seconds(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(roundi(value))
	var text := "%.1f" % value
	return text.replace(".", ",") if TranslationServer.get_locale() in COMMA_LANGS else text


func _ink() -> Color:
	return ThemeFactory.PAPER_INK if style == Style.PAPER else Color(ThemeFactory.TEXT, 0.82)


func _muted() -> Color:
	return ThemeFactory.RED_INK if style == Style.PAPER else ThemeFactory.MUTED


func _accent() -> Color:
	return ThemeFactory.RED_INK if style == Style.PAPER else ThemeFactory.ACCENT


func _blood() -> Color:
	return Color("a3141c") if style == Style.PAPER else Color("ff8a80")


func _label(value: String, color: Color, font: Font = null) -> Label:
	var l := MenuKit.text(value, 12, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if font != null:
		l.add_theme_font_override("font", font)
	if style == Style.PAPER:
		l.add_theme_constant_override("outline_size", 0)
		l.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.25))
		l.add_theme_constant_override("shadow_offset_x", 0)
		l.add_theme_constant_override("shadow_offset_y", 1)
	return l


func _caption(value: String) -> Control:
	var l := _label(value, _muted())
	l.name = "Caption"
	return l


## Ícone emoldurado e a coluna de textos: título (kanji + nome), linha de números e descrição.
func _row(icon_path: String, side: float, kanji: String, title: String, meta: String, desc: String, color: Color,
		row_name: String) -> Control:
	var row := HBoxContainer.new()
	row.name = row_name
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	var frame := PanelContainer.new()
	var bg := Color(0.02, 0.01, 0.02, 0.9) if style == Style.LACQUER else Color(0.16, 0.1, 0.07, 0.92)
	frame.add_theme_stylebox_override("panel", ThemeFactory.flat_box(bg, Color(color, 0.85), 1, 3, Vector2(2, 2)))
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(side, side)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.texture = load(icon_path) as Texture2D if icon_path != "" and ResourceLoader.exists(icon_path) else null
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(icon)
	if side < ICON:
		# Glifo 12x12 na moldura do tamanho dos ícones (as colunas de texto alinham).
		frame.custom_minimum_size = Vector2(ICON + 4.0, ICON + 4.0)
	row.add_child(frame)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	head.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_child(head)
	if kanji != "":
		var ink := ThemeFactory.GOLD if style == Style.LACQUER else ThemeFactory.PAPER_INK_SOFT
		var k := _label(kanji, ink, MenuKit.ja_font())
		k.name = "Kanji"
		k.autowrap_mode = TextServer.AUTOWRAP_OFF
		k.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		head.add_child(k)
	var t := _label(title, color.darkened(0.62) if style == Style.PAPER else color.lightened(0.25))
	t.name = "Name"
	head.add_child(t)
	if meta != "":
		var m := _label(meta, _accent())
		m.name = "Meta"
		col.add_child(m)
	var d := _label(desc, _ink())
	d.name = "Desc"
	col.add_child(d)
	return row
