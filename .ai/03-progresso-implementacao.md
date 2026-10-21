# Progresso da implementação completa

Pedido (20/10/2026): "Implemente tudo. No lugar do dispositivo físico android utilize o emulador. Valide tudo,
só pare quando terminar e validar tudo." Em 21/10: "termine tudo, quando terminar faça commit e push".

- Branch: `feat/prototipo-m1`.
- Godot 4.7.2 em `C:\src\tools\godot` · Android SDK `C:\android-sdk` · emulador `Redmi_Note_14_Pro_Plus_5G`
  (1220×2712, x86_64, google_apis, **sem Play Store**) em `emulator-5554`.
- Pacote base: `C:\src\assets\ninja-adventure\NinjaAdventure-AssetPack.zip` (SHA-256 `95a06f4f…7b15`, CC0),
  fora do repositório; só os 752 arquivos usados são copiados para `assets/` por `tools/sync_assets.py`.

## Decisões de arquitetura
- Dados em **JSON** (`data/*.json`) carregados pelo autoload `DB` (plano 10.1 atualizado).
- Textos em `i18n/strings.csv` (11 idiomas), gerado por `tools/build_i18n.py` e lido em tempo de execução
  pelo autoload `Locale`. O CSV está com `importer="keep"` para o Godot não gerar `.translation`.
- Fontes carregadas pelo `ResourceLoader` (no APK só existe a fonte importada, não o `.woff2` bruto).
- Anúncios e compras atrás de `AdsManager`/`PurchaseManager` com **provedor simulado**.

## Checklist
(✅ feito e validado · ⚠️ limitação registrada)

### Base
- ✅ Pipeline de assets (`tools/asset_manifest.json`, `tools/sync_assets.py`, `assets/asset_index.json` com hash)
- ✅ Registro de licenças (`licenses/registry.json`, 7 componentes) + textos e avisos em `licenses/`,
  snapshots PDF das páginas de origem em `docs/licenses/` + `tools/fetch_licenses.py`,
  `tools/check_licenses.py` (cobre 100% de `assets/`), `tools/build_license_index.py`
  (`licenses/index.json`, `ASSET_LICENSES.md`, `CREDITS.md`). Licença do Ninja Adventure conferida na página
  em 21/10/2026: CC0, uso comercial permitido.
- ✅ Fontes para os 11 idiomas (Fusion Pixel 12px, OFL); teste de cobertura de glifos por idioma
- ✅ Qualidade de código: `gdlint` limpo (regras em `gdlintrc`), testes, `tools/run_checks.ps1`

### Jogo
- ✅ StatBlock, dados JSON, sprites com animação por direção, 8 arquétipos + props, elites, projéteis inimigos
- ✅ 12 armas, 12 passivos, 12 evoluções + 2 uniões, Baú Laqueado
- ✅ Lanterna (shader, Sombras), 15 Kami, 6 Golpes da Lanterna, destrutíveis, itens de chão, cura
- ✅ Mapa por chunks, obstáculos com deslize, perigos por fase, limites (corredor, arena)
- ✅ 12 chefes (Kuroe 3 fases, Shinigami, Izanami), 6 fases com ondas e eventos (enxame, cerco, procissão)
- ✅ Noite Sem Fim, Desafio Diário, Brisa / Normal / Lua Vermelha I–V
- ✅ Save com backup e migração, ryō, Santuário (reembolso total), 40 conquistas com desbloqueios
- ✅ Diário do Guardião, história (intro, falas de abertura, amanhecer, final, final verdadeiro)

### Interface, áudio, idiomas
- ✅ Telas: consentimento, título, heróis, fases, HUD, pausa, level-up, baú, Kami, reviver, resultados,
  Santuário, Loja, Diário, Opções, Créditos, Licenças, história
