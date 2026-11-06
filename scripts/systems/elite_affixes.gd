class_name EliteAffixes
extends RefCounted
## Afixos dos Elites dos Altares do Selo (.ai/05-altares-e-elites.md): poderes que reaproveitam a
## biblioteca dos chefes (AreaEffects.telegraph/hazard_pool, EnemyShotManager.spawn) e o desenho
## que só os Elites com afixos têm (aura na cor do 1º afixo, barra de vida com os kanji, bolha
## do escudo, rastro da investida, brasão).
##
## Simulação: step(dt) no passo fixo, só game.rng, sem alocar por inimigo. Cada Elite é um
## registro guardado pelo índice do EnemyManager e conferido pelo `uid` daquele nascimento, então
## uma vaga reusada (o Elite sumiu na travessia ou no amanhecer) nunca herda os poderes.
## Desenho: draw_under/draw_over/draw_glow, chamados pelas camadas do AltarSystem (só retângulos,
## texturas e Stroke).

## Afixos na ordem das cores do ícone (assets/art/altar/affix_icons.png, 8 quadros de 14x14).
const IDS: Array[StringName] = [&"raijin", &"kitsunebi", &"kagero", &"iwa", &"kasumi", &"kongo", &"yomi", &"kaze"]
const KANJI := {&"raijin": "雷", &"kitsunebi": "狐", &"kagero": "陽", &"iwa": "岩", &"kasumi": "霞",
		&"kongo": "剛", &"yomi": "冥", &"kaze": "風"}
const COLORS := {&"raijin": Color("ffd84a"), &"kitsunebi": Color("ff7ad1"), &"kagero": Color("ff9a4a"),
		&"iwa": Color("c8925a"), &"kasumi": Color("b4c4e0"), &"kongo": Color("8ff0ff"),
		&"yomi": Color("a46cff"), &"kaze": Color("7dffb0")}
## Pares que não saem juntos: dois poderes que tomam o controle do corpo ao mesmo tempo.
const FORBIDDEN: Array = [[&"kagero", &"kaze"], [&"iwa", &"kaze"]]
## Quantos afixos: 1 antes de TWO_AFFIX_T s, 2 depois; Lua Vermelha HIGH_MOON+ soma 1 (até MAX).
const TWO_AFFIX_T := 480.0
const HIGH_MOON := 3
const MAX_AFFIXES := 3
## Vida: × (1 + HP_PER_AFFIX × (afixos − 1)); velocidade e resistência a empurrão.
const HP_PER_AFFIX := 0.35
const SPEED_BONUS := 1.1
const KNOCK_RESIST := 0.6
## Primeiro poder depois de soltar (para o surgimento respirar) e a recarga quando o alvo está longe.
const FIRST_CAST := 1.6
const RETRY := 0.5

## 雷 Trovão: marca RAIJIN_MARKS círculos perto da guardiã; raio em cada um depois do aviso.
const RAIJIN_EVERY := 4.0
const RAIJIN_MARKS := 3
const RAIJIN_WINDUP := 0.9
const RAIJIN_RADIUS := 18.0
const RAIJIN_SPREAD := 42.0
const RAIJIN_DAMAGE := 9.0
const RAIJIN_RANGE := 260.0
## 狐 Raposa: leque de fogos-fátuos.
const FOX_EVERY := 3.0
const FOX_COUNT := 5
const FOX_SPREAD := 1.0
const FOX_SPEED := 82.0
const FOX_DAMAGE := 6.0
const FOX_HOMING := 0.35
const FOX_LIFE := 4.0
const FOX_RANGE := 230.0
## 陽 Miragem: some num estalo e reaparece atrás da guardiã (aviso no destino).
const KAGERO_EVERY := 5.0
const KAGERO_WINDUP := 0.7
const KAGERO_BEHIND := 34.0
const KAGERO_RADIUS := 16.0
const KAGERO_DAMAGE := 7.0
const KAGERO_RANGE := 260.0
## 岩 Rocha: para, ergue-se e bate no chão (onda com aviso em anel). Raio e aviso cabem na fuga do
## guardião mais lento (Goro, 54 px/s) saindo do centro: 54 × (1,2 − 0,08) ≈ 60 > 56 + 4.
const IWA_EVERY := 6.0
const IWA_WINDUP := 1.2
const IWA_RADIUS := 56.0
const IWA_DAMAGE := 12.0
const IWA_RANGE := 120.0
const IWA_PUSH := 140.0
## 霞 Névoa: lacaios com fumaça (teto de vivos).
const KASUMI_EVERY := 7.0
const KASUMI_COUNT := 4
const KASUMI_CAP := 8
const KASUMI_RING := 26.0
## 剛 Diamante: escudo de SHIELD_FRACTION da vida máxima; volta KONGO_REGEN s depois de quebrar.
const SHIELD_FRACTION := 0.3
const KONGO_REGEN := 8.0
## 冥 Yomi: poças de miasma pelo caminho, soltas no rastro (YOMI_BEHIND px atrás do Elite, do
## lado oposto ao guardião) e com aviso de YOMI_WINDUP s antes de ferir.
const YOMI_BEHIND := 12.0
const YOMI_GAP := 18.0
const YOMI_EVERY := 0.5
const YOMI_RADIUS := 15.0
const YOMI_LIFE := 3.5
const YOMI_DAMAGE := 3.0
const YOMI_SLOW := 0.6
const YOMI_WINDUP := 0.6
## 風 Vento: investida em linha com aviso.
const KAZE_EVERY := 4.0
const KAZE_WINDUP := 0.7
const KAZE_SPEED := 240.0
const KAZE_TIME := 0.55
const KAZE_MIN := 50.0
const KAZE_RANGE := 210.0
const KAZE_WIDTH := 7.0

