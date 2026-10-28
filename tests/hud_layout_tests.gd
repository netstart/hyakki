extends RefCounted
## HUD da partida (scripts/ui/hud.gd) em cada resolução de tests/device_profiles.gd, sem e com o
## furo da câmera de cada lado. Chamado por tests/integration_tests.gd e por
## tests/hud_layout_runner.gd.
##
## O que vale para a HUD:
## - topo: barra de XP, nível, relógio, abates/ryō e as duas fileiras de ícones (6 armas e
##   6 passivas) inteiros na área segura (fora do recorte), sem um texto encostar no outro
##   nem nos botões do canto, com números curtos e longos em cada idioma;
## - botões de pausa, velocidade e Golpe da Lanterna e o joystick fixo (dos dois lados, para
##   canhotos) inteiros na área segura e sem se sobrepor;
## - aviso, dica do tutorial, contagem e a oferta de reviver: textos inteiros na área segura;
## - setas de santuário e baú fora da tela: dentro da área segura em qualquer direção;
## - "Um Kami oferece um pacto": título, os 3 cartões (ícone e texto) e "Ignorar o santuário"
##   dentro da área segura com 4 px de folga; cada Kami em cada posição e Hachiman (bênção,
##   especial e custo: o texto mais longo) em cada uma delas;
## - a HUD refaz o layout quando a tela muda de tamanho e quando o recorte troca de lado.

const DeviceProfiles := preload("res://tests/device_profiles.gd")
## Pior caso dos números do topo (nível, tempo e contadores longos) e o começo da partida.
const NUMBERS: Array[Array] = [[99, "59:59", 999999, 9999999], [1, "00:00", 0, 0]]
const ICON_SLOTS := 6

var _host: Node
var _check: Callable


func run(host: Node, check: Callable) -> void:
	_host = host
	_check = check
	var side: Variant = Settings.get_value("joystick_side")
	var mode: Variant = Settings.get_value("joystick_mode")
	for c: Dictionary in DeviceProfiles.layout_cases():
		DeviceProfiles.simulate_insets(c["insets"])
		var safe := DeviceProfiles.safe_rect(c["view"], c["insets"])
		var hud := await _open(c["view"])
		await _check_controls(hud, safe, String(c["label"]))
		for lang: String in c["langs"]:
			Locale.set_language(lang, false)
			var state := "HUD %s [%s]" % [lang, c["label"]]
			_check_top(hud, safe, state)
			await _check_labels(hud, safe, state)
			_check_arrows(hud, c["view"], safe, state)
		await _check_kami(hud, safe.grow(-4.0), c["langs"], String(c["label"]))
		await _close(hud)
	DeviceProfiles.clear_insets()
	Locale.set_language("pt_BR", false)
	await _check_relayout()
	Settings.set_value("joystick_side", side)
	Settings.set_value("joystick_mode", mode)


## HUD no tamanho do jogo (o teste roda numa janela menor: a raiz recebe o viewport do jogo),
## sem o _process (senão a dica do tutorial some sem partida).
func _open(view: Vector2) -> Hud:
	var hud := Hud.new()
	_host.add_child(hud)
	await _host.get_tree().process_frame
	var root := hud.get("_root") as Control
	root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.size = view
	hud.set_process(false)
	await _host.get_tree().process_frame
	return hud


func _close(hud: Hud) -> void:
	hud.queue_free()
	await _host.get_tree().process_frame


