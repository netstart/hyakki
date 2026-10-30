class_name ChestPanel
extends Control
## Tela do BAÚ LAQUEADO (plano 4.8), em sequência de cinema sobre a luta parada:
##  0. OMIKUJI (おみくじ, Omikuji): o tubo hexagonal de madeira cai, chacoalha, a vareta salta
##     pelo furo e o papel desenrola com a sorte em kanji grande e a leitura no idioma:
##     吉 = 1 item, 中吉 = 3, 大吉 = 5 (chuva de moedas, clarão dourado e o gongo). A sorte só
##     APRESENTA a contagem que o ChestSystem já sorteou. No 凶 (má sorte, ainda com o item e um
##     consolo em ryō) o papel voa e fica amarrado num galho, como nos templos. Nos outros, o
##     papel encolhe até virar o selo da sorte embaixo do título;
##  1. o mundo escurece; o baú (LacquerChest) cai do alto e amassa no chão com poeira;
##  2. treme cada vez mais forte, com a luz da raridade vazando pela fresta;
##  3. a tampa abre numa explosão de luz da cor da raridade (1 item = comum, prata-azulado;
##     3 = raro, violeta; 5 = lendário, ouro), com raios girando, clarão e moedas jorrando;
##  4. ROLETA: na janela sobre o baú, ícones giram na vertical para cada item, desaceleram com
##     estalos e param no item de verdade (evolução e união: giro mais longo, parada com
##     ressalto, brilho e sino); dali o item voa até o seu cartão à direita, cada pouso com uma
##     nota do koto subindo (arpejo pentatônico) e um brilho no cartão;
##  5. o ryō ganho conta até o total embaixo do baú, e "Pular" vira "Continuar";
##  6. no "Continuar", o ícone de cada item (e o saco de ryō) sai do cartão e voa até a guardiã
##     (`claimed` -> RewardFlight da HUD) enquanto a luta já volta.
## "Pular" (ou tocar fora do botão) mostra tudo de uma vez a qualquer momento. A opção "Animação
## curta do baú" (Settings.chest_short) passa a sequência inteira no dobro da velocidade.
## "Reduzir flashes": sem o clarão dourado do 大吉 e sem tremor de tela.
## Tudo o que é novo e redesenhado a cada quadro (tubo, papel, galho, roleta) é retângulo,
## círculo, textura ou texto, sem draw_polygon/draw_arc; o tubo gira por draw_set_transform.
## GfxQuality: Baixa = mesma coreografia com poucas moedas/faíscas e sem efeito de tela cheia
## (sem desfoque, vinheta, clarão nem tremor de tela); Alta = completo. Troca ao vivo.
## A sequência anda por um relógio próprio (`_t`, tempo real): pular é só ir para o fim.

signal closed
## Os ícones ganhos, prontos para o voo até a guardiã (ver RewardFlight.launch).
signal claimed(items: Array[Dictionary])

const MARGIN := 8.0
const GAP := 10.0
## Linha do tempo (segundos).
const DROP := 0.34
const SETTLE := 0.18
const SHAKE := 0.6
## Omikuji (antes do baú): tubo caindo, chacoalhando, vareta saltando, papel desenrolando,
## leitura e saída (selo ou galho).
const OMI_IN := 0.22
const OMI_SHAKE := 0.45
const OMI_POP := 0.14
const OMI_UNROLL := 0.3
const OMI_HOLD := 0.5
const OMI_OUT := 0.3
## Roleta: giro do 1º item, dos seguintes e o extra das evoluções/uniões.
const REEL_FIRST := 0.9
const REEL_NEXT := 0.5
const REEL_SPECIAL := 0.3
## Altura de cada ícone na fita da roleta (e lado da janela).
const REEL_CELL := 30.0
## Ícones de enchimento antes do item (1º giro, seguintes, extra das especiais).
const REEL_SPINS := [7, 4, 3]
## Ritmo da animação curta (Settings.chest_short).
const SHORT_PACE := 2.0
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


