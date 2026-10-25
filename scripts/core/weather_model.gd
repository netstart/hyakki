class_name WeatherModel
extends RefCounted
## Clima da partida como função pura de (fase, semente, tempo de simulação).
##
## O ciclo calmaria → brisa → vento forte → chuva fina → tempestade → estiagem se repete com
## durações sorteadas pela semente (data/weather.json). Tudo aqui depende só da semente e de
## `t` (GameClock.game_time): o mesmo clima em 1x/2x/3x, ao restaurar uma partida suspensa e
## em qualquer nível gráfico. O desenho (WeatherSystem e camadas) só lê estes valores.
##
## Jogabilidade: mud_level_at diz quanto o chão encharcado virou lama; as manchas de lama (e as
## outras superfícies lentas) ficam no SurfaceField, também por semente + chunk + tempo.

enum State { CALM, BREEZE, GALE, DRIZZLE, STORM, CLEARING }

const DATA_PATH := "res://data/weather.json"
const STATE_NAMES: Array[String] = ["calm", "breeze", "gale", "drizzle", "storm", "clearing"]
## Alvos por estado: [vento base, amplitude das rajadas, chuva, relâmpagos].
const TARGETS := [
	[0.06, 0.04, 0.0, 0.0],
	[0.3, 0.14, 0.0, 0.0],
	[0.62, 0.34, 0.0, 0.0],
	[0.42, 0.18, 0.42, 0.0],
	[0.82, 0.38, 1.0, 1.0],
	[0.22, 0.1, 0.06, 0.0],
]
## Lado do chunk do WorldMap (16 tiles de 16 px).
const CHUNK := 256.0
## Amostras da tabela de umidade por segundo de simulação.
const WET_STEP := 1.0
## Margem das manchas dentro do chunk: cada uma fica inteira no próprio chunk.
const PATCH_MARGIN := 46.0
## O ash_storm das dunas cresce e assenta nestes segundos em volta da janela do perigo.
const HAZARD_RAMP := 10.0

static var _data: Dictionary = {}

var stage_id: String = ""
var seed_value: int = 0
var profile: Dictionary = {}
## Estado forçado (--weather=storm etc., capturas e testes): -1 = ciclo normal.
var forced: int = -1

## Segmentos do ciclo: [estado, início, fim], gerados sob demanda.
var _segments: Array = []
var _seg_rng := RandomNumberGenerator.new()
var _last_seg: int = 0
## Umidade do chão amostrada a cada WET_STEP (integração determinística da chuva).
var _wet := PackedFloat32Array([0.0])
## Relâmpagos já gerados: [tempo, x 0..1, distância 0..1, semente visual], em ordem.
var _strikes: Array = []
var _strikes_until: float = 0.0
var _puddle_cache: Dictionary = {}
var _phase := PackedFloat32Array()
var _hazard: Dictionary = {}


func _init(p_stage: String = "village", p_seed: int = 0, stage_data: Dictionary = {}, p_forced: int = -1) -> void:
	stage_id = p_stage
	seed_value = p_seed
	forced = p_forced
	profile = profile_for(p_stage)
	_hazard = stage_data.get("hazard", {}) if bool(profile.get("sync_hazard", false)) else {}
	_seg_rng.seed = hash([p_seed, p_stage, "weather"])
	var phase_rng := RandomNumberGenerator.new()
	phase_rng.seed = hash([p_seed, p_stage, "wind"])
	for _k: int in range(8):
		_phase.append(phase_rng.randf() * TAU)
	var first: Array = profile.get("first_calm", [20, 30])
	_segments.append([State.CALM, 0.0, _seg_rng.randf_range(float(first[0]), float(first[1]))])


# --- Dados ---------------------------------------------------------------------------

static func data() -> Dictionary:
	if _data.is_empty():
		var text := FileAccess.get_file_as_string(DATA_PATH)
		var parsed: Variant = JSON.parse_string(text)
		_data = parsed if parsed is Dictionary else {"defaults": {}, "stages": {}}
	return _data


