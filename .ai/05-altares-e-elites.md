# Altares do Selo (封印の祭壇) e Inimigos Elite

Documento de design. Fonte da verdade para os executores; números finais vivem como constantes
nomeadas no código (`scripts/systems/altar_system.gd`, `scripts/systems/elite_affixes.gd`) e são
lidos pelo Guia do Diário em tempo real, como o resto do Guia.

## Fantasia

Pelos mapas há altares de pedra antigos, selados com cordas shimenawa e ofuda. O guardião que fica
dentro do círculo do altar "lê o selo": runas acendem uma a uma, o anel de progresso enche, raios
começam a cair em volta. Quando o selo quebra, o altar libera o que estava preso: às vezes uma
emboscada, às vezes um **Elite** — um yōkai mais forte, com poderes, que aparece com uma animação
própria e, ao morrer, derruba um baú ou um item raro. Risco escolhido pelo jogador = recompensa.

## Regras (simulação — tudo em `step(dt)`, só `game.rng`, determinístico)

### Posicionamento
- Gerado por chunk em `WorldMap.chunk_data(c)` (mesmo padrão das `statues`): lista `altars: [pos]`.
- Probabilidade por chunk `ALTAR_CHANCE` (~0,10, ajustar para ~1 altar a cada 15–25 s de corrida
  em linha reta), nunca a menos de `ALTAR_MIN_START_DIST` (~520 px) do início da fase, distância
  mínima entre altares (checar chunks vizinhos pelo hash, ou só 1 por chunk + chance baixa).
- Altar é sólido no centro (raio pequeno, ~10 px) e reserva um círculo livre (raio do ritual + folga)
  para o terreno não nascer em cima.
- Estado "usado" guardado num dicionário por chave de posição (como `_destroyed_lanterns`), sobrevive
  a descarregar o chunk e entra no snapshot.
- Fases sem altar: Noite Sem Fim e Desafio Diário têm altar (são bons nelas); travessia do Kakuriyo
  (rift) e luta de chefe: altares não ativam enquanto um chefe/midboss estiver vivo (o anel fica
  apagado, com cadeado), para não empilhar perigo injusto.

### Ritual (estados de cada altar)
`DORMANT → CHANNELING → BREAKING → SPENT`
- **DORMANT**: brilho fraco, ofuda balançando. Guardião entra no raio `ALTAR_RADIUS` (~44 px) → CHANNELING.
- **CHANNELING**: progresso sobe `1 / ALTAR_CHANNEL_TIME` por segundo (~3,5 s). Fora do raio o
  progresso cai a `ALTAR_DECAY` (metade da velocidade); a 0 volta a DORMANT. 4 runas acendem em
  25/50/75/100 % (som de sino a cada uma, tom subindo). A partir de 50 % caem raios decorativos em
  volta (só visual) e inimigos próximos são levemente atraídos (sensação de ameaça).
- **BREAKING** (`ALTAR_BREAK_TIME` ~1,2 s): o selo estoura → libera o resultado (abaixo). Guardião
  não precisa mais ficar.
- **SPENT**: altar rachado, sem brilho, fumaça fina. Nunca reativa.

### Resultado do altar
Rolagem com `game.rng`, com "pena" (pity) para o Elite sempre vir:
- `elite_chance = ALTAR_ELITE_BASE (0,40) + ALTAR_ELITE_PITY (0,30) × altares_sem_elite`; 3º altar
  sem elite garante. O 1º altar da partida é sempre Elite se a partida já passou de 3 min (primeira
  impressão forte); antes disso, emboscada.
- **Emboscada**: anel de `6 + 2×minuto/3` (teto ~16) inimigos da fase surgindo com raio + fumaça em
  volta do altar, mais 1 "campeão" (inimigo da fase com `elite` comum, sem afixos). Drop: bolsa de ryō.
- **Elite**: um inimigo da fase (escolhido entre os não-`prop`, não-`swarm`, preferindo `tank`,
  `charger`, `shooter`, `chaser`) com o flag `elite` + **afixos**.

