extends RefCounted
## Dublê do AbilitySystem para os testes da UI (tests/ability_hud_tests.gd): a mesma leitura que
## a HUD usa (AbilityPad.source), com os dados reais de data/abilities.json do herói e o estado
## escolhido pelo teste (nível, recargas, energia, pagamento com vida). activate registra o toque e
## emite Events.ability_failed / ability_used como o sistema de verdade.

var hero: StringName
var rows: Array[Dictionary] = []
var energy_rules: Dictionary = {}
var level := 10
var left := PackedFloat32Array([0.0, 0.0, 0.0])
var value := 100.0
## Vida que a Yuki pagaria (0 = energia basta; INF = não pode pagar).
var blood := 0.0
var activated: Array[int] = []


func _init(p_hero: StringName = &"aki") -> void:
	setup(p_hero)


func setup(p_hero: StringName) -> void:
	hero = p_hero
	var data := DB.hero_abilities(hero)
	energy_rules = data.get("energy", {})
	rows.clear()
	for row: Variant in data.get("abilities", []):
		rows.append(row)
	value = float(energy_rules.get("max", 100.0))
	blood = 0.0


func slot_count() -> int:
	return rows.size()


func ability(slot: int) -> Dictionary:
	return rows[slot] if slot >= 0 and slot < rows.size() else {}


func ability_id(slot: int) -> StringName:
	return StringName(String(ability(slot).get("id", "")))


func required_level(slot: int) -> int:
	return int(ability(slot).get("level", 1))


func is_unlocked(slot: int) -> bool:
	return slot >= 0 and slot < rows.size() and level >= required_level(slot)


func cost(slot: int) -> float:
	return float(ability(slot).get("cost", 0.0))


func cooldown_total(slot: int) -> float:
	return float(ability(slot).get("cooldown", 1.0))


func cooldown_left(slot: int) -> float:
	return left[slot] if slot >= 0 and slot < 3 else 0.0


func cooldown_fraction(slot: int) -> float:
	return clampf(cooldown_left(slot) / maxf(cooldown_total(slot), 0.001), 0.0, 1.0)


func is_ready(slot: int) -> bool:
	return is_unlocked(slot) and cooldown_left(slot) <= 0.0


func hp_price(slot: int) -> float:
	return 0.0 if value >= cost(slot) else blood


func can_pay(slot: int) -> bool:
	return hp_price(slot) < INF


func energy_id() -> StringName:
	return StringName(String(energy_rules.get("id", "")))


func energy_value() -> float:
	return value


func energy_max() -> float:
	return float(energy_rules.get("max", 100.0))


func energy_fraction() -> float:
	return value / energy_max()


func energy_color() -> Color:
	return Color(String(energy_rules.get("color", "ffffff")))


func energy_icon() -> String:
	return String(energy_rules.get("icon", ""))


func activate(slot: int) -> bool:
	activated.append(slot)
	var reason := AbilitySystem.Fail.NONE
	if not is_unlocked(slot):
		reason = AbilitySystem.Fail.LOCKED
	elif cooldown_left(slot) > 0.0:
		reason = AbilitySystem.Fail.COOLDOWN
	elif not can_pay(slot):
		reason = AbilitySystem.Fail.NO_ENERGY
	if reason != AbilitySystem.Fail.NONE:
		Events.ability_failed.emit(slot, reason)
		return false
	value = maxf(0.0, value - cost(slot))
	left[slot] = cooldown_total(slot)
	Events.ability_used.emit(hero, slot, ability_id(slot), String(ability(slot).get("kanji", "")))
	return true
