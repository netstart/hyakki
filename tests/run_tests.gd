extends SceneTree
## Testes das regras puras (plano 14.1). Sem cena e sem autoloads.
## Rodar: godot --headless --path . --script res://tests/run_tests.gd

var _count: int = 0
var _failures: int = 0


func _initialize() -> void:
	_test_xp_curve()
	_test_target_count()
	_test_spatial_hash()
	_test_segment_hit()
	_test_damage_control()
	_test_hit_sounds()
	_test_settings_defaults()
	_test_journey_geo()
	_test_gfx_quality()
	_test_ads_config()
	load("res://tests/enemy_fx_tests.gd").run_unit(_check)
	(load("res://tests/terrain_tests.gd") as GDScript).new().run_unit(_check)
	(load("res://tests/pickup_spawn_tests.gd") as GDScript).new().run_unit(_check)
	print("%d verificações, %d falhas" % [_count, _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	_count += 1
	if not condition:
		_failures += 1
		printerr("FALHOU: " + label)
	elif "--verbose" in OS.get_cmdline_user_args():
		print("ok: " + label)


## Modo "sem anúncios": só liga os anúncios de release com todos os IDs reais preenchidos.
func _test_ads_config() -> void:
	var app_id := "ca-app-pub-1234567890123456~1234567890"
	var real := {"app_open": "ca-app-pub-1234567890123456/1111111111",
			"rewarded": "ca-app-pub-1234567890123456/2222222222"}
	_check(AdMobProvider.ids_configured(real, app_id), "IDs reais + ID do app: anúncios de release ligados")
	_check(not AdMobProvider.ids_configured({"app_open": "", "rewarded": ""}, app_id),
			"blocos vazios: sem anúncios")
	_check(not AdMobProvider.ids_configured({"app_open": real["app_open"], "rewarded": ""}, app_id),
			"um bloco vazio basta para ficar sem anúncios")
	_check(not AdMobProvider.ids_configured(real, ""), "sem o ID do app: sem anúncios")
	_check(not AdMobProvider.ids_configured(real, "ca-app-pub-3940256099942544~3347511713"),
			"ID de app de teste do Google não conta como real")
	_check(not AdMobProvider.ids_configured(AdMobProvider.TEST_UNITS, app_id),
			"blocos de teste do Google não contam como reais")
	_check(not AdMobProvider.ids_configured(real, "ca-app-pub-1234567890123456/1"),
			"ID do app precisa do formato com ~")
	_check(not AdMobProvider.ids_configured({}, app_id), "sem blocos: sem anúncios")
	_check(AdMobProvider.has_release_ids() == AdMobProvider.ids_configured(AdMobProvider.RELEASE_UNITS,
			String(ProjectSettings.get_setting(AdMobProvider.APP_ID_SETTING, ""))), "has_release_ids lê o projeto")
	_check(AdMobProvider.ads_allowed() == (OS.is_debug_build() or AdMobProvider.has_release_ids()),
			"anúncios ligados = debug ou IDs reais")


func _test_xp_curve() -> void:
	_check(Progression.xp_to_next(1) == 5, "xp nível 1 = 5")
	_check(Progression.xp_to_next(2) == 15, "xp nível 2 = 15")
	_check(Progression.xp_to_next(19) == 185, "xp nível 19 = 185")
	_check(Progression.xp_to_next(20) == 185 + 13 + 600, "nível 20 tem o muro de +600")
	_check(Progression.xp_to_next(21) == 185 + 26, "nível 21 volta a +13 por nível")
	_check(Progression.xp_to_next(40) == 185 + 260 + 16 + 2400, "nível 40 tem o muro de +2400")
	for level: int in range(1, 19):
		_check(Progression.xp_to_next(level + 1) > Progression.xp_to_next(level),
				"curva cresce do nível %d para o %d" % [level, level + 1])


func _test_target_count() -> void:
	_check(Progression.target_count(0.0, 500) == 15, "alvo no minuto 0 = 15")
	_check(Progression.target_count(1.0, 500) == 38, "alvo no minuto 1 = 38")
	_check(Progression.target_count(15.0, 500) == 500, "alvo respeita o teto")
	_check(is_equal_approx(Progression.enemy_hp_mult(10.0), 1.8), "HP ×1,8 no minuto 10")
	_check(Progression.spawn_rate(10.0) > Progression.spawn_rate(0.0), "ritmo de nascimento cresce com o tempo")


## Controle de dano recebido (plano 4.15).
func _test_damage_control() -> void:
	var d := DamageControl.new()
	_check(is_equal_approx(d.resolve(5.0, 2.0, 100.0, false, 0.0), 3.0), "armadura tira do golpe")
	_check(is_equal_approx(d.resolve(2.0, 5.0, 100.0, false, 0.0), 1.0), "golpe mínimo 1 com armadura alta")
	_check(is_equal_approx(d.resolve(10.0, 0.0, 100.0, true, 0.0), 6.0), "Brisa tira 40%")
	_check(is_equal_approx(d.resolve(80.0, 0.0, 100.0, false, 0.0), 34.0), "teto por golpe: 34% do HP máx.")
	_check(d.resolve(99999.0, 0.0, 100.0, false, 0.0) >= DamageControl.LETHAL, "golpe letal passa pelos tetos")
	d.reset()
	d.record(&"slime_rice", 30.0, 0.0)
	_check(is_equal_approx(d.resolve(30.0, 0.0, 100.0, false, 0.5), 15.0), "teto da janela: 45% em 2 s")
	d.record(&"slime_rice", 15.0, 0.5)
	_check(d.resolve(30.0, 0.0, 100.0, false, 1.0) == 0.0, "janela cheia absorve o golpe")
	_check(is_equal_approx(d.resolve(30.0, 0.0, 100.0, false, 2.6), 30.0), "janela libera depois de 2 s")
	d.record(&"skeleton_peasant", 20.0, 61.0)
	d.record(&"", 0.0, 62.0)
	_check(is_equal_approx(d.total, 65.0) and d.hits == 3, "registra total e golpes")
	_check(d.last_source == &"skeleton_peasant", "golpe zerado não vira causa da morte")
	_check(d.top_sources(1) == [&"slime_rice"], "fonte que mais feriu primeiro")
	_check(d.per_minute.size() == 2 and is_equal_approx(d.per_minute[1], 20.0), "dano por minuto")
	var copy := DamageControl.new()
	copy.restore(d.summary())
	_check(is_equal_approx(copy.total, d.total) and copy.last_source == d.last_source
			and copy.by_source.size() == 2, "summary/restore ida e volta")


func _test_spatial_hash() -> void:
	var grid := SpatialHash.new(24.0)
	grid.insert(1, Vector2(10.0, 10.0))
	grid.insert(2, Vector2(100.0, 100.0))
	grid.insert(3, Vector2(-30.0, 5.0))
	var found: Array[int] = []
	grid.query(Vector2(0.0, 0.0), 20.0, found)
	_check(found.has(1), "acha o vizinho próximo")
	_check(not found.has(2), "não acha o distante")
	grid.query(Vector2(-25.0, 0.0), 10.0, found)
	_check(found.has(3), "funciona com coordenadas negativas")
	grid.clear()
	grid.query(Vector2(0.0, 0.0), 20.0, found)
	_check(found.is_empty(), "clear esvazia a grade")


func _test_segment_hit() -> void:
	var a := Vector2(0.0, 0.0)
	var b := Vector2(30.0, 0.0)
	_check(Geometry.segment_hits_circle(a, b, Vector2(15.0, 3.0), 5.0),
			"projétil rápido acerta alvo no meio do caminho (sem tunneling)")
	_check(not Geometry.segment_hits_circle(a, b, Vector2(15.0, 9.0), 5.0),
			"não acerta alvo fora do raio")
	_check(not Geometry.segment_hits_circle(a, b, Vector2(40.0, 0.0), 5.0),
			"não acerta alvo depois do fim do segmento")


func _test_hit_sounds() -> void:
	var cases := {
		"katana": "hit_blade", "blade_cyclone": "hit_blade", "onikiri": "hit_blade",
		"shuriken": "hit_projectile", "kunai": "hit_projectile", "yumi": "hit_projectile",
		"kusarigama": "hit_projectile", "hitodama": "hit_fire", "raijin": "hit_thunder",
		"typhoon": "hit_thunder", "fujin_fan": "hit_wind", "hurricane": "hit_wind",
		"taiko": "hit_area", "incense": "hit_area", "ofuda": "hit_orbit", "smoke_bomb": "hit_poison",
	}
	for behavior: String in cases:
		_check(HitSounds.for_weapon({"behavior": behavior, "tags": []}) == cases[behavior],
				"som do golpe: %s -> %s" % [behavior, cases[behavior]])
	_check(HitSounds.for_weapon({"behavior": "taiko", "tags": ["area"]}) == "hit_area",
			"comportamento vence a tag (Trovão Ritual usa taiko)")
	_check(HitSounds.for_weapon({"behavior": "kaminari", "tags": ["thunder"]}) == "hit_thunder",
			"arma nova com tag thunder -> hit_thunder")
	_check(HitSounds.for_weapon({"behavior": "x", "tags": ["projectile", "fire"]}) == "hit_fire",
			"fogo tem prioridade sobre projétil")
	_check(HitSounds.for_weapon({}) == "hit", "sem arma (Kami, especial) -> hit")
	_check(HitSounds.for_weapon({"behavior": "x", "tags": ["nada"]}) == "hit", "desconhecido -> hit")

## Opções novas vêm ligadas: números de dano, sons de golpe nos inimigos e de dano no herói.
func _test_settings_defaults() -> void:
	var script := load("res://scripts/autoload/settings.gd") as GDScript
	var defaults: Dictionary = script.get_script_constant_map()["DEFAULTS"]
	for key: String in ["damage_numbers", "damage_sounds", "hurt_sounds"]:
		_check(defaults.get(key) == true, "opção %s vem ligada por padrão" % key)


## Mapa da Jornada (scripts/app/journey_geo.gd): estados, projeção, encaixe, contornos,
## afastamento dos pontos, estrada e tracejado.
func _test_journey_geo() -> void:
	_check(JourneyGeo.stage_state(true, true) == &"cleared", "jornada: vencida -> cleared")
	_check(JourneyGeo.stage_state(false, true) == &"open", "jornada: liberada -> open")
	_check(JourneyGeo.stage_state(false, false) == &"locked", "jornada: bloqueada -> locked")
	var tokyo := JourneyGeo.project(Vector2(139.45, 35.7))
	var sendai := JourneyGeo.project(Vector2(140.9, 38.27))
	_check(sendai.y < tokyo.y and sendai.x > tokyo.x, "jornada: norte fica em cima, leste à direita")
	var area := Rect2(10, 40, 300, 200)
	var pts: Array[Vector2] = []
	for id: StringName in JourneyGeo.STAGES:
		pts.append(JourneyGeo.project(JourneyGeo.STAGES[id]))
	var xf := JourneyGeo.fit(pts, area)
	var inside := true
	for p: Vector2 in pts:
		inside = inside and area.grow(0.01).has_point(xf * p)
	_check(inside, "jornada: encaixe põe todos os pontos na área")
	for poly: Array in [JourneyGeo.HONSHU, JourneyGeo.HOKKAIDO, JourneyGeo.SHIKOKU, JourneyGeo.KYUSHU,
			JourneyGeo.KOREA] + JourneyGeo.ISLETS:
		var projected := JourneyGeo.project_all(poly, xf)
		_check(not Geometry2D.triangulate_polygon(projected).is_empty(),
				"jornada: contorno de %d pontos é um polígono válido" % poly.size())
		for passes: int in [1, 2]:
			var smooth := JourneyGeo.chaikin(projected, passes)
			_check(smooth.size() == projected.size() * (2 ** passes)
					and not Geometry2D.triangulate_polygon(smooth).is_empty(),
					"jornada: costa de %d pontos suavizada (%d passes) segue válida" % [poly.size(), passes])
	var corners := PackedVector2Array([Vector2(0, 0), Vector2(8, 0), Vector2(8, 8), Vector2(0, 8)])
	var square := JourneyGeo.chaikin(corners, 1)
	_check(square.size() == 8 and square[0] == Vector2(2, 0) and square[1] == Vector2(6, 0),
			"jornada: Chaikin corta os cantos a 1/4 e 3/4 de cada aresta")
	var islands: Array[PackedVector2Array] = []
	for poly: Array in [JourneyGeo.HONSHU, JourneyGeo.KYUSHU]:
		islands.append(JourneyGeo.chaikin(JourneyGeo.project_all(poly, xf), 2))
	for id: StringName in JourneyGeo.STAGES:
		var at := xf * JourneyGeo.project(JourneyGeo.STAGES[id])
		var on_land := false
		for island: PackedVector2Array in islands:
			on_land = on_land or Geometry2D.is_point_in_polygon(at, island)
		_check(on_land, "jornada: ponto %s fica em terra depois da costa suavizada" % id)
	var crowded := {&"a": Vector2(50, 50), &"b": Vector2(52, 51), &"c": Vector2(300, 100)}
	var apart := JourneyGeo.separate(crowded, 30.0, Rect2(0, 0, 400, 200))
	var gap: Vector2 = ((apart[&"b"] as Vector2) - (apart[&"a"] as Vector2)).abs()
	_check(maxf(gap.x, gap.y) >= 29.9, "jornada: pontos colados se afastam até os quadrados não se tocarem")
	_check(apart[&"c"] == Vector2(300, 100), "jornada: ponto já afastado não se mexe")
	var curve := JourneyGeo.catmull_rom(PackedVector2Array([Vector2.ZERO, Vector2(10, 5), Vector2(20, 0)]), 4)
	_check(curve[0] == Vector2.ZERO and curve[curve.size() - 1] == Vector2(20, 0) and curve.size() == 9,
			"jornada: estrada passa pelas pontas")
	var dash := JourneyGeo.dashes(PackedVector2Array([Vector2.ZERO, Vector2(20, 0)]), 4.0, 2.0)
	_check(dash.size() == 8 and dash[1] == Vector2(4, 0) and dash[2] == Vector2(6, 0), "jornada: tracejado 4/2")


## Qualidade gráfica (scripts/core/gfx_quality.gd): regra do nível, detecção, pick, todos os
## orçamentos em todos os níveis, override e ciclo da pausa. Sem autoloads: a opção vale "auto".
func _test_gfx_quality() -> void:
	var q := GfxQuality
	_check(q.LOW == 0 and q.MEDIUM == 1 and q.HIGH == 2, "gfx: constantes LOW/MEDIUM/HIGH")
	_check(q.changed_signal_key() == "graphics_quality", "gfx: chave do sinal")
	_check(q.resolve("low", q.HIGH) == q.LOW and q.resolve("medium", q.LOW) == q.MEDIUM
			and q.resolve("high", q.LOW) == q.HIGH, "gfx: opção fixa ignora a detecção")
	_check(q.resolve("auto", q.HIGH) == q.HIGH and q.resolve("auto", q.MEDIUM) == q.MEDIUM,
			"gfx: auto usa o nível detectado")
	_check(q.resolve("auto", q.HIGH, 1) == q.MEDIUM and q.resolve("auto", q.HIGH, 5) == q.LOW,
			"gfx: rebaixamentos do auto descem até LOW")
	_check(q.resolve("high", q.HIGH, 2) == q.HIGH, "gfx: rebaixamento não afeta opção fixa")
	_check(q.resolve("???", q.MEDIUM) == q.MEDIUM, "gfx: valor inválido vale auto")
	var gb := 1024 * 1024 * 1024
	_check(q.classify(false, 2, gb, "") == q.HIGH, "gfx: desktop -> HIGH")
	_check(q.classify(true, 8, 8 * gb, "Adreno (TM) 740") == q.HIGH, "gfx: celular 8 núcleos 8 GB -> HIGH")
	_check(q.classify(true, 8, 4 * gb, "Mali-G57") == q.MEDIUM, "gfx: 8 núcleos com 4 GB -> MEDIUM")
	_check(q.classify(true, 8, -1, "") == q.MEDIUM, "gfx: memória desconhecida não conta como 6 GB")
	_check(q.classify(true, 6, 8 * gb, "") == q.MEDIUM, "gfx: 6 núcleos -> MEDIUM")
	_check(q.classify(true, 4, 8 * gb, "") == q.LOW, "gfx: 4 núcleos -> LOW")
	_check(q.classify(true, 8, 8 * gb, "Mali-T880") == q.LOW, "gfx: GPU antiga conhecida -> LOW")
	_check(q.detected_level() in [q.LOW, q.MEDIUM, q.HIGH], "gfx: detected_level válido")
	_check(q.mode() == "auto" and q.level() == q.detected_level(), "gfx: sem Settings vale auto")
	var expected := {
		"particles_max": [250, 600, 1400], "weather_drops": [60, 160, 420], "weather_layers": [1, 2, 3],
		"ambient_motes": [8, 24, 60], "decor_density": [0.7, 1.0, 1.25], "grass_sway": [false, true, true],
		"post_fx": [false, true, true], "glow": [false, false, true], "soft_shadows": [false, true, true],
		"enemy_fx": [0, 1, 2], "weapon_fx": [0, 1, 2], "screen_shake": [0.6, 1.0, 1.0],
		"trail_points": [0, 6, 14], "lights_max": [4, 10, 24], "splashes": [false, true, true],
		"ui_fx": [0, 1, 2],
	}
	_check(expected.keys().size() == q.BUDGETS.size(), "gfx: todas as chaves de orçamento testadas")
	for lv: int in [q.LOW, q.MEDIUM, q.HIGH]:
		q.set_override(lv)
		_check(q.level() == lv and q.is_low() == (lv == q.LOW) and q.is_high() == (lv == q.HIGH),
				"gfx: override %d vale" % lv)
		_check(q.pick("a", "b", "c") == ["a", "b", "c"][lv], "gfx: pick no nível %d" % lv)
		for key: String in expected:
			var want: Variant = (expected[key] as Array)[lv]
			var got: Variant = q.budget(key)
			_check(typeof(got) == typeof(want) and got == want,
					"gfx: budget %s no nível %d = %s (veio %s)" % [key, lv, want, got])
	q.set_override(9)
	_check(q.level() == q.HIGH, "gfx: override fora da faixa é limitado")
	q.clear_override()
	_check(q.level() == q.detected_level(), "gfx: clear_override volta ao auto")
	_check(q.budget_at("weather_drops", q.LOW) == 60, "gfx: budget_at")
	_check(q.next_mode("auto") == "low" and q.next_mode("low") == "medium" and q.next_mode("medium") == "high"
			and q.next_mode("high") == "auto", "gfx: ciclo Auto → Baixa → Média → Alta → Auto")
