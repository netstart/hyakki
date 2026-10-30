extends Screen
## Diário do Guardião (plano 3.2 e 3.6.8): um livro aberto sobre capa de laca. Marcadores de
## categoria em cima (Yōkai, Chefes, Armas, Relíquias, Kami, Guardiões, Conquistas e
## História); na página esquerda, a grade de cartões com retrato (o que ainda não se conhece
## fica em silhueta com "?"); na direita, a entrada escolhida: retrato animado ampliado, nome,
## lore e números. Contador "x/y descobertos" no alto e por página. Trocar de categoria vira
## a página (ui_fx ≥ 1); escolher outro cartão troca a página da direita com um esmaecer.
##
## Bestiário: lore liberada com 100 abates (MetaProgress.CODEX_KILLS); chefes ao vencer;
## armas base sempre, evoluções e uniões ao descobrir; relíquias e guardiões pelo
## desbloqueio; kami sempre; conquistas e história conforme o progresso.
##
## Receitas: armas e relíquias mostram, abaixo da descrição, com o que combinam e no que viram
## ("Com [ícone] Saquê, evolui em: [ícone] Lâmina da Aurora"), montadas dos dados (evolution,
## evolves_with, from, requires) com o modelo traduzido de cada idioma (cada %s vira um chip, na
## ordem do idioma). Cada item é um chip com o ícone 1:1 e o nome; tocar nele abre a entrada do
## item. O que ainda não se conhece segue a regra do Diário: chip em silhueta com "?" e "???".
##
## Missões do Santuário (marcador "Missões", CodexMissions/MissionBook): ~170 cartões em seções por
## categoria (cabeçalho com ícone, nome e "feitas/total"); cada cartão aberto mostra uma barrinha
## de progresso (assada com o cartão); a página da direita traz a barra com "312 / 500" e as
## recompensas com ícone.

const HEADER_H := 40.0
const TAB_H := 26.0
const MARGIN := 8.0
const CARD := 40.0
const CARD_GAP := 4
const FLIP_TIME := 0.16
const CATEGORIES: Array[StringName] = [&"enemies", &"bosses", &"weapons", &"relics", &"kami", &"heroes",
		&"achievements", &"story"]
const TAB_ICONS := {
	&"enemies": "res://assets/art/ui/icons/spell/Necromancy.png",
	&"bosses": "res://assets/art/ui/icons/spell/Death.png",
	&"weapons": "res://assets/art/ui/icons/items/Shuriken.png",
	&"relics": "res://assets/art/ui/icons/items/Amulet.png",
	&"kami": "res://assets/art/ui/icons/spell/OrbLight.png",
	&"heroes": "res://assets/art/ui/icons/items/Helmet.png",
	&"achievements": "res://assets/art/ui/icons/items/Ring.png",
	&"story": "res://assets/art/items/object/Book.png",
}
const STORY_ICON := "res://assets/art/items/object/Book.png"
const DAWN_ICON := "res://assets/art/ui/icons/meteo/Sun.png"
## Chip das receitas: 18x18 em escala 1 (pixel perfeito), da altura da linha da fonte 12 (16 px)
## mais a moldura. O miolo são os 16x16 centrais do ícone de habilidade 24x24 e a moldura de 1 px
## vem do bisel do próprio ícone (cor da categoria: arma, relíquia, evolução, união).
const CHIP := 18
## Chip de item desconhecido: as cores da silhueta dos cartões, com "?" no meio.
const CHIP_UNKNOWN_FILL := Color(0.3, 0.2, 0.13)
const CHIP_UNKNOWN_RIM := Color(0.55, 0.38, 0.24)
const CHIP_UNKNOWN_INK := Color("f0d9a8")
const CHIP_QUESTION: Array[String] = [".###.", "#...#", "....#", "..##.", "..#..", ".....", "..#.."]

static var _chips: Dictionary = {}

var _tabs: Array[Button] = []
var _chip: Label
var _book: Book
var _left: Control
var _page_title: Label
var _page_count: Label
var _grid_scroll: ScrollContainer
## Coluna da página da esquerda: uma grade por seção (com cabeçalho nas Missões).
var _list: VBoxContainer
var _grids: Array[GridContainer] = []
var _right: Control
var _view: EntryView
var _name: Label
var _kind: Label
var _detail_scroll: ScrollContainer
var _lore: Label
var _recipe: RichTextLabel
var _stats: Label
## Missões: barra e "312 / 500" do progresso e as recompensas com ícone.
var _progress_row: HBoxContainer
var _progress_bar: ProgressBar
var _progress_text: Label
var _rewards: RichTextLabel
var _actions: HBoxContainer
var _hint: Label
var _category: StringName = &""
var _entries: Array[Dictionary] = []
var _selected := -1
var _cards: Array[Button] = []
var _flip: Tween
## Entrada a abrir quando a página virar (toque num chip de receita de outra categoria).
var _pending := &""


func _ready() -> void:
	var scrim := ColorRect.new()
	scrim.color = Color(0.02, 0.012, 0.04, 0.5)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)
	MenuKit.header(self, tr("codex.title"), "記")
	_build_chip()
	_build_tabs()
	_book = Book.new()
	_book.name = "Book"
	add_child(_book)
	_build_left()
	_build_right()
	add_child(back_button())
	resized.connect(_layout)
	# Furo da câmera que troca de lado com a tela aberta (giro de 180°).
	MenuKit.on_insets_change(self, _layout)


func on_show() -> void:
	_layout()
	var start := _category if _category != &"" else CATEGORIES[0]
	_category = &""
	open_category(start, false)


# --- API (testes e toques) -------------------------------------------------------------

## Abre a categoria `id`; com animate, vira a página.
func open_category(id: StringName, animate: bool = true) -> void:
	if id == _category:
		return
	var index := CATEGORIES.find(id)
	if index < 0:
		return
	var previous := _category
	_category = id
	for i: int in _tabs.size():
		_style_tab(_tabs[i], i == index)
	if animate and previous != &"" and MenuKit.ui_fx() >= 1 and is_inside_tree():
		AudioManager.play_ui("ui_move")
		if _flip != null and _flip.is_valid():
			_flip.kill()
		_left.pivot_offset = Vector2(_left.size.x, _left.size.y * 0.5)
		_flip = create_tween().set_trans(Tween.TRANS_SINE)
		_flip.tween_property(_left, "scale:x", 0.0, FLIP_TIME).set_ease(Tween.EASE_IN)
		_flip.parallel().tween_property(_left, "modulate", Color(0.55, 0.5, 0.45), FLIP_TIME)
		_flip.tween_callback(_fill_page)
		_flip.tween_property(_left, "scale:x", 1.0, FLIP_TIME).set_ease(Tween.EASE_OUT)
		_flip.parallel().tween_property(_left, "modulate", Color.WHITE, FLIP_TIME)
	else:
		_left.scale = Vector2.ONE
		_left.modulate = Color.WHITE
		_fill_page()


