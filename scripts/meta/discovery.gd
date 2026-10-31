class_name Discovery
extends RefCounted
## O que o jogador já conhece (regras do Diário do Guardião), num lugar só: o Diário e o Guia
## (GuideBook) escondem o que ainda não foi visto com exatamente as mesmas regras.
## - armas: as base sempre; evoluções e uniões depois de descobertas (stats "evolved"/"unions");
## - relíquias: liberadas (as sem condição desde o início);
## - chefes: depois de vencidos (stats "bosses_defeated");
## - guardiãs e fases: liberadas no save;
## - Kami: sempre (o Diário mostra todos).
## Item desconhecido aparece como "???" (nome) e chip em silhueta com "?".

const UNKNOWN := "???"


## Arma conhecida: base sempre; evolução e união depois de descobertas.
static func weapon_known(w: StringName) -> bool:
	var stats: Dictionary = SaveManager.data["stats"]
	return String(DB.weapon(w).get("kind", "base")) == "base" or (stats["evolved"] as Array).has(String(w)) \
			or (stats.get("unions", []) as Array).has(String(w))


## Relíquia conhecida: liberada (as sem condição desde o início).
static func passive_known(p: StringName) -> bool:
	return MetaProgress.is_content_available("passives", p, DB.passives.get(p, {}) as Dictionary)


## Chefe conhecido: já vencido alguma vez.
static func boss_known(b: StringName) -> bool:
	return (SaveManager.data["stats"]["bosses_defeated"] as Dictionary).has(String(b))


static func hero_known(h: StringName) -> bool:
	return MetaProgress.is_hero_unlocked(h)


static func stage_known(s: StringName) -> bool:
	return MetaProgress.is_stage_unlocked(s)


## Kami: o Diário mostra todos desde o início.
static func kami_known(_k: StringName) -> bool:
	return true


## Item citado numa receita: {category, id, known, icon, name}; desconhecido sai como "???".
## `cat` é &"weapons" ou &"relics" (categorias do Diário).
static func recipe_ref(cat: StringName, id: String) -> Dictionary:
	var weapon := cat == &"weapons"
	var known := weapon_known(StringName(id)) if weapon else passive_known(StringName(id))
	var name_key := ("weapon.%s.name" if weapon else "passive.%s.name") % id
	return {"category": cat, "id": id, "known": known,
			"icon": UiIcons.skill_path("weapons" if weapon else "passives", id),
			"name": TranslationServer.translate(name_key) if known else UNKNOWN}


## Referência "weapon:id" / "passive:id" (formato das dicas) ainda desconhecida pelo Diário.
static func ref_hidden(kind: String, id: String) -> bool:
	match kind:
		"weapon":
			return DB.weapons.has(StringName(id)) and not weapon_known(StringName(id))
		"passive":
			return DB.passives.has(StringName(id)) and not passive_known(StringName(id))
	return false
