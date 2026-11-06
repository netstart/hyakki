class_name AltarFx
extends RefCounted
## Efeitos de um momento dos Altares do Selo e dos poderes dos Elites (só desenho e som): chamados
## pela simulação (AltarSystem, EliteAffixes) no passo em que a coisa acontece, sem tocar no
## game.rng (o acaso aqui é próprio) e sem mudar a partida. Respeita o nível gráfico (FxLayer.wfx:
## menos raios e partículas na Baixa, distorção e aberração só na Alta) e "reduzir clarões".

## Cores: selo (azul pálido das runas), ouro do selo vencido e o branco do estouro.
const SEAL := Color(0.62, 0.82, 1.0)
const GOLD := Color(1.0, 0.84, 0.36)
const FLASH := Color(1.0, 0.98, 0.92)
const SKY_HEIGHT := 170.0
## Volume dos sons ambientes (raios decorativos e runas) e o intervalo mínimo entre trovões soltos.
const AMBIENT_DB := -14.0
const AMBIENT_GAP_MS := 260
## Lampejo e som do golpe no escudo do Diamante: no máximo um a cada SHIELD_HIT_GAP_MS (a horda
## inteira batendo não vira um borrão nem um zumbido).
const SHIELD_HIT_GAP_MS := 120

var game: HyakkiGame
## Lampejos de golpe no escudo mostrados (testes do limite).
var shield_hits_shown: int = 0

var _look := RandomNumberGenerator.new()
var _last_ambient_ms: int = -10000
var _last_shield_ms: int = -10000


func _init(p_game: HyakkiGame = null) -> void:
	game = p_game
	_look.randomize()


static func _sfx(id: String, pitch: float = 1.0, jitter: float = 0.0, db: float = 0.0) -> void:
	AudioManager.play(id, pitch, jitter, db)


func _fx() -> FxLayer:
	return game.fx if game != null else null


# --- Altar ---------------------------------------------------------------------------------

## Runa `k` (0..3) acendeu no anel: clarão, faíscas e o sino subindo de tom.
func rune_lit(at: Vector2, k: int) -> void:
	var fx := _fx()
	if fx == null:
		return
	fx.flash(at, 12.0, Color(SEAL, 0.9), 0.18)
	fx.motes(at, SEAL.lerp(Color.WHITE, 0.4), [2, 4, 6][FxLayer.wfx], 4.0, 26.0)
	fx.add_ring(at, 9.0, Color(SEAL, 0.9), 0.3, 1.0)
	_sfx("alt_rune_%d" % clampi(k, 0, 3), 1.0, 0.0, -4.0)


## Raio decorativo em volta do altar (a partir de 50 %): cai do céu num ponto a 30–70 px.
func ambient_bolt(center: Vector2) -> void:
	var fx := _fx()
	if fx == null:
		return
	var at := center + Vector2.from_angle(_look.randf() * TAU) * _look.randf_range(30.0, 70.0)
	fx.lightning_bolt(at + Vector2(_look.randf_range(-24.0, 24.0), -SKY_HEIGHT * 0.8), at, SEAL, 1.0,
			1, FxLayer.BOLT_LIFE * 0.8)
	fx.flash(at, 10.0, Color(SEAL, 0.7), 0.1)
	fx.sparks(at, Vector2.UP, SEAL.lerp(Color.WHITE, 0.5), [1, 3, 5][FxLayer.wfx], 80.0, 1.2, 0.16)
	var now := Time.get_ticks_msec()
	if now - _last_ambient_ms > AMBIENT_GAP_MS:
		_last_ambient_ms = now
		_sfx("alt_thunder", 1.3, 0.1, AMBIENT_DB)