- ✅ Tema madeira, acessibilidade (daltônico, reduzir flashes, números de dano), tutorial, vibração
- ✅ AudioManager (música por fase e chefe, pool de efeitos, ducking, batimento com vida baixa)
- ✅ 11 idiomas: 629 chaves, geradas e validadas (chaves, colunas, marcadores, glifos)

### Monetização (17)
- ✅ Anúncio de abertura (a partir da 2ª abertura, intervalo de 4 h, removível), Loja com 6 vagas de 6 h e
  proteção contra relógio voltado, reviver 1×, dobrar ryō, compra "Remover anúncio de abertura", restaurar
- ⚠️ Provedores simulados. Falta integrar o plugin AdMob + UMP e o Play Billing (exigem contas)

### Testes e validação
- ✅ `tests/run_tests.gd`: 36 verificações (regras puras)
- ✅ `tests/integration_tests.tscn`: 486 verificações (integridade dos dados, sprites e músicas existentes,
  11 idiomas, formatação, glifos, StatBlock, descrições, migração do save, Santuário, Loja, regras de anúncio)
- ✅ Determinismo: mesma semente → mesmo hash em 1x, 2x e 3x (`hash=634242473`, 90 s)
- ✅ Estresse 500 inimigos: ~4–6 ms por passo no PC (era ~14,6 ms; ver Registro)
- ✅ Emulador: APK instala e abre; telas percorridas com toque (consentimento, anúncio simulado, história,
  título, heróis, fases, partida, level-up, pausa, 3x, resultados, Loja com anúncio premiado e compra,
  Santuário, Diário, Opções, troca de idioma para japonês e português, Licenças, Créditos); logcat sem erros
  do Godot, sem crash nem ANR
- ✅ Ficha da loja nos 11 idiomas (`docs/store/listing.md`, limites conferidos), política de privacidade
  (`docs/privacy-policy.md`, pt-BR e en), modelo de `docs/app-ads.txt`

### Limitações (fora do alcance desta sessão)
- ⚠️ Play Console, AdMob real, teste fechado, keystore de release, ID definitivo do pacote, hospedar a política
  e o `app-ads.txt`, preencher `[CONTATO]`/`[DATA]` na política
- ⚠️ Revisão das traduções por falantes nativos (plano 7.7.3)
- ⚠️ Balanceamento validado só com o bot (sem upgrades, sem desviar como um humano): Vila 3,5–5 min,
  fases do meio ~2–2,5 min, Yomi ~1 min. Falta playtest humano (plano 15.3–15.5)
- ⚠️ Desempenho medido no PC e no emulador x86_64; falta medir no Redmi físico (ARM)

## Etapa 1 (21/10/2026): integrações, conteúdo extra e publicação
Pedido: "complete a etapa 1 inteira, faça commit e push; crie um script que me permita compilar pronto pra
publicação, otimizado, e execute a aplicação dentro do emulador".

- ✅ **AdMob real em modo de teste:** plugin Poing AdMob 5.1.0 (MIT) + UMP, `scripts/ads/admob_provider.gd`.
  Consentimento pelo formulário oficial do Google (só onde é exigido); anúncio de abertura e recompensado com os
  IDs de teste do Google. Formulário de privacidade em Opções. No PC e nos testes continua o provedor simulado.
- ✅ **Play Billing:** plugin oficial GodotGooglePlayBilling 3.3.0 (MIT), `scripts/ads/play_billing_provider.gd`:
  preço da loja, compra, confirmação (acknowledge), pendente, restauração e reembolso. No emulador sem Play
  Store responde "não concluída" (verificado: "Billing service unavailable on device").
- ✅ **Build Gradle:** template Android instalado em `android/` (fora do git), três presets (debug, AAB e APK de
  release), daemon do Gradle desligado (o Godot travava na saída com ele ligado).
