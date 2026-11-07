# Fogo, Gelo e Clones: novas armas, relíquias, combos e itens (1.23.0)

Pedido (2026-11-03): "Crie novos itens e combos com poder de fogo, gelo e clones."

Documento de design, fonte da verdade para os executores. Números finais vivem em `data/*.json`
(armas, relíquias, itens) e em constantes nomeadas no código (status dos inimigos), lidas pelo Guia
em tempo real como o resto do Guia. Ajustes de equilíbrio pequenos são livres, desde que o doc seja
atualizado junto.

## Visão

Três elementos novos, cada um com uma linha completa (arma base → relíquia → evolução), três uniões
cruzando os elementos dois a dois, dois itens de chão e dois estados novos nos inimigos (Queimadura
e Congelamento) que conversam entre si (Choque Térmico). Tudo entra no pool sem desbloqueio
(`unlock: ""`), como Katana e Shuriken.

| Elemento | Arma base | Relíquia | Evolução | Cor |
|---|---|---|---|---|
| Fogo 火 | Hōroku-biya 焙烙火矢 (`horokubiya`) | Pedra de Fogo 火打石 (`hiuchi_ishi`) | Kagutsuchi 迦具土 (`kagutsuchi`) | `#ff7a3a` / quente `#ffe0b0` |
| Gelo 氷 | Tsurara 氷柱 (`tsurara`) | Pente da Yuki-onna 雪女の櫛 (`yuki_kushi`) | Sopro da Yuki-onna 雪女 (`yukionna`) | `#8fe0ff` / quente `#f0fcff` |
| Sombra 影 | Kage Bunshin 影分身 (`kage_bunshin`) | Espelho Yata 八咫鏡 (`yata_kagami`) | Mil Sombras 千影 (`senkage`) | `#9a7cff` / quente `#e8e0ff` |

Uniões (combos):

| União | Requer | Ideia |
|---|---|---|
| Taikyoku do Onmyō 陰陽太極 (`onmyo_taikyoku`) | `kagutsuchi` + `yukionna` | dois orbes (fogo e gelo) em yin-yang em volta do guardião; quem tem os dois estados explode em Choque Térmico |
| Casamento da Raposa 狐の嫁入り (`kitsune_yomeiri`) | `kagutsuchi` + `senkage` | os clones viram raposas de fogo: cada corte queima e cada clone explode em chamas ao sumir |
| Espelho de Gelo 氷鏡 (`hyokyo`) | `yukionna` + `senkage` | clones de gelo: cada corte gela; ao sumir estilhaçam em leque de pingentes |

Uma evolução pode servir a duas uniões; ao formar uma, as duas evoluções são consumidas (regra
atual), então o jogador escolhe qual combo fazer.

Itens de chão (quebra de objetos, sorteio por peso como os atuais):

| Item | id | effect | value | weight | Efeito |
|---|---|---|---|---|---|
| Jarro de Fogo | `fire_jar` | `inferno` | 4 (s) | 4 | toda a tela queima por 4 s (Queimadura de 8 dps × bônus da Pedra de Fogo); chefes também |
| Caco do Espelho | `mirror_shard` | `clones` | 10 (s) | 4 | 3 clones de sombra (iguais aos do Kage Bunshin nível 1, dano escalado pelo nível do guardião) por 10 s |

Ícones dos itens: arte existente de `assets/art/items` (ex.: `potion/` ou `object/Gourd.png` para o
jarro; algo espelhado/brilhante para o caco). Se não houver nada adequado, gerar no `gen_skill_icons.gd`
como grupo `items` mantendo a regra de licença (gerado pelo projeto = mesma licença dos ícones gerados).

## Estados novos nos inimigos (`scripts/systems/enemy_manager.gd`)

Struct-of-arrays como o resto (entram na lista do `_ready` e no reset do spawn). Constantes nomeadas
(`BURN_TICK`, `CHILL_STACKS_TO_FREEZE`, ...), lidas pelo Guia.

### Queimadura 炎上 (burn)
- Arrays `burn_time`, `burn_dps`, `burn_src` (índice num pequeno registro de ids de arma para o
  `deal_damage` creditar o dano à arma certa).
