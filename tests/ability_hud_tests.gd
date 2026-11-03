extends RefCounted
## Habilidades na HUD (scripts/ui/ability_pad.gd), com o dublê tests/ability_stub.gd:
##   check_layout (de tests/hud_layout_tests.gd, em cada resolução de tests/device_profiles.gd, sem
##     e com o furo da câmera de cada lado, nos idiomas do caso): com o joystick fixo de cada lado
##     (canhoto e destro) e cada estado (pronta, recarga com segundos, sem energia, pagando com vida,
##     travadas no nível 1 e no 5), os 3 botões (alvo de toque ≥ 28), o custo, o cadeado com "Nv 5",
##     a barra de energia (glifo, barra e valor) e o texto de desbloqueio de cada habilidade inteiros
##     na área segura, sem sobrepor uns aos outros, o Golpe, o joystick fixo, os botões do canto, o
##     topo (barra de XP, textos e as fileiras de 6 ícones) nem a dica e o aviso do centro (com a dica
##     tutorial.abilities); arco do lado oposto ao joystick, colado no Golpe;
##   run_touch (uma vez): tocar no botão chama activate; com o polegar no joystick (outro dedo) o
##     toque no botão e no Golpe ainda valem e o joystick segue preso ao 1º dedo; toque bloqueado com
##     a HUD em contagem; travada e sem energia dão aviso, tremor e o piscar da barra; o Golpe não é
##     mais um Button que pega o mouse (sem toque duplo); estado parado não redesenha e a recarga
##     redesenha só a camada de cima.

const Stub := preload("res://tests/ability_stub.gd")
const NUMBERS := [99, "59:59", 999999, 9999999]
const ICON_SLOTS := 6
## Heróis do layout: Aki (comum), Yuki (pagando com vida) e Hana (energia 120, custo 70).
const HEROES: Array[StringName] = [&"aki", &"yuki", &"hana"]

var _check: Callable
var _host: Node


func _ok(condition: bool, label: String) -> void:
	_check.call(condition, label)


# --- Layout ------------------------------------------------------------------------------------

func check_layout(host: Node, hud: Hud, safe: Rect2, langs: Array, label: String, check: Callable) -> void:
	_check = check
	_host = host
	var pad := hud.ability_pad()
	var stub: RefCounted = Stub.new()
	pad.source = stub
	Settings.set_value("joystick_mode", "fixed")
	for side: String in ["left", "right"]:
		Settings.set_value("joystick_side", side)
		await host.get_tree().process_frame
		var st := "Habilidades HUD [%s] joystick à %s" % [label, "esquerda" if side == "left" else "direita"]
		var fixed := _fixed_rects(hud)
		_check_arc(hud, safe, side == "left", st)
		for hero: StringName in HEROES:
			stub.call("setup", hero)
			for state: String in ["ready", "cooldown", "no_energy", "blood", "locked_1", "locked_5"]:
				_apply_state(stub, state)
				pad.refresh()
				pad.call("_process", 0.0)
				_check_pad(pad, safe, fixed, "%s %s %s" % [st, hero, state])
		for lang: String in langs:
			Locale.set_language(lang, false)
			stub.call("setup", &"aki")
			for hero: StringName in DB.ids("heroes"):
				stub.call("setup", hero)
				_apply_state(stub, "locked_1")
				pad.refresh()
				pad.call("_process", 0.0)
				var sub := "%s %s %s" % [st, lang, hero]
				_check_locked_text(pad, sub)
				for slot: int in 3:
					pad.show_caption(slot)
					var cap := pad.caption_rect()
					_ok(cap.size.x > 0.0 and safe.grow(-2.0).encloses(cap),
							"%s: nome da habilidade %d liberada na área segura (%s em %s)" % [sub, slot + 1, cap, safe])
					for r: Rect2 in fixed + _pad_rects(pad):
						_ok(not r.intersects(cap), "%s: nome da habilidade %d sem sobrepor (%s e %s)" % [sub, slot + 1, cap, r])
			await _check_center_texts(hud, safe, "%s %s" % [st, lang])
		pad.caption().visible = false
	Locale.set_language("pt_BR", false)
	pad.source = null
	pad.call("_process", 0.0)


func _apply_state(stub: RefCounted, state: String) -> void:
	stub.set("level", 10)
	stub.set("left", PackedFloat32Array([0.0, 0.0, 0.0]))
	stub.set("value", float(stub.call("energy_max")))
	stub.set("blood", INF)
	match state:
		"cooldown":
			stub.set("left", PackedFloat32Array([12.4, 3.2, 0.6]))
		"no_energy":
			stub.set("value", 3.0)
		"blood":
			stub.set("value", 3.0)
			stub.set("blood", 12.0)
		"locked_1":
			stub.set("level", 1)
		"locked_5":
			stub.set("level", 5)


