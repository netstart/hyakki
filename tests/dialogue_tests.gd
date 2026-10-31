extends RefCounted
## Diálogo antes dos chefes (data/dialogues.json, scripts/systems/dialogue_script.gd,
## scripts/ui/dialogue_panel.gd, HyakkiGame.open_dialogue, BossDirector.spawn e
## RiftPortal.spawn_midboss):
##   - dados (sem autoloads): todo chefe das 10:00 e todo Guardião do Limiar de data/stages.json
##     tem roteiro com abertura e fecho do chefe e a resposta de cada um dos heróis de
##     data/heroes.json; o aparte de um companheiro some quando ele é o herói da partida (Tora no
##     Velho Kappa, Tora e Goro no Monge sem Rosto, Hana no Onmoraki, Rin no Onibi), sobrando de
##     3 a 4 falas; toda chave existe em i18n/strings.csv; "Mostrar diálogos sempre" vem desligada;
##   - regras (com a árvore): build() para todo chefe × herói, textos e nomes traduzidos nos 11
##     idiomas, retrato de quem fala, visto ao abrir, opção "sempre", Shinigami calado e o save
##     novo com "dialogue_seen";
##   - partida: aviso do Guardião aos 7:26, diálogo aos 7:30 com o relógio parado e a entrada
##     (painel com o selo 門, aviso "Guardião do Limiar", música) só depois; segunda partida sem
##     diálogo, com a opção ligada ele volta; o mesmo para o chefe das 10:00 (Velho Kappa, 3 falas
##     com Tora); o Dragão de Cinzas aos 5:00 do Santuário Secreto entra calado; o Guardião chamado
##     de novo ao retomar a partida não repete o diálogo.
## run_unit() roda sem autoloads (tests/run_tests.gd); run() precisa da árvore
## (tests/integration_tests.gd ou tests/dialogue_tests.tscn).

const GAME_SCENE := "res://scenes/game/Game.tscn"
const STEP := 1.0 / 60.0
## Apartes que somem para o próprio companheiro (e para Goro, aluno do Monge sem Rosto).
const ASIDE_SKIPS := {"kappa_elder": ["tora"], "faceless_monk": ["tora", "goro"], "onmoraki": ["hana"],
		"onibi": ["rin"]}

var _check: Callable
var _host: Node


