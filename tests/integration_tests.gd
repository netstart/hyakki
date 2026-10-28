extends Node
## Testes com os autoloads carregados (plano 14.1 e 15.1): dados, idiomas, fontes,
## atributos, Santuário, Loja e save. Rodar:
##   godot --headless --path . res://tests/integration_tests.tscn
## Save e opções vão para arquivos próprios dos testes (SaveManager.use_test_files e
## Settings.use_test_file) antes de qualquer verificação: nem um teste interrompido no meio
## mexe no perfil ou no settings.cfg do jogador.

const GAME_SCENE := "res://scenes/game/Game.tscn"
## Layout e rolagem da Loja (separado para o arquivo caber no limite de linhas do gdlint).
const ShopLayoutTests := preload("res://tests/shop_layout_tests.gd")
## Guardiões, Opções, Diário e o "voltar" nas telas de tests/device_profiles.gd e em 480x270.
const MenusLayoutTests := preload("res://tests/menus_layout_tests.gd")
const OPTIONS_SCREEN := "res://scripts/app/screens/options_screen.gd"
## Raios do céu do Raijin (separado para o arquivo caber no limite de linhas do gdlint).
const RaijinBoltTests := preload("res://tests/raijin_bolt_tests.gd")
## Onikiri e Dōjigiri, a espada da Yuki: combo, meia-lua, golpe final e onda.
const OnikiriTests := preload("res://tests/onikiri_tests.gd")
## Mão, tamanho e pose de ataque dos heróis "side" (Yuki).
const HeroHandTests := preload("res://tests/hero_hand_tests.gd")
## Santuário sem rolagem: cartões, painel de detalhes e estados, em todos os idiomas.
const SanctuaryLayoutTests := preload("res://tests/sanctuary_layout_tests.gd")
## Som das armas: prioridade de canais, Katana em camadas e farfalhar da Ofuda.
const WeaponAudioTests := preload("res://tests/weapon_audio_tests.gd")
## Efeitos das armas: cotas por nível, troca ao vivo, rastros, brilho, golpe e determinismo.
const WeaponFxTests := preload("res://tests/weapon_fx_tests.gd")
## Sequência de morte: queda, aviso, reviver, bot, desistir e restauração.
const DeathSequenceTests := preload("res://tests/death_sequence_tests.gd")
## Resultados: colunas, armas, conquistas, dobrar ryō e recorde em cada idioma.
const ResultsLayoutTests := preload("res://tests/results_layout_tests.gd")
## Título: coluna de menu, bloco de ação, selos e foco, em todos os idiomas.
const TitleLayoutTests := preload("res://tests/title_layout_tests.gd")
## HUD da partida: topo, botões, joystick, avisos, reviver, setas e o painel de Kami, em cada
## resolução e com o recorte da câmera.
const HudLayoutTests := preload("res://tests/hud_layout_tests.gd")
## Jornada do Guardião (seleção de fase): mapa, pontos, estados e pergaminho em cada idioma.
const StageMapLayoutTests := preload("res://tests/stage_map_layout_tests.gd")
## Explosão atrás do baú da fase: abertura, centro, fim sozinho, pular e novo baú.
const ChestBurstTests := preload("res://tests/chest_burst_tests.gd")
## Telas de nova habilidade e do baú: fluxo, qualidade gráfica e layout em cada idioma.
const LevelChestTests := preload("res://tests/level_chest_tests.gd")
## Desbloqueios de conquistas reaplicados em saves antigos (Onikiri do Oni Vermelho).
const AchievementRewardTests := preload("res://tests/achievement_reward_tests.gd")
## Fundo dos menus (Hyakki Yagyō): camadas, procissão na crista, guardiã escolhida e tamanhos.
const MenuBackdropTests := preload("res://tests/menu_backdrop_tests.gd")
## Pausa: ícone do canto, botão de velocidade, música, desistir com confirmação e layout.
const PauseMenuTests := preload("res://tests/pause_menu_tests.gd")
## Créditos: toda entrada de licenses/index.json visível, layout, arrasto e roda.
const CreditsScreenTests := preload("res://tests/credits_screen_tests.gd")
## Qualidade gráfica: opção, troca ao vivo, rebaixamento adaptativo, Opções e pausa.
const GfxQualityTests := preload("res://tests/gfx_quality_tests.gd")
## Inimigos, onis, chefes e guardiã (efeitos, painel do chefe, determinismo por nível).
const EnemyFxTests := preload("res://tests/enemy_fx_tests.gd")
## Clima dinâmico: ciclo determinístico, lama (lentidão), relâmpagos, orçamentos e troca ao vivo.
const WeatherTests := preload("res://tests/weather_tests.gd")
## Superfícies lentas: todos os tipos × guardiã, inimigo, elite e chefe; recuperação até 1.0.
const SurfaceTests := preload("res://tests/surface_tests.gd")
## Ícones de habilidade (arquivos, pintor da HUD, 3 níveis): tests/skill_icon_tests.gd.
const SkillIconTests := preload("res://tests/skill_icon_tests.gd")
## Modo "sem anúncios" (release sem IDs do AdMob ou --ads-off): presentes, sem abertura nem compra.
const AdsOffTests := preload("res://tests/ads_off_tests.gd")
## Furo da câmera trocando de lado com cada tela aberta, sem redimensionar (giro de 180°).
const InsetFlipTests := preload("res://tests/inset_flip_tests.gd")
## Aparelhos-alvo dos testes de layout (Redmi Note 14 Pro+, Galaxy M55, Pixel 7) e o furo da câmera.
const DeviceProfiles := preload("res://tests/device_profiles.gd")