- Aplicar: `burn_one(j, dps, time, src)` e `burn_circle(pos, r, dps, time, src)`. Reaplicar fica com o
  **maior** dps e o **maior** tempo restante (não soma; evita explosão numérica).
- Tick a cada `BURN_TICK = 0.5` s: `game.deal_damage(src, j, dps*BURN_TICK, dir0, 0, false, dot=true)`
  (sem crítico, sem empurrão, sem energia de habilidade — igual aos outros DoT).
- Stat global novo `burn` (pct, base 0): multiplica o dps de toda Queimadura. Vem da relíquia.
- Chefes queimam normalmente (é dano, não controle).
- Visual: chama pequena tremulando sobre o inimigo, na 2ª passada de marcas de estado (já existe, com
  teto por quadro) — sem `draw_polygon`; textura/retângulos/`Stroke`. Tom laranja leve no corpo.

### Frio e Congelamento 凍結 (chill / freeze)
- Frio reaproveita `slow`/`slow_mult` (`apply_slow`), que já desenha o tom gelado e o floco.
- Array novo `chill` (pilhas). Cada acerto de arma de gelo soma `chill` pilhas (campo `chill` da arma).
  Ao chegar em `CHILL_STACKS_TO_FREEZE = 5`: zera as pilhas e **congela** por `FREEZE_TIME = 1.2` s
  (× (1 + stat `chill`)), usando o `stun[]` (inimigo parado) e um array `frozen` para o visual
  (bloco de gelo/tom `FROZEN_TINT` individual — hoje o tom congelado é só global).
- Lentidão do frio: `CHILL_SLOW = 0.35` (35 %) por `CHILL_SLOW_TIME = 1.5` s, × (1 + stat `chill`) na
  força, com teto de 70 %.
- Chefes: recebem frio (lentidão com o mesmo corte ×0.4 usado no atordoar) mas **não congelam**
  (as pilhas param em 4).
- Stat global novo `chill` (pct, base 0): força da lentidão e duração do congelamento.
- **Estilhaçar** (flag `shatter` da evolução `yukionna` e das uniões de gelo): inimigo morto enquanto
  congelado explode em estilhaços: dano `SHATTER_DAMAGE = 25` (× might) em raio 30, aplicando 1 pilha
  de frio em volta.

### Choque Térmico 温度衝撃 (regra global)
- Acerto de **fogo** num inimigo **congelado** ou acerto de **gelo** num inimigo **queimando**:
  consome o estado oposto e causa dano extra = `THERMAL_SHOCK_MULT = 1.0` × dano do acerto (dobra o
  golpe), com nuvem de vapor branca e o som `hit_ice` mais grave. Recarga por inimigo de 0.5 s.
- "Fogo" e "gelo" = tags `fire` / `ice` da arma (a Hitodama, que já tem `fire`, entra no jogo do
  Choque). A união `onmyo_taikyoku` tem as duas tags e causa o choque em área (ver abaixo).

## Armas

Comportamentos novos em `scripts/weapons/` (registrar em `WEAPON_BEHAVIORS`): `horokubiya`,
`tsurara`, `kage_bunshin`, `taikyoku`. As evoluções reusam o script da base com `flags`. As uniões de
clone reusam `kage_bunshin` com flags. Chaves novas nos `levels`/`base`: `burn`, `burn_time`,
`chill` (precisam de `delta.<k>` e entram em `Weapon.FRACTION_KEYS` só se forem fração — não são).

### Hōroku-biya 焙烙火矢 (fogo, tags `["area","fire"]`)
Pote de barro com pólvora arremessado em arco (sombra no chão + pote girando) até um inimigo
aleatório num raio de 170 px; explode (dano em área + `burn_circle`) e deixa chão em brasa
(`areas.pool` de fogo) que reaplica a Queimadura enquanto durar.
- base: `damage 12, cooldown 2.4, amount 1, radius 26, duration 2.0, burn 3, burn_time 3.0, speed 1.0 (tempo de voo 0.55 s / speed), knockback 60`
- levels: `{}, {amount 1}, {damage 5}, {area 0.2}, {burn 2}, {amount 1}, {duration 0.5, burn 2}, {damage 8, amount 1}`
- evolves_with `hiuchi_ishi`, evolution `kagutsuchi`
- sfx: launch novo `horokubiya` (assobio do arremesso + chiado do pavio), impact `hit_fire`

