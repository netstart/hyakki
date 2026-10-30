# Guia de publicação na Google Play — Hyakki: Até o Amanhecer

Passo a passo para publicar **este** jogo, do zero, com as respostas prontas para colar na Play Console.
Escrito em 25/10/2026, revisto em 27/10/2026 para a 1ª versão **com anúncios e compra**, e conferido nas
páginas oficiais do Google listadas em [Fontes](#fontes). A Play Console muda os nomes dos menus de
tempos em tempos: se algo não bater, procure pelo nome em inglês entre parênteses.

**Dados fixos desta versão**

| Item | Valor |
|---|---|
| Nome do app | Hyakki: Até o Amanhecer |
| ID do aplicativo (pacote) | `io.github.netstart.hyakki` (**não muda nunca mais** depois do primeiro envio) |
| Versão do 1º envio | `1.7.0` (versionCode 19) |
| Desenvolvedor | conta pessoal, GitHub `netstart` |
| E-mail público | netstart@gmail.com |
| Site | https://netstart.github.io/ |
| Política de privacidade | https://netstart.github.io/privacy-policy.html |
| targetSdk / minSdk | 36 (Android 16) / 24 (Android 7.0) |
| Preço | gratuito |
| Anúncios / compras | só anúncios premiados opcionais (sem anúncio de abertura); compras `remove_open_ad` ("Apoiar o jogo": Lanterna Dourada + recompensas sem anúncio) e `unlock_speed` (Ampulheta de Fūjin, velocidade 2x/3x) |
| AdMob | app `ca-app-pub-6552169828297838~1237111269`; editor `pub-6552169828297838` |

Visão geral do caminho (conta pessoal nova):

1. Criar a conta de desenvolvedor e verificar identidade e aparelho.
2. Publicar o site com a política e o `app-ads.txt` (GitHub Pages).
3. Criar o app e preencher **Conteúdo do app** e **Ficha da loja**.
4. Preparar a monetização: conta **AdMob** (pagamentos, impostos, mensagem de consentimento, aparelho
   de teste) e **perfil de pagamentos** da Play Console.
5. Gerar o AAB e enviar para o **teste interno** (só você, para conferir); só então criar o
   **produtos no app** `remove_open_ad` e `unlock_speed` e testar as compras com a conta de teste de licença.
6. Enviar para o **teste fechado** e manter **pelo menos 12 testadores por 14 dias seguidos**.
7. Pedir acesso à **produção**, esperar a análise (em geral até 7 dias) e lançar em etapas.
8. Com a ficha pública, **vincular o app no AdMob à ficha da Play**.

---

## 1. Conta de desenvolvedor (pessoal)

1. Acesse <https://play.google.com/console/signup> com a conta Google que vai ser dona do jogo
   (de preferência a mesma do e-mail netstart@gmail.com). É preciso ter 18 anos ou mais.
2. Escolha **Uso pessoal / Conta pessoal** (*Personal*). O número D-U-N-S **não** é pedido para
   conta pessoal; ele só é exigido de contas de organização.
3. Aceite o Contrato de Distribuição do Desenvolvedor e pague a taxa única de **US$ 25** com cartão de
   crédito ou débito no seu nome (Visa, Mastercard, Amex; cartão pré-pago não é aceito).
4. **Verificação de identidade:** envie um documento oficial com foto (RG ou CNH) com o mesmo nome do
   cartão. Se os dados forem recusados, a taxa não é devolvida, então confira o nome antes.
5. Preencha e verifique o **e-mail de contato** e o **telefone** que a Play Console pedir (o e-mail de
   contato do desenvolvedor é público na loja: use netstart@gmail.com).
6. **Verificação de aparelho Android:** contas pessoais novas precisam instalar o app
   **Google Play Console** num celular Android e entrar com a mesma conta para provar acesso a um
   aparelho real. O emulador não serve.
7. **Verificação de desenvolvedor Android (2026):** a partir de 30/09/2026 o Android exige apps de
   desenvolvedores verificados no Brasil, Indonésia, Singapura e Tailândia. Quem completou a
   verificação da Play Console já está coberto e o Google registra o pacote automaticamente. Depois de
   criar o app, confira em **Configurações › Verificação de desenvolvedor Android** se o pacote
   `io.github.netstart.hyakki` aparece como registrado.

> Regra das contas pessoais criadas depois de 13/11/2023: antes de publicar em produção é obrigatório
> um **teste fechado com pelo menos 12 testadores inscritos por 14 dias seguidos**. Veja a
> [seção 10](#10-teste-fechado-com-12-testadores-estratégia).

## 2. Site e política de privacidade (GitHub Pages)

O catálogo público está publicado no repositório [`netstart/netstart.github.io`](https://github.com/netstart/netstart.github.io), na raiz da branch `main`, em `https://netstart.github.io/`. A página inicial agrega os registros de licença dos jogos; a política do Hyakki fica em **`https://netstart.github.io/privacy-policy.html`** e o `app-ads.txt` em `https://netstart.github.io/app-ads.txt`.

1. A política é editada **diretamente** no repositório do site, `C:\src\netstart.github.io`
   (`netstart/netstart.github.io`): a fonte é `hyakki/privacy-policy.md` e a página publicada é
   `privacy-policy.html` na raiz, com a **mesma data** nas duas. Faça o commit e o `git push` lá; o hook
   `.githooks/pre-commit` do site (instalado com `.githooks/install.ps1`) confere os dois arquivos. Nada da
   política fica neste repositório.
2. Em **Settings › Pages**, confirme `Deploy from a branch`, branch `main`, pasta `/`.
3. Abra no celular e confira:
   - <https://netstart.github.io/>
   - <https://netstart.github.io/privacy-policy.html> (texto atual, falando de anúncios e da compra)
   - <https://netstart.github.io/app-ads.txt> (linha com `pub-6552169828297838`)
4. A política precisa ficar sempre no ar, pública, sem login, sem bloqueio por país e em HTML (PDF não vale). Não apague nem renomeie o arquivo depois de publicado.
5. O endereço antigo `https://netstart.github.io/games/hyakki/privacy-policy.html` continua no ar só como
   redirecionamento (*meta-refresh*) para a URL nova. **Não** use o antigo na Play Console: cole sempre
   `https://netstart.github.io/privacy-policy.html`.
> Nota: a pasta `docs/` do hyakki **não** é mais publicada (o Pages do site sai da raiz do repositório
> `netstart.github.io`). O `app-ads.txt` do site é gerado com `python -I tools/sync_site.py` a partir do
> `general/android/app_id` do `project.godot` (o hook de pre-commit do hyakki faz isso quando o ID muda);
> `--check` só confere.

O app já inclui o botão que abre a política em Opções; o endereço precisa continuar público e acessível.

## 3. Gerar o pacote de envio (AAB)

```powershell
powershell -ExecutionPolicy Bypass -File tools\build_release.ps1
```

- Gera `build\release\hyakki-release.aab` (é este que vai para a Play Console) e
  `build\release\hyakki-release.apk` (para conferir no emulador ou aparelho).
- Cada envio à Play Console precisa de um **versionCode maior** que o anterior. O versionCode e o
  versionName seguem o SemVer do `AGENTS.md` (sobem a cada commit); o script também aceita
  `-VersionCode N -VersionName X.Y.Z` se precisar forçar. O 1º envio é `1.7.0` (versionCode 19).
- Os IDs reais do AdMob **já estão no projeto** (`admob/general/android/app_id` no `project.godot` e
  `RELEASE_UNITS` em `scripts/ads/admob_provider.gd`), então o build de release sai com anúncios e
  compra ligados.
- **Nunca clique em anúncio real** do próprio app (o AdMob pode suspender a conta por tráfego
  inválido). Antes de abrir o APK de release, cadastre o aparelho como **dispositivo de teste** no
  AdMob ([seção 8.1](#81-conta-admob)); aí os anúncios vêm marcados como "Test Ad".
- Antes de enviar, abra o APK de release no aparelho de teste e confira:
  - o jogo abre **sem anúncio**: consentimento (onde exigido), introdução na 1ª vez e o título;
  - os **anúncios premiados** (Loja, Reviver, Dobrar ryō) entregam a recompensa depois de assistidos;
  - nenhum anúncio aparece no meio de uma partida;
  - em Opções existem **"Privacidade e anúncios"** (reabre o formulário de consentimento) e
    **"Restaurar compras"**;
  - a compra "Apoiar o jogo" mostra o **preço da loja** (só depois que o produto existir
    na Play e o app vier instalado pela Play Store; no APK lateral ela pode aparecer indisponível).

### Chave de envio e Assinatura de apps do Google Play

- A chave de envio (*upload key*) é `C:\src\keys\hyakki-upload.keystore`; usuário e senha ficam em
  `C:\src\keys\hyakki-release.env`. **Nunca** coloque esses arquivos no repositório, em `docs/`, em
  e-mail ou em chat.
- **Backup agora:** copie os dois arquivos para dois lugares fora do PC (por exemplo um pendrive
  guardado em casa e um cofre de senhas ou nuvem com criptografia). Guarde a senha também no cofre de
  senhas.
- No primeiro envio, a Play Console oferece a **Assinatura de apps do Google Play** (*Play App
  Signing*): aceite a opção padrão "Deixar o Google gerar e gerenciar a chave de assinatura do app". O
  Google guarda a chave final; a sua vira só a chave de envio. Se um dia perder a chave de envio, dá
  para pedir a troca em **Testar e lançar › Configuração › Integridade do app**.

## 4. Criar o app

**Página inicial › Criar app** (*Create app*):

| Campo | Resposta |
|---|---|
| Nome do app | `Hyakki: Até o Amanhecer` |
| Idioma padrão | `Português (Brasil) – pt-BR` |
| App ou jogo | **Jogo** |
| Gratuito ou pago | **Gratuito** (um app gratuito não pode virar pago depois) |
| Declarações | marque as duas: Políticas do programa para desenvolvedores e Leis de exportação dos EUA |

## 5. Conteúdo do app (*App content*)

Fica em **Monitorar e melhorar › Política › Conteúdo do app** (ou pelo painel "Configurar seu app").

### 5.1 Política de privacidade
`https://netstart.github.io/privacy-policy.html`

(Não use o endereço antigo `/games/hyakki/privacy-policy.html`: ele é só um redirecionamento.)

### 5.2 Anúncios (*Ads*)
**Sim, meu app contém anúncios.** A 1ª versão mostra um anúncio ao abrir o jogo (removível pela
compra) e anúncios premiados opcionais. Com "Sim", a Play exibe o selo "Contém anúncios" na ficha.
Declarar errado é violação de política.

### 5.3 Acesso ao app (*App access*)
**Todas as funcionalidades estão disponíveis sem restrições de acesso** (não há login nem conta).

### 5.4 Classificação do conteúdo (questionário IARC)
1. E-mail: netstart@gmail.com. Categoria: **Jogo** (*Game*; não é "Rede social", "Comunicação" nem
   "Referência").
2. Respostas (o texto das perguntas varia; responda pelo sentido):

| Tema | Resposta | Por quê |
|---|---|---|
| Violência | **Sim**, violência de fantasia | a guardiã combate yōkai, demônios e espíritos com armas mágicas e lâminas, em pixel art, visto de cima |
| Violência realista / contra humanos reais | **Não** | todos os inimigos são criaturas sobrenaturais; nada fotorrealista |
| Sangue, gore, desmembramento | **Não** | inimigos somem em cinzas, névoa, ossos de pixel, respingo de slime; sem sangue humano |
| Medo / terror | **Sim, leve** (criaturas e cenas assustadoras de fantasia, sem susto realista) | ambientação noturna com yōkai e chefes como Shinigami e Izanami |
| Conteúdo sexual / nudez | **Não** | |
| Linguagem imprópria | **Não** | |
| Drogas, álcool, tabaco | **Referência a álcool: Sim** (sem uso mostrado, sem incentivo) | o item passivo "Saquê Sagrado" (oferenda ritual 御神酒) e o enfeite de Loja "Cabaça de Saquê"; não há personagem bebendo |
| Jogos de azar simulados / apostas com dinheiro | **Não** | a "aposta" do chefe Tanuki é só história; o Baú Laqueado é recompensa de jogo, não se compra |
| Humor grosseiro | **Não** | |
| Interação entre usuários / chat / conteúdo gerado | **Não** | jogo offline, um jogador |
| Compartilha localização do usuário | **Não** | |
| Compras digitais | **Sim** | duas compras únicas, não consumíveis: `remove_open_ad` ("Apoiar o jogo": dá a Lanterna Dourada e entrega as recompensas opcionais sem assistir anúncio) e `unlock_speed` (Ampulheta de Fūjin: libera a velocidade 2x/3x; também pode ser liberada com ryō ganho jogando); não há caixa de itens aleatórios à venda |
| Navegador ou busca na web | **Não** | |
| NFT / blockchain | **Não** | |

3. Classificação esperada (aproximada; o IARC decide): **ESRB Everyone 10+** (Fantasy Violence;
   pode vir "Alcohol Reference" e o aviso "In-Game Purchases"), **PEGI 7**, **USK 6 ou 12**,
   **ClassInd 10** (Violência fantasiosa; pode subir para 12 por menção a álcool), e
   "Classificação 10+/12+" na Play. Qualquer resultado até 12 é compatível com o público-alvo 13+ abaixo.
4. Refaça o questionário sempre que mudar algo nas respostas (por exemplo, se um dia entrar outra
   compra, chat ou conteúdo novo que mude a classificação).

### 5.5 Público-alvo e conteúdo (*Target audience and content*)
- Faixas etárias: marque **13–15**, **16–17** e **18 ou mais**. **Não** marque 5 e menos, 6–8 nem 9–12.
- Por quê: com anúncios, a faixa **13+ é necessária**. Qualquer faixa abaixo de 13 coloca o app na
  **Política para Famílias**, que exige SDK de anúncios **autocertificado para Famílias**, anúncios
  adequados a crianças, sem ID de publicidade para crianças, revisão mais rígida e cumprimento de
  COPPA. O AdMob como está configurado no jogo não é usado em modo autocertificado para Famílias, então
  marcar faixa infantil tornaria o app irregular. Além disso, o jogo tem combate, criaturas
  assustadoras e referência a álcool (classificação esperada 10+/12), e a política de privacidade já
  diz "a partir de 13 anos".
- Se aparecer "A ficha da loja pode atrair crianças sem querer?": responda **Não**. A ficha usa tom
  noturno, yōkai e combate, sem personagens infantis nem linguagem voltada a crianças. Não use
  imagens fofas/infantis nas capturas para manter essa resposta verdadeira.

### 5.6 App de notícias
**Não.**

### 5.7 Segurança dos dados (*Data safety*)
Base: "coletar" é enviar dados para fora do aparelho, inclusive por SDKs de terceiros; dados que só
ficam no aparelho não entram no formulário. O save, as configurações e o registro de partidas do Hyakki
ficam só no aparelho.

O pacote inclui o **SDK de anúncios do Google (GMA Next-Gen SDK 1.4.0)**, o **Play Billing 9.1.0** e o
manifesto final recebe a permissão `AD_ID`. Na 1ª versão o SDK de anúncios **é iniciado** e pede
anúncios (só premiados; não há anúncio de abertura), então a coleta abaixo é real: declare **os tipos que o Google
documenta para o SDK de anúncios**. Ela também precisa bater com a declaração de ID de publicidade
(5.12) e com os SDKs que a Play encontra no pacote; declarar a menos é violação.

Respostas recomendadas:

1. **Seu app coleta ou compartilha algum dos tipos de dados exigidos?** **Sim.**
2. **Todos os dados coletados são criptografados em trânsito?** **Sim** (o SDK usa TLS).
3. **Você oferece uma forma de os usuários pedirem a exclusão dos dados?** **Não** — não há conta
   nem dados no nosso servidor; o app não guarda nada fora do aparelho. (Os controles do ID de
   publicidade ficam nas configurações do Android, e o consentimento pode ser revisto em Opções ›
   "Privacidade e anúncios".)
4. Tipos de dados (para cada um: **Coletado: Sim**, **Compartilhado: Sim**, **Processado de forma
   temporária: Não**, **Obrigatório** — o jogador não pode desligar dentro do app):

| Categoria › tipo | Finalidades (marque) |
|---|---|
| Local › **Local aproximado** (estimado pelo IP) | Publicidade ou marketing; Análise; Prevenção de fraudes, segurança e conformidade |
| Atividade no app › **Interações no app** (aberturas, toques, vídeos vistos) | Publicidade ou marketing; Análise; Prevenção de fraudes, segurança e conformidade |
| Informações e desempenho do app › **Diagnóstico** (tempo de abertura, travamentos, energia) | Análise; Prevenção de fraudes, segurança e conformidade |
| IDs do dispositivo ou outros IDs › **IDs do dispositivo ou outros IDs** (ID de publicidade, ID do conjunto de apps) | Publicidade ou marketing; Análise; Prevenção de fraudes, segurança e conformidade |

5. Não marque: informações pessoais, financeiras (veja a nota), saúde, mensagens, fotos, áudio,
   arquivos, agenda, contatos, histórico de navegação, local exato, registros de falhas (*crash logs*:
   o jogo não tem Crashlytics).
6. **Compras (nota):** a compra é processada pelo próprio Google Play e o jogo só confere a compra no
   aparelho, sem servidor próprio; por isso não há "Histórico de compras" a declarar. Se um dia houver
   servidor validando compras, acrescente **Informações financeiras › Histórico de compras**.

Depois de salvar, a Play mostra a prévia da seção "Segurança dos dados". Confira se aparece
"Os dados são criptografados em trânsito" e os quatro tipos acima.

### 5.8 Apps governamentais
**Não.**

### 5.9 Recursos financeiros
**Meu app não oferece nenhum recurso financeiro.**

### 5.10 Saúde
**Meu app não tem recursos de saúde.**

### 5.11 Outras declarações que podem aparecer
- **Serviço em primeiro plano** (*Foreground service*): o manifesto final tem só
  `FOREGROUND_SERVICE` genérico, vindo da biblioteca WorkManager (dependência dos SDKs do Google), e
  nenhum `FOREGROUND_SERVICE_<tipo>`. Se a Play Console pedir declaração, responda que o app **não usa**
  serviço em primeiro plano por conta própria (é da biblioteca).
- **`READ_BASIC_PHONE_STATE`**: vem do SDK de anúncios; é permissão normal, sem diálogo e sem
  declaração especial.
- **Exclusão de conta** (*Account deletion*): não se aplica (o app não cria contas).

### 5.12 ID de publicidade (*Advertising ID*)
O manifesto final (fundido pelo Gradle) contém `com.google.android.gms.permission.AD_ID` (e
`android.permission.AD_ID`), trazidas pelo SDK de anúncios. Responda:

- **Seu app usa o ID de publicidade?** **Sim.**
- Finalidades: **Publicidade ou marketing**, **Análise**, **Prevenção de fraudes, segurança e
  conformidade** (as mesmas do formulário de segurança dos dados).

Se responder "Não" com a permissão no manifesto, a Play bloqueia o envio da versão.

Permissões do manifesto final (para referência, conferidas no manifesto fundido do build):
`INTERNET`, `ACCESS_NETWORK_STATE`, `VIBRATE` (do jogo); `AD_ID` (as duas),
`READ_BASIC_PHONE_STATE` (SDK de anúncios); `com.android.vending.BILLING` (Play Billing);
`WAKE_LOCK`, `FOREGROUND_SERVICE` (WorkManager); `<pacote>.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`
(AndroidX, interna). Nenhuma é "perigosa" (nenhum diálogo de permissão aparece para o jogador).

## 6. Ficha principal da loja (*Main store listing*)

**Crescer › Presença na loja › Ficha principal da loja.** Textos em `docs/store/listing.md`, bloco
`pt_BR` (o idioma padrão):

| Campo | De onde |
|---|---|
| Nome do app (≤ 30) | linha **Título** do bloco `pt_BR` |
| Descrição curta (≤ 80) | linha **Descrição curta** |
| Descrição completa (≤ 4.000) | tudo abaixo de **Descrição completa:** até o fim do bloco (sem os marcadores `<!-- -->`) |

Rode `python -I tools/check_store_listing.py` depois de qualquer ajuste. Os marcadores `•` funcionam
na Play; não use emoji, ranking, preço, "grátis" nem chamada como "baixe já". A ficha já explica os
anúncios premiados opcionais e a compra única; a Play mostra os selos "Contém anúncios" e
"Compras no app".

### 6.1 Gráficos
A arte pronta fica em `docs/store/graphics/` (como regerar: [graphics/README.md](graphics/README.md)).
Envie assim:

| Campo | Arquivo | Regras da Play |
|---|---|---|
| Ícone do app | `docs/store/graphics/icon_512.png` | 512 × 512, PNG 32 bits, até 1 MB; a Play aplica a máscara (não arredonde) |
| Recurso gráfico (*feature graphic*) | `docs/store/graphics/feature_graphic_pt-BR.png` (inglês: `feature_graphic_en.png`) | 1024 × 500, PNG 24 bits **sem alfa** |
| Capturas de telefone | `docs/store/graphics/screenshots/pt-BR/` (inglês: `screenshots/en/`) | **no máximo 8**: há 12, escolha 8. Sugestão: 01, 02, 03, 04, 06, 07, 08, 09 (não use a 12: mostra "Dobrar ryō (presente)", texto de um build sem anúncios). 1920 × 1080 (16:9) |
| Tablet 7" | `docs/store/graphics/tablet/7in/pt-BR/` (inglês: `tablet/7in/en/`) | 4 capturas, 2560 × 1440 |
| Tablet 10" | `docs/store/graphics/tablet/10in/pt-BR/` (inglês: `tablet/10in/en/`) | 4 capturas, 2560 × 1440 |
| Vídeo (opcional) | URL do YouTube | público ou não listado, sem anúncios; jogo de verdade nos primeiros 10 s |

As pastas `screenshots/raw/` e `tablet/*/raw/` são capturas cruas de referência (proporção 2,22 do jogo,
acima do limite 2:1 da Play): **não envie essas**.

Na tradução em inglês (e nas outras, se quiser), use **Gráficos localizados** com as versões `en`.

### 6.2 Categoria, tags e contato
**Crescer › Presença na loja › Configurações da loja** (*Store settings*):

- **Categoria: Ação** (*Action*). Recomendada no lugar de Casual: o núcleo é combate em tempo real
  contra hordas e chefes, com builds e dificuldade crescente; é onde estão os survivors-like e
  roguelikes de ação, e quem busca esse gênero filtra por Ação. Casual sugere partidas sem desafio e
  frustraria quem chega por lá.
- **Tags** (até 5, escolhidas da lista da Play; os nomes exatos podem variar): Roguelike, Ação,
  Pixel art/Pixelado, Fantasia, Offline/Um jogador. Prefira as que descrevem o jogo, não tendências.
- **E-mail:** netstart@gmail.com · **Site:** https://netstart.github.io/ (o AdMob procura o
  `app-ads.txt` na raiz desse domínio; não mude) · **Telefone:** deixe em branco (opcional).
- **Política de privacidade:** já preenchida em 5.1.

## 7. Traduções da ficha

**Ficha principal da loja › Gerenciar traduções › Adicionar suas próprias traduções.** Adicione os 10
idiomas e cole de `docs/store/listing.md` o bloco correspondente (título, descrição curta e
completa):

| Bloco no arquivo | Idioma na Play Console |
|---|---|
| `en` | Inglês (Estados Unidos) – en-US (opcional: copie também para en-GB) |
| `es` | Espanhol (Espanha) – es-ES e Espanhol (América Latina) – es-419 |
| `de` | Alemão – de-DE |
| `fr` | Francês (França) – fr-FR (opcional: fr-CA) |
| `ru` | Russo – ru-RU |
| `id` | Indonésio – id |
| `ja` | Japonês – ja-JP |
| `ko` | Coreano – ko-KR |
| `zh_TW` | Chinês (tradicional) – zh-TW |
| `zh_CN` | Chinês (simplificado) – zh-CN |

Não use a tradução automática da Play: os textos já foram escritos com os nomes do jogo. Sem
capturas localizadas, a Play mostra as da ficha principal.

## 8. Monetização: AdMob e compra no app

Os IDs reais **já estão no projeto**; não há nada para colar no código:

| Onde | Valor |
|---|---|
| `project.godot` › `admob/general/android/app_id` | `ca-app-pub-6552169828297838~1237111269` |
| `scripts/ads/admob_provider.gd` › `RELEASE_UNITS["rewarded"]` | `ca-app-pub-6552169828297838/5734137356` |
| `scripts/autoload/purchase_manager.gd` › `PRODUCT` | `remove_open_ad` — "Apoiar o jogo" (preço de referência `PRICE_TEXT`: US$ 2,99) |
| `scripts/autoload/purchase_manager.gd` › `SPEED_PRODUCT` | `unlock_speed` (preço de referência `SPEED_PRICE_USD`: US$ 1,99; `SPEED_PRICE_BRL`: R$ 4,99 em pt_BR) |
| `scripts/autoload/purchase_manager.gd` › `SPEED_RYO_PRICE` | 3.000 ryō (a mesma Ampulheta, comprada com a moeda do jogo) |

Com isso o build de release liga: anúncios premiados opcionais (Loja, Reviver, Dobrar ryō; com
"Apoiar o jogo" eles viram presentes, sem anúncio), o formulário de consentimento UMP e as linhas
"Privacidade e anúncios" e "Restaurar compras" em Opções. Nenhum anúncio interrompe uma partida.
A Ampulheta de Fūjin (`unlock_speed`) não depende de anúncios: o Play Billing conecta sempre e
"Restaurar compras" aparece mesmo num build sem anúncios.

### 8.1 Conta AdMob
Em <https://admob.google.com>, com a mesma conta Google (o app e os blocos já existem nela):

0. **Bloco de abertura sem uso:** o jogo não carrega mais o bloco *App open*
   `ca-app-pub-6552169828297838/9118848597`. Ele pode ficar como está (sem pedidos, sem efeito) ou
   ser arquivado em **Apps › Hyakki › Blocos de anúncios**; não reaproveite o ID.

1. **Pagamentos** (*Payments*): preencha endereço e dados de pagamento e, em **Informações
   fiscais**, o formulário **W-8BEN** (pessoa física residente no Brasil, sem negócio nos EUA). Sem
   isso o AdMob retém os pagamentos.
2. **Privacidade e mensagens** (*Privacy & messaging*):
   - **GDPR** — **obrigatória**: crie e publique a mensagem de consentimento para EEE, Reino Unido e
     Suíça, ligada ao app Hyakki. O jogo mostra o formulário UMP quando ele existe, e sem a mensagem os
     anúncios nessas regiões ficam limitados.
   - **Regulamentos estaduais dos EUA** — opcional; pode criar a mensagem de "não vender/compartilhar".
3. **Aparelho de teste:** **Configurações › Dispositivos de teste › Adicionar dispositivo de teste**,
   com o ID de publicidade do seu celular (Configurações do Android › Google › Anúncios). Faça isso
   **antes** de abrir o APK ou a versão de teste interno. Nunca clique em anúncio real do próprio app.
4. **app-ads.txt:** o arquivo já está em <https://netstart.github.io/app-ads.txt> com
   `pub-6552169828297838` (gerado por `python -I tools/sync_site.py` a partir do `app_id` do
   `project.godot`; não edite à mão). O AdMob o procura na raiz do domínio do **site da ficha da Play**
   (`https://netstart.github.io/`), então só verifica depois que a ficha estiver pública. Em
   **Apps › app-ads.txt**, acompanhe o status; a verificação pode levar até 24 h depois do vínculo.
5. **Vincular à ficha da Play** (depois que o app estiver **público** na produção): **Apps › Hyakki ›
   Configurações do app › Detalhes da app store › Adicionar**, procure `io.github.netstart.hyakki` e
   confirme. Antes do vínculo e da revisão do app, o AdMob pode **limitar a veiculação** (poucos ou
   nenhum anúncio real); isso é esperado no teste interno e fechado.

### 8.2 Perfil de pagamentos na Play Console
Para vender a compra é preciso um **perfil de pagamentos** (conta de comerciante): **Configurações ›
Perfil de pagamentos** (*Payments profile*), crie ou associe o perfil e preencha os **dados fiscais
brasileiros** (CPF e endereço) e a conta bancária para receber. Sem ele o menu de produtos fica
bloqueado.

### 8.3 Produto `remove_open_ad` — "Apoiar o jogo" (só depois do 1º AAB)
A Play **só deixa criar produto no app depois que um AAB com a permissão `BILLING` foi enviado para
alguma faixa**. O teste interno serve. A ordem é:

1. Envie o AAB `1.7.0` no **teste interno** ([seção 9.2](#92-teste-interno-primeiro-para-você)).
2. **Monetizar › Produtos › Produtos no app › Criar produto** (*In-app products*):
   - ID do produto: **`remove_open_ad`** (a constante `PRODUCT`; o ID **não pode ser mudado** nem
     reaproveitado depois);
   - tipo: **único, não consumível** (*one-time*);
   - nome: "Apoiar o jogo";
   - descrição: "Compra única de apoio: a Lanterna Dourada é sua e as recompensas opcionais (Loja,
     Reviver, Dobrar ryō) chegam de presente, sem assistir anúncio.";
   - preço: **US$ 2,99** como base (o `PRICE_TEXT` de referência), deixando a Play converter para as
     outras moedas; o jogo mostra o preço real que vem da loja;
   - traduções de nome e descrição para os **10 idiomas** da ficha (mesma lista da seção 7);
   - **Salvar** e **Ativar**.

   **Produto já criado com o nome antigo** ("Remover anúncio de abertura"): o ID continua
   `remove_open_ad`, então só edite o produto em **Monetizar › Produtos › Produtos no app ›
   remove_open_ad**: troque o **nome** e a **descrição** pelos acima, nos 11 idiomas (os textos do
   jogo estão em `tools/i18n/ui.py`: `shop.support` sem o preço e `shop.support_hint`), e salve. Quem
   já comprou não precisa fazer nada: a restauração ao abrir o jogo entrega as recompensas sem anúncio.
3. **Configurações › Teste de licença** (*License testing*): adicione a sua conta Google (e a de quem
   for testar a compra). Contas de teste de licença compram com cartão de teste, **sem cobrança**.

### 8.4 Produto `unlock_speed` — Ampulheta de Fūjin (velocidade 2x/3x)
Mesmo caminho da seção 8.3 (depois do 1º AAB com `BILLING`):

1. **Monetizar › Produtos › Produtos no app › Criar produto**:
   - ID do produto: **`unlock_speed`** (a constante `SPEED_PRODUCT`; o ID **não pode ser mudado** nem
     reaproveitado depois);
   - tipo: **único, não consumível** (*one-time*): vale para sempre e volta em "Restaurar compras";
   - preço: **US$ 1,99** como base, deixando a Play converter, e **preço manual de R$ 4,99 no
     Brasil** (**Preços por país/região › Brasil › Editar**). Por quê: a conversão direta de
     US$ 1,99 dá cerca de R$ 11, alto para o poder de compra local; R$ 4,99 fica na faixa de compra
     por impulso (abaixo de um lanche), coerente com a mesma Ampulheta custar 3.000 ryō (~7 boas
     partidas) para quem não quer pagar. O jogo mostra o `formatted_price` real que vem da Play e,
     enquanto ela não responde, R$ 4,99 em pt-BR e US$ 1,99 nos outros idiomas;
   - nome e descrição (até 55 e 200 caracteres), um por idioma:

| Idioma | Nome | Descrição |
|---|---|---|
| pt-BR | Ampulheta de Fūjin | Libera para sempre a velocidade 2x e 3x em todas as partidas. |
| en-US | Fūjin's Hourglass | Unlocks 2x and 3x game speed in every run, forever. |
| es-ES / es-419 | Reloj de arena de Fūjin | Desbloquea para siempre la velocidad 2x y 3x en todas las partidas. |
| de-DE | Fūjins Sanduhr | Schaltet Tempo 2x und 3x in jedem Lauf dauerhaft frei. |
| fr-FR | Sablier de Fūjin | Débloque pour toujours la vitesse 2x et 3x dans chaque partie. |
| ru-RU | Песочные часы Фудзина | Навсегда открывает скорость 2x и 3x во всех забегах. |
| id | Jam Pasir Fūjin | Membuka kecepatan 2x dan 3x di setiap permainan, selamanya. |
| ja-JP | 風神の砂時計 | すべてのプレイで2倍速・3倍速が永久に使えるようになります。 |
| ko-KR | 후진의 모래시계 | 모든 판에서 2배속·3배속을 영구히 해제합니다. |
| zh-TW | 風神沙漏 | 永久解鎖每一局的 2 倍與 3 倍速度。 |
| zh-CN | 风神沙漏 | 永久解锁每一局的 2 倍与 3 倍速度。 |

   - **Salvar** e **Ativar**.
2. Teste com a conta de **Teste de licença**: comprar, reinstalar e "Restaurar compras". Um reembolso
   pelo Play Console tira a velocidade só de quem pagou na Play; quem liberou com ryō nunca perde.

## 9. Lançamentos: teste interno → teste fechado → produção

### 9.1 Países e regiões
Em cada faixa: **Países/regiões › Adicionar** e escolha **todos** (o jogo é offline, em 11 idiomas, sem
conteúdo regional). Se algum país pedir documentação extra, remova só ele.

### 9.2 Teste interno (primeiro, para você)
1. **Testar e lançar › Testes › Teste interno › Criar nova versão.**
2. Aceite a **Assinatura de apps do Google Play** (seção 3).
3. Envie `build\release\hyakki-release.aab`. Nome da versão: o `version/name` (`1.7.0`).
4. Notas da versão: as da [seção 9.5](#95-notas-da-versão-1-versão).
5. Em **Testadores**, crie uma lista de e-mails com a sua conta, salve e abra o **link de inscrição**
   (*opt-in URL*) no celular. A versão aparece em minutos.
6. Agora crie o produto e o teste de licença ([seção 8.3](#83-produto-remove_open_ad--apoiar-o-jogo-só-depois-do-1-aab)).
7. Instale pela Play Store, no aparelho cadastrado como teste no AdMob, e confira:
   - o **formulário de consentimento** aparece na primeira abertura quando você estiver numa região
     com mensagem (no Brasil, em geral não aparece; Opções › "Privacidade e anúncios" abre o
     formulário quando houver);
   - o jogo abre **sem anúncio** e os **premiados** aparecem como anúncio de teste (ou não aparecem
     ainda, se o AdMob estiver limitando a veiculação) e o jogo segue normalmente nos dois casos;
   - os premiados entregam a recompensa; nenhum anúncio aparece no meio da partida;
   - a compra mostra o preço da loja e, com a conta de teste de licença, conclui **sem cobrança** e
     as recompensas passam a vir de presente ("Receber grátis", "Reviver (presente)"); desinstale, reinstale e use **"Restaurar compras"** para conferir
     que ela volta.

### 9.3 Teste fechado (obrigatório para contas pessoais novas)
1. **Testes › Teste fechado › Gerenciar faixa** (a faixa "Alpha" já existe) **› Criar nova versão**,
   e promova o mesmo AAB do teste interno (ou envie um novo com versionCode maior).
2. Países: todos. **Testadores:** um **Grupo do Google** (ver seção 10) e/ou uma lista de e-mails.
3. Envie para **revisão**. A primeira revisão de um app novo pode levar alguns dias.
4. Depois de aprovado, mande o **link de inscrição** aos testadores. O relógio dos 14 dias começa para
   cada testador quando ele se inscreve.
5. Testadores que não estão no teste de licença **pagam de verdade** se comprarem; avise isso no
   convite.

### 9.4 Pedir produção e lançar
1. Quando o painel mostrar **12+ testadores inscritos há 14 dias seguidos**, vá em **Painel › Solicitar
   acesso à produção** (*Apply for production*).
2. Responda às três partes: sobre o teste fechado (como recrutou, o que eles testaram, o que mudou com
   o feedback), sobre o jogo (público, o que o diferencia, quantas instalações espera no primeiro ano)
   e sobre a prontidão (como sabe que está pronto). Seja específico: cite as correções feitas a
   partir do teste.
3. A análise costuma levar **até 7 dias**. Se pedirem mais teste, continue o teste fechado.
4. Aprovado: **Produção › Criar nova versão**, envie o AAB (ou promova do teste fechado), países todos.
5. **Lançamento em etapas** (*staged rollout*): comece com **20%** de usuários; após 2–3 dias sem
   falhas no **Android vitals** (taxa de falhas e ANR), suba para 50% e depois 100%. Se aparecer um
   problema grave, use **Interromper lançamento**, corrija e envie nova versão com versionCode maior.
6. Com a ficha pública, faça o **vínculo AdMob ↔ Play** e acompanhe o `app-ads.txt`
   ([seção 8.1](#81-conta-admob), itens 4 e 5).

### 9.5 Notas da versão (1ª versão)
Cole no campo de notas (cada idioma tem limite de 500 caracteres):

```
<pt-BR>
Primeira versão de Hyakki: Até o Amanhecer. Enfrente a procissão dos cem yōkai com 7 guardiões, 26 armas e pactos com 15 Kami em 6 fases. Partidas de 15 minutos, jogáveis com um dedo, offline e em 11 idiomas. Anúncios premiados são opcionais e há um anúncio ao abrir o jogo, removível com uma compra única. Nenhum anúncio interrompe uma partida. Encontrou um problema? Escreva para netstart@gmail.com.
</pt-BR>
<en-US>
First release of Hyakki: Until Dawn. Face the parade of a hundred yōkai with 7 guardians, 26 weapons and pacts with 15 Kami across 6 stages. 15-minute runs, playable with one finger, offline and in 11 languages. Rewarded ads are optional, and one ad shows when the game opens, removable with a one-time purchase. No ad ever interrupts a run. Found a problem? Write to netstart@gmail.com.
</en-US>
```

(pt-BR: 401 caracteres; en-US: 387.)

### 9.5.1 Notas da versão 1.15.0 (versionCode 31)
Para o envio com o Omikuji do baú (1.14.0) e as Missões do Santuário (1.15.0). Gere o AAB com
`tools\build_release.ps1` e envie em **Teste interno** (ou na faixa em que o app estiver):

```
<pt-BR>
Novidades: o Baú Laqueado agora tira a sua sorte no omikuji (吉, 中吉, 大吉 e, às vezes, 凶 com consolo) antes de uma roleta que para em cada item. As conquistas viraram 172 Missões do Santuário em 10 categorias, com barras de progresso no Diário e as Próximas 3 metas no título e nos Resultados. Nova opção "Animação curta do baú" e correção da conquista de 5 Golpes da Lanterna.
</pt-BR>
<en-US>
New: the Lacquered Chest now draws your omikuji fortune (吉, 中吉, 大吉 and sometimes 凶 with a consolation) before a reel that stops on each item. Achievements became 172 Sanctuary Missions in 10 categories, with progress bars in the Journal and your Next 3 goals on the title and Results screens. New "Short chest animation" option, and the 5 Lantern Strikes achievement is fixed.
</en-US>
```

### 9.6 Relatório de pré-lançamento (*Pre-launch report*)
Roda sozinho em aparelhos reais do Google sempre que um AAB entra num teste (interno, fechado ou
aberto). Abra em **Testar e lançar › Relatório de pré-lançamento** e confira:
- **Estabilidade:** nenhuma falha (crash) nem ANR. Se houver, o relatório traz vídeo e log.
- **Desempenho e capturas:** se o jogo abre em paisagem e passa da tela de título nos aparelhos testados.
- **Acessibilidade:** avisos de contraste/tamanho de toque em jogos Godot costumam ser falsos positivos
  (a interface é desenhada pelo motor); leia, mas não bloqueiam.
- **Segurança e privacidade:** avisos sobre bibliotecas desatualizadas; atualize se aparecer algo crítico.
O jogo não precisa de credenciais de login para o robô.

## 10. Teste fechado com 12 testadores: estratégia

- **Recrute pelo menos 15–20 pessoas** para ter folga: quem sair antes dos 14 dias não conta, e se sair
  e voltar o prazo recomeça para ela.
- **Grupo do Google:** crie em <https://groups.google.com> um grupo (ex.: `hyakki-testers`), tipo
  "Lista de e-mails", com "Quem pode participar: qualquer pessoa pode pedir" ou "por convite". Na
  faixa de teste fechado, adicione o e-mail do grupo em **Testadores › Grupos do Google**. Cada pessoa
  entra no grupo com a conta Google que usa na Play Store.
- **Link de inscrição:** depois de aprovado o teste fechado, copie o link em **Testadores › Como os
  testadores entram no teste** e envie junto com estas instruções:
  1. entre no grupo com a mesma conta da Play Store;
  2. abra o link, toque em **Tornar-se testador**;
  3. instale pela Play Store e **não saia do teste** por 14 dias;
  4. jogue algumas partidas em dias diferentes e mande comentários (o "feedback privado" da Play Store
     chega na Play Console);
  5. não clique em anúncios só para ajudar (o AdMob trata isso como tráfego inválido) e não compre a
     remoção do anúncio se não quiser pagar.
- Onde achar testadores: amigos e família com Android, grupos de jogos/Godot, comunidades de troca de
  testes (por exemplo o subreddit r/AndroidClosedTesting). Retribua testando os apps deles.
- Durante os 14 dias, **publique pelo menos uma atualização** com correções vindas do feedback: isso
  dá boas respostas para o formulário de produção.
- Acompanhe o número de inscritos no **Painel** e em **Teste fechado › Testadores**.

## 11. Depois de publicar

- Responda às avaliações em **Avaliações** (educado, curto, sem prometer data).
- Acompanhe **Android vitals** (falhas e ANR abaixo dos limites ruins da Play).
- Acompanhe no AdMob a **taxa de preenchimento**, o status do `app-ads.txt` e eventuais avisos de
  política; na Play Console, **Monetizar › Visão geral** mostra as compras.
- Mantenha o targetSdk em dia: hoje a Play exige **API 36** para apps novos e atualizações (desde
  31/08/2026); o requisito sobe uma vez por ano, por volta de agosto.
- Se trocar de conta AdMob um dia, atualize os três IDs (`project.godot` e `RELEASE_UNITS`) e o
  `app-ads.txt` antes de gerar a versão.

## 12. Checklist do primeiro lançamento

- [ ] Conta pessoal criada, taxa de US$ 25 paga, identidade verificada
- [ ] Aparelho Android verificado pelo app Play Console
- [ ] Backup da chave de envio e do `.env` em dois lugares fora do PC
- [ ] Política atualizada e enviada em `netstart/netstart.github.io` (`hyakki/privacy-policy.md` + `privacy-policy.html`, mesma data); `python -I tools/sync_site.py --check` passa
- [ ] `https://netstart.github.io/privacy-policy.html` e `https://netstart.github.io/app-ads.txt` abrem no celular
- [x] Link para a política de privacidade dentro do jogo (Opções) — conferido
- [ ] App criado: nome, pt-BR, Jogo, Gratuito
- [ ] Política de privacidade: URL nova colada (`https://netstart.github.io/privacy-policy.html`)
- [ ] Anúncios: **Sim, meu app contém anúncios**
- [ ] Acesso ao app: sem restrições
- [ ] Classificação IARC enviada com **compras digitais: Sim** (resultado anotado)
- [ ] Público-alvo: 13–15, 16–17, 18+; "atrai crianças": Não
- [ ] App de notícias: Não · Governamental: Não · Financeiro: nenhum · Saúde: não
- [ ] Segurança dos dados preenchida (4 tipos do SDK de anúncios, criptografado em trânsito)
- [ ] ID de publicidade: Sim (publicidade, análise, prevenção de fraudes)
- [ ] Ficha principal: título, curta, completa (pt-BR) e `check_store_listing.py` OK
- [ ] Ícone 512, recurso gráfico 1024 × 500, 3+ capturas 16:9 de telefone, 4+ de tablet 7" e 10"
- [ ] Categoria Ação, tags, e-mail, site
- [ ] 10 traduções coladas
- [ ] AdMob: pagamentos e W-8BEN preenchidos
- [ ] AdMob: mensagem GDPR publicada (estados dos EUA opcional)
- [ ] AdMob: aparelho cadastrado como dispositivo de teste
- [ ] Play Console: perfil de pagamentos (comerciante) com dados fiscais
- [ ] AAB `1.7.0` gerado com `tools\build_release.ps1` e conferido no aparelho de teste (abre sem
      anúncio, premiados, consentimento, "Privacidade e anúncios", "Restaurar compras")
- [ ] Assinatura de apps do Google Play aceita
- [ ] Teste interno enviado (1º AAB com `BILLING`)
- [ ] Produto `remove_open_ad` ("Apoiar o jogo") criado depois do 1º AAB, ou nome e descrição
      trocados se já existia: único, US$ 2,99, 10 traduções, **ativo**
- [ ] Produto `unlock_speed` (Ampulheta de Fūjin) criado: único, US$ 1,99 com **R$ 4,99 manual no
      Brasil**, 10 traduções, **ativo**; compra, restauração e velocidade 2x/3x testadas
- [ ] Conta em **Teste de licença**; compra e "Restaurar compras" testadas sem cobrança
- [ ] Teste interno instalado e jogado pela Play Store
- [ ] Teste fechado aprovado, link enviado, 12+ inscritos
- [ ] 14 dias seguidos com 12+ inscritos; pelo menos uma atualização com feedback
- [ ] Relatório de pré-lançamento sem falhas
- [ ] Acesso à produção solicitado e aprovado
- [ ] Produção: países todos, notas da versão, lançamento em etapas 20% → 50% → 100%
- [ ] App vinculado à ficha da Play no AdMob (depois de público)
- [ ] `app-ads.txt` verificado no AdMob
- [ ] Pacote registrado na verificação de desenvolvedor Android

---

## Fontes

Consultadas em 25/10/2026:

- Requisitos de teste para contas pessoais novas (12 testadores, 14 dias, solicitar produção):
  <https://support.google.com/googleplay/android-developer/answer/14151465>
- Criar e configurar a conta (US$ 25, identidade, verificação de aparelho):
  <https://support.google.com/googleplay/android-developer/answer/6112435>
- Verificação de desenvolvedor Android (30/09/2026, registro automático dos apps da Play):
  <https://android-developers.googleblog.com/2026/03/android-developer-verification-rolling-out-to-all-developers.html>
  e <https://support.google.com/googleplay/android-developer/answer/16984799>
- Política de Dados do Usuário (política no Console **e** dentro do app, conteúdo mínimo, sem PDF):
  <https://support.google.com/googleplay/android-developer/answer/10144311>
- Seção Segurança dos dados (definição de coleta, SDKs de terceiros, dados só no aparelho):
  <https://support.google.com/googleplay/android-developer/answer/10787469>
- Divulgação de dados do SDK de anúncios (Next-Gen, usado pelo plugin Poing 1.4.0):
  <https://developers.google.com/admob/android/next-gen/privacy/play-data-disclosure>
  (SDK legado: <https://developers.google.com/admob/android/privacy/play-data-disclosure>)
- ID de publicidade e permissão `AD_ID`:
  <https://support.google.com/googleplay/android-developer/answer/6048248>
- Declaração de anúncios: <https://support.google.com/googleplay/android-developer/answer/9859455>
- Classificação de conteúdo: <https://support.google.com/googleplay/android-developer/answer/9898843>
- Público-alvo e Política para Famílias:
  <https://support.google.com/googleplay/android-developer/answer/9867159>
- Recursos gráficos, capturas e textos da ficha:
  <https://support.google.com/googleplay/android-developer/answer/9866151>
- Nível de API exigido (API 36 desde 31/08/2026):
  <https://support.google.com/googleplay/android-developer/answer/11926878>
- app-ads.txt (raiz do domínio, um nível de subdomínio):
  <https://support.google.com/admob/answer/9363762>
- Produtos no app e teste de compras com contas de teste de licença (Play Billing):
  <https://developer.android.com/google/play/billing/test>
