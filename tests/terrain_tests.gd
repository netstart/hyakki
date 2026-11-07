extends RefCounted
## Terreno, biomas e luz (scripts/game/world_map.gd, terrain_layout.gd, terrain_art.gd,
## chunk_view.gd, scripts/systems/lantern_system.gd):
##   - determinismo: a mesma semente dá os mesmos obstáculos, lanternas e estruturas, e eles não
##     dependem do nível gráfico (só a decoração SEM colisão escala com decor_density);
##   - densidade: Baixa ⊂ Média ⊂ Alta, com contagens crescentes, sem nada sólido no espalhado;
##   - coerência: ruas da vila contínuas entre chunks, casas fora das ruas, área segura livre;
##   - ruído da CPU igual ao do shader (fórmula), máscara de estruturas, atlas sem buracos;
##   - Tokoyo (biomas <fase>_toko, layout "tokoyo"): só ele usa o layout, diferente da fase e do
##     Kakuriyo; praça do meio livre, tōrō e torii, espelhos d'água sem colisão, moldura que não
##     fecha a borda, determinismo e custo de geração na ordem dos outros layouts;
##   - partida de verdade nas 6 fases: chunks montados com chão e decoração, troca ao vivo
##     Baixa → Alta → Baixa remontando os chunks, luzes do cenário dentro de lights_max.
## run_unit() roda sem autoloads (tests/run_tests.gd); run() precisa da árvore
## (tests/integration_tests.gd).

const GAME_SCENE := "res://scenes/game/Game.tscn"
const STAGES := ["village", "bamboo", "temple", "dunes", "yomi", "secret"]
## Limites do Tokoyo nos testes (metade da arena, como o bloco "tokoyo" de data/stages.json).
const TOKO_BOUNDS := [1200, 1200]
## Geração do Tokoyo: no máximo este múltiplo do custo do layout da própria fase (mesmos chunks).
const TOKO_COST_RATIO := 4.0
## Folga (µs) para o custo, que em poucos chunks fica perto do ruído do relógio.
const TOKO_COST_SLACK_US := 20000
## Peças por chunk (estrutura + espalhado na Alta) no máximo, no Tokoyo.
const TOKO_MAX_ITEMS := 900

var _check: Callable


static func stage_data(id: String) -> Dictionary:
	var file := FileAccess.open("res://data/stages.json", FileAccess.READ)
	for s: Dictionary in JSON.parse_string(file.get_as_text()):
		if String(s["id"]) == id:
			return s
	return {}


static func _world(id: String, run_seed: int) -> WorldMap:
	var w := WorldMap.new()
	w.setup(stage_data(id), run_seed)
	return w


## Fase `id` no Tokoyo: o bioma <fase>_toko com os limites da arena.
static func toko_stage(id: String) -> Dictionary:
	var s := stage_data(id).duplicate(true)
	s["biome"] = id + "_toko"
	s["bounds"] = TOKO_BOUNDS.duplicate()
	s["hazard"] = {}
	return s


static func _toko_world(id: String, run_seed: int) -> WorldMap:
	var w := WorldMap.new()
	w.setup(toko_stage(id), run_seed)
	return w


func run_unit(check: Callable) -> void:
	_check = check
	_test_biomes_data()
	_test_noise()
	for id: String in STAGES:
		_test_determinism(id)
		_test_density(id)
	_test_village_streets()
	_test_mask()
	_test_tokoyo_biomes()
	for id: String in STAGES:
		_test_tokoyo_layout(id)
		_test_tokoyo_determinism(id)
		_test_tokoyo_edge(id)
	_test_tokoyo_cost()
	GfxQuality.clear_override()