## O selo estoura: clarão branco, anel de choque com distorção, estilhaços de ofuda, coluna de luz
## que cresce, vento que puxa para o centro, aberração, trovão grave, tremida média, vibração e
## hit-stop (sem o clarão da tela inteira: ele apagava o próprio efeito).
func seal_break(at: Vector2) -> void:
	var fx := _fx()
	if fx == null:
		return
	var core := at + Vector2(0, -10)
	fx.flash(core, 60.0, Color(FLASH, 1.0), 0.35)
	fx.shockwave(at, 92.0, Color(SEAL.lerp(Color.WHITE, 0.4), 1.0), 1.4, 0.5)
	fx.add_ring(at, 60.0, Color(0.05, 0.03, 0.08, 0.6), 0.4, 4.0)
	fx.paper_burst(core, [8, 14, 22][FxLayer.wfx], 110.0)
	fx.light_pillar(at, SEAL, 190.0, 40.0, AltarSystem.BREAK_TIME - 0.1)
	fx.gather(core, 70.0, SEAL.lerp(Color.WHITE, 0.3), [6, 14, 24][FxLayer.wfx], 0.45)
	fx.sparks(core, Vector2.ZERO, FLASH, [6, 12, 20][FxLayer.wfx], 170.0, PI, 0.3)
	fx.chroma_pulse(0.7, 0.22)
	fx.hitstop(0.08)
	game.shake(2.2 * FxLayer.shake_mult)
	Settings.vibrate(60)
	_sfx("alt_break", 1.0, 0.04, 0.0)
	_sfx("alt_thunder", 0.7, 0.05, -2.0)


## Raio grosso do céu no altar (a sequência do estouro): `k`-ésimo, alternando os lados.
func sky_bolt(at: Vector2, k: int) -> void:
	var fx := _fx()
	if fx == null:
		return
	# Baixa: 3 dos 5 raios (pula os de índice ímpar a partir do 3º).
	if FxLayer.wfx == 0 and k % 2 == 1:
		return
	var side := -1.0 if k % 2 == 0 else 1.0
	var hit := at + Vector2(_look.randf_range(-8.0, 8.0), _look.randf_range(-6.0, 4.0))
	var top := hit + Vector2(side * _look.randf_range(10.0, 34.0), -SKY_HEIGHT)
	fx.lightning_bolt(top, hit, SEAL.lerp(Color.WHITE, 0.25), 3.0, 3)
	fx.flash(hit, 26.0, Color(SEAL, 0.95), 0.14)
	fx.sparks(hit, Vector2.UP, FLASH, [3, 7, 12][FxLayer.wfx], 150.0, 1.4, 0.22)
	fx.add_ring(hit, 22.0, Color(SEAL, 0.9), 0.25, 2.0)
	fx.play_anim("thunder", hit - Vector2(0, 10), 1.6, 0.0, SEAL.lerp(Color.WHITE, 0.5), 18.0, false, true)
	game.shake(1.2 * FxLayer.shake_mult)
	_sfx("alt_thunder", _look.randf_range(0.85, 1.1), 0.0, -3.0)


## A silhueta do Elite sobe do chão: pedras, poeira e o som de subida.
func elite_rise(at: Vector2, size: float) -> void:
	var fx := _fx()
	if fx == null:
		return
	fx.play_anim("rock_burst" if fx.has_anim("rock_burst") else "rock_spike", at, 0.9 + 0.3 * size)
	fx.dust(at, 6.0, Color(0.7, 0.62, 0.5, 0.9), [5, 9, 14][FxLayer.wfx], 55.0)
	fx.add_ring(at, 26.0 * size, Color(0.75, 0.66, 0.52, 0.8), 0.35, 2.0)
	game.enemies.fx.stomp(at, 1.6 * size)
	game.shake(1.5 * FxLayer.shake_mult)
	_sfx("alt_elite_rise", 1.0, 0.03, -1.0)