## Perfil da fase: "defaults" + o que a fase sobrescreve (fase sem entrada = só os padrões).
static func profile_for(p_stage: String) -> Dictionary:
	var d := data()
	var out: Dictionary = (d.get("defaults", {}) as Dictionary).duplicate(true)
	out["precip"] = "rain"
	out["extra"] = ""
	out.merge((d.get("stages", {}) as Dictionary).get(p_stage, {}), true)
	return out


static func state_from_name(name: String) -> int:
	return STATE_NAMES.find(name)


# --- Ciclo ---------------------------------------------------------------------------

## Índice do segmento que contém `t` (gera o ciclo sob demanda).
func _segment_index(t: float) -> int:
	while float(_segments[-1][2]) <= t:
		var last: Array = _segments[-1]
		var next_state := (int(last[0]) + 1) % STATE_NAMES.size()
		var span: Array = (profile.get("durations", {}) as Dictionary).get(STATE_NAMES[next_state], [30, 40])
		var start := float(last[2])
		_segments.append([next_state, start, start + _seg_rng.randf_range(float(span[0]), float(span[1]))])
	var i := clampi(_last_seg, 0, _segments.size() - 1)
	if float(_segments[i][1]) > t:
		i = 0
	while float(_segments[i][2]) <= t:
		i += 1
	_last_seg = i
	return i


## Estado dominante em `t` (o do segmento atual).
func state_at(t: float) -> int:
	if forced >= 0:
		return forced
	if not _hazard.is_empty():
		return _hazard_state(t)
	return int(_segments[_segment_index(t)][0])


func state_name_at(t: float) -> String:
	return STATE_NAMES[state_at(t)]


## Alvos misturados [vento, rajada, chuva, relâmpago] em `t`, com transição suave.
func blend_at(t: float) -> PackedFloat32Array:
	if forced >= 0:
		return PackedFloat32Array(TARGETS[forced])
	if not _hazard.is_empty():
		return _hazard_blend(t)
	var i := _segment_index(t)
	var seg: Array = _segments[i]
	var cur: Array = TARGETS[int(seg[0])]
	var prev: Array = TARGETS[int(_segments[i - 1][0])] if i > 0 else TARGETS[State.CALM]
	var k := smoothstep(0.0, float(profile.get("transition", 9.0)), t - float(seg[1]))
	var out := PackedFloat32Array()
	for j: int in range(4):
		out.append(lerpf(float(prev[j]), float(cur[j]), k))
	return out


## Dunas: o clima segue a janela do ash_storm do WorldMap (mesma conta de world_map.gd:
## fmod(t, interval) > interval - duration), com vento crescendo antes e assentando depois.
func _hazard_window(t: float) -> float:
	var interval := float(_hazard.get("interval", 90))
	var duration := float(_hazard.get("duration", 15))
	var local := fmod(t, interval)
	var start := interval - duration
	if local > start:
		return 1.0
	# Antes da tempestade o vento cresce; logo depois ela ainda assenta.
	var before := smoothstep(start - HAZARD_RAMP * 1.5, start, local)
	var after := 1.0 - smoothstep(0.0, HAZARD_RAMP, local) if t >= interval else 0.0
	return maxf(before * 0.6, after * 0.8)


func _hazard_state(t: float) -> int:
	var w := _hazard_window(t)
	if w >= 1.0:
		return State.STORM
	if w > 0.3:
		return State.GALE
	return State.BREEZE if w > 0.05 else State.CALM


func _hazard_blend(t: float) -> PackedFloat32Array:
	var w := _hazard_window(t)
	var calm: Array = TARGETS[State.BREEZE]
	var storm: Array = TARGETS[State.STORM]
	var out := PackedFloat32Array()
	for j: int in range(4):
		out.append(lerpf(float(calm[j]), float(storm[j]), w))
	return out