## Desenho: barra de vida sobre a cabeça, ícones e brasão (assets/art/altar/).
const BAR_WIDTH := 30.0
const BAR_HEIGHT := 3.0
const ICONS_PATH := "res://assets/art/altar/affix_icons.png"
const ICON := 14
const CREST_PATH := "res://assets/art/altar/elite_crest.png"
## Surgimento visto pelo EnemyLook: escala com sobre-salto e silhueta na cor do afixo.
const RISE_TIME := 0.6

var game: HyakkiGame
## índice do EnemyManager -> registro (uid, id, afixos, recargas, estado do poder).
var records: Dictionary = {}

var _near: Array[int] = []
var _icons: Texture2D
var _crest: Texture2D
var _soft: Texture2D


func _init(p_game: HyakkiGame = null) -> void:
	game = p_game
	_icons = _texture(ICONS_PATH)
	_crest = _texture(CREST_PATH)


static func _texture(path: String) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


func reset() -> void:
	records.clear()


# --- Regras puras --------------------------------------------------------------------------

## Quantos afixos um Elite que surge em `time` s ganha (Lua Vermelha `moon`).
static func affix_count(time: float, moon: int) -> int:
	var n := 1 if time < TWO_AFFIX_T else 2
	if moon >= HIGH_MOON:
		n += 1
	return mini(n, MAX_AFFIXES)


## `count` afixos sem repetir e sem par proibido, sorteados com `rng` (game.rng na partida).
static func roll(rng: RandomNumberGenerator, count: int) -> Array[StringName]:
	var out: Array[StringName] = []
	var pool: Array[StringName] = IDS.duplicate()
	while out.size() < count and not pool.is_empty():
		var pick: StringName = pool.pop_at(rng.randi_range(0, pool.size() - 1))
		if allowed(out, pick):
			out.append(pick)
	return out


## `pick` pode entrar junto com `chosen` (nenhum par proibido, sem repetir).
static func allowed(chosen: Array[StringName], pick: StringName) -> bool:
	if chosen.has(pick):
		return false
	for pair: Array in FORBIDDEN:
		if pair.has(pick) and chosen.any(func(a: StringName) -> bool: return a != pick and pair.has(a)):
			return false
	return true


## Vida do Elite com `count` afixos, a partir da vida de Elite comum.
static func hp_mult(count: int) -> float:
	return 1.0 + HP_PER_AFFIX * maxi(0, count - 1)


static func color_of(id: StringName) -> Color:
	return COLORS.get(id, Color.WHITE)


static func kanji_of(id: StringName) -> String:
	return String(KANJI.get(id, ""))


## Nome mostrado: "<Inimigo> <afixo>" pelo modelo do idioma, e os outros afixos depois de " · ".
static func elite_name(enemy_id: StringName, affixes: Array) -> String:
	var enemy := TranslationServer.translate("enemy.%s.name" % enemy_id)
	if affixes.is_empty():
		return enemy
	var name := TranslationServer.translate("elite.name").format(
			{"enemy": enemy, "affix": affix_name(StringName(affixes[0]))})
	for k: int in range(1, affixes.size()):
		name += " · " + affix_name(StringName(affixes[k]))
	return name