func _test_biomes_data() -> void:
	var sprites: Dictionary = TerrainArt.data().get("sprites", {})
	_check.call(sprites.size() > 100, "terreno: catálogo de sprites carregado (%d)", sprites.size())
	# Folhas dos materiais (a do material e a de cada tile [x, y, peso, folha]) e do catálogo existem.
	var sheets_ok := true
	var mixed := 0
	for b: Dictionary in (TerrainArt.data().get("biomes", {}) as Dictionary).values():
		for m: Dictionary in b.get("materials", []):
			var sheet := String(m.get("tileset", "floor"))
			sheets_ok = sheets_ok and (bool(m.get("lava", false)) or TerrainArt.TILESETS.has(sheet))
			for t: Array in m.get("tiles", []):
				if t.size() > 3:
					mixed += 1
					sheets_ok = sheets_ok and TerrainArt.TILESETS.has(String(t[3]))
	for e: Array in sprites.values():
		sheets_ok = sheets_ok and TerrainArt.TILESETS.has(String(e[0]))
	_check.call(sheets_ok and mixed > 30, "terreno: folhas dos materiais e sprites existem (%d tiles de outra folha)",
			mixed)
	for id: String in STAGES:
		var b := TerrainArt.biome(id)
		_check.call(String(b.get("layout", "")) == id, "terreno: bioma %s com layout próprio", id)
		_check.call((b.get("materials", []) as Array).size() == 6, "terreno: %s tem 6 materiais", id)
		for s: Dictionary in b.get("scatter", []):
			for e: Array in s["sprites"]:
				var n := String(e[0])
				_check.call(sprites.has(n) or n.begins_with("gen_"), "terreno: %s usa sprite existente %s", [id, n])


func _test_noise() -> void:
	# Mesmos números que o shader: hash em [0, 1), contínuo e determinístico.
	var a := TerrainNoise.hash2(12.0, -7.0)
	_check.call(a >= 0.0 and a < 1.0 and is_equal_approx(a, TerrainNoise.hash2(12.0, -7.0)),
			"terreno: hash do ruído em [0,1) e determinístico")
	var v0 := TerrainNoise.fbm(3.2, 4.1)
	var v1 := TerrainNoise.fbm(3.2001, 4.1)
	_check.call(absf(v0 - v1) < 0.01 and v0 >= 0.0 and v0 <= 1.0, "terreno: fbm contínuo em [0,1]")
	var off5 := TerrainNoise.offset_for(5)
	_check.call(off5.is_equal_approx(TerrainNoise.offset_for(5)) and off5 != TerrainNoise.offset_for(6),
			"terreno: deslocamento vem da semente")


## Chunks iguais entre mundos com a mesma semente e entre níveis gráficos.
func _test_determinism(id: String) -> void:
	var chunks := [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(2, -1), Vector2i(-3, 4)]
	GfxQuality.set_override(GfxQuality.LOW)
	var low := _world(id, 1234)
	GfxQuality.set_override(GfxQuality.HIGH)
	var high := _world(id, 1234)
	var other := _world(id, 99)
	var same := true
	var differs := false
	for c: Vector2i in chunks:
		var a := low.chunk_data(c)
		var b := high.chunk_data(c)
		for key: String in ["solids", "lanterns", "statues", "lava"]:
			same = same and var_to_str(a[key]) == var_to_str(b[key])
		same = same and (a["items"] as Array).size() == (b["items"] as Array).size()
		differs = differs or var_to_str(a["solids"]) != var_to_str(other.chunk_data(c)["solids"])
	_check.call(same, "terreno %s: obstáculos e estruturas iguais na Baixa e na Alta", id)
	_check.call(differs, "terreno %s: outra semente muda o mapa", id)
	var solids_near := false
	for c: Vector2i in [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1)]:
		for s: Array in low.chunk_data(c)["solids"]:
			if (s[0] as Vector2).length() < 40.0:
				solids_near = true
	_check.call(not solids_near, "terreno %s: área do início livre de obstáculos", id)


