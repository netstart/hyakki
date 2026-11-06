extends RefCounted
## Tela de pausa (scripts/ui/pause_menu.gd) e botões do canto da HUD:
## - ícone de pausa (Kenney) no botão do canto, sem o "II" de texto;
## - botão de velocidade com ícone, multiplicador e cor que mudam com GameClock.speed, e o
##   "soco" de escala no toque;
## - pausa abre e fecha pelo jogo (tempo parado, contagem na volta);
## - música liga/desliga mostrando o estado (ícone e texto) com o mesmo efeito de antes;
## - "Desistir" pede confirmação ("voltar" cancela) e só então encerra a partida;
## - layout em cada resolução de tests/device_profiles.gd, sem e com o furo da câmera de cada
##   lado, e também em 640x360 (EXTRA_SIZES), nos 11 idiomas com o painel cheio (e em pt_BR, de,
##   ru e ja sem itens): tudo dentro da área segura, sem sobreposição, textos inteiros e o painel
##   alcançável rolando;
## - escolha automática da comida/moedas (AutoPickRow) no painel: grava a opção pelo segmento,
##   acompanha a opção mudada na tela do nível e desfaz o "Não perguntar mais" no meio da partida.
## Chamado por tests/pause_menu_runner.gd (ou pelo integration_tests.gd).

const GAME_SCENE := "res://scenes/game/Game.tscn"
const CONFIG := {"hero": "aki", "stage": "village", "moon": 2, "mode": "normal", "seed": 5, "speed": 1}
const LANGS: Array[String] = ["pt_BR", "de", "ru", "ja"]
## Telas a mais, além das de tests/device_profiles.gd (sem recorte): 640x360 é a mais alta,
## onde o painel sobra na vertical.
const EXTRA_SIZES: Array[Vector2] = [Vector2(640, 360)]
const DeviceProfiles := preload("res://tests/device_profiles.gd")
## Fatias da integração: a parte sem layout roda numa fatia só (TestShards.runs_rest).
const TestShards := preload("res://tests/test_shards.gd")
## Opção da qualidade gráfica (botão de ciclo da pausa).
const QUALITY_KEY := "graphics_quality"

var _host: Node
var _check: Callable
## Recorte da câmera (esquerda, direita) do caso atual; o conteúdo fica fora dele.
var _insets := Vector2.ZERO


func run(host: Node, check: Callable) -> void:
	_host = host
	_check = check
	var music: Variant = Settings.get_value("music_volume")
	var speed := GameClock.speed
	if TestShards.runs_rest(&"PauseMenuTests"):
		_test_format()
		await _test_corner_buttons()
		await _test_open_close()
		await _test_music()
		await _test_auto_pick()
		await _test_give_up()
		await _test_finish_intro()
	await _test_layouts()
	Settings.set_value("music_volume", music)
	GameClock.speed = speed
	Locale.set_language("pt_BR", false)
	GameClock.paused = true


## Mesmo formato e realce dos atributos.
func _test_format() -> void:
	_check.call(PauseMenu.format_stat("max_hp", 120.0) == "120" and PauseMenu.format_stat("might", 1.25) == "125%"
			and PauseMenu.format_stat("armor", 2.0) == "2", "atributos: inteiro para flat/vida, % para o resto")
	_check.call(PauseMenu.stat_tone("might", 1.0) == 0 and PauseMenu.stat_tone("might", 1.2) == 1
			and PauseMenu.stat_tone("cooldown", 0.9) == 1 and PauseMenu.stat_tone("cooldown", 1.1) == -1
			and PauseMenu.stat_tone("curse", 1.1) == -1 and PauseMenu.stat_tone("speed", 50.0) == -1,
			"atributos: realce acima da base, recarga menor é melhor, maldição maior é pior")


