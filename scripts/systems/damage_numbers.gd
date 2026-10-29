class_name DamageNumbers
extends Node2D
## Números de dano e cura (regras, cores, limites e densidade adaptativa em DamagePalette). Fica
## dentro de um CanvasLayer que segue a câmera, acima da escuridão da lanterna e do tom da noite:
## as cores chegam fiéis à paleta. Tudo em arrays empacotados de tamanho fixo (CAPACITY): nenhum
## nó, nenhum dicionário e nenhum Vector/Color alocado por quadro; o movimento sai da idade
## (motion / crit_motion), não de uma posição integrada.
##
## Densidade adaptativa: `enemies` (a FxLayer passa os inimigos vivos) e a taxa de números pedidos
## por segundo viram a pressão suavizada e o nível 0/1/2 (DamagePalette.next_level), que encolhe e
## encurta o comum, junta perto e parecido ("×N") e esconde golpes comuns pequenos.
##
## O menor degrau usa dígitos 3×5 desenhados aqui mesmo (atlas criado uma vez em memória, sem
## arquivo nem licença de terceiros): a fonte pixel de 12 px abaixo de 10 px vira borrão.
##
## Só desenho: usa randf() próprio, nunca o rng da partida (não mexe no determinismo).

## Vagas do anel (bem acima de MAX_ON_SCREEN: achar vaga livre é quase sempre imediato).
const CAPACITY := 120
## Raios das faíscas do crítico.
const CRIT_RAYS := 6
## Estilhaços do crítico (direção e velocidade fixas por estilhaço, girados pela vaga).
const SHARDS := [Vector2(-38, -30), Vector2(34, -36), Vector2(-20, -52), Vector2(44, -12), Vector2(-46, -6)]
const SHARD_GRAVITY := 160.0
## Dígitos 3×5: caracteres e linhas (3 bits por linha, o bit 2 é a coluna da esquerda).
const MICRO_CHARS := "0123456789+-!kM.,x"
const MICRO_ROWS := [
	[7, 5, 5, 5, 7], [2, 6, 2, 2, 7], [7, 1, 7, 4, 7], [7, 1, 3, 1, 7], [5, 5, 7, 1, 1],
	[7, 4, 7, 1, 7], [7, 4, 7, 5, 7], [7, 1, 2, 2, 2], [7, 5, 7, 5, 7], [7, 5, 7, 1, 7],
	[0, 2, 7, 2, 0], [0, 0, 7, 0, 0], [2, 2, 2, 0, 2], [4, 5, 6, 5, 5], [5, 7, 7, 5, 5],
	[0, 0, 0, 0, 2], [0, 0, 0, 2, 4], [0, 5, 2, 5, 0],
]
## Célula do atlas (glifo 3×5 + 1 px de contorno em volta) e avanço entre glifos.
const MICRO_CELL := Vector2i(5, 7)
const MICRO_ADVANCE := 4

## Atlas dos dígitos 3×5 (preenchimento e contorno, brancos: a cor vem na hora do desenho).
static var _micro_fill: ImageTexture
static var _micro_line: ImageTexture
## Código do caractere (0..127) → índice do glifo (-1 = sem glifo).
static var _micro_map := PackedInt32Array()

## Posição de quem não deve ser coberto (a guardiã), atualizada pela FxLayer.
var guard := Vector2.INF
## Qualidade Baixa (FxLayer.wfx == 0): crítico reduzido, sem tremor nem inchaço.
var low := false
## Golpes mostrados (número novo, somado ou juntado): os testes conferem que algo apareceu.
var events: int = 0
## Números vivos agora (MAX_ON_SCREEN no máximo).
var live: int = 0
## Vivos por tipo (contadores: o limite de críticos não varre o anel).
var live_kind := PackedInt32Array()
## Inimigos vivos (a FxLayer atualiza a cada quadro) e a pressão/nível que saem deles.
var enemies: int = 0
var pressure: float = 0.0
var level: int = 0
## Testes e capturas: pressão fixa (step não recalcula).
var lock_pressure := false
## Números pedidos por segundo (suavizado) e os pedidos deste quadro.
var rate: float = 0.0
## Escondidos pelas regras de densidade (juntados e pequenos demais), para os testes.
var folded: int = 0
var dropped: int = 0