**Kagutsuchi 迦具土** (evolução): 3 potes por vez, explosão maior, chão em brasa 4 s, e
`flags.burn_spread = 36`: inimigo que morre queimando explode em chamas e passa a Queimadura a quem
estiver em 36 px.
- base: `damage 40, cooldown 1.8, amount 3, radius 40, duration 4.0, burn 10, burn_time 4.0, knockback 90`

### Tsurara 氷柱 (gelo, tags `["projectile","ice"]`)
Leque de pingentes de gelo na direção do inimigo mais próximo; cada acerto aplica frio (`chill` pilhas).
Projétil novo `KINDS` "icicle" (textura pequena azul-branca, rastro curto com `Stroke.polyline`).
- base: `damage 7, cooldown 1.4, amount 3, spread 0.35, pierce 1, speed 230, duration 1.0, chill 1, knockback 20`
- levels: `{}, {amount 1}, {damage 3}, {pierce 1}, {amount 1}, {chill 1}, {damage 4}, {amount 2}`
- evolves_with `yuki_kushi`, evolution `yukionna`
- sfx: launch novo `tsurara` (tilintar cristalino), impact novo `hit_ice`

**Sopro da Yuki-onna 雪女** (evolução): rajada em anel completo de 12 pingentes + 3 no alvo,
`chill 2`, `flags.shatter = true`.
- base: `damage 18, cooldown 1.1, amount 15, spread 6.28, pierce 3, speed 260, duration 1.1, chill 2, knockback 25`

### Kage Bunshin 影分身 (sombra, tags `["blade","shadow"]`)
Invoca clones de sombra (silhueta do guardião atual escurecida e roxa, com borda clara para ler na
horda; desenho reaproveita o do clone da ultimate do Kenta) que aparecem em volta do guardião com
fumaça, correm até o inimigo mais próximo (velocidade `speed`) e cortam em meia-lua de raio `radius`
a cada 0.6 s; somem com fumaça ao fim de `duration`. Teto global de clones vivos `MAX_CLONES = 10`.
Os clones **não** disparam as outras armas (isso é da ultimate do Kenta) e não recebem dano.
Estado vivo dos clones **não** vai para o save da partida suspensa (renascem no próximo disparo).
- base: `damage 8, cooldown 7.0, amount 1, duration 5.0, radius 20, speed 140, knockback 40`
- levels: `{}, {damage 4}, {amount 1}, {duration 1.0}, {damage 4}, {amount 1}, {area 0.2}, {amount 1, damage 6}`
- evolves_with `yata_kagami`, evolution `senkage`
- sfx: launch novo `kage_bunshin` (puf de fumaça + selo de mão), impact `hit_blade`

**Mil Sombras 千影** (evolução): 4 clones **permanentes** (`flags.permanent`) que reaparecem 1 s
depois se o grupo for desfeito (ex.: troca de fase) e `flags.clone_on_kill = 0.25`: abate de clone tem
25 % de gerar um clone extra de 4 s (até `MAX_CLONES`).
- base: `damage 26, cooldown 1.0, amount 4, duration 999, radius 26, speed 170, knockback 60`

### Relíquias (`data/passives.json`)
| id | max | per_level | Evolui |
|---|---|---|---|
| `hiuchi_ishi` | 5 | `{"burn": 0.15}` (+15 % de dano de Queimadura) | Hōroku-biya |
| `yuki_kushi` | 5 | `{"chill": 0.1}` (+10 % de força do frio e duração do congelamento) | Tsurara |
| `yata_kagami` | 5 | `{"duration": 0.05, "might": 0.05}` | Kage Bunshin |

Stats novos `burn` e `chill` em `StatBlock.DEFS` (`pct`), `stat.<k>`, `statname.<k>` e na lista de
atributos da pausa.

