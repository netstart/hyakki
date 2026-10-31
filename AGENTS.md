## Padrão de Excelência Profissional

Todo trabalho neste projeto deve ser entregue com qualidade premium que surpreenda o usuário. O agente deve agir como um profissional especialista, demonstrando:

- Domínio técnico completo das tecnologias utilizadas (Godot, GDScript, GodotExport, etc.)
- Atenção minuciosa aos detalhes e à experiência do usuário final
- Soluções elegantes, otimizadas e bem documentadas
- Código limpo, bem estruturado e alinhado com padrões de engenharia de software
- Respeito aos princípios de licença livre e testes automatizados estabelecidos
- Compromisso com o versionamento SemVer rigoroso em todos os commits

A excelência profissional significa entregar valor real, não apenas código funcional. Cada contribuição deve elevar o padrão do projeto, demonstrando expertise que vai além do básico e cria impacto mensurável.

## Política de licença (obrigatório para qualquer contribuição)

**Tudo neste jogo precisa ser de licença livre para uso comercial, livre distribuição, inclusive para uso comercial.**

Qualquer código, asset, fonte, áudio, plugin ou dependência adicionado ao repositório deve:

1. Permitir **uso comercial** (venda, monetização, anúncios, compras in-app).
2. Permitir **distribuição livre** (redistribuição do jogo e de seus ativos, sem custo ou por valor).
3. Permitir **modificações** (editar, cortar, redimensionar, recompilar, integrar ao Godot).
4. Permitir **sub-licenciamento ou incorporação** no binário do jogo (Android/APK, exportação Godot).

Licenças que exigem "compartilha-alike" viral sobre todo o jogo (ex.: GPL, AGPL) ou que proíbem uso comercial (NC — Non-Commercial) ou obras derivadas (ND — No-Derivatives) **não são aceitas**.

## Lista de licenças permitidas

| Licença | SPDX | Uso comercial | Distribuição livre | Modificações | Atribuição | Observações |
|---------|------|---------------|--------------------|--------------|------------|-------------|
| MIT | `MIT` | ✅ Sim | ✅ Sim | ✅ Sim | ✅ Obrigatória | Código e assets |
| Apache 2.0 | `Apache-2.0` | ✅ Sim | ✅ Sim | ✅ Sim | ✅ Obrigatória | Código e assets; inclui patentes |
| CC0 1.0 | `CC0-1.0` | ✅ Sim | ✅ Sim | ✅ Sim | ❌ Não exigida | Domínio público; ideal para assets |
| Open Font License 1.1 | `OFL-1.1` | ✅ Sim | ✅ Sim | ✅ Sim | ✅ Obrigatória | Apenas fontes |
| CC-BY 4.0 | `CC-BY-4.0` | ✅ Sim | ✅ Sim | ✅ Sim | ✅ Obrigatória | Atribuição obrigatória ao autor |

## Licenças NÃO permitidas (exemplos)

- GPL, AGPL, LGPL (viral sobre o jogo inteiro)
- CC-BY-NC, CC-BY-ND, CC0-NC (proíbem comercial ou derivados)
- Qualquer licença proprietária "todos os direitos reservados" sem permissão explícita
- Licenças que restringem campos de uso (ex.: "não para militares", "não para jogos de azar")

## Processo para adicionar um novo ativo ou dependência

1. Verifique a licença do upstream e confirme que está na lista permitida acima.
2. Adicione a entrada em `licenses/registry.json` e `licenses/index.json` (campos: `id`, `name`, `category`, `author`, `license_id`, `commercial_use: true`, `attribution_required`, `source_url`, `license_file`, `notice_file`, `downloaded_at`, `verified_at`).
3. Copie o texto da licença para `licenses/texts/<id>.<spdx>.txt`.
4. Copie o aviso/copyright do autor para `licenses/notices/<id>_<nome>.txt`.
5. Inclua o asset no jogo/repositório, sempre junto com uma cópia da sua licença (`licenses/texts/<id>.<spdx>.txt` para o texto da licença e `licenses/notices/<id>_<nome>.txt` para o aviso/copyright do autor). Nenhum asset entra no jogo sem sua licença acompanhando.
6. Atualize `tools/check_licenses.py` se houver novas categorias ou validações.
7. Rode `python -I tools/check_licenses.py` antes de commitar.
8. Regenere `licenses/index.json`, `ASSET_LICENSES.md` e `CREDITS.md` com `python -I tools/build_license_index.py` e confirme que o ativo aparece na tela de créditos (veja "Tela de créditos" abaixo).