static func affix_name(id: StringName) -> String:
	match id:
		&"raijin":
			return TranslationServer.translate("elite.affix.raijin")
		&"kitsunebi":
			return TranslationServer.translate("elite.affix.kitsunebi")
		&"kagero":
			return TranslationServer.translate("elite.affix.kagero")
		&"iwa":
			return TranslationServer.translate("elite.affix.iwa")
		&"kasumi":
			return TranslationServer.translate("elite.affix.kasumi")
		&"kongo":
			return TranslationServer.translate("elite.affix.kongo")
		&"yomi":
			return TranslationServer.translate("elite.affix.yomi")
		&"kaze":
			return TranslationServer.translate("elite.affix.kaze")
	return String(id)


# --- Registro ------------------------------------------------------------------------------

## Dá os afixos ao Elite `i` (já criado com elite=true): vida, velocidade, resistência e escudo.
## `rescale` false na retomada (a vida salva já tem o multiplicador).
func attach(i: int, affixes: Array[StringName], altar_key: String, rescale: bool = true) -> Dictionary:
	var enemies := game.enemies
	if rescale:
		var mult := hp_mult(affixes.size())
		enemies.max_hp[i] *= mult
		enemies.hp[i] = enemies.max_hp[i]
		enemies.speed[i] *= SPEED_BONUS
	enemies.resist[i] = maxf(enemies.resist[i], KNOCK_RESIST)
	var timers := {}
	for k: int in affixes.size():
		timers[affixes[k]] = FIRST_CAST + 0.7 * k
	var rec := {"uid": enemies.uid[i], "id": enemies.type_ids[enemies.kind[i]], "affixes": affixes,
			"altar": altar_key, "timers": timers, "busy": &"", "t": 0.0, "dir": Vector2.ZERO,
			"line": [], "minions": [], "last_pool": enemies.pos[i], "shield_max": 0.0, "shield_cd": 0.0,
			"emerge": -1.0, "fade": 1.0, "broke_at": -100.0}
	if affixes.has(&"kongo"):
		rec["shield_max"] = enemies.max_hp[i] * SHIELD_FRACTION
		enemies.shield[i] = rec["shield_max"]
	records[i] = rec
	return rec


## Registro vivo do Elite `i` ({} se não for um Elite com afixos ou se a vaga foi reusada).
func record(i: int) -> Dictionary:
	var rec: Dictionary = records.get(i, {})
	if rec.is_empty() or game.enemies.uid[i] != int(rec["uid"]):
		return {}
	return rec


func has(i: int) -> bool:
	return not record(i).is_empty() and game.enemies.alive[i] == 1


func count() -> int:
	return records.size()


## Morreu: devolve o registro (e o tira da lista) para o AltarSystem fazer a explosão e o saque.
func take_dead(i: int) -> Dictionary:
	var rec := record(i)
	if not rec.is_empty():
		records.erase(i)
		_release_body(i)
	return rec


## Fim do controle do corpo pelos poderes (selo, investida, salto).
func _release_body(i: int) -> void:
	game.enemies.controlled[i] = 0


# --- Passo ---------------------------------------------------------------------------------

func step(dt: float) -> void:
	var enemies := game.enemies
	for i: int in records.keys():
		var rec: Dictionary = records[i]
		if enemies.alive[i] == 0 or enemies.uid[i] != int(rec["uid"]):
			records.erase(i)
			continue
		_step_kongo(i, rec, dt)
		if enemies.sealed[i] == 1 or float(rec["emerge"]) >= 0.0:
			continue
		# Ampulheta e atordoamento seguram tudo: recargas e o poder em curso (o Vento não investe
		# congelado, a Miragem não termina o sumiço).
		var held := enemies.freeze_time > 0.0 or enemies.stun[i] > 0.0
		if StringName(rec["busy"]) != &"":
			if held:
				enemies.vel[i] = Vector2.ZERO
			else:
				_step_busy(i, rec, dt)
			continue
		if held:
			continue
		_step_yomi(i, rec, dt)
		var timers: Dictionary = rec["timers"]
		for id: StringName in rec["affixes"]:
			if id == &"kongo" or id == &"yomi":
				continue
			timers[id] = float(timers[id]) - dt
			if float(timers[id]) > 0.0:
				continue
			timers[id] = _cast(i, rec, id)
			if StringName(rec["busy"]) != &"":
				break


