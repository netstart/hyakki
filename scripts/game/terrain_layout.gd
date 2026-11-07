class_name TerrainLayout
extends RefCounted
## Composição dos chunks de cada bioma (data/biomes.json "layout"): vila com ruas e quarteirões,
## bambuzal com trilha, templo com avenida e santuários, dunas de cinza com ruínas, Yomi com
## rochas e lava, Encosta dos Mortos com escadaria, Osorezan (恐山) com o rio Sanzu e as margens
## de pedras empilhadas, Tokoyo (常世) com o santuário de luz da batalha final. Tudo é função pura
## da semente e do chunk.
##
## generate(c) devolve o que tem jogabilidade ou estrutura (obstáculos sólidos, casas, ruas) e é
## igual em qualquer nível gráfico. scatter(c) devolve a decoração orgânica SEM colisão (tufos,
## flores, folhas, pedrinhas); cada item tem um "rank" em [0, 1) e quem desenha guarda só os
## itens com rank < densidade (decor_density / máximo), então Baixa é um subconjunto da Alta.
##
## Item: {"s": sprite, "p": base (centro de baixo), "solid": raio, "sway": 0..1, "layer":
## "auto"|"flat"|"decor"|"canopy", "shadow": largura, "light": [cor, raio, força, dy] ou [],
## "rank": -1 (sempre) ou [0, 1), "tone": 0..1 (0.5 neutro)}.
## Pintura da máscara: ["rect", canal, Rect2, 0] | ["circle", canal, centro, raio] |
## ["line", canal, a, b, largura]. Canais: 0 = caminho (R), 1 = calçamento (G), 2 = especial (B).

const CHUNK := 256.0
const SAFE_RADIUS := 90.0
const STREET_HALF := 18.0
const TORO_LIGHT := ["#ffb35c", 54.0, 0.7, -20.0]
const SPIRIT_LIGHT := ["#86b4ff", 56.0, 0.8, -20.0]
const EMBER_LIGHT := ["#ff7a30", 34.0, 0.55, -4.0]
const HOUSES := ["house_orange", "house_beige", "house_orange2", "house_wood", "shop_blue", "izakaya",
		"house_round", "house_redtile"]
const VILLAGE_TREES := ["tree_round", "tree_green", "big_green", "sakura", "tree_round", "green_cluster",
		"round_cluster", "tree_yellow"]
const YARD := ["barrel", "barrel_open", "barrel_b", "basket_fish", "basket_veg", "basket_fruit", "pot",
		"bucket", "hay_bale", "hay_round", "pumpkin"]
## Margem da borda da área jogável onde nada sólido nasce (px), nos layouts comuns.
const EDGE_MARGIN := 12.0

## Tokoyo (常世): arena limitada com o santuário na origem (veja _toko_plan). Metade da arena quando
## a fase não dá limites (as fases dão bounds no bloco "tokoyo" de data/stages.json).
const TOKO_HALF := 1200.0
## Praça: calçamento (canal G) até TOKO_PLAZA_R, anel de pedra (canal R) até TOKO_PLAZA_RIM;
## nenhum sólido a menos de TOKO_CLEAR_R da origem (luta do último chefe e nascimento da guardiã).
const TOKO_PLAZA_R := 152.0
const TOKO_PLAZA_RIM := 170.0
## Desenho do calçamento: disco do meio até TOKO_PLAZA_CORE, um friso de pedra de TOKO_PLAZA_INLAY px
## e a coroa até TOKO_PLAZA_R, feita de TOKO_PLAZA_PETALS círculos (borda em pétalas).
const TOKO_PLAZA_CORE := 52.0
const TOKO_PLAZA_INLAY := 18.0
const TOKO_PLAZA_PETALS := 24
const TOKO_CLEAR_R := 118.0
## Anel de tōrō na borda da praça, fora dos eixos das entradas (ângulos de 15° + 30° k).
const TOKO_TORO_R := 136.0
const TOKO_TORO_COUNT := 12
## Caminhos sagrados cardeais: meia largura, faixa central calçada e os portões (torii na entrada
## e mais TOKO_TUNNEL em corredor, como o senbon torii), a cada TOKO_TUNNEL_STEP px.
const TOKO_PATH_HALF := 22.0
const TOKO_INLAY_HALF := 6.0
const TOKO_GATE_R := 196.0
const TOKO_TUNNEL := 3
const TOKO_TUNNEL_STEP := 46.0
## Lanternas dos dois lados dos caminhos, a cada TOKO_LAMP_STEP px depois do corredor.
const TOKO_LAMP_STEP := 120.0
const TOKO_LAMP_SIDE := 14.0
## Caminhos diagonais (da praça ao anel) e o anel de pedra, em fração da metade da arena.
const TOKO_DIAG_HALF := 10.0
const TOKO_RING_K := 0.55
const TOKO_RING_HALF := 12.0
const TOKO_RING_SEGMENTS := 64
## Espelhos d'água: um em cada setor entre os caminhos, por dentro e por fora do anel; os de
## dentro com índice par têm uma ilha com a árvore sagrada (fosso de TOKO_MOAT círculos).
const TOKO_POND_SECTORS := 8
const TOKO_POND_GAP := 20.0
const TOKO_MOAT := 10
## Moldura: nada sólido a menos de TOKO_EDGE_CLEAR px do limite; meio-fio de pedra por dentro e
## pilares e rochedos (só visuais) por fora.
const TOKO_EDGE_CLEAR := 44.0
const TOKO_CURB := 20.0
## Luz das lanternas do Tokoyo quando o bioma não dá "toko.light".
const TOKO_LIGHT := ["#ffe2a0", 58.0, 0.75, -20.0]
## Torii de lado (gen_torii_side, terrain_art.gd) nos caminhos leste-oeste: distância entre os
## pés dos dois pilares, no chão (px); como no torii de frente, os pilares ficam dentro do caminho.
const TORII_SIDE_SPAN := 30.0
## Osorezan: o rio Sanzu corre de oeste a leste ao sul do início. Linha do meio em SANZU_Y px com
## duas ondas de seno (amplitudes SANZU_WAVE), meia largura SANZU_HALF (só água no canal B, sem
## colisão: dá para atravessar a vau) e as margens de pedra até SANZU_BANK px do meio.
const SANZU_Y := 236.0
const SANZU_WAVE := Vector2(68.0, 16.0)
const SANZU_HALF := 26.0
const SANZU_BANK := 58.0
## Passo das amostras do rio e das lanternas da margem norte (px).
const SANZU_STEP := 24.0
const SANZU_LAMP_STEP := 192.0
## Torii da travessia: um a cada SANZU_GATE_EVERY chunks, na margem norte.
const SANZU_GATE_EVERY := 3
const JIZO := ["jizo_a", "jizo_b", "jizo_c"]
const CAIRNS := ["cairn_s", "cairn_m", "cairn_s", "cairn_l"]
const PINWHEELS := ["kazaguruma_a", "kazaguruma_b", "kazaguruma_a", "kazaguruma_pile"]

var seed_value: int = 0
var stage_id: String = ""
var biome: Dictionary = {}
var kind: String = "village"
## Metade da área jogável (0 = sem limite), como no WorldMap.
var bounds := Vector2.ZERO
var noise_offset := Vector2.ZERO
var scales := Vector2(0.012, 0.018)
## Margem da borda onde nada sólido nasce (EDGE_MARGIN ou TOKO_EDGE_CLEAR).
var edge_margin := EDGE_MARGIN

var _rng := RandomNumberGenerator.new()
var _origin := Vector2.ZERO
var _items: Array = []
var _solids: Array = []
var _paint: Array = []
## Áreas ocupadas: [centro, raio] (sólidos, reservas de jogabilidade e estruturas).
var _taken: Array = []
## Faixas onde nada sólido pode ficar (ruas, trilhas, praças).
var _keepout: Array[Rect2] = []
## Plano fixo do Tokoyo (cacheado por semente): {"paint", "items", "taken", "keepout"}.
var _toko: Dictionary = {}