func _test_corner_buttons() -> void:
	# Com a Ampulheta de Fūjin (sem ela a velocidade fica em 1x; ver tests/speed_unlock_tests.gd).
	SaveManager.data["purchases"]["unlock_speed"] = true
	var game := await _new_game()
	var pause := game.hud.get("_pause_button") as Button
	_check.call(pause.text == "" and pause.icon != null and pause.icon.get_size() == Vector2(14, 14),
			"botão de pausa com ícone 14x14 e sem texto")
	_check.call(pause.tooltip_text == tr("hud.pause"), "botão de pausa com nome acessível")
	var rect := pause.get_global_rect()
	var icon_fits := pause.icon.get_width() <= rect.size.x - 8.0 and pause.icon.get_height() <= rect.size.y - 4.0
	_check.call(icon_fits, "ícone cabe no botão do canto (%s)", rect.size)
	_check.call(UiIcons.get_icon("fast_forward", Hud.SPEED_ICON) != null, "ícone de velocidade carrega")
	var speed_button := game.hud.get("_speed_button") as Button
	_check.call(speed_button.text == "", "botão de velocidade desenha ícone + multiplicador (sem texto cru)")
	GameClock.speed = 1
	game.hud.refresh_speed()
	_check.call(game.hud.speed_shown() == 1 and game.hud.speed_tint() == Hud.SPEED_TINT[1], "1x: cor calma")
	var presses := [0]
	game.hud.speed_pressed.connect(func() -> void: presses[0] += 1)
	speed_button.pressed.emit()
	_check.call(presses[0] == 1 and GameClock.speed == 2, "toque no botão emite speed_pressed e acelera")
	_check.call(speed_button.scale.x < 1.0, "toque dá um soco de escala no botão")
	_check.call(game.hud.speed_shown() == 2 and game.hud.speed_tint() == Hud.SPEED_TINT[2], "2x: dourado")
	await _seconds(0.3)
	_check.call(is_equal_approx(speed_button.scale.x, 1.0), "o soco volta à escala normal")
	speed_button.pressed.emit()
	_check.call(game.hud.speed_shown() == 3 and game.hud.speed_tint() == Hud.SPEED_TINT[3], "3x: vermelhão")
	_check.call(Hud.SPEED_TINT[1] != Hud.SPEED_TINT[2] and Hud.SPEED_TINT[2] != Hud.SPEED_TINT[3],
			"cada velocidade tem a sua cor")
	game.open_pause()
	var menu := game.hud.pause_menu()
	_check.call((menu.get("_speed_value") as Label).text == "3x", "a pausa mostra a velocidade atual")
	(menu.get("_speed") as Button).pressed.emit()
	_check.call(GameClock.speed == 1 and (menu.get("_speed_value") as Label).text == "1x"
			and game.hud.speed_shown() == 1, "velocidade na pausa troca e atualiza os dois botões")
	var tile_icon := ((menu.get("_speed") as Button).get_child(0).get_child(0).get_child(0)) as TextureRect
	_check.call(tile_icon.texture == UiIcons.get_icon("fast_forward", 16), "pausa usa o mesmo ícone de velocidade")
	_check.call(not (menu.get("_speed_lock") as Control).visible,
			"com a Ampulheta a pausa não mostra o cadeado")
	await _free(game)
	SaveManager.data["purchases"]["unlock_speed"] = false


func _test_open_close() -> void:
	var game := await _new_game()
	var menu := game.hud.pause_menu()
	_check.call(not game.hud.pause_open() and not menu.visible, "pausa começa fechada")
	(game.hud.get("_pause_button") as Button).pressed.emit()
	_check.call(game.hud.pause_open() and menu.visible and GameClock.paused, "botão do canto abre a pausa")
	_check.call(menu.modulate.a < 1.0, "pausa entra com fade")
	_check.call((game.hud.get("_top") as Control).modulate.a == 0.0, "HUD de jogo some sob a pausa")
	await _seconds(0.35)
	_check.call(is_equal_approx(menu.modulate.a, 1.0), "entrada termina opaca")
	var frozen := GameClock.game_time
	await _seconds(0.3)
	_check.call(is_equal_approx(frozen, GameClock.game_time), "tempo parado na pausa")
	(menu.get("_resume") as Button).pressed.emit()
	_check.call(not game.hud.pause_open(), "Continuar fecha a pausa na hora")
	_check.call(not game.hud.overlay_open(), "nenhuma tela aberta depois de continuar")
	_check.call((game.hud.get("_top") as Control).modulate.a == 1.0, "HUD de jogo volta ao continuar")
	await _seconds(0.3)
	_check.call(not menu.visible, "saída com fade termina invisível")
	await _seconds(1.8)
	_check.call(not GameClock.paused and GameClock.game_time > frozen, "o tempo volta depois da contagem")
	await _free(game)


