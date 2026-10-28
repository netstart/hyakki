extends RefCounted
## Resultados (scripts/app/screens/results_screen.gd) em cada resolução de
## tests/device_profiles.gd (sem e com o furo da câmera de cada lado): nada cortado nem sobreposto,
## botões visíveis e dentro da tela, armas em ordem de dano com barras proporcionais,
## vitória/derrota/desistência, sem armas, muitas armas (rolagem), textos longos (todos os
## idiomas), "Dobrar ryō" só quando dá e uma vez, jingle de conquista uma vez, trava de toque
## da entrada, selo de recorde e "Reduzir flashes".
## Chamado por tests/results_layout_runner.gd (ou pelo integration_tests.gd), que passa o nó
## anfitrião e o _check.

const RESULTS_SCREEN := "res://scripts/app/screens/results_screen.gd"
const DeviceProfiles := preload("res://tests/device_profiles.gd")


## App de mentira: guarda para onde a tela mandou o jogador, sem abrir partida nem menu.
class StubApp:
	extends App
	var went: StringName = &""
	var replays: int = 0

	func go(name: StringName) -> void:
		went = name

	func play_again() -> void:
		replays += 1


var _host: Node
var _check: Callable
## Tela lógica do caso atual (tamanho do anfitrião) e a área segura (fora do furo da câmera).
## Fora do laço de resoluções (rolagem, Dobrar ryō etc.), a resolução de referência.
var _view := Rect2(Vector2.ZERO, DeviceProfiles.main_view())
var _safe := Rect2(Vector2.ZERO, DeviceProfiles.main_view())


func run(host: Node, check: Callable) -> void:
	_host = host
	_check = check
	var original := SaveManager.data
	var flashes: Variant = Settings.get_value("reduce_flashes")
	Settings.set_value("reduce_flashes", false)
	AdsManager.mock_fill = true
	for c: Dictionary in DeviceProfiles.layout_cases():
		use_case(c["view"], c["insets"])
		for lang: String in c["langs"]:
			Locale.set_language(lang, false)
			SaveManager.data = SaveManager.default_profile()
			for variant: String in ["defeat", "victory", "gave_up"]:
				# Todos os idiomas no caso mais cheio (derrota); os mais longos em todos os casos.
				if variant != "defeat" and lang not in ["de", "ru", "fr", "pt_BR"]:
					continue
				for count: int in [6, 0, 10]:
					var r := make_result(variant, count)
					var opened := await _open(r)
					var state := "%s [%s], %s, %d armas" % [lang, c["label"], variant, count]
					check_layout(opened, state)
					_check_variant(opened, r, variant, state)
					_check_weapons(opened, r, state)
					_close(opened)
					await host.get_tree().process_frame
	use_case(DeviceProfiles.main_view(), Vector2.ZERO)
	Locale.set_language("pt_BR", false)
	SaveManager.data = SaveManager.default_profile()
	await _test_scroll()
	await _test_double()
	await _test_achievement_sound()
	await _test_guard_and_count()
	await _test_record()
	await _test_calm()
	await _test_actions()
	Settings.set_value("reduce_flashes", flashes)
	SaveManager.data = original
	Locale.set_language("pt_BR", false)


## Tela lógica e recorte da câmera (esquerda, direita) usados por _open e check_layout.
func use_case(view: Vector2, insets: Vector2) -> void:
	_view = Rect2(Vector2.ZERO, view)
	_safe = DeviceProfiles.safe_rect(view, insets)
	DeviceProfiles.simulate_insets(insets)


## Resultado de exemplo como o HyakkiGame.build_result + MetaProgress.apply_run.
static func make_result(variant: String, weapons: int) -> Dictionary:
	var rows: Array[Dictionary] = []
	var ids := DB.ids("weapons")
	for i: int in range(weapons):
		var id := ids[i % ids.size()]
		# Ordem embaralhada de propósito: a tela é que ordena por dano.
		var damage := float(((i * 7) % 11 + 1) * 1375 + i)
		rows.append({"id": String(id), "level": 1 + i % 8, "damage": damage, "dps": damage / 600.0})
	var victory := variant == "victory"
	return {"victory": victory, "gave_up": variant == "gave_up", "hero": "aki", "stage": "village",
			"mode": "normal", "moon": 3, "time": 600.0 if victory else 431.5, "level": 27, "kills": 12345,
			"ryo_earned": 1234, "weapons": rows,
			"new_achievements": [&"ach_win_village", &"ach_unscathed", &"ach_win_moon3"] if victory else [&"ach_first_steps"],
			"damage_taken": {"total": 345.0, "top": ["tanuki", "slime_rice"], "cause": "slime_rice"},
			"endless": false, "daily": false, "doubled": false, "prev_best_time": 0.0}