func setup(p_seed: int, p_stage_id: String, p_biome: Dictionary, p_bounds: Vector2) -> void:
	seed_value = p_seed
	stage_id = p_stage_id
	biome = p_biome
	kind = String(biome.get("layout", "village"))
	bounds = p_bounds
	noise_offset = TerrainNoise.offset_for(p_seed)
	var s: Array = biome.get("scales", [0.012, 0.018])
	scales = Vector2(float(s[0]), float(s[1]))
	edge_margin = TOKO_EDGE_CLEAR if kind == "tokoyo" else EDGE_MARGIN
	_toko = {}


## Estrutura determinística do chunk. `reserved`: círculos [pos, raio] já usados pela
## jogabilidade (lanternas, estátuas, lava), que a decoração sólida evita.
func generate(c: Vector2i, reserved: Array) -> Dictionary:
	_rng.seed = hash([seed_value, c.x, c.y, stage_id, "layout"])
	_origin = Vector2(c.x * CHUNK, c.y * CHUNK)
	_items = []
	_solids = []
	_paint = []
	_taken = reserved.duplicate()
	_keepout = []
	match kind:
		"village":
			_village(c)
		"bamboo":
			_bamboo(c)
		"temple":
			_temple(c)
		"dunes":
			_dunes(c)
		"yomi":
			_yomi(c)
		"secret":
			_secret(c)
		"osorezan":
			_osorezan(c)
		"tokoyo":
			_tokoyo(c)
	if kind == "tokoyo":
		_toko_frame()
	else:
		_edges()
	return {"items": _items, "solids": _solids, "paint": _paint, "keepout": _keepout}


# --- Utilitários ------------------------------------------------------------------------

func _item(sprite: String, p: Vector2, solid: float = 0.0, extra: Dictionary = {}) -> Dictionary:
	var size := TerrainArt.sprite_size(sprite)
	var it := {"s": sprite, "p": p.round(), "solid": solid, "sway": 0.0, "layer": "auto",
			"shadow": size.x * 0.8 if solid > 0.0 else 0.0, "light": [], "rank": -1.0,
			"tone": 0.5}
	it.merge(extra, true)
	return it


## Tenta pôr um item sólido: dentro do chunk (o sprite inteiro), fora da área segura, das ruas
## e longe do que já existe. Devolve se pôs.
func _place(sprite: String, p: Vector2, solid: float, extra: Dictionary = {}, gap: float = 4.0) -> bool:
	var size := TerrainArt.sprite_size(sprite)
	var foot := maxf(solid, size.x * 0.36)
	if not _fits(p, size):
		return false
	if solid > 0.0 and p.length() < SAFE_RADIUS + foot:
		return false
	if not _in_bounds(p, edge_margin):
		return false
	var box := Rect2(p - Vector2(size.x * 0.5, minf(size.y, 20.0)), Vector2(size.x, minf(size.y, 20.0)))
	for k: Rect2 in _keepout:
		if k.intersects(box):
			return false
	for t: Array in _taken:
		if (t[0] as Vector2).distance_to(p) < float(t[1]) + foot + gap:
			return false
	_taken.append([p, foot])
	_items.append(_item(sprite, p, solid, extra))
	if solid > 0.0:
		_add_solid(sprite, p, solid)
	return true


## Obstáculo do item: um círculo, ou uma fileira deles para casas largas.
func _add_solid(sprite: String, p: Vector2, solid: float) -> void:
	_solids.append_array(solid_circles(sprite, p, solid))


## Círculos [centro, raio] do obstáculo de um item com base em `p`.
static func solid_circles(sprite: String, p: Vector2, solid: float) -> Array:
	var w := TerrainArt.sprite_size(sprite).x
	var out: Array = []
	if w >= 48.0 and solid >= 14.0:
		var n := int(ceil(w / 26.0))
		var r := minf(solid, w / float(n) * 0.62)
		for k: int in range(n):
			var x := -w * 0.5 + (float(k) + 0.5) * w / float(n)
			out.append([p + Vector2(x, -r * 0.7), r])
	else:
		out.append([p + Vector2(0, -solid * 0.3), solid])
	return out


## Item sem colisão que ainda respeita o espaço (decoração estrutural: cercas, varais, escadas).
func _deco(sprite: String, p: Vector2, extra: Dictionary = {}) -> bool:
	var size := TerrainArt.sprite_size(sprite)
	if not _fits(p, size) or not _in_bounds(p, 6.0):
		return false
	var box := Rect2(p - Vector2(size.x * 0.5, minf(size.y, 12.0)), Vector2(size.x, minf(size.y, 12.0)))
	for k: Rect2 in _keepout:
		if k.intersects(box) and not bool(extra.get("on_road", false)):
			return false
	for t: Array in _taken:
		if (t[0] as Vector2).distance_to(p) < float(t[1]) + size.x * 0.3:
			return false
	_taken.append([p, size.x * 0.3])
	_items.append(_item(sprite, p, 0.0, extra))
	return true


func _fits(p: Vector2, size: Vector2) -> bool:
	return p.x - size.x * 0.5 >= _origin.x + 2.0 and p.x + size.x * 0.5 <= _origin.x + CHUNK - 2.0 \
			and p.y - size.y >= _origin.y + 2.0 and p.y <= _origin.y + CHUNK - 2.0


func _in_bounds(p: Vector2, margin: float) -> bool:
	if bounds.x > 0.0 and absf(p.x) > bounds.x - margin:
		return false
	if bounds.y > 0.0 and absf(p.y) > bounds.y - margin:
		return false
	return true


func _rand_in(margin: float = 16.0) -> Vector2:
	return _origin + Vector2(_rng.randf_range(margin, CHUNK - margin), _rng.randf_range(margin, CHUNK - margin))


func _pick(list: Array) -> String:
	return String(list[_rng.randi_range(0, list.size() - 1)])


func _row_hash(tag: String, v: int) -> int:
	return absi(hash([seed_value, stage_id, tag, v]))


## Bosque: árvores agrupadas ao redor de um centro, moitas na borda (sem colisão).
func _grove(center: Vector2, trees: Array, count: int, spread: float, bushes: Array = []) -> void:
	for k: int in range(count):
		var a := _rng.randf() * TAU
		var r := sqrt(_rng.randf()) * spread
		var p := center + Vector2(cos(a), sin(a) * 0.8) * r
		var t := _pick(trees)
		var size := TerrainArt.sprite_size(t)
		_place(t, p, clampf(size.x * 0.2, 6.0, 14.0), {"sway": 0.18, "tone": _rng.randf_range(0.42, 0.58)}, 0.0)
	for k: int in range(bushes.size() * 2 if not bushes.is_empty() else 0):
		var a := _rng.randf() * TAU
		var p := center + Vector2(cos(a), sin(a) * 0.8) * (spread + _rng.randf_range(4.0, 18.0))
		_deco(_pick(bushes), p, {"sway": 0.55, "shadow": 10.0, "tone": _rng.randf_range(0.4, 0.6)})


# --- Vila ---------------------------------------------------------------------------------

func _street_row(cy: int) -> bool:
	return cy == 0 or _row_hash("row", cy) % 5 < 3


func _street_col(cx: int) -> bool:
	return cx == -1 or _row_hash("col", cx) % 5 < 2


