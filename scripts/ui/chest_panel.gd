class_name ChestPanel
extends Control
## Tela do BAÚ LAQUEADO (plano 4.8), em sequência de cinema sobre a luta parada:
##  1. o mundo escurece; o baú (LacquerChest) cai do alto e amassa no chão com poeira;
##  2. treme cada vez mais forte, com a luz da raridade vazando pela fresta;
##  3. a tampa abre numa explosão de luz da cor da raridade (1 item = comum, prata-azulado;
##     3 = raro, violeta; 5 = lendário, ouro), com raios girando, clarão e moedas jorrando;
##  4. os itens sobem um a um girando e voam até os cartões de recompensa à direita, cada
##     pouso com uma nota do koto subindo (arpejo pentatônico) e um brilho no cartão;
##  5. o ryō ganho conta até o total embaixo do baú, e "Pular" vira "Continuar".
## "Pular" (ou tocar fora do botão) mostra tudo de uma vez a qualquer momento.
## GfxQuality: Baixa = mesma coreografia com poucas moedas/faíscas e sem efeito de tela cheia
## (sem desfoque, vinheta, clarão nem tremor de tela); Alta = completo. Troca ao vivo.
## A sequência anda por um relógio próprio (`_t`, tempo real): pular é só ir para o fim.

signal closed

const MARGIN := 8.0
const GAP := 10.0
## Linha do tempo (segundos).
const DROP := 0.34
const SETTLE := 0.18
const SHAKE := 0.95
const RISE := 0.38
const ITEM_STEP := 0.4
const ITEM_FLY := 0.52
const COUNT_TIME := 0.7
const TAIL := 0.3
const BUTTON_H := 26.0
const ROW_GAP := 3.0
const ROW_MIN := 30.0
const ROW_MAX := 60.0
const COINS := [12, 28, 56]
const GLINTS := [4, 10, 22]
const STAGE_RAYS := [6, 10, 16]
## Raridade pelo número de itens: [mínimo de itens, cor, kanji].
const RARITIES := [
	[5, Color("ffd166"), "極"],
	[3, Color("d29bff"), "珍"],
	[0, Color("9fd3ff"), "並"],
]
## Escala pentatônica (semitons) do arpejo dos itens.
const ARPEGGIO := [0, 2, 4, 7, 9, 12, 14, 16]