## Tudo visível dentro da tela, sem sobreposição; textos e botões inteiros; o que está nas
## áreas roláveis fica alcançável rolando (dentro da largura visível).
func check_layout(screen: Control, state: String) -> void:
	var controls: Array[Control] = []
	_controls_in(screen, controls)
	_check.call(controls.size() >= 16, "%s: a tela mostra os controles (%d)" % [state, controls.size()])
	var columns: Array[Rect2] = []
	for name: String in ["Left", "Center", "Right"]:
		var column := screen.get_node(name) as Control
		var rect := column.get_global_rect()
		_check.call(_safe.encloses(rect), "%s: coluna %s dentro da tela (%s em %s)" % [state, name, rect, _safe])
		_check.call(column.get_combined_minimum_size().y <= rect.size.y + 0.5,
				"%s: coluna %s cabe na altura (%s)" % [state, name, column.get_combined_minimum_size()])
		for other: Rect2 in columns:
			_check.call(not other.intersects(rect), "%s: coluna %s não cobre outra" % [state, name])
		columns.append(rect)
	for control: Control in controls:
		var rect := control.get_global_rect()
		var path := "%s \"%s\" (%s)" % [control.get_class(), _text(control), rect]
		var scroll := _scroll_of(control)
		if scroll != null:
			var content := scroll.get_child(0) as Control
			var local := Rect2(rect.position - content.get_global_rect().position, rect.size)
			_check.call(local.position.x >= -0.5 and local.end.x <= scroll.size.x + 0.5
					and local.position.y >= -0.5 and local.end.y <= content.size.y + 0.5,
					"%s: %s alcançável rolando" % [state, path])
		else:
			_check.call(_safe.encloses(rect), "%s: %s dentro da tela" % [state, path])
		_check_text_fits(control, state, path)
	# Sem sobreposição entre textos e botões da mesma região (fixa ou a mesma rolagem).
	for i: int in range(controls.size()):
		for j: int in range(i + 1, controls.size()):
			var a := controls[i]
			var b := controls[j]
			if a.is_ancestor_of(b) or b.is_ancestor_of(a) or _scroll_of(a) != _scroll_of(b):
				continue
			var overlap := a.get_global_rect().grow(-0.5).intersects(b.get_global_rect().grow(-0.5))
			_check.call(not overlap, "%s: \"%s\" e \"%s\" não se sobrepõem (%s, %s)" % [state, _text(a),
					_text(b), a.get_global_rect(), b.get_global_rect()])
	# Botões: o principal e o menu visíveis, ativos, inteiros e com os textos que o E2E toca.
	var again := screen.get("_again") as Button
	var menu := screen.get("_menu") as Button
	for b: Button in [again, menu]:
		_check.call(b.is_visible_in_tree() and not b.disabled and _safe.encloses(b.get_global_rect())
				and b.size.y >= 22.0, "%s: botão \"%s\" visível e ativo" % [state, b.text])
	_check.call(again.text == tr("results.again") and menu.text == tr("results.menu"),
			"%s: botões com os textos results.again e results.menu" % state)
	_check.call(again.size.y > menu.size.y, "%s: o principal é o maior botão" % state)


func _check_text_fits(control: Control, state: String, path: String) -> void:
	if control is Label and (control as Label).text != "":
		var l := control as Label
		var font := l.get_theme_font("font")
		var font_size := l.get_theme_font_size("font_size")
		var needed := l.get_line_count() * font.get_height(font_size)
		_check.call(needed <= l.size.y + 0.5, "%s: %s cabe na altura (%.0f de %.0f)" % [state, path, needed, l.size.y])
		if l.autowrap_mode == TextServer.AUTOWRAP_OFF and l.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING:
			var width := font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			_check.call(width <= l.size.x + 0.5, "%s: %s cabe na largura (%.0f de %.0f)" % [state, path,
					width, l.size.x])
	if control is Button and (control as Button).text != "":
		var b := control as Button
		var minimum := b.get_combined_minimum_size()
		_check.call(minimum.x <= b.size.x + 0.5 and minimum.y <= b.size.y + 0.5,
				"%s: %s mostra o texto inteiro (%s de %s)" % [state, path, minimum, b.size])