func _village(c: Vector2i) -> void:
	var hy := _origin.y + 128.0
	var vx := _origin.x + 128.0
	var has_h := _street_row(c.y)
	var has_v := _street_col(c.x)
	var town := (has_h or has_v) and TerrainNoise.value(c.x * 0.43 + noise_offset.x, c.y * 0.43 + noise_offset.y) > 0.42
	var pad := 8.0
	if has_h:
		_paint.append(["rect", 0, Rect2(_origin.x - pad, hy - STREET_HALF, CHUNK + pad * 2.0, STREET_HALF * 2.0), 0])
		_keepout.append(Rect2(_origin.x - pad, hy - STREET_HALF - 2.0, CHUNK + pad * 2.0, STREET_HALF * 2.0 + 4.0))
		if town:
			_paint.append(["rect", 1, Rect2(_origin.x - pad, hy - 7.0, CHUNK + pad * 2.0, 14.0), 0])
	if has_v:
		_paint.append(["rect", 0, Rect2(vx - STREET_HALF, _origin.y - pad, STREET_HALF * 2.0, CHUNK + pad * 2.0), 0])
		_keepout.append(Rect2(vx - STREET_HALF - 2.0, _origin.y - pad, STREET_HALF * 2.0 + 4.0, CHUNK + pad * 2.0))
		if town:
			_paint.append(["rect", 1, Rect2(vx - 7.0, _origin.y - pad, 14.0, CHUNK + pad * 2.0), 0])
	if has_h and has_v and town:
		# Praça no cruzamento: calçamento redondo, poço no meio e lanternas de pedra.
		_paint.append(["circle", 1, Vector2(vx, hy), 46.0])
		_keepout.append(Rect2(vx - 50.0, hy - 50.0, 100.0, 100.0))
		var well := Vector2(vx + 30.0, hy + 34.0)
		_place("well", well, 12.0, {}, 0.0)
		for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1)]:
			_place("toro", Vector2(vx, hy) + corner * 40.0 + Vector2(0, 14), 5.0, {"light": TORO_LIGHT}, 0.0)
	if town:
		if has_h:
			_house_row(hy - STREET_HALF - 4.0, has_v, vx, true)
			_house_row(hy + STREET_HALF + 52.0, has_v, vx, false)
		if has_v and not has_h:
			_house_column(vx - STREET_HALF - 4.0, -1.0)
			_house_column(vx + STREET_HALF + 4.0, 1.0)
		if has_v and has_h:
			_house_column(vx - STREET_HALF - 4.0, -1.0)
			_house_column(vx + STREET_HALF + 4.0, 1.0)
		_backyards()
	else:
		_countryside(c, has_h or has_v)


## Fileira de casas ao longo de uma rua horizontal; `base_y` é a base das casas.
func _house_row(base_y: float, has_v: bool, vx: float, north: bool) -> void:
	var x := _origin.x + _rng.randf_range(6.0, 24.0)
	while x < _origin.x + CHUNK - 30.0:
		var h := _pick(HOUSES)
		var w := TerrainArt.sprite_size(h).x
		var center := x + w * 0.5
		if has_v and absf(center - vx) < w * 0.5 + STREET_HALF + 6.0:
			x = vx + STREET_HALF + 6.0
			continue
		if _rng.randf() < 0.3:
			# Terreno vago entre as casas: a rua respira (jardim, árvore ou nada).
			if _rng.randf() < 0.5:
				_place(_pick(VILLAGE_TREES), Vector2(center, base_y - (0.0 if north else 10.0)), 8.0, {"sway": 0.18})
			x += w * 0.8 + _rng.randf_range(16.0, 40.0)
			continue
		if _place(h, Vector2(center, base_y), 22.0, {"shadow": w * 0.95, "tone": _rng.randf_range(0.45, 0.55)}, 0.0):
			x += w + _rng.randf_range(26.0, 52.0)
			# Entre as casas: lanterna de pedra, barris ou cesto junto à rua.
			var gap_x := x - _rng.randf_range(5.0, 9.0)
			var roll := _rng.randf()
			var front := base_y + (2.0 if north else -50.0)
			if roll < 0.35:
				_place("toro", Vector2(gap_x, base_y - 2.0), 5.0, {"light": TORO_LIGHT}, 0.0)
			elif roll < 0.75:
				_deco(_pick(YARD), Vector2(gap_x, front if north else base_y - 4.0), {"shadow": 12.0})
		else:
			x += 14.0


func _house_column(edge_x: float, side: float) -> void:
	var y := _origin.y + _rng.randf_range(54.0, 70.0)
	while y < _origin.y + CHUNK - 4.0:
		var h := _pick(HOUSES)
		var size := TerrainArt.sprite_size(h)
		var p := Vector2(edge_x + side * size.x * 0.5, y)
		if _rng.randf() < 0.3:
			y += size.y * 0.7 + 20.0
			continue
		if _place(h, p, 22.0, {"shadow": size.x * 0.95}, 0.0):
			y += size.y + _rng.randf_range(30.0, 52.0)
			if _rng.randf() < 0.5:
				_place("toro", Vector2(edge_x + side * 6.0, y - 6.0), 5.0, {"light": TORO_LIGHT}, 0.0)
		else:
			y += 18.0


## Quintais: varais, carroças, feno, árvores e cercas no espaço que sobrou.
func _backyards() -> void:
	for k: int in range(6):
		var p := _rand_in(20.0)
		var roll := _rng.randf()
		if roll < 0.18:
			_place("laundry", p, 0.0, {"sway": 0.25})
		elif roll < 0.32:
			_place(_pick(["cart", "cart_loaded"]), p, 10.0)
		elif roll < 0.55:
			_place(_pick(VILLAGE_TREES), p, 8.0, {"sway": 0.18})
		elif roll < 0.7:
			_place("hay_bale", p, 6.0)
		elif roll < 0.8:
			_place("notice_board", p, 10.0)
		else:
			_deco(_pick(YARD), p, {"shadow": 12.0})


## Campo: bosques, pedras, um pequeno santuário com torii às vezes.
func _countryside(c: Vector2i, roads: bool) -> void:
	var groves := _rng.randi_range(1, 3)
	for k: int in range(groves):
		_grove(_rand_in(50.0), VILLAGE_TREES, _rng.randi_range(3, 6), _rng.randf_range(26.0, 44.0),
				["bush_a", "bush_b", "bush_d", "bush_e"])
	if _rng.randf() < 0.3 and not roads:
		_shrine(_origin + Vector2(128, 150))
	for k: int in range(3):
		_place(_pick(["rock_brown", "rock_gray", "stump_big", "rock_gray_s", "log_small", "hay_round"]),
				_rand_in(16.0), 6.0)
	if _rng.randf() < 0.4:
		_place(_pick(["cart", "hay_bale"]), _rand_in(30.0), 8.0)
	if c == Vector2i.ZERO:
		_place("toro", Vector2(60, 70), 5.0, {"light": TORO_LIGHT})


## Santuário: torii na frente, lanternas, estátuas de raposa e o salão atrás.
func _shrine(front: Vector2) -> void:
	_paint.append(["rect", 1, Rect2(front.x - 40.0, front.y - 96.0, 80.0, 90.0), 0])
	_paint.append(["rect", 1, Rect2(front.x - 10.0, front.y - 10.0, 20.0, 60.0), 0])
	_place("house_redtile", front + Vector2(0, -56), 22.0, {"shadow": 66.0}, 0.0)
	_place("toro", front + Vector2(-30, -20), 5.0, {"light": TORO_LIGHT}, 0.0)
	_place("toro", front + Vector2(30, -20), 5.0, {"light": TORO_LIGHT}, 0.0)
	_place("fox_statue", front + Vector2(-22, 8), 5.0, {}, 0.0)
	_place("fox_statue", front + Vector2(22, 8), 5.0, {}, 0.0)
	_torii(front + Vector2(0, 40))


## Torii: só os dois pilares têm colisão (dá para passar por baixo).
func _torii(p: Vector2) -> void:
	if not _deco("torii", p, {"shadow": 0.0}):
		return
	for side: float in [-1.0, 1.0]:
		_solids.append([p + Vector2(side * 17.0, -3.0), 4.0])


# --- Bambuzal -----------------------------------------------------------------------------

func _trail_y(x: float, row: int) -> float:
	return row * CHUNK + 128.0 + sin(x * 0.012 + row * 1.7) * 46.0 + sin(x * 0.031) * 12.0