## Referência: licenças já aprovadas no projeto

Conforme `licenses/index.json`, o jogo já utiliza: MIT (Godot engine, Poing AdMob, GodotGooglePlayBilling), Apache-2.0 (AndroidX), CC0-1.0 (Ninja Adventure assets, Kenney áudio), OFL-1.1 (fontes Fusion Pixel, Ark Pixel, Cubic 11, Galmuri), CC-BY-4.0 (Helton Yan Pixel Combat), além de licenças específicas de terceiros (Google Mobile Ads SDK, Play Billing Library, Sound Effect Lab, Merakintsugi, Amacha) que permitem uso comercial com ou sem atribuição.

## Tela de créditos (obrigatório em toda versão)

A tela de créditos do jogo (`scripts/app/screens/credits_screen.gd`) e o `CREDITS.md` precisam listar **todo** autor, asset e software de `licenses/registry.json` / `licenses/index.json`, em **toda** versão. Nenhum autor fica de fora, nem os CC0.

- Sempre que um asset ou dependência for adicionado, removido ou alterado: atualize `licenses/registry.json`, regenere o índice com `python -I tools/build_license_index.py` (gera também `ASSET_LICENSES.md` e `CREDITS.md`) e confirme que a entrada aparece na tela de créditos, na seção certa.
- A tela lê `licenses/index.json` em tempo de execução: o que não é arte, áudio ou fonte (motor, Android, plugins, categorias novas) cai em Tecnologia. Não filtre entradas.
- O teste dos créditos (`tests/credits_screen_tests.gd`, rodado por `tests/integration_tests.tscn` ou sozinho por `tests/credits_screen_tests.tscn`) precisa passar antes de qualquer commit: ele confere que todo nome e autor do índice está visível na tela e no `CREDITS.md`.

## Dúvidas?

Antes de adicionar algo com licença incerta, abra uma issue ou pergunte ao mantenedor. Não adicione o arquivo ao repositório sem confirmação de que a licença está na lista permitida acima.

## Política de testes automatizados (obrigatório para qualquer contribuição)

**Tudo neste jogo precisa ter testes automatizados.** Qualquer código, feature, sistema ou comportamento adicionado ao repositório deve ser coberto por:

1. **Testes unitários**: testes rápidos e isolados de unidades de código (scripts GDScript etc.), executados dentro do Godot com a suíte de testes do projeto.
2. **Testes end-to-end (E2E)**: testes que exercitam fluxos completos do jogo (partida do bot, cenários,
   telas em sequência), executados **só no Godot** do PC, em cada uma das resoluções-alvo abaixo.

**Testes por resolução só no Godot; emulador Android só para teste manual.** Os testes que simulam a
tela dos aparelhos rodam **apenas no Godot** do PC: runners headless ou com janela que leem
`tests/device_profiles.gd` (testes de layout de cada tela, painel e HUD), `tests/scroll_bench.tscn`, os
testes de desempenho (`tests/perf_tests.gd`) e o `tools/run_checks.ps1`. **É proibido executar testes
automatizados no emulador Android** (roteiro E2E, AVDs de teste, `adb input`, medição de quadros ou
qualquer script que instale, toque e confira sozinho). O emulador e o aparelho servem só para **teste
manual**: uma pessoa instala, joga e confere (`Testar no emulador.bat`, `Testar release no emulador.bat`).
Não crie script, roteiro nem critério de aprovação que rode no emulador.

**Resoluções-alvo** (a regra de qualidade é **por resolução**, não por aparelho). O jogo escala a tela
por um fator inteiro `k = min(round(altura / 300), floor(largura / 480))`, nunca menor que 1
(`scripts/autoload/pixel_scaler.gd`), então cada resolução física vira uma **resolução lógica**, e é
ela que define o layout (simulada no Godot com a resolução lógica e a área segura de cada linha).
O segundo termo garante largura lógica de pelo menos 480: só muda o fator em telas quase quadradas (Galaxy Z Fold aberto, tablets 4:3), que descem um passo inteiro e ficam
mais altas (até 453) em vez de estreitas; em todas as outras linhas os dois termos dão o mesmo `k`. **Toda tela, todo painel
e todo HUD precisam ser testados em todas as resoluções lógicas da tabela.** Os aparelhos são só
exemplos de cada resolução:

