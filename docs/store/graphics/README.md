# Arte da Google Play

Tudo aqui é gerado a partir do próprio jogo: assets já registrados em `licenses/` (Ninja Adventure,
CC0; fonte Fusion Pixel, OFL) e o fundo animado dos menus (`MenuBackdrop`). Nada externo, nada de
IA. A pixel art é composta na resolução nativa e ampliada por vizinho mais próximo em escala inteira
(sem borrar).

**As capturas mostram o jogo exatamente como ele é** (política "as capturas devem representar o
app"): tela lógica real de 678×305 (a do aparelho alvo, stretch viewport/keep), nenhum layout
alterado, build atual com `--ads-off` (interface da v1, sem botões de anúncio; o bônus aparece
como "presente"). Cada captura entra inteira, ×2 (1356×610) no telefone e ×3 (2034×915) no
tablet, num painel com moldura dourada sobre o céu noturno do menu, com a legenda acima e o
desfile de yōkai do jogo embaixo. Conferido por `python -I tools/check_store_graphics.py`.

## Arquivos e espaço na Play Console

| Arquivo | Tamanho | Espaço na Play Console |
|---|---|---|
| `icon_512.png` | 512×512, PNG 32 bits, opaco | Ícone do app (sem cantos nem sombra: a Play aplica a máscara) |
| `feature_graphic_pt-BR.png` | 1024×500, PNG 24 bits | Gráfico de recursos (pt-BR) |
| `feature_graphic_en.png` | 1024×500, PNG 24 bits | Gráfico de recursos (inglês e demais idiomas) |
| `feature_graphic_notext.png` | 1024×500, PNG 24 bits | Gráfico de recursos sem texto (alternativa / outros idiomas) |
| `screenshots/pt-BR/01…12_*.png` | 1920×1080 | Capturas de tela do telefone, ficha pt-BR (com legenda) |
| `screenshots/en/01…12_*.png` | 1920×1080 | Capturas de tela do telefone, ficha en-US (com legenda) |
| `tablet/7in/{pt-BR,en}/01…04_*.png` | 2560×1440 | Capturas de tablet de 7" (com legenda) |
| `tablet/10in/{pt-BR,en}/01…04_*.png` | 2560×1440 | Capturas de tablet de 10" (com legenda) |
| `screenshots/raw/{pt-BR,en}/*.png` | 1356×610 | **Só referência, não enviar**: a tela real ×2, sem moldura (2,22:1 passa do limite de 2:1 da Play). Inclui `extra_*` (vila, templo, bambuzal, Kitsune, título, amanhecer) |
| `launcher/icon_192.png` | 192×192 | Godot → Exportar → Android → `launcher_icons/main_192x192` |
| `launcher/adaptive_foreground_432.png` | 432×432, com alfa | `launcher_icons/adaptive_foreground_432x432` (rosto no círculo seguro de 66%) |
| `launcher/adaptive_background_432.png` | 432×432 | `launcher_icons/adaptive_background_432x432` |
| `launcher/adaptive_monochrome_432.png` | 432×432, só alfa | `launcher_icons/adaptive_monochrome_432x432` (ícone temático do Android 13+) |

Os quatro ícones do launcher também ficam em `assets/art/ui/app_icon/` (vão no APK; licença
`hyakki_app_icon`, CC0, derivada do Faceset da Aki do Ninja Adventure). Para usá-los, aponte os
campos `launcher_icons/*` do `export_presets.cfg` para `res://assets/art/ui/app_icon/…`.

## Capturas (ordem da ficha)

| # | Captura | Legenda pt-BR | Legenda en |
|---|---|---|---|
| 01 | Chefe Oni Vermelho no Portão do Yomi | Sobreviva até o amanhecer | Survive until dawn |
| 02 | Horda nas dunas de cinza | Jogue com um dedo | Play with one finger |
| 03 | Escolha de bênção ao subir de nível | Monte sua build a cada nível | Craft your build every level |
| 04 | Golpe da Lanterna (Clarão da Aurora) | Golpe da Lanterna | Lantern Strike |
| 05 | Pausa com 6 armas evoluídas | Mais de 30 armas e evoluções | 30+ weapons and evolutions |
| 06 | Chefe Rei Tengu Corvo no templo | 12 chefes lendários | 12 legendary bosses |
| 07 | Escolha do guardião | 7 guardiões, 7 estilos | 7 guardians, 7 playstyles |
| 08 | Jornada do Guardião (mapa das fases) | Uma jornada pelo Japão mítico | A journey through mythic Japan |
| 09 | Baú laqueado com evolução | Baús laqueados e evoluções | Lacquered chests and evolutions |
| 10 | Santuário | Fique mais forte a cada noite | Grow stronger every night |
| 11 | Diário do Guardião (bestiário) | Desvende o bestiário yōkai | Uncover the yōkai bestiary |
| 12 | Resultados: vitória ao amanhecer | Chegue ao amanhecer | Make it to dawn |

Tablets (7" e 10"): 01, 02, 03 e o guardião (07). Números das legendas conferidos nos dados:
15 armas + 15 evoluções + 2 uniões (`data/weapons.json`), 12 chefes, 7 guardiões, 18 ofertas.

## Como regenerar

```powershell
powershell -ExecutionPolicy Bypass -File tools\make_store_art.ps1
```

1. `tools/store_capture.tscn` abre o jogo (debug, `--ads-off`, qualidade gráfica Alta, save e
   opções de teste: o progresso do jogador não é tocado), monta um perfil de vitrine e leva cada
   tela ou momento de partida ao ponto certo; salva em `build/store_capture/<idioma>/` na tela
   lógica real, 678×305, sem mexer em layout nenhum.
2. `tools/make_store_art.tscn` gera tudo acima (painel ×2 em 1920×1080, ×3 em 2560×1440; ícones
   em ×4/×2; gráfico de recursos 512×250 ×2). Partes isoladas: `-Only icons,feature,screens`.
3. `tools/check_store_graphics.py` confere tamanho, alfa e peso de cada arquivo.

Legendas, ordem e escolha das capturas ficam em `SHOTS`, `EXTRA_RAW` e `TABLET` no topo de
`tools/make_store_art.gd`; as cenas capturadas, em `tools/store_capture.gd`. Os combates usam o
piloto automático e invulnerabilidade, então cada nova captura sai um pouco diferente: confira as
imagens antes de enviar.
