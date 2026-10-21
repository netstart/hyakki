# Licenças de assets e software

Gerado por `tools/build_license_index.py` a partir de `licenses/registry.json`. Não editar à mão.
Os componentes de terceiros do próprio Godot (FreeType, HarfBuzz, etc.) aparecem na tela
Licenças do jogo, lidos do motor exportado (`Engine.get_copyright_info()`).

| Componente | Autor | Licença | Versão | Uso comercial | Crédito exigido | Texto local | Origem |
|---|---|---|---|---|---|---|---|
| Godot Engine | Juan Linietsky, Ariel Manzur and Godot Engine contributors | MIT | 4.7.2-stable | sim | sim | `licenses/texts/MIT-Godot.txt` | https://godotengine.org/license |
| Android Jetpack (AndroidX) and Kotlin stdlib | The Android Open Source Project; JetBrains s.r.o. | Apache-2.0 | as bundled by the Godot 4.7.2 Android export template | sim | sim | `licenses/texts/Apache-2.0.txt` | https://developer.android.com/jetpack/androidx |
| Ninja Adventure - Asset Pack | pixel-boy & AAA | CC0-1.0 | NinjaAdventure-AssetPack.zip (SHA-256 95a06f4fdcfd1882f061a45ff313b7c905dbe2de1e8512b281d7937df62a7b15) | sim | não | `licenses/texts/CC0-1.0.txt` | https://pixel-boy.itch.io/ninja-adventure-asset-pack |
| Fusion Pixel Font (12px proportional) | TakWolf | OFL-1.1 | 2026.10.16 | sim | sim | `licenses/texts/OFL-1.1.txt` | https://github.com/TakWolf/fusion-pixel-font |
| Ark Pixel Font (Fusion Pixel upstream) | TakWolf | OFL-1.1 | included in Fusion Pixel 2026.10.16 | sim | sim | `licenses/texts/OFL-1.1.txt` | https://github.com/TakWolf/ark-pixel-font |
| Cubic 11 (Fusion Pixel upstream) | ACh-K | OFL-1.1 | included in Fusion Pixel 2026.10.16 | sim | sim | `licenses/texts/OFL-1.1.txt` | https://github.com/ACh-K/Cubic-11 |
| Galmuri (Fusion Pixel upstream) | Lee Minseo (quiple) | OFL-1.1 | included in Fusion Pixel 2026.10.16 | sim | sim | `licenses/texts/OFL-1.1.txt` | https://github.com/quiple/galmuri |

Verificação: `python -I tools/check_licenses.py` (cobertura de todos os arquivos de `assets/`,
hash das cópias, licenças permitidas, data de verificação). Snapshots das páginas de origem em
`docs/licenses/` (fora do APK).