var _font: Font
var _decimal := "."
var _palette: Array = DamagePalette.NORMAL
var _colorblind := false
var _attempts: int = 0
var _pos := PackedVector2Array()
var _age := PackedFloat32Array()
var _life := PackedFloat32Array()
## Idade no último golpe somado (janela da soma).
var _last := PackedFloat32Array()
var _amount := PackedFloat32Array()
var _ref := PackedFloat32Array()
var _text := PackedStringArray()
## Meia largura do texto no tamanho dele (medida só ao criar ou somar).
var _half := PackedFloat32Array()
var _kind := PackedByteArray()
## 1 = crítico com o SLAM grande (até CRIT_BIG_MAX ao mesmo tempo).
var _big := PackedByteArray()
var _step := PackedByteArray()
## Tamanho em px (0 = dígitos 3×5), fixado ao criar (DamagePalette.number_size).
var _size := PackedByteArray()
## Golpes parecidos juntados neste número (1 = só ele; mostra "×N" acima de 1).
var _count := PackedInt32Array()
var _target := PackedInt32Array()
var _next: int = 0
var _last_slot: int = -1
## Vagas mais recentes (afastamento, densidade local e juntar parecidos).
var _recent := PackedInt32Array()
var _recent_next: int = 0
## Inimigo → vaga + 1 do número que ainda soma (comum e contínuo).
var _merge_hit := PackedInt32Array()
var _merge_dot := PackedInt32Array()


func _ready() -> void:
	_font = Locale.font if Locale.font else ThemeDB.fallback_font
	_decimal = DamagePalette.decimal_for(TranslationServer.get_locale())
	for packed: StringName in [&"_pos", &"_age", &"_life", &"_last", &"_amount", &"_ref", &"_text", &"_half",
			&"_kind", &"_big", &"_step", &"_size", &"_count", &"_target"]:
		var array: Variant = get(packed)
		array.resize(CAPACITY)
		set(packed, array)
	_life.fill(0.0)
	_recent.resize(DamagePalette.SPREAD_CHECK)
	_recent.fill(-1)
	_merge_hit.resize(EnemyManager.CAPACITY)
	_merge_dot.resize(EnemyManager.CAPACITY)
	_build_micro()
	reset()


func reset() -> void:
	_life.fill(0.0)
	_age.fill(0.0)
	_merge_hit.fill(0)
	_merge_dot.fill(0)
	_recent.fill(-1)
	live = 0
	live_kind.resize(DamagePalette.Kind.size())
	live_kind.fill(0)
	_last_slot = -1
	if not lock_pressure:
		pressure = 0.0
		level = 0
	rate = 0.0
	_attempts = 0


func set_colorblind(on: bool) -> void:
	_colorblind = on
	_palette = DamagePalette.palette(on)


## Pressão e nível fixos (testes e capturas); `on` falso volta ao cálculo ao vivo.
func force_level(new_level: int, new_pressure: float, on: bool = true) -> void:
	lock_pressure = on
	level = new_level
	pressure = new_pressure


## Novo número (ou soma no número do mesmo inimigo). `ref`: média móvel (dano causado) ou HP
## máximo (recebido e cura); `target`: índice do inimigo (-1 = sem soma).
func add(at: Vector2, amount: float, kind: int, ref: float = 0.0, target: int = -1) -> void:
	if _merge(amount, kind, target):
		return
	# Só conta o que viraria número novo (somas no mesmo inimigo não poluem a tela).
	_attempts += 1
	if DamagePalette.insignificant(kind, amount, ref, level):
		dropped += 1
		return
	if level > 0 and _fold(at + Vector2(0.0, -8.0), amount, kind):
		return
	var priority := DamagePalette.priority(kind)
	if kind == DamagePalette.Kind.CRIT and live_kind.size() > kind and live_kind[kind] >= DamagePalette.MAX_CRITS:
		return
	if DamagePalette.is_enemy(kind) and _crowded(at + Vector2(0.0, -8.0), priority):
		return
	if live >= int(DamagePalette.LEVEL_CAP[level]) and not _evict(priority):
		return
	var big := kind == DamagePalette.Kind.CRIT and _big_crits() < DamagePalette.CRIT_BIG_MAX
	var i := _free_slot()
	_big[i] = 1 if big else 0
	var s: Dictionary = DamagePalette.NORMAL[kind]
	var life := float(s["life"])
	if priority < 3:
		life *= lerpf(1.0, DamagePalette.DENSE_LIFE_MIN, float(live) / float(DamagePalette.LEVEL_CAP[level]))
		life = maxf(DamagePalette.MIN_LIFE, life * DamagePalette.level_life(kind, level))
	_pos[i] = _place(at + Vector2(randf_range(-3.0, 3.0), -8.0), kind)
	_age[i] = 0.0
	_last[i] = 0.0
	_life[i] = life
	_amount[i] = amount
	_ref[i] = ref
	_kind[i] = kind
	_count[i] = 1
	_target[i] = target
	_set_text(i)
	live += 1
	live_kind[kind] += 1
	events += 1
	_last_slot = i
	_recent[_recent_next] = i
	_recent_next = (_recent_next + 1) % _recent.size()
	if target >= 0 and target < EnemyManager.CAPACITY:
		if kind == DamagePalette.Kind.HIT:
			_merge_hit[target] = i + 1
		elif kind == DamagePalette.Kind.DOT:
			_merge_dot[target] = i + 1