| Resolução lógica | Tela física (paisagem) | Escala | Aparelhos de exemplo |
|---|---|---|---|
| **678x305** | 2712x1220 (20:9) | ×4 | Redmi Note 14 Pro+ 5G |
| **600x270** | 2400x1080 (20:9) | ×4 | Samsung Galaxy M55 5G (SM-M556B/DS), Google Pixel 7 |
| **585x270** | 2340x1080 (19.5:9) | ×4 | Samsung Galaxy A15 / A15 5G (SM-A155F / SM-A156B), Samsung Galaxy A56 5G (SM-A566B), Xiaomi POCO M3, Galaxy S24 Ultra / S25 Ultra em FHD+ (padrão) |
| **624x288** | 3120x1440 (19.5:9) | ×5 | Samsung Galaxy S24 Ultra (SM-S928B) / S25 Ultra (SM-S938B) em QHD+ |
| **780x360** | 1560x720 (19.5:9) | ×2 | Samsung Galaxy S24 Ultra / S25 Ultra em HD+ |
| **480x270** | 1920x1080 (16:9) | ×4 | telas 16:9 / desktop |
| **512x320** | 2560x1600 (16:10) | ×5 | Samsung Galaxy Tab S9 / S9 FE+ e tablets 16:10 QHD (sem furo na tela) |
| **500x300** | 2000x1200 (16:10) | ×4 | Samsung Galaxy Tab A9+ e tablets 16:10 de entrada (sem furo na tela) |
| **512x384** | 2048x1536 (4:3) | ×4 | tablets 4:3 (estilo iPad), Xiaomi Pad 4:3 (sem furo na tela) |
| **800x360** | 1600x720 (20:9) | ×2 | Samsung Galaxy A05 / A05s, Motorola Moto E13 / E14 (HD+ baratos) |
| **806x360** | 1612x720 (20:9) | ×2 | Motorola Moto G04 / G24 / E22, Xiaomi Redmi A3 (HD+ baratos) |
| **544x453** | 2176x1812 (quase 1:1) | ×4 | Samsung Galaxy Z Fold5 / Fold6 aberto (tela interna) |
| **772x301** | 2316x904 (23:9) | ×3 | Samsung Galaxy Z Fold5 / Fold6 fechado (tela externa) |
| **630x270** | 2520x1080 (21:9) | ×4 | Sony Xperia 1 / Xperia 5 (FHD+), Xiaomi e Motorola 21:9 |
| **660x270** | 2640x1080 (22:9) | ×4 | aparelhos 22:9 muito alongados (FHD+) |

- **Todas as resoluções, sempre:** **cada** tela, painel, diálogo, sobreposição e o HUD da partida
  (inclusive a área visível do jogo e a borda de surgimento dos inimigos) precisam ser testados em
  **todas** as resoluções lógicas da tabela, sem exceção, antes de qualquer commit e de qualquer
  versão: os testes de layout rodam no Godot em todas as linhas. Tela ou painel novo só entra com
  teste de layout que percorra a tabela inteira (`DeviceProfiles.layout_cases()`); falha em uma resolução reprova o commit, mesmo que as outras
  passem. A correção é sempre de layout responsivo (quebra de linha, rolagem, empilhar, colunas
  menores, tamanhos a partir da tela), nunca um caso especial para uma resolução.
- **Fonte única:** a lista de resoluções dos testes fica em `tests/device_profiles.gd`; os testes de
  layout leem dela, sem tamanho fixo no código. Resolução nova = uma linha nesta tabela **e** em
  `tests/device_profiles.gd`; a partir daí todas as telas passam a ser testadas nela. Aparelhos que dão
  a mesma resolução lógica ficam na mesma linha.
- **Testes unitários de layout:** em **cada** resolução da tabela, nos 11 idiomas, e com a área segura
  de um furo de câmera **dos dois lados** (paisagem para a esquerda e para a direita), nenhum botão,
  texto ou elemento de toque pode ficar fora da tela, cortado, sobreposto ou dentro do recorte. Vale
  também para as telas sem furo (tablets, Fold aberto): elas são testadas com a mesma faixa genérica
  dos dois lados.
