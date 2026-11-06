class_name AbilityPad
extends Control
## Habilidades na HUD da partida (.ai/04-habilidades-dos-guardioes.md): três botões redondos em
## arco em volta do Golpe da Lanterna, do lado oposto ao joystick (espelha para canhotos e anda
## com o recorte da câmera junto com o Golpe), e a barra da energia do guardião logo acima do
## arco (glifo, barra na cor da energia com marcas no custo de cada habilidade liberada e o valor).
##
## Cada botão: ícone (os 18x18 de dentro da moldura do ícone 24x24, pixel perfeito), aro na cor da energia,
## varredura radial da recarga (Stroke, sem polígono por quadro) com os segundos que faltam quando
## falta ≥ 1 s, custo em dígitos 3x5 embaixo. Sem energia: ícone sem cor e aro vermelho. Yuki
## pagando com vida (AbilitySystem.hp_price): aro e custo cor de sangue, com a gota. Travada:
## ícone apagado, cadeado e "Nv 5". Lampejo quando a recarga acaba (Events.ability_ready) e,
## maior, quando a habilidade libera (Events.ability_unlocked, com o nome por 2,6 s acima da
## barra); tremor e piscar quando falha por energia (Events.ability_failed: o botão e a barra).
##
## Toque: InputEventScreenTouch de qualquer dedo em _input. O Godot só emula o mouse para o
## primeiro dedo na tela; com o polegar no joystick, um Button comum não recebe o segundo dedo.
## Assim o arco e o Golpe (ultimate_tapped) funcionam junto com o joystick (multitoque). No PC o
## clique vira toque (emulate_touch_from_mouse). Teclas e controle ficam no AbilitySystem.
##
## Desenho: cada botão tem duas camadas. A de baixo (disco e ícone, com o material sem cor quando
## falta energia) só é redesenhada quando o estado muda; a de cima (aro, varredura, segundos,
## custo, cadeado, lampejo) também só muda quando algo muda, e a cada quadro só com recarga ou
## lampejo em andamento. Tremores mexem a posição (sem redesenho). A barra de energia redesenha
## quando o valor inteiro muda.
##
## `source` é o AbilitySystem da partida (game.abilities) ou um dublê com a mesma leitura nos
## testes: slot_count, ability, ability_id, required_level, is_unlocked, cost, cooldown_left,
## cooldown_fraction, can_pay, hp_price, activate, energy_id, energy_value, energy_max,
## energy_color, energy_icon.

signal ultimate_tapped
## Aviso curto para a HUD mostrar (toque numa travada, falta de energia).
signal notice(text: String)

const RADIUS := 14.0
## Alvo de toque (um pouco maior que o desenho, sem chegar no vizinho).
const HIT := 16.0
const GAP := 4.0
## Ângulos do arco com o Golpe à direita (o lado esquerdo espelha): à esquerda do Golpe (a 1ª,
## onde o polegar já está), na diagonal e em cima.
const ANGLES: Array[float] = [PI, PI * 1.25, PI * 1.5]
const ICON_CROP := Rect2(3, 3, 18, 18)
const GAUGE_GAP := 5.0
const GAUGE_H := 16.0
const GLYPH := 12.0
const BAR := Vector2(46.0, 6.0)
const READY_TIME := 0.55
const UNLOCK_TIME := 2.6
const USED_TIME := 0.2
const SHAKE_TIME := 0.38
const SHAKE := 3.0
const BLOOD := Color("ff4a4a")
const DENY := Color("e0473a")
const DISC := Color(0.07, 0.04, 0.09, 0.82)
const SHADE := Color(0.02, 0.01, 0.04, 0.68)
const LOCKED_TINT := Color(0.42, 0.4, 0.46)
const INK := Color("fff8e8")
const CAPTION_GAP := 3.0
## Varredura da recarga em passos (1/96 de volta): redesenha só quando muda de passo.
const SWEEP_STEPS := 96
const GRAY_SHADER := """
shader_type canvas_item;
void fragment() {
	float g = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
	COLOR.rgb = mix(COLOR.rgb, vec3(g * 0.78), 0.92);
}
"""

static var _gray: ShaderMaterial

## AbilitySystem (ou dublê dos testes); null esconde o arco.
var source: Object
## true quando a HUD não aceita toque de jogo (telas abertas, morte, contagem).
var blocked := Callable()
var ult_center := Vector2.ZERO
var ult_radius := 27.0
## Arco do lado esquerdo da tela (joystick à direita).
var on_left := false