## Botões do canto, Golpe, joystick fixo e o topo (pior caso de números e 6+6 ícones).
func _fixed_rects(hud: Hud) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for key: String in ["_pause_button", "_speed_button"]:
		out.append((hud.get(key) as Control).get_global_rect())
	var joy := hud.joystick
	var c := joy.get_global_transform() * joy.fixed_center()
	out.append(Rect2(c - Vector2.ONE * TouchJoystick.RADIUS, Vector2.ONE * TouchJoystick.RADIUS * 2.0))
	var counters := "%s %s   %s %s" % [TranslationServer.translate("hud.kills"), Locale.format_number(NUMBERS[2]),
			TranslationServer.translate("hud.ryo"), Locale.format_number(NUMBERS[3])]
	var layout: Dictionary = hud.top_layout(TranslationServer.translate("hud.level") % NUMBERS[0], NUMBERS[1], counters)
	for key: String in ["xp", "level", "clock", "counters"]:
		out.append(layout[key] as Rect2)
	var step := SkillIconPainter.ICON + 3.0
	for key: String in ["weapons_at", "passives_at"]:
		out.append(Rect2(layout[key] as Vector2, Vector2(step * ICON_SLOTS - 3.0, SkillIconPainter.ICON)))
	return out


## Peças do arco nas coordenadas da HUD: os 3 alvos de toque e a barra de energia.
func _pad_rects(pad: AbilityPad) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for slot: int in 3:
		out.append(pad.button_rect(slot))
	out.append(pad.gauge_rect())
	return out


