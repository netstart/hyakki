# Hyakki — Até o Amanhecer

Survivors-like para Android (paisagem), feito em Godot 4.7.2 com assets gratuitos e licenças verificadas.
Plano completo: [.ai/01-hyakki-survivors-game-plan.md](.ai/01-hyakki-survivors-game-plan.md) ·
progresso e checklist: [.ai/03-progresso-implementacao.md](.ai/03-progresso-implementacao.md).

## O que tem

- 8 guardiões (incluindo Yuki, a meio-oni, desbloqueada ao vencer o Oni Vermelho, e Kuon, a shinobi dos mortos,
  liberada ao vencer a Gashadokuro), 7 fases (5 + secreta + Monte do Medo), 48 armas (21 base, 21 evoluções,
  6 uniões), 17 passivos (relíquias), 40 yōkai, 28 chefes (21 + 7 Sombras do Guardião 影), 15 Kami, 8 Golpes
  da Lanterna, Baú Laqueado, itens de chão e perigos por fase.
- **Monte do Medo e Kuon** (1.28.0): a 7ª fase, **Osorezan (恐山)**, abre ao vencer a Encosta dos Mortos.
  Campos de enxofre com cata-ventos, pilhas de pedras e o rio Sanzu; o Kakuriyo é **Sai no Kawara**, a margem
  dos seixos. Chefes novos: o **Onryō de Masakado** (5:00), **Datsue-ba**, a velha do rio, como Guardiã do
  Limiar (7:30, com a sua Sombra no Kakuriyo) e a **Gashadokuro** (10:00), o esqueleto gigante dos mortos sem
  enterro; inimigos novos gaki, funayūrei e a ossada rastejante. Vencer a Gashadokuro liberta **Kuon (久遠)**,
  a 8ª guardiã, a última do clã Hakamori: energia **Almas (魂)**, servos espectrais que se levantam dos abates,
  3 habilidades (Caça às Almas, Muralha de Ossos, Retorno de Yomi), o Golpe Rito dos Hakamori e um arsenal só
  dela (3 armas, 2 relíquias, 3 evoluções e a união **Exército de Yomi**), que não aparece para os outros
  guardiões. História nova narrada por Tora (a libertação da Kuon e o epílogo do Monte do Medo), diálogos com
  resposta da Kuon para todos os chefes, conquistas e missões da fase.
- **Fogo, gelo e sombra** ([.ai/06-fogo-gelo-clones.md](.ai/06-fogo-gelo-clones.md), 1.23.0): três linhas
  novas sem desbloqueio, cada uma arma base → relíquia → evolução:
  Hōroku-biya 焙烙火矢 (pote de pólvora em arco, explosão e chão em brasa) + Pedra de Fogo → Kagutsuchi
  (3 potes; quem morre queimando espalha as chamas); Tsurara 氷柱 (leque de pingentes que gelam) + Pente da
  Yuki-onna → Sopro da Yuki-onna (anel de 15 pingentes que estilhaçam os congelados); Kage Bunshin 影分身
  (clones de sombra que cortam em meia-lua) + Espelho Yata → Mil Sombras (4 clones permanentes e clone extra
  nos abates). Três uniões cruzam os elementos: **Taikyoku do Onmyō** (Kagutsuchi + Sopro da Yuki-onna,
  orbes de fogo e gelo em yin-yang com pulso de Choque Térmico), **Casamento da Raposa** (Kagutsuchi + Mil
  Sombras, clones de fogo-fátuo que explodem) e **Espelho de Gelo** (Sopro da Yuki-onna + Mil Sombras, clones
  de gelo que estilhaçam em leque). Estados novos nos yōkai: Queimadura (tique a cada 0,5 s, sem somar) e
  Frio (lentidão e 5 pilhas congelam; chefes só ficam lentos), Estilhaçar e Choque Térmico (fogo em
  congelado ou gelo em queimando dobra o golpe). Itens de chão Jarro de Fogo (a tela toda queima por 4 s) e
  Caco do Espelho (3 clones por 10 s). Ícones próprios (elementos gelo e sombra), impacto `hit_ice` e sons de
  lançamento em camadas (pavio assobiando, cristais tilintando, selo com fumaça); 6 missões novas
  (3 evoluções e 3 uniões) e uma seção no Guia com os números lidos do código.