func _check_variant(screen: Control, r: Dictionary, variant: String, state: String) -> void:
	var title := (screen.get("_title") as Label).text
	var key: String = {"victory": "results.victory", "defeat": "results.defeat", "gave_up": "results.gave_up"}[variant]
	_check.call(title == tr(key), "%s: título %s" % [state, key])
	var tip := screen.get("_tip_box") as Control
	_check.call(tip.visible == (variant != "victory"), "%s: dica só fora da vitória" % state)
	var cause := (screen.get("_cause") as Label).text
	if variant == "defeat":
		_check.call(cause == tr("results.final_blow") % tr("enemy.slime_rice.name"), "%s: golpe final" % state)
		_check.call((screen.get("_cause_icon") as TextureRect).texture != null, "%s: ícone do golpe final" % state)
	else:
		_check.call(cause == tr("results.hurt_most") % tr("boss.tanuki.name"), "%s: quem mais feriu" % state)
	var cards := 0
	for child: Node in (screen.get("_achievements") as Node).get_children():
		if child is PanelContainer:
			cards += 1
	_check.call(cards == (r["new_achievements"] as Array).size(), "%s: um cartão por conquista nova" % state)
	var tiles: Array = screen.get("_tiles")
	var shown := PackedStringArray()
	for tile: Dictionary in tiles:
		shown.append((tile["value"] as Label).text)
	_check.call(shown[0] == Screen.format_time(float(r["time"])) and shown[1] == str(int(r["level"]))
			and shown[2] == Locale.format_number(int(r["kills"])) and shown[3] == Locale.format_number(int(r["ryo_earned"])),
			"%s: números finais depois da contagem (%s)" % [state, shown])


## Linhas em ordem de dano decrescente, barra proporcional à melhor, MVP só na primeira.
func _check_weapons(screen: Control, r: Dictionary, state: String) -> void:
	var rows: Array = screen.get("_rows")
	var expected := (r["weapons"] as Array).size()
	_check.call(rows.size() == expected, "%s: uma linha por arma (%d)" % [state, rows.size()])
	var empty := screen.get("_no_weapons") as Label
	_check.call(empty.is_visible_in_tree() == (expected == 0), "%s: aviso de sem armas só quando vazio" % state)
	if rows.is_empty():
		return
	var top := float(rows[0]["damage"])
	var last := INF
	var list := screen.get("_weapon_list") as Control
	for i: int in range(rows.size()):
		var row: Dictionary = rows[i]
		var node := row["row"] as Control
		_check.call(list.get_child(i) == node, "%s: linha %d na ordem mostrada" % [state, i])
		_check.call(float(row["damage"]) <= last, "%s: linha %d em ordem de dano" % [state, i])
		last = float(row["damage"])
		var bar := row["bar"] as Control
		var want := node.size.x * float(row["damage"]) / top
		_check.call(absf(bar.size.x - want) <= 1.0, "%s: barra %d proporcional (%.0f, esperado %.0f)" % [state, i,
				bar.size.x, want])
		_check.call((node.find_child("Mvp", true, false) != null) == (i == 0), "%s: MVP só na melhor arma" % state)
		var pips := node.find_child("Pips", true, false) as Control
		var lit := 0
		for pip: Node in pips.get_children():
			if (pip as ColorRect).color.a > 0.9:
				lit += 1
		_check.call(lit == int((r["weapons"] as Array).filter(func(w: Dictionary) -> bool:
				return is_equal_approx(float(w["damage"]), float(row["damage"])))[0]["level"]),
				"%s: pips do nível da linha %d" % [state, i])


func _test_scroll() -> void:
	var screen := await _open(make_result("defeat", 10))
	var scroll := screen.get("_weapon_scroll") as ScrollContainer
	var content := scroll.get_child(0) as Control
	_check.call(content.size.y > scroll.size.y and scroll.get_v_scroll_bar().visible,
			"10 armas: o painel rola (%.0f em %.0f)" % [content.size.y, scroll.size.y])
	scroll.scroll_vertical = int(content.size.y)
	await _host.get_tree().process_frame
	await _host.get_tree().process_frame
	var rows: Array = screen.get("_rows")
	var last := (rows[rows.size() - 1]["row"] as Control).get_global_rect()
	_check.call(scroll.get_global_rect().grow(0.5).encloses(last), "10 armas: rolando, a última linha aparece inteira")
	_check.call(content.get_global_rect().end.x <= scroll.get_v_scroll_bar().get_global_rect().position.x + 0.5,
			"10 armas: a barra de rolagem não cobre as linhas")
	_close(screen)