## Solta o poder `id` e devolve a próxima recarga (RETRY se o alvo estava fora de alcance).
func _cast(i: int, rec: Dictionary, id: StringName) -> float:
	var enemies := game.enemies
	var me: Vector2 = enemies.pos[i]
	var target := game.player.sim_pos
	var dist := me.distance_to(target)
	var mult := game.enemy_damage_mult()
	var src := StringName(rec["id"])
	match id:
		&"raijin":
			if dist > RAIJIN_RANGE:
				return RETRY
			for k: int in RAIJIN_MARKS:
				var at := target
				if k > 0:
					at += Vector2.from_angle(game.rng.randf() * TAU) * game.rng.randf_range(RAIJIN_SPREAD * 0.5, RAIJIN_SPREAD)
				at = game.world.clamp_to_bounds(at)
				game.areas.telegraph(at, RAIJIN_RADIUS, RAIJIN_WINDUP + 0.12 * k, RAIJIN_DAMAGE * mult,
						_on_raijin_strike, color_of(&"raijin"), src)
			game.altars.visuals.affix_cast(id, me)
			return RAIJIN_EVERY
		&"kitsunebi":
			if dist > FOX_RANGE:
				return RETRY
			var aim := (target - me).normalized()
			for k: int in FOX_COUNT:
				var t := float(k) / (FOX_COUNT - 1) - 0.5
				game.enemy_shots.spawn(me, aim.rotated(t * FOX_SPREAD) * FOX_SPEED, FOX_DAMAGE * mult, "fox_fire",
						FOX_LIFE, FOX_HOMING, src)
			game.altars.visuals.affix_cast(id, me)
			return FOX_EVERY
		&"kagero":
			if dist > KAGERO_RANGE:
				return RETRY
			var facing := game.player.facing if game.player.facing != Vector2.ZERO else (target - me).normalized()
			var dest := game.world.free_point(game.world.clamp_to_bounds(target - facing.normalized() * KAGERO_BEHIND),
					enemies.radius[i])
			rec["busy"] = &"kagero"
			rec["t"] = KAGERO_WINDUP
			rec["dir"] = dest
			enemies.controlled[i] = 1
			enemies.vel[i] = Vector2.ZERO
			game.areas.telegraph(dest, KAGERO_RADIUS, KAGERO_WINDUP, KAGERO_DAMAGE * mult, Callable(),
					color_of(&"kagero"), src)
			game.altars.visuals.affix_cast(id, me)
			return KAGERO_EVERY
		&"iwa":
			if dist > IWA_RANGE:
				return RETRY
			rec["busy"] = &"iwa"
			rec["t"] = IWA_WINDUP
			enemies.controlled[i] = 1
			enemies.vel[i] = Vector2.ZERO
			game.areas.telegraph(me, IWA_RADIUS, IWA_WINDUP, IWA_DAMAGE * mult, _on_iwa_slam.bind(i, enemies.uid[i]),
					color_of(&"iwa"), src)
			game.altars.visuals.affix_cast(id, me)
			return IWA_EVERY
		&"kasumi":
			var alive_minions := _alive_minions(rec)
			if alive_minions >= KASUMI_CAP or dist > FOX_RANGE * 1.4:
				return RETRY
			var minion := game.altars.minion_type()
			var minions: Array = rec["minions"]
			for k: int in mini(KASUMI_COUNT, KASUMI_CAP - alive_minions):
				var at := game.world.clamp_to_bounds(me + Vector2.from_angle(TAU * k / KASUMI_COUNT + 0.4) * KASUMI_RING)
				var j := enemies.spawn(minion, at, game.enemy_hp_mult(), mult)
				if j >= 0:
					minions.append([j, enemies.uid[j]])
			game.altars.visuals.affix_cast(id, me)
			return KASUMI_EVERY
		&"kaze":
			if dist < KAZE_MIN or dist > KAZE_RANGE:
				return RETRY
			var dir := (target - me).normalized()
			rec["busy"] = &"kaze"
			rec["t"] = KAZE_WINDUP
			rec["dir"] = dir
			rec["line"] = [me, me + dir * KAZE_SPEED * KAZE_TIME]
			enemies.controlled[i] = 1
			enemies.vel[i] = Vector2.ZERO
			game.altars.visuals.affix_cast(id, me)
			return KAZE_EVERY
	return RETRY