func _bamboo(c: Vector2i) -> void:
	var trail := c.y % 2 == 0
	if trail:
		var prev := Vector2(_origin.x - 12.0, _trail_y(_origin.x - 12.0, c.y))
		for k: int in range(1, 10):
			var x := _origin.x - 12.0 + k * 31.0
			var cur := Vector2(x, _trail_y(x, c.y))
			_paint.append(["line", 0, prev, cur, 13.0])
			_keepout.append(Rect2(prev - Vector2(4, 24), Vector2(35, 48)))
			prev = cur
		if _rng.randf() < 0.6:
			var x := _origin.x + _rng.randf_range(40.0, 216.0)
			_place("toro", Vector2(x, _trail_y(x, c.y) - 22.0), 5.0, {"light": TORO_LIGHT}, 0.0)
	# Touceiras densas onde o ruído largo é alto; clareiras no resto.
	var cell := 27.0
	for gy: int in range(int(CHUNK / cell)):
		for gx: int in range(int(CHUNK / cell)):
			var p := _origin + Vector2((gx + 0.5) * cell, (gy + 0.5) * cell) \
					+ Vector2(_rng.randf_range(-6, 6), _rng.randf_range(-6, 6))
			var d := TerrainNoise.fbm(p.x * 0.006 + noise_offset.y, p.y * 0.006 + noise_offset.x)
			var roll := _rng.randf()
			if d > 0.5 and roll < 0.7:
				_bamboo_clump(p)
			elif roll < 0.05:
				_place(_pick(["log_fallen", "log_fallen_moss", "stump", "rock_gray_s", "fox_statue"]), p, 6.0)


func _bamboo_clump(p: Vector2) -> void:
	# Touceira: um obstáculo e 2 a 4 colmos altos; a base fica com os atores, o resto (a maior
	# parte) na frente deles, balançando e abrindo o buraco do herói.
	if not _place("gen_bamboo_a", p, 7.0, {"sway": 0.55, "shadow": 18.0, "tone": _rng.randf_range(0.4, 0.6)}, 2.0):
		return
	var culms := _rng.randi_range(1, 3)
	for k: int in range(culms):
		var q := p + Vector2(_rng.randf_range(-8, 8), _rng.randf_range(-4, 5))
		_items.append(_item(_pick(["gen_bamboo_a", "gen_bamboo_b", "gen_bamboo_c"]), q, 0.0,
				{"sway": _rng.randf_range(0.45, 0.8), "tone": _rng.randf_range(0.32, 0.62), "flip": _rng.randf() < 0.5}))


# --- Templo -------------------------------------------------------------------------------

func _temple(c: Vector2i) -> void:
	var avenue := absf(_origin.y + 128.0) < 200.0
	if c.y == -1 or c.y == 0:
		# Avenida de pedra lavrada em y = 0 com lanternas e cerejeiras nas margens.
		var band := Rect2(_origin.x - 8.0, -36.0, CHUNK + 16.0, 72.0)
		_paint.append(["rect", 1, band, 0])
		_keepout.append(band.grow(4.0))
		var step := 64.0
		var first := ceilf(_origin.x / step) * step
		var x := first
		while x < _origin.x + CHUNK:
			var odd := posmod(int(x / step), 2) == 1
			var y := -50.0 if c.y == -1 else 70.0
			if odd:
				_place("toro", Vector2(x, y), 5.0, {"light": TORO_LIGHT}, 0.0)
			else:
				_place(_pick(["sakura", "sakura", "big_sakura"]), Vector2(x, y + (6.0 if c.y == 0 else -4.0)), 8.0,
						{"sway": 0.2}, 0.0)
			x += step
		if c.y == -1 and _rng.randf() < 0.55:
			_courtyard(Vector2(_origin.x + 128.0, -64.0), -1.0)
		elif c.y == 0 and _rng.randf() < 0.45:
			_courtyard(Vector2(_origin.x + 128.0, 90.0), 1.0)
	elif not avenue:
		var roll := _rng.randf()
		if roll < 0.4:
			_courtyard(_origin + Vector2(128, 200), -1.0)
		elif roll < 0.7:
			_rock_garden(_origin + Vector2(128, 128))
		_grove(_rand_in(48.0), ["sakura", "big_sakura", "sakura_cluster", "pine"], _rng.randi_range(2, 4), 34.0,
				["bush_a", "bush_b"])
	for k: int in range(2):
		_place(_pick(["pillar", "pillar_block", "buddha", "frog_statue", "ninja_statue"]), _rand_in(24.0), 7.0)


## Pátio de santuário: calçamento, escadaria até a avenida, torii, salão e lanternas.
## `dir` = -1 para o norte (salão acima da entrada), 1 para o sul.
func _courtyard(entry: Vector2, dir: float) -> void:
	var hall := entry + Vector2(0, dir * 92.0 + (0.0 if dir < 0.0 else 52.0))
	var yard := Rect2(entry.x - 56.0, minf(entry.y, hall.y - 60.0), 112.0, absf(hall.y - entry.y) + 70.0)
	yard = yard.intersection(Rect2(_origin, Vector2(CHUNK, CHUNK)).grow(-4.0))
	_paint.append(["rect", 1, yard, 0])
	_place(_pick(["house_redtile", "house_wood", "izakaya"]), hall, 22.0, {"shadow": 60.0}, 0.0)
	for side: float in [-1.0, 1.0]:
		_place("toro", hall + Vector2(side * 46.0, dir * -8.0 + 4.0), 5.0, {"light": TORO_LIGHT}, 0.0)
		_place(_pick(["fox_statue", "buddha", "lion_statue"]), entry + Vector2(side * 30.0, dir * 30.0 + 18.0), 6.0,
				{}, 0.0)
	# Escadaria: degraus no caminho entre a avenida e o pátio.
	for k: int in range(4):
		_items.append(_item("gen_step", entry + Vector2(0, dir * (4.0 + k * 9.0) + 18.0), 0.0, {"layer": "flat"}))
	_torii(entry + Vector2(0, dir * 52.0 + 18.0))


## Jardim de pedras (karesansui): areia penteada (canal R) com rochas e musgo.
func _rock_garden(center: Vector2) -> void:
	var r := Rect2(center - Vector2(70, 46), Vector2(140, 92))
	_paint.append(["rect", 0, r, 0])
	for k: int in range(_rng.randi_range(2, 4)):
		var p := r.position + Vector2(_rng.randf_range(20, r.size.x - 20), _rng.randf_range(24, r.size.y - 6))
		_place(_pick(["rock_gray", "boulder_gray", "rock_gray_s", "boulder_gray2"]), p, 9.0, {}, 6.0)


# --- Dunas de cinza -----------------------------------------------------------------------

func _dunes(_c: Vector2i) -> void:
	var roll := _rng.randf()
	if roll < 0.28:
		# Ruínas: piso antigo, pilares caídos e uma casa em pedaços.
		var center := _rand_in(70.0)
		_paint.append(["circle", 1, center, _rng.randf_range(44.0, 62.0)])
		_place(_pick(["ruin_house", "ruin_grave", "stone_arch"]), center + Vector2(0, -6), 18.0, {}, 0.0)
		for k: int in range(4):
			var a := _rng.randf() * TAU
			_place(_pick(["ruin_pillar", "pillar", "pillar_block", "ruin_rock", "ruin_statue"]),
					center + Vector2(cos(a), sin(a) * 0.7) * _rng.randf_range(40.0, 60.0), 6.0, {}, 0.0)
	elif roll < 0.55:
		# Rochedo de basalto com pedras soltas ao redor.
		var p := _rand_in(60.0)
		_place(_pick(["rocks_gray", "rockwall_gray", "boulder_gray", "rockpillar_gray"]), p, 24.0, {"tone": 0.42}, 0.0)
		for k: int in range(4):
			_place(_pick(["rocklet_g1", "rocklet_g2", "rock_gray_s", "rocklet_g3"]),
					p + Vector2(_rng.randf_range(-60, 60), _rng.randf_range(-20, 30)), 4.0, {"tone": 0.42})
	elif roll < 0.75:
		# Caravana perdida: carroça, barris e uma brasa ainda acesa.
		var p := _rand_in(50.0)
		_place(_pick(["cart", "cart_loaded"]), p, 10.0, {"tone": 0.4}, 0.0)
		_place("barrel", p + Vector2(28, 6), 6.0, {"tone": 0.4}, 0.0)
		_place("stump", p + Vector2(-30, 12), 5.0, {"light": EMBER_LIGHT, "tone": 0.3}, 0.0)
	for k: int in range(_rng.randi_range(2, 4)):
		_place(_pick(["dead_tree", "dead_tree", "stump_big", "stump_big2", "dead_cluster", "rockpillar_gray",
				"skull_horn", "rock_gray"]), _rand_in(24.0), 8.0, {"tone": _rng.randf_range(0.35, 0.5), "sway": 0.05})