var _buttons: Array[AbilityButton] = []
var _gauge: EnergyGauge
var _caption: Caption
var _icons: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for slot: int in 3:
		var b := AbilityButton.new()
		b.pad = self
		b.slot = slot
		b.name = "Ability%d" % (slot + 1)
		add_child(b)
		_buttons.append(b)
	_gauge = EnergyGauge.new()
	_gauge.pad = self
	_gauge.name = "EnergyGauge"
	add_child(_gauge)
	_caption = Caption.new()
	_caption.name = "UnlockCaption"
	add_child(_caption)
	Events.ability_ready.connect(_on_ready)
	Events.ability_unlocked.connect(_on_unlocked)
	Events.ability_failed.connect(_on_failed)
	Events.ability_used.connect(_on_used)
	_place()


static func gray_material() -> ShaderMaterial:
	if _gray == null:
		var shader := Shader.new()
		shader.code = GRAY_SHADER
		_gray = ShaderMaterial.new()
		_gray.shader = shader
	return _gray


# --- Layout ----------------------------------------------------------------------------------

## Golpe com centro `center` e raio `radius` (coordenadas da HUD); `left`: arco à esquerda.
func place(center: Vector2, radius: float, left: bool) -> void:
	ult_center = center
	ult_radius = radius
	on_left = left
	_place()


func _place() -> void:
	if _buttons.is_empty():
		return
	for slot: int in _buttons.size():
		var b := _buttons[slot]
		b.base = button_center(slot) - Vector2(HIT, HIT)
		b.position = b.base
		b.size = Vector2(HIT, HIT) * 2.0
	var g := gauge_rect()
	_gauge.base = g.position
	_gauge.position = g.position
	_gauge.size = g.size
	_caption.anchor_x = ult_center.x - ult_radius if on_left else ult_center.x + ult_radius
	_caption.left = on_left
	_caption.bottom = g.position.y - CAPTION_GAP
	_caption.relayout()


## Centro do botão `slot` (0..2) nas coordenadas da HUD.
func button_center(slot: int) -> Vector2:
	var angle := ANGLES[clampi(slot, 0, 2)]
	if on_left:
		angle = PI - angle
	var reach := ult_radius + GAP + RADIUS
	return (ult_center + Vector2(cos(angle), sin(angle)) * reach).round()


## Alvo de toque do botão (quadrado em volta do círculo de toque), para os testes de layout.
func button_rect(slot: int) -> Rect2:
	return Rect2(button_center(slot) - Vector2(HIT, HIT), Vector2(HIT, HIT) * 2.0)


## Barra de energia: acima do botão de cima do arco, alinhada à borda de fora do Golpe.
func gauge_rect() -> Rect2:
	var w := gauge_width()
	var top := button_center(2).y - RADIUS - GAUGE_GAP - GAUGE_H
	var x := ult_center.x - ult_radius if on_left else ult_center.x + ult_radius - w
	return Rect2(roundf(x), roundf(top), w, GAUGE_H)


func gauge_width() -> float:
	return GLYPH + 3.0 + BAR.x + 3.0 + value_width()


## Largura do valor no pior caso (3 dígitos).
static func value_width() -> float:
	return ceilf(UiPaint.text_width("888"))


## Retângulo do texto de desbloqueio (vazio se não está aparecendo).
func caption_rect() -> Rect2:
	return _caption.text_rect() if _caption.visible else Rect2()


## Mostra o texto de desbloqueio do slot agora (testes de layout também usam).
func show_caption(slot: int) -> void:
	var id := ability_id(slot)
	_caption.show_text(String(ability(slot).get("kanji", "")), tr("ability.%s.name" % id) if id != &"" else "")


## Distância da borda da tela (largura `width`) até o lado de dentro do arco e da barra (a HUD
## afasta os textos centrais).
func reach_from_edge(width: float) -> float:
	var inner := -INF if on_left else INF
	for slot: int in 3:
		var c := button_center(slot)
		inner = maxf(inner, c.x + HIT) if on_left else minf(inner, c.x - HIT)
	var g := gauge_rect()
	inner = maxf(inner, g.end.x) if on_left else minf(inner, g.position.x)
	return inner if on_left else width - inner


