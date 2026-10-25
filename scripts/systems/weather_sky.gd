class_name WeatherSky
extends CanvasLayer
## Céu do clima em espaço de tela (CanvasLayer 4: acima do mundo, abaixo da escuridão da
## lanterna e da HUD): gradação da tempestade, névoa/véu de areia, o que cai (chuva em camadas
## inclinadas pelo vento, neve, areia, cinza, almas), o que o vento carrega (folhas, pétalas,
## brasas, poeira) e, numa camada própria acima da escuridão (7), o clarão dos relâmpagos.
##
## Tudo aqui é visual (RNG próprio, sem semente): nada afeta a simulação. As partículas vivem
## em arrays empacotados e cada camada é um único _draw (chuva: um draw_multiline por camada).
## O que fica perto do herói "anda" com a câmera (paralaxe), então a chuva parece estar no mundo.

const LAYER := 4
const FLASH_LAYER := 7
const LEAF_TEX := "res://assets/art/fx/particle/Leaf.png"
const PETAL_TEX := "res://assets/art/fx/particle/LeafPink.png"
const SNOW_TEX := "res://assets/art/fx/particle/Snow.png"
const FOG_TEX := "res://assets/art/fx/environment/Fog.png"
## Paralaxe por camada (fundo, meio, frente) e queda em px/s da chuva.
const PARALLAX := [0.75, 1.0, 1.2]
const RAIN_FALL := [250.0, 340.0, 460.0]
const RAIN_LEN := [7.0, 12.0, 20.0]
const SNOW_FALL := [14.0, 22.0, 34.0]
const ASH_FALL := [10.0, 16.0, 24.0]
const SPIRIT_FALL := [110.0, 150.0, 200.0]
const MARGIN := 40.0

var weather: WeatherSystem

var _grade: Node2D
var _back: Node2D
var _front: Node2D
var _flash_layer: CanvasLayer
var _flash_node: Node2D
var _grade_mat: CanvasItemMaterial
var _add_mat: CanvasItemMaterial
var _rng := RandomNumberGenerator.new()
var _view := Vector2(678, 305)
var _last_cam := Vector2.INF
var _time: float = 0.0
var _sim_t: float = 0.0
var _precip_kind: String = "rain"
var _extra_kind: String = ""

# Queda: posição, camada, variação (0..1) e y em que a gota toca o chão.
var _pos := PackedVector2Array()
var _layer := PackedInt32Array()
var _var := PackedFloat32Array()
var _land := PackedFloat32Array()
var _active: int = 0
var _layers: int = 3
# Vento: folhas/pétalas/brasas/poeira.
var _mote_pos := PackedVector2Array()
var _mote_var := PackedFloat32Array()
var _mote_active: int = 0
# Clarão: tempo desde o último relâmpago e o relâmpago (x, distância, semente).
var _flash_age: float = 99.0
var _flash_strike: Array = []
var _flash_count: int = 0
var _bolt := PackedVector2Array()
var _branch := PackedVector2Array()
var _fog_scroll: float = 0.0
var _tex: Dictionary = {}
var _quality: int = GfxQuality.HIGH
var _splashes_on: bool = true


func _ready() -> void:
	layer = LAYER
	_rng.randomize()
	_grade_mat = CanvasItemMaterial.new()
	_grade_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	_add_mat = CanvasItemMaterial.new()
	_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_grade = Node2D.new()
	_grade.material = _grade_mat
	_grade.draw.connect(_draw_grade)
	add_child(_grade)
	_back = Node2D.new()
	_back.draw.connect(_draw_back)
	add_child(_back)
	_front = Node2D.new()
	_front.draw.connect(_draw_front)
	add_child(_front)
	_flash_layer = CanvasLayer.new()
	_flash_layer.layer = FLASH_LAYER
	add_child(_flash_layer)
	_flash_node = Node2D.new()
	_flash_node.material = _add_mat
	_flash_node.draw.connect(_draw_flash)
	_flash_layer.add_child(_flash_node)
	for path: String in [LEAF_TEX, PETAL_TEX, SNOW_TEX, FOG_TEX]:
		_tex[path] = load(path) as Texture2D
	apply_quality()


