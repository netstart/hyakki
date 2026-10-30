# Hyakki — Até o Amanhecer

Survivors-like para Android (paisagem), feito em Godot 4.7.2 com assets gratuitos e licenças verificadas.
Plano completo: [.ai/01-hyakki-survivors-game-plan.md](.ai/01-hyakki-survivors-game-plan.md) ·
progresso e checklist: [.ai/03-progresso-implementacao.md](.ai/03-progresso-implementacao.md).

## O que tem

- 7 guardiões (incluindo Yuki, a meio-oni, desbloqueada ao vencer o Oni Vermelho), 6 fases (5 + secreta), 26 armas (12 base, 12 evoluções, 2 uniões), 12 passivos,
  37 yōkai, 12 chefes, 15 Kami, 6 Golpes da Lanterna, Baú Laqueado, itens de chão e perigos por fase.
- Omikuji do baú (おみくじ): antes de abrir, o tubo de madeira solta a sorte (吉 1 item, 中吉 3, 大吉 5,
  e às vezes 凶 com consolo em ryō, amarrado no galho) e uma roleta para em cada item. A sorte só mostra a
  contagem já sorteada; os 3 primeiros baús comuns do save saem com 中吉 garantido (o bot não usa nem gasta
  esses baús, então os testes de determinismo não dependem do save). Opção "Animação curta do baú".
- Santuário (18 power-ups, reembolso total), **Missões do Santuário** (as 41 conquistas que desbloqueiam conteúdo
  e mais 131 missões em 10 categorias, cada uma com recompensa e barra de progresso no Diário, e as
  Próximas 3 metas no título e nos Resultados), Diário do Guardião,
  história completa, Noite Sem Fim, Desafio Diário, Brisa / Normal / Lua Vermelha I–V.
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
**F3** desempenho · **F4** hitboxes. O mouse simula o toque (arraste na metade esquerda para o joystick).

## Verificações

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_checks.ps1
```

Faz, em ordem: importação (sintaxe de todos os scripts), testes de regras, `gdlint`, textos (1066 chaves ×
11 idiomas, marcadores `%s/%d`), licenças (cobertura de todos os arquivos de `assets/`, hashes, licenças
permitidas), limites da ficha da loja, testes de integração (dados, idiomas, cobertura de glifos, Loja,
Santuário, save, regras de anúncio), determinismo 1x/2x/3x e estresse com 500 inimigos.

Para um relatório completo (cada verificação listada, tempos e logs) em `build\test-report\<data_hora>\relatorio.html`:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_tests_report.ps1
```

`-SkipStress` pula o estresse e `-NoOpen` não abre o navegador.

Missões do Santuário sozinhas (dados, cada condição, recompensas, save, Próximas metas e uma partida pelo
bot que conclui missões): `Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tests/mission_tests.tscn`
(também rodam dentro de `tests/integration_tests.tscn`).

### Testes por resolução (só no Godot)

Os testes que simulam a tela de cada aparelho rodam **só no Godot do PC**, com as resoluções de
[tests/device_profiles.gd](tests/device_profiles.gd): testes de layout de todas as telas e do HUD em todas
as resoluções-alvo (com furo de câmera dos dois lados), o benchmark de rolagem `tests/scroll_bench.tscn` e
os testes de desempenho. Os comandos e critérios estão no `AGENTS.md`.

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
  um aparelho com Play Store. No emulador sem Play Store a compra responde "não concluída".
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