## Cartão de recompensa: ícone, nome, selo (Novo / Nv / Evolução) e efeito.
class RewardRow:
	extends Control
	var reward: Dictionary = {}
	var icon: Texture2D
	var accent: Color = UiPaint.GOLD
	var pill: String = ""
	var special: bool = false
	## 0 = vazio (encaixe esperando), 1 = item pousou.
	var shown: float = 0.0
	var flash: float = 0.0
	var icon_scale: int = 1
	var name_label: Label
	var effect: RichTextLabel
	var time: float = 0.0
	## Texto do efeito sem BBCode e se precisou ser encurtado com "…".
	var plain: String = ""
	var shortened: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		name_label = Label.new()
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.clip_text = true
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.add_theme_constant_override("line_spacing", -1)
		add_child(name_label)
		effect = RichTextLabel.new()
		effect.bbcode_enabled = true
		effect.scroll_active = false
		effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		effect.add_theme_constant_override("line_separation", -1)
		effect.add_theme_color_override("default_color", Color(0.86, 0.82, 0.78))
		add_child(effect)

	## Lado do ícone desenhado: o nativo (24 px) em escala inteira, mais a folga do halo.
	func icon_side() -> float:
		var native := 24.0 if icon == null else maxf(icon.get_width(), icon.get_height())
		return native * maxf(1.0, floorf(24.0 * icon_scale / native))

	func icon_box() -> float:
		return icon_side() + 6.0

	## Centro do ícone (alvo do voo), em coordenadas locais.
	func icon_center() -> Vector2:
		return Vector2(4.0 + icon_box() * 0.5, size.y * 0.5).floor()

	func layout_row(row_size: Vector2) -> void:
		size = row_size
		pivot_offset = row_size * 0.5
		icon_scale = 1
		var x := 4.0 + icon_box() + 6.0
		var pill_w := UiPaint.text_width(pill) + 10.0 if not pill.is_empty() else 0.0
		var lh := Locale.font.get_height(12) - 1.0
		# Nome que não cabe ao lado do selo (tela estreita com câmera, idioma longo) quebra
		# em duas linhas em vez de ganhar "…"; o efeito desce uma linha.
		var name_w := maxf(row_size.x - x - pill_w - 8.0, 10.0)
		var wrap := UiPaint.text_width(name_label.text) > name_w
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
		var name_h := lh * (2.0 if wrap else 1.0)
		effect.size = Vector2(maxf(row_size.x - x - 4.0, 10.0), row_size.y)
		var need := float(effect.get_content_height()) if not effect.get_parsed_text().is_empty() else 0.0
		var room := row_size.y - 3.0 - name_h
		var effect_h := minf(need, room)
		var top := maxf(1.0, floorf((row_size.y - name_h - effect_h) * 0.5))
		name_label.position = Vector2(x, top - 1.0)
		name_label.size = Vector2(name_w, name_h + 1.0)
		effect.position = Vector2(x - 1.0, top + name_h)
		effect.size = Vector2(effect.size.x, maxf(row_size.y - 1.0 - effect.position.y, 4.0))
		# Último recurso: corta o efeito em palavras e termina com "…".
		var words := plain.split(" ", false)
		effect.text = UiPaint.highlight_numbers(plain)
		shortened = false
		while words.size() > 1 and not effect_fits():
			words.resize(words.size() - 1)
			effect.text = UiPaint.highlight_numbers(" ".join(words).trim_suffix(",").trim_suffix(";") + "…")
			shortened = true

	## Linhas que o efeito precisa e as que cabem (testes de layout).
	func effect_fits() -> bool:
		if effect.get_parsed_text().is_empty():
			return true
		return effect.position.y + effect.get_content_height() <= size.y

	## Nome inteiro: numa linha, ou em até duas com cada palavra cabendo na largura.
	func name_fits() -> bool:
		var w := name_label.size.x + 0.5
		if UiPaint.text_width(name_label.text) <= w:
			return true
		if name_label.autowrap_mode == TextServer.AUTOWRAP_OFF or name_label.get_line_count() > 2 \
				or name_label.get_visible_line_count() < name_label.get_line_count():
			return false
		for word: String in name_label.text.split(" ", false):
			if UiPaint.text_width(word) > w:
				return false
		return true

	func _process(delta: float) -> void:
		time += delta
		if flash > 0.0:
			flash = maxf(0.0, flash - delta * 2.5)
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var k := clampf(shown, 0.0, 1.0)
		name_label.modulate.a = k
		effect.modulate.a = k
		if k <= 0.0:
			# Encaixe vazio: moldura tracejada esperando o item.
			draw_rect(r, Color(0, 0, 0, 0.25))
			for x: int in range(0, int(size.x), 6):
				draw_rect(Rect2(x, 0, 3, 1), Color(UiPaint.GOLD, 0.25))
				draw_rect(Rect2(x, size.y - 1.0, 3, 1), Color(UiPaint.GOLD, 0.25))
			var c := icon_center()
			draw_rect(Rect2(c - Vector2.ONE * icon_box() * 0.5, Vector2.ONE * icon_box()), Color(1, 1, 1, 0.05))
			return
		var top := Color(0.11, 0.07, 0.12, 0.95) if not special else Color(0.3, 0.2, 0.05, 0.96)
		UiPaint.vgradient(self, r, top, Color(0.03, 0.02, 0.05, 0.95))
		draw_rect(Rect2(0, 0, 3, size.y), accent)
		draw_rect(r, Color(0.05, 0.02, 0.02), false, 1.0)
		draw_rect(r.grow(-1.0), Color(accent, 0.6), false, 1.0)
		UiPaint.corners(self, r.grow(-1.0), Color(UiPaint.GOLD_HI, 0.8), 5.0)
		if special:
			var sweep := fmod(time * 0.7, 1.6) - 0.3
			var sx := sweep * size.x
			draw_colored_polygon(PackedVector2Array([Vector2(sx, 1), Vector2(sx + 10, 1), Vector2(sx - 4, size.y - 1),
					Vector2(sx - 14, size.y - 1)]), Color(1, 1, 0.8, 0.12))
		var c := icon_center()
		var box := icon_box()
		draw_circle(c, box * 0.5 + 1.0, Color(accent, 0.18))
		draw_arc(c, box * 0.5 + 1.0, 0.0, TAU, 32, Color(accent, 0.6), 1.0)
		if icon:
			var native := icon.get_size()
			var s := native * (icon_side() / maxf(native.x, native.y))
			draw_texture_rect(icon, Rect2((c - s * 0.5).floor(), s), false)
		if not pill.is_empty():
			var w := UiPaint.text_width(pill) + 8.0
			var p := Rect2(size.x - w - 5.0, name_label.position.y + 1.0, w, Locale.font.get_height(12) - 1.0)
			draw_rect(p, accent.darkened(0.55))
			draw_rect(p, accent, false, 1.0)
			UiPaint.text(self, Vector2(p.position.x + 4.0, p.position.y + 10.0), pill, 12, accent.lerp(Color.WHITE, 0.6),
					HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
		if flash > 0.0:
			draw_rect(r, Color(1, 1, 0.9, 0.5 * flash))
			draw_rect(r.grow(1.0 + 3.0 * (1.0 - flash)), Color(accent, flash), false, 1.0)


var _rewards: Array[Dictionary] = []
var _rows: Array[RewardRow] = []
var _ryo_total: int = 0
var _has_ryo: bool = false
var _rarity: Array = RARITIES[2]
var _items: int = 0
var _t: float = -1.0
var _busy: bool = false
var _fired: Dictionary = {}
var _fx_level: int = 2
var _calm: bool = false
var _rng := RandomNumberGenerator.new()
var _shake_screen: float = 0.0

var _fx: OverlayFx
var _stage: Control
var _chest: LacquerChest
var _burst: ChestBurst
var _list: Control
var _fly: Control
var _button: Button
var _stage_rect := Rect2()
var _chest_rest := Vector2.ZERO
## Moedas e faíscas: posição, velocidade e (vida, giro).
var _coins: Array[Dictionary] = []
var _glints: Array[Dictionary] = []
## Itens voando: índice da linha e o progresso (0..1).
var _flying: Array[Dictionary] = []
var _ryo_shown: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_rng.seed = 41
	_fx = OverlayFx.new()
	add_child(_fx)
	_stage = Control.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.draw.connect(_draw_stage)
	add_child(_stage)
	_chest = LacquerChest.new()
	_stage.add_child(_chest)
	_burst = ChestBurst.new()
	_chest.add_child(_burst)
	_list = Control.new()
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_list)
	_button = Button.new()
	_button.focus_mode = Control.FOCUS_NONE
	_button.pressed.connect(_on_button)
	_button.pressed.connect(func() -> void: AudioManager.play_ui("ui_accept"))
	add_child(_button)
	_fly = Control.new()
	_fly.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fly.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fly.draw.connect(_draw_fly)
	add_child(_fly)
	resized.connect(_layout)
	# Furo da câmera que troca de lado com a tela aberta (giro de 180°).
	MenuKit.on_insets_change(self, _layout)
	Settings.changed.connect(func(key: String) -> void:
		if key == GfxQuality.changed_signal_key():
			_apply_quality())
	_apply_quality()