func buttons() -> Array[AbilityButton]:
	return _buttons


func gauge() -> EnergyGauge:
	return _gauge


func caption() -> Caption:
	return _caption


# --- Leitura do sistema ------------------------------------------------------------------------

func has_abilities() -> bool:
	return source != null and int(source.call("slot_count")) > 0


func ability(slot: int) -> Dictionary:
	return source.call("ability", slot) as Dictionary if source != null else {}


func ability_id(slot: int) -> StringName:
	return StringName(String(ability(slot).get("id", "")))


## Estado do slot para o desenho e para os testes: unlocked, level, cost, left (s), fraction,
## pay (tem energia ou vida), blood (vai pagar com vida), icon.
func slot_state(slot: int) -> Dictionary:
	if not has_abilities() or slot >= int(source.call("slot_count")):
		return {}
	var price := float(source.call("hp_price", slot))
	return {"unlocked": bool(source.call("is_unlocked", slot)), "level": int(source.call("required_level", slot)),
			"cost": int(roundf(float(source.call("cost", slot)))), "left": float(source.call("cooldown_left", slot)),
			"fraction": float(source.call("cooldown_fraction", slot)), "pay": bool(source.call("can_pay", slot)),
			"blood": price > 0.0 and price < INF, "icon": String(ability(slot).get("icon", ""))}


