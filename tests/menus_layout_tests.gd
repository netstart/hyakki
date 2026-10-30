extends RefCounted
## Guardiões, Opções e Diário do Guardião (e o botão "voltar") em cada resolução de
## tests/device_profiles.gd, sem e com o furo da câmera de cada lado, nos 11 idiomas. Chamado
## por tests/integration_tests.gd e por tests/menus_layout_runner.gd.

const DeviceProfiles := preload("res://tests/device_profiles.gd")
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
		"codex", "codex:detail", "codex:bosses", "codex:kami", "codex:recipe", "codex:evolution", "codex:relic"]

const OPTION_KEYS: Array[String] = ["language", "music_volume", "sfx_volume", "ui_volume", "damage_sounds",
		"hurt_sounds", "joystick_mode", "joystick_side", "vibration", "fps", "graphics_quality", "colorblind",
		"reduce_flashes", "damage_numbers", "damage_show_hit", "damage_show_high", "damage_show_crit",
		"damage_show_dot", "damage_show_taken", "damage_show_taken_heavy", "damage_show_heal", "hp_bar_below",
		"notifications", "dialogues_always", "tips", "privacy", "restore", "credits",
		"licenses", "privacy_policy", "reset", "version"]

var _host: Node
var _check: Callable
## Recorte da câmera (esquerda, direita) do caso atual; textos e botões ficam fora dele.
var _insets := Vector2.ZERO


## Casos de tela: cada resolução de tests/device_profiles.gd, sem e com o furo da câmera.
static func cases() -> Array[Dictionary]:
	return DeviceProfiles.layout_cases()


## Resolução de referência (os testes de comportamento rodam nela).
static func main_view() -> Vector2:
	return DeviceProfiles.main_view()


func run(host: Node, check: Callable) -> void:
	_host = host
	_check = check
	var original := SaveManager.data
	for c: Dictionary in cases():
		use_insets(c["insets"])
		var view: Vector2 = c["view"]
		for lang: String in c["langs"]:
			Locale.set_language(lang, false)
			var state := "%s [%s]" % [lang, c["label"]]
			SaveManager.data = SaveManager.default_profile()
			await _test_heroes(view, state)
			await _test_options(view, state)
			await _test_codex(view, state)
	use_insets(Vector2.ZERO)
	SaveManager.data = original
	Locale.set_language("pt_BR", false)
	await _test_hero_behaviour()
	await _test_options_behaviour()
	await _test_codex_behaviour()
	await _test_codex_recipes()
	await _test_back_everywhere()
	await _test_real_app()


func _ok(condition: bool, label: String) -> void:
	_check.call(condition, label)


## Liga o recorte simulado da câmera (MenuKit.safe_insets) para as próximas telas.
func use_insets(insets: Vector2) -> void:
	_insets = insets
	DeviceProfiles.simulate_insets(insets)


## Área segura de uma tela `view` com o recorte atual.
func _area(view: Vector2) -> Rect2:
	return DeviceProfiles.safe_rect(view, _insets)


# --- Verificações comuns ---------------------------------------------------------------

## Rótulos e botões visíveis: inteiros na tela (ou na área de rolagem que os contém), sem
## texto cortado; botões com altura de toque; o "voltar" com alvo ≥ 34 e longe do título.
func check_common(screen: Control, view: Vector2, state: String) -> void:
	var area := _area(view)
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
			_ok(_area(view).encloses(r) and r.size.x >= 26.0, "%s: retrato %s inteiro" % [st, child.name])
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
			_ok(_area(view).encloses(panel.get_global_rect()), "%s: painel inteiro" % sub)
			_ok(_area(view).encloses(go.get_global_rect())
					and panel.get_global_rect().end.y <= go.get_global_rect().position.y,
					"%s: Escolher fase na base, abaixo do painel" % sub)
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
	var screen := await open_screen(_host, main_view(), &"heroes")
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
		"recipe", "evolution", "relic":
			# Receitas com ícones: Katana (base), Lâmina da Aurora (evolução e união) e Jade (relíquia de duas armas).
			var target: Array = {"recipe": [&"weapons", &"katana"], "evolution": [&"weapons", &"dawn_blade"],
					"relic": [&"relics", &"jade"]}[state]
			screen.call("open_category", target[0], false)
			screen.call("open_entry", screen.call("index_of", target[1]))
	await host.get_tree().process_frame


