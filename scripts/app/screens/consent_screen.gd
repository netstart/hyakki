extends Screen
## Consentimento de privacidade (plano 17.1 e 17.5). No build com AdMob, esta tela dá
## lugar ao formulário oficial do Google UMP; aqui ela registra a escolha e explica os
## anúncios. Recusar mantém os anúncios, mas não personalizados. Reabre em Opções.

var _text: Label


func _ready() -> void:
	var margin := content_box(16.0)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 8)
	margin.add_child(col)
	col.add_child(title_label(tr("consent.title")))
	var box := panel()
	_text = wrap_label(tr("consent.text"), 560)
	box.add_child(_text)
	col.add_child(box)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.add_child(button(tr("consent.accept"), _answer.bind(true), Vector2(200, 34)))
	row.add_child(button(tr("consent.refuse"), _answer.bind(false), Vector2(200, 34)))
	col.add_child(row)
	col.add_child(label(tr("consent.policy"), 12, HORIZONTAL_ALIGNMENT_CENTER))


func _answer(personalized: bool) -> void:
	var first := not bool(SaveManager.data["consent"]["asked"])
	SaveManager.data["consent"]["asked"] = true
	SaveManager.data["consent"]["personalized"] = personalized
	SaveManager.save_profile()
	if first:
		app.after_consent()
	else:
		app.go(&"options")


func on_back() -> void:
	if bool(SaveManager.data["consent"]["asked"]):
		app.go(&"options")
