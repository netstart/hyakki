# Hyakki — Até o Amanhecer

Survivors-like para Android (paisagem), feito em Godot 4.7.2 com assets gratuitos e licenças verificadas.
Plano completo: [.ai/01-hyakki-survivors-game-plan.md](.ai/01-hyakki-survivors-game-plan.md) ·
progresso e checklist: [.ai/03-progresso-implementacao.md](.ai/03-progresso-implementacao.md).

## O que tem

- 7 guardiões (incluindo Yuki, a meio-oni, desbloqueada ao vencer o Oni Vermelho), 6 fases (5 + secreta), 26 armas (12 base, 12 evoluções, 2 uniões), 12 passivos,
  37 yōkai, 12 chefes, 15 Kami, 6 Golpes da Lanterna, Baú Laqueado, itens de chão e perigos por fase.
- Santuário (18 power-ups, reembolso total), 40 conquistas que desbloqueiam conteúdo, Diário do Guardião,
  história completa, Noite Sem Fim, Desafio Diário, Brisa / Normal / Lua Vermelha I–V.
- Velocidade **1x / 2x / 3x** com passo fixo: a mesma semente gera a mesma partida em qualquer velocidade.
  2x e 3x são liberados pela **Ampulheta de Fūjin**, compra única e permanente na Loja: 3.000 ryō ou
  dinheiro (Google Play, produto `unlock_speed`, R$ 4,99 / US$ 1,99). O bot e o `--speed=N` dos testes
  aceleram sem a compra.
- **11 idiomas** (pt-BR, en, es, de, fr, ru, id, ja, ko, zh-TW, zh-CN) com a fonte Fusion Pixel.
- Monetização do plano 17: anúncio de abertura, Loja com recompensas a cada 6 h, reviver e dobrar ryō,
  compra para remover o anúncio de abertura e a Ampulheta de Fūjin (velocidade 2x/3x, com ryō ou dinheiro). **Hoje com provedores simulados** (sem SDK do AdMob/Billing).
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
**F3** desempenho · **F4** hitboxes. O mouse simula o toque (arraste na metade esquerda para o joystick).

## Verificações

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_checks.ps1
```

Faz, em ordem: importação (sintaxe de todos os scripts), testes de regras, `gdlint`, textos (799 chaves ×
11 idiomas, marcadores `%s/%d`), licenças (cobertura de todos os arquivos de `assets/`, hashes, licenças
permitidas), limites da ficha da loja, testes de integração (dados, idiomas, cobertura de glifos, Loja,
Santuário, save, regras de anúncio), determinismo 1x/2x/3x e estresse com 500 inimigos.

Para um relatório completo (cada verificação listada, tempos e logs) em `build\test-report\<data_hora>\relatorio.html`:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_tests_report.ps1 -E2E
```

`-E2E` inclui os testes de ponta a ponta no emulador (abaixo); `-SkipStress` pula o estresse e `-NoOpen`
não abre o navegador.

### Ponta a ponta no emulador (E2E)

Dois cliques em **`Testes E2E no emulador.bat`** (ou `tools\run_e2e.ps1 [-NoBuild] [-NoChecks] [-Avd all|nome]`).
O APK de debug é exportado uma vez só (com o primeiro emulador já ligando) e reinstalado em todos os aparelhos;
logo depois o `tools\run_checks.ps1` roda em paralelo (log `run_checks.log` no relatório; se falhar, o E2E
falha; `-NoChecks` pula). Os emuladores ligam a frio (`-no-snapshot`, ~30 s). Por
padrão roda em todas as **resoluções-alvo** (a regra de qualidade é por resolução; veja `AGENTS.md`), um
AVD depois do outro (o emulador anterior é desligado antes do próximo):

| Resolução lógica | Tela física | AVDs |
|---|---|---|
| 678x305 | 2712x1220 | `Redmi_Note_14_Pro_Plus_5G` (Redmi Note 14 Pro+ 5G) |
| 600x270 | 2400x1080 | `Galaxy_M55_5G` (Galaxy M55 5G), `Pixel_7` (Pixel 7) |
| 585x270 | 2340x1080 | `Galaxy_A15` (Galaxy A15; cobre também o Galaxy A56 5G, o POCO M3 e o S24/S25 Ultra em FHD+) |
| 624x288 | 3120x1440 | `Galaxy_S24_Ultra` (Galaxy S24 Ultra e S25 Ultra em QHD+) |

