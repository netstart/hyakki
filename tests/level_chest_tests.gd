extends RefCounted
## Telas de NOVA HABILIDADE (scripts/ui/level_up_panel.gd + level_card.gd) e do BAÚ
## (scripts/ui/chest_panel.gd + lacquer_chest.gd), com o fundo compartilhado (overlay_fx.gd):
## - regras puras: números destacados, categoria/elemento/sinergia de cada carta, raridade;
## - fluxo numa partida de verdade: entrada em leque, bloqueio do toque acidental, escolha
##   (o jogo aplica, a luz voa para a HUD, a tela some sozinha), pular, rerrolar, banir com o
##   carimbo e o bot;
## - baú: queda, tremor, abertura com a explosão, itens um a um, ryō contando, pular a qualquer
##   momento, fechar, novo baú e nova partida;
## - GfxQuality: Baixa sem desfoque/vinheta e com menos moedas e faíscas, Alta completa, e a
##   troca ao vivo com a tela aberta;
## - layout em 678x305 e 480x270 nos 11 idiomas, com as cartas e os cartões mais longos.
## Chamado por tests/integration_tests.gd ou sozinho por tests/level_chest_tests.tscn.

const GAME_SCENE := "res://scenes/game/Game.tscn"
const CONFIG := {"hero": "aki", "stage": "village", "moon": 2, "mode": "normal", "seed": 5, "speed": 1}
const SIZES: Array[Vector2] = [Vector2(678, 305), Vector2(480, 270)]
## Espera até o baú pousar e começar a tremer.
const DROP_WAIT := 0.6

var _host: Node
var _check: Callable


func run(host: Node, check: Callable) -> void:
	_host = host
	_check = check
	_test_rules()
	await _test_level_flow()
	await _test_chest_flow()
	await _test_quality()
	await _test_layouts()
	GfxQuality.clear_override()
	Locale.set_language("pt_BR", false)
	GameClock.paused = true


# --- Amostras (também usadas pelo runner de capturas) ------------------------------------

## Quatro cartas que esticam o layout no idioma atual: lendária (nível máximo com a linha de
## evolução), arma nova com a descrição mais longa, item com dois atributos e melhoria comum.
static func sample_cards() -> Array[Dictionary]:
	var longest := &""
	var longest_len := -1
	var legend := &""
	for id: StringName in DB.ids("weapons"):
		var data := DB.weapon(id)
		if String(data.get("kind", "")) != "base":
			continue
		var desc := TranslationServer.translate("weapon.%s.desc" % id)
		if desc.length() > longest_len:
			longest_len = desc.length()
			longest = id
		if legend == &"" and id != longest:
			legend = id
	var ldata := DB.weapon(legend)
	var levels: Array = ldata["levels"]
	var passive := StringName(ldata.get("evolves_with", ""))
	var legend_text := LevelUpSystem.describe_delta(levels[levels.size() - 1]) + "\n" \
			+ TranslationServer.translate("levelup.evolves_with") % TranslationServer.translate("passive.%s.name" % passive)
	var up_id := &"shuriken" if longest != &"shuriken" else &"kunai"
	var up_levels: Array = DB.weapon(up_id)["levels"]
	var cards: Array[Dictionary] = [
		{"kind": "weapon_up", "id": legend, "level": levels.size(), "tag": "", "text": legend_text,
				"title": TranslationServer.translate("weapon.%s.name" % legend), "icon": ldata.get("icon", "")},
		{"kind": "weapon_new", "id": longest, "level": 1, "tag": "",
				"text": TranslationServer.translate("weapon.%s.desc" % longest),
				"title": TranslationServer.translate("weapon.%s.name" % longest), "icon": DB.weapon(longest).get("icon", "")},
		{"kind": "passive", "id": &"noh_mask", "level": 3, "tag": "",
				"text": LevelUpSystem.describe_stats(DB.passives[&"noh_mask"]["per_level"]),
				"title": TranslationServer.translate("passive.noh_mask.name"), "icon": DB.passives[&"noh_mask"]["icon"]},
		{"kind": "weapon_up", "id": up_id, "level": 4, "tag": "", "text": LevelUpSystem.describe_delta(up_levels[3]),
				"title": TranslationServer.translate("weapon.%s.name" % up_id), "icon": DB.weapon(up_id).get("icon", "")},
	]
	return cards


