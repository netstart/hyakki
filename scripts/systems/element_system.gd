class_name ElementSystem
extends RefCounted
## Fogo, gelo e clones do lado da partida (.ai/06-fogo-gelo-clones.md):
## - registro das armas de fogo/gelo por id (Weapon._init / on_removed), consultado por
##   HyakkiGame.deal_damage em todo acerto (before_hit) para o Choque Térmico e os estados;
## - itens do chão: Jarro de Fogo ("inferno") e Caco do Espelho ("clones");
## - os clones do Caco (um Kage Bunshin fora das armas da guardiã), no passo e no desenho;
## - arsenal forçado dos testes e do determinismo (config "arsenal", --arsenal=a,b).
## - Estilhaçar e o vapor do Choque Térmico (o desenho e o som; a regra fica no EnemyManager).
## Os estados em si (arrays, tiques, congelar, Choque Térmico) ficam no EnemyManager.

## Jarro de Fogo: Queimadura de INFERNO_DPS (× atributo "burn") em tudo o que está na tela.
const INFERNO_DPS := 8.0
## Caco do Espelho: clones do Kage Bunshin nível 1, dano + MIRROR_DAMAGE_PER_LEVEL por nível.
const MIRROR_CLONES := 3
const MIRROR_DAMAGE_PER_LEVEL := 0.1
## Fontes de dano dos itens (registro de dano por arma e cor do impacto).
const FIRE_JAR := &"fire_jar"
const MIRROR_SHARD := &"mirror_shard"
const FIRE_JAR_STYLE := {"fx": {"color": "#ff7a3a", "hot": "#ffe0b0"}, "sfx": {"impact": "hit_fire"}}
const MIRROR_STYLE := {"fx": {"color": "#9a7cff", "hot": "#e8e0ff"}, "sfx": {"impact": "hit_blade"}}

var game: HyakkiGame
## > 0 desliga element_hit/apply_status (estilhaços: o dano sai sem os estados da arma).
var mute: int = 0
## Clones do Caco do Espelho (criado no 1º caco da partida).
var item_clones: KageBunshin

var _weapons: Dictionary = {}


func _init(p_game: HyakkiGame) -> void:
	game = p_game


## A arma mais nova com o id vale (evoluir troca a instância; a velha sai em on_removed).
func register(weapon: Weapon) -> void:
	_weapons[weapon.id] = weapon


func unregister(weapon: Weapon) -> void:
	if _weapons.get(weapon.id) == weapon:
		_weapons.erase(weapon.id)


## Antes de cada dano (HyakkiGame.deal_damage): anota quem bateu (EnemyManager.dying_killer) e
## devolve a arma de fogo/gelo do golpe, ou null (`skip`: contínuo ou prop; desligado; sem elemento).
func before_hit(weapon_id: StringName, skip: bool) -> Weapon:
	game.enemies.hit_by = weapon_id
	if skip or mute > 0:
		return null
	return _weapons.get(weapon_id) as Weapon


## Começo da partida (depois da arma da guardiã): zera os clones do Caco e põe o arsenal forçado.
func start(cfg: Dictionary) -> void:
	mute = 0
	item_clones = null
	add_arsenal(cfg.get("arsenal", []))


## Armas extras desde o começo, no nível máximo (testes E2E e o determinismo do run_checks).
func add_arsenal(ids: Array) -> void:
	for raw_id: Variant in ids:
		var id := StringName(String(raw_id))
		if id == &"" or game.has_weapon(id) or DB.weapon(id).is_empty():
			continue
		game.add_weapon(id)
		var weapon := game.get_weapon(id)
		while weapon != null and weapon.level < weapon.max_level:
			weapon.level_up()


func step(dt: float) -> void:
	if item_clones != null:
		item_clones.step(dt)


func draw(canvas: CanvasItem) -> void:
	if item_clones != null:
		item_clones.draw(canvas)