## Poderes que seguram o corpo: Miragem (sumindo), Rocha (erguendo) e Vento (preparando e investindo).
func _step_busy(i: int, rec: Dictionary, dt: float) -> void:
	var enemies := game.enemies
	rec["t"] = float(rec["t"]) - dt
	var left := float(rec["t"])
	match StringName(rec["busy"]):
		&"kagero":
			rec["fade"] = clampf(left / KAGERO_WINDUP, 0.0, 1.0)
			if left <= 0.0:
				var from: Vector2 = enemies.pos[i]
				var dest: Vector2 = rec["dir"]
				enemies.pos[i] = dest
				enemies.prev[i] = dest
				rec["fade"] = 1.0
				_end_busy(i, rec)
				game.altars.visuals.kagero_blink(from, dest)
		&"iwa":
			if left <= 0.0:
				_end_busy(i, rec)
		&"kaze":
			var dir: Vector2 = rec["dir"]
			if StringName(rec.get("phase", &"")) != &"dash":
				enemies.facing[i] = SpriteSheet.dir_from_vector(dir, enemies.facing[i])
				if left <= 0.0:
					rec["phase"] = &"dash"
					rec["t"] = KAZE_TIME
					game.altars.visuals.kaze_dash(enemies.pos[i], dir)
				return
			# Investida: o corpo é controlado (o EnemyManager ainda fere por contato a cada passo).
			var v := dir * KAZE_SPEED * enemies.speed_mult
			enemies.vel[i] = v
			enemies.pos[i] = game.world.clamp_to_bounds(game.world.resolve(enemies.pos[i] + v * dt, enemies.radius[i] * 0.8))
			if left <= 0.0:
				rec["phase"] = &""
				rec["line"] = []
				enemies.vel[i] = dir * 40.0
				_end_busy(i, rec)


func _end_busy(i: int, rec: Dictionary) -> void:
	rec["busy"] = &""
	rec["t"] = 0.0
	_release_body(i)


## Raio do Trovão no fim de cada aviso (o dano já saiu do aviso): só o efeito.
func _on_raijin_strike(at: Vector2) -> void:
	game.altars.visuals.raijin_strike(at)


## Rocha: o golpe no chão (o dano já saiu do aviso); a guardiã perto é jogada para fora.
func _on_iwa_slam(at: Vector2, i: int, uid: int) -> void:
	# O Elite morreu (ou a vaga foi reusada) durante o aviso: o dano do aviso já saiu, sem o resto.
	if game.enemies.alive[i] == 0 or game.enemies.uid[i] != uid:
		return
	var player := game.player
	var away := player.sim_pos - at
	if away.length() < IWA_RADIUS * 1.25 and player.is_alive:
		player.velocity += (away.normalized() if away.length() > 0.01 else Vector2.RIGHT) * IWA_PUSH
	game.enemies.push_from(at, IWA_RADIUS * 0.8, IWA_PUSH)
	game.enemies.vel[i] = Vector2.ZERO
	game.altars.visuals.iwa_slam(at)


## Poças de miasma: uma a cada YOMI_GAP px andados (no máximo a cada YOMI_EVERY s).
func _step_yomi(i: int, rec: Dictionary, dt: float) -> void:
	if not (rec["affixes"] as Array).has(&"yomi"):
		return
	var timers: Dictionary = rec["timers"]
	timers[&"yomi"] = float(timers[&"yomi"]) - dt
	var at: Vector2 = game.enemies.pos[i]
	if float(timers[&"yomi"]) > 0.0 or at.distance_to(rec["last_pool"]) < YOMI_GAP:
		return
	timers[&"yomi"] = YOMI_EVERY
	rec["last_pool"] = at
	var away := at - game.player.sim_pos
	var behind := at + (away.normalized() if away.length() > 0.01 else Vector2.DOWN) * YOMI_BEHIND
	game.areas.hazard_pool(game.world.clamp_to_bounds(behind), YOMI_RADIUS, YOMI_DAMAGE * game.enemy_damage_mult(),
			YOMI_LIFE, YOMI_SLOW, YOMI_WINDUP, StringName(rec["id"]))


## Escudo do Diamante: volta cheio KONGO_REGEN s depois de quebrar.
func _step_kongo(i: int, rec: Dictionary, dt: float) -> void:
	if float(rec["shield_max"]) <= 0.0 or game.enemies.shield[i] > 0.0:
		return
	rec["shield_cd"] = float(rec["shield_cd"]) - dt
	if float(rec["shield_cd"]) <= 0.0:
		game.enemies.shield[i] = float(rec["shield_max"])
		game.altars.visuals.shield_up(game.enemies.pos[i])


## O escudo do Elite `i` levou um golpe (e talvez quebrou): recarga e efeito.
func on_shield_hit(i: int, broke: bool) -> void:
	var rec := record(i)
	if rec.is_empty():
		return
	if broke:
		rec["shield_cd"] = KONGO_REGEN
		rec["broke_at"] = GameClock.game_time
		game.altars.visuals.shield_break(game.enemies.pos[i])
	else:
		game.altars.visuals.shield_hit(game.enemies.pos[i])


