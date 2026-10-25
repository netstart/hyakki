extends RefCounted
## Guardiões, Opções e Diário do Guardião (e o botão "voltar") em 678x305 e 480x270, nos 11
## idiomas. Chamado por tests/integration_tests.gd e por tests/menus_layout_runner.gd.

const SIZES: Array[Vector2] = [Vector2(678, 305), Vector2(480, 270)]
const SCREENS := {
	&"heroes": "res://scripts/app/screens/hero_screen.gd",
	&"options": "res://scripts/app/screens/options_screen.gd",
	&"codex": "res://scripts/app/screens/codex_screen.gd",
	&"title": "res://scripts/app/screens/title_screen.gd",
	&"sanctuary": "res://scripts/app/screens/sanctuary_screen.gd",
	&"shop": "res://scripts/app/screens/shop_screen.gd",
	&"credits": "res://scripts/app/screens/credits_screen.gd",
	&"stages": "res://scripts/app/screens/stage_screen.gd",
}
## Variantes das capturas: "tela" ou "tela:estado".
const SHOT_VARIANTS: Array[String] = ["heroes", "heroes:locked", "options", "options:display",
		"codex", "codex:detail", "codex:bosses", "codex:kami"]

const OPTION_KEYS: Array[String] = ["language", "music_volume", "sfx_volume", "ui_volume", "damage_sounds",
		"hurt_sounds", "joystick_mode", "joystick_side", "vibration", "fps", "graphics_quality", "colorblind",
		"reduce_flashes", "damage_numbers", "hp_bar_below", "notifications", "privacy", "restore", "credits",
		"licenses", "reset", "version"]

var _host: Node
var _check: Callable


func run(host: Node, check: Callable) -> void:
	_host = host
	_check = check
	var original := SaveManager.data
	for lang: String in Locale.SUPPORTED:
		Locale.set_language(lang, false)
		for view: Vector2 in SIZES:
			var state := "%s %dx%d" % [lang, view.x, view.y]
			SaveManager.data = SaveManager.default_profile()
			await _test_heroes(view, state)
			await _test_options(view, state)
			await _test_codex(view, state)
	SaveManager.data = original
	Locale.set_language("pt_BR", false)
	await _test_hero_behaviour()
	await _test_options_behaviour()
	await _test_codex_behaviour()
	await _test_back_everywhere()


func _ok(condition: bool, label: String) -> void:
	_check.call(condition, label)


# --- Verificações comuns ---------------------------------------------------------------

## Rótulos e botões visíveis: inteiros na tela (ou na área de rolagem que os contém), sem
## texto cortado; botões com altura de toque; o "voltar" com alvo ≥ 34 e longe do título.
func check_common(screen: Control, view: Vector2, state: String) -> void:
	var area := Rect2(Vector2.ZERO, view)
	var back := find_back(screen)
	_ok(back != null and back.is_visible_in_tree(), "%s: tem o voltar" % state)
	if back != null:
		var r := back.get_global_rect()
		_ok(area.encloses(r) and r.size.y >= 34.0, "%s: voltar inteiro e com alvo ≥ 34 (%s)" % [state, r])
		var title := screen.find_child("Title", true, false) as Label
		if title != null:
			_ok(not r.intersects(title.get_global_rect()), "%s: voltar não encosta no título" % state)
			_ok(title.get_minimum_size().x <= title.size.x + 0.5 and area.encloses(title.get_global_rect()),
					"%s: título inteiro" % state)
	for node: Node in screen.find_children("*", "Label", true, false):
		var l := node as Label
		if not l.is_visible_in_tree() or l.text.strip_edges() == "":
			continue
		var clip := _clip_rect(l, area)
		var r := l.get_global_rect()
		if not clip.intersects(r):
			continue
		_ok(r.position.x >= clip.position.x - 0.5 and r.end.x <= clip.end.x + 0.5,
				"%s: rótulo \"%s\" dentro da largura (%s em %s)" % [state, l.text.left(30), r, clip])
		if l.autowrap_mode == TextServer.AUTOWRAP_OFF:
			_ok(l.get_minimum_size().x <= l.size.x + 0.5, "%s: rótulo \"%s\" sem corte" % [state, l.text.left(30)])
		else:
			_ok(l.get_line_count() <= l.get_visible_line_count(),
					"%s: rótulo \"%s\" com todas as linhas" % [state, l.text.left(30)])
	for node: Node in screen.find_children("*", "BaseButton", true, false):
		var b := node as BaseButton
		if not b.is_visible_in_tree():
			continue
		var clip := _clip_rect(b, area)
		var r := b.get_global_rect()
		if not clip.intersects(r):
			continue
		var in_scroll := clip != area
		_ok(r.position.x >= clip.position.x - 0.5 and r.end.x <= clip.end.x + 0.5
				and (in_scroll or clip.grow(0.5).encloses(r)), "%s: botão %s inteiro (%s em %s)" % [state, b.name, r, clip])
		_ok(r.size.y >= 24.0, "%s: botão %s com altura de toque (%.0f)" % [state, b.name, r.size.y])
		if b is Button and (b as Button).text != "" and (b as Button).autowrap_mode == TextServer.AUTOWRAP_OFF:
			var bt := b as Button
			var need := bt.get_theme_font("font").get_string_size(bt.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
					bt.get_theme_font_size("font_size")).x
			_ok(need <= r.size.x, "%s: texto do botão \"%s\" cabe (%.0f de %.0f)" % [state, bt.text, need, r.size.x])