## Baú com `count` itens (o último lendário traz uma evolução) e o ryō.
static func sample_rewards(count: int) -> Array[Dictionary]:
	var rewards: Array[Dictionary] = []
	var cards := sample_cards()
	for i: int in range(count):
		if count >= 5 and i == 0:
			rewards.append({"kind": "evolution", "id": &"dawn_blade",
					"title": TranslationServer.translate("weapon.dawn_blade.name"),
					"text": TranslationServer.translate("chest.evolution"), "icon": DB.weapon(&"dawn_blade").get("icon", "")})
		else:
			rewards.append(cards[i % cards.size()])
	rewards.append({"kind": "ryo", "title": TranslationServer.translate("chest.ryo") % (10 * count),
			"icon": "res://assets/art/items/object/MoneyBag.png"})
	return rewards


# --- Regras ------------------------------------------------------------------------------

func _test_rules() -> void:
	var bb := UiPaint.highlight_numbers("+5 dano, -8% recarga [x]")
	_check.call(bb.contains("[color=#") and bb.contains("+5[/color]") and bb.contains("-8%[/color]")
			and bb.contains("[lb]x]"), "números da melhoria destacados e colchetes escapados (%s)" % bb)
	var cards := sample_cards()
	var legend := LevelUpPanel.card_info(cards[0], null)
	_check.call(int(legend["category"]) == LevelCard.Cat.LEGEND, "nível máximo com evolução = carta lendária")
	_check.call(not String(legend["text"]).contains(tr("levelup.evolves_with").split("%")[0].strip_edges())
			and not String(legend["evo_name"]).is_empty() and legend["evo_icon"] != null,
			"linha \"Evolui com\" vira rodapé com mini-ícone")
	_check.call(int(LevelUpPanel.card_info(cards[1], null)["category"]) == LevelCard.Cat.NEW, "arma nova")
	_check.call(int(LevelUpPanel.card_info(cards[2], null)["category"]) == LevelCard.Cat.PASSIVE, "item")
	var up := LevelUpPanel.card_info(cards[3], null)
	_check.call(int(up["category"]) == LevelCard.Cat.UP and int(up["max_level"]) == 8, "melhoria com 8 marcas")
	_check.call(LevelUpPanel.element_color(["projectile", "fire"]) == LevelUpPanel.element_color(["fire"]),
			"elemento mais marcante (fogo) define o halo")
	_check.call(int(LevelUpPanel.card_info({"kind": "heal", "id": &"onigiri", "level": 0}, null)["category"])
			== LevelCard.Cat.HEAL, "carta de cura")
	_check.call(ChestPanel._ryo_amount({"title": tr("chest.ryo") % 60}) == 60, "ryō lido do título")


# --- Nova habilidade ---------------------------------------------------------------------

