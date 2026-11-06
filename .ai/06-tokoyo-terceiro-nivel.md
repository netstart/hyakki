# Tokoyo (常世): o terceiro nível de cada fase

Documento de design. Fonte da verdade para os executores; números finais vivem em `data/*.json` e em
constantes nomeadas no código, lidos pelo Guia do Diário em tempo real.

## Fantasia

Cada fase tem agora **três níveis**:

1. **A fase** (mundo dos vivos) — como hoje.
2. **Kakuriyo (隠世)**, o mundo oculto — como hoje, aberto pelo 1º Guardião do Limiar (7:30).
3. **Tokoyo (常世)**, a Terra Eterna — **novo**. No Kakuriyo, a **Sombra do Guardião** (影) guarda o
   último limiar; vencida, deixa dois baús de chefe e um **torii dourado**. Do outro lado fica um
   santuário de luz, mapa com layout próprio (nenhum outro bioma usa), onde mora o **último chefe**
   da fase (o das 10:00).

O contraste é intencional: o Kakuriyo é escuro e tingido; o Tokoyo é **claro, dourado e solene**
(mais luz, menos escuridão), um jardim sagrado com espelhos d'água — o lugar da batalha final.

## Regras (simulação determinística, passo fixo, só `game.rng`)

### Cronograma

| Nível | Entrada | Quem aparece |
|---|---|---|
| 1 Fase | 0:00 | chefe das 5:00, Kami, 1º Guardião aos 7:30 (como hoje) |
| 2 Kakuriyo | portal do 1º Guardião | **Sombra do Guardião** em `max(midboss2.t, chegada + midboss2.after)` (aviso `WARN_LEAD` s antes, como o 1º) |
| 3 Tokoyo | torii dourado da Sombra | **último chefe** (último de `bosses`) em `max(t do chefe, chegada + FINAL_AFTER)` |

- `data/stages.json`, em cada fase: `"midboss2": {"t": 540, "id": "<midboss>_kage", "after": 45}` e
  um bloco `"tokoyo"` no formato do `"otherworld"` (`biome`, `kanji`, `tint`, `light_mult`, `music`,
  `weather`, `bounds`, `hazard`).
- `FINAL_AFTER` (~8 s): constante nomeada; a chegada ao Tokoyo ganha um respiro (`Spawner.hush`) e o
  aviso "o senhor de Tokoyo desperta" antes da entrada (com o diálogo que esse chefe já tem).
- **O último chefe só aparece no Tokoyo.** Quem não atravessa os portais vence ao amanhecer
  (15:00) como hoje, mas sem a luta final e sem o baú dela. O chefe das 5:00 e o Kami não mudam.
- A Sombra só nasce no Kakuriyo. Os portais continuam convites (nunca puxam nem forçam).
- Noite Sem Fim, Desafio Diário, Lua Vermelha, altares (bloqueados com chefe vivo) e partida
  suspensa seguem valendo nos três níveis.

### Sombra do Guardião (`<midboss>_kage`, 6 chefes novos em `data/bosses.json`)

Variante do Guardião do Limiar da fase, com a mesma arte: `"midboss": true`, `"tier": 2`, selo `影`,
tinta e aura do Kakuriyo da fase, escala ~1,15×, vida ~1,3× (sempre abaixo da do último chefe da fase), dano ~1,15×, velocidade ~1,1×, e uma
fase a mais (abaixo de 1/3 da vida) com esperas mais curtas (≥ 0,6 s, regra dos padrões avisados)
e um padrão a mais do próprio kit. Nomes e lore nos 11 idiomas (Diário).

### Portais e travessias (`scripts/systems/rift_portal.gd` generalizado)

- `depth`: 0 fase, 1 Kakuriyo, 2 Tokoyo (`in_realm` = `depth >= 1`, mantido por compatibilidade).
- Guardião de tier 1 vencido → portal violeta (Kakuriyo, como hoje). Tier 2 → **torii dourado**
  (vórtice ouro/branco, almas douradas, zumbido mais grave) que leva ao Tokoyo.
- `realm_stage(stage, depth)` mistura `otherworld` (1) ou `tokoyo` (2). Semente própria
  (`hash([seed, "tokoyo"])`).
- RealmCard: kanji `常世` (do bloco `tokoyo`), nome `realm3.<fase>.name`, legenda `realm3.caption`.
- Snapshot ganha `depth`; um snapshot antigo com `in_realm` vira `depth` 1 (sem quebrar saves).
- Tracker/resultado: `realm_reached` (como hoje) e `tokoyo_reached`; o resultado leva `"tokoyo"`.
- Bot: entra em qualquer portal aberto (já faz); E2E chega ao Tokoyo e vence o último chefe;
  mesmo hash em 1x/2x/3x e na qualidade Baixa.

### Mapa do Tokoyo (layout novo `"tokoyo"` em `scripts/game/terrain_layout.gd`)

Biomas `<fase>_toko` em `data/biomes.json` (`"tokoyo": true`), todos com o layout `tokoyo`, que
nenhum bioma das fases nem do Kakuriyo usa (teste confere):

- **Arena limitada** (`bounds` do bloco `tokoyo`, menor que o Kakuriyo): sensação de lugar final.
- **Santuário central** na origem: praça circular calçada, livre no meio (luta do chefe), com
  anel de tōrō (lanternas de pedra) sólidos na borda e quatro torii nas entradas cardeais.
- **Caminhos sagrados** radiais e um anel de pedra ligando a praça às bordas; entre eles **espelhos
  d'água** (material especial, sem colisão) e ilhas de árvores sagradas, flores e ruínas.
- Paleta clara por fase (ouro de aurora, jade, vermelhão e ouro, prata de lua, lótus violeta,
  aurora iridescente), luz alta, pouca escuridão e clima próprio.

## Conteúdo e textos

Guia (capítulos de chefes e de fases, números lidos dos dados), Diário (6 chefes novos, descoberta),
Missões do Santuário ("chegar ao Tokoyo" por fase e no total), tela de Resultados, 11 idiomas,
README, guia da Play Console e ficha da loja. Versão MENOR (funcionalidade nova).