## Cartão de recompensa (ícone, nome, selo e efeito): scripts/ui/chest_reward_row.gd.
const RewardRow := preload("res://scripts/ui/chest_reward_row.gd")


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
## Omikuji: a sorte mostrada, o ritmo (1 ou SHORT_PACE) e as peças no palco.
var _fortune: StringName = Omikuji.KICHI
var _pace: float = 1.0
var _reel: Control
var _tube_base := Vector2.ZERO
var _slip_rect := Rect2()
var _reel_rect := Rect2()
var _branch_rect := Rect2()
## Fita de cada cartão na roleta: ícones de enchimento e o item no fim.
var _strips: Array = []
var _pool: Array[Texture2D] = []
var _reel_row: int = -1
var _reel_index: int = -1
var _reel_flash: float = 0.0
## Contadores para os testes: estalos da roleta, clarões dourados e chuvas de moedas.
var _ticks: int = 0
var _gold_flashes: int = 0
var _coin_rains: int = 0


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
	# Janela da roleta: recorta a fita de ícones (clip_contents) e fica na frente do baú.
	_reel = Control.new()
	_reel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reel.clip_contents = true
	_reel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_reel.draw.connect(_draw_reel)
	_stage.add_child(_reel)
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

## `fortune`: a sorte do omikuji (Omikuji.KICHI...); vazia = a sorte da contagem de itens.
func show_chest(rewards: Array[Dictionary], fortune: StringName = &"") -> void:
	cancel()
	_rewards = rewards
	_calm = bool(Settings.get_value("reduce_flashes"))
	_pace = SHORT_PACE if bool(Settings.get_value("chest_short")) else 1.0
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
	_fortune = fortune if Omikuji.is_valid(fortune) else Omikuji.fortune_of_count(_items)
	_build_strips()
	_reel_row = -1
	_reel_index = -1
	_reel_flash = 0.0
	_ticks = 0
	_gold_flashes = 0
	_coin_rains = 0
	_chest.visible = false
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
	_reel_row = -1
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


## Linha do tempo do omikuji (segundos da sequência, antes do ritmo).
func pop_time() -> float:
	return OMI_IN + OMI_SHAKE


func unroll_time() -> float:
	return pop_time() + OMI_POP


## Papel aberto: a sorte fica legível (clarão e chuva de moedas do 大吉).
func reveal_time() -> float:
	return unroll_time() + OMI_UNROLL


func fold_time() -> float:
	return reveal_time() + OMI_HOLD


## Fim do omikuji: o papel virou selo (ou está amarrado no galho) e o baú começa a cair.
func omikuji_time() -> float:
	return fold_time() + OMI_OUT


func open_time() -> float:
	return omikuji_time() + DROP + SETTLE + SHAKE


## Duração do giro da roleta do cartão `i` (evolução e união giram mais).
func reel_time(i: int) -> float:
	var base := REEL_FIRST if i == 0 else REEL_NEXT
	return base + (REEL_SPECIAL if i < _rows.size() and _rows[i].special else 0.0)


func reel_start(i: int) -> float:
	var at := open_time() + RISE
	for j: int in range(mini(i, _rows.size())):
		at += reel_time(j)
	return at


## A roleta do cartão `i` para no item, e ele sai voando até o cartão.
func item_time(i: int) -> float:
	return reel_start(i) + reel_time(i)


func end_time() -> float:
	var last := item_time(maxi(_rows.size() - 1, 0)) + ITEM_FLY
	return maxf(last, open_time() + COUNT_TIME) + TAIL


## Duração da sequência em tempo real (com a animação curta, a metade).
func real_duration() -> float:
	return end_time() / _pace


func pace() -> float:
	return _pace


func fortune() -> StringName:
	return _fortune


## O papel do 凶 já está amarrado no galho.
func tied() -> bool:
	return _fortune == Omikuji.KYO and fortune_sealed()


## O omikuji acabou: o selo da sorte está embaixo do título (ou o 凶 no galho).
func fortune_sealed() -> bool:
	return visible and (_t >= omikuji_time() or not _busy)


## Fase atual: "omikuji", "chest", "reel" ou "done".
func phase() -> String:
	if not _busy:
		return "done"
	if _t < omikuji_time():
		return "omikuji"
	if _rows.is_empty() or _t < reel_start(0):
		return "chest"
	return "reel"


## Cartão girando na roleta agora (-1 = nenhum).
func reel_row() -> int:
	return _reel_row


func reel_ticks() -> int:
	return _ticks