## Verdadeiro na mesma janela em que o WorldMap liga o ash_storm.
func hazard_storm_at(t: float) -> bool:
	return not _hazard.is_empty() and _hazard_window(t) >= 1.0


# --- Vento ---------------------------------------------------------------------------

## Rajadas: pulsos determinísticos (produto de senos), 0..1.
func gust_at(t: float) -> float:
	var a := 0.5 + 0.5 * sin(t * 0.83 + _phase[0])
	var b := 0.5 + 0.5 * sin(t * 0.31 + _phase[1])
	var c := 0.5 + 0.5 * sin(t * 1.3 + _phase[2])
	return clampf(pow(a * b, 2.0) * 1.6 + c * 0.08, 0.0, 1.0)


## Força do vento 0..1 com as rajadas.
func wind_strength_at(t: float) -> float:
	var b := blend_at(t)
	var scale := float(profile.get("wind_scale", 1.0))
	return clampf((b[0] + b[1] * gust_at(t)) * scale, 0.0, 1.0)


## Direção (normalizada). Vento sobrenatural ("swirl") gira mais rápido e dá voltas.
func wind_dir_at(t: float) -> Vector2:
	var swirl := float(profile.get("swirl", 0.0))
	var base := 0.0 if _phase[3] < PI else PI
	var angle := base + (_phase[4] - PI) * 0.12 + 0.45 * sin(t * 0.017 + _phase[5]) \
			+ 0.18 * sin(t * 0.071 + _phase[6]) + swirl * (0.9 * sin(t * 0.11 + _phase[7]) + 0.004 * t)
	return Vector2.from_angle(angle)


func wind_vector_at(t: float) -> Vector2:
	return wind_dir_at(t) * wind_strength_at(t)


# --- Chuva, umidade, lama ------------------------------------------------------------

## Intensidade da precipitação da fase 0..1 (chuva, neve, areia, cinza...).
func precip_at(t: float) -> float:
	var b := blend_at(t)
	if _hazard.is_empty():
		return b[2]
	return _hazard_window(t)


## Chuva que molha o chão (0 nas fases secas: rain_scale 0).
func rain_at(t: float) -> float:
	return clampf(blend_at(t)[2] * float(profile.get("rain_scale", 1.0)), 0.0, 1.0)


## Relâmpagos ativos 0..1 (só nas fases com "lightning").
func lightning_at(t: float) -> float:
	return blend_at(t)[3] if bool(profile.get("lightning", false)) else 0.0


## Chão molhado 0..1: integra a chuva (molha) e o tempo seco (seca), amostrado por segundo.
func wetness_at(t: float) -> float:
	if float(profile.get("rain_scale", 1.0)) <= 0.0:
		return 0.0
	if forced >= 0:
		return 1.0 if TARGETS[forced][2] > 0.3 else (0.5 if TARGETS[forced][2] > 0.0 else 0.0)
	var k := t / WET_STEP
	var need := int(k) + 2
	var wet_rate := float(profile.get("wet_rate", 0.045))
	var dry_rate := float(profile.get("dry_rate", 0.011))
	while _wet.size() < need:
		var s := (_wet.size() - 1) * WET_STEP
		var r := rain_at(s + WET_STEP * 0.5)
		var w := _wet[-1]
		if r > 0.05:
			w += r * wet_rate * WET_STEP
		else:
			w -= dry_rate * (1.0 + 0.6 * wind_strength_at(s)) * WET_STEP
		_wet.append(clampf(w, 0.0, 1.0))
	var i := int(k)
	return lerpf(_wet[i], _wet[i + 1], k - i)


## Quanto o chão encharcado vira lama 0..1 (as superfícies "rain" do SurfaceField crescem com ele).
func mud_level_at(t: float) -> float:
	return clampf(inverse_lerp(float(profile.get("mud_from", 0.3)), float(profile.get("mud_full", 0.85)),
			wetness_at(t)), 0.0, 1.0)