- **Habilidades dos guardiões** ([.ai/04-habilidades-dos-guardioes.md](.ai/04-habilidades-dos-guardioes.md)):
  24 habilidades (3 por guardião, ligadas à história de cada um, liberadas nos níveis 1, 5 e 10 da partida)
  e 8 energias próprias (Chama da Ordem, Sombra, Prece, Penitência, Foco, Calor da Forja, Sangue Oni, que
  a Yuki pode pagar com vida, e Almas, da Kuon), com recarga, efeitos, som em camadas, grito do guardião e o letreiro
  kanji + nome. Números em `data/abilities.json`; o bot usa as três por regras fixas (determinístico).
  No toque, 3 botões em arco ao lado do Golpe; ficha na tela do guardião, no Diário e um capítulo no Guia.
- **Três níveis por fase** ([.ai/06-tokoyo-terceiro-nivel.md](.ai/06-tokoyo-terceiro-nivel.md)): a fase, o
  **Kakuriyo (隠世)**, o mundo oculto aberto pelo portal violeta do Guardião do Limiar (7:30), e o **Tokoyo
  (常世)**, a Terra Eterna. No Kakuriyo surge a **Sombra do Guardião** (影, 6 chefes novos, a partir das 9:00
  ou 45 s depois da chegada), que deixa dois baús de chefe e um **torii dourado**; do outro lado fica um
  santuário claro e dourado com mapa próprio (praça com tōrō e quatro torii, caminhos sagrados e espelhos
  d'água), onde mora o **último chefe** da fase, que agora só aparece no Tokoyo (8 s depois da chegada, a
  partir das 10:00). Quem não atravessa vence ao amanhecer sem a luta final. Os portais são convites (nunca
  puxam); Noite Sem Fim, Desafio Diário, Lua Vermelha e partida suspensa valem nos três níveis. Missões
  "chegar ao Tokoyo" por fase e no total; o bot atravessa os dois portais com o mesmo hash em 1x/2x/3x.
- Omikuji do baú (おみくじ): antes de abrir, o tubo de madeira solta a sorte (吉 1 item, 中吉 3, 大吉 5,
  e às vezes 凶 com consolo em ryō, amarrado no galho) e uma roleta para em cada item. A sorte só mostra a
  contagem já sorteada; os 3 primeiros baús comuns do save saem com 中吉 garantido (o bot não usa nem gasta
  esses baús, então os testes de determinismo não dependem do save). Opção "Animação curta do baú".
- Tela de nível: **Rerrolar sempre à mão** (cargas grátis do Santuário primeiro; sem elas, 10 ryō da partida
  na 1ª rolagem paga e +10 a cada outra, com cartas novas sempre que o sorteio tiver outras) e, com tudo no
  máximo, a mão comida/moedas com "Não perguntar mais": a escolha vira automática, sem pausar a luta, só com
  o som (com a vida cheia, "Comida" pega as moedas); muda em Opções e no menu de pausa.
- Santuário (18 power-ups, reembolso total; preços base de 240 a 12.000 ryō em `data/powerups.json`), **Missões do Santuário** (as 44 conquistas que desbloqueiam conteúdo
  e mais 170 missões em 11 categorias, cada uma com recompensa e barra de progresso no Diário, e as
  Próximas 3 metas no título e nos Resultados), Diário do Guardião
  (com o **Guia**: 9 capítulos de manual montados dos dados do jogo, sem revelar o que não foi descoberto),
  história completa, Noite Sem Fim (o ryō ganho depois do amanhecer vale ×1,5), Desafio Diário, Brisa / Normal / Lua Vermelha I–V (regras cumulativas em
  `scripts/systems/red_moon.gd`: I +50% de elites, II o Eclipse dos chefes, III Sombras também na luz, IV sem
  onigiri, V só 2 pactos dos Kami).