static func _json(name: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/%s.json" % name))


## Ids dos chefes com diálogo: o último chefe de cada fase (10:00) e o Guardião do Limiar.
static func dialogue_bosses(stages: Array) -> Array[String]:
	var out: Array[String] = []
	for s: Dictionary in stages:
		var bosses: Array = s.get("bosses", [])
		for id: String in [String((bosses.back() as Dictionary)["id"]) if not bosses.is_empty() else "",
				String((s.get("midboss", {}) as Dictionary).get("id", ""))]:
			if not id.is_empty() and not out.has(id):
				out.append(id)
	return out


# --- Dados (sem autoloads) ----------------------------------------------------------------

func run_unit(check: Callable) -> void:
	_check = check
	var stages: Array = _json("stages")
	var heroes: Array[String] = []
	for h: Dictionary in _json("heroes"):
		heroes.append(String(h["id"]))
	var scripts: Dictionary = _json("dialogues")
	var csv_keys := _csv_keys()
	var ids := dialogue_bosses(stages)
	_check.call(ids.size() == stages.size() * 2, "diálogo: chefe das 10:00 e Guardião em cada fase (%d)" % ids.size())
	for id: String in ids:
		_check_script(id, scripts.get(id, {}), heroes, csv_keys)
	for id: String in scripts:
		_check.call(ids.has(id), "diálogo: %s é chefe das 10:00 ou Guardião" % id)
	var settings := load("res://scripts/autoload/settings.gd") as GDScript
	var defaults: Dictionary = settings.get_script_constant_map()["DEFAULTS"]
	_check.call(defaults.has("dialogues_always") and defaults["dialogues_always"] == true,
			"opção dialogues_always vem ligada por padrão")
	_check.call(defaults.get("notifications") == true, "opção notifications vem ligada por padrão")


func _check_script(id: String, entry: Variant, heroes: Array[String], csv_keys: Dictionary) -> void:
	var lines: Array = (entry as Dictionary).get("lines", []) if typeof(entry) == TYPE_DICTIONARY else []
	_check.call(not lines.is_empty(), "diálogo: %s tem roteiro" % id)
	if lines.is_empty():
		return
	_check.call(String(lines[0]["who"]) == "boss" and String(lines.back()["who"]) == "boss",
			"diálogo: %s abre e fecha com o chefe" % id)
	var missing: Array[String] = []
	var replies := 0
	for raw: Dictionary in lines:
		var who := String(raw["who"])
		var key := String(raw["key"])
		_check.call(["boss", "hero", "tora", "hana", "rin"].has(who), "diálogo: %s, quem fala (%s)" % [id, who])
		if who == "hero":
			replies += 1
			for hero: String in heroes:
				if not csv_keys.has("%s.%s" % [key, hero]):
					missing.append("%s.%s" % [key, hero])
		elif not csv_keys.has(key):
			missing.append(key)
		if who in ["tora", "hana", "rin"]:
			_check.call((raw.get("skip", []) as Array).has(who), "diálogo: %s, %s não faz aparte para si" % [id, who])
	_check.call(replies == 1, "diálogo: %s com uma resposta do herói" % id)
	_check.call(missing.is_empty(), "diálogo: %s com todas as chaves no CSV (faltam %s)" % [id, missing])
	for hero: String in heroes:
		var kept: Array = lines.filter(func(l: Dictionary) -> bool: return not (l.get("skip", []) as Array).has(hero))
		var asides := kept.filter(func(l: Dictionary) -> bool: return String(l["who"]) in ["tora", "hana", "rin"])
		_check.call(kept.size() >= 3 and kept.size() <= 4,
				"diálogo: %s com %s tem 3 a 4 falas (%d)" % [id, hero, kept.size()])
		if ASIDE_SKIPS.has(id) and (ASIDE_SKIPS[id] as Array).has(hero):
			_check.call(asides.is_empty(), "diálogo: %s sem aparte quando o herói é %s" % [id, hero])
	for hero: String in ASIDE_SKIPS.get(id, []):
		var skips := lines.any(func(l: Dictionary) -> bool: return (l.get("skip", []) as Array).has(hero))
		_check.call(skips, "diálogo: %s pula o aparte para %s" % [id, hero])


static func _csv_keys() -> Dictionary:
	var keys := {}
	var file := FileAccess.open("res://i18n/strings.csv", FileAccess.READ)
	if file == null:
		return keys
	file.get_csv_line()
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() > 1:
			keys[row[0]] = true
	return keys


# --- Regras e partida (com a árvore) -----------------------------------------------------

func run(host: Node, check: Callable) -> void:
	_host = host
	_check = check
	var saved: Dictionary = SaveManager.data
	var always: Variant = Settings.get_value("dialogues_always")
	_test_build()
	_test_texts()
	_test_rules()
	await _test_midboss_flow()
	await _test_boss_flow()
	await _test_secret_five()
	await _test_restore()
	Settings.set_value("dialogues_always", always)
	SaveManager.data = saved
	GameClock.paused = false
	await _host.get_tree().process_frame


func _ids() -> Array[String]:
	var stages: Array = []
	for id: StringName in DB.ids("stages"):
		stages.append(DB.stage(id))
	return dialogue_bosses(stages)


func _test_build() -> void:
	for id: String in _ids():
		for hero: StringName in DB.ids("heroes"):
			var lines := DialogueScript.build(StringName(id), hero)
			var tag := "diálogo: build(%s, %s)" % [id, hero]
			_check.call(lines.size() >= 3 and lines.size() <= 4, "%s com 3 a 4 falas (%d)" % [tag, lines.size()])
			if lines.size() < 3:
				continue
			_check.call(lines[0]["who"] == "boss" and lines[0]["side"] == "right" and lines[0]["speaker_id"] == StringName(id)
					and lines.back()["who"] == "boss", "%s: abre e fecha com o chefe, à direita" % tag)
			_check.call(lines[1]["who"] == "hero" and lines[1]["speaker_id"] == hero and lines[1]["side"] == "left"
					and String(lines[1]["text_key"]) == "dialog.%s.reply.%s" % [id, hero],
					"%s: resposta do herói da partida, à esquerda" % tag)
			for line: Dictionary in lines:
				_check.call(String(line["who"]) == "boss" or line["speaker_id"] != hero or line["who"] == "hero",
						"%s: nenhum aparte do próprio herói" % tag)
	_check.call(DialogueScript.build(&"kappa_elder", &"tora").size() == 3, "diálogo: Velho Kappa com Tora tem 3 falas")
	_check.call(DialogueScript.build(&"faceless_monk", &"goro").size() == 3,
			"diálogo: Monge sem Rosto com Goro tem 3 falas")
	_check.call(DialogueScript.build(&"onmoraki", &"hana").size() == 3, "diálogo: Onmoraki com Hana tem 3 falas")
	_check.call(DialogueScript.build(&"onibi", &"rin").size() == 3, "diálogo: Onibi com Rin tem 3 falas")
	_check.call(DialogueScript.build(&"kappa_elder", &"aki").size() == 4, "diálogo: Velho Kappa com Aki tem 4 falas")
	_check.call(DialogueScript.build(&"tanuki", &"aki").is_empty() and not DialogueScript.has_dialogue(&"tanuki"),
			"diálogo: chefe dos 5:00 sem roteiro")
	_check.call(not DialogueScript.has_dialogue(&"shinigami"), "diálogo: o Shinigami nunca fala")


## Toda fala e todo nome traduzidos nos 11 idiomas; retrato de quem fala existe e carrega.
func _test_texts() -> void:
	var lines: Array[Dictionary] = []
	for id: String in _ids():
		for hero: StringName in DB.ids("heroes"):
			lines.append_array(DialogueScript.build(StringName(id), hero))
	var faces := {}
	for line: Dictionary in lines:
		faces[DialogueScript.face_path(line)] = String(line["speaker_id"])
	for path: String in faces:
		_check.call(not path.is_empty() and ResourceLoader.exists(path) and DialoguePanel.face_texture(path) != null,
				"diálogo: retrato de %s (%s)" % [faces[path], path])
	for lang: String in Locale.SUPPORTED:
		Locale.set_language(lang, false)
		var missing: Array[String] = []
		for line: Dictionary in lines:
			for key: String in [String(line["text_key"]), DialogueScript.name_key(line)]:
				if tr(key) == key or tr(key).strip_edges().is_empty():
					if not missing.has(key):
						missing.append(key)
		_check.call(missing.is_empty(), "diálogo: %s traduz todas as falas e nomes (faltam %s)" % [lang, missing])
	Locale.set_language("pt_BR", false)


func _test_rules() -> void:
	Settings.set_value("dialogues_always", false)
	SaveManager.data = SaveManager.default_profile()
	var seen: Variant = SaveManager.data.get("dialogue_seen")
	_check.call(seen is Dictionary and (seen as Dictionary).is_empty(),
			"diálogo: perfil novo sem diálogos vistos")
	_check.call(DialogueScript.should_show(&"onikuma") and not DialogueScript.seen(&"onikuma"),
			"diálogo: 1º encontro mostra")
	DialogueScript.mark_seen(&"onikuma")
	_check.call(DialogueScript.seen(&"onikuma") and not DialogueScript.should_show(&"onikuma"),
			"diálogo: visto não repete")
	_check.call(DialogueScript.should_show(&"kappa_elder"), "diálogo: visto vale por chefe")
	Settings.set_value("dialogues_always", true)
	_check.call(DialogueScript.should_show(&"onikuma"), "diálogo: opção \"sempre\" mostra de novo")
	_check.call(not DialogueScript.should_show(&"tanuki") and not DialogueScript.should_show(&"shinigami"),
			"diálogo: opção \"sempre\" não inventa roteiro")
	Settings.set_value("dialogues_always", false)
	SaveManager.data.erase("dialogue_seen")
	_check.call(DialogueScript.should_show(&"onikuma"), "diálogo: save sem a chave mostra")
	DialogueScript.mark_seen(&"onikuma")
	_check.call(DialogueScript.seen(&"onikuma"), "diálogo: mark_seen cria a chave")
	var migrated: Dictionary = SaveManager.migrate({"version": 0, "ryo": 5})
	_check.call(migrated.get("dialogue_seen") is Dictionary, "diálogo: migração cria dialogue_seen")
	SaveManager.data = SaveManager.default_profile()


func _new_game(hero: String = "aki", stage_id: String = "village") -> HyakkiGame:
	var game := (load(GAME_SCENE) as PackedScene).instantiate() as HyakkiGame
	game.config = {"hero": hero, "stage": stage_id, "moon": 0, "mode": "normal", "seed": 909, "speed": 1}
	_host.add_child(game)
	await _host.get_tree().process_frame
	GameClock.paused = true
	game.player.god_mode = true
	return game


func _free(game: HyakkiGame) -> void:
	game.queue_free()
	GameClock.paused = true
	await _host.get_tree().process_frame


## Pula para `from` e anda passo a passo até `cond` (ou `seconds`), com o relógio solto como na
## partida; outras telas (nível, baú, Kami) são respondidas como o bot, o diálogo não.
func _run_until(game: HyakkiGame, from: float, seconds: float, cond: Callable) -> bool:
	GameClock.game_time = from
	game.spawner.skip_until(from)
	GameClock.paused = false
	for _k: int in roundi(seconds / STEP):
		GameClock.game_time += STEP
		game._on_tick(STEP)
		if game.hud.overlay_open() and not game.hud.dialogue_open():
			game.hud.bot_answer()
			GameClock.paused = false
		if cond.call():
			return true
	return false


func _toast(game: HyakkiGame) -> String:
	return String((game.hud.get("_toast") as Label).text)


func _music() -> String:
	return String(AudioManager.get("_music_id"))


## Guardião aos 7:30: aviso, diálogo com a luta parada e só depois a entrada.
func _test_midboss_flow() -> void:
	SaveManager.data = SaveManager.default_profile()
	Settings.set_value("dialogues_always", false)
	var game := await _new_game()
	var warned := [false]
	var opened := _run_until(game, 445.0, 8.0, func() -> bool:
		warned[0] = warned[0] or _toast(game) == tr("midboss.warning")
		return game.hud.dialogue_open())
	var tag := "diálogo do Guardião"
	_check.call(warned[0], "%s: aviso antes da entrada" % tag)
	_check.call(opened and GameClock.game_time >= 450.0 and GameClock.game_time < 450.0 + STEP * 2.0,
			"%s: abre aos 7:30 (%.2f)" % [tag, GameClock.game_time])
	_check.call(GameClock.paused and game.hud.overlay_open(), "%s: a luta para" % tag)
	_check.call(game.bosses.has_boss(&"onikuma"), "%s: Onikuma já em campo, parado" % tag)
	_check.call(not game.hud.boss_panel().visible and _toast(game) != tr("midboss.title") and _music() != "midboss",
			"%s: painel, aviso \"Guardião do Limiar\" e música só depois" % tag)
	var panel := game.hud.dialogue_panel()
	_check.call(panel.lines().size() == 4 and panel.speaker_name() == tr("boss.onikuma.name")
			and panel.current_side() == "right" and panel.portrait() != null,
			"%s: 4 falas, abre com o chefe à direita e com retrato" % tag)
	_check.call(DialogueScript.seen(&"onikuma"), "%s: marcado como visto ao abrir" % tag)
	game.hud.bot_answer()
	_check.call(not game.hud.dialogue_open() and not GameClock.paused, "%s: bot fecha e o relógio volta" % tag)
	var boss := game.hud.boss_panel()
	_check.call(boss.visible and boss.seal_glyph == "門" and boss.title == tr("boss.onikuma.name"),
			"%s: depois, painel do chefe com o selo 門" % tag)
	_check.call(_toast(game) == tr("midboss.title") and _music() == "midboss",
			"%s: depois, aviso e música do Guardião" % tag)
	await _free(game)
	# Segunda partida: já visto.
	game = await _new_game()
	var again := _run_until(game, 445.0, 6.0, func() -> bool: return game.hud.dialogue_open())
	_check.call(not again and game.bosses.has_boss(&"onikuma") and game.hud.boss_panel().visible
			and _toast(game) == tr("midboss.title"), "%s: segunda partida entra direto" % tag)
	await _free(game)
	# Opção "Mostrar diálogos sempre".
	Settings.set_value("dialogues_always", true)
	game = await _new_game()
	_check.call(_run_until(game, 445.0, 6.0, func() -> bool: return game.hud.dialogue_open())
			and not game.hud.boss_panel().visible, "%s: com a opção ligada, volta" % tag)
	game.hud.dialogue_panel().skip()
	_check.call(not game.hud.dialogue_open() and not GameClock.paused and game.hud.boss_panel().visible,
			"%s: \"Pular\" segue com a entrada" % tag)
	await _free(game)
	Settings.set_value("dialogues_always", false)


## Chefe das 10:00 (Velho Kappa na Vila), com Aki e com Tora (sem o aparte dele mesmo).
func _test_boss_flow() -> void:
	SaveManager.data = SaveManager.default_profile()
	var game := await _new_game()
	var tag := "diálogo do Velho Kappa"
	var opened := _run_until(game, 598.0, 4.0, func() -> bool: return game.hud.dialogue_open())
	_check.call(opened and GameClock.game_time >= 600.0 and GameClock.paused and game.bosses.has_boss(&"kappa_elder"),
			"%s: abre aos 10:00 com a luta parada" % tag)
	_check.call(not game.hud.boss_panel().visible and _music() != "boss_b", "%s: painel e música só depois" % tag)
	_check.call(game.hud.dialogue_panel().lines().size() == 4, "%s: 4 falas com Aki" % tag)
	game.hud.bot_answer()
	var boss := game.hud.boss_panel()
	_check.call(not GameClock.paused and boss.visible and boss.title == tr("boss.kappa_elder.name")
			and _music() == "boss_b",
			"%s: depois do diálogo, painel e música" % tag)
	await _free(game)
	game = await _new_game()
	_check.call(not _run_until(game, 598.0, 4.0, func() -> bool: return game.hud.dialogue_open())
			and game.hud.boss_panel().visible, "%s: segunda partida entra direto" % tag)
	await _free(game)
	SaveManager.data = SaveManager.default_profile()
	game = await _new_game("tora")
	_check.call(_run_until(game, 598.0, 4.0, func() -> bool: return game.hud.dialogue_open()), "%s com Tora: abre" % tag)
	var lines := game.hud.dialogue_panel().lines()
	var whos: Array = lines.map(func(l: Dictionary) -> String: return String(l["who"]))
	_check.call(lines.size() == 3 and whos == ["boss", "hero", "boss"] and lines[1]["speaker_id"] == &"tora",
			"%s com Tora: 3 falas, sem o aparte (%s)" % [tag, whos])
	game.hud.bot_answer()
	await _free(game)


## O Dragão de Cinzas é o chefe dos 5:00 do Santuário Secreto: lá ele entra sem diálogo.
func _test_secret_five() -> void:
	SaveManager.data = SaveManager.default_profile()
	var game := await _new_game("aki", "secret")
	var opened := _run_until(game, 298.0, 4.0, func() -> bool: return game.hud.dialogue_open())
	_check.call(not opened and game.bosses.has_boss(&"ash_dragon") and not DialogueScript.seen(&"ash_dragon"),
			"diálogo: Dragão de Cinzas aos 5:00 do Santuário Secreto entra calado")
	await _free(game)


## Guardião em campo ao suspender: chamado de novo na retomada, sem diálogo (nem com a opção).
func _test_restore() -> void:
	SaveManager.data = SaveManager.default_profile()
	Settings.set_value("dialogues_always", true)
	var game := await _new_game()
	GameClock.game_time = 455.0
	game.spawner.skip_until(455.0)
	var snap: Dictionary = JSON.parse_string(JSON.stringify(game.snapshot()))
	await _free(game)
	var again := await _new_game()
	again.restore_snapshot(snap)
	_check.call(again.bosses.has_boss(&"onikuma") and not again.hud.dialogue_open()
			and again.hud.boss_panel().visible and _toast(again) == tr("midboss.title"),
			"diálogo: Guardião chamado de novo na retomada não repete o diálogo")
	await _free(again)
	Settings.set_value("dialogues_always", false)