## Mostra a entrada `index` da categoria atual na página da direita.
func open_entry(index: int) -> void:
	if index < 0 or index >= _entries.size():
		return
	_selected = index
	for i: int in _cards.size():
		(_cards[i] as Card).set_selected(i == index)
	var e := _entries[index]
	var known := bool(e["known"])
	_hint.visible = false
	_view.visible = true
	_view.setup(e, known)
	_name.text = String(e["title"]) if known else "???"
	_kind.text = String(e.get("kind", ""))
	_kind.visible = _kind.text != ""
	_lore.text = String(e["text"])
	_fill_recipe(e.get("recipe", []) as Array)
	_progress_row.visible = e.has("progress_text")
	if _progress_row.visible:
		_progress_bar.value = 1.0 if known else float(e["progress"])
		_progress_text.text = String(e["progress_text"])
	CodexMissions.fill_rewards(_rewards, e.get("rewards", []) as Array)
	_stats.text = "\n".join(e.get("stats", []) as Array) if known else ""
	_stats.visible = _stats.text != ""
	for child: Node in _actions.get_children():
		_actions.remove_child(child)
		child.queue_free()
	var story := StringName(String(e.get("replay", "")))
	if known and story != &"":
		var b := button(String(e["replay_text"]), _replay.bind(story), Vector2(0, 28))
		b.name = "Replay"
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		MenuKit.apply_primary(b, 12)
		b.add_theme_constant_override("outline_size", 3)
		_actions.add_child(b)
	_actions.visible = _actions.get_child_count() > 0
	_detail_scroll.scroll_vertical = 0
	if MenuKit.ui_fx() >= 1 and is_inside_tree():
		var tween := create_tween()
		tween.tween_property(_right, "modulate:a", 1.0, 0.18).from(0.25)
	else:
		_right.modulate.a = 1.0


func category() -> StringName:
	return _category


## Pula para a entrada `id` da categoria `cat` (toque num chip de receita); outra categoria
## vira a página e abre a entrada quando ela chega.
func open_item(cat: StringName, id: StringName) -> void:
	if cat == _category:
		var index := index_of(id)
		if index >= 0:
			open_entry(index)
		return
	_pending = id
	open_category(cat)


## Índice da entrada `id` na categoria atual; -1 se não houver.
func index_of(id: StringName) -> int:
	for i: int in _entries.size():
		if StringName(String(_entries[i].get("id", ""))) == id:
			return i
	return -1


func selected() -> int:
	return _selected


func entries() -> Array[Dictionary]:
	return _entries


func cards() -> Array[Button]:
	return _cards


## [conhecidas, total] somando todas as categorias.
func discovered_total() -> Array[int]:
	var known := 0
	var total := 0
	for id: StringName in CATEGORIES:
		for e: Dictionary in entries_for(id):
			total += 1
			known += int(bool(e["known"]))
	return [known, total]


# --- Página da esquerda --------------------------------------------------------------

func _fill_page() -> void:
	_entries = entries_for(_category)
	_cards.clear()
	_grids.clear()
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var sections: Array[Dictionary] = [{"from": 0, "to": _entries.size()}]
	if _category == &"achievements":
		sections = CodexMissions.sections(_entries)
	for s: Dictionary in sections:
		if s.has("title"):
			_list.add_child(_section_header(s))
		var grid := _new_grid()
		for i: int in range(int(s["from"]), int(s["to"])):
			var card := Card.new()
			card.setup(_entries[i])
			card.pressed.connect(func() -> void:
				AudioManager.play_ui("ui_accept")
				open_entry(i))
			grid.add_child(card)
			_cards.append(card)
	var known := 0
	for e: Dictionary in _entries:
		known += int(bool(e["known"]))
	var titles := {&"enemies": tr("codex.enemies"), &"bosses": tr("codex.bosses"), &"weapons": tr("codex.weapons"),
			&"relics": tr("codex.relics"), &"kami": tr("codex.kami"), &"heroes": tr("codex.heroes"),
			&"achievements": tr("codex.achievements"), &"story": tr("codex.story")}
	_page_title.text = String(titles[_category])
	if _category == &"achievements":
		_page_count.text = tr("codex.achievements_count") % [known, _entries.size()]
	else:
		_page_count.text = tr("codex.discovered") % [known, _entries.size()]
	_grid_scroll.scroll_vertical = 0
	_layout_grid()
	_selected = -1
	_view.visible = false
	_name.text = ""
	_kind.visible = false
	_lore.text = ""
	_recipe.visible = false
	_stats.visible = false
	_progress_row.visible = false
	_rewards.visible = false
	_actions.visible = false
	_hint.visible = true
	# Abre a primeira conhecida (ou a primeira) para a página da direita nunca ficar vazia; vindo
	# de um chip de receita, abre o item tocado.
	var first := 0
	for i: int in _entries.size():
		if bool(_entries[i]["known"]):
			first = i
			break
	if _pending != &"":
		var wanted := index_of(_pending)
		_pending = &""
		if wanted >= 0:
			first = wanted
	if not _entries.is_empty():
		open_entry(first)