## Retângulo visível de um nó: a tela, ou a área de rolagem que o contém.
func _clip_rect(node: Control, area: Rect2) -> Rect2:
	var p := node.get_parent()
	while p != null and p is Control:
		if p is ScrollContainer:
			return (p as Control).get_global_rect().intersection(area)
		p = p.get_parent()
	return area


static func find_back(screen: Node) -> Button:
	for node: Node in screen.find_children("*", "Button", true, false):
		if node is MenuKit.BackButton:
			return node as Button
	return null


# --- Guardiões ------------------------------------------------------------------------

func _test_heroes(view: Vector2, state: String) -> void:
	for locked: bool in [false, true]:
		if locked:
			SaveManager.data["unlocked"]["heroes"] = ["aki"]
		var screen := await open_screen(_host, view, &"heroes")
		var st := "Guardiões %s%s" % [state, " bloqueados" if locked else ""]
		var grid := screen.get("_grid") as Control
		_ok(grid.get_child_count() == DB.ids("heroes").size(), "%s: um retrato por guardião" % st)
		var rects: Array[Rect2] = []
		for child: Node in grid.get_children():
			var r := (child as Control).get_global_rect()
			_ok(Rect2(Vector2.ZERO, view).encloses(r) and r.size.x >= 26.0, "%s: retrato %s inteiro" % [st, child.name])
			for o: Rect2 in rects:
				_ok(not o.intersects(r), "%s: retratos sem sobrepor" % st)
			rects.append(r)
		var ids := DB.ids("heroes")
		var picks: Array[StringName] = [ids[0], ids[ids.size() - 1], &"goro"]
		if locked:
			picks = ids
		for id: StringName in picks:
			screen.call("_select", id)
			await _host.get_tree().process_frame
			await _host.get_tree().process_frame
			var unlocked := MetaProgress.is_hero_unlocked(id)
			var sub := "%s %s" % [st, id]
			var panel := screen.get("_panel") as Control
			var go := screen.get("_go") as Button
			_ok(Rect2(Vector2.ZERO, view).encloses(panel.get_global_rect()), "%s: painel inteiro" % sub)
			_ok(panel.get_global_rect().encloses(go.get_global_rect()), "%s: Escolher fase no painel" % sub)
			_ok(go.disabled != unlocked, "%s: Escolher fase só liberado" % sub)
			_ok((screen.get("_lock_box") as Control).visible != unlocked, "%s: condição só no bloqueado" % sub)
			var stage := screen.get("_stage") as Control
			var hero_rect: Rect2 = stage.call("hero_rect")
			_ok(Rect2(Vector2.ZERO, stage.size).encloses(hero_rect), "%s: guardião inteiro no palco" % sub)
			_ok(not stage.get_global_rect().intersects(panel.get_global_rect()), "%s: palco fora do painel" % sub)
			for r: Rect2 in rects:
				_ok(not r.intersects(panel.get_global_rect()), "%s: retratos fora do painel" % sub)
			check_common(screen, view, sub)
		close_screen(screen)
		await _host.get_tree().process_frame
		SaveManager.data["unlocked"]["heroes"] = SaveManager.default_profile()["unlocked"]["heroes"]