func _test_music() -> void:
	var game := await _new_game()
	Settings.set_value("music_volume", 0.7)
	game.open_pause()
	var menu := game.hud.pause_menu()
	var button := menu.get("_music") as Button
	var icon := menu.get("_music_icon") as TextureRect
	var value := menu.get("_music_value") as Label
	_check.call(icon.texture == UiIcons.get_icon("music_on", 16) and value.text == tr("pause.on"),
			"música ligada: ícone e texto de ligada")
	button.pressed.emit()
	_check.call(float(Settings.get_value("music_volume")) == 0.0, "toque desliga a música (volume 0)")
	_check.call(icon.texture == UiIcons.get_icon("music_off", 16) and value.text == tr("pause.off"),
			"música desligada: ícone e texto mudam na hora")
	button.pressed.emit()
	_check.call(is_equal_approx(float(Settings.get_value("music_volume")), 0.7) and value.text == tr("pause.on"),
			"segundo toque religa em 0,7")
	await _free(game)


## Desfazer a escolha automática sem sair da partida: a pausa mostra a opção gravada e o segmento
## "Perguntar" volta a perguntar.
func _test_auto_pick() -> void:
	var game := await _new_game()
	Settings.set_value(LevelUpSystem.AUTO_SETTING, "ryo")
	game.open_pause()
	var row := game.hud.pause_menu().find_child("PauseAutoPick", true, false) as AutoPickRow
	_check.call(row != null and row.is_visible_in_tree() and row.segments.selected_index() == 2
			and row.segments.buttons[2].text == tr("options.levelup_auto_ryo"), "pausa mostra a escolha automática (Moedas)")
	row.segments.buttons[0].pressed.emit()
	_check.call(String(Settings.get_value(LevelUpSystem.AUTO_SETTING)) == "" and row.segments.selected_index() == 0,
			"pausa: \"Perguntar\" desfaz a escolha automática")
	row.segments.buttons[1].pressed.emit()
	_check.call(String(Settings.get_value(LevelUpSystem.AUTO_SETTING)) == "heal", "pausa: segmento Comida grava a opção")
	Settings.set_value(LevelUpSystem.AUTO_SETTING, "ryo")
	_check.call(row.segments.selected_index() == 2, "pausa acompanha a opção mudada em outro lugar")
	Settings.set_value(LevelUpSystem.AUTO_SETTING, "")
	await _free(game)


func _test_give_up() -> void:
	var game := await _new_game()
	var results: Array[Dictionary] = []
	game.finished.connect(func(r: Dictionary) -> void: results.append(r))
	game.open_pause()
	var menu := game.hud.pause_menu()
	(menu.get("_quit") as Button).pressed.emit()
	_check.call(results.is_empty() and menu.confirm_open() and game.hud.pause_open(),
			"Desistir só abre a confirmação")
	(menu.get("_resume") as Button).pressed.emit()
	_check.call(game.hud.pause_open(), "com a confirmação aberta, os botões de trás não reagem")
	game.open_pause()
	_check.call(not menu.confirm_open() and game.hud.pause_open() and results.is_empty(),
			"voltar fecha a confirmação e mantém a pausa")
	(menu.get("_quit") as Button).pressed.emit()
	(menu.get("_confirm_back") as Button).pressed.emit()
	_check.call(not menu.confirm_open() and results.is_empty(), "Voltar na confirmação cancela")
	(menu.get("_quit") as Button).pressed.emit()
	(menu.get("_confirm_quit") as Button).pressed.emit()
	_check.call(results.size() == 1 and bool(results[0]["gave_up"]), "confirmar encerra como desistência")
	_check.call(not game.hud.pause_open(), "pausa fechada ao desistir")
	await _free(game)