# --- Yomi --------------------------------------------------------------------------------

func _yomi(_c: Vector2i) -> void:
	for k: int in range(_rng.randi_range(2, 4)):
		_place(_pick(["rockpillar_gray", "rocks_gray", "boulder_gray", "rockwall_gray", "boulder_gray2"]),
				_rand_in(36.0), 14.0, {"tone": 0.3})
	if _rng.randf() < 0.4:
		# Cemitério esquecido: lápides, uma lanterna de fogo-fátuo e ossos.
		var p := _rand_in(56.0)
		_place("toro", p, 5.0, {"light": SPIRIT_LIGHT, "tone": 0.4}, 0.0)
		for k: int in range(5):
			_place(_pick(["grave_a", "grave_b", "grave_cross", "pillar_moss"]),
					p + Vector2(_rng.randf_range(-50, 50), _rng.randf_range(-30, 40)), 4.0, {"tone": 0.38}, 2.0)
	if _rng.randf() < 0.35:
		_place(_pick(["statue_eye_moss", "buddha_moss", "frog_moss", "torii"]), _rand_in(40.0), 10.0, {"tone": 0.36})
	for k: int in range(2):
		_place(_pick(["dead_tree", "dead_cluster"]), _rand_in(30.0), 9.0, {"tone": 0.28, "sway": 0.05})


# --- Encosta dos Mortos ---------------------------------------------------------------------

func _secret(c: Vector2i) -> void:
	# Ladeira de pedra subindo para o norte em x = 0, com degraus e lanternas azuis.
	if c.x == -1 or c.x == 0:
		var band := Rect2(-26.0, _origin.y - 8.0, 52.0, CHUNK + 16.0)
		_paint.append(["rect", 1, band, 0])
		_keepout.append(band.grow(2.0))
		var y := _origin.y + 20.0
		while y < _origin.y + CHUNK - 4.0:
			if c.x == 0:
				for k: int in range(3):
					_items.append(_item("gen_step", Vector2(0, y + k * 8.0), 0.0, {"layer": "flat"}))
			y += 64.0
		var lamp_x := 40.0 if c.x == 0 else -40.0
		var ly := _origin.y + 40.0
		while ly < _origin.y + CHUNK:
			_place("toro", Vector2(lamp_x, ly), 5.0, {"light": SPIRIT_LIGHT}, 0.0)
			ly += 96.0
		if c.x == 0 and posmod(c.y, 3) == 0:
			_torii(Vector2(0, _origin.y + 200.0))
	var roll := _rng.randf()
	if roll < 0.35:
		# A Grande Pedra: rochedo enorme que sela a passagem.
		_place(_pick(["rockwall_gray", "rocks_gray", "boulder_blue"]), _rand_in(64.0), 26.0, {"tone": 0.45}, 0.0)
	elif roll < 0.6:
		_grove(_rand_in(56.0), ["big_autumn", "sakura", "big_sakura", "moss_tree"], _rng.randi_range(2, 4), 34.0,
				["bush_a", "bush_c"])
	for k: int in range(_rng.randi_range(2, 4)):
		_place(_pick(["dead_tree", "grave_a", "grave_b", "ruin_pillar", "ruin_statue", "statue_eye_moss",
				"rock_gray", "stump_big"]), _rand_in(24.0), 7.0, {"tone": 0.45})


# --- Osorezan -----------------------------------------------------------------------------

## Linha do meio do Sanzu na coluna `x` (fase das ondas tirada da semente).
func sanzu_y(x: float) -> float:
	var phase := float(_row_hash("sanzu", 0) % 6283) * 0.001
	return SANZU_Y + sin(x * 0.0061 + phase) * SANZU_WAVE.x + sin(x * 0.019 + phase * 2.0) * SANZU_WAVE.y


## Campos de enxofre com o rio Sanzu: a água no canal B (sem colisão), as margens de seixos com as
## pilhas de pedras das crianças (Sai no Kawara), cata-ventos e lanternas de fogo-fátuo na margem
## norte, um torii de travessia de vez em quando; fora do rio, rochas vulcânicas, fileiras de Jizō,
## bosques de sotoba e pinheiros mortos.
func _osorezan(c: Vector2i) -> void:
	var top := _origin.y - SANZU_BANK - SANZU_WAVE.x - SANZU_WAVE.y
	var bottom := _origin.y + CHUNK + SANZU_BANK
	if SANZU_Y + SANZU_WAVE.x + SANZU_WAVE.y > top and SANZU_Y - SANZU_WAVE.x - SANZU_WAVE.y < bottom:
		_sanzu(c)
	var roll := _rng.randf()
	if roll < 0.3:
		# Rochedo vulcânico com pedras soltas (o enxofre aflora em volta pelo espalhado).
		var p := _rand_in(56.0)
		if _place("volcanic_a", p, 13.0, {"tone": 0.45}, 0.0):
			for k: int in range(_rng.randi_range(2, 4)):
				_place(_pick(["volcanic_b", "volcanic_c"]), p + Vector2(_rng.randf_range(-44, 44),
						_rng.randf_range(-18, 26)), 5.0, {"tone": 0.45})
	elif roll < 0.5:
		# Fileira de Jizō de babador vermelho com uma lanterna de pedra na ponta.
		var p := _rand_in(60.0)
		var step := Vector2(18.0, 0.0)
		var n := _rng.randi_range(3, 5)
		var start := p - step * float(n - 1) * 0.5
		for k: int in range(n):
			_place(_pick(JIZO), start + step * float(k), 4.0, {"tone": 0.5}, 0.0)
		_place("lantern_old", start + step * float(n) + Vector2(4, 0), 5.0, {"light": SPIRIT_LIGHT}, 0.0)
	elif roll < 0.68:
		# Bosque de sotoba (tábuas de prece fincadas) em volta de uma pilha grande.
		var p := _rand_in(52.0)
		_place("cairn_l", p, 5.0, {}, 0.0)
		for k: int in range(_rng.randi_range(3, 6)):
			var a := _rng.randf() * TAU
			_place(_pick(["sotoba_a", "sotoba_b"]), p + Vector2(cos(a), sin(a) * 0.7) * _rng.randf_range(18.0, 40.0),
					3.0, {"tone": _rng.randf_range(0.45, 0.55)}, 0.0)
		_deco(_pick(PINWHEELS), p + Vector2(_rng.randf_range(-30, 30), 22.0), {"sway": 0.9})
	for k: int in range(_rng.randi_range(1, 3)):
		_place(_pick(["dead_pine", "dead_tree_bare", "volcanic_b", "cairn_m", "volcanic_c"]), _rand_in(26.0), 7.0,
				{"tone": _rng.randf_range(0.4, 0.5), "sway": 0.04})
	if c == Vector2i.ZERO:
		_place("lantern_old", Vector2(60, 70), 5.0, {"light": SPIRIT_LIGHT})


