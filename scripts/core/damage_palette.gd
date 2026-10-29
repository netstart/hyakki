class_name DamagePalette
extends RefCounted
## Paleta e regras dos números de dano (DamageNumbers, via FxLayer.add_number). Fonte única das
## cores, formas, tamanhos, animações e limites anti-poluição, sem nó e sem autoload, para os
## testes (tests/damage_number_tests.gd).
##
## Duas famílias que nunca se confundem:
## - dano causado no inimigo: tons quentes (branco quente → ouro → carmim), sobe;
## - dano recebido pela guardiã: violeta/magenta com contorno roxo, prefixo "-", desce e treme;
## - cura da guardiã: verde com "+", sobe devagar.
##
## Tipos e regras:
## - HIT: golpe comum.
## - HIGH: golpe alto = pelo menos HIGH_RATIO × a média móvel dos golpes diretos comuns da
##   partida (next_mean). Média adaptativa: no começo a Katana (10) não é "alto" perto da Kunai (6),
##   mas o Kaminari (30) é; no fim do jogo, o Takemikazuchi (110) se destaca do Steel Storm (20).
##   Críticos e dano contínuo não entram na média (não puxam a referência).
## - CRIT: crítico (sempre vence os outros): carmim, "!" e a animação própria do corte (crit_*).
## - DOT: tique de dano contínuo (poças, furacões, aura do incenso): azul-gelo, contorno fino;
##   tiques no mesmo inimigo somam num só número por segundo, que vai subindo (DOT_MERGE_WINDOW).
## - TAKEN / TAKEN_HEAVY: recebido; pesado = pelo menos HEAVY_FRACTION do HP máximo (chefes,
##   explosões, golpes letais), com negrito, inchaço curto e tremor maior.
## - HEAL: cura vinda de item, carta de cura ou especial (roubo de vida contínuo não mostra).
##
## Tamanho proporcional ao dano (size_step): degraus discretos da fonte pixel (SIZES), pelo log2
## da razão entre o golpe e a média móvel (a mesma do "alto"), com teto. Recebido: pela fração do
## HP máximo. Contínuo e cura ficam no tamanho base.
##
## Animação do crítico (crit_motion), ~0,75 s, diferente de todas as outras:
##   1. HOLD (congela): só um brilho branco no ponto do golpe, o número ainda não aparece;
##   2. SLAM: o número bate de cima em degraus inteiros de escala (3x → 2x → 1x, pixel nítido),
##      branco virando carmim, inclinado e endireitando num estalo, com o risco diagonal de katana
##      atrás, faíscas radiais e um anel de choque;
##   3. HANG: parado, sem deriva (o resto dos números sobe);
##   4. SHATTER: dispara para cima e some, soltando estilhaços.
##   Na qualidade Baixa: o mesmo HOLD/SLAM/HANG/SHATTER e o risco da katana, sem faíscas, anel
##   nem estilhaços.
##
## Anti-poluição: no máximo MAX_ON_SCREEN números vivos; cheio, o comum/contínuo novo é
## descartado e os importantes (alto, cura, crítico, recebido) tiram o mais velho de prioridade
## menor (crítico e recebido nunca saem primeiro). Golpes comuns seguidos no mesmo inimigo somam
## (MERGE_WINDOW), dano num lugar já cheio é descartado (LOCAL_MAX), no máximo MAX_CRITS críticos
## vivos e CRIT_BIG_MAX com o SLAM grande ao mesmo tempo, a vida encurta com a tela cheia
## (DENSE_LIFE_MIN), números sobrepostos se afastam (SPREAD_PX), nada entra na faixa da HUD
## (HUD_TOP) e o dano nos inimigos não cobre a guardiã (GUARD_CLEAR).
##
## Densidade adaptativa (pressão, como Diablo/MMOs e o "menos é mais" dos survivors-like): uma
## pressão suavizada de 0 a 1 sai dos inimigos vivos e dos números pedidos por segundo
## (raw_pressure, next_pressure) e vira um nível 0/1/2 com histerese (next_level). Subindo o
## nível: o comum encolhe (12 → 10 → dígitos 3×5 próprios) e some mais rápido (level_life);
## números perto e de valor parecido do mesmo tipo viram um só com contador "×N" (should_fold);
## golpes comuns abaixo de uma fração da média somem (insignificant). Crítico, recebido e cura nunca
## são escondidos por essas regras; crítico e recebido nem encolhem. No nível 0 (começo da
## partida) nada disso age. Valores grandes abreviam (12,3k / 1,2M, com a vírgula do idioma).
##
## Daltonismo (opção "colorblind"): paleta Okabe-Ito ordenada por luminância dentro de cada
## família, e cada tipo também tem uma forma própria (prefixo, sufixo, negrito, animação, direção
## e tremor), então nenhum depende só da cor (style_signature).