## Jarro de Fogo: tudo o que está na tela (chefes também) queima por `seconds`. Devolve quantos.
func inferno(seconds: float) -> int:
	var fx := game.fx
	fx.register_style(FIRE_JAR, FIRE_JAR_STYLE)
	var enemies := game.enemies
	var half := game.view_size() * 0.5 + Vector2(20, 20)
	var me := game.player.sim_pos
	var count := 0
	for i: int in range(EnemyManager.CAPACITY):
		if enemies.alive[i] == 0 or enemies.is_prop(i):
			continue
		var d := enemies.pos[i] - me
		if absf(d.x) <= half.x and absf(d.y) <= half.y and enemies.burn_one(i, INFERNO_DPS, seconds, FIRE_JAR):
			count += 1
	fx.add_ring(me, half.x, Color(1.0, 0.55, 0.2))
	fx.embers(me, Color(1.0, 0.6, 0.25), [6, 14, 24][FxLayer.wfx], half.y * 0.5)
	game.hud.flash_screen(Color(1.0, 0.6, 0.3))
	AudioManager.play("powerup", 0.8)
	game.hud.toast(tr("item.fire_jar.toast"))
	return count


## Caco do Espelho: MIRROR_CLONES clones de sombra por `seconds` (até KageBunshin.MAX_CLONES).
func mirror(seconds: float) -> int:
	if item_clones == null:
		item_clones = KageBunshin.new(game, &"kage_bunshin")
		item_clones.source_id = MIRROR_SHARD
		item_clones.auto_fire = false
		game.fx.register_style(MIRROR_SHARD, MIRROR_STYLE)
	item_clones.damage_scale = 1.0 + MIRROR_DAMAGE_PER_LEVEL * (game.level - 1)
	var made := item_clones.summon(MIRROR_CLONES, seconds)
	AudioManager.play("magic1", 0.8)
	game.hud.toast(tr("item.mirror_shard.toast"))
	return made


## Estilhaçar (Sopro da Yuki-onna e Espelho de Gelo): estilhaços em EnemyManager.SHATTER_RADIUS em
## volta de `at` (dano `damage`, creditado a `src`, sem os estados da arma) e SHATTER_CHILL pilha de
## frio em quem sobrar, no teto de reações em cadeia do passo. Devolve quantos acertou.
func shatter(at: Vector2, src: StringName, damage: float) -> int:
	var enemies := game.enemies
	if not enemies.take_cascade():
		return 0
	var list: Array[int] = []
	enemies.query_circle(at, EnemyManager.SHATTER_RADIUS, list)
	mute += 1
	for j: int in list:
		if enemies.alive[j] == 1:
			game.deal_damage(src, j, damage, (enemies.pos[j] - at).normalized(), 40.0)
	mute -= 1
	for j: int in list:
		enemies.chill_one(j, EnemyManager.SHATTER_CHILL)
	if game.fx and enemies.view_rect.has_point(at):
		game.fx.play_anim("ice", at, 1.3, 0.0, Color(0.85, 0.97, 1.0), 26.0, false, true)
		game.fx.sparks(at, Vector2.ZERO, Color(0.8, 0.95, 1.0), [3, 6, 10][FxLayer.wfx], 110.0, PI, 0.22)
		game.fx.flash(at, EnemyManager.SHATTER_RADIUS, Color(0.7, 0.9, 1.0, 0.7), 0.1)
	WeaponSfx.play("shatter")
	return list.size()


## Nuvem de vapor branca do Choque Térmico (só desenho e som).
func steam(at: Vector2) -> void:
	if game.fx == null:
		return
	if game.enemies.view_rect.has_point(at):
		game.fx.play_anim("smoke", at, 0.8, 0.0, Color(1.0, 1.0, 1.0, 0.85), 18.0)
		game.fx.flash(at, 14.0, Color(1.0, 1.0, 1.0, 0.7), 0.1)
		game.fx.motes(at, Color(0.95, 0.97, 1.0), 2 + 2 * FxLayer.wfx, 6.0, 24.0)
	WeaponSfx.play("thermal_shock")