func _check_arc(hud: Hud, safe: Rect2, joystick_left: bool, st: String) -> void:
	var pad := hud.ability_pad()
	var ult := (hud.get("_ult_button") as Control).get_global_rect()
	_ok(pad.ult_center.distance_to(ult.get_center()) < 0.6,
			"%s: arco em volta do Golpe (%s e %s)" % [st, pad.ult_center, ult])
	_ok(pad.on_left != joystick_left and (pad.button_center(0).x < safe.get_center().x) != joystick_left,
			"%s: arco do lado oposto ao joystick" % st)
	_ok((hud.get("_ult_button") as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"%s: o toque do Golpe vem do arco (multitoque), não do Button" % st)


## Botões, custo, cadeado e barra num estado.
func _check_pad(pad: AbilityPad, safe: Rect2, fixed: Array[Rect2], st: String) -> void:
	var ult_r := pad.ult_radius
	var buttons := pad.buttons()
	for slot: int in 3:
		var b := buttons[slot]
		var r := pad.button_rect(slot)
		_ok(b.visible and safe.encloses(r) and r.size.x >= 28.0 and r.size.y >= 28.0,
				"%s: botão %d inteiro na área segura com alvo de toque (%s em %s)" % [st, slot + 1, r, safe])
		_ok(b.get_global_rect().is_equal_approx(r), "%s: botão %d no lugar (%s)" % [st, slot + 1, b.get_global_rect()])
		var c := pad.button_center(slot)
		_ok(c.distance_to(pad.ult_center) >= ult_r + AbilityPad.HIT - 0.5
				and c.distance_to(pad.ult_center) <= ult_r + AbilityPad.HIT + 8.0,
				"%s: botão %d colado no Golpe, sem sobrepor" % [st, slot + 1])
		for o: int in range(slot):
			_ok(c.distance_to(pad.button_center(o)) >= AbilityPad.HIT * 2.0,
					"%s: botões %d e %d sem sobrepor os alvos" % [st, o + 1, slot + 1])
		for f: Rect2 in fixed:
			_ok(not f.intersects(r), "%s: botão %d longe do joystick, cantos e topo (%s e %s)" % [st, slot + 1, r, f])
		var state := b.state
		_ok(not state.is_empty(), "%s: botão %d com estado" % [st, slot + 1])
		var box := Rect2(Vector2.ZERO, b.size)
		if bool(state.get("unlocked", false)):
			var cost := b.cost_rect()
			_ok(box.encloses(cost) and cost.position.distance_to(b.center()) <= AbilityPad.RADIUS
					and (cost.end - Vector2.ONE).distance_to(b.center()) <= AbilityPad.RADIUS + 0.5,
					"%s: custo %d dentro do botão (%s)" % [st, slot + 1, cost])
		else:
			var parts := b.locked_parts()
			var pill: Rect2 = parts["pill"]
			_ok(box.encloses(pill) and box.encloses(parts["lock"] as Rect2) and not pill.intersects(parts["lock"] as Rect2),
					"%s: cadeado e \"%s\" inteiros no botão %d (%s)" % [st, parts["text"], slot + 1, pill])
	var g := pad.gauge_rect()
	_ok(pad.gauge().visible and safe.grow(-2.0).encloses(g),
			"%s: barra de energia na área segura (%s em %s)" % [st, g, safe])
	for slot: int in 3:
		_ok(not g.intersects(pad.button_rect(slot)), "%s: barra longe do botão %d" % [st, slot + 1])
	_ok(g.position.distance_to(pad.ult_center) > ult_r and g.end.y <= pad.ult_center.y - ult_r,
			"%s: barra acima do Golpe" % st)
	for f: Rect2 in fixed:
		_ok(not f.intersects(g), "%s: barra longe do joystick, cantos e topo (%s e %s)" % [st, g, f])
	var parts := pad.gauge().parts()
	var local := Rect2(Vector2.ZERO, g.size)
	var rects: Array[Rect2] = []
	for key: String in ["glyph", "bar", "value"]:
		var r: Rect2 = parts[key]
		_ok(local.grow(0.5).encloses(r), "%s: %s da barra inteiro (%s em %s)" % [st, key, r, local])
		for o: Rect2 in rects:
			_ok(not o.intersects(r), "%s: %s da barra sem sobrepor" % [st, key])
		rects.append(r)
	_ok(pad.icon(String(pad.source.call("energy_icon"))) != null, "%s: glifo da energia carregado" % st)


## "Nv 5" / "Nv 10" no idioma (ou só o número, se não couber) dentro do alvo de toque.
func _check_locked_text(pad: AbilityPad, st: String) -> void:
	for slot: int in [1, 2]:
		var b := pad.buttons()[slot]
		var parts := b.locked_parts()
		var pill: Rect2 = parts["pill"]
		var level := str(b.state.get("level", 0))
		_ok(String(parts["text"]).contains(level) and Rect2(Vector2.ZERO, b.size).encloses(pill),
				"%s: travada %d com \"%s\" inteiro (%s)" % [st, slot + 1, parts["text"], pill])


## Dica tutorial.abilities e aviso (falta de energia, nível) no centro, sem chegar no arco.
func _check_center_texts(hud: Hud, safe: Rect2, st: String) -> void:
	var pad := hud.ability_pad()
	var hint := hud.get("_hint") as Label
	var toast := hud.get("_toast") as Label
	var avoid := _pad_rects(pad)
	avoid.append((hud.get("_ult_button") as Control).get_global_rect())
	for key: String in ["tutorial.abilities", "tutorial.ultimate", "ability.no_energy", "ability.level_req"]:
		var text := TranslationServer.translate(key)
		if key == "ability.no_energy":
			text = text % TranslationServer.translate("energy.forge_heat.name")
		elif key == "ability.level_req":
			text = text % 10
		hint.text = text
		hint.visible = true
		hud.toast(text)
		await _host.get_tree().process_frame
		for l: Label in [hint, toast]:
			var r := l.get_global_rect()
			_ok(safe.encloses(r) and l.get_line_count() <= l.get_visible_line_count(),
					"%s: %s \"%s\" inteiro na área segura (%s)" % [st, l.name, text.left(24), r])
			for a: Rect2 in avoid:
				_ok(not a.intersects(r), "%s: %s \"%s\" sem chegar no arco (%s e %s)" % [st, l.name, text.left(24), r, a])
	hint.visible = false
	toast.visible = false


# --- Toque -------------------------------------------------------------------------------------

func run_touch(host: Node, check: Callable, view: Vector2) -> void:
	_check = check
	_host = host
	Settings.set_value("joystick_mode", "floating")
	Settings.set_value("joystick_side", "left")
	var hud := Hud.new()
	host.add_child(hud)
	await host.get_tree().process_frame
	var root := hud.get("_root") as Control
	root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.size = view
	hud.set_process(false)
	await host.get_tree().process_frame
	var pad := hud.ability_pad()
	var stub: RefCounted = Stub.new(&"yuki")
	pad.source = stub
	pad.call("_process", 0.0)
	var ults := [0]
	hud.ultimate_pressed.connect(func() -> void: ults[0] += 1)
	var notices: Array[String] = []
	pad.notice.connect(func(text: String) -> void: notices.append(text))
	# 1º dedo no joystick (metade esquerda), 2º no botão da 1ª habilidade.
	_touch(hud, 0, Vector2(view.x * 0.2, view.y * 0.7), true)
	_ok(int(hud.joystick.get("_touch_index")) == 0, "toque: joystick preso ao 1º dedo")
	_touch(hud, 1, pad.button_center(0), true)
	_ok((stub.get("activated") as Array) == [0], "toque: botão com outro dedo chama activate(0) com o joystick em uso")
	_ok(int(hud.joystick.get("_touch_index")) == 0, "toque: o joystick continua no 1º dedo")
	_touch(hud, 1, pad.button_center(0), false)
	_touch(hud, 2, pad.ult_center, true)
	_ok(ults[0] == 1, "toque: Golpe com outro dedo, junto com o joystick")
	_touch(hud, 2, pad.ult_center, false)
	_touch(hud, 0, Vector2(view.x * 0.2, view.y * 0.7), false)
	_ok(int(hud.joystick.get("_touch_index")) == -1, "toque: joystick solta com o 1º dedo")
	# Sem joystick, o 1º dedo no botão (como no PC, com o clique emulado em toque).
	stub.set("left", PackedFloat32Array([0.0, 0.0, 0.0]))
	_touch(hud, 0, pad.button_center(0) + Vector2(AbilityPad.HIT - 1.0, 0.0), true)
	_touch(hud, 0, pad.button_center(0), false)
	_ok((stub.get("activated") as Array).size() == 2, "toque: borda do alvo de toque ainda vale")
	_touch(hud, 0, pad.button_center(0) + Vector2(0.0, AbilityPad.HIT + 3.0), true)
	_touch(hud, 0, pad.button_center(0), false)
	_ok((stub.get("activated") as Array).size() == 2, "toque: fora do alvo não solta")
	# Contagem depois de fechar uma tela: o arco não aceita toque.
	hud.set("_countdown_left", 1.0)
	_touch(hud, 0, pad.button_center(1), true)
	_touch(hud, 0, pad.button_center(1), false)
	_ok((stub.get("activated") as Array).size() == 2, "toque: bloqueado durante a contagem")
	hud.set("_countdown_left", 0.0)
	# Travada: aviso com o nível e tremor; sem energia: aviso, tremor e a barra piscando.
	stub.set("level", 1)
	pad.call("_process", 0.0)
	_touch(hud, 0, pad.button_center(2), true)
	_touch(hud, 0, pad.button_center(2), false)
	_ok(notices.size() == 1 and notices[0] == TranslationServer.translate("ability.level_req") % 10
			and pad.buttons()[2].denying(), "toque: travada avisa \"%s\" e treme" % [notices])
	stub.set("level", 10)
	stub.set("left", PackedFloat32Array([0.0, 0.0, 0.0]))
	stub.set("value", 0.0)
	stub.set("blood", INF)
	pad.call("_process", 0.0)
	_touch(hud, 0, pad.button_center(1), true)
	_touch(hud, 0, pad.button_center(1), false)
	pad.call("_process", 0.0)
	_ok(notices.size() == 2 and pad.buttons()[1].denying() and pad.gauge().denying(),
			"toque: sem energia avisa, treme o botão e a barra (%s)" % [notices])
	_ok(pad.buttons()[1].get_child(0).material != null, "sem energia: ícone sem cor")
	stub.set("blood", 10.0)
	pad.call("_process", 0.0)
	_ok(bool(pad.buttons()[1].state["blood"]) and pad.buttons()[1].get_child(0).material == null,
			"Yuki: vai pagar com vida (aro e custo de sangue, ícone com cor)")
	await _check_redraws(pad, stub)
	hud.queue_free()
	await host.get_tree().process_frame


## Estado parado: nenhuma camada redesenha; recarga: só a de cima, a cada passo da varredura.
func _check_redraws(pad: AbilityPad, stub: RefCounted) -> void:
	stub.set("value", 100.0)
	stub.set("blood", 0.0)
	stub.set("left", PackedFloat32Array([0.0, 0.0, 0.0]))
	for _i: int in 30:
		pad.call("_process", 0.0)
		await _host.get_tree().process_frame
	var counts := [0, 0]
	var b := pad.buttons()[0]
	(b.get_child(0) as Control).draw.connect(func() -> void: counts[0] += 1)
	(b.get_child(1) as Control).draw.connect(func() -> void: counts[1] += 1)
	for _i: int in 10:
		pad.call("_process", 0.0)
		await _host.get_tree().process_frame
	_ok(counts == [0, 0], "desenho: botão parado não redesenha (%s)" % [counts])
	for i: int in 10:
		stub.set("left", PackedFloat32Array([3.0 - i * 0.1, 0.0, 0.0]))
		pad.call("_process", 0.0)
		await _host.get_tree().process_frame
	_ok(counts[0] == 0 and counts[1] >= 8, "desenho: recarga redesenha só a camada de cima (%s)" % [counts])


## Toque de verdade pela janela (o viewport converte para a tela lógica e chama os _input).
func _touch(hud: Hud, index: int, at: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.pressed = pressed
	var vp := hud.get_viewport()
	ev.position = vp.get_final_transform() * at
	vp.push_input(ev)