func _test_hero_behaviour() -> void:
	SaveManager.data = SaveManager.default_profile()
	SaveManager.data["unlocked"]["heroes"] = ["aki", "kenta"]
	var screen := await open_screen(_host, SIZES[0], &"heroes")
	var app := screen.get("app") as App
	screen.call("_select", &"kenta")
	_ok(String(app.selection["hero"]) == "kenta", "Guardiões: escolher Kenta vale")
	var portraits: Dictionary = screen.get("_portraits")
	_ok((portraits[&"kenta"] as Control).call("is_selected") and not (portraits[&"aki"] as Control).call("is_selected"),
			"Guardiões: só o retrato escolhido fica destacado")
	(portraits[&"yuki"] as Button).pressed.emit()
	_ok(screen.call("selected_hero") == &"yuki" and String(app.selection["hero"]) == "kenta",
			"Guardiões: tocar num bloqueado mostra, mas não escolhe")
	_ok((screen.get("_go") as Button).disabled, "Guardiões: bloqueado desliga Escolher fase")
	_ok((screen.get("_lock_text") as Label).text == TranslationServer.translate("achievement.ach_boss_red_oni.desc"),
			"Guardiões: bloqueado mostra a condição")
	for level: int in [GfxQuality.LOW, GfxQuality.MEDIUM, GfxQuality.HIGH]:
		GfxQuality.set_override(level)
		Settings.changed.emit(GfxQuality.changed_signal_key())
		screen.call("_select", &"aki")
		var motes := screen.get("_motes") as MenuKit.Motes
		_ok(motes.count == [0, 14, 36][level], "Guardiões: partículas por nível (%d: %d)" % [level, motes.count])
		_ok(int((screen.get("_stage") as Control).get("fx")) == level, "Guardiões: palco segue ui_fx ao vivo")
	GfxQuality.clear_override()
	_ok(screen.call("_attr_level", 0.2) == 5 and screen.call("_attr_level", -0.1) == 2
			and screen.call("_attr_level", 0.0) == 3, "Guardiões: barras de atributo por modificador")
	close_screen(screen)
	await _host.get_tree().process_frame


## Abre a tela `name` num retângulo `view`, com o tema e (opcional) o fundo dos menus.
func open_screen(host: Node, view: Vector2, name: StringName, backdrop: bool = false) -> Control:
	var area := Control.new()
	area.theme = ThemeFactory.build()
	area.size = view
	area.clip_contents = true
	host.add_child(area)
	if backdrop:
		area.add_child(MenuBackdrop.new())
		rich_profile()
	var app := App.new()
	app.selection = (SaveManager.data["selected"] as Dictionary).duplicate()
	area.set_meta("app", app)
	var screen := (load(SCREENS[name]) as GDScript).new() as Screen
	screen.app = app
	area.add_child(screen)
	await host.get_tree().process_frame
	screen.on_show()
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	return screen


func prepare_variant(host: Node, screen: Control, variant: String) -> void:
	var state := variant.get_slice(":", 1) if variant.contains(":") else ""
	match state:
		"locked":
			var all: Array = (SaveManager.data["unlocked"]["heroes"] as Array).duplicate()
			SaveManager.data["unlocked"]["heroes"] = ["aki", "kenta"]
			screen.call("on_show")
			await host.get_tree().process_frame
			screen.call("_select", &"yuki")
			SaveManager.data["unlocked"]["heroes"] = all
		"display":
			if screen.has_method("show_section"):
				screen.call("show_section", 2, false)
		"bosses", "kami":
			screen.call("open_category", StringName(state), false)
			screen.call("open_entry", 1)
		"detail":
			if screen.has_method("open_entry"):
				screen.call("open_entry", 0)
	await host.get_tree().process_frame


func close_screen(screen: Control) -> void:
	var area := screen.get_parent()
	var app := area.get_meta("app") as App
	area.queue_free()
	if app != null:
		app.free()


# --- Opções ---------------------------------------------------------------------------