enum Kind { HIT, HIGH, CRIT, DOT, TAKEN, TAKEN_HEAVY, HEAL }
## Movimento de cada tipo (style "anim").
enum Anim { RISE, POP, CRIT, TICK, SINK, SINK_HEAVY, FLOAT }
## Fases da animação do crítico.
enum CritPhase { HOLD, SLAM, HANG, SHATTER, DONE }

## --- Densidade adaptativa ---
## Inimigos vivos que levam a pressão de 0 a 1 (início, fim).
const PRESSURE_ENEMIES := Vector2(100.0, 400.0)
## Números pedidos por segundo que levam a pressão de 0 a 1 (início, fim).
const PRESSURE_RATE := Vector2(30.0, 140.0)
## Suavização da pressão (s): sobe rápido, desce devagar (não pisca ao fim de uma onda).
const PRESSURE_RISE := 0.35
const PRESSURE_FALL := 1.5
## Suavização da taxa de números por segundo (s).
const RATE_SMOOTH := 0.5
## Histerese: sobe para o nível n+1 acima de LEVEL_UP[n], desce para n abaixo de LEVEL_DOWN[n].
const LEVEL_UP := [0.35, 0.7]
const LEVEL_DOWN := [0.22, 0.52]
## Escada de tamanhos (0 = dígitos 3×5 próprios, nítidos; a fonte pixel abaixo de 10 vira borrão).
const LADDER := [0, 10, 12, 16, 20, 24]
## Degraus que o comum e o contínuo descem por nível (alto e cura descem um a menos; crítico e
## recebido não descem).
const LEVEL_SHRINK := [0, 1, 2]
## Vida por nível (comum, contínuo e cura; o alto usa LEVEL_LIFE_HIGH; crítico e recebido inteiros).
const LEVEL_LIFE := [1.0, 0.7, 0.5]
const LEVEL_LIFE_HIGH := [1.0, 0.85, 0.7]
const MIN_LIFE := 0.25
## Juntar perto e parecido: raio (px) e diferença relativa máxima por nível (0 = desligado).
const FOLD_RADIUS := [0.0, 22.0, 36.0]
const FOLD_SHARE := [0.0, 0.15, 0.3]
## Limite de números vivos por nível (o MAX_ON_SCREEN vale sem pressão).
const LEVEL_CAP := [MAX_ON_SCREEN, 32, 24]
## Golpe comum abaixo desta fração da média móvel some, por nível.
const SIGNIF_SHARE := [0.0, 0.25, 0.5]
## A partir daqui o valor abrevia (12,3k; 1,2M).
const ABBREV_FROM := 10000
## Idiomas que escrevem a casa decimal com vírgula.
const COMMA_LOCALES := ["pt", "es", "de", "fr", "ru", "id"]

## Opção de cada tipo (Settings, padrão ligado; tela de Opções, abaixo de "damage_numbers"):
## desligar esconde só aquele tipo. O texto da linha é "options.<chave>".
const SETTING_KEYS := [
	"damage_show_hit", "damage_show_high", "damage_show_crit", "damage_show_dot",
	"damage_show_taken", "damage_show_taken_heavy", "damage_show_heal",
]
## Amostra mostrada ao lado de cada opção (na paleta em uso).
const SAMPLE_AMOUNTS := [9.0, 31.0, 24.0, 4.0, 6.0, 28.0, 30.0]

const HIGH_RATIO := 2.0
## Peso de cada golpe novo na média móvel (≈ os últimos 12 golpes).
const MEAN_WEIGHT := 0.08
const HEAVY_FRACTION := 0.15

## Tamanhos da fonte por degrau (o 0 é o tamanho de sempre). O teto vale também para o crítico.
const SIZES := [12, 16, 20, 24]
const MAX_STEP := 3