### Elite com poderes (afixos)
- Número de afixos: 1 antes de `ELITE_TWO_AFFIX_T` (8 min), 2 depois; Lua Vermelha/dificuldade alta +1
  (máx. 3). Sem afixos repetidos; combinações proibidas definidas no código.
- HP: `ELITE_HP` atual × `(1 + 0,35 × (afixos-1))`. Velocidade +10 %. Resistência a empurrão.
- Afixos (reaproveitam a biblioteca de padrões de chefes: `areas.telegraph`, `enemy_shots.spawn`,
  `hazard_pool`, `beam`). Cada um tem nome (i18n), cor, ícone e kanji:
  | id | kanji | nome pt-BR | poder |
  |---|---|---|---|
  | `raijin` | 雷 | do Trovão | a cada ~4 s marca 3 círculos perto do guardião (telegraph 0,9 s) e cai um raio em cada |
  | `kitsunebi` | 狐 | da Raposa | leque de 5 fogos-fátuos (`fox_fire`) a cada ~3 s |
  | `kagero` | 陽 | Miragem | a cada ~5 s some num estalo e reaparece atrás do guardião (telegraph no destino) |
  | `iwa` | 岩 | da Rocha | para, ergue-se e bate no chão: onda de choque com telegraph em anel (~70 px) |
  | `kasumi` | 霞 | da Névoa | invoca 4 lacaios com fumaça a cada ~7 s (teto de lacaios vivos) |
  | `kongo` | 剛 | Diamante | escudo que absorve X de dano e volta a cada ~8 s (bolha visível, estilhaça) |
  | `yomi` | 冥 | do Yomi | deixa poças de miasma pelo caminho (`hazard_pool`) |
  | `kaze` | 風 | do Vento | investida (charge) com telegraph em linha a cada ~4 s |
- Nome exibido: "<Inimigo> <afixo>" ex.: "Kappa do Trovão", e com 2: "Kappa do Trovão · Miragem".
  Formato via chave i18n (ordem das palavras varia por idioma).
- Dano dos poderes escala com `game.enemy_damage_mult()`.

### Animação de surgimento do Elite (BREAKING → ~1,6 s total, o Elite fica `controlled`, invulnerável e parado)
1. 0,0 s: selo estoura — flash branco no altar, anel de choque (`shockwave` + `distort`), estilhaços
   de ofuda (partículas de papel), som de vidro/selo quebrando + trovão grave. Tremida média.
2. 0,1–0,8 s: 3–5 raios ramificados (novo efeito procedural `fx.lightning_bolt(from, to, color)`)
   caem do céu no altar, coluna de luz (`Raylight`) cresce, círculo de runas no chão gira e se expande
   (textura assada uma vez, só rotação/escala por quadro), vento puxa partículas para o centro.
   O jogo desacelera levemente (hit-stop curto 0,08 s, opcional, só visual se não puder mexer na simulação).
3. 0,8–1,4 s: silhueta do Elite sobe do chão (escala 0→1 com sobre-salto, silhueta branca/cor do afixo
   piscando para a cor real), poeira e pedras (`rock`), som de rugido (`e_roar` com pitch do tamanho).
4. 1,4 s: rugido final, explosão de ar (empurra inimigos comuns e o guardião levemente), banner no
   HUD com o nome do Elite e os kanji dos afixos ("強敵" — "Elite!"), tremida forte, vibração.
   Elite liberado.
- O Elite tem barra de vida própria sobre a cabeça (fina, com cor dos afixos e marcas dos kanji) e aura
  da cor do primeiro afixo (por cima da aura dourada do elite comum).

### Morte do Elite e drop
- Explosão grande em camadas: flash, `explosion` sprite, anel duplo, estilhaços dourados, pilar de luz
  curto, som de explosão + sino de vitória (jingle curto), tremida, hit-stop curto.
- Drop: 2+ afixos → **baú de chefe** (`chest` com `boss: true`) sempre. 1 afixo → 65 % baú comum,
  35 % item raro (`solar_ember` / `hourglass` / `purifying_bell` / `magnet_scroll`, peso igual) +
  bolsa de ryō. Itens saem num pequeno arco ("pop") até um `free_point`.
