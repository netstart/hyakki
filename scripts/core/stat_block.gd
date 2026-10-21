class_name StatBlock
extends RefCounted
## Atributos da guardiã (plano 4.2 e 10.5). Cada fonte (herói, passivo, power-up,
## Kami, bênção temporária) registra seus modificadores; o valor final é recalculado
## quando algo muda. Atributos percentuais somam frações (+0,10 = +10%), como no VS.

signal changed

## Valor base e como os modificadores se aplicam: "pct" multiplica a base por (1 + soma);
## "flat" soma direto.
const DEFS := {
	"max_hp": [100.0, "pct"],
	"regen": [0.0, "flat"],
	"armor": [0.0, "flat"],
	"speed": [60.0, "pct"],
	"might": [1.0, "pct"],
	"area": [1.0, "pct"],
	"proj_speed": [1.0, "pct"],
	"duration": [1.0, "pct"],
	"amount": [0.0, "flat"],
	"cooldown": [1.0, "pct"],
	"luck": [1.0, "pct"],
	"growth": [1.0, "pct"],
	"greed": [1.0, "pct"],
	"magnet": [40.0, "pct"],
	"curse": [1.0, "pct"],
	"revive": [0.0, "flat"],
	"light": [120.0, "pct"],
	"crit": [0.0, "flat"],
	"ult_charge": [1.0, "pct"],
	"reroll": [0.0, "flat"],
	"skip": [0.0, "flat"],
	"banish": [0.0, "flat"],
}
const MIN_COOLDOWN := 0.1

var _sources: Dictionary = {}
var _values: Dictionary = {}


func _init() -> void:
	recalculate()


func set_source(source: String, modifiers: Dictionary) -> void:
	if modifiers.is_empty():
		_sources.erase(source)
	else:
		_sources[source] = modifiers.duplicate()
	recalculate()


func remove_source(source: String) -> void:
	if _sources.has(source):
		_sources.erase(source)
		recalculate()


func has_source(source: String) -> bool:
	return _sources.has(source)


func clear() -> void:
	_sources.clear()
	recalculate()


func get_stat(stat: String) -> float:
	return float(_values.get(stat, 0.0))


func recalculate() -> void:
	var sums: Dictionary = {}
	for modifiers: Dictionary in _sources.values():
		for stat: String in modifiers:
			sums[stat] = float(sums.get(stat, 0.0)) + float(modifiers[stat])
	for stat: String in DEFS:
		var base: float = DEFS[stat][0]
		var mode: String = DEFS[stat][1]
		var sum: float = sums.get(stat, 0.0)
		var value := base * (1.0 + sum) if mode == "pct" else base + sum
		_values[stat] = value
	_values["cooldown"] = maxf(MIN_COOLDOWN, float(_values["cooldown"]))
	_values["max_hp"] = maxf(1.0, float(_values["max_hp"]))
	_values["speed"] = maxf(10.0, float(_values["speed"]))
	_values["magnet"] = maxf(8.0, float(_values["magnet"]))
	_values["light"] = maxf(40.0, float(_values["light"]))
	changed.emit()


func snapshot() -> Dictionary:
	return _values.duplicate()
