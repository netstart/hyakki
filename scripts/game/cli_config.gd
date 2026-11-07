class_name CliConfig
extends RefCounted
## Configuração da partida pela linha de comando (depois de `--`), para o bot e os testes:
## --hero=ID, --stage=ID, --moon=0..5, --mode=normal|brisa, --speed=1|2|3, --endless e
## --arsenal=id1,id2 (armas extras no nível máximo desde o começo, ElementSystem.add_arsenal).


## Config de HyakkiGame.start_run lida dos argumentos, com a semente `run_seed`.
static func run_config(run_seed: int) -> Dictionary:
	var cfg := {"hero": "aki", "stage": "village", "moon": 0, "mode": "normal", "endless": false,
			"speed": 1, "seed": run_seed}
	for arg: String in OS.get_cmdline_user_args():
		var value := arg.get_slice("=", 1)
		if arg.begins_with("--hero="):
			cfg["hero"] = value
		elif arg.begins_with("--stage="):
			cfg["stage"] = value
		elif arg.begins_with("--moon="):
			cfg["moon"] = clampi(value.to_int(), 0, HyakkiGame.MAX_MOON)
		elif arg.begins_with("--mode="):
			cfg["mode"] = value
		elif arg.begins_with("--speed="):
			cfg["speed"] = clampi(value.to_int(), 1, 3)
		elif arg == "--endless":
			cfg["endless"] = true
		elif arg.begins_with("--arsenal="):
			cfg["arsenal"] = Array(value.split(",", false))
	return cfg