func _test_level_flow() -> void:
	var game := await _new_game()
	var hud := game.hud
	var panel := hud.level_up_panel()
	game.level_up.rerolls = 2
	game.level_up.skips = 1
	game.level_up.banishes = 1
	game.call("_open_level_up")
	_check.call(hud.level_up_open() and hud.overlay_open() and GameClock.paused, "nível novo abre e pausa a luta")
	_check.call(hud.level_cards().size() >= 3, "três ou mais cartas (%d)" % hud.level_cards().size())
	var chosen := [-1, 0]
	hud.card_chosen.connect(func(i: int) -> void:
		chosen[0] = i
		chosen[1] += 1)
	var first := hud.level_cards()[0] as LevelCard
	_check.call(not first.settled and first.modulate.a < 1.0, "cartas entram depois (leque)")
	first.pressed.emit()
	_check.call(chosen[1] == 0, "toque antes da carta pousar é ignorado (proteção)")
	await _seconds(0.9)
	_check.call(panel.level_cards().all(func(c: LevelCard) -> bool: return c.settled and c.position == c.base_position),
			"todas as cartas pousam no lugar")
	_check.call(panel.overlay().power >= 0.99, "fundo escurecido por inteiro")
	_check.call(panel.action_buttons().all(func(b: Button) -> bool: return b.visible),
			"Rerrolar, Pular e Banir com contador")
	# Rerrolar troca as cartas e gasta um.
	var rerolled := [0]
	hud.reroll_pressed.connect(func() -> void: rerolled[0] += 1)
	panel.action_buttons()[0].pressed.emit()
	_check.call(rerolled[0] == 1 and game.level_up.rerolls == 1 and hud.level_up_open(), "rerrolar troca as cartas")
	await _seconds(0.8)
	# Banir: borda vermelha nas cartas e o carimbo.
	panel.action_buttons()[2].pressed.emit()
	_check.call(panel.banish_mode() and panel.level_cards().all(func(c: LevelCard) -> bool: return c.banish_mode),
			"modo banir marca as cartas")
	_check.call(panel.subtitle_text() == tr("levelup.banish_hint"), "dica de banir no subtítulo")
	var banished := [-1]
	hud.banish_pressed.connect(func(i: int) -> void: banished[0] = i)
	var target := panel.level_cards()[1]
	var banished_id := StringName(target.data["id"])
	target.pressed.emit()
	_check.call(banished[0] == -1 and target.stamp >= 0.0, "carimbo cai antes de banir")
	await _seconds(LevelUpPanel.STAMP_TIME + 0.3)
	_check.call(banished[0] == 1 and game.level_up.banished.has(banished_id) and not panel.banish_mode(),
			"banir depois do carimbo, e o modo sai")
	await _seconds(0.8)
	# Escolher: o jogo aplica, a tela fecha e a luz voa até a HUD.
	var card := panel.level_cards()[0]
	var data := card.data
	card.pressed.emit()
	_check.call(chosen[1] == 1 and chosen[0] == 0, "tocar a carta escolhe uma vez")
	card.pressed.emit()
	_check.call(chosen[1] == 1, "segundo toque não escolhe de novo")
	_check.call(not hud.level_up_open() and not hud.overlay_open(), "a luta volta logo depois da escolha")
	_check.call(panel.outro_playing() and panel.flyers() == 1, "a carta escolhida voa para a HUD")
	var slot := hud.skill_slot(data)
	_check.call(slot.y < 80.0, "alvo do voo na barra do topo (%s)" % slot)
	await _seconds(1.2)
	_check.call(not panel.visible and panel.flyers() == 0, "a tela some sozinha ao fim da saída")
	# Pular.
	game.call("_open_level_up")
	await _seconds(0.9)
	var skipped := [0]
	hud.skip_pressed.connect(func() -> void: skipped[0] += 1)
	panel.action_buttons()[1].pressed.emit()
	_check.call(skipped[0] == 1 and not hud.level_up_open(), "pular fecha sem escolher")
	await _seconds(0.8)
	# Bot e nova partida.
	game.call("_open_level_up")
	hud.bot_answer()
	_check.call(not hud.level_up_open() and not panel.visible, "bot escolhe e a tela some na hora")
	game.call("_open_level_up")
	hud.start_run()
	_check.call(not hud.level_up_open() and not panel.visible, "nova partida fecha a tela")
	await _free(game)


# --- Baú ---------------------------------------------------------------------------------

