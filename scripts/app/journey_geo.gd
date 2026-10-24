class_name JourneyGeo
extends RefCounted
## Geografia do mapa da Jornada do Guardião (sem autoloads, testável em tests/run_tests.gd):
## contornos aproximados do arquipélago em graus (lon, lat), projeção equiretangular
## girada, estrada em Catmull-Rom e afastamento mínimo entre os pontos de luta.

## Latitude de referência da projeção equiretangular (centro de Honshu).
const REF_LAT := 36.0
## Giro do mapa, em graus no sentido horário da tela: deita o arquipélago (que sobe para
## nordeste) para ele ocupar bem a área larga e baixa do mapa.
const TILT_DEG := 27.0

## Pontos de luta (lon, lat).
const STAGES := {
	&"village": Vector2(141.53, 39.33),  # Tōno (Iwate)
	&"bamboo": Vector2(139.45, 35.70),  # Musashino
	&"temple": Vector2(135.77, 35.12),  # Monte Kurama
	&"dunes": Vector2(134.40, 35.52),  # Tottori
	&"yomi": Vector2(130.26, 32.75),  # Unzen
	&"secret": Vector2(132.69, 35.40),  # Izumo / Yomotsu Hirasaka
}

## Pontos de passagem da estrada até cada fase (lon, lat), para ela correr por terra e o
## caminho secreto (de Unzen a Izumo) seguir pela costa do Mar do Japão, sem cruzar o outro.
const VIA := {
	&"bamboo": [Vector2(140.75, 37.75), Vector2(139.85, 36.6)],
	&"temple": [Vector2(137.9, 35.75), Vector2(136.7, 35.3)],
	&"dunes": [Vector2(135.15, 35.05)],
	&"yomi": [Vector2(133.3, 34.95), Vector2(131.9, 34.2), Vector2(130.75, 33.55)],
	&"secret": [Vector2(129.85, 33.25), Vector2(130.9, 34.35), Vector2(131.9, 35.05)],
}

