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
- **11 idiomas** (pt-BR, en, es, de, fr, ru, id, ja, ko, zh-TW, zh-CN) com a fonte Fusion Pixel.
- Monetização do plano 17: anúncio de abertura, Loja com recompensas a cada 6 h, reviver e dobrar ryō,
  compra para remover o anúncio de abertura. **Hoje com provedores simulados** (sem SDK do AdMob/Billing).
- Telas Licenças e Créditos geradas do registro de licenças.

## Rodar no PC

```powershell
C:\src\tools\godot\Godot_v4.7.2-stable_win64.exe --path C:\src\hyakki
```

Teclas: **WASD/setas** movem · **Esc/P** pausa · **Tab** velocidade · **Espaço/E** Golpe da Lanterna ·
**F3** desempenho · **F4** hitboxes. O mouse simula o toque (arraste na metade esquerda para o joystick).

## Verificações

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_checks.ps1
```

Faz, em ordem: importação (sintaxe de todos os scripts), testes de regras, `gdlint`, textos (629 chaves ×
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

Dois cliques em **`Testes E2E no emulador.bat`** (ou `tools\run_e2e.ps1 [-NoBuild]`). O script instala a
build de debug, apaga os dados do app (**perde o save do emulador**) e liga o roteiro de
[scripts/app/e2e_driver.gd](scripts/app/e2e_driver.gd). O jogo pede ao PC, pelo logcat, toques e arrastos
reais (`adb shell input`), o botão voltar, ir para segundo plano, fechar/reabrir e capturas de tela, e
confere o efeito de cada um. O roteiro cobre: abertura, consentimento, introdução, todos os menus,
seleção, controle por toque, nível novo, baú, pausa, derrota com oferta de reviver, resultados, partida
suspensa e "Continuar". Relatório com as capturas em `build\e2e-report\<data_hora>\`. Anúncios ficam no
modo simulado (o AdMob abre outra tela do Android).

Opções de teste (depois de `--`): `--bot`, `--seed=N`, `--speed=1|2|3`, `--hero=ID`, `--stage=ID`,
`--moon=0..5`, `--mode=normal|brisa`, `--endless`, `--god`, `--quit-at=S`, `--hash-at=S`,
`--log-every=S`, `--stress=N`, `--screenshot-at=S`, `--screenshot=arquivo.png`. Detalhes em
[scripts/game/game.gd](scripts/game/game.gd). Anúncios simulados: `--ads-no-fill`, `--ads-auto`,
`--purchase-pending`.

## Android

```powershell
C:\src\tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path C:\src\hyakki --export-debug "Android" C:\src\hyakki\build\hyakki-debug.apk
```

```powershell
C:\android-sdk\platform-tools\adb.exe install -r C:\src\hyakki\build\hyakki-debug.apk
```

O APK inclui arm64-v8a (celulares) e x86_64 (emulador). Validado no emulador `Redmi_Note_14_Pro_Plus_5G`.

> O pacote `dev.hyakki.prototype` (em `export_presets.cfg`) é provisório: escolha o definitivo antes de
> publicar, porque **ele não pode mudar depois que o app sai na Play Store**.

## Publicação (build de release)

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
- **Anúncios:** o build usa o AdMob real (plugin Poing, com UMP), mas com os IDs de **teste** do Google até
  `AdMobProvider.RELEASE_UNITS` e `admob/general/android/app_id` receberem os IDs da sua conta AdMob.
- **Compras:** Google Play Billing real; só funciona com o app publicado na Play Console (teste interno) e
  um aparelho com Play Store. No emulador sem Play Store a compra responde "não concluída".

## Testes no aparelho (build de debug)

Para testar à mão, dê dois cliques em **`Testar no emulador.bat`** (raiz do projeto): ele compila o
APK de debug, liga o emulador `Redmi_Note_14_Pro_Plus_5G` se estiver desligado, instala, abre o jogo
e fica mostrando o log do Godot. Pela linha de comando aceita opções:

```bash
powershell -ExecutionPolicy Bypass -File tools\run_emulator.ps1 -NoBuild -Scenario chest
```

`-NoBuild` reinstala o último APK sem compilar, `-Scenario X` abre num dos cenários abaixo e `-NoLog`
encerra assim que o jogo abre.

Para jogar a **build de produção** (APK de release otimizado e assinado), dois cliques em
**`Testar release no emulador.bat`** (`tools\run_emulator_release.ps1`, aceita `-NoBuild` e `-NoLog`).

Cenários que levam direto a telas difíceis de alcançar jogando (só funcionam em build de debug):

```bash
adb shell "run-as dev.hyakki.prototype sh -c 'echo chest > files/scenario.txt'"
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