func close_screen(screen: Control) -> void:
	var area := screen.get_parent()
	var app := area.get_meta("app") as App
	area.queue_free()
	if app != null:
		app.free()


# --- Opções ---------------------------------------------------------------------------



## Opções num tamanho e idioma (também usado pelo tests/ads_off_tests.gd no modo sem anúncios).
func run_options(host: Node, check: Callable, view: Vector2, state: String, insets := Vector2.ZERO) -> void:
	_host = host
	_check = check
	use_insets(insets)
	await _test_options(view, state)
	use_insets(Vector2.ZERO)


## Chaves esperadas: sem anúncios não há "privacy"; "restore" só some sem loja de dinheiro (o
## resto, inclusive a política de privacidade, aparece sempre).
static func expected_option_keys() -> Array[String]:
	var keys: Array[String] = []
	for key: String in OPTION_KEYS:
		if key == "privacy" and not AdsManager.ads_enabled:
			continue
		if key == "restore" and not PurchaseManager.billing_available():
			continue
		keys.append(key)
	return keys


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
		_ok(_area(view).encloses(t.get_global_rect()) and t.size.y >= 28.0, "%s: aba %s inteira" % [st, t.name])
		_ok(not t.get_global_rect().intersects(scroll.get_global_rect()), "%s: aba %s fora da rolagem" % [st, t.name])
	_ok(rail.get_global_rect().end.y <= view.y, "%s: trilho cabe na altura" % st)
	var controls: Array[Control] = []
	for key: String in expected_option_keys():
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
	var screen := await open_screen(_host, main_view(), &"options")
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
	# Política de privacidade: pede ao abridor exatamente a URL publicada (sem abrir o navegador).
	var opened: Array[String] = []
	var options_script := load(SCREENS[&"options"]) as GDScript
	options_script.set("url_opener", func(url: String) -> void: opened.append(url))
	(screen.find_child("opt_privacy_policy", true, false) as Button).pressed.emit()
	options_script.set("url_opener", Callable())
	_ok(opened == ["https://netstart.github.io/privacy-policy.html"],
			"Opções: Política de privacidade pede a URL publicada (%s)" % [opened])
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
	_ok(_area(view).encloses(book.get_global_rect()), "%s: livro inteiro" % st)
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
			_ok(_area(view).encloses(t.get_global_rect()) and t.size.y >= 24.0
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
		if id in [&"weapons", &"relics"]:
			await _test_codex_recipe_layout(screen, view, sub)
	close_screen(screen)
	await _host.get_tree().process_frame


func _test_codex_behaviour() -> void:
	SaveManager.data = SaveManager.default_profile()
	(SaveManager.data["stats"]["kills_by_enemy"] as Dictionary)["slime_rice"] = 150
	(SaveManager.data["stats"]["kills_by_enemy"] as Dictionary)["bat"] = 5
	var screen := await open_screen(_host, main_view(), &"codex")
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


# --- Diário: receitas com ícones --------------------------------------------------------

## Tamanho do chip das receitas, lido do script do Diário.
static func recipe_chip_size() -> int:
	return int((load(SCREENS[&"codex"]) as GDScript).get_script_constant_map()["CHIP"])


## Comprimento aproximado de uma receita na tela (modelo + nomes + chips), para escolher as
## mais longas de cada idioma.
static func recipe_length(entry: Dictionary) -> int:
	var total := 0
	for line: Dictionary in entry.get("recipe", []):
		total += String(line["text"]).length() + 4
		for ref: Dictionary in line["refs"]:
			total += String(ref["name"]).length() + 3
	return total


## Entradas da categoria atual com receita, das mais longas para as mais curtas (até `count`).
static func longest_recipes(entries: Array, count: int) -> Array[int]:
	var idx: Array[int] = []
	for i: int in entries.size():
		if not (entries[i].get("recipe", []) as Array).is_empty():
			idx.append(i)
	idx.sort_custom(func(a: int, b: int) -> bool: return recipe_length(entries[a]) > recipe_length(entries[b]))
	return idx.slice(0, count)


## Layout das receitas na categoria aberta (armas ou relíquias): as mais longas com o perfil do
## caso (há itens desconhecidos, chip "?") e com tudo descoberto (todos os nomes, os mais longos).
func _test_codex_recipe_layout(screen: Control, view: Vector2, sub: String) -> void:
	var stats: Dictionary = SaveManager.data["stats"]
	var evolved: Array = (stats["evolved"] as Array).duplicate()
	var unions: Array = (stats.get("unions", []) as Array).duplicate()
	var unlocked: Array = (SaveManager.data["unlocked"].get("passives", []) as Array).duplicate()
	for full: bool in [false, true]:
		if full:
			for w: StringName in DB.ids("weapons"):
				var kind := String(DB.weapon(w).get("kind", "base"))
				if kind == "evolution":
					(stats["evolved"] as Array).append(String(w))
				elif kind == "union":
					if not stats.has("unions"):
						stats["unions"] = []
					(stats["unions"] as Array).append(String(w))
			for p: StringName in DB.ids("passives"):
				(SaveManager.data["unlocked"]["passives"] as Array).append(String(p))
		screen.call("_fill_page")
		var entries: Array = screen.call("entries")
		for i: int in longest_recipes(entries, 2 if full else 1):
			screen.call("open_entry", i)
			await _host.get_tree().process_frame
			await _host.get_tree().process_frame
			check_recipe(screen, view, "%s receita %s%s" % [sub, entries[i]["id"], " (tudo descoberto)" if full else ""])
	stats["evolved"] = evolved
	stats["unions"] = unions
	SaveManager.data["unlocked"]["passives"] = unlocked
	screen.call("_fill_page")


## A receita (texto rico com chips) inteira na página: dentro da largura da área de rolagem e
## fora do recorte, sem linha cortada (fit_content), cada linha com a altura do chip, abaixo da
## descrição e acima dos números, sem sobrepor; e o resto da página continua sem corte.
func check_recipe(screen: Control, view: Vector2, st: String) -> void:
	var recipe := screen.get("_recipe") as RichTextLabel
	_ok(recipe != null and recipe.is_visible_in_tree() and recipe.get_line_count() >= 1, "%s: receita visível" % st)
	if recipe == null or not recipe.is_visible_in_tree():
		return
	var scroll := screen.get("_detail_scroll") as Control
	var clip := scroll.get_global_rect().intersection(_area(view))
	var r := recipe.get_global_rect()
	_ok(r.position.x >= clip.position.x - 0.5 and r.end.x <= clip.end.x + 0.5,
			"%s: receita dentro da largura (%s em %s)" % [st, r, clip])
	_ok(recipe.get_content_width() <= r.size.x + 0.5,
			"%s: nenhuma linha da receita passa da largura (%d de %.0f)" % [st, recipe.get_content_width(), r.size.x])
	_ok(recipe.get_content_height() <= r.size.y + 0.5,
			"%s: receita com todas as linhas (%d de %.0f)" % [st, recipe.get_content_height(), r.size.y])
	var chip := recipe_chip_size()
	_ok(recipe.get_content_height() >= recipe.get_line_count() * chip,
			"%s: cada linha comporta o chip de %d px (%d linhas, %d px)" % [st, chip, recipe.get_line_count(),
			recipe.get_content_height()])
	var lore := screen.get("_lore") as Label
	_ok(lore.get_global_rect().end.y <= r.position.y + 0.5, "%s: receita abaixo da descrição" % st)
	var stats := screen.get("_stats") as Label
	if stats.is_visible_in_tree():
		_ok(r.end.y <= stats.get_global_rect().position.y + 0.5, "%s: receita acima dos números" % st)
	check_common(screen, view, st)


## Receitas: toda arma base com evolução mostra a relíquia e a evolução; toda evolução, a base,
## a relíquia e as uniões de que participa; toda união, o par; toda relíquia, as armas que faz
## evoluir. Ícones existem e viram chips de 18x18 pixel perfeitos; o desconhecido sai em
## silhueta com "???"; tocar num chip abre a entrada do item (mesma categoria ou virando a página).
func _test_codex_recipes() -> void:
	SaveManager.data = SaveManager.default_profile()
	GfxQuality.set_override(GfxQuality.LOW)
	var screen := await open_screen(_host, main_view(), &"codex")
	var script := screen.get_script() as GDScript
	var chip := recipe_chip_size()
	screen.call("open_category", &"weapons", false)
	await _host.get_tree().process_frame
	var entries: Array = screen.call("entries")
	_ok(entries.size() == DB.ids("weapons").size(), "Receitas: uma entrada por arma")
	var bad_icons: Array[String] = []
	var wrong: Array[String] = []
	var unknown_named: Array[String] = []
	for e: Dictionary in entries:
		var w := StringName(String(e["id"]))
		var expected := _expected_recipe(w)
		var got: Array = []
		for line: Dictionary in e["recipe"]:
			var pair: Array = []
			for ref: Dictionary in line["refs"]:
				pair.append([String(ref["category"]), String(ref["id"])])
				var path := String(ref["icon"])
				var tex: Texture2D = script.call("recipe_chip", path, bool(ref["known"]))
				if not ResourceLoader.exists(path) or tex == null or tex.get_size() != Vector2(chip, chip):
					bad_icons.append(path)
				var known := _ref_known(String(ref["category"]), String(ref["id"]))
				if bool(ref["known"]) != known or (String(ref["name"]) == "???") == known:
					unknown_named.append("%s→%s" % [w, ref["id"]])
			_ok(String(line["text"]).count("%s") == pair.size(), "Receitas %s: um %%s por chip" % w)
			got.append(pair)
		if got != expected:
			wrong.append("%s: %s != %s" % [w, got, expected])
	_ok(wrong.is_empty(), "Receitas: parceiro e resultado certos em toda arma %s" % [wrong])
	_ok(bad_icons.is_empty(), "Receitas: todo ícone citado existe e vira chip de %d px %s" % [chip, bad_icons])
	_ok(unknown_named.is_empty(), "Receitas: desconhecido como ???, conhecido com nome %s" % [unknown_named])
	var katana := int(screen.call("index_of", &"katana"))
	var dawn := TranslationServer.translate("weapon.dawn_blade.name")
	screen.call("open_entry", katana)
	await _host.get_tree().process_frame
	var recipe := screen.get("_recipe") as RichTextLabel
	var text := recipe.get_parsed_text()
	_ok(recipe.is_visible_in_tree() and text.contains(TranslationServer.translate("passive.sake.name"))
			and text.contains("???") and not text.contains(dawn),
			"Receitas: Katana mostra Saquê e a evolução ainda desconhecida como ??? (%s)" % text)
	_ok(not (screen.get("_lore") as Label).text.contains("???"), "Receitas: a descrição fica só com a descrição")
	(SaveManager.data["stats"]["evolved"] as Array).append("dawn_blade")
	screen.call("_fill_page")
	screen.call("open_entry", katana)
	await _host.get_tree().process_frame
	_ok(recipe.get_parsed_text().contains(dawn) and not recipe.get_parsed_text().contains("???"),
			"Receitas: evolução descoberta mostra o nome")
	# Chips: conhecido copia o miolo do ícone 1:1; desconhecido é a silhueta com "?".
	var icon_path := UiIcons.skill_path("weapons", "katana")
	var icon := (load(icon_path) as Texture2D).get_image()
	icon.decompress()
	icon.convert(Image.FORMAT_RGBA8)
	var known_chip := (script.call("recipe_chip", icon_path, true) as Texture2D).get_image()
	var unknown_chip := (script.call("recipe_chip", icon_path, false) as Texture2D).get_image()
	var same := true
	for y: int in range(1, chip - 1):
		for x: int in range(1, chip - 1):
			same = same and known_chip.get_pixel(x, y).is_equal_approx(icon.get_pixel(x + 3, y + 3))
	_ok(same and known_chip.get_pixel(0, 0).a == 0.0, "Receitas: chip conhecido é o miolo do ícone em escala 1")
	var ink := 0
	for y: int in chip:
		for x: int in chip:
			ink += int(unknown_chip.get_pixel(x, y).is_equal_approx(script.get_script_constant_map()["CHIP_UNKNOWN_INK"]))
	_ok(ink >= 8 and not unknown_chip.get_pixel(9, 9).is_equal_approx(known_chip.get_pixel(9, 9)),
			"Receitas: chip desconhecido em silhueta com \"?\" (%d px de tinta)" % ink)
	# Relíquia bloqueada: a receita da arma esconde o nome dela; a página da relíquia não mostra receita.
	var raijin := int(screen.call("index_of", &"raijin"))
	var rosary_ref: Dictionary = (entries[raijin]["recipe"] as Array)[0]["refs"][0]
	_ok(String(rosary_ref["id"]) == "rosary" and not bool(rosary_ref["known"]) and String(rosary_ref["name"]) == "???",
			"Receitas: relíquia bloqueada (Rosário) aparece como ???")
	# Tocar num chip: outra categoria vira a página e abre o item; na mesma, abre direto.
	screen.call("_on_recipe_meta", {"category": &"relics", "id": "sake"})
	await _host.get_tree().process_frame
	_ok(screen.call("category") == &"relics" and int(screen.call("selected")) == int(screen.call("index_of", &"sake"))
			and (screen.get("_name") as Label).text == TranslationServer.translate("passive.sake.name"),
			"Receitas: tocar em Saquê abre a relíquia")
	var relics: Array = screen.call("entries")
	var sake: Dictionary = relics[int(screen.call("index_of", &"sake"))]
	var sake_lines: Array = sake["recipe"]
	_ok(sake_lines.size() == 1 and String(sake_lines[0]["refs"][0]["id"]) == "katana"
			and String(sake_lines[0]["refs"][1]["id"]) == "dawn_blade", "Receitas: Saquê evolui Katana em Lâmina da Aurora")
	var multi := 0
	for r: Dictionary in relics:
		multi = maxi(multi, (r.get("recipe", []) as Array).size())
	_ok(multi >= 2 and recipe.is_visible_in_tree(), "Receitas: relíquia de várias armas lista todas (%d)" % multi)
	var rosary: Dictionary = relics[int(screen.call("index_of", &"rosary"))]
	_ok(not bool(rosary["known"]) and (rosary["recipe"] as Array).is_empty(), "Receitas: relíquia bloqueada sem receita")
	screen.call("_on_recipe_meta", {"category": &"weapons", "id": "katana"})
	await _host.get_tree().process_frame
	_ok(screen.call("category") == &"weapons" and int(screen.call("selected")) == katana, "Receitas: e volta à Katana")
	screen.call("_on_recipe_meta", {"category": &"weapons", "id": "dawn_blade"})
	_ok(int(screen.call("selected")) == int(screen.call("index_of", &"dawn_blade")),
			"Receitas: na mesma categoria abre direto")
	screen.call("open_category", &"enemies", false)
	await _host.get_tree().process_frame
	_ok(not recipe.is_visible_in_tree(), "Receitas: yōkai não têm receita")
	GfxQuality.clear_override()
	close_screen(screen)
	await _host.get_tree().process_frame


## Receita esperada de uma arma, direto dos dados: [[[categoria, id], [categoria, id]], ...].
func _expected_recipe(w: StringName) -> Array:
	var data := DB.weapon(w)
	var out: Array = []
	match String(data.get("kind", "base")):
		"base":
			if data.has("evolution"):
				out.append([["relics", String(data["evolves_with"])], ["weapons", String(data["evolution"])]])
		"evolution":
			var base := String(data["from"])
			out.append([["weapons", base], ["relics", String(DB.weapon(StringName(base))["evolves_with"])]])
			for u: StringName in DB.ids("weapons"):
				var parts: Array = DB.weapon(u).get("requires", [])
				if parts.has(String(w)):
					out.append([["weapons", String(parts[0] if String(parts[1]) == String(w) else parts[1])],
							["weapons", String(u)]])
		"union":
			out.append([["weapons", String(data["requires"][0])], ["weapons", String(data["requires"][1])]])
	return out


func _ref_known(category: String, id: String) -> bool:
	if category == "relics":
		return MetaProgress.is_content_available("passives", StringName(id), DB.passives[StringName(id)])
	var stats: Dictionary = SaveManager.data["stats"]
	return String(DB.weapon(StringName(id)).get("kind", "base")) == "base" or (stats["evolved"] as Array).has(id) \
			or (stats.get("unions", []) as Array).has(id)


# --- Voltar --------------------------------------------------------------------------

## O mesmo "voltar" em toda tela que o usa: placa de laca, alvo ≥ 34, mesma posição; tocar
## chama on_back (vai ao título).
func _test_back_everywhere() -> void:
	SaveManager.data = SaveManager.default_profile()
	for name: StringName in [&"heroes", &"options", &"codex", &"sanctuary", &"shop", &"credits", &"stages"]:
		for c: Dictionary in cases():
			use_insets(c["insets"])
			var view: Vector2 = c["view"]
			var screen := await open_screen(_host, view, name)
			var back := find_back(screen)
			var st := "Voltar %s [%s]" % [name, c["label"]]
			_ok(back != null, "%s: usa o voltar único" % st)
			if back == null:
				close_screen(screen)
				continue
			var r := back.get_global_rect()
			_ok(r.position.is_equal_approx(Vector2(4.0 + _insets.x, 2)) and r.size.y >= 34.0 and r.size.x >= 48.0,
					"%s: posição e alvo de toque (%s)" % [st, r])
			_ok(_area(view).encloses(r), "%s: voltar fora do furo da câmera (%s)" % [st, r])
			_ok(back.text == TranslationServer.translate("menu.back"), "%s: texto Voltar" % st)
			var font := back.get_theme_font("font")
			var need := font.get_string_size(back.text, HORIZONTAL_ALIGNMENT_LEFT, -1, back.get_theme_font_size("font_size")).x
			_ok(need + 30.0 <= r.size.x, "%s: texto inteiro na placa" % st)
			var top := screen.get_child(screen.get_child_count() - 1)
			_ok(top == back, "%s: voltar por cima de tudo" % st)
			close_screen(screen)
			await _host.get_tree().process_frame
	use_insets(Vector2.ZERO)
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


## Pelo caminho real do jogo (App → go), num viewport de cada resolução lógica de
## tests/device_profiles.gd (stretch "viewport", k = round(altura / 300)).
## Pega o que o host de tamanho fixo não pega: o App cria a tela escondida e o painel media
## alto antes da 1ª largura (o "Escolher fase" ficava fora da tela no aparelho).
func _test_real_app() -> void:
	for c: Dictionary in cases():
		use_insets(c["insets"])
		var view: Vector2 = c["view"]
		for lang: String in ["en", "pt_BR", "ru", "ja"]:
			if lang not in c["langs"]:
				continue
			Locale.set_language(lang, false)
			SaveManager.data = SaveManager.default_profile()
			var vp := SubViewport.new()
			vp.size = Vector2i(view)
			vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
			_host.add_child(vp)
			var app := App.new()
			vp.add_child(app)
			await _host.get_tree().process_frame
			var st := "App %s [%s]" % [lang, c["label"]]
			var area := _area(view)
			for name: StringName in [&"heroes", &"options", &"codex"]:
				app.go(name)
				for i: int in 3:
					await _host.get_tree().process_frame
				var screen := (app.get("_screens") as Dictionary)[name] as Control
				_ok(screen.size.is_equal_approx(view), "%s %s: tela do tamanho do viewport" % [st, name])
				if name == &"heroes":
					for id: StringName in DB.ids("heroes"):
						screen.call("_select", id)
						await _host.get_tree().process_frame
						var go := screen.get("_go") as Button
						var panel := screen.get("_panel") as Control
						_ok(go.is_visible_in_tree() and area.encloses(go.get_global_rect()) and go.size.y >= 28.0,
								"%s %s: Escolher fase visível (%s)" % [st, id, go.get_global_rect()])
						_ok(area.encloses(panel.get_global_rect())
								and panel.get_global_rect().end.y <= go.get_global_rect().position.y,
								"%s %s: painel acima do botão (%s)" % [st, id, panel.get_global_rect()])
				check_common(screen, view, "%s %s" % [st, name])
			app.queue_free()
			vp.queue_free()
			await _host.get_tree().process_frame
	use_insets(Vector2.ZERO)
	Locale.set_language("pt_BR", false)