## Rugido final: explosão de ar (anéis na cor do afixo e distorção), aberração, tremida forte,
## vibração e hit-stop; o rugido com o tom do tamanho do bicho.
func elite_roar(at: Vector2, color: Color, size: float) -> void:
	var fx := _fx()
	if fx == null:
		return
	var core := at + Vector2(0, -8.0 * size)
	fx.shockwave(at, AltarSystem.BLAST_RADIUS + 20.0, color.lerp(Color.WHITE, 0.3), 1.8, 0.55)
	fx.add_ring(at, AltarSystem.BLAST_RADIUS * 0.6, Color(color, 0.9), 0.4, 3.0)
	fx.flash(core, 46.0, Color(color.lerp(Color.WHITE, 0.5), 0.9), 0.25)
	fx.sparks(core, Vector2.ZERO, color.lerp(Color.WHITE, 0.4), [8, 16, 28][FxLayer.wfx], 200.0, PI, 0.35)
	fx.dust(at, 10.0, Color(0.75, 0.68, 0.55, 0.9), [6, 12, 18][FxLayer.wfx], 90.0)
	fx.chroma_pulse(1.2, 0.3)
	fx.hitstop(0.06)
	game.shake(3.0 * FxLayer.shake_mult)
	Settings.vibrate(120)
	_sfx("alt_elite_roar", clampf(1.25 - 0.25 * size, 0.7, 1.2), 0.03, 0.0)
	_sfx("e_roar_%d" % _look.randi_range(0, 2), clampf(1.1 - 0.2 * size, 0.6, 1.1), 0.05, -8.0)


## Emboscada: um raio e fumaça em cada ponto do anel (os primeiros, conforme o nível gráfico).
func ambush(center: Vector2, points: Array[Vector2]) -> void:
	var fx := _fx()
	if fx == null:
		return
	var bolts: int = [4, 7, 10][FxLayer.wfx]
	for k: int in points.size():
		var at := points[k]
		if k < bolts:
			fx.lightning_bolt(at + Vector2(_look.randf_range(-16.0, 16.0), -SKY_HEIGHT * 0.9), at, SEAL, 2.0, 1)
			fx.flash(at, 14.0, Color(SEAL, 0.85), 0.12)
		fx.play_anim("smoke", at, 1.0)
	fx.add_ring(center, AltarSystem.AMBUSH_RING + 14.0, Color(1.0, 0.35, 0.3, 0.9), 0.45, 2.0)
	game.shake(2.0 * FxLayer.shake_mult)
	_sfx("alt_ambush", 1.0, 0.03, 0.0)
	_sfx("alt_thunder", 0.9, 0.05, -4.0)


## Morte do Elite: clarão, explosão grande, anel duplo, estilhaços dourados, coluna de luz curta,
## explosão + sino de vitória, tremida, vibração e hit-stop.
func elite_death(at: Vector2, color: Color, size: float) -> void:
	var fx := _fx()
	if fx == null:
		return
	var core := at + Vector2(0, -8.0 * size)
	fx.flash(core, 70.0, Color(FLASH, 1.0), 0.3)
	if fx.has_anim("explosion_big"):
		fx.play_anim("explosion_big", core, 0.6 + 0.1 * size, 0.0, Color.WHITE, 20.0)
	else:
		fx.play_anim("explosion", core, 2.0 + 0.4 * size)
	fx.shockwave(at, 110.0, Color(GOLD, 1.0), 1.6, 0.55)
	fx.add_ring(at, 70.0, Color(color, 0.95), 0.5, 3.0)
	fx.add_ring(at, 40.0, Color(FLASH, 0.9), 0.3, 2.0)
	fx.sparks(core, Vector2.ZERO, GOLD, [10, 22, 36][FxLayer.wfx], 230.0, PI, 0.45)
	fx.motes(core, GOLD, [4, 12, 22][FxLayer.wfx], 12.0, 50.0)
	fx.paper_burst(core, [4, 8, 12][FxLayer.wfx], 120.0)
	fx.light_pillar(at, GOLD, 150.0, 22.0, 0.7)
	fx.chroma_pulse(0.9, 0.25)
	fx.hitstop(0.07)
	game.enemies.fx.soul_rain(core, [4, 8, 14][FxLayer.wfx])
	game.shake(3.0 * FxLayer.shake_mult)
	Settings.vibrate(140)
	_sfx("alt_elite_death", 1.0, 0.03, 0.0)
	_sfx("alt_explosion", 0.9, 0.05, -2.0)
	_sfx("j_temple_bell", 1.1, 0.0, -4.0)