## Decoração sem colisão: Baixa ⊂ Média ⊂ Alta, e nada do espalhado tem colisão.
func _test_density(id: String) -> void:
	var w := _world(id, 77)
	var counts: Array[int] = []
	var subset := true
	var prev: Dictionary = {}
	for level: int in [GfxQuality.LOW, GfxQuality.MEDIUM, GfxQuality.HIGH]:
		GfxQuality.set_override(level)
		var total := 0
		var keys: Dictionary = {}
		for c: Vector2i in [Vector2i(1, 1), Vector2i(-2, 0), Vector2i(0, 2)]:
			for it: Dictionary in w.visual_items(c):
				total += 1
				keys["%s|%s" % [it["s"], it["p"]]] = true
		for k: String in prev:
			subset = subset and keys.has(k)
		prev = keys
		counts.append(total)
	_check.call(counts[0] < counts[1] and counts[1] < counts[2],
			"terreno %s: decoração cresce Baixa < Média < Alta (%s)", [id, counts])
	_check.call(subset, "terreno %s: decoração da Baixa está toda na Alta", id)
	var solid_scatter := false
	for it: Dictionary in w.layout.scatter(Vector2i(1, 1), w.chunk_data(Vector2i(1, 1))):
		solid_scatter = solid_scatter or float(it["solid"]) > 0.0 or float(it["rank"]) < 0.0
	_check.call(not solid_scatter, "terreno %s: espalhados não têm colisão", id)


## Vila: ruas pintadas atravessam a borda do chunk e nenhuma casa fica em cima delas.
func _test_village_streets() -> void:
	var w := _world("village", 5)
	var streets := 0
	var houses := 0
	var blocked := false
	for cx: int in range(-2, 3):
		for cy: int in range(-2, 3):
			var d := w.chunk_data(Vector2i(cx, cy))
			for op: Array in d["paint"]:
				if String(op[0]) == "rect" and int(op[1]) == 0:
					streets += 1
					var r: Rect2 = op[2]
					_check.call(r.size.x > 256.0 or r.size.y > 256.0, "vila: rua passa da borda do chunk")
			for it: Dictionary in d["items"]:
				if String(it["s"]).begins_with("house") or ["shop_blue", "izakaya"].has(String(it["s"])):
					houses += 1
					for k: Rect2 in d["keepout"]:
						if k.has_point(it["p"]):
							blocked = true
	_check.call(streets >= 4 and houses >= 6, "vila: ruas (%d) e casas (%d) agrupadas", [streets, houses])
	_check.call(not blocked, "vila: nenhuma casa em cima da rua")


func _test_mask() -> void:
	var img := ChunkView.paint_mask(Vector2.ZERO, [["rect", 0, Rect2(-8, 100, 272, 40), 0],
			["circle", 2, Vector2(128, 40), 20.0]])
	_check.call(img.get_size() == Vector2i(ChunkView.MASK_SIZE, ChunkView.MASK_SIZE), "máscara 34x34 com borda")
	_check.call(img.get_pixel(17, 16).r > 0.9 and img.get_pixel(17, 4).r < 0.1, "máscara: rua no canal R")
	_check.call(img.get_pixel(17, 6).b > 0.5 and img.get_pixel(5, 30).b == 0.0, "máscara: lava no canal B")
	_check.call(img.get_pixel(0, 16).r > 0.6, "máscara: borda recebe a rua do vizinho")


# --- Tokoyo ------------------------------------------------------------------------------