## Último número criado, somado ou juntado (testes): {"kind", "text", "fill", "size", ...} ou vazio.
func last() -> Dictionary:
	if _last_slot < 0 or _life[_last_slot] <= _age[_last_slot]:
		return {}
	var i := _last_slot
	return {"kind": int(_kind[i]), "text": _text[i], "fill": _palette[_kind[i]]["fill"], "size": int(_size[i]),
			"amount": _amount[i], "pos": _pos[i], "big": _big[i] == 1, "count": _count[i], "life": _life[i]}


## Números vivos do tipo `kind` (-1 = todos), para os testes.
func count(kind: int = -1) -> int:
	var n := 0
	for i: int in range(CAPACITY):
		if _life[i] > 0.0 and (kind < 0 or _kind[i] == kind):
			n += 1
	return n


## Área (px lógicos²) coberta pelos números vivos, contorno incluído (testes de cobertura da tela).
func screen_area() -> float:
	var area := 0.0
	for i: int in range(CAPACITY):
		if _life[i] > 0.0:
			var r := _rect(i)
			area += r.x * r.y
	return area


func step(delta: float) -> void:
	rate = lerpf(rate, _attempts / maxf(delta, 0.001), clampf(delta / DamagePalette.RATE_SMOOTH, 0.0, 1.0))
	_attempts = 0
	if not lock_pressure:
		pressure = DamagePalette.next_pressure(pressure, DamagePalette.raw_pressure(enemies, rate), delta)
		level = DamagePalette.next_level(pressure, level)
	for i: int in range(CAPACITY):
		if _life[i] <= 0.0:
			continue
		_age[i] += delta
		if _age[i] >= _life[i]:
			_life[i] = 0.0
			live -= 1
			live_kind[_kind[i]] -= 1
	queue_redraw()


# --- Criação ------------------------------------------------------------------------------

## Golpe comum/contínuo no mesmo inimigo dentro da janela: soma, cresce e renova a vida.
## Comum: a menos de MERGE_WINDOW do último golpe (até MERGE_MAX_AGE); contínuo: por
## DOT_MERGE_WINDOW desde o primeiro tique (soma por alvo por segundo).
func _merge(amount: float, kind: int, target: int) -> bool:
	if target < 0 or target >= EnemyManager.CAPACITY:
		return false
	var map: PackedInt32Array
	if kind == DamagePalette.Kind.HIT:
		map = _merge_hit
	elif kind == DamagePalette.Kind.DOT:
		map = _merge_dot
	else:
		return false
	var i := map[target] - 1
	if i < 0 or _life[i] <= 0.0 or _kind[i] != kind or _target[i] != target:
		return false
	if kind == DamagePalette.Kind.DOT:
		if _age[i] > DamagePalette.DOT_MERGE_WINDOW:
			return false
	elif _age[i] - _last[i] > DamagePalette.MERGE_WINDOW or _age[i] > DamagePalette.MERGE_MAX_AGE:
		return false
	_amount[i] += amount
	_last[i] = _age[i]
	_life[i] = maxf(_life[i], _age[i] + float(DamagePalette.NORMAL[kind]["life"]) * DamagePalette.level_life(kind, level))
	_set_text(i)
	events += 1
	_last_slot = i
	return true


