# Hyakki — Até o Amanhecer

Survivors-like para Android (paisagem), feito em Godot 4.7.2 com assets gratuitos e licenças verificadas.
Plano completo: [.ai/01-hyakki-survivors-game-plan.md](.ai/01-hyakki-survivors-game-plan.md) ·
progresso e checklist: [.ai/03-progresso-implementacao.md](.ai/03-progresso-implementacao.md).

## O que tem

- 7 guardiões (incluindo Yuki, a meio-oni, desbloqueada ao vencer o Oni Vermelho), 6 fases (5 + secreta), 26 armas (12 base, 12 evoluções, 2 uniões), 12 passivos,
  37 yōkai, 12 chefes, 15 Kami, 6 Golpes da Lanterna, Baú Laqueado, itens de chão e perigos por fase.
- **Habilidades dos guardiões** ([.ai/04-habilidades-dos-guardioes.md](.ai/04-habilidades-dos-guardioes.md)):
  21 habilidades (3 por guardião, ligadas à história de cada um, liberadas nos níveis 1, 5 e 10 da partida)
  e 7 energias próprias (Chama da Ordem, Sombra, Prece, Penitência, Foco, Calor da Forja e Sangue Oni, que
  a Yuki pode pagar com vida), com recarga, efeitos, som em camadas, grito do guardião e o letreiro
  kanji + nome. Números em `data/abilities.json`; o bot usa as três por regras fixas (determinístico).
  No toque, 3 botões em arco ao lado do Golpe; ficha na tela do guardião, no Diário e um capítulo no Guia.
- Omikuji do baú (おみくじ): antes de abrir, o tubo de madeira solta a sorte (吉 1 item, 中吉 3, 大吉 5,
  e às vezes 凶 com consolo em ryō, amarrado no galho) e uma roleta para em cada item. A sorte só mostra a
  contagem já sorteada; os 3 primeiros baús comuns do save saem com 中吉 garantido (o bot não usa nem gasta
  esses baús, então os testes de determinismo não dependem do save). Opção "Animação curta do baú".
- Tela de nível: **Rerrolar sempre à mão** (cargas grátis do Santuário primeiro; sem elas, 10 ryō da partida
  na 1ª rolagem paga e +10 a cada outra, com cartas novas sempre que o sorteio tiver outras) e, com tudo no
  máximo, a mão comida/moedas com "Não perguntar mais": a escolha vira automática, sem pausar a luta, só com
  o som (com a vida cheia, "Comida" pega as moedas); muda em Opções e no menu de pausa.
