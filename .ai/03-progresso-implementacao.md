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
