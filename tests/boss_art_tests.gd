extends RefCounted
## Arte dos chefes, guardiões e Elites (Sengoku Pixel Pack, tools/import_sengoku.py; data/bosses.json
## "sprite"/"walk_sprite"/"attack_sprite"/"faceset" e data/enemies.json "elite_sprite";
## scripts/systems/enemy_look.gd sheet_of e sprite_scale):
##   - dados: toda folha existe, o quadro divide a largura e tem a altura da folha; os retratos
##     existem (38x38); os chefes e guardiões trocados olham para a esquerda, sem montagem nem escala,
##     no tamanho da prancha; as Sombras usam a mesma arte × KAGE_SCALE;
##   - Elite com "elite_sprite" desenha a folha própria sem ELITE_SCALE; Elite sem ela continua
##     com a folha do inimigo × ELITE_SCALE; o raio de colisão do Elite não muda com a arte.
## run_unit() roda sem autoloads (tests/run_tests.gd); run() precisa da árvore
## (tests/integration_tests.gd).

const AbilityTests := preload("res://tests/ability_tests.gd")
const KAGE_SCALE := 1.15
## Ids trocados pela arte do Sengoku Pixel Pack (chefes e guardiões).
const BOSSES := [&"tanuki", &"kappa_elder", &"bamboo_ancestral", &"kitsune_nine", &"tengu_crow_king",
		&"faceless_monk", &"stone_cyclops", &"ash_dragon", &"red_oni", &"kuroe", &"izanami", &"shinigami",
		&"masakado", &"gashadokuro"]
const GUARDS := [&"onikuma", &"nuppeppo", &"onmoraki", &"onibi", &"yomi_hebi", &"datsueba"]
## Chefes gigantes (a Gashadokuro do Osorezan: o esqueleto do Shinigami 1,5x, fogo de alma por cima).
const GIANTS := [&"gashadokuro"]
## Altura do quadro (px na tela) de cada grupo, a da prancha de conferência com folga.
const BOSS_HEIGHT := Vector2(56.0, 90.0)
const GIANT_HEIGHT := Vector2(100.0, 130.0)
const GUARD_HEIGHT := Vector2(34.0, 72.0)
const ELITE_HEIGHT := Vector2(20.0, 44.0)
const FACE_SIZE := 38

var _check: Callable