## Com pressão: número do mesmo tipo, perto e de valor parecido, vira "×N" num vivo recente.
func _fold(at: Vector2, amount: float, kind: int) -> bool:
	for k: int in range(_recent.size()):
		var j := _recent[k]
		if j < 0 or _life[j] <= 0.0 or _kind[j] != kind:
			continue
		if DamagePalette.should_fold(kind, level, _pos[j].distance_to(at), _amount[j], amount):
			_count[j] += 1
			folded += 1
			events += 1
			_last_slot = j
			return true
	return false


func _set_text(i: int) -> void:
	var kind := int(_kind[i])
	_step[i] = DamagePalette.size_step(kind, _amount[i], _ref[i])
	_size[i] = DamagePalette.number_size(kind, _step[i], level)
	_text[i] = DamagePalette.text(kind, _amount[i], _decimal)
	if _size[i] == 0:
		_half[i] = float(_text[i].length() * MICRO_ADVANCE - 1) * 0.5
	elif _font:
		_half[i] = roundf(_font.get_string_size(_text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, _size[i]).x * 0.5)


## Caixa (largura, altura) do número `i` na tela, com contorno.
func _rect(i: int) -> Vector2:
	if _size[i] == 0:
		return Vector2(_half[i] * 2.0 + 2.0, float(MICRO_CELL.y))
	var px := float(_palette[_kind[i]]["outline_px"])
	return Vector2(_half[i] * 2.0 + px * 2.0, float(_size[i]) + px)


## Lugar cheio: LOCAL_MAX números recentes e vivos, de prioridade igual ou maior, a menos de
## LOCAL_RADIUS px de `at`. Um crítico ainda aparece no meio de comuns, mas não empilha com outros.
func _crowded(at: Vector2, priority: int) -> bool:
	var near := 0
	var r2 := DamagePalette.LOCAL_RADIUS * DamagePalette.LOCAL_RADIUS
	for k: int in range(_recent.size()):
		var j := _recent[k]
		if j < 0 or _life[j] <= 0.0 or DamagePalette.priority(_kind[j]) < priority:
			continue
		if _pos[j].distance_squared_to(at) < r2:
			near += 1
	return near >= DamagePalette.LOCAL_MAX


## Críticos ainda no HOLD/SLAM grande entre os recentes (o crítico é raro: os recentes bastam).
func _big_crits() -> int:
	var n := 0
	for k: int in range(_recent.size()):
		var j := _recent[k]
		if j >= 0 and _life[j] > 0.0 and _big[j] == 1 and _age[j] < DamagePalette.CRIT_SLAM_END:
			n += 1
	return n


## Tela cheia: tira o vivo de menor prioridade (o mais velho no empate), se não for mais
## importante que o novo. O comum/contínuo novo nem procura: é descartado.
func _evict(priority: int) -> bool:
	if priority == 0:
		return false
	var victim := -1
	var best_priority := 99
	var best_age := -1.0
	for i: int in range(CAPACITY):
		if _life[i] <= 0.0:
			continue
		var p := DamagePalette.priority(_kind[i])
		var aged := _age[i] / _life[i]
		if p < best_priority or (p == best_priority and aged > best_age):
			victim = i
			best_priority = p
			best_age = aged
	if victim < 0 or best_priority > priority:
		return false
	_life[victim] = 0.0
	live -= 1
	live_kind[_kind[victim]] -= 1
	return true


func _free_slot() -> int:
	for k: int in range(CAPACITY):
		var i := (_next + k) % CAPACITY
		if _life[i] <= 0.0:
			_next = (i + 1) % CAPACITY
			return i
	_next = (_next + 1) % CAPACITY
	return _next


## Afasta de números recentes no mesmo lugar e tira o dano dos inimigos de cima da guardiã.
func _place(at: Vector2, kind: int) -> Vector2:
	if DamagePalette.is_enemy(kind) and guard != Vector2.INF:
		var d := at - guard
		var clear := DamagePalette.GUARD_CLEAR
		if absf(d.x) < clear.x and d.y > -clear.y and d.y < 4.0:
			at.x = guard.x + (clear.x if d.x >= 0.0 else -clear.x)
	for k: int in range(_recent.size()):
		var j := _recent[k]
		if j < 0 or _life[j] <= 0.0 or _age[j] > 0.3:
			continue
		var o := _pos[j]
		if absf(o.x - at.x) < 12.0 and absf(o.y - at.y) < DamagePalette.SPREAD_PX:
			at.y = o.y - DamagePalette.SPREAD_PX
	return at


# --- Desenho ------------------------------------------------------------------------------