## Poças 0..1: crescem com a chuva e secam depois.
func puddle_level_at(t: float) -> float:
	if not bool(profile.get("puddles", false)):
		return 0.0
	return clampf(inverse_lerp(0.12, 0.75, wetness_at(t)), 0.0, 1.0)


## Poças do chunk (só visual): mesmo formato das manchas.
func puddles(c: Vector2i) -> Array:
	if _puddle_cache.has(c):
		return _puddle_cache[c]
	var out: Array = []
	if bool(profile.get("puddles", false)):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([seed_value, c.x, c.y, stage_id, "puddle"])
		var per := float(profile.get("puddles_per_chunk", 2.2))
		var count := int(per) + (1 if rng.randf() < fmod(per, 1.0) else 0)
		for _k: int in range(count):
			out.append(_make_patch(rng, c, rng.randf_range(7.0, 13.0), 2 + rng.randi_range(0, 2)))
	_puddle_cache[c] = out
	return out


func _make_patch(rng: RandomNumberGenerator, c: Vector2i, size: float, blobs: int) -> Dictionary:
	var origin := Vector2(c.x * CHUNK, c.y * CHUNK)
	var center := origin + Vector2(rng.randf_range(PATCH_MARGIN, CHUNK - PATCH_MARGIN),
			rng.randf_range(PATCH_MARGIN, CHUNK - PATCH_MARGIN))
	var list: Array[Vector3] = [Vector3(0.0, 0.0, size)]
	var bound := size
	var stretch := rng.randf_range(1.0, 1.6)
	for _k: int in range(blobs):
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.35, 0.8) * size
		var off := Vector2(cos(a) * d * stretch, sin(a) * d * 0.7)
		var r := rng.randf_range(0.45, 0.75) * size
		list.append(Vector3(off.x, off.y, r))
		bound = maxf(bound, off.length() + r)
	return {"center": center.round(), "bound": bound, "blobs": list, "th": rng.randf_range(0.0, 0.6),
			"seed": rng.randi()}


## Escala 0..1 de uma mancha com o nível de lama/água `level`.
static func patch_scale(patch: Dictionary, level: float) -> float:
	var th := float(patch["th"])
	return smoothstep(th, th + 0.35, level)


## Verdadeiro se `p` está dentro da mancha já com a escala `s`.
static func patch_contains(patch: Dictionary, p: Vector2, s: float) -> bool:
	if s <= 0.0:
		return false
	var d: Vector2 = p - (patch["center"] as Vector2)
	var bound := float(patch["bound"]) * s
	if d.length_squared() > bound * bound:
		return false
	for b: Vector3 in patch["blobs"]:
		var r := b.z * s
		if (d - Vector2(b.x, b.y) * s).length_squared() < r * r:
			return true
	return false


# --- Relâmpagos ----------------------------------------------------------------------

## Relâmpagos com tempo em [from, to): cada um [tempo, x 0..1, distância 0..1, semente].
func strikes_between(from: float, to: float) -> Array:
	if not bool(profile.get("lightning", false)):
		return []
	_generate_strikes(to)
	var out: Array = []
	for s: Array in _strikes:
		if float(s[0]) >= to:
			break
		if float(s[0]) >= from:
			out.append(s)
	return out


func _generate_strikes(until: float) -> void:
	while _strikes_until < until:
		var from := _strikes_until
		var to := from + 10.0
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([seed_value, stage_id, "strike", int(from)])
		var at := from + rng.randf_range(0.5, 3.0)
		while at < to:
			var level := lightning_at(at)
			if level > 0.25 and rng.randf() < level:
				_strikes.append([at, rng.randf_range(0.08, 0.92), rng.randf(), rng.randi()])
			at += rng.randf_range(2.5, 7.0)
		_strikes_until = to
