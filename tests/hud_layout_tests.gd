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
## - seta do portal do Kakuriyo (vórtice + chevron, RiftPortal.arrow_rect) inteira na área segura
##   em 16 direções;
## - título da travessia (scripts/ui/realm_card.gd): legenda, kanji e nome de cada um dos 6 reinos,
##   em cada idioma, inteiros na área segura com folga, sem se sobrepor e na ordem de leitura;
## - "Um Kami oferece um pacto" (scripts/ui/kami_panel.gd): selo + título, subtítulo, as placas
##   (com o cordão e o aro de seleção) e os botões Ignorar / Selar dentro da área segura com 4 px
##   de folga, sem se sobrepor; cada placa com nome, domínio, bênção e preço inteiros e sem um
##   texto encostar no outro, o mesmo arranjo nas três e as legendas "Bênção"/"Preço" em telas
##   de 300 px ou mais; todo Kami em alguma oferta, Hachiman em cada posição e a oferta de 2
##   (Lua V);
## - diálogo antes do chefe (scripts/ui/dialogue_panel.gd): caixa, retrato 38x38 na moldura, nome,
##   fala e "Pular" na área segura com 4 px de folga, sem se sobrepor, com a fala mais longa de
##   cada idioma do lado do chefe e do herói, e toda fala do idioma cabendo nas linhas da caixa;
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
		_check_portal_arrows(hud, c["view"], safe, "HUD [%s]" % c["label"])
		for lang: String in c["langs"]:
			Locale.set_language(lang, false)
			var state := "HUD %s [%s]" % [lang, c["label"]]
			_check_top(hud, safe, state)
			await _check_labels(hud, safe, state)
			_check_arrows(hud, c["view"], safe, state)
			_check_realm_card(hud, c["view"], c["insets"], safe, state)
		await _check_kami(hud, safe.grow(-4.0), c["langs"], String(c["label"]))
		await _check_dialogue(hud, safe.grow(-4.0), c["langs"], String(c["label"]))
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


## Seta do portal: o vórtice e a ponta no pulso máximo, em 16 direções, na área segura.
func _check_portal_arrows(hud: Hud, view: Vector2, safe: Rect2, state: String) -> void:
	for i: int in 16:
		var dir := Vector2.RIGHT.rotated(TAU * i / 16.0)
		var r := RiftPortal.arrow_rect(hud.arrow_point(dir, view), dir)
		_check.call(safe.encloses(r), "%s: seta do portal para %.0f° na área segura (%s)"
				% [state, rad_to_deg(dir.angle()), r])


## Título da travessia de cada reino: legenda, kanji e nome inteiros na área segura (com a folga
## RealmCard.MARGIN dos lados), um embaixo do outro, sem se sobrepor.
func _check_realm_card(hud: Hud, view: Vector2, insets: Vector2, safe: Rect2, state: String) -> void:
	var card := hud.realm_card()
	var room := safe.grow_individual(-RealmCard.MARGIN, 0.0, -RealmCard.MARGIN, 0.0)
	for id: StringName in DB.ids("stages"):
		var ow: Dictionary = DB.stage(id).get("otherworld", {})
		card.kanji = String(ow.get("kanji", ""))
		card.title = TranslationServer.translate("realm.%s.name" % id)
		card.caption = TranslationServer.translate("realm.caption")
		var layout: Dictionary = card.title_layout(view, insets)
		var tag := "%s: título do reino %s" % [state, id]
		var rects: Array[Rect2] = []
		for key: String in ["caption", "kanji", "name"]:
			var r: Rect2 = layout[key]
			_check.call(r.size.x > 0.0 and room.encloses(r), "%s, %s inteiro na área segura (%s em %s)" % [tag, key, r, room])
			for o: Rect2 in rects:
				_check.call(not o.intersects(r) and o.end.y <= r.position.y + 0.5, "%s, %s abaixo e sem sobrepor" % [tag, key])
			rects.append(r)
		_check.call(int(layout["name_size"]) >= 12, "%s, nome legível" % tag)


# --- Kami -------------------------------------------------------------------------

