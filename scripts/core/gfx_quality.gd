class_name GfxQuality
extends RefCounted
## Qualidade gráfica: o único lugar que decide quanto cada sistema visual pode gastar
## (partículas, clima, decoração, pós-processo, rastros, luzes, efeitos de UI...).
##
## Opção do jogador em Settings "graphics_quality": "auto" | "low" | "medium" | "high".
## Em "auto" vale o nível detectado no aparelho (detected_level()), menos os rebaixamentos
## que o monitor de FPS (GfxMonitor, criado pela HUD da partida) fez nesta sessão.
##
## Só funções estáticas; nada aqui mexe na simulação (o determinismo 1x/2x/3x não depende
## do nível). Uso típico num sistema visual:
##     var drops: int = GfxQuality.budget("weather_drops")
##     var glow := GfxQuality.pick(false, false, true)
##     Settings.changed.connect(func(k: String) -> void:
##         if k == GfxQuality.changed_signal_key(): _rebuild())
##
## Settings é lido pela árvore (/root/Settings), não pelo nome global do autoload: assim
## este script também roda nos testes sem autoloads (tests/run_tests.gd), onde vale o
## padrão "auto".

const LOW := 0
const MEDIUM := 1
const HIGH := 2
const KEY := "graphics_quality"
## Valores da opção, na ordem do ciclo da pausa.
const MODES: Array[String] = ["auto", "low", "medium", "high"]
const MODE_LEVEL := {"low": LOW, "medium": MEDIUM, "high": HIGH}

## Orçamentos por nível: [LOW, MEDIUM, HIGH].
const BUDGETS := {
	# Partículas vivas somadas na tela (armas, impactos, mortes, coletas).
	"particles_max": [250, 600, 1400],
	# Gotas/flocos/folhas do clima ao mesmo tempo.
	"weather_drops": [60, 160, 420],
	# Camadas de profundidade do clima (1 = só a camada principal; 3 = fundo, meio e frente).
	"weather_layers": [1, 2, 3],
	# Partículas de ambiente soltas no ar (vaga-lumes, poeira, pétalas, brasas).
	"ambient_motes": [8, 24, 60],
	# Multiplicador da densidade de decoração do terreno (moitas, pedras, flores).
	"decor_density": [0.7, 1.0, 1.25],
	# Grama e folhagem balançam com o vento.
	"grass_sway": [false, true, true],
	# Pós-processo de tela: vinheta e gradação de cor.
	"post_fx": [false, true, true],
	# Brilho (bloom/halo aditivo) em magias, chefes e luzes fortes.
	"glow": [false, false, true],
	# Sombras suaves (borda degradê) em vez de elipses duras.
	"soft_shadows": [false, true, true],
	# Detalhe dos efeitos de inimigos: 0 = mínimo, 1 = normal, 2 = completo (auras, faíscas).
	"enemy_fx": [0, 1, 2],
	# Detalhe dos efeitos de armas: 0 = mínimo, 1 = normal, 2 = completo.
	"weapon_fx": [0, 1, 2],
	# Multiplicador da intensidade do tremor de tela.
	"screen_shake": [0.6, 1.0, 1.0],
	# Pontos de rastro por projétil/golpe (0 = sem rastro).
	"trail_points": [0, 6, 14],
	# Luzes dinâmicas (PointLight2D/halos) ao mesmo tempo.
	"lights_max": [4, 10, 24],
	# Respingos (chuva no chão, água, sangue de yokai).
	"splashes": [false, true, true],
	# Efeitos das telas de UI: 0 = estático, 1 = brilho leve, 2 = brilho e partículas.
	"ui_fx": [0, 1, 2],
}

## -1 = sem override (testes usam set_override).
static var _override: int = -1
## -1 = ainda não detectado.
static var _detected: int = -1
## Níveis tirados pelo monitor adaptativo nesta sessão (só no modo "auto"; nunca volta).
static var _auto_drops: int = 0


# --- Nível ---------------------------------------------------------------------------

## Nível efetivo (LOW, MEDIUM ou HIGH).
static func level() -> int:
	if _override >= 0:
		return _override
	return resolve(mode(), detected_level(), _auto_drops)


static func is_high() -> bool:
	return level() == HIGH


static func is_low() -> bool:
	return level() == LOW


## Um dos três valores, conforme o nível efetivo.
static func pick(low: Variant, medium: Variant, high: Variant) -> Variant:
	match level():
		LOW:
			return low
		MEDIUM:
			return medium
	return high


