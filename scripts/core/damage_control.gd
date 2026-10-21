class_name DamageControl
extends RefCounted
## Controle do dano recebido pela guardiã (plano 4.15): uma só porta de entrada, regras
## fixas e registro por fonte. Sem nó e sem autoload, para os testes de regras.
##
## Ordem das regras: invencibilidade → armadura (mín. 1) → modo Brisa → teto por golpe →
## teto por janela. Golpes letais (Shinigami, cenários de teste) passam por cima dos tetos.

const INVULN_TIME := 0.5
## Nenhum golpe tira mais que esta fração do HP máximo (exceto letais).
const HIT_CAP := 0.34
## Na janela de WINDOW segundos, no máximo WINDOW_CAP do HP máximo: ser cercado ou pegar
## explosões sobrepostas nunca mata de uma vez (plano 8.7.2 e 15.2).
const WINDOW := 2.0
const WINDOW_CAP := 0.45
const LETHAL := 9999.0
const BRISA_MULT := 0.6
const UNKNOWN := &"unknown"

var total: float = 0.0
var hits: int = 0
var biggest: float = 0.0
## Golpes que chegaram durante a invencibilidade.
var blocked: int = 0
## Dano tirado pela armadura e pelos tetos.
var absorbed: float = 0.0
var capped: float = 0.0
## fonte → {"damage", "hits", "max"}
var by_source: Dictionary = {}
## Dano por minuto de jogo (índice = minuto).
var per_minute := PackedFloat32Array()
var last_source: StringName = UNKNOWN

var _window_times := PackedFloat32Array()
var _window_amounts := PackedFloat32Array()


func reset() -> void:
	total = 0.0
	hits = 0
	biggest = 0.0
	blocked = 0
	absorbed = 0.0
	capped = 0.0
	by_source.clear()
	per_minute = PackedFloat32Array()
	last_source = UNKNOWN
	_window_times = PackedFloat32Array()
	_window_amounts = PackedFloat32Array()


## Dano final de um golpe já fora da invencibilidade; 0 quando os tetos absorvem tudo.
func resolve(amount: float, armor: float, max_hp: float, brisa: bool, now: float) -> float:
	if amount >= LETHAL:
		return amount
	var after_armor := maxf(1.0, amount - armor)
	var final := after_armor * (BRISA_MULT if brisa else 1.0)
	absorbed += maxf(0.0, amount - after_armor)
	var limit := minf(max_hp * HIT_CAP, max_hp * WINDOW_CAP - window_sum(now))
	if final > limit:
		capped += final - maxf(limit, 0.0)
		final = maxf(limit, 0.0)
	return final


## Soma do dano recebido nos últimos WINDOW segundos.
func window_sum(now: float) -> float:
	while not _window_times.is_empty() and now - _window_times[0] >= WINDOW:
		_window_times.remove_at(0)
		_window_amounts.remove_at(0)
	var sum := 0.0
	for amount: float in _window_amounts:
		sum += amount
	return sum


func record(source: StringName, amount: float, now: float) -> void:
	if source == &"":
		source = UNKNOWN
	if amount <= 0.0:
		return
	last_source = source
	total += amount
	hits += 1
	biggest = maxf(biggest, amount)
	_window_times.append(now)
	_window_amounts.append(amount)
	var row: Dictionary = by_source.get(source, {"damage": 0.0, "hits": 0, "max": 0.0})
	row["damage"] = float(row["damage"]) + amount
	row["hits"] = int(row["hits"]) + 1
	row["max"] = maxf(float(row["max"]), amount)
	by_source[source] = row
	var minute := int(now / 60.0)
	if per_minute.size() <= minute:
		per_minute.resize(minute + 1)
	per_minute[minute] += amount


## Fontes ordenadas da que mais feriu para a que menos feriu.
func top_sources(count: int = 3) -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in by_source:
		ids.append(id)
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return float(by_source[a]["damage"]) > float(by_source[b]["damage"]))
	return ids.slice(0, count)


func summary() -> Dictionary:
	var sources := {}
	for id: StringName in by_source:
		sources[String(id)] = (by_source[id] as Dictionary).duplicate()
	return {"total": total, "hits": hits, "biggest": biggest, "blocked": blocked,
			"absorbed": absorbed, "capped": capped, "cause": String(last_source),
			"top": Array(top_sources()).map(func(s: StringName) -> String: return String(s)),
			"per_minute": Array(per_minute), "sources": sources}


## Volta ao estado salvo por summary() (partida suspensa, plano 10.11).
func restore(s: Dictionary) -> void:
	reset()
	total = float(s.get("total", 0.0))
	hits = int(s.get("hits", 0))
	biggest = float(s.get("biggest", 0.0))
	blocked = int(s.get("blocked", 0))
	absorbed = float(s.get("absorbed", 0.0))
	capped = float(s.get("capped", 0.0))
	last_source = StringName(s.get("cause", UNKNOWN))
	per_minute = PackedFloat32Array(s.get("per_minute", []))
	var sources: Dictionary = s.get("sources", {})
	for id: String in sources:
		var row: Dictionary = sources[id]
		by_source[StringName(id)] = {"damage": float(row.get("damage", 0.0)), "hits": int(row.get("hits", 0)),
				"max": float(row.get("max", 0.0))}


## Linha para o bot e para o balanceamento (plano 14.3 e 15.4).
func report_line() -> String:
	var minutes: PackedStringArray = []
	for amount: float in per_minute:
		minutes.append(str(roundi(amount)))
	var sources: PackedStringArray = []
	for id: StringName in top_sources(5):
		var row: Dictionary = by_source[id]
		sources.append("%s:%d/%d" % [id, roundi(float(row["damage"])), int(row["hits"])])
	return ("DANO total=%d golpes=%d maior=%.1f bloqueados=%d armadura=%.0f teto=%.0f causa=%s"
			+ " por_minuto=[%s] fontes=[%s]") % [roundi(total), hits, biggest, blocked, absorbed, capped,
			last_source, ",".join(minutes), " ".join(sources)]