var _count: int = 0
var _failures: int = 0
## md5 do save e das opções do jogador antes dos testes ("" = não existia).
var _real_files: Dictionary = {}


func _ready() -> void:
	_use_test_files()
	DeviceProfiles.check_scaler(self, _check)
	_test_data_integrity()
	_test_assets_exist()
	_test_i18n()
	_test_glyphs()
	_test_stat_block()
	_test_descriptions()
	_test_save_migration()
	AchievementRewardTests.new().run(_check)
	_test_sanctuary()
	_test_shop_clock()
	_test_shop_coin_items()
	_test_ads_rules()
	_test_unscathed_achievement()
	_test_frozen_tint()
	await _test_suspended_run()
	await _test_revive_by_ad()
	await DeathSequenceTests.new().run(self, _check)
	await AdsOffTests.new().run(self, _check)
	await _test_thunder_weapons()
	await _test_raijin_bolts()
	await OnikiriTests.new().run(self, _check)
	await _test_hero_hand()
	await WeaponAudioTests.new().run(self, _check)
	await WeaponFxTests.new().run(self, _check)
	await _test_sound_options()
	await HudLayoutTests.new().run(self, _check)
	await ChestBurstTests.new().run(self, _check)
	await LevelChestTests.new().run(self, _check)
	await MenusLayoutTests.new().run(self, _check)
	await SanctuaryLayoutTests.new().run(self, _check)
	await ResultsLayoutTests.new().run(self, _check)
	await TitleLayoutTests.new().run(self, _check)
	await StageMapLayoutTests.new().run(self, _check)
	await MenuBackdropTests.new().run(self, _check)
	await PauseMenuTests.new().run(self, _check)
	await GfxQualityTests.new().run(self, _check)
	await (load("res://tests/terrain_tests.gd") as GDScript).new().run(self, _check)
	await (load("res://tests/pickup_spawn_tests.gd") as GDScript).new().run(self, _check)
	await EnemyFxTests.new().run(self, _check)
	await WeatherTests.new().run(self, _check)
	await SurfaceTests.new().run(self, _check)
	await SkillIconTests.new().run(self, _check)
	await CreditsScreenTests.new().run(self, _check)
	await InsetFlipTests.new().run(self, _check)
	await _test_shop_layout()
	await _test_shop_scroll()
	_remove_test_files()
	print("%d verificações, %d falhas" % [_count, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	_count += 1
	if not condition:
		_failures += 1
		printerr("FALHOU: " + label)
	elif "--verbose" in OS.get_cmdline_user_args():
		print("ok: " + label)


func _use_test_files() -> void:
	for path: String in [SaveManager.PATH, SaveManager.BACKUP_PATH, Settings.PATH]:
		_real_files[path] = FileAccess.get_md5(path) if FileAccess.file_exists(path) else ""
	SaveManager.use_test_files()
	Settings.use_test_file()
	_check(SaveManager.path not in _real_files and Settings.path not in _real_files,
			"testes usam arquivos próprios de save e opções")
	for key: String in ["damage_numbers", "damage_sounds", "hurt_sounds"]:
		_check(Settings.get_value(key) == true, "arquivo de opções dos testes começa com %s ligado" % key)


## Apaga os arquivos dos testes e volta aos do jogador (lidos de novo, sem gravar).
func _remove_test_files() -> void:
	for path: String in SaveManager.TEST_PATHS + [Settings.TEST_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	for path: String in _real_files:
		var now := FileAccess.get_md5(path) if FileAccess.file_exists(path) else ""
		_check(now == _real_files[path], "testes não mexeram em %s do jogador" % path)
	SaveManager.path = SaveManager.PATH
	SaveManager.backup_path = SaveManager.BACKUP_PATH
	SaveManager.temp_path = SaveManager.TEMP_PATH
	SaveManager.load_profile()
	Settings.path = Settings.PATH
	Settings.load_settings()


# --- Guardiões, Opções e Diário: tests/menus_layout_tests.gd ------------------------

# --- Loja -------------------------------------------------------------------------

## Loja em cada idioma (layout, cartões, ícones, hover e aviso): tests/shop_layout_tests.gd.
func _test_shop_layout() -> void:
	await ShopLayoutTests.new().run_layout(self, _check)


## Reforços comprados com ryō na Loja: preço, fila da próxima partida (1 de cada), falta de
## ryō, consumo por take_next_run_bonuses e save antigo migrado.
func _test_shop_coin_items() -> void:
	SaveManager.data = SaveManager.default_profile()
	_check(ShopManager.coin_items().size() == 6, "Loja: 6 reforços por ryō")
	_check(ShopManager.ad_slots().size() == 6, "Loja: as 6 vagas por anúncio continuam")
	for id: StringName in ShopManager.coin_items():
		_check(ShopManager.coin_price(id) > 0, "reforço %s tem preço" % id)
		var effect := ShopManager.coin_effect(id)
		_check(effect != "" and not effect.contains("%s"), "reforço %s descreve o efeito: %s" % [id, effect])
		_check(not DB.powerups.has(id), "reforço %s não é power-up do Santuário" % id)
	SaveManager.data["ryo"] = 1000
	var price := ShopManager.coin_price(&"coin_scroll")
	_check(ShopManager.buy_coin(&"coin_scroll"), "compra reforço com ryō suficiente")
	_check(SaveManager.ryo() == 1000 - price, "a compra desconta o preço (%d)" % price)
	_check(ShopManager.is_queued(&"coin_scroll") and ShopManager.pending_next_run().has("coin_scroll"),
			"o reforço fica guardado para a próxima partida")
	_check(not ShopManager.buy_coin(&"coin_scroll") and SaveManager.ryo() == 1000 - price,
			"no máximo 1 de cada reforço por partida")
	_check(int(SaveManager.data["spent"]) == 0, "reforço não entra no reembolso do Santuário")
	var chest_price := ShopManager.coin_price(&"coin_chest")
	SaveManager.data["ryo"] = chest_price - 1
	_check(not ShopManager.can_buy_coin(&"coin_chest") and not ShopManager.buy_coin(&"coin_chest"),
			"sem ryō suficiente a compra falha")
	_check(SaveManager.ryo() == chest_price - 1 and not ShopManager.is_queued(&"coin_chest"),
			"compra que falhou não desconta nem guarda")
	SaveManager.data["ryo"] = 1000
	_check(ShopManager.buy_coin(&"coin_chest"), "compra o Baú do Mercador")
	SaveManager.data["shop"]["next_run"]["slot_chest"] = true
	var bonus := ShopManager.take_next_run_bonuses()
	_check(is_equal_approx(float(bonus["modifiers"].get("growth", 0.0)), 0.15), "o pergaminho dá +15% de crescimento")
	_check(int(bonus["start_chest"]) == 2, "baú comprado soma com o baú da vaga")
	_check(ShopManager.pending_next_run().is_empty() and not ShopManager.is_queued(&"coin_scroll"),
			"take_next_run_bonuses consome os reforços")
	_check(ShopManager.can_buy_coin(&"coin_scroll"), "depois da partida o reforço pode ser comprado de novo")
	# Save antigo sem a fila next_run: a migração completa e a compra funciona.
	SaveManager.data = SaveManager.migrate({"version": 0, "ryo": 500, "shop": {"slots": {}}})
	_check(ShopManager.buy_coin(&"coin_bag") and SaveManager.ryo() == 500 - ShopManager.coin_price(&"coin_bag"),
			"save migrado compra reforço")
	SaveManager.data = SaveManager.default_profile()


## Loja rolável (compra e restauração no fim da rolagem): tests/shop_layout_tests.gd.
func _test_shop_scroll() -> void:
	await ShopLayoutTests.new().run_scroll(self, _check)


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
	_test_sfx_variants_exist()


## Todo arquivo de todo grupo de AudioManager.VARIANTS existe em assets/audio/sfx/.
func _test_sfx_variants_exist() -> void:
	var missing: Array[String] = []
	var total := 0
	for group: String in AudioManager.VARIANTS:
		var files: Array = AudioManager.VARIANTS[group]
		_check(not files.is_empty(), "grupo de som %s tem arquivos" % group)
		for file: String in files:
			total += 1
			var base := AudioManager.SFX_DIR + file
			if not (ResourceLoader.exists(base + ".wav") or ResourceLoader.exists(base + ".ogg")
					or ResourceLoader.exists(base + ".mp3")):
				missing.append("%s/%s" % [group, file])
	_check(missing.is_empty(), "todos os sons dos grupos existem (%d): faltam %s" % [total, missing])
	for group: String in ["thunder", "zap", "chain_zap", "hit_blade", "hit_projectile", "hit_fire",
			"hit_thunder", "hit_wind", "hit_area", "hit_orbit", "hit_poison", "ofuda_cast", "incense_pulse", "chest_open"]:
		_check(AudioManager.VARIANTS.has(group), "grupo de som %s registrado" % group)


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
	var original_data := SaveManager.data
	SaveManager.data = SaveManager.default_profile()
	SaveManager.data["unlocked"]["heroes"] = ["aki"]
	_check(SaveManager.unlock_all_heroes(), "libera guardiões que faltam no perfil de desenvolvimento")
	for id: StringName in DB.ids("heroes"):
		_check(SaveManager.is_unlocked("heroes", id), "guardião %s fica liberado" % id)
	_check(not SaveManager.unlock_all_heroes(), "não altera perfil que já tem todos os guardiões")
	SaveManager.data = original_data


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


## Opções de som e de números de dano: padrão ligado, um CheckButton para cada uma na tela
## de Opções (alcançável pela rolagem em cada tela de tests/device_profiles.gd) e cada uma respeitada no jogo. As
## opções vão para o arquivo dos testes (Settings.use_test_file), nunca o do jogador.
func _test_sound_options() -> void:
	_check(Settings.path == Settings.TEST_PATH, "Opções: os testes gravam em %s" % Settings.TEST_PATH)
	var keys := ["damage_numbers", "damage_sounds", "hurt_sounds"]
	for key: String in keys:
		_check(Settings.DEFAULTS.get(key) == true, "opção %s existe e vem ligada" % key)
		Settings.set_value(key, true)

	# Tela de Opções: CheckButton "opt_<chave>" com o rótulo, visível depois de rolar até ele,
	# em cada tela de tests/device_profiles.gd.
	Locale.set_language("pt_BR", false)
	for c: Dictionary in DeviceProfiles.layout_cases():
		DeviceProfiles.simulate_insets(c["insets"])
		var safe := DeviceProfiles.safe_rect(c["view"], c["insets"])
		await _sound_options_screen(c["view"], safe, String(c["label"]), keys)
	DeviceProfiles.clear_insets()

	# No jogo: som do golpe por arma, som de dano no herói e números de dano.
	var scene := load(GAME_SCENE) as PackedScene
	var game := scene.instantiate() as HyakkiGame
	game.config = {"hero": "goro", "stage": "bamboo", "moon": 1, "mode": "normal", "seed": 5, "speed": 1}
	add_child(game)
	await get_tree().process_frame
	var enemy := game.enemies.spawn(&"slime_rice", game.player.sim_pos + Vector2(60, 0), 1000.0, 1.0)
	_check(enemy >= 0, "inimigo de teste nasceu")
	if enemy >= 0:
		game.deal_damage(&"katana", enemy, 0.1, Vector2.RIGHT, 0.0)
		_check(game.last_hit_sound == "hit_blade", "golpe da katana toca hit_blade")
		game.deal_damage(&"raijin", enemy, 0.1, Vector2.RIGHT, 0.0)
		_check(game.last_hit_sound == "hit_thunder", "golpe do raijin toca hit_thunder")
		game.deal_damage(&"kami_test", enemy, 0.1, Vector2.RIGHT, 0.0)
		_check(game.last_hit_sound == "hit", "golpe sem arma toca hit")
		Settings.set_value("damage_sounds", false)
		game.deal_damage(&"katana", enemy, 0.1, Vector2.RIGHT, 0.0)
		_check(game.last_hit_sound == "", "damage_sounds desligado silencia o golpe")
		var n_before := int(game.fx.get("_n_next"))
		game.deal_damage(&"katana", enemy, 0.1, Vector2.RIGHT, 0.0)
		_check(int(game.fx.get("_n_next")) != n_before, "número de dano aparece com a opção ligada")
		Settings.set_value("damage_numbers", false)
		n_before = int(game.fx.get("_n_next"))
		game.deal_damage(&"katana", enemy, 0.1, Vector2.RIGHT, 0.0)
		game.player.invuln = 0.0
		game.player.take_damage(1.0)
		_check(int(game.fx.get("_n_next")) == n_before, "damage_numbers desligado esconde inimigo e herói")
	_check(game.player.play_hurt_sound(), "hurt_sounds ligado toca o som do herói")
	Settings.set_value("hurt_sounds", false)
	_check(not game.player.play_hurt_sound(), "hurt_sounds desligado silencia o herói")
	game.queue_free()
	GameClock.paused = false
	await get_tree().process_frame

	for key: String in keys:
		Settings.set_value(key, true)


func _wait_until(condition: Callable, timeout: float) -> void:
	var waited := 0.0
	while not bool(condition.call()) and waited < timeout:
		await get_tree().create_timer(0.05).timeout
		waited += 0.05


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
		_check(GameClock.paused, "%s: a morte pausa o tempo" % label)
		_check(not game.hud.revive_open() and game.death.is_active(),
				"%s: a oferta espera o corpo cair (sequência de morte)" % label)
		var time_at_death := GameClock.game_time
		var snap := game.snapshot()
		await _wait_until(func() -> bool: return game.hud.revive_open(), 3.0)
		_check(game.hud.revive_open(), "%s: morrer abre a oferta de reviver" % label)
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
		await _wait_until(func() -> bool: return game.death.can_skip(), 4.0)
		_check(not game.hud.revive_open() and game.death.notice_open(),
				"%s: só um reviver por partida (direto ao aviso da morte)" % label)
		game.death.skip()
		_check(not game.running, "%s: tocar no aviso encerra a partida" % label)

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


## Opções de som na tela de Opções numa tela `size`; `view` é a área segura (fora do furo).
func _sound_options_screen(size: Vector2, view: Rect2, label: String, keys: Array) -> void:
	# Host com o tamanho do viewport do jogo, como na Loja.
	var host := Control.new()
	host.size = size
	add_child(host)
	var screen := (load(OPTIONS_SCREEN) as GDScript).new() as Control
	host.add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	var scroll := screen.get("_scroll") as ScrollContainer
	for key: String in keys:
		var found := screen.find_child("opt_%s" % key, true, false) as CheckButton
		_check(found != null, "Opções: CheckButton de %s" % key)
		if found == null:
			continue
		var cell_label := found.get_parent().get_child(0) as Label
		_check(cell_label != null and cell_label.text == tr("options.%s" % key),
				"Opções: %s tem o rótulo na mesma célula" % key)
		_check(found.button_pressed, "Opções: %s aparece ligado" % key)
		_check(scroll != null and scroll.is_ancestor_of(found), "Opções: %s fica dentro da rolagem" % key)
		if scroll != null:
			scroll.ensure_control_visible(found)
			await get_tree().process_frame
			await get_tree().process_frame
			_check(found.is_visible_in_tree() and view.encloses(found.get_global_rect())
					and scroll.get_global_rect().encloses(found.get_global_rect()),
					"Opções: %s alcançável na tela de celular [%s]" % [key, label])
		found.button_pressed = false
		_check(Settings.get_value(key) == false, "Opções: desligar %s grava a opção" % key)
		found.button_pressed = true
	host.queue_free()
	await get_tree().process_frame


## Intocável (ach_unscathed, 300 s sem dano): vale numa partida sem reviver por anúncio
## e não vale quando a partida teve reviver (plano 17.6). Usa o perfil dos testes.
func _test_unscathed_achievement() -> void:
	var result := {"victory": false, "time": 400.0, "hero": "goro", "stage": "bamboo",
			"mode": "normal", "moon": 0, "level": 1, "daily": false}
	var done: Dictionary = SaveManager.data["achievements"]
	# Sem reviver: 300 s sem dano dão a conquista.
	done.erase("ach_unscathed")
	var tracker := RunTracker.new()
	tracker.max_no_damage = 300.0
	tracker.revived_by_ad = false
	var unlocked := MetaProgress.check_achievements(result, tracker)
	_check(unlocked.has(&"ach_unscathed") and done.has("ach_unscathed"),
			"Intocável é dada com 300 s sem dano e sem reviver")
	# Com reviver: a mesma marca não dá a conquista.
	done.erase("ach_unscathed")
	tracker = RunTracker.new()
	tracker.max_no_damage = 300.0
	tracker.revived_by_ad = true
	unlocked = MetaProgress.check_achievements(result, tracker)
	_check(not unlocked.has(&"ach_unscathed") and not done.has("ach_unscathed"),
			"Intocável não é dada quando a partida teve reviver por anúncio")
	# Abaixo de 300 s não basta.
	tracker = RunTracker.new()
	tracker.max_no_damage = 299.0
	tracker.revived_by_ad = false
	unlocked = MetaProgress.check_achievements(result, tracker)
	_check(not unlocked.has(&"ach_unscathed"), "Intocável exige 300 s sem dano")


# --- Armas de trovão --------------------------------------------------------------

## Kaminari e Inazuma (e as evoluções Takemikazuchi e Raikiri): carregam do DB com a tag
## "thunder", nascem em _make_weapon com o comportamento certo, sobem até o nível máximo e,
## disparadas numa partida, ferem inimigos. O Kaminari avisa no chão antes de cair; o
## Inazuma salta de inimigo em inimigo. O Kami Raijin soma raios nas duas.
func _test_thunder_weapons() -> void:
	var expected := {&"kaminari": "Kaminari", &"inazuma": "Inazuma",
			&"takemikazuchi": "Kaminari", &"raikiri": "Inazuma"}
	for id: StringName in expected:
		var data := DB.weapon(id)
		_check(not data.is_empty(), "%s existe no DB" % id)
		_check((data.get("tags", []) as Array).has("thunder"), "%s tem a tag thunder" % id)
		_check(tr("weapon.%s.name" % id) != "weapon.%s.name" % id, "%s tem nome traduzido" % id)
	for id: StringName in [&"kaminari", &"inazuma"]:
		var data := DB.weapon(id)
		_check((data["levels"] as Array).size() == 8, "%s tem 8 níveis" % id)
		_check(String(data.get("unlock", "x")) == "", "%s vem liberada" % id)
		_check(DB.weapon(StringName(data["evolution"])).get("from", "") == String(id),
				"%s evolui para uma arma que aponta de volta" % id)

	var scene := load(GAME_SCENE) as PackedScene
	var game := scene.instantiate() as HyakkiGame
	game.config = {"hero": "goro", "stage": "bamboo", "moon": 0, "mode": "normal", "seed": 13, "speed": 1}
	add_child(game)
	await get_tree().process_frame
	game.player.god_mode = true
	var origin := game.player.sim_pos
	# Campo limpo: só os inimigos de teste contam para mira e grupo.
	for i: int in range(EnemyManager.CAPACITY):
		if game.enemies.alive[i] == 1:
			game.enemies.despawn(i)
	for id: StringName in expected:
		var weapon := game._make_weapon(id)
		_check(weapon != null and weapon.get_script().get_global_name() == StringName(expected[id]),
				"%s nasce com o comportamento %s" % [id, expected[id]])
		if weapon == null:
			continue
		if not weapon.is_evolved():
			var first_damage := weapon.damage()
			while weapon.level < weapon.max_level:
				weapon.level_up()
			_check(weapon.level == 8 and weapon.damage() > first_damage, "%s sobe até o nível 8 e ganha dano" % id)
		# Inimigos em fila, longe dos outros: alvo, e dois para o raio saltar.
		var targets: Array[int] = []
		for k: int in range(3):
			targets.append(game.enemies.spawn(&"slime_rice", origin + Vector2(50 + 35 * k, 0), 1000.0, 1.0))
		_check(not targets.has(-1), "%s: inimigos de teste nasceram" % id)
		if targets.has(-1):
			continue
		# O hash espacial só é refeito no passo dos inimigos; sem passo, a área (query_circle)
		# veria índices antigos. Refaz como o passo faz, para o teste não depender da ordem.
		game.enemies.spatial.clear()
		for i: int in range(EnemyManager.CAPACITY):
			if game.enemies.alive[i] == 1:
				game.enemies.spatial.insert(i, game.enemies.pos[i])
		var hp_before := game.enemies.hp[targets[0]]
		var dealt_before := float(game.tracker.damage_by_weapon.get(id, 0.0))
		weapon.fire(origin)
		if weapon is Kaminari:
			var kaminari := weapon as Kaminari
			_check(not kaminari.strikes.is_empty(), "%s marca o chão antes de cair" % id)
			_check(game.enemies.hp[targets[0]] == hp_before, "%s não fere durante o aviso" % id)
			for _t: int in range(10):
				kaminari.step(0.1)
			_check(not kaminari.bolts.is_empty() or kaminari.strikes.is_empty(), "%s desenha o raio do céu" % id)
			var hits := 0
			for j: int in targets:
				if game.enemies.hp[j] < game.enemies.max_hp[j]:
					hits += 1
			_check(hits >= 2, "%s fere em área (%d de 3 inimigos)" % [id, hits])
		else:
			var inazuma := weapon as Inazuma
			_check(not inazuma.bolts.is_empty(), "%s desenha o raio a partir do herói" % id)
			var chained := true
			for j: int in targets:
				chained = chained and game.enemies.hp[j] < game.enemies.max_hp[j]
			_check(chained, "%s salta para os 3 inimigos em fila" % id)
		_check(game.enemies.hp[targets[0]] < hp_before, "%s fere o inimigo" % id)
		_check(float(game.tracker.damage_by_weapon.get(id, 0.0)) > dealt_before, "%s conta o dano da arma" % id)
		for j: int in targets:
			game.enemies.despawn(j)
	# Kami Raijin: +2 raios em armas de trovão, nas duas novas.
	var plain := game._make_weapon(&"inazuma")
	var before := plain.amount()
	game.kami.accept(&"raijin", true)
	_check(game._make_weapon(&"inazuma").amount() == before + 2, "Kami Raijin soma 2 raios no Inazuma")
	game.add_weapon(&"kaminari")
	_check(game.has_weapon(&"kaminari"), "Kaminari entra na partida pelo add_weapon")
	game.queue_free()
	GameClock.paused = false
	await get_tree().process_frame


## Tambor de Raijin e Fúria de Raijin: cada elo do raio desenha um raio caindo do céu
## sobre o alvo (variante 0..7 do lightning.png); a corrente estica o raio entre os alvos.
## Os raios são só desenho: expiram em ~0,2 s, têm teto e somem no reset().
func _test_raijin_bolts() -> void:
	await RaijinBoltTests.new().run(self, _check)


## Yuki menor, com a mão de onde saem os poderes e a pose de ataque (tests/hero_hand_tests.gd).
func _test_hero_hand() -> void:
	await HeroHandTests.new().run(self, _check)