func _alive_minions(rec: Dictionary) -> int:
	var minions: Array = rec["minions"]
	var enemies := game.enemies
	for k: int in range(minions.size() - 1, -1, -1):
		var pair: Array = minions[k]
		if enemies.alive[int(pair[0])] == 0 or enemies.uid[int(pair[0])] != int(pair[1]):
			minions.remove_at(k)
	return minions.size()


## Linha do hash: Elites vivos, afixos, poder em curso e escudos (determinismo).
func hash_tag() -> String:
	var parts: PackedStringArray = []
	for i: int in records:
		var rec: Dictionary = records[i]
		var names: PackedStringArray = []
		for id: StringName in rec["affixes"]:
			names.append(String(id))
		parts.append("%s:%s:%s:%.2f" % [rec["id"], ",".join(names), rec["busy"], game.enemies.shield[i]])
	parts.sort()
	return ";".join(parts)


# --- Partida suspensa ----------------------------------------------------------------------

## Elites vivos com afixos (inimigos não entram no snapshot: o AltarSystem os chama de volta).
func snapshot() -> Array:
	var out: Array = []
	var enemies := game.enemies
	for i: int in records:
		var rec: Dictionary = records[i]
		if enemies.alive[i] == 0 or enemies.uid[i] != int(rec["uid"]):
			continue
		out.append({"enemy": String(rec["id"]), "altar": String(rec["altar"]),
				"affixes": (rec["affixes"] as Array).map(func(a: StringName) -> String: return String(a)),
				"x": enemies.pos[i].x, "y": enemies.pos[i].y, "hp": enemies.hp[i], "max_hp": enemies.max_hp[i],
				"shield": enemies.shield[i], "sealed": enemies.sealed[i] == 1, "emerge": float(rec["emerge"]),
				"state": power_state(rec)})
	return out


## Estado dos poderes que a retomada precisa (JSON): recargas, poder em curso e o do escudo.
static func power_state(rec: Dictionary) -> Dictionary:
	var timers := {}
	for id: StringName in (rec["timers"] as Dictionary):
		timers[String(id)] = float(rec["timers"][id])
	var dir: Vector2 = rec["dir"]
	var line: Array = []
	for p: Vector2 in rec["line"]:
		line.append([p.x, p.y])
	return {"timers": timers, "busy": String(rec["busy"]), "t": float(rec["t"]), "dir": [dir.x, dir.y],
			"line": line, "phase": String(rec.get("phase", &"")), "fade": float(rec["fade"]),
			"shield_cd": float(rec["shield_cd"])}


## Volta o estado dos poderes salvo por power_state no Elite `i` (registro já criado por attach).
func load_power_state(i: int, rec: Dictionary, s: Dictionary) -> void:
	var timers: Dictionary = rec["timers"]
	for id: String in (s.get("timers", {}) as Dictionary):
		if timers.has(StringName(id)):
			timers[StringName(id)] = float(s["timers"][id])
	var dir: Array = s.get("dir", [0.0, 0.0])
	rec["dir"] = Vector2(float(dir[0]), float(dir[1]))
	var line: Array = []
	for p: Variant in s.get("line", []):
		line.append(Vector2(float(p[0]), float(p[1])))
	rec["line"] = line
	rec["busy"] = StringName(String(s.get("busy", "")))
	rec["t"] = float(s.get("t", 0.0))
	rec["phase"] = StringName(String(s.get("phase", "")))
	rec["fade"] = float(s.get("fade", 1.0))
	rec["shield_cd"] = float(s.get("shield_cd", 0.0))
	if StringName(rec["busy"]) != &"":
		game.enemies.controlled[i] = 1


# --- Desenho (só leitura) ------------------------------------------------------------------

## Escala, silhueta e transparência do corpo do Elite `i` agora: (escala, silhueta 0..1, alfa).
## Vector3(1, 0, 1) para quem não está surgindo nem sumindo. Lido pelo EnemyLook.
func body_look(i: int) -> Vector3:
	var rec := record(i)
	if rec.is_empty():
		return Vector3(1.0, 0.0, 1.0)
	var emerge := float(rec["emerge"])
	if emerge >= 0.0:
		var k := clampf(emerge / RISE_TIME, 0.0, 1.0)
		# Sobe do chão com sobre-salto (ease out back) e a silhueta na cor do afixo se desfaz.
		var c := 1.70158 * 1.4
		var back := 1.0 + (c + 1.0) * pow(k - 1.0, 3.0) + c * pow(k - 1.0, 2.0)
		return Vector3(maxf(0.05, back), 1.0 - k * k, 1.0)
	return Vector3(1.0, 0.0, float(rec["fade"]))


