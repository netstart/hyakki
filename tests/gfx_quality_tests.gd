extends RefCounted
## Qualidade gráfica com os autoloads (scripts/core/gfx_quality.gd e gfx_monitor.gd):
## - opção "graphics_quality" em Settings (padrão "auto"), troca ao vivo pelo sinal changed e
##   persistência no arquivo de opções;
## - rebaixamento adaptativo simulado: FPS baixo por 5 s desce um nível, no máximo uma vez a
##   cada 20 s, nunca sobe sozinho, só em "auto" e nunca abaixo de LOW;
## - tela de Opções: escolha "opt_graphics_quality" com Auto (nível) / Baixa / Média / Alta;
## - pausa: botão em ciclo Auto → Baixa → Média → Alta → Auto, com "Auto (nível)", e texto
##   inteiro em todos os idiomas na coluna mais estreita.
## Chamado por tests/integration_tests.gd.

const OPTIONS_SCREEN := "res://scripts/app/screens/options_screen.gd"
const PauseMenuTests := preload("res://tests/pause_menu_tests.gd")
const KEY := "graphics_quality"

var _host: Node
var _check: Callable
var _emitted: Array[String] = []


func run(host: Node, check: Callable) -> void:
	_host = host
	_check = check
	var saved: Variant = Settings.get_value(KEY)
	Settings.changed.connect(_on_changed)
	_test_setting()
	_test_adaptive()
	await _test_options()
	await _test_pause()
	Settings.changed.disconnect(_on_changed)
	GfxQuality.reset_session()
	GfxQuality.clear_override()
	Settings.set_value(KEY, saved)
	Locale.set_language("pt_BR", false)


func _on_changed(key: String) -> void:
	_emitted.append(key)


func _test_setting() -> void:
	_check.call(Settings.DEFAULTS.get(KEY) == "auto", "gfx: opção graphics_quality vem em auto")
	GfxQuality.reset_session()
	GfxQuality.set_detected(GfxQuality.MEDIUM)
	Settings.set_value(KEY, "auto")
	_check.call(GfxQuality.mode() == "auto" and GfxQuality.level() == GfxQuality.MEDIUM, "gfx: auto usa o detectado")
	_emitted.clear()
	for entry: Array in [["low", GfxQuality.LOW], ["medium", GfxQuality.MEDIUM], ["high", GfxQuality.HIGH]]:
		Settings.set_value(KEY, entry[0])
		_check.call(GfxQuality.level() == int(entry[1]), "gfx: opção %s vale ao vivo" % entry[0])
	_check.call(_emitted.count(GfxQuality.changed_signal_key()) == 3, "gfx: cada troca emite Settings.changed")
	Settings.set_value(KEY, "low")
	Settings.load_settings()
	_check.call(Settings.get_value(KEY) == "low" and GfxQuality.level() == GfxQuality.LOW,
			"gfx: opção persiste no arquivo de opções")
	var config := ConfigFile.new()
	_check.call(config.load(Settings.path) == OK and config.get_value("settings", KEY, "") == "low",
			"gfx: gravada em %s" % Settings.path)
	GfxQuality.set_override(GfxQuality.HIGH)
	_check.call(GfxQuality.level() == GfxQuality.HIGH, "gfx: override vence a opção")
	GfxQuality.clear_override()
	_check.call(GfxQuality.level() == GfxQuality.LOW, "gfx: clear_override volta à opção")


## Alimenta o monitor com `seconds` de quadros a `fps`; devolve quantos rebaixamentos houve.
func _run_monitor(monitor: GfxMonitor, seconds: float, fps: float, active: bool = true) -> int:
	var drops := 0
	var frame := 1.0 / fps
	var t := 0.0
	while t < seconds:
		if monitor.feed(frame, 60.0, active and GfxQuality.mode() == "auto") and GfxQuality.auto_downgrade():
			drops += 1
		t += frame
	return drops


func _test_adaptive() -> void:
	GfxQuality.reset_session()
	GfxQuality.set_detected(GfxQuality.HIGH)
	Settings.set_value(KEY, "auto")
	var monitor := GfxMonitor.new()
	_check.call(_run_monitor(monitor, 30.0, 58.0) == 0, "gfx: FPS bom não rebaixa")
	_check.call(_run_monitor(monitor, 4.0, 30.0) == 0, "gfx: FPS baixo por menos de 5 s não rebaixa")
	_check.call(_run_monitor(monitor, 10.0, 58.0) == 0, "gfx: FPS volta e zera a contagem")
	_emitted.clear()
	_check.call(_run_monitor(monitor, 6.5, 30.0) == 1 and GfxQuality.level() == GfxQuality.MEDIUM,
			"gfx: FPS abaixo de 80%% por 5 s desce um nível (agora %d)" % GfxQuality.level())
	_check.call(GfxQuality.changed_signal_key() in _emitted, "gfx: rebaixamento avisa por Settings.changed")
	_check.call(Settings.get_value(KEY) == "auto", "gfx: rebaixamento não mexe na opção salva")
	_check.call(_run_monitor(monitor, 12.0, 30.0) == 0, "gfx: no máximo um rebaixamento a cada 20 s")
	_check.call(_run_monitor(monitor, 10.0, 30.0) == 1 and GfxQuality.level() == GfxQuality.LOW,
			"gfx: depois de 20 s pode descer de novo")
	_check.call(_run_monitor(monitor, 60.0, 20.0) == 0 and GfxQuality.level() == GfxQuality.LOW,
			"gfx: nunca abaixo de LOW")
	_check.call(_run_monitor(monitor, 60.0, 120.0) == 0 and GfxQuality.level() == GfxQuality.LOW,
			"gfx: nunca sobe sozinho na sessão")
	_check.call(_run_monitor(monitor, 30.0, 20.0, false) == 0, "gfx: pausado não conta")
	GfxQuality.reset_session()
	GfxQuality.set_detected(GfxQuality.HIGH)
	Settings.set_value(KEY, "high")
	_check.call(_run_monitor(GfxMonitor.new(), 40.0, 20.0) == 0 and not GfxQuality.auto_downgrade()
			and GfxQuality.level() == GfxQuality.HIGH, "gfx: opção fixa nunca é rebaixada")
	monitor.free()
	_check.call(GfxMonitor.target_fps() > 0.0 and GfxMonitor.target_fps() <= float(Settings.get_value("fps")),
			"gfx: alvo do monitor vem da opção fps")
	GfxQuality.reset_session()
	GfxQuality.set_detected(GfxQuality.HIGH)
	Settings.set_value(KEY, "auto")


