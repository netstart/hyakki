class_name LevelUpPanel
extends Control
## Tela de NOVA HABILIDADE (plano 7.4), sobre a luta parada:
## - entrada: o mundo escurece (desfoque, vinheta e fogos-fátuos em Alta), raios de luz se
##   abrem atrás das cartas, o título "Nível N" desce com o selo 昇 e as cartas entram em
##   leque, uma a uma, cada uma com o som do papel;
## - cartas LevelCard (moldura por categoria, lendária animada, números em verde, sinergia);
## - toque: a carta destacada sobe e brilha; ao escolher, as outras caem, a escolhida encolhe
##   na luz e o ícone dela voa até a guardiã (`claimed` -> RewardFlight da HUD); bloqueio contra
##   toque acidental (CARD_LOCK_MS depois de abrir e só com a carta já no lugar);
## - Rerrolar / Pular / Banir com glifo e contador; no modo banir as cartas ficam com borda
##   vermelha e o carimbo 封 cai na escolhida.
## Cabe em 678x305 e 480x270 em todos os idiomas (tests/level_up_panel_tests.gd).
## Quem decide o jogo é o HyakkiGame: a tela só emite os sinais (a HUD repassa).

signal card_chosen(index: int)
signal reroll_pressed
signal skip_pressed
signal banish_pressed(index: int)
## O ícone da carta escolhida, pronto para o voo até a guardiã (ver RewardFlight.launch).
signal claimed(items: Array[Dictionary])

const CARD_LOCK_MS := 350
const MAX_CARDS := 4
const MARGIN := 8.0
const GAP := 8.0
const HEADER_H := 48.0
const ACTIONS_H := 24.0
const CARD_MIN := Vector2(96, 140)
const CARD_MAX := Vector2(146, 200)
## Entrada: fundo, atraso da primeira carta, intervalo entre cartas e voo de cada uma.
const FADE_IN := 0.25
const DEAL_DELAY := 0.14
const DEAL_STEP := 0.085
const DEAL_TIME := 0.32
const REDEAL_DELAY := 0.0
## Saída: queda das outras cartas e o fundo sumindo (o voo do ícone fica com a RewardFlight).
const DROP_TIME := 0.32
const FADE_OUT := 0.32
const STAMP_TIME := 0.42
## Cor do halo por elemento (a primeira etiqueta da arma que estiver aqui, na ordem).
const ELEMENTS := [
	["fire", Color("ff9a4d")], ["thunder", Color("ffe066")], ["wind", Color("8ff0e0")],
	["aura", Color("c9a7ff")], ["orbit", Color("ffe3a3")], ["area", Color("9be37f")],
	["blade", Color("dfe9ff")], ["projectile", Color("bcd2f0")],
]
const PASSIVE_GLOW := Color("8ff0c8")
const HEAL_GLOW := Color("ff9db0")
const RYO_GLOW := Color("ffd166")

## Botão de ação com glifo de pixel à esquerda e contador num selo dourado.
class ActionButton:
	extends Button
	var glyph: String = ""
	var count: int = 0
	var active: bool = false
	var _t: float = 0.0

	func _process(delta: float) -> void:
		_t += delta
		if active:
			queue_redraw()

	func _draw() -> void:
		var hot := get_draw_mode() != DRAW_NORMAL
		var color := Color.WHITE if (hot or active) else UiPaint.PAPER
		if active:
			var pulse := 0.5 + 0.5 * sin(_t * 6.0)
			draw_rect(Rect2(Vector2.ZERO, size).grow(1.0), Color(1, 0.4, 0.3, 0.25 + 0.4 * pulse), false, 1.0)
		UiPaint.glyph(self, glyph, Vector2(7, floorf((size.y - 12.0) * 0.5)), color)
		# Contador: selo redondo dourado no canto direito.
		var c := Vector2(size.x - 9.0, floorf(size.y * 0.5))
		draw_circle(c, 7.0, Color("3b2416"))
		draw_circle(c, 6.0, ThemeFactory.ACCENT if count > 0 else Color(0.5, 0.45, 0.4))
		var label := str(count)
		var w := UiPaint.text_width(label)
		UiPaint.text(self, Vector2(roundf(c.x - w * 0.5), c.y + 4.0), label, 12, Color("3b2416"),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 0)