- Velocidade **1x / 2x / 3x** com passo fixo: a mesma semente gera a mesma partida em qualquer velocidade.
  2x e 3x são liberados pela **Ampulheta de Fūjin**, compra única e permanente na Loja: 3.000 ryō ou
  dinheiro (Google Play, produto `unlock_speed`, R$ 4,99 / US$ 1,99). O bot e o `--speed=N` dos testes
  aceleram sem a compra.
- **11 idiomas** (pt-BR, en, es, de, fr, ru, id, ja, ko, zh-TW, zh-CN) com a fonte Fusion Pixel.
- Monetização do plano 17: só anúncios premiados opcionais (sem anúncio de abertura), Loja com recompensas a
  cada 6 h, reviver e dobrar ryō, a compra "Apoiar o jogo" (Lanterna Dourada e recompensas sem anúncio) e a Ampulheta de Fūjin (velocidade 2x/3x, com ryō ou dinheiro). **Hoje com provedores simulados** (sem SDK do AdMob/Billing).
- Telas Licenças e Créditos geradas do registro de licenças.

## Rodar no PC

Para abrir o projeto no editor do Godot 4.7.2:

```powershell
C:\src\tools\godot\Godot_v4.7.2-stable_win64.exe --editor --path C:\src\hyakki
```

Na primeira abertura, espere a importação dos recursos terminar e pressione **F5** para executar o projeto
(ou use **Executar projeto** no canto superior direito). O jogo também pode ser aberto diretamente:

```powershell
C:\src\tools\godot\Godot_v4.7.2-stable_win64.exe --path C:\src\hyakki
```

### Testar todos os heróis

Execute este comando para abrir o jogo em modo de desenvolvimento com os oito guardiões liberados:

```powershell
C:\src\tools\godot\Godot_v4.7.2-stable_win64.exe --path C:\src\hyakki
```

Ao iniciar, a build de desenvolvimento libera e salva automaticamente Aki, Kenta, Hana, Goro, Rin, Tora,
Yuki e Kuon no perfil local, preservando o restante do progresso. Esse desbloqueio automático é exclusivo da build
de desenvolvimento; na build de produção, os heróis continuam sendo liberados pela progressão normal.

Teclas: **WASD/setas** movem · **Esc/P** pausa · **Tab** velocidade · **Espaço/E** Golpe da Lanterna ·
**1/2/3** ou **J/K/L** habilidades (controle: **X/Y/B**) · **F3** desempenho · **F4** hitboxes. O mouse simula o toque (arraste na metade esquerda para o joystick).