## O altar do Elite vencido: nuvem dourada subindo e um anel de ouro.
func altar_vanquished(at: Vector2) -> void:
	var fx := _fx()
	if fx == null:
		return
	fx.motes(at + Vector2(0, -12), GOLD, [4, 10, 18][FxLayer.wfx], 10.0, 30.0)
	fx.embers(at + Vector2(0, -8), GOLD, [3, 6, 10][FxLayer.wfx], 8.0)
	fx.add_ring(at, 40.0, Color(GOLD, 0.9), 0.6, 2.0)


# --- Poderes dos Elites --------------------------------------------------------------------

## O poder `id` começou: um lampejo na cor do afixo no Elite (o jogador lê quem fez).
func affix_cast(id: StringName, at: Vector2) -> void:
	var fx := _fx()
	if fx == null:
		return
	var color := EliteAffixes.color_of(id)
	var core := at + Vector2(0, -10)
	fx.flash(core, 18.0, Color(color, 0.85), 0.16)
	match id:
		&"raijin":
			fx.sparks(core, Vector2.UP, color, [2, 5, 8][FxLayer.wfx], 120.0, 0.6, 0.2)
			_sfx("n_magic_3", 1.2, 0.05, -4.0)
		&"kitsunebi":
			fx.embers(core, color, [2, 4, 6][FxLayer.wfx], 5.0)
			_sfx("fireball", 1.1, 0.08, -5.0)
		&"kagero":
			fx.motes(core, color, [2, 5, 8][FxLayer.wfx], 6.0, 20.0)
			_sfx("n_magic_5", 1.3, 0.05, -5.0)
		&"iwa":
			fx.dust(at, 6.0, Color(0.72, 0.62, 0.5, 0.9), [3, 6, 10][FxLayer.wfx], 30.0)
			_sfx("n_alert_2", 0.8, 0.03, -4.0)
		&"kasumi":
			fx.play_anim("smoke", at, 2.0)
			fx.play_anim("smoke_circular", at, 1.4)
			_sfx("n_magic_5", 0.8, 0.05, -4.0)
		&"kaze":
			fx.dust(at, 4.0, Color(color, 0.8), [3, 6, 10][FxLayer.wfx], 40.0)
			_sfx("alt_telegraph", 1.0, 0.03, -3.0)


## Trovão: o raio do céu cai no fim de cada aviso.
func raijin_strike(at: Vector2) -> void:
	var fx := _fx()
	if fx == null:
		return
	var color := EliteAffixes.color_of(&"raijin")
	fx.lightning_bolt(at + Vector2(_look.randf_range(-20.0, 20.0), -SKY_HEIGHT), at, color, 3.0, 2)
	fx.flash(at, 24.0, Color(color, 0.95), 0.14)
	fx.sparks(at, Vector2.UP, color.lerp(Color.WHITE, 0.5), [3, 6, 10][FxLayer.wfx], 140.0, 1.3, 0.2)
	if fx.has_anim("impact_1"):
		fx.play_anim("impact_1", at - Vector2(0, 4), 0.32, 0.0, color.lerp(Color.WHITE, 0.5), 8.0, false, true)
	_sfx("alt_thunder", _look.randf_range(1.0, 1.2), 0.0, -4.0)


## Miragem: estalo onde estava e onde reaparece (fumaça, faíscas e um risco entre os dois).
func kagero_blink(from: Vector2, to: Vector2) -> void:
	var fx := _fx()
	if fx == null:
		return
	var color := EliteAffixes.color_of(&"kagero")
	for at: Vector2 in [from, to]:
		fx.play_anim("smoke_circular", at, 1.0)
		fx.flash(at + Vector2(0, -8), 20.0, Color(color, 0.9), 0.14)
		fx.sparks(at + Vector2(0, -8), Vector2.ZERO, color, [3, 6, 9][FxLayer.wfx], 110.0, PI, 0.2)
	if FxLayer.wfx > 0:
		fx.lightning_bolt(from + Vector2(0, -8), to + Vector2(0, -8), color, 1.0, 0, 0.12)
	if fx.has_anim("cut_double"):
		fx.play_anim("cut_double", to + Vector2(0, -8), 0.8, 0.0, color.lerp(Color.WHITE, 0.4), 22.0, false, true)
	_sfx("n_magic_5", 1.5, 0.05, -2.0)


