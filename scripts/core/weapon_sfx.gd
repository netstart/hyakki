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
	# Habilidades dos guardiões (data/abilities.json): "ab_<id>" no lançamento e "ab_<id>_hit"
	# no impacto/fim. A assinatura de cada uma é um som a_* (tools/gen_ability_sfx.py, sempre
	# com canal) somado aos grupos das armas; a voz do guardião toca à parte (AbilitySystem).
	# Aki: luz e fogo da Ordem.
	"ab_dawn_step": {"layers": [["a_dash", 1.0, 0.05, -4.0], ["slash", 1.1, 0.06, -6.0],
			["bell", 2.4, 0.03, -16.0]]},
	"ab_dawn_step_hit": {"layers": [["hit_blade", 1.05, 0.08, -12.0]], "gap": 60},
	"ab_lantern_wall": {"layers": [["a_light_ring", 1.0, 0.03, -4.0], ["spirit_flame", 0.8, 0.05, -10.0],
			["j_furin", 1.0, 0.03, -14.0]]},
	"ab_lantern_wall_hit": {"layers": [["hit_fire", 1.1, 0.08, -15.0]], "gap": 120},
	"ab_century_flame": {"layers": [["spirit_flame", 0.9, 0.05, -6.0], ["whoosh", 0.8, 0.05, -9.0]]},
	"ab_century_flame_hit": {"layers": [["a_fire_column", 1.0, 0.04, -2.0], ["explosion", 0.8, 0.05, -8.0],
			["taiko", 0.8, 0.03, -10.0]], "gap": 200},
	# Kenta: sombra, fumaça e ferro.
	"ab_shadow_step": {"layers": [["teleport", 1.15, 0.05, -5.0], ["whoosh", 1.2, 0.08, -8.0],
			["smoke_pop", 1.1, 0.08, -10.0]]},
	"ab_shadow_step_hit": {"layers": [["hit_blade", 1.1, 0.1, -13.0]], "gap": 60},
	"ab_kawarimi": {"layers": [["smoke_pop", 0.9, 0.06, -4.0], ["prop_break", 1.1, 0.06, -8.0],
			["whoosh", 1.3, 0.05, -12.0]]},
	"ab_kawarimi_hit": {"layers": [["explosion", 0.95, 0.06, -4.0], ["prop_break", 0.8, 0.05, -9.0],
			["smoke_pop", 0.8, 0.05, -10.0]], "gap": 200},
	"ab_makibishi": {"layers": [["a_caltrops", 1.0, 0.05, -4.0], ["kunai_throw", 1.0, 0.08, -7.0],
			["shuriken_whirl", 1.2, 0.08, -14.0]]},
	"ab_makibishi_hit": {"layers": [["hit_projectile", 1.3, 0.1, -14.0]], "gap": 80},
	# Hana: gohei, barreira e selo de papel.
	"ab_harae": {"layers": [["ofuda_fan", 0.9, 0.05, -3.0], ["wind_gust", 1.3, 0.06, -8.0],
			["suzu", 1.1, 0.05, -11.0]]},
	"ab_harae_hit": {"layers": [["hit_wind", 1.0, 0.08, -13.0]], "gap": 60},
	"ab_kekkai": {"layers": [["a_barrier", 1.0, 0.03, -4.0], ["suzu", 0.9, 0.04, -9.0],
			["j_furin", 0.9, 0.03, -14.0]]},
	"ab_kekkai_hit": {"layers": [["hit_area", 1.1, 0.08, -16.0]], "gap": 150},
	"ab_grandmother_seal": {"layers": [["paper_flutter", 1.0, 0.06, -4.0], ["ofuda_fan", 1.1, 0.05, -6.0],
			["ofuda_cast", 0.9, 0.05, -8.0]]},
	"ab_grandmother_seal_hit": {"layers": [["a_seal", 1.0, 0.03, -3.0], ["j_gong", 1.3, 0.03, -10.0],
			["bell", 1.8, 0.03, -16.0]], "gap": 200},
	# Goro: bronze, cajado de argolas e mantra.
	"ab_diamond_body": {"layers": [["a_diamond", 1.0, 0.03, -4.0], ["j_gong", 0.8, 0.03, -10.0],
			["powerup", 0.8, 0.03, -14.0]]},
	"ab_diamond_body_hit": {"layers": [["metal_light", 0.9, 0.08, -14.0]], "gap": 120},
	"ab_shakujo": {"layers": [["a_shakujo", 1.0, 0.04, -3.0], ["taiko", 0.9, 0.04, -6.0],
			["impact", 0.7, 0.04, -10.0]]},
	"ab_shakujo_hit": {"layers": [["hit_area", 0.9, 0.08, -13.0]], "gap": 100},
	"ab_master_mantra": {"layers": [["a_mantra", 1.0, 0.02, -4.0], ["j_temple_bell", 1.1, 0.02, -14.0]]},
	"ab_master_mantra_hit": {"layers": [["a_mantra", 1.05, 0.03, -6.0], ["incense_pulse", 0.8, 0.05, -12.0]],
			"gap": 300},
	# Rin: flecha que canta, armadilha e o salto.
	"ab_hamaya": {"layers": [["a_holy_arrow", 1.0, 0.04, -4.0], ["bow_twang", 0.95, 0.05, -5.0],
			["bell", 2.6, 0.03, -16.0]]},
	"ab_hamaya_hit": {"layers": [["hit_projectile", 0.9, 0.08, -12.0]], "gap": 60},
	"ab_hunting_trap": {"layers": [["a_trap", 0.75, 0.04, -9.0], ["chain_rattle", 1.4, 0.06, -15.0]]},
	"ab_hunting_trap_hit": {"layers": [["a_trap", 1.0, 0.05, -4.0], ["hit_projectile", 0.8, 0.08, -11.0]],
			"gap": 60},
	"ab_swallow_leap": {"layers": [["whoosh", 1.1, 0.06, -6.0], ["bow_twang", 1.05, 0.05, -6.0],
			["arrow", 1.4, 0.08, -9.0], ["a_holy_arrow", 1.3, 0.04, -16.0]]},
	# Tora: bigorna, corrente e vapor.
	"ab_anvil_hammer": {"layers": [["a_anvil", 1.0, 0.04, -3.0], ["taiko", 0.7, 0.04, -8.0],
			["hit_fire", 1.2, 0.08, -12.0]]},
	"ab_chain_pull": {"layers": [["a_chain_spin", 1.0, 0.04, -4.0], ["chain_rattle", 0.9, 0.06, -7.0]]},
	"ab_chain_pull_hit": {"layers": [["explosion", 0.9, 0.05, -5.0], ["heavy_blade", 0.8, 0.05, -10.0],
			["a_anvil", 0.7, 0.04, -12.0]], "gap": 200},
	"ab_quench": {"layers": [["a_steam", 1.0, 0.03, -3.0], ["explosion", 0.7, 0.04, -8.0],
			["a_anvil", 1.15, 0.03, -13.0]]},
	# Yuki: garras, rugido e a lâmina oni.
	"ab_oni_claw": {"layers": [["whoosh", 0.85, 0.06, -5.0], ["wings", 0.8, 0.05, -14.0]]},
	"ab_oni_claw_hit": {"layers": [["a_claw", 1.0, 0.05, -3.0], ["hit_blade", 0.85, 0.08, -9.0],
			["impact", 0.8, 0.05, -12.0]], "gap": 120},
	"ab_oni_roar": {"layers": [["a_oni_roar", 1.0, 0.03, -2.0], ["taiko", 0.75, 0.03, -7.0],
			["midboss_roar", 1.1, 0.05, -14.0]]},
	"ab_onikiri_whirl": {"layers": [["a_whirl", 1.0, 0.03, -4.0], ["heavy_blade", 0.9, 0.05, -7.0],
			["katana", 0.8, 0.05, -12.0]]},
	"ab_onikiri_whirl_hit": {"layers": [["hit_blade", 0.9, 0.1, -14.0]], "gap": 140},
	# Retorno da interface das habilidades: sem energia (recusa) e pronta de novo (discreto).
	"ab_denied": {"layers": [["a_denied", 1.0, 0.0, -6.0]], "gap": 250},
	"ab_ready": {"layers": [["a_ready", 1.0, 0.02, -12.0]], "gap": 200},
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