func gold_flashes() -> int:
	return _gold_flashes


func coin_rains() -> int:
	return _coin_rains


## Peças do omikuji e da roleta no espaço da tela (testes de layout).
func slip_global_rect() -> Rect2:
	return Rect2(_slip_rect.position + _stage_rect.position, _slip_rect.size)


## Papel mais as duas linhas de leitura embaixo.
func slip_block_rect() -> Rect2:
	var r := slip_global_rect()
	return Rect2(r.position, Vector2(r.size.x, r.size.y + 6.0 + OmikujiPaint.READ_LINE * 2.0))


func reel_global_rect() -> Rect2:
	return Rect2(_reel_rect.position + _stage_rect.position, _reel_rect.size)


func branch_global_rect() -> Rect2:
	return Rect2(_branch_rect.position + _stage_rect.position, _branch_rect.size)


## Tubo parado (com a vareta para fora), no espaço da tela.
func tube_global_rect() -> Rect2:
	var s := OmikujiPaint.tube_size(_chest.px)
	var stick := 10.0 * _chest.px
	return Rect2(_tube_base + _stage_rect.position - Vector2(s.x * 0.5, s.y + stick), Vector2(s.x, s.y + stick))


## Largura da linha da sorte (selo + leitura) embaixo do título.
func fortune_line_width() -> float:
	return OmikujiPaint.line_width(_fortune)


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


## Fita da roleta de cada cartão: ícones de armas sorteados (só visual, `_rng` da tela, nunca
## o da partida) e o item de verdade no fim, onde a roleta para.
func _build_strips() -> void:
	if _pool.is_empty():
		for id: StringName in DB.ids("weapons"):
			var path := String(DB.weapon(id).get("icon", ""))
			if not path.is_empty() and ResourceLoader.exists(path):
				var tex := load(path) as Texture2D
				if tex and not _pool.has(tex):
					_pool.append(tex)
	_strips.clear()
	for i: int in range(_rows.size()):
		var row := _rows[i]
		var spins: int = REEL_SPINS[0 if i == 0 else 1] + (REEL_SPINS[2] if row.special else 0)
		var strip: Array[Texture2D] = []
		for k: int in range(spins):
			var pick: Texture2D = _pool[_rng.randi() % _pool.size()] if not _pool.is_empty() else null
			# Sem repetir o item logo antes da parada (a fita "passa" por ele).
			if pick == row.icon and _pool.size() > 1 and k == spins - 1:
				pick = _pool[(_pool.find(pick) + 1) % _pool.size()]
			strip.append(pick)
		strip.append(row.icon)
		_strips.append(strip)


# --- Linha do tempo ----------------------------------------------------------------------

func _process(delta: float) -> void:
	if not visible:
		return
	if _busy:
		_t += delta * _pace
		_run_omikuji()
		_run_timeline()
		if _t >= end_time():
			_settle()
	_update_particles(delta)
	_reel_flash = maxf(0.0, _reel_flash - delta * 2.5)
	_stage.queue_redraw()
	_reel.queue_redraw()
	_fly.queue_redraw()


## Dispara cada evento uma vez, quando o relógio passa por ele.
func _once(key: String, at: float) -> bool:
	if _t < at or _fired.has(key):
		return false
	_fired[key] = true
	return true


func _run_timeline() -> void:
	_fx.power = clampf(_t / 0.25, 0.0, 1.0)
	# 1. Queda e amassado (depois do omikuji).
	var d0 := omikuji_time()
	_chest.visible = _t >= d0
	var land := d0 + DROP
	if _t < land:
		var k := clampf((_t - d0) / DROP, 0.0, 1.0)
		_chest.position = _chest_rest - Vector2(0, (1.0 - k * k) * (_chest_rest.y + _chest.size.y + 10.0))
		_chest.squash = Vector2(0.92, 1.1)
	else:
		_chest.position = _chest_rest
		var s := clampf((_t - land) / SETTLE, 0.0, 1.0)
		var bounce := sin(s * PI) * (1.0 - s)
		_chest.squash = Vector2(1.0 + 0.22 * bounce, 1.0 - 0.25 * bounce)
	if _once("whoosh", d0 + 0.02):
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
	# 4. Roleta e itens, um a um.
	_run_reel()
	for i: int in range(_rows.size()):
		var at := item_time(i)
		if _once("item%d" % i, at):
			_stop_reel(i)
			_flying.append({"row": i, "k": 0.0})
			AudioManager.play("whoosh", 1.3 + 0.08 * i, 0.0, -12.0)
		if _once("land%d" % i, at + ITEM_FLY):
			_land(i)