## Entradas de uma categoria: {title, known, icon, face, sprite, text, stats, kind, replay}; armas
## e relíquias também têm id e recipe (linhas de _recipe_line).
func entries_for(id: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	match id:
		&"enemies":
			var kills: Dictionary = SaveManager.data["stats"]["kills_by_enemy"]
			for e: StringName in DB.ids("enemies"):
				var data := DB.enemy(e)
				if not bool(data.get("codex", true)) or String(data.get("archetype", "")) == "prop":
					continue
				var count := int(kills.get(String(e), 0))
				var lore := MetaProgress.is_enemy_entry_unlocked(e)
				var sprite := String(data["sprite"])
				out.append({"title": tr("enemy.%s.name" % e), "known": count > 0,
						"icon": sprite.get_base_dir().path_join("Faceset.png"), "face": true,
						"sprite": {"path": sprite, "layout": String(data.get("layout", "dir4")),
								"frame": data.get("frame", [16, 16]), "faces_left": bool(data.get("faces_left", false))},
						"text": tr("enemy.%s.lore" % e) if lore else tr("codex.kill_more") % [count, MetaProgress.CODEX_KILLS],
						"stats": [tr("codex.kills") % count, "%s %d · %s %d · %s %d" % [tr("heroes.attr_hp"),
								int(data.get("hp", 0)), tr("codex.stat_damage"), int(data.get("damage", 0)),
								tr("heroes.attr_speed"), int(data.get("speed", 0))]]})
		&"bosses":
			var defeated: Dictionary = SaveManager.data["stats"]["bosses_defeated"]
			for b: StringName in DB.ids("bosses"):
				if b == &"shinigami":
					continue
				var data: Dictionary = DB.bosses[b]
				var won := defeated.has(String(b))
				var sprite: Dictionary = data["sprite"]
				out.append({"title": tr("boss.%s.name" % b), "known": won,
						"icon": String(data.get("faceset", String(sprite["path"]).get_base_dir().path_join("Faceset.png"))),
						"face": true,
						"sprite": sprite, "text": tr("boss.%s.lore" % b) if won else tr("codex.boss_locked"),
						"stats": ["%s %d · %s %d · %s %d" % [tr("heroes.attr_hp"), int(data.get("hp", 0)),
								tr("codex.stat_damage"), int(data.get("damage", 0)), tr("heroes.attr_speed"),
								int(data.get("speed", 0))]]})
		&"weapons":
			out = _weapon_entries()
		&"relics":
			for p: StringName in DB.ids("passives"):
				var data: Dictionary = DB.passives[p]
				var known := _passive_known(p)
				var effect := tr("codex.per_level") % LevelUpSystem.describe_stats(data["per_level"])
				out.append({"title": tr("passive.%s.name" % p), "known": known, "icon": UiIcons.skill_path("passives", p),
						"id": String(p), "recipe": _relic_recipe(p) if known else [],
						"text": effect if known else tr("heroes.locked") % tr("achievement.%s.desc" % data["unlock"])})
		&"kami":
			for k: StringName in DB.ids("kami"):
				var data: Dictionary = DB.kami[k]
				var lines: Array[String] = []
				var blessing: Dictionary = data.get("blessing", {})
				if not blessing.is_empty():
					lines.append("%s: %s" % [tr("codex.blessing"), LevelUpSystem.describe_stats(blessing)])
				var costs: Dictionary = data.get("cost", {})
				if not costs.is_empty():
					lines.append("%s: %s" % [tr("codex.cost"), LevelUpSystem.describe_stats(costs)])
				elif data.has("special"):
					lines.append("%s: %s" % [tr("codex.cost"), tr("kami.%s.cost" % k)])
				if data.has("special"):
					lines.append(tr("kami.%s.special" % k))
				out.append({"title": tr("kami.%s.name" % k), "known": true, "icon": UiIcons.skill_path("kami", k),
						"text": "\n".join(lines), "color": String(data.get("color", ""))})
		&"heroes":
			for h: StringName in DB.ids("heroes"):
				var data: Dictionary = DB.heroes[h]
				var unlocked := MetaProgress.is_hero_unlocked(h)
				out.append({"title": tr("hero.%s.name" % h), "known": unlocked, "icon": String(data["face"]), "face": true,
						"kind": tr("hero.%s.role" % h), "hero": data,
						"text": tr("hero.%s.story" % h) if unlocked else tr("heroes.locked") % tr("achievement.%s.desc" % data["unlock"]),
						"stats": [tr("heroes.weapon") % tr("weapon.%s.name" % data["weapon"]),
								tr("heroes.ultimate") % tr("ultimate.%s.name" % data["ultimate"]["type"])]})
		&"achievements":
			out = CodexMissions.entries()
		&"story":
			out = _story_entries()
	return out


func _weapon_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var kinds := {"base": tr("codex.kind_base"), "evolution": tr("codex.kind_evolution"), "union": tr("codex.kind_union")}
	for w: StringName in DB.ids("weapons"):
		var kind := String(DB.weapon(w).get("kind", "base"))
		var known := _weapon_known(w)
		out.append({"title": tr("weapon.%s.name" % w), "known": known, "icon": UiIcons.skill_path("weapons", w),
				"id": String(w), "recipe": _weapon_recipe(w), "kind": String(kinds.get(kind, "")),
				"text": tr("weapon.%s.desc" % w) if known else tr("codex.weapon_locked")})
	return out


# --- Receitas (combinações) ------------------------------------------------------------

## Arma conhecida pelo Diário: base sempre; evolução e união depois de descobertas.
func _weapon_known(w: StringName) -> bool:
	var stats: Dictionary = SaveManager.data["stats"]
	return String(DB.weapon(w).get("kind", "base")) == "base" or (stats["evolved"] as Array).has(String(w)) \
			or (stats.get("unions", []) as Array).has(String(w))


## Relíquia conhecida pelo Diário: liberada (as sem condição desde o início).
func _passive_known(p: StringName) -> bool:
	return MetaProgress.is_content_available("passives", p, DB.passives.get(p, {}) as Dictionary)


## Item citado numa receita: {category, id, known, icon, name}; desconhecido sai como "???".
func recipe_ref(cat: StringName, id: String) -> Dictionary:
	var weapon := cat == &"weapons"
	var known := _weapon_known(StringName(id)) if weapon else _passive_known(StringName(id))
	var name_key := ("weapon.%s.name" if weapon else "passive.%s.name") % id
	return {"category": cat, "id": id, "known": known,
			"icon": UiIcons.skill_path("weapons" if weapon else "passives", id), "name": tr(name_key) if known else "???"}


## Linha de receita: o modelo traduzido (cada %s vira um chip, na ordem do idioma) e os itens.
func _recipe_line(template: String, refs: Array[Dictionary]) -> Dictionary:
	return {"text": template, "refs": refs}


## Receitas de uma arma: a base diz com que relíquia evolui e no quê; a evolução, de onde nasce
## e com que outra evolução se une; a união, de que par nasce.
func _weapon_recipe(w: StringName) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	var data := DB.weapon(w)
	match String(data.get("kind", "base")):
		"base":
			if data.has("evolution"):
				lines.append(_recipe_line(tr("codex.evolves"), [recipe_ref(&"relics", String(data.get("evolves_with", ""))),
						recipe_ref(&"weapons", String(data["evolution"]))]))
		"evolution":
			var base := String(data.get("from", ""))
			lines.append(_recipe_line(tr("codex.evolved_from"), [recipe_ref(&"weapons", base),
					recipe_ref(&"relics", String(DB.weapon(StringName(base)).get("evolves_with", "")))]))
			for u: StringName in DB.ids("weapons"):
				var parts: Array = DB.weapon(u).get("requires", [])
				if String(DB.weapon(u).get("kind", "")) == "union" and parts.size() >= 2 and parts.has(String(w)):
					var other := String(parts[1] if String(parts[0]) == String(w) else parts[0])
					lines.append(_recipe_line(tr("codex.unites_into"), [recipe_ref(&"weapons", other),
							recipe_ref(&"weapons", String(u))]))
		"union":
			var parts: Array = data.get("requires", [])
			if parts.size() >= 2:
				lines.append(_recipe_line(tr("codex.union_of"), [recipe_ref(&"weapons", String(parts[0])),
						recipe_ref(&"weapons", String(parts[1]))]))
	return lines


## Receitas de uma relíquia: cada arma base que ela faz evoluir, e no quê.
func _relic_recipe(p: StringName) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	for w: StringName in DB.ids("weapons"):
		var data := DB.weapon(w)
		if String(data.get("kind", "base")) == "base" and data.has("evolution") \
				and String(data.get("evolves_with", "")) == String(p):
			lines.append(_recipe_line(tr("codex.relic_evolves"), [recipe_ref(&"weapons", String(w)),
					recipe_ref(&"weapons", String(data["evolution"]))]))
	return lines


## Escreve as receitas na página: o texto do idioma entre os chips (ícone + nome), uma por linha.
func _fill_recipe(lines: Array) -> void:
	_recipe.clear()
	_recipe.visible = not lines.is_empty()
	for i: int in lines.size():
		if i > 0:
			_recipe.newline()
		var line: Dictionary = lines[i]
		var refs: Array = line["refs"]
		var parts := String(line["text"]).split("%s")
		for j: int in parts.size():
			if parts[j] != "":
				_recipe.add_text(parts[j])
			if j < refs.size():
				_add_chip(refs[j] as Dictionary)


## Chip de um item: ícone 18x18 centrado na linha e o nome em tinta vermelha (marrom se
## desconhecido), num link só (tocar no ícone ou no nome abre a entrada).
func _add_chip(ref: Dictionary) -> void:
	var known := bool(ref["known"])
	var label := String(ref["name"])
	_recipe.push_meta({"category": ref["category"], "id": ref["id"]}, RichTextLabel.META_UNDERLINE_NEVER, label)
	_recipe.add_image(recipe_chip(String(ref["icon"]), known), CHIP, CHIP, Color.WHITE, INLINE_ALIGNMENT_CENTER,
			Rect2(), null, false, label)
	_recipe.push_color(ThemeFactory.RED_INK if known else ThemeFactory.PAPER_INK_SOFT)
	# Espaço fino inquebrável: o nome não se separa do ícone na quebra de linha.
	_recipe.add_text(" " + label)
	_recipe.pop()
	_recipe.pop()


func _on_recipe_meta(meta: Variant) -> void:
	if meta is Dictionary:
		AudioManager.play_ui("ui_accept")
		open_item(StringName(String(meta["category"])), StringName(String(meta["id"])))


## Textura do chip (em cache): conhecido, miolo 16x16 do ícone com a moldura do bisel dele e os
## cantos vazados; desconhecido (ou sem ícone), silhueta de papel escuro com "?".
static func recipe_chip(path: String, known: bool) -> Texture2D:
	var key := "%s|%s" % [path, known]
	if _chips.has(key):
		return _chips[key]
	var src: Image = null
	if known and ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		src = tex.get_image() if tex != null else null
		if src != null:
			if src.is_compressed():
				src.decompress()
			src.convert(Image.FORMAT_RGBA8)
	var img := Image.create_empty(CHIP, CHIP, false, Image.FORMAT_RGBA8)
	var last := CHIP - 1
	for y: int in CHIP:
		for x: int in CHIP:
			var edge := x == 0 or y == 0 or x == last or y == last
			if (x == 0 or x == last) and (y == 0 or y == last):
				continue
			if src != null:
				img.set_pixel(x, y, src.get_pixel(_chip_src(x, src.get_width()), _chip_src(y, src.get_height())))
			else:
				img.set_pixel(x, y, CHIP_UNKNOWN_RIM if edge else CHIP_UNKNOWN_FILL)
	if src == null:
		var at := Vector2i((CHIP - CHIP_QUESTION[0].length()) / 2, (CHIP - CHIP_QUESTION.size()) / 2)
		for row: int in CHIP_QUESTION.size():
			for col: int in CHIP_QUESTION[row].length():
				if CHIP_QUESTION[row][col] == "#":
					img.set_pixel(at.x + col, at.y + row, CHIP_UNKNOWN_INK)
	var out := ImageTexture.create_from_image(img)
	_chips[key] = out
	return out


## Pixel do ícone (lado `side`, 24) para a coordenada `c` do chip: a borda pega o bisel (1 px
## para dentro da borda do ícone) e o miolo 1..16 pega os 16 pixels centrais (4..19).
static func _chip_src(c: int, side: int) -> int:
	if c == 0:
		return 1
	if c == CHIP - 1:
		return side - 2
	return c + (side - CHIP) / 2


func _story_entries() -> Array[Dictionary]:
	var story: Dictionary = SaveManager.data["story"]
	var out: Array[Dictionary] = [
		{"title": tr("codex.story_intro"), "known": bool(story["intro_seen"]), "icon": STORY_ICON,
				"replay": "intro", "replay_text": tr("codex.replay_intro")},
		{"title": tr("codex.story_ending"), "known": bool(story["ending_seen"]), "icon": STORY_ICON,
				"replay": "ending", "replay_text": tr("codex.replay_ending")},
		{"title": tr("codex.story_secret"), "known": bool(story["secret_ending_seen"]), "icon": STORY_ICON,
				"replay": "secret_ending", "replay_text": tr("codex.replay_secret")},
	]
	for e: Dictionary in out:
		e["text"] = String(e["replay_text"]) if bool(e["known"]) else tr("codex.story_locked")
	for s: StringName in DB.ids("stages"):
		var won := bool(SaveManager.stage_best(s)["won"])
		out.append({"title": tr("stage.%s.name" % s), "known": won, "icon": DAWN_ICON,
				"text": tr("stage.%s.dawn" % s) if won else tr("codex.story_locked")})
	return out


func _replay(story_id: StringName) -> void:
	app.play_story(story_id, func() -> void: app.go(&"codex"))


# --- Montagem ------------------------------------------------------------------------

func _build_chip() -> void:
	var chip := PanelContainer.new()
	chip.name = "Progress"
	chip.add_theme_stylebox_override("panel", ThemeFactory.flat_box(Color(0.05, 0.03, 0.06, 0.7),
			Color(ThemeFactory.ACCENT, 0.4), 1, 8, Vector2(7, 1)))
	chip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	chip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	chip.offset_right = -MARGIN
	var place := func() -> void: chip.offset_right = -MARGIN - MenuKit.safe_insets(chip).y
	chip.ready.connect(func() -> void:
		place.call()
		MenuKit.on_insets_change(chip, place), CONNECT_ONE_SHOT)
	chip.offset_top = HEADER_H + 5
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var star := TextureRect.new()
	star.texture = UiIcons.get_icon("star", 10)
	star.modulate = ThemeFactory.ACCENT
	star.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	star.custom_minimum_size = Vector2(10, 14)
	row.add_child(star)
	_chip = MenuKit.text("", 12, ThemeFactory.ACCENT)
	_chip.name = "ProgressText"
	row.add_child(_chip)
	chip.add_child(row)
	add_child(chip)


func _build_tabs() -> void:
	var titles := [tr("codex.enemies"), tr("codex.bosses"), tr("codex.weapons"), tr("codex.relics"),
			tr("codex.kami"), tr("codex.heroes"), tr("codex.achievements"), tr("codex.story")]
	for i: int in CATEGORIES.size():
		var b := Button.new()
		b.name = "Tab_%s" % CATEGORIES[i]
		b.tooltip_text = titles[i]
		b.set_meta("title", titles[i])
		b.focus_mode = Control.FOCUS_ALL
		b.icon = load(TAB_ICONS[CATEGORIES[i]]) as Texture2D
		b.expand_icon = false
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.add_theme_constant_override("h_separation", 4)
		var id := CATEGORIES[i]
		b.pressed.connect(func() -> void: open_category(id))
		add_child(b)
		_tabs.append(b)


## Marcador: o escolhido mostra o nome e fica vermelhão; os outros só o ícone, em laca.
func _style_tab(b: Button, on: bool) -> void:
	b.text = String(b.get_meta("title")) if on else ""
	var bg := Color("b8322a") if on else Color(0.12, 0.06, 0.06, 0.88)
	var normal := ThemeFactory.flat_box(bg, ThemeFactory.ACCENT if on else Color(ThemeFactory.GOLD, 0.45), 1, 3,
			Vector2(6, 1))
	normal.corner_radius_bottom_left = 0
	normal.corner_radius_bottom_right = 0
	normal.border_width_bottom = 0
	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = ThemeFactory.ACCENT
	if not on:
		hover.bg_color = Color(0.3, 0.09, 0.07, 0.92)
	var boxes: Array[StyleBoxFlat] = [normal, hover, hover, normal]
	ThemeFactory.apply_button_boxes(b, boxes)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_constant_override("outline_size", 3)
	b.add_theme_color_override("font_outline_color", Color(0.25, 0.04, 0.03))
	b.modulate = Color.WHITE if on else Color(0.85, 0.82, 0.8)
	_layout_tabs()


func _build_left() -> void:
	_left = Control.new()
	_left.name = "LeftPage"
	_left.clip_contents = true
	_book.add_child(_left)
	var col := VBoxContainer.new()
	col.name = "Column"
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 3)
	_left.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	_page_title = _ink("", 12, ThemeFactory.RED_INK)
	_page_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(_page_title)
	_page_count = _ink("", 12, ThemeFactory.PAPER_INK_SOFT)
	_page_count.name = "PageCount"
	head.add_child(_page_count)
	col.add_child(head)
	col.add_child(_ink_rule())
	_grid_scroll = ScrollContainer.new()
	_grid_scroll.name = "GridScroll"
	_grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid_scroll.scroll_deadzone = 8
	_style_ink_scrollbar(_grid_scroll.get_v_scroll_bar())
	col.add_child(_grid_scroll)
	_list = VBoxContainer.new()
	_list.name = "Sections"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 3)
	_list.mouse_filter = Control.MOUSE_FILTER_PASS
	_grid_scroll.add_child(_list)