## O trecho do Sanzu no chunk: água, faixa livre de sólidos, margens e a travessia.
func _sanzu(c: Vector2i) -> void:
	var x0 := _origin.x - SANZU_STEP
	var prev := Vector2(x0, sanzu_y(x0))
	var x := x0 + SANZU_STEP
	while x <= _origin.x + CHUNK + SANZU_STEP:
		var cur := Vector2(x, sanzu_y(x))
		_paint.append(["line", 2, prev, cur, SANZU_HALF])
		var lo := minf(prev.y, cur.y) - SANZU_HALF - 6.0
		_keepout.append(Rect2(prev.x, lo, cur.x - prev.x, absf(cur.y - prev.y) + (SANZU_HALF + 6.0) * 2.0))
		prev = cur
		x += SANZU_STEP
	# Margens: pilhas de pedras e cata-ventos dos dois lados, mais densos no sul (a margem dos
	# mortos), Jizō vigiando de vez em quando.
	for k: int in range(_rng.randi_range(5, 8)):
		var bx := _origin.x + _rng.randf_range(10.0, CHUNK - 10.0)
		# A base do sprite fica embaixo: na margem sul ela desce mais para o corpo não cair na água.
		var north := _rng.randf() < 0.4
		var by := sanzu_y(bx) - _rng.randf_range(SANZU_HALF + 10.0, SANZU_BANK) if north \
				else sanzu_y(bx) + _rng.randf_range(SANZU_HALF + 26.0, SANZU_BANK + 12.0)
		var p := Vector2(bx, by)
		var roll := _rng.randf()
		if roll < 0.55:
			_place(_pick(CAIRNS), p, 4.0, {"tone": _rng.randf_range(0.42, 0.58)}, 2.0)
		elif roll < 0.85:
			_deco(_pick(PINWHEELS), p, {"sway": 1.0})
		else:
			_place(_pick(JIZO), p, 4.0, {}, 2.0)
	# Lanternas de fogo-fátuo na margem norte, numa grade fixa do mundo (emendam entre chunks).
	var lx := ceilf(_origin.x / SANZU_LAMP_STEP) * SANZU_LAMP_STEP
	while lx < _origin.x + CHUNK:
		_place("lantern_old", Vector2(lx, sanzu_y(lx) - SANZU_HALF - 16.0), 5.0, {"light": SPIRIT_LIGHT}, 0.0)
		lx += SANZU_LAMP_STEP
	if posmod(c.x, SANZU_GATE_EVERY) == 1:
		var gx := _origin.x + 128.0
		_sanzu_gate(Vector2(gx, sanzu_y(gx) - SANZU_HALF - 30.0))


## Torii de madeira gasta da travessia: só os pilares têm colisão.
func _sanzu_gate(p: Vector2) -> void:
	if not _deco("sanzu_torii", p, {"shadow": 0.0, "tone": 0.45}):
		return
	for side: float in [-1.0, 1.0]:
		_solids.append([p + Vector2(side * 12.0, -3.0), 3.5])


# --- Tokoyo ------------------------------------------------------------------------------

## Metade da arena (o menor dos dois limites; TOKO_HALF sem limites).
func toko_half() -> float:
	var half := INF
	for axis: int in range(2):
		if bounds[axis] > 0.0:
			half = minf(half, bounds[axis])
	return TOKO_HALF if half == INF else half


## Raio do anel de pedra.
func toko_ring_radius() -> float:
	return toko_half() * TOKO_RING_K


## Se um círculo em `at` cai na estrutura fixa do layout (no Tokoyo: praça, caminhos, anel, espelhos
## d'água e peças do santuário). O WorldMap não põe altar nesses lugares.
func structure_blocks(at: Vector2, r: float) -> bool:
	if kind != "tokoyo":
		return false
	var plan := _toko_plan()
	for t: Array in plan["taken"]:
		if (t[0] as Vector2).distance_to(at) < float(t[1]) + r:
			return true
	for k: Rect2 in plan["keepout"]:
		if k.grow(r).has_point(at):
			return true
	return false


## Santuário de luz (常世), a arena final: a composição fixa em volta da origem (praça, tōrō,
## torii, caminhos, anel de pedra, espelhos d'água e ilhas) sai de _toko_plan e é recortada por
## chunk; o resto (bosques sagrados, relíquias e, nas margens, ruínas) é sorteado no chunk.
func _tokoyo(_c: Vector2i) -> void:
	var plan := _toko_plan()
	var rect := Rect2(_origin, Vector2(CHUNK, CHUNK))
	var reserved := _taken.duplicate()
	for op: Array in plan["paint"]:
		if ChunkView._op_box(op).grow(ChunkView.MASK_TEXEL * 3.0).intersects(rect):
			_paint.append(op)
	for k: Rect2 in plan["keepout"]:
		if k.intersects(rect.grow(32.0)):
			_keepout.append(k)
	for t: Array in plan["taken"]:
		if rect.grow(float(t[1]) + 48.0).has_point(t[0]):
			_taken.append(t)
	# Peças fixas cuja base cai neste chunk; uma peça de enfeite que encostaria numa lanterna
	# destrutível ou num altar (sorteio da jogabilidade, que vem antes) cede o lugar. As do santuário
	# (anel de tōrō e torii) ficam sempre.
	for e: Array in plan["items"]:
		var it: Dictionary = e[0]
		if not rect.has_point(it["p"]):
			continue
		var blocked := false
		for s: Array in ([] if bool(e[2]) else e[1]):
			for r: Array in reserved:
				blocked = blocked or (s[0] as Vector2).distance_to(r[0]) < float(s[1]) + float(r[1])
		if blocked:
			continue
		_items.append(it)
		_solids.append_array(e[1])
	_toko_local()


## Composição fixa do Tokoyo, calculada uma vez por semente (só o tamanho e a forma dos espelhos
## d'água variam com ela). Itens: [item, sólidos, fixo (nunca cede o lugar)]; taken: [centro, raio] que o sorteio evita.
func _toko_plan() -> Dictionary:
	if not _toko.is_empty():
		return _toko
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, stage_id, "tokoyo"])
	var cfg: Dictionary = biome.get("toko", {})
	var light: Array = cfg.get("light", TOKO_LIGHT)
	var half := toko_half()
	var reach := half + 64.0
	var ring_r := toko_ring_radius()
	var keepout: Array[Rect2] = []
	var plan := {"paint": [], "items": [], "taken": [], "keepout": keepout}
	var paint: Array = plan["paint"]
	var taken: Array = plan["taken"]
	# Praça: pedra (R) por baixo do calçamento (G) em disco e coroa; o meio fica livre.
	paint.append(["circle", 0, Vector2.ZERO, TOKO_PLAZA_RIM])
	paint.append(["circle", 1, Vector2.ZERO, TOKO_PLAZA_CORE])
	var inner := TOKO_PLAZA_CORE + TOKO_PLAZA_INLAY
	for k: int in range(TOKO_PLAZA_PETALS):
		var q := Vector2.from_angle(TAU * float(k) / float(TOKO_PLAZA_PETALS)) * (inner + TOKO_PLAZA_R) * 0.5
		paint.append(["circle", 1, q, (TOKO_PLAZA_R - inner) * 0.5])
	taken.append([Vector2.ZERO, TOKO_PLAZA_RIM + 12.0])
	for k: int in range(TOKO_TORO_COUNT):
		var p := Vector2.from_angle(TAU * (float(k) + 0.5) / float(TOKO_TORO_COUNT)) * TOKO_TORO_R
		_toko_put(plan, "toro", p, 5.0, {"light": light}, true)
	# Caminhos sagrados cardeais: pedra (R) com a faixa do meio calçada (G), torii na entrada e em
	# corredor, um torii no cruzamento com o anel e lanternas dos dois lados até a borda.
	for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var side := d.orthogonal()
		paint.append(["line", 0, d * TOKO_PLAZA_R, d * reach, TOKO_PATH_HALF])
		paint.append(["line", 1, d * (TOKO_PLAZA_RIM + 6.0), d * reach, TOKO_INLAY_HALF])
		keepout.append(Rect2(d * (TOKO_PLAZA_RIM + 4.0) + side * (TOKO_PATH_HALF + 4.0), Vector2.ZERO)
				.expand(d * reach - side * (TOKO_PATH_HALF + 4.0)))
		for g: int in range(TOKO_TUNNEL + 1):
			_toko_gate(plan, d, TOKO_GATE_R + float(g) * TOKO_TUNNEL_STEP)
		_toko_gate(plan, d, ring_r)
		var r := TOKO_GATE_R + float(TOKO_TUNNEL + 1) * TOKO_TUNNEL_STEP + 40.0
		while r < half - TOKO_EDGE_CLEAR - 30.0:
			if absf(r - ring_r) > 56.0:
				for s: float in [-1.0, 1.0]:
					_toko_put(plan, "toro", d * r + side * s * (TOKO_PATH_HALF + TOKO_LAMP_SIDE), 5.0, {"light": light})
			r += TOKO_LAMP_STEP
	# Diagonais até o anel, com um par de guardiões de pedra (komainu) onde chegam nele.
	var guardian := String(cfg.get("guardian", "fox_statue"))
	for k: int in range(4):
		var d := Vector2.from_angle(PI * 0.25 + float(k) * PI * 0.5)
		paint.append(["line", 0, d * (TOKO_PLAZA_RIM - 4.0), d * ring_r, TOKO_DIAG_HALF])
		var r := TOKO_PLAZA_RIM
		while r < ring_r:
			taken.append([d * r, TOKO_DIAG_HALF + 10.0])
			r += 20.0
		for s: float in [-1.0, 1.0]:
			_toko_put(plan, guardian, d * (ring_r - 34.0) + d.orthogonal() * s * (TOKO_DIAG_HALF + 14.0), 6.0,
					{"flip": s > 0.0})
	# Anel de pedra.
	for k: int in range(TOKO_RING_SEGMENTS):
		var a := Vector2.from_angle(TAU * float(k) / float(TOKO_RING_SEGMENTS)) * ring_r
		var b := Vector2.from_angle(TAU * float(k + 1) / float(TOKO_RING_SEGMENTS)) * ring_r
		paint.append(["line", 0, a, b, TOKO_RING_HALF])
		taken.append([a, TOKO_RING_HALF + 10.0])
		taken.append([(a + b) * 0.5, TOKO_RING_HALF + 10.0])
	# Meio-fio de pedra por dentro do limite.
	for axis: int in range(2):
		for s: float in [-1.0, 1.0]:
			var lo := Vector2.ZERO
			lo[axis] = s * (half - TOKO_CURB)
			lo[1 - axis] = -reach
			var hi := Vector2.ZERO
			hi[axis] = s * (half + 80.0)
			hi[1 - axis] = reach
			paint.append(["rect", 0, Rect2(lo, Vector2.ZERO).expand(hi), 0])
	_toko_ponds(plan, rng, cfg, light, half, ring_r)
	_toko = plan
	return plan