## Vento: a investida sai (rajada atrás, poeira e o assobio).
func kaze_dash(at: Vector2, dir: Vector2) -> void:
	var fx := _fx()
	if fx == null:
		return
	var color := EliteAffixes.color_of(&"kaze")
	fx.sparks(at, -dir, color, [4, 8, 12][FxLayer.wfx], 160.0, 0.5, 0.25)
	fx.dust(at, 4.0, Color(0.75, 0.7, 0.6, 0.85), [3, 6, 9][FxLayer.wfx], 60.0)
	if fx.has_anim("cut_double"):
		fx.play_anim("cut_double", at + dir * 14.0, 0.9, dir.angle(), color, 20.0, false, true)
	_sfx("whoosh", 0.7, 0.05, -2.0)


## Rocha: o golpe no chão (pedras, poeira em anel, distorção).
func iwa_slam(at: Vector2) -> void:
	var fx := _fx()
	if fx == null:
		return
	var color := EliteAffixes.color_of(&"iwa")
	fx.play_anim("rock_burst" if fx.has_anim("rock_burst") else "rock_spike", at, 1.4)
	fx.shockwave(at, EliteAffixes.IWA_RADIUS, color.lerp(Color.WHITE, 0.2), 1.3, 0.45)
	fx.dust(at, EliteAffixes.IWA_RADIUS * 0.5, Color(0.72, 0.62, 0.5, 0.9), [6, 12, 20][FxLayer.wfx], 70.0)
	game.shake(2.6 * FxLayer.shake_mult)
	Settings.vibrate(50)
	_sfx("alt_explosion", 0.7, 0.05, -3.0)


func shield_up(at: Vector2) -> void:
	var fx := _fx()
	if fx == null:
		return
	var color := EliteAffixes.color_of(&"kongo")
	fx.add_ring(at + Vector2(0, -8), 18.0, Color(color, 0.9), 0.35, 2.0)
	fx.motes(at + Vector2(0, -8), color, [2, 5, 8][FxLayer.wfx], 10.0, 14.0)
	_sfx("a_diamond", 1.3, 0.05, -6.0)


func shield_hit(at: Vector2) -> void:
	var fx := _fx()
	var now := Time.get_ticks_msec()
	if fx == null or now - _last_shield_ms < SHIELD_HIT_GAP_MS:
		return
	_last_shield_ms = now
	shield_hits_shown += 1
	fx.flash(at + Vector2(0, -8), 10.0, Color(EliteAffixes.color_of(&"kongo"), 0.6), 0.06)
	_sfx("alt_shield_hit", 1.0, 0.1, -8.0)


## O escudo estilhaça: cacos claros para todo lado, anel e o som de vidro.
func shield_break(at: Vector2) -> void:
	var fx := _fx()
	if fx == null:
		return
	var color := EliteAffixes.color_of(&"kongo")
	var core := at + Vector2(0, -8)
	fx.sparks(core, Vector2.ZERO, color.lerp(Color.WHITE, 0.5), [6, 12, 20][FxLayer.wfx], 170.0, PI, 0.35)
	fx.burst(core, color, [4, 8, 12][FxLayer.wfx])
	fx.add_ring(core, 26.0, Color(color, 1.0), 0.3, 2.0)
	fx.flash(core, 24.0, Color(color, 0.9), 0.14)
	game.shake(1.2 * FxLayer.shake_mult)
	_sfx("alt_shield_break", 1.0, 0.05, 0.0)
