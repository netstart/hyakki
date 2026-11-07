class_name Horokubiya
extends Weapon
## Hōroku-biya 焙烙火矢 / Kagutsuchi 迦具土 (.ai/06-fogo-gelo-clones.md): potes de barro com
## pólvora arremessados em arco (sombra no chão + pote girando) até um inimigo ao acaso num raio
## de RANGE px; explodem (dano em área, que queima pelo apply_status) e deixam o chão em brasa
## (AreaEffects.fire_pool) que reaplica a Queimadura enquanto dura. A evolução lança 3 por vez e,
## com "burn_spread", inimigo que morre queimando passa as chamas a quem estiver perto.
## O voo é simulação (passo fixo); o arco desenhado só lê o progresso.

const RANGE := 170.0
## Tempo de voo com "speed" 1 (o atributo de velocidade de projétil encurta).
const FLIGHT := 0.55
const ARC_HEIGHT := 26.0
const SPIN := 12.0
const MAX_POTS := 24
## Atraso de voo de cada pote da leva em relação ao anterior (fração do voo).
const POT_GAP := 0.15
const POT_TEXTURE := "res://assets/art/items/projectile/bomb.png"

## Potes no ar: {"from", "to", "t", "time"}.
var pots: Array[Dictionary] = []

var _tex: Texture2D


func _init(p_game: HyakkiGame, p_id: StringName) -> void:
	super(p_game, p_id)
	_tex = load(POT_TEXTURE) as Texture2D


func flight_time() -> float:
	return FLIGHT / maxf(0.2, proj_speed())


func fire(origin: Vector2) -> void:
	for k: int in range(amount()):
		var target := game.enemies.random_alive(origin, RANGE)
		var to := origin + Vector2.from_angle(game.rng.randf() * TAU) * game.rng.randf_range(30.0, 90.0)
		if target >= 0:
			to = game.enemies.pos[target]
		if pots.size() >= MAX_POTS:
			_explode(pots.pop_front()["to"])
		# Potes da mesma leva caem um pouco depois um do outro (POT_GAP), não todos no mesmo passo.
		pots.append({"from": origin, "to": to, "t": 0.0, "time": flight_time() * (1.0 + POT_GAP * k)})
	game.fx.muzzle(id, origin, game.player.facing)
	WeaponSfx.launch(self)


func step(dt: float) -> void:
	super(dt)
	for k: int in range(pots.size() - 1, -1, -1):
		var pot := pots[k]
		pot["t"] = float(pot["t"]) + dt
		if float(pot["t"]) >= float(pot["time"]):
			pots.remove_at(k)
			_explode(pot["to"])


## Explosão do pote: dano em área (queima pelo apply_status) e o chão em brasa.
func _explode(at: Vector2) -> void:
	var r := raw("radius") * area()
	game.areas.blast(id, at, r, damage(), knockback())
	game.areas.fire_pool(id, at, r, duration(), burn_dps(), raw("burn_time"))
	var fx := game.fx
	fx.play_anim("explosion", at, minf(2.4, r / 18.0), 0.0, Color(1.0, 0.78, 0.5))
	fx.flash(at, r * 1.2, Color(fx_color(), 0.8), 0.14)
	fx.embers(at, fx_color(), [2, 6, 10][FxLayer.wfx], r * 0.4)
	if FxLayer.wfx > 0:
		fx.play_anim("flame", at - Vector2(0, 6), minf(1.6, r / 24.0), 0.0, Color(fx_hot(), 0.9), 18.0, false, true)
	WeaponSfx.play("hachiman_blast", 1.25 if not is_evolved() else 1.0)
	game.shake(0.6 * FxLayer.shake_mult)


## Kagutsuchi: inimigo que morre queimando explode em chamas e queima quem está a "burn_spread" px.
func on_kill(at: Vector2, _j: int) -> void:
	var spread := float(flags.get("burn_spread", 0.0))
	if spread <= 0.0 or game.enemies.dying_burn() <= 0.0 or not game.enemies.take_cascade():
		return
	game.enemies.burn_circle(at, spread, burn_dps(), raw("burn_time"), id)
	if game.fx != null and game.enemies.view_rect.has_point(at):
		game.fx.play_anim("flame", at - Vector2(0, 5), 0.8, 0.0, Color(fx_hot(), 0.9), 22.0, false, true)
		game.fx.embers(at, fx_color(), 1 + FxLayer.wfx, spread * 0.3)


func on_removed() -> void:
	pots.clear()
	super()


## Troca de mundo: os potes no ar cairiam nas coordenadas do mundo velho (o chão em brasa já sai
## com o AreaEffects.reset do RiftPortal.clear_field).
func on_realm_change() -> void:
	pots.clear()


## Potes no ar: sombra no chão seguindo a reta e o pote no arco, girando, com pavio aceso. Em três
## passadas (sombras, potes, pavios): pote a pote, retângulo e textura se alternavam.
func draw(canvas: CanvasItem) -> void:
	if pots.is_empty() or _tex == null:
		return
	var lead := GameClock.alpha * GameClock.STEP
	var size := _tex.get_size()
	var spots := PackedVector2Array()
	for pot: Dictionary in pots:
		var u := clampf((float(pot["t"]) + lead) / maxf(float(pot["time"]), 0.001), 0.0, 1.0)
		var ground := (pot["from"] as Vector2).lerp(pot["to"], u)
		var lift := ARC_HEIGHT * 4.0 * u * (1.0 - u)
		var shadow := 1.0 - 0.5 * lift / ARC_HEIGHT
		canvas.draw_rect(Rect2((ground + Vector2(-3.0 * shadow, -1.0)).round(), Vector2(roundf(6.0 * shadow), 2)),
				Color(0.0, 0.0, 0.0, 0.3))
		spots.append((ground - Vector2(0.0, lift)).round())
	for k: int in range(pots.size()):
		canvas.draw_set_transform(spots[k], float(pots[k]["t"]) * SPIN, Vector2.ONE)
		canvas.draw_texture(_tex, -size * 0.5)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for k: int in range(pots.size()):
		var spark := spots[k] + Vector2.from_angle(float(pots[k]["t"]) * SPIN - PI * 0.5) * (size.y * 0.5)
		canvas.draw_rect(Rect2(spark.round(), Vector2(1, 1)), fx_hot())


func draw_glow(canvas: CanvasItem) -> void:
	var lead := GameClock.alpha * GameClock.STEP
	for pot: Dictionary in pots:
		var u := clampf((float(pot["t"]) + lead) / maxf(float(pot["time"]), 0.001), 0.0, 1.0)
		var at := (pot["from"] as Vector2).lerp(pot["to"], u) - Vector2(0.0, ARC_HEIGHT * 4.0 * u * (1.0 - u))
		FxLayer.draw_soft(canvas, at, 6.0, Color(fx_color(), 0.45))