## Os 6 biomas <fase>_toko existem, usam o layout tokoyo (que nenhum outro bioma usa) e são claros.
func _test_tokoyo_biomes() -> void:
	var sprites: Dictionary = TerrainArt.data().get("sprites", {})
	var biomes: Dictionary = TerrainArt.data().get("biomes", {})
	for name: String in biomes:
		var b: Dictionary = biomes[name]
		var toko := String(b.get("layout", "")) == "tokoyo"
		_check.call(toko == (name.ends_with("_toko") and bool(b.get("tokoyo", false))),
				"tokoyo: layout tokoyo só nos biomas <fase>_toko (%s)", name)
	for id: String in STAGES:
		var name := id + "_toko"
		_check.call(biomes.has(name), "tokoyo: bioma %s existe", name)
		var b := TerrainArt.biome(name)
		var layout := String(b.get("layout", ""))
		_check.call(layout == "tokoyo" and bool(b.get("tokoyo", false)), "tokoyo: %s com o layout tokoyo", name)
		_check.call(layout != String(TerrainArt.biome(id).get("layout", ""))
				and layout != String(TerrainArt.biome(id + "_ura").get("layout", "")),
				"tokoyo: %s diferente do layout da fase e do Kakuriyo", name)
		var mats: Array = b.get("materials", [])
		_check.call(mats.size() == 6 and bool((mats[5] as Dictionary).get("water", false)),
				"tokoyo: %s com 6 materiais e água espelhada no especial (B)", name)
		var dark := float((b.get("grade", {}) as Dictionary).get("darkness", 1.0))
		var ura_dark := float((TerrainArt.biome(id + "_ura").get("grade", {}) as Dictionary).get("darkness", 1.0))
		var phase_dark := float((TerrainArt.biome(id).get("grade", {}) as Dictionary).get("darkness", 1.0))
		_check.call(dark <= 0.5 and dark < ura_dark and dark < phase_dark,
				"tokoyo: %s mais claro que a fase e o Kakuriyo (escuridão %.2f)", [name, dark])
		var used: Array = []
		for s: Dictionary in b.get("scatter", []):
			for e: Array in s["sprites"]:
				used.append(String(e[0]))
		var cfg: Dictionary = b.get("toko", {})
		for key: String in ["trees", "relics", "ruins", "bushes", "frame"]:
			used.append_array(cfg.get(key, []))
		used.append(String(cfg.get("island_tree", "")))
		used.append(String(cfg.get("guardian", "")))
		for n: String in used:
			_check.call(sprites.has(n) or n.begins_with("gen_"), "tokoyo: %s usa sprite existente %s", [name, n])


## Chunks da arena inteira (com a moldura de fora).
static func _toko_chunks(w: WorldMap) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var lo := w.chunk_of(-w.bounds - Vector2(80, 80))
	var hi := w.chunk_of(w.bounds + Vector2(80, 80))
	for cy: int in range(lo.y, hi.y + 1):
		for cx: int in range(lo.x, hi.x + 1):
			out.append(Vector2i(cx, cy))
	return out


## Praça livre no meio, tōrō em anel, quatro torii nas entradas, água sem colisão.
func _test_tokoyo_layout(id: String) -> void:
	var w := _toko_world(id, 41)
	var near := 0
	var ring_toro := 0
	var gates := 0
	var water := 0
	var wet_solid := false
	var items := 0
	for c: Vector2i in _toko_chunks(w):
		var d := w.chunk_data(c)
		for s: Array in d["solids"]:
			if (s[0] as Vector2).length() < TerrainLayout.TOKO_CLEAR_R + float(s[1]):
				near += 1
		for it: Dictionary in d["items"]:
			items += 1
			var p: Vector2 = it["p"]
			if String(it["s"]) == "toro" and p.length() < TerrainLayout.TOKO_PLAZA_R and float(it["solid"]) > 0.0:
				ring_toro += 1
			var gate_r := maxf(absf(p.x), absf(p.y))
			if ["torii", "gen_torii_side"].has(String(it["s"])) and minf(absf(p.x), absf(p.y)) <= TerrainLayout.TORII_SIDE_SPAN \
					and absf(gate_r - TerrainLayout.TOKO_GATE_R) < 1.0:
				gates += 1
		for op: Array in d["paint"]:
			if int(op[1]) != 2 or String(op[0]) != "circle":
				continue
			water += 1
			for s: Array in d["solids"]:
				wet_solid = wet_solid or (s[0] as Vector2).distance_to(op[2]) < float(op[3])
	_check.call(near == 0, "tokoyo %s: nenhum sólido a %d px da origem (%d)", [id, int(TerrainLayout.TOKO_CLEAR_R), near])
	_check.call(w.free_point(Vector2.ZERO, 12.0) == Vector2.ZERO, "tokoyo %s: a origem é ponto livre", id)
	_check.call(ring_toro == TerrainLayout.TOKO_TORO_COUNT, "tokoyo %s: anel de %d tōrō sólidos (%d)",
			[id, TerrainLayout.TOKO_TORO_COUNT, ring_toro])
	_check.call(gates == 4, "tokoyo %s: quatro torii nas entradas (%d)", [id, gates])
	_check.call(water >= 8 and not wet_solid, "tokoyo %s: espelhos d'água (%d) sem colisão", [id, water])
	_check.call(items > 400, "tokoyo %s: arena decorada (%d peças)", [id, items])
	var plaza := ChunkView.paint_mask(Vector2(-256, -256), w.chunk_data(Vector2i(-1, -1))["paint"])
	_check.call(plaza.get_pixel(32, 32).g > 0.9, "tokoyo %s: praça calçada (canal G)", id)
	# Caminho norte: dá para ir da praça até a borda sem parar em nada sólido.
	var y := -TerrainLayout.TOKO_PLAZA_R
	var open := true
	while y > -w.bounds.y + 8.0:
		open = open and not w.overlaps_solid(Vector2(0, y), 8.0)
		y -= 8.0
	_check.call(open, "tokoyo %s: caminho norte aberto da praça até a borda", id)
	w.free()