## Botões do canto, Golpe e joystick fixo, com o joystick de cada lado.
func _check_controls(hud: Hud, safe: Rect2, label: String) -> void:
	Settings.set_value("joystick_mode", "fixed")
	for side: String in ["left", "right"]:
		Settings.set_value("joystick_side", side)
		await _host.get_tree().process_frame
		var state := "HUD [%s] joystick à %s" % [label, "esquerda" if side == "left" else "direita"]
		var pause := hud.get("_pause_button") as Button
		var speed := hud.get("_speed_button") as Button
		var ult := hud.get("_ult_button") as Button
		_check.call(speed.visible, "%s: botão de velocidade visível (sem partida)" % state)
		var rects: Array[Rect2] = []
		for b: Button in [pause, speed, ult]:
			var r := b.get_global_rect()
			_check.call(safe.encloses(r), "%s: botão %s inteiro na área segura (%s em %s)" % [state, b.name, r, safe])
			_check.call(r.size.y >= 28.0 and r.size.x >= 28.0, "%s: botão %s com alvo de toque (%s)" % [state, b.name, r.size])
			for o: Rect2 in rects:
				_check.call(not o.intersects(r), "%s: botão %s sem sobrepor outro" % [state, b.name])
			rects.append(r)
		_check_speed_parts(hud, safe, state)
		var joy := hud.joystick
		_check.call(joy.fixed and joy.left_side == (side == "left"), "%s: joystick fixo no lado escolhido" % state)
		var c := joy.get_global_transform() * joy.fixed_center()
		var ring := Rect2(c - Vector2.ONE * TouchJoystick.RADIUS, Vector2.ONE * TouchJoystick.RADIUS * 2.0)
		_check.call(safe.encloses(ring), "%s: joystick fixo inteiro na área segura (%s em %s)" % [state, ring, safe])
		for r: Rect2 in rects:
			_check.call(not r.intersects(ring), "%s: joystick fixo longe dos botões" % state)
		_check.call((ring.get_center().x < safe.get_center().x) == (side == "left")
				and (ult.get_global_rect().get_center().x < safe.get_center().x) != (side == "left"),
				"%s: Golpe no lado oposto ao joystick" % state)


## Conteúdo do botão de velocidade, livre (1x, 2x, 3x) e bloqueado sem a Ampulheta de Fūjin
## (1x esmaecido + cadeado): ícone, texto e cadeado inteiros dentro do botão, na área segura
## e sem se sobrepor.
func _check_speed_parts(hud: Hud, safe: Rect2, state: String) -> void:
	var button := hud.get("_speed_button") as Button
	var speed := GameClock.speed
	var top := GameClock.max_speed
	for locked: bool in [false, true]:
		GameClock.max_speed = 1 if locked else GameClock.SPEEDS[-1]
		for value: int in ([1] if locked else GameClock.SPEEDS):
			GameClock.speed = value
			hud.refresh_speed()
			var tag := "%s, velocidade %dx%s" % [state, value, " bloqueada" if locked else ""]
			_check.call(hud.speed_locked() == locked, "%s: estado do cadeado" % tag)
			var parts: Dictionary = hud.speed_parts()
			_check.call(parts.has("lock") == locked, "%s: cadeado só quando bloqueada" % tag)
			var origin := button.get_global_rect().position
			var rects: Array[Rect2] = []
			for key: String in ["icon", "label", "lock"]:
				if not parts.has(key):
					continue
				var r := Rect2((parts[key] as Rect2).position + origin, (parts[key] as Rect2).size)
				_check.call(button.get_global_rect().grow(0.5).encloses(r) and safe.encloses(r),
						"%s: %s inteiro no botão e na área segura (%s em %s)" % [tag, key, r, button.get_global_rect()])
				for o: Rect2 in rects:
					_check.call(not o.grow(-0.5).intersects(r.grow(-0.5)), "%s: %s sem sobrepor" % [tag, key])
				rects.append(r)
	GameClock.max_speed = top
	GameClock.speed = speed
	hud.refresh_speed()


## Topo: barra de XP, textos e fileiras de ícones, com números curtos e longos.
func _check_top(hud: Hud, safe: Rect2, state: String) -> void:
	var corners: Array[Rect2] = []
	for key: String in ["_pause_button", "_speed_button"]:
		corners.append((hud.get(key) as Control).get_global_rect())
	var step := SkillIconPainter.ICON + 3.0
	var row := Vector2(step * ICON_SLOTS - 3.0, SkillIconPainter.ICON)
	for n: Array in NUMBERS:
		var counters := "%s %s   %s %s" % [TranslationServer.translate("hud.kills"), Locale.format_number(n[2]),
				TranslationServer.translate("hud.ryo"), Locale.format_number(n[3])]
		var layout: Dictionary = hud.top_layout(TranslationServer.translate("hud.level") % n[0], n[1], counters)
		var sub := "%s (%s)" % [state, n[1]]
		var xp: Rect2 = layout["xp"]
		_check.call(safe.encloses(xp) and xp.size.x >= safe.size.x - 8.5,
				"%s: barra de XP de ponta a ponta da área segura (%s em %s)" % [sub, xp, safe])
		var texts: Array[Rect2] = []
		for key: String in ["level", "clock", "counters"]:
			var r: Rect2 = layout[key]
			_check.call(safe.encloses(r) and r.size.x > 0.0,
					"%s: texto %s inteiro na área segura (%s em %s)" % [sub, key, r, safe])
			for o: Rect2 in texts + corners:
				_check.call(not o.grow(1.0).intersects(r), "%s: texto %s sem encostar (%s e %s)" % [sub, key, r, o])
			texts.append(r)
		for key: String in ["weapons_at", "passives_at"]:
			var r := Rect2(layout[key] as Vector2, row)
			_check.call(safe.encloses(r), "%s: fileira %s com %d ícones na área segura (%s)" % [sub, key, ICON_SLOTS, r])
			for o: Rect2 in corners:
				_check.call(not o.intersects(r), "%s: fileira %s longe dos botões do canto" % [sub, key])
			_check.call(not (layout["counters"] as Rect2).intersects(r), "%s: fileira %s longe dos contadores" % [sub, key])
			_check.call((layout["level"] as Rect2).end.y <= r.position.y, "%s: fileira %s abaixo do nível" % [sub, key])