# --- Omikuji -----------------------------------------------------------------------------

func _run_omikuji() -> void:
	if _t >= omikuji_time() + 0.05 and _fired.has("omi_out"):
		return
	if _once("omi_in", 0.0):
		AudioManager.play("whoosh", 0.7, 0.0, -10.0)
	if _once("omi_land", OMI_IN):
		AudioManager.play("k_wood_0", 0.9, 0.0, -4.0)
	# Chacoalhar: estalos de madeira cada vez mais rápidos.
	if _t >= OMI_IN and _t < pop_time():
		var k := (_t - OMI_IN) / OMI_SHAKE
		var beat := int(floorf(pow(k, 0.8) * 8.0))
		if _once("tube%d" % beat, _t):
			AudioManager.play("k_wood_1", 1.1 + 0.06 * beat, 0.04, -10.0 + beat * 0.5)
	if _once("omi_pop", pop_time()):
		AudioManager.play("k_wood_0", 1.6, 0.0, -2.0)
		AudioManager.play("whoosh", 1.5, 0.0, -10.0)
	if _once("omi_unroll", unroll_time()):
		AudioManager.play("paper_flutter", 1.0, 0.05, -4.0)
	if _once("omi_reveal", reveal_time()):
		_reveal()
	if _once("omi_fold", fold_time()):
		AudioManager.play("paper_flutter" if _fortune == Omikuji.KYO else "paper_fold", 1.1, 0.05, -4.0)
	if _once("omi_out", omikuji_time()):
		if _fortune == Omikuji.KYO:
			AudioManager.play("paper_fold", 0.9, 0.0, -2.0)
		else:
			AudioManager.play("ui_confirm", 1.0, 0.0, -6.0)


## O papel abre: som da sorte e, no 大吉, clarão dourado, chuva de moedas e o gongo.
func _reveal() -> void:
	match _fortune:
		Omikuji.DAIKICHI:
			AudioManager.play("j_gong", 1.0, 0.0, -3.0)
			AudioManager.play("j_temple_bell", 1.0, 0.0, -2.0)
			AudioManager.play("fanfare", 1.0, 0.0, -4.0)
			AudioManager.play("coin", 1.0, 0.0, -6.0)
			if _fx_level >= 1 and not _calm:
				_fx.flash_color = Color("ffd166")
				_fx.flash = 0.9
				_gold_flashes += 1
			_coin_rain()
			_screen_kick(3.0)
		Omikuji.CHUKICHI:
			AudioManager.play("bell", 1.0, 0.0, -4.0)
			AudioManager.play("suzu", 1.0, 0.0, -6.0)
			_sparkle(UiPaint.GOLD_HI, [3, 6, 10][_fx_level])
		Omikuji.KYO:
			AudioManager.play("taiko", 0.7, 0.0, -4.0)
		_:
			AudioManager.play("suzu", 1.0, 0.0, -4.0)
			_sparkle(UiPaint.PAPER, [2, 4, 6][_fx_level])


## Moedas caindo do alto do palco inteiro (大吉), no orçamento de partículas.
func _coin_rain() -> void:
	var count := int(COINS[_fx_level] * 1.5)
	count = mini(count, int(GfxQuality.budget("particles_max")) / 10)
	_coin_rains += 1
	var top := _stage_rect.position
	for i: int in range(count):
		_coins.append({"p": top + Vector2(_rng.randf_range(4.0, _stage_rect.size.x - 4.0), -_rng.randf_range(4.0, 60.0)),
				"v": Vector2(_rng.randf_range(-25.0, 25.0), _rng.randf_range(30.0, 110.0)),
				"life": -_rng.randf_range(0.0, 0.3), "spin": _rng.randf() * TAU, "bounced": false})