# --- API ---------------------------------------------------------------------------------

func show_chest(rewards: Array[Dictionary]) -> void:
	cancel()
	_rewards = rewards
	_calm = bool(Settings.get_value("reduce_flashes"))
	_apply_quality()
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_rows.clear()
	_has_ryo = false
	_ryo_total = 0
	_items = 0
	for reward: Dictionary in rewards:
		if String(reward.get("kind", "")) == "ryo":
			_has_ryo = true
			_ryo_total += _ryo_amount(reward)
			continue
		_items += 1
		var row := RewardRow.new()
		_fill_row(row, reward)
		_list.add_child(row)
		_rows.append(row)
	for entry: Array in RARITIES:
		if _items >= int(entry[0]):
			_rarity = entry
			break
	_chest.glow = rarity_color()
	_chest.lid = 0.0
	_chest.crack = 0.0
	_chest.squash = Vector2.ONE
	_chest.shake = Vector2.ZERO
	_chest.modulate = Color.WHITE
	_burst.color = rarity_color()
	_ryo_shown = 0
	_fx.ray_color = rarity_color()
	_fx.power = 0.0
	_fx.rays = 0.0
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_button.text = tr("chest.skip")
	_style_button(false)
	_layout()
	_busy = true
	_t = 0.0
	_fired.clear()
	set_process(true)


## Para tudo (fechar no meio, bot, nova partida) e esconde.
func cancel() -> void:
	_busy = false
	_t = -1.0
	_burst.stop()
	_coins.clear()
	_glints.clear()
	_flying.clear()
	visible = false


## Pular: vai para o fim da sequência e mostra tudo de uma vez.
func skip() -> void:
	if not _busy:
		return
	_t = end_time()
	_settle()


func is_open() -> bool:
	return visible


func animating() -> bool:
	return _busy


func burst_active() -> bool:
	return _burst.active()


func lines_shown() -> int:
	var shown := 0
	for row: RewardRow in _rows:
		if row.shown >= 1.0:
			shown += 1
	if _has_ryo and not _busy:
		shown += 1
	return shown


func lines_total() -> int:
	return _rows.size() + (1 if _has_ryo else 0)


func rows() -> Array[RewardRow]:
	return _rows


func chest() -> LacquerChest:
	return _chest


func burst() -> ChestBurst:
	return _burst


func overlay() -> OverlayFx:
	return _fx


func button() -> Button:
	return _button


func rarity_color() -> Color:
	return _rarity[1]