## Anti-poluição.
const MAX_ON_SCREEN := 40
## Críticos vivos ao mesmo tempo: o crítico só se destaca se for raro na tela; os além disto
## não aparecem (o golpe acontece igual, só sem número).
const MAX_CRITS := 8
## Golpes comuns no mesmo inimigo a menos disto do último somam no mesmo número.
const MERGE_WINDOW := 0.25
## Tiques contínuos no mesmo inimigo somam por 1 s a partir do primeiro (soma por alvo por segundo).
const DOT_MERGE_WINDOW := 1.0
## Um número que soma para de aceitar golpes depois desta idade (não sobe para sempre).
const MERGE_MAX_AGE := 1.0
## Fração da vida que sobra com a tela cheia (comum, alto, contínuo e cura).
const DENSE_LIFE_MIN := 0.55
## Afastamento vertical entre números que nasceriam um em cima do outro.
const SPREAD_PX := 11.0
## Quantos números recentes são conferidos para o afastamento e a densidade local.
const SPREAD_CHECK := 16
## Densidade local: com LOCAL_MAX números recentes de prioridade igual ou maior a menos de
## LOCAL_RADIUS px, o dano novo no inimigo ali é descartado (comum some no meio de comuns, crítico
## só no meio de críticos): a multidão em volta da guardiã não vira uma pilha de números.
const LOCAL_RADIUS := 36.0
const LOCAL_MAX := 4
## Críticos com o SLAM grande ao mesmo tempo; os outros fazem o crítico "mini" (sem crescer,
## mesmo HOLD, risco, HANG e SHATTER), para uma chuva de críticos não cobrir a tela.
const CRIT_BIG_MAX := 3
## Faixa do topo da tela (px lógicos) reservada à HUD.
const HUD_TOP := 26.0
## Caixa em volta da guardiã (meia largura, altura acima dos pés) que o dano nos inimigos evita.
const GUARD_CLEAR := Vector2(14.0, 28.0)

## Inchaço curto do alto e do recebido pesado (degraus de fonte a mais, por POP_TIME s).
const POP_TIME := 0.09
const POP_STEPS := 1
## Tremor dos números recebidos.
const SHAKE_TIME := 0.22

## Linha do tempo do crítico (segundos desde o golpe).
const CRIT_HOLD := 0.05
const CRIT_SLAM_END := 0.17
const CRIT_HANG_END := 0.5
const CRIT_LIFE := 0.75
## Inclinação inicial do SLAM (radianos), que endireita em degraus.
const CRIT_TILT := -0.16
## Quanto o crítico sobe no SHATTER (px).
const CRIT_RISE := 26.0

## Campos: fill, outline (cor do contorno), outline_px, prefix, suffix, bold (negrito de 1 px),
## anim (Anim), drift (px/s; negativo sobe), shake (px), life (s), priority (anti-poluição).
const NORMAL := [
	{"fill": Color("fff3dc"), "outline": Color("1b1008"), "outline_px": 3, "prefix": "", "suffix": "",
			"bold": false, "anim": Anim.RISE, "drift": -14.0, "shake": 0.0, "life": 0.6, "priority": 0},
	{"fill": Color("ffb52e"), "outline": Color("2a1400"), "outline_px": 3, "prefix": "", "suffix": "",
			"bold": true, "anim": Anim.POP, "drift": -16.0, "shake": 0.0, "life": 0.7, "priority": 1},
	{"fill": Color("ff3355"), "outline": Color("2b0010"), "outline_px": 3, "prefix": "", "suffix": "!",
			"bold": true, "anim": Anim.CRIT, "drift": 0.0, "shake": 0.0, "life": CRIT_LIFE, "priority": 3},
	{"fill": Color("a9dcff"), "outline": Color("0b1a2a"), "outline_px": 2, "prefix": "", "suffix": "",
			"bold": false, "anim": Anim.TICK, "drift": -10.0, "shake": 0.0, "life": 0.45, "priority": 0},
	{"fill": Color("c77dff"), "outline": Color("1e0630"), "outline_px": 3, "prefix": "-", "suffix": "",
			"bold": false, "anim": Anim.SINK, "drift": 12.0, "shake": 1.5, "life": 0.7, "priority": 3},
	{"fill": Color("e83cff"), "outline": Color("1a0026"), "outline_px": 3, "prefix": "-", "suffix": "",
			"bold": true, "anim": Anim.SINK_HEAVY, "drift": 9.0, "shake": 3.0, "life": 0.9, "priority": 3},
	{"fill": Color("5cf28a"), "outline": Color("052712"), "outline_px": 3, "prefix": "+", "suffix": "",
			"bold": false, "anim": Anim.FLOAT, "drift": -9.0, "shake": 0.0, "life": 0.8, "priority": 2},
]