## Verificações

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_checks.ps1
```

Primeiro a importação (sintaxe de todos os scripts), sozinha; depois, numa **fila com teto**, cada tarefa num
processo próprio: os testes de integração em N fatias (dados, idiomas, cobertura de glifos, Loja, Santuário,
save, regras de anúncio, as suítes de cada sistema e o layout de toda tela em todas as resoluções × 11 idiomas ×
furo dos dois lados), os testes de regras, o determinismo (bot em 1x, 2x, 3x e 3x na Baixa, mesmo hash; de
novo com o arsenal de fogo, gelo e clones, `arsenal_*`), a
jornada pelos três níveis (1x, 2x e 3x, mesmo hash), o estresse com 500 inimigos, o `gdlint` em partes, os
checks em Python (textos, chaves × 11 idiomas e marcadores `%s/%d`; licenças; ficha da loja; site irmão) e, com
janela (sem `--headless`), os traços e discos do `Stroke` iguais aos do motor pixel a pixel
(`tests/stroke_pixel_tests.tscn`), o mesmo quadro de uma partida pelos dois caminhos (`tests/game_bench.tscn
--compare-shots --strict`) e a navegação entre os menus sem piscar (`tests/nav_bench.tscn --strict-flicker`, em 3
processos). No fim, um resumo por tarefa, as 5 mais lentas e o pico de processos e de memória; qualquer falha,
erro de script ou trava reprova o todo.

- **Teto e fila (a máquina não trava):** no máximo `-MaxParallel` tarefas ao mesmo tempo (padrão: núcleos
  lógicos − 2, e nunca mais do que a memória disponível comporta: (disponível − `-ReserveMB` 4096) /
  `-GodotMemoryMB` 600; uma fatia headless fica em ~500 MB, um Godot com janela em ~800 MB). As tarefas
  esperam numa fila, da mais longa para a mais curta (jornada, fatias, partidas do bot, regras, navegação,
  pixels, lint, Python), e cada vaga liberada puxa a próxima, se ainda houver memória para mais um Godot.
- **Prioridade:** o Godot sobe a própria prioridade ao abrir; o `run_checks` baixa cada um para
  **BelowNormal** (o PC continua usável durante os testes) e deixa só a jornada, a tarefa mais longa (uma
  partida de 11 min que não se divide, 3 processos), em Normal. No
  Linux, as outras rodam com `nice -n 10`. `-SamePriority` desliga.
- **Fatias (`--shard=k/N`):** cada processo da integração roda a sua parte das unidades (caso de layout,
  idioma) de `DeviceProfiles.layout_cases()` (em blocos contíguos) e das suítes sem layout (repartidas pelo
  custo medido em `SUITE_MS`, em `tests/integration_tests.gd`). Os casos de layout são repartidos pelo custo
  (`TestShards.plan_layout` com `LAYOUT_MS`): a fatia que recebe uma suíte sem layout cara (AbilityTests,
  RealmTests) fica com menos casos, para todas terminarem juntas. Padrão: `MaxParallel − 4` fatias (a jornada
  ocupa 3 vagas e sobra 1 para a fila das tarefas curtas, que depois entram nas vagas que se liberam). A união das fatias é o conjunto completo:
  `tests/test_shards.gd` confere a partição para N = 1..16 e cada fatia imprime a linha `COBERTURA`, que o
  `run_checks` confere (casos de 0 ao total sem buraco e toda suíte rodada em alguma fatia). Também imprime
  `SUÍTE <nome>: <ms>, <verificações>` por suíte (é de onde saem os números de `SUITE_MS` e `LAYOUT_MS`), e `PROGRESSO` a cada 60 s no meio
  de uma suíte longa, para o vigia de 8 min não confundir uma fatia ocupada com uma travada.
- **Uma suíte só:** a integração aceita `-- --suites=A,B` (ou `--suite=A`): roda só essas suítes inteiras (a
  parte sem layout e todos os casos de layout). Vale o nome da tabela ou o do arquivo, como começo:
  `red_moon` roda `RedMoonTests` e `RedMoonTests.run_unit`, `damage_number` as três suítes dos números de
  dano, `menus_layout`, `shop_layout`, `ability`, `mission`... Nome que não acha nenhuma suíte reprova.
  ```powershell
  Godot_v4.7.2-stable_win64_console.exe --headless --path . --fixed-fps 60 res://tests/integration_tests.tscn -- --suites=red_moon
  ```
  Os unitários sem árvore (`run_unit` de cada suíte) ficam nos testes de regras:
  `Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/run_tests.gd`. As cenas
  `tests/*_tests.tscn` que restam (Altar, Créditos, números de dano, HUD, baú de nível, pausa, outro mundo,
  Resultados, Santuário, Loja, Jornada e título) só gravam capturas para conferir o visual
  (`-- --shots=<pasta>`, sem `--headless`); sem `--shots` elas dizem qual `--suites=` usar.
- **Isolamento:** cada Godot roda com uma APPDATA própria (Linux: `XDG_DATA_HOME`) numa pasta temporária, então
  `user://` (save, `settings.cfg`, `runs.csv`, logs) nunca é o perfil real do jogador; a integração confere
  `OS.get_user_data_dir()` contra a pasta isolada e o `run_checks` confere no fim que o perfil real não mudou.
  Fora do `run_checks`, um Godot de teste por vez.
- **Tempo de simulação:** a integração roda com `--fixed-fps 60`; as esperas dos testes contam quadros e
  tempo de simulação (`tests/sim_clock.gd`, `UiClock`), nunca o relógio da parede.
- **Opções:** `-MaxParallel N`, `-GodotMemoryMB M`, `-ReserveMB M`, `-Shards N` (padrão: `MaxParallel − 4`,
  entre 2 e 12), `-StallMinutes M` (padrão 8: tarefa sem saída nova por M minutos é encerrada à força e rodada
  de novo uma vez; travou de novo = falha), `-StressAlone` (o estresse sozinho no fim, com os números sem
  disputa de CPU), `-NoWindow` (pula as tarefas com janela), `-NavShards N` (padrão 3), `-SamePriority`,
  `-Only integracao,regras` (só essas tarefas), `-KeepTemp`. Saída de cada tarefa em
  `build\checks\<data_hora>\<tarefa>.log`.
- **Linux/CI:** `GODOT=/caminho/godot tools/run_checks.sh` (o mesmo, com `MAX_PARALLEL`, `GODOT_MEMORY_MB`,
  `RESERVE_MB`, `SHARDS`, `STALL_MINUTES`, `NO_WINDOW`, `NAV_SHARDS`, `SAME_PRIORITY` e `ONLY`; sem tela, as
  tarefas com janela são puladas; a prioridade baixa é `nice -n 10`).
- **Fora do `run_checks` (de propósito):** os limites de ms do `tests/nav_bench.tscn -- --strict` e os números do
  `tests/game_bench.tscn` mudam com a disputa de CPU (sozinho no PC, o `--strict` já passa de 20 ms em p95 de
  vez em quando): rode-os à mão, sozinhos, antes e depois de mexer em telas ou no desenho. As capturas
  (`tests/surface_shots.tscn` e os `--shots` das cenas acima) são para olhar, não têm critério.

Tempos neste PC (16 núcleos lógicos, 30 GB, com outro agente rodando 4 bots ao mesmo tempo), do
`run_checks.ps1` inteiro: **806 s** antes (33 tarefas abertas de uma vez, 12 fatias; a jornada 1x, 788 s, era a
mais lenta) e **~960 s** agora (36 tarefas, 5 delas novas: navegação em 3 processos e as duas comparações de
pixels; no máximo 14 ao mesmo tempo, 10 fatias). O tempo total é o da jornada 1x (uma partida de 11 min que
não se divide, ~940 s); as fatias terminam antes dela (~730–900 s). Em troca, a máquina não engasga: no
máximo 14 Godot de teste em vez de 24 (sem teto, as tarefas curtas ficavam 2 a 7 vezes mais lentas: o
`gdlint` de 25 s para 180 s), o pico de memória dos Godot cai de ~12,3 GB para ~7,0 GB e a memória livre
mínima sobe de ~4,2 GB para ~9,5 GB (uma fatia chega a ~590 MB, a importação a ~790 MB, a navegação com
janela a ~550 MB, a jornada a ~330 MB). Histórico: 3322 s (≈ 55 min) com tudo em série, antes da 1.20.4.

Para um relatório completo (resumo por etapa, falhas com o texto inteiro, tempos e logs) em
`build\test-report\<data_hora>\relatorio.html`:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_tests_report.ps1
```

`-SkipStress` pula o estresse, `-NoOpen` não abre o navegador e `-ListPassed` lista também cada verificação
que passou (`--verbose`, milhões de linhas). O relatório roda as etapas em sequência, com `user://` isolado.

Suítes que se rodam sozinhas com frequência (todas também rodam dentro da integração do `run_checks`):
habilidades dos guardiões (`--suites=ability`: energias, AbilitySystem, primitivas, as 24 habilidades em
cenários montados, marcadores de estado, partida suspensa e o bot com o mesmo hash na Baixa e na Alta; a HUD das
habilidades em todas as resoluções fica em `tests/ability_hud_tests.gd`, chamada pelos testes de layout do HUD),
missões do Santuário (`--suites=mission`: dados, cada condição, recompensas, save, Próximas metas e uma partida
pelo bot que conclui missões), regras da Lua Vermelha (`--suites=red_moon`: cada regra na lua dela e logo
abaixo, textos com os números das constantes) e fogo, gelo e clones (`--suites=elements`: Queimadura,
Frio/Congelamento, Estilhaçar, Choque Térmico, as 9 armas, as 3 relíquias, os 2 itens e o bot com o arsenal
novo). No fim de uma partida do bot com `--quit-at`, a linha `HABILIDADES` mostra o nível e quantas vezes cada habilidade saiu.

Partida do bot com as armas de fogo, gelo e sombra no máximo desde o começo:
`-- --bot --seed=7 --arsenal=horokubiya,tsurara,kage_bunshin,kagutsuchi,yukionna,senkage,onmyo_taikyoku,kitsune_yomeiri,hyokyo`
(o `run_checks` roda as tarefas `arsenal_1x/2x/3x/3x_baixa` e confere o mesmo hash nas quatro).

### Testes por resolução (só no Godot)

Os testes que simulam a tela de cada aparelho rodam **só no Godot do PC**, com as resoluções de
[tests/device_profiles.gd](tests/device_profiles.gd): testes de layout de todas as telas e do HUD em todas
as resoluções-alvo (com furo de câmera dos dois lados), o
benchmark de navegação entre os menus `tests/nav_bench.tscn` e os testes de desempenho. Os comandos e critérios estão no `AGENTS.md`.

**Testes automatizados no emulador Android são proibidos.** O emulador (e o aparelho) servem só para
teste manual: uma pessoa instala, joga e confere (veja "Testes manuais no aparelho" abaixo).

Opções de teste (depois de `--`): `--bot`, `--seed=N`, `--speed=1|2|3`, `--hero=ID`, `--stage=ID`,
`--moon=0..5`, `--mode=normal|brisa`, `--endless`, `--god`, `--quit-at=S`, `--hash-at=S`,
`--log-every=S`, `--stress=N`, `--screenshot-at=S`, `--screenshot=arquivo.png`. Vitrine de armas: `--weapons=id1,id2`,
`--weapon-level=N` e `--ult-at=S` (scripts/systems/weapon_showcase.gd); arsenal do bot no nível máximo desde o começo: `--arsenal=id1,id2` (ElementSystem); nível gráfico: `--gfx=low|medium|high`. Detalhes em
[scripts/game/game.gd](scripts/game/game.gd). Anúncios simulados: `--ads-no-fill`, `--ads-auto`,
`--purchase-pending`.

## Android

```powershell
C:\src\tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path C:\src\hyakki --export-debug "Android" C:\src\hyakki\build\hyakki-debug.apk
```

```powershell
C:\android-sdk\platform-tools\adb.exe install -r C:\src\hyakki\build\hyakki-debug.apk
```

O APK inclui arm64-v8a (celulares) e x86_64 (emulador, para teste manual).

> O pacote definitivo é `io.github.netstart.hyakki` (em `export_presets.cfg`). **Não mude:** depois que o
> app sai na Play Store, o ID não pode mais ser trocado.

## Publicação (build de release)

Passo a passo da Play Console, com as respostas prontas: [docs/store/play-console-guia.md](docs/store/play-console-guia.md).
Arte da loja: [docs/store/graphics/](docs/store/graphics/README.md) · ficha: [docs/store/listing.md](docs/store/listing.md) ·
política de privacidade: https://netstart.github.io/privacy-policy.html (fonte `hyakki/privacy-policy.md` e página
`privacy-policy.html` no repositório do site, veja abaixo).

```powershell
powershell -ExecutionPolicy Bypass -File tools\build_release.ps1
```

O script roda todas as verificações, gera `build\release\hyakki-release.aab` (para a Play Console) e
`build\release\hyakki-release.apk` (release, para conferir à mão) e confere as assinaturas. Não instala
nem testa no emulador; para jogar a build à mão use `Testar release no emulador.bat -NoBuild`. Opções:
`-VersionCode N` (obrigatório subir a cada envio à Play Store), `-VersionName 1.0.1`, `-SkipChecks`.

- **Otimização:** template de release do Godot, R8/minify do Gradle (`admob/general/android/enable_r8_optimization`),
  texturas ETC2/ASTC, só os recursos do jogo (testes, ferramentas, docs, mocks e binários iOS dos plugins
  ficam de fora) e AAB com uma ABI por aparelho.

### Site público (netstart.github.io)

Tudo que é publicado em https://netstart.github.io (política de privacidade em HTML e sua fonte `.md`,
páginas HTML, `app-ads.txt`, licenças/créditos do site) vive no repositório irmão `C:\src\netstart.github.io`
([github.com/netstart/netstart.github.io](https://github.com/netstart/netstart.github.io), GitHub Pages da raiz
da `main`) e é editado e commitado **lá**, nunca em `docs/` deste repositório. `docs/` aqui guarda só material
da Play Console e os snapshots de licenças, e **não** é publicado. O `app-ads.txt` do site é gerado a partir do
`general/android/app_id` do `project.godot`, nunca editado à mão (regra completa no [AGENTS.md](AGENTS.md)).

```powershell
powershell -ExecutionPolicy Bypass -File tools\install_hooks.ps1   # uma vez por clone: hook de pre-commit
python -I tools/sync_site.py --check                                # confere o app-ads.txt do site
```

O hook bloqueia commits que tragam os arquivos do site de volta para `docs/` e, quando o `app_id` do AdMob muda,
regenera e commita o `app-ads.txt` no site (`python -I tools/sync_site.py` faz o mesmo à mão; `--commit`/`--push`
também commitam/enviam lá). O site é localizado por `NETSTART_SITE_DIR` ou por `../netstart.github.io`.
- **Chave de envio:** `C:\src\keys\hyakki-upload.keystore`, com usuário e senha em
  `C:\src\keys\hyakki-release.env`. **Fora do repositório; faça backup dos dois arquivos.** Na Play Console,
  ative a "Assinatura de apps do Google Play": o Google guarda a chave final e esta vira só a chave de envio
  (se perder, dá para pedir a troca).
- **Anúncios:** enquanto `AdMobProvider.RELEASE_UNITS` e `admob/general/android/app_id` não tiverem os IDs
  da sua conta AdMob, a build de release fica **sem anúncios**: o SDK não é iniciado, as recompensas viram
  presente e a compra "Apoiar o jogo" some. Preenchidos os IDs, tudo volta sozinho.
- **Compras:** Google Play Billing real; só funciona com o app publicado na Play Console (teste interno) e
  um aparelho com Play Store. O toque na compra espera a Play (`PlayBillingProvider`): sem conexão, conecta;
  sem os detalhes do produto, consulta de novo; aí abre a tela de pagamento. Enquanto espera, o botão diz
  "Abrindo a Google Play…" e fica desativado. Sem resposta em `PURCHASE_TIMEOUT` (12 s), produto fora da
  resposta ou erro de conexão, o aviso é "A Google Play não respondeu" (no emulador sem Play Store, também);
  fechar a tela de pagamento avisa "Compra cancelada"; "já é seu" na Play restaura a compra. Cada falha vai
  para o logcat (`Billing: compra de <produto> <motivo> (<código>) <mensagem>`).
- **Backup do save:** o addon `addons/hyakki_android_backup` (ligado no `project.godot`) liga o Auto Backup do
  Android a cada export Gradle: escreve em `android/build` (não versionada) as regras `res/xml/hyakki_*.xml` e
  os manifestos de `src/standardDebug`/`src/standardRelease` com `allowBackup="true"`, só para `save.json`,
  `save.bak` e `settings.cfg` (tudo o mais fica fora). Testes: `tests/android_backup_tests.gd`.

## Testes manuais no aparelho (build de debug)

Só teste manual (nada automatizado roda no emulador). Para testar à mão, dê dois cliques em
**`Testar no emulador.bat`** (raiz do projeto): ele compila o APK de debug, liga o emulador `Redmi_Note_14_Pro_Plus_5G` se estiver desligado, instala, abre o jogo
e fica mostrando o log do Godot. Pela linha de comando aceita opções:

```bash
powershell -ExecutionPolicy Bypass -File tools\run_emulator.ps1 -NoBuild -Scenario chest
```

`-NoBuild` reinstala o último APK sem compilar, `-Scenario X` abre num dos cenários abaixo, `-NoLog`
encerra assim que o jogo abre e `-Avd Galaxy_M55_5G` ou `-Avd Pixel_7` usa outro AVD
(criado no Device Manager do Android Studio; o emulador ligado é trocado; vale também para o script de release).

Para jogar a **build de produção** (APK de release otimizado e assinado), dois cliques em
**`Testar release no emulador.bat`** (`tools\run_emulator_release.ps1`, aceita `-NoBuild` e `-NoLog`).

Cenários que levam direto a telas difíceis de alcançar jogando (só funcionam em build de debug):

```bash
adb shell "run-as io.github.netstart.hyakki sh -c 'echo chest > files/scenario.txt'"
```

Depois abra o jogo: ele lê e apaga o arquivo. Cenários: `chest`, `kami`, `revive` (anúncio premiado de teste do AdMob), `dawn` (vitória),
`ending` (final), `secret` (final verdadeiro), `hero:yuki` (jogar com um herói bloqueado).

## Conteúdo, textos e licenças

| O quê | Onde | Como regenerar |
|---|---|---|
| Dados do jogo | `data/*.json` (missões: `data/missions.json`, nomes e descrições por modelo em `tools/i18n/missions.py`) | editar à mão; os testes de integração validam as referências |
| Textos (11 idiomas) | `tools/i18n/*.py` → `i18n/strings.csv` | `python -I tools/build_i18n.py` |
| Assets usados | `assets/` (cópia do que é usado; o pack bruto fica fora do repositório) | `python -I tools/sync_assets.py` |
| Licenças | `licenses/registry.json` → `licenses/index.json`, `ASSET_LICENSES.md`, `CREDITS.md` | `python -I tools/fetch_licenses.py` e `python -I tools/build_license_index.py` |
| Loja | `docs/store/listing.md` | preencher os campos marcados antes de publicar |
| Privacidade e site | repositório do site `C:\src\netstart.github.io` ([github.com/netstart/netstart.github.io](https://github.com/netstart/netstart.github.io)): `hyakki/privacy-policy.md` (fonte) + `privacy-policy.html` (raiz); `app-ads.txt` gerado | editar e commitar no site; `python -I tools/sync_site.py` gera o `app-ads.txt` (`--check` confere) |

## Estrutura

```
scenes/app/App.tscn          entrada: roteia as telas (título, heróis, fases, Loja, Diário...)
scenes/game/Game.tscn        uma partida
scripts/autoload/            Events, GameClock, Settings, SaveManager, DB, Locale, Audio, Ads, Purchase, Shop
scripts/core/                regras puras (StatBlock, progressão, grade espacial, geometria, sprites)
scripts/game/                partida (orquestrador), guardiã, mapa por chunks
scripts/systems/             inimigos, chefes, projéteis, áreas, brasas, Kami, baú, lanterna, level-up, spawner
scripts/weapons/             armas (uma classe por comportamento)
scripts/meta/                meta-progressão, conquistas e Missões do Santuário (MissionBook), registro da partida
scripts/ui/ e scripts/app/   HUD, joystick, tema e telas
tests/                       testes de regras e de integração
tools/                       verificações, geradores, pipeline de assets e licenças, sync do site
docs/                        material da Play Console (store/) e snapshots de licenças; não é publicado
```
