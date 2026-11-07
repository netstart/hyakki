extends RefCounted
## Guardião do Limiar, portal e Kakuriyo (scripts/systems/rift_portal.gd, scripts/ui/realm_card.gd,
## scripts/game/bot_pilot.gd, data/stages.json "midboss"/"otherworld", data/bosses.json "midboss",
## biomas "<fase>_ura" de data/biomes.json):
##   - dados: toda fase tem o Guardião aos RUN_LENGTH/2, com vida entre a dos chefes dos 5:00 e
##     dos 10:00, padrões próprios, kanji e selo; nenhum evento da fase cai na janela da entrada;
##     todo reino tem bioma do outro mundo (6 materiais, layout válido, sprites existentes),
##     kanji, tinta, luz, música e clima existentes; a mistura da fase com o reino;
##   - agenda ao vivo: aviso 4 s antes, entrada com selo 門 e respiro do spawner;
##   - morte: dois baús de chefe em pontos livres e separados e o portal livre longe deles (em
##     cima de casas reais da vila), sem o baú comum; os dois baús abrem um depois do outro;
##   - portal: selo afasta inimigos e só o toque da guardiã atravessa; ele nunca se move, nunca
##     cresce e nunca força a travessia (só chama: aviso e brilho), e o amanhecer com ele aberto
##     vence no primeiro mapa e o fecha; o bot anda até ele e entra;
##   - outro mundo de verdade: layout, chão, decoração, luz e clima diferentes da fase de origem;
##   - travessia: relógio para e volta, bioma e semente novos, guardiã na origem livre, campo
##     limpo, brasas viram XP, baús vão para a fila, chefe ativo vem junto;
##   - o outro mundo segue: amanhecer (vitória com "realm") e Noite Sem Fim, mas o chefe dos 10:00
##     (o último da lista) não vem no Kakuriyo nem no primeiro mapa;
##   - Tokoyo (3º nível): dados de "midboss2"/"tokoyo" e das 7 Sombras do Guardião (tier 2, selo
##     影, tinta, escala/vida/dano/velocidade, fase extra com esperas ≥ 0,6 s e um padrão do kit);
##     a Sombra só nasce no Kakuriyo, em max(midboss2.t, chegada + after) com o aviso antes; vencida,
##     dois baús e o torii dourado (paleta, folhas douradas, zumbido grave, luz); a travessia leva
##     ao nível 2 com o bioma "<fase>_toko", os limites do bloco e uma semente própria; o último
##     chefe só nasce lá, em max(t, chegada + FINAL_AFTER), com o aviso antes; vencê-lo e amanhecer
##     dá a vitória com "tokoyo"; o bot passa pelos dois portais e enfrenta o último chefe;
##   - partida suspensa: reino, portal aberto e Guardião em campo voltam do snapshot, em cada nível
##     (portal dourado, Sombra e último chefe em campo, chegada salva) e de um snapshot antigo;
##   - cenários de depuração "midboss", "portal", "realm", "midboss2", "portal2" e "tokoyo";
##   - arte própria: cada Guardião usa a folha de assets/art/midbosses/<fase>/ (sem tinta nem
##     montagem provisória), com retrato do códice, tamanho de chefe e, na folha "strip" que olha
##     para a esquerda (Kasa-obake), o lado certo para onde anda e investe; o portal usa portal_open → portal_loop e o
##     torii importados, e o zumbido toca com o portal aberto e para ao fechar, atravessar,
##     reiniciar, retomar sem portal e no fim da partida.
## run_unit() roda sem autoloads (tests/run_tests.gd); run() precisa da árvore
## (tests/integration_tests.gd).

const GAME_SCENE := "res://scenes/game/Game.tscn"
const STEP := 1.0 / 60.0
## Janela em volta do Guardião onde nenhum evento da fase pode cair (aviso, entrada e respiro).
const QUIET_BEFORE := RiftPortal.WARN_LEAD + 6.0
const QUIET_AFTER := 8.0
## Multiplicadores da Sombra do Guardião sobre o Guardião da fase (data/bosses.json "_kage") e a
## folga aceita em cada um (arredondamentos dos dados).
const KAGE_HP := 1.3
const KAGE_DAMAGE := 1.15
const KAGE_SPEED := 1.1
const KAGE_SCALE := 1.15
const KAGE_SLACK := 0.08
## Espera mínima de um padrão avisado (regra dos chefes).
const MIN_WINDUP := 0.6
const AudioFiles := preload("res://scripts/autoload/audio_manager.gd")

var _check: Callable
var _host: Node


