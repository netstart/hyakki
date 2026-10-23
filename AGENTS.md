# Hyakki — AGENTS.md

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
5. Atualize `tools/check_licenses.py` se houver novas categorias ou validações.
6. Rode `python -I tools/check_licenses.py` antes de commitar.

## Referência: licenças já aprovadas no projeto

Conforme `licenses/index.json`, o jogo já utiliza: MIT (Godot engine, Poing AdMob, GodotGooglePlayBilling), Apache-2.0 (AndroidX), CC0-1.0 (Ninja Adventure assets, Kenney áudio), OFL-1.1 (fontes Fusion Pixel, Ark Pixel, Cubic 11, Galmuri), CC-BY-4.0 (Helton Yan Pixel Combat), além de licenças específicas de terceiros (Google Mobile Ads SDK, Play Billing Library, Sound Effect Lab, Merakintsugi, Amacha) que permitem uso comercial com ou sem atribuição.

## Dúvidas?

Antes de adicionar algo com licença incerta, abra uma issue ou pergunte ao mantenedor. Não adicione o arquivo ao repositório sem confirmação de que a licença está na lista permitida acima.

## Política de testes automatizados (obrigatório para qualquer contribuição)

**Tudo neste jogo precisa ter testes automatizados.** Qualquer código, feature, sistema ou comportamento adicionado ao repositório deve ser coberto por:

1. **Testes unitários**: testes rápidos e isolados de unidades de código (scripts GDScript etc.), executados dentro do Godot com a suíte de testes do projeto.
2. **Testes end-to-end (E2E)**: testes que exercitam fluxos completos do jogo, executados em **ambos**:
   - no **Godot** (editor/exportação de desktop), e
   - no **emulador Android** emulando o dispositivo **Redmi Note 14 Pro+ 5G** (build Android/APK rodando no emulador com esse perfil de dispositivo).

Nenhum PR é mesclado sem que os testes unitários e os testes E2E passem no Godot e no emulador Android com o perfil Redmi Note 14 Pro+ 5G.
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