## Orçamentos do nível atual (troca ao vivo): gotas, camadas e respingos.
func apply_quality() -> void:
	_quality = GfxQuality.level()
	_layers = int(GfxQuality.budget("weather_layers"))
	_splashes_on = bool(GfxQuality.budget("splashes"))
	var drops := int(GfxQuality.budget("weather_drops"))
	var motes := int(GfxQuality.budget("ambient_motes"))
	_pos.resize(drops)
	_layer.resize(drops)
	_var.resize(drops)
	_land.resize(drops)
	for i: int in range(drops):
		_respawn(i, true)
	_mote_pos.resize(motes)
	_mote_var.resize(motes)
	for i: int in range(motes):
		_mote_pos[i] = Vector2(_rng.randf() * _view.x, _rng.randf() * _view.y)
		_mote_var[i] = _rng.randf()


func reset() -> void:
	_flash_age = 99.0
	_flash_count = 0
	_last_cam = Vector2.INF


## Quantas partículas de queda existem (orçamento) e quantas estão ativas.
func drop_capacity() -> int:
	return _pos.size()


func active_drops() -> int:
	return _active


func layer_count() -> int:
	return _layers


func flash_count() -> int:
	return _flash_count


## Brilho atual do clarão 0..1 (já suavizado com "reduce_flashes").
func flash_level() -> float:
	return _flash_curve(_flash_age, _calm())


func _calm() -> bool:
	return bool(Settings.get_value("reduce_flashes"))


## Relâmpago agora: clarão (duplo, ou um só e suave com "reduce_flashes") e o raio no céu.
func flash(strike: Array) -> void:
	_flash_age = 0.0
	_flash_strike = strike
	_flash_count += 1
	_make_bolt(float(strike[1]) * _view.x, int(strike[3]))


static func _flash_curve(age: float, calm: bool) -> float:
	if calm:
		# Um só pulso lento e fraco: sem piscar.
		return 0.22 * sin(clampf(age / 0.9, 0.0, 1.0) * PI)
	if age < 0.07:
		return age / 0.07
	if age < 0.13:
		return lerpf(1.0, 0.25, (age - 0.07) / 0.06)
	if age < 0.19:
		return lerpf(0.25, 0.8, (age - 0.13) / 0.06)
	return maxf(0.0, 0.8 * exp(-(age - 0.19) * 5.5))