func _draw() -> void:
	if live <= 0:
		return
	# Faixa da HUD em coordenadas do mundo (a camada segue a câmera).
	var ct := get_viewport().get_canvas_transform()
	var hud_y := (ct.affine_inverse() * Vector2(0.0, DamagePalette.HUD_TOP)).y
	for i: int in range(CAPACITY):
		if _life[i] > 0.0:
			_draw_number(i, hud_y)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_number(i: int, hud_y: float) -> void:
	var kind := int(_kind[i])
	var s: Dictionary = _palette[kind]
	var age := _age[i]
	var anim := int(s["anim"])
	var crit := anim == DamagePalette.Anim.CRIT
	var m := DamagePalette.motion(kind, age, _life[i], _colorblind)
	if crit:
		m = DamagePalette.crit_motion(age, _step[i], _big[i] == 1)
	var base := int(_size[i])
	var size := base
	if base > 0 and not low and DamagePalette.pop_steps(anim, age) > 0:
		size = DamagePalette.LADDER[mini(DamagePalette.LADDER.find(base) + 1, DamagePalette.LADDER.size() - 1)]
	var at := _pos[i] + Vector2(0.0, m.z)
	var shake := float(s["shake"])
	if shake > 0.0 and not low and age < DamagePalette.SHAKE_TIME:
		at.x += sin(age * 90.0) * shake * (1.0 - age / DamagePalette.SHAKE_TIME)
	at.y = maxf(at.y, hud_y + maxi(size, MICRO_CELL.y))
	at = at.round()
	var fill: Color = s["fill"]
	if crit:
		_draw_crit_fx(i, at, age, size)
		fill = fill.lerp(Color.WHITE, DamagePalette.crit_flash(age))
		if m.x <= 0.0:
			return
	var alpha := m.w
	var outline := Color(s["outline"], alpha)
	fill.a = alpha
	if base == 0:
		var left := Vector2(at.x - roundf(_half[i]), at.y - 3.0)
		var right := _draw_micro(_text[i], -1, left, fill, outline)
		if _count[i] > 1:
			_draw_micro("x", _count[i], right + Vector2(1.0, 0.0), Color(fill, alpha * 0.85), outline)
		return
	var half := _half[i] * float(size) / float(base)
	draw_set_transform(at, m.y, Vector2(m.x, m.x))
	var origin := Vector2(-roundf(half), roundf(size * 0.35))
	var px := int(s["outline_px"])
	draw_string_outline(_font, origin, _text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size, px, outline)
	if bool(s["bold"]):
		draw_string_outline(_font, origin + Vector2.RIGHT, _text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size, px, outline)
		draw_string(_font, origin + Vector2.RIGHT, _text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size, fill)
	draw_string(_font, origin, _text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size, fill)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _count[i] > 1:
		_draw_micro("x", _count[i], Vector2(at.x + roundf(half) + 2.0, at.y + roundf(size * 0.35) - 5.0),
				Color(fill, alpha * 0.85), outline)


## Texto em dígitos 3×5 com o canto de cima à esquerda em `left` (depois, `number` em dígitos,
## se ≥ 0, sem montar String). Contornos primeiro, preenchimentos por cima. Devolve o fim.
func _draw_micro(text: String, number: int, left: Vector2, fill: Color, outline: Color) -> Vector2:
	var end := left
	for pass_index: int in range(2):
		var pass_fill := pass_index == 1
		var x := left.x
		for k: int in range(text.length()):
			x = _micro_glyph(text.unicode_at(k), Vector2(x, left.y), fill if pass_fill else outline, pass_fill)
		if number >= 0:
			var digits := 1
			var probe := number
			while probe >= 10:
				probe /= 10
				digits += 1
			var div := int(pow(10.0, digits - 1))
			for _d: int in range(digits):
				x = _micro_glyph(48 + (number / div) % 10, Vector2(x, left.y), fill if pass_fill else outline, pass_fill)
				div = maxi(1, div / 10)
		end = Vector2(x, left.y)
	return end


func _micro_glyph(code: int, at: Vector2, color: Color, fill: bool) -> float:
	var g := _micro_map[code] if code >= 0 and code < _micro_map.size() else -1
	if g >= 0:
		var src := Rect2(g * MICRO_CELL.x, 0, MICRO_CELL.x, MICRO_CELL.y)
		draw_texture_rect_region(_micro_fill if fill else _micro_line,
				Rect2(at - Vector2.ONE, Vector2(MICRO_CELL)), src, color)
	return at.x + MICRO_ADVANCE


