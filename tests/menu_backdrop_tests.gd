extends RefCounted
## Fundo dos menus (MenuBackdrop): não captura toque, carrega todas as folhas, procissão com
## variedade andando na crista, guardiã que acompanha o herói escolhido e desenho sem erros
## em vários tamanhos. Chamado por tests/integration_tests.gd, que passa o nó e o _check.

const SIZES: Array[Vector2] = [Vector2(678, 305), Vector2(400, 305), Vector2(900, 400)]


func run(host: Node, check: Callable) -> void:
	var original := SaveManager.data
	SaveManager.data = SaveManager.default_profile()
	var holder := Control.new()
	host.add_child(holder)
	holder.size = SIZES[0]
	var backdrop := MenuBackdrop.new()
	holder.add_child(backdrop)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	check.call(backdrop.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Fundo dos menus: ignora o mouse")
	for layer: Node in backdrop.get_children():
		check.call((layer as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE,
				"Fundo dos menus: camada %s ignora o mouse" % layer.name)
	_check_textures(backdrop, check)
	_check_walkers(backdrop, check, "678x305")
	await _check_hero(host, backdrop, check)
	for area: Vector2 in SIZES:
		holder.size = area
		await host.get_tree().process_frame
		await host.get_tree().process_frame
		check.call(backdrop.size == area, "Fundo dos menus: ocupa a tela toda em %s" % area)
		_check_walkers(backdrop, check, str(area))
	holder.queue_free()
	await host.get_tree().process_frame
	SaveManager.data = original


func _check_textures(backdrop: MenuBackdrop, check: Callable) -> void:
	for field: String in ["_floor", "_nature", "_house", "_element", "_fog", "_grass", "_sky", "_glow",
			"_vignette", "_left_shade", "_ground_shade"]:
		check.call(backdrop.get(field) is Texture2D, "Fundo dos menus: textura %s carregada" % field)
	var sheets: Array[SpriteSheet] = backdrop.get("_walker_sheets")
	var distinct: Dictionary = {}
	for sheet: SpriteSheet in sheets:
		var path := sheet.texture.resource_path if sheet.texture != null else ""
		check.call(path.begins_with("res://assets/art/actors/enemies/"),
				"Fundo dos menus: folha da procissão carregada (%s)" % path)
		distinct[path] = true
	check.call(distinct.size() >= 8, "Fundo dos menus: procissão com ≥ 8 yōkai diferentes (%d)" % distinct.size())


func _check_walkers(backdrop: MenuBackdrop, check: Callable, label: String) -> void:
	var h := backdrop.size.y
	var band: Vector2 = MenuBackdrop.RIDGE_BAND
	var walkers := backdrop.walker_positions()
	check.call(walkers.size() >= 8, "Fundo dos menus %s: procissão com ≥ 8 yōkai (%d)" % [label, walkers.size()])
	var inside := true
	for feet: Vector2 in walkers:
		inside = inside and feet.y >= h * band.x and feet.y <= h * band.y + 1.0
		inside = inside and absf(feet.y - (backdrop.ridge_y(feet.x) + 1.0)) < 0.5
	check.call(inside, "Fundo dos menus %s: yōkai andam sobre a crista" % label)


func _check_hero(host: Node, backdrop: MenuBackdrop, check: Callable) -> void:
	check.call(backdrop.hero_id() == "aki", "Fundo dos menus: guardiã padrão é a Aki")
	for id: String in ["kenta", "yuki"]:
		(SaveManager.data["selected"] as Dictionary)["hero"] = id
		await host.get_tree().create_timer(MenuBackdrop.HERO_CHECK_INTERVAL + 0.2).timeout
		var sheet: SpriteSheet = backdrop.get("_hero")
		# Yuki ("side") é reduzida uma vez numa textura nova, sem caminho: confere o layout.
		var side: bool = backdrop.get("_hero_side") != Vector2.ZERO
		var matches := side if id == "yuki" else sheet.texture.resource_path.contains("/heroes/%s/" % id)
		check.call(backdrop.hero_id() == id and sheet != null and sheet.texture != null and matches,
				"Fundo dos menus: guardiã segue o herói escolhido (%s)" % id)
	(SaveManager.data["selected"] as Dictionary)["hero"] = "nao_existe"
	await host.get_tree().create_timer(MenuBackdrop.HERO_CHECK_INTERVAL + 0.2).timeout
	check.call(backdrop.hero_id() == "aki", "Fundo dos menus: herói desconhecido volta para a Aki")
