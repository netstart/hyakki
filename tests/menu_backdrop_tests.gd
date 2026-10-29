extends RefCounted
## Fundo dos menus (MenuBackdrop): não captura toque, carrega todas as folhas, procissão com
## variedade andando na crista, guardiã que acompanha o herói escolhido e desenho sem erros
## em cada resolução de tests/device_profiles.gd e em tamanhos fora da lista. Chamado por
## tests/integration_tests.gd, que passa o nó e o _check.

## Tamanhos fora da lista de resoluções: só robustez do desenho (estreito e grande).
const ODD_SIZES: Array[Vector2] = [Vector2(400, 305), Vector2(900, 400)]
const DeviceProfiles := preload("res://tests/device_profiles.gd")


func run(host: Node, check: Callable) -> void:
	var original := SaveManager.data
	SaveManager.data = SaveManager.default_profile()
	var holder := Control.new()
	host.add_child(holder)
	holder.size = DeviceProfiles.main_view()
	var backdrop := MenuBackdrop.new()
	holder.add_child(backdrop)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	check.call(backdrop.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Fundo dos menus: ignora o mouse")
	for layer: Node in backdrop.get_children():
		check.call((layer as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE,
				"Fundo dos menus: camada %s ignora o mouse" % layer.name)
	_check_textures(backdrop, check)
	_check_walkers(backdrop, check, "%dx%d" % [holder.size.x, holder.size.y])
	await _check_hero(host, backdrop, check)
	await _check_redraw_budget(host, backdrop, check)
	for area: Vector2 in DeviceProfiles.views() + ODD_SIZES:
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


## Desempenho: o cenário animado é refeito a REDRAW_HZ (não a cada quadro), as camadas fixas
## (lua, cordilheiras, chão, caminho, árvores, vinheta) não são refeitas sem mudar o tamanho,
## nenhuma camada animada usa polígonos, e escondido o fundo não anima nem redesenha.
func _check_redraw_budget(host: Node, backdrop: MenuBackdrop, check: Callable) -> void:
	var layers: Array[Control] = backdrop.get("_layers")
	var dynamic: Array[Control] = backdrop.get("_dynamic")
	var light := backdrop.get("_light") as Control
	var shade := backdrop.get("_shade") as Control
	check.call(layers.size() >= 10 and dynamic.size() >= 5 and dynamic.has(light) and not dynamic.has(shade),
			"Fundo dos menus: camadas fixas e animadas separadas (%d camadas, %d animadas)" % [layers.size(),
			dynamic.size()])
	var counts: Array[int] = []
	counts.resize(layers.size())
	var hooks: Array[Callable] = []
	for i: int in range(layers.size()):
		var hook := func() -> void: counts[i] += 1
		hooks.append(hook)
		layers[i].draw.connect(hook)
	var frames := 0
	var start := Time.get_ticks_usec()
	while Time.get_ticks_usec() - start < 600000:
		await host.get_tree().process_frame
		frames += 1
	var seconds := (Time.get_ticks_usec() - start) / 1e6
	var budget := ceili(seconds * MenuBackdrop.REDRAW_HZ) + 2
	var animated_ok := true
	var still_ok := true
	for i: int in range(layers.size()):
		if dynamic.has(layers[i]):
			animated_ok = animated_ok and counts[i] >= 3 and counts[i] <= mini(budget, frames)
		else:
			still_ok = still_ok and counts[i] == 0
	check.call(animated_ok, "Fundo dos menus: camadas animadas refeitas até %d vezes/s (%s em %d quadros, %.2f s)" % [
			MenuBackdrop.REDRAW_HZ, counts, frames, seconds])
	check.call(still_ok, "Fundo dos menus: camadas fixas não são refeitas a cada quadro (%s)" % [counts])
	backdrop.hide()
	counts.fill(0)
	for k: int in range(12):
		await host.get_tree().process_frame
	check.call(counts.max() == 0 and not backdrop.is_processing(), "Fundo dos menus: escondido não anima nem redesenha")
	backdrop.show()
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	check.call(backdrop.is_processing() and counts[layers.find(dynamic[0])] >= 1,
			"Fundo dos menus: volta a animar ao reaparecer")
	counts.fill(0)
	var holder := backdrop.get_parent() as Control
	holder.size += Vector2(10, 0)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	check.call(counts.min() >= 1, "Fundo dos menus: todas as camadas refeitas quando o tamanho muda (%s)" % [counts])
	holder.size -= Vector2(10, 0)
	# Lista rolando pelo dedo: o cenário espera (sem redesenho e sem andar o tempo).
	for k: int in range(4):
		await host.get_tree().process_frame
	var time_before := float(backdrop.get("_time"))
	counts.fill(0)
	var start_busy := Time.get_ticks_usec()
	while Time.get_ticks_usec() - start_busy < 250000:
		TouchScroll.mark_moving()
		await host.get_tree().process_frame
	check.call(counts.max() == 0 and is_equal_approx(float(backdrop.get("_time")), time_before),
			"Fundo dos menus: espera parado enquanto a lista rola pelo dedo (%s)" % [counts])
	var wait_free := Time.get_ticks_usec()
	while TouchScroll.busy() and Time.get_ticks_usec() - wait_free < 1000000:
		await host.get_tree().process_frame
	var wait_redraw := Time.get_ticks_usec()
	while counts[layers.find(dynamic[0])] == 0 and Time.get_ticks_usec() - wait_redraw < 500000:
		await host.get_tree().process_frame
	check.call(counts[layers.find(dynamic[0])] >= 1, "Fundo dos menus: volta a animar quando a lista para")
	for i: int in range(layers.size()):
		layers[i].draw.disconnect(hooks[i])
	_check_no_polygons(backdrop, check)


## As camadas animadas não chamam desenho de polígono (polígono, polilinha, arco, multilinha):
## cada um cria um buffer de vértices novo na GPU a cada redesenho. Confere no código das funções
## que pintam as camadas animadas.
func _check_no_polygons(backdrop: MenuBackdrop, check: Callable) -> void:
	var source := (backdrop.get_script() as GDScript).source_code
	var painters: PackedStringArray = ["_paint_sky_stars", "_paint_clouds", "_paint_far_fog", "_paint_procession",
			"_paint_ground_fog", "_paint_fire_and_hero", "_paint_front", "_draw_lights", "_draw_procession", "_draw_hero",
			"_draw_fireflies", "_draw_fog_band", "_draw_sprite", "_light_at"]
	var offenders: PackedStringArray = []
	for name: String in painters:
		var at := source.find("func %s(" % name)
		if at < 0:
			offenders.append(name + " (não encontrada)")
			continue
		var end := source.find("\nfunc ", at + 5)
		var body := source.substr(at, (end if end > 0 else source.length()) - at)
		for call: String in ["draw_polygon(", "draw_colored_polygon(", "draw_polyline(", "draw_arc(", "draw_multiline("]:
			if body.contains(call):
				offenders.append("%s usa %s" % [name, call])
	check.call(offenders.is_empty(), "Fundo dos menus: camadas animadas sem polígonos %s" % [offenders])