func _test_chest_flow() -> void:
	var game := await _new_game()
	var hud := game.hud
	var panel := hud.chest_panel()
	var chest := panel.chest()
	var burst := panel.burst()
	_check.call(burst.get_parent() == chest and burst.show_behind_parent, "explosão atrás do baú")
	_check.call(burst.mouse_filter == Control.MOUSE_FILTER_IGNORE and burst.size == Vector2.ZERO,
			"explosão não pega toques nem ocupa espaço")
	for count: int in [1, 3, 5]:
		hud.show_chest(sample_rewards(count))
		_check.call(panel.lines_total() == count + 1, "baú de %d: %d cartões + ryō" % [count, count])
		var expected: Color = ChestPanel.RARITIES[0 if count >= 5 else (1 if count >= 3 else 2)][1]
		_check.call(panel.rarity_color() == expected, "baú de %d: cor da raridade" % count)
		hud.call("_chest_skip")
	var closed := [0]
	hud.chest_closed.connect(func() -> void: closed[0] += 1)
	hud.show_chest(sample_rewards(3))
	await _host.get_tree().process_frame
	_check.call(hud.chest_open() and hud.chest_animating() and not hud.chest_burst_active(),
			"baú cai e treme sem explosão")
	_check.call(chest.lid == 0.0, "tampa fechada no começo")
	await _seconds(DROP_WAIT)
	_check.call(chest.position == panel.get("_chest_rest") and chest.crack > 0.0, "baú no chão com luz pela fresta")
	_check.call(await _wait(hud.chest_burst_active, 2.0), "abre com a explosão")
	var center := chest.get_global_transform_with_canvas() * chest.mouth()
	_check.call(burst.get_global_transform_with_canvas().origin.distance_to(center) < 1.0, "explosão na boca do baú")
	_check.call(panel.coin_count() > 0, "moedas jorram na abertura")
	await _seconds(0.3)
	_check.call(chest.lid > 0.9, "tampa aberta")
	_check.call(await _wait(func() -> bool: return panel.lines_shown() >= 1, 1.5), "primeiro item pousa no cartão")
	_check.call(panel.lines_shown() < panel.lines_total(), "os itens chegam um a um")
	_check.call(await _wait(func() -> bool: return not hud.chest_burst_active(), 1.5) and hud.chest_animating(),
			"explosão some sozinha sem esperar os itens")
	_check.call(await _wait(func() -> bool: return not hud.chest_animating(), 4.0), "fim natural")
	_check.call(hud.chest_lines_shown() == hud.chest_lines_total() and panel.ryo_shown() == panel.ryo_total()
			and panel.ryo_total() == 30, "todos os cartões e o ryō completo (%d)" % panel.ryo_shown())
	_check.call(panel.button().text == tr("chest.close"), "botão vira Continuar")
	# Pular a qualquer momento, até na queda.
	hud.show_chest(sample_rewards(5))
	await _host.get_tree().process_frame
	panel.button().pressed.emit()
	_check.call(not hud.chest_animating() and hud.chest_lines_shown() == hud.chest_lines_total()
			and panel.ryo_shown() == panel.ryo_total() and chest.lid == 1.0, "pular na queda mostra tudo")
	_check.call(not hud.chest_burst_active() and not burst.visible and hud.chest_open(), "pular apaga a explosão e espera")
	panel.button().pressed.emit()
	_check.call(closed[0] == 1 and not hud.chest_open(), "Continuar fecha o baú")
	# Tocar fora do botão também pula.
	hud.show_chest(sample_rewards(3))
	await _seconds(0.5)
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	panel.call("_gui_input", tap)
	_check.call(not hud.chest_animating(), "tocar no fundo pula")
	# Novo baú e nova partida no meio.
	hud.show_chest(sample_rewards(3))
	await _wait(hud.chest_burst_active, 3.0)
	hud.show_chest(sample_rewards(1))
	_check.call(not hud.chest_burst_active() and hud.chest_animating() and panel.lines_shown() == 0,
			"novo baú recomeça do zero")
	hud.start_run()
	_check.call(not hud.chest_open() and not hud.chest_burst_active() and not burst.visible, "nova partida apaga o baú")
	_check.call(chest.get_child_count() == 1, "um nó de explosão só, reaproveitado")
	# O jogo de verdade: abrir pelo cenário e o bot fechar.
	game.apply_scenario("chest")
	_check.call(await _wait(hud.chest_open, 3.0), "baú da partida abre a tela")
	hud.bot_answer()
	_check.call(not hud.chest_open() and closed[0] == 2, "bot fecha o baú")
	await _free(game)