- Altar volta a SPENT com uma nuvem dourada subindo (feedback de "selo vencido").

## Feedback e interface
- No mundo: anel do raio do altar (Stroke.arc, nunca draw_arc), arco de progresso, 4 runas, ícone de
  cadeado quando bloqueado por chefe.
- HUD: seta fora da tela para o altar dormente mais próximo dentro de `ALTAR_ARROW_RANGE` (~520 px),
  discreta (reusar `RiftPortal.draw_arrow`); banner de Elite; toast do resultado ("Emboscada!").
- Som: zumbido posicional enquanto canaliza (pitch sobe com o progresso), sinos nas runas, trovão e
  estouro no BREAKING, rugido, explosão de morte. Respeitar `GameClock.paused`.
- Vibração (Settings.vibrate) no estouro e na morte do Elite.
- Qualidade Baixa (`gfx_quality`): menos raios/partículas, sem distort.

## Meta
- RunTracker: `altars_awakened`, `altar_ambushes`, `altar_elites_slain`, `elite_affix_max` (só leitura,
  não muda o hash da simulação além do próprio sistema).
- Missões do Santuário (nova categoria ou dentro de "abates"): despertar 1 / 10 / 50 altares, derrotar
  1 / 10 / 50 Elites de altar, derrotar um Elite com 3 afixos, derrotar um Elite de cada afixo
  (coleção), 3 altares numa partida. Recompensas no padrão existente.
- Diário: Guia ganha seção "Altares do Selo" (no capítulo de chefes ou capítulo novo), números lidos
  das constantes; afixos listados com kanji/nome/poder; descoberta respeitada (afixo não visto = "?").
- Dica 心得 nova sobre altares (aparece depois de ver o 1º altar).
- Textos em 11 idiomas (`tools/i18n/*.py` + `python -I tools/build_i18n.py`).
- Bot (`bot_pilot.gd`): quando saudável (HP > 60 %), sem chefe vivo, e altar dormente a < 300 px,
  vai até ele e fica até quebrar; foge da emboscada como hoje. Assim o E2E exercita a mecânica.

## Ativos e licenças
- Sons novos gerados por `tools/gen_altar_sfx.py` (semente fixa, CC0 do próprio Hyakki, mesmo padrão
  de `gen_portal_sfx.py`): `alt_hum` (loop), `alt_rune_0..3`, `alt_break`, `alt_thunder_0..2`,
  `alt_elite_rise`, `alt_elite_death`, `alt_shield_break`. Somar com sons CC0 ainda não usados do Ninja
  Adventure (Explosion2/4/5, Magic3/5, Alert, Voice) importados para `assets/audio/sfx/`.
- FX novas: `Raylight` (já importado, sem uso), `Elemental/Rock` e `Attack/CutDouble` do Ninja (CC0),
  FreeMix `explosion`/`impact_0x` (licença já aprovada). Arte do altar: gerada por script
  (`tools/gen_altar_art.py`, CC0 próprio, pixel art 32×32 em 3 estados + runas + círculo de runas
  + ofuda) — mantém o estilo pixel do jogo.
- Toda entrada nova em `licenses/registry.json` + `python -I tools/build_license_index.py` +
  `python -I tools/check_licenses.py`; créditos atualizados.

## Testes (obrigatórios)
- Unitários: posicionamento determinístico (mesmo seed → mesmos altares, distância mínima ao início),
  progresso/decaimento, bloqueio com chefe, pity do Elite, sorteio de afixos (sem repetição, contagem
  por tempo), HP do Elite, drop, snapshot/restore no meio do ritual e no meio do surgimento.
- Integração (modelo `tests/realm_tests.gd`): partida real, guardião parado no altar → Elite surge
  com animação (fica invulnerável durante), poderes disparam, matar → baú no chão; bot visita altar.
- Layout: banner do Elite e barra de vida em todas as resoluções × 11 idiomas × furo dos dois lados.
- Determinismo: hash igual em 1x/2x/3x e Baixa (`run_checks`).
- Desempenho: `game_bench` com Elite + afixos ativos sem piorar p95.
- Versão: MENOR (funcionalidade nova).
