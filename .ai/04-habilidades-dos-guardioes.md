# Habilidades dos Guardiões (1.18.0)

Pedido (01/11/2026): cada guardião ganha **três habilidades únicas**, ligadas à sua história, com
**recarga** e consumo de uma **energia própria**, também ligada à história (como Fúria × Mana no
Diablo). Efeitos fortes, sons e uma voz/grito do personagem ao soltar. O Golpe da Lanterna continua
como está (é a "ultimate" carregada por brasas); as habilidades são a camada nova, de uso frequente.

## Regras gerais

- **Desbloqueio dentro da partida pelo nível do guardião:** habilidade 1 no nível 1, 2 no nível 5,
  3 no nível 10 (ensina aos poucos). Botão travado mostra o cadeado e "Nv 5" / "Nv 10".
- **Custo** em energia e **recarga** em segundos. Só usa se tiver energia, a recarga zerou, o herói
  está vivo e o jogo não está pausado / em painel. Falta de energia: som curto de recusa, a barra de
  energia treme e pisca (sem gastar nada).
- **Escala:** dano = `base * might * poder`, com `poder = 1 + 0.035 * (nível - 1)`; raios por `area`;
  durações por `duration`; recarga por `cooldown` (o mesmo atributo das armas). Custo fixo.
- **Simulação determinística:** tudo roda no passo fixo da simulação (`step(dt)` do jogo), com o RNG
  da simulação; nada de `randf()` solto nem relógio real. Mesma semente = mesma partida em 1x/2x/3x,
  e o bot usa as habilidades por regras fixas (o hash de determinismo inclui o efeito delas).
- **Suspender partida:** energia, recargas e efeitos persistentes (armadilhas, zonas, barreiras)
  vão para o save da partida suspensa.
- **Entrada:** teclado `1` `2` `3` (e `J` `K` `L`), controle X / Y / B; no toque, 3 botões redondos
  em arco em volta do botão do Golpe, no lado oposto ao joystick (respeita canhoto e furo da câmera).
- **Retorno ao soltar:** voz/grito do guardião (sem palavras, vale para os 11 idiomas), assinatura
  sonora em camadas (`WeaponSfx`), efeito visual forte, tremor leve e o nome da habilidade em
  kanji + nome traduzido num letreiro curto acima do herói.
- **Missões/rastreio:** `RunTracker.abilities` (total de usos na partida), só registro.

## Energias e habilidades

Números em `data/abilities.json` (fonte única; abaixo, os valores iniciais).

### Aki — **Chama da Ordem** (灯火) · cor `ffb347`
Carrega a última chama da Ordem: regenera sozinha, **dobrada dentro da luz da lanterna** e pela metade fora.
máx 100, início 100, regen 5/s (×2 na luz, ×0.5 fora).

| # | Nome | Nv | Custo | Recarga | Efeito |
|---|------|----|-------|---------|--------|
| 1 | 暁閃 Passo da Aurora | 1 | 25 | 4 s | Avanço de 90 px na direção do movimento, invulnerável, corta todos no caminho (40) e deixa um rastro de luz. |
| 2 | 灯籠結界 Muralha da Lanterna | 5 | 40 | 12 s | Anel de luz r 70 por 3 s: apaga projéteis inimigos que tocam o anel, queima quem está na borda (12 a cada 0,25 s) e empurra para fora quem entra. |
| 3 | 百年の焔 Chama de Cem Anos | 10 | 60 | 16 s | Lança a chama no maior grupo até 160 px: após 0,5 s, coluna de fogo r 55 (120) e chão em brasa por 4 s (15 a cada 0,5 s). |

### Kenta — **Sombra** (影) · cor `8f7cf0`
Ninja do clã vizinho: a sombra cresce **enquanto se move** e mais rápido **fora da luz**.
máx 100, início 50, regen 8/s em movimento, 2/s parado, ×1.5 fora da luz.

| # | Nome | Nv | Custo | Recarga | Efeito |
|---|------|----|-------|---------|--------|
| 1 | 瞬身 Passo Sombrio | 1 | 20 | 3 s | Teleporte de 110 px atravessando inimigos (30 em quem cruzou), fumaça na origem que deixa lentos (−50%, 1,5 s). |
| 2 | 変わり身 Troca de Corpo | 5 | 45 | 14 s | Deixa um tronco-isca: inimigos até 180 px o perseguem por 3 s; depois ele explode (80, r 60). Kenta fica invulnerável 1 s. |
| 3 | 撒菱 Chuva de Makibishi | 10 | 55 | 15 s | Espalha 12 estrepes r 90 por 6 s (18 e −40% de velocidade a quem pisa) e solta 8 kunai em círculo (25). |