- **Rolagem suave e desempenho (qualidade Alta):** toda tela com lista rolável precisa rolar sem
  engasgo, na qualidade gráfica **Alta**, em todas as resoluções. Os testes rodam no Godot do PC
  (nunca no emulador):
  - **Benchmark de rolagem (`tests/scroll_bench.tscn`, sem `--headless`):** em cada tela com lista
    rolável (Guardiões, Fases, Loja, Diário e cada capítulo do Guia, Opções, Créditos, Resultados, Santuário, Título), mede a
    tela parada e, em cada lista, piparotes até o fim e de volta e um arrasto lento com o dedo
    simulado, em todas as resoluções de `tests/device_profiles.gd`, sem VSync (custo real do quadro),
    com média, p95, p99, pior quadro, travadas, tempo de render na CPU, chamadas de desenho e o tempo
    da 1ª abertura de cada tela. Só os quadros em movimento contam. **Critério:** com `-- --strict`
    passa com **p95 ≤ 6 ms**, **nenhum quadro > 33 ms** e **nenhuma travada** (quadro em que a lista
    parou no meio do movimento) por lista, em todas as resoluções. Rode antes e depois de mexer em
    telas, fundo ou tema (`-- --res=585x270 --screens=shop,codex --out=bench.json`).
  - **Unitários (`tests/perf_tests.gd`, `tests/menu_backdrop_tests.gd`):** medidor de quadros,
    rolagem pelo dedo começando em cima de botões (sem apertá-los), ritmo de quadros,
    silhuetas nativas iguais ao laço, janela das partículas vivas e o fundo dos menus redesenhando só
    as camadas animadas.
  - **Partida (`tests/game_bench.tscn`, sem `--headless`):** quadro, render na CPU, chamadas de
    desenho e traços por quadro de uma partida do bot (`-- --bot --seed=7 --stress=500`), com
    `--native-strokes` para comparar com o caminho antigo e `--compare-shots=<pasta>` para conferir
    que o mesmo quadro sai igual pelos dois caminhos.
  Regras de desenho que esses testes protegem: o que é fixo não é redesenhado a cada quadro (camada
  própria, ou `StaticBake` para desenhos grandes como o mapa da jornada); desenho refeito a cada
  quadro não usa `draw_polygon`, `draw_colored_polygon`, `draw_polyline`, `draw_arc` nem
  `draw_multiline` (cada um cria um buffer novo na GPU a cada redesenho): use retângulos, texturas
  ou o `Stroke` (`Stroke.arc`, `Stroke.line`, `Stroke.polyline`, `Stroke.convex`, mesma geometria
  do motor em primitivas sem buffer, conferida pixel a pixel por `tests/stroke_pixel_tests.tscn`,
  sem `--headless`); cartões de lista que só mudam com toque/foco ficam assados (`StaticBake`, como
  os do Diário); trocar override de tema ou caixa de estilo só quando o estado muda (cada troca
  refaz o layout da tela); animações só decorativas esperam enquanto a lista rola pelo dedo
  (`TouchScroll.busy()`);
  animação lenta redesenha em ritmo próprio (o fundo dos menus a 30 Hz); botões e cartões dentro de
  listas deixam o toque passar para a lista (`TouchScroll`, ligado pelo App); nada de laço por pixel
  em GDScript para gerar texturas (use as operações nativas de `Image`).

Nenhum PR é mesclado e nenhuma versão é lançada sem que os testes unitários (inclusive os de layout em
todas as resoluções-alvo), os testes E2E e o benchmark de rolagem passem **no Godot** em todas as
resoluções-alvo. Teste no emulador ou no aparelho é só manual e não substitui nenhum deles.

## Site público e documentação publicada (netstart.github.io) — obrigatório