func _test_options(view: Vector2, state: String) -> void:
	var screen := await open_screen(_host, view, &"options")
	var st := "Opções %s" % state
	var scroll := screen.get("_scroll") as ScrollContainer
	_ok(scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED and scroll.scroll_deadzone > 0,
			"%s: rola só na vertical, com zona morta" % st)
	var rail := screen.get("_rail") as Control
	var tabs: Array = screen.get("_tabs")
	_ok(tabs.size() == 6, "%s: seis abas" % st)
	for t: Button in tabs:
		_ok(Rect2(Vector2.ZERO, view).encloses(t.get_global_rect()) and t.size.y >= 28.0, "%s: aba %s inteira" % [st, t.name])
		_ok(not t.get_global_rect().intersects(scroll.get_global_rect()), "%s: aba %s fora da rolagem" % [st, t.name])
	_ok(rail.get_global_rect().end.y <= view.y, "%s: trilho cabe na altura" % st)
	var controls: Array[Control] = []
	for key: String in OPTION_KEYS:
		var c := screen.find_child("opt_%s" % key, true, false) as Control
		_ok(c != null, "%s: tem opt_%s" % [st, key])
		if c != null:
			controls.append(c)
	var area := scroll.get_global_rect()
	var interactive: Array[Control] = []
	for c: Control in controls:
		if c is BaseButton or c is Range:
			interactive.append(c)
	for i: int in interactive.size():
		var a := interactive[i].get_global_rect()
		_ok(a.position.x >= area.position.x - 0.5 and a.end.x <= area.end.x + 0.5,
				"%s: %s não passa da largura" % [st, interactive[i].name])
		for j: int in range(i + 1, interactive.size()):
			_ok(not a.grow(-0.5).intersects(interactive[j].get_global_rect().grow(-0.5)),
					"%s: %s não encosta em %s" % [st, interactive[i].name, interactive[j].name])
	for i: int in 6:
		screen.call("show_section", i, false)
		await _host.get_tree().process_frame
		_ok(screen.call("current_section") == i, "%s: aba %d leva à seção" % [st, i])
		check_common(screen, view, "%s seção %d" % [st, i])
	for c: Control in controls:
		scroll.ensure_control_visible(c)
		await _host.get_tree().process_frame
		_ok(area.grow(0.5).encloses(c.get_global_rect()), "%s: %s alcançável pela rolagem" % [st, c.name])
	close_screen(screen)
	await _host.get_tree().process_frame


func _test_options_behaviour() -> void:
	Locale.set_language("pt_BR", false)
	var screen := await open_screen(_host, SIZES[0], &"options")
	var key := GfxQuality.changed_signal_key()
	var preview := screen.find_child("QualityPreview", true, false) as Control
	for mode: String in ["low", "medium", "high"]:
		Settings.set_value(key, mode)
		await _host.get_tree().process_frame
		_ok(preview.call("level_shown") == GfxQuality.MODE_LEVEL[mode],
				"Opções: prévia acompanha a qualidade %s ao vivo" % mode)
	var desc := preview.find_child("Description", true, false) as Label
	_ok(desc.text == TranslationServer.translate("options.gfx_desc_high"), "Opções: prévia descreve o nível Alta")
	Settings.set_value(key, "auto")
	var seg := screen.find_child("opt_fps", true, false) as MenuKit.Segmented
	seg.buttons[2].pressed.emit()
	_ok(int(Settings.get_value("fps")) == 120 and seg.selected_index() == 2, "Opções: segmento 120 grava fps")
	_ok((screen.find_child("opt_fps_hint", true, false) as Label).text == TranslationServer.translate("options.fps120"),
			"Opções: dica do fps acompanha a escolha")
	seg.buttons[1].pressed.emit()
	var side := screen.find_child("opt_joystick_side", true, false) as MenuKit.Segmented
	side.buttons[1].pressed.emit()
	_ok(String(Settings.get_value("joystick_side")) == "right", "Opções: lado do joystick pelo segmento")
	side.buttons[0].pressed.emit()
	var toggle := screen.find_child("opt_vibration", true, false) as CheckButton
	var before := bool(Settings.get_value("vibration"))
	toggle.button_pressed = not before
	_ok(bool(Settings.get_value("vibration")) != before, "Opções: chave grava a opção")
	toggle.button_pressed = before
	var slider := screen.find_child("opt_music_volume", true, false) as HSlider
	slider.value = 0.35
	_ok(is_equal_approx(float(Settings.get_value("music_volume")), 0.35)
			and (screen.find_child("opt_music_volume_value", true, false) as Label).text == "35%",
			"Opções: barra de volume grava e mostra a porcentagem")
	var chips := screen.find_child("opt_language", true, false) as Control
	_ok(chips.get_child_count() == Locale.SUPPORTED.size(), "Opções: um chip por idioma")
	screen.call("show_section", 5, false)
	await _host.get_tree().process_frame
	_ok(screen.call("current_section") == 5, "Opções: Outros abre pela aba")
	var scroll := screen.get("_scroll") as ScrollContainer
	scroll.scroll_vertical = 0
	await _host.get_tree().process_frame
	await _host.get_tree().process_frame
	_ok(screen.call("current_section") == 0, "Opções: rolar ao topo acende Áudio")
	var reset := screen.find_child("opt_reset", true, false) as Button
	SaveManager.data["ryo"] = 77
	reset.pressed.emit()
	_ok(reset.text == TranslationServer.translate("options.reset_confirm") and SaveManager.ryo() == 77,
			"Opções: o primeiro toque em apagar só pede confirmação")
	reset.pressed.emit()
	_ok(reset.text == TranslationServer.translate("options.reset_done") and SaveManager.ryo() == 0,
			"Opções: o segundo toque apaga o progresso")
	close_screen(screen)
	await _host.get_tree().process_frame


