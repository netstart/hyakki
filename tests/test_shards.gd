extends RefCounted
## Fatias da integração (--shard=k/N, tools/run_checks): quais suítes cada processo roda.
## As suítes de layout (as que percorrem DeviceProfiles.layout_cases()) rodam em toda fatia, cada
## uma só com a parte dos casos (resolução × idioma × furo) daquela fatia; as outras vão inteiras
## para uma fatia só, repartidas pelo custo (a mais cara primeiro para a fatia menos carregada).
## A união das N fatias é sempre o conjunto completo: check_partition confere isso para N = 1..16
## e coverage_line imprime o que cada fatia rodou, para o run_checks conferir a união de verdade.

const DeviceProfiles := preload("res://tests/device_profiles.gd")
## Custo de uma suíte sem medida em SUITE_MS (ms).
const DEFAULT_MS := 500
## Sufixo da parte sem layout de uma suíte de layout.
const REST := ".resto"
## Maior N conferido por check_partition.
const MAX_SHARDS := 16


## Parte sem layout de cada suíte de layout ("<suíte>.resto", repartida como as outras suítes): se roda
## nesta fatia. Sem entrada (runner sozinho, sem fatias), roda.
static var _rest: Dictionary = {}


## Marca, para cada suíte de layout, se a parte sem layout dela ("<nome>.resto") cabe a esta fatia.
static func set_rest(mine: Dictionary, names: Array[StringName]) -> void:
	_rest.clear()
	for name: StringName in names:
		var key := String(name)
		if key.ends_with(REST):
			_rest[StringName(key.trim_suffix(REST))] = mine.has(name)


## A suíte de layout `suite` roda nesta fatia a parte que não percorre os casos de layout?
static func runs_rest(suite: StringName) -> bool:
	return bool(_rest.get(suite, true))


## Nomes das suítes que a fatia `shard` (Vector2i(k, N)) roda.
static func assign(names: Array[StringName], layout: Array[bool], costs: Dictionary, shard: Vector2i) -> Dictionary:
	var owner := owners(names, layout, costs, shard.y)
	var mine := {}
	for i: int in names.size():
		if owner[i] < 0 or owner[i] == shard.x - 1:
			mine[names[i]] = true
	return mine


## Fatia (0..n-1) de cada suíte; -1 = suíte de layout (roda em todas). Distribuição gulosa pelo custo:
## a suíte mais cara vai para a fatia com menos custo somado (empate: a de menor índice).
static func owners(names: Array[StringName], layout: Array[bool], costs: Dictionary, n: int) -> Array[int]:
	var owner: Array[int] = []
	owner.resize(names.size())
	var order: Array[int] = []
	for i: int in names.size():
		owner[i] = -1
		if not layout[i]:
			order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		var ca := int(costs.get(names[a], DEFAULT_MS))
		var cb := int(costs.get(names[b], DEFAULT_MS))
		return ca > cb or (ca == cb and a < b))
	var sums: Array[int] = []
	sums.resize(maxi(1, n))
	sums.fill(0)
	for i: int in order:
		var best := 0
		for k: int in range(1, sums.size()):
			if sums[k] < sums[best]:
				best = k
		owner[i] = best
		sums[best] += int(costs.get(names[i], DEFAULT_MS))
	return owner


## Para N = 1..MAX_SHARDS: toda suíte sem layout cai em exatamente uma fatia, as de layout em todas, e
## as partes de layout_units() e das resoluções (DeviceProfiles.shard_range) cobrem tudo sem buraco
## nem repetição.
static func check_partition(names: Array[StringName], layout: Array[bool], costs: Dictionary, units: int,
		check: Callable) -> void:
	for n: int in range(1, MAX_SHARDS + 1):
		var hits: Array[int] = []
		hits.resize(names.size())
		hits.fill(0)
		var next := 0
		var next_res := 0
		var ranges_ok := true
		for k: int in range(1, n + 1):
			var mine := assign(names, layout, costs, Vector2i(k, n))
			for i: int in names.size():
				if mine.has(names[i]):
					hits[i] += 1
			var part := DeviceProfiles.shard_range(units, Vector2i(k, n))
			ranges_ok = ranges_ok and part.x == next and part.y >= part.x
			next = part.y
			# Resoluções (DeviceProfiles.shard_resolutions, para quem percorre RESOLUTIONS).
			var res := DeviceProfiles.shard_range(DeviceProfiles.RESOLUTIONS.size(), Vector2i(k, n))
			ranges_ok = ranges_ok and res.x == next_res and res.y >= res.x
			next_res = res.y
		var suites_ok := true
		for i: int in names.size():
			suites_ok = suites_ok and hits[i] == (n if layout[i] else 1)
		ranges_ok = ranges_ok and next_res == DeviceProfiles.RESOLUTIONS.size()
		check.call(suites_ok and ranges_ok and next == units,
				"Fatias: com %d fatia(s) a união é o conjunto completo (suítes %s, casos 0..%d de %d)", [n,
				hits, next, units])


## Linha "COBERTURA k/N ..." que a fatia imprime: suítes rodadas, todas as suítes e a parte dos casos.
static func coverage_line(shard: Vector2i, mine: Dictionary, names: Array[StringName], units: int) -> String:
	var ran: PackedStringArray = []
	var all: PackedStringArray = []
	for name: StringName in names:
		all.append(String(name))
		if mine.has(name):
			ran.append(String(name))
	var part := DeviceProfiles.shard_range(units, shard)
	return "COBERTURA %d/%d casos=%d-%d/%d suites=%s todas=%s" % [shard.x, shard.y, part.x, part.y, units,
			",".join(ran), ",".join(all)]