- Santuário (18 power-ups, reembolso total), **Missões do Santuário** (as 41 conquistas que desbloqueiam conteúdo
  e mais 140 missões em 11 categorias, cada uma com recompensa e barra de progresso no Diário, e as
  Próximas 3 metas no título e nos Resultados), Diário do Guardião
  (com o **Guia**: 9 capítulos de manual montados dos dados do jogo, sem revelar o que não foi descoberto),
  história completa, Noite Sem Fim, Desafio Diário, Brisa / Normal / Lua Vermelha I–V (regras cumulativas em
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

Execute este comando para abrir o jogo em modo de desenvolvimento com os sete guardiões liberados:

```powershell
C:\src\tools\godot\Godot_v4.7.2-stable_win64.exe --path C:\src\hyakki
```

Ao iniciar, a build de desenvolvimento libera e salva automaticamente Aki, Kenta, Hana, Goro, Rin, Tora e
Yuki no perfil local, preservando o restante do progresso. Esse desbloqueio automático é exclusivo da build
de desenvolvimento; na build de produção, os heróis continuam sendo liberados pela progressão normal.

Teclas: **WASD/setas** movem · **Esc/P** pausa · **Tab** velocidade · **Espaço/E** Golpe da Lanterna ·
**1/2/3** ou **J/K/L** habilidades (controle: **X/Y/B**) · **F3** desempenho · **F4** hitboxes. O mouse simula o toque (arraste na metade esquerda para o joystick).

## Verificações

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_checks.ps1
```

Primeiro a importação (sintaxe de todos os scripts), sozinha; depois, **ao mesmo tempo**, cada tarefa num
processo próprio: os testes de integração em N fatias (dados, idiomas, cobertura de glifos, Loja, Santuário,
save, regras de anúncio e o layout de toda tela em todas as resoluções × 11 idiomas × furo dos dois lados), os
testes de regras, o determinismo (bot em 1x, 2x, 3x e 3x na Baixa, mesmo hash), o estresse com 500 inimigos,
o `gdlint` em partes e os checks em Python (textos, 1389 chaves × 11 idiomas e marcadores `%s/%d`; licenças;
ficha da loja; site irmão). No fim, um resumo por tarefa; qualquer falha, erro de script ou trava reprova o todo.

- **Fatias (`--shard=k/N`):** cada processo da integração roda a sua parte das unidades (caso de layout,
  idioma) de `DeviceProfiles.layout_cases()` (em blocos contíguos) e das suítes sem layout (repartidas pelo
  custo medido em `SUITE_MS`, em `tests/integration_tests.gd`). A união das fatias é o conjunto completo:
  `tests/test_shards.gd` confere a partição para N = 1..16 e cada fatia imprime a linha `COBERTURA`, que o
  `run_checks` confere (casos de 0 ao total sem buraco e toda suíte rodada em alguma fatia). Também imprime
  `SUÍTE <nome>: <ms>, <verificações>` por suíte. Para depurar: `-- --suites=A,B` roda só essas suítes.
- **Isolamento:** cada Godot roda com uma APPDATA própria (Linux: `XDG_DATA_HOME`) numa pasta temporária, então
  `user://` (save, `settings.cfg`, `runs.csv`, logs) nunca é o perfil real do jogador; a integração confere
  `OS.get_user_data_dir()` contra a pasta isolada e o `run_checks` confere no fim que o perfil real não mudou.
- **Tempo de simulação:** a integração roda com `--fixed-fps 60`; as esperas dos testes contam quadros e
  tempo de simulação (`tests/sim_clock.gd`, `UiClock`), nunca o relógio da parede.
- **Opções:** `-Shards N` (padrão: núcleos − 4, entre 2 e 12), `-StallMinutes M` (padrão 8: tarefa sem saída
  nova por M minutos é encerrada à força e rodada de novo uma vez; travou de novo = falha), `-StressAlone` (o
  estresse sozinho no fim, com os números sem disputa de CPU), `-Only integracao,regras` (só essas tarefas),
  `-KeepTemp`. Saída de cada tarefa em `build\checks\<data_hora>\<tarefa>.log`.
- **Linux/CI:** `GODOT=/caminho/godot tools/run_checks.sh` (o mesmo, com `SHARDS`, `STALL_MINUTES` e `ONLY`).

Tempos neste PC (16 núcleos lógicos), do `run_checks.ps1` inteiro: **3322 s (≈ 55 min)** antes (tudo em série, integração
num processo só, sem `--fixed-fps`) e **320–330 s (≈ 5,5 min)** agora (12 fatias; a integração sozinha de 3149 s para ~310 s). Detalhes por etapa no commit 1.20.3.

Para um relatório completo (resumo por etapa, falhas com o texto inteiro, tempos e logs) em
`build\test-report\<data_hora>\relatorio.html`:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_tests_report.ps1
```

`-SkipStress` pula o estresse, `-NoOpen` não abre o navegador e `-ListPassed` lista também cada verificação
que passou (`--verbose`, milhões de linhas). O relatório roda as etapas em sequência, com `user://` isolado.

Habilidades dos guardiões sozinhas (energias, AbilitySystem, primitivas, as 21 habilidades em cenários
montados, marcadores de estado, partida suspensa e o bot com o mesmo hash na Baixa e na Alta):
`Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tests/ability_tests.tscn` (também rodam
dentro de `tests/integration_tests.tscn`; a HUD das habilidades em todas as resoluções fica em
`tests/ability_hud_tests.gd`, chamada pelos testes de layout do HUD). No fim de uma partida do bot com
`--quit-at`, a linha `HABILIDADES` mostra o nível e quantas vezes cada habilidade saiu.

Missões do Santuário sozinhas (dados, cada condição, recompensas, save, Próximas metas e uma partida pelo
bot que conclui missões): `Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tests/mission_tests.tscn`
(também rodam dentro de `tests/integration_tests.tscn`).

Regras da Lua Vermelha sozinhas (cada regra na lua dela e logo abaixo, textos com os números das constantes):
`Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tests/red_moon_tests.tscn` (também rodam
dentro de `tests/integration_tests.tscn`).

### Testes por resolução (só no Godot)

Os testes que simulam a tela de cada aparelho rodam **só no Godot do PC**, com as resoluções de
[tests/device_profiles.gd](tests/device_profiles.gd): testes de layout de todas as telas e do HUD em todas
as resoluções-alvo (com furo de câmera dos dois lados), o benchmark de rolagem `tests/scroll_bench.tscn`, o
benchmark de navegação entre os menus `tests/nav_bench.tscn` e os testes de desempenho. Os comandos e critérios estão no `AGENTS.md`.

**Testes automatizados no emulador Android são proibidos.** O emulador (e o aparelho) servem só para
teste manual: uma pessoa instala, joga e confere (veja "Testes manuais no aparelho" abaixo).

Opções de teste (depois de `--`): `--bot`, `--seed=N`, `--speed=1|2|3`, `--hero=ID`, `--stage=ID`,
`--moon=0..5`, `--mode=normal|brisa`, `--endless`, `--god`, `--quit-at=S`, `--hash-at=S`,
`--log-every=S`, `--stress=N`, `--screenshot-at=S`, `--screenshot=arquivo.png`. Vitrine de armas: `--weapons=id1,id2`,
`--weapon-level=N` e `--ult-at=S` (scripts/systems/weapon_showcase.gd); nível gráfico: `--gfx=low|medium|high`. Detalhes em
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
