class_name SurfaceField
extends RefCounted
## Onde estão as superfícies lentas (lama, barro, pântano, óleo, piche, areia movediça) e de
## que tipo: função pura da fase, da semente, do chunk e do tempo de simulação (as manchas de
## "rain" crescem com a chuva do WeatherModel). Nada aqui depende do nível gráfico.
##
## Consulta barata: type_at(p, t) olha só as manchas do chunk de `p` (cada mancha cabe inteira
## no próprio chunk), primeiro o círculo que envolve a mancha e depois as bolhas.

const DATA_PATH := "res://data/surfaces.json"
const CHUNK := WeatherModel.CHUNK
const MARGIN := WeatherModel.PATCH_MARGIN

static var _data: Dictionary = {}

## Nomes dos tipos na ordem de índice (o índice é o que os atores guardam).
var type_names: Array[String] = []
## Parâmetros por índice: {"slow", "ease_in", "ease_out", "accel", "resist_by_size", "sound"}.
var types: Array[Dictionary] = []
var stage_id: String = ""
var seed_value: int = 0
var weather: WeatherModel
var bounds := Vector2.ZERO
var safe_radius: float = 90.0

var _rules: Array = []
var _cache: Dictionary = {}


func _init(p_stage: String, p_seed: int, p_weather: WeatherModel = null, p_bounds: Vector2 = Vector2.ZERO) -> void:
	stage_id = p_stage
	seed_value = p_seed
	weather = p_weather if p_weather != null else WeatherModel.new(p_stage, p_seed)
	bounds = p_bounds
	var d := data()
	safe_radius = float(d.get("safe_radius", 90.0))
	var all_types: Dictionary = d.get("types", {})
	for name: String in all_types:
		type_names.append(name)
		types.append(all_types[name])
	_rules = (d.get("stages", {}) as Dictionary).get(p_stage, [])


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_data = parsed if parsed is Dictionary else {"types": {}, "stages": {}}
	return _data


func type_index(name: String) -> int:
	return type_names.find(name)


func slow_of(type: int) -> float:
	return float(types[type].get("slow", 1.0))


## Tipos que aparecem nesta fase.
func stage_types() -> Array[String]:
	var out: Array[String] = []
	for rule: Dictionary in _rules:
		out.append(String(rule["type"]))
	return out


## Manchas do chunk: [{"type", "center", "bound", "blobs", "th", "seed", "rain"}].
func patches(c: Vector2i) -> Array:
	if _cache.has(c):
		return _cache[c]
	var out: Array = []
	for k: int in range(_rules.size()):
		var rule: Dictionary = _rules[k]
		var t := type_index(String(rule["type"]))
		if t < 0:
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([seed_value, c.x, c.y, stage_id, "surface", k])
		var per := float(rule.get("per_chunk", 1.0))
		var count := int(per) + (1 if rng.randf() < fmod(per, 1.0) else 0)
		var size: Array = rule.get("size", [16, 26])
		for _j: int in range(count):
			var patch := _make_patch(rng, c, rng.randf_range(float(size[0]), float(size[1])), 3 + rng.randi_range(0, 3))
			patch["type"] = t
			patch["rain"] = bool(rule.get("rain", false))
			if _allowed(patch):
				out.append(patch)
	_cache[c] = out
	return out


## Fora da zona segura do nascimento e inteira dentro dos limites da fase (Templo e Yomi).
func _allowed(patch: Dictionary) -> bool:
	var center: Vector2 = patch["center"]
	var reach := float(patch["bound"])
	if center.length() < safe_radius + reach:
		return false
	if bounds.x > 0.0 and absf(center.x) > bounds.x - reach - 24.0:
		return false
	if bounds.y > 0.0 and absf(center.y) > bounds.y - reach - 24.0:
		return false
	return true


func _make_patch(rng: RandomNumberGenerator, c: Vector2i, size: float, blobs: int) -> Dictionary:
	var origin := Vector2(c.x * CHUNK, c.y * CHUNK)
	var center := origin + Vector2(rng.randf_range(MARGIN, CHUNK - MARGIN), rng.randf_range(MARGIN, CHUNK - MARGIN))
	var list: Array[Vector3] = [Vector3(0.0, 0.0, size)]
	var bound := size
	var stretch := rng.randf_range(1.0, 1.5)
	for _k: int in range(blobs):
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.35, 0.75) * size
		var off := Vector2(cos(a) * d * stretch, sin(a) * d * 0.7)
		var r := rng.randf_range(0.45, 0.72) * size
		list.append(Vector3(off.x, off.y, r))
		bound = maxf(bound, off.length() + r)
	# A mancha inteira cabe no próprio chunk (a consulta só olha o chunk do ponto).
	if bound > MARGIN - 2.0:
		var f := (MARGIN - 2.0) / bound
		for k: int in range(list.size()):
			list[k] = list[k] * f
		bound = MARGIN - 2.0
	return {"center": center.round(), "bound": bound, "blobs": list,
			"th": rng.randf_range(0.0, 0.6), "seed": rng.randi()}


## Escala 0..1 da mancha no tempo `t` (as de chuva crescem e secam; as outras são fixas).
func scale_of(patch: Dictionary, t: float) -> float:
	if not bool(patch["rain"]):
		return 1.0
	return WeatherModel.patch_scale(patch, weather.mud_level_at(t))


## Tipo da superfície em `p` no tempo `t` (-1 = chão normal).
func type_at(p: Vector2, t: float) -> int:
	var c := Vector2i(floori(p.x / CHUNK), floori(p.y / CHUNK))
	var list: Array = patches(c)
	if list.is_empty():
		return -1
	var level := -1.0
	for patch: Dictionary in list:
		var s := 1.0
		if bool(patch["rain"]):
			if level < 0.0:
				level = weather.mud_level_at(t)
			s = WeatherModel.patch_scale(patch, level)
		if WeatherModel.patch_contains(patch, p, s):
			return int(patch["type"])
	return -1


## Multiplicador de velocidade instantâneo em `p` (sem suavização: a do ator fica no SurfaceSystem).
func slow_at(p: Vector2, t: float) -> float:
	var type := type_at(p, t)
	return 1.0 if type < 0 else slow_of(type)
