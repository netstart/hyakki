extends RefCounted
## Recompensas de conquista reaplicadas na carga do perfil: um save antigo com
## ach_boss_red_oni (que hoje também libera a Onikiri) ganha a arma ao carregar, sem ryō
## de novo, sem itens repetidos, ignorando conquistas que não existem mais.
## Chamado por tests/integration_tests.gd (já nos arquivos de teste do SaveManager).


func run(check: Callable) -> void:
	var original := SaveManager.data
	check.call(String(DB.achievements[&"ach_boss_red_oni"]["reward"]).contains("weapon:onikiri"),
			"ach_boss_red_oni libera a Onikiri")

	_load_old_profile({"ach_boss_red_oni": 1000, "ach_que_nao_existe": 1000})
	var weapons: Array = SaveManager.data["unlocked"]["weapons"]
	check.call(weapons.has("onikiri"), "save antigo com ach_boss_red_oni ganha a Onikiri ao carregar")
	check.call(SaveManager.ryo() == 250 and int(SaveManager.data["ryo_total"]) == 900,
			"reaplicar conquistas não devolve ryō")
	check.call(weapons.count("onikiri") == 1 and _heroes().count("yuki") == 1,
			"Onikiri e Yuki aparecem uma vez só")
	check.call(not weapons.has("ach_que_nao_existe") and SaveManager.data["achievements"].has("ach_que_nao_existe"),
			"conquista que não existe mais é ignorada (e mantida no save)")

	check.call(not MetaProgress.reapply_achievement_unlocks(), "segunda aplicação não libera nada")
	SaveManager.load_profile()
	check.call((SaveManager.data["unlocked"]["weapons"] as Array).count("onikiri") == 1,
			"carregar de novo não repete a Onikiri")
	check.call(SaveManager.ryo() == 250, "carregar de novo mantém o ryō")

	_load_old_profile({"ach_boss_kuroe": 1000})
	check.call(not (SaveManager.data["unlocked"]["weapons"] as Array).has("onikiri"),
			"perfil sem ach_boss_red_oni não ganha a Onikiri")
	check.call(SaveManager.ryo() == 250, "conquista só de ryō (ach_boss_kuroe) não paga de novo")

	SaveManager.data = original
	SaveManager.save_profile()


## Grava um save da versão antiga (Yuki liberada, Onikiri não) e carrega pelo fluxo normal.
func _load_old_profile(achievements: Dictionary) -> void:
	var old := {"version": 0, "ryo": 250, "ryo_total": 900, "achievements": achievements,
			"unlocked": {"heroes": ["aki", "yuki"], "weapons": [], "passives": [],
			"stages": ["village"], "cosmetics": [], "kami": []}}
	var file := FileAccess.open(SaveManager.path, FileAccess.WRITE)
	file.store_string(JSON.stringify(old))
	file.close()
	SaveManager.load_profile()


func _heroes() -> Array:
	return SaveManager.data["unlocked"]["heroes"]