func rarity_name() -> String:
	if _items >= 5:
		return tr("lvchest.rarity_legendary")
	if _items >= 3:
		return tr("lvchest.rarity_rare")
	return tr("lvchest.rarity_common")


func ryo_shown() -> int:
	return _ryo_shown


func ryo_total() -> int:
	return _ryo_total


func coin_count() -> int:
	return _coins.size()


func fx_level() -> int:
	return _fx_level


## Retângulo do palco (baú, título, ryō e botão) e o da lista, para os testes de layout.
func stage_rect() -> Rect2:
	return _stage_rect


func open_time() -> float:
	return DROP + SETTLE + SHAKE


func item_time(i: int) -> float:
	return open_time() + RISE + ITEM_STEP * i


func end_time() -> float:
	var last := item_time(maxi(_rows.size() - 1, 0)) + ITEM_FLY
	return maxf(last, open_time() + COUNT_TIME) + TAIL


static func _ryo_amount(reward: Dictionary) -> int:
	if reward.has("amount"):
		return int(reward["amount"])
	var digits := RegEx.create_from_string("\\d+").search(String(reward.get("title", "")))
	return int(digits.get_string()) if digits != null else 0


func _fill_row(row: RewardRow, reward: Dictionary) -> void:
	row.reward = reward
	var path := String(reward.get("icon", ""))
	row.icon = load(path) as Texture2D if not path.is_empty() and ResourceLoader.exists(path) else null
	row.name_label.text = String(reward.get("title", ""))
	var kind := String(reward.get("kind", ""))
	var text := String(reward.get("text", ""))
	row.special = kind in ["evolution", "union"]
	match kind:
		"evolution", "union":
			row.accent = Color("ffd166")
			row.pill = text
			var desc_key := "weapon.%s.desc" % reward.get("id", "")
			text = tr(desc_key) if tr(desc_key) != desc_key else ""
		"weapon_new", "weapon_up", "passive":
			var lv := int(reward.get("level", 1))
			row.pill = tr("lvchest.new") if lv <= 1 else tr("lvchest.level_short") % lv
			row.accent = Color("ff7a52") if kind == "weapon_new" else (Color("6fe0b0") if kind == "passive" else Color("8fb0ff"))
			text = LevelUpPanel.card_info(reward, null)["text"]
		_:
			row.accent = UiPaint.GOLD
			row.pill = String(reward.get("tag", ""))
	row.name_label.add_theme_color_override("font_color", row.accent.lerp(Color.WHITE, 0.55))
	row.plain = text.replace("\n", " ")
	row.effect.text = UiPaint.highlight_numbers(row.plain)
	row.shown = 0.0


# --- Linha do tempo ----------------------------------------------------------------------

func _process(delta: float) -> void:
	if not visible:
		return
	if _busy:
		_t += delta
		_run_timeline()
		if _t >= end_time():
			_settle()
	_update_particles(delta)
	_stage.queue_redraw()
	_fly.queue_redraw()


## Dispara cada evento uma vez, quando o relógio passa por ele.
func _once(key: String, at: float) -> bool:
	if _t < at or _fired.has(key):
		return false
	_fired[key] = true
	return true


func _run_timeline() -> void:
	_fx.power = clampf(_t / 0.25, 0.0, 1.0)
	# 1. Queda e amassado.
	var land := DROP
	if _t < land:
		var k := _t / DROP
		_chest.position = _chest_rest - Vector2(0, (1.0 - k * k) * (_chest_rest.y + _chest.size.y + 10.0))
		_chest.squash = Vector2(0.92, 1.1)
	else:
		_chest.position = _chest_rest
		var s := clampf((_t - land) / SETTLE, 0.0, 1.0)
		var bounce := sin(s * PI) * (1.0 - s)
		_chest.squash = Vector2(1.0 + 0.22 * bounce, 1.0 - 0.25 * bounce)
	if _once("whoosh", 0.02):
		AudioManager.play("whoosh", 0.8, 0.0, -10.0)
	if _once("land", land):
		AudioManager.play("k_wood_0", 0.6, 0.0, -2.0)
		AudioManager.play("impact", 0.8, 0.0, -8.0)
		_dust()
		_screen_kick(2.0)
	# 2. Tremor crescente com a luz vazando.
	var t_open := open_time()
	var shake_from := land + SETTLE
	if _t >= shake_from and _t < t_open:
		var k := (_t - shake_from) / SHAKE
		var amp := lerpf(0.5, 3.0, k * k)
		_chest.shake = Vector2(sin(_t * 70.0) * amp, -absf(sin(_t * 41.0)) * amp * 0.6)
		_chest.crack = k
		_fx.rays = k * 0.4
		var beat := int(floorf(pow(k, 0.7) * 12.0))
		if _once("rattle%d" % beat, _t):
			AudioManager.play("k_wood_1", 1.2 + 0.05 * beat, 0.04, -12.0 + beat * 0.4)
	# 3. Abertura.
	if _once("open", t_open):
		_open_chest()
	if _t >= t_open:
		var k := clampf((_t - t_open) / 0.22, 0.0, 1.0)
		_chest.lid = 1.0 - pow(1.0 - k, 3.0)
		_chest.shake = Vector2.ZERO
		_chest.crack = 0.0
		_fx.rays = 1.0
		var c := clampf((_t - t_open) / COUNT_TIME, 0.0, 1.0)
		var shown := roundi(_ryo_total * (1.0 - pow(1.0 - c, 2.0)))
		if shown != _ryo_shown and _once("tick%d" % roundi(c * 10.0), _t):
			AudioManager.play("coin", 1.5 + c * 0.4, 0.0, -14.0)
		_ryo_shown = shown
	# 4. Itens, um a um.
	for i: int in range(_rows.size()):
		var at := item_time(i)
		if _once("item%d" % i, at):
			_flying.append({"row": i, "k": 0.0})
			AudioManager.play("whoosh", 1.3 + 0.08 * i, 0.0, -12.0)
		if _once("land%d" % i, at + ITEM_FLY):
			_land(i)