## Cor da silhueta do surgimento (pisca entre branco e a cor do 1º afixo).
func silhouette_color(i: int) -> Color:
	var rec := record(i)
	if rec.is_empty():
		return Color.WHITE
	var first := color_of(StringName((rec["affixes"] as Array)[0]))
	return Color.WHITE if int(GameClock.game_time * 20.0) % 2 == 0 else first


## Aura na cor do 1º afixo por baixo do corpo (camada aditiva do chão).
func draw_under(canvas: CanvasItem, detail: int) -> void:
	if _soft == null:
		_soft = EnemyFx.soft_texture()
	var enemies := game.enemies
	var time := GameClock.game_time
	var look := enemies.look
	for i: int in records:
		if not _visible(i):
			continue
		var rec: Dictionary = records[i]
		var color := color_of(StringName((rec["affixes"] as Array)[0]))
		var foot := look.foot_of(i)
		var s := look.body_scale(i) * body_look(i).x
		var pulse := 0.6 + 0.4 * sin(time * 6.0 + i)
		var r := 15.0 * s * (0.9 + 0.1 * pulse)
		canvas.draw_texture_rect(_soft, Rect2(foot - Vector2(r, r * 0.5), Vector2(r * 2.0, r)), false,
				Color(color, (0.45 if detail > 0 else 0.3) * pulse))
		if detail >= 2:
			canvas.draw_texture_rect(_soft, Rect2(foot - Vector2(r * 0.8, r * 1.9), Vector2(r * 1.6, r * 1.9)), false,
					Color(color, 0.16 * pulse))


## Por cima dos corpos: aviso da investida, bolha do escudo, brasão, barra de vida e kanji.
func draw_over(canvas: CanvasItem) -> void:
	var enemies := game.enemies
	var time := GameClock.game_time
	var look := enemies.look
	for i: int in records:
		if not _visible(i):
			continue
		var rec: Dictionary = records[i]
		var affixes: Array = rec["affixes"]
		var foot := look.foot_of(i)
		var bl := body_look(i)
		var s := look.body_scale(i) * bl.x
		var sheet: SpriteSheet = enemies.type_sheets[enemies.kind[i]]
		var top := foot.y - sheet.frame_size.y * s + 2.0
		if StringName(rec["busy"]) == &"kaze" and StringName(rec.get("phase", &"")) != &"dash":
			_draw_dash_warning(canvas, rec, time)
		if enemies.shield[i] > 0.0:
			_draw_bubble(canvas, foot + Vector2(0, -sheet.frame_size.y * s * 0.45), maxf(10.0, enemies.radius[i] * 1.6),
					time, i)
		if float(rec["emerge"]) >= 0.0 or bl.z < 0.5:
			continue
		var bar_y := roundf(top - 7.0)
		_draw_bar(canvas, Vector2(roundf(foot.x), bar_y), i, affixes)
		_draw_crest(canvas, Vector2(roundf(foot.x), bar_y - 9.0), affixes, time, i)


func _visible(i: int) -> bool:
	var enemies := game.enemies
	if enemies.alive[i] == 0 or enemies.uid[i] != int((records[i] as Dictionary)["uid"]):
		return false
	return enemies.view_rect.has_point(enemies.pos[i])


## Barra fina com borda escura, faixas na cor de cada afixo, escudo em branco por cima e as marcas.
func _draw_bar(canvas: CanvasItem, center: Vector2, i: int, affixes: Array) -> void:
	var enemies := game.enemies
	var w := BAR_WIDTH
	var rect := Rect2(center.x - w * 0.5, center.y, w, BAR_HEIGHT)
	canvas.draw_rect(rect.grow(1.0), Color(0.04, 0.02, 0.05, 0.9))
	canvas.draw_rect(rect, Color(0.25, 0.08, 0.1, 0.9))
	var fraction := clampf(enemies.hp[i] / maxf(enemies.max_hp[i], 1.0), 0.0, 1.0)
	var fill := roundf(w * fraction)
	var n := affixes.size()
	for k: int in n:
		var x0 := roundf(w * k / n)
		var x1 := minf(roundf(w * (k + 1) / n), fill)
		if x1 > x0:
			var c := color_of(StringName(affixes[k]))
			canvas.draw_rect(Rect2(rect.position.x + x0, rect.position.y, x1 - x0, BAR_HEIGHT), c)
			canvas.draw_rect(Rect2(rect.position.x + x0, rect.position.y, x1 - x0, 1.0), c.lightened(0.45))
	var shield := enemies.shield[i]
	if shield > 0.0:
		var sw := roundf(w * clampf(shield / maxf(enemies.max_hp[i], 1.0), 0.0, 1.0))
		canvas.draw_rect(Rect2(rect.position.x, rect.position.y - 2.0, sw, 1.0), Color(0.85, 1.0, 1.0, 0.95))
	# Marcas a cada quarto (lê o quanto falta como a barra de chefe).
	for q: int in range(1, 4):
		canvas.draw_rect(Rect2(rect.position.x + roundf(w * q / 4.0), rect.position.y, 1.0, BAR_HEIGHT),
				Color(0.0, 0.0, 0.0, 0.35))


