class_name AutoPickRow
extends VBoxContainer
## Escolha automática da mão de comida/moedas (LevelUpSystem.AUTO_SETTING) no painel da pausa:
## legenda, os três segmentos Perguntar / Comida / Moedas (como na tela de Opções) e a dica da
## vida cheia. Desfaz no meio da partida o "Não perguntar mais" da tela do nível; acompanha a
## opção quando ela muda em outro lugar. A coluna da esquerda da pausa não tem altura sobrando em
## 270 de altura, então a linha fica no painel que rola.

const VALUES: Array[String] = ["", "heal", "ryo"]

var caption: Label
var hint: Label
var segments: MenuKit.Segmented


func _init() -> void:
	name = "PauseAutoPick"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 2)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption = MenuKit.text("", 12, PauseMenu.GOLD.lightened(0.15))
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(caption)
	segments = MenuKit.Segmented.new()
	segments.name = "opt_%s" % LevelUpSystem.AUTO_SETTING
	segments.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	segments.setup([[VALUES[0], ""], [VALUES[1], ""], [VALUES[2], ""]], Settings.get_value(LevelUpSystem.AUTO_SETTING))
	segments.value_changed.connect(func(v: Variant) -> void:
		Settings.set_value(LevelUpSystem.AUTO_SETTING, v)
		segments.set_value(v))
	add_child(segments)
	hint = MenuKit.text("", 12, PauseMenu.DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint)
	Settings.changed.connect(_on_setting)
	refresh()


## Textos no idioma atual e o segmento da opção gravada (chamado ao abrir a pausa).
func refresh() -> void:
	caption.text = tr("options.levelup_auto")
	hint.text = tr("options.levelup_auto_hint")
	var labels := [tr("options.levelup_auto_ask"), tr("options.levelup_auto_heal"), tr("options.levelup_auto_ryo")]
	for i: int in segments.buttons.size():
		segments.buttons[i].text = labels[i]
	sync()


func _on_setting(key: String) -> void:
	if key == LevelUpSystem.AUTO_SETTING:
		sync()


## Acende o segmento da opção gravada (só restiliza se mudou).
func sync() -> void:
	var current := String(Settings.get_value(LevelUpSystem.AUTO_SETTING))
	var index := VALUES.find(current)
	if index >= 0 and segments.selected_index() != index:
		segments.set_value(current)
