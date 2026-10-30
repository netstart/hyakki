class_name Omikuji
extends RefCounted
## Omikuji do baú (おみくじ): a sorte tirada no tubo de madeira antes de o Baú Laqueado abrir.
##
## A sorte é só a APRESENTAÇÃO do número de itens que o ChestSystem já sorteou (as chances
## 70/25/5% e a sorte do herói não mudam):
##   吉 kichi = 1 item, 中吉 chūkichi = 3 itens, 大吉 daikichi = 5 itens.
## 凶 kyō: um baú de 1 item às vezes (KYO_CHANCE) sai como "má sorte". O jogador recebe o mesmo
## item (nunca menos) e mais KYO_RYO de consolo, e o papel é amarrado no galho (gesto dos
## templos: deixa-se o azar para trás). O sorteio do kyō sai de um fluxo próprio derivado da
## semente da partida (stream_seed), e não do `game.rng`: a mesma semente dá a mesma sequência
## de sortes em 1x, 2x e 3x, sem deslocar os sorteios da luta (inimigos, cartas, itens).
##
## Baús generosos: os GENEROUS_CHESTS primeiros baús comuns (não de chefe) do save inteiro
## saem com pelo menos 中吉 (3 itens). O contador fica no save (`omikuji.generous_used`); saves
## antigos migram contando os baús já abertos (stats.chests), então quem já jogou não ganha de
## novo. O bot (testes de determinismo) nunca usa nem gasta os baús generosos.

const KICHI := &"kichi"
const CHUKICHI := &"chukichi"
const DAIKICHI := &"daikichi"
const KYO := &"kyo"
const ALL: Array[StringName] = [KICHI, CHUKICHI, DAIKICHI, KYO]
## Chance de um baú de 1 item sair como 凶 (só apresentação + consolo).
const KYO_CHANCE := 0.08
## Ryō de consolo do 凶 (antes da ganância e do multiplicador da lua, como o ryō do baú).
const KYO_RYO := 15
## Baús comuns com 中吉 garantido no começo do save.
const GENEROUS_CHESTS := 3
const SAVE_KEY := "omikuji"
## Mistura a semente da partida para o fluxo do omikuji (nunca igual ao `game.rng`).
const STREAM_SALT := 0x6f6d696b


## Sorte para `items` itens entregues; `roll` (0..1) decide o 凶 dos baús de 1 item.
static func fortune_for(items: int, roll: float) -> StringName:
	if items >= 5:
		return DAIKICHI
	if items >= 3:
		return CHUKICHI
	return KYO if roll < KYO_CHANCE else KICHI


## Sorte só pela contagem (sem 凶): o que a tela mostra quando ninguém informou a sorte.
static func fortune_of_count(items: int) -> StringName:
	return fortune_for(items, 1.0)


static func is_valid(fortune: StringName) -> bool:
	return ALL.has(fortune)


## Kanji do papel (fonte japonesa em qualquer idioma).
static func kanji(fortune: StringName) -> String:
	match fortune:
		CHUKICHI:
			return "中吉"
		DAIKICHI:
			return "大吉"
		KYO:
			return "凶"
	return "吉"


## Itens que cada sorte representa (凶 continua entregando 1 item).
static func items_of(fortune: StringName) -> int:
	match fortune:
		CHUKICHI:
			return 3
		DAIKICHI:
			return 5
	return 1


## Leitura localizada (romaji, kana, hangul...).
static func reading(fortune: StringName) -> String:
	match fortune:
		CHUKICHI:
			return TranslationServer.translate("omikuji.chukichi")
		DAIKICHI:
			return TranslationServer.translate("omikuji.daikichi")
		KYO:
			return TranslationServer.translate("omikuji.kyo")
	return TranslationServer.translate("omikuji.kichi")


## O que a sorte quer dizer, no idioma do jogador.
static func meaning(fortune: StringName) -> String:
	match fortune:
		CHUKICHI:
			return TranslationServer.translate("omikuji.chukichi_meaning")
		DAIKICHI:
			return TranslationServer.translate("omikuji.daikichi_meaning")
		KYO:
			return TranslationServer.translate("omikuji.kyo_meaning")
	return TranslationServer.translate("omikuji.kichi_meaning")


## Semente do fluxo do omikuji a partir da semente da partida (determinística, nunca 0).
static func stream_seed(run_seed: int) -> int:
	var mixed := (run_seed * 0x9E3779B1 + STREAM_SALT) & 0x7fffffffffffffff
	return mixed if mixed != 0 else STREAM_SALT


# --- Save (baús generosos) ---------------------------------------------------------------

static func default_state() -> Dictionary:
	return {"generous_used": 0}


## Estado para um save antigo sem a chave: os baús já abertos contam como generosos gastos.
static func migrate_state(profile: Dictionary) -> Dictionary:
	var stats: Variant = profile.get("stats", {})
	var opened := int((stats as Dictionary).get("chests", 0)) if stats is Dictionary else 0
	return {"generous_used": clampi(opened, 0, GENEROUS_CHESTS)}


static func _state(profile: Dictionary) -> Dictionary:
	var state: Variant = profile.get(SAVE_KEY)
	if not state is Dictionary:
		state = default_state()
		profile[SAVE_KEY] = state
	return state


static func generous_left(profile: Dictionary) -> int:
	return maxi(0, GENEROUS_CHESTS - int(_state(profile).get("generous_used", 0)))


## Gasta um baú generoso (fica no save; vai para o disco na próxima gravação).
static func use_generous(profile: Dictionary) -> void:
	var state := _state(profile)
	state["generous_used"] = mini(GENEROUS_CHESTS, int(state.get("generous_used", 0)) + 1)


## Mínimo de itens do baú: chefe 3; comum 3 enquanto houver generoso, senão 1.
static func min_items(from_boss: bool, generous: int) -> int:
	return 3 if from_boss or generous > 0 else 1