# --- Layout -------------------------------------------------------------------------------

## Dados de exemplo: 6 armas (uma evoluída, uma no máximo) e 6 itens, ou sem itens.
static func make_snapshot(full: bool) -> Dictionary:
	var weapons: Array[Dictionary] = []
	var base: Array[StringName] = []
	var evolved: Array[StringName] = []
	for id: StringName in DB.ids("weapons"):
		if String(DB.weapon(id).get("kind", "base")) == "base":
			base.append(id)
		else:
			evolved.append(id)
	var picks: Array[StringName] = base.slice(0, 5)
	if not evolved.is_empty():
		picks.append(evolved[0])
	for i: int in range(picks.size() if full else 2):
		var data := DB.weapon(picks[i])
		var top := maxi(1, (data.get("levels", [{}]) as Array).size())
		weapons.append({"id": picks[i], "name": TranslationServer.translate("weapon.%s.name" % picks[i]),
				"icon": String(data.get("icon", "")), "level": top if i == 1 else mini(1 + i, top), "max": top,
				"evolved": String(data.get("kind", "base")) != "base"})
	var items: Array[Dictionary] = []
	if full:
		for id: StringName in (DB.passives.keys() as Array).slice(0, 6):
			var data: Dictionary = DB.passives[id]
			items.append({"id": id, "name": TranslationServer.translate("passive.%s.name" % id),
					"icon": String(data.get("icon", "")), "level": 1 + items.size() % 5, "max": int(data.get("max", 5))})
	var stats := {}
	for stat: String in PauseMenu.STATS:
		stats[stat] = float(StatBlock.DEFS[stat][0])
	stats["might"] = 1.35
	stats["cooldown"] = 0.85
	stats["curse"] = 1.1
	stats["max_hp"] = 180.0
	stats["amount"] = 2.0
	return {"time": 431.0, "run_length": 900.0, "endless": false, "level": 27, "kills": 12345, "ryo": 1234,
			"subtitle": "%s · %s" % [TranslationServer.translate("stage.village.name"),
			TranslationServer.translate("moon.level") % "III"], "weapons": weapons, "items": items, "stats": stats,
			"weapon_cap": 6, "item_cap": 6, "speed": 2}


## Abre a pausa sozinha numa área do tamanho dado (a tela lógica do aparelho).
func open_standalone(view: Vector2, snapshot: Dictionary) -> PauseMenu:
	var area := Control.new()
	area.theme = ThemeFactory.build()
	area.size = view
	_host.add_child(area)
	var menu := PauseMenu.new()
	area.add_child(menu)
	menu.open(snapshot)
	# Abertura terminada na hora (mesmo estado final da animação, conferido em _test_finish_intro).
	finish_intro(menu)
	await _host.get_tree().process_frame
	return menu


## Termina na hora a animação de abertura em curso (o Tween da pausa avança até o fim, com os mesmos
## passos e callbacks da animação natural).
static func finish_intro(menu: PauseMenu) -> void:
	var tween := menu.get("_tween") as Tween
	if tween != null and tween.is_valid() and tween.is_running():
		tween.custom_step(60.0)