## Contornos (lon, lat), no sentido horário do mapa.
const HONSHU: Array[Vector2] = [
	Vector2(140.92, 41.52), Vector2(141.45, 41.42), Vector2(141.42, 40.72), Vector2(141.62, 40.45),
	Vector2(141.82, 40.15), Vector2(142.02, 39.62), Vector2(141.9, 39.2), Vector2(141.62, 38.85),
	Vector2(141.52, 38.32), Vector2(141.0, 38.3), Vector2(140.98, 37.7), Vector2(140.98, 36.95),
	Vector2(140.62, 36.45), Vector2(140.87, 35.73), Vector2(140.38, 35.2), Vector2(139.85, 34.92),
	Vector2(139.9, 35.4), Vector2(139.65, 35.2), Vector2(139.12, 35.12), Vector2(138.85, 34.62),
	Vector2(138.72, 35.05), Vector2(138.25, 34.65), Vector2(137.7, 34.66), Vector2(137.02, 34.6),
	Vector2(136.88, 34.92), Vector2(136.6, 34.65), Vector2(136.9, 34.32), Vector2(136.3, 34.0),
	Vector2(135.77, 33.44), Vector2(135.35, 33.7), Vector2(135.08, 34.25), Vector2(135.4, 34.68),
	Vector2(134.9, 34.66), Vector2(134.3, 34.68), Vector2(133.9, 34.52), Vector2(133.3, 34.4),
	Vector2(132.5, 34.3), Vector2(132.15, 33.92), Vector2(131.5, 34.0), Vector2(130.92, 33.92),
	Vector2(130.88, 34.28), Vector2(131.4, 34.45), Vector2(132.05, 34.88), Vector2(132.62, 35.4),
	Vector2(133.05, 35.58), Vector2(133.6, 35.5), Vector2(134.25, 35.55), Vector2(134.9, 35.66),
	Vector2(135.25, 35.78), Vector2(135.62, 35.5), Vector2(136.05, 35.68), Vector2(136.1, 36.2),
	Vector2(136.6, 36.6), Vector2(136.72, 37.08), Vector2(136.9, 37.4), Vector2(137.35, 37.52),
	Vector2(137.05, 37.08), Vector2(137.35, 36.78), Vector2(137.88, 37.05), Vector2(138.6, 37.45),
	Vector2(139.08, 37.95), Vector2(139.48, 38.3), Vector2(139.85, 38.95), Vector2(140.02, 39.6),
	Vector2(139.72, 39.95), Vector2(140.02, 40.25), Vector2(139.9, 40.6), Vector2(140.35, 41.22),
	Vector2(140.72, 40.88), Vector2(141.18, 40.92), Vector2(141.22, 41.22),
]
const HOKKAIDO: Array[Vector2] = [
	Vector2(140.72, 41.78), Vector2(141.18, 41.8), Vector2(140.98, 42.3), Vector2(141.62, 42.62),
	Vector2(142.6, 42.25), Vector2(143.25, 41.93), Vector2(143.7, 42.6), Vector2(144.4, 42.98),
	Vector2(145.6, 43.33), Vector2(145.15, 43.65), Vector2(145.32, 44.35), Vector2(144.28, 44.02),
	Vector2(143.35, 44.36), Vector2(142.4, 44.95), Vector2(141.94, 45.52), Vector2(141.65, 45.4),
	Vector2(141.75, 44.6), Vector2(141.65, 43.95), Vector2(141.35, 43.25), Vector2(140.98, 43.2),
	Vector2(140.42, 43.36), Vector2(140.5, 42.98), Vector2(139.85, 42.45), Vector2(140.12, 41.9),
	Vector2(140.08, 41.45), Vector2(140.42, 41.65),
]
const SHIKOKU: Array[Vector2] = [
	Vector2(134.62, 34.22), Vector2(134.72, 33.85), Vector2(134.18, 33.25), Vector2(133.6, 33.5),
	Vector2(133.25, 33.35), Vector2(133.0, 32.72), Vector2(132.68, 32.9), Vector2(132.52, 33.22),
	Vector2(132.0, 33.36), Vector2(132.42, 33.48), Vector2(132.68, 33.86), Vector2(133.0, 34.08),
	Vector2(133.3, 33.97), Vector2(133.65, 34.18), Vector2(134.05, 34.36), Vector2(134.4, 34.2),
]
const KYUSHU: Array[Vector2] = [
	Vector2(130.92, 33.9), Vector2(131.7, 33.65), Vector2(131.55, 33.27), Vector2(132.05, 33.22),
	Vector2(131.88, 32.92), Vector2(131.7, 32.55), Vector2(131.45, 31.9), Vector2(131.35, 31.38),
	Vector2(130.92, 31.12), Vector2(130.66, 31.0), Vector2(130.8, 31.45), Vector2(130.58, 31.62),
	Vector2(130.65, 31.25), Vector2(130.5, 31.15), Vector2(130.28, 31.28), Vector2(130.25, 31.72),
	Vector2(130.2, 32.05), Vector2(130.4, 32.22), Vector2(130.6, 32.5), Vector2(130.62, 32.8),
	Vector2(130.44, 32.98), Vector2(130.38, 33.15), Vector2(130.22, 33.2), Vector2(130.08, 33.08),
	Vector2(130.15, 32.9), Vector2(130.38, 32.8), Vector2(130.3, 32.58), Vector2(130.12, 32.66),
	Vector2(129.98, 32.82), Vector2(129.86, 32.72), Vector2(129.76, 32.57), Vector2(129.68, 32.92),
	Vector2(129.72, 33.2), Vector2(129.56, 33.36), Vector2(129.95, 33.48), Vector2(130.2, 33.6),
	Vector2(130.42, 33.62), Vector2(130.6, 33.88),
]
## Ilhas pequenas: Sado, Awaji, Oki, Tsushima, Iki, Goto, Izu Ōshima, Tanegashima, Yakushima.
const ISLETS: Array = [
	[Vector2(138.22, 38.32), Vector2(138.52, 38.3), Vector2(138.55, 37.95), Vector2(138.3, 37.8),
			Vector2(138.2, 38.02)],
	[Vector2(134.95, 34.6), Vector2(134.98, 34.3), Vector2(134.72, 34.2), Vector2(134.8, 34.45)],
	[Vector2(133.1, 36.32), Vector2(133.38, 36.28), Vector2(133.32, 36.12), Vector2(133.08, 36.15)],
	[Vector2(129.35, 34.68), Vector2(129.48, 34.6), Vector2(129.38, 34.2), Vector2(129.22, 34.3)],
	[Vector2(129.68, 33.85), Vector2(129.82, 33.8), Vector2(129.72, 33.72)],
	[Vector2(128.85, 32.85), Vector2(129.08, 32.78), Vector2(128.95, 32.6), Vector2(128.72, 32.65)],
	[Vector2(139.35, 34.8), Vector2(139.45, 34.72), Vector2(139.38, 34.67)],
	[Vector2(130.98, 30.85), Vector2(131.08, 30.6), Vector2(130.92, 30.38), Vector2(130.88, 30.65)],
	[Vector2(130.45, 30.45), Vector2(130.65, 30.38), Vector2(130.55, 30.25), Vector2(130.4, 30.3)],
]
## Penínsulas e costas da Coreia (borda esquerda), só para o mar não parecer vazio.
const KOREA: Array[Vector2] = [
	Vector2(126.0, 38.6), Vector2(128.4, 38.6), Vector2(129.45, 36.6), Vector2(129.35, 35.5),
	Vector2(128.6, 35.0), Vector2(127.6, 34.6), Vector2(126.3, 34.4), Vector2(126.0, 35.5),
]