## Okabe-Ito: luminância bem separada dentro de cada família; mesmas formas da paleta normal.
const COLORBLIND := [
	{"fill": Color("ffffff"), "outline": Color("101010"), "outline_px": 3, "prefix": "", "suffix": "",
			"bold": false, "anim": Anim.RISE, "drift": -14.0, "shake": 0.0, "life": 0.6, "priority": 0},
	{"fill": Color("f0e442"), "outline": Color("1a1600"), "outline_px": 3, "prefix": "", "suffix": "",
			"bold": true, "anim": Anim.POP, "drift": -16.0, "shake": 0.0, "life": 0.7, "priority": 1},
	{"fill": Color("e69f00"), "outline": Color("1f0e00"), "outline_px": 3, "prefix": "", "suffix": "!",
			"bold": true, "anim": Anim.CRIT, "drift": 0.0, "shake": 0.0, "life": CRIT_LIFE, "priority": 3},
	{"fill": Color("bbbbbb"), "outline": Color("101010"), "outline_px": 2, "prefix": "", "suffix": "",
			"bold": false, "anim": Anim.TICK, "drift": -10.0, "shake": 0.0, "life": 0.45, "priority": 0},
	{"fill": Color("9ad1f5"), "outline": Color("041828"), "outline_px": 3, "prefix": "-", "suffix": "",
			"bold": false, "anim": Anim.SINK, "drift": 12.0, "shake": 1.5, "life": 0.7, "priority": 3},
	{"fill": Color("3fa0f0"), "outline": Color("02101e"), "outline_px": 3, "prefix": "-", "suffix": "",
			"bold": true, "anim": Anim.SINK_HEAVY, "drift": 9.0, "shake": 3.0, "life": 0.9, "priority": 3},
	{"fill": Color("3fd9a8"), "outline": Color("02200f"), "outline_px": 3, "prefix": "+", "suffix": "",
			"bold": false, "anim": Anim.FLOAT, "drift": -9.0, "shake": 0.0, "life": 0.8, "priority": 2},
]


## Tipo de um golpe no inimigo. `mean` é a média móvel dos golpes diretos comuns (0 = sem média).
static func classify_hit(amount: float, crit: bool, dot: bool, mean: float) -> int:
	if crit:
		return Kind.CRIT
	if dot:
		return Kind.DOT
	if mean > 0.0 and amount >= mean * HIGH_RATIO:
		return Kind.HIGH
	return Kind.HIT


## Média móvel depois de um golpe do tipo `kind`. Só golpes diretos sem crítico contam.
static func next_mean(mean: float, amount: float, kind: int) -> float:
	if kind == Kind.CRIT or kind == Kind.DOT or amount <= 0.0:
		return mean
	if mean <= 0.0:
		return amount
	return lerpf(mean, amount, MEAN_WEIGHT)


## Tipo do dano recebido pela guardiã (já depois da armadura e dos tetos).
static func classify_taken(amount: float, max_hp: float) -> int:
	if max_hp > 0.0 and amount >= max_hp * HEAVY_FRACTION:
		return Kind.TAKEN_HEAVY
	return Kind.TAKEN


## Degrau de tamanho (0..MAX_STEP). `ref`: média móvel (dano causado) ou HP máximo (recebido).
## Causado: floor(log2(golpe / média)), então o dobro da média sobe um degrau, 4× dois, 8× três.
static func size_step(kind: int, amount: float, ref: float) -> int:
	match kind:
		Kind.DOT, Kind.HEAL:
			return 0
		Kind.TAKEN, Kind.TAKEN_HEAVY:
			if ref <= 0.0:
				return 0
			return clampi(floori(amount / (ref * HEAVY_FRACTION)), 0, 2)
	if ref <= 0.0 or amount <= ref:
		return 0
	return clampi(floori(log(amount / ref) / log(2.0)), 0, MAX_STEP)


static func font_size(step: int) -> int:
	return SIZES[clampi(step, 0, MAX_STEP)]