## finish_intro(menu) deixa a pausa no mesmo estado da abertura natural (OPEN_TIME), para os testes de
## layout não esperarem a animação em cada resolução e idioma.
func _test_finish_intro() -> void:
	var view := DeviceProfiles.main_view()
	var states: Array[PackedStringArray] = []
	for natural: bool in [true, false]:
		var area := Control.new()
		area.theme = ThemeFactory.build()
		area.size = view
		_host.add_child(area)
		var menu := PauseMenu.new()
		area.add_child(menu)
		menu.open(make_snapshot(true))
		if natural:
			await _seconds(0.3)
		else:
			finish_intro(menu)
		await _host.get_tree().process_frame
		# Posições com folga de 0,01 ponto (a curva da animação termina em 419,99997 em vez de 420).
		var state: PackedStringArray = [var_to_str([snappedf(float(menu.get("_intro")), 0.001), menu.modulate])]
		var controls: Array[Control] = []
		_controls_in(menu, controls)
		for c: Control in controls:
			var r := c.get_global_rect()
			var tag := c.get_class() if String(c.name).begins_with("@") else String(c.name)
			state.append(var_to_str([tag, r.position.snapped(Vector2(0.01, 0.01)), r.size.snapped(Vector2(0.01, 0.01)),
					c.modulate]))
		states.append(state)
		area.queue_free()
		await _host.get_tree().process_frame
	var diff := "" if states[0].size() == states[1].size() else "%d × %d controles" % [states[0].size(), states[1].size()]
	for i: int in mini(states[0].size(), states[1].size()):
		if diff.is_empty() and states[0][i] != states[1][i]:
			diff = "%s × %s" % [states[0][i], states[1][i]]
	_check.call(diff.is_empty(), "Pausa: finish_intro(menu) termina no mesmo estado da abertura natural %s", diff)


func _test_layouts() -> void:
	var cases := DeviceProfiles.layout_cases()
	# As telas a mais também vão para uma fatia só (--shard).
	for view: Vector2 in DeviceProfiles.shard_items(EXTRA_SIZES):
		cases.append({"label": "%dx%d" % [view.x, view.y], "view": view, "insets": Vector2.ZERO, "langs": LANGS})
	for c: Dictionary in cases:
		use_insets(c["insets"])
		var view: Vector2 = c["view"]
		for lang: String in Locale.SUPPORTED:
			if lang not in c["langs"]:
				continue
			Locale.set_language(lang, false)
			for full: bool in [true, false]:
				if not full and lang not in LANGS:
					continue
				var snapshot := make_snapshot(full)
				# Sem itens, a velocidade bloqueada (sem a Ampulheta de Fūjin): cadeado e aviso.
				snapshot["speed_locked"] = not full
				if not full:
					snapshot["speed"] = 1
				if full:
					Settings.set_value(QUALITY_KEY, "auto")
				var menu := await open_standalone(view, snapshot)
				var state := "%s [%s] %s" % [lang, c["label"], "cheio" if full else "sem itens, velocidade bloqueada"]
				check_layout(menu, view, state)
				if full:
					await check_quality(menu, view, lang, c["label"])
				if full and lang == "pt_BR":
					await _check_confirm_layout(menu, view, state)
				if not full:
					await _check_locked_speed(menu, view, state)
				menu.get_parent().queue_free()
				await _host.get_tree().process_frame
	use_insets(Vector2.ZERO)
	Locale.set_language("pt_BR", false)