O site público https://netstart.github.io é o repositório irmão `C:\src\netstart.github.io`
([github.com/netstart/netstart.github.io](https://github.com/netstart/netstart.github.io)), publicado pelo GitHub
Pages a partir da **raiz** da branch `main` daquele repositório.

**Regra:** tudo que é publicado no site é editado e commitado **no repositório do site**, nunca em `docs/` do
hyakki. A pasta `docs/` do hyakki guarda só material da Play Console (`docs/store/`: ficha, guia, arte) e os
snapshots de licenças (`docs/licenses/`, lidos por `licenses/registry.json` e `tools/check_licenses.py`), e
**não é publicada**.

**O que vive no site** (`C:\src\netstart.github.io`):

- `privacy-policy.html` (raiz): a política de privacidade do Hyakki. URL oficial
  `https://netstart.github.io/privacy-policy.html`, usada na Play Console e em
  `scripts/app/screens/options_screen.gd`.
- `hyakki/privacy-policy.md`: fonte da política (mesma data e mesmo conteúdo do HTML).
- `hyakki/index.html`: landing do jogo.
- `app-ads.txt` (raiz): **gerado** pelo hyakki com `python -I tools/sync_site.py` a partir de
  `general/android/app_id` do `project.godot`. Nunca editado à mão.
- Redirecionamentos `games/hyakki/privacy-policy.html` e `hyakki/privacy-policy.html` (endereços antigos),
  `.nojekyll`, licenças/créditos do site e o hook `.githooks/pre-commit` (instalado com `.githooks/install.ps1`).

**Obrigações:**

1. Mudou `general/android/app_id` no `project.godot`? Rode `python -I tools/sync_site.py` e commite (e envie) o
   `app-ads.txt` no site. O hook de pre-commit do hyakki faz isso sozinho (`--commit`); `--push` também envia.
2. A URL da política é estável: `privacy-policy.html` **nunca** é apagado nem renomeado depois de publicado.
3. Mudou SDK, anúncios, compras, backup, servidor ou qualquer coleta de dados? Revise a política **no site**
   (`hyakki/privacy-policy.md` e `privacy-policy.html`, com a mesma data nos dois), commite e faça `git push`
   lá, no mesmo trabalho.
4. Nunca crie `docs/index.html`, `docs/privacy-policy.*`, `docs/app-ads.txt` ou `docs/.nojekyll` no hyakki.

**Hooks e verificações:**

- No hyakki, uma vez por clone: `powershell -ExecutionPolicy Bypass -File tools\install_hooks.ps1` (ou
  `tools/install_hooks.sh`). O hook `tools/githooks/pre-commit` bloqueia commits que tragam os arquivos do site de
  volta para `docs/` e, quando o `app_id` do AdMob muda, regenera e commita o `app-ads.txt` no site.
- No site: `.githooks/install.ps1` instala o `.githooks/pre-commit`, que confere a política (`.md` e `.html`).
- O hook do Claude Code em `.claude/settings.json` bloqueia `Edit`/`Write` nos caminhos antigos de `docs/`.
- `tools/run_checks.ps1`/`.sh` rodam `tools/test_sync_site.py` e `python -I tools/sync_site.py --check`; o site é
  localizado por `NETSTART_SITE_DIR` ou por `../netstart.github.io`.

## Versionamento (SemVer, obrigatório em todo commit)

A versão do jogo segue o [Versionamento Semântico](https://semver.org/lang/pt-BR/) no formato `MAIOR.MENOR.CORREÇÃO` (ex.: `1.4.12`).

**Onde fica a versão** (os quatro lugares precisam ter sempre o mesmo valor):

- `project.godot`: `config/version="X.Y.Z"`
- `export_presets.cfg`: `version/name="X.Y.Z"` em **todos** os presets
- `export_presets.cfg`: `version/code=N` em **todos** os presets. É o versionCode do Android, um inteiro que só sobe.

**Regra automática, em todo commit:**

1. Antes de cada commit, aumente o último número (`CORREÇÃO`) em 1 (ex.: `1.0.0` → `1.0.1`) e o `version/code` em 1.
2. Inclua essas alterações no próprio commit.
3. Faça isso **sem avisar e sem perguntar**: é rotina, não precisa de confirmação nem de menção na resposta.

**Quando mudar `MAIOR` ou `MENOR`:** a IA pode decidir mudar esses números quando a mudança justificar, seguindo o SemVer:

- `MENOR` (ex.: `1.4.12` → `1.5.0`): conteúdo ou funcionalidade nova que mantém a compatibilidade, como uma fase, um herói, um modo ou um sistema novo.
- `MAIOR` (ex.: `1.5.0` → `2.0.0`): mudança que quebra a compatibilidade, como um save antigo que não carrega mais sem migração, ou uma mudança grande de regras ou economia.
- Ao subir `MENOR`, a `CORREÇÃO` volta a 0. Ao subir `MAIOR`, `MENOR` e `CORREÇÃO` voltam a 0. O `version/code` continua subindo 1, sem zerar.

Nesse caso a IA **deve avisar** na resposta e na mensagem do commit qual número mudou (de → para) e por quê.