### Uniões (`kind: union`)
- **Taikyoku do Onmyō** (`onmyo_taikyoku`, behavior novo `taikyoku`, tags `["fire","ice","orbit"]`):
  dois orbes grandes (vermelho e azul) girando opostos em volta do guardião num raio que pulsa
  60↔90 px, deixando rastro curto; orbe de fogo aplica Queimadura (12 dps, 3 s), orbe de gelo 2 pilhas
  de frio; a cada 2 s um pulso yin-yang em raio 110 causa Choque Térmico em área em quem tem
  Queimadura **ou** frio (consome). `base: damage 45, cooldown 2.0, amount 2, radius 75, speed 3.4, burn 12, burn_time 3.0, chill 2, knockback 80`
- **Casamento da Raposa** (`kitsune_yomeiri`, behavior `kage_bunshin`, tags `["blade","shadow","fire"]`):
  6 clones permanentes de fogo-fátuo (laranja, rabos de raposa de luz), corte aplica Queimadura 10 dps
  e cada clone, a cada 6 s, se lança e explode (raio 40, dano 60) e renasce 1 s depois.
  `base: damage 34, cooldown 0.9, amount 6, duration 999, radius 28, speed 190, burn 10, burn_time 3.0, knockback 70`, `flags: {permanent, fire_clone, burst_every: 6.0, burst_radius: 40, burst_damage: 60}`
- **Espelho de Gelo** (`hyokyo`, behavior `kage_bunshin`, tags `["blade","shadow","ice"]`):
  6 clones permanentes de gelo (azul translúcido), corte aplica 2 pilhas de frio, `shatter`, e a cada
  6 s cada clone estilhaça num leque de 8 pingentes (projéteis "icicle", 20 de dano, chill 1) e renasce.
  `base: damage 30, cooldown 0.9, amount 6, duration 999, radius 28, speed 180, chill 2, knockback 60`, `flags: {permanent, ice_clone, shatter, burst_every: 6.0, burst_shards: 8, shard_damage: 20}`

## Integração (checklist)

- `data/weapons.json`, `data/passives.json`, `data/items.json`; `WEAPON_BEHAVIORS` em `game.gd`.
- Gancho genérico `Weapon.on_kill(at, j)` chamado pelo handler de morte para todas as armas (substitui
  o `if weapon is Hitodama`); `burn_spread`, `shatter`, `clone_on_kill` usam esse gancho / o estado do
  inimigo no momento da morte.
- Itens: casos `inferno` e `clones` no `collect_item`, toast `item.<id>.toast`, `guide.item.<effect>`,
  caso no `GuideBook.item_effect`, ícone no preload do `pickup_manager`.
- Missões: `m_evo_<id>` para as 3 evoluções e `m_union_<id>` para as 3 uniões, no padrão atual.
- `ELEMENTS` do `level_up_panel.gd` (cores das cartas): `ice` e `shadow`.
- Ícones: `tools/gen_skill_icons.gd` com elementos novos `ice` e `shadow` e arte própria para as 9
  armas e 3 relíquias (pote de barro com pavio, pingente, silhueta dupla; pedra de fogo, pente, espelho
  redondo; Kagutsuchi em chamas, floco/rosto da Yuki-onna, várias silhuetas; yin-yang, raposa, espelho
  de gelo). Rodar o gerador e o `--import`.
- Sons: impacto novo `hit_ice` (as 8 etapas do checklist de impacto, gerado por `tools/gen_sfx.py`,
  licença do gerado já registrada — conferir `check_licenses`) e cues de lançamento novos no
  `WeaponSfx.CUES` (evolução com cue diferente da base). Vapor do Choque Térmico e estilhaço reusam
  camadas.
- Guia: capítulo de baús/evoluções/uniões lista as linhas automaticamente; acrescentar uma seção
  curta "Fogo, gelo e sombra" explicando Queimadura, Frio/Congelamento, Estilhaçar e Choque Térmico com
  os números lidos das constantes.
- Textos nos 11 idiomas (`tools/i18n/data.py` e afins, depois `python tools/build_i18n.py`): nome e
  descrição de 9 armas, nome de 3 relíquias, `delta.burn`, `delta.burn_time`, `delta.chill`, `stat.burn`,
  `stat.chill`, `statname.*`, 2 itens + toasts, textos do Guia. Limites de tamanho dos testes de layout.