## Botão de qualidade gráfica no menu já aberto (com a opção em "auto"): legenda e valor inteiros em
## cada modo e, em pt_BR, o ciclo Auto → Baixa → Média → Alta → Auto (era a matriz da pausa repetida
## em tests/gfx_quality_tests.gd; agora roda no mesmo menu de cada caso de layout). Volta a "auto".
func check_quality(menu: PauseMenu, view: Vector2, lang: String, label: String) -> void:
	var state := "gfx %s [%s]" % [lang, label]
	var quality := menu.get("_quality") as Button
	var caption := menu.get("_quality_caption") as Label
	var value := menu.get("_quality_value") as Label
	var compact := bool(menu.get("_compact"))
	_check.call(compact == (view.y < 300.0), "%s: modo compacto só na tela baixa", state)
	_check.call(quality != null and quality.is_visible_in_tree() and quality.size.y >= 22.0,
			"%s: pausa tem o botão de qualidade", state)
	var font := value.get_theme_font("font")
	if not compact:
		var need := font.get_string_size(caption.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		_check.call(need <= caption.size.x + 0.5 and caption.text == tr("pause.graphics"),
				"%s: legenda inteira (%.0f de %.0f)", [state, need, caption.size.x])
	for mode: String in GfxQuality.MODES:
		Settings.set_value(QUALITY_KEY, mode)
		await _host.get_tree().process_frame
		var width := font.get_string_size(value.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		_check.call(width <= value.size.x + 0.5 and quality.get_global_rect().grow(0.5).encloses(value.get_global_rect()),
				"%s: valor \"%s\" inteiro dentro do botão (%.0f de %.0f)", [state, value.text, width, value.size.x])
	Settings.set_value(QUALITY_KEY, "auto")
	if lang == "pt_BR":
		var seen: Array[String] = [value.text]
		for i: int in range(4):
			quality.pressed.emit()
			seen.append(value.text)
		var auto_text := "Auto" if compact else "Auto (Alta)"
		_check.call(seen == [auto_text, "Baixa", "Média", "Alta", auto_text], "%s: ciclo na pausa (%s)", [state, seen])
		_check.call(Settings.get_value(QUALITY_KEY) == "auto", "%s: ciclo volta ao auto", state)
		Settings.set_value(QUALITY_KEY, "low")
		_check.call(value.text == "Baixa", "%s: pausa acompanha troca feita fora dela", state)
	Settings.set_value(QUALITY_KEY, "auto")


## Liga o recorte simulado da câmera (MenuKit.safe_insets, usado pela pausa).
func use_insets(insets: Vector2) -> void:
	_insets = insets
	DeviceProfiles.simulate_insets(insets)


func check_layout(menu: PauseMenu, view: Vector2, state: String) -> void:
	var screen := DeviceProfiles.safe_rect(view, _insets)
	var left := menu.get("_left") as Control
	var panel := menu.get("_panel") as Control
	var menu_box := menu.get("_menu") as VBoxContainer
	_check.call(screen.encloses(left.get_global_rect()) and screen.encloses(panel.get_global_rect()),
			"%s: colunas dentro da tela (%s, %s em %s)", [state, left.get_global_rect(), panel.get_global_rect(), screen])
	_check.call(not left.get_global_rect().intersects(panel.get_global_rect()), "%s: colunas separadas", state)
	_check.call(menu_box.get_combined_minimum_size().y <= left.size.y + 0.5,
			"%s: coluna do menu cabe na altura (%.0f de %.0f)", [state, menu_box.get_combined_minimum_size().y,
			left.size.y])
	var resume := menu.get("_resume") as Button
	var quit := menu.get("_quit") as Button
	_check.call(resume.size.y > quit.size.y and resume.size.y >= 36.0, "%s: Continuar é o maior botão", state)
	# Todo controle da pausa fica visível e tocável em qualquer tela (o modo compacto só esconde a
	# legenda "Gráficos" do botão de qualidade, que segue com o valor, as barras e a dica).
	var quality := menu.get("_quality") as Button
	for b: Button in [resume, menu.get("_speed"), menu.get("_music"), quality, quit]:
		_check.call(b.is_visible_in_tree() and screen.encloses(b.get_global_rect()) and b.size.y >= 22.0,
				"%s: botão %s visível e inteiro", [state, b.name if b.text.is_empty() else b.text])
	var value := menu.get("_quality_value") as Label
	_check.call(value.is_visible_in_tree() and not value.text.is_empty() and quality.get_global_rect().encloses(
			value.get_global_rect()) and quality.tooltip_text == tr("options.graphics_quality"),
			"%s: qualidade gráfica mostra o valor (%s) e diz o que é na dica", [state, value.text])
	# Coluna fixa: tudo dentro da tela, textos inteiros e sem sobreposição.
	var controls: Array[Control] = []
	_controls_in(left, controls)
	for c: Control in controls:
		var label := "%s \"%s\"" % [c.get_class(), _text(c)]
		_check.call(screen.encloses(c.get_global_rect().grow(-0.5)), "%s: %s dentro da tela", [state, label])
		_check_text_fits(c, state, label)
	_check_no_overlap(controls, state)
	# Botões compactos: o conteúdo cabe dentro do botão.
	for b: Button in [menu.get("_speed"), menu.get("_music")]:
		var inside: Array[Control] = []
		_controls_in(b, inside)
		for c: Control in inside:
			_check.call(b.get_global_rect().grow(0.5).encloses(c.get_global_rect()),
					"%s: \"%s\" dentro do botão", [state, _text(c)])
	# Painel: o conteúdo cabe na largura da rolagem e cada linha é alcançável rolando.
	var scroll := menu.get("_scroll") as ScrollContainer
	var build := menu.get("_build") as VBoxContainer
	_check.call(build.get_combined_minimum_size().x <= scroll.size.x + 0.5,
			"%s: painel cabe na largura (%.0f de %.0f)", [state, build.get_combined_minimum_size().x, scroll.size.x])
	var inner: Array[Control] = []
	_controls_in(build, inner)
	for c: Control in inner:
		var local := Rect2(c.get_global_rect().position - build.get_global_rect().position, c.size)
		_check.call(local.position.x >= -0.5 and local.end.x <= scroll.size.x + 0.5 and local.end.y <= build.size.y + 0.5,
				"%s: %s \"%s\" alcançável rolando", [state, c.get_class(), _text(c)])
		var limit := scroll.get_global_rect().end.x - scroll.get_v_scroll_bar().custom_minimum_size.x - PauseMenu.SCROLL_GAP
		_check.call(c.get_global_rect().end.x <= limit + 0.5,
				"%s: %s \"%s\" com folga da barra de rolagem (%.0f até %.0f)", [state, c.get_class(), _text(c),
				c.get_global_rect().end.x, limit])
		_check_text_fits(c, state, "%s \"%s\"" % [c.get_class(), _text(c)])
	var auto := menu.get("_auto_pick") as AutoPickRow
	var segments_ok := auto.is_visible_in_tree() and auto.segments.buttons.size() == 3
	for b: Button in auto.segments.buttons:
		segments_ok = segments_ok and b.is_visible_in_tree() and b.size.y >= 22.0 and not b.text.is_empty()
	_check.call(segments_ok, "%s: escolha automática com os 3 segmentos no painel", state)
	var stats := menu.get("_stats_grid") as GridContainer
	_check.call(stats.get_child_count() == PauseMenu.STATS.size(), "%s: todos os atributos na grade", state)
	var might := stats.find_child("Value_might", true, false) as Label
	var luck := stats.find_child("Value_luck", true, false) as Label
	_check.call(might != null and might.get_theme_color("font_color") == PauseMenu.JADE
			and luck.get_theme_color("font_color") == ThemeFactory.TEXT, "%s: realce só acima da base", state)


## Velocidade bloqueada na pausa: valor esmaecido, cadeado inteiro dentro do botão e ao lado do
## valor (sem encostar), e o aviso de onde liberar inteiro na área segura.
func _check_locked_speed(menu: PauseMenu, view: Vector2, state: String) -> void:
	var tile := menu.get("_speed") as Button
	var lock := menu.get("_speed_lock") as Control
	var value := menu.get("_speed_value") as Label
	_check.call(lock.is_visible_in_tree() and value.modulate.a < 1.0,
			"%s: velocidade bloqueada com cadeado e valor esmaecido", state)
	_check.call(tile.get_global_rect().grow(0.5).encloses(lock.get_global_rect()),
			"%s: cadeado dentro do botão de velocidade (%s em %s)", [state, lock.get_global_rect(),
			tile.get_global_rect()])
	_check.call(not lock.get_global_rect().grow(-0.5).intersects(value.get_global_rect().grow(-0.5)),
			"%s: cadeado sem cobrir o valor", state)
	menu.deny_speed(tr("speed.locked"))
	await _host.get_tree().process_frame
	await _host.get_tree().process_frame
	var notice := menu.get("_notice") as FloatingNotice
	var label := notice.label
	var safe := DeviceProfiles.safe_rect(view, _insets)
	_check.call(notice.is_open() and safe.encloses(notice.get_global_rect()),
			"%s: aviso da velocidade bloqueada dentro da área segura (%s em %s)", [state,
			notice.get_global_rect(), safe])
	_check_text_fits(label, state, "aviso \"%s\"" % label.text)
	_check.call(label.get_line_count() <= label.get_visible_line_count(), "%s: aviso com todas as linhas", state)
	await _seconds(0.4)
	var content := tile.get_child(0) as Control
	_check.call(is_equal_approx(content.position.x, 0.0), "%s: a tremida do negado volta ao lugar", state)


func _check_confirm_layout(menu: PauseMenu, view: Vector2, state: String) -> void:
	(menu.get("_quit") as Button).pressed.emit()
	await _seconds(0.25)
	var card := menu.get("_confirm_card") as Control
	_check.call(DeviceProfiles.safe_rect(view, _insets).encloses(card.get_global_rect()),
			"%s: confirmação dentro da tela", state)
	var inside: Array[Control] = []
	_controls_in(card, inside)
	for c: Control in inside:
		_check_text_fits(c, state + " confirmação", "%s \"%s\"" % [c.get_class(), _text(c)])
	menu.back()


func _check_text_fits(control: Control, state: String, path: String) -> void:
	if control is Label and (control as Label).text != "":
		var l := control as Label
		var font := l.get_theme_font("font")
		var font_size := l.get_theme_font_size("font_size")
		var needed := l.get_line_count() * font.get_height(font_size)
		_check.call(needed <= l.size.y + 0.5, "%s: %s cabe na altura (%.0f de %.0f)", [state, path, needed, l.size.y])
		if l.autowrap_mode == TextServer.AUTOWRAP_OFF and l.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING:
			var width := font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			_check.call(width <= l.size.x + 0.5, "%s: %s cabe na largura (%.0f de %.0f)", [state, path, width, l.size.x])
	if control is Button and (control as Button).text != "":
		var b := control as Button
		var minimum := b.get_combined_minimum_size()
		_check.call(minimum.x <= b.size.x + 0.5 and minimum.y <= b.size.y + 0.5,
				"%s: botão %s cabe (%s em %s)", [state, path, minimum, b.size])


## Textos e botões não se sobrepõem (fora os que estão um dentro do outro).
func _check_no_overlap(controls: Array[Control], state: String) -> void:
	var leaves := controls.filter(func(c: Control) -> bool: return c is Label or c is Button or c is TextureRect)
	for i: int in range(leaves.size()):
		for j: int in range(i + 1, leaves.size()):
			var a: Control = leaves[i]
			var b: Control = leaves[j]
			if a.is_ancestor_of(b) or b.is_ancestor_of(a):
				continue
			var overlap := a.get_global_rect().grow(-0.5).intersects(b.get_global_rect().grow(-0.5))
			_check.call(not overlap, "%s: \"%s\" e \"%s\" não se sobrepõem", [state, _text(a), _text(b)])


func _controls_in(node: Node, out: Array[Control]) -> void:
	for child: Node in node.get_children():
		var c := child as Control
		if c == null or not c.is_visible_in_tree():
			continue
		out.append(c)
		_controls_in(c, out)


func _text(c: Control) -> String:
	if c is Label:
		return (c as Label).text
	if c is Button:
		return (c as Button).text
	return c.name


# --- Partida ----------------------------------------------------------------------------

func _new_game() -> HyakkiGame:
	var game := (load(GAME_SCENE) as PackedScene).instantiate() as HyakkiGame
	game.config = CONFIG.duplicate()
	_host.add_child(game)
	await _host.get_tree().process_frame
	await _host.get_tree().process_frame
	GameClock.paused = false
	return game


func _free(game: HyakkiGame) -> void:
	game.queue_free()
	GameClock.paused = false
	await _host.get_tree().process_frame


func _seconds(value: float) -> void:
	await _host.get_tree().create_timer(value).timeout