# --- Qualidade ---------------------------------------------------------------------------

func _test_quality() -> void:
	var game := await _new_game()
	var hud := game.hud
	var coins := {}
	for level: int in [GfxQuality.LOW, GfxQuality.HIGH]:
		GfxQuality.set_override(level)
		Settings.emit_signal("changed", GfxQuality.changed_signal_key())
		hud.show_chest(sample_rewards(5))
		var panel := hud.chest_panel()
		var name := GfxQuality.level_name(level)
		_check.call(panel.fx_level() == GfxQuality.budget("ui_fx"), "%s: baú usa ui_fx" % name)
		_check.call(panel.overlay().blur_on() == (level == GfxQuality.HIGH) or panel.overlay().power == 0.0,
				"%s: desfoque só em Alta" % name)
		await _wait(hud.chest_burst_active, 3.0)
		await _host.get_tree().process_frame
		coins[level] = panel.coin_count()
		_check.call(panel.overlay().blur_on() == (level == GfxQuality.HIGH), "%s: desfoque de tela cheia" % name)
		_check.call(panel.coin_count() * 10 <= int(GfxQuality.budget("particles_max")), "%s: moedas no orçamento" % name)
		hud.call("_chest_skip")
		hud.chest_panel().button().pressed.emit()
		game.call("_open_level_up")
		await _seconds(0.9)
		var lp := hud.level_up_panel()
		_check.call(lp.fx_level() == GfxQuality.budget("ui_fx") and lp.level_cards()[0].fx_level == lp.fx_level(),
				"%s: cartas usam ui_fx" % name)
		_check.call(lp.overlay().mote_count() == OverlayFx.MOTE_COUNT[level], "%s: fogos-fátuos no orçamento" % name)
		hud.bot_answer()
	_check.call(int(coins[GfxQuality.LOW]) < int(coins[GfxQuality.HIGH]), "Baixa com menos moedas que Alta (%d < %d)"
			% [coins[GfxQuality.LOW], coins[GfxQuality.HIGH]])
	# Troca ao vivo com a tela aberta.
	game.call("_open_level_up")
	await _seconds(0.5)
	GfxQuality.set_override(GfxQuality.LOW)
	Settings.emit_signal("changed", GfxQuality.changed_signal_key())
	var lp := hud.level_up_panel()
	_check.call(lp.fx_level() == 0 and not lp.overlay().blur_on() and lp.level_cards()[0].fx_level == 0,
			"troca ao vivo para Baixa com a tela aberta")
	GfxQuality.set_override(GfxQuality.HIGH)
	Settings.emit_signal("changed", GfxQuality.changed_signal_key())
	_check.call(lp.fx_level() == 2 and lp.overlay().blur_on(), "e de volta para Alta")
	hud.bot_answer()
	GfxQuality.clear_override()
	await _free(game)


# --- Layout ------------------------------------------------------------------------------

func _test_layouts() -> void:
	for lang: String in Locale.SUPPORTED:
		Locale.set_language(lang, false)
		for view: Vector2 in SIZES:
			var state := "%s %dx%d" % [lang, view.x, view.y]
			var area := _area(view)
			var panel := LevelUpPanel.new()
			area.add_child(panel)
			panel.show_cards(sample_cards(), 2, 1, 3, 27)
			await _seconds(0.75)
			check_level_layout(panel, view, state)
			var chest := ChestPanel.new()
			area.add_child(chest)
			panel.close_now()
			chest.show_chest(sample_rewards(5))
			chest.skip()
			await _host.get_tree().process_frame
			check_chest_layout(chest, view, state)
			area.queue_free()
			await _host.get_tree().process_frame
	Locale.set_language("pt_BR", false)