- Bot: nada (escolhe a carta 0); as armas novas entram nas partidas do bot.
- Desenho: nada de `draw_polygon/draw_colored_polygon/draw_polyline/draw_arc/draw_multiline` por
  quadro; usar `Stroke`, texturas e retângulos. Testes `_check_no_polygons` para cada script novo.
- README, guia da Play Console (notas da 1.23.0) e ficha da loja nos 11 idiomas.
- Versão: MENOR 1.22.0 → 1.23.0, versionCode 47 → 48 (feito sobre a 1.18.0 e integrado à main na 1.22.0).

## Testes

- Unitários (`tests/elements_tests.gd`, ligado no `integration_tests.gd`):
  dados das 9 armas/3 relíquias/2 itens; Queimadura (tick, dano creditado à arma, reaplicar sem somar,
  bônus `burn`, chefe queima); Frio (lentidão, 5 pilhas → congela, chefe não congela, bônus `chill`);
  Estilhaçar; Choque Térmico (fogo em congelado e gelo em queimando, recarga); Hōroku-biya (arco,
  explosão, chão em brasa); Tsurara (leque, pierce, pilhas); Kage Bunshin (clones nascem, cortam,
  somem, teto, Mil Sombras permanentes e clone extra no abate); 3 uniões; itens `inferno` e `clones`;
  `_check_no_polygons` nos scripts novos.
- E2E: partida do bot com arsenal forçado das armas novas (base → evolução → união), mesmo hash de
  determinismo em 1x/2x/3x e na qualidade Baixa; `weapon_fx_tests`/`weapon_audio_tests`/
  `skill_icon_tests` cobrindo os ids novos.
- Layout: carta de nível com as relíquias/armas novas e os combos no rodapé, Diário e capítulo do Guia
  em todas as resoluções × 11 idiomas × furo dos dois lados (os testes atuais iteram os dados; garantir
  que passam).
- Desempenho: `tests/game_bench.tscn` com o arsenal novo (clones + muitos inimigos queimando/
  congelados) sem regressão do p95.

## IDs fixos

Armas: `horokubiya`, `kagutsuchi`, `tsurara`, `yukionna`, `kage_bunshin`, `senkage`,
`onmyo_taikyoku`, `kitsune_yomeiri`, `hyokyo`. Relíquias: `hiuchi_ishi`, `yuki_kushi`, `yata_kagami`.
Itens: `fire_jar` (`inferno`), `mirror_shard` (`clones`). Tags: `fire`, `ice`, `shadow`.
Stats: `burn`, `chill`. Impacto: `hit_ice`. Projétil: `icicle`.

## Decisões da implementação (fase 1: jogabilidade, dados, textos, testes)

Onde o código divergiu ou detalhou o design acima:

- **Atributos `burn` e `chill`**: em `StatBlock.DEFS` com base **1.0** (`pct`), como multiplicadores
  (`1 + soma`), e não base 0: com base 0 um `pct` daria sempre 0. A pausa mostra "100%" sem relíquia.
- **Dps da Queimadura das armas** = `burn` da arma × Poder × bônus de dano (`Weapon.burn_dps`), e o
  `EnemyManager.burn_one` ainda multiplica pelo atributo `burn`. O Jarro de Fogo usa 8 dps fixos
  (× atributo `burn`, sem Poder).
- **Tiques sem crítico**: `HyakkiGame.deal_damage` ganhou o parâmetro `no_crit` (só os tiques usam).
- **Pilhas de frio** só valem enquanto a lentidão do frio dura (`CHILL_SLOW_TIME`); sem lentidão,
  recomeçam do zero (senão acumulavam para sempre). Congelado não soma pilhas. Chefes: a lentidão
  (× `BOSS_STUN`) é lida pelo `BossDirector._speed` via `EnemyManager.move_factor`; o tempo da
  lentidão do chefe corre no passo dos inimigos.
