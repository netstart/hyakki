class_name WeaponSfx
extends RefCounted
## Som de lançamento das armas e do golpe da lanterna, em camadas ("cues").
## Cada arma de data/weapons.json diz o seu em "sfx": {"launch": cue, "impact": hit_*}; a
## evolução tem cue próprio, mais encorpado. Uma camada é [id, tom, variação de tom, dB]:
## o id é um grupo de AudioManager.VARIANTS ou um arquivo de assets/audio/sfx.
## Limites: cada cue tem um intervalo mínimo em tempo real (GAP_MS; as armas de rajada usam
## mais), e o AudioManager ainda limita 4 vozes por som e 2/3 do pool para acertos, então
## 100 projéteis não saturam o pool. Os sorteios de tom são do AudioManager (fora da simulação).

const DEFAULT_GAP_MS := 45
## Mixagem de referência: lançamento entre -3 e -10 dB, acertos -13 a -16 dB (HitSounds.MIX),
## música no barramento próprio. Camadas de brilho e cauda ficam 8-12 dB abaixo do corpo.
const CUES := {
	# Lâminas: "shing" metálico + swish de ar; a Lâmina do Amanhecer soma um brilho de sino.
	"katana": {"layers": [["katana", 1.0, 0.06, -3.0], ["slash", 1.0, 0.08, -4.0]]},
	"dawn_blade": {"layers": [["katana", 0.96, 0.05, -3.0], ["slash", 0.95, 0.06, -4.0],
			["bell", 2.2, 0.04, -16.0]]},
	"katana_back": {"layers": [["whoosh", 0.88, 0.05, -10.0]]},
	"onikiri": {"layers": [["katana", 1.08, 0.05, -5.0], ["slash", 1.1, 0.08, -6.0]]},
	"onikiri_final": {"layers": [["katana", 0.9, 0.04, -3.0], ["slash", 0.92, 0.06, -4.0],
			["heavy_blade", 1.0, 0.05, -7.0]]},
	"dojigiri_final": {"layers": [["katana", 0.85, 0.04, -3.0], ["heavy_blade", 0.9, 0.05, -5.0],
			["slash", 0.88, 0.06, -5.0], ["bell", 1.6, 0.03, -18.0]]},
	"blade_back": {"layers": [["whoosh", 0.9, 0.05, -12.0]]},
	"hundred_blades": {"layers": [["heavy_blade", 1.15, 0.1, -9.0], ["slash", 1.1, 0.1, -9.0]],
			"gap": 300},
	# Projéteis: assobio giratório, arremesso seco, corda do arco, corrente.
	"shuriken": {"layers": [["shuriken_whirl", 1.0, 0.08, -6.0]], "gap": 70},
	"steel_storm": {"layers": [["shuriken_whirl", 1.15, 0.1, -7.0], ["metal_light", 1.7, 0.1, -17.0]],
			"gap": 90},
	"kunai": {"layers": [["kunai_throw", 1.0, 0.1, -5.0], ["draw_knife", 1.35, 0.08, -18.0]], "gap": 60},
	"thousand_needles": {"layers": [["kunai_throw", 1.2, 0.12, -6.0], ["suzu", 1.7, 0.08, -20.0]],
			"gap": 80},
	"yumi": {"layers": [["bow_twang", 1.0, 0.06, -5.0], ["arrow", 1.45, 0.06, -9.0]]},
	"hachiman_arrow": {"layers": [["bow_twang", 0.9, 0.05, -4.0], ["arrow", 1.3, 0.06, -8.0],
			["bell", 2.6, 0.03, -17.0]]},
	"hachiman_blast": {"layers": [["explosion", 0.9, 0.08, -10.0]], "gap": 120},
	"kusarigama": {"layers": [["chain_rattle", 1.0, 0.08, -5.0], ["whoosh", 0.8, 0.1, -10.0]]},
	"reaper_chain": {"layers": [["chain_rattle", 0.85, 0.08, -4.0], ["heavy_blade", 1.1, 0.06, -10.0]]},
	"hitodama": {"layers": [["spirit_flame", 1.0, 0.1, -7.0]]},
	"inverted_procession": {"layers": [["spirit_flame", 0.85, 0.1, -6.0], ["spirit", 1.2, 0.1, -14.0]]},
	# Papel e santuário.
	"ofuda": {"layers": [["ofuda_fan", 1.0, 0.06, -3.0], ["ofuda_cast", 1.0, 0.06, -8.0],
			["suzu", 1.0, 0.05, -13.0]]},
	"amaterasu_barrier": {"layers": [["ofuda_fan", 0.95, 0.06, -3.0], ["ofuda_cast", 1.1, 0.06, -7.0],
			["suzu", 0.9, 0.05, -11.0], ["j_furin", 1.0, 0.03, -14.0]]},
	"incense": {"layers": [["incense_pulse", 1.0, 0.08, -14.0]]},
	"temple_smoke": {"layers": [["incense_pulse", 0.9, 0.08, -13.0], ["bell", 1.6, 0.04, -22.0]]},
	"smoke_bomb": {"layers": [["smoke_pop", 1.0, 0.1, -7.0]], "gap": 90},
	"poison_mist": {"layers": [["smoke_pop", 0.85, 0.1, -6.0], ["water", 0.7, 0.1, -14.0]], "gap": 90},
	# Tambor.
	"taiko": {"layers": [["taiko", 1.0, 0.05, -4.0], ["impact", 0.7, 0.05, -9.0]]},
	"ritual_thunder": {"layers": [["taiko", 0.94, 0.04, -3.0], ["j_taiko_rim", 1.0, 0.04, -9.0],
			["thunder", 0.8, 0.05, -10.0]]},
	# Raios: estalo elétrico; o trovão sai à parte (THUNDER_GAP nas armas).
	"raijin": {"layers": [["zap", 1.05, 0.1, -8.0]], "gap": 60},
	"raijin_fury": {"layers": [["zap", 0.92, 0.1, -7.0], ["chain_zap", 1.0, 0.1, -12.0]], "gap": 60},
	"raijin_thunder": {"layers": [["thunder", 1.35, 0.08, -11.0]], "gap": 500},
	"kaminari": {"layers": [["zap", 0.6, 0.05, -15.0]]},
	"takemikazuchi": {"layers": [["zap", 0.5, 0.05, -14.0], ["chain_zap", 0.7, 0.05, -18.0]]},
	"kaminari_strike": {"layers": [["thunder", 1.0, 0.08, -4.0]], "gap": 120},
	"takemikazuchi_strike": {"layers": [["thunder", 0.85, 0.06, -3.0], ["explosion", 0.7, 0.05, -10.0]],
			"gap": 120},
	"inazuma": {"layers": [["zap", 1.0, 0.08, -6.0]]},
	"raikiri": {"layers": [["zap", 0.85, 0.08, -5.0], ["katana", 1.3, 0.06, -12.0]]},
	"chain_link": {"layers": [["chain_zap", 1.0, 0.05, -10.0]], "gap": 35},
	# Vento.
	"fujin_fan": {"layers": [["wind_gust", 1.0, 0.08, -5.0], ["ofuda_fan", 0.8, 0.05, -12.0]]},
	"fujin_hurricane": {"layers": [["wind_gust", 0.7, 0.05, -4.0], ["whoosh", 0.6, 0.05, -9.0]]},
	"fujin_raijin": {"layers": [["wind_gust", 0.6, 0.05, -4.0], ["thunder", 0.9, 0.05, -8.0],
			["zap", 0.8, 0.05, -10.0]]},
	# Golpe da lanterna: impacto comum + a assinatura de cada guardiã.
	"ult": {"layers": [["ult_burst", 1.0, 0.0, -2.0]]},
	"ult_dawn_flash": {"layers": [["explosion", 0.8, 0.0, -6.0], ["j_gong", 1.0, 0.0, -6.0]]},
	"ult_shadow_clone": {"layers": [["whoosh2", 0.7, 0.0, -6.0], ["smoke_pop", 0.8, 0.0, -8.0]]},
	"ult_kagura": {"layers": [["heal", 1.0, 0.0, -4.0], ["suzu", 0.8, 0.0, -8.0], ["wings", 0.9, 0.0, -10.0]]},
	"ult_temple_bell": {"layers": [["j_temple_bell", 1.0, 0.0, 0.0]]},
	"ult_arrow_rain": {"layers": [["bow_twang", 0.8, 0.0, -4.0], ["launch", 0.9, 0.0, -6.0]]},
	"ult_oni_awakening": {"layers": [["taiko", 0.85, 0.0, -2.0], ["heavy_blade", 0.7, 0.0, -6.0]]},
	"ult_living_forge": {"layers": [["fire", 0.8, 0.0, -4.0], ["j_gong", 1.2, 0.0, -9.0]]},
}