## Degraus de fonte a mais agora (inchaço curto do alto e do recebido pesado).
static func pop_steps(anim: int, age: float) -> int:
	if (anim == Anim.POP or anim == Anim.SINK_HEAVY) and age < POP_TIME:
		return POP_STEPS
	return 0


static func crit_phase(age: float) -> int:
	if age < CRIT_HOLD:
		return CritPhase.HOLD
	if age < CRIT_SLAM_END:
		return CritPhase.SLAM
	if age < CRIT_HANG_END:
		return CritPhase.HANG
	if age < CRIT_LIFE:
		return CritPhase.SHATTER
	return CritPhase.DONE


## Movimento do crítico: Vector4(escala inteira, inclinação, deslocamento vertical, opacidade).
## Escala 0 = ainda invisível (HOLD). Números grandes (degrau ≥ 2) batem de 2x, os outros de 3x;
## o crítico "mini" (`big` falso, além de CRIT_BIG_MAX) não cresce, só inclina e endireita.
## Vector4 é valor: nenhuma alocação por quadro.
static func crit_motion(age: float, step: int, big: bool = true) -> Vector4:
	match crit_phase(age):
		CritPhase.HOLD:
			return Vector4(0.0, 0.0, 0.0, 1.0)
		CritPhase.SLAM:
			var t := (age - CRIT_HOLD) / (CRIT_SLAM_END - CRIT_HOLD)
			var from := (2 if step >= 2 else 3) if big else 1
			var scale := clampi(from - floori(t * from), 1, from)
			var tilt := CRIT_TILT * (1.0 - floorf(t * 3.0) / 3.0)
			return Vector4(float(scale), tilt, 0.0, 1.0)
		CritPhase.HANG:
			return Vector4(1.0, 0.0, 0.0, 1.0)
		CritPhase.SHATTER:
			var s := (age - CRIT_HANG_END) / (CRIT_LIFE - CRIT_HANG_END)
			return Vector4(1.0, 0.0, -CRIT_RISE * s * s, 1.0 - s)
	return Vector4(1.0, 0.0, -CRIT_RISE, 0.0)


## Mistura de branco no preenchimento do crítico (1 no golpe, 0 no fim do SLAM).
static func crit_flash(age: float) -> float:
	return clampf(1.0 - (age - CRIT_HOLD) / (CRIT_SLAM_END - CRIT_HOLD), 0.0, 1.0)


## Movimento dos outros tipos: Vector4(escala, inclinação, deslocamento vertical, opacidade).
## Escala sempre 1 e sem inclinação: só a fonte incha (pop_steps) e o número deriva.
static func motion(kind: int, age: float, life: float, colorblind: bool = false) -> Vector4:
	var s: Dictionary = style(kind, colorblind)
	return Vector4(1.0, 0.0, float(s["drift"]) * age, clampf((life - age) / maxf(life, 0.001) * 2.0, 0.0, 1.0))


static func priority(kind: int) -> int:
	return int(NORMAL[kind]["priority"])


## O número do tipo aparece? `settings` é o dicionário de opções (chave → valor); a opção
## geral "damage_numbers" desligada esconde todos. Chave ausente (save antigo) = visível.
static func visible(kind: int, settings: Dictionary) -> bool:
	return bool(settings.get("damage_numbers", true)) and bool(settings.get(SETTING_KEYS[kind], true))


static func palette(colorblind: bool) -> Array:
	return COLORBLIND if colorblind else NORMAL


static func style(kind: int, colorblind: bool = false) -> Dictionary:
	return palette(colorblind)[kind]


## Texto do número: prefixo + valor arredondado (mínimo 1, abreviado se grande) + sufixo.
static func text(kind: int, amount: float, decimal: String = ".") -> String:
	var s: Dictionary = NORMAL[kind]
	return String(s["prefix"]) + abbreviate(maxi(1, roundi(amount)), decimal) + String(s["suffix"])


## 9999 fica inteiro; 12345 → "12.3k"; 123456 → "123k"; 1234567 → "1.2M" (com `decimal`).
static func abbreviate(value: int, decimal: String = ".") -> String:
	if value < ABBREV_FROM:
		return str(value)
	var unit := "k"
	var v := value / 1000.0
	if value >= 1000000:
		unit = "M"
		v = value / 1000000.0
	if v >= 100.0:
		return "%d%s" % [floori(v), unit]
	var tenths := floori(v * 10.0)
	if tenths % 10 == 0:
		return "%d%s" % [tenths / 10, unit]
	return "%d%s%d%s" % [tenths / 10, decimal, tenths % 10, unit]


