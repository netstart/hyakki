class_name HitSounds
extends RefCounted
## Som do golpe no inimigo conforme o tipo de ataque. Função pura, com testes.
## Ordem: o campo "sfx.impact" da arma em data/weapons.json; senão o comportamento; senão as
## tags; sem nada, o "hit" genérico. play() toca com o volume e a variação de tom do tipo
## (mixagem: acertos ficam abaixo do lançamento das armas e da música).

const DEFAULT := "hit"
const BY_BEHAVIOR := {
	"katana": "hit_blade",
	"blade_cyclone": "hit_blade",
	"onikiri": "hit_blade",
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
## Mixagem por tipo: [volume dB, tom, variação de tom]. Golpes pesados um pouco mais altos e
## graves; os que chegam em rajada (projéteis, raios, veneno) mais baixos.
const MIX := {
	"hit": [-14.0, 1.0, 0.08],
	"hit_blade": [-13.0, 1.0, 0.1],
	"hit_projectile": [-15.0, 1.0, 0.1],
	"hit_fire": [-14.0, 1.0, 0.1],
	"hit_thunder": [-15.0, 1.0, 0.12],
	"hit_wind": [-15.0, 1.0, 0.1],
	"hit_area": [-13.0, 0.95, 0.08],
	"hit_orbit": [-15.0, 1.0, 0.1],
	"hit_poison": [-16.0, 1.0, 0.12],
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
	var sfx: Dictionary = weapon.get("sfx", {})
	if MIX.has(String(sfx.get("impact", ""))):
		return String(sfx["impact"])
	var behavior := String(weapon.get("behavior", ""))
	if BY_BEHAVIOR.has(behavior):
		return BY_BEHAVIOR[behavior]
	var tags: Array = weapon.get("tags", [])
	for entry: Array in BY_TAG:
		if tags.has(entry[0]):
			return entry[1]
	return DEFAULT


## Toca o acerto `id` com a mixagem do tipo (AudioManager limita vozes e prioridade).
static func play(id: String) -> void:
	var mix: Array = MIX.get(id, MIX[DEFAULT])
	var audio := _audio()
	if audio:
		audio.call("play", id, float(mix[1]), float(mix[2]), float(mix[0]))


## AudioManager pela árvore (este script também carrega nos testes sem autoloads).
static func _audio() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null(^"AudioManager") if tree and tree.root else null
