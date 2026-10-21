extends Node
## Testes com os autoloads carregados (plano 14.1 e 15.1): dados, idiomas, fontes,
## atributos, Santuário, Loja e save. Rodar:
##   godot --headless --path . res://tests/integration_tests.tscn
## O save do jogador é copiado antes e restaurado no fim; nada do perfil real se perde.

const SAVE_FILES := ["user://save.json", "user://save.bak"]

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
	await _test_suspended_run()
	_restore_save()
	print("%d verificações, %d falhas" % [_count, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	_count += 1
	if not condition:
		_failures += 1
		printerr("FALHOU: " + label)


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
	for table: String in ["heroes", "weapons", "passives", "enemies", "bosses", "items", "shop"]:
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
func _test_suspended_run() -> void:
	var scene := load("res://scenes/game/Game.tscn") as PackedScene
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
