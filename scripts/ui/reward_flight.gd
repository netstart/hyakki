class_name RewardFlight
extends Control
## Voo das recompensas até a guardiã: toda vez que ela ganha algo (carta do nível novo, itens
## e ryō do baú no "Continuar", pacto com um Kami), o ícone de cada item sai de onde estava na
## tela, dá um pulinho com um "pop" de escala, faz um arco em leque (um item para cada lado,
## escalonados) com rastro de ecos e faíscas na cor do item e mergulha na guardiã: o ícone
## encolhe clareando, e um anel com raios e um clarão curto marcam a absorção, cada um com uma
## nota do koto subindo (arpejo pentatônico, como no baú). O alvo é relido a cada quadro
## (`target`), então o voo segue a guardiã se a câmera andar.
## - A luta volta enquanto os ícones voam: a camada não pega toques e não trava nada.
## - Tempo real (delta do _process): igual em 1x, 2x e 3x. Com a pausa aberta (`hold`), o voo
##   congela e some até ela fechar.
## - GfxQuality "ui_fx": 0 = só o ícone e o anel (sem ecos, faíscas nem brilho), 1 = ecos curtos
##   e poucas faíscas, 2 = completo. "Reduzir flashes" apaga o clarão da absorção.
## - Puramente visual: RNG próprio, só LÊ a posição da guardiã; nunca toca a simulação.

## Cada ícone que pousa (a HUD acende o encaixe dele na barra do topo).
signal landed(item: Dictionary)
## O último ícone foi absorvido e o efeito acabou.
signal finished

## Pulinho inicial, voo e absorção (segundos) de cada ícone; atraso entre um ícone e o próximo.
const LIFT_TIME := 0.13
const FLY_TIME := 0.44
const ABSORB_TIME := 0.28
const STAGGER := 0.08
## Muitos itens (baú lendário): o escalonamento se comprime para o total caber em ~1 s.
const MAX_STAGGER_SPAN := 0.26
const LIFT_HEIGHT := 12.0
## "Pop" de escala no topo do pulinho e a fração final do voo em que o ícone mergulha.
const POP := 1.3
const DIVE := 0.18
## Ecos do rastro e faíscas por nível de ui_fx.
const ECHOES := [0, 4, 7]
## Distância mínima entre dois ecos (px), para o rastro se abrir mesmo em voo curto.
const ECHO_STEP := 5.0
const SPARKS_PER_SECOND := [0.0, 22.0, 60.0]
const MAX_SPARKS := 90
const BURST_SPARKS := [0, 5, 10]
const BURST_RAYS := [0, 6, 10]
const RING_REACH := 22.0
## Ponto de pouso relativo à origem da guardiã (o peito, não os pés).
const GUARDIAN_OFFSET := Vector2(0.0, -5.0)
## Escala pentatônica (semitons) das notas de chegada, como no baú.
const ARPEGGIO := [0, 2, 4, 7, 9, 12, 14, 16]

## () -> Vector2: onde a guardiã está agora, no espaço desta camada.
var target: Callable
## () -> bool: true congela e esconde o voo (pausa aberta).
var hold: Callable

## Ícones no ar: {item, from, at, t, delay, side, icon, color, scale, echoes: PackedVector2Array}.
var _flyers: Array[Dictionary] = []
## Absorções tocando: {t, color, index}.
var _bursts: Array[Dictionary] = []
## Faíscas: {p, v, life, color}.
var _sparks: Array[Dictionary] = []
var _fx_level: int = 2
var _calm: bool = false
var _launched: int = 0
var _landed: int = 0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rng.seed = 61
	visible = false


# --- API ---------------------------------------------------------------------------------

## Solta os ícones. Cada item: {"icon": Texture2D, "from": Vector2 (espaço desta camada),
## "color": Color, "scale": float (escala do ícone na origem; padrão 1), "key": String (encaixe
## na HUD, opcional)}. Itens sem ícone voam como uma luz da cor deles.
func launch(items: Array[Dictionary]) -> void:
	if items.is_empty():
		return
	_fx_level = int(GfxQuality.budget("ui_fx"))
	_calm = bool(Settings.get_value("reduce_flashes"))
	var step := minf(STAGGER, MAX_STAGGER_SPAN / maxf(items.size() - 1, 1.0))
	var base := _flyers.size()
	for i: int in range(items.size()):
		var item := items[i]
		var from: Vector2 = item.get("from", size * 0.5)
		var index := base + i
		_flyers.append({"item": item, "from": from, "at": from, "t": 0.0, "delay": step * i,
				"side": -1.0 if index % 2 == 0 else 1.0, "icon": item.get("icon", null) as Texture2D,
				"color": item.get("color", ThemeFactory.ACCENT) as Color,
				"scale": maxf(float(item.get("scale", 1.0)), 1.0), "echoes": PackedVector2Array(),
				"index": _launched})
		_launched += 1
	visible = true
	AudioManager.play("whoosh", 1.35, 0.04, -12.0)