func icon(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if not _icons.has(path):
		_icons[path] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _icons[path]


func energy_name() -> String:
	return tr("energy.%s.name" % String(source.call("energy_id"))) if source != null else ""


# --- Quadro --------------------------------------------------------------------------------------

func _process(_delta: float) -> void:
	var shown := has_abilities()
	if visible != shown:
		visible = shown
	if not shown:
		return
	var now := UiClock.msec() / 1000.0
	for b: AbilityButton in _buttons:
		b.visible = b.slot < int(source.call("slot_count"))
		if b.visible:
			b.update(now)
	_gauge.update(now)
	_caption.update(now)


## Redesenha tudo na próxima vez (troca de idioma, de herói, testes).
func refresh() -> void:
	_place()
	for b: AbilityButton in _buttons:
		b.invalidate()
	_gauge.invalidate()


# --- Toque -----------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch == null or not touch.pressed or not is_visible_in_tree() or not has_abilities():
		return
	if blocked.is_valid() and bool(blocked.call()):
		return
	var at := touch.position - global_position
	var slot := slot_at(at)
	if slot >= 0:
		get_viewport().set_input_as_handled()
		tap(slot)
	elif at.distance_to(ult_center) <= ult_radius:
		get_viewport().set_input_as_handled()
		ultimate_tapped.emit()


## Slot sob o ponto (coordenadas da HUD) ou -1.
func slot_at(at: Vector2) -> int:
	for slot: int in mini(3, int(source.call("slot_count")) if source != null else 0):
		if at.distance_to(button_center(slot)) <= HIT:
			return slot
	return -1


## Toque no slot: tenta soltar (o retorno de falha chega por Events.ability_failed).
func tap(slot: int) -> bool:
	return bool(source.call("activate", slot)) if has_abilities() else false


# --- Eventos ---------------------------------------------------------------------------------

func _on_ready(slot: int) -> void:
	if slot >= 0 and slot < _buttons.size():
		_buttons[slot].flash_ready()


func _on_unlocked(slot: int, _id: StringName) -> void:
	if slot < 0 or slot >= _buttons.size() or not has_abilities():
		return
	_buttons[slot].flash_unlock()
	show_caption(slot)


func _on_used(_hero: StringName, slot: int, _id: StringName, _kanji: String) -> void:
	if slot >= 0 and slot < _buttons.size():
		_buttons[slot].flash_used()


func _on_failed(slot: int, reason: int) -> void:
	if slot < 0 or slot >= _buttons.size() or not has_abilities():
		return
	match reason:
		AbilitySystem.Fail.NO_ENERGY:
			_buttons[slot].deny(true)
			_gauge.deny()
			notice.emit(tr("ability.no_energy") % energy_name())
		AbilitySystem.Fail.LOCKED:
			_buttons[slot].deny(false)
			notice.emit(tr("ability.level_req") % int(source.call("required_level", slot)))
		AbilitySystem.Fail.COOLDOWN, AbilitySystem.Fail.NO_TARGET:
			_buttons[slot].deny(false)


static func calm() -> bool:
	return bool(Settings.get_value("reduce_flashes"))


# --- Peças ---------------------------------------------------------------------------------------

## Um botão: camada de baixo (disco e ícone) e de cima (aro, varredura, textos, lampejos).
class AbilityButton extends Control:
	var pad: AbilityPad
	var slot := 0
	var base := Vector2.ZERO
	var state: Dictionary = {}
	var _face: Control
	var _over: Control
	var _face_sig: Array = []
	var _over_sig: Array = []
	var _ready_at := -100.0
	var _unlock_at := -100.0
	var _used_at := -100.0
	var _deny_at := -100.0
	var _deny_red := false
	var _now := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_face = _layer(_draw_face)
		_over = _layer(_draw_over)

	func _layer(painter: Callable) -> Control:
		var c := Control.new()
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		c.draw.connect(painter)
		add_child(c)
		return c

	func center() -> Vector2:
		return Vector2(AbilityPad.HIT, AbilityPad.HIT)

	func invalidate() -> void:
		_face_sig = []
		_over_sig = []

	func flash_ready() -> void:
		_ready_at = _clock()

	func flash_unlock() -> void:
		_unlock_at = _clock()

	func flash_used() -> void:
		_used_at = _clock()

	func deny(red: bool) -> void:
		_deny_at = _clock()
		_deny_red = red

	func denying() -> bool:
		return _clock() - _deny_at < AbilityPad.SHAKE_TIME

	func _clock() -> float:
		return UiClock.msec() / 1000.0

	## Lampejo ativo (0..1, 1 = começou agora) de `at` com duração `time`.
	func _fade(at: float, time: float) -> float:
		return clampf(1.0 - (_now - at) / time, 0.0, 1.0)

	func update(now: float) -> void:
		_now = now
		state = pad.slot_state(slot)
		if state.is_empty():
			return
		var face := [state["icon"], state["unlocked"], state["pay"]]
		if face != _face_sig:
			_face_sig = face
			# Sem energia (nem vida, na Yuki) para pagar: ícone sem cor.
			_face.material = AbilityPad.gray_material() if bool(state["unlocked"]) and not bool(state["pay"]) else null
			_face.queue_redraw()
		var flashing := _fade(_ready_at, AbilityPad.READY_TIME) > 0.0 \
				or _fade(_unlock_at, AbilityPad.UNLOCK_TIME * 0.4) > 0.0 or _fade(_used_at, AbilityPad.USED_TIME) > 0.0
		var shaking := denying()
		var left := float(state["left"])
		var over := [state["unlocked"], state["pay"], state["blood"], state["cost"], state["level"],
				ceili(left) if left >= 1.0 else 0, ceili(float(state["fraction"]) * AbilityPad.SWEEP_STEPS),
				flashing, shaking, now if flashing or shaking else 0.0]
		if over != _over_sig:
			_over_sig = over
			_over.queue_redraw()
		var shake := 0.0
		if shaking:
			var k := 1.0 - (now - _deny_at) / AbilityPad.SHAKE_TIME
			shake = roundf(sin((now - _deny_at) * 70.0) * AbilityPad.SHAKE * k)
		position = base + Vector2(shake, 0.0)

	func _draw_face() -> void:
		if state.is_empty():
			return
		var c := center()
		var unlocked := bool(state["unlocked"])
		_face.draw_circle(c, AbilityPad.RADIUS, AbilityPad.DISC)
		var tex := pad.icon(String(state["icon"]))
		if tex != null:
			var tint := Color.WHITE if unlocked else AbilityPad.LOCKED_TINT
			var crop := AbilityPad.ICON_CROP
			_face.draw_texture_rect_region(tex, Rect2(c - crop.size * 0.5, crop.size), crop, tint)

	func _draw_over() -> void:
		if state.is_empty():
			return
		var c := center()
		var r := AbilityPad.RADIUS
		var unlocked := bool(state["unlocked"])
		var left := float(state["left"])
		var fraction := float(state["fraction"])
		var color: Color = pad.source.call("energy_color") if pad.source != null else Color.WHITE
		var blood := bool(state["blood"])
		var pay := bool(state["pay"])
		var calm := AbilityPad.calm()
		if unlocked and fraction > 0.0:
			# Varredura: a parte escura é o que falta da recarga, a partir do meio-dia no sentido horário.
			var start := -PI * 0.5 + TAU * (1.0 - fraction)
			var points := maxi(2, ceili(28.0 * fraction) + 1)
			Stroke.arc(_over, c, (r - 1.0) * 0.5, start, PI * 1.5, points, AbilityPad.SHADE, r - 1.0)
			var edge := Vector2(cos(start), sin(start))
			Stroke.line(_over, PackedVector2Array([c, c + edge * (r - 1.0)]), Color(color, 0.85), 1.0)
		var rim := Color(color, 0.95)
		if not unlocked:
			rim = Color(0.55, 0.5, 0.6, 0.8)
		elif blood:
			rim = AbilityPad.BLOOD
		elif not pay:
			rim = AbilityPad.DENY.darkened(0.15)
		if denying() and _deny_red and int(_now * 16.0) % 2 == 0:
			rim = Color.WHITE
		Stroke.arc(_over, c, r - 0.5, 0.0, TAU, 28, Color(0.0, 0.0, 0.0, 0.85), 3.0)
		Stroke.arc(_over, c, r - 0.5, 0.0, TAU, 28, rim, 1.0)
		if not unlocked:
			_draw_locked(c)
			return
		if left >= 1.0:
			var secs := str(ceili(left))
			var w := UiPaint.text_width(secs)
			UiPaint.text(_over, Vector2(c.x - roundf(w * 0.5), c.y + 2.0), secs, 12, AbilityPad.INK)
		_draw_cost(blood, pay)
		var ready := _fade(_ready_at, AbilityPad.READY_TIME)
		if ready > 0.0:
			var a := ready * (0.5 if calm else 1.0)
			Stroke.arc(_over, c, r + 1.0 + (1.0 - ready) * 5.0, 0.0, TAU, 28, Color(color.lightened(0.4), a), 2.0)
		var unlock := _fade(_unlock_at, AbilityPad.UNLOCK_TIME * 0.4)
		if unlock > 0.0:
			var a := unlock * (0.5 if calm else 1.0)
			_over.draw_rect(Rect2(c - Vector2(9, 9), Vector2(18, 18)), Color(1, 1, 1, 0.5 * a * a))
			Stroke.arc(_over, c, r + 2.0 + (1.0 - unlock) * 9.0, 0.0, TAU, 32, Color(UiPaint.GOLD_HI, a), 2.0)
		var used := _fade(_used_at, AbilityPad.USED_TIME)
		if used > 0.0:
			_over.draw_rect(Rect2(c - Vector2(9, 9), Vector2(18, 18)), Color(1, 1, 1, 0.45 * used * (0.5 if calm else 1.0)))

	## Custo em dígitos 3x5 numa pílula embaixo do ícone; com vida (Yuki), cor de sangue e a gota.
	func _draw_cost(blood: bool, pay: bool) -> void:
		var r := cost_rect()
		var ink := AbilityPad.INK
		var bg := Color(0.06, 0.03, 0.09, 0.92)
		if blood:
			bg = Color("5a0c10")
			ink = Color("ffd0c8")
		elif not pay:
			ink = Color("ff9a8a")
		_over.draw_rect(Rect2(r.position + Vector2(1, 0), r.size - Vector2(2, 0)), Color(0, 0, 0, 0.9))
		_over.draw_rect(Rect2(r.position + Vector2(0, 1), r.size - Vector2(0, 2)), Color(0, 0, 0, 0.9))
		_over.draw_rect(r.grow(-1.0), bg)
		var x := r.position.x + 2.0
		if blood:
			_drop(Vector2(x, r.position.y + 2.0))
			x += 4.0
		SkillIconPainter.draw_digits(_over, Vector2(x, r.position.y + 2.0), str(state["cost"]), ink)

	## Gota de sangue 3x5.
	func _drop(at: Vector2) -> void:
		_over.draw_rect(Rect2(at + Vector2(1, 0), Vector2(1, 1)), AbilityPad.BLOOD)
		_over.draw_rect(Rect2(at + Vector2(0, 1), Vector2(3, 3)), AbilityPad.BLOOD)
		_over.draw_rect(Rect2(at + Vector2(1, 4), Vector2(1, 1)), AbilityPad.BLOOD)
		_over.draw_rect(Rect2(at + Vector2(0, 1), Vector2(1, 1)), Color("ffb0a8"))

	## Pílula do custo no espaço do botão (testes de layout).
	func cost_rect() -> Rect2:
		var digits := str(state.get("cost", 0)).length()
		var w := digits * 4.0 + 3.0 + (4.0 if bool(state.get("blood", false)) else 0.0)
		var c := center()
		return Rect2(Vector2(c.x - floorf(w * 0.5), c.y + 4.0), Vector2(w, 9.0))

	## Cadeado em cima e "Nv 5" numa pílula no meio do botão; se o texto do idioma não cabe no alvo
	## de toque, só o número.
	func _draw_locked(c: Vector2) -> void:
		UiPaint.padlock(_over, Vector2(c.x - 3.0, c.y - 12.0), Color("e0b04a"))
		var parts := locked_parts()
		var pill: Rect2 = parts["pill"]
		_over.draw_rect(pill, Color(0.05, 0.03, 0.07, 0.92))
		_over.draw_rect(pill, Color(0.75, 0.62, 0.35, 0.8), false, 1.0)
		UiPaint.text(_over, parts["baseline"] as Vector2, String(parts["text"]), 12, Color("f2e2c0"),
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, 2)

	## Peças do botão travado no espaço do botão: "text", "pill", "baseline", "lock".
	func locked_parts() -> Dictionary:
		var level := int(state.get("level", 1))
		var text := TranslationServer.translate("ability.locked") % level
		var font := Locale.font
		if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 4.0 > AbilityPad.HIT * 2.0:
			text = str(level)
		var w := ceilf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x)
		var c := center()
		var asc := font.get_ascent(12)
		var h := asc + font.get_descent(12)
		var pill := Rect2(roundf(c.x - w * 0.5) - 2.0, c.y - 2.0, w + 4.0, roundf(h) + 1.0)
		return {"text": text, "pill": pill, "baseline": Vector2(pill.position.x + 2.0, pill.position.y + roundf(asc) + 1.0),
				"lock": Rect2(Vector2(c.x - 3.0, c.y - 12.0), UiPaint.PADLOCK_SIZE)}


