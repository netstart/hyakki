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
2. **Testes end-to-end (E2E)**: testes que exercitam fluxos completos do jogo, executados em **ambos**:
   - no **Godot** (editor/exportação de desktop), e
   - no **emulador Android**, em **cada uma** das resoluções-alvo abaixo (build Android/APK rodando no emulador com o perfil de cada resolução).

**Resoluções-alvo** (a regra de qualidade é **por resolução**, não por aparelho). O jogo escala a tela
por um fator inteiro `k = round(altura / 300)` (`scripts/autoload/pixel_scaler.gd`), então cada
resolução física vira uma **resolução lógica**, e é ela que define o layout. **Toda tela, todo painel
e todo HUD precisam ser testados em todas as resoluções lógicas da tabela.** Os aparelhos são só
exemplos e perfis de emulador de cada resolução:

| Resolução lógica | Tela física (paisagem) | Escala | Aparelhos de exemplo | AVD do E2E |
|---|---|---|---|---|
| **678x305** | 2712x1220 (20:9) | ×4 | Redmi Note 14 Pro+ 5G | `Redmi_Note_14_Pro_Plus_5G` |
| **600x270** | 2400x1080 (20:9) | ×4 | Samsung Galaxy M55 5G (SM-M556B/DS), Google Pixel 7 | `Galaxy_M55_5G`, `Pixel_7` |
| **585x270** | 2340x1080 (19.5:9) | ×4 | Samsung Galaxy A15 / A15 5G (SM-A155F / SM-A156B), Samsung Galaxy A56 5G (SM-A566B), Xiaomi POCO M3, Galaxy S24 Ultra / S25 Ultra em FHD+ (padrão) | `Galaxy_A15` |
| **624x288** | 3120x1440 (19.5:9) | ×5 | Samsung Galaxy S24 Ultra (SM-S928B) / S25 Ultra (SM-S938B) em QHD+ | `Galaxy_S24_Ultra` |
| **780x360** | 1560x720 (19.5:9) | ×2 | Samsung Galaxy S24 Ultra / S25 Ultra em HD+ | — (só testes unitários) |
| **480x270** | 1920x1080 (16:9) | ×4 | telas 16:9 / desktop | — (só testes unitários) |

- **Fonte única:** a lista de resoluções dos testes fica em `tests/device_profiles.gd`; os testes de
  layout leem dela, sem tamanho fixo no código. Resolução nova = uma linha nesta tabela **e** em
  `tests/device_profiles.gd`; a partir daí todas as telas passam a ser testadas nela.
- **Testes unitários de layout:** em **cada** resolução da tabela, com a área segura de um furo de
  câmera **dos dois lados** (paisagem para a esquerda e para a direita), nenhum botão, texto ou elemento
  de toque pode ficar fora da tela, cortado, sobreposto ou dentro do recorte.
- **E2E:** `tools/run_e2e.ps1` (ou `Testes E2E no emulador.bat`) roda o roteiro nos AVDs da tabela
  (criados por `tools/create_test_avds.ps1`, perfis em `tools/test_devices.ps1`), um depois do outro, com
  o recorte de câmera emulado do Android ligado (`com.android.internal.display.cutout.emulation.hole`),
  e só passa se passar em todos.
- **Emulador travado:** a execução no emulador pode travar eventualmente (boot congelado ou `adb`
  sem resposta). Espere o emulador responder por até **8 minutos**; se não responder, desligue-o à força
  e reinicie-o, e retome o roteiro naquele AVD. Um travamento não conta como falha do teste, mas um
  AVD que não fica pronto nem depois do reinício reprova o E2E.

Nenhum PR é mesclado e nenhuma versão é lançada sem que os testes unitários (inclusive os de layout em
todas as resoluções-alvo) e os testes E2E passem no Godot e no emulador Android em todas as
resoluções-alvo.
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