func _check_kami(hud: Hud, room: Rect2, langs: Array, label: String) -> void:
	var ids := DB.ids("kami")
	var count := ids.size()
	var offers: Array = []
	for i: int in range(0, count, 3):
		offers.append([ids[i], ids[(i + 1) % count], ids[(i + 2) % count]])
	for slot: int in 3:
		var offer: Array = [StringName("inari"), StringName("raijin"), StringName("bishamon")]
		offer[slot] = StringName("hachiman")
		offers.append(offer)
	offers.append([StringName("benzaiten"), StringName("bishamon")])
	var panel := hud.kami_panel()
	for lang: String in langs:
		Locale.set_language(lang, false)
		for offer: Array in offers:
			var typed: Array[StringName] = []
			typed.assign(offer)
			hud.show_kami(typed)
			panel.finish_intro()
			check_kami_layout(panel, room, "%s [%s], %s" % [lang, label, ", ".join(offer)])
		await _host.get_tree().process_frame
	panel.close_now()
	Locale.set_language("pt_BR", false)


## Painel de Kami aberto e parado: tudo inteiro em `room` (área segura com folga), sem sobrepor.
func check_kami_layout(panel: KamiPanel, room: Rect2, state: String) -> void:
	var origin := panel.get_global_rect().position
	var cards := panel.cards()
	_check.call(cards.size() == panel.offer().size(), "%s: uma placa por Kami" % state)
	var header := panel.header_rects()
	for r: Rect2 in header:
		_check.call(room.encloses(r), "%s: título e subtítulo na tela (%s em %s)" % [state, r, room])
	_check.call(not header[0].intersects(header[1]), "%s: título e subtítulo separados" % state)
	var mode := panel.layout_mode()
	var rects: Array[Rect2] = []
	for i: int in range(cards.size()):
		var card := cards[i]
		var r := Rect2(origin + card.base_position, card.size)
		var cord_top := r.position.y - KamiPanel.CORD
		_check.call(room.encloses(r) and cord_top >= header[1].end.y,
				"%s: placa %s na tela, com o cordão abaixo do título (%s em %s)" % [state, card.id, r, room])
		_check.call(room.grow(4.0).encloses(r.grow(4.0)), "%s: aro de seleção de %s na área segura" % [state, card.id])
		_check.call(card.fits(), "%s: textos de %s inteiros na placa" % [state, card.id])
		_check.call(card.icon_texture() != null and card.icon_scale() == int(mode[0])
				and card.captions_shown() == bool(mode[1]),
				"%s: ícone de %s e o mesmo arranjo nas placas" % [state, card.id])
		var texts := card.text_controls()
		for a: int in range(texts.size()):
			for b: int in range(a + 1, texts.size()):
				var ra := Rect2(texts[a].position, texts[a].size).grow(-1.0)
				var rb := Rect2(texts[b].position, texts[b].size).grow(-1.0)
				_check.call(not ra.intersects(rb), "%s: textos %d e %d de %s sem se sobrepor" % [state, a, b, card.id])
		for other: Rect2 in rects:
			_check.call(not other.intersects(r), "%s: placas separadas" % state)
		rects.append(r)
	_check.call(bool(mode[1]) or room.size.y < 290.0, "%s: legendas Bênção/Preço em tela alta" % state)
	var buttons: Array[Button] = [panel.decline_button(), panel.confirm_button()]
	for b: Button in buttons:
		var br := b.get_global_rect()
		_check.call(room.encloses(br), "%s: botão %s na tela (%s em %s)" % [state, b.text, br, room])
		var minimum := b.get_combined_minimum_size()
		_check.call(minimum.x <= br.size.x + 0.5 and minimum.y <= br.size.y + 0.5, "%s: botão %s inteiro" % [state, b.text])
		for r: Rect2 in rects:
			_check.call(not r.intersects(br), "%s: botão %s longe das placas" % [state, b.text])
	_check.call(not buttons[0].get_global_rect().intersects(buttons[1].get_global_rect()), "%s: botões separados" % state)


# --- Diálogo antes do chefe -------------------------------------------------------

## Todas as falas de todos os roteiros, com cada herói (DialogueScript.build), sem repetir.
static func dialogue_lines() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen := {}
	for boss: String in DB.dialogues:
		for hero: StringName in DB.ids("heroes"):
			for line: Dictionary in DialogueScript.build(StringName(boss), hero):
				if not seen.has(line["text_key"]):
					seen[line["text_key"]] = true
					out.append(line)
	return out