- ✅ **Sons novos com licença verificada:** Kenney Impact/Interface/Jingles (CC0), 効果音ラボ (taiko, sino do
  templo, fūrin, koto, gongo; termos lidos: uso comercial e em app permitidos), Helton Yan Pixel Combat (CC BY
  4.0; 4 arquivos baixados por HTTP Range do zip de 2,1 GB e cortados em 6 variações cada por
  `tools/split_variations.py`). Variações por som no `AudioManager` (acerto com 17 variações).
- ✅ **Registro de licenças:** 14 componentes, cobrindo `assets/` e `addons/` (820 arquivos).
- ✅ **Partida suspensa (plano 10.11):** snapshot ao ir para segundo plano, "Continuar partida" no título (vale 3
  dias), teste de ida e volta nos testes de integração.
- ✅ **Cenários de teste no aparelho** (debug): `chest`, `kami`, `revive`, `dawn`, `ending`, `secret`.
- ✅ **CI:** `.github/workflows/checks.yml` + `tools/run_checks.sh`.
- ✅ **Chave de envio** em `C:\src\keys\` (fora do repositório) e `tools/build_release.ps1`.
- Achado: as ferramentas desta sessão rodam dentro de um "job" do Windows que encerra os processos filhos;
  emulador e servidor adb precisam ser abertos como processos independentes (WMI). Para você, rodando o script
  no seu terminal, isso não acontece.

### Herói Yuki (pedido de 21/10: personagem do Merakintsugi)
- Avaliação: a licença do "Platformer character pack" permite uso comercial e modificação, crédito opcional;
  proíbe revender/redistribuir os sprites como asset e usar para IA/NFT. Só a amostra (parado + andando) é
  gratuita; o pacote completo custa US$ 15+. Para um survivors-like basta parado + andando (as armas atacam
  sozinhas), espelhando para a esquerda.
- Diferença de escala: o original tem ~55 px de altura; os personagens do Ninja Adventure têm 16 px. Reduzi a
  50% (~29 px) com `tools/make_side_sheet.gd`. Ela fica maior e mais detalhada que os outros: lê bem como
  protagonista, mas destoa um pouco do estilo (regra 8.1). Se incomodar, a alternativa é desenhar uma versão
  16×16 dela ou comprar o pacote e escolher outro tamanho.
- Implementado: layout "side" no `Player`, herói `yuki` (Tambor de Raijin, +10% poder, +5% velocidade, −10%
  vida), Golpe da Lanterna "Despertar Oni", conquista "Sangue de Oni" (vencer o Oni Vermelho) que a libera,
  textos nos 11 idiomas e licença no registro.

### Músicas japonesas (pedido de 21/10)
- 15 faixas do 甘茶の音楽工房 (categoria 和風・アジア), escolhidas pelo clima indicado no site (não foi possível
  ouvir): オープニング (título), 平安ノ宵 (Vila), 夜半ノ月 ～夜道/～荒城/～唐傘 (Bambu, Templo, Dunas), 幕末舞曲
  ～花ノ乱 (Yomi), 神々の宿る場所 (fase secreta), 幕末舞曲～戦 e 龍ノ舞 (chefes), 打ち上げ花火 (Noite Sem Fim),
  花祭り (amanhecer), 桜雲 (Santuário), Japanese Autumn (história), 故郷 (créditos), 悠久の時へ (Diário).
- Termos lidos no original: uso comercial como BGM de jogos e apps, edição livre, crédito opcional; proibido
  vender/redistribuir a música avulsa, Content ID e registro em JASRAC.
- `AudioManager` toca .ogg ou .mp3 em loop; a tela Créditos passou a tocar a própria música (antes usava a do
  título). Teste de integração confere que toda música usada existe.
- **Ouça e troque o que não combinar:** cada faixa é uma linha em `tools/amacha_assets.json`.

## Controle de dano e ritmo (21/10/2026)
Pedidos: "controle de dano que o personagem está recebendo desde a primeira fase"; tirar a contagem de 3 s
depois de escolher habilidade; itens do chão que chamem atenção; barra de vida sobre a cabeça.
- ✅ **Controle de dano** (plano 4.15): `DamageControl` com tetos por golpe e por janela, fonte de cada golpe,
  causa da morte, dano por minuto, linha `DANO` do bot, resultados e telemetria. Vila com `damage_mult` 0,5:
  bot passou de 2:21–3:39 para 3:07–5:24 (4 de 6 sementes passam dos 5:00).
- ✅ **Sem contagem** ao voltar de level-up, baú e Kami; a contagem de 1,5 s fica só na pausa e no reviver.
- ✅ **Itens do chão**: halo que pulsa, pulinho com sombra e brilho em cruz girando. Sem piscar (lê como
  "vai sumir" ou dano); com "reduzir flashes" o halo pulsa devagar e sem o brilho.
- ✅ **Barra de vida sobre a cabeça** por padrão (opção continua em Opções; ajustes antigos migrados).

### Splash (21/10/2026)
- Análise do que as boas aberturas têm em comum: curtas (2–3 s) e puláveis; continuam a splash do sistema
  sem piscar (mesma cor de fundo); uma única imagem que já passa o tom do jogo; um só som marcante; nada de
  texto longo; saída em fade direto na tela seguinte; o carregamento acontece por trás.
- ✅ `scripts/app/splash_screen.gd`: a chama da lanterna acende na noite, o halo cresce, brasas sobem, entram
  "百鬼 / HYAKKI / Até o Amanhecer" e toca o sino do templo. 2,6 s, toque pula, sem tremulação com "reduzir
  flashes". O título nasce por baixo no fade de saída. `boot_splash` do Godot com a mesma cor e sem imagem.

### Música de chefe (21/10/2026, aguardando download)
- Hoje: `boss_a` = 幕末舞曲～戦～ e `boss_b` = 龍ノ舞 (escolhidas sem ouvir, plano 12.7.2).
- Candidatas no catálogo, do mesmo 甘茶の音楽工房 (licença já registrada, crédito opcional), categoria 激しい:
  ボス戦 `boss.mp3` (1:11), 最終戦 `saishuusen.mp3` (3:07), 戦火 `senka.mp3` (2:26), 侵攻 `shinkou.mp3` (2:49),
  魔王の城 `maounoshiro.mp3` (2:32). Alternativa CC0: Hydrogene "28 High Quality 16-bit RPG Music"
  ("Battle Theme III", "The Evil One"; zip de 574 MB).

## Registro
- 20/10 19:25 — pipeline APK → emulador validado com o protótipo.
- 21/10 — 629 textos em 11 idiomas; registro e verificação de licenças; testes de integração.
- 21/10 — Correções achadas na validação:
  - bot reiniciava a partida dentro do passo em que morreu (partidas seguintes divergiam) → reinício adiado;
  - batimento de vida baixa conectava o sinal duas vezes → ligado uma vez;
  - `world.resolve` custava 7 ms por passo com 500 inimigos → grade de obstáculos;
    hash espacial sem alocações; separação escalonada a cada 3 passos;
  - fases 3–6 matavam em 7–30 s (inimigos de abertura fortes e mais rápidos que a guardiã) → status por fase
    reescalonados, perseguidores ≤ 55 de velocidade, degrau `difficulty` por fase aplicado nos primeiros 5 min;
  - só no APK: fonte não carregava (lida como arquivo bruto) → `ResourceLoader`;
  - fundo dos menus colapsava no canto (tamanho 0) → usa o tamanho da tela;
  - botão Voltar coberto pelos painéis (Loja etc.) → vai para a frente;
  - anúncio simulado descentralizado e sem tema; rótulo de velocidade errado ao iniciar em 3x;
    aba selecionada ilegível; glifo `›` ausente na fonte; chance de crítico exibida como "+0.1";
    créditos listavam motor e bibliotecas como "arte"; fonte da Ninja Adventure sem uso removida.
