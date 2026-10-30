class_name TipBook
extends RefCounted
## Dicas "心得" (Kokoroe): catálogo, condições e escolha. Regras puras e estáticas, sem autoloads
## (testes unitários em tests/run_tests.gd); quem junta o save, o DB e as opções é o TipDeck, e
## quem mostra é o balão da guardiã no título (TipBalloon) e o cartão dos Resultados.
##
## Catálogo = dicas escritas de data/tips.json + dicas geradas dos dados, que ficam sempre em
## sincronia com o jogo e já saem traduzidas pelos nomes de cada idioma:
## - evolução de cada arma base: "<arma> no nível máx. + <relíquia> = <evolução>" (a regra real do
##   LevelUpSystem.evolution_ready: arma no nível máximo + a relíquia em qualquer nível; o próximo
##   baú entrega, ChestSystem._next_reward);
## - união de cada arma "union": as duas evoluções de "requires" viram uma no próximo baú;
## - relíquia que evolui duas armas (Pergaminho Antigo, Magatama de Jade, Máscara Nō);
## - arma ou relíquia ainda bloqueada: a conquista que a libera (data/achievements.json "reward").
##
## Cada dica: {id, cat, tier, weight, key, args (chaves traduzidas que entram nos %s), icons
## ("weapon:id", "passive:id", "item:id", "kami:id"), recipe (ícones com + e =), when, after,
## priority, gap, base}. Condições ("when", todas precisam valer): platform, min_runs, max_runs,
## min_wins, max_wins, min_deaths, evolved, can_buy, hero, unlocked e locked ("weapons:id",
## "passives:id"). Uma chave desconhecida reprova a dica (erro de digitação não passa calado).
##
## Escolha (pick): só dicas que valem para o save (contexto do TipDeck), as de iniciante primeiro
## (tier 0, depois 1 a partir de TIER_RUNS[1] partidas e 2 a partir de TIER_RUNS[2]) e sem repetir
## até esgotar o ciclo ("seen"); a dica da arma da guardiã escolhida conta como de iniciante e pesa
## mais. "priority" passa na frente na primeira vez (backup no Android, assim que há progresso a
## perder); "gap" afasta dicas da mesma categoria (o backup volta de tempos em tempos, nunca em
## toda abertura). Com a mesma semente, a mesma escolha.
## Depois de uma derrota (pick_for_result), o motivo pesa: morte cedo, sem evolução, chefe,
## Guardião do Limiar, Shinigami ou Sombra no escuro (result_tags); uma arma que ficou no nível
## máximo sem a relíquia vira a dica "faltou" (missed_tip).

## Partidas para liberar cada nível de dica (iniciante, intermediária, avançada).
const TIER_RUNS: Array[int] = [0, 3, 10]
## Últimas dicas lembradas (para "gap" e para não repetir logo em seguida).
const RECENT_MAX := 24
## Peso extra das dicas que casam com o contexto (motivo da derrota) e da arma da guardiã.
const AFTER_WEIGHT := 4.0
const HERO_WEAPON_WEIGHT := 3.0
## Morte cedo (s) e a partir de quando "sem evolução" e "poucas armas" contam (s).
const EARLY_DEATH := 180.0
const MID_RUN := 240.0
const WHEN_KEYS: Array[String] = ["platform", "min_runs", "max_runs", "min_wins", "max_wins", "min_deaths",
		"evolved", "can_buy", "hero", "unlocked", "locked"]
const AFTER_TAGS: Array[String] = ["early", "no_evolution", "few_weapons", "boss", "midboss", "shinigami", "dark"]
const GEN_EVOLUTION := "tip.gen.evolution"
const GEN_UNION := "tip.gen.union"
const GEN_SHARED := "tip.gen.shared"
const GEN_UNLOCK_WEAPON := "tip.gen.unlock_weapon"
const GEN_UNLOCK_PASSIVE := "tip.gen.unlock_passive"
const GEN_MISSED := "tip.gen.missed"


# --- Catálogo ------------------------------------------------------------------------------