func _test_double() -> void:
	AdsManager.auto_answer = true
	AdsManager.mock_fill = false
	var screen := await _open(make_result("defeat", 3))
	var double := screen.get("_double") as Button
	_check.call(not double.visible, "Dobrar ryō escondido sem anúncio carregado")
	_close(screen)
	AdsManager.mock_fill = true
	var none := make_result("defeat", 3)
	none["ryo_earned"] = 0
	screen = await _open(none)
	_check.call(not (screen.get("_double") as Button).visible, "Dobrar ryō escondido sem ryō ganho")
	_close(screen)
	SaveManager.data = SaveManager.default_profile()
	var r := make_result("victory", 3)
	screen = await _open(r)
	double = screen.get("_double") as Button
	_check.call(double.is_visible_in_tree() and not double.disabled, "Dobrar ryō visível com anúncio e ryō")
	check_layout(screen, "com Dobrar ryō")
	var before := SaveManager.ryo()
	double.pressed.emit()
	_check.call(double.disabled, "Dobrar ryō trava enquanto o anúncio passa")
	var waited := 0.0
	while not bool(r.get("doubled", false)) and waited < 5.0:
		await _host.get_tree().create_timer(0.1).timeout
		waited += 0.1
	await _host.get_tree().process_frame
	(screen as Object).call("skip_intro")
	await _host.get_tree().process_frame
	_check.call(bool(r["doubled"]) and int(r["ryo_earned"]) == 2468, "Dobrar ryō dobra o ganho da partida")
	_check.call(SaveManager.ryo() == before + 1234, "Dobrar ryō soma só o ganho uma vez no saldo")
	_check.call(not double.visible, "Dobrar ryō some depois de usado")
	_check.call((screen.get("_doubled_pill") as Control).is_visible_in_tree(), "selo ×2 no ryō dobrado")
	var tiles: Array = screen.get("_tiles")
	_check.call((tiles[3]["value"] as Label).text == Locale.format_number(2468), "o bloco de ryō conta até o dobro")
	screen.call("_on_double")
	await _host.get_tree().create_timer(1.0).timeout
	_check.call(SaveManager.ryo() == before + 1234 and int(r["ryo_earned"]) == 2468, "Dobrar ryō só funciona uma vez")
	check_layout(screen, "depois de dobrar")
	_close(screen)
	AdsManager.auto_answer = false


func _test_achievement_sound() -> void:
	var r := make_result("victory", 2)
	var before := int(AudioManager.request_count.get("achievement", 0))
	var screen := await _open(r)
	_check.call(int(AudioManager.request_count.get("achievement", 0)) == before + 1, "jingle de conquista toca")
	screen.call("on_show")
	screen.call("on_show")
	_check.call(int(AudioManager.request_count.get("achievement", 0)) == before + 1,
			"jingle de conquista toca só uma vez por resultado")
	_close(screen)
	var quiet := make_result("defeat", 2)
	quiet["new_achievements"] = []
	before = int(AudioManager.request_count.get("achievement", 0))
	screen = await _open(quiet)
	_check.call(int(AudioManager.request_count.get("achievement", 0)) == before, "sem conquista nova, sem jingle")
	check_layout(screen, "sem conquista nova")
	_close(screen)


## Trava de toque na entrada e contagem dos números a partir do zero.
func _test_guard_and_count() -> void:
	var screen := await _open(make_result("defeat", 4), false)
	var again := screen.get("_again") as Button
	var tiles: Array = screen.get("_tiles")
	_check.call(again.disabled and (screen.get("_menu") as Button).disabled, "botões travados logo que a tela aparece")
	_check.call((tiles[3]["value"] as Label).text == "0", "o ryō começa a contar do zero")
	var ticks := int(AudioManager.request_count.get("paper_fold", 0))
	await _host.get_tree().create_timer(0.5).timeout
	_check.call(not again.disabled, "botões liberados depois de %.1f s" % 0.4)
	await _host.get_tree().create_timer(1.2).timeout
	_check.call((tiles[3]["value"] as Label).text == Locale.format_number(1234), "a contagem termina no valor")
	_check.call(int(AudioManager.request_count.get("paper_fold", 0)) - ticks >= 3, "tique suave na contagem")
	_check.call(is_equal_approx((screen.get_node("Center") as Control).modulate.a, 1.0), "a entrada termina opaca")
	_close(screen)