### Hana — **Prece** (霊力) · cor `9fffc4`
Miko herdeira do selo: energia espiritual que volta com calma, como mana, e cresce com a regeneração.
máx 120, início 120, regen 4/s + 2× o atributo `regen`.

| # | Nome | Nv | Custo | Recarga | Efeito |
|---|------|----|-------|---------|--------|
| 1 | 祓 Purificação | 1 | 25 | 3,5 s | Varredura do gohei em leque de 100°, alcance 80 (35, empurrão 180) e purifica projéteis inimigos no leque. |
| 2 | 結界 Kekkai | 5 | 50 | 15 s | Barreira sagrada r 80 por 5 s no lugar: inimigos dentro −60% de velocidade e 8 a cada 0,5 s; bloqueia tiros; Hana cura 2% da vida/s dentro. |
| 3 | 祖母の封印 Selo da Avó | 10 | 70 | 20 s | 5 ofuda selam o inimigo mais forte até 200 px (chefe primeiro): comum/elite é selado e destruído em 1 s (conta abate); chefe fica atordoado 2,5 s e leva 200. |

### Goro — **Penitência** (業) · cor `ffd36b`
Monge preso a um voto: a penitência vem da **dor que ele aceita** (dano recebido) e dos abates; esfria se ele foge do combate.
máx 100, início 0, +1,5 por ponto de vida perdido, +0,6 por abate, 1,5/s de base; perde 2/s depois de 4 s sem ganhar.

| # | Nome | Nv | Custo | Recarga | Efeito |
|---|------|----|-------|---------|--------|
| 1 | 金剛身 Corpo de Diamante | 1 | 30 | 10 s | 4 s com −60% de dano recebido e devolve 50% do dano de contato; aura dourada. |
| 2 | 錫杖 Golpe do Shakujō | 5 | 40 | 8 s | Bate o cajado: onda r 110 (70) e atordoa 1,2 s; argolas do cajado tilintam. |
| 3 | 師の真言 Mantra do Mestre | 10 | 70 | 18 s | 3 pulsos de mantra (a cada 0,6 s) r 140 (45 cada); cada inimigo atingido cura 1 (máx 15 por pulso). |

### Rin — **Foco** (集中) · cor `ffe08a`
Caçadora contra o tempo: o foco enche **rápido parada** (mirando) e devagar em movimento.
máx 100, início 100, regen 14/s parada, 4/s em movimento.

| # | Nome | Nv | Custo | Recarga | Efeito |
|---|------|----|-------|---------|--------|
| 1 | 破魔矢 Hamaya | 1 | 25 | 2,5 s | Flecha sagrada para o inimigo mais próximo (ou a frente): atravessa tudo numa linha de 320 px (60). |
| 2 | 罠 Armadilha de Caça | 5 | 35 | 6 s | Armadilha aos pés (dura 12 s, no máx. 2): os 6 primeiros que entram em r 40 ficam presos 3 s e levam 40. |
| 3 | 燕返し Salto da Andorinha | 10 | 50 | 9 s | Salto para trás de 80 px (invulnerável) e leque de 9 flechas para onde estava (35, atravessa 3). |

### Tora — **Calor da Forja** (熱) · cor `ff7a3a`
Ferreiro de 70 anos: o calor sobe **batendo** (cada acerto das armas) e esfria parado.
máx 100, início 0, +0,5 por acerto, +1 por abate; perde 3/s depois de 3 s sem acertar.

| # | Nome | Nv | Custo | Recarga | Efeito |
|---|------|----|-------|---------|--------|
| 1 | 鉄槌 Martelo na Bigorna | 1 | 30 | 5 s | Martelada 40 px à frente, r 60 (70), atordoa 0,8 s, chuva de fagulhas. |
| 2 | 鎖引き Corrente Puxadora | 5 | 45 | 12 s | A corrente gira 360°: puxa todos até 170 px para perto (30) e, 0,4 s depois, estouro r 50 (60). |
| 3 | 焼き入れ Têmpera | 10 | 70 | 18 s | Explosão de vapor r 120 (90, empurrão 380); por 6 s +5 de armadura e cura 10% da vida. |

