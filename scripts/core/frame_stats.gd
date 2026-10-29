class_name FrameStats
extends RefCounted
## Medidor de quadros para os testes de desempenho (rolagem das telas, partida). Guarda a
## duração de cada quadro em microssegundos (tempo real, Time.get_ticks_usec) e, opcional, a
## posição de uma rolagem no quadro, e resume em média, p50/p95/p99, pior quadro, quadros
## acima de 20 ms / 33 ms / 50 ms e "travadas" da rolagem (quadros em que a lista parou de
## andar no meio de um movimento).
##
## Uso típico (um quadro por _process):
##     var stats := FrameStats.new()
##     stats.tick()                    # a cada quadro
##     stats.tick_scroll(scroll_value) # ou com a posição da rolagem
##     var r := stats.summary()        # {"frames", "avg_ms", "p95_ms", ...}
##
## A parte de cálculo é pura (summarize, percentile, scroll_stalls): testada sem cena.

## Limites dos quadros "longos" contados no resumo (ms).
const SLOW_MS := 20.0
const JANK_MS := 33.4
const HITCH_MS := 50.0
## Velocidade mínima (px/s) para um quadro parado contar como travada da rolagem.
const STALL_SPEED := 40.0

var frames_us := PackedInt64Array()
var scroll := PackedFloat32Array()

var _last_usec: int = 0


## Começa de novo (o próximo tick só marca o início).
func reset() -> void:
	frames_us.clear()
	scroll.clear()
	_last_usec = 0


## Marca um quadro; o primeiro só inicia o relógio.
func tick() -> void:
	var now := Time.get_ticks_usec()
	if _last_usec != 0:
		frames_us.append(now - _last_usec)
	_last_usec = now


## Marca um quadro com a posição da rolagem nele (px lógicos).
func tick_scroll(value: float) -> void:
	var had := _last_usec != 0
	tick()
	if had:
		scroll.append(value)
	elif scroll.is_empty():
		# Posição inicial: a 1ª diferença compara o 1º quadro medido com ela.
		scroll.append(value)


func summary() -> Dictionary:
	var result := summarize(frames_us)
	if scroll.size() > 1:
		result["stalls"] = scroll_stalls(frames_us, scroll)
		var distance := 0.0
		for k: int in range(1, scroll.size()):
			distance += absf(scroll[k] - scroll[k - 1])
		result["distance"] = distance
	return result


## Resumo só dos quadros em movimento: cada quadro em que a rolagem andou, com `pad` quadros
## de cada lado (pega as travadas no meio do gesto). Serve para medir só o gesto quando a
## medição inclui esperas paradas (o gesto pode demorar a começar).
func motion_summary(pad: int = 3) -> Dictionary:
	var n := mini(frames_us.size(), scroll.size() - 1)
	var keep := PackedByteArray()
	keep.resize(maxi(n, 0))
	for k: int in range(n):
		if scroll[k + 1] != scroll[k]:
			for j: int in range(maxi(0, k - pad), mini(n, k + pad + 1)):
				keep[j] = 1
	var picked := PackedInt64Array()
	var stalls := 0
	var distance := 0.0
	var k := 0
	while k < n:
		if keep[k] == 0:
			k += 1
			continue
		# Um trecho contínuo [k, end): quadros e as posições antes/depois de cada um.
		var end := k
		while end < n and keep[end] == 1:
			end += 1
		var seg_us := frames_us.slice(k, end)
		var seg_pos := scroll.slice(k, end + 1)
		picked.append_array(seg_us)
		stalls += scroll_stalls(seg_us, seg_pos)
		for j: int in range(k, end):
			distance += absf(scroll[j + 1] - scroll[j])
		k = end
	var result := summarize(picked)
	result["stalls"] = stalls
	result["distance"] = distance
	return result


## Resumo de uma lista de durações (µs): frames, avg_ms, p50_ms, p95_ms, p99_ms, max_ms,
## over_20, over_33, over_50 e fps (média).
static func summarize(us: PackedInt64Array) -> Dictionary:
	var n := us.size()
	if n == 0:
		return {"frames": 0, "avg_ms": 0.0, "p50_ms": 0.0, "p95_ms": 0.0, "p99_ms": 0.0, "max_ms": 0.0,
				"over_20": 0, "over_33": 0, "over_50": 0, "fps": 0.0}
	var sorted := us.duplicate()
	sorted.sort()
	var total := 0
	var over := [0, 0, 0]
	for v: int in us:
		total += v
		var ms := v / 1000.0
		if ms > SLOW_MS:
			over[0] += 1
		if ms > JANK_MS:
			over[1] += 1
		if ms > HITCH_MS:
			over[2] += 1
	var avg := total / 1000.0 / n
	return {"frames": n, "avg_ms": avg, "p50_ms": percentile(sorted, 0.5) / 1000.0,
			"p95_ms": percentile(sorted, 0.95) / 1000.0, "p99_ms": percentile(sorted, 0.99) / 1000.0,
			"max_ms": sorted[n - 1] / 1000.0, "over_20": over[0], "over_33": over[1], "over_50": over[2],
			"fps": 1000.0 / avg if avg > 0.0 else 0.0}


## Percentil (0..1) de uma lista JÁ ordenada, pelo posto mais próximo (sem interpolar).
static func percentile(sorted: PackedInt64Array, q: float) -> float:
	if sorted.is_empty():
		return 0.0
	var rank := clampi(ceili(q * sorted.size()) - 1, 0, sorted.size() - 1)
	return float(sorted[rank])


## Travadas da rolagem: quadros em que a posição não mudou embora a lista estivesse andando
## (o quadro anterior e o seguinte andaram, ambos acima de STALL_SPEED). `positions[k]` é a
## posição depois do quadro k-1 (positions tem um item a mais que us, o ponto de partida).
## Não conta o fim natural do movimento (parou e ficou parado).
static func scroll_stalls(us: PackedInt64Array, positions: PackedFloat32Array) -> int:
	var stalls := 0
	var n := mini(us.size(), positions.size() - 1)
	for k: int in range(1, n - 1):
		var moved := absf(positions[k + 1] - positions[k])
		if moved > 0.0:
			continue
		var before := absf(positions[k] - positions[k - 1]) / maxf(us[k - 1] / 1e6, 1e-4)
		var after := absf(positions[k + 2] - positions[k + 1]) / maxf(us[k + 1] / 1e6, 1e-4)
		if before > STALL_SPEED and after > STALL_SPEED:
			stalls += 1
	return stalls


## Uma linha legível do resumo, para logs e o relatório do benchmark.
static func describe(s: Dictionary) -> String:
	var line := "%d quadros, média %.2f ms (%.0f fps), p95 %.2f, p99 %.2f, pior %.1f ms, >20 ms: %d, >33 ms: %d" % [
			int(s.get("frames", 0)), float(s.get("avg_ms", 0.0)), float(s.get("fps", 0.0)),
			float(s.get("p95_ms", 0.0)), float(s.get("p99_ms", 0.0)), float(s.get("max_ms", 0.0)),
			int(s.get("over_20", 0)), int(s.get("over_33", 0))]
	if s.has("stalls"):
		line += ", travadas %d em %.0f px" % [int(s["stalls"]), float(s.get("distance", 0.0))]
	return line