# --- Diário --------------------------------------------------------------------------

func _test_codex(view: Vector2, state: String) -> void:
	rich_profile()
	var screen := await open_screen(_host, view, &"codex")
	var st := "Diário %s" % state
	var book := screen.get("_book") as Control
	_ok(Rect2(Vector2.ZERO, view).encloses(book.get_global_rect()), "%s: livro inteiro" % st)
	var left := screen.get("_left") as Control
	var right := screen.get("_right") as Control
	_ok(not left.get_global_rect().intersects(right.get_global_rect()), "%s: páginas lado a lado" % st)
	var chip := screen.find_child("Progress", true, false) as Control
	var tabs: Array = screen.get("_tabs")
	for id: StringName in screen.get("CATEGORIES"):
		screen.call("open_category", id, false)
		await _host.get_tree().process_frame
		await _host.get_tree().process_frame
		var sub := "%s %s" % [st, id]
		var cards: Array = screen.call("cards")
		_ok(cards.size() == (screen.call("entries") as Array).size() and cards.size() > 0, "%s: um cartão por entrada" % sub)
		for t: Button in tabs:
			_ok(Rect2(Vector2.ZERO, view).encloses(t.get_global_rect()) and t.size.y >= 24.0
					and not t.get_global_rect().intersects(chip.get_global_rect()), "%s: marcador %s inteiro" % [sub, t.name])
		var grid_area := (screen.get("_grid_scroll") as Control).get_global_rect()
		for c: Button in cards:
			var r := c.get_global_rect()
			_ok(r.position.x >= grid_area.position.x - 0.5 and r.end.x <= grid_area.end.x + 0.5,
					"%s: cartão dentro da página" % sub)
		var entries: Array = screen.call("entries")
		for i: int in [0, entries.size() - 1]:
			screen.call("open_entry", i)
			await _host.get_tree().process_frame
			check_common(screen, view, "%s entrada %d" % [sub, i])
	close_screen(screen)
	await _host.get_tree().process_frame


func _test_codex_behaviour() -> void:
	SaveManager.data = SaveManager.default_profile()
	(SaveManager.data["stats"]["kills_by_enemy"] as Dictionary)["slime_rice"] = 150
	(SaveManager.data["stats"]["kills_by_enemy"] as Dictionary)["bat"] = 5
	var screen := await open_screen(_host, SIZES[0], &"codex")
	var entries: Array = screen.call("entries")
	var known: Array = entries.filter(func(e: Dictionary) -> bool: return bool(e["known"]))
	_ok(known.size() >= 1 and known.size() < entries.size(), "Diário: só os yōkai vistos ficam conhecidos")
	var unknown := entries.find(entries.filter(func(e: Dictionary) -> bool: return not bool(e["known"]))[0])
	screen.call("open_entry", unknown)
	_ok((screen.get("_name") as Label).text == "???", "Diário: desconhecido aparece como ???")
	screen.call("open_entry", 0)
	_ok((screen.get("_name") as Label).text == TranslationServer.translate("enemy.slime_rice.name")
			and (screen.get("_lore") as Label).text == TranslationServer.translate("enemy.slime_rice.lore"),
			"Diário: 100 abates liberam a lore")
	var total: Array = screen.call("discovered_total")
	_ok(total[1] > total[0] and (screen.find_child("ProgressText", true, false) as Label).text.contains(str(total[0])),
			"Diário: contador x/y descobertos")
	screen.call("open_category", &"story", false)
	await _host.get_tree().process_frame
	screen.call("open_entry", 0)
	var replay := screen.find_child("Replay", true, false) as Button
	_ok(replay == null or not replay.is_visible_in_tree(), "Diário: introdução não vista não tem rever")
	SaveManager.data["story"]["intro_seen"] = true
	screen.call("open_category", &"enemies", false)
	screen.call("open_category", &"story", false)
	screen.call("open_entry", 0)
	await _host.get_tree().process_frame
	replay = screen.find_child("Replay", true, false) as Button
	_ok(replay != null and replay.is_visible_in_tree(), "Diário: introdução vista tem Rever")
	for level: int in [GfxQuality.LOW, GfxQuality.HIGH]:
		GfxQuality.set_override(level)
		screen.call("open_category", &"kami")
		await _host.get_tree().create_timer(0.5).timeout
		_ok(screen.call("category") == &"kami" and (screen.call("cards") as Array).size() == DB.ids("kami").size()
				and is_equal_approx((screen.get("_left") as Control).scale.x, 1.0),
				"Diário: virar a página termina na categoria nova (nível %d)" % level)
		screen.call("open_category", &"weapons")
		await _host.get_tree().create_timer(0.5).timeout
	GfxQuality.clear_override()
	close_screen(screen)
	await _host.get_tree().process_frame