## Aviso, dica do tutorial, contagem e a oferta de reviver: textos inteiros na área segura.
func _check_labels(hud: Hud, safe: Rect2, state: String) -> void:
	var toast := hud.get("_toast") as Label
	var hint := hud.get("_hint") as Label
	var countdown := hud.get("_countdown_label") as Label
	for key: String in ["tutorial.move", "tutorial.embers", "tutorial.ultimate", "speed.locked"]:
		hint.text = TranslationServer.translate(key)
		hint.visible = true
		hud.toast(TranslationServer.translate(key))
		countdown.text = "3"
		countdown.visible = true
		await _host.get_tree().process_frame
		for l: Label in [hint, toast, countdown]:
			_check_label(l, safe, "%s: %s (%s)" % [state, l.name, key])
	hint.visible = false
	toast.visible = false
	countdown.visible = false
	hud.show_revive_offer()
	await _host.get_tree().process_frame
	var panel := hud.get("_revive_panel") as Control
	for node: Node in panel.find_children("*", "Control", true, false):
		var control := node as Control
		if node is Label:
			_check_label(node as Label, safe, "%s: reviver" % state)
		elif node is Button:
			var b := node as Button
			var r := b.get_global_rect()
			_check.call(safe.encloses(r) and b.get_combined_minimum_size().x <= r.size.x + 0.5,
					"%s: reviver, botão \"%s\" inteiro na área segura (%s em %s)" % [state, b.text, r, safe])
		elif control is VBoxContainer or control is CenterContainer:
			_check.call(safe.encloses(control.get_global_rect()), "%s: reviver, faixa na área segura" % state)
	panel.visible = false


func _check_label(l: Label, safe: Rect2, state: String) -> void:
	var r := l.get_global_rect()
	_check.call(safe.encloses(r), "%s: \"%s\" na área segura (%s em %s)" % [state, l.text.left(30), r, safe])
	if l.autowrap_mode == TextServer.AUTOWRAP_OFF:
		_check.call(l.get_minimum_size().x <= r.size.x + 0.5, "%s: \"%s\" sem corte" % [state, l.text.left(30)])
	else:
		_check.call(l.get_line_count() <= l.get_visible_line_count(),
				"%s: \"%s\" com todas as linhas" % [state, l.text.left(30)])


## Setas de alvos fora da tela, em 16 direções: a seta inteira (ponta e base) na área segura.
func _check_arrows(hud: Hud, view: Vector2, safe: Rect2, state: String) -> void:
	for i: int in 16:
		var dir := Vector2.RIGHT.rotated(TAU * i / 16.0)
		var p: Vector2 = hud.arrow_point(dir, view)
		var arrow := Rect2(p, Vector2.ZERO).grow(8.0)
		_check.call(safe.encloses(arrow), "%s: seta para %.0f° na área segura (%s)" % [state, rad_to_deg(dir.angle()), p])


# --- Kami -------------------------------------------------------------------------