## Efeitos do crítico (desenhados atrás do número): brilho do HOLD, risco diagonal de katana,
## faíscas radiais, anel de choque e estilhaços. Na Baixa e no crítico "mini" só o brilho e o risco.
func _draw_crit_fx(i: int, at: Vector2, age: float, size: int) -> void:
	var fill: Color = _palette[_kind[i]]["fill"]
	if age < DamagePalette.CRIT_HOLD:
		var k := age / DamagePalette.CRIT_HOLD
		draw_rect(Rect2(at - Vector2(1, 4 + 4 * k), Vector2(2, 8 + 8 * k)), Color(1, 1, 1, 0.9))
		draw_rect(Rect2(at - Vector2(4 + 4 * k, 1), Vector2(8 + 8 * k, 2)), Color(1, 1, 1, 0.9))
		return
	var t := age - DamagePalette.CRIT_HOLD
	# Risco da katana: do alto-direita ao baixo-esquerda, abre rápido e afina.
	if t < 0.3:
		var reach := minf(1.0, t / 0.08) * (_half[i] + 14.0 + size * 0.5)
		var dir := Vector2(1.0, -0.55).normalized()
		var w := maxf(1.0, roundf(4.0 * (1.0 - t / 0.3)))
		var a := 1.0 - t / 0.3
		draw_line(at - dir * reach, at + dir * reach, Color(fill.lerp(Color.WHITE, 0.4), a), w + 2.0)
		draw_line(at - dir * reach, at + dir * reach, Color(1, 1, 1, a), w)
	if low or _big[i] == 0:
		return
	if t < 0.25:
		var k := t / 0.25
		var r := 4.0 + 18.0 * (1.0 - (1.0 - k) * (1.0 - k))
		draw_arc(at, r, 0.0, TAU, 20, Color(fill, 0.8 * (1.0 - k)), 2.0)
		var spin := float(i) * 0.7
		for ray: int in range(CRIT_RAYS):
			var d := Vector2.from_angle(spin + TAU * ray / CRIT_RAYS)
			draw_line((at + d * r * 0.7).round(), (at + d * (r + 5.0)).round(), Color(1.0, 0.95, 0.8, 1.0 - k), 1.0)
	if age > DamagePalette.CRIT_HANG_END:
		var st := age - DamagePalette.CRIT_HANG_END
		var a := 1.0 - st / (DamagePalette.CRIT_LIFE - DamagePalette.CRIT_HANG_END)
		for k: int in range(SHARDS.size()):
			var v: Vector2 = (SHARDS[k] as Vector2).rotated(float(i) * 0.37)
			var p := at + v * st + Vector2(0.0, 0.5 * SHARD_GRAVITY * st * st)
			draw_rect(Rect2(p.round() - Vector2.ONE, Vector2(4, 4)), Color(0.1, 0.0, 0.03, a))
			draw_rect(Rect2(p.round(), Vector2(2, 2)), Color(fill.lerp(Color.WHITE, 0.45), a))


## Monta uma vez o atlas dos dígitos 3×5 (preenchimento e contorno de 1 px, brancos).
static func _build_micro() -> void:
	if _micro_fill != null:
		return
	var n := MICRO_CHARS.length()
	var fill := Image.create_empty(MICRO_CELL.x * n, MICRO_CELL.y, false, Image.FORMAT_RGBA8)
	var line := Image.create_empty(MICRO_CELL.x * n, MICRO_CELL.y, false, Image.FORMAT_RGBA8)
	_micro_map.resize(128)
	_micro_map.fill(-1)
	for g: int in range(n):
		_micro_map[MICRO_CHARS.unicode_at(g)] = g
		var rows: Array = MICRO_ROWS[g]
		for r: int in range(5):
			for c: int in range(3):
				if (int(rows[r]) >> (2 - c)) & 1 == 0:
					continue
				var x := g * MICRO_CELL.x + 1 + c
				fill.set_pixel(x, 1 + r, Color.WHITE)
				for dy: int in range(-1, 2):
					for dx: int in range(-1, 2):
						line.set_pixel(x + dx, 1 + r + dy, Color.WHITE)
	_micro_fill = ImageTexture.create_from_image(fill)
	_micro_line = ImageTexture.create_from_image(line)