## Brasão (assets/art/altar/elite_crest.png) e os ícones dos afixos lado a lado; sem a arte, pinos.
func _draw_crest(canvas: CanvasItem, center: Vector2, affixes: Array, time: float, i: int) -> void:
	var n := affixes.size()
	var step := 9.0
	var x0 := center.x - (n - 1) * step * 0.5
	var bob := roundf(sin(time * 3.0 + i) * 0.6)
	for k: int in n:
		var id := StringName(affixes[k])
		var at := Vector2(roundf(x0 + k * step), center.y + bob)
		if _icons != null:
			var frame := IDS.find(id)
			canvas.draw_texture_rect_region(_icons, Rect2(at - Vector2(4.0, 4.0), Vector2(8.0, 8.0)),
					Rect2(frame * ICON, 0, ICON, ICON))
		else:
			canvas.draw_rect(Rect2(at - Vector2(3, 3), Vector2(6, 6)), Color(0.05, 0.02, 0.05, 0.9))
			canvas.draw_rect(Rect2(at - Vector2(2, 2), Vector2(4, 4)), color_of(id))
	if _crest != null and n > 0:
		var cs := 12.0
		canvas.draw_texture_rect(_crest, Rect2(Vector2(roundf(center.x - cs * 0.5), center.y - cs - 3.0 + bob),
				Vector2(cs, cs)), false)


## Faixa do aviso da investida: pulsa e enche do corpo até a ponta conforme o tempo passa.
func _draw_dash_warning(canvas: CanvasItem, rec: Dictionary, time: float) -> void:
	var line: Array = rec["line"]
	if line.size() < 2:
		return
	var a: Vector2 = line[0]
	var b: Vector2 = line[1]
	var dir := (b - a).normalized()
	var side := dir.orthogonal() * KAZE_WIDTH
	var k := 1.0 - clampf(float(rec["t"]) / KAZE_WINDUP, 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(time * 30.0)
	var color := color_of(&"kaze")
	Stroke.convex(canvas, PackedVector2Array([a + side, b + side, b - side, a - side]),
			Color(0.9, 0.15, 0.1, 0.16 + 0.1 * pulse))
	var mid := a.lerp(b, k)
	Stroke.convex(canvas, PackedVector2Array([a + side * 0.6, mid + side * 0.6, mid - side * 0.6, a - side * 0.6]),
			Color(color, 0.35))
	Stroke.line(canvas, PackedVector2Array([a + side, b + side]), Color(1.0, 0.35, 0.25, 0.8), 1.0)
	Stroke.line(canvas, PackedVector2Array([a - side, b - side]), Color(1.0, 0.35, 0.25, 0.8), 1.0)
	var tip := b + dir * 6.0
	Stroke.convex(canvas, PackedVector2Array([tip, b + side * 1.3, b - side * 1.3]),
			Color(1.0, 0.4, 0.3, 0.6 + 0.3 * pulse))


## Bolha do Diamante: disco claro, aro com brilho que corre e lampejo quando recebe golpe.
func _draw_bubble(canvas: CanvasItem, center: Vector2, r: float, time: float, i: int) -> void:
	var color := color_of(&"kongo")
	var hit := clampf(game.enemies.flash[i] / 0.05, 0.0, 1.0)
	canvas.draw_circle(center, r, Color(color, 0.1 + 0.15 * hit))
	Stroke.arc(canvas, center, r, 0.0, TAU, 24, Color(color.lerp(Color.WHITE, 0.3), 0.55 + 0.4 * hit), 1.0)
	var spin := time * 2.2 + i
	Stroke.arc(canvas, center, r - 2.0, spin, spin + 1.1, 8, Color(1.0, 1.0, 1.0, 0.75), 1.0)
	Stroke.arc(canvas, center, r - 2.0, spin + PI, spin + PI + 0.5, 5, Color(1.0, 1.0, 1.0, 0.45), 1.0)