## Mesma semente = mesmos chunks (e iguais na Baixa e na Alta); outra semente muda os detalhes.
func _test_tokoyo_determinism(id: String) -> void:
	var chunks := [Vector2i(0, 0), Vector2i(-1, -1), Vector2i(1, 2), Vector2i(-3, 1), Vector2i(-5, -5), Vector2i(4, 0)]
	GfxQuality.set_override(GfxQuality.LOW)
	var low := _toko_world(id, 1234)
	GfxQuality.set_override(GfxQuality.HIGH)
	var high := _toko_world(id, 1234)
	var other := _toko_world(id, 99)
	var same := true
	var differs := false
	for c: Vector2i in chunks:
		var a := low.chunk_data(c)
		var b := high.chunk_data(c)
		for key: String in ["solids", "items", "paint", "keepout"]:
			same = same and var_to_str(a[key]) == var_to_str(b[key])
		same = same and var_to_str(low.layout.scatter(c, a)) == var_to_str(high.layout.scatter(c, b))
		differs = differs or var_to_str(a["items"]) != var_to_str(other.chunk_data(c)["items"])
	_check.call(same, "tokoyo %s: mesma semente, mesmos chunks (Baixa e Alta)", id)
	_check.call(differs, "tokoyo %s: outra semente muda o detalhe do mapa", id)
	for w: WorldMap in [low, high, other]:
		w.free()


## Borda: nada sólido fora da arena nem colado no limite, e a faixa junto do limite é contínua.
func _test_tokoyo_edge(id: String) -> void:
	var w := _toko_world(id, 7)
	var half := w.layout.toko_half()
	var outside := 0
	var frame := 0
	for c: Vector2i in _toko_chunks(w):
		var d := w.chunk_data(c)
		for s: Array in d["solids"]:
			var p: Vector2 = s[0]
			if maxf(absf(p.x), absf(p.y)) + float(s[1]) > half - TerrainLayout.TOKO_EDGE_CLEAR * 0.5:
				outside += 1
		for it: Dictionary in d["items"]:
			var p: Vector2 = it["p"]
			if maxf(absf(p.x), absf(p.y)) > half and float(it["solid"]) == 0.0:
				frame += 1
	_check.call(outside == 0, "tokoyo %s: nada sólido fora da arena nem colado no limite (%d)", [id, outside])
	_check.call(frame >= 100, "tokoyo %s: moldura por fora do limite (%d peças)", [id, frame])
	var blocked := 0
	var t := -half + 16.0
	while t < half - 16.0:
		var lane := half - 14.0
		for p: Vector2 in [Vector2(t, -lane), Vector2(t, lane), Vector2(-lane, t), Vector2(lane, t)]:
			if w.overlaps_solid(p, 10.0):
				blocked += 1
		t += 8.0
	_check.call(blocked == 0, "tokoyo %s: faixa junto do limite livre o caminho todo (%d pontos presos)", [id, blocked])
	w.free()