## Some na hora (nova partida, morte, testes).
func clear() -> void:
	_flyers.clear()
	_bursts.clear()
	_sparks.clear()
	_launched = 0
	_landed = 0
	visible = false


## Ainda há algo voando, explodindo ou faiscando.
func active() -> bool:
	return not _flyers.is_empty() or not _bursts.is_empty() or not _sparks.is_empty()


## Ícones ainda no ar (sem contar as absorções).
func flyer_count() -> int:
	return _flyers.size()


func burst_count() -> int:
	return _bursts.size()


func spark_count() -> int:
	return _sparks.size()


## Ícones absorvidos desde o último clear().
func landed_count() -> int:
	return _landed


## Duração total do efeito para `count` itens (do launch até a última absorção acabar).
static func total_time(count: int) -> float:
	var step := minf(STAGGER, MAX_STAGGER_SPAN / maxf(count - 1, 1.0))
	return step * maxi(count - 1, 0) + LIFT_TIME + FLY_TIME + ABSORB_TIME


## Lado nativo do ícone de um voo (8 px para a luz sem ícone).
static func native_side(f: Dictionary) -> float:
	var icon: Texture2D = f["icon"]
	return maxf(icon.get_width(), icon.get_height()) if icon != null else 8.0


## Posição do ícone `index` agora (testes).
func flyer_position(index: int) -> Vector2:
	return _flyers[index]["at"]


## Onde os ícones pousam neste quadro.
func goal() -> Vector2:
	if target.is_valid():
		var at: Variant = target.call()
		if at is Vector2:
			return (at as Vector2) + GUARDIAN_OFFSET
	return size * 0.5


# --- Movimento ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not active():
		visible = false
		return
	var frozen := hold.is_valid() and bool(hold.call())
	visible = not frozen
	if frozen:
		return
	step(delta)
	queue_redraw()


## Avança `delta` segundos de tempo real (o _process chama; os testes também).
func step(delta: float) -> void:
	var to := goal()
	for i: int in range(_flyers.size() - 1, -1, -1):
		var f := _flyers[i]
		f["t"] = float(f["t"]) + delta
		var t := float(f["t"]) - float(f["delay"])
		if t <= 0.0:
			continue
		var at := path_point(f, t, to)
		var echoes: PackedVector2Array = f["echoes"]
		if echoes.is_empty() or echoes[echoes.size() - 1].distance_to(at) >= ECHO_STEP:
			echoes.append(at)
		while echoes.size() > int(ECHOES[_fx_level]) + 1:
			echoes.remove_at(0)
		f["echoes"] = echoes
		f["at"] = at
		_emit_sparks(f, delta)
		if t >= LIFT_TIME + FLY_TIME:
			_flyers.remove_at(i)
			_absorb(f)
	for i: int in range(_bursts.size() - 1, -1, -1):
		var b := _bursts[i]
		b["t"] = float(b["t"]) + delta / ABSORB_TIME
		if float(b["t"]) >= 1.0:
			_bursts.remove_at(i)
	for i: int in range(_sparks.size() - 1, -1, -1):
		var s := _sparks[i]
		s["v"] = (s["v"] as Vector2) * maxf(0.0, 1.0 - 3.0 * delta)
		s["p"] = (s["p"] as Vector2) + (s["v"] as Vector2) * delta
		s["life"] = float(s["life"]) - delta
		if float(s["life"]) <= 0.0:
			_sparks.remove_at(i)
	if not active():
		visible = false
		finished.emit()


## Ponto do caminho `t` segundos depois da saída: pulinho para cima (ease-out) e depois um arco
## de Bézier até a guardiã, curvado para o lado do ícone, que acelera no fim (mergulho).
func path_point(f: Dictionary, t: float, to: Vector2) -> Vector2:
	var from: Vector2 = f["from"]
	var lifted := from + Vector2(0.0, -LIFT_HEIGHT)
	if t < LIFT_TIME:
		var k := t / LIFT_TIME
		return from.lerp(lifted, 1.0 - pow(1.0 - k, 3.0))
	var v := clampf((t - LIFT_TIME) / FLY_TIME, 0.0, 1.0)
	var e := v * v * v * (v * (v * 6.0 - 15.0) + 10.0)
	e = lerpf(e, v * v, 0.35)
	var span := to - lifted
	var bend := clampf(span.length() * 0.28, 16.0, 70.0) * float(f["side"])
	var control := lifted.lerp(to, 0.45) + span.orthogonal().normalized() * bend + Vector2(0.0, -24.0)
	var a := lifted.lerp(control, e)
	var b := control.lerp(to, e)
	return a.lerp(b, e)


