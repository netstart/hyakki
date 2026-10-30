class_name TipDeck
extends RefCounted
## Liga o TipBook (regras puras) ao jogo: lê data/tips.json e os dados do DB, monta o contexto do
## save (partidas, vitórias, evoluções, ryō para o Santuário, guardiã escolhida, o que já está
## liberado), guarda o histórico em SaveManager.data["tips"] e traduz o texto.
## Quem usa: o balão do título (TipBalloon) e o cartão 心得 dos Resultados. Com a opção "Dicas"
## desligada (Settings "tips"), nada aparece.
## Plataforma: "android" no aparelho (OS.has_feature), "desktop" no PC; os testes trocam por
## platform_override.

const PATH := "res://data/tips.json"
## Selo das dicas (Kokoroe, "o que se aprendeu"), escrito com a fonte japonesa em todo idioma.
const KANJI := "心得"

## Testes: "android" ou "desktop" no lugar da plataforma real ("" = a real).
static var platform_override := ""
static var _raw: Dictionary = {}
static var _catalog: Array[Dictionary] = []


## Conteúdo de data/tips.json ({"categories", "tips"}).
static func raw() -> Dictionary:
	if _raw.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_raw = parsed if typeof(parsed) == TYPE_DICTIONARY else {"categories": [], "tips": []}
	return _raw


## Catálogo inteiro (escritas + geradas dos dados do DB), montado uma vez.
static func catalog() -> Array[Dictionary]:
	if _catalog.is_empty():
		_catalog = TipBook.build_catalog(raw(), _rows("weapons"), _rows("passives"), _rows("achievements"))
	return _catalog


static func _rows(table: String) -> Array:
	var table_data: Dictionary = DB.get(table)
	var out: Array = []
	for id: StringName in DB.ids(table):
		out.append(table_data[id])
	return out


static func enabled() -> bool:
	return bool(Settings.get_value("tips"))


static func platform() -> String:
	if not platform_override.is_empty():
		return platform_override
	return "android" if OS.has_feature("android") else "desktop"


## Contexto do save atual para TipBook.eligible / pick.
static func context() -> Dictionary:
	var ctx := TipBook.default_context()
	var stats: Dictionary = SaveManager.data.get("stats", {})
	ctx["enabled"] = enabled()
	ctx["platform"] = platform()
	ctx["runs"] = int(stats.get("runs", 0))
	ctx["wins"] = int(stats.get("wins", 0))
	ctx["deaths"] = int(stats.get("deaths", 0))
	ctx["evolved"] = (stats.get("evolved", []) as Array).size()
	var hero := String((SaveManager.data.get("selected", {}) as Dictionary).get("hero", "aki"))
	if not DB.heroes.has(StringName(hero)):
		hero = "aki"
	ctx["hero"] = hero
	ctx["hero_weapon"] = String((DB.heroes[StringName(hero)] as Dictionary).get("weapon", ""))
	var can_buy := false
	for id: StringName in DB.ids("powerups"):
		if MetaProgress.can_buy(id):
			can_buy = true
			break
	ctx["can_buy"] = can_buy
	var available := {"weapons": [], "passives": []}
	for id: StringName in DB.ids("weapons"):
		var data := DB.weapon(id)
		if String(data.get("kind", "")) == "base" and MetaProgress.is_content_available("weapons", id, data):
			(available["weapons"] as Array).append(String(id))
	for id: StringName in DB.ids("passives"):
		if MetaProgress.is_content_available("passives", id, DB.passives[id]):
			(available["passives"] as Array).append(String(id))
	ctx["available"] = available
	return ctx


## Histórico das dicas no save (cria ou completa o de saves antigos).
static func state() -> Dictionary:
	var current: Variant = SaveManager.data.get("tips")
	var fixed := TipBook.migrate_state(current)
	if typeof(current) != TYPE_DICTIONARY or fixed != current:
		SaveManager.data["tips"] = fixed
	return SaveManager.data["tips"]