static func _json(name: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/%s.json" % name))


static func _image(path: String) -> Image:
	if not ResourceLoader.exists(path):
		return null
	return (load(path) as Texture2D).get_image()


func run_unit(check: Callable) -> void:
	_check = check
	var bosses := {}
	for b: Dictionary in _json("bosses"):
		bosses[StringName(String(b["id"]))] = b
	for id: StringName in bosses:
		var b: Dictionary = bosses[id]
		for key: String in ["sprite", "walk_sprite", "attack_sprite"]:
			if b.has(key):
				_sheet_ok(b[key], "%s.%s" % [id, key])
		var sprite: Dictionary = b["sprite"]
		var face := String(b.get("faceset", String(sprite["path"]).get_base_dir().path_join("Faceset.png")))
		var img := _image(face)
		_check.call(img != null and img.get_width() == FACE_SIZE and img.get_height() == FACE_SIZE,
				"%s: retrato %s 38x38", [id, face])
	for id: StringName in BOSSES + GUARDS:
		var b: Dictionary = bosses.get(id, {})
		var sprite: Dictionary = b.get("sprite", {})
		var limits: Vector2 = GUARD_HEIGHT if GUARDS.has(id) else (GIANT_HEIGHT if GIANTS.has(id) else BOSS_HEIGHT)
		var tall := float((sprite.get("frame", [0, 0]) as Array)[1]) * float(b.get("scale", 1.0))
		_check.call(bool(sprite.get("faces_left", false)) and not sprite.has("composite")
				and not b.has("scale") and not b.has("tint") and not b.has("walk_sprite") and not b.has("attack_sprite"),
				"%s: arte do Sengoku olhando para a esquerda, sem montagem, escala, tinta nem folhas antigas", id)
		_check.call(tall >= limits.x and tall <= limits.y, "%s: altura %.0f px no tamanho da prancha", [id, tall])
		var kage: Dictionary = bosses.get(StringName(String(id) + "_kage"), {})
		if not kage.is_empty():
			_check.call(kage["sprite"] == sprite and kage.get("faceset") == b.get("faceset")
					and is_equal_approx(float(kage.get("scale", 1.0)), KAGE_SCALE),
					"%s_kage: mesma arte do Guardião × %.2f", [id, KAGE_SCALE])
	var shini: Dictionary = (bosses.get(&"shinigami", {}) as Dictionary).get("sprite", {})
	var gasha: Dictionary = (bosses.get(&"gashadokuro", {}) as Dictionary).get("sprite", {})
	_check.call(String(shini.get("path", "")).ends_with("bosses/shinigami/Idle.png")
			and String(gasha.get("path", "")) != String(shini.get("path", ""))
			and float((gasha.get("frame", [0, 0]) as Array)[1]) >= 1.4 * float((shini.get("frame", [0, 0]) as Array)[1]),
			"gashadokuro: arte própria, bem maior que a do Shinigami (que continua a mesma)")
	var with_art := 0
	for e: Dictionary in _json("enemies"):
		if not e.has("elite_sprite"):
			continue
		with_art += 1
		var es: Dictionary = e["elite_sprite"]
		var tall := float((es.get("frame", [0, 0]) as Array)[1])
		_sheet_ok(es, "%s.elite_sprite" % e["id"])
		_check.call(String(es["path"]).begins_with("res://assets/art/elites/%s/" % e["id"])
				and bool(es.get("faces_left", false)), "%s: arte do Elite em assets/art/elites, olhando à esquerda", e["id"])
		_check.call(tall >= ELITE_HEIGHT.x and tall <= ELITE_HEIGHT.y, "%s: Elite com %.0f px de altura", [e["id"], tall])
	_check.call(with_art == 11, "11 inimigos com arte própria de Elite (%d)", with_art)


## A folha existe e o quadro (strip) divide a largura e tem a altura dela.
func _sheet_ok(spec: Dictionary, tag: String) -> void:
	var img := _image(String(spec.get("path", "")))
	_check.call(img != null, "%s: folha existe (%s)", [tag, spec.get("path", "")])
	if img == null or String(spec.get("layout", "strip")) != "strip":
		return
	var frame: Array = spec.get("frame", [0, 0])
	var fw := int(frame[0])
	_check.call(fw > 0 and img.get_width() % fw == 0 and img.get_height() == int(frame[1]),
			"%s: quadro %sx%s divide a folha %dx%d", [tag, frame[0], frame[1], img.get_width(), img.get_height()])


func run(host: Node, check: Callable) -> void:
	_check = check
	var a := AbilityTests.new()
	a._check = check
	var game := await a._new_game(host, "aki", 41)
	var em := game.enemies
	var look := em.look
	var art := em.spawn(&"kappa_young", Vector2(40, 0), 1.0, 1.0, true)
	var plain := em.spawn(&"slime_rice", Vector2(-40, 0), 1.0, 1.0, true)
	var common := em.spawn(&"kappa_young", Vector2(0, 40), 1.0, 1.0)
	var t_art := em.type_of(&"kappa_young")
	var t_plain := em.type_of(&"slime_rice")
	_check.call(look.elite_sheets[t_art] != null and look.elite_sheets[t_plain] == null,
			"elite_sprite: só o tipo com a chave tem folha de Elite")
	var sheet := look.sheet_of(art)
	_check.call(sheet == look.elite_sheets[t_art]
			and sheet.texture.resource_path.ends_with("elites/kappa_young/Idle.png")
			and sheet.frame_size == Vector2(33, 37) and sheet.faces_left,
			"Elite com elite_sprite: desenha a folha própria (%s)", sheet.texture.resource_path)
	_check.call(is_equal_approx(look.sprite_scale(art), 1.0), "Elite com elite_sprite: sem ELITE_SCALE (%.2f)",
			look.sprite_scale(art))
	_check.call(look.sheet_of(plain) == em.type_sheets[t_plain]
			and is_equal_approx(look.sprite_scale(plain), em.type_scale[t_plain] * EnemyManager.ELITE_SCALE),
			"Elite sem elite_sprite: folha do inimigo × ELITE_SCALE, como antes")
	_check.call(look.sheet_of(common) == em.type_sheets[t_art]
			and is_equal_approx(look.sprite_scale(common), em.type_scale[t_art]),
			"inimigo comum do mesmo tipo: folha e escala de sempre")
	var base_r := float(DB.enemies[&"kappa_young"].get("radius", 5))
	_check.call(is_equal_approx(em.radius[art], base_r * EnemyManager.ELITE_SCALE)
			and is_equal_approx(em.radius[common], base_r),
			"raio de colisão do Elite igual ao de antes (%.1f)", em.radius[art])
	# Um quadro desenhado com os dois Elites na tela (EnemyLook.draw e EliteAffixes.draw_over).
	GameClock.paused = false
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	_check.call(em.alive[art] == 1 and em.alive[plain] == 1, "Elites desenhados sem erro")
	a._clear(game)
	game.queue_free()
	GameClock.paused = false
	await host.get_tree().process_frame