## Escala do ícone: cresce no pulinho (pop), volta ao tamanho de origem e encolhe a zero no
## mergulho final.
func flyer_scale(f: Dictionary, t: float) -> float:
	var base := float(f["scale"])
	if t < LIFT_TIME:
		return base * lerpf(1.0, POP, sin(t / LIFT_TIME * PI * 0.5))
	var v := clampf((t - LIFT_TIME) / FLY_TIME, 0.0, 1.0)
	var size_now := lerpf(base * POP, maxf(1.0, base * 0.75), minf(v / (1.0 - DIVE), 1.0))
	if v > 1.0 - DIVE:
		size_now *= 1.0 - (v - (1.0 - DIVE)) / DIVE
	return size_now


func _emit_sparks(f: Dictionary, delta: float) -> void:
	var rate: float = SPARKS_PER_SECOND[_fx_level]
	if rate <= 0.0 or _sparks.size() >= MAX_SPARKS:
		return
	var chance := rate * delta
	while chance > 0.0 and _sparks.size() < MAX_SPARKS:
		if _rng.randf() < chance:
			var color: Color = f["color"]
			_sparks.append({"p": (f["at"] as Vector2) + Vector2(_rng.randf_range(-4.0, 4.0), _rng.randf_range(-4.0, 4.0)),
					"v": Vector2(_rng.randf_range(-14.0, 14.0), _rng.randf_range(-18.0, 4.0)),
					"life": _rng.randf_range(0.25, 0.5), "color": color.lerp(Color.WHITE, _rng.randf_range(0.2, 0.7))})
		chance -= 1.0


## O ícone chegou: absorção na guardiã (anel, raios, clarão e faíscas), a nota do koto e o aviso
## para a HUD acender o encaixe.
func _absorb(f: Dictionary) -> void:
	var index := int(f["index"])
	var color: Color = f["color"]
	_bursts.append({"t": 0.0, "color": color, "index": index})
	var to := goal()
	for k: int in range(mini(int(BURST_SPARKS[_fx_level]), MAX_SPARKS - _sparks.size())):
		var dir := Vector2.from_angle(TAU * (k + _rng.randf() * 0.5) / maxf(BURST_SPARKS[_fx_level], 1.0))
		_sparks.append({"p": to + dir * 3.0, "v": dir * _rng.randf_range(40.0, 75.0),
				"life": _rng.randf_range(0.25, 0.4), "color": color.lerp(Color.WHITE, 0.5)})
	var note: int = ARPEGGIO[mini(_landed, ARPEGGIO.size() - 1)]
	AudioManager.play("j_koto", 1.5 * pow(2.0, note / 12.0), 0.0, -6.0)
	if _landed == 0:
		AudioManager.play("bell", 1.6, 0.0, -14.0)
	_landed += 1
	landed.emit(f["item"])


# --- Desenho -----------------------------------------------------------------------------

func _draw() -> void:
	var to := goal()
	var glow := MenuKit.glow_texture()
	for b: Dictionary in _bursts:
		_draw_burst(to, b, glow)
	for s: Dictionary in _sparks:
		var a := clampf(float(s["life"]) / 0.3, 0.0, 1.0)
		var p := (s["p"] as Vector2).floor()
		draw_rect(Rect2(p, Vector2.ONE * (2.0 if a > 0.7 else 1.0)), Color(s["color"] as Color, a))
		if _fx_level >= 2 and a > 0.6:
			draw_rect(Rect2(p + Vector2(-1, 0), Vector2(3, 1)), Color(s["color"] as Color, a * 0.35))
	for f: Dictionary in _flyers:
		var t := float(f["t"]) - float(f["delay"])
		if t > 0.0:
			_draw_flyer(f, t, to, glow)
		else:
			_draw_waiting(f, glow)


## Ícone esperando a vez (escalonado): parado onde estava, brilhando de leve.
func _draw_waiting(f: Dictionary, glow: Texture2D) -> void:
	var icon: Texture2D = f["icon"]
	var at: Vector2 = f["from"]
	var color: Color = f["color"]
	var s := (icon.get_size() if icon != null else Vector2(8, 8)) * float(f["scale"])
	if _fx_level >= 1:
		draw_texture_rect(glow, Rect2(at - s * 0.9, s * 1.8), false, Color(color, 0.35))
	if icon != null:
		draw_texture_rect(icon, Rect2((at - s * 0.5).floor(), s.floor()), false)