## Próxima dica do título, já registrada como vista ({} com as dicas desligadas). Não grava o
## save (quem mostra grava ao sair). `seed` 0 = sorteio novo.
static func next_tip(seed: int = 0) -> Dictionary:
	var ctx := context()
	if not bool(ctx["enabled"]):
		return {}
	var tip := TipBook.pick(catalog(), ctx, state(), _rng(seed))
	TipBook.mark_shown(state(), tip)
	return tip


## Dica do resultado de uma derrota ({} na vitória ou com as dicas desligadas). A mesma para o
## mesmo resultado: a semente sai dos números da partida.
static func result_tip(result: Dictionary) -> Dictionary:
	if bool(result.get("victory", false)):
		return {}
	var ctx := context()
	if not bool(ctx["enabled"]):
		return {}
	var tags := TipBook.result_tags(result, DB.bosses, DB.enemies, DB.weapons)
	var missed := TipBook.missed_tip(result.get("weapons", []), _rows("weapons"))
	if not missed.is_empty() and not TipBook.eligible({"when": {"unlocked": ["passives:" + _passive_of(missed)]}}, ctx):
		missed = {}
	var seed := int(float(result.get("time", 0.0)) * 10.0) + int(result.get("kills", 0)) * 7 + int(result.get("level", 0))
	var tip := TipBook.pick_for_result(catalog(), ctx, state(), _rng(maxi(seed, 1)), tags, missed)
	TipBook.mark_shown(state(), tip)
	return tip


static func _passive_of(tip: Dictionary) -> String:
	var icons: Array = tip.get("icons", [])
	return String(icons[1]).trim_prefix("passive:") if icons.size() > 1 else ""


static func _rng(seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	if seed != 0:
		rng.seed = seed
	else:
		rng.randomize()
	return rng


## Texto da dica no idioma atual.
static func text(tip: Dictionary) -> String:
	return TipBook.text(tip, func(key: String) -> String: return TranslationServer.translate(key))


## Rótulo da categoria (Combo, Estratégia, Armas...).
static func category_text(tip: Dictionary) -> String:
	return TranslationServer.translate("tip.cat.%s" % String(tip.get("cat", "strategy")))


## Ícone de "weapon:id", "passive:id", "item:id" ou "kami:id" ("" se não houver).
static func icon_path(ref: String) -> String:
	var parts := ref.split(":")
	if parts.size() != 2:
		return ""
	var id := StringName(parts[1])
	var table: Dictionary = {}
	match parts[0]:
		"weapon":
			table = DB.weapons
		"passive":
			table = DB.passives
		"item":
			table = DB.items
		"kami":
			table = DB.kami
	return String((table.get(id, {}) as Dictionary).get("icon", ""))


## Texturas dos ícones da dica, na ordem (as que não existem ficam de fora).
static func icons(tip: Dictionary) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for ref: Variant in tip.get("icons", []):
		var path := icon_path(String(ref))
		if not path.is_empty() and ResourceLoader.exists(path):
			out.append(load(path) as Texture2D)
	return out


## Dica cujo texto fica mais largo no idioma atual (testes de layout): a mais exigente do
## catálogo inteiro (escritas e geradas, valendo ou não para o save) e das "faltou".
static func longest(font: Font, font_size: int = 12) -> Dictionary:
	var best: Dictionary = {}
	var best_w := -1.0
	var all: Array[Dictionary] = catalog().duplicate()
	for w: Dictionary in _rows("weapons"):
		if String(w.get("kind", "")) == "base" and not String(w.get("evolution", "")).is_empty():
			var missed := TipBook.missed_tip([{"id": String(w["id"]), "level": 99}], _rows("weapons"))
			if not missed.is_empty():
				all.append(missed)
	for tip: Dictionary in all:
		var width := font.get_string_size(text(tip), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if width > best_w:
			best_w = width
			best = tip
	return best