var _open: bool = false
var _opened_at: int = 0
var _banish_mode: bool = false
## Entrada da tela: primeira abertura (com fundo e título) ou troca das cartas.
var _intro: float = 0.0
var _level: int = 0
var _fx_level: int = 2
var _busy: bool = false
var _tweens: Array[Tween] = []
var _deal_count: int = 0
## Carta escolhida esperando o hide_panel para a saída (-1 = nenhuma).
var _chosen: int = -1

var _fx: OverlayFx
var _header: Control
var _row: Control
var _cards: Array[LevelCard] = []
var _actions: HBoxContainer
var _reroll: ActionButton
var _skip: ActionButton
var _banish: ActionButton
var _time: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_fx = OverlayFx.new()
	add_child(_fx)
	_header = Control.new()
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header.draw.connect(_draw_header)
	add_child(_header)
	_row = Control.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_row)
	for i: int in range(MAX_CARDS):
		var card := LevelCard.new()
		card.visible = false
		card.pressed.connect(_on_card.bind(i))
		card.mouse_entered.connect(func() -> void:
			if card.settled and _open:
				AudioManager.play("ui_move", 1.0 + 0.05 * i, 0.0, -8.0))
		_row.add_child(card)
		_cards.append(card)
	_actions = HBoxContainer.new()
	_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	_actions.add_theme_constant_override("separation", 8)
	_actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_actions)
	_reroll = _action("reroll", func() -> void:
		if _accepting():
			_set_banish(false)
			reroll_pressed.emit())
	_skip = _action("skip", func() -> void:
		if _accepting():
			_set_banish(false)
			_play_skip()
			skip_pressed.emit())
	_banish = _action("banish", func() -> void:
		if _accepting():
			_set_banish(not _banish_mode))
	resized.connect(_layout)
	# Furo da câmera que troca de lado com a tela aberta (giro de 180°).
	MenuKit.on_insets_change(self, _layout)
	Settings.changed.connect(func(key: String) -> void:
		if key == GfxQuality.changed_signal_key():
			_apply_quality())
	_apply_quality()


# --- API ---------------------------------------------------------------------------------

