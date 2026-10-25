extends RefCounted
## Terreno, biomas e luz (scripts/game/world_map.gd, terrain_layout.gd, terrain_art.gd,
## chunk_view.gd, scripts/systems/lantern_system.gd):
##   - determinismo: a mesma semente dá os mesmos obstáculos, lanternas e estruturas, e eles não
##     dependem do nível gráfico (só a decoração SEM colisão escala com decor_density);
##   - densidade: Baixa ⊂ Média ⊂ Alta, com contagens crescentes, sem nada sólido no espalhado;
##   - coerência: ruas da vila contínuas entre chunks, casas fora das ruas, área segura livre;
##   - ruído da CPU igual ao do shader (fórmula), máscara de estruturas, atlas sem buracos;
##   - partida de verdade nas 6 fases: chunks montados com chão e decoração, troca ao vivo
##     Baixa → Alta → Baixa remontando os chunks, luzes do cenário dentro de lights_max.
## run_unit() roda sem autoloads (tests/run_tests.gd); run() precisa da árvore
## (tests/integration_tests.gd).

const GAME_SCENE := "res://scenes/game/Game.tscn"
const STAGES := ["village", "bamboo", "temple", "dunes", "yomi", "secret"]

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


func run_unit(check: Callable) -> void:
	_check = check
	_test_biomes_data()
	_test_noise()
	for id: String in STAGES:
		_test_determinism(id)
		_test_density(id)
	_test_village_streets()
	_test_mask()
	GfxQuality.clear_override()


func _test_biomes_data() -> void:
	var sprites: Dictionary = TerrainArt.data().get("sprites", {})
	_check.call(sprites.size() > 100, "terreno: catálogo de sprites carregado (%d)" % sprites.size())
	for id: String in STAGES:
		var b := TerrainArt.biome(id)
		_check.call(String(b.get("layout", "")) == id, "terreno: bioma %s com layout próprio" % id)
		_check.call((b.get("materials", []) as Array).size() == 6, "terreno: %s tem 6 materiais" % id)
		for s: Dictionary in b.get("scatter", []):
			for e: Array in s["sprites"]:
				var n := String(e[0])
				_check.call(sprites.has(n) or n.begins_with("gen_"), "terreno: %s usa sprite existente %s" % [id, n])


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
	_check.call(same, "terreno %s: obstáculos e estruturas iguais na Baixa e na Alta" % id)
	_check.call(differs, "terreno %s: outra semente muda o mapa" % id)
	var solids_near := false
	for c: Vector2i in [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1)]:
		for s: Array in low.chunk_data(c)["solids"]:
			if (s[0] as Vector2).length() < 40.0:
				solids_near = true
	_check.call(not solids_near, "terreno %s: área do início livre de obstáculos" % id)


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
			"terreno %s: decoração cresce Baixa < Média < Alta (%s)" % [id, counts])
	_check.call(subset, "terreno %s: decoração da Baixa está toda na Alta" % id)
	var solid_scatter := false
	for it: Dictionary in w.layout.scatter(Vector2i(1, 1), w.chunk_data(Vector2i(1, 1))):
		solid_scatter = solid_scatter or float(it["solid"]) > 0.0 or float(it["rank"]) < 0.0
	_check.call(not solid_scatter, "terreno %s: espalhados não têm colisão" % id)


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
	_check.call(streets >= 4 and houses >= 6, "vila: ruas (%d) e casas (%d) agrupadas" % [streets, houses])
	_check.call(not blocked, "vila: nenhuma casa em cima da rua")


func _test_mask() -> void:
	var img := ChunkView.paint_mask(Vector2.ZERO, [["rect", 0, Rect2(-8, 100, 272, 40), 0],
			["circle", 2, Vector2(128, 40), 20.0]])
	_check.call(img.get_size() == Vector2i(ChunkView.MASK_SIZE, ChunkView.MASK_SIZE), "máscara 34x34 com borda")
	_check.call(img.get_pixel(17, 16).r > 0.9 and img.get_pixel(17, 4).r < 0.1, "máscara: rua no canal R")
	_check.call(img.get_pixel(17, 6).b > 0.5 and img.get_pixel(5, 30).b == 0.0, "máscara: lava no canal B")
	_check.call(img.get_pixel(0, 16).r > 0.6, "máscara: borda recebe a rua do vizinho")


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
		_check.call(views.size() >= 4, "terreno %s: chunks da tela montados (%d)" % [id, views.size()])
		var low_items := _count(views)
		var first: ChunkView = views.values()[0]
		_check.call(first.get_node_or_null(^"Ground") is Sprite2D, "terreno %s: chunk com chão" % id)
		_check.call(low_items > 0, "terreno %s: chunk com decoração" % id)
		_test_fade(game, views)
		var low_glow: bool = game.lantern._halos.visible
		Settings.set_value(GfxQuality.KEY, "high")
		await host.get_tree().process_frame
		var high_views := game.world.built_views()
		var rebuilt := high_views.size() > 0 and not high_views.values().has(first)
		_check.call(rebuilt, "terreno %s: troca ao vivo remonta os chunks" % id)
		_check.call(_count(high_views) > low_items, "terreno %s: Alta tem mais decoração que a Baixa" % id)
		_check.call(not low_glow and game.lantern._halos.visible, "luz %s: halos só na Alta" % id)
		_check.call(game.lantern.frame_lights.size() <= int(GfxQuality.budget("lights_max")) - 1,
				"luz %s: respeita lights_max" % id)
		Settings.set_value(GfxQuality.KEY, "low")
		await host.get_tree().process_frame
		_check.call(_count(game.world.built_views()) == low_items, "terreno %s: volta à Baixa igual" % id)
		game.queue_free()
		await host.get_tree().process_frame
	Settings.set_value(GfxQuality.KEY, saved)
	GameClock.paused = false


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