- **Choque Térmico de fogo** descongela (tira o tempo do congelamento do `stun`).
- **Ganchos**: `scripts/systems/element_system.gd` (`ElementSystem`, `game.elements`) guarda as armas de
  fogo/gelo por id (registradas no `Weapon._init`), o `mute` dos estilhaços, os itens `inferno`/`clones`,
  os clones do Caco, o arsenal forçado, o Estilhaçar (`game.elements.shatter`) e o vapor do Choque
  Térmico (`game.elements.steam`). Ao integrar a main (1.23.0), `game.gd` e `enemy_manager.gd` passavam
  do limite de 1200 linhas do gdlint: o Estilhaçar e o vapor saíram do `EnemyManager` para o
  `ElementSystem` e a leitura de `--hero/--stage/--moon/--mode/--speed/--endless/--arsenal` saiu do
  `game.gd` para `scripts/game/cli_config.gd` (`CliConfig.run_config`). Selados do Altar do Selo
  (`EnemyManager.sealed`, anel da emboscada e Elite surgindo) não queimam, não gelam nem congelam,
  como já não recebiam dano; as Sombras 影 do Kakuriyo são chefes (`is_boss`) e seguem a regra do frio
  dos chefes (lentas, nunca congeladas). No acerto
  não contínuo: `Weapon.element_hit` (Choque Térmico, dano extra) antes e `Weapon.apply_status`
  (Queimadura/frio da arma) depois. O Taikyoku sobrescreve os dois por orbe.
- **Estado de quem morre**: `EnemyManager.dying_burn()/dying_frozen()/dying_killer()/dying_index()`
  (pilha, para mortes dentro de mortes) lidos pelo `Weapon.on_kill(at, j)`. Estilhaçar e Kagutsuchi
  valem para qualquer inimigo que morra congelado/queimando enquanto a arma está na mão (encadeiam).
- **Estilhaçar** sai sem os estados da arma (`mute`) e põe as `SHATTER_CHILL` pilhas à parte. Os
  estilhaços do Espelho de Gelo (projéteis "icicle" creditados ao `hyokyo`) aplicam o frio da união
  (2 pilhas), não 1.
- **Kagutsuchi** ganhou `speed 1.0` na base (o tempo de voo do pote usa a velocidade de projétil).
- **Projétil "icicle"**: o `IceSpike.png` do Ninja Adventure (CC0, já no projeto e na licença do pacote),
  sem textura gerada.
- **Chão em brasa**: `AreaEffects.fire_pool` (poça sem dano direto que reaplica a Queimadura a cada
  `BURN_TICK`), com pontos de brasa e brasas subindo no desenho.
- **Clones**: `KageBunshin` com teto global somando armas e o Caco (`alive_total`), retorno ao lado da
  guardiã acima de 320 px (`LEASH`), novo alvo a cada 0,3 s, corte em meia-lua de 180° (`query_cone`),
  lançamento de 0,25 s antes de estourar (uniões). Desenho por `Player.draw_silhouette` (mesmo corpo do
  clone da Sombra Dupla, com borda de 1 px).
- **Caco do Espelho**: um `KageBunshin` fora das armas (`game.elements.item_clones`, sem recarga), dano
  creditado a `mirror_shard`, + 10% por nível da guardiã acima do 1 (`MIRROR_DAMAGE_PER_LEVEL`).
- **Taikyoku**: os dois orbes em lados opostos, girando juntos (yin-yang); o pulso gasta Queimadura,
  pilhas e congelamento e causa `THERMAL_SHOCK_MULT` × o dano da arma.
- **Guia**: a seção "Fogo, gelo e sombra" fica no fim do capítulo de baús/evoluções/uniões
  (`GuideBook.element_blocks`), não num capítulo novo; os itens novos entram na lista do capítulo de
  itens com `guide.item.inferno`/`guide.item.clones`.
- **Sons e ícones da fase 1** eram provisórios (cues existentes, impacto `hit_projectile` no gelo,
  ícones com os elementos antigos): trocados na fase 2, abaixo.
- **Determinismo**: `--arsenal=a,b,...` (config `arsenal`) põe armas extras no nível máximo desde o
  começo; `tools/run_checks.ps1` (3b) e `.sh` (6b) comparam o hash com o arsenal novo em 1x/2x/3x/Baixa.