func _test_options() -> void:
	Locale.set_language("pt_BR", false)
	var host := Control.new()
	host.size = Vector2(678, 305)
	host.theme = ThemeFactory.build()
	_host.add_child(host)
	var screen := (load(OPTIONS_SCREEN) as GDScript).new() as Control
	host.add_child(screen)
	await _host.get_tree().process_frame
	await _host.get_tree().process_frame
	var option := screen.find_child("opt_%s" % KEY, true, false) as OptionButton
	_check.call(option != null, "gfx: Opções tem a escolha de qualidade gráfica")
	if option != null:
		_check.call(option.item_count == 4, "gfx: Opções com Auto, Baixa, Média e Alta")
		var texts: Array[String] = []
		for i: int in range(option.item_count):
			texts.append(option.get_item_text(i))
		_check.call(texts == [tr("options.gfx_auto_level") % tr("options.gfx_high"), tr("options.gfx_low"),
				tr("options.gfx_medium"), tr("options.gfx_high")], "gfx: textos das opções (%s)" % [texts])
		_check.call(str(option.get_item_metadata(option.selected)) == "auto", "gfx: Opções mostra a opção atual")
		var cell_label := option.get_parent().get_child(0) as Label
		_check.call(cell_label.text == tr("options.graphics_quality"), "gfx: rótulo Qualidade gráfica")
		option.select(2)
		option.item_selected.emit(2)
		_check.call(Settings.get_value(KEY) == "medium" and GfxQuality.level() == GfxQuality.MEDIUM,
				"gfx: escolher Média nas Opções vale na hora")
	host.queue_free()
	await _host.get_tree().process_frame
	Settings.set_value(KEY, "auto")


func _test_pause() -> void:
	var tests := PauseMenuTests.new()
	tests.set("_host", _host)
	for view: Vector2 in [Vector2(678, 305), Vector2(480, 270)]:
		for lang: String in Locale.SUPPORTED:
			await _check_pause(tests, view, lang)
	Locale.set_language("pt_BR", false)


func _check_pause(tests: RefCounted, view: Vector2, lang: String) -> void:
	Locale.set_language(lang, false)
	Settings.set_value(KEY, "auto")
	var state := "gfx %s %dx%d" % [lang, view.x, view.y]
	var menu: PauseMenu = await tests.call("open_standalone", view, PauseMenuTests.make_snapshot(true))
	var quality := menu.get("_quality") as Button
	var caption := menu.get("_quality_caption") as Label
	var value := menu.get("_quality_value") as Label
	var compact := bool(menu.get("_compact"))
	_check.call(compact == (view.y < 300.0), "%s: modo compacto só na tela baixa" % state)
	_check.call(quality != null and quality.is_visible_in_tree() and quality.size.y >= 22.0,
			"%s: pausa tem o botão de qualidade" % state)
	var font := value.get_theme_font("font")
	if not compact:
		var need := font.get_string_size(caption.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		_check.call(need <= caption.size.x + 0.5 and caption.text == tr("pause.graphics"),
				"%s: legenda inteira (%.0f de %.0f)" % [state, need, caption.size.x])
	for mode: String in GfxQuality.MODES:
		Settings.set_value(KEY, mode)
		await _host.get_tree().process_frame
		var width := font.get_string_size(value.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		_check.call(width <= value.size.x + 0.5 and quality.get_global_rect().grow(0.5).encloses(value.get_global_rect()),
				"%s: valor \"%s\" inteiro dentro do botão (%.0f de %.0f)" % [state, value.text, width, value.size.x])
	Settings.set_value(KEY, "auto")
	if lang == "pt_BR":
		var seen: Array[String] = [value.text]
		for i: int in range(4):
			quality.pressed.emit()
			seen.append(value.text)
		var auto_text := "Auto" if compact else "Auto (Alta)"
		_check.call(seen == [auto_text, "Baixa", "Média", "Alta", auto_text], "%s: ciclo na pausa (%s)" % [state, seen])
		_check.call(Settings.get_value(KEY) == "auto", "%s: ciclo volta ao auto" % state)
		Settings.set_value(KEY, "low")
		_check.call(value.text == "Baixa", "%s: pausa acompanha troca feita fora dela" % state)
	menu.get_parent().queue_free()
	await _host.get_tree().process_frame