## Dicas escritas (`raw`, o conteúdo de data/tips.json) seguidas das geradas de `weapons`,
## `passives` e `achievements` (as listas de data/*.json, na ordem do arquivo).
static func build_catalog(raw: Dictionary, weapons: Array, passives: Array, achievements: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Variant in raw.get("tips", []):
		if typeof(entry) == TYPE_DICTIONARY:
			out.append(_normalize(entry, "tip.%s" % String((entry as Dictionary).get("id", ""))))
	out.append_array(generated(weapons, passives, achievements))
	return out


## Só as geradas dos dados (evoluções, uniões, relíquias que evoluem duas armas e desbloqueios).
static func generated(weapons: Array, passives: Array, achievements: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var by_id := _by_id(weapons)
	var users: Dictionary = {}
	for w: Dictionary in weapons:
		if String(w.get("kind", "")) != "base" or String(w.get("evolution", "")).is_empty():
			continue
		var base := String(w["id"])
		var passive := String(w.get("evolves_with", ""))
		var evo := String(w["evolution"])
		if not users.has(passive):
			users[passive] = []
		(users[passive] as Array).append(base)
		out.append(_normalize({"id": "evo.%s" % base, "cat": "combo", "tier": 1, "base": base, "recipe": true,
				"args": ["weapon.%s.name" % base, "passive.%s.name" % passive, "weapon.%s.name" % evo],
				"icons": ["weapon:" + base, "passive:" + passive, "weapon:" + evo],
				"when": {"unlocked": ["weapons:" + base, "passives:" + passive]}, "after": ["no_evolution"]},
				GEN_EVOLUTION))
	for w: Dictionary in weapons:
		if String(w.get("kind", "")) != "union":
			continue
		var needs: Array = w.get("requires", [])
		if needs.size() != 2:
			continue
		var unlocked: Array[String] = []
		for need: Variant in needs:
			var evo: Dictionary = by_id.get(String(need), {})
			var base: Dictionary = by_id.get(String(evo.get("from", "")), {})
			if base.is_empty():
				continue
			unlocked.append("weapons:" + String(base["id"]))
			unlocked.append("passives:" + String(base.get("evolves_with", "")))
		var uid := String(w["id"])
		out.append(_normalize({"id": "union.%s" % uid, "cat": "combo", "tier": 2, "recipe": true,
				"args": ["weapon.%s.name" % needs[0], "weapon.%s.name" % needs[1], "weapon.%s.name" % uid],
				"icons": ["weapon:%s" % needs[0], "weapon:%s" % needs[1], "weapon:" + uid],
				"when": {"evolved": true, "unlocked": unlocked}}, GEN_UNION))
	for p: Dictionary in passives:
		var pid := String(p["id"])
		var list: Array = users.get(pid, [])
		if list.size() < 2:
			continue
		out.append(_normalize({"id": "shared.%s" % pid, "cat": "combo", "tier": 1,
				"args": ["passive.%s.name" % pid, "weapon.%s.name" % list[0], "weapon.%s.name" % list[1]],
				"icons": ["passive:" + pid, "weapon:%s" % list[0], "weapon:%s" % list[1]],
				"when": {"unlocked": ["passives:" + pid, "weapons:%s" % list[0], "weapons:%s" % list[1]]}},
				GEN_SHARED))
	for pair: Array in [["weapon", "weapons", weapons, GEN_UNLOCK_WEAPON], ["passive", "passives", passives,
			GEN_UNLOCK_PASSIVE]]:
		for item: Dictionary in pair[2]:
			if String(item.get("unlock", "")).is_empty() or String(item.get("kind", "base")) != "base":
				continue
			var id := String(item["id"])
			var ach := _achievement_for(achievements, "%s:%s" % [pair[0], id])
			if ach.is_empty():
				continue
			out.append(_normalize({"id": "unlock.%s.%s" % [pair[0], id], "cat": "progress", "tier": 1,
					"args": ["%s.%s.name" % [pair[0], id], "achievement.%s.desc" % ach],
					"icons": ["%s:%s" % [pair[0], id]], "when": {"locked": ["%s:%s" % [pair[1], id]]}},
					String(pair[3])))
	return out


## Dica "faltou" dos Resultados: a primeira arma base no nível máximo (`max_level` por id) que
## não evoluiu. {} se nenhuma. `rows` são as armas do resultado ({id, level}).
static func missed_tip(rows: Array, weapons: Array) -> Dictionary:
	var by_id := _by_id(weapons)
	for row: Variant in rows:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var w: Dictionary = by_id.get(String((row as Dictionary).get("id", "")), {})
		if String(w.get("kind", "")) != "base" or String(w.get("evolution", "")).is_empty():
			continue
		if int((row as Dictionary).get("level", 0)) < (w.get("levels", [{}]) as Array).size():
			continue
		var base := String(w["id"])
		var passive := String(w.get("evolves_with", ""))
		var evo := String(w["evolution"])
		return _normalize({"id": "missed.%s" % base, "cat": "combo", "tier": 0, "recipe": true, "base": base,
				"args": ["weapon.%s.name" % base, "passive.%s.name" % passive, "weapon.%s.name" % evo],
				"icons": ["weapon:" + base, "passive:" + passive, "weapon:" + evo]}, GEN_MISSED)
	return {}


static func _normalize(entry: Dictionary, key: String) -> Dictionary:
	var args: Array[String] = []
	for a: Variant in entry.get("args", []):
		args.append(String(a))
	var icons: Array[String] = []
	for i: Variant in entry.get("icons", []):
		icons.append(String(i))
	var after: Array[String] = []
	for t: Variant in entry.get("after", []):
		after.append(String(t))
	return {"id": String(entry.get("id", "")), "cat": String(entry.get("cat", "strategy")),
			"tier": int(entry.get("tier", 0)), "weight": float(entry.get("weight", 1.0)), "key": key,
			"args": args, "icons": icons, "recipe": bool(entry.get("recipe", false)),
			"when": (entry.get("when", {}) as Dictionary).duplicate(true), "after": after,
			"priority": bool(entry.get("priority", false)), "gap": int(entry.get("gap", 0)),
			"base": String(entry.get("base", ""))}


static func _by_id(list: Array) -> Dictionary:
	var out: Dictionary = {}
	for e: Variant in list:
		if typeof(e) == TYPE_DICTIONARY:
			out[String((e as Dictionary).get("id", ""))] = e
	return out


static func _achievement_for(achievements: Array, reward: String) -> String:
	for a: Variant in achievements:
		if typeof(a) != TYPE_DICTIONARY:
			continue
		for part: String in String((a as Dictionary).get("reward", "")).split(",", false):
			if part.strip_edges() == reward:
				return String((a as Dictionary)["id"])
	return ""


# --- Condições -----------------------------------------------------------------------------

## Contexto vazio (padrões de um save novo, fora do Android). O TipDeck preenche do jogo.
static func default_context() -> Dictionary:
	return {"enabled": true, "platform": "desktop", "runs": 0, "wins": 0, "deaths": 0, "evolved": 0,
			"can_buy": false, "hero": "aki", "hero_weapon": "katana", "available": {"weapons": [], "passives": []}}


## A dica vale para este contexto (todas as condições de "when").
static func eligible(tip: Dictionary, ctx: Dictionary) -> bool:
	var when: Dictionary = tip.get("when", {})
	for key: String in when:
		var v: Variant = when[key]
		var ok := true
		match key:
			"platform":
				ok = String(ctx.get("platform", "")) == String(v)
			"min_runs":
				ok = int(ctx.get("runs", 0)) >= int(v)
			"max_runs":
				ok = int(ctx.get("runs", 0)) <= int(v)
			"min_wins":
				ok = int(ctx.get("wins", 0)) >= int(v)
			"max_wins":
				ok = int(ctx.get("wins", 0)) <= int(v)
			"min_deaths":
				ok = int(ctx.get("deaths", 0)) >= int(v)
			"evolved":
				ok = (int(ctx.get("evolved", 0)) > 0) == bool(v)
			"can_buy":
				ok = bool(ctx.get("can_buy", false)) == bool(v)
			"hero":
				ok = String(ctx.get("hero", "")) == String(v)
			"unlocked":
				ok = _all_available(v, ctx, true)
			"locked":
				ok = _all_available(v, ctx, false)
			_:
				ok = false
		if not ok:
			return false
	return true


static func _all_available(refs: Variant, ctx: Dictionary, wanted: bool) -> bool:
	var available: Dictionary = ctx.get("available", {})
	for ref: Variant in (refs as Array if refs is Array else [refs]):
		var parts := String(ref).split(":")
		if parts.size() != 2:
			return false
		var has := (available.get(parts[0], []) as Array).has(parts[1])
		if has != wanted:
			return false
	return true


## Nível de experiência do save: 0 (iniciante), 1 ou 2 pelas partidas jogadas (TIER_RUNS).
static func experience(ctx: Dictionary) -> int:
	var runs := int(ctx.get("runs", 0))
	var level := 0
	for i: int in TIER_RUNS.size():
		if runs >= TIER_RUNS[i]:
			level = i
	return level


## Nível da dica neste contexto: a da arma da guardiã escolhida conta como de iniciante.
static func tier_of(tip: Dictionary, ctx: Dictionary) -> int:
	var base := String(tip.get("base", ""))
	if not base.is_empty() and base == String(ctx.get("hero_weapon", "")):
		return 0
	return int(tip.get("tier", 0))


static func weight_of(tip: Dictionary, ctx: Dictionary, tags: Array = []) -> float:
	var w := maxf(float(tip.get("weight", 1.0)), 0.01)
	var base := String(tip.get("base", ""))
	if not base.is_empty() and base == String(ctx.get("hero_weapon", "")):
		w *= HERO_WEAPON_WEIGHT
	for tag: Variant in tags:
		if (tip.get("after", []) as Array).has(String(tag)):
			w *= AFTER_WEIGHT
			break
	return w


# --- Escolha -------------------------------------------------------------------------------

## Estado novo do histórico (SaveManager.data["tips"]): ciclo atual, já vistas, recentes, total.
static func default_state() -> Dictionary:
	return {"seen": [], "ever": [], "recent": [], "count": 0}


## Completa um estado antigo ou estragado sem perder o que já foi visto.
static func migrate_state(value: Variant) -> Dictionary:
	var out := default_state()
	if typeof(value) != TYPE_DICTIONARY:
		return out
	var old: Dictionary = value
	for key: String in ["seen", "ever", "recent"]:
		if old.get(key) is Array:
			for id: Variant in old[key]:
				(out[key] as Array).append(String(id))
	out["count"] = maxi(0, int(old.get("count", 0)))
	return out


## Próxima dica para o título (ou {} se as dicas estão desligadas ou nada vale). Pode começar um
## ciclo novo em `state` ("seen" zerado) quando todas as que valem já apareceram; quem mostra
## chama mark_shown depois.
static func pick(catalog: Array[Dictionary], ctx: Dictionary, state: Dictionary,
		rng: RandomNumberGenerator, tags: Array = []) -> Dictionary:
	if not bool(ctx.get("enabled", true)):
		return {}
	var pool: Array[Dictionary] = []
	for tip: Dictionary in catalog:
		if eligible(tip, ctx):
			pool.append(tip)
	if pool.is_empty():
		return {}
	var ever: Array = state.get("ever", [])
	for tip: Dictionary in pool:
		if bool(tip["priority"]) and not ever.has(tip["id"]):
			return tip
	var level := experience(ctx)
	var seen: Array = state.get("seen", [])
	var recent: Array = state.get("recent", [])
	var cats := _cats(catalog)
	var ready: Array[Dictionary] = []
	var waiting := false
	for tip: Dictionary in pool:
		if tier_of(tip, ctx) > level:
			continue
		if _gap_blocked(tip, recent, cats):
			waiting = waiting or not seen.has(tip["id"])
			continue
		ready.append(tip)
	if ready.is_empty():
		return {}
	if not tags.is_empty():
		var tagged := _with_tags(ready, tags)
		var fresh_tagged := _unseen(tagged, seen)
		if not fresh_tagged.is_empty():
			return _weighted(fresh_tagged, ctx, rng, tags)
		if not tagged.is_empty():
			return _weighted(_not_last(tagged, recent), ctx, rng, tags)
	var fresh := _unseen(ready, seen)
	if fresh.is_empty():
		if waiting:
			# Só faltam dicas afastadas pelo "gap": repete uma das prontas até elas voltarem.
			return _weighted(_not_last(ready, recent, 8), ctx, rng)
		seen.clear()
		state["seen"] = seen
		fresh = _not_last(ready, recent)
	# Iniciante primeiro: o menor nível que ainda tem dica nova.
	var lowest := 99
	for tip: Dictionary in fresh:
		lowest = mini(lowest, tier_of(tip, ctx))
	var first: Array[Dictionary] = []
	for tip: Dictionary in fresh:
		if tier_of(tip, ctx) == lowest:
			first.append(tip)
	return _weighted(first, ctx, rng)


## Dica dos Resultados: a "faltou" (`missed`), senão a que mais casa com o motivo da derrota.
static func pick_for_result(catalog: Array[Dictionary], ctx: Dictionary, state: Dictionary,
		rng: RandomNumberGenerator, tags: Array, missed: Dictionary = {}) -> Dictionary:
	if not bool(ctx.get("enabled", true)):
		return {}
	if not missed.is_empty():
		return missed
	return pick(catalog, ctx, state, rng, tags)


## Registra a dica mostrada: entra no ciclo atual, nas já vistas e nas recentes.
static func mark_shown(state: Dictionary, tip: Dictionary) -> void:
	if tip.is_empty():
		return
	var id := String(tip["id"])
	for key: String in ["seen", "ever", "recent"]:
		if not (state.get(key) is Array):
			state[key] = []
	if not (state["seen"] as Array).has(id):
		(state["seen"] as Array).append(id)
	if not (state["ever"] as Array).has(id):
		(state["ever"] as Array).append(id)
	var recent: Array = state["recent"]
	recent.append(id)
	while recent.size() > RECENT_MAX:
		recent.remove_at(0)
	state["count"] = int(state.get("count", 0)) + 1


## Motivos da derrota que pesam na dica dos Resultados (ver AFTER_TAGS). `bosses` é {id: dados}
## (com "midboss"), `enemies` {id: dados} (com "archetype") e `weapons` {id: dados} (com "kind").
static func result_tags(result: Dictionary, bosses: Dictionary, enemies: Dictionary,
		weapons: Dictionary) -> Array[String]:
	var tags: Array[String] = []
	if bool(result.get("victory", false)):
		return tags
	var time := float(result.get("time", 0.0))
	if time < EARLY_DEATH:
		tags.append("early")
	var cause := String((result.get("damage_taken", {}) as Dictionary).get("cause", ""))
	var boss: Variant = bosses.get(StringName(cause), bosses.get(cause, null))
	if boss is Dictionary:
		if cause == "shinigami":
			tags.append("shinigami")
		elif bool((boss as Dictionary).get("midboss", false)):
			tags.append("midboss")
		else:
			tags.append("boss")
	var foe: Variant = enemies.get(StringName(cause), enemies.get(cause, null))
	if foe is Dictionary and String((foe as Dictionary).get("archetype", "")) == "shade":
		tags.append("dark")
	var rows: Array = result.get("weapons", [])
	if time >= MID_RUN:
		var evolved := false
		for row: Variant in rows:
			var id := String((row as Dictionary).get("id", "")) if row is Dictionary else ""
			var data: Variant = weapons.get(StringName(id), weapons.get(id, null))
			if data is Dictionary and String((data as Dictionary).get("kind", "base")) != "base":
				evolved = true
		if not evolved:
			tags.append("no_evolution")
		if rows.size() <= 2:
			tags.append("few_weapons")
	return tags


## Texto da dica no idioma atual: `translate` traduz a chave e cada argumento.
static func text(tip: Dictionary, translate: Callable) -> String:
	var base := String(translate.call(String(tip.get("key", ""))))
	var args: Array = tip.get("args", [])
	if args.is_empty():
		return base
	var values: Array = []
	for a: Variant in args:
		values.append(String(translate.call(String(a))))
	return base % values


static func _cats(catalog: Array[Dictionary]) -> Dictionary:
	var out: Dictionary = {}
	for tip: Dictionary in catalog:
		out[tip["id"]] = tip["cat"]
	return out


## Outra dica da mesma categoria apareceu nas últimas `gap` (dica com "gap").
static func _gap_blocked(tip: Dictionary, recent: Array, cats: Dictionary) -> bool:
	var gap := int(tip.get("gap", 0))
	if gap <= 0:
		return false
	var from := maxi(0, recent.size() - gap)
	for i: int in range(from, recent.size()):
		if String(cats.get(String(recent[i]), "")) == String(tip["cat"]):
			return true
	return false


static func _with_tags(list: Array[Dictionary], tags: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for tip: Dictionary in list:
		for tag: Variant in tags:
			if (tip["after"] as Array).has(String(tag)):
				out.append(tip)
				break
	return out


static func _unseen(list: Array[Dictionary], seen: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for tip: Dictionary in list:
		if not seen.has(tip["id"]):
			out.append(tip)
	return out


## Tira as últimas `count` dicas mostradas (se sobrar alguma).
static func _not_last(list: Array[Dictionary], recent: Array, count: int = 1) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var tail := recent.slice(maxi(0, recent.size() - count))
	for tip: Dictionary in list:
		if not tail.has(tip["id"]):
			out.append(tip)
	return out if not out.is_empty() else list


static func _weighted(list: Array[Dictionary], ctx: Dictionary, rng: RandomNumberGenerator,
		tags: Array = []) -> Dictionary:
	if list.is_empty():
		return {}
	var total := 0.0
	var weights: Array[float] = []
	for tip: Dictionary in list:
		var w := weight_of(tip, ctx, tags)
		weights.append(w)
		total += w
	var roll := rng.randf() * total
	for i: int in list.size():
		roll -= weights[i]
		if roll <= 0.0:
			return list[i]
	return list[list.size() - 1]