## Separador decimal do idioma ("pt_BR" → ",", "en" → ".").
static func decimal_for(locale: String) -> String:
	return "," if COMMA_LOCALES.has(locale.substr(0, 2)) else "."


# --- Densidade adaptativa -----------------------------------------------------------------

## Pressão crua (0..1): a maior entre inimigos vivos e números pedidos por segundo.
static func raw_pressure(enemies: int, rate: float) -> float:
	var by_enemies := inverse_lerp(PRESSURE_ENEMIES.x, PRESSURE_ENEMIES.y, float(enemies))
	var by_rate := inverse_lerp(PRESSURE_RATE.x, PRESSURE_RATE.y, rate)
	return clampf(maxf(by_enemies, by_rate), 0.0, 1.0)


## Um passo da suavização: sobe com PRESSURE_RISE, desce com PRESSURE_FALL.
static func next_pressure(pressure: float, raw: float, dt: float) -> float:
	var tau := PRESSURE_RISE if raw > pressure else PRESSURE_FALL
	return lerpf(pressure, raw, clampf(dt / tau, 0.0, 1.0))


## Nível com histerese (sobe/desce no máximo um por chamada).
static func next_level(pressure: float, level: int) -> int:
	if level < LEVEL_UP.size() and pressure > float(LEVEL_UP[level]):
		return level + 1
	if level > 0 and pressure < float(LEVEL_DOWN[level - 1]):
		return level - 1
	return level


## Tamanho em px do número (0 = dígitos 3×5) para o degrau `step` no nível `level`.
static func number_size(kind: int, step: int, level: int) -> int:
	var at := LADDER.find(font_size(step))
	return LADDER[maxi(0, at - shrink_steps(kind, level))]


static func shrink_steps(kind: int, level: int) -> int:
	match kind:
		Kind.CRIT, Kind.TAKEN, Kind.TAKEN_HEAVY:
			return 0
		Kind.HIGH, Kind.HEAL:
			return maxi(0, int(LEVEL_SHRINK[level]) - 1)
	return int(LEVEL_SHRINK[level])


## Multiplicador da vida no nível `level`.
static func level_life(kind: int, level: int) -> float:
	match kind:
		Kind.CRIT, Kind.TAKEN, Kind.TAKEN_HEAVY:
			return 1.0
		Kind.HIGH:
			return float(LEVEL_LIFE_HIGH[level])
	return float(LEVEL_LIFE[level])


## Juntar `b` num número vivo `a` do mesmo tipo a `dist` px? Só comum, alto e contínuo, só com
## pressão, só perto e de valor parecido.
static func should_fold(kind: int, level: int, dist: float, a: float, b: float) -> bool:
	if level <= 0 or (kind != Kind.HIT and kind != Kind.HIGH and kind != Kind.DOT):
		return false
	if dist > float(FOLD_RADIUS[level]):
		return false
	return absf(a - b) <= float(FOLD_SHARE[level]) * maxf(a, b)


## Golpe comum pequeno demais para a pressão atual (`ref` = média móvel).
static func insignificant(kind: int, amount: float, ref: float, level: int) -> bool:
	return kind == Kind.HIT and ref > 0.0 and amount < float(SIGNIF_SHARE[level]) * ref


static func is_taken(kind: int) -> bool:
	return kind == Kind.TAKEN or kind == Kind.TAKEN_HEAVY


static func is_enemy(kind: int) -> bool:
	return kind <= Kind.DOT


## Luminância relativa (WCAG) de uma cor, para os testes de contraste.
static func luminance(c: Color) -> float:
	var l := c.srgb_to_linear()
	return 0.2126 * l.r + 0.7152 * l.g + 0.0722 * l.b


## Forma do tipo sem a cor (prefixo, sufixo, negrito, animação, direção, tremor): única por tipo.
static func style_signature(s: Dictionary) -> String:
	return "%s|%s|%s|%d|%s|%s|%d" % [s["prefix"], s["suffix"], s["bold"], s["anim"],
			"down" if float(s["drift"]) > 0.0 else "up", float(s["shake"]) > 0.0, s["outline_px"]]