func _open_chest() -> void:
	_burst.zoom = 1.0 if _items >= 5 else (0.85 if _items >= 3 else 0.7)
	_burst.play(_chest.mouth())
	if _fx_level >= 1:
		_fx.flash_color = rarity_color()
		_fx.flash = 0.6 if _items >= 5 else 0.4
	_screen_kick(4.0 if _items >= 5 else 3.0)
	AudioManager.play("chest_open")
	AudioManager.play("magic1", 1.0, 0.0, -8.0)
	if _items >= 5:
		AudioManager.play("j_gong", 1.0, 0.0, -4.0)
		AudioManager.play("j_temple_bell", 1.0, 0.0, -2.0)
	elif _items >= 3:
		AudioManager.play("bell", 1.0, 0.0, -6.0)
	var count := int(COINS[_fx_level] * (1.0 + 0.4 * (_items - 1) / 4.0))
	count = mini(count, int(GfxQuality.budget("particles_max")) / 10)
	var mouth := _chest_global_mouth()
	for i: int in range(count):
		_coins.append({"p": mouth + Vector2(_rng.randf_range(-20.0, 20.0), 0.0),
				"v": Vector2(_rng.randf_range(-130.0, 130.0), _rng.randf_range(-250.0, -120.0)),
				"life": 0.0, "spin": _rng.randf() * TAU, "bounced": false})
	AudioManager.play("coin", 1.2, 0.0, -8.0)