## Grade de cartões (centrada na página) no fim da coluna da esquerda.
func _new_grid() -> GridContainer:
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.use_top_left = false
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	_list.add_child(center)
	var grid := GridContainer.new()
	grid.name = "Cards"
	grid.add_theme_constant_override("h_separation", CARD_GAP)
	grid.add_theme_constant_override("v_separation", CARD_GAP)
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	grid.columns = _columns()
	center.add_child(grid)
	_grids.append(grid)
	return grid


## Cabeçalho de uma seção das Missões: ícone, nome da categoria e "feitas/total".
func _section_header(s: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.name = "Section_%s" % s["id"]
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	var icon := TextureRect.new()
	var path := String(s["icon"])
	icon.texture = load(path) as Texture2D if ResourceLoader.exists(path) else null
	icon.custom_minimum_size = Vector2(16, 16)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var title := _ink(String(s["title"]), 12, ThemeFactory.RED_INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(title)
	row.add_child(_ink("%d/%d" % [s["done"], s["total"]], 12, ThemeFactory.PAPER_INK_SOFT))
	return row


func _build_right() -> void:
	_right = Control.new()
	_right.name = "RightPage"
	_right.clip_contents = true
	_book.add_child(_right)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 3)
	_right.add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	col.add_child(top)
	_view = EntryView.new()
	_view.name = "EntryView"
	_view.custom_minimum_size = Vector2(64, 64)
	top.add_child(_view)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	titles.add_theme_constant_override("separation", 1)
	top.add_child(titles)
	_name = _ink("", 16, ThemeFactory.PAPER_INK)
	_name.name = "EntryName"
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titles.add_child(_name)
	_kind = _ink("", 12, ThemeFactory.RED_INK)
	_kind.name = "EntryKind"
	_kind.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titles.add_child(_kind)
	col.add_child(_ink_rule())
	_detail_scroll = ScrollContainer.new()
	_detail_scroll.name = "DetailScroll"
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_scroll.scroll_deadzone = 8
	_style_ink_scrollbar(_detail_scroll.get_v_scroll_bar())
	col.add_child(_detail_scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 5)
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	_detail_scroll.add_child(body)
	_hint = _ink(tr("codex.pick_hint"), 12, ThemeFactory.PAPER_INK_SOFT)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_hint)
	_lore = _ink("", 12, ThemeFactory.PAPER_INK)
	_lore.name = "Lore"
	_lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_lore)
	_recipe = RichTextLabel.new()
	_recipe.name = "Recipe"
	_recipe.fit_content = true
	_recipe.scroll_active = false
	_recipe.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_recipe.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recipe.mouse_filter = Control.MOUSE_FILTER_PASS
	_recipe.meta_underlined = false
	_recipe.add_theme_color_override("default_color", ThemeFactory.PAPER_INK)
	_recipe.add_theme_constant_override("outline_size", 0)
	_recipe.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.25))
	_recipe.add_theme_constant_override("shadow_offset_x", 0)
	_recipe.add_theme_constant_override("shadow_offset_y", 1)
	_recipe.add_theme_constant_override("line_separation", 2)
	_recipe.meta_clicked.connect(_on_recipe_meta)
	_recipe.visible = false
	body.add_child(_recipe)
	_stats = _ink("", 12, Color("2f5a22"))
	_stats.name = "Stats"
	_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_stats)
	_build_mission_rows(body)
	_actions = HBoxContainer.new()
	_actions.name = "Actions"
	body.add_child(_actions)