## Espelhos d'água (canal B, sem colisão), um por setor entre os caminhos, por dentro e por fora do
## anel; cada um do tamanho que cabe sem encostar em caminho, anel, praça ou borda.
func _toko_ponds(plan: Dictionary, rng: RandomNumberGenerator, cfg: Dictionary, light: Array, half: float,
		ring_r: float) -> void:
	var paint: Array = plan["paint"]
	var taken: Array = plan["taken"]
	var scale := float(cfg.get("pond", 1.0))
	var island_tree := String(cfg.get("island_tree", "big_sakura"))
	var zones := [[(TOKO_PLAZA_RIM + ring_r) * 0.5, 84.0, 110.0], [(ring_r + half) * 0.5, 104.0, 150.0]]
	for z: int in range(zones.size()):
		var zone: Array = zones[z]
		for k: int in range(TOKO_POND_SECTORS):
			var a := PI / float(TOKO_POND_SECTORS) + float(k) * TAU / float(TOKO_POND_SECTORS) \
					+ rng.randf_range(-0.05, 0.05)
			var dist := float(zone[0]) + rng.randf_range(-16.0, 16.0)
			var center := (Vector2.from_angle(a) * dist).round()
			# Distância ao caminho mais perto: por dentro do anel há caminhos a cada 45°, por fora só
			# os cardeais (a cada 90°).
			var off := absf(wrapf(a, -PI / 4.0, PI / 4.0))
			var to_path := dist * sin(minf(off, PI / 4.0 - off) if z == 0 else off) - TOKO_PATH_HALF
			var lim := minf(to_path, absf(dist - ring_r) - TOKO_RING_HALF)
			if z == 0:
				lim = minf(lim, dist - TOKO_PLAZA_RIM)
			else:
				lim = minf(lim, half - maxf(absf(center.x), absf(center.y)) - TOKO_EDGE_CLEAR)
			var radius := minf(lim - TOKO_POND_GAP, rng.randf_range(float(zone[1]), float(zone[2])) * scale)
			if radius < 40.0:
				continue
			taken.append([center, radius + 6.0])
			if z == 0 and k % 2 == 0:
				# Ilha: fosso de círculos em volta e a árvore sagrada no meio.
				for m: int in range(TOKO_MOAT):
					var q := center + Vector2.from_angle(TAU * float(m) / float(TOKO_MOAT) + a) * radius * 0.6
					paint.append(["circle", 2, q.round(), radius * 0.4])
				_toko_put(plan, island_tree, center + Vector2(0, 10), 10.0, {"sway": 0.16, "tone": 0.56})
				continue
			paint.append(["circle", 2, center, radius * 0.72])
			for m: int in range(3):
				var lobe := radius * rng.randf_range(0.42, 0.56)
				var q := center + Vector2.from_angle(rng.randf() * TAU) * (radius - lobe)
				paint.append(["circle", 2, q.round(), lobe])
			if z == 1:
				# Lanterna na margem, do lado da praça (a luz se espelha na água).
				_toko_put(plan, "toro", center - center.normalized() * (radius + 14.0), 5.0, {"light": light})


## Torii no caminho da direção `d`, a `r` px da origem: de frente nos caminhos norte-sul (só os
## pilares têm colisão), de lado (gen_torii_side) nos leste-oeste, um pilar de cada lado do meio.
func _toko_gate(plan: Dictionary, d: Vector2, r: float) -> void:
	var p := d * r
	if absf(d.x) < 0.5:
		var it := _item("torii", p, 0.0, {"shadow": 0.0})
		(plan["items"] as Array).append([it, [[p + Vector2(-17, -3), 4.0], [p + Vector2(17, -3), 4.0]], true])
	else:
		var front := p + Vector2(0, TORII_SIDE_SPAN * 0.5)
		var it := _item("gen_torii_side", front, 0.0, {"shadow": 10.0})
		(plan["items"] as Array).append([it, [[front + Vector2(0, -2), 4.0],
				[front + Vector2(0, -TORII_SIDE_SPAN - 2.0), 4.0]], true])
	(plan["taken"] as Array).append([p, 30.0])


## Peça fixa com obstáculo `solid` (fora do raio livre da praça e da moldura); `keep`: nunca cede o
## lugar a uma lanterna destrutível ou a um altar.
func _toko_put(plan: Dictionary, sprite: String, p: Vector2, solid: float, extra: Dictionary = {},
		keep: bool = false) -> void:
	if p.length() < TOKO_CLEAR_R + solid or not _in_bounds(p, TOKO_EDGE_CLEAR):
		return
	var it := _item(sprite, p, solid, extra)
	(plan["items"] as Array).append([it, solid_circles(sprite, it["p"], solid), keep])
	(plan["taken"] as Array).append([it["p"], maxf(solid, TerrainArt.sprite_size(sprite).x * 0.36) + 4.0])


## Detalhe sorteado do chunk: bosques de árvores sagradas e relíquias de pedra; perto do limite,
## ruínas (pilares e estátuas antigas).
func _toko_local() -> void:
	var cfg: Dictionary = biome.get("toko", {})
	var trees: Array = cfg.get("trees", ["big_sakura", "sakura"])
	var bushes: Array = cfg.get("bushes", ["bush_a", "bush_b"])
	var relics: Array = cfg.get("relics", ["fox_statue", "rock_gray"])
	var ruins: Array = cfg.get("ruins", ["ruin_pillar", "pillar"])
	var center := _origin + Vector2(CHUNK, CHUNK) * 0.5
	var to_edge := toko_half() - maxf(absf(center.x), absf(center.y))
	for k: int in range(_rng.randi_range(1, 3)):
		_grove(_rand_in(48.0), trees, _rng.randi_range(2, 4), _rng.randf_range(24.0, 40.0), bushes)
	for k: int in range(_rng.randi_range(1, 2)):
		_place(_pick(relics), _rand_in(24.0), 6.0, {"tone": _rng.randf_range(0.5, 0.62)})
	if to_edge < 320.0:
		for k: int in range(_rng.randi_range(2, 4)):
			_place(_pick(ruins), _rand_in(20.0), 6.0, {"tone": _rng.randf_range(0.48, 0.6)})


