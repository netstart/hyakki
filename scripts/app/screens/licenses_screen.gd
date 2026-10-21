extends Screen
## Tela Licenças (plano 12.6.5): lista de todo software e asset do jogo, com filtro por
## categoria e busca; o detalhe mostra autor, licença, versão, datas, modificações e o
## texto completo (empacotado no APK, funciona offline). A seção "Motor" é gerada pelo
## próprio Godot (Engine.get_copyright_info / get_license_info).

const CATEGORIES := ["all", "engine", "art", "audio", "font", "android"]

var _list: ItemList
var _detail: RichTextLabel
var _search: LineEdit
var _filter: OptionButton
var _rows: Array[Dictionary] = []
var _shown: Array[Dictionary] = []


func _ready() -> void:
	add_child(back_button())
	var title := title_label(tr("licenses.title"))
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_left = -150
	title.offset_right = 150
	title.offset_top = 6
	add_child(title)
	var margin := content_box(42.0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	margin.add_child(col)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	_filter = OptionButton.new()
	for c: String in CATEGORIES:
		_filter.add_item(tr("licenses.cat_%s" % c))
	_filter.custom_minimum_size = Vector2(140, 28)
	_filter.item_selected.connect(func(_i: int) -> void: _apply_filter())
	bar.add_child(_filter)
	_search = LineEdit.new()
	_search.placeholder_text = tr("licenses.search")
	_search.custom_minimum_size = Vector2(200, 28)
	_search.text_changed.connect(func(_t: String) -> void: _apply_filter())
	bar.add_child(_search)
	col.add_child(bar)
	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 8)
	col.add_child(split)
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(230, 0)
	_list.item_selected.connect(_show_detail)
	split.add_child(_list)
	var box := panel()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = false
	_detail.scroll_active = true
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_detail)
	split.add_child(box)
	_load_rows()
	_apply_filter()


func _load_rows() -> void:
	_rows.clear()
	for entry: Dictionary in LicenseIndex.entries():
		_rows.append(entry)
	for comp: Dictionary in LicenseIndex.engine_components():
		comp["category"] = "engine_thirdparty"
		_rows.append(comp)


func _category_of(entry: Dictionary) -> String:
	var c := String(entry.get("category", ""))
	if c.begins_with("engine"):
		return "engine"
	if c in ["plugin", "android"]:
		return "android"
	return c


func _apply_filter() -> void:
	var wanted: String = CATEGORIES[_filter.selected]
	var query := _search.text.strip_edges().to_lower()
	_list.clear()
	_shown.clear()
	for entry: Dictionary in _rows:
		if wanted != "all" and _category_of(entry) != wanted:
			continue
		var text := "%s  [%s]" % [entry.get("name", ""), entry.get("license_id", "")]
		if not query.is_empty() and not text.to_lower().contains(query):
			continue
		_list.add_item(text)
		_shown.append(entry)
	if not _shown.is_empty():
		_list.select(0)
		_show_detail(0)


func _show_detail(index: int) -> void:
	var e := _shown[index]
	var lines: PackedStringArray = [String(e.get("name", "")), ""]
	lines.append(tr("licenses.author") % String(e.get("author", "")))
	lines.append(tr("licenses.license") % String(e.get("license_id", "")))
	if e.has("version"):
		lines.append(tr("licenses.version") % String(e["version"]))
	if e.has("downloaded_at"):
		lines.append(tr("licenses.dates") % [e["downloaded_at"], e.get("verified_at", "")])
	if e.has("modifications") and not String(e["modifications"]).is_empty():
		lines.append(tr("licenses.modifications") % String(e["modifications"]))
	if e.has("files_count"):
		lines.append(tr("licenses.used_in") % int(e["files_count"]))
	if e.has("source_url"):
		lines.append(String(e["source_url"]))
	lines.append("")
	var text := LicenseIndex.read_file(String(e.get("license_file", "")))
	if text.is_empty():
		var ids := String(e.get("license_id", "")).split(" / ")
		for id: String in ids:
			text += LicenseIndex.license_text(id) + "\n"
	if String(e.get("name", "")) == "Godot Engine":
		text = Engine.get_license_text()
	var notice := LicenseIndex.read_file(String(e.get("notice_file", "")))
	if not notice.is_empty():
		text = notice + "\n\n" + text
	lines.append(text)
	_detail.text = "\n".join(lines)
	_detail.scroll_to_line(0)


func on_back() -> void:
	app.go(&"options")
