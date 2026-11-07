class_name Discovery
extends RefCounted
## O que o jogador já conhece (regras do Diário do Guardião), num lugar só: o Diário e o Guia
## (GuideBook) escondem o que ainda não foi visto com exatamente as mesmas regras.
## - armas: as base sempre; evoluções e uniões depois de descobertas (stats "evolved"/"unions");
## - relíquias: liberadas (as sem condição desde o início);
## - exclusivas de uma guardiã ("hero", as da Kuon): só depois de liberar a dona;
## - chefes: depois de vencidos (stats "bosses_defeated");
## - guardiãs e fases: liberadas no save;
## - Kami: sempre (o Diário mostra todos).
## - Kakuriyo de uma fase: depois de vencer o Guardião do Limiar dela; Tokoyo de uma fase: depois de
##   chegar lá (recorde "stage_tokoyo" das Missões, gravado no fim da partida);
## - afixos dos Elites dos altares: depois de ver um Elite com ele (stats "affixes_seen");
## - Shinigami da Noite Sem Fim (fora do Diário): depois de chegar à hora dele (Spawner.SHINIGAMI_TIME).
## Item desconhecido aparece como "???" (nome) e chip em silhueta com "?".
## A ordem dos chefes no Diário (boss_order) também mora aqui: cada Sombra ao lado do seu Guardião.

const UNKNOWN := "???"


## Arma conhecida: base sempre; evolução e união depois de descobertas. As exclusivas de uma guardiã
## (as da Kuon) ficam escondidas enquanto ela estiver bloqueada.
static func weapon_known(w: StringName) -> bool:
	var stats: Dictionary = SaveManager.data["stats"]
	var data := DB.weapon(w)
	if MetaProgress.exclusive_locked(data):
		return false
	return String(data.get("kind", "base")) == "base" or (stats["evolved"] as Array).has(String(w)) \
			or (stats.get("unions", []) as Array).has(String(w))


## Relíquia conhecida: liberada (as sem condição desde o início); a exclusiva, com a dona liberada.
static func passive_known(p: StringName) -> bool:
	var data: Dictionary = DB.passives.get(p, {})
	return MetaProgress.is_content_available("passives", p, data) and not MetaProgress.exclusive_locked(data)


## Chefe conhecido: já vencido alguma vez.
static func boss_known(b: StringName) -> bool:
	return (SaveManager.data["stats"]["bosses_defeated"] as Dictionary).has(String(b))


static func hero_known(h: StringName) -> bool:
	return MetaProgress.is_hero_unlocked(h)


static func stage_known(s: StringName) -> bool:
	return MetaProgress.is_stage_unlocked(s)


## Chefes na ordem do Diário (data/bosses.json), com cada Sombra do Guardião ("midboss2" de uma
## fase) logo depois do Guardião do Limiar dela ("midboss" da mesma fase).
static func boss_order() -> Array[StringName]:
	var shadow_of := {}
	var shadows := {}
	for s: StringName in DB.ids("stages"):
		var row: Dictionary = DB.stages[s]
		var mid := StringName(String(RiftPortal.midboss_of(row).get("id", "")))
		var mid2 := StringName(String(RiftPortal.midboss2_of(row).get("id", "")))
		if mid != &"" and mid2 != &"" and DB.bosses.has(mid2):
			shadow_of[mid] = mid2
			shadows[mid2] = true
	var out: Array[StringName] = []
	for b: StringName in DB.ids("bosses"):
		if shadows.has(b):
			continue
		out.append(b)
		if shadow_of.has(b):
			out.append(shadow_of[b])
	# Sombra sem Guardião conhecido (dados incompletos) entra no fim, sem sumir do Diário.
	for b: StringName in DB.ids("bosses"):
		if not out.has(b):
			out.append(b)
	return out


## Kakuriyo da fase conhecido: o Guardião do Limiar dela (que abre o portal) já foi vencido.
static func realm_known(s: StringName) -> bool:
	return boss_known(StringName(String(RiftPortal.midboss_of(DB.stage(s)).get("id", ""))))


## Tokoyo da fase conhecido: alguma partida chegou lá (MissionBook.record_run grava a fase em
## records["stage_tokoyo"]; o resultado leva "tokoyo" e o RunTracker, tokoyo_reached).
static func tokoyo_known(s: StringName) -> bool:
	var rec: Dictionary = SaveManager.data.get("records", {})
	return (rec.get("stage_tokoyo", {}) as Dictionary).has(String(s))


## Kami: o Diário mostra todos desde o início.
static func kami_known(_k: StringName) -> bool:
	return true


## Afixo de Elite conhecido: um Elite com ele já surgiu num altar (registrado no fim da partida).
static func affix_known(id: StringName) -> bool:
	return ((SaveManager.data["stats"] as Dictionary).get("affixes_seen", []) as Array).has(String(id))


## Shinigami conhecido: alguma Noite Sem Fim chegou à hora em que ele aparece.
static func reaper_known() -> bool:
	for s: Variant in (SaveManager.data.get("stage_best", {}) as Dictionary):
		if float((SaveManager.data["stage_best"][s] as Dictionary).get("endless_best", 0.0)) >= Spawner.SHINIGAMI_TIME:
			return true
	return false


## Marca "Exclusiva de <guardiã>" de uma arma ou relíquia exclusiva (data "hero"), já traduzida; "" nas
## das outras e enquanto a dona estiver bloqueada (aí o item nem aparece).
static func exclusive_note(data: Dictionary) -> String:
	var owner := MetaProgress.exclusive_hero(data)
	if owner == &"" or MetaProgress.exclusive_locked(data):
		return ""
	var template := TranslationServer.translate("exclusive.hero")
	var name := TranslationServer.translate("hero.%s.name" % owner)
	return template % name if template.contains("%s") else "%s · %s" % [template, name]


## Como liberar uma arma ou relíquia ainda escondida: a conquista dela, ou a da dona, se for exclusiva.
static func unlock_achievement(data: Dictionary) -> String:
	var owner := MetaProgress.exclusive_hero(data)
	if owner != &"" and MetaProgress.exclusive_locked(data):
		return String((DB.heroes.get(owner, {}) as Dictionary).get("unlock", ""))
	return String(data.get("unlock", ""))


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
