extends RefCounted
## Letreiro do Elite dos altares (AltarSystem.banner_layout) e a barra sobre a cabeça do Elite
## (EliteAffixes), chamado por tests/hud_layout_tests.gd em cada resolução de
## tests/device_profiles.gd × 11 idiomas × furo da câmera dos dois lados.
##
## O que vale para o letreiro, com o nome mais largo do idioma (inimigo de nome mais largo que pode
## virar Elite + os 3 afixos de nome mais largo) e com o mais curto (1 afixo):
## - faixa inteira na área segura (fora do recorte), com o 強敵, os chips dos afixos dos dois lados
##   e o nome inteiros dentro da faixa (o nome encolhe até a fonte mínima, nunca é cortado);
## - sem sobrepor a HUD: topo (nível, relógio, contadores e as duas fileiras de ícones), botões de
##   pausa e velocidade, Golpe, os 3 botões das habilidades e a barra de energia (joystick fixo dos
##   dois lados) e a barra do chefe com o nome embaixo (scripts/ui/boss_panel.gd).
## A barra sobre a cabeça é do mundo (anda com o Elite, sem texto): os ícones dos 3 afixos cabem
## na largura dela.

const NUMBERS: Array = [99, "59:59", 999999, 9999999]
const ICON_SLOTS := 6
## Fonte mínima do nome no letreiro (AltarSystem.banner_layout encolhe até 8).
const MIN_NAME_SIZE := 8

var _check: Callable


func check_layout(host: Node, hud: Hud, view: Vector2, insets: Vector2, safe: Rect2, langs: Array, label: String,
		check: Callable) -> void:
	_check = check
	var altar := AltarSystem.new()
	var kanji_font: Font = load(AltarSystem.KANJI_FONT) as Font if ResourceLoader.exists(AltarSystem.KANJI_FONT) \
			else ThemeDB.fallback_font
	_check_overhead_bar("Elite [%s]" % label)
	Settings.set_value("joystick_mode", "fixed")
	for side: String in ["left", "right"]:
		Settings.set_value("joystick_side", side)
		await host.get_tree().process_frame
		for lang: String in langs:
			Locale.set_language(lang, false)
			var font: Font = Locale.font if Locale.font else ThemeDB.fallback_font
			altar.set("_font", font)
			altar.set("_kanji_font", kanji_font)
			var avoid := _hud_rects(hud, view)
			var st := "Letreiro do Elite %s [%s] joystick à %s" % [lang, label, "esquerda" if side == "left" else "direita"]
			for row: Array in _names(font):
				_check_banner(altar, font, kanji_font, String(row[0]), row[1] as Array, view, insets, safe, avoid,
						"%s (%d afixos)" % [st, (row[1] as Array).size()])
	altar.free()