## Faíscas em volta do papel aberto.
func _sparkle(color: Color, count: int) -> void:
	var c := _slip_rect.get_center() + _stage_rect.position
	for k: int in range(count):
		var spread := Vector2(_rng.randf_range(-OmikujiPaint.SLIP_W, OmikujiPaint.SLIP_W), _rng.randf_range(-30.0, 30.0))
		_glints.append({"p": c + spread,
				"v": Vector2(_rng.randf_range(-10.0, 10.0), _rng.randf_range(-30.0, -10.0)), "life": 0.0, "color": color})


# --- Roleta ------------------------------------------------------------------------------

## Fita girando: posição (em ícones) com desaceleração; estalo a cada ícone que passa.
func _run_reel() -> void:
	_reel_row = -1
	for i: int in range(_rows.size()):
		if _t >= reel_start(i) and _t < item_time(i):
			_reel_row = i
			break
	if _reel_row < 0:
		return
	if _once("reel%d" % _reel_row, reel_start(_reel_row)):
		AudioManager.play("whoosh", 1.6, 0.0, -14.0)
	var index := int(floorf(reel_offset(_reel_row) + 0.5))
	if index != _reel_index:
		_reel_index = index
		_ticks += 1
		AudioManager.play("ui_move", 0.9 + 0.04 * index, 0.0, -8.0)


## Posição da fita do cartão `i` agora, em ícones (0 = primeiro de enchimento; o item de
## verdade fica no último). Evolução/união passa um pouco do ponto e volta (ressalto).
func reel_offset(i: int) -> float:
	if i < 0 or i >= _strips.size():
		return 0.0
	var steps := float((_strips[i] as Array).size() - 1)
	var p := clampf((_t - reel_start(i)) / reel_time(i), 0.0, 1.0)
	var e := 1.0 - pow(1.0 - p, 3.0)
	if _rows[i].special:
		var c1 := 1.4
		e = 1.0 + (c1 + 1.0) * pow(p - 1.0, 3.0) + c1 * pow(p - 1.0, 2.0)
	return e * steps


## O item `i` em que a roleta parou (testes): o último ícone da fita.
func reel_target(i: int) -> Texture2D:
	return (_strips[i] as Array).back() if i >= 0 and i < _strips.size() else null


func _stop_reel(i: int) -> void:
	_reel_index = -1
	var special := _rows[i].special
	_reel_flash = 1.0 if special else 0.6
	AudioManager.play("k_wood_0", 1.5, 0.0, -6.0)
	if special:
		AudioManager.play("suzu", 1.2, 0.0, -2.0)
		AudioManager.play("metal_light", 1.0, 0.0, -6.0)
		_screen_kick(2.5)
		var c := reel_global_rect().get_center()
		for k: int in range([3, 6, 12][_fx_level]):
			_glints.append({"p": c, "v": Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(25.0, 70.0),
					"life": 0.0, "color": Color("ffd166")})


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
	_reel_row = -1
	_chest.visible = true
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
	var items := flight_items()
	cancel()
	claimed.emit(items)
	closed.emit()


## Um item de voo por cartão (do centro do ícone, na cor do cartão) e o saco de ryō saindo do
## total embaixo do baú, no espaço da tela.
func flight_items() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for row: RewardRow in _rows:
		items.append({"from": row.get_global_transform_with_canvas() * row.icon_center(), "icon": row.icon,
				"color": row.accent, "scale": float(row.icon_side()) / maxf(row.icon.get_width(), 1.0) if row.icon else 1.0,
				"key": LevelUpPanel.slot_key(row.reward)})
	if _has_ryo:
		var bag: Texture2D = null
		for reward: Dictionary in _rewards:
			if String(reward.get("kind", "")) == "ryo":
				bag = LevelUpPanel._load(String(reward.get("icon", "")))
		var at := _stage.get_global_transform_with_canvas() * Vector2(_stage.size.x * 0.5, _stage.size.y - BUTTON_H - 14.0)
		items.append({"from": at, "icon": bag, "color": UiPaint.GOLD_HI, "scale": 1.0, "key": ""})
	return items


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
	_layout_omikuji(stage_w, top)
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