func _check_kami(hud: Hud, view: Rect2, langs: Array, label: String) -> void:
	var ids := DB.ids("kami")
	var count := ids.size()
	var offers: Array = []
	for i: int in count:
		offers.append([ids[i], ids[(i + 1) % count], ids[(i + 2) % count]])
	for slot: int in 3:
		var offer: Array = [StringName("inari"), StringName("raijin"), StringName("inari")]
		offer[slot] = StringName("hachiman")
		offers.append(offer)
	for lang: String in langs:
		Locale.set_language(lang, false)
		for offer: Array in offers:
			var typed: Array[StringName] = []
			typed.assign(offer)
			hud.show_kami(typed)
			await _host.get_tree().process_frame
			await _host.get_tree().process_frame
			var state := "%s [%s], %s" % [lang, label, ", ".join(offer)]
			var panel := hud.get("_kami_panel") as Control
			var controls: Array[Control] = []
			_kami_controls_in(panel, controls)
			_check.call(controls.size() >= 3 + 3 + 1, "%s: o painel mostra título, cartões e botão" % state)
			for control: Control in controls:
				_check.call(control.is_visible_in_tree() and view.encloses(control.get_global_rect()),
						"%s: %s dentro da tela (%s)" % [state, control.get_class(), control.get_global_rect()])
				if control is Button and (control as Button).text != "":
					var button_node := control as Button
					var minimum := button_node.get_combined_minimum_size()
					_check.call(minimum.x <= button_node.size.x + 0.5 and minimum.y <= button_node.size.y + 0.5,
							"%s: o cartão mostra o texto inteiro (%s de %s)" % [state, minimum, button_node.size])
			var row := hud.get("_kami_row") as HBoxContainer
			_check.call(row.get_child_count() == 3, "%s: três cartões" % state)
			for card: Node in row.get_children():
				var icons := 0
				for child: Node in card.get_children():
					if child is TextureRect and (child as TextureRect).texture != null:
						icons += 1
						_check.call(view.encloses((child as Control).get_global_rect()),
								"%s: ícone do cartão dentro da tela" % state)
				_check.call(icons == 1, "%s: cada cartão mostra o ícone do Kami" % state)
	(hud.get("_kami_panel") as Control).visible = false
	Locale.set_language("pt_BR", false)


## Coleta botões, textos e ícones de uma árvore de controles (o painel de Kami).
func _kami_controls_in(node: Node, out: Array[Control]) -> void:
	for child: Node in node.get_children():
		if (child is BaseButton or child is Label or child is TextureRect) and not out.has(child):
			out.append(child as Control)
		_kami_controls_in(child, out)


# --- Relayout ---------------------------------------------------------------------

## O recorte trocando de lado com a HUD aberta (girar o aparelho) e a tela mudando de tamanho:
## a HUD refaz o layout sozinha.
func _check_relayout() -> void:
	Settings.set_value("joystick_mode", "fixed")
	Settings.set_value("joystick_side", "left")
	var views := DeviceProfiles.views()
	var hud := await _open(views[0])
	var root := hud.get("_root") as Control
	var cut := DeviceProfiles.cutout_logical(DeviceProfiles.RESOLUTIONS[0])
	# Sem tique da HUD: a troca chega só por PixelScaler.safe_insets_changed.
	for insets: Vector2 in [Vector2(0.0, cut), Vector2(cut, 0.0), Vector2.ZERO]:
		DeviceProfiles.simulate_insets(insets)
		await _host.get_tree().process_frame
		var safe := DeviceProfiles.safe_rect(views[0], insets)
		_check_placed(hud, safe, "HUD com o recorte trocado para %s" % insets)
	DeviceProfiles.simulate_insets(Vector2(cut, 0.0))
	await _host.get_tree().process_frame
	for view: Vector2 in views:
		root.size = view
		await _host.get_tree().process_frame
		_check_placed(hud, DeviceProfiles.safe_rect(view, Vector2(cut, 0.0)), "HUD redimensionada para %s" % view)
	DeviceProfiles.clear_insets()
	await _close(hud)


## Pausa no canto direito da área segura, Golpe no canto direito e joystick à esquerda.
func _check_placed(hud: Hud, safe: Rect2, state: String) -> void:
	var pause := (hud.get("_pause_button") as Control).get_global_rect()
	var ult := (hud.get("_ult_button") as Control).get_global_rect()
	var center: Vector2 = hud.joystick.get_global_transform() * hud.joystick.fixed_center()
	_check.call(is_equal_approx(pause.end.x, safe.end.x - 4.0), "%s: pausa no canto da área segura (%s)" % [state, pause])
	_check.call(is_equal_approx(ult.end.x, safe.end.x - 10.0), "%s: Golpe no canto da área segura (%s)" % [state, ult])
	_check.call(is_equal_approx(center.x - TouchJoystick.RADIUS, safe.position.x + TouchJoystick.FIXED_OFFSET.x
			- TouchJoystick.RADIUS), "%s: joystick fixo a partir da área segura (%s)" % [state, center])