## Moldura da arena por fora do limite (só visual: o limite já prende a guardiã): uma fileira de
## pilares e, atrás, rochedos.
func _toko_frame() -> void:
	var cfg: Dictionary = biome.get("toko", {})
	var posts: Array = cfg.get("frame", ["pillar", "pillar", "rockpillar_gray"])
	var half := toko_half()
	for axis: int in range(2):
		for side: float in [-1.0, 1.0]:
			var lo := _origin[axis]
			for row: int in range(2):
				# Cada peça fica no chunk onde está a base dela (sem repetir no vizinho).
				var at := half * side + side * (16.0 if row == 0 else 52.0)
				if at < lo or at >= lo + CHUNK:
					continue
				var t := _origin[1 - axis] + (12.0 if row == 0 else 30.0)
				while t < _origin[1 - axis] + CHUNK:
					var p := Vector2.ZERO
					p[axis] = at
					p[1 - axis] = t
					if absf(t) < half + 60.0:
						var sprite := _pick(posts) if row == 0 else _pick(["rockwall_gray", "rocks_gray", "boulder_gray"])
						_items.append(_item(sprite, p, 0.0, {"tone": 0.6 if row == 0 else 0.5, "shadow": 0.0,
								"layer": "decor"}))
					t += _rng.randf_range(30.0, 40.0) if row == 0 else _rng.randf_range(48.0, 64.0)


# --- Limites ---------------------------------------------------------------------------

## Muros de rocha ao longo do limite da área jogável (só visual: o limite já prende o jogador).
func _edges() -> void:
	if bounds == Vector2.ZERO:
		return
	var wall := "rockwall_gray" if kind == "yomi" else ("volcanic_a" if kind == "osorezan" else "rockpillar_gray")
	for axis: int in range(2):
		var lim := bounds[axis]
		if lim <= 0.0:
			continue
		for side: float in [-1.0, 1.0]:
			var edge := lim * side
			var lo := _origin[axis]
			if edge < lo - 40.0 or edge > lo + CHUNK + 40.0:
				continue
			var t := _origin[1 - axis] + 16.0
			while t < _origin[1 - axis] + CHUNK:
				var p := Vector2.ZERO
				p[axis] = edge + side * 24.0
				p[1 - axis] = t
				var it := _item(wall if _rng.randf() < 0.6 else "boulder_gray", p, 0.0,
						{"tone": 0.32, "shadow": 0.0, "layer": "decor"})
				_items.append(it)
				t += _rng.randf_range(34.0, 52.0)


# --- Decoração orgânica (sem colisão; visual) -----------------------------------------------

## Tufos, flores, folhas e pedrinhas do chunk, com rank para escalar a densidade.
## `mask`: a máscara de estruturas do chunk (ChunkView.paint_mask), para não pôr grama na rua.
## Os campos de ruído são amostrados numa grade de 32 px e interpolados (barato e fiel: o
## ruído é de baixa frequência).
func scatter(c: Vector2i, structure: Dictionary, mask: Image = null) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, c.x, c.y, stage_id, "scatter"])
	var origin := Vector2(c.x * CHUNK, c.y * CHUNK)
	if mask == null:
		mask = ChunkView.paint_mask(origin, structure.get("paint", []))
	var bands: Array = biome.get("bands", [])
	var grid := PackedVector2Array()
	for gy: int in range(9):
		for gx: int in range(9):
			grid.append(TerrainNoise.fields(origin + Vector2(gx, gy) * 32.0, scales, noise_offset))
	var blocked := _solid_cells(structure.get("items", []), origin)
	var out: Array = []
	for set_v: Variant in biome.get("scatter", []):
		var s: Dictionary = set_v
		var sprites: Array = s.get("sprites", [])
		var weights := PackedFloat32Array()
		for e: Array in sprites:
			weights.append(float(e[1]))
		var count := int(s.get("count", 10))
		var cluster := int(s.get("cluster", 1))
		var zone := String(s.get("zone", "any"))
		var flat := bool(s.get("flat", false))
		var sway := float(s.get("sway", 0.0))
		var tries := 0
		var made := 0
		while made < count and tries < count * 3:
			tries += 1
			var p := Vector2(rng.randf_range(4, CHUNK - 4), rng.randf_range(8, CHUNK - 2))
			var sprite := String(sprites[WorldMap.weighted(rng, weights)][0])
			var rank := rng.randf()
			for k: int in range(cluster):
				var q := p + (Vector2(rng.randf_range(-9, 9), rng.randf_range(-6, 6)) if k > 0 else Vector2.ZERO)
				q = q.clamp(Vector2(2, 2), Vector2(CHUNK - 2, CHUNK - 2))
				if not _zone_ok(zone, q, bands, mask, grid, blocked) or not _in_bounds(origin + q, 6.0):
					continue
				out.append({"s": sprite, "p": (origin + q).round(), "solid": 0.0, "sway": sway, "shadow": 0.0,
						"layer": "flat" if flat else "decor", "light": [], "rank": rank,
						"tone": rng.randf_range(0.4, 0.62), "flip": rng.randf() < 0.5})
				made += 1
	return out


## Células de 16 px ocupadas pela base de objetos sólidos (casas, árvores, rochas).
static func _solid_cells(items: Array, origin: Vector2) -> Dictionary:
	var cells: Dictionary = {}
	for it: Dictionary in items:
		var r := float(it.get("solid", 0.0))
		if r <= 0.0:
			continue
		var w := maxf(r, TerrainArt.sprite_size(String(it["s"])).x * 0.45)
		var p: Vector2 = (it["p"] as Vector2) - origin
		for gy: int in range(floori((p.y - 18.0) / 16.0), floori(p.y / 16.0) + 1):
			for gx: int in range(floori((p.x - w) / 16.0), floori((p.x + w) / 16.0) + 1):
				cells[Vector2i(gx, gy)] = true
	return cells


func _zone_ok(zone: String, q: Vector2, bands: Array, mask: Image, grid: PackedVector2Array,
		blocked: Dictionary) -> bool:
	var m := mask.get_pixel(clampi(int(q.x / ChunkView.MASK_TEXEL) + 1, 0, ChunkView.MASK_SIZE - 1),
			clampi(int(q.y / ChunkView.MASK_TEXEL) + 1, 0, ChunkView.MASK_SIZE - 1))
	if zone == "any":
		return m.g < 0.4 and m.b < 0.3
	if zone == "water":
		# Espelhos d'água (canal B): lótus e folhas flutuando, longe da margem.
		return m.b > 0.75 and m.g < 0.3
	if m.r > 0.35 or m.g > 0.35 or m.b > 0.2:
		return false
	if blocked.has(Vector2i(floori(q.x / 16.0), floori(q.y / 16.0))):
		return false
	var gx := clampf(q.x / 32.0, 0.0, 7.999)
	var gy := clampf(q.y / 32.0, 0.0, 7.999)
	var ix := int(gx)
	var iy := int(gy)
	var top := grid[iy * 9 + ix].lerp(grid[iy * 9 + ix + 1], gx - ix)
	var bottom := grid[(iy + 1) * 9 + ix].lerp(grid[(iy + 1) * 9 + ix + 1], gx - ix)
	var f := top.lerp(bottom, gy - iy)
	var lush := _in_band(f, bands, 0)
	var dirt := _in_band(f, bands, 2)
	match zone:
		"lush":
			return lush
		"grass":
			return not lush and not dirt and not _in_band(f, bands, 1)
		"dirt":
			return dirt or _in_band(f, bands, 1)
	return true


static func _in_band(f: Vector2, bands: Array, k: int) -> bool:
	if k >= bands.size():
		return false
	var b: Array = bands[k]
	if int(b[0]) < 0:
		return false
	var v := f.x if int(b[0]) == 0 else f.y
	return v > float(b[1]) + 0.01 and v < float(b[2]) - 0.01