## Tubo no lugar do baú; papel (com as duas linhas de leitura) centrado entre a linha da sorte e
## o ryō; galho do 凶 no canto direito, acima da tampa aberta; janela da roleta sobre a boca do
## baú, abaixo da linha da sorte.
func _layout_omikuji(stage_w: float, top: float) -> void:
	var floor_y := _chest_rest.y + _chest.size.y
	_tube_base = Vector2(floorf(stage_w * 0.5), floor_y)
	var slip_h := OmikujiPaint.slip_height()
	var block := slip_h + 6.0 + OmikujiPaint.READ_LINE * 2.0
	var lo := top + 4.0
	var hi := _stage_rect.size.y - BUTTON_H - 34.0
	var y := floorf(lo + maxf(hi - lo - block, 0.0) * 0.5)
	_slip_rect = Rect2(floorf((stage_w - OmikujiPaint.SLIP_W) * 0.5), y, OmikujiPaint.SLIP_W, slip_h)
	_branch_rect = Rect2(Vector2(stage_w - OmikujiPaint.BRANCH_SIZE.x - 2.0, top), OmikujiPaint.BRANCH_SIZE)
	var lid_top := _chest_rest.y - 9.0 * _chest.px
	var reel_y := clampf(lid_top - REEL_CELL - 2.0, top, _chest_rest.y + _chest.mouth().y - REEL_CELL)
	_reel_rect = Rect2(floorf((stage_w - REEL_CELL) * 0.5), reel_y, REEL_CELL, REEL_CELL)
	_reel.position = _reel_rect.position
	_reel.size = _reel_rect.size


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
	# Linha da sorte: o selo com o kanji do omikuji e a leitura, na cor da raridade.
	if fortune_sealed():
		OmikujiPaint.fortune_line(_stage, w, _fortune, color, a)
	else:
		UiPaint.ornament(_stage, Vector2(w * 0.5, 34.0), minf(w * 0.3, 70.0), a)
	if _fortune == Omikuji.KYO and (_t >= fold_time() or not _busy):
		OmikujiPaint.branch(_stage, _branch_rect, clampf((_t - fold_time()) / 0.15, 0.0, 1.0) if _busy else 1.0, tied())
	if _busy and _t < omikuji_time():
		_draw_omikuji()
	if not _chest.visible:
		_draw_ryo(w, opened, a)
		return
	var mouth := _chest_rest + _chest.mouth()
	# Sombra no chão.
	var floor_c := _chest_rest + Vector2(_chest.size.x * 0.5, _chest.size.y + 1.0)
	var fall := clampf((_t - omikuji_time()) / DROP, 0.0, 1.0) if _busy else 1.0
	_stage.draw_set_transform(floor_c, 0.0, Vector2(1.0, 0.25))
	_stage.draw_circle(Vector2.ZERO, _chest.size.x * 0.55 * fall, Color(0, 0, 0, 0.45 * a))
	_stage.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Aura e raios girando atrás do baú aberto (ou vazando antes de abrir).
	var glow := 1.0 if opened else _chest.crack * 0.5
	if glow > 0.0:
		var count: int = STAGE_RAYS[_fx_level]
		var spin := _time() * (0.6 if _fx_level > 0 else 0.0)
		var reach := minf(w * 0.6, 150.0)
		# Triângulos em degradê como primitivas (sem o buffer novo de draw_polygon a cada quadro).
		var ray_colors := PackedColorArray([Color(color, 0.32 * glow), Color(color, 0.0), Color(color, 0.0)])
		for i: int in range(count):
			var ang := -PI * 0.5 + spin + TAU * i / count
			var width := 0.09 + 0.04 * sin(i * 1.9)
			var tip := mouth
			_stage.draw_primitive(PackedVector2Array([tip, tip + Vector2.from_angle(ang - width) * reach,
					tip + Vector2.from_angle(ang + width) * reach]), ray_colors, PackedVector2Array())
		_stage.draw_circle(mouth, 34.0, Color(color, 0.1 * glow))
		_stage.draw_circle(mouth, 20.0, Color(color.lerp(Color.WHITE, 0.4), 0.14 * glow))
		# Coluna de luz subindo da boca.
		if opened:
			var col_w := _chest.size.x * 0.7
			var col_h := mouth.y - 4.0
			UiPaint.vgradient(_stage, Rect2(mouth.x - col_w * 0.5, mouth.y - col_h, col_w, col_h),
					Color(color, 0.0), Color(color.lerp(Color.WHITE, 0.3), 0.22))
	# Halo dourado atrás da roleta quando gira uma evolução ou união.
	if _reel_row >= 0 and _rows[_reel_row].special:
		var pulse := 0.5 + 0.5 * sin(_time() * 12.0)
		_stage.draw_circle(_reel_rect.get_center(), REEL_CELL * 0.85, Color(Color("ffd166"), 0.18 + 0.12 * pulse))
	_draw_ryo(w, opened, a)


