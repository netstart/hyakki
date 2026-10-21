extends Screen
## Créditos (plano 12.1 e 18.4): todos os autores dos assets, mesmo os CC0.
## O texto vem de licenses/index.json, gerado a partir do registro de licenças.


func _ready() -> void:
	add_child(back_button())
	var title := title_label(tr("credits.title"))
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_left = -150
	title.offset_right = 150
	title.offset_top = 6
	add_child(title)
	var margin := content_box(44.0)
	var scroll := ScrollContainer.new()
	margin.add_child(scroll)
	var text := RichTextLabel.new()
	text.fit_content = true
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(text)
	var lines: PackedStringArray = ["HYAKKI — %s" % tr("title.subtitle"), "",
			tr("credits.design"), "", tr("credits.assets")]
	for entry: Dictionary in LicenseIndex.entries():
		# Motor e bibliotecas Android ficam na linha do motor e na tela Licenças.
		if not String(entry.get("category", "")) in ["art", "audio", "font"]:
			continue
		lines.append("• %s — %s (%s)" % [entry["name"], entry["author"], entry["license_id"]])
	lines.append("")
	lines.append(tr("credits.engine"))
	lines.append("")
	lines.append(tr("credits.thanks"))
	text.text = "\n".join(lines)


func on_back() -> void:
	app.go(&"title")