## Orçamento `key` (ver BUDGETS) no nível efetivo; null se a chave não existir.
static func budget(key: String) -> Variant:
	return budget_at(key, level())


static func budget_at(key: String, at_level: int) -> Variant:
	if not BUDGETS.has(key):
		push_warning("GfxQuality: orçamento desconhecido '%s'" % key)
		return null
	return (BUDGETS[key] as Array)[clampi(at_level, LOW, HIGH)]


## Chave que Settings.changed emite quando a qualidade muda (opção ou rebaixamento automático).
static func changed_signal_key() -> String:
	return KEY


## Opção escolhida ("auto", "low", "medium" ou "high").
static func mode() -> String:
	var settings := _settings()
	var value := "auto" if settings == null else str(settings.call("get_value", KEY))
	return value if value in MODES else "auto"


## Regra pura: nível efetivo para uma opção, o nível detectado e os rebaixamentos da sessão.
static func resolve(p_mode: String, detected: int, drops: int = 0) -> int:
	if MODE_LEVEL.has(p_mode):
		return int(MODE_LEVEL[p_mode])
	return clampi(detected - drops, LOW, HIGH)


## Próxima opção do ciclo da pausa: Auto → Baixa → Média → Alta → Auto.
static func next_mode(p_mode: String) -> String:
	var i := MODES.find(p_mode)
	return MODES[(i + 1) % MODES.size()]


## Nome traduzido de um nível ("Baixa", "Média", "Alta").
static func level_name(p_level: int) -> String:
	match p_level:
		LOW:
			return TranslationServer.translate("options.gfx_low")
		MEDIUM:
			return TranslationServer.translate("options.gfx_medium")
	return TranslationServer.translate("options.gfx_high")


## Texto de uma opção: "Baixa"/"Média"/"Alta", ou "Auto (Alta)" com o nível que vale em auto.
static func mode_label(p_mode: String) -> String:
	if MODE_LEVEL.has(p_mode):
		return level_name(int(MODE_LEVEL[p_mode]))
	return TranslationServer.translate("options.gfx_auto_level") % level_name(
			resolve("auto", detected_level(), _auto_drops))


static func set_override(p_level: int) -> void:
	_override = clampi(p_level, LOW, HIGH)


static func clear_override() -> void:
	_override = -1


# --- Detecção ------------------------------------------------------------------------

## Nível que o aparelho aguenta, detectado uma vez por sessão.
static func detected_level() -> int:
	if _detected < 0:
		var memory: Dictionary = OS.get_memory_info()
		_detected = classify(OS.has_feature("mobile"), OS.get_processor_count(),
				int(memory.get("physical", -1)), RenderingServer.get_video_adapter_name())
	return _detected


## Heurística pura. Desktop → HIGH. Celular: >= 8 núcleos e >= 6 GB → HIGH; >= 6 núcleos →
## MEDIUM; senão LOW. GPUs móveis antigas conhecidas (Mali-4xx/T, Adreno 3xx/4xx/50x,
## PowerVR SGX) ficam no máximo em LOW; memória desconhecida (-1) não conta como 6 GB.
static func classify(mobile: bool, cores: int, memory_bytes: int, adapter: String) -> int:
	if not mobile:
		return HIGH
	var result := LOW
	if cores >= 8 and memory_bytes >= 6 * 1024 * 1024 * 1024:
		result = HIGH
	elif cores >= 6:
		result = MEDIUM
	var gpu := adapter.to_lower()
	for weak: String in ["mali-4", "mali-t", "adreno (tm) 3", "adreno (tm) 4", "adreno (tm) 50", "powervr sgx"]:
		if gpu.contains(weak):
			return LOW
	return result


# --- Ajuste adaptativo (modo "auto") ---------------------------------------------------

## Rebaixa um nível na sessão (chamado pelo GfxMonitor). Só no modo "auto" e acima de LOW.
## Avisa os sistemas por Settings.changed(changed_signal_key()). Devolve se rebaixou.
static func auto_downgrade() -> bool:
	if mode() != "auto" or level() == LOW or _override >= 0:
		return false
	_auto_drops += 1
	var settings := _settings()
	if settings != null:
		settings.emit_signal("changed", KEY)
	return true


static func auto_drops() -> int:
	return _auto_drops


## Testes: fixa o nível "detectado" (simula outro aparelho).
static func set_detected(p_level: int) -> void:
	_detected = clampi(p_level, LOW, HIGH)


## Testes: esquece os rebaixamentos e a detecção.
static func reset_session() -> void:
	_auto_drops = 0
	_detected = -1


static func _settings() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(^"Settings")