func check_level_layout(panel: LevelUpPanel, view: Vector2, state: String) -> void:
	var screen := Rect2(Vector2.ZERO, view)
	var cards := panel.level_cards()
	_check.call(cards.size() == 4, "%s: 4 cartas" % state)
	for i: int in range(cards.size()):
		var c := cards[i]
		var r := c.get_global_rect()
		_check.call(screen.encloses(r) and r.position.y >= LevelUpPanel.HEADER_H, "%s: carta %d na tela" % [state, i])
		_check.call(c.desc_fits(), "%s: descrição cabe na carta %d (%s)" % [state, i, c.data["title"]])
		_check.call(not c.shortened or view.x < 600.0, "%s: descrição inteira na carta %d (%s)" % [state, i, c.data["title"]])
		_check.call(c.name_fits(), "%s: nome inteiro na carta %d" % [state, i])
		_check.call(UiPaint.text_width(c.category_text()) <= c.size.x - 16.0, "%s: categoria cabe na fita %d" % [state, i])
		if not c.footer_text().is_empty():
			_check.call(c.footer_fits(),
					"%s: sinergia cabe na carta %d" % [state, i])
		if i > 0:
			_check.call(not cards[i - 1].get_global_rect().intersects(r), "%s: cartas %d e %d separadas" % [state, i - 1, i])
	var title := UiPaint.text_width(panel.title_text(), 24) + 26.0
	_check.call(title <= view.x - 16.0, "%s: título cabe" % state)
	_check.call(UiPaint.text_width(tr("levelup.banish_hint")) <= view.x - 16.0, "%s: dica de banir cabe" % state)
	var last := Rect2()
	for b: Button in panel.action_buttons():
		var r := b.get_global_rect()
		_check.call(screen.encloses(r), "%s: botão %s na tela" % [state, b.text])
		_check.call(b.get_combined_minimum_size().x <= r.size.x + 0.5, "%s: botão %s inteiro" % [state, b.text])
		for c: LevelCard in cards:
			_check.call(not c.get_global_rect().intersects(r), "%s: botão %s não cobre cartas" % [state, b.text])
		if last.size.x > 0.0:
			_check.call(not last.intersects(r), "%s: botões separados" % state)
		last = r


func check_chest_layout(chest: ChestPanel, view: Vector2, state: String) -> void:
	var screen := Rect2(Vector2.ZERO, view)
	var stage := chest.stage_rect()
	_check.call(screen.encloses(stage), "%s: palco do baú na tela" % state)
	var c := chest.chest()
	var chest_rect := Rect2(chest.get("_chest_rest") + stage.position, c.size)
	_check.call(stage.encloses(chest_rect), "%s: baú dentro do palco" % state)
	_check.call(chest_rect.position.y - 9.0 * c.px >= stage.position.y + 40.0, "%s: tampa aberta abaixo do título" % state)
	var b := chest.button().get_global_rect()
	_check.call(screen.encloses(b) and not b.intersects(chest_rect), "%s: botão na tela, longe do baú" % state)
	_check.call(chest.button().get_combined_minimum_size().x <= b.size.x + 0.5, "%s: botão inteiro" % state)
	var title := UiPaint.text_width(tr("chest.title"))
	_check.call(title <= stage.size.x, "%s: título do baú cabe" % state)
	_check.call(UiPaint.text_width(tr("chest.ryo") % 999) + 16.0 <= stage.size.x, "%s: ryō cabe" % state)
	for row: ChestPanel.RewardRow in chest.rows():
		var r := row.get_global_rect()
		_check.call(screen.encloses(r) and not r.intersects(stage), "%s: cartão %s na tela" % [state, row.name_label.text])
		_check.call(row.effect_fits(), "%s: efeito cabe em %s" % [state, row.name_label.text])
		_check.call(not row.shortened or view.x < 600.0, "%s: efeito inteiro em %s" % [state, row.name_label.text])
		_check.call(row.name_fits(), "%s: nome inteiro em %s" % [state, row.name_label.text])


# --- Utilidades --------------------------------------------------------------------------

func _area(view: Vector2) -> Control:
	var area := Control.new()
	area.theme = ThemeFactory.build()
	area.size = view
	_host.add_child(area)
	return area


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


func _wait(condition: Callable, timeout: float) -> bool:
	var until := Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < until:
		if condition.call():
			return true
		await _host.get_tree().process_frame
	return bool(condition.call())