static var _last_ms: Dictionary = {}


## Camadas do cue (vazio se não existir).
static func layers(cue: String) -> Array:
	return (CUES.get(cue, {}) as Dictionary).get("layers", [])


## Cue de lançamento da arma (linha de data/weapons.json); "" sem som próprio.
static func launch_cue(weapon: Dictionary) -> String:
	return String((weapon.get("sfx", {}) as Dictionary).get("launch", ""))


## Toca o cue respeitando o intervalo mínimo. Devolve se tocou (testes). `pitch` e `db`
## multiplicam/somam em todas as camadas (ex.: a escala do combo, o volume por quantidade).
static func play(cue: String, pitch: float = 1.0, db: float = 0.0) -> bool:
	if not CUES.has(cue):
		push_warning("WeaponSfx: cue desconhecido '%s'" % cue)
		return false
	var now := Time.get_ticks_msec()
	var gap := int((CUES[cue] as Dictionary).get("gap", DEFAULT_GAP_MS))
	if now - int(_last_ms.get(cue, -100000)) < gap:
		return false
	_last_ms[cue] = now
	var audio := _audio()
	if audio == null:
		return true
	for layer: Array in layers(cue):
		audio.call("play", String(layer[0]), float(layer[1]) * pitch, float(layer[2]), float(layer[3]) + db)
	return true


## Lançamento da arma `weapon` (o cue do "sfx.launch" dela).
static func launch(weapon: Weapon, pitch: float = 1.0, db: float = 0.0) -> bool:
	return play(launch_cue(weapon.data), pitch, db)


## Testes: esquece os intervalos (para tocar o mesmo cue de novo no mesmo quadro).
static func reset_gaps() -> void:
	_last_ms.clear()


## AudioManager pela árvore (este script também carrega nos testes sem autoloads).
static func _audio() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null(^"AudioManager") if tree and tree.root else null