Os AVDs que faltarem são criados por `tools\create_test_avds.ps1` (o `.bat` já chama); em todos
o script liga o recorte de câmera emulado do Android (`cmd overlay ... cutout.emulation.hole`).
`-Avd Pixel_7` roda só um aparelho. Em cada um o script instala a
build de debug, apaga os dados do app (**perde o save do emulador**) e liga o roteiro de
[scripts/app/e2e_driver.gd](scripts/app/e2e_driver.gd). O jogo pede ao PC, pelo logcat, toques e arrastos
reais (`adb shell input`), o botão voltar, ir para segundo plano, fechar/reabrir e capturas de tela, e
confere o efeito de cada um. O roteiro cobre: abertura, consentimento, introdução, todos os menus,
seleção, controle por toque, nível novo, baú, pausa, derrota com oferta de reviver, resultados, partida
suspensa e "Continuar". Relatório geral em `build\e2e-report\<data_hora>\relatorio.html` e um por
aparelho, com as capturas, em `build\e2e-report\<data_hora>\<AVD>\`. Anúncios ficam no
modo simulado (o AdMob abre outra tela do Android).

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

O APK inclui arm64-v8a (celulares) e x86_64 (emulador). Validado nos emuladores `Redmi_Note_14_Pro_Plus_5G`,
`Galaxy_M55_5G` e `Pixel_7`.

> O pacote definitivo é `io.github.netstart.hyakki` (em `export_presets.cfg`). **Não mude:** depois que o
> app sai na Play Store, o ID não pode mais ser trocado.

## Publicação (build de release)

Passo a passo da Play Console, com as respostas prontas: [docs/store/play-console-guia.md](docs/store/play-console-guia.md).
Arte da loja: [docs/store/graphics/](docs/store/graphics/README.md) · ficha: [docs/store/listing.md](docs/store/listing.md) ·
política de privacidade: https://netstart.github.io/privacy-policy.html.

```powershell
powershell -ExecutionPolicy Bypass -File tools\build_release.ps1
```

O script roda todas as verificações, gera `build\release\hyakki-release.aab` (para a Play Console) e
`build\release\hyakki-release.apk` (release, para conferir), confere as assinaturas, instala o APK no
emulador, abre o jogo e falha se houver erro do Godot no logcat. Opções: `-VersionCode N`
(obrigatório subir a cada envio à Play Store), `-VersionName 1.0.1`, `-SkipChecks`, `-NoEmulator`.

- **Otimização:** template de release do Godot, R8/minify do Gradle (`admob/general/android/enable_r8_optimization`),
  texturas ETC2/ASTC, só os recursos do jogo (testes, ferramentas, docs, mocks e binários iOS dos plugins
  ficam de fora) e AAB com uma ABI por aparelho.
- **Chave de envio:** `C:\src\keys\hyakki-upload.keystore`, com usuário e senha em
  `C:\src\keys\hyakki-release.env`. **Fora do repositório; faça backup dos dois arquivos.** Na Play Console,
  ative a "Assinatura de apps do Google Play": o Google guarda a chave final e esta vira só a chave de envio
  (se perder, dá para pedir a troca).
- **Anúncios:** enquanto `AdMobProvider.RELEASE_UNITS` e `admob/general/android/app_id` não tiverem os IDs
  da sua conta AdMob, a build de release fica **sem anúncios**: o SDK não é iniciado, as recompensas viram
  presente e a compra "remover anúncio" some. Preenchidos os IDs, tudo volta sozinho.
- **Compras:** Google Play Billing real; só funciona com o app publicado na Play Console (teste interno) e
  um aparelho com Play Store. No emulador sem Play Store a compra responde "não concluída".

## Testes no aparelho (build de debug)

Para testar à mão, dê dois cliques em **`Testar no emulador.bat`** (raiz do projeto): ele compila o
APK de debug, liga o emulador `Redmi_Note_14_Pro_Plus_5G` se estiver desligado, instala, abre o jogo
e fica mostrando o log do Godot. Pela linha de comando aceita opções:

```bash
powershell -ExecutionPolicy Bypass -File tools\run_emulator.ps1 -NoBuild -Scenario chest
```

`-NoBuild` reinstala o último APK sem compilar, `-Scenario X` abre num dos cenários abaixo, `-NoLog`
encerra assim que o jogo abre e `-Avd Galaxy_M55_5G` ou `-Avd Pixel_7` usa outro aparelho-alvo (o
emulador ligado é trocado; vale também para os scripts de release).

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
| Dados do jogo | `data/*.json` | editar à mão; os testes de integração validam as referências |
| Textos (11 idiomas) | `tools/i18n/*.py` → `i18n/strings.csv` | `python -I tools/build_i18n.py` |
| Assets usados | `assets/` (cópia do que é usado; o pack bruto fica fora do repositório) | `python -I tools/sync_assets.py` |
| Licenças | `licenses/registry.json` → `licenses/index.json`, `ASSET_LICENSES.md`, `CREDITS.md` | `python -I tools/fetch_licenses.py` e `python -I tools/build_license_index.py` |
| Loja e privacidade | `docs/store/listing.md`, `docs/privacy-policy.md`, `docs/app-ads.txt` | preencher os campos marcados antes de publicar |

## Estrutura

```
scenes/app/App.tscn          entrada: roteia as telas (título, heróis, fases, Loja, Diário...)
scenes/game/Game.tscn        uma partida
scripts/autoload/            Events, GameClock, Settings, SaveManager, DB, Locale, Audio, Ads, Purchase, Shop
scripts/core/                regras puras (StatBlock, progressão, grade espacial, geometria, sprites)
scripts/game/                partida (orquestrador), guardiã, mapa por chunks
scripts/systems/             inimigos, chefes, projéteis, áreas, brasas, Kami, baú, lanterna, level-up, spawner
scripts/weapons/             armas (uma classe por comportamento)
scripts/meta/                meta-progressão, conquistas, registro da partida
scripts/ui/ e scripts/app/   HUD, joystick, tema e telas
tests/                       testes de regras e de integração
tools/                       verificações, geradores, pipeline de assets e licenças
```
