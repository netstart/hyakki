class_name CodexMissions
extends RefCounted
## Página "Missões" do Diário (MissionBook): entradas agrupadas por categoria, na ordem das
## categorias (cada entrada leva "section"), com a fração do progresso para a barrinha do cartão,
## o texto "312 / 500" e as recompensas (ícone + nome) para a página da direita. Os chips das
## recompensas são montados com as operações nativas de Image (sem laço por pixel) e ficam em cache.

## Lado do chip da recompensa (mesma altura dos chips das receitas).
const CHIP := 18

static var _chips: Dictionary = {}


## Entradas da página: {id, title, known, icon, face, show_locked, kind, text, section, progress,
## progress_text, rewards}.
static func entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for cat: StringName in MissionBook.CATEGORIES:
		for id: StringName in MissionBook.in_category(cat):
			var done := MissionBook.is_done(id)
			out.append({"id": String(id), "title": MissionBook.title(id), "known": done,
					"icon": MissionBook.icon(id), "face": MissionBook.icon_is_face(id), "show_locked": true,
					"kind": "%s · %s" % [MissionBook.category_name(cat), TranslationServer.translate("codex.done")] if done
							else MissionBook.category_name(cat),
					"text": MissionBook.description(id), "section": String(cat), "progress": MissionBook.ratio(id),
					"progress_text": MissionBook.progress_text(id), "rewards": MissionBook.reward_parts(id)})
	return out


## Seções na ordem: [{id, title, icon, done, total, from, to}] (índices das entradas [from, to)).
static func sections(list: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in list.size():
		var cat := String(list[i].get("section", ""))
		if out.is_empty() or String(out.back()["id"]) != cat:
			out.append({"id": cat, "title": MissionBook.category_name(StringName(cat)),
					"icon": String(MissionBook.CATEGORY_ICONS.get(StringName(cat), "")), "done": 0, "total": 0,
					"from": i, "to": i})
		var s: Dictionary = out.back()
		s["total"] = int(s["total"]) + 1
		s["done"] = int(s["done"]) + int(bool(list[i]["known"]))
		s["to"] = i + 1
	return out


## Escreve as recompensas em `rich`: "Recompensa:" e, para cada parte, o chip e o nome.
static func fill_rewards(rich: RichTextLabel, rewards: Array) -> void:
	rich.clear()
	rich.visible = not rewards.is_empty()
	if rewards.is_empty():
		return
	rich.push_color(ThemeFactory.RED_INK)
	rich.add_text(TranslationServer.translate("mission.reward") + ": ")
	rich.pop()
	for i: int in rewards.size():
		var part: Dictionary = rewards[i]
		if i > 0:
			rich.add_text("  ")
		var label := String(part["text"])
		rich.add_image(reward_chip(String(part["icon"]), bool(part.get("face", false))), CHIP, CHIP, Color.WHITE,
				INLINE_ALIGNMENT_CENTER, Rect2(), null, false, label)
		# Espaço fino inquebrável: o nome não se separa do ícone na quebra de linha.
		rich.add_text(" " + label)


## Chip 18x18 de um ícone (em cache): até 18 px fica no centro em escala 1; maior, recorta o meio
## (retratos: os 2/3 centrais, reduzidos para 16). Sem ícone: chip vazio.
static func reward_chip(path: String, face: bool) -> Texture2D:
	var key := "%s|%s" % [path, face]
	if _chips.has(key):
		return _chips[key]
	var img := Image.create_empty(CHIP, CHIP, false, Image.FORMAT_RGBA8)
	var tex: Texture2D = load(path) as Texture2D if path != "" and ResourceLoader.exists(path) else null
	var src: Image = tex.get_image() if tex != null else null
	if src != null:
		if src.is_compressed():
			src.decompress()
		src.convert(Image.FORMAT_RGBA8)
		var side := mini(src.get_width(), src.get_height())
		if face:
			var crop := maxi(1, roundi(side * 2.0 / 3.0))
			src = src.get_region(Rect2i((src.get_size() - Vector2i(crop, crop)) / 2, Vector2i(crop, crop)))
			if crop > 16:
				src.resize(16, 16, Image.INTERPOLATE_NEAREST)
		elif side > CHIP:
			src = src.get_region(Rect2i((src.get_size() - Vector2i(CHIP, CHIP)) / 2, Vector2i(CHIP, CHIP)))
		var at := (Vector2i(CHIP, CHIP) - src.get_size()) / 2
		img.blit_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), at)
	var out := ImageTexture.create_from_image(img)
	_chips[key] = out
	return out