### Yuki — **Sangue Oni** (鬼血) · cor `ff4a4a`
A meio-oni: o sangue oni cresce **com os abates** e fora da luz, e **a luz o queima** (perde dentro dela).
Única: se faltar energia, paga a diferença com **vida** (1 de vida por 2 de energia), só acima de 30% da vida.
máx 100, início 30, +3 por abate, +2/s fora da luz, −2/s dentro da luz.

| # | Nome | Nv | Custo | Recarga | Efeito |
|---|------|----|-------|---------|--------|
| 1 | 鬼爪 Garra Oni | 1 | 25 | 3,5 s | Salto de 100 px rumo ao inimigo mais próximo e 3 garradas ao cair, r 45 (30 cada). |
| 2 | 鬼哭 Rugido Oni | 5 | 40 | 13 s | Rugido r 150: inimigos fogem 2,5 s (medo), levam 25 e os tiros inimigos somem. |
| 3 | 鬼神斬 Redemoinho Onikiri | 10 | 65 | 16 s | 2 s girando a lâmina r 70: 12 golpes de 22, rouba 10% do dano em vida (máx 30), +30% de velocidade. |

## Arquitetura

- `data/abilities.json`: por herói, `energy` (id, cor, máx, início, regras de ganho/perda) e
  `abilities` (3 itens: id, kanji, nível, custo, recarga, ícone, voz, sfx, params).
- `scripts/systems/hero_energy.gd` (`HeroEnergy`): energia genérica movida pelos eventos
  (passo, movimento, luz, dano recebido, acerto, abate) segundo as regras do JSON.
- `scripts/systems/ability_system.gd` (`AbilitySystem`): recargas, custo, desbloqueio, entrada,
  save, rastreio, letreiro, voz e despacho para o comportamento de cada herói.
- `scripts/systems/abilities/<herói>_abilities.gd`: comportamento das 3 habilidades de cada herói
  (efeitos persistentes com `step(dt)`), usando primitivas comuns:
  - inimigos (`EnemyManager`): lentidão, prender (root), medo (fugir), isca (taunt), puxar,
    atordoar em área, dano em linha / leque;
  - tiros inimigos (`EnemyShotManager`): apagar em círculo / leque;
  - jogador (`Player`): avanço/teleporte com invulnerabilidade, redução de dano, espinhos,
    armadura temporária.
- Áudio: `assets/audio/voice/<herói>_<n>.ogg` (gritos CC0, tratados por herói) e cues
  `ab_<id>` em `WeaponSfx`.
- Ícones 24x24 próprios em `assets/art/ui/ability_icons/` (CC0, autoria do projeto).
- UI: HUD (3 botões + barra de energia), tela do guardião, Diário (ficha do herói) e o Guia
  (capítulo das habilidades e energias), em 11 idiomas, com testes de layout em todas as resoluções.

## IDs (fixos; usados em dados, textos, ícones, sons e testes)

| Herói | Energia | Habilidade 1 | Habilidade 2 | Habilidade 3 |
|---|---|---|---|---|
| aki | `order_flame` | `dawn_step` | `lantern_wall` | `century_flame` |
| kenta | `shadow` | `shadow_step` | `kawarimi` | `makibishi` |
| hana | `prayer` | `harae` | `kekkai` | `grandmother_seal` |
| goro | `penance` | `diamond_body` | `shakujo` | `master_mantra` |
| rin | `focus` | `hamaya` | `hunting_trap` | `swallow_leap` |
| tora | `forge_heat` | `anvil_hammer` | `chain_pull` | `quench` |
| yuki | `oni_blood` | `oni_claw` | `oni_roar` | `onikiri_whirl` |

- Textos: `ability.<id>.name`, `ability.<id>.desc` (curta, ≤ 90 caracteres em pt-BR, com os números
  principais), `energy.<id>.name`, `energy.<id>.desc` (como enche/esvazia, ≤ 110), e os da UI:
  `ability.locked` ("Nv %d"), `ability.no_energy`, `ability.cooldown`, `ability.cost` ("%d de %s"),
  `heroes.abilities_label`, `heroes.energy_label`, `tutorial.abilities`, e o capítulo do Guia
  `guide.abilities.*`. O kanji fica no JSON (`kanji`), não nos textos.
- Ícones: `res://assets/art/ui/ability_icons/<id>.png` (24x24) e `res://assets/art/ui/ability_icons/energy_<energia>.png` (12x12).
- Voz: `res://assets/audio/voice/<herói>_<1|2|3>.ogg` (uma por habilidade; pode haver `_b` como variação).
- Som: cue `ab_<id>` em `WeaponSfx.CUES` (lançamento) e, quando houver, `ab_<id>_hit` (impacto/fim).
