extends Node
## Testes com os autoloads carregados (plano 14.1 e 15.1): dados, idiomas, fontes,
## atributos, Santuário, Loja e save. Rodar:
##   godot --headless --path . res://tests/integration_tests.tscn
## O save do jogador é copiado antes e restaurado no fim; nada do perfil real se perde.

const SAVE_FILES := ["user://save.json", "user://save.bak"]
const GAME_SCENE := "res://scenes/game/Game.tscn"

var _count: int = 0
var _failures: int = 0
var _backup: Dictionary = {}


func _ready() -> void:
	_backup_save()
	_test_data_integrity()
	_test_assets_exist()
	_test_i18n()
	_test_glyphs()
	_test_stat_block()
	_test_descriptions()
	_test_save_migration()
	_test_sanctuary()
	_test_shop_clock()
	_test_ads_rules()
	_test_frozen_tint()
	await _test_suspended_run()
	await _test_revive_by_ad()
	await _test_kami_layout()
	await _test_hero_screen_layout()
	await _test_shop_layout()
	_restore_save()
	print("%d verificações, %d falhas" % [_count, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	_count += 1
	if not condition:
		_failures += 1
		printerr("FALHOU: " + label)
	elif "--verbose" in OS.get_cmdline_user_args():
		print("ok: " + label)


func _backup_save() -> void:
	for path: String in SAVE_FILES:
		_backup[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null


func _restore_save() -> void:
	for path: String in SAVE_FILES:
		var bytes: Variant = _backup[path]
		if bytes == null:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
		else:
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_buffer(bytes)
			file.close()
	SaveManager.load_profile()


# --- Kami -------------------------------------------------------------------------

## "Um Kami oferece um pacto" em cada idioma: título, os 3 cartões (ícone e texto) e
## "Ignorar o santuário" ficam dentro de 678x305, com 4 px de folga. Cada Kami aparece em
## cada posição, e Hachiman (bênção, especial e custo: o texto mais longo) em cada uma delas.
func _test_kami_layout() -> void:
	var view := Rect2(Vector2(4, 4), Vector2(670, 297))
	var hud := Hud.new()
	add_child(hud)
	await get_tree().process_frame
	# O teste roda numa janela menor que o jogo: a raiz da HUD recebe o tamanho do viewport do jogo.
	var root := hud.get("_root") as Control
	root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.size = Vector2(678, 305)
	await get_tree().process_frame
	var ids := DB.ids("kami")
	var count := ids.size()
	var offers: Array = []
	for i: int in count:
		offers.append([ids[i], ids[(i + 1) % count], ids[(i + 2) % count]])
	for slot: int in 3:
		var offer: Array = [StringName("inari"), StringName("raijin"), StringName("inari")]
		offer[slot] = StringName("hachiman")
		offers.append(offer)
	for lang: String in Locale.SUPPORTED:
		Locale.set_language(lang, false)
		for offer: Array in offers:
			var typed: Array[StringName] = []
			typed.assign(offer)
			hud.show_kami(typed)
			await get_tree().process_frame
			await get_tree().process_frame
			var state := "%s, %s" % [lang, ", ".join(offer)]
			var panel := hud.get("_kami_panel") as Control
			var controls: Array[Control] = []
			_kami_controls_in(panel, controls)
			_check(controls.size() >= 3 + 3 + 1, "%s: o painel mostra título, cartões e botão" % state)
			for control: Control in controls:
				_check(control.is_visible_in_tree() and view.encloses(control.get_global_rect()),
						"%s: %s dentro da tela (%s)" % [state, control.get_class(), control.get_global_rect()])
				if control is Button and (control as Button).text != "":
					var button_node := control as Button
					var minimum := button_node.get_combined_minimum_size()
					_check(minimum.x <= button_node.size.x + 0.5 and minimum.y <= button_node.size.y + 0.5,
							"%s: o cartão mostra o texto inteiro (%s de %s)" % [state, minimum, button_node.size])
			var row := hud.get("_kami_row") as HBoxContainer
			_check(row.get_child_count() == 3, "%s: três cartões" % state)
			for card: Node in row.get_children():
				var icons := 0
				for child: Node in card.get_children():
					if child is TextureRect and (child as TextureRect).texture != null:
						icons += 1
						_check(view.encloses((child as Control).get_global_rect()),
								"%s: ícone do cartão dentro da tela" % state)
				_check(icons == 1, "%s: cada cartão mostra o ícone do Kami" % state)
	hud.queue_free()
	await get_tree().process_frame
	Locale.set_language("pt_BR", false)


## Coleta botões, textos e ícones de uma árvore de controles (o painel de Kami).
func _kami_controls_in(node: Node, out: Array[Control]) -> void:
	for child: Node in node.get_children():
		if (child is BaseButton or child is Label or child is TextureRect) and not out.has(child):
			out.append(child as Control)
		_kami_controls_in(child, out)


# --- Tela de guardiões ------------------------------------------------------------

## Cada guardião (bloqueado e desbloqueado) em cada idioma: a grade, o painel de texto,
## "Escolher fase" e "voltar" ficam inteiramente dentro de 678x305 (o viewport do jogo).
func _test_hero_screen_layout() -> void:
	var view := Rect2(Vector2.ZERO, Vector2(678, 305))
	var all_heroes: Array = []
	for id: StringName in DB.ids("heroes"):
		all_heroes.append(String(id))
	var original_unlocked: Array = (SaveManager.data["unlocked"]["heroes"] as Array).duplicate()
	for lang: String in Locale.SUPPORTED:
		Locale.set_language(lang, false)
		for unlock_all: bool in [false, true]:
			SaveManager.data["unlocked"]["heroes"] = all_heroes.duplicate() if unlock_all else original_unlocked.duplicate()
			var app := App.new()
			add_child(app)
			await get_tree().process_frame
			app.go(&"heroes")
			await get_tree().process_frame
			await get_tree().process_frame
			var screen := (app.get("_screens") as Dictionary)[&"heroes"] as Control
			var grid := screen.get("_grid") as Control
			_check(grid.get_child_count() == DB.ids("heroes").size(),
					"%s: a grade mostra todos os guardiões" % lang)
			for id: StringName in DB.ids("heroes"):
				screen.call("_select", id)
				await get_tree().process_frame
				var state := "%s, %s, %s" % [lang, id, "desbloqueado" if MetaProgress.is_hero_unlocked(id) else "bloqueado"]
				var controls: Array[Control] = [screen.get("_go") as Control, screen.get("_cosmetic") as Control]
				_buttons_in(screen, controls)
				for control: Control in controls:
					_check(control.is_visible_in_tree() and view.encloses(control.get_global_rect()),
							"%s: %s dentro da tela (%s)" % [state, control.get_class(), control.get_path()])
				var info := screen.get("_info") as Control
				_check(view.encloses(info.get_parent().get_global_rect()),
						"%s: o painel de texto dentro da tela" % state)
			app.queue_free()
			await get_tree().process_frame
	SaveManager.data["unlocked"]["heroes"] = original_unlocked
	Locale.set_language("pt_BR", false)


## Coleta os botões (BaseButton) de uma árvore de controles.
func _buttons_in(node: Node, out: Array[Control]) -> void:
	for child: Node in node.get_children():
		if child is BaseButton and not out.has(child):
			out.append(child as Control)
		_buttons_in(child, out)


# --- Loja -------------------------------------------------------------------------

## Loja em cada idioma: ao abrir, depois de um resgate, com status de falha e sem anúncio,
## título, voltar, as 6 vagas, dica, status e a linha de botões ficam dentro de 678x305 e
## com pelo menos 8 px até a borda inferior.
func _test_shop_layout() -> void:
	var view := Rect2(Vector2.ZERO, Vector2(678, 305 - 8))
	AdsManager.auto_answer = true
	for lang: String in Locale.SUPPORTED:
		Locale.set_language(lang, false)
		SaveManager.data = SaveManager.default_profile()
		AdsManager.mock_fill = true
		# Host com o tamanho do viewport do jogo: a tela sozinha na árvore de testes não tem esse tamanho.
		var host := Control.new()
		host.size = Vector2(678, 305)
		add_child(host)
		var screen := (load("res://scripts/app/screens/shop_screen.gd") as GDScript).new() as Control
		host.add_child(screen)
		screen.on_show()
		await get_tree().process_frame
		await get_tree().process_frame
		var status := screen.get("_status") as Label
		_check_shop_layout(screen, view, "%s, ao abrir" % lang)

		# Resgate bem-sucedido (anúncio simulado até o fim): a vaga volta a ficar em cronômetro.
		screen.call("_claim", &"slot_ryo")
		var waited := 0.0
		while ShopManager.is_ready(&"slot_ryo") and waited < 10.0:
			await get_tree().create_timer(0.1).timeout
			waited += 0.1
		await get_tree().process_frame
		await get_tree().process_frame
		_check(not ShopManager.is_ready(&"slot_ryo"), "%s: o resgate põe a vaga em cronômetro" % lang)
		_check(status.text == tr("shop.received") % tr("shop.slot_ryo.name"),
				"%s: o status mostra o recebido" % lang)
		_check_shop_layout(screen, view, "%s, depois do resgate" % lang)

		# Status de falha (o texto mais longo de cada caso).
		var long_reward := tr("shop.received") % tr("shop.slot_lantern.name")
		for text: String in [tr("shop.failed"), tr("shop.pending"), tr("shop.watch_full"), long_reward]:
			status.text = text
			await get_tree().process_frame
			_check_shop_layout(screen, view, "%s, status \"%s\"" % [lang, text])

		# Sem anúncio disponível: as vagas prontas ficam desativadas com o aviso.
		SaveManager.data = SaveManager.default_profile()
		AdsManager.mock_fill = false
		screen.call("on_show")
		await get_tree().process_frame
		await get_tree().process_frame
		_check_shop_layout(screen, view, "%s, sem anúncio" % lang)
		AdsManager.mock_fill = true
		host.queue_free()
		await get_tree().process_frame
	AdsManager.auto_answer = false
	Locale.set_language("pt_BR", false)


## Confere que cada botão e texto da Loja está dentro de `view` (ou seja, visível e com
## a folga da borda inferior).
func _check_shop_layout(screen: Control, view: Rect2, state: String) -> void:
	var controls: Array[Control] = []
	_shop_controls_in(screen, controls)
	_check(controls.size() >= 12, "%s: a Loja mostra os controles" % state)
	for control: Control in controls:
		_check(control.is_visible_in_tree() and view.encloses(control.get_global_rect()),
				"%s: %s dentro da tela com folga (%s, %s)" % [state, control.get_class(),
				control.get_global_rect(), control.get_path()])
		# Texto inteiro (sem corte): o motor calcula a altura necessária com a quebra de linha
		# da largura real; ela tem de caber na caixa (Label) ou no botão.
		if control is Label and (control as Label).text != "":
			var label_node := control as Label
			var font := label_node.get_theme_font("font")
			var needed := label_node.get_line_count() * font.get_height(label_node.get_theme_font_size("font_size"))
			_check(needed <= label_node.size.y + 0.5,
					"%s: o texto \"%s\" cabe na caixa (%.0f de %.0f px)" % [state, label_node.text,
					needed, label_node.size.y])
		if control is Button and (control as Button).text != "":
			var button_node := control as Button
			var minimum := button_node.get_combined_minimum_size()
			_check(minimum.x <= button_node.size.x + 0.5 and minimum.y <= button_node.size.y + 0.5,
					"%s: o botão \"%s\" mostra o texto inteiro (%s de %s)" % [state, button_node.text,
					minimum, button_node.size])


## Coleta botões e textos de uma árvore de controles.
func _shop_controls_in(node: Node, out: Array[Control]) -> void:
	for child: Node in node.get_children():
		if (child is BaseButton or child is Label) and not out.has(child):
			out.append(child as Control)
		_shop_controls_in(child, out)


# --- Dados ------------------------------------------------------------------------

func _test_data_integrity() -> void:
	_check(DB.errors.is_empty(), "DB carregou sem erros: %s" % ", ".join(DB.errors))
	for id: StringName in DB.ids("weapons"):
		var w: Dictionary = DB.weapons[id]
		if String(w.get("evolution", "")) != "":
			_check(DB.weapons.has(StringName(w["evolution"])), "%s evolui para arma existente" % id)
			_check(DB.passives.has(StringName(w.get("evolves_with", ""))), "%s evolui com passiva existente" % id)
		for part: Variant in w.get("requires", []):
			_check(DB.weapons.has(StringName(part)), "%s: união pede arma existente %s" % [id, part])
	for id: StringName in DB.ids("heroes"):
		_check(DB.weapons.has(StringName(DB.heroes[id]["weapon"])), "herói %s tem arma existente" % id)
		var unlock := String(DB.heroes[id].get("unlock", ""))
		_check(unlock.is_empty() or DB.achievements.has(StringName(unlock)),
				"herói %s: conquista de desbloqueio existe" % id)
	for id: StringName in DB.ids("stages"):
		var s: Dictionary = DB.stages[id]
		for wave: Variant in s.get("waves", []):
			for enemy: String in (wave as Dictionary)["mix"]:
				_check(DB.enemies.has(StringName(enemy)), "fase %s: inimigo %s existe" % [id, enemy])
		for b: Variant in s.get("bosses", []):
			_check(DB.bosses.has(StringName((b as Dictionary)["id"])), "fase %s: chefe existe" % id)
		for e: Variant in s.get("events", []):
			var enemy := String((e as Dictionary).get("enemy", ""))
			_check(enemy.is_empty() or DB.enemies.has(StringName(enemy)),
					"fase %s: evento usa inimigo existente %s" % [id, enemy])
	var kinds := {"hero": DB.heroes, "weapon": DB.weapons, "passive": DB.passives, "stage": DB.stages}
	for id: StringName in DB.ids("achievements"):
		for part: String in String(DB.achievements[id].get("reward", "")).split(",", false):
			var kv := part.split(":")
			if kinds.has(kv[0]):
				_check((kinds[kv[0]] as Dictionary).has(StringName(kv[1])), "conquista %s: recompensa %s existe" % [id, part])
			else:
				_check(kv[0] in ["ryo", "cosmetic"], "conquista %s: tipo de recompensa conhecido %s" % [id, kv[0]])
	for id: StringName in DB.ids("powerups"):
		_check(StatBlock.DEFS.has(String(DB.powerups[id]["stat"])), "power-up %s usa atributo existente" % id)
	for id: StringName in DB.ids("passives"):
		for stat: String in DB.passives[id]["per_level"]:
			_check(StatBlock.DEFS.has(stat), "passiva %s usa atributo existente %s" % [id, stat])


func _test_assets_exist() -> void:
	var paths: Array[String] = []
	for table: String in ["heroes", "weapons", "passives", "enemies", "bosses", "items", "shop", "kami"]:
		var rows: Dictionary = DB.get(table)
		for id: StringName in rows:
			for key: String in ["sprite", "face", "icon", "attack_sprite"]:
				var value := str((rows[id] as Dictionary).get(key, ""))
				if value.begins_with("res://"):
					paths.append(value)
	var missing: Array[String] = []
	for path: String in paths:
		if not ResourceLoader.exists(path):
			missing.append(path)
	_check(missing.is_empty(), "todos os sprites/ícones existem (%d): faltam %s" % [paths.size(), missing])
	# Todo Kami tem ícone, e o arquivo carrega como textura (não só existe no disco).
	for id: StringName in DB.ids("kami"):
		var icon_path := String(DB.kami[id].get("icon", ""))
		_check(icon_path.begins_with("res://") and load(icon_path) is Texture2D,
				"Kami %s tem ícone que carrega (%s)" % [id, icon_path])
	for id: StringName in DB.ids("stages"):
		var music := "res://assets/audio/music/%s" % DB.stages[id].get("music", "")
		_check(ResourceLoader.exists(music + ".ogg") or ResourceLoader.exists(music + ".mp3"),
				"música da fase %s existe" % id)
	# Toda música tocada pelo código ou pelos chefes também precisa existir.
	var ids: Array[String] = ["title", "dawn", "defeat", "endless", "sanctuary", "story", "credits", "codex"]
	for boss: StringName in DB.ids("bosses"):
		ids.append(String(DB.bosses[boss].get("music", "boss_a")))
	for mid: String in ids:
		var base := "res://assets/audio/music/" + mid
		_check(ResourceLoader.exists(base + ".ogg") or ResourceLoader.exists(base + ".mp3"), "música %s existe" % mid)


# --- Idiomas ----------------------------------------------------------------------

func _test_i18n() -> void:
	_check(Locale.SUPPORTED.size() == 11, "11 idiomas suportados")
	for lang: String in Locale.SUPPORTED:
		var table: Dictionary = Locale.table.get(lang, {})
		_check(table.size() == Locale.keys.size() and table.size() > 600,
				"%s tem todas as %d chaves" % [lang, Locale.keys.size()])
	var formats := {"hud.level": [7], "results.summary": ["12:00", 30, "1.234", "500"],
			"codex.kill_more": [3, 100], "licenses.dates": ["2026-10-21", "2026-10-21"],
			"stat.might": ["+10%"], "shop.remove_ad": ["US$ 2,99"]}
	for lang: String in Locale.SUPPORTED:
		Locale.set_language(lang, false)
		_check(tr("title.play") != "title.play", "%s traduz title.play" % lang)
		for key: String in formats:
			var text := tr(key) % formats[key]
			_check(not (text.contains("%s") or text.contains("%d")), "%s: %s formata sem sobras" % [lang, key])
	Locale.set_language("pt_BR", false)
	_check(tr("title.play") == "Jogar", "pt_BR: Jogar")
	_check(Locale.format_number(1234567) == "1.234.567", "pt_BR separa milhar com ponto")
	Locale.set_language("en", false)
	_check(Locale.format_number(1234567) == "1,234,567", "en separa milhar com vírgula")


## Cada caractere de cada idioma precisa existir na fonte daquele idioma (plano 7.7.2).
func _test_glyphs() -> void:
	for lang: String in Locale.SUPPORTED:
		Locale.set_language(lang, false)
		var font := Locale.font
		var missing: Dictionary = {}
		var table: Dictionary = Locale.table[lang]
		for key: String in table:
			var text := String(table[key])
			for i: int in range(text.length()):
				var code := text.unicode_at(i)
				if code > 32 and code != 0x200B and not font.has_char(code):
					missing[text[i]] = true
		var absent := "".join(PackedStringArray(missing.keys()))
		_check(missing.is_empty(), "%s: fonte cobre todos os caracteres (faltam %s)" % [lang, absent])
	Locale.set_language("pt_BR", false)


# --- Regras -----------------------------------------------------------------------

func _test_stat_block() -> void:
	var stats := StatBlock.new()
	_check(is_equal_approx(stats.get_stat("max_hp"), 100.0), "vida base 100")
	stats.set_source("hero", {"max_hp": 0.2, "armor": 1.0})
	stats.set_source("passive", {"max_hp": 0.1})
	_check(is_equal_approx(stats.get_stat("max_hp"), 130.0), "percentuais somam: +20% e +10% = 130")
	_check(is_equal_approx(stats.get_stat("armor"), 1.0), "armadura soma direto")
	stats.set_source("curse", {"cooldown": -5.0})
	_check(is_equal_approx(stats.get_stat("cooldown"), StatBlock.MIN_COOLDOWN), "recarga tem piso")
	stats.remove_source("passive")
	_check(is_equal_approx(stats.get_stat("max_hp"), 120.0), "remover fonte recalcula")
	stats.set_source("hero", {})
	_check(not stats.has_source("hero"), "fonte vazia é removida")


func _test_descriptions() -> void:
	Locale.set_language("en", false)
	_check(LevelUpSystem.describe_stats({"might": 0.1}) == "+10% Might", "descreve +10% Might")
	_check(LevelUpSystem.describe_stats({"armor": 1.0}) == "+1 Armor", "descreve +1 Armor")
	_check(LevelUpSystem.describe_stats({"crit": 0.1}) == "+10% Critical chance", "crítico em %")
	_check(LevelUpSystem.describe_delta({"amount": 1, "damage": 5}) == "+1 projectile, +5 damage",
			"descreve delta de arma")
	_check(LevelUpSystem.describe_delta({"cooldown": -0.1}) == "-10% cooldown", "delta percentual negativo")
	Locale.set_language("pt_BR", false)


func _test_save_migration() -> void:
	var old := {"version": 0, "ryo": 321, "unlocked": {"heroes": ["aki", "kenta"]}}
	var migrated: Dictionary = SaveManager.migrate(old)
	_check(int(migrated["ryo"]) == 321, "migração mantém ryō")
	_check((migrated["unlocked"]["heroes"] as Array).has("kenta"), "migração mantém heróis")
	_check(migrated["unlocked"].has("stages") and migrated.has("shop"), "migração completa campos novos")
	_check(int(migrated["version"]) == SaveManager.VERSION, "migração atualiza versão")


func _test_sanctuary() -> void:
	SaveManager.data = SaveManager.default_profile()
	SaveManager.data["ryo"] = 100000
	var first := MetaProgress.powerup_price(&"pu_might")
	_check(MetaProgress.buy(&"pu_might"), "compra o primeiro power-up")
	_check(MetaProgress.powerup_price(&"pu_might") > first, "o próximo nível custa mais")
	var armor_before := MetaProgress.powerup_price(&"pu_armor")
	_check(MetaProgress.buy(&"pu_max_hp"), "compra outro power-up")
	_check(MetaProgress.powerup_price(&"pu_armor") > armor_before, "comprar encarece os outros")
	var spent := 100000 - SaveManager.ryo()
	_check(MetaProgress.refund_all() == spent and SaveManager.ryo() == 100000, "reembolso devolve exatamente o gasto")
	_check(MetaProgress.powerup_modifiers().is_empty(), "reembolso zera os power-ups")


func _test_shop_clock() -> void:
	SaveManager.data = SaveManager.default_profile()
	var real := int(Time.get_unix_time_from_system())
	_check(ShopManager.is_ready(&"slot_ryo"), "vaga nova está pronta")
	SaveManager.data["shop"]["slots"]["slot_ryo"] = real + ShopManager.COOLDOWN
	_check(not ShopManager.is_ready(&"slot_ryo"), "vaga usada espera 6 h")
	# Simula relógio que já esteve 1 dia à frente: voltar o relógio não libera a vaga.
	SaveManager.data["shop"]["max_seen_unix"] = real + 86400
	SaveManager.data["shop"]["slots"]["slot_luck"] = real + 86400 + 60
	_check(not ShopManager.is_ready(&"slot_luck"), "relógio voltado não encurta a espera")
	_check(ShopManager.now() == real + 86400, "usa o maior horário já visto")
	SaveManager.data["shop"]["next_run"] = {"slot_luck": true, "slot_lantern": true}
	var bonus := ShopManager.take_next_run_bonuses()
	_check(is_equal_approx(float(bonus["modifiers"]["reroll"]), 2.0), "bônus da próxima partida aplica rerolagens")
	_check(int(bonus["ult_start"]) == 50, "Lanterna Abençoada carrega o golpe")
	_check(ShopManager.pending_next_run().is_empty(), "bônus é consumido uma vez")


func _test_ads_rules() -> void:
	SaveManager.data = SaveManager.default_profile()
	SaveManager.data["launches"] = 1
	_check(not AdsManager.should_show_app_open(), "sem anúncio de abertura na 1ª abertura")
	SaveManager.data["launches"] = 3
	_check(AdsManager.should_show_app_open(), "anúncio de abertura a partir da 2ª abertura")
	SaveManager.data["last_open_ad_unix"] = int(Time.get_unix_time_from_system()) - 60
	_check(not AdsManager.should_show_app_open(), "respeita o intervalo de 4 h")
	SaveManager.data["last_open_ad_unix"] = 0
	SaveManager.data["purchases"]["remove_open_ad"] = true
	_check(not AdsManager.should_show_app_open(), "compra remove o anúncio de abertura")


## Partida suspensa (plano 10.11): snapshot → nova partida → restaurar dá o mesmo estado.
## Congelado (ampulheta): só troca a cor do sprite, sem desenho extra por inimigo.
func _test_frozen_tint() -> void:
	var base := Color(1.0, 0.5, 0.2, 0.7)
	_check(EnemyManager.frozen_tint(base, false) == base, "fora do congelamento a cor não muda")
	var frozen := EnemyManager.frozen_tint(base, true)
	_check(frozen != base, "congelado muda a cor do inimigo")
	_check(frozen.b > base.b, "congelado fica mais azulado")
	_check(is_equal_approx(frozen.a, base.a), "congelado mantém a transparência")


func _test_suspended_run() -> void:
	var scene := load(GAME_SCENE) as PackedScene
	var cfg := {"hero": "goro", "stage": "bamboo", "moon": 1, "mode": "normal", "seed": 77, "speed": 2}
	var first := scene.instantiate() as HyakkiGame
	first.config = cfg.duplicate()
	add_child(first)
	await get_tree().process_frame
	first.add_weapon(&"kunai")
	first.get_weapon(&"kunai").level_up()
	first.get_weapon(&"kunai").level_up()
	first.level_up.passive_levels[&"sake"] = 2
	first.kami.accept(&"susanoo", true)
	first.level = 9
	first.xp = 5
	GameClock.game_time = 333.0
	first.player.hp = 42.0
	var snap := first.snapshot()
	first.queue_free()
	await get_tree().process_frame
	var json_round: Dictionary = JSON.parse_string(JSON.stringify(snap))
	var second := scene.instantiate() as HyakkiGame
	second.config = json_round["config"]
	add_child(second)
	await get_tree().process_frame
	second.restore_snapshot(json_round)
	var again := second.snapshot()
	for key: String in ["level", "xp", "weapons", "passives", "kami", "hp"]:
		_check(JSON.stringify(again[key]) == JSON.stringify(snap[key]), "partida retomada mantém %s" % key)
	_check(is_equal_approx(GameClock.game_time, 333.0), "partida retomada mantém o tempo")
	_check(is_equal_approx(second.player.stats.get_stat("might"), 1.0 + 0.2 + 0.25),
			"retomada reaplica passivas e Kami no StatBlock")
	second.queue_free()
	GameClock.paused = false
	await get_tree().process_frame


## Reviver por anúncio (17.6): em qualquer modo, inclusive o Desafio Diário, o anúncio
## recompensado devolve o herói no mesmo instante, sem reiniciar: mesmo tempo, abates, nível
## e armas. Um segundo reviver não é oferecido. Partida salva durante a morte volta com a oferta.
func _test_revive_by_ad() -> void:
	var scene := load(GAME_SCENE) as PackedScene
	var modes := [
		{"name": "campanha", "daily": false, "endless": false},
		{"name": "noite sem fim", "daily": false, "endless": true},
		{"name": "diário", "daily": true, "endless": false},
	]
	AdsManager.auto_answer = true
	for mode: Dictionary in modes:
		var label: String = mode["name"]
		var cfg := {"hero": "goro", "stage": "bamboo", "moon": 0, "mode": "normal", "seed": 91,
				"speed": 1, "daily": mode["daily"], "endless": mode["endless"]}
		var game := scene.instantiate() as HyakkiGame
		game.config = cfg
		add_child(game)
		await get_tree().process_frame
		# Estado fixado logo antes da morte, sem esperar tempo real: abates e níveis só
		# mudam pelo que a própria simulação faz, e aqui não há nenhum passo entre a
		# montagem e a morte.
		game.endless_phase = bool(mode["endless"])
		GameClock.game_time = 42.0
		game.tracker.kills = 7
		game.level = 4
		game.player.god_mode = false
		game.player.revives_used = 99
		game.player.invuln = 0.0
		var weapons_before := game.weapons.size()
		game.player.take_damage(99999.0)
		_check(game.hud.revive_open(), "%s: morrer abre a oferta de reviver" % label)
		_check(GameClock.paused, "%s: a morte pausa o tempo" % label)
		var time_at_death := GameClock.game_time
		var snap := game.snapshot()
		_check(bool(snap["dead"]) and not bool(snap["ad_revive_used"]),
				"%s: partida salva na morte guarda a morte" % label)

		# Aceitar (o painel fecha antes de emitir, como no botão).
		game.hud._revive_panel.visible = false
		game.hud.revive_answered.emit(true)
		var waited := 0.0
		while GameClock.paused and waited < 8.0:
			await get_tree().create_timer(0.1).timeout
			waited += 0.1
		_check(game.running and game.player.is_alive, "%s: depois do anúncio a partida segue viva" % label)
		_check(GameClock.game_time >= time_at_death and GameClock.game_time < time_at_death + 1.0,
				"%s: o tempo de jogo continua de onde parou" % label)
		_check(game.tracker.kills == 7 and game.level == 4 and game.weapons.size() == weapons_before,
				"%s: abates, nível e armas são mantidos" % label)
		_check(game.tracker.revived_by_ad, "%s: o resultado marca o reviver por anúncio" % label)
		var later := GameClock.game_time
		await get_tree().create_timer(0.5).timeout
		_check(GameClock.game_time > later, "%s: o tempo volta a correr" % label)

		# Um segundo reviver não é oferecido.
		game.player.invuln = 0.0
		game.player.take_damage(99999.0)
		_check(not game.hud.revive_open() and not game.running,
				"%s: só um reviver por partida" % label)

		if label == "campanha":
			# App fechado durante o anúncio: a partida salva volta à morte, com a oferta.
			var json_snap: Dictionary = JSON.parse_string(JSON.stringify(snap))
			var again := scene.instantiate() as HyakkiGame
			again.config = json_snap["config"]
			add_child(again)
			await get_tree().process_frame
			again.restore_snapshot(json_snap)
			_check(again.hud.revive_open(), "partida salva durante a morte volta com a oferta")
			again.queue_free()
			await get_tree().process_frame
		game.queue_free()
		await get_tree().process_frame
	AdsManager.auto_answer = false
	GameClock.paused = true
