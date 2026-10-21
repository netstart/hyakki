# Hyakki — Até o Amanhecer

Survivors-like para Android (paisagem), feito em Godot 4.7.2 com assets gratuitos e licenças verificadas.
Plano completo: [.ai/01-hyakki-survivors-game-plan.md](.ai/01-hyakki-survivors-game-plan.md) ·
progresso e checklist: [.ai/03-progresso-implementacao.md](.ai/03-progresso-implementacao.md).

## O que tem

- 6 guardiões, 6 fases (5 + secreta), 26 armas (12 base, 12 evoluções, 2 uniões), 12 passivos,
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