## Custo de geração (estrutura, máscara e espalhado) na ordem do layout da própria fase.
func _test_tokoyo_cost() -> void:
	var chunks: Array[Vector2i] = []
	for cy: int in range(-2, 2):
		for cx: int in range(-2, 2):
			chunks.append(Vector2i(cx, cy))
	var most := 0
	for id: String in STAGES:
		var base := _gen_cost(stage_data(id), chunks)
		var toko := _gen_cost(toko_stage(id), chunks)
		_check.call(toko.x <= int(base.x * TOKO_COST_RATIO) + TOKO_COST_SLACK_US,
				"tokoyo %s: gerar %d chunks custa %d µs (fase: %d µs)", [id, chunks.size(), toko.x, base.x])
		most = maxi(most, toko.y)
	_check.call(most <= TOKO_MAX_ITEMS, "tokoyo: no máximo %d peças por chunk na Alta (%d)", [TOKO_MAX_ITEMS, most])


## [µs para gerar os chunks, maior número de peças num chunk]: melhor de 2 rodadas, mundo novo em
## cada uma (estrutura, máscara e decoração da Alta, como a montagem de um chunk).
func _gen_cost(stage: Dictionary, chunks: Array[Vector2i]) -> Vector2i:
	GfxQuality.set_override(GfxQuality.HIGH)
	var best := 1 << 30
	var most := 0
	for _round: int in range(2):
		var w := WorldMap.new()
		w.setup(stage, 3)
		var t0 := Time.get_ticks_usec()
		for c: Vector2i in chunks:
			var mask := ChunkView.paint_mask(Vector2(c) * float(WorldMap.CHUNK), w.chunk_data(c)["paint"])
			most = maxi(most, w.visual_items(c, mask).size())
		best = mini(best, Time.get_ticks_usec() - t0)
		w.free()
	return Vector2i(best, most)


# --- Com a árvore (integração) ---------------------------------------------------------

func run(host: Node, check: Callable) -> void:
	_check = check
	var saved: Variant = Settings.get_value(GfxQuality.KEY)
	var scene := load(GAME_SCENE) as PackedScene
	for id: String in STAGES:
		Settings.set_value(GfxQuality.KEY, "low")
		var game := scene.instantiate() as HyakkiGame
		game.config = {"hero": "aki", "stage": id, "moon": 0, "mode": "normal", "seed": 31, "speed": 1}
		host.add_child(game)
		for _k: int in range(3):
			await host.get_tree().process_frame
		var views := game.world.built_views()
		_check.call(views.size() >= 4, "terreno %s: chunks da tela montados (%d)", [id, views.size()])
		var low_items := _count(views)
		var first: ChunkView = views.values()[0]
		_check.call(first.get_node_or_null(^"Ground") is Sprite2D, "terreno %s: chunk com chão", id)
		_check.call(low_items > 0, "terreno %s: chunk com decoração", id)
		_test_fade(game, views)
		var low_glow: bool = game.lantern._halos.visible
		Settings.set_value(GfxQuality.KEY, "high")
		await host.get_tree().process_frame
		var high_views := game.world.built_views()
		var rebuilt := high_views.size() > 0 and not high_views.values().has(first)
		_check.call(rebuilt, "terreno %s: troca ao vivo remonta os chunks", id)
		_check.call(_count(high_views) > low_items, "terreno %s: Alta tem mais decoração que a Baixa", id)
		_check.call(not low_glow and game.lantern._halos.visible, "luz %s: halos só na Alta", id)
		_check.call(game.lantern.frame_lights.size() <= int(GfxQuality.budget("lights_max")) - 1,
				"luz %s: respeita lights_max", id)
		Settings.set_value(GfxQuality.KEY, "low")
		await host.get_tree().process_frame
		_check.call(_count(game.world.built_views()) == low_items, "terreno %s: volta à Baixa igual", id)
		game.queue_free()
		await host.get_tree().process_frame
	Settings.set_value(GfxQuality.KEY, saved)
	GameClock.paused = false
	await _test_tokoyo_mount(host)