func _land(i: int) -> void:
	var row := _rows[i]
	row.shown = 1.0
	row.flash = 1.0
	var punch := create_tween()
	row.scale = Vector2.ONE * 1.06
	punch.tween_property(row, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var note: int = ARPEGGIO[mini(i, ARPEGGIO.size() - 1)]
	AudioManager.play("j_koto", pow(2.0, note / 12.0), 0.0, -2.0)
	AudioManager.play("coin", pow(1.12, i), 0.0, -10.0)
	if row.special:
		AudioManager.play("powerup")
		AudioManager.play("j_temple_bell", 1.0, 0.0, -2.0)
	for f: int in range(_flying.size() - 1, -1, -1):
		if int(_flying[f]["row"]) == i:
			_flying.remove_at(f)
	# Faíscas no pouso.
	var c := row.get_global_transform_with_canvas() * row.icon_center()
	for k: int in range([2, 5, 9][_fx_level]):
		_glints.append({"p": c, "v": Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(20.0, 60.0),
				"life": 0.0, "color": row.accent})


## Estado final: tudo no lugar, ryō completo, botão "Continuar". Fim natural e pular.
func _settle() -> void:
	var was_busy := _busy
	_busy = false
	_t = end_time()
	_fired["open"] = true
	_burst.stop()
	_flying.clear()
	_chest.position = _chest_rest
	_chest.squash = Vector2.ONE
	_chest.shake = Vector2.ZERO
	_chest.crack = 0.0
	_chest.lid = 1.0
	_fx.power = 1.0
	_fx.rays = 1.0
	_ryo_shown = _ryo_total
	for row: RewardRow in _rows:
		row.shown = 1.0
	_button.text = tr("chest.close")
	_style_button(true)
	if was_busy:
		AudioManager.play("jingle_chest_big" if _items >= 3 else "jingle_success")


func _on_button() -> void:
	if _busy:
		skip()
		return
	cancel()
	closed.emit()


func _gui_input(event: InputEvent) -> void:
	var tap := event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			or event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed
	if tap and _busy:
		skip()
		accept_event()


func _screen_kick(amount: float) -> void:
	if _fx_level >= 1 and not _calm:
		_shake_screen = maxf(_shake_screen, amount)


func _dust() -> void:
	var base := _chest_global_mouth() + Vector2(0, _chest.size.y - _chest.mouth().y)
	for i: int in range([4, 8, 14][_fx_level]):
		var side := -1.0 if i % 2 == 0 else 1.0
		_glints.append({"p": base + Vector2(side * _chest.size.x * 0.4, -2.0),
				"v": Vector2(side * _rng.randf_range(20.0, 60.0), _rng.randf_range(-20.0, -5.0)),
				"life": 0.0, "color": Color(0.75, 0.68, 0.6), "dust": true})


func _chest_global_mouth() -> Vector2:
	return _chest_rest + _chest.mouth() + _stage.position


func _update_particles(delta: float) -> void:
	if _shake_screen > 0.0:
		_shake_screen = maxf(0.0, _shake_screen - delta * 14.0)
		_stage.position = _stage_rect.position + Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * _shake_screen
	else:
		_stage.position = _stage_rect.position
	var floor_base := _chest_rest.y + _chest.size.y + _stage_rect.position.y
	for i: int in range(_coins.size() - 1, -1, -1):
		var c := _coins[i]
		var v: Vector2 = c["v"]
		v.y += 520.0 * delta
		var p: Vector2 = c["p"] + v * delta
		var floor_y := floor_base + 2.0 + float(i % 7) * 1.5
		if p.y > floor_y and v.y > 0.0:
			if not bool(c["bounced"]):
				v = Vector2(v.x * 0.5, -v.y * 0.35)
				c["bounced"] = true
			p.y = floor_y
			v.x *= 0.9
		c["v"] = v
		c["p"] = p
		c["life"] = float(c["life"]) + delta
		c["spin"] = float(c["spin"]) + delta * 14.0
		if float(c["life"]) > 1.6:
			_coins.remove_at(i)
	# Faíscas subindo da boca aberta enquanto o baú brilha.
	if _t >= open_time() and _glints.size() < GLINTS[_fx_level] and _rng.randf() < 0.6:
		var m := _chest_global_mouth()
		_glints.append({"p": m + Vector2(_rng.randf_range(-30.0, 30.0), 0.0),
				"v": Vector2(_rng.randf_range(-8.0, 8.0), _rng.randf_range(-40.0, -18.0)), "life": 0.0,
				"color": rarity_color().lerp(Color.WHITE, 0.4)})
	for i: int in range(_glints.size() - 1, -1, -1):
		var g := _glints[i]
		g["p"] = (g["p"] as Vector2) + (g["v"] as Vector2) * delta
		g["life"] = float(g["life"]) + delta
		if float(g["life"]) > (0.5 if g.has("dust") else 1.1):
			_glints.remove_at(i)
	for f: Dictionary in _flying:
		f["k"] = clampf(float(f["k"]) + delta / ITEM_FLY, 0.0, 1.0)


# --- Layout ------------------------------------------------------------------------------

func _layout() -> void:
	var view := size
	var insets := MenuKit.safe_insets(self)
	var left := MARGIN + insets.x
	var stage_w := clampf(roundf(view.x * 0.4), 172.0, 290.0) if view.x >= 560.0 else 172.0
	_stage_rect = Rect2(left, MARGIN, stage_w, view.y - MARGIN * 2.0)
	_stage.position = _stage_rect.position
	_stage.size = _stage_rect.size
	_chest.px = 3 if view.y >= 250.0 else 2
	# Título (26) + raridade (16) em cima; ryō (20) e botão embaixo; o baú no meio.
	var top := 46.0
	var bottom := BUTTON_H + 34.0
	var chest_h := _chest.size.y
	var room := _stage_rect.size.y - top - bottom
	_chest_rest = Vector2(floorf((stage_w - _chest.size.x) * 0.5),
			floorf(top + maxf(room - chest_h, 0.0) * 0.72))
	_chest.position = _chest_rest
	_button.size = Vector2(minf(stage_w - 20.0, 200.0), BUTTON_H)
	_button.position = Vector2(_stage_rect.position.x + floorf((stage_w - _button.size.x) * 0.5),
			_stage_rect.end.y - BUTTON_H)
	var list_x := _stage_rect.end.x + GAP
	var list_w := view.x - list_x - MARGIN - insets.y
	var n := maxi(_rows.size(), 1)
	var row_h := clampf(floorf((_stage_rect.size.y - ROW_GAP * (n - 1)) / n), ROW_MIN, ROW_MAX)
	var total := row_h * n + ROW_GAP * (n - 1)
	_list.position = Vector2(list_x, floorf(MARGIN + (_stage_rect.size.y - total) * 0.5))
	_list.size = Vector2(list_w, total)
	for i: int in range(_rows.size()):
		_rows[i].position = Vector2(0, i * (row_h + ROW_GAP))
		_rows[i].layout_row(Vector2(list_w, row_h))
	_fx.ray_origin = _chest_global_mouth()


func _apply_quality() -> void:
	_fx_level = int(GfxQuality.budget("ui_fx"))
	if _fx:
		_fx.apply_quality()


func _style_button(done: bool) -> void:
	var bg := UiPaint.VERMILION if done else Color(0.05, 0.04, 0.09, 0.9)
	var border := ThemeFactory.ACCENT if done else Color(UiPaint.GOLD, 0.55)
	var normal := LevelUpPanel._flat(bg, border)
	var hover := LevelUpPanel._flat(bg.lightened(0.12), Color.WHITE)
	var pressed := LevelUpPanel._flat(bg.darkened(0.25), ThemeFactory.ACCENT)
	if done:
		for box: StyleBoxFlat in [normal, hover, pressed]:
			box.set_border_width_all(2)
			box.shadow_color = Color(ThemeFactory.ACCENT, 0.28)
			box.shadow_size = 3
	_button.add_theme_stylebox_override("normal", normal)
	_button.add_theme_stylebox_override("hover", hover)
	_button.add_theme_stylebox_override("pressed", pressed)
	_button.add_theme_stylebox_override("hover_pressed", pressed)
	_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_button.add_theme_color_override("font_color", UiPaint.PAPER if done else UiPaint.DIM)


# --- Desenho -----------------------------------------------------------------------------

func _draw_stage() -> void:
	var w := _stage.size.x
	var color := rarity_color()
	var a := _fx.power
	# Título e raridade.
	var title := tr("chest.title")
	var big := UiPaint.text_width(title, 24) <= w - 8.0
	UiPaint.text(_stage, Vector2(0, 22.0 if big else 16.0), title, 24 if big else 12, Color(UiPaint.PAPER, a),
			HORIZONTAL_ALIGNMENT_CENTER, w, 4 if big else 3, Color(0.12, 0.03, 0.03))
	var opened := _t >= open_time() or not _busy
	var rarity := rarity_name()
	var rw := UiPaint.text_width(rarity) + 20.0
	var rx := floorf((w - rw) * 0.5)
	if opened:
		UiPaint.seal(_stage, Vector2(rx + 6.0, 35.0), String(_rarity[2]), 13.0, UiPaint.SEAL_RED, UiPaint.SEAL_TEXT, -0.1, a)
		UiPaint.text(_stage, Vector2(rx + 16.0, 40.0), rarity, 12, Color(color, a))
	else:
		UiPaint.ornament(_stage, Vector2(w * 0.5, 34.0), minf(w * 0.3, 70.0), a)
	var mouth := _chest_rest + _chest.mouth()
	# Sombra no chão.
	var floor_c := _chest_rest + Vector2(_chest.size.x * 0.5, _chest.size.y + 1.0)
	var fall := clampf(_t / DROP, 0.0, 1.0) if _busy else 1.0
	_stage.draw_set_transform(floor_c, 0.0, Vector2(1.0, 0.25))
	_stage.draw_circle(Vector2.ZERO, _chest.size.x * 0.55 * fall, Color(0, 0, 0, 0.45 * a))
	_stage.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Aura e raios girando atrás do baú aberto (ou vazando antes de abrir).
	var glow := 1.0 if opened else _chest.crack * 0.5
	if glow > 0.0:
		var count: int = STAGE_RAYS[_fx_level]
		var spin := _time() * (0.6 if _fx_level > 0 else 0.0)
		var reach := minf(w * 0.6, 150.0)
		for i: int in range(count):
			var ang := -PI * 0.5 + spin + TAU * i / count
			var width := 0.09 + 0.04 * sin(i * 1.9)
			var tip := mouth
			_stage.draw_polygon(PackedVector2Array([tip, tip + Vector2.from_angle(ang - width) * reach,
					tip + Vector2.from_angle(ang + width) * reach]),
					PackedColorArray([Color(color, 0.32 * glow), Color(color, 0.0), Color(color, 0.0)]))
		_stage.draw_circle(mouth, 34.0, Color(color, 0.1 * glow))
		_stage.draw_circle(mouth, 20.0, Color(color.lerp(Color.WHITE, 0.4), 0.14 * glow))
		# Coluna de luz subindo da boca.
		if opened:
			var col_w := _chest.size.x * 0.7
			var col_h := mouth.y - 4.0
			UiPaint.vgradient(_stage, Rect2(mouth.x - col_w * 0.5, mouth.y - col_h, col_w, col_h),
					Color(color, 0.0), Color(color.lerp(Color.WHITE, 0.3), 0.22))
	# Ryō ganho, contando.
	if _has_ryo:
		var label := tr("chest.ryo") % _ryo_shown
		var size_px := 24 if UiPaint.text_width(tr("chest.ryo") % 999, 24) + 18.0 <= w else 12
		var y := _stage.size.y - BUTTON_H - (7.0 if size_px == 24 else 8.0)
		var lw := UiPaint.text_width(label, size_px) + 16.0
		var x := floorf((w - lw) * 0.5)
		UiPaint.glyph(_stage, "coin", Vector2(x, y - (15.0 if size_px == 24 else 10.0)), Color.WHITE)
		var done := _ryo_shown >= _ryo_total and opened
		UiPaint.text(_stage, Vector2(x + 16.0, y), label, size_px, Color(ThemeFactory.ACCENT if done else UiPaint.DIM, a),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 4 if size_px == 24 else 3)


func _time() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


func _draw_fly() -> void:
	# Moedas de ouro girando (largura pulsa com o giro) e faíscas.
	for c: Dictionary in _coins:
		var p: Vector2 = (c["p"] as Vector2).floor()
		var fade := 1.0 - clampf((float(c["life"]) - 1.2) / 0.4, 0.0, 1.0)
		var turn := cos(float(c["spin"]))
		var w := maxf(1.0, roundf(absf(turn) * 4.0))
		var face := Color("f4c542") if turn > 0.0 else Color("c98a1c")
		_fly.draw_rect(Rect2(p.x - floorf(w * 0.5), p.y - 2.0, w, 4.0), Color(Color("6b3f0a"), fade))
		_fly.draw_rect(Rect2(p.x - floorf(w * 0.5), p.y - 2.0, w, 3.0), Color(face, fade))
		if w >= 3.0:
			_fly.draw_rect(Rect2(p.x - 1.0, p.y - 2.0, 1, 1), Color(1, 1, 0.85, fade))
	for g: Dictionary in _glints:
		var life := float(g["life"])
		var p: Vector2 = (g["p"] as Vector2).floor()
		var col: Color = g["color"]
		if g.has("dust"):
			_fly.draw_circle(p, 2.0 + life * 8.0, Color(col, 0.35 * (1.0 - life / 0.5)))
			continue
		var a := sin(clampf(life / 1.1, 0.0, 1.0) * PI)
		_fly.draw_rect(Rect2(p, Vector2.ONE), Color(col, a))
		if _fx_level >= 2 and int(p.x) % 3 == 0:
			_fly.draw_rect(Rect2(p + Vector2(-1, 0), Vector2(3, 1)), Color(col, a * 0.5))
			_fly.draw_rect(Rect2(p + Vector2(0, -1), Vector2(1, 3)), Color(col, a * 0.5))
	for f: Dictionary in _flying:
		_draw_flyer(f)


## Item saindo do baú: sobe girando na luz e faz um arco até o cartão.
func _draw_flyer(f: Dictionary) -> void:
	var row := _rows[int(f["row"])]
	var k := float(f["k"])
	var from := _chest_global_mouth()
	var to := row.get_global_transform_with_canvas() * row.icon_center()
	var peak := from + Vector2(0, -42.0)
	var at: Vector2
	if k < 0.35:
		at = from.lerp(peak, sin(k / 0.35 * PI * 0.5))
	else:
		var e := (k - 0.35) / 0.65
		e = e * e * (3.0 - 2.0 * e)
		at = peak.lerp(to, e) - Vector2(0, sin(e * PI) * 18.0)
	var color := row.accent
	var spin := cos(k * TAU * 2.0)
	if _fx_level >= 1:
		for j: int in range(6):
			var back := clampf(k - j * 0.03, 0.0, 1.0)
			var trail := from.lerp(to, back) if back > 0.35 else from.lerp(peak, back / 0.35)
			_fly.draw_rect(Rect2(trail.floor(), Vector2.ONE * 2.0), Color(color.lerp(Color.WHITE, 0.4), 0.5 - j * 0.08))
	_fly.draw_circle(at, 12.0, Color(color, 0.22))
	_fly.draw_circle(at, 6.0, Color(1, 1, 0.9, 0.35))
	if row.icon:
		var native := row.icon.get_size()
		var s := native * (row.icon_side() / maxf(native.x, native.y))
		var w := maxf(absf(spin) * s.x, 2.0)
		_fly.draw_texture_rect(row.icon, Rect2(Vector2(at.x - w * 0.5, at.y - s.y * 0.5).floor(), Vector2(w, s.y).floor()),
				false, Color(1.3, 1.3, 1.2) if spin < 0.0 else Color.WHITE)