## Barra do progresso da missão e "312 / 500" ao lado, e as recompensas com ícone.
func _build_mission_rows(body: VBoxContainer) -> void:
	_progress_row = HBoxContainer.new()
	_progress_row.name = "MissionProgress"
	_progress_row.add_theme_constant_override("separation", 6)
	_progress_row.tooltip_text = tr("mission.progress")
	_progress_bar = ProgressBar.new()
	_progress_bar.show_percentage = false
	_progress_bar.max_value = 1.0
	_progress_bar.step = 0.0
	_progress_bar.custom_minimum_size = Vector2(24, 8)
	_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_progress_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	_progress_bar.add_theme_stylebox_override("background", ThemeFactory.flat_box(Color(0.3, 0.2, 0.1, 0.2),
			Color(ThemeFactory.RED_INK, 0.6), 1, 2))
	_progress_bar.add_theme_stylebox_override("fill", ThemeFactory.flat_box(ThemeFactory.GOLD, ThemeFactory.RED_INK, 1, 2))
	_progress_row.add_child(_progress_bar)
	_progress_text = _ink("", 12, ThemeFactory.PAPER_INK)
	_progress_text.name = "ProgressValue"
	_progress_row.add_child(_progress_text)
	_progress_row.visible = false
	body.add_child(_progress_row)
	_rewards = RichTextLabel.new()
	_rewards.name = "Rewards"
	_rewards.fit_content = true
	_rewards.scroll_active = false
	_rewards.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rewards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rewards.mouse_filter = Control.MOUSE_FILTER_PASS
	_rewards.add_theme_color_override("default_color", ThemeFactory.PAPER_INK)
	_rewards.add_theme_constant_override("outline_size", 0)
	_rewards.add_theme_constant_override("line_separation", 2)
	_rewards.visible = false
	body.add_child(_rewards)