## Ryō ganho, contando.
func _draw_ryo(w: float, opened: bool, a: float) -> void:
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


## Tubo, vareta e papel do omikuji (só durante a fase do omikuji).
func _draw_omikuji() -> void:
	# Tubo: cai, chacoalha, solta a vareta e some enquanto o papel desenrola.
	var tube_a := 1.0 - clampf((_t - unroll_time()) / OMI_UNROLL, 0.0, 1.0)
	if tube_a > 0.0:
		var drop := clampf(_t / OMI_IN, 0.0, 1.0)
		var base := _tube_base - Vector2(0, (1.0 - drop * drop) * (_tube_base.y + 10.0))
		var tilt := 0.0
		if _t >= OMI_IN and _t < pop_time():
			tilt = sin(_t * 46.0) * lerpf(0.06, 0.22, (_t - OMI_IN) / OMI_SHAKE)
		var stick := 0.0
		if _t >= pop_time():
			var p := clampf((_t - pop_time()) / OMI_POP, 0.0, 1.0)
			stick = (1.0 - pow(1.0 - p, 3.0) + sin(p * PI) * 0.25) * 10.0 * _chest.px
		OmikujiPaint.tube(_stage, base, tilt, stick, tube_a, _chest.px)
	if _t < unroll_time():
		return
	# Papel: desenrola, mostra a sorte e sai (encolhe até o selo, ou dobra e voa até o galho).
	var open := clampf((_t - unroll_time()) / OMI_UNROLL, 0.0, 1.0)
	var out := clampf((_t - fold_time()) / OMI_OUT, 0.0, 1.0)
	var kyo := _fortune == Omikuji.KYO
	var center := _slip_rect.get_center()
	var zoom := 1.0
	var alpha := 1.0
	if out > 0.0:
		var e := out * out * (3.0 - 2.0 * out)
		var target := OmikujiPaint.seal_center(_stage.size.x, _fortune)
		if kyo:
			target = OmikujiPaint.knot_point(_branch_rect) + Vector2(0, 8.0)
		center = center.lerp(target, e) - Vector2(0, sin(e * PI) * (14.0 if kyo else 6.0))
		zoom = lerpf(1.0, 0.22, e)
		alpha = 1.0 - clampf((out - 0.75) / 0.25, 0.0, 1.0)
	OmikujiPaint.slip(_stage, center, _slip_rect.size, zoom, 0.5 * out if kyo else 0.0, open, _fortune, alpha)
	# Leitura e significado embaixo do papel, enquanto ele está aberto.
	var text_a := clampf((open - 0.6) / 0.4, 0.0, 1.0) * (1.0 - clampf(out * 3.0, 0.0, 1.0))
	if text_a > 0.0:
		var color := UiPaint.DIM if kyo else rarity_color().lerp(UiPaint.GOLD_HI, 0.4)
		var y0 := _slip_rect.end.y + 6.0 + OmikujiPaint.READ_LINE - 3.0
		OmikujiPaint.reading(_stage, _stage.size.x, y0, _fortune, color, text_a)


## Janela da roleta: a fita do cartão girando (vazia entre uma parada e o próximo giro).
func _draw_reel() -> void:
	if not _busy or _rows.is_empty() or _t < reel_start(0) - 0.15 or _t >= item_time(_rows.size() - 1) + 0.25:
		return
	var row := _reel_row
	var strip: Array = _strips[row] if row >= 0 else []
	OmikujiPaint.reel(_reel, _reel.size, strip, reel_offset(row), REEL_CELL, row >= 0 and _rows[row].special,
			_reel_flash)


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
	# Sai da janela da roleta, onde ela parou no item.
	var from := _stage_rect.position + _reel_rect.get_center()
	var to := row.get_global_transform_with_canvas() * row.icon_center()
	var peak := from + Vector2(0, -14.0)
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