## Tokoyo montado de verdade (arte e chão): chunks da praça com chão, decoração e luzes, a água
## espelhada no material especial e o torii de lado gerado no atlas.
func _test_tokoyo_mount(host: Node) -> void:
	for id: String in STAGES:
		var w := WorldMap.new()
		host.add_child(w)
		w.setup(toko_stage(id), 31)
		w._ensure_art()
		for c: Vector2i in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
			w._build(c)
		var views := w.built_views()
		var items := _count(views)
		var lights := 0
		for v: ChunkView in views.values():
			lights += v.lights.size()
		var first: ChunkView = views[Vector2i(0, 0)]
		_check.call(first.get_node_or_null(^"Ground") is Sprite2D and items > 200,
				"tokoyo %s: praça montada com chão e decoração (%d peças)", [id, items])
		_check.call(lights >= TerrainLayout.TOKO_TORO_COUNT, "tokoyo %s: tōrō acesos na praça (%d luzes)", [id, lights])
		_check.call(w.art.water_slot == 5 and w.art.regions.has("gen_torii_side"),
				"tokoyo %s: água espelhada no material 5 e torii de lado no atlas", id)
		var mat := (w._materials["ground"] as ShaderMaterial)
		_check.call(is_equal_approx(float(mat.get_shader_parameter("water_slot")), 5.0),
				"tokoyo %s: shader do chão com a água ligada", id)
		var ripples: Variant = mat.get_shader_parameter("ripples")
		_check.call(w.art.water_ripple > 0.0 and ripples is Texture2D
				and (ripples as Texture2D).get_size() == Vector2(TerrainArt.TILE * TerrainArt.RIPPLE_FRAMES, TerrainArt.TILE)
				and is_equal_approx(float(mat.get_shader_parameter("water_ripple")), w.art.water_ripple),
				"tokoyo %s: ondulações animadas da água no shader (%.2f das células)", [id, w.art.water_ripple])
		_check.call(w.art.materials_texture.get_width() == TerrainArt.SLOT_W
				and w.art.mat_info[5].y == float(TerrainArt.VARIATIONS),
				"tokoyo %s: água com %d variações do TilesetWater", [id, TerrainArt.VARIATIONS])
		w.queue_free()
		await host.get_tree().process_frame


## Copas e telhados ficam a 35% com a guardiã ou um inimigo atrás e voltam depois.
func _test_fade(game: HyakkiGame, views: Dictionary) -> void:
	var view: ChunkView = null
	for v: ChunkView in views.values():
		if not v.fade_rects.is_empty():
			view = v
			break
	if view == null:
		return
	var r := view.fade_rects[0]
	var all := Rect2(-1e6, -1e6, 2e6, 2e6)
	var far := r.get_center() + Vector2(5000, 5000)
	for _k: int in range(4):
		view.update_fade(r.get_center(), null, 0.2, all)
	_check.call(is_equal_approx(view.fade_alpha[0], ChunkView.FADE_ALPHA), "terreno: copa a 35%% com a guardiã atrás")
	for _k: int in range(4):
		view.update_fade(far, null, 0.2, all)
	_check.call(is_equal_approx(view.fade_alpha[0], 1.0), "terreno: copa volta ao normal")
	var i := game.enemies.spawn(&"slime_rice", r.get_center(), 1.0, 1.0)
	if i >= 0:
		game.enemies.spatial.insert(i, r.get_center())
		for _k: int in range(4):
			view.update_fade(far, game.enemies, 0.2, all)
		_check.call(is_equal_approx(view.fade_alpha[0], ChunkView.FADE_ALPHA), "terreno: copa a 35%% com inimigo atrás")
		game.enemies.despawn(i)


static func _count(views: Dictionary) -> int:
	var n := 0
	for v: ChunkView in views.values():
		n += v.item_count
	return n