## [nome, afixos]: o mais largo (3 afixos) e o mais curto (1 afixo) do idioma atual.
static func _names(font: Font) -> Array:
	var enemies: Array[StringName] = []
	for id: StringName in DB.ids("enemies"):
		if AltarSystem.ARCHETYPE_WEIGHT.has(String(DB.enemy(id).get("archetype", "chaser"))):
			enemies.append(id)
	var by_width := func(list: Array, measure: Callable) -> Array:
		var copy := list.duplicate()
		copy.sort_custom(func(a: Variant, b: Variant) -> bool: return float(measure.call(a)) > float(measure.call(b)))
		return copy
	var enemy_w := func(id: StringName) -> float:
		return font.get_string_size(TranslationServer.translate("enemy.%s.name" % id), HORIZONTAL_ALIGNMENT_LEFT, -1,
				12).x
	var affix_w := func(id: StringName) -> float:
		return font.get_string_size(EliteAffixes.affix_name(id), HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var enemies_sorted: Array = by_width.call(enemies, enemy_w)
	var affixes_sorted: Array = by_width.call(Array(EliteAffixes.IDS), affix_w)
	var long_affixes := affixes_sorted.slice(0, 3)
	var long_name := EliteAffixes.elite_name(StringName(enemies_sorted[0]), long_affixes)
	var short_affixes := [affixes_sorted.back()]
	var short_name := EliteAffixes.elite_name(StringName(enemies_sorted.back()), short_affixes)
	return [[long_name, long_affixes], [short_name, short_affixes]]


## Elementos da HUD que o letreiro não pode cobrir (coordenadas da HUD).
static func _hud_rects(hud: Hud, view: Vector2) -> Dictionary:
	var out := {}
	for key: String in ["_pause_button", "_speed_button", "_ult_button"]:
		out[key] = (hud.get(key) as Control).get_global_rect()
	var counters := "%s %s   %s %s" % [TranslationServer.translate("hud.kills"), Locale.format_number(NUMBERS[2]),
			TranslationServer.translate("hud.ryo"), Locale.format_number(NUMBERS[3])]
	var layout: Dictionary = hud.top_layout(TranslationServer.translate("hud.level") % NUMBERS[0], NUMBERS[1], counters)
	for key: String in ["level", "clock", "counters"]:
		out["topo " + key] = layout[key]
	var step := SkillIconPainter.ICON + 3.0
	var row := Vector2(step * ICON_SLOTS - 3.0, SkillIconPainter.ICON)
	for key: String in ["weapons_at", "passives_at"]:
		out["topo " + key] = Rect2(layout[key] as Vector2, row)
	var pad := hud.ability_pad()
	for slot: int in 3:
		out["habilidade %d" % slot] = pad.button_rect(slot)
	out["barra de energia"] = pad.gauge_rect()
	out["barra do chefe"] = boss_bar_rect(view)
	return out


## Caixa da barra do chefe com o selo à esquerda e o nome embaixo (BossPanel._draw_bar), com folga.
static func boss_bar_rect(view: Vector2) -> Rect2:
	var bar_x := roundf(view.x * 0.5 - BossPanel.BAR_W * 0.5 + BossPanel.SEAL * 0.5)
	var left := bar_x - 2.0 - BossPanel.SEAL - 4.0
	var top := BossPanel.BAR_Y - 3.0
	# Nome: linha de base 13 px abaixo da barra, fonte de 12 (descida ~4 px).
	var bottom := BossPanel.BAR_Y + BossPanel.BAR_H + 13.0 + 4.0
	return Rect2(left, top, bar_x + BossPanel.BAR_W + 3.0 - left, bottom - top)


func _check_banner(altar: AltarSystem, font: Font, kanji_font: Font, elite_name: String, affixes: Array,
		view: Vector2, insets: Vector2, safe: Rect2, avoid: Dictionary, st: String) -> void:
	var lay: Dictionary = altar.banner_layout(elite_name, affixes, view, insets)
	var plate: Rect2 = lay["plate"]
	_check.call(safe.encloses(plate), "%s: faixa inteira na área segura (%s em %s)" % [st, plate, safe])
	# Nome inteiro na faixa, sem corte, na fonte mínima ou maior.
	var name_size := int(lay["name_size"])
	var name_at: Vector2 = lay["name_at"]
	var name_w := font.get_string_size(elite_name, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x
	var name_rect := Rect2(name_at.x, name_at.y - font.get_ascent(name_size), name_w, font.get_height(name_size))
	_check.call(name_size >= MIN_NAME_SIZE, "%s: nome com fonte ≥ %d (%d)" % [st, MIN_NAME_SIZE, name_size])
	_check.call(plate.grow(-2.0).encloses(name_rect), "%s: nome \"%s\" inteiro na faixa (%s em %s)"
			% [st, elite_name, name_rect, plate])
	# 強敵 e os chips dos afixos dos dois lados (mesma conta do _draw_banner).
	var title_size := int(lay["title_size"])
	var title_w := float(lay["title_w"])
	var title_at: Vector2 = lay["title_at"]
	var title_rect := Rect2(title_at.x, title_at.y - kanji_font.get_ascent(title_size), title_w,
			kanji_font.get_ascent(title_size))
	_check.call(plate.encloses(title_rect), "%s: 強敵 inteiro na faixa (%s em %s)" % [st, title_rect, plate])
	_check.call(title_rect.end.y <= name_rect.position.y + 1.0, "%s: 強敵 acima do nome" % st)
	var cy := float(lay["chips_y"])
	for k: int in affixes.size():
		var sgn := -1.0 if k % 2 == 0 else 1.0
		var cx := plate.get_center().x + sgn * (title_w * 0.5 + 12.0 + floorf(k / 2.0) * 16.0)
		var chip := Rect2(Vector2(roundf(cx - 7.0), roundf(cy - 7.0)), Vector2(14, 14))
		_check.call(plate.encloses(chip), "%s: chip do afixo %d inteiro na faixa (%s em %s)" % [st, k, chip, plate])
		_check.call(not chip.intersects(title_rect), "%s: chip do afixo %d sem cobrir o 強敵" % [st, k])
	for key: String in avoid:
		var r: Rect2 = avoid[key]
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			continue
		_check.call(not plate.intersects(r), "%s: faixa sem cobrir %s (%s e %s)" % [st, key, plate, r])


## Barra sobre a cabeça: os ícones (8 px, passo de 9) de até 3 afixos cabem na largura da barra.
func _check_overhead_bar(st: String) -> void:
	var span := (3 - 1) * 9.0 + 8.0
	_check.call(span <= EliteAffixes.BAR_WIDTH, "%s: ícones de 3 afixos (%.0f px) cabem na barra (%.0f px)"
			% [st, span, EliteAffixes.BAR_WIDTH])