func _ink(value: String, font_size: int, color: Color) -> Label:
	var l := MenuKit.text(value, font_size, color)
	l.add_theme_constant_override("outline_size", 0)
	l.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.25))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 1)
	return l


func _ink_rule() -> Control:
	var line := ColorRect.new()
	line.color = Color(ThemeFactory.RED_INK, 0.45)
	line.custom_minimum_size = Vector2(0, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func _style_ink_scrollbar(bar: ScrollBar) -> void:
	bar.add_theme_stylebox_override("scroll", ThemeFactory.flat_box(Color(0.3, 0.2, 0.1, 0.15),
			Color(0, 0, 0, 0), 0, 2, Vector2(2, 2)))
	for state: String in ["grabber", "grabber_highlight", "grabber_pressed"]:
		bar.add_theme_stylebox_override(state, ThemeFactory.flat_box(Color(ThemeFactory.RED_INK, 0.7),
				Color(0, 0, 0, 0), 0, 2, Vector2(2, 8)))
	bar.custom_minimum_size.x = 4


# --- Layout --------------------------------------------------------------------------

func _layout() -> void:
	if _book == null:
		return
	var inset := MenuKit.safe_insets(self)
	var w := size.x - inset.x - inset.y
	var h := size.y
	_layout_tabs()
	var total := discovered_total()
	_chip.text = tr("codex.discovered") % total if w >= 600.0 else "%d/%d" % total
	var top := HEADER_H + TAB_H
	_book.position = Vector2(inset.x + MARGIN - 2, top)
	_book.size = Vector2(w - MARGIN * 2.0 + 4, h - top - 4)
	var inner := Rect2(Vector2(8, 6), _book.size - Vector2(16, 12))
	var left_w := roundf(inner.size.x * (0.46 if w >= 600.0 else 0.47))
	_left.position = inner.position + Vector2(4, 4)
	_left.size = Vector2(left_w - 14, inner.size.y - 8)
	_right.position = Vector2(inner.position.x + left_w + 10, inner.position.y + 4)
	_right.size = Vector2(inner.end.x - _right.position.x - 4, inner.size.y - 8)
	_book.spine_x = inner.position.x + left_w
	_view.custom_minimum_size = Vector2(72, 72) if h >= 290.0 else Vector2(56, 56)
	_layout_grid()
	_book.queue_redraw()


func _layout_tabs() -> void:
	var x := MenuKit.safe_insets(self).x + MARGIN + 4
	for b: Button in _tabs:
		b.custom_minimum_size = Vector2(28, TAB_H)
		b.size = Vector2(maxf(28.0, b.get_combined_minimum_size().x), TAB_H)
		b.position = Vector2(x, HEADER_H)
		x += b.size.x + 2


func _layout_grid() -> void:
	for grid: GridContainer in _grids:
		grid.columns = _columns()


func _columns() -> int:
	return maxi(1, floori((_left.size.x - 8.0 + CARD_GAP) / (CARD + CARD_GAP)))


# --- Peças desenhadas ----------------------------------------------------------------

## Capa de laca com cantoneiras de ouro, duas páginas de papel e a lombada com sombra.
class Book extends Control:
	var spine_x := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var cover := ThemeFactory.flat_box(Color("3b1712"), Color("1a0806"), 1, 4)
		cover.shadow_color = Color(0, 0, 0, 0.55)
		cover.shadow_size = 3
		cover.shadow_offset = Vector2(0, 3)
		draw_style_box(cover, r)
		draw_rect(Rect2(r.position + Vector2(3, 3), r.size - Vector2(6, 6)), Color(ThemeFactory.GOLD, 0.35), false, 1.0)
		var inner := Rect2(Vector2(8, 6), size - Vector2(16, 12))
		var left := Rect2(inner.position, Vector2(spine_x - inner.position.x, inner.size.y))
		var right := Rect2(Vector2(spine_x, inner.position.y), Vector2(inner.end.x - spine_x, inner.size.y))
		# Bordas das folhas por baixo (espessura do livro).
		for i: int in 3:
			var off := float(3 - i)
			draw_rect(Rect2(left.position + Vector2(-off, off), left.size), ThemeFactory.PAPER_DARK.darkened(0.1 * i))
			draw_rect(Rect2(right.position + Vector2(off, off), right.size), ThemeFactory.PAPER_DARK.darkened(0.1 * i))
		draw_rect(left, ThemeFactory.PAPER)
		draw_rect(right, ThemeFactory.PAPER)
		# Sombra da lombada: escurece perto do meio das duas páginas.
		for i: int in 10:
			var a := 0.16 * (1.0 - i / 10.0)
			draw_rect(Rect2(spine_x - 1 - i, inner.position.y, 1, inner.size.y), Color(0.35, 0.2, 0.1, a))
			draw_rect(Rect2(spine_x + i, inner.position.y, 1, inner.size.y), Color(0.35, 0.2, 0.1, a))
		draw_rect(Rect2(spine_x - 1, inner.position.y, 2, inner.size.y), Color(0.3, 0.16, 0.08, 0.5))
		# Cantoneiras de ouro.
		for c: Vector2 in [r.position, Vector2(r.end.x - 7, 0), Vector2(0, r.end.y - 7), r.end - Vector2(7, 7)]:
			draw_rect(Rect2(c, Vector2(7, 7)), ThemeFactory.GOLD)
			draw_rect(Rect2(c + Vector2(2, 2), Vector2(3, 3)), Color("8a6020"))


## Cartão da grade: moldura de papel escuro com o retrato; desconhecido em silhueta com "?";
## o escolhido ganha borda de tinta vermelha.
class Card extends Button:
	var entry: Dictionary
	var _tex: Texture2D
	var _pair: Array[Texture2D] = []
	var _shape: SpriteSheet
	var _selected := false
	## O cartão inteiro fica assado numa textura (StaticBake), refeita só quando muda (toque,
	## foco, seleção, tamanho): a grade rolando desenha um retângulo por cartão em vez de ~6
	## trocas de textura cada (caixa, silhueta, aro, "?").
	var _bake: StaticBake

	func setup(p_entry: Dictionary) -> void:
		entry = p_entry
		custom_minimum_size = Vector2(40, 40)
		focus_mode = Control.FOCUS_ALL
		tooltip_text = String(entry["title"]) if bool(entry["known"]) else "???"
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		var path := String(entry.get("icon", ""))
		if path != "" and ResourceLoader.exists(path):
			_tex = load(path) as Texture2D
		var sprite: Dictionary = entry.get("sprite", {})
		var drawable := not sprite.is_empty() and String(sprite.get("layout", "dir4")) != "region"
		if not bool(entry["known"]) and drawable and ResourceLoader.exists(String(sprite["path"])):
			# Retrato desconhecido: silhueta do próprio sprite (o rosto tem fundo opaco).
			var frame: Array = sprite.get("frame", [16, 16])
			var layout := String(sprite.get("layout", "dir4"))
			_shape = SpriteSheet.load_sheet(String(sprite["path"]), layout, Vector2(float(frame[0]), float(frame[1])),
					4 if layout == "dir4" else 0, bool(sprite.get("faces_left", false)))
			_pair = MenuKit.silhouette_pair(_shape.texture, Color(0.3, 0.2, 0.13), Color(0.55, 0.38, 0.24, 0.9))
		elif _tex != null and not bool(entry["known"]) and not bool(entry.get("show_locked", false)):
			_pair = MenuKit.silhouette_pair(_tex, Color(0.3, 0.2, 0.13), Color(0.55, 0.38, 0.24, 0.9))
		if _bake == null:
			_bake = StaticBake.new(_paint)
			_bake.name = "Bake"
			add_child(_bake)
		_bake.invalidate()
		mouse_entered.connect(_bake.invalidate)
		mouse_exited.connect(_bake.invalidate)
		focus_entered.connect(_bake.invalidate)
		focus_exited.connect(_bake.invalidate)

	func set_selected(on: bool) -> void:
		_selected = on
		if _bake != null:
			_bake.invalidate()

	func is_selected() -> bool:
		return _selected

	func _paint(c: CanvasItem) -> void:
		var r := Rect2(Vector2.ZERO, size)
		var known := bool(entry["known"])
		var hot := is_hovered() or has_focus()
		var border := ThemeFactory.RED_INK if _selected else Color("6b4a2a", 0.9 if hot else 0.55)
		var bg := Color("f6ead0") if known else Color("dcc79b")
		c.draw_style_box(ThemeFactory.flat_box(bg, border, 2 if _selected else 1, 3), r)
		if _shape != null:
			var cell := _shape.frame_size
			var k := maxf(1.0, floorf((size.x - 8.0) / maxf(cell.x, cell.y))) if cell.x <= 32.0 else (size.x - 8.0) / cell.x
			var dest := Rect2(r.get_center() - cell * k * 0.5, cell * k)
			dest.position = dest.position.round()
			var src := _shape.region(0, SpriteSheet.Dir.DOWN)
			c.draw_texture_rect_region(_pair[0], dest, src)
			c.draw_texture_rect_region(_pair[1], dest, src)
		elif _tex != null:
			var inner := r.grow(-4)
			var fs := _tex.get_size()
			var src := Rect2(Vector2.ZERO, fs)
			var dest := inner
			if bool(entry.get("face", false)):
				var k := 1.0 if fs.x <= 40.0 else 0.5
				var crop := inner.size / k
				src = Rect2((fs - crop) * 0.5, crop)
			else:
				var s := minf(floorf(inner.size.x / fs.x), floorf(inner.size.y / fs.y))
				s = maxf(s, 1.0) if fs.x <= inner.size.x else inner.size.x / fs.x
				dest = Rect2(inner.get_center() - fs * s * 0.5, fs * s).abs()
				dest.position = dest.position.round()
			if not _pair.is_empty():
				c.draw_texture_rect_region(_pair[0], dest, src)
				c.draw_texture_rect_region(_pair[1], dest, src)
			else:
				var tint := Color.WHITE if known else Color(0.45, 0.4, 0.38, 0.7)
				c.draw_texture_rect_region(_tex, dest, src, tint)
		if entry.has("progress") and not known:
			var bar := Rect2(4, size.y - 7, size.x - 8, 4)
			c.draw_rect(bar, Color("6b4a2a", 0.55))
			var fill := floorf((bar.size.x - 2.0) * clampf(float(entry["progress"]), 0.0, 1.0))
			if fill > 0.0:
				c.draw_rect(Rect2(bar.position + Vector2(1, 1), Vector2(fill, 2)), ThemeFactory.GOLD)
		elif not known:
			var font := get_theme_default_font()
			var q := "?"
			var at := Vector2(size.x - 9, size.y - 4)
			c.draw_string_outline(font, at, q, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, Color("2a1a10"))
			c.draw_string(font, at, q, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("f0d9a8"))
		elif bool(entry.get("show_locked", false)):
			c.draw_rect(Rect2(size.x - 9, 3, 6, 6), Color("2f7d4a"))
			c.draw_rect(Rect2(size.x - 9, 3, 6, 6), ThemeFactory.GOLD, false, 1.0)


## Retrato ampliado da entrada, num disco de tinta: o sprite anima (inimigos e chefes), os
## rostos e ícones ficam parados. Desconhecido: silhueta.
class EntryView extends Control:
	var _sheet: SpriteSheet
	var _tex: Texture2D
	var _src := Rect2()
	var _known := true
	var _pair: Array[Texture2D] = []
	var _time := 0.0
	var _color := Color(0.62, 0.17, 0.12)
	var _disc: Control
	var _drawn_frame := -1

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_disc = Control.new()
		_disc.show_behind_parent = true
		_disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_disc.set_anchors_preset(Control.PRESET_FULL_RECT)
		_disc.draw.connect(_draw_disc.bind(_disc))
		add_child(_disc)

	func setup(entry: Dictionary, known: bool) -> void:
		_known = known
		_sheet = null
		_tex = null
		_pair = []
		var color := String(entry.get("color", ""))
		_color = Color(color) if color != "" else Color(0.62, 0.17, 0.12)
		var sprite: Dictionary = entry.get("sprite", {})
		var hero: Dictionary = entry.get("hero", {})
		if not hero.is_empty():
			sprite = {"path": hero["sprite"], "layout": String(hero.get("layout", "dir4")),
					"frame": hero.get("frame", [16, 16]), "scale": float(hero.get("draw_scale", 1.0)),
					"idle": int(hero.get("idle_frames", 1))}
		var path := String(sprite.get("path", ""))
		if path != "" and ResourceLoader.exists(path) and String(sprite.get("layout", "dir4")) != "region":
			var frame: Array = sprite.get("frame", [16, 16])
			var layout := String(sprite.get("layout", "dir4"))
			_sheet = SpriteSheet.load_sheet(path, layout, Vector2(float(frame[0]), float(frame[1])),
					4 if layout == "dir4" else (int(sprite.get("idle", 0)) if layout == "side" else 0),
					bool(sprite.get("faces_left", false)), float(sprite.get("scale", 1.0)))
			if not known:
				_pair = MenuKit.silhouette_pair(_sheet.texture, Color(0.24, 0.17, 0.12), Color(0.45, 0.3, 0.2, 0.9))
		else:
			var icon := String(entry.get("icon", ""))
			if icon != "" and ResourceLoader.exists(icon):
				_tex = load(icon) as Texture2D
				if not known and not bool(entry.get("show_locked", false)):
					_pair = MenuKit.silhouette_pair(_tex, Color(0.24, 0.17, 0.12), Color(0.45, 0.3, 0.2, 0.9))
		set_process(_sheet != null and MenuKit.ui_fx() >= 1)
		queue_redraw()
		_disc.queue_redraw()

	## O sprite anda a 6 quadros/s: só redesenha quando o quadro muda, e espera enquanto uma lista
	## rola pelo dedo (TouchScroll.busy).
	func _process(delta: float) -> void:
		_time += delta
		if int(_time * 6.0) != _drawn_frame and not TouchScroll.busy():
			queue_redraw()

	## Disco de tinta e aros, fixos, numa camada atrás (os aros são polígonos: não são refeitos a
	## cada quadro do sprite).
	func _draw_disc(layer: Control) -> void:
		var c := size * 0.5
		var rad := minf(size.x, size.y) * 0.5
		layer.draw_circle(c + Vector2(0, 1), rad, Color(0.3, 0.18, 0.08, 0.35))
		layer.draw_circle(c, rad, Color("e3cfa2"))
		layer.draw_arc(c, rad - 1.0, 0.0, TAU, 40, Color(_color, 0.8), 2.0)
		layer.draw_arc(c, rad - 4.0, 0.0, TAU, 40, Color(_color, 0.3), 1.0)

	func _draw() -> void:
		var c := size * 0.5
		var rad := minf(size.x, size.y) * 0.5
		_drawn_frame = int(_time * 6.0)
		if _sheet != null:
			var cell := _sheet.frame_size
			var k := maxf(1.0, floorf((rad * 1.5) / maxf(cell.x, cell.y)))
			var frame := int(_time * 6.0)
			var src := _sheet.region(frame, SpriteSheet.Dir.DOWN)
			var flip := _sheet.layout == "side" or (_sheet.layout == "strip" and _sheet.faces_left)
			var dest := Rect2(c - cell * k * 0.5, cell * k)
			dest.position = dest.position.round()
			var tex := _sheet.texture if _pair.is_empty() else _pair[0]
			if flip:
				draw_set_transform(dest.position + Vector2(dest.size.x, 0), 0.0, Vector2(-k, k))
				draw_texture_rect_region(tex, Rect2(Vector2.ZERO, cell), src)
				if not _pair.is_empty():
					draw_texture_rect_region(_pair[1], Rect2(Vector2.ZERO, cell), src)
				draw_set_transform(Vector2.ZERO)
			else:
				draw_texture_rect_region(tex, dest, src)
				if not _pair.is_empty():
					draw_texture_rect_region(_pair[1], dest, src)
		elif _tex != null:
			var fs := _tex.get_size()
			var k := maxf(1.0, floorf((rad * 1.4) / maxf(fs.x, fs.y)))
			if fs.x > rad * 1.6:
				k = (rad * 1.5) / fs.x
			var dest := Rect2(c - fs * k * 0.5, fs * k)
			dest.position = dest.position.round()
			if _pair.is_empty():
				draw_texture_rect(_tex, dest, false)
			else:
				draw_texture_rect(_pair[0], dest, false)
				draw_texture_rect(_pair[1], dest, false)
