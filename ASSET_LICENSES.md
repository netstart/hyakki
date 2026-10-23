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
| Kenney - Impact Sounds, Interface Sounds and Music Jingles | Kenney Vleugels (Kenney.nl) | CC0-1.0 | kenney_impact-sounds.zip, kenney_interface-sounds.zip, kenney_music-jingles.zip (2023) | sim | não | `licenses/texts/CC0-1.0.txt` | https://kenney.nl/assets/music-jingles |
| Hyakki - procedural sound effects | Hyakki project (Clayton K. N. Passos) | CC0-1.0 | tools/gen_sfx.py (2026-10-23) | sim | não | `licenses/texts/CC0-1.0.txt` | tools/gen_sfx.py |
| Poing Studios AdMob Plugin for Godot | Poing Studios | MIT | 5.1.0 (android-template-v4.7.2) | sim | sim | `licenses/texts/MIT-PoingAdMob.txt` | https://github.com/poingstudios/godot-admob-plugin |
| Google Mobile Ads SDK and UMP SDK | Google LLC | LicenseRef-Google-Mobile-Ads-SDK | ads-mobile-sdk 1.4.0 (via Poing AdMob 5.1.0) | sim | não | `licenses/texts/LicenseRef-Google-Mobile-Ads-SDK.txt` | https://developers.google.com/admob/android/quick-start |
| GodotGooglePlayBilling | Godot Engine contributors | MIT | 3.3.0 | sim | sim | `licenses/texts/MIT-GodotGooglePlayBilling.txt` | https://github.com/godot-sdk-integrations/godot-google-play-billing |
| Google Play Billing Library | Google LLC | LicenseRef-Google-Play-Billing-Library | billing-ktx 9.1.0 (via GodotGooglePlayBilling 3.3.0) | sim | não | `licenses/texts/LicenseRef-Google-Play-Billing-Library.txt` | https://developer.android.com/google/play/billing |
| 効果音ラボ (Sound Effect Lab) - Japanese sound effects | 効果音ラボ | LicenseRef-SoundEffectLab | 7 files downloaded 2026-10-21 (SHA-256 in C:/src/assets/soundeffect-lab/SHA256SUMS.txt) | sim | não | `licenses/texts/LicenseRef-SoundEffectLab.txt` | https://soundeffect-lab.info/ |
| Helton Yan's Pixel Combat | Helton Yan and Beto Bezerra | CC-BY-4.0 | Single Files.zip (itch.io upload 13796512); 4 of 350 files used | sim | sim | `licenses/texts/CC-BY-4.0.txt` | https://heltonyan.itch.io/pixelcombat |
| Platformer character pack (free sample) | Merakintsugi | LicenseRef-Merakintsugi | sample(idle&walk).zip (itch.io upload 16345894, SHA-256 177f9874985b0a03729aaef95612b63327da556858a3198b0e44439cb316a415) | sim | não | `licenses/texts/LicenseRef-Merakintsugi.txt` | https://merakintsugi.itch.io/platformer-character-pack |
| 甘茶の音楽工房 (Amacha) - Japanese-style background music | 甘茶 (Amacha) | LicenseRef-Amacha | 13 tracks of the 和風・アジア category + 4 boss tracks of the 激しい category (ボス戦, 侵攻, 戦火, 最終戦), downloaded 2026-10-21 (SHA-256 in C:/src/assets/amacha/SHA256SUMS.txt) | sim | não | `licenses/texts/LicenseRef-Amacha.txt` | https://amachamusic.chagasi.com/genre_asia.html |
| Lightning (OpenGameArt) | oglsdl | CC0-1.0 | lightning.png (256x256, 8 bolts of 32x256), downloaded 2026-10-23 | sim | não | `licenses/texts/CC0-1.0.txt` | https://opengameart.org/content/lightning-1 |

Verificação: `python -I tools/check_licenses.py` (cobertura de todos os arquivos de `assets/`,
hash das cópias, licenças permitidas, data de verificação). Snapshots das páginas de origem em
`docs/licenses/` (fora do APK).