static func _json(name: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/%s.json" % name))


# --- Dados (sem autoloads) ----------------------------------------------------------------

func run_unit(check: Callable) -> void:
	_check = check
	var stages: Array = _json("stages")
	var bosses := {}
	for b: Dictionary in _json("bosses"):
		bosses[String(b["id"])] = b
	var biomes: Dictionary = (_json("biomes") as Dictionary)["biomes"]
	var sprites: Dictionary = (_json("biomes") as Dictionary)["sprites"]
	var weather: Dictionary = (_json("weather") as Dictionary)["stages"]
	var seen := {}
	for s: Dictionary in stages:
		var id := String(s["id"])
		_test_midboss_data(s, bosses, seen)
		_test_quiet_window(s)
		_test_realm_data(id, s, biomes, sprites, weather)
		_test_shadow_data(s, bosses)
		_test_tokoyo_data(id, s, biomes, weather)
	_check.call(seen.size() == stages.size(), "limiar: um Guardião diferente por fase (%d)", seen.size())
	_test_realm_stage(stages[0])
	_test_tokoyo_stage(stages[0])
	_test_schedule_math(stages[0])
	_test_palettes()
	_test_arrow_rect()


func _test_midboss_data(s: Dictionary, bosses: Dictionary, seen: Dictionary) -> void:
	var id := String(s["id"])
	var mid := RiftPortal.midboss_of(s)
	_check.call(not mid.is_empty(), "limiar %s: fase tem Guardião", id)
	if mid.is_empty():
		return
	_check.call(is_equal_approx(float(mid["t"]), HyakkiGame.RUN_LENGTH * 0.5),
			"limiar %s: Guardião no meio da noite (%.0f s)", [id, float(mid["t"])])
	var boss: Dictionary = bosses.get(String(mid["id"]), {})
	seen[String(mid["id"])] = true
	_check.call(bool(boss.get("midboss", false)), "limiar %s: %s marcado midboss", [id, mid["id"]])
	var hp := float(boss.get("hp", 0))
	var first := float((bosses[String(s["bosses"][0]["id"])] as Dictionary)["hp"])
	var last := float((bosses[String(s["bosses"][1]["id"])] as Dictionary)["hp"])
	_check.call(hp > first and hp < last, "limiar %s: vida %.0f entre %.0f e %.0f", [id, hp, first, last])
	var patterns := 0
	for phase: Dictionary in boss.get("phases", []):
		patterns += (phase["patterns"] as Array).size()
	patterns += (boss.get("patterns", []) as Array).size()
	_check.call(patterns >= 4, "limiar %s: padrões próprios (%d)", [id, patterns])
	_check.call(String(boss.get("kanji", "")).length() >= 2 and String(boss.get("seal", "")) == "門",
			"limiar %s: kanji e selo 門", id)
	var sheet: Dictionary = boss.get("sprite", {})
	var sprite := String(sheet.get("path", ""))
	_check.call(ResourceLoader.exists(sprite), "limiar %s: sprite existe (%s)", [id, sprite])
	_check.call(sprite.begins_with("res://assets/art/midbosses/%s/" % id), "limiar %s: arte própria do Guardião", id)
	_check.call(not boss.has("tint") and not sheet.has("composite"), "limiar %s: sem tinta nem montagem provisória", id)
	_check.call(ResourceLoader.exists(String(boss.get("faceset", ""))), "limiar %s: retrato do códice existe", id)
	var frame: Array = sheet.get("frame", [0, 0])
	var tall := float(frame[1]) * float(boss.get("scale", 1.0))
	_check.call(tall >= 34.0 and tall <= 100.0, "limiar %s: altura de chefe intermediário (%.0f px)", [id, tall])
	_check.call(String(boss.get("music", "")) == "midboss", "limiar %s: música do Guardião", id)
	# O Kakuriyo toca o tema "kakuriyo"; o Sai no Kawara do Osorezan tem a balsa do Sanzu ("sanzu").
	var ow_music := String((s.get("otherworld", {}) as Dictionary).get("music", ""))
	_check.call(ow_music == ("sanzu" if id == "osorezan" else "kakuriyo"),
			"reino %s: música do Kakuriyo na chegada (%s)", [id, ow_music])


## Nenhum evento (onda especial, elite, cerco) cai na entrada do Guardião; nem chefe nem Kami.
func _test_quiet_window(s: Dictionary) -> void:
	var t := float(RiftPortal.midboss_of(s).get("t", 450.0))
	var clash: Array = []
	for e: Dictionary in s.get("events", []):
		var et := float(e["t"])
		if et > t - QUIET_BEFORE and et < t + QUIET_AFTER:
			clash.append(et)
	for b: Dictionary in s.get("bosses", []):
		if absf(float(b["t"]) - t) < 60.0:
			clash.append(float(b["t"]))
	for k: Variant in s.get("kami", []):
		if absf(float(k) - t) < 30.0:
			clash.append(float(k))
	_check.call(clash.is_empty(), "limiar %s: nada colide com a entrada do Guardião %s", [s["id"], clash])


func _test_realm_data(id: String, s: Dictionary, biomes: Dictionary, sprites: Dictionary,
		weather: Dictionary) -> void:
	var ow: Dictionary = s.get("otherworld", {})
	_check.call(not ow.is_empty(), "reino %s: fase tem outro mundo", id)
	var biome: Dictionary = biomes.get(String(ow.get("biome", "")), {})
	_check.call(bool(biome.get("otherworld", false)) and String(ow.get("biome", "")) == id + "_ura",
			"reino %s: bioma %s do outro mundo", [id, ow.get("biome", "")])
	_check.call(String(biome.get("layout", "")) in ["village", "bamboo", "temple", "dunes", "yomi", "secret", "osorezan"],
			"reino %s: layout válido", id)
	_check.call((biome.get("materials", []) as Array).size() == 6, "reino %s: 6 materiais", id)
	_check.call((biome.get("grade", {}) as Dictionary).has("night"), "reino %s: noite própria", id)
	var missing: Array = []
	for set_v: Dictionary in biome.get("scatter", []):
		for e: Array in set_v["sprites"]:
			if not sprites.has(String(e[0])) and not String(e[0]).begins_with("gen_"):
				missing.append(e[0])
	_check.call(missing.is_empty(), "reino %s: sprites do espalhado existem %s", [id, missing])
	_check.call(String(ow.get("kanji", "")).length() >= 2, "reino %s: nome em kanji", id)
	_check.call(String(ow.get("tint", "")).begins_with("#") and String(ow.get("tint")) != String(s.get("tint")),
			"reino %s: tinta própria", id)
	_check.call(float(ow.get("light_mult", 0.0)) > 0.0, "reino %s: luz definida", id)
	var music := "res://assets/audio/music/%s" % ow.get("music", "")
	_check.call(ResourceLoader.exists(music + ".mp3") or ResourceLoader.exists(music + ".ogg"),
			"reino %s: música existe", id)
	_check.call(weather.has(String(ow.get("weather", ""))), "reino %s: clima existe", id)
	# Outro lugar de verdade, não a mesma fase com outra tinta.
	var origin: Dictionary = biomes.get(id, {})
	_check.call(String(biome.get("layout", "")) != String(origin.get("layout", "")),
			"reino %s: estruturas de outro tipo (%s → %s)", [id, origin.get("layout"), biome.get("layout")])
	_check.call(String(ow.get("weather", "")) != id, "reino %s: clima de outro tipo", id)
	var same := 0
	for k: int in 6:
		var a: Dictionary = (origin.get("materials", []) as Array)[k]
		var b: Dictionary = (biome.get("materials", []) as Array)[k]
		if a.get("tiles", a.get("block")) == b.get("tiles", b.get("block")) and a.get("tint") == b.get("tint"):
			same += 1
	_check.call(same == 0, "reino %s: chão todo diferente da origem (%d materiais iguais)", [id, same])
	_check.call((biome["grade"] as Dictionary)["night"] != (origin["grade"] as Dictionary)["night"]
			and biome.get("tufts") != origin.get("tufts"), "reino %s: luz da noite e vegetação próprias", id)


func _test_realm_stage(s: Dictionary) -> void:
	var realm := RiftPortal.realm_stage(s)
	var ow: Dictionary = s["otherworld"]
	_check.call(realm["id"] == s["id"] and realm["waves"] == s["waves"], "reino: mesma fase (id, ondas)")
	_check.call(realm["biome"] == ow["biome"] and realm["tint"] == ow["tint"] and realm["music"] == ow["music"],
			"reino: bioma, tinta e música do outro mundo")
	_check.call(not realm.has("kanji") and bool(realm.get("realm", false)), "reino: marcado e sem o kanji")
	_check.call(not s.has("realm") and s["tint"] != realm["tint"], "reino: a fase original não muda")


## Sombra do Guardião: variante do Guardião da fase com a mesma arte, mais forte, uma fase a mais
## (abaixo de 1/3) com esperas menores (nunca < 0,6 s) e um padrão a mais do próprio kit.
func _test_shadow_data(s: Dictionary, bosses: Dictionary) -> void:
	var id := String(s["id"])
	var mid := RiftPortal.midboss_of(s)
	var mid2 := RiftPortal.midboss2_of(s)
	_check.call(not mid2.is_empty(), "sombra %s: fase tem a Sombra do Guardião", id)
	if mid2.is_empty() or mid.is_empty():
		return
	_check.call(is_equal_approx(float(mid2["t"]), 540.0) and float(mid2["t"]) > float(mid["t"]),
			"sombra %s: depois do Guardião (%.0f s)", [id, float(mid2["t"])])
	_check.call(float(mid2.get("after", 0.0)) > RiftPortal.WARN_LEAD, "sombra %s: espera depois da chegada", id)
	_check.call(String(mid2["id"]) == String(mid["id"]) + "_kage", "sombra %s: id %s", [id, mid2["id"]])
	var base: Dictionary = bosses.get(String(mid["id"]), {})
	var kage: Dictionary = bosses.get(String(mid2["id"]), {})
	_check.call(not kage.is_empty(), "sombra %s: chefe em data/bosses.json", id)
	if kage.is_empty() or base.is_empty():
		return
	_check.call(bool(kage.get("midboss", false)) and int(kage.get("tier", 1)) == 2
			and String(kage.get("seal", "")) == "影",
			"sombra %s: midboss de tier 2 com o selo 影", id)
	_check.call(int(base.get("tier", 1)) == 1, "sombra %s: o Guardião da fase é tier 1", id)
	_check.call(kage["sprite"] == base["sprite"] and kage.get("faceset") == base.get("faceset")
			and kage.get("walk_sprite") == base.get("walk_sprite") and kage.get("attack_sprite") == base.get("attack_sprite"),
			"sombra %s: mesma arte do Guardião", id)
	var tint := Color(String(kage.get("tint", "#ffffff")))
	_check.call(kage.has("tint") and tint != Color.WHITE and tint.get_luminance() < 0.92,
			"sombra %s: tinta do Kakuriyo (%s)", [id, tint])
	_check.call(String(kage.get("aura", "")) != String(base.get("aura", "")), "sombra %s: aura própria", id)
	for row: Array in [["hp", KAGE_HP], ["damage", KAGE_DAMAGE], ["speed", KAGE_SPEED]]:
		var ratio := float(kage[row[0]]) / float(base[row[0]])
		_check.call(absf(ratio - float(row[1])) <= KAGE_SLACK * float(row[1]), "sombra %s: %s %.2fx", [id, row[0], ratio])
	# Equilíbrio: a Sombra nunca tem mais vida que o último chefe da fase (o senhor do Tokoyo).
	var last_boss: Dictionary = bosses.get(String(RiftPortal.final_boss_of(s).get("id", "")), {})
	_check.call(float(kage["hp"]) < float(last_boss.get("hp", 0.0)),
			"sombra %s: vida %.0f abaixo da do último chefe (%.0f)", [id, float(kage["hp"]), float(last_boss.get("hp", 0.0))])
	var scale := float(kage.get("scale", 1.0)) / float(base.get("scale", 1.0))
	_check.call(absf(scale - KAGE_SCALE) <= 0.01, "sombra %s: escala %.3fx", [id, scale])
	var phases: Array = kage.get("phases", [])
	var base_phases: Array = base.get("phases", [])
	_check.call(phases.size() == base_phases.size() + 1, "sombra %s: uma fase a mais (%d)", [id, phases.size()])
	if phases.size() < 2:
		return
	var last: Dictionary = phases.back()
	var before: Dictionary = phases[phases.size() - 2]
	_check.call(float(last["below"]) < 0.34 and float(last["below"]) > 0.3, "sombra %s: fase extra abaixo de 1/3", id)
	_check.call((last["patterns"] as Array).size() == (before["patterns"] as Array).size() + 1,
			"sombra %s: um padrão a mais na fase extra", id)
	var kit := {}
	for phase: Dictionary in base_phases:
		for p: Dictionary in phase["patterns"]:
			kit[String(p["type"])] = true
	var faster := false
	var outside: Array = []
	var short: Array = []
	for phase: Dictionary in phases:
		for p: Dictionary in phase["patterns"]:
			if not kit.has(String(p["type"])):
				outside.append(p["type"])
			if p.has("windup") and float(p["windup"]) < MIN_WINDUP - 0.001:
				short.append(p["windup"])
	for k: int in (before["patterns"] as Array).size():
		var a: Dictionary = before["patterns"][k]
		var b: Dictionary = last["patterns"][k]
		# Esperas: a preparação dos padrões avisados e o intervalo entre os tiros da espiral.
		_check.call(a["type"] == b["type"] and float(b.get("windup", 0.0)) <= float(a.get("windup", 0.0))
				and float(b.get("rate", 0.0)) <= float(a.get("rate", 0.0)),
				"sombra %s: fase extra repete a anterior sem esperar mais (%s)", [id, a["type"]])
		var quicker := float(b.get("windup", 0.0)) < float(a.get("windup", 0.0))
		faster = faster or quicker or float(b.get("rate", 0.0)) < float(a.get("rate", 0.0))
	_check.call(faster, "sombra %s: esperas menores na fase extra", id)
	_check.call(outside.is_empty(), "sombra %s: só padrões do kit do Guardião %s", [id, outside])
	_check.call(short.is_empty(), "sombra %s: nenhuma espera abaixo de %.1f s %s", [id, MIN_WINDUP, short])


## O bloco "tokoyo": bioma próprio "<fase>_toko", kanji 常世…, tinta clara e dourada, luz alta,
## música, clima sem tempestade, arena limitada e sem perigo.
func _test_tokoyo_data(id: String, s: Dictionary, biomes: Dictionary, weather: Dictionary) -> void:
	var toko: Dictionary = s.get("tokoyo", {})
	var ow: Dictionary = s.get("otherworld", {})
	_check.call(not toko.is_empty(), "tokoyo %s: fase tem o Tokoyo", id)
	if toko.is_empty():
		return
	_check.call(String(toko.get("biome", "")) == id + "_toko", "tokoyo %s: bioma %s", [id, toko.get("biome")])
	var biome: Dictionary = biomes.get(String(toko.get("biome", "")), {})
	_check.call(bool(biome.get("tokoyo", false)), "tokoyo %s: bioma do Tokoyo em data/biomes.json", id)
	var kanji := String(toko.get("kanji", ""))
	_check.call(kanji.begins_with("常世") and kanji.length() == 3 and kanji != String(ow.get("kanji", "")),
			"tokoyo %s: nome em kanji (%s)", [id, kanji])
	var tint := Color(String(toko.get("tint", "#000000")))
	_check.call(String(toko.get("tint", "")).begins_with("#") and tint.get_luminance() > 0.88,
			"tokoyo %s: tinta clara (%s)", [id, toko.get("tint")])
	var light := float(toko.get("light_mult", 0.0))
	_check.call(light > 1.05 and light > float(ow.get("light_mult", 1.0)),
			"tokoyo %s: mais luz que o Kakuriyo", id)
	var music := String(toko.get("music", ""))
	var file := String(AudioFiles.MUSIC_FILES.get(music, music))
	_check.call(music == "tokoyo" and (ResourceLoader.exists(AudioFiles.MUSIC_DIR + file + ".mp3")
			or ResourceLoader.exists(AudioFiles.MUSIC_DIR + file + ".ogg")), "tokoyo %s: música existe (%s)", [id, file])
	var w := String(toko.get("weather", ""))
	_check.call(weather.has(w) and not bool((weather.get(w, {}) as Dictionary).get("lightning", false)),
			"tokoyo %s: clima sem tempestade (%s)", [id, w])
	var b: Array = toko.get("bounds", [])
	_check.call(b.size() == 2 and float(b[0]) > 0.0 and float(b[1]) > 0.0, "tokoyo %s: arena limitada %s", [id, b])
	_check.call((toko.get("hazard", {"x": 1}) as Dictionary).is_empty(), "tokoyo %s: sem perigo", id)


func _test_tokoyo_stage(s: Dictionary) -> void:
	var toko: Dictionary = s["tokoyo"]
	var realm := RiftPortal.realm_stage(s, RiftPortal.DEPTH_TOKOYO)
	_check.call(realm["id"] == s["id"] and realm["waves"] == s["waves"] and realm["bosses"] == s["bosses"],
			"tokoyo: mesma fase (id, ondas, chefes)")
	_check.call(realm["biome"] == toko["biome"] and realm["tint"] == toko["tint"] and realm["music"] == "tokoyo"
			and realm["bounds"] == toko["bounds"] and int(realm["depth"]) == 2,
			"tokoyo: bioma, tinta, música e limites do bloco")
	_check.call(not realm.has("kanji") and bool(realm.get("realm", false)), "tokoyo: marcado e sem o kanji")
	_check.call(RiftPortal.realm_stage(s, 0) == s and int(RiftPortal.realm_stage(s)["depth"]) == 1,
			"níveis: 0 é a própria fase, o padrão é o Kakuriyo")


## Agenda relativa à chegada: a Sombra em max(midboss2.t, chegada + after), o último chefe em
## max(t, chegada + FINAL_AFTER).
func _test_schedule_math(s: Dictionary) -> void:
	var mid2 := RiftPortal.midboss2_of(s)
	var after := float(mid2["after"])
	var t2 := float(mid2["t"])
	var final_t := float(RiftPortal.final_boss_of(s)["t"])
	_check.call(is_equal_approx(Spawner.shadow_time(s, t2 - after - 30.0), t2), "agenda: chegada cedo, Sombra no horário")
	_check.call(is_equal_approx(Spawner.shadow_time(s, t2), t2 + after), "agenda: chegada tarde, Sombra depois da espera")
	_check.call(is_equal_approx(Spawner.final_time(s, final_t - 40.0), final_t), "agenda: último chefe no horário")
	_check.call(is_equal_approx(Spawner.final_time(s, final_t + 40.0), final_t + 40.0 + Spawner.FINAL_AFTER),
			"agenda: chegada tarde, último chefe depois de FINAL_AFTER")
	_check.call(Spawner.FINAL_AFTER > Spawner.FINAL_WARN and Spawner.FINAL_AFTER <= 10.0, "agenda: aviso cabe na espera")
	_check.call(RiftPortal.final_boss_of(s) == (s["bosses"] as Array).back(),
			"agenda: o último chefe é o último da lista")


## Violeta para o Kakuriyo, ouro e luz para o Tokoyo.
func _test_palettes() -> void:
	var violet := RiftPortal.palette(false)
	var gold := RiftPortal.palette(true)
	for key: String in ["void", "swirl", "edge", "torii", "arrow", "light", "flash"]:
		_check.call(violet.has(key) and gold.has(key) and violet[key] != gold[key],
				"paleta: %s própria do torii dourado", key)
	for key: String in ["swirl", "torii", "arrow", "light"]:
		var c: Color = gold[key]
		_check.call(c.h > 0.08 and c.h < 0.17 and c.r > c.b, "paleta: %s dourado (matiz %.2f)", [key, c.h])
		var v: Color = violet[key]
		_check.call(key == "torii" or (v.h > 0.68 and v.h < 0.85), "paleta: %s violeta (matiz %.2f)", [key, v.h])
	var edge: Color = gold["edge"]
	_check.call(edge.get_luminance() > 0.9, "paleta: borda do torii dourado é luz")


## A seta do portal cabe na folga de 18 px que Hud.arrow_point deixa da borda.
func _test_arrow_rect() -> void:
	for i: int in 16:
		var dir := Vector2.RIGHT.rotated(TAU * i / 16.0)
		var r := RiftPortal.arrow_rect(Vector2(100, 100), dir)
		_check.call(Rect2(Vector2(100, 100), Vector2.ZERO).grow(17.0).encloses(r),
				"seta do portal para %.0f° cabe na folga da borda (%s)", [rad_to_deg(dir.angle()), r])


# --- Partida (com a árvore) -----------------------------------------------------------------

func run(host: Node, check: Callable) -> void:
	_host = host
	_check = check
	await _test_terrain()
	await _test_schedule()
	await _test_double_chest()
	await _test_portal()
	await _test_touch_only_and_bot()
	await _test_dawn_with_portal_open()
	await _test_realm_continues(false)
	await _test_realm_continues(true)
	await _test_snapshot()
	await _test_scenarios()
	await _test_shadow_schedule(false)
	await _test_shadow_schedule(true)
	await _test_no_final_outside()
	await _test_golden_torii()
	await _test_tokoyo_crossing()
	await _test_final_schedule(false)
	await _test_final_schedule(true)
	await _test_tokoyo_snapshots()
	await _test_tokoyo_scenarios()
	await _test_bot_two_portals()
	await _test_midboss_kill_daily()
	await _test_strip_facing()
	await _test_portal_art_and_hum()
	GameClock.paused = false
	await _host.get_tree().process_frame


func _new_game(stage_id: String = "village", endless: bool = false) -> HyakkiGame:
	var game := (load(GAME_SCENE) as PackedScene).instantiate() as HyakkiGame
	game.config = {"hero": "aki", "stage": stage_id, "moon": 0, "mode": "normal", "seed": 909, "speed": 1,
			"endless": endless}
	_host.add_child(game)
	await _host.get_tree().process_frame
	GameClock.paused = true
	game.player.god_mode = true
	return game


func _free(game: HyakkiGame) -> void:
	game.queue_free()
	GameClock.paused = false
	await _host.get_tree().process_frame


## Passos manuais (o relógio do autoload fica parado); telas que abrirem são respondidas como o bot.
func _tick(game: HyakkiGame, count: int) -> void:
	for _k: int in count:
		GameClock.game_time += STEP
		game._on_tick(STEP)
		if game.hud.overlay_open() and not game.rift.crossing():
			game.hud.bot_answer()


func _chests(game: HyakkiGame) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item: Dictionary in game.pickups.items:
		if item["id"] == &"chest":
			out.append(item)
	return out


## Os 7 reinos de verdade: estrutura gerada, origem livre para a guardiã nascer, limites.
func _test_terrain() -> void:
	for id: StringName in DB.ids("stages"):
		var realm := RiftPortal.realm_stage(DB.stage(id))
		var w := WorldMap.new()
		w.setup(realm, 4321)
		var solids := 0
		for cy: int in range(-1, 2):
			for cx: int in range(-1, 2):
				solids += (w.chunk_data(Vector2i(cx, cy))["solids"] as Array).size()
		_check.call(bool(w.biome.get("otherworld", false)), "reino %s: mundo monta o bioma do outro lado", id)
		_check.call(solids > 0, "reino %s: estrutura gerada (%d obstáculos)", [id, solids])
		_check.call(not w.overlaps_solid(Vector2.ZERO, Player.RADIUS + 2.0), "reino %s: origem livre", id)
		w.free()
	await _host.get_tree().process_frame


func _test_schedule() -> void:
	var game := await _new_game()
	GameClock.game_time = 440.0
	game.spawner.skip_until(440.0)
	_tick(game, roundi(6.5 / STEP))
	_check.call(String(game.hud.get("_toast").text) == TranslationServer.translate("midboss.warning"),
			"limiar: aviso antes da entrada")
	_check.call(not game.bosses.has_boss(&"onikuma"), "limiar: Guardião ainda não entrou no aviso")
	_tick(game, roundi(4.0 / STEP))
	_check.call(game.bosses.has_boss(&"onikuma"), "limiar: Kasa-obake entra aos 7:30 na Vila")
	_check.call(game.hud.boss_panel().seal_glyph == "門" and game.hud.boss_panel().kanji == "傘お化け",
			"limiar: painel do chefe com o kanji e o selo do portão")
	var commons := game.enemies.count_common
	game.spawner.hush(2.0)
	_tick(game, 30)
	_check.call(game.enemies.count_common <= commons, "limiar: respiro do spawner segura os comuns")
	await _free(game)


## Morte em cima de casas reais da vila: dois baús livres e separados, portal livre e longe.
func _test_double_chest() -> void:
	var game := await _new_game()
	var world := game.world
	var spots: Array[Vector2] = [game.player.sim_pos + Vector2(120, 0)]
	for cy: int in range(-1, 2):
		for cx: int in range(-1, 2):
			for solid: Array in world.chunk_data(Vector2i(cx, cy))["solids"]:
				if spots.size() < 6 and float(solid[1]) >= 10.0:
					spots.append(solid[0])
	var bad := 0
	for at: Vector2 in spots:
		game.pickups.items.clear()
		game.rift.reset()
		game.on_boss_defeated(&"onikuma", at)
		var chests := _chests(game)
		var ok := chests.size() == 2 and game.rift.is_open()
		for c: Dictionary in chests:
			ok = ok and bool(c.get("boss", false)) and not world.overlaps_solid(c["pos"], PickupManager.SPAWN_CLEARANCE)
			ok = ok and (c["pos"] as Vector2).distance_to(game.rift.portal_pos) >= RiftPortal.CLEARANCE
		if chests.size() == 2:
			ok = ok and (chests[0]["pos"] as Vector2).distance_to(chests[1]["pos"]) >= RiftPortal.CHEST_MIN_GAP
		ok = ok and not world.overlaps_solid(game.rift.portal_pos, RiftPortal.CLEARANCE)
		if not ok:
			bad += 1
	_check.call(spots.size() >= 4, "limiar: pontos de morte para testar (%d)", spots.size())
	_check.call(bad == 0, "limiar: dois baús de chefe livres e separados e o portal livre (%d falhas)", bad)
	_check.call(game.tracker.bosses.has(&"onikuma") and game.rift.midboss_done, "limiar: Guardião vencido conta")
	# Os dois baús pegos juntos abrem um depois do outro.
	game.rift.close_portal()
	var opened := game.tracker.chests
	for c: Dictionary in _chests(game):
		c["pos"] = game.player.sim_pos
	_tick(game, 3)
	_check.call(game.hud.chest_open() or game.tracker.chests > opened, "limiar: primeiro baú abre")
	_tick(game, 30)
	_check.call(game.tracker.chests == opened + 2, "limiar: os dois baús abrem (%d)", (game.tracker.chests - opened))
	await _free(game)


func _test_portal() -> void:
	var game := await _new_game()
	var rift := game.rift
	var origin_seed := game.world.seed_value
	game.bosses.spawn(&"tanuki")
	rift.midboss_done = true
	rift.open_portal(game.player.sim_pos + Vector2(70, 0))
	var e := game.enemies.spawn(&"slime_rice", rift.portal_pos, 1000.0, 1.0)
	_tick(game, 1)
	_check.call(game.enemies.pos[e].distance_to(rift.portal_pos) >= rift.portal_radius + RiftPortal.WARD - 0.01,
			"portal: o selo afasta inimigos")
	_check.call(rift.is_open() and not rift.crossing(), "portal: aberto sem a guardiã encostar")
	for k: int in 20:
		game.enemies.spawn(&"slime_rice", game.player.sim_pos + Vector2.from_angle(k) * 60.0, 1000.0, 1.0)
	game.pickups.spawn(game.player.sim_pos + Vector2(200, 40), 7)
	game.pickups.spawn_item(&"chest", game.player.sim_pos + Vector2(-220, 0))
	var xp_before := game.xp + game.level * 1000
	var pending: Array = game.get("_pending_chests")
	var queued := pending.size()
	var time := GameClock.game_time
	game.player.sim_pos = rift.portal_pos
	_tick(game, 1)
	_check.call(rift.crossing() and GameClock.paused and game.hud.overlay_open(),
			"portal: tocar atravessa (relógio parado, travessia na tela)")
	_check.call(game.hud.realm_card().active and game.hud.realm_card().kanji == "裏村", "portal: título do reino")
	rift.finish_crossing_now()
	_check.call(rift.in_realm and rift.reached and game.tracker.realm_reached, "travessia: chegou ao Kakuriyo")
	_check.call(game.world.biome == TerrainArt.biome("village_ura") and game.stage["biome"] == "village_ura",
			"travessia: bioma do outro mundo")
	_check.call(game.world.seed_value == rift.realm_seed and rift.realm_seed != origin_seed, "travessia: semente nova")
	_check.call(game.player.sim_pos == Vector2.ZERO and not game.world.overlaps_solid(Vector2.ZERO, Player.RADIUS),
			"travessia: guardiã na origem livre")
	_check.call(game.enemies.count_common == 0 and game.enemy_shots.count_alive == 0, "travessia: campo limpo")
	_check.call(game.pickups.count_alive == 0 and game.pickups.items.is_empty(), "travessia: nada fica no chão")
	_check.call(game.xp + game.level * 1000 > xp_before, "travessia: brasas viram XP")
	_check.call(pending.size() == queued + 1, "travessia: baú do chão vai para a fila")
	_check.call(game.bosses.has_boss(&"tanuki"), "travessia: chefe ativo vem junto")
	var boss_at: Vector2 = game.enemies.pos[int(game.bosses.bosses[0]["index"])]
	var half := game.view_size() * 0.5
	_check.call(absf(boss_at.x) >= half.x - 1.0 or absf(boss_at.y) >= half.y - 1.0,
			"travessia: chefe reaparece na borda da tela, longe da guardiã (%s, tela %s)", [boss_at, half * 2.0])
	_check.call(not GameClock.paused and not game.hud.realm_active() and not rift.is_open(),
			"travessia: relógio volta e o portal fecha")
	_check.call(is_equal_approx(GameClock.game_time, time + STEP), "travessia: o tempo da noite continua")
	_check.call(String(game.hud.get("_toast").text) == TranslationServer.translate("realm.entered"),
			"travessia: aviso de chegada")
	await _free(game)


## O portal espera: em 1,5 minuto aberto não sai do lugar, não cresce, não puxa nem atravessa
## sozinho (só chama); a guardiã andando até ele (pelo controle, como o bot) atravessa no toque.
func _test_touch_only_and_bot() -> void:
	var game := await _new_game()
	var rift := game.rift
	rift.midboss_done = true
	rift.open_portal(game.player.sim_pos + Vector2(160, 30))
	var at := rift.portal_pos
	var me := game.player.sim_pos
	var toasts := 0
	for _k: int in roundi(90.0 / STEP / 30.0):
		_tick(game, 30)
		game.player.sim_pos = me
		if String(game.hud.get("_toast").text) == TranslationServer.translate("portal.invite"):
			toasts += 1
	_check.call(rift.is_open() and not rift.crossing() and not rift.in_realm,
			"portal: 1,5 min sem toque, nada de travessia")
	_check.call(rift.portal_pos == at and rift.portal_radius == RiftPortal.PORTAL_RADIUS and rift.art_scale() == 1.0,
			"portal: nunca se move nem cresce")
	_check.call(rift.beckon() == 1.0 and toasts > 0, "portal: só chama (brilho e aviso de convite)")
	# Andando até ele pelo controle (o mesmo que o joystick faz), a guardiã atravessa no toque.
	var steps := 0
	while not rift.crossing() and steps < 900:
		game.player.move_input = BotPilot.input(game)
		_tick(game, 1)
		steps += 1
	_check.call(rift.crossing() and game.player.sim_pos.distance_to(at) <= RiftPortal.PORTAL_RADIUS + Player.RADIUS + 2.0,
			"bot: anda até o portal e atravessa ao tocar (%.1f s)", (steps * STEP))
	rift.finish_crossing_now()
	_check.call(rift.in_realm, "portal: o toque leva ao Kakuriyo")
	await _free(game)


## O amanhecer com o portal aberto: vitória no primeiro mapa e o portal fecha.
func _test_dawn_with_portal_open() -> void:
	var game := await _new_game()
	var results: Array[Dictionary] = []
	game.finished.connect(func(r: Dictionary) -> void: results.append(r))
	game.apply_scenario("portal")
	GameClock.game_time = HyakkiGame.RUN_LENGTH - STEP * 2.0
	_tick(game, 4)
	_check.call(results.size() == 1 and bool(results[0]["victory"]) and not bool(results[0]["realm"]),
			"portal: amanhecer antes de entrar vence no primeiro mapa")
	_check.call(not game.rift.is_open() and not game.rift.hum_playing() and not game.rift.in_realm,
			"portal: o amanhecer fecha o portal")
	await _free(game)


## No outro mundo: o chefe dos 10:00 não vem (só no Tokoyo), o amanhecer vence (ou abre a Noite
## Sem Fim).
func _test_realm_continues(endless: bool) -> void:
	var game := await _new_game("bamboo", endless)
	var results: Array[Dictionary] = []
	game.finished.connect(func(r: Dictionary) -> void: results.append(r))
	game.apply_scenario("realm")
	_tick(game, 1)
	game.rift.finish_crossing_now()
	var tag := "Noite Sem Fim" if endless else "amanhecer"
	_check.call(game.rift.in_realm and game.stage["biome"] == "bamboo_ura", "reino (%s): na Planície Nevada da Lua", tag)
	GameClock.game_time = 599.0
	game.spawner.skip_until(599.0)
	_tick(game, roundi(3.0 / STEP))
	_check.call(not game.bosses.has_boss(&"kitsune_nine"), "reino (%s): chefe dos 10:00 não vem no Kakuriyo", tag)
	game.bosses.reset()
	GameClock.game_time = HyakkiGame.RUN_LENGTH - STEP * 2.0
	_tick(game, 4)
	if endless:
		_check.call(game.endless_phase and game.running and game.rift.in_realm
				and game.world.biome == TerrainArt.biome("bamboo_ura"), "reino: Noite Sem Fim segue no outro mundo")
		_check.call(results.is_empty(), "reino: Noite Sem Fim não encerra no amanhecer")
	else:
		_check.call(results.size() == 1 and bool(results[0]["victory"]) and bool(results[0]["realm"]),
				"reino: amanhecer no outro mundo é vitória e registra o reino")
	await _free(game)


func _test_snapshot() -> void:
	# No reino.
	var game := await _new_game()
	game.apply_scenario("realm")
	_tick(game, 1)
	game.rift.finish_crossing_now()
	var seed_realm := game.rift.realm_seed
	var snap: Dictionary = JSON.parse_string(JSON.stringify(game.snapshot()))
	await _free(game)
	var again := await _new_game()
	again.restore_snapshot(snap)
	_check.call(again.rift.in_realm and again.world.seed_value == seed_realm
			and again.world.biome == TerrainArt.biome("village_ura"), "retomada: volta ao Kakuriyo com a mesma semente")
	_check.call(again.rift.midboss_done and not again.bosses.has_boss(&"onikuma"), "retomada: Guardião não volta")
	again.close_pause()
	await _free(again)
	# Portal aberto.
	game = await _new_game()
	game.apply_scenario("portal")
	var portal := game.rift.portal_pos
	game.rift.portal_age = 12.5
	snap = JSON.parse_string(JSON.stringify(game.snapshot()))
	await _free(game)
	again = await _new_game()
	again.restore_snapshot(snap)
	_check.call(again.rift.is_open() and again.rift.portal_pos.is_equal_approx(portal)
			and is_equal_approx(again.rift.portal_age, 12.5) and not again.rift.in_realm,
			"retomada: portal aberto no mesmo lugar e tempo")
	await _free(again)
	# Guardião em campo (inimigos não entram no snapshot): volta a ser chamado.
	game = await _new_game()
	GameClock.game_time = 455.0
	game.spawner.skip_until(455.0)
	snap = JSON.parse_string(JSON.stringify(game.snapshot()))
	await _free(game)
	again = await _new_game()
	again.restore_snapshot(snap)
	_check.call(again.bosses.has_boss(&"onikuma"), "retomada: Guardião em campo é chamado de novo")
	await _free(again)


## Folha "strip" do Guardião (arte que olha para a esquerda): vira para onde anda e investe.
func _test_strip_facing() -> void:
	var game := await _new_game()
	game.bosses.spawn(&"onikuma")
	var boss: Dictionary = game.bosses.bosses[0]
	var i := int(boss["index"])
	var enemies := game.enemies
	var sheet: SpriteSheet = enemies.type_sheets[enemies.kind[i]]
	_check.call(sheet.layout == "strip" and sheet.faces_left, "strip: folha do Kasa-obake olhando para a esquerda")
	for dir: int in [SpriteSheet.Dir.LEFT, SpriteSheet.Dir.RIGHT]:
		var offset: Vector2 = [Vector2(0, 1), Vector2(0, -1), Vector2(-1, 0), Vector2(1, 0)][dir] * 200.0
		game.player.sim_pos = enemies.pos[i] + offset
		boss["state"] = "move"
		boss["timer"] = 5.0
		_tick(game, 2)
		_check.call(enemies.facing[i] == dir and sheet.needs_flip(dir) == (dir == SpriteSheet.Dir.RIGHT),
				"strip: anda e olha para a %s", ["", "", "esquerda", "direita"][dir])
	boss["state"] = "charge"
	boss["timer"] = 1.0
	boss["dir"] = Vector2(-200, 0)
	_tick(game, 1)
	_check.call(enemies.facing[i] == SpriteSheet.Dir.LEFT and not sheet.needs_flip(enemies.facing[i]),
			"strip: olha para onde investe")
	await _free(game)


func _test_portal_art_and_hum() -> void:
	var game := await _new_game()
	var rift := game.rift
	_check.call(rift.has_art(), "portal: arte importada (abertura, loop e torii) carregada")
	rift.open_portal(game.player.sim_pos + Vector2(80, 0))
	_check.call((rift.sprite_frame()[0] as Texture2D).resource_path == RiftPortal.SPRITE_OPEN,
			"portal: abre com portal_open")
	rift.portal_age = 2.0
	var pick := rift.sprite_frame()
	_check.call((pick[0] as Texture2D).resource_path == RiftPortal.SPRITE_LOOP and int(pick[1]) < 12,
			"portal: segue no portal_loop")
	_check.call(rift.art_scale() == 1.0, "portal: arte em escala inteira (1x, como os atores)")
	_check.call(rift.hum_playing(), "zumbido: toca com o portal aberto")
	rift.close_portal()
	_check.call(not rift.hum_playing(), "zumbido: para ao fechar")
	rift.open_portal(game.player.sim_pos + Vector2(80, 0))
	game.player.sim_pos = rift.portal_pos
	_tick(game, 1)
	_check.call(rift.crossing() and not rift.hum_playing(), "zumbido: para ao atravessar")
	rift.finish_crossing_now()
	rift.open_portal(game.player.sim_pos + Vector2(200, 0))
	var snap: Dictionary = JSON.parse_string(JSON.stringify(game.snapshot()))
	game.start_run(game.config)
	_check.call(not rift.hum_playing(), "zumbido: para ao reiniciar a partida")
	await _free(game)
	var again := await _new_game()
	snap["realm"]["in_realm"] = false
	again.restore_snapshot(snap)
	_check.call(again.rift.is_open() and again.rift.hum_playing(), "zumbido: volta com o portal retomado")
	again.call("_end_run", false, true)
	_check.call(not again.rift.hum_playing(), "zumbido: para no fim da partida")
	await _free(again)


func _test_scenarios() -> void:
	var game := await _new_game("yomi")
	game.apply_scenario("midboss")
	_check.call(is_equal_approx(GameClock.game_time, 450.0 - RiftPortal.WARN_LEAD - 1.0),
			"cenário midboss: antes do aviso")
	_tick(game, roundi((RiftPortal.WARN_LEAD + 1.5) / STEP))
	_check.call(game.bosses.has_boss(&"yomi_hebi"), "cenário midboss: Yomi-hebi entra no Yomi")
	await _free(game)
	game = await _new_game("secret")
	game.apply_scenario("portal")
	_check.call(game.rift.is_open() and _chests(game).size() == 2, "cenário portal: dois baús e o portal")
	await _free(game)


## Guardião morto pelo caminho real (a vida zera por dano e o BossDirector vê a morte): o portal
## abre com os dois baús de chefe, na partida comum e na do Desafio Diário (cfg como a do
## App._apply_daily: semente sorteada, herói variado, lua 0, sem bônus da Loja), em cada fase.
## Dois jeitos de matar: dano de arma com o Guardião longe da guardiã (os baús ficam no chão) e o
## bot jogando (armas e habilidades de verdade, com a vida do Guardião já baixa).
func _test_midboss_kill_daily() -> void:
	var heroes := DB.ids("heroes")
	var k := 0
	for stage_id: StringName in DB.ids("stages"):
		for daily: bool in [false, true]:
			for by_bot: bool in [false, true]:
				var cfg := {"hero": "aki", "stage": String(stage_id), "moon": 0, "mode": "normal",
						"seed": 909, "speed": 1, "endless": false, "cosmetic": ""}
				if daily:
					# A cfg do Desafio de hoje; fase e herói trocados para cobrir todos.
					var app := App.new()
					app._apply_daily(cfg)
					app.free()
					cfg["hero"] = heroes[k % heroes.size()]
					cfg["stage"] = stage_id
					cfg["seed"] = int(cfg["seed"]) + k
				k += 1
				await _midboss_kill(cfg, by_bot)


func _midboss_kill(cfg: Dictionary, by_bot: bool) -> void:
	var stage_id := StringName(cfg["stage"])
	var game := (load(GAME_SCENE) as PackedScene).instantiate() as HyakkiGame
	game.config = cfg
	_host.add_child(game)
	await _host.get_tree().process_frame
	GameClock.paused = true
	game.apply_scenario("midboss")
	if by_bot:
		game._bot = true
	var mid := StringName(RiftPortal.midboss_of(DB.stage(stage_id))["id"])
	var label := "limiar %s%s (%s, %s): " % [stage_id, " diário" if bool(cfg.get("daily", false)) else "",
			cfg["hero"], "bot" if by_bot else "dano"]
	_tick(game, roundi((RiftPortal.WARN_LEAD + 1.5) / STEP))
	_check.call(game.bosses.has_boss(mid), label + "Guardião entra")
	var weapon := game.weapons[0].id
	var ticks := 0
	while game.bosses.has_boss(mid) and ticks < 60 * 90:
		for boss: Dictionary in game.bosses.bosses:
			var i := int(boss["index"])
			if StringName(boss["id"]) != mid:
				continue
			if by_bot:
				game.enemies.hp[i] = minf(game.enemies.hp[i], 60.0)
			else:
				game.enemies.pos[i] = game.player.sim_pos + Vector2(220.0, 0.0)
				game.enemies.prev[i] = game.enemies.pos[i]
				game.deal_damage(weapon, i, 400.0, Vector2.RIGHT, 0.0)
		_tick(game, 1)
		ticks += 1
	var rift := game.rift
	_check.call(not game.bosses.has_boss(mid), label + "Guardião morre (%d passos)" % ticks)
	_check.call(rift.midboss_done and (rift.is_open() or rift.crossing() or rift.in_realm),
			label + "portal aberto (estado %d)" % rift.state)
	if not by_bot:
		var boss_chests := _chests(game).filter(func(c: Dictionary) -> bool: return bool(c.get("boss", false)))
		_check.call(boss_chests.size() == 2, label + "dois baús de chefe (%d)" % boss_chests.size())
	await _free(game)


# --- Tokoyo (3º nível) ----------------------------------------------------------------------

## Atravessa o portal do Guardião (cenário "realm") e chega ao Kakuriyo.
func _to_kakuriyo(game: HyakkiGame, at_time: float = -1.0) -> void:
	game.apply_scenario("realm")
	if at_time > 0.0:
		_jump(game, at_time)
	_tick(game, 1)
	game.rift.finish_crossing_now()


## Atravessa o torii dourado (cenário "tokoyo") e chega ao Tokoyo.
func _to_tokoyo(game: HyakkiGame, at_time: float = -1.0) -> void:
	game.apply_scenario("tokoyo")
	if at_time > 0.0:
		_jump(game, at_time)
	_tick(game, 1)
	game.rift.finish_crossing_now()


func _jump(game: HyakkiGame, time: float) -> void:
	GameClock.game_time = time
	game.spawner.skip_until(time)


func _toast_is(game: HyakkiGame, key: String) -> bool:
	return String(game.hud.get("_toast").text) == TranslationServer.translate(key)


## Passos até o chefe `id` entrar (ou `seconds`); devolve a hora da entrada (-1 se não entrou).
func _tick_until_boss(game: HyakkiGame, id: StringName, seconds: float) -> float:
	for _k: int in roundi(seconds / STEP):
		_tick(game, 1)
		if game.bosses.has_boss(id):
			return GameClock.game_time
	return -1.0


## A Sombra só nasce no Kakuriyo, relativa à chegada: chegando cedo, no horário de "midboss2";
## chegando tarde, "after" s depois da chegada; sempre com o aviso WARN_LEAD s antes.
func _test_shadow_schedule(late: bool) -> void:
	var game := await _new_game()
	var rift := game.rift
	_to_kakuriyo(game, 530.0 if late else -1.0)
	var mid2 := RiftPortal.midboss2_of(rift.base_stage)
	var expected := maxf(float(mid2["t"]), rift.arrived_at + float(mid2["after"]))
	var tag := "sombra (%s)" % ("chegada tarde" if late else "chegada cedo")
	_check.call(rift.depth == RiftPortal.DEPTH_KAKURIYO and is_equal_approx(rift.next_boss_time(), expected)
			and (expected > float(mid2["t"])) == late,
			"%s: agendada para %.2f s (chegada %.2f)", [tag, expected, rift.arrived_at])
	_jump(game, expected - RiftPortal.WARN_LEAD - 0.5)
	_tick(game, roundi(0.4 / STEP))
	_check.call(not game.bosses.has_boss(mid2["id"]), "%s: nada antes do aviso", tag)
	_tick(game, roundi(0.3 / STEP))
	_check.call(_toast_is(game, "midboss2.warning") and not game.bosses.has_boss(mid2["id"]),
			"%s: aviso antes da entrada", tag)
	var entered := _tick_until_boss(game, StringName(mid2["id"]), RiftPortal.WARN_LEAD + 1.0)
	_check.call(entered >= expected and entered <= expected + STEP * 2.0, "%s: entra na hora (%.3f s)", [tag, entered])
	_tick(game, 2)
	_check.call(game.hud.boss_panel().seal_glyph == "影" and _toast_is(game, "midboss2.title"),
			"%s: painel com o selo 影 e o título da Sombra", tag)
	await _free(game)


## Quem fica no primeiro mapa não vê a Sombra nem o último chefe; o amanhecer vence sem a luta
## final, sem "realm" nem "tokoyo".
func _test_no_final_outside() -> void:
	var game := await _new_game()
	var results: Array[Dictionary] = []
	game.finished.connect(func(r: Dictionary) -> void: results.append(r))
	var events: Array = game.spawner.get("_events")
	var last := StringName(RiftPortal.final_boss_of(game.stage)["id"])
	var shadow := StringName(RiftPortal.midboss2_of(game.stage)["id"])
	var planned := events.filter(func(e: Dictionary) -> bool:
		return StringName(String(e.get("boss", ""))) in [last, shadow])
	_check.call(planned.is_empty(), "primeiro mapa: nem Sombra nem último chefe na agenda (%s)", [planned])
	_jump(game, 535.0)
	_tick(game, roundi(10.0 / STEP))
	_check.call(not game.bosses.has_boss(shadow), "primeiro mapa: a Sombra não vem")
	_jump(game, 595.0)
	_tick(game, roundi(10.0 / STEP))
	_check.call(not game.bosses.has_boss(last), "primeiro mapa: o chefe dos 10:00 não vem")
	GameClock.game_time = HyakkiGame.RUN_LENGTH - STEP * 2.0
	_tick(game, 4)
	_check.call(results.size() == 1 and bool(results[0]["victory"]) and not bool(results[0]["realm"])
			and not bool(results[0]["tokoyo"]) and not game.tracker.bosses.has(last),
			"primeiro mapa: amanhecer vence sem a luta final")
	await _free(game)


## A Sombra vencida deixa dois baús e o torii dourado: paleta de ouro, folhas douradas, zumbido
## grave, luz dourada e o aviso próprio; o portal do Guardião continua violeta.
func _test_golden_torii() -> void:
	var game := await _new_game()
	var rift := game.rift
	game.apply_scenario("portal2")
	_check.call(rift.depth == RiftPortal.DEPTH_KAKURIYO and rift.is_open() and rift.golden()
			and rift.portal_to == RiftPortal.DEPTH_TOKOYO and rift.midboss2_done,
			"torii dourado: aberto no Kakuriyo pela Sombra")
	_check.call(_chests(game).size() == 2, "torii dourado: dois baús de chefe (%d)", _chests(game).size())
	_check.call(rift.has_gold_art(), "torii dourado: folhas douradas feitas da arte do portal")
	var pick := rift.sprite_frame()
	_check.call(pick[0] != null and (pick[0] as Texture2D).resource_path == "",
			"torii dourado: vórtice com a folha dourada")
	_check.call(rift.hum_playing() and is_equal_approx(rift.hum_pitch(), RiftPortal.HUM_GOLD_PITCH),
			"torii dourado: zumbido mais grave")
	var lights := rift.collect_lights(rift.portal_pos, Vector2(200, 200))
	_check.call(lights.size() == 1 and lights[0][1] == RiftPortal.GOLD_LIGHT, "torii dourado: luz dourada para a lanterna")
	_check.call(rift.tones()["swirl"] == RiftPortal.GOLD_SWIRL and rift.tones()["arrow"] == RiftPortal.GOLD_ARROW,
			"torii dourado: vórtice e seta da HUD em ouro")
	_tick(game, roundi((RiftPortal.OPEN_TOAST_DELAY + 0.1) / STEP))
	_check.call(_toast_is(game, "portal2.opened"), "torii dourado: aviso próprio")
	rift.close_portal()
	rift.open_portal(game.player.sim_pos + Vector2(120, 0), RiftPortal.DEPTH_KAKURIYO)
	_check.call(not rift.golden() and rift.tones()["swirl"] == RiftPortal.SWIRL and is_equal_approx(rift.hum_pitch(), 1.0)
			and (rift.sprite_frame()[0] as Texture2D).resource_path == RiftPortal.SPRITE_OPEN,
			"portal do Guardião continua violeta")
	# Pelo caminho real: a Sombra vencida (on_boss_defeated) abre o torii dourado, sem o baú comum.
	rift.close_portal()
	game.pickups.items.clear()
	rift.midboss2_done = false
	game.on_boss_defeated(&"onikuma_kage", game.player.sim_pos + Vector2(90, 0))
	_check.call(rift.golden() and rift.is_open() and rift.midboss2_done and _chests(game).size() == 2
			and game.tracker.bosses.has(&"onikuma_kage"), "torii dourado: a Sombra vencida abre o torii e conta")
	await _free(game)


## A travessia do torii dourado: título do Tokoyo, nível 2, bioma "<fase>_toko", limites do bloco,
## semente própria, guardiã na origem, aviso e música do Tokoyo.
func _test_tokoyo_crossing() -> void:
	var game := await _new_game("bamboo")
	var rift := game.rift
	game.apply_scenario("tokoyo")
	var kakuriyo_seed := rift.realm_seed
	var toko: Dictionary = rift.base_stage["tokoyo"]
	_check.call(rift.depth == RiftPortal.DEPTH_KAKURIYO and rift.is_open() and rift.golden(),
			"tokoyo: torii dourado sob a guardiã no Kakuriyo")
	_tick(game, 1)
	var card := game.hud.realm_card()
	_check.call(rift.crossing() and card.active and card.gold and card.kanji == String(toko["kanji"])
			and card.glyphs() == "常世"
			and card.title == TranslationServer.translate("realm3.bamboo.name")
			and card.caption == TranslationServer.translate("realm3.caption"),
			"tokoyo: título dourado do Tokoyo (%s)", card.kanji)
	_check.call(rift.snapshot()["depth"] == RiftPortal.DEPTH_TOKOYO, "tokoyo: travessia salva vai para o destino")
	rift.finish_crossing_now()
	_check.call(rift.depth == RiftPortal.DEPTH_TOKOYO and rift.in_realm and rift.reached and rift.reached_tokoyo
			and game.tracker.tokoyo_reached and game.tracker.realm_reached, "tokoyo: chegou ao nível 2")
	_check.call(game.stage["biome"] == "bamboo_toko" and game.world.biome == TerrainArt.biome("bamboo_toko"),
			"tokoyo: bioma bamboo_toko")
	var b: Array = toko["bounds"]
	_check.call(game.world.bounds == Vector2(float(b[0]), float(b[1])), "tokoyo: limites do bloco (%s)", game.world.bounds)
	_check.call(game.world.seed_value == rift.tokoyo_seed and rift.tokoyo_seed != kakuriyo_seed
			and rift.tokoyo_seed == absi(hash([kakuriyo_seed, "tokoyo"])) | 1, "tokoyo: semente própria")
	_check.call(game.player.sim_pos == Vector2.ZERO and not game.world.overlaps_solid(Vector2.ZERO, Player.RADIUS),
			"tokoyo: guardiã na origem livre")
	_check.call(_toast_is(game, "realm3.entered") and AudioManager.music_id() == "tokoyo"
			and not GameClock.paused and not rift.is_open(), "tokoyo: aviso de chegada, música do Tokoyo e relógio de volta")
	await _free(game)


## O último chefe só nasce no Tokoyo, em max(t, chegada + FINAL_AFTER), com o aviso antes e o
## diálogo dele; vencido, deixa o baú de chefe e o amanhecer registra o Tokoyo.
func _test_final_schedule(late: bool) -> void:
	var game := await _new_game()
	var rift := game.rift
	var results: Array[Dictionary] = []
	game.finished.connect(func(r: Dictionary) -> void: results.append(r))
	_to_tokoyo(game, 640.0 if late else -1.0)
	var last: Dictionary = RiftPortal.final_boss_of(rift.base_stage)
	var id := StringName(last["id"])
	var expected := maxf(float(last["t"]), rift.arrived_at + Spawner.FINAL_AFTER)
	var tag := "último chefe (%s)" % ("chegada tarde" if late else "chegada cedo")
	_check.call(is_equal_approx(rift.next_boss_time(), expected) and (expected > float(last["t"])) == late,
			"%s: agendado para %.2f s", [tag, expected])
	if not late:
		_tick(game, roundi(2.0 / STEP))
		_check.call(game.enemies.count_common == 0, "%s: respiro na chegada", tag)
	_jump(game, expected - Spawner.FINAL_WARN - 0.5)
	_tick(game, roundi(0.4 / STEP))
	_check.call(not game.bosses.has_boss(id), "%s: nada antes do aviso", tag)
	_tick(game, roundi(0.3 / STEP))
	_check.call(_toast_is(game, "final.awakens") and not game.bosses.has_boss(id), "%s: aviso antes da entrada", tag)
	var entered := _tick_until_boss(game, id, Spawner.FINAL_WARN + 1.0)
	_check.call(entered >= expected and entered <= expected + STEP * 2.0, "%s: entra na hora (%.3f s)", [tag, entered])
	_tick(game, 3)
	var panel := game.hud.boss_panel()
	_check.call(panel.visible and panel.title == TranslationServer.translate("boss.%s.name" % id),
			"%s: entrada com o painel (depois do diálogo)", tag)
	if late:
		await _free(game)
		return
	for boss: Dictionary in game.bosses.bosses:
		if StringName(boss["id"]) == id:
			game.deal_damage(game.weapons[0].id, int(boss["index"]), 1.0e9, Vector2.RIGHT, 0.0)
	_tick(game, 2)
	var boss_chests := _chests(game).filter(func(c: Dictionary) -> bool: return bool(c.get("boss", false)))
	_check.call(rift.final_done and game.tracker.bosses.has(id) and boss_chests.size() == 1 and not rift.is_open(),
			"%s: vencido, um baú de chefe e nenhum portal", tag)
	GameClock.game_time = HyakkiGame.RUN_LENGTH - STEP * 2.0
	_tick(game, 4)
	_check.call(results.size() == 1 and bool(results[0]["victory"]) and bool(results[0]["realm"])
			and bool(results[0]["tokoyo"]),
			"%s: amanhecer no Tokoyo é vitória com \"tokoyo\"", tag)
	await _free(game)


## Partida suspensa em cada nível: Kakuriyo (com a chegada), Sombra em campo, torii dourado
## aberto, Tokoyo, último chefe em campo e um snapshot antigo (só "in_realm").
func _test_tokoyo_snapshots() -> void:
	# Kakuriyo: a agenda da Sombra volta igual (chegada salva).
	var game := await _new_game()
	_to_kakuriyo(game, 500.0)
	var shadow_at := game.rift.next_boss_time()
	var snap: Dictionary = JSON.parse_string(JSON.stringify(game.snapshot()))
	await _free(game)
	var again := await _new_game()
	again.restore_snapshot(snap)
	_check.call(again.rift.depth == RiftPortal.DEPTH_KAKURIYO and is_equal_approx(again.rift.next_boss_time(), shadow_at)
			and again.world.biome == TerrainArt.biome("village_ura"),
			"retomada: Kakuriyo com a agenda da Sombra (%.2f s)", shadow_at)
	await _free(again)
	# Sombra em campo (já nasceu e não foi vencida): volta a ser chamada.
	game = await _new_game()
	_to_kakuriyo(game)
	_jump(game, game.rift.next_boss_time() + 5.0)
	snap = JSON.parse_string(JSON.stringify(game.snapshot()))
	await _free(game)
	again = await _new_game()
	again.restore_snapshot(snap)
	_check.call(again.bosses.has_boss(&"onikuma_kage") and again.rift.depth == RiftPortal.DEPTH_KAKURIYO,
			"retomada: Sombra em campo é chamada de novo")
	await _free(again)
	# Torii dourado aberto no Kakuriyo.
	game = await _new_game()
	game.apply_scenario("portal2")
	var portal := game.rift.portal_pos
	game.rift.portal_age = 7.5
	snap = JSON.parse_string(JSON.stringify(game.snapshot()))
	await _free(game)
	again = await _new_game()
	again.restore_snapshot(snap)
	_check.call(again.rift.is_open() and again.rift.golden() and again.rift.portal_pos.is_equal_approx(portal)
			and is_equal_approx(again.rift.portal_age, 7.5) and again.rift.depth == RiftPortal.DEPTH_KAKURIYO
			and again.rift.midboss2_done and not again.bosses.has_boss(&"onikuma_kage")
			and is_equal_approx(again.rift.hum_pitch(), RiftPortal.HUM_GOLD_PITCH),
			"retomada: torii dourado aberto no mesmo lugar, sem a Sombra")
	await _free(again)
	# Tokoyo: nível, semente, bioma e agenda do último chefe.
	game = await _new_game()
	_to_tokoyo(game)
	var seed_toko := game.rift.tokoyo_seed
	var final_at := game.rift.next_boss_time()
	snap = JSON.parse_string(JSON.stringify(game.snapshot()))
	await _free(game)
	_check.call(int(snap["realm"]["depth"]) == RiftPortal.DEPTH_TOKOYO and bool(snap["tracker"]["tokoyo_reached"]),
			"retomada: snapshot do Tokoyo")
	again = await _new_game()
	again.restore_snapshot(snap)
	_check.call(again.rift.depth == RiftPortal.DEPTH_TOKOYO and again.world.seed_value == seed_toko
			and again.world.biome == TerrainArt.biome("village_toko") and again.world.bounds == Vector2(1200, 1200)
			and again.tracker.tokoyo_reached and is_equal_approx(again.rift.next_boss_time(), final_at),
			"retomada: volta ao Tokoyo com a mesma semente e a mesma agenda")
	await _free(again)
	# Último chefe em campo.
	game = await _new_game()
	_to_tokoyo(game)
	_jump(game, game.rift.next_boss_time() + 5.0)
	snap = JSON.parse_string(JSON.stringify(game.snapshot()))
	await _free(game)
	again = await _new_game()
	again.restore_snapshot(snap)
	_check.call(again.bosses.has_boss(&"kappa_elder") and again.rift.depth == RiftPortal.DEPTH_TOKOYO,
			"retomada: último chefe em campo é chamado de novo")
	await _free(again)
	# Snapshot antigo (antes do Tokoyo): "in_realm" sem "depth" vira o Kakuriyo, chegada na hora salva.
	game = await _new_game()
	_jump(game, 520.0)
	snap = JSON.parse_string(JSON.stringify(game.snapshot()))
	await _free(game)
	snap["realm"] = {"in_realm": true, "midboss_done": true, "seed": 4242, "portal": [], "age": 0.0}
	snap["tracker"].erase("tokoyo_reached")
	again = await _new_game()
	again.restore_snapshot(snap)
	_check.call(again.rift.depth == RiftPortal.DEPTH_KAKURIYO and again.world.seed_value == 4242
			and again.world.biome == TerrainArt.biome("village_ura") and is_equal_approx(again.rift.arrived_at, 520.0)
			and is_equal_approx(again.rift.next_boss_time(), Spawner.shadow_time(again.rift.base_stage, 520.0))
			and not again.tracker.tokoyo_reached, "retomada: snapshot antigo com in_realm volta ao Kakuriyo")
	await _free(again)


func _test_tokoyo_scenarios() -> void:
	var game := await _new_game("yomi")
	game.apply_scenario("midboss2")
	var shadow := game.rift.next_boss_time()
	_check.call(game.rift.depth == RiftPortal.DEPTH_KAKURIYO
			and is_equal_approx(GameClock.game_time, shadow - RiftPortal.WARN_LEAD - 1.0),
			"cenário midboss2: no Kakuriyo, antes do aviso")
	_tick(game, roundi((RiftPortal.WARN_LEAD + 1.5) / STEP))
	_check.call(game.bosses.has_boss(&"yomi_hebi_kage"), "cenário midboss2: a Sombra entra no Kakuriyo do Yomi")
	await _free(game)
	game = await _new_game("secret")
	game.apply_scenario("portal2")
	_check.call(game.rift.is_open() and game.rift.golden() and _chests(game).size() == 2,
			"cenário portal2: dois baús e o torii dourado")
	await _free(game)
	game = await _new_game("dunes")
	game.apply_scenario("tokoyo")
	_tick(game, 1)
	_check.call(game.rift.crossing() and game.rift.golden(), "cenário tokoyo: a travessia começa no próximo passo")
	game.rift.finish_crossing_now()
	_check.call(game.rift.depth == RiftPortal.DEPTH_TOKOYO and game.stage["biome"] == "dunes_toko",
			"cenário tokoyo: no Tokoyo das Dunas")
	await _free(game)


## O bot (vida dos Guardiões baixa, como em _midboss_kill; as esperas até cada chefe puladas)
## vence o Guardião, anda até o portal violeta, vence a Sombra no Kakuriyo, anda até o torii
## dourado e enfrenta o último chefe no Tokoyo.
func _test_bot_two_portals() -> void:
	var game := await _new_game("temple")
	game._bot = true
	game.apply_scenario("midboss")
	var rift := game.rift
	var last := StringName(RiftPortal.final_boss_of(rift.base_stage)["id"])
	var hit := false
	var ticks := 0
	while not hit and ticks < 60 * 240:
		for boss: Dictionary in game.bosses.bosses:
			if RiftPortal.is_midboss(StringName(boss["id"])):
				var i := int(boss["index"])
				game.enemies.hp[i] = minf(game.enemies.hp[i], 60.0)
		# Sem chefe nem portal, a espera até o próximo chefe do nível é pulada.
		var wait := rift.next_boss_time() - RiftPortal.WARN_LEAD - 1.0
		if game.bosses.active_count() == 0 and not rift.is_open() and wait < INF and GameClock.game_time < wait:
			_jump(game, wait)
		_tick(game, 1)
		ticks += 1
		for boss: Dictionary in game.bosses.bosses:
			var i := int(boss["index"])
			if StringName(boss["id"]) == last and rift.depth == RiftPortal.DEPTH_TOKOYO:
				hit = game.enemies.hp[i] < game.enemies.max_hp[i]
	_check.call(rift.reached and rift.midboss_done and rift.midboss2_done,
			"bot: venceu os dois Guardiões e passou pelo Kakuriyo")
	_check.call(rift.depth == RiftPortal.DEPTH_TOKOYO and rift.reached_tokoyo, "bot: chegou ao Tokoyo pelo torii dourado")
	_check.call(hit, "bot: enfrenta o último chefe no Tokoyo (%.1f s de partida)", (ticks * STEP))
	await _free(game)