## Montes (lon, lat) com picos nevados ao norte.
const MOUNTAINS: Array[Vector2] = [
	Vector2(140.8, 40.4), Vector2(140.55, 39.6), Vector2(140.6, 38.7), Vector2(140.1, 37.6),
	Vector2(138.6, 36.4), Vector2(137.6, 36.2), Vector2(142.8, 43.5), Vector2(143.6, 43.1),
	Vector2(133.6, 35.25), Vector2(131.1, 32.9), Vector2(141.4, 44.3), Vector2(136.3, 35.6),
]
const FUJI := Vector2(138.73, 35.36)
## Torii desenhado um pouco a sudoeste de Izumo, para não ficar sob o ponto da fase secreta.
const IZUMO_TORII := Vector2(132.0, 34.6)
const TOTTORI_SAND := Vector2(134.25, 35.53)


## Estado de uma fase no mapa: vencida (selo), liberada (lanterna) ou bloqueada (névoa).
static func stage_state(won: bool, unlocked: bool) -> StringName:
	if won:
		return &"cleared"
	return &"open" if unlocked else &"locked"


## Graus (lon, lat) para o plano do mapa, ainda sem escala (1 unidade ≈ 1 grau de latitude).
static func project(lon_lat: Vector2) -> Vector2:
	var flat := Vector2(lon_lat.x * cos(deg_to_rad(REF_LAT)), -lon_lat.y)
	return flat.rotated(deg_to_rad(TILT_DEG))


## Escala e deslocamento que põem os pontos (já projetados) dentro de `area`.
static func fit(points: Array[Vector2], area: Rect2) -> Transform2D:
	var box := Rect2(points[0], Vector2.ZERO)
	for p: Vector2 in points:
		box = box.expand(p)
	var scale := minf(area.size.x / maxf(box.size.x, 0.001), area.size.y / maxf(box.size.y, 0.001))
	var offset := area.get_center() - box.get_center() * scale
	return Transform2D(0.0, Vector2(scale, scale), 0.0, offset)


static func project_all(points: Array, xf: Transform2D) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in points:
		out.append(xf * project(p))
	return out


## Afasta pontos cujos quadrados tocáveis (lado `min_dist`) se encostariam: a maior das
## distâncias em x e em y tem de ser ≥ `min_dist`. Iterativo e simétrico; mantém em `area`.
static func separate(points: Dictionary, min_dist: float, area: Rect2) -> Dictionary:
	var out := points.duplicate()
	var keys := out.keys()
	for _pass: int in range(40):
		var moved := false
		for i: int in range(keys.size()):
			for j: int in range(i + 1, keys.size()):
				var a: Vector2 = out[keys[i]]
				var b: Vector2 = out[keys[j]]
				var delta := b - a
				var reach := maxf(absf(delta.x), absf(delta.y))
				if reach >= min_dist:
					continue
				var push := (delta * (min_dist / reach - 1.0) if reach > 0.01 else Vector2(min_dist, 0)) * 0.5
				push += push.normalized() * 0.25
				out[keys[i]] = (a - push).clamp(area.position, area.end)
				out[keys[j]] = (b + push).clamp(area.position, area.end)
				moved = true
		if not moved:
			break
	return out


## Curva Catmull-Rom (uniforme) pelos pontos, com `steps` amostras por trecho.
static func catmull_rom(points: PackedVector2Array, steps: int = 8) -> PackedVector2Array:
	var out := PackedVector2Array()
	if points.size() < 2:
		return points
	for i: int in range(points.size() - 1):
		var p0 := points[maxi(i - 1, 0)]
		var p1 := points[i]
		var p2 := points[i + 1]
		var p3 := points[mini(i + 2, points.size() - 1)]
		for s: int in range(steps):
			var t := float(s) / steps
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
					+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(points[points.size() - 1])
	return out


## Corta uma linha em traços de `dash` com intervalos de `gap` (pares de pontos início/fim).
static func dashes(line: PackedVector2Array, dash: float, gap: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var on := true
	var left := dash
	for i: int in range(line.size() - 1):
		var a := line[i]
		var b := line[i + 1]
		var length := a.distance_to(b)
		var at := 0.0
		while at < length:
			var step := minf(left, length - at)
			var p := a.lerp(b, at / length)
			var q := a.lerp(b, (at + step) / length)
			if on:
				out.append(p)
				out.append(q)
			at += step
			left -= step
			if left <= 0.0:
				on = not on
				left = dash if on else gap
	return out