## Mostra as cartas. Na primeira vez, com a entrada completa; depois (rerrolar, banir ou
## outro nível em seguida), só troca as cartas.
func show_cards(cards: Array[Dictionary], rerolls: int, skips: int, banishes: int, level: int = 0,
		game: HyakkiGame = null) -> void:
	var first := not _open
	_open = true
	_chosen = -1
	_busy = false
	_level = level
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_opened_at = Time.get_ticks_msec()
	_set_banish(false)
	_kill_tweens()
	_apply_quality()
	for i: int in range(_cards.size()):
		var card := _cards[i]
		card.visible = i < cards.size()
		card.settled = false
		card.disabled = false
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.modulate = Color.WHITE
		if card.visible:
			card.setup(cards[i], card_info(cards[i], game))
	_set_action(_reroll, tr("lvchest.reroll"), rerolls)
	_set_action(_skip, tr("lvchest.skip"), skips)
	_set_action(_banish, tr("lvchest.banish"), banishes)
	_layout()
	if first:
		_intro = 0.0
		_fx.power = 0.0
		_fx.rays = 0.0
		var t := _tween()
		t.tween_property(_fx, "power", 1.0, FADE_IN)
		t.parallel().tween_property(_fx, "rays", 1.0, FADE_IN * 2.0)
		t.parallel().tween_property(self, "_intro", 1.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_fx.flash_color = Color(1.0, 0.9, 0.6)
		_fx.flash = 0.5
		AudioManager.play("magic2", 1.2, 0.0, -10.0)
	else:
		_fx.power = 1.0
		_fx.rays = 1.0
		_intro = 1.0
	_deal(REDEAL_DELAY if not first else DEAL_DELAY)


## Fecha (o jogo chamou hide_level_up). Se uma carta foi escolhida, a saída segue animando
## sem pegar toques; senão, só some.
func hide_panel() -> void:
	if not _open and not visible:
		return
	_open = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for card: LevelCard in _cards:
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.settled = false
	_set_banish(false)
	if _chosen >= 0:
		_drop_cards(_chosen)
		_chosen = -1
	var t := _tween()
	t.tween_property(_fx, "power", 0.0, FADE_OUT)
	t.parallel().tween_property(self, "_intro", 0.0, FADE_OUT * 0.7)
	t.parallel().tween_property(_actions, "modulate:a", 0.0, FADE_OUT * 0.5)


## Some na hora, sem animação (bot, nova partida).
func close_now() -> void:
	_open = false
	_busy = false
	_chosen = -1
	_kill_tweens()
	_set_banish(false)
	for card: LevelCard in _cards:
		card.settled = false
		card.visible = false
	_fx.power = 0.0
	visible = false


func is_open() -> bool:
	return _open


## A saída (cartas caindo, fundo sumindo) ainda está tocando.
func outro_playing() -> bool:
	return not _open and visible


func cards() -> Array[Button]:
	var list: Array[Button] = []
	for card: LevelCard in _cards:
		if card.visible:
			list.append(card)
	return list


func level_cards() -> Array[LevelCard]:
	return _cards.filter(func(c: LevelCard) -> bool: return c.visible)


func banish_mode() -> bool:
	return _banish_mode


func overlay() -> OverlayFx:
	return _fx


func action_buttons() -> Array[ActionButton]:
	return [_reroll, _skip, _banish]


func title_text() -> String:
	return tr("lvchest.level_title") % _level if _level > 0 else tr("levelup.title")


func subtitle_text() -> String:
	return tr("levelup.banish_hint") if _banish_mode else tr("levelup.title")


## Cor, categoria, marcas de nível, texto e sinergias de uma carta do LevelUpSystem.
## "combos" lista SEMPRE todas as sinergias do item (mesmo as que o jogador ainda não tem e sem
## depender da descoberta do Diário), cada uma {label, names, icons, ready}:
## - arma: a relíquia que a evolui ("Evolui com") e, se a evolução entra numa união, a arma base
##   parceira ("Une com");
## - relíquia: todas as armas base que ela evolui ("Evolui"; jade, pergaminho e máscara nō têm duas).
## `ready` acende o rodapé quando o jogador já tem a parte que falta.
static func card_info(card: Dictionary, game: HyakkiGame) -> Dictionary:
	var kind := String(card.get("kind", ""))
	var id := StringName(card.get("id", &""))
	var path := String(card.get("icon", ""))
	var combos: Array[Dictionary] = []
	var info := {"category": LevelCard.Cat.NEW, "element": RYO_GLOW, "max_level": 1, "text": String(card.get("text", "")),
			"icon": load(path) as Texture2D if not path.is_empty() and ResourceLoader.exists(path) else null,
			"combos": combos}
	match kind:
		"weapon_new", "weapon_up":
			var data := DB.weapon(id)
			info["max_level"] = (data.get("levels", [1]) as Array).size()
			info["element"] = element_color(data.get("tags", []))
			info["category"] = LevelCard.Cat.NEW if kind == "weapon_new" else LevelCard.Cat.UP
			var passive := StringName(data.get("evolves_with", ""))
			var evolution := StringName(data.get("evolution", ""))
			if passive != &"" and DB.passives.has(passive):
				var passive_name := TranslationServer.translate("passive.%s.name" % passive)
				combos.append(_combo(TranslationServer.translate("lvchest.evolves_with"), [passive_name],
						[_load(String(DB.passives[passive].get("icon", "")))],
						game != null and game.level_up.has_passive(passive)))
				# A linha "Evolui com: X" do texto vira o rodapé da carta.
				var line := TranslationServer.translate("levelup.evolves_with") % passive_name
				info["text"] = String(info["text"]).replace("\n" + line, "").replace(line, "").strip_edges()
			# A evolução entra numa união: a arma base parceira ("Une com"), acesa quando o jogador
			# já tem a evolução parceira.
			for partner: Array in union_partners(evolution):
				var base: StringName = partner[0]
				combos.append(_combo(TranslationServer.translate("lvchest.unites_with"),
						[TranslationServer.translate("weapon.%s.name" % base)],
						[_load(String(DB.weapon(base).get("icon", "")))], game != null and game.has_weapon(partner[1])))
			var owned_evolution := game != null and evolution != &"" and game.has_weapon(evolution)
			if kind == "weapon_up" and evolution != &"" and not owned_evolution \
					and int(card.get("level", 1)) >= int(info["max_level"]):
				info["category"] = LevelCard.Cat.LEGEND
		"passive":
			info["category"] = LevelCard.Cat.PASSIVE
			info["element"] = PASSIVE_GLOW
			if DB.passives.has(id):
				info["max_level"] = int(DB.passives[id].get("max", 5))
			var names: Array[String] = []
			var icons: Array[Texture2D] = []
			var ready := false
			for weapon_id: StringName in weapons_evolved_by(id):
				names.append(TranslationServer.translate("weapon.%s.name" % weapon_id))
				icons.append(_load(String(DB.weapon(weapon_id).get("icon", ""))))
				var owned: Weapon = game.get_weapon(weapon_id) if game != null else null
				ready = ready or (owned != null and owned.level >= owned.max_level)
			if not names.is_empty():
				combos.append(_combo(TranslationServer.translate("lvchest.evolves"), names, icons, ready))
		"heal":
			info["category"] = LevelCard.Cat.HEAL
			info["element"] = HEAL_GLOW
		"ryo":
			info["category"] = LevelCard.Cat.RYO
			info["element"] = RYO_GLOW
	return info


## Armas base (na ordem de data/weapons.json) que a relíquia `passive` evolui.
static func weapons_evolved_by(passive: StringName) -> Array[StringName]:
	var list: Array[StringName] = []
	for weapon_id: StringName in DB.ids("weapons"):
		var data := DB.weapon(weapon_id)
		if String(data.get("kind", "")) == "base" and StringName(data.get("evolves_with", "")) == passive:
			list.append(weapon_id)
	return list


## Parceiros de união da evolução `evolution`: [arma base parceira, evolução parceira, união] para
## cada arma "union" cujo "requires" traz `evolution`.
static func union_partners(evolution: StringName) -> Array[Array]:
	var list: Array[Array] = []
	if evolution == &"":
		return list
	for union_id: StringName in DB.ids("weapons"):
		var data := DB.weapon(union_id)
		var parts: Array = data.get("requires", [])
		if String(data.get("kind", "")) != "union" or not parts.has(String(evolution)):
			continue
		for part: Variant in parts:
			var other := StringName(part)
			if other == evolution:
				continue
			for base_id: StringName in DB.ids("weapons"):
				var base := DB.weapon(base_id)
				if String(base.get("kind", "")) == "base" and StringName(base.get("evolution", "")) == other:
					list.append([base_id, other, union_id])
	return list


static func _combo(label: String, names: Array[String], icons: Array[Texture2D], ready: bool) -> Dictionary:
	return {"label": label, "names": names, "icons": icons, "ready": ready}


static func element_color(tags: Variant) -> Color:
	for entry: Array in ELEMENTS:
		if (tags as Array).has(entry[0]):
			return entry[1]
	return Color(1.0, 0.85, 0.55)


static func _load(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


# --- Toque -------------------------------------------------------------------------------

func _accepting() -> bool:
	return _open and not _busy and Time.get_ticks_msec() - _opened_at >= CARD_LOCK_MS


func _on_card(index: int) -> void:
	var card := _cards[index]
	if not _accepting() or not card.settled:
		return
	if _banish_mode:
		_busy = true
		_set_banish(false)
		card.banish_mode = true
		var t := _tween()
		t.tween_property(card, "stamp", 1.0, STAMP_TIME)
		t.parallel().tween_callback(func() -> void:
			AudioManager.play("j_taiko_rim", 0.9, 0.0, -2.0)
			AudioManager.play("k_paper_place_0", 0.7)).set_delay(STAMP_TIME * 0.4)
		t.tween_interval(0.12)
		t.tween_callback(func() -> void:
			_busy = false
			banish_pressed.emit(index))
		return
	_choose(index)


## Escolha: o ícone da carta sai voando até a guardiã; as outras caem. O sinal sai antes da
## saída (o jogo aplica a escolha e decide se fecha a tela ou mostra o próximo nível).
func _choose(index: int) -> void:
	var card := _cards[index]
	_busy = true
	var item := {"from": card.get_global_transform_with_canvas() * card.icon_center(), "icon": card.icon_texture(),
			"color": card.element, "scale": card.icon_scale(), "key": slot_key(card.data)}
	AudioManager.play("magic1", 1.3, 0.0, -6.0)
	card_chosen.emit(index)
	var items: Array[Dictionary] = [item]
	claimed.emit(items)
	if _open:
		# O jogo ainda não fechou a tela: a queda das cartas espera o hide_panel.
		_chosen = index
		return
	_drop_cards(index)


## Saída da escolha: as outras cartas caem e a escolhida encolhe na luz.
func _drop_cards(index: int) -> void:
	for i: int in range(_cards.size()):
		var other := _cards[i]
		if not other.visible:
			continue
		var t := _tween()
		if i == index:
			t.tween_property(other, "scale", Vector2.ONE * 0.2, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			t.parallel().tween_property(other, "modulate", Color(2.0, 2.0, 1.6, 0.0), 0.18)
		else:
			var side := -1.0 if i < index else 1.0
			t.tween_property(other, "position:y", other.position.y + 90.0, DROP_TIME) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			t.parallel().tween_property(other, "rotation", 0.35 * side, DROP_TIME)
			t.parallel().tween_property(other, "modulate:a", 0.0, DROP_TIME)


## Encaixe da recompensa na barra da HUD ("w:<arma>" ou "p:<passiva>"; "" se não tiver ícone lá).
static func slot_key(reward: Dictionary) -> String:
	var id := String(reward.get("id", ""))
	match String(reward.get("kind", "")):
		"weapon_new", "weapon_up", "evolution", "union":
			return "w:" + id
		"passive":
			return "p:" + id
	return ""


## Pular: as cartas sobem e somem como papel ao vento.
func _play_skip() -> void:
	AudioManager.play("paper_flutter", 1.1, 0.05, -4.0)
	for card: LevelCard in _cards:
		if not card.visible:
			continue
		card.settled = false
		var t := _tween()
		t.tween_property(card, "position:y", card.position.y - 40.0, 0.25).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(card, "modulate:a", 0.0, 0.25)


func _set_banish(on: bool) -> void:
	_banish_mode = on
	if _banish:
		_banish.active = on
		_banish.queue_redraw()
	for card: LevelCard in _cards:
		card.banish_mode = on
	if _header:
		_header.queue_redraw()


# --- Entrada -----------------------------------------------------------------------------

## Cartas em leque: saem de baixo, giradas, e pousam uma a uma.
func _deal(delay: float) -> void:
	_deal_count += 1
	var visible_cards := level_cards()
	var n := visible_cards.size()
	var center := Vector2(size.x * 0.5, size.y + 30.0)
	for i: int in range(n):
		var card := visible_cards[i]
		var spread := float(i) - (n - 1) * 0.5
		card.position = center - card.size * 0.5 + Vector2(spread * 30.0, 0.0)
		card.rotation = spread * 0.32
		card.scale = Vector2.ONE * 0.7
		card.modulate.a = 0.0
		var t := _tween()
		var at := delay + DEAL_STEP * i
		t.tween_interval(at)
		t.tween_callback(func() -> void:
			AudioManager.play("paper_flutter", 0.95 + 0.07 * i, 0.03, -5.0))
		t.tween_property(card, "position", card.base_position, DEAL_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(card, "rotation", 0.0, DEAL_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(card, "scale", Vector2.ONE, DEAL_TIME).set_trans(Tween.TRANS_BACK) \
				.set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(card, "modulate:a", 1.0, DEAL_TIME * 0.4)
		t.tween_callback(func() -> void:
			card.settled = true
			AudioManager.play("paper_fold", 1.0 + 0.06 * i, 0.0, -6.0))
	_actions.modulate.a = 0.0
	var a := _tween()
	a.tween_interval(delay + DEAL_STEP * n)
	a.tween_property(_actions, "modulate:a", 1.0, 0.2)


func _tween() -> Tween:
	var t := create_tween()
	_tweens.append(t)
	return t


func _kill_tweens() -> void:
	for t: Tween in _tweens:
		if t.is_valid():
			t.kill()
	_tweens.clear()
	_actions.modulate.a = 1.0
	for card: LevelCard in _cards:
		card.rotation = 0.0
		card.scale = Vector2.ONE
		card.stamp = 0.0


# --- Layout ------------------------------------------------------------------------------

func _safe_insets() -> Vector2:
	return MenuKit.safe_insets(self)


func _layout() -> void:
	if _cards.is_empty():
		return
	var view := size
	var insets := _safe_insets()
	var left := MARGIN + insets.x
	var width := view.x - left - MARGIN - insets.y
	var visible_cards := level_cards()
	var n := maxi(visible_cards.size(), 1)
	var has_actions := _reroll.visible or _skip.visible or _banish.visible
	var bottom := (ACTIONS_H + 6.0) if has_actions else 0.0
	var avail := view.y - MARGIN * 2.0 - HEADER_H - bottom - 2.0
	var card_size := Vector2(clampf(floorf((width - GAP * (n - 1)) / n), CARD_MIN.x, CARD_MAX.x),
			clampf(avail, CARD_MIN.y, CARD_MAX.y))
	var total := card_size.x * n + GAP * (n - 1)
	var x0 := floorf(left + (width - total) * 0.5)
	var y0 := floorf(MARGIN + HEADER_H + maxf(0.0, (avail - card_size.y) * 0.5))
	for i: int in range(visible_cards.size()):
		var card := visible_cards[i]
		card.layout_content(card_size)
		card.base_position = Vector2(x0 + i * (card_size.x + GAP), y0)
		if card.settled:
			card.position = card.base_position
		card.fx_level = _fx_level
	_header.position = Vector2(0, MARGIN)
	_header.size = Vector2(view.x, HEADER_H)
	_actions.size = Vector2(view.x, ACTIONS_H)
	_actions.position = Vector2(0, view.y - MARGIN - ACTIONS_H)
	_fx.ray_origin = Vector2(view.x * 0.5, y0 + card_size.y * 0.4)


func _apply_quality() -> void:
	_fx_level = int(GfxQuality.budget("ui_fx"))
	if _fx:
		_fx.apply_quality()
	for card: LevelCard in _cards:
		card.fx_level = _fx_level


func fx_level() -> int:
	return _fx_level


func _action(glyph: String, on_press: Callable) -> ActionButton:
	var b := ActionButton.new()
	b.glyph = glyph
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, ACTIONS_H)
	var normal := _flat(Color(0.05, 0.04, 0.09, 0.92), Color(UiPaint.GOLD, 0.6))
	var hover := _flat(Color(0.1, 0.07, 0.14, 0.95), ThemeFactory.ACCENT)
	var pressed := _flat(Color(0.02, 0.015, 0.04, 0.95), ThemeFactory.ACCENT)
	for box: StyleBoxFlat in [normal, hover, pressed]:
		box.content_margin_left = 22.0
		box.content_margin_right = 20.0
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", UiPaint.PAPER)
	b.pressed.connect(on_press)
	b.pressed.connect(func() -> void: AudioManager.play_ui("ui_accept"))
	_actions.add_child(b)
	return b


func _set_action(b: ActionButton, label: String, count: int) -> void:
	b.text = label
	b.tooltip_text = label
	b.count = count
	b.visible = count > 0
	b.active = false
	b.queue_redraw()


static func _flat(bg: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	box.anti_aliasing = false
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	return box


# --- Desenho -----------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	_header.queue_redraw()
	if _banish_mode:
		_banish.queue_redraw()
	if not _open and _fx.power <= 0.0:
		visible = false
		for card: LevelCard in _cards:
			card.visible = false


func _draw_header() -> void:
	var w := _header.size.x
	var k := clampf(_intro, 0.0, 1.2)
	if k <= 0.0:
		return
	var alpha := clampf(k, 0.0, 1.0)
	var drop := (1.0 - minf(k, 1.0)) * -14.0
	var title := title_text()
	var title_w := UiPaint.text_width(title, 24)
	var seal_side := 20.0
	var total := title_w + seal_side + 6.0
	var x := floorf((w - total) * 0.5)
	var base := 22.0 + drop
	# Brilho atrás do título.
	if _fx_level >= 1:
		_header.draw_circle(Vector2(w * 0.5, 16.0 + drop), 46.0, Color(1.0, 0.8, 0.45, 0.06 * alpha))
	UiPaint.seal(_header, Vector2(x + seal_side * 0.5, base - 8.0), "昇", seal_side, UiPaint.SEAL_RED,
			UiPaint.SEAL_TEXT, -0.08, alpha)
	UiPaint.text(_header, Vector2(x + seal_side + 6.0, base), title, 24, Color(UiPaint.PAPER, alpha),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 4, Color(0.12, 0.03, 0.03))
	UiPaint.ornament(_header, Vector2(w * 0.5, 27.0 + drop), minf(w * 0.3, 110.0), alpha)
	var sub := subtitle_text()
	var color := Color("ff8a7a") if _banish_mode else UiPaint.DIM
	UiPaint.text(_header, Vector2(0, 40.0 + drop), sub, 12, Color(color, alpha), HORIZONTAL_ALIGNMENT_CENTER, w)