func _make_bolt(x: float, bolt_seed: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = bolt_seed
	_bolt.clear()
	_branch.clear()
	var p := Vector2(x, -4.0)
	var end_y := _view.y * r.randf_range(0.3, 0.55)
	var split := r.randi_range(3, 6)
	var k := 0
	while p.y < end_y:
		_bolt.append(p.round())
		p += Vector2(r.randf_range(-9.0, 9.0), r.randf_range(7.0, 14.0))
		k += 1
		if k == split:
			var q := p
			for _j: int in range(r.randi_range(3, 5)):
				_branch.append(q.round())
				q += Vector2(r.randf_range(2.0, 10.0) * (1.0 if r.randf() < 0.5 else -1.0), r.randf_range(5.0, 10.0))
			_branch.append(q.round())
	_bolt.append(p.round())


# --- Passo visual --------------------------------------------------------------------

func tick(dt: float, sim_t: float) -> void:
	var game := weather.game
	_view = game.view_size()
	_time += dt
	_sim_t = sim_t
	var profile := weather.profile()
	_precip_kind = String(profile.get("precip", "rain"))
	_extra_kind = String(profile.get("extra", ""))
	var cam := game.camera.get_screen_center_position() if game.camera != null else Vector2.ZERO
	var shift := Vector2.ZERO if _last_cam == Vector2.INF else cam - _last_cam
	if shift.length() > 200.0:
		shift = Vector2.ZERO
	_last_cam = cam
	var model := weather.model
	var precip := model.precip_at(sim_t)
	_active = int(round(_pos.size() * precip))
	var wind := model.wind_vector_at(sim_t)
	_step_drops(dt, shift, wind)
	_step_motes(dt, shift, wind, model.wind_strength_at(sim_t))
	_fog_scroll += dt * (6.0 + 60.0 * absf(wind.x))
	_flash_age += dt if dt > 0.0 else 0.0
	_grade.queue_redraw()
	_back.queue_redraw()
	_front.queue_redraw()
	_flash_node.queue_redraw()


func _velocity(i: int, wind: Vector2) -> Vector2:
	var lyr := _layer[i]
	var v := _var[i]
	match _precip_kind:
		"snow":
			return Vector2(wind.x * 90.0 + sin(_time * 1.7 + v * 20.0) * 10.0, SNOW_FALL[lyr] * (0.8 + 0.4 * v))
		"ash":
			return Vector2(wind.x * 70.0 + sin(_time * 1.3 + v * 17.0) * 8.0, ASH_FALL[lyr] * (0.8 + 0.4 * v))
		"sand":
			var dir := wind.normalized() if wind.length() > 0.01 else Vector2.RIGHT
			return dir * (260.0 + 260.0 * v) * (0.6 + 0.4 * PARALLAX[lyr]) + Vector2(0.0, 18.0 * (v - 0.5))
		"spirit":
			return Vector2(wind.x * 80.0, SPIRIT_FALL[lyr] * (0.85 + 0.3 * v))
	return Vector2(wind.x * 240.0 * (0.8 + 0.2 * lyr), RAIN_FALL[lyr] * (0.9 + 0.2 * v))


func _step_drops(dt: float, shift: Vector2, wind: Vector2) -> void:
	var w := _view.x + MARGIN * 2.0
	var h := _view.y + MARGIN * 2.0
	var ground := weather.ground()
	for i: int in range(_pos.size()):
		var p := _pos[i] - shift * float(PARALLAX[_layer[i]]) + _velocity(i, wind) * dt
		if _precip_kind in ["rain", "spirit"] and p.y >= _land[i]:
			if i < _active and _splashes_on and _layer[i] > 0 and ground != null:
				ground.add_drop_splash(_screen_to_world(Vector2(p.x, _land[i])), _layer[i] == 2)
			_respawn(i, false)
			continue
		p.x = fposmod(p.x + MARGIN, w) - MARGIN
		if p.y > _view.y + MARGIN or p.y < -MARGIN * 1.5:
			p.y = fposmod(p.y + MARGIN, h) - MARGIN
		_pos[i] = p


func _respawn(i: int, anywhere: bool) -> void:
	_layer[i] = _pick_layer()
	_var[i] = _rng.randf()
	var y := _rng.randf_range(-MARGIN, _view.y) if anywhere else -_rng.randf_range(4.0, MARGIN)
	_pos[i] = Vector2(_rng.randf_range(-MARGIN, _view.x + MARGIN), y)
	# Gotas da frente caem mais longe na tela (mais perto da câmera).
	_land[i] = _rng.randf_range(_view.y * 0.15, _view.y + 10.0) if _layer[i] > 0 else _rng.randf_range(
			_view.y * 0.05, _view.y * 0.8)
	if anywhere:
		_land[i] = maxf(_land[i], y + 8.0)


func _pick_layer() -> int:
	if _layers <= 1:
		return 1
	if _layers == 2:
		return 1 if _rng.randf() < 0.6 else 2
	var r := _rng.randf()
	return 0 if r < 0.45 else (1 if r < 0.8 else 2)


func _step_motes(dt: float, shift: Vector2, wind: Vector2, strength: float) -> void:
	var count := _mote_pos.size()
	match _extra_kind:
		"embers":
			_mote_active = count
		"dust":
			_mote_active = int(count * smoothstep(0.2, 0.8, strength))
		_:
			_mote_active = int(count * smoothstep(0.18, 0.75, strength))
	for i: int in range(count):
		var v := _mote_var[i]
		var vel := wind * (110.0 + 120.0 * v) + Vector2(0.0, 10.0 + sin(_time * 2.0 + v * 30.0) * 14.0)
		if _extra_kind == "embers":
			vel = wind * 40.0 + Vector2(sin(_time * 1.6 + v * 25.0) * 10.0, -14.0 - 16.0 * v)
		var p := _mote_pos[i] - shift * (0.8 + 0.4 * v) + vel * dt
		p.x = fposmod(p.x + MARGIN, _view.x + MARGIN * 2.0) - MARGIN
		p.y = fposmod(p.y + MARGIN, _view.y + MARGIN * 2.0) - MARGIN
		_mote_pos[i] = p


func _screen_to_world(p: Vector2) -> Vector2:
	var game := weather.game
	return game.get_viewport().get_canvas_transform().affine_inverse() * p


# --- Desenho -------------------------------------------------------------------------

## Gradação do céu (multiplicação): escurece e esfria na tempestade, alaranja na areia; o
## relâmpago clareia por um instante.
func _draw_grade() -> void:
	var model := weather.model
	if model == null:
		return
	var p := weather.profile()
	var dark := clampf(model.precip_at(_sim_t) * 0.9 + model.lightning_at(_sim_t) * 0.1, 0.0, 1.0)
	if _precip_kind in ["snow"]:
		dark *= 0.5
	var tint := Color.WHITE.lerp(Color(String(p.get("storm_grade", "#b8c4e6"))), dark)
	tint = tint.lerp(Color.WHITE, flash_level() * 0.6)
	if tint.is_equal_approx(Color.WHITE):
		return
	_grade.draw_rect(Rect2(Vector2.ZERO, _view), tint)


## Fundo: névoa/véu e a camada de trás e do meio da queda.
func _draw_back() -> void:
	var model := weather.model
	if model == null:
		return
	_draw_fog(model)
	_draw_precip(_back, [0, 1])


## Frente: camada da frente da queda e o que o vento carrega.
func _draw_front() -> void:
	if weather.model == null:
		return
	_draw_precip(_front, [2])
	_draw_motes()


func _draw_fog(model: WeatherModel) -> void:
	var p := weather.profile()
	var fog := float(p.get("fog", 0.0))
	var precip := model.precip_at(_sim_t)
	var amount := 0.0
	var tint := Color(0.78, 0.84, 0.92)
	match _precip_kind:
		"sand":
			amount = precip * 0.85 + fog
			tint = Color(0.86, 0.68, 0.46)
		"ash":
			amount = precip * 0.35
			tint = Color(0.5, 0.42, 0.48)
		_:
			amount = fog * (0.7 + 0.6 * precip) + precip * 0.12
	if amount <= 0.01:
		return
	var tex := _tex[FOG_TEX] as Texture2D
	var bands: int = 1 if _quality == GfxQuality.LOW else (2 if _quality == GfxQuality.MEDIUM else 4)
	var cam := _last_cam if _last_cam != Vector2.INF else Vector2.ZERO
	for k: int in range(bands):
		var span := _view.x * (0.9 + 0.25 * k)
		var y := fposmod(-cam.y * (0.35 + 0.1 * k) + k * 83.0, _view.y + 120.0) - 90.0
		var x := -fposmod(_fog_scroll * (0.6 + 0.3 * k) + cam.x * (0.35 + 0.1 * k), span) - span * 0.3
		var a := clampf(amount * (0.32 - 0.04 * k), 0.0, 0.6)
		while x < _view.x:
			_back.draw_texture_rect(tex, Rect2(roundf(x), roundf(y), span * 1.3, 120.0 + 30.0 * k), false,
					Color(tint, a))
			x += span


func _draw_precip(node: Node2D, layers: Array) -> void:
	if _active <= 0:
		return
	var model := weather.model
	var wind := model.wind_vector_at(_sim_t)
	var p := weather.profile()
	match _precip_kind:
		"rain", "spirit":
			var base := Color(String(p.get("rain_color", "#c8d6ff")))
			for lyr: int in layers:
				var pts := PackedVector2Array()
				var cols := PackedColorArray()
				var heads := PackedVector2Array()
				var a: float = [0.3, 0.48, 0.66][lyr]
				if _quality == GfxQuality.LOW:
					a += 0.18  # Baixa: uma camada só, mais marcada
				for i: int in range(_active):
					if _layer[i] != lyr:
						continue
					var v := _velocity(i, wind)
					var tail := v.normalized() * float(RAIN_LEN[lyr]) * (0.7 + 0.5 * _var[i])
					pts.append(_pos[i].round())
					pts.append((_pos[i] - tail).round())
					cols.append(Color(base, a))
					if _precip_kind == "spirit" or (lyr == 2 and _quality == GfxQuality.HIGH):
						heads.append(_pos[i].round())
				if not pts.is_empty():
					node.draw_multiline_colors(pts, cols, -1.0)
				for h: Vector2 in heads:
					node.draw_rect(Rect2(h - Vector2(0, 1), Vector2(1, 2)), Color(base.lightened(0.4), a + 0.25))
		"snow":
			var tex := _tex[SNOW_TEX] as Texture2D
			for i: int in range(_active):
				var lyr := _layer[i]
				if lyr not in layers:
					continue
				var frame := clampi(4 - lyr * 2 + int(_var[i] * 2.0), 0, 6)
				var size := 4.0 + lyr * 2.0
				node.draw_texture_rect_region(tex, Rect2(_pos[i].round(), Vector2(size, size)),
						Rect2(frame * 8, 0, 8, 8), Color(1, 1, 1, 0.55 + 0.15 * lyr))
		"ash":
			for i: int in range(_active):
				var lyr := _layer[i]
				if lyr not in layers:
					continue
				var c := Color(0.62, 0.58, 0.6, 0.45 + 0.15 * lyr)
				var flick := 1.0 + float(int(_time * 6.0 + _var[i] * 9.0) % 2)
				node.draw_rect(Rect2(_pos[i].round(), Vector2(1.0 + lyr, flick)), c)
		"sand":
			var pts := PackedVector2Array()
			var cols := PackedColorArray()
			for i: int in range(_active):
				var lyr := _layer[i]
				if lyr not in layers:
					continue
				var v := _velocity(i, wind)
				pts.append(_pos[i].round())
				pts.append((_pos[i] - v.normalized() * (5.0 + 6.0 * lyr)).round())
				cols.append(Color(0.98, 0.86, 0.62, 0.42 + 0.2 * lyr))
			if not pts.is_empty():
				node.draw_multiline_colors(pts, cols, -1.0)


func _draw_motes() -> void:
	if _mote_active <= 0:
		return
	match _extra_kind:
		"leaves", "petals":
			var tex := _tex[LEAF_TEX if _extra_kind == "leaves" else PETAL_TEX] as Texture2D
			for i: int in range(_mote_active):
				var frame := int(_time * (6.0 + 6.0 * _mote_var[i]) + _mote_var[i] * 6.0) % 6
				_front.draw_texture_rect_region(tex, Rect2(_mote_pos[i].round(), Vector2(12, 7)),
						Rect2(frame * 12, 0, 12, 7), Color(1, 1, 1, 0.9))
		"embers":
			for i: int in range(_mote_active):
				var v := _mote_var[i]
				var pulse := 0.55 + 0.45 * sin(_time * (3.0 + 4.0 * v) + v * 40.0)
				var c := Color(1.0, 0.45 + 0.3 * v, 0.15, 0.5 + 0.4 * pulse)
				if _quality == GfxQuality.HIGH:
					_front.draw_circle(_mote_pos[i], 2.5, Color(1.0, 0.35, 0.1, 0.12 * pulse))
				_front.draw_rect(Rect2(_mote_pos[i].round(), Vector2(1, 1) * (1.0 + float(v > 0.7))), c)
		"dust":
			for i: int in range(_mote_active):
				var v := _mote_var[i]
				_front.draw_rect(Rect2(_mote_pos[i].round(), Vector2(2.0 + 3.0 * v, 1.0 + float(v > 0.6))),
						Color(0.95, 0.8, 0.58, 0.5))


## Clarão aditivo acima da escuridão da lanterna e o raio no céu (Média/Alta).
func _draw_flash() -> void:
	var level := flash_level()
	if level <= 0.001 or _flash_strike.is_empty():
		return
	var p := weather.profile()
	var color := Color(String(p.get("lightning_color", "#dfe6ff")))
	var dist := float(_flash_strike[2])
	var strength := level * lerpf(0.42, 0.18, dist)
	_flash_node.draw_rect(Rect2(Vector2.ZERO, _view), Color(color * strength, 1.0))
	if _quality >= GfxQuality.MEDIUM and _flash_age < 0.24 and not _calm() and _bolt.size() > 1:
		var a := clampf(1.0 - _flash_age / 0.24, 0.0, 1.0) * lerpf(1.0, 0.45, dist)
		if _quality == GfxQuality.HIGH:
			_flash_node.draw_polyline(_bolt, Color(color, a * 0.35), 3.0)
		_flash_node.draw_polyline(_bolt, Color(1, 1, 1, a), 1.0)
		if _branch.size() > 1:
			_flash_node.draw_polyline(_branch, Color(color, a * 0.7), 1.0)