# --- Voltar --------------------------------------------------------------------------

## O mesmo "voltar" em toda tela que o usa: placa de laca, alvo ≥ 34, mesma posição; tocar
## chama on_back (vai ao título).
func _test_back_everywhere() -> void:
	SaveManager.data = SaveManager.default_profile()
	for name: StringName in [&"heroes", &"options", &"codex", &"sanctuary", &"shop", &"credits", &"stages"]:
		for view: Vector2 in SIZES:
			var screen := await open_screen(_host, view, name)
			var back := find_back(screen)
			var st := "Voltar %s %dx%d" % [name, view.x, view.y]
			_ok(back != null, "%s: usa o voltar único" % st)
			if back == null:
				close_screen(screen)
				continue
			var r := back.get_global_rect()
			_ok(r.position.is_equal_approx(Vector2(4, 2)) and r.size.y >= 34.0 and r.size.x >= 48.0,
					"%s: posição e alvo de toque (%s)" % [st, r])
			_ok(back.text == TranslationServer.translate("menu.back"), "%s: texto Voltar" % st)
			var font := back.get_theme_font("font")
			var need := font.get_string_size(back.text, HORIZONTAL_ALIGNMENT_LEFT, -1, back.get_theme_font_size("font_size")).x
			_ok(need + 30.0 <= r.size.x, "%s: texto inteiro na placa" % st)
			var top := screen.get_child(screen.get_child_count() - 1)
			_ok(top == back, "%s: voltar por cima de tudo" % st)
			close_screen(screen)
			await _host.get_tree().process_frame
	for lang: String in Locale.SUPPORTED:
		Locale.set_language(lang, false)
		var b := MenuKit.BackButton.new(TranslationServer.translate("menu.back"))
		_host.add_child(b)
		await _host.get_tree().process_frame
		b.size = b.get_combined_minimum_size()
		var need := b.get_theme_font("font").get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		_ok(need + 30.0 <= b.size.x + 0.5 and b.size.y >= 34.0, "Voltar %s: cabe o texto" % lang)
		b.queue_free()
	Locale.set_language("pt_BR", false)


## Perfil com progresso (capturas e testes do Diário): abates, chefes, conquistas e história.
static func rich_profile() -> void:
	var d := SaveManager.data
	var kills: Dictionary = d["stats"]["kills_by_enemy"]
	var ids := DB.ids("enemies")
	for i: int in ids.size():
		if i % 3 != 2:
			kills[String(ids[i])] = 150 if i % 2 == 0 else 12
	var bosses := DB.ids("bosses")
	for i: int in 4:
		(d["stats"]["bosses_defeated"] as Dictionary)[String(bosses[i])] = 1
	var ach := DB.ids("achievements")
	for i: int in 12:
		(d["achievements"] as Dictionary)[String(ach[i])] = 1
	d["story"]["intro_seen"] = true
	d["story"]["ending_seen"] = true
	(d["stats"]["evolved"] as Array).append_array(["dawn_blade", "steel_storm"])
	d["unlocked"]["heroes"] = ["aki", "kenta", "hana", "goro", "rin"]
