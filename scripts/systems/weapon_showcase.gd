class_name WeaponShowcase
extends RefCounted
## Vitrine de armas para capturas e testes manuais (depois de "--"):
##   --weapons=katana,ofuda,raijin_fury   arsenal extra no começo da partida (ids de weapons.json)
##   --weapon-level=N                     sobe todas as armas até o nível N (1..8)
##   --ult-at=S                           enche e solta o golpe da lanterna aos S s de jogo
## Só existe com o argumento: sem ele, nada muda (a partida normal e o determinismo do bot
## ficam intactos). Chamado pela camada de efeitos a cada passo (FxLayer.step).

var _weapons: PackedStringArray = []
var _level: int = 1
var _ult_at: float = -1.0
var _applied: bool = false


func _init() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var value := arg.get_slice("=", 1)
		if arg.begins_with("--weapons="):
			_weapons = value.split(",", false)
		elif arg.begins_with("--weapon-level="):
			_level = clampi(value.to_int(), 1, 8)
		elif arg.begins_with("--ult-at="):
			_ult_at = value.to_float()


## Algum argumento da vitrine foi passado?
func active() -> bool:
	return not _weapons.is_empty() or _level > 1 or _ult_at >= 0.0


func step(game: HyakkiGame) -> void:
	if game == null or not game.running:
		return
	if not _applied:
		_applied = true
		for id: String in _weapons:
			var key := StringName(id.strip_edges())
			if not DB.weapon(key).is_empty() and not game.has_weapon(key):
				game.add_weapon(key)
		for weapon: Weapon in game.weapons:
			while weapon.level < mini(_level, weapon.max_level):
				weapon.level_up()
	if _ult_at >= 0.0 and GameClock.game_time >= _ult_at:
		_ult_at = -1.0
		game.ultimate.fill()
		game.ultimate.activate()
