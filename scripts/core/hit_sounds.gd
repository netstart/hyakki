class_name HitSounds
extends RefCounted
## Som do golpe no inimigo conforme o tipo de ataque. Função pura, com testes.
## O comportamento da arma decide primeiro; sem ele, as tags; sem nada, o "hit" genérico.

const DEFAULT := "hit"
const BY_BEHAVIOR := {
	"katana": "hit_blade",
	"blade_cyclone": "hit_blade",
	"shuriken": "hit_projectile",
	"kunai": "hit_projectile",
	"yumi": "hit_projectile",
	"kusarigama": "hit_projectile",
	"hitodama": "hit_fire",
	"raijin": "hit_thunder",
	"typhoon": "hit_thunder",
	"fujin_fan": "hit_wind",
	"hurricane": "hit_wind",
	"taiko": "hit_area",
	"incense": "hit_area",
	"ofuda": "hit_orbit",
	"smoke_bomb": "hit_poison",
}
## Ordem de prioridade das tags quando o comportamento não é conhecido.
const BY_TAG := [
	["thunder", "hit_thunder"],
	["fire", "hit_fire"],
	["poison", "hit_poison"],
	["wind", "hit_wind"],
	["blade", "hit_blade"],
	["orbit", "hit_orbit"],
	["projectile", "hit_projectile"],
	["area", "hit_area"],
	["aura", "hit_area"],
]


## `weapon` é a linha da arma em data/weapons.json (vazia para Kami, especial etc.).
static func for_weapon(weapon: Dictionary) -> String:
	if weapon.is_empty():
		return DEFAULT
	var behavior := String(weapon.get("behavior", ""))
	if BY_BEHAVIOR.has(behavior):
		return BY_BEHAVIOR[behavior]
	var tags: Array = weapon.get("tags", [])
	for entry: Array in BY_TAG:
		if tags.has(entry[0]):
			return entry[1]
	return DEFAULT