- **Desempenho (estresse de 500 inimigos, `--arsenal` com as 7 armas novas no máximo)**: reações em
  cadeia limitadas a `EnemyManager.CASCADES_PER_STEP = 12` por passo (Estilhaçar e as chamas do
  Kagutsuchi; sem o teto, a horda congelada estourava em cascata: pico de 138 ms nas armas); relógios
  de corte e estouro dos clones defasados por clone (`KageBunshin.STAGGER`) e potes da mesma leva com
  voo `POT_GAP` mais longo um que o outro. Pior passo das armas: 138 → ~20-30 ms com o arsenal inteiro
  (Hōroku-biya 50 → ~15, Casamento da Raposa 70 → ~20, Espelho de Gelo 57 → ~12; só a katana ~8).
  O `tests/game_bench.tscn` (com janela) com o arsenal novo ficou para a fase 2 (abaixo).
- **Guia**: o capítulo de baús ficou mais longo; o teste do botão "Ver armas" chama `GuidePage.complete()`
  antes de procurar o botão (a página monta 10 blocos na hora e o resto em quadros seguintes).

## Decisões da implementação (fase 2: ícones, sons, desempenho, docs, versão)

- **Ícones** (`tools/gen_skill_icons.gd`): elementos novos `ice` (`eafcff`/`62c4e8`/`0e3a62`) e `shadow`
  (`dcd0ff`/`7254d2`/`16082e`), com o mesmo fundo pontilhado. Arte própria em ASCII/código, sem itens do
  Ninja Adventure: Hōroku-biya `horoku` (pote de barro com cordão vermelho e pavio aceso), Kagutsuchi
  `horoku_blaze` (o pote engolido por chamas), Tsurara (beiral de neve `eave` com 3 pingentes
  `icicle`/`icicle_s`), Sopro da Yuki-onna `code:snowflake` (floco de 6 pontas com galhos), Kage Bunshin
  (2 silhuetas `ninja`: uma clara/fantasma atrás e uma escura na frente), Mil Sombras (silhueta escura e
  duas pequenas `ninja_s` claras + névoa), Taikyoku `code:yin_yang` (vermelho/azul, fundo `night`),
  Casamento da Raposa (raposa recolorida `fire_fox` com 2 chamas `flame_s`), Espelho de Gelo
  (`code:ice_mirror` com uma silhueta violeta e brilho `code:glint`). Relíquias: Pedra de Fogo `flint`
  (pedra com faíscas), Pente da Yuki-onna `kushi` (pente de neve), Espelho Yata `code:yata_mirror`
  (bronze octogonal com borla). Recolorações novas: `shadow_front`, `shadow_ghost`, `fire_fox`. Os
  ícones antigos saem com os mesmos bytes (só os 12 novos mudaram).
- **Itens de chão**: Jarro de Fogo com `object/Gourd.png` (cabaça laranja, lê como jarro de fogo; o
  `EmptyPot` branco parecia um pote vazio) e Caco do Espelho com `resource/BarPurple.png` (lâmina
  violeta brilhante, cor da sombra; o `GemPurple` foi descartado por ser a gema de experiência).
- **Sons** (`tools/gen_sfx.py`, CC0 `hyakki_generated_sfx`, 70 → 82 arquivos): impacto `hit_ice`
  (estalo de cristal rachando: ruído agudo curto, parciais vítreos inarmônicos e baque leve) e três camadas
  de lançamento: `fuse_whistle` (assobio do pote em arco + chiado e estalos do pavio), `ice_tinkle`
  (cascata de notas vítreas agudas + brilho frio) e `shadow_puff` (dois estalos de mão do selo + puf de
  fumaça). `hit_ice` nas 8 etapas: `HitSounds.MIX` (-15 dB), `BY_BEHAVIOR` (`tsurara`), `BY_TAG` (`ice`
  depois de `fire`), `AudioManager.VARIANTS`, `RECIPES`, `WeaponStyle.DEFAULTS`, `FxLayer.impact`
  (faíscas claras e clarão azul), `HIT_IDS` e a lista de grupos do `integration_tests.gd` (+ casos em
  `run_tests.gd`). Cues próprios no `WeaponSfx.CUES` com o id de cada arma (evolução ≠ base):
  `horokubiya`, `kagutsuchi` (+ fogo e `hit_fire`), `tsurara`, `yukionna` (+ rajada e furin),
  `kage_bunshin`, `senkage` (+ lâmina pesada), `onmyo_taikyoku` (chama + cristais + gongo),
  `kitsune_yomeiri` (selo + chama espiritual), `hyokyo` (selo + cristais). `thermal_shock` ganhou o
  `hit_ice` grave (tom 0.7) e `shatter` virou `hit_ice` + `ice_tinkle`. Impacto `hit_ice` em Tsurara,
  Sopro da Yuki-onna e Espelho de Gelo; o Taikyoku continua `hit_fire` (cada orbe já tem o seu efeito).
  `licenses/index.json` regenerado (`files_count` 70 → 82).
