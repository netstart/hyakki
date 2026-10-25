class_name WeaponStyle
extends RefCounted
## Identidade visual de uma arma (campo "fx" de data/weapons.json): a cor do poder ("color"),
## a cor quente do núcleo/faíscas ("hot") e o tipo de impacto (o mesmo do som, HitSounds).
## Sem "fx", cada tipo de impacto tem cores próprias. Função pura, com testes.

const DEFAULTS := {
	"hit_blade": ["#cfe8ff", "#ffffff"],
	"hit_projectile": ["#d8dde6", "#fff3c4"],
	"hit_fire": ["#7fc8ff", "#e6f6ff"],
	"hit_thunder": ["#8fd0ff", "#f2fbff"],
	"hit_wind": ["#b8f0d8", "#f4fff8"],
	"hit_area": ["#e8c890", "#fff1d0"],
	"hit_orbit": ["#ffd98a", "#fffbe8"],
	"hit_poison": ["#9be070", "#e6ffd0"],
	"hit": ["#ffffff", "#ffffff"],
}


## {"color": Color, "hot": Color, "impact": String} da linha da arma (vazia → genérico).
static func of(weapon: Dictionary) -> Dictionary:
	var impact := HitSounds.for_weapon(weapon)
	var fallback: Array = DEFAULTS.get(impact, DEFAULTS["hit"])
	var fx: Dictionary = weapon.get("fx", {})
	return {
		"color": Color(String(fx.get("color", fallback[0]))),
		"hot": Color(String(fx.get("hot", fallback[1]))),
		"impact": impact,
	}