## A caixa com a fala mais longa do idioma do lado do chefe e do lado do herói.
func _check_dialogue(hud: Hud, room: Rect2, langs: Array, label: String) -> void:
	var panel := hud.dialogue_panel()
	var lines := dialogue_lines()
	for lang: String in langs:
		Locale.set_language(lang, false)
		var texts: Array[String] = []
		var longest := {}
		for line: Dictionary in lines:
			var text := TranslationServer.translate(String(line["text_key"]))
			texts.append(text)
			var side := String(line["side"])
			if not longest.has(side) or text.length() > String(longest[side][1]).length():
				longest[side] = [line, text]
		for side: String in ["right", "left"]:
			var one: Array[Dictionary] = [longest[side][0]]
			hud.show_dialogue(one)
			panel.finish_intro()
			check_dialogue_layout(panel, room, texts, "%s [%s], diálogo à %s" % [lang, label,
					"direita" if side == "right" else "esquerda"])
		await _host.get_tree().process_frame
	panel.close_now()
	Locale.set_language("pt_BR", false)


## Diálogo aberto e parado: caixa, retrato, nome, fala e "Pular" inteiros em `room`, sem se
## sobrepor; toda fala `texts` do idioma cabe na área de texto (DialoguePanel.text_fits).
func check_dialogue_layout(panel: DialoguePanel, room: Rect2, texts: Array[String], state: String) -> void:
	var origin := panel.get_global_rect().position
	var layout := panel.layout_rects()
	var rects := {}
	for key: String in ["box", "frame", "portrait", "name", "text", "skip"]:
		var r := Rect2(origin + (layout[key] as Rect2).position, (layout[key] as Rect2).size)
		rects[key] = r
		_check.call(r.size.x > 0.0 and room.encloses(r), "%s: %s na área segura (%s em %s)" % [state, key, r, room])
	var box: Rect2 = rects["box"]
	for key: String in ["frame", "name", "text"]:
		_check.call(box.encloses(rects[key]), "%s: %s dentro da caixa" % [state, key])
	_check.call((rects["frame"] as Rect2).encloses(rects["portrait"]) and (rects["portrait"] as Rect2).size
			== Vector2(DialoguePanel.FACE, DialoguePanel.FACE), "%s: retrato 38x38 na moldura" % state)
	_check.call(((rects["frame"] as Rect2).get_center().x > box.get_center().x) == (panel.current_side() == "right"),
			"%s: retrato do lado de quem fala" % state)
	var parts: Array[String] = ["frame", "name", "text", "skip"]
	for a: int in parts.size():
		for b: int in range(a + 1, parts.size()):
			_check.call(not (rects[parts[a]] as Rect2).intersects(rects[parts[b]]),
					"%s: %s e %s sem se sobrepor" % [state, parts[a], parts[b]])
	_check.call(not box.intersects(rects["skip"]), "%s: \"Pular\" fora da caixa" % state)
	var skip := panel.skip_button()
	var br := skip.get_global_rect()
	var minimum := skip.get_combined_minimum_size()
	_check.call(room.encloses(br) and minimum.x <= br.size.x + 0.5 and minimum.y <= br.size.y + 0.5,
			"%s: botão \"%s\" inteiro (%s, mínimo %s)" % [state, skip.text, br, minimum])
	var font := Locale.font
	var name_w := font.get_string_size(panel.speaker_name(), HORIZONTAL_ALIGNMENT_LEFT, -1,
			DialoguePanel.FONT_SIZE).x
	_check.call(name_w <= (rects["name"] as Rect2).size.x, "%s: nome \"%s\" inteiro" % [state, panel.speaker_name()])
	_check.call(panel.text_label().get_line_count() <= DialoguePanel.TEXT_LINES,
			"%s: fala aberta com todas as linhas (%d)" % [state, panel.text_label().get_line_count()])
	var width := (rects["text"] as Rect2).size.x
	var cut: Array[String] = []
	for text: String in texts:
		if not DialoguePanel.text_fits(text, width, font):
			cut.append(text.left(24))
	_check.call(cut.is_empty(), "%s: todas as falas cabem em %.0f px (não cabem: %s)" % [state, width, cut])


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