func _draw_flyer(f: Dictionary, t: float, to: Vector2, glow: Texture2D) -> void:
	var color: Color = f["color"]
	var at: Vector2 = f["at"]
	var scale_now := flyer_scale(f, t)
	var v := clampf((t - LIFT_TIME) / FLY_TIME, 0.0, 1.0)
	var whiten := clampf((v - (1.0 - DIVE * 2.0)) / (DIVE * 2.0), 0.0, 1.0)
	if _fx_level >= 1:
		var halo := maxf(native_side(f) * scale_now * 2.2, 14.0) + 8.0 * sin(minf(t / LIFT_TIME, 1.0) * PI * 0.5)
		draw_texture_rect(glow, Rect2(at - Vector2.ONE * halo * 0.5, Vector2.ONE * halo), false, Color(color, 0.7))
	var icon: Texture2D = f["icon"]
	var native := icon.get_size() if icon != null else Vector2(8, 8)
	# Ecos: o ícone repetido para trás, na cor do item, cada vez mais apagado.
	var echoes: PackedVector2Array = f["echoes"]
	# Cauda de cometa: um fio de luz pelos ecos até o ícone, afinando para trás.
	for j: int in range(echoes.size() - 1):
		var k := float(j + 1) / echoes.size()
		var b := echoes[j + 1] if j + 1 < echoes.size() - 1 else at
		draw_line(echoes[j], b, Color(color.lerp(Color.WHITE, 0.45), 0.55 * k), 1.0 + roundf(k * 2.0))
	for j: int in range(echoes.size() - 1):
		var k := float(j + 1) / echoes.size()
		var s := native * scale_now * (0.6 + 0.4 * k)
		if icon != null:
			draw_texture_rect(icon, Rect2((echoes[j] - s * 0.5).floor(), s.floor()), false,
					Color(color.lerp(Color.WHITE, 0.3), 0.28 * k))
		else:
			draw_circle(echoes[j], 2.0 + 2.0 * k, Color(color, 0.3 * k))
	# Linha de luz até a guardiã no mergulho final.
	if _fx_level >= 1 and whiten > 0.0:
		draw_line(at, to, Color(color.lerp(Color.WHITE, 0.6), 0.25 * whiten), 1.0)
	if icon != null and scale_now > 0.05:
		var s := native * scale_now
		var tint := Color.WHITE.lerp(Color(2.0, 2.0, 1.8), whiten)
		draw_texture_rect(icon, Rect2((at - s * 0.5).floor(), s.floor()), false, tint)
	else:
		draw_circle(at, 3.0 + 2.0 * (1.0 - whiten), Color(color.lerp(Color.WHITE, 0.5), 0.9))
	# Faísca branca no centro durante o mergulho.
	if whiten > 0.0:
		draw_circle(at, 1.5 + 2.5 * whiten, Color(1.0, 1.0, 0.9, 0.9 * whiten))


## Absorção: clarão (sem "Reduzir flashes"), anel que abre e raios curtos girando um pouco.
func _draw_burst(to: Vector2, b: Dictionary, glow: Texture2D) -> void:
	var k := clampf(float(b["t"]), 0.0, 1.0)
	var color: Color = b["color"]
	var fade := 1.0 - k
	var ease_k := 1.0 - pow(1.0 - k, 3.0)
	if _fx_level >= 1:
		var flash := 0.35 if _calm else 0.85
		var side := 20.0 + 22.0 * ease_k
		draw_texture_rect(glow, Rect2(to - Vector2.ONE * side * 0.5, Vector2.ONE * side), false,
				Color(color.lerp(Color.WHITE, 0.5), flash * fade))
	var radius := 3.0 + RING_REACH * ease_k
	draw_arc(to, radius, 0.0, TAU, 28, Color(color.lerp(Color.WHITE, 0.35), fade), 1.0 + fade)
	if _fx_level >= 2:
		draw_arc(to, radius * 0.6, 0.0, TAU, 20, Color(1.0, 1.0, 0.9, 0.6 * fade), 1.0)
	var rays: int = BURST_RAYS[_fx_level]
	for r: int in range(rays):
		var dir := Vector2.from_angle(TAU * r / rays + float(b["index"]) * 0.4 + k * 0.6)
		var inner := to + dir * (4.0 + 10.0 * ease_k)
		var outer := to + dir * (8.0 + 20.0 * ease_k)
		draw_line(inner, outer, Color(color.lerp(Color.WHITE, 0.6), 0.8 * fade), 1.0)
	if not _calm and k < 0.35:
		draw_circle(to, 5.0 * (1.0 - k / 0.35), Color(1.0, 1.0, 0.92, 0.85))
