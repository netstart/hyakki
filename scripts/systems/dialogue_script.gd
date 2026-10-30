class_name DialogueScript
extends RefCounted
## Roteiro do diálogo antes de um chefe (data/dialogues.json, lido pelo DB em DB.dialogues):
## abertura do chefe, resposta do herói da partida, um aparte opcional de Tora, Hana ou Rin e o
## fecho do chefe. Regras puras e estáticas (testes unitários); quem mostra é o DialoguePanel
## da HUD e quem abre é HyakkiGame.open_dialogue.
##
## Cada fala do arquivo: {"who": "boss" | "hero" | "tora" | "hana" | "rin", "key": "dialog...",
## "skip": ["tora"]}. Para "hero" a chave traduzida é key + "." + id do herói. A fala é pulada
## quando o herói da partida está em "skip" (Tora não faz aparte para si mesmo).
## Aparece só no 1º encontro com cada chefe (SaveManager.data["dialogue_seen"]), ou sempre com a
## opção "Mostrar diálogos sempre" (Settings "dialogues_always"). O Shinigami nunca fala.

const SHINIGAMI := &"shinigami"


## Falas de `boss_id` para o herói `hero_id`, já filtradas: {"who", "speaker_id", "text_key",
## "side"} com side "left" (herói e companheiros) ou "right" (chefe). Vazio sem roteiro.
static func build(boss_id: StringName, hero_id: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var entry: Variant = DB.dialogues.get(String(boss_id), {})
	if typeof(entry) != TYPE_DICTIONARY:
		return out
	for raw: Variant in (entry as Dictionary).get("lines", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var line: Dictionary = raw
		var skip: Array = line.get("skip", [])
		if skip.has(String(hero_id)):
			continue
		var who := String(line.get("who", ""))
		var key := String(line.get("key", ""))
		if who.is_empty() or key.is_empty():
			continue
		var speaker := StringName(who)
		if who == "boss":
			speaker = boss_id
		elif who == "hero":
			speaker = hero_id
			key += "." + String(hero_id)
		out.append({"who": who, "speaker_id": speaker, "text_key": key,
				"side": "right" if who == "boss" else "left"})
	return out


## O chefe tem roteiro no arquivo.
static func has_dialogue(boss_id: StringName) -> bool:
	if boss_id == SHINIGAMI:
		return false
	var entry: Variant = DB.dialogues.get(String(boss_id), {})
	return typeof(entry) == TYPE_DICTIONARY and not ((entry as Dictionary).get("lines", []) as Array).is_empty()


## Mostra o diálogo deste chefe agora: tem roteiro e é o 1º encontro (ou a opção pede sempre).
static func should_show(boss_id: StringName) -> bool:
	if not has_dialogue(boss_id):
		return false
	if bool(Settings.get_value("dialogues_always")):
		return true
	return not seen(boss_id)


static func seen(boss_id: StringName) -> bool:
	var seen_map: Variant = SaveManager.data.get("dialogue_seen", {})
	return typeof(seen_map) == TYPE_DICTIONARY and (seen_map as Dictionary).has(String(boss_id))


## Marca como visto ao abrir: um Guardião chamado de novo ao retomar a partida não repete.
static func mark_seen(boss_id: StringName) -> void:
	if typeof(SaveManager.data.get("dialogue_seen")) != TYPE_DICTIONARY:
		SaveManager.data["dialogue_seen"] = {}
	(SaveManager.data["dialogue_seen"] as Dictionary)[String(boss_id)] = true


## Chave do nome de quem fala (o nome do chefe ou do herói, já traduzidos no jogo).
static func name_key(line: Dictionary) -> String:
	if String(line.get("who", "")) == "boss":
		return "boss.%s.name" % line["speaker_id"]
	return "hero.%s.name" % line["speaker_id"]


## Retrato de quem fala: o Faceset do herói (DB.heroes "face") ou do chefe ("faceset" em
## data/bosses.json, senão o Faceset.png ao lado da folha do chefe, como no Diário).
static func face_path(line: Dictionary) -> String:
	var id := StringName(line.get("speaker_id", &""))
	if String(line.get("who", "")) == "boss":
		var data: Dictionary = DB.bosses.get(id, {})
		if data.is_empty():
			return ""
		var sprite: Dictionary = data.get("sprite", {})
		return String(data.get("faceset", String(sprite.get("path", "")).get_base_dir().path_join("Faceset.png")))
	return String((DB.heroes.get(id, {}) as Dictionary).get("face", ""))