func _test_record() -> void:
	var r := make_result("defeat", 2)
	r["prev_best_time"] = 300.0
	var screen := await _open(r)
	_check.call((screen.get("_record") as Control).is_visible_in_tree(), "selo de recorde ao passar o melhor tempo")
	check_layout(screen, "com recorde")
	_close(screen)
	for prev: float in [0.0, 431.5, 500.0]:
		r = make_result("defeat", 2)
		r["prev_best_time"] = prev
		screen = await _open(r)
		_check.call(not (screen.get("_record") as Control).visible, "sem selo de recorde (antes %.0f s)" % prev)
		_close(screen)


func _test_calm() -> void:
	Settings.set_value("reduce_flashes", true)
	var screen := await _open(make_result("victory", 2))
	var style := (screen.get("_again") as Button).get_theme_stylebox("normal") as StyleBoxFlat
	var alpha := style.shadow_color.a
	await _host.get_tree().create_timer(0.3).timeout
	_check.call(is_equal_approx(style.shadow_color.a, alpha), "Reduzir flashes: o botão principal não pulsa")
	_close(screen)
	Settings.set_value("reduce_flashes", false)
	screen = await _open(make_result("victory", 2))
	style = (screen.get("_again") as Button).get_theme_stylebox("normal") as StyleBoxFlat
	var values: Array[float] = []
	for k: int in range(4):
		await _host.get_tree().create_timer(0.15).timeout
		values.append(style.shadow_color.a)
	_check.call(values.max() - values.min() > 0.01, "sem Reduzir flashes, o botão principal pulsa")
	_close(screen)


func _test_actions() -> void:
	var screen := await _open(make_result("defeat", 2))
	var app := screen.get("app") as StubApp
	(screen.get("_again") as Button).pressed.emit()
	_check.call(app.replays == 1, "Jogar de novo chama app.play_again")
	(screen.get("_menu") as Button).pressed.emit()
	_check.call(app.went == &"title", "Menu volta ao título")
	app.went = &""
	screen.call("on_back")
	_check.call(app.went == &"title", "voltar do Android volta ao título")
	var found := 0
	for node: Node in screen.find_children("*", "Button", true, false):
		if (node as Button).text == tr("results.again") and (node as Button).is_visible_in_tree():
			found += 1
	_check.call(found == 1, "um único botão results.again visível (E2E)")
	_close(screen)


func _open(r: Dictionary, skip: bool = true) -> Control:
	# Anfitrião com o tamanho e o tema do jogo: a tela sozinha na árvore de testes não os tem.
	var host := Control.new()
	host.size = _view.size
	host.theme = ThemeFactory.build()
	_host.add_child(host)
	var app := StubApp.new()
	app.last_result = r
	var screen := (load(RESULTS_SCREEN) as GDScript).new() as Screen
	screen.app = app
	host.add_child(screen)
	screen.on_show()
	await _host.get_tree().process_frame
	if skip:
		screen.call("skip_intro")
	await _host.get_tree().process_frame
	await _host.get_tree().process_frame
	return screen


func _close(screen: Control) -> void:
	(screen.get("app") as Node).free()
	screen.get_parent().queue_free()


## Ancestral ScrollContainer mais próximo (ou null).
func _scroll_of(control: Control) -> ScrollContainer:
	var node := control.get_parent()
	while node != null:
		if node is ScrollContainer:
			return node as ScrollContainer
		node = node.get_parent()
	return null


func _text(control: Control) -> String:
	if control is Label:
		return (control as Label).text
	if control is Button:
		return (control as Button).text
	return control.name


## Coleta botões e textos visíveis de uma árvore de controles.
func _controls_in(node: Node, out: Array[Control]) -> void:
	for child: Node in node.get_children():
		if (child is BaseButton or child is Label) and (child as Control).is_visible_in_tree():
			out.append(child as Control)
		_controls_in(child, out)