## Barra de energia: glifo, barra com as marcas dos custos e o valor.
class EnergyGauge extends Control:
	var pad: AbilityPad
	var base := Vector2.ZERO
	var _sig: Array = []
	var _deny_at := -100.0
	var _now := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func invalidate() -> void:
		_sig = []

	func deny() -> void:
		_deny_at = UiClock.msec() / 1000.0

	func denying() -> bool:
		return _now - _deny_at < AbilityPad.SHAKE_TIME

	func update(now: float) -> void:
		_now = now
		var src := pad.source
		var value := floori(float(src.call("energy_value")))
		var unlocked: Array[bool] = []
		for slot: int in int(src.call("slot_count")):
			unlocked.append(bool(src.call("is_unlocked", slot)))
		var sig := [value, float(src.call("energy_max")), src.call("energy_icon"), unlocked, denying(),
				now if denying() else 0.0]
		if sig != _sig:
			_sig = sig
			queue_redraw()
		var shake := 0.0
		if denying():
			var k := 1.0 - (now - _deny_at) / AbilityPad.SHAKE_TIME
			shake = roundf(sin((now - _deny_at) * 70.0) * AbilityPad.SHAKE * k)
		position = base + Vector2(shake, 0.0)

	## Peças no espaço da barra: "glyph", "bar", "value" (caixa do texto) e "baseline".
	func parts() -> Dictionary:
		var font := Locale.font
		var asc := font.get_ascent(12)
		var bar_x := AbilityPad.GLYPH + 3.0
		var bar := Rect2(bar_x, roundf((size.y - AbilityPad.BAR.y) * 0.5), AbilityPad.BAR.x, AbilityPad.BAR.y)
		var value_x := bar.end.x + 3.0
		var baseline := roundf((size.y - asc - font.get_descent(12)) * 0.5 + asc)
		return {"glyph": Rect2(0, roundf((size.y - AbilityPad.GLYPH) * 0.5), AbilityPad.GLYPH, AbilityPad.GLYPH),
				"bar": bar, "value": Rect2(value_x, baseline - asc, AbilityPad.value_width(), asc + font.get_descent(12)),
				"baseline": baseline}

	func _draw() -> void:
		var src := pad.source
		if src == null:
			return
		var p := parts()
		var color: Color = src.call("energy_color")
		var max_value := maxf(1.0, float(src.call("energy_max")))
		var value := float(src.call("energy_value"))
		var red := denying() and int(_now * 16.0) % 2 == 0
		# Placa escura atrás de tudo: a barra se lê sobre a grama clara e a neve.
		draw_rect(Rect2(Vector2(-2.0, 0.0), size + Vector2(4.0, 0.0)), Color(0.03, 0.02, 0.05, 0.42))
		var glyph := pad.icon(String(src.call("energy_icon")))
		if glyph != null:
			draw_texture_rect(glyph, p["glyph"] as Rect2, false)
		var bar: Rect2 = p["bar"]
		draw_rect(bar.grow(1.0), Color(0.0, 0.0, 0.0, 0.85))
		draw_rect(bar, Color(0.12, 0.08, 0.14, 0.9))
		var fill := Rect2(bar.position, Vector2(roundf(bar.size.x * clampf(value / max_value, 0.0, 1.0)), bar.size.y))
		draw_rect(fill, AbilityPad.DENY if red else color)
		if fill.size.x > 0.0:
			draw_rect(Rect2(fill.position, Vector2(fill.size.x, 1.0)), Color(1, 1, 1, 0.35))
		# Marca do custo de cada habilidade liberada: clara quando dá para pagar.
		for slot: int in int(src.call("slot_count")):
			if not bool(src.call("is_unlocked", slot)):
				continue
			var cost := float(src.call("cost", slot))
			var x := bar.position.x + roundf(bar.size.x * clampf(cost / max_value, 0.0, 1.0))
			if x >= bar.end.x:
				continue
			draw_rect(Rect2(x, bar.position.y - 1.0, 1.0, bar.size.y + 2.0),
					Color(1, 1, 1, 0.75) if value >= cost else Color(0, 0, 0, 0.7))
		if red:
			draw_rect(bar.grow(1.0), Color(AbilityPad.DENY, 0.9), false, 1.0)
		var text := str(floori(value))
		UiPaint.text(self, Vector2((p["value"] as Rect2).position.x, float(p["baseline"])), text, 12,
				AbilityPad.DENY.lightened(0.3) if red else color.lightened(0.35))


