extends RefCounted
## Ícones de habilidade (assets/art/ui/skill_icons, tools/gen_skill_icons.gd):
## - todo id de weapons/passives/powerups/kami aponta para <grupo>/<id>.png, que existe, carrega,
##   tem 24x24 e a mesma moldura (cantos chanfrados transparentes, aro opaco);
## - SkillIconPainter: halo das evoluídas só com ui_fx > 0, lampejo ao subir de nível só em
##   Média/Alta (Baixa estático), selo de nível com dígitos 3x5;
## - HUD em partida desenha armas (1ª fileira) e passivas (2ª) sem erro nos 3 níveis e com
##   troca ao vivo do nível, inclusive com arma evoluída.
## Chamado por tests/integration_tests.gd.

const GAME_SCENE := "res://scenes/game/Game.tscn"
const GROUPS := {"weapons": "weapons", "passives": "passives", "powerups": "powerups", "kami": "kami"}


func run(host: Node, check: Callable) -> void:
	_check_files(check)
	_check_painter(check)
	await _check_hud(host, check)
	GfxQuality.clear_override()


func _check_files(check: Callable) -> void:
	var total := 0
	var bad: Array[String] = []
	for table: String in GROUPS:
		var rows: Dictionary = DB.get(table)
		for id: StringName in rows:
			total += 1
			var path := String((rows[id] as Dictionary).get("icon", ""))
			if path != UiIcons.skill_path(GROUPS[table], String(id)):
				bad.append("%s/%s: caminho %s" % [table, id, path])
				continue
			var tex := load(path) as Texture2D if ResourceLoader.exists(path) else null
			if tex == null:
				bad.append("%s/%s: não carrega" % [table, id])
				continue
			if tex.get_size() != Vector2(UiIcons.SKILL_SIZE, UiIcons.SKILL_SIZE):
				bad.append("%s/%s: tamanho %s" % [table, id, tex.get_size()])
				continue
			var img := tex.get_image()
			if img.is_compressed():
				img.decompress()
			# Moldura: canto (0,0) transparente; aro do topo e meio do ícone opacos.
			if img.get_pixel(0, 0).a > 0.01 or img.get_pixel(6, 0).a < 0.99 or img.get_pixel(12, 12).a < 0.99:
				bad.append("%s/%s: moldura fora do padrão" % [table, id])
	check.call(total >= 70, "há ícones para todas as habilidades (%d)" % total)
	check.call(bad.is_empty(), "todo ícone de habilidade existe, carrega, 24x24 com moldura (%s)" % [bad])
	check.call(UiIcons.skill_icon("weapons", "katana") != null and UiIcons.skill_icon("weapons", "nada") == null,
			"UiIcons.skill_icon acha a katana e devolve null para id inexistente")


func _check_painter(check: Callable) -> void:
	check.call(SkillIconPainter.glow_alpha(0, 0.3) == 0.0, "Baixa: evoluída sem halo pulsante")
	var a1 := SkillIconPainter.glow_alpha(1, 0.0)
	var b1 := SkillIconPainter.glow_alpha(1, SkillIconPainter.PULSE_SECONDS * 0.25)
	check.call(a1 > 0.0 and b1 > a1, "Média: halo pulsa (%.2f → %.2f)" % [a1, b1])
	check.call(SkillIconPainter.glow_alpha(2, 0.4) > SkillIconPainter.glow_alpha(1, 0.4),
			"Alta: halo mais forte que na Média")
	for lvl: int in [GfxQuality.LOW, GfxQuality.MEDIUM, GfxQuality.HIGH]:
		GfxQuality.set_override(lvl)
		var p := SkillIconPainter.new()
		check.call(not p.note("w:katana", 1, 10.0), "nível %d: primeira vez não conta como subida" % lvl)
		check.call(p.note("w:katana", 2, 10.5), "nível %d: 1 → 2 conta como subida" % lvl)
		var f := p.flash("w:katana", 10.6)
		if lvl == GfxQuality.LOW:
			check.call(f == 0.0, "Baixa: sem lampejo ao subir de nível")
		else:
			check.call(f > 0.0 and p.flash("w:katana", 12.0) == 0.0, "nível %d: lampejo curto ao subir" % lvl)
	GfxQuality.clear_override()
	var digits_ok := true
	for d: Array in SkillIconPainter.DIGITS:
		digits_ok = digits_ok and d.size() == 5 and d.all(func(v: int) -> bool: return v >= 0 and v <= 7)
	check.call(SkillIconPainter.DIGITS.size() == 10 and digits_ok, "selo de nível tem os 10 dígitos 3x5")
	check.call(SkillIconPainter.STAR.size() == 5 and SkillIconPainter.STAR_OUTLINE.size() == 7,
			"evolução de nível único usa estrela 5x5 com contorno 7x7 em vez do selo \"1\"")


func _check_hud(host: Node, check: Callable) -> void:
	var game := (load(GAME_SCENE) as PackedScene).instantiate() as HyakkiGame
	game.config = {"hero": "aki", "stage": "village", "moon": 0, "mode": "normal", "seed": 5, "speed": 1}
	host.add_child(game)
	await host.get_tree().process_frame
	game.player.god_mode = true
	game.add_weapon(&"shuriken")
	game.add_weapon(&"dawn_blade")
	game.level_up.passive_levels[&"sake"] = 2
	game.level_up.passive_levels[&"jade"] = 5
	var painter := game.hud.get("_skill_icons") as SkillIconPainter
	check.call(painter != null, "HUD tem o pintor de ícones de habilidade")
	var top := game.hud.get("_top") as Control
	for lvl: int in [GfxQuality.LOW, GfxQuality.MEDIUM, GfxQuality.HIGH, GfxQuality.LOW]:
		GfxQuality.set_override(lvl)
		top.queue_redraw()
		await host.get_tree().process_frame
		await host.get_tree().process_frame
		var shuriken := game.get_weapon(&"shuriken")
		shuriken.level_up()
		top.queue_redraw()
		await host.get_tree().process_frame
		await host.get_tree().process_frame
		var now := Time.get_ticks_msec() / 1000.0
		var flashing := painter.flash("w:shuriken", now) > 0.0
		check.call(flashing == (lvl != GfxQuality.LOW),
				"HUD nível %d: arma subiu de nível %s lampejo" % [lvl, "com" if lvl != GfxQuality.LOW else "sem"])
	check.call(game.hud.get("_skill_icons") == painter, "troca ao vivo do nível não recria a HUD")
	game.queue_free()
	GameClock.paused = false
	await host.get_tree().process_frame