- **Desempenho**: `tests/game_bench.tscn` com janela, Alta, `-- --bot --seed=7 --stress=500 --bench-seconds=20`
  (no estresse a horda não morre, então os 500 ficam queimando/gelados o tempo todo e não há cascatas),
  neste PC e com bastante ruído entre rodadas (±1-2 ms na média):

  | Arsenal | média | p95 | pior | chamadas de desenho |
  |---|---|---|---|---|
  | padrão (katana) | 15,6-16,8 ms | 27-30 ms | 34-42 ms | 152 |
  | Hōroku-biya + Tsurara + Kage Bunshin (nível 8) | 16,4 ms | 34,7 ms | 48,5 ms | 257 |
  | Taikyoku + Mil Sombras | 17,0 ms | 34,8 ms | 44,9 ms | 230 |
  | Casamento da Raposa + Sopro da Yuki-onna | 18,1 ms | 41,5 ms | 52,0 ms | 251 |
  | Espelho de Gelo + Kagutsuchi | 19,0 ms | 43,6 ms | 60,4 ms | 292 |
  | as 9 armas novas juntas (`--arsenal` do run_checks) | 28-30 ms | 53-56 ms | 82-94 ms | 484 |

  Perfil (instrumentação temporária, já removida): por passo, as armas novas somam ~1 ms com as 9
  juntas (Casamento da Raposa 0,28, Kagutsuchi 0,23, Taikyoku 0,20, Mil Sombras 0,13, Hōroku-biya 0,11;
  Tsurara, Sopro e Espelho de Gelo < 0,05); `deal_damage` inteiro fica em ~0,4 ms por quadro; o passo
  dos inimigos sobe ~0,75 ms com os 500 queimando (tiques e `_step_status`); partículas (passo +
  desenho) ~1,2 ms por quadro. Não há um ponto quente único: o custo cresce com o volume de acertos e
  de estados, e o quadro mais lento faz a partida rodar 2 passos por quadro mais vezes (p95). Única
  correção aplicada: `FxLayer.DOT_IMPACTS_PER_STEP = 4` (além disso cada tique de dano contínuo solta
  uma brasa só, sem faíscas nem clarão; ganho pequeno, ~0,2 ms, dentro do ruído) com teste em
  `integration_tests.gd`. As 9 juntas não acontecem numa partida (as uniões consomem as evoluções);
  o realista é uma união + uma evolução (+1,5 a 3,5 ms na média, p95 35-44 ms). Pendente: chamadas de
  desenho (152 → 230-480: poças de brasa, clones e marcas alternando textura e retângulo quebram o lote)
  e o p95 sob 500 inimigos.
- **Docs**: README (contagens reais: 41 armas = 18 base + 18 evoluções + 5 uniões e 15 passivos; o README
  dizia 26/12, desatualizado desde Kaminari/Inazuma/Onikiri; 153 missões novas depois de integrar a main com os Altares e o Tokoyo), seção "Fogo, gelo e
  sombra" e o `--arsenal` nas verificações; guia da Play Console com as notas da 1.23.0 (9.5.8) e a
  versão atual; ficha da loja nos 11 idiomas com o tópico novo, 41 armas/15 passivos e 194 missões (41 conquistas + 153).
- **Versão**: MENOR 1.22.0 → 1.23.0, versionCode 47 → 48 (`project.godot` e os 3 presets), ao integrar a
  main (1.22.0: Tokoyo, economia, testes em fatias); feito sobre a 1.18.0 como 1.19.0, que nunca saiu.