## Texto curto quando uma habilidade libera: kanji e nome, acima da barra, por UNLOCK_TIME.
class Caption extends Control:
	var anchor_x := 0.0
	var bottom := 0.0
	var left := false
	var kanji := ""
	var title := ""
	var _at := -100.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false

	func show_text(p_kanji: String, p_title: String) -> void:
		kanji = p_kanji
		title = p_title
		_at = UiClock.msec() / 1000.0
		visible = true
		modulate.a = 1.0
		relayout()
		queue_redraw()

	func relayout() -> void:
		var r := text_rect()
		position = r.position
		size = r.size

	func _kanji_w() -> float:
		return ceilf(UiPaint.text_width(kanji, 12, UiPaint.ja_font())) if kanji != "" else 0.0

	func _title_w() -> float:
		return ceilf(UiPaint.text_width(title))

	## Caixa do texto nas coordenadas da HUD.
	func text_rect() -> Rect2:
		var gap := 4.0 if kanji != "" and title != "" else 0.0
		var w := _kanji_w() + gap + _title_w()
		var h := ceilf(Locale.font.get_height(12))
		var x := anchor_x if left else anchor_x - w
		return Rect2(roundf(x), roundf(bottom - h), w, h)

	func update(now: float) -> void:
		if not visible:
			return
		var t := now - _at
		if t >= AbilityPad.UNLOCK_TIME:
			visible = false
			return
		# Some no último terço (só o modulate: o texto não é redesenhado).
		modulate.a = clampf((AbilityPad.UNLOCK_TIME - t) / (AbilityPad.UNLOCK_TIME / 3.0), 0.0, 1.0)

	func _draw() -> void:
		var asc := Locale.font.get_ascent(12)
		var x := 0.0
		if kanji != "":
			UiPaint.text(self, Vector2(x, roundf(asc)), kanji, 12, UiPaint.GOLD_HI, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 3,
					UiPaint.OUTLINE, UiPaint.ja_font())
			x += _kanji_w() + 4.0
		UiPaint.text(self, Vector2(x, roundf(asc)), title, 12, UiPaint.PAPER)
