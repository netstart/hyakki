# HYAKKI — Até o Amanhecer
### Plano completo de game design e implementação (survivors-like, Android paisagem, só assets gratuitos)

| Campo | Valor |
|---|---|
| Gênero | Survivors-like / bullet heaven / roguelite de sessão curta |
| Engine | Godot 4.6.x (GDScript), renderer **Compatibility** (GLES3) no início |
| Plataforma | Android, **somente paisagem** (sensor_landscape) |
| Dispositivo de teste | Redmi Note 14 Pro+ 5G — Snapdragon 7s Gen 3 / Adreno 710, AMOLED 6,67" 2712×1220, 120 Hz |
| Arte base | **Ninja Adventure Asset Pack** (pixel-boy) — CC0, 16×16 |
| Política de assets | 100% gratuitos e com uso comercial permitido; preferência absoluta por CC0 |
| Data do plano | 20/10/2026 |

---

## Sumário

0. Resumo executivo
1. Pesquisa: Vampire Survivors e concorrentes
2. Conceito do jogo
3. Narrativa e mundo
4. Game design (sistemas)
5. Level design
6. Bestiário e chefes
7. UI/UX (paisagem, mobile)
8. Direção de arte, technical art e integração de pixel art
9. Áudio (música e SFX)
10. Arquitetura técnica (Godot 4.6)
11. Android e o Redmi Note 14 Pro+
12. Catálogo de assets e licenças
13. Roadmap de implementação (fases, tarefas, critérios de pronto)
14. Plano de testes (QA, performance, balanceamento)
15. Critérios de qualidade (código, jogabilidade, balanceamento, dificuldade, progressão, diversão, som)
16. Riscos e mitigação
17. Monetização (gratuito com anúncios)
18. Apêndices (fórmulas, tabelas, templates)

---

## 0. Resumo executivo

**Hyakki — Até o Amanhecer** é um survivors-like de sessões de 15 minutos ambientado num Japão feudal folclórico. Uma vez a cada cem anos, o **Hyakki Yagyō** — a Parada Noturna dos Cem Demônios — atravessa o vale de Kagerō. O jogador controla um dos últimos **Guardiões da Lanterna** e precisa manter a **Lanterna do Amanhecer** acesa até o sol nascer.

Por que esse tema:

- O **Ninja Adventure Asset Pack** (CC0) cobre, num só estilo coerente, personagens (50+), monstros (30+), chefes (9+), tilesets, itens (60+), VFX (30+), ícones de magia (50+), UI, **37 músicas**, **100+ SFX** e 2 fontes. É o único pacote gratuito encontrado que entrega "absolutamente tudo" com estética unificada e licença de domínio público — isso elimina o maior risco de jogos feitos com assets gratuitos: a colcha de retalhos visual.
- O folclore yōkai é rico, de domínio público e pouco explorado no gênero (Vampire Survivors usa horror gótico; Halls of Torment, fantasia sombria; Brotato, sci-fi cômico).

Diferenciais em relação ao Vampire Survivors (detalhados na seção 2):

1. **A Lanterna** — mecânica de luz: brasas de alma (XP) alimentam o raio de luz; fora dele, os yōkai *Sombra* ficam meio invisíveis e mais fortes.
2. **Pactos com Kami** — santuários aparecem aos 5 e 10 minutos com 3 bênçãos que vêm com um custo (risco/recompensa explícito).
3. **Golpe da Lanterna** — um único botão de ultimate, carregado por brasas, para o polegar direito (que no VS fica ocioso).
4. Sessões de **15 min** (VS usa 30) pensadas para mobile, com modo Noite Sem Fim após o amanhecer.

Escopo da versão 1.0: 6 heróis, 5 fases, 12 armas + 12 evoluções + 2 uniões, 12 passivos, ~35 tipos de inimigo, 10 chefes, meta-progressão (Santuário), 40 conquistas, **11 idiomas** (pt-BR, en, es, de, fr, ru, id, ja, ko, zh-TW, zh-CN; ver 7.7).

Modelo de negócio: **gratuito com anúncios**. Há um anúncio de abertura para liberar o jogo e uma Loja onde anúncios recompensados liberam recompensas a cada 6 h. Também há anúncios opcionais para reviver 1× por partida e dobrar o ryō, e uma compra única para remover o anúncio de abertura. Nenhum anúncio interrompe uma partida em andamento (seção 17).

Estimativa para 1 desenvolvedor em tempo parcial: **~22–26 semanas** até a 1.0 na Play Store; **protótipo jogável no Redmi na semana 3**.

### Estado da implementação (21/10/2026)

O conteúdo da 1.0 está implementado e validado no PC e no emulador Android (`Redmi_Note_14_Pro_Plus_5G`, AVD sem Play Store). Detalhes, números e checklist em [03-progresso-implementacao.md](03-progresso-implementacao.md).

- **Feito:** 6 heróis, 6 fases (5 + secreta), 26 armas (12 + 12 evoluções + 2 uniões), 12 passivos, ~37 yōkai + props, 12 chefes (Kuroe com 3 fases, Shinigami, Izanami), 15 Kami, 6 Golpes da Lanterna, Santuário (18 power-ups com reembolso), 40 conquistas, Diário, história completa (intro, falas, amanhecer, finais), Noite Sem Fim, Desafio Diário, Brisa/Normal/Lua Vermelha I–V, velocidade 1x/2x/3x determinística, 11 idiomas (629 textos), Loja de 6 h, anúncio de abertura, reviver e dobrar ryō, compra para remover o anúncio, telas de Licenças e Créditos, registro de licenças verificado (12.6).
- **Simulado:** anúncios e compra usam provedores de teste (`AdsManager`/`PurchaseManager`), porque o plugin AdMob e o Play Billing exigem contas e o emulador não tem Play Store.
- **Depende de contas externas (fora do alcance aqui):** Play Console, AdMob real + UMP, teste fechado, ID do pacote definitivo (hoje `dev.hyakki.prototype`), keystore de release, hospedar a política de privacidade e o `app-ads.txt`.
- **Precisa de pessoas:** revisão das traduções por nativos (7.7.3), playtests humanos de balanceamento e de diversão (15.3–15.5) e teste no Redmi físico.

---

## 1. Pesquisa: Vampire Survivors e concorrentes

### 1.1 Vampire Survivors (Poncle) — dados da Play Store (consultados em 20/10/2026)

- Gratuito para baixar, com anúncios opcionais e compras (DLCs, incluindo Ode to Castlevania).
- Nota 4,4 com ~81 mil avaliações; **5 mi+ downloads**; jogável **offline**; single-player e **co-op local até 4**, em paisagem.
- Última atualização: 02/09/2026. Reclamações recorrentes nas avaliações: bugs no fluxo de ressurreição e DLC que não aparece — lição: o fluxo de *revive* e o de *compras* precisam de teste dedicado.
- A Play Store lista como semelhantes: Deep Rock Galactic: Survivor, 20 Minutes Till Dawn, Halls of Torment, Survivor.io.

### 1.2 Anatomia do Vampire Survivors

**Loop de partida (30 min):**
mover → armas disparam sozinhas → inimigos morrem e soltam gemas → gemas enchem a barra → level-up pausa o jogo e oferece 3–4 escolhas → build cresce → hordas e chefes crescem → aos 30:00 surge o Ceifador (fim da partida).

**Loop de meta (entre partidas):**
ouro → Power-Ups permanentes → desbloqueio de personagens, armas, fases, arcanas → nova partida "um pouco mais forte".

**Regras de evolução (wiki da comunidade):**
- Arma no nível máximo **+** o item passivo correspondente → abrir um **baú** (normalmente de chefe/elite, geralmente a partir dos 10 min) evolui a arma. Ex.: Whip + Hollow Heart = Bloody Tear; Magic Wand + Empty Tome = Holy Wand; Knife + Bracer = Thousand Edge.
- **Uniões**: duas armas base viram uma só e liberam um slot (ex.: Peachone + Ebony Wings = Vandalier).
- 6 slots de arma, 6 de passivo.

**Por que funciona (análise de design):**
- **Controle de um polegar**: só movimento; o jogador decide *posicionamento* e *build*, nunca mira.
- **Recompensa variável e constante** — o próprio Luca Galante trouxe referências de design de caça-níqueis (baús com "roleta", luzes, moedas, sons de cassino). O efeito de "quase consegui" (morrer aos 27 min) motiva a próxima partida.
- **Nenhuma partida é desperdiçada**: sempre volta ouro para a meta-progressão.
- **Escalada de poder perceptível**: começa frágil e termina apagando a tela inteira; a fantasia de poder é o produto.
- **Descoberta**: evoluções e segredos escondidos criam conversa da comunidade.
- **Fluxo**: picos de tensão (cercos, chefes) alternados com momentos de domínio.
- Arte simples e barata; o "juice" (números, flashes, sons) compensa.

### 1.3 Concorrentes e o que aprender

| Jogo | Plataforma | Ideia-chave | O que levamos | O que evitamos |
|---|---|---|---|---|
| **Survivor.io** | iOS/Android, F2P | Nasceu para toque; partidas curtas; EVO combina 2 itens | Sessões curtas, joystick flutuante, UI grande | Monetização agressiva, energia/stamina |
| **20 Minutes Till Dawn** | PC/iOS/Android | Tiro manual, 20 min fixos, escuridão | Duração fixa, **escuridão/visão** como tensão | Mira manual (ruim em toque) |
| **Brotato** | PC/mobile/Switch | Ondas curtas + loja entre ondas | Pausas estratégicas curtas (nossos santuários) | Ondas fragmentam o fluxo contínuo |
| **Halls of Torment** | PC | Visual Diablo II, árvore de talentos, chefes estruturados | Chefes com padrões legíveis | Tons escuros demais para tela de celular sob sol |
| **Deep Rock Galactic: Survivor** | PC | Terreno destrutível, objetivos secundários | Objetivos opcionais na fase (lanternas, santuários) | Complexidade de terreno (custo de dev) |
| **Death Must Die** | PC | Bênçãos de deuses estilo Hades | **Pactos com Kami** | — |
| **Soulstone Survivors** | PC | Maldições aumentam dificuldade e recompensa | Níveis de **Lua Vermelha** (dificuldade opcional) | — |
| **Yet Another Zombie Survivors / Boneraiser Minions** | PC | Esquadrão / exército de lacaios | Ideia futura (DLC/atualização) | Fora do escopo 1.0 |
| **Spirit Hunters: Infinite Horde** | PC | Milhares de inimigos | Meta técnica: **500 inimigos a 60 fps** | Escala absurda em mobile |

### 1.4 Pilares derivados da pesquisa

1. **Um polegar joga, o outro decide quando** — movimento sempre; ultimate opcional.
2. **Cada minuto muda algo** — tabela de ondas com evento novo a cada 60 s.
3. **Poder visível** — toda melhoria precisa ser vista e ouvida.
4. **Nenhuma partida é perdida** — ouro, conquistas e lore sempre avançam.
5. **Legível sob o sol** — contraste alto, inimigos perigosos com silhueta e cor distintas.

---

## 2. Conceito do jogo

**Título de trabalho:** HYAKKI — Até o Amanhecer (en: *Hyakki — Until Dawn*). Alternativas: "Lanterna de Kagerō", "Cem Demônios".

**Pitch (1 frase):** Sobreviva à Parada Noturna dos Cem Demônios mantendo sua lanterna acesa até o sol nascer.

**Fantasia do jogador:** começar como um guardião assustado com uma katana e terminar como uma tempestade de papel sagrado, trovões e fogo que transforma a noite em dia.

**Público:** jogadores mobile 16+ de roguelites casuais/midcore; fãs de VS, Survivor.io, pixel art e folclore japonês. Classificação pretendida: 12+ (violência fantasiosa, sem sangue realista).

**Sessão:** 15 min por fase (vitória ao amanhecer) + modo **Noite Sem Fim** opcional após a vitória (até o Shinigami aparecer aos 20:00).

### 2.1 Mecânicas-assinatura

| Mecânica | Descrição | Por quê |
|---|---|---|
| **Lanterna do Amanhecer** | Raio de luz ao redor do herói (começa 120 px). Brasas coletadas aumentam o raio temporariamente (+ até 60%), decaindo devagar. Fora da luz: inimigos *Sombra* ficam translúcidos (40%) e com +20% de velocidade. Chefes "comem" a luz durante a luta. | Tensão espacial nova no gênero, incentiva coletar XP agressivamente, usa o tema. Inspirada na escuridão de 20MTD, mas sem mira manual. |
| **Pactos com Kami** | Aos 5:00 e 10:00 surge um santuário a ~600 px. Ao tocá-lo, o jogo pausa e oferece 3 bênçãos com contrapartida (ex.: "Inari: +30% ouro, −10% HP máx."). Ignorar é permitido. | Decisão estratégica rara e marcante; dá identidade a cada partida. |
| **Golpe da Lanterna** (ultimate) | Botão no canto inferior direito. Carrega com brasas (100 = cheio). Efeito depende do herói (ex.: Aki: onda de luz que atordoa 2 s e dá 300% dano). | Dá ao polegar direito um papel de *timing* sem exigir mira. |
| **Selos de Evolução** | Evoluções exigem arma máx. + passivo + abrir um **Baú Laqueado** de elite/chefe (igual ao VS — comprovado). | Mantém o "momento cassino". |
| **Lua Vermelha (dificuldade)** | Após vencer uma fase, desbloqueia Lua I–V: +HP/velocidade dos inimigos, +ouro/XP. | Rejogabilidade para veteranos. |

### 2.2 Escopo 1.0

| Conteúdo | Quantidade |
|---|---|
| Heróis jogáveis | 6 |
| Fases | 5 (+ fase secreta pós-jogo opcional) |
| Armas base | 12 |
| Evoluções | 12 + 2 uniões |
| Passivos | 12 |
| Pactos de Kami | 15 |
| Tipos de inimigo | ~35 (incluindo variantes de cor) |
| Chefes | 10 (2 por fase) + Shinigami |
| Power-ups permanentes | 14 |
| Conquistas | 40 |
| Idiomas | 11: pt-BR, en, es, de, fr, ru, id, ja, ko, zh-TW, zh-CN (7.7) |

---

## 3. Narrativa e mundo

### 3.1 Premissa

O vale de **Kagerō** fica sobre uma fenda entre o mundo dos vivos e o **Yomi**, o mundo dos mortos. A cada cem anos, na lua mais escura do outono, a fenda se abre e os yōkai marcham em procissão — o **Hyakki Yagyō**. Quem é tocado pela procissão perde a alma e vira mais um demônio na fila.

A única defesa é a **Lanterna do Amanhecer**, cuja chama foi acesa pela deusa do sol **Amaterasu** e confiada a uma ordem de guardiões. Na última procissão, a ordem foi traída: o guardião-chefe **Kuroe** apagou sua lanterna e entrou na parada, tornando-se o **Senhor da Procissão**. Cem anos depois, restam poucos guardiões — e a noite está chegando.

### 3.2 Estrutura narrativa (mínima, não intrusiva)

- **Intro** (5 painéis estáticos com texto, pulável) na primeira abertura.
- **Cada fase** abre com 1 frase do narrador (o velho ferreiro Tora) e termina com 1 painel de amanhecer.
- **Diário do Guardião** (códex): cada inimigo derrotado 100× e cada chefe vencido desbloqueia uma entrada de lore (2–3 linhas). Isso é *narrativa ambiental* sem cortar o ritmo.
- **Final** após a fase 5: revelação de que Kuroe apagou a lanterna para proteger a filha (Aki) da procissão; ele pede para ser "levado ao amanhecer". Final de pós-jogo desbloqueia a fase secreta.

### 3.3 Fases e arco

| # | Fase | Ambiente | Tema narrativo | Chefe 5:00 / 10:00 | Final 15:00 |
|---|---|---|---|---|---|
| 1 | **Vila de Kagerō** | arrozais, casas, ponte | A procissão chega à vila | Tanuki Gigante / Kappa Ancião | Amanhecer |
| 2 | **Bosque de Bambu Sussurrante** | bambuzal, trilhas | Espíritos das árvores despertam | Bambu Ancestral / Kitsune de Nove Caudas | Amanhecer |
| 3 | **Templo Tomado** | ruínas cobertas por vegetação (tileset "abandoned") | O templo da ordem caiu | Tengu Corvo / Monge Sem Rosto | Amanhecer |
| 4 | **Dunas de Cinza** | deserto vulcânico | Rastro de destruição do Senhor da Procissão | Ciclope de Pedra / Dragão de Cinza | Amanhecer |
| 5 | **Portão do Yomi** | caverna/dungeon | Confronto com Kuroe | Oni Vermelho / **Kuroe, Senhor da Procissão** | Amanhecer final |

> Os nomes acima são de design. Na fase 0 do roadmap, cada chefe é mapeado para um sprite real do pack (ver 12.4). Se faltar um chefe visual, usar variante de cor + escala ×2 de um monstro (técnica comum e barata).

### 3.4 Heróis

| Herói | Arquétipo | Arma inicial | Bônus | Ultimate (Golpe da Lanterna) | Desbloqueio |
|---|---|---|---|---|---|
| **Aki** | Guardiã aprendiz (protagonista) | Katana Crescente | +10% área | Clarão: atordoa a tela 2 s, 300% dano | Inicial |
| **Kenta** | Ninja | Kunai | +10% velocidade de movimento | Sombra Dupla: clone por 8 s | Sobreviver 10 min |
| **Hana** | Miko (sacerdotisa) | Ofuda Orbitante | +1 regeneração | Kagura: cura 50% e repele | Vencer a fase 1 |
| **Goro** | Monge guerreiro | Incenso Sagrado | +20% HP máx., −10% velocidade | Sino do Templo: onda de knockback | Matar 5.000 inimigos |
| **Rin** | Caçadora | Arco Yumi | +1 projétil a cada 10 níveis | Chuva de Flechas: 6 s | Evoluir 3 armas diferentes |
| **Tora** | Ferreiro idoso, narrador | Kusarigama | +15% dano, −1 projétil | Forja Viva: todas as armas +50% por 10 s | Vencer a fase 3 |

Cada herói usa um personagem distinto do Ninja Adventure (o pack tem 50+), com recolor quando necessário.

### 3.5 Tom e escrita

- Frases curtas, poéticas, sem humor escrachado (contraste com o "absurdo" do VS; mais próximo de um conto popular).
- Inimigos não falam; chefes têm 1 frase de entrada (balão de 2 s, sem pausar).
- Glossário fixo: *brasa* (XP), *ryō* (ouro), *selo* (evolução), *Kami* (pacto), *Lua Vermelha* (dificuldade).

**Texto de intro (rascunho):**
> "Cem anos se passaram. A lua escureceu. No vale de Kagerō, a última lanterna ainda queima.
> Os mortos marcham ao som de tambores que ninguém toca.
> Se a chama se apagar antes do amanhecer, o vale será deles para sempre.
> Levante a lanterna, guardiã. A noite é longa."

### 3.6 Enredo completo

#### 3.6.1 O que aconteceu há cem anos (história de fundo)

- A **Ordem da Lanterna** guardava o vale de Kagerō. Cada guardião carregava uma lanterna acesa com a chama de Amaterasu. Os yōkai da procissão não conseguem tocar quem está dentro da luz.
- Na última procissão, **Aki**, filha de seis anos do guardião-chefe **Kuroe**, saiu da luz atrás de um vaga-lume e foi **tocada** pela procissão. Quem é tocado fica com uma *marca* e, ao amanhecer, vira yōkai.
- Só existe uma forma de salvar quem foi marcado: **outra alma toma o seu lugar na fila**, por vontade própria. Ninguém com a lanterna acesa pode entrar na procissão. Por isso Kuroe **apagou a sua** e entrou no lugar da filha.
- A procissão ganhou o mais forte dos guardiões e ficou mais forte do que nunca. Naquela noite, a Ordem caiu. Os sobreviventes viram apenas que o chefe tinha apagado a lanterna e entrado na fila, e chamaram aquilo de **traição**. Ninguém sabia da marca.
- A marca de Aki só ia desaparecer quando a procissão voltasse. Para isso, a miko da Ordem a pôs em **sono selado** dentro da forja do templo, onde o tempo não passa. A família de ferreiros de **Tora** guardou o selo por três gerações, junto com a **Lanterna do Amanhecer**: a última chama da Ordem, guardada sob as cinzas da forja.
- Dentro do Yomi, a alma de Kuroe foi corroída por cem anos de marcha até ele se tornar o **Senhor da Procissão**. Hoje ele lidera a parada, mas ainda guarda um único desejo humano: rever a filha.

#### 3.6.2 Ponto de partida

Tora, já velho, sente a terra tremer com os tambores e quebra o selo. Aki acorda sem memória, tendo apenas o próprio nome e uma sensação de frio na nuca (a marca, já quase apagada). Tora entrega a lanterna a ela, sem contar o resto: *"Você é a última guardiã. Mantenha a chama viva até o amanhecer, e eu conto tudo."*

**Gancho central:** quem é Aki, por que dormiu cem anos e por que o Senhor da Procissão parece estar procurando por ela.

#### 3.6.3 Arco por fase

| # | Fase | O que acontece | Fala de abertura (Tora) | Revelação no amanhecer (painel final) |
|---|---|---|---|---|
| 1 | Vila de Kagerō | A procissão invade a vila onde Aki nasceu. Os aldeões já viraram yōkai. | "Os tambores chegaram antes da lua. Não olhe para os rostos, só para a chama." | Aki encontra um brinquedo de madeira numa casa em ruínas e o reconhece sem saber por quê. |
| 2 | Bosque de Bambu Sussurrante | Os espíritos do bambu repetem vozes antigas. A Kitsune de Nove Caudas imita a voz de um homem chamando "Aki". | "O bambu guarda tudo o que ouviu. Não acredite em tudo o que ele repete." | A kitsune, vencida, diz: "Ele também ouviu essa voz. Por cem anos." Aki descobre que alguém da procissão a conhece. |
| 3 | Templo Tomado | A sede da Ordem. Nas paredes, a história oficial: "Kuroe, o Traidor". O Monge Sem Rosto é o último monge da Ordem, que se recusou a fugir. | "Aqui fizemos os juramentos. Aqui os quebramos." | Aki acha o registro da miko sobre a menina marcada e o sono selado. Agora ela sabe que é **ela** a menina. Tora confessa que sabia. |
| 4 | Dunas de Cinza | O rastro que Kuroe deixou ao sair do Yomi para buscá-la: tudo o que ele tocou virou cinza. | "Cinza também é fogo que lembra. Ande com cuidado." | Entre as cinzas, a lanterna apagada de Kuroe, com o nome dela gravado no cabo. Aki entende que o Senhor da Procissão é **seu pai**. |
| 5 | Portão do Yomi | Confronto com Kuroe. Ele quer levá-la para o Yomi ("lá ninguém mais vai te tocar"). | Tora não fala. O painel mostra só a lanterna tremendo. | Veja o final, em 3.6.5. |

#### 3.6.4 Heróis e motivações

| Herói | Por que está na noite | Arco pessoal (desbloqueado no Diário ao vencer com ele) |
|---|---|---|
| **Aki** | Foi acordada para carregar a última chama. | Deixa de ser "a menina salva" e passa a ser quem salva. |
| **Kenta** | Ninja de um clã vizinho, contratado para *roubar* a lanterna. | Desiste do contrato ao ver a vila do próprio clã na procissão. |
| **Hana** | Neta da miko que selou Aki. Herdou o dever de vigiar o selo. | Quer descobrir se a avó agiu certo ao esconder a verdade. |
| **Goro** | Monge que fugiu do templo na noite da queda, cem anos atrás. Vive por causa de um voto e não envelhece. | Quer se redimir diante do Monge Sem Rosto, seu antigo mestre. |
| **Rin** | Caçadora cujo irmão foi tocado na procissão desta noite. | Corre contra o tempo: ele ainda pode ser salvo se ela vencer antes do amanhecer. |
| **Tora** | Guardião do selo, narrador. | Carrega a culpa de ter mentido para Aki. Pega em armas pela primeira vez aos 70 anos. |

#### 3.6.5 Final

1. **Fase 1 da luta:** Kuroe luta como guardião, com a espada sombria e a técnica da Ordem.
2. **Fase 2:** ele convoca a procissão inteira para separar a filha do mundo dos vivos.
3. **Fase 3:** ele apaga a lanterna de Aki. Só o **Golpe da Lanterna** a reacende. Na história, Aki usa a chama não para destruí-lo, mas para mostrar a ele o próprio rosto humano.
4. **Epílogo (5 painéis):** Kuroe reconhece a filha, pede para ser "levado ao amanhecer" e se desfaz em luz quando o sol nasce. Sem líder, a procissão se dispersa. Aki acende de novo as lanternas do templo, e a Ordem renasce com os seis heróis.
5. **Gancho pós-jogo:** os tambores continuam tocando, mais baixo. Kuroe liderava a procissão, mas não era quem tocava os tambores.

#### 3.6.6 Fase secreta (pós-jogo, opcional): *Yomotsu Hirasaka — a Encosta dos Mortos*

- A fronteira entre os vivos e o Yomi. Chefe final: **Izanami**, a deusa que governa o Yomi. A procissão é o lamento dela: a cada cem anos ela tenta trazer o mundo dos vivos para perto de si.
- Vitória: Aki não a mata. Ela fecha a fenda deixando ali a Lanterna do Amanhecer como selo permanente. Créditos verdadeiros.
- Desbloqueia o modo **Noite Sem Fim** com lore própria: quem continua na noite depois do amanhecer desafia a ordem natural, e o **Shinigami** vem cobrar.

#### 3.6.7 Falas de entrada dos chefes (balão de 2 s)

| Chefe | Fala |
|---|---|
| Tanuki Gigante | "Essa vila é minha agora. Quer apostar?" |
| Kappa Ancião | "A água do arrozal lembra de você, menina." |
| Bambu Ancestral | "Cem anos de raízes. Você cabe nelas." |
| Kitsune de Nove Caudas | "Aki... Aki... Reconhece essa voz?" |
| Tengu Corvo | "Guardiões caem. Eu vi todos caírem." |
| Monge Sem Rosto | "Eu fiquei. Onde você estava?" |
| Ciclope de Pedra | "Ele passou por aqui. Só sobrou eu." |
| Dragão de Cinza | "Sou o que restou do fogo dele." |
| Oni Vermelho | "O Senhor espera. Eu não." |
| Kuroe | "Finalmente. Vem, ninguém mais vai te tocar." |
| Izanami | "Toda luz um dia desce até mim." |

#### 3.6.8 Diário do Guardião: exemplos de entradas

- **Slime-de-Arroz:** "Arroz oferecido aos mortos e esquecido no altar. Ainda tem fome de ser lembrado."
- **Fantasma Sombra:** "Viajantes que saíram da luz para ver a procissão de perto. Ainda estão olhando."
- **Monge Sem Rosto:** "Ele deu o rosto para segurar a porta do templo. A porta caiu mesmo assim."
- **Kuroe:** "Apagou a própria luz para que outra continuasse acesa. A Ordem chamou isso de traição."

#### 3.6.9 Regras de entrega (lembrando 3.2)

- Nenhuma cena interrompe o combate. A história fica na intro, nas falas de abertura, nos painéis de amanhecer, nos balões dos chefes e no Diário.
- A revelação central (Kuroe é o pai) é **construída aos poucos** nas fases 2→4, para que o jogador possa suspeitar antes da fase 5.
- Todos os textos ficam em `i18n/strings.csv` (chaves `story_*`, `boss_line_*`, `codex_*`), nos 11 idiomas de 7.7.

---

## 4. Game design (sistemas)

### 4.1 Controles

- **Movimento:** joystick virtual **flutuante** — nasce onde o polegar esquerdo toca, em qualquer ponto da metade esquerda da tela; raio 64 px de tela lógica; zona morta 12%.
- **Ultimate:** botão circular de 96 dp no canto inferior direito, com anel de carga.
- **Pausa:** botão no canto superior direito; também pausa automaticamente ao perder foco (`NOTIFICATION_APPLICATION_FOCUS_OUT`).
- **Gamepad Bluetooth** suportado (stick esquerdo + botão A/Sul para ultimate) — barato de implementar via InputMap.
- Opção: "joystick fixo" e "lado do joystick" (canhotos).

### 4.2 Atributos (Stats)

| Stat | Base | Notas |
|---|---|---|
| HP máx. | 100 | |
| Regeneração | 0 HP/s | |
| Armadura | 0 | reduz dano recebido por golpe (mín. 1) |
| Velocidade | 100% (60 px/s) | |
| Poder (Might) | 100% | multiplica dano |
| Área | 100% | |
| Velocidade de projétil | 100% | |
| Duração | 100% | |
| Quantidade | +0 | projéteis extras |
| Recarga | 100% | menor = melhor; mínimo 10% |
| Sorte | 100% | chance de 4ª escolha, drops |
| Crescimento | 100% | ganho de XP |
| Ganância | 100% | ganho de ouro |
| Ímã | 40 px | raio de coleta |
| Maldição | 100% | velocidade/HP/quantidade dos inimigos |
| Revive | 0 | |
| Luz | 120 px | raio da lanterna (exclusivo) |

Todos os stats ficam num `StatBlock` (Resource) com modificadores aditivos e multiplicativos; ver 10.5.

### 4.3 Experiência e nível

- Brasas (gemas) com valores 1 (azul), 5 (verde), 25 (vermelha), 100 (dourada).
- Fórmula de XP necessária para subir do nível *L*:
  - L 1–19: `5 + 10·(L−1)`
  - L 20–39: `+13 por nível`; no nível 20 a barra exige +600 extra (como VS: "muro" que segura o ritmo)
  - L 40+: `+16 por nível`; no 40, +2400 extra
- **Fusão de brasas:** acima de 300 brasas no chão, novas brasas se fundem na gema existente mais próxima (vira vermelha "acumulada") — essencial para performance.
- Meta de ritmo: nível 10 aos ~3 min, 25 aos ~10 min, 35–45 aos 15 min.

### 4.4 Level-up

- Pausa o jogo, escurece o fundo, mostra 3 cartas (4 com sorte: chance = `(sorte−100%)/2`, máx. 40%).
- Pool: armas/passivos possuídos que não estão no máximo + novos itens se houver slot (6 armas, 6 passivos).
- Pesos: item possuído ×1,5; item novo ×1,0; item com evolução "pronta" ×1,2.
- **Rerolar / Pular / Banir** (VS tem os três, desbloqueáveis): 0 de cada no início; comprados no Santuário.
- Se nada sobrar: "Bolinho de arroz" (cura 30) ou "Saquinho de ryō" (+25 ouro).
- Cada carta mostra: ícone, nome, nível atual → próximo, descrição da mudança em 1 linha, selo "NOVO" ou "EVOLUÇÃO PRONTA".

### 4.5 Armas base (12)

Valores no nível 1; cada arma tem 8 níveis com melhorias definidas em `WeaponData.levels`.

| # | Arma | Comportamento | Dano | Recarga | Notas | Análogo |
|---|---|---|---|---|---|---|
| 1 | **Katana Crescente** | corte horizontal à frente, alterna lados com Quantidade | 10 | 1,35 s | perfura tudo | Whip |
| 2 | **Shuriken** | dispara no inimigo mais próximo | 8 | 1,1 s | 1 perfuração | Magic Wand |
| 3 | **Kunai** | dispara na direção do movimento, rápida | 6 | 0,9 s | | Knife |
| 4 | **Ofuda Orbitante** | papéis-selo giram em volta do herói | 9 | 3 s ativo / 3 s pausa | | King Bible |
| 5 | **Incenso Sagrado** | aura de dano contínuo + leve empurrão | 4/tick | 0,6 s tick | reduz resistência a knockback | Garlic |
| 6 | **Kusarigama** | arremesso que vai e volta (bumerangue) | 12 | 1,6 s | | Cross |
| 7 | **Bomba de Fumaça** | cai em ponto aleatório, deixa poça de dano | 7/tick | 4 s | | Santa Water |
| 8 | **Raio de Raijin** | relâmpago em inimigos aleatórios | 15 | 4,5 s | | Lightning Ring |
| 9 | **Leque de Fūjin** | cone de vento, knockback forte | 6 | 2 s | | — |
| 10 | **Arco Yumi** | flecha longa que perfura em linha | 14 | 1,8 s | | Runetracer/Arrow |
| 11 | **Tambor Taiko** | onda de choque circular pulsante | 10 | 3,5 s | | — |
| 12 | **Hitodama** | chamas-fantasma teleguiadas | 9 | 2,2 s | buscam o inimigo com mais HP | — |

### 4.6 Passivos (12)

| Passivo | Efeito por nível (5 níveis) | Ícone sugerido (pack) |
|---|---|---|
| Sake de Arroz | +10% Poder | garrafa |
| Pedra de Jade | +10% Área | gema verde |
| Pergaminho Antigo | −8% Recarga | pergaminho |
| Sandálias de Palha | +10% Velocidade | sapato |
| Coração de Carpa | +20% HP máx. | coração/peixe |
| Gi Acolchoado | +1 Armadura | armadura |
| Ampulheta de Areia | +10% Duração | ampulheta |
| Pena de Tengu | +10% Vel. projétil | pena |
| Rosário Duplo | +1 Quantidade (3 níveis) | colar |
| Ímã de Kitsune | +25% Ímã | cauda/ímã |
| Gato da Sorte (Maneki) | +10% Sorte | gato |
| Máscara Noh | +10% Maldição, +10% XP | máscara |

### 4.7 Evoluções e uniões

| Arma (máx.) | + Passivo | = Evolução | Efeito |
|---|---|---|---|
| Katana Crescente | Sake de Arroz | **Lâmina do Amanhecer** | cortes dos dois lados, cura 1 HP a cada 10 acertos |
| Shuriken | Pergaminho Antigo | **Tempestade de Aço** | sem recarga entre disparos |
| Kunai | Pena de Tengu | **Mil Agulhas** | dispara em leque contínuo |
| Ofuda Orbitante | Ampulheta de Areia | **Barreira de Amaterasu** | órbita permanente |
| Incenso Sagrado | Coração de Carpa | **Fumaça do Templo** | aura rouba vida (cura máx. 8 HP/s) |
| Kusarigama | Sandálias de Palha | **Corrente do Ceifador** | 3 correntes, retorno em espiral |
| Bomba de Fumaça | Pedra de Jade | **Névoa Venenosa** | poças crescem e se movem até o herói |
| Raio de Raijin | Rosário Duplo | **Fúria de Raijin** | relâmpagos encadeiam em 3 alvos |
| Arco Yumi | Gato da Sorte | **Flecha de Hachiman** | crítico garantido, explode no fim |
| Tambor Taiko | Gi Acolchoado | **Trovão Ritual** | ondas duplas que atordoam |
| Hitodama | Máscara Noh | **Procissão Invertida** | inimigos mortos viram hitodama aliados |
| Leque de Fūjin | Ímã de Kitsune | **Furacão de Fūjin** | furacão que suga inimigos e brasas |
| **União:** Raio de Raijin evoluído + Leque de Fūjin evoluído | — | **Fūjin-Raijin** | tufão elétrico que vaga pela tela |
| **União:** Katana evoluída + Kusarigama evoluída | — | **Dança das Cem Lâminas** | ciclone de lâminas em volta do herói |

### 4.8 Baús, coletáveis e destrutíveis

- **Baú Laqueado**: dropado por elites e chefes. Conteúdo: 1, 3 ou 5 melhorias (prob. 70/25/5, modificada por Sorte). Prioriza evoluções prontas. Abertura com animação "roleta" de 3–5 s (pulável com toque), moedas voando, música própria — a recompensa *precisa* ser um evento.
- **Lanternas de pedra (destrutíveis)** espalhadas pelo mapa: dropam Bolinho de Arroz (cura 30), Saco de ryō, Ímã Total (puxa todas as brasas), Sino Purificador (mata todos os inimigos comuns da tela), Relógio de Areia (congela inimigos 10 s), Brasa Solar (luz máxima + ultimate cheio).
- **Ryō** (ouro): drop raro de inimigos, frequente de baús e destrutíveis.

### 4.9 Pactos com Kami (15, exemplos)

| Kami | Bênção | Custo |
|---|---|---|
| Inari (raposa) | +30% Ganância | −10% HP máx. |
| Raijin | +2 Quantidade em armas elétricas | +15% Maldição |
| Amaterasu | Luz +50% permanente | −10% Poder |
| Susanoo | +25% Poder | −2 Armadura |
| Tsukuyomi | Recarga −15% | Luz −30% |
| Hachiman | Crítico +10% | Revive removido |
| Ebisu | Baús sempre com 3 itens | Inimigos +10% HP |
| Fūjin | +20% Velocidade | Ímã −30% |
| Benzaiten | +1 escolha no level-up | XP −10% |
| Bishamon | Ultimate carrega 2× mais rápido | Regeneração 0 |

Regras: 3 opções aleatórias sem repetição na partida; cada Kami tem cor e partícula própria no santuário.

### 4.10 Meta-progressão: o Santuário

- Moeda: **ryō**. Power-ups com 1–5 níveis, preço crescente (`base · (1 + 0,1·total_comprados) · nível`, como VS: comprar qualquer upgrade encarece os outros — incentiva escolhas).
- Lista: Poder, Armadura, HP, Regeneração, Recarga, Área, Velocidade, Duração, Quantidade (1 nível), Ímã, Sorte, Crescimento, Ganância, Revive (1 nível), Reroll, Pular, Banir, Luz.
- **Reembolso total gratuito** (o VS faz isso; reduz medo de errar).
- **Desbloqueios por conquista**: armas e passivos novos entram no pool somente após conquistas (ex.: "Sobreviva 5 min com Hana" → libera Hitodama). Isso gera o fluxo constante de novidades que segura as primeiras 10 horas.

### 4.11 Dificuldade e escalonamento

- HP do inimigo: `hp = base_hp · (1 + 0,08·minuto) · maldição · lua_mult`
- Dano do inimigo: `dano = base · (1 + 0,04·minuto) · lua_mult`
- Quantidade alvo na tela: tabela por minuto (5.2), multiplicada por maldição.
- Lua Vermelha I–V: `lua_mult = 1 + 0,25·n` em HP, +5%·n velocidade, +15%·n ouro e XP.
- Modos **Brisa / Normal / Lua Vermelha**, com regras extras por Lua e metas de vitória: ver 15.3.
- **Morte**: tela de resultados com estatísticas por arma (dano total, DPS) — jogadores de survivors-like adoram isso e ajuda o balanceamento.

### 4.12 Conquistas (amostra de 40)

"Primeira Luz" (vença a fase 1), "Cem Demônios" (mate 100 inimigos em 10 s), "Sem Pacto" (vença sem aceitar Kami), "Escuridão Total" (sobreviva 3 min com luz < 60 px), "Ferreiro" (evolua todas as armas), "Ilesa" (passe 5 min sem dano), etc. Cada uma desbloqueia algo concreto.

### 4.13 Modos

- **Campanha** (5 fases em sequência de desbloqueio).
- **Noite Sem Fim** (após vencer, continuar até o Shinigami às 20:00; ouro ×1,5).
- **Desafio Diário** (pós-1.0): semente fixa por data, herói/fase sorteados, ranking local.

### 4.14 Velocidade do jogo (1x, 2x, 3x)

O jogador pode acelerar a partida em **1x (normal), 2x ou 3x**. Assim, uma fase de 15 min pode ser jogada em ~7,5 min (2x) ou ~5 min (3x): bom para sessões curtas no celular, para repetir fases já dominadas e para farmar ryō.

**Regras de jogo**

- A velocidade muda **só o ritmo do tempo real**. As regras são as mesmas: o relógio da fase conta o **tempo de jogo** (o amanhecer continua aos 15:00 do relógio do jogo), e HP, dano, XP, ryō, drops e ondas não mudam. Por isso a velocidade **não dá vantagem nem desvantagem nas recompensas**: só exige reflexo mais rápido.
- **Botão no HUD**, ao lado da pausa (≥ 48 dp), mostrando "1x", "2x" ou "3x". Cada toque passa para a próxima velocidade (1x → 2x → 3x → 1x). Também fica em Opções e no menu de Pausa.
- A escolha é **lembrada** entre partidas (em `Settings`). Padrão: 1x.
- **Liberação:** 2x e 3x ficam disponíveis a partir da **2ª partida** (depois do tutorial da 1ª). Na 1ª partida o botão não aparece, para não confundir quem está aprendendo.
- **Sempre em 1x, independentemente da escolha:** telas de level-up, baú, Kami, pausa, morte e reviver (17.6), resultados, falas dos chefes (balão de 2 s) e entrada do chefe com o nome. Esses momentos são decisões e recompensas e precisam ser lidos com calma.
- **Ultimate (Golpe da Lanterna) e hit-stop** usam o tempo de jogo, então também ficam mais rápidos. O *hit-stop* (8.5) continua com ~40 ms **reais**, para manter a sensação de impacto.
- **Desafio Diário:** velocidade permitida, porque o resultado é o mesmo em qualquer velocidade. O ranking mostra o tempo de jogo, não o tempo real.
- **Conquistas novas:** "Vento de Fūjin" (vencer uma fase em 3x) e "Sem Pressa" (vencer a fase 5 em 1x na Lua Vermelha III ou mais).
- **Não afeta:** esperas de 6 h da Loja (17.3), notificações e qualquer contagem em tempo real fora da partida.

**Sensação e legibilidade**

- **Música:** continua na velocidade e no tom normais (acelerar música soa mal). Em 2x/3x, ela ganha uma camada de percussão ou um filtro leve, que dá a sensação de pressa sem distorcer.
- **Efeitos sonoros:** tocam no tom normal. Como há 2–3× mais eventos por segundo, o limite de polifonia e o *cooldown* por som (9.3) passam a contar em **tempo real**, para o áudio não embolar. A coleta de brasas mantém a escala musical (15.7).
- **Animações e partículas** seguem o tempo de jogo, então ficam mais rápidas e coerentes com o movimento.
- **Números de dano** duram o mesmo tempo **real** (0,6 s), para continuarem legíveis.
- **Avisos de ataque de chefe** (≥ 0,7 s, 15.2) continuam definidos em tempo de jogo: em 3x isso dá ~0,23 s reais. Isso faz parte do desafio da velocidade e fica explicado na primeira vez que o jogador liga o 3x ("Os inimigos também ficam mais rápidos!").
- **Hápticos:** no máximo 1 vibração a cada 80 ms reais, para não virar zumbido contínuo.

**Implementação técnica**

- **Não usar `Engine.time_scale` sozinho.** Ele aumenta o *delta* de cada passo. Com projéteis rápidos e a colisão própria por *spatial hash* (10.6), passos maiores fazem projéteis **atravessarem** inimigos sem acertar (*tunneling*) e mudam o resultado da partida conforme a velocidade.
- Em vez disso, um **`GameClock`** com **passo fixo** de 1/60 s de tempo de jogo: em 2x, roda **2 passos de simulação por frame**; em 3x, **3 passos**. Movimento, colisão, spawner, armas, brasas e IA rodam nesses passos. Renderização, UI e áudio rodam uma vez por frame.
- Resultado: a mesma semente produz **exatamente a mesma partida** em 1x, 2x ou 3x, o que mantém o determinismo de 15.1 e permite que o bot (14.4) e a simulação de balanceamento (15.4) usem a velocidade máxima sem distorcer os dados.
- Todo sistema de jogo lê o tempo do `GameClock` (`game_time`, `step_delta`), nunca de `Time.get_ticks_msec()`. Shaders que usam `TIME` recebem um uniform `game_time`. Tweens de gameplay usam o processo do `GameClock`. Tweens de UI usam tempo real.
- O teste de determinismo de 15.1 passa a comparar o hash do estado no minuto 5 **entre as três velocidades**.

**Performance**

- Em 3x, a simulação custa ~3× mais CPU. Orçamentos de 11.4:
  - **1x:** 500 inimigos a 60 fps (meta atual).
  - **2x:** ≥ 55 fps no pior cenário.
  - **3x:** ≥ 50 fps no pior cenário.
- **Proteção automática:** se a simulação passar do orçamento por 5 s seguidos, o jogo aplica primeiro o "Modo Desempenho" (11.4). Se ainda não bastar, ele **reduz a velocidade** (3x → 2x) e mostra um aviso discreto ("Velocidade reduzida para manter a fluidez"). O jogo nunca deixa a partida travar para manter a velocidade.
- **Telemetria local (14.3):** registrar a velocidade usada em cada partida e quantas vezes a proteção automática foi acionada.

---

## 5. Level design

### 5.1 Estrutura do mapa

- **Mapa infinito por chunks**: chunks de 32×32 tiles (512×512 px) gerados ao redor do jogador numa grade 3×3; os que saem são reciclados. Cada fase tem 6–10 "templates" de chunk feitos à mão no editor (TileMapLayer) e sorteados com semente — mais controle estético que ruído puro.
- **Fase 3 (Templo)**: mapa limitado horizontalmente (corredor de 2.000 px de altura, infinito na horizontal) — variedade de forma, como a Biblioteca do VS.
- **Fase 5 (Portão do Yomi)**: arena fechada de 3.000×3.000 px com pilares (obstáculos) — tensão final.
- Obstáculos sólidos ≤ 8% da área (o gênero pune labirintos); árvores e casas com colisão só na base.
- Destrutíveis: 1 lanterna de pedra a cada ~400 px em média, distribuição Poisson-disk.
- Santuários de Kami: posicionados a 600–800 px do jogador, com seta na borda da tela.

### 5.2 Tabela de ondas (fase 1, modelo)

| Minuto | Alvo na tela | Inimigos comuns | Evento |
|---|---|---|---|
| 0–1 | 15→30 | Slime-de-Arroz | — |
| 1–2 | 40 | + Morcego-Lanterna | enxame em linha (morcegos atravessam a tela) |
| 2–3 | 60 | + Esqueleto-Camponês | elite: Esqueleto Grande (baú) |
| 3–4 | 80 | Slime vermelho | cerco: anel de 40 slimes |
| 4–5 | 100 | + Kappa jovem | — |
| **5:00** | — | — | **Chefe 1 (Tanuki Gigante)** + santuário de Kami |
| 5–7 | 120–150 | + Fantasma Sombra | luz começa a importar |
| 7–9 | 180 | + Aranha Tsuchigumo | enxame de morcegos ×2 |
| 9–10 | 200 | mistura | elite duplo |
| **10:00** | — | — | **Chefe 2 (Kappa Ancião)** + santuário |
| 10–13 | 250–300 | + Oni pequeno, Bakeneko | cerco duplo |
| 13–14:30 | 350 | todos | "Procissão": coluna maciça atravessa o mapa — fuja ou corte |
| 14:30–15:00 | 400 | — | tambores aceleram, céu clareia (shader) |
| **15:00** | — | — | **Amanhecer**: inimigos viram cinza, vitória |

Regras do *spawner*:
- Nasce **logo além da borda visível da tela** (retângulo da tela + 16–40 px), priorizando a direção do movimento do jogador (60%). *(Ajustado no protótipo: um anel pela diagonal deixava quem nasce acima ou abaixo a 250+ px da tela numa tela 20:9, e a horda demorava ~12 s para chegar.)*
- Se `vivos < alvo`, gera até `min(alvo − vivos, 20, orçamento)` por frame de spawn (intervalo de 0,25 s). O **orçamento** cresce `2,5 + 1,5·minuto` inimigos por segundo e acumula no máximo 2 s. *(Ajustado no protótipo: sem orçamento, quem mata rápido abria uma "torneira infinita" de XP, com nível 17 aos 75 s.)*
- Inimigos a mais de 2× a diagonal de distância são **teleportados** para a frente do jogador (padrão do gênero: nunca "perde" a horda).
- Teto absoluto: 500 inimigos vivos (ajustável pelo perfil de performance).

### 5.3 Identidade por fase

| Fase | Paleta | Obstáculo-assinatura | Perigo ambiental | Música |
|---|---|---|---|---|
| Vila | verdes e ocres | casas, cercas | — | tema animado, taiko |
| Bambu | verde-água, sombras azuis | bambuzais densos (bloqueiam visão, não movimento) | nevoeiro reduz luz −20% | flauta, mistério |
| Templo | cinza e musgo | pilares, estátuas | estátuas que disparam lentamente | coral/sinos |
| Dunas | laranja, cinza | rochas | tempestades de cinza periódicas (lentidão 20%) | percussão pesada |
| Yomi | roxo, vermelho | pilares, tochas | chão de lava em faixas | tema final intenso |

---

## 6. Bestiário e chefes

### 6.1 Arquétipos de comportamento (8 scripts reutilizáveis)

| Arquétipo | Comportamento | Uso |
|---|---|---|
| **Perseguidor** | vai reto ao jogador | 70% dos inimigos |
| **Enxame** | atravessa a tela em linha reta, não persegue | morcegos, borboletas |
| **Cerco** | spawna em anel fechando | slimes |
| **Investida** | para, pisca 0,6 s, dispara em linha | javali, bakeneko |
| **Atirador** | mantém distância 180 px, atira projétil lento | monge fantasma, kitsune |
| **Tanque** | lento, muito HP, resiste a knockback | ciclope, oni |
| **Sombra** | só visível dentro da luz; +20% velocidade no escuro | fantasmas, yurei |
| **Divisor** | ao morrer vira 2–3 menores | slimes grandes, larvas |

### 6.2 Tabela de inimigos (amostra; ~35 na 1.0)

| Inimigo | Arquétipo | HP | Vel. (px/s) | Dano | XP | Fase |
|---|---|---|---|---|---|---|
| Slime-de-Arroz | Perseguidor | 6 | 35 | 2 | 1 | 1 |
| Morcego-Lanterna | Enxame | 4 | 70 | 2 | 1 | 1–2 |
| Esqueleto-Camponês | Perseguidor | 15 | 40 | 4 | 2 | 1 |
| Kappa jovem | Investida | 20 | 45/180 | 10 | 3 | 1 |
| Fantasma Sombra | Sombra | 12 | 50 | 8 | 2 | 1–5 |
| Espírito de Bambu | Perseguidor | 25 | 38 | 10 | 3 | 2 |
| Kitsune Menor | Atirador | 30 | 45 | 12 | 5 | 2 |
| Tsuchigumo (aranha) | Divisor | 40 | 42 | 12 | 5 | 2–3 |
| Monge Fantasma | Atirador | 45 | 30 | 14 | 6 | 3 |
| Bakeneko | Investida | 50 | 55/220 | 16 | 6 | 3 |
| Ciclope de Pedra | Tanque | 300 | 25 | 25 | 25 | 4 |
| Larva de Cinza | Divisor | 60 | 40 | 15 | 6 | 4 |
| Oni Pequeno | Perseguidor | 90 | 50 | 20 | 10 | 5 |
| Yūrei | Sombra | 70 | 60 | 18 | 8 | 5 |

> **Mapeamento sprite → inimigo** é feito na Fase 0 após inventariar o pack (pastas `Actor/Monsters`, `Actor/Boss`, `Actor/Animals`). Inimigos sem sprite próprio = variante de cor (shader de *palette swap*) + escala.

**Elites:** qualquer inimigo com escala ×1,6, contorno dourado (shader), HP ×10, dropa Baú Laqueado.

### 6.3 Chefes

Regras gerais: barra de vida no topo, entrada com nome em letreiro (1,5 s), arena "escurece" (luz −30%), 2–3 padrões telegrafados (aviso vermelho no chão ≥ 0,7 s), dropa Baú com garantia de evolução se houver uma pronta.

| Chefe | Padrões |
|---|---|
| Tanuki Gigante | (1) rola em linha reta; (2) folhas que viram tanukis pequenos; (3) salto com onda de choque |
| Kappa Ancião | (1) jato d'água em cone; (2) poças que deixam lento; (3) mergulho e reaparece embaixo do jogador |
| Bambu Ancestral | (1) brotos que surgem do chão em linha; (2) gira com folhas-lâmina |
| Kitsune de Nove Caudas | (1) 9 fogos-fátuos teleguiados; (2) cria 2 ilusões (só a real recebe dano) |
| Tengu Corvo | (1) mergulho aéreo; (2) leque de penas; (3) invoca corvos (enxame) |
| Monge Sem Rosto | (1) apaga a luz por 4 s; (2) contas de rosário em espiral |
| Ciclope de Pedra | (1) raio do olho varrendo; (2) pisão em área |
| Dragão de Cinza | (1) sopro em arco; (2) chuva de brasas (áreas marcadas) |
| Oni Vermelho | (1) clava em área; (2) fúria com +50% velocidade abaixo de 30% HP |
| **Kuroe, Senhor da Procissão** | 3 fases: espada sombria → convoca a procissão (colunas de yōkai) → apaga a lanterna, só o ultimate reacende |
| **Shinigami** (Noite Sem Fim, 20:00) | invencível, 99999 de dano, persegue — fim da partida (como o Ceifador do VS) |

---

## 7. UI/UX (paisagem, mobile)

### 7.1 Princípios

- **Tudo nas bordas, centro livre.** O herói fica no centro exato; nenhum elemento de HUD entra nos 60% centrais.
- **Polegares:** esquerdo = movimento (metade esquerda inteira); direito = ultimate (canto inferior direito). Nada interativo na faixa superior central durante o combate.
- **Safe area:** o Redmi tem câmera em furo; em paisagem ela fica numa lateral. Usar `DisplayServer.get_display_safe_area()` e aplicar margens no `HUD` (MarginContainer) — testar com o furo à esquerda *e* à direita (girar o aparelho).
- **Alvos de toque ≥ 48 dp** (diretriz Android). Botões de menu ≥ 56 dp.
- **Legibilidade sob sol:** texto branco com contorno de 1 px escuro; nunca texto sobre o mapa sem fundo.
- **Uma ação por tela** nos menus; botão primário sempre no mesmo lugar (inferior direito).

### 7.2 HUD em combate (wireframe, 678×305 lógico)

```
┌────────────────────────────────────────────────────────────────────────┐
│[XP ██████████████████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░  Nv 23 ]      │
│ ⚔⚔⚔⚔⚔⚔  ◆◆◆◆◆◆         12:47        ☠ 3.412   ¥ 186   [2x] [❚❚]   │
│ (armas)  (passivos)    (relógio)    (abates) (ryō) (veloc.)(pausa)    │
│                                                                        │
│                                                                        │
│                               @  ← herói (centro)                      │
│                              ▂▂▂ (barra de HP sob o herói)              │
│                                                                        │
│   ◯ ← joystick flutuante                                    ╭───╮      │
│                                                             │ ☀ │ ult  │
│                                                             ╰───╯      │
└────────────────────────────────────────────────────────────────────────┘
```

- **HP sob o herói** (padrão do gênero — o olhar já está ali).
- Barra de XP de ponta a ponta no topo, com flash ao subir de nível.
- Barra do chefe aparece logo abaixo da XP durante lutas.
- Indicador de borda (seta) para santuários de Kami e baús fora da tela.

### 7.3 Fluxo de telas

```
Splash → [Consentimento 1ª vez] → [Anúncio de abertura, 17.2] → Título ─┬─ Jogar → Seleção de herói → Seleção de fase (+Lua) → Partida
                 │                                                        │
                 │                                    Level-up / Baú / Kami (overlays)
                 │                                                        │
                 │                                    Pausa ─ Opções ─ Desistir
                 │                                                        ↓
                 │                                            Resultados → Santuário/Título
                 ├─ Santuário (power-ups)
                 ├─ Loja (recompensas por anúncio a cada 6 h, 17.3)
                 ├─ Diário do Guardião (bestiário, armas, lore, conquistas)
                 ├─ Opções (áudio, vibração, joystick, FPS, idioma, acessibilidade)
                 └─ Créditos (inclui todos os autores dos assets) ─ Licenças (12.6.5)
```

> A tela **Licenças** também pode ser aberta por Opções → Sobre.

### 7.4 Telas-chave

- **Level-up:** 3–4 cartas lado a lado (paisagem permite), cada uma 150×200 lógico; toque seleciona e confirma com o *mesmo* toque (sem passo extra) — mas com **bloqueio de 0,35 s** após abrir, para o jogador não escolher sem querer enquanto movia o polegar (problema clássico em mobile).
- **Baú:** animação da roleta no centro, botão "Pular" grande; ao final, lista o que foi ganho.
- **Kami:** 3 painéis verticais com a arte do santuário, bênção em verde e custo em vermelho.
- **Resultados:** tempo, nível, abates, ryō, e tabela por arma (ícone, nível, dano total, DPS, tempo ativa).
- **Pausa:** mostra build atual com níveis e stats completos (VS faz isso; jogadores consultam muito).

### 7.5 Acessibilidade e opções

- Escala de UI (90/100/115%), modo daltônico (troca cores de brasas e avisos), reduzir flashes/tremor de tela, desativar números de dano, vibração on/off, vida "acima" ou "abaixo" do herói.
- FPS alvo: 30 / 60 (padrão) / 120 (o Redmi suporta; avisar sobre bateria).
- Idiomas: os 11 de 7.7, via `TranslationServer` (CSV em `res://i18n/`), com troca na hora.

### 7.6 Hápticos

`Input.vibrate_handheld(duração_ms, amplitude)` — dano recebido (40 ms), baú aberto (padrão de 3 pulsos), level-up (20 ms), morte do chefe (120 ms). Exige permissão `VIBRATE` no preset de exportação. Respeitar a opção do usuário.

### 7.7 Localização (11 idiomas desde a 1.0)

O jogo é lançado em **todos** os idiomas abaixo: jogo, textos da história, Diário, conquistas, tela de Licenças (nomes e categorias; os textos legais ficam no original) **e** página da Play Store.

| Código | Idioma | Por quê | Escrita / fonte |
|---|---|---|---|
| `pt_BR` | Português (Brasil) | mercado de origem, idioma de criação | latina |
| `en` | Inglês | maior mercado; **idioma-ponte** para os tradutores | latina |
| `es` | Espanhol (neutro latino-americano) | América Latina + Espanha | latina |
| `de` | Alemão | mercado premium forte | latina (palavras longas) |
| `fr` | Francês | França, Canadá, África | latina |
| `ru` | Russo | grande público de survivors-like | **cirílica** |
| `id` | Indonésio | grande mercado Android | latina |
| `ja` | Japonês | tema yōkai; público que conhece o folclore | **CJK** (kana + kanji) |
| `ko` | Coreano | mercado mobile forte | **CJK** (hangul) |
| `zh_TW` | Chinês tradicional | Taiwan e Hong Kong (o Google Play não funciona na China continental) | **CJK** |
| `zh_CN` | Chinês simplificado | Sudeste Asiático e diáspora; base para lojas fora do Play no futuro | **CJK** |

> A sugestão era "zh". Ela vira as duas variantes porque o Google Play não opera na China continental: quem usa o Play em chinês está principalmente em Taiwan e Hong Kong, que usam a escrita tradicional. Converter do tradicional para o simplificado é barato, mas precisa de revisão.

#### 7.7.1 Regras de texto e interface

- **Nenhum texto no código nem em imagens.** Tudo vem de `i18n/strings.csv` (chave, contexto para o tradutor, limite de caracteres, `en`, `pt_BR`, …) via `TranslationServer`. Ícones e arte não levam texto.
- **Pouco texto de propósito:** frases curtas (3.5) e sem dublagem, para manter a tradução barata. Meta: **≤ 12 mil palavras** de origem na 1.0, com contagem acompanhada em `docs/i18n/wordcount.csv`.
- **Espaço para crescer:** toda caixa de texto aceita **+40%** de comprimento em relação ao inglês (alemão e russo) com `autowrap` e redução automática da fonte até 85%. Nada com largura fixa.
- **Quebra de linha CJK:** usar o `TextServerAdvanced` do Godot (padrão, com ICU), que quebra japonês, chinês e coreano sem espaços. Nunca removê-lo do export para economizar tamanho.
- **Números e formatos por idioma:** separador de milhar e decimal (3.412 / 3,412 / 3 412), formato de tempo e plural (russo tem 3 formas). Ter uma função `Fmt.number()` e usar plurais do Godot (`tr_n`).
- **Nomes próprios:** nomes yōkai e de personagens mantêm a forma japonesa (em `ja`, escritos em kanji ou kana corretos). Os termos do glossário (brasa, ryō, selo, Kami, Lua Vermelha) ficam em `docs/i18n/glossary.csv`, com a tradução fixa em cada idioma.
- **Escolha do idioma:** na primeira abertura, usar `OS.get_locale()`; se não houver suporte, usar `en`. Em Opções, a lista mostra cada idioma escrito nele mesmo ("日本語", "Русский") e a troca acontece na hora, sem reiniciar.

#### 7.7.2 Fontes

As fontes pixel do Ninja Adventure e a Pixelify Sans **não** cobrem CJK, e o cirílico precisa ser conferido. Plano (cada fonte entra no registro de licenças, 12.6):

| Escrita | Fonte pixel (jogo) | Fonte legível (textos longos, Licenças) | Licença esperada |
|---|---|---|---|
| Latina + cirílica | fonte do pack ou **monogram** (CC0); alternativas: **Press Start 2P** (OFL, cirílico confirmado) e **Pixeloid** (OFL) | Noto Sans | CC0 / OFL 1.1 |
| Japonês | **Fusion Pixel Font** ou **Ark Pixel Font** (12 px) | Noto Sans CJK | OFL 1.1 |
| Chinês tradicional (zh-TW) | Fusion Pixel Font; alternativas taiwanesas: **Cubic 11 / 俐方體11號** (11×11) e **BoutiqueBitmap9x9 / 精品點陣體** (12.858 caracteres, inclui símbolos de botões de controle) | Noto Sans CJK TC | OFL 1.1 (ambas com **nome reservado**: o subconjunto precisa de outro nome) |
| Chinês simplificado (zh-CN) | Fusion Pixel Font ou BoutiqueBitmap9x9 | Noto Sans CJK SC; títulos: **Smiley Sans / 得意黑** (OFL) | OFL 1.1 |
| Coreano | Fusion Pixel Font ou **Galmuri** | Noto Sans CJK KR | OFL 1.1 |
| **Uma fonte para quase tudo (candidata)** | **Silver** (Poppy Works): latim, cirílico, grego, japonês, coreano e chinês numa só fonte pixel | — | **CC BY 4.0** (crédito obrigatório; projetos acima de US$ 100 mil precisam de licença) |

**Rejeitadas:** **Zpix / 最像素** (uso comercial pago: US$ 1.000 por produto, e proíbe fazer subconjunto). **VonwaonBitmap / 凤凰点阵体** é CC0, mas a origem dos glifos é contestada pelos próprios usuários (derivaria de uma fonte comercial antiga), então fica só como reserva. **Misaki** e **JFドットフォント** têm licenças diferentes por fonte, e várias não liberam o uso em jogo. **Cyrillic Pixel-7** é só para uso pessoal; **F77 Minecraft** é CC BY-ND (proíbe modificar).

**Decisão na Fase 0:** testar a **Silver** contra a combinação Fusion Pixel + monogram. Se a Silver cobrir todos os caracteres de `strings.csv` nos 11 idiomas (teste de 7.7.4), ela simplifica o tema e o *fallback*. O custo é um crédito obrigatório a mais.

- Usar o *fallback* de fontes do Godot (`FontFile.fallbacks`) para que um único tema sirva para todos os idiomas.
- **Tamanho do download:** fontes CJK completas têm vários MB. `tools/subset_fonts.py` (fonttools `pyftsubset`) gera subconjuntos só com os caracteres de `strings.csv`. A licença OFL permite isso, mas conferir se há **Reserved Font Name**: se houver, o subconjunto precisa de outro nome.
- Na Fase 0, confirmar a cobertura e a licença de cada fonte (verificação de 12.6.4).

#### 7.7.3 Fluxo de tradução e qualidade

1. O texto é escrito em pt-BR, fechado em inglês e **congelado** (*string freeze*) na Fase 3. Depois disso, texto novo entra só com aprovação.
2. Tradução a partir do inglês, numa plataforma de tradução (Weblate, Crowdin ou POEditor) que importa e exporta o CSV, com glossário e limites de caracteres.
3. Nível de qualidade por idioma:
   - **ja, zh_TW, zh_CN, ko:** tradutor profissional nativo. A Ásia pune tradução ruim nas avaliações, e o tema é japonês.
   - **es, de, fr, ru, id:** tradução profissional ou tradução automática **revisada por um nativo** (freelancer ou voluntário da comunidade, creditado).
   - **ja:** além disso, uma **revisão cultural** do folclore, dos nomes e do tom.
4. **LQA** (teste de qualidade da tradução) no aparelho: um nativo joga 30 min em cada idioma e marca corte de texto, contexto errado e tom.
5. Orçamento: a ser fechado com a contagem real de palavras. É o **maior custo em dinheiro** do projeto, então pedir orçamento a 2–3 fornecedores na Fase 3.

#### 7.7.4 Testes de localização

- **Pseudolocalização** do Godot (`internationalization/pseudolocalization`) ligada no build de debug desde a Fase 1: alonga os textos e troca letras por acentuadas, o que revela texto fixo no código e cortes antes de qualquer tradução.
- Teste automático (14.1): toda chave existe nos 11 idiomas; nenhum texto passa do limite de caracteres; todo caractere usado existe na fonte daquele idioma.
- Screenshots automáticos de todas as telas em todos os idiomas (`tools/capture_locales.gd`) para revisão visual rápida.
- Página da loja: título, descrição curta, descrição completa e screenshots com legendas traduzidas nos 11 idiomas.

---

## 8. Direção de arte, technical art e integração de pixel art

### 8.1 Guia de estilo

- **Base única:** Ninja Adventure (16×16, paleta própria do pack). **Regra de ouro: não misturar outro pack de personagens/tilesets** com resolução ou paleta diferentes. Complementos só para: ícones de UI, VFX abstratos (partículas), fontes.
- Tile 16 px; personagens ~16×16; chefes 32–64 px; escala de câmera inteira.
- Contorno: o pack já tem contorno escuro nos personagens; usar shader de **outline colorido** apenas para elites (dourado) e itens interativos (branco pulsante).
- Hierarquia visual: jogador (cores quentes + contorno claro) > projéteis inimigos (vermelho/magenta, sempre) > inimigos > brasas (azul/verde) > chão (dessaturado ~15% via `CanvasModulate` por fase).

### 8.2 Resolução e escala pixel-perfect

O Redmi tem 2712×1220 (20:9). Estratégia: **escala inteira calculada em tempo de execução**.

- Project Settings: `display/window/stretch/mode = viewport`, `aspect = keep`, `rendering/textures/canvas_textures/default_texture_filter = Nearest`, `rendering/2d/snap/snap_2d_transforms_to_pixel = true`.
- No boot: `k = round(altura_tela / 300)` → `content_scale_size = tela / k`.
  - Redmi: k = 4 → **678×305 pixels lógicos**, cada pixel de arte = 4×4 pixels físicos, nítido.
  - Celular 1080p (2400×1080): k = 4 → 600×270. Tablet 1600×2560 paisagem (2560×1600): k = 5 → 512×320.
- Isso mantém o campo de visão parecido entre aparelhos (~40×19 tiles) sem pixels tortos.

### 8.3 Pipeline de importação

1. Baixar o pack em `C:\src\assets\ninja-adventure\` (fora do projeto; versionar só o que for usado).
2. Copiar para `res://assets/art/...` apenas os arquivos usados (ver 10.2).
3. Import preset "PixelArt": Filter **Nearest**, Mipmaps **off**, Compress **Lossless** (VRAM compressed borra pixel art).
4. Spritesheets → `SpriteFrames` (.tres) via script de editor (`tools/build_spriteframes.gd`) que lê convenção `nome_linhas×colunas.png` e cria animações `walk_down/up/left/right`, `idle`, `hit`, `die`.
5. Atlas: Godot agrupa por textura; manter cada personagem num único PNG (o pack já faz isso) reduz trocas de textura.
6. Recolor/edição: **Aseprite** (pago) ou **LibreSprite**/**Pixelorama** (gratuitos). Pixelorama é feito em Godot e é open source.
7. Toda alteração fica registrada em `ASSET_LICENSES.md` (origem, licença, modificação feita).

### 8.4 Shaders (technical art)

| Shader | Uso | Custo |
|---|---|---|
| `hit_flash.gdshader` | inimigo pisca branco 0,08 s ao levar dano (uniform `flash`) | trivial |
| `outline.gdshader` | elites, itens interativos | baixo (4 amostras) |
| `palette_swap.gdshader` | variantes de inimigos e heróis com LUT 1D de 16 cores | baixo |
| `dissolve.gdshader` | morte de chefe, amanhecer | baixo |
| `lantern_light.gdshader` | escuridão fora do raio (tela inteira, 1 passe: distância do pixel ao herói → escurecer) | **1 passe de tela**, sem Light2D |
| `dawn_sky.gdshader` | gradiente de amanhecer nos últimos 30 s | baixo |

> **Importante:** não usar `PointLight2D` para a lanterna — em mobile, luzes 2D com muitos sprites custam caro. Um único `ColorRect` fullscreen com shader que recebe a posição do herói em coordenadas de tela resolve com custo fixo.

```glsl
// lantern_light.gdshader (CanvasItem, ColorRect fullscreen acima do mundo)
shader_type canvas_item;
uniform vec2 hero_screen_uv = vec2(0.5);
uniform float radius_px = 120.0;
uniform float soft_px = 48.0;
uniform vec2 screen_px = vec2(678.0, 305.0);
uniform float darkness : hint_range(0.0, 1.0) = 0.72;
uniform vec4 night_tint : source_color = vec4(0.05, 0.04, 0.12, 1.0);
void fragment() {
    vec2 d = (UV - hero_screen_uv) * screen_px;
    float t = smoothstep(radius_px, radius_px + soft_px, length(d));
    COLOR = vec4(night_tint.rgb, t * darkness);
}
```

### 8.5 VFX e "juice" (checklist)

- Números de dano (pool de 120 `Label` com fonte bitmap; agrupar acertos no mesmo alvo em 0,1 s).
- Hit-stop de 40 ms só em golpes de chefe/ultimate (não em cada acerto — com 500 inimigos vira travamento).
- Screen shake leve (máx. 3 px) em explosões e dano recebido.
- Partículas de morte: 4–6 pixels da cor do inimigo (`CPUParticles2D` pooled — `GPUParticles2D` no Compatibility pode ser mais custoso; medir).
- Brasas com leve flutuação e "sugadas" ao ímã com aceleração (tween).
- Level-up: anel de luz expandindo + empurrão nos inimigos próximos (dá respiro).
- Amanhecer: tela clareia, inimigos dissolvem em cinza da borda para o centro, música resolve.
- VFX do Ninja Adventure (30+) para slashes, explosões, magia; Kenney Particle Pack (CC0) como base de partículas (texturas 512 px — reduzir para 32/64 px e aplicar *posterize* para casar com pixel art).

### 8.6 Lacunas previstas do pack (e solução)

| Lacuna | Solução |
|---|---|
| Projéteis específicos (ofuda, kunai, raio) | O pack tem shuriken/kunai/ícones de magia; ofuda e raio desenhados à mão em 8×16 px (5 min cada) ou derivados dos FX |
| Arte de painéis de história | Montar cenas com tiles/personagens do próprio pack em escala ×4, com vinheta e texto (estilo diorama) |
| Ícones de 12 passivos | Itens do pack (60+) + ícones de magia (50+); complemento: 496 RPG Icons (CC0, 34 px — reduzir para 16 px) |
| Chefes faltantes | variante de cor + escala ×2 + padrões de ataque diferentes |
| Ícone do app / arte da loja | Composição com sprites do pack ampliados ×8 sobre fundo pintado com gradiente; Feature Graphic 1024×500 |

### 8.7 Animação e física (atenção especial)

Num survivors-like, o jogador passa 15 minutos olhando para centenas de coisas se mexendo. **Animação ruim ou física "esquisita"** (inimigos tremendo, empilhados, deslizando, atravessando paredes) é o que mais faz o jogo parecer amador, mesmo com arte boa. Por isso estas duas áreas têm regras e critérios próprios. As metas medíveis estão em 15.2.

#### 8.7.1 Animação de personagens e inimigos

| Regra | Detalhe |
|---|---|
| **Conjunto mínimo por personagem** | herói: `idle`, `walk` em 4 direções, `hit`, `die`, `victory`; inimigo comum: `walk`, `hit`, `die`; chefe: `idle`, `walk`, 1 animação por padrão de ataque com **antecipação** visível (≥ 0,7 s, 15.2), `hurt`, `die` em várias etapas. O que o Ninja Adventure não tiver é feito à mão no Pixelorama/LibreSprite (8.3) |
| **Animação ligada ao movimento** | a velocidade da animação de andar acompanha a velocidade real (`speed_scale = velocidade_atual / velocidade_base`, entre 0,6 e 1,6). Assim o personagem **não "patina"**: os pés acompanham o chão. Parado = `idle`, nunca `walk` congelado |
| **Direção** | o herói vira para a direção do joystick; os inimigos, para a direção do movimento. Para não ficarem trocando de lado sem parar, só viram quando a direção muda por mais de 0,1 s (*histerese*) |
| **Variedade na horda** | cada inimigo começa a animação num **quadro aleatório** e com velocidade ±10%. Isso evita 300 inimigos andando perfeitamente sincronizados, o que parece artificial |
| **Animação procedural barata** | *squash & stretch* leve (escala 0,9–1,1) ao levar dano, ao pousar e ao nascer; balanço sutil (*bob*) de 1 px ao andar nos inimigos sem animação de andar; inclinação de 5–8° na direção do movimento nos que voam |
| **Feedback de dano** | flash branco de 0,08 s (8.4) + recuo (*knockback*) + número de dano, sempre os três juntos. O herói pisca durante a invencibilidade (15.2) |
| **Morte** | inimigo comum: dissolve em 0,25 s + 4–6 partículas da cor dele (8.5) + a brasa "salta" e cai. Chefe: câmera desacelera 0,3 s, explosão em etapas, `dissolve` (8.4) e chuva de brasas |
| **Nascimento** | inimigos surgem fora da tela (5.2). Os que nascem dentro dela (cercos, invocações) aparecem com um círculo no chão por 0,4 s antes, nunca do nada em cima do jogador |
| **Pixel perfeito** | todas as posições de sprite são arredondadas para o pixel lógico no **desenho** (não na simulação): `snap_2d_transforms_to_pixel` (8.2). Escalas de squash usam valores que não deformam o pixel art (ou só no eixo vertical) |
| **Interpolação** | a simulação roda em passo fixo (`GameClock`, 4.14). O desenho **interpola** entre os dois últimos passos (*physics interpolation* do Godot 4 ou interpolação própria), para o movimento ficar suave em telas de 90/120 Hz como a do Redmi, sem tremer |
| **Ordem de desenho** | ordenação por Y (`y_sort`) para quem está mais abaixo aparecer na frente. Sombras de 1 elipse escura sob cada personagem, que ajudam a ler a posição no chão |
| **Animações de arma** | toda arma tem: disparo/antecipação, trajeto e impacto. Projéteis giram ou deixam rastro quando faz sentido (shuriken gira; kunai deixa rastro de 2–3 px) |
| **UI animada** | cartas de level-up entram com mola (*ease out back*), o baú treme antes de abrir, números de ryō contam para cima. Duração máxima de 0,4 s para não atrasar o jogador (exceto o baú, 4.8) |
| **Pipeline** | `tools/build_spriteframes.gd` (8.3) valida que toda animação obrigatória existe, que os quadros têm o mesmo tamanho e que o ponto de apoio (*pivot*, os pés) está no mesmo lugar em todos os quadros. Pivot errado faz o personagem "pular" entre quadros |

#### 8.7.2 Física e movimento

A física é **própria** (10.6): sem corpos físicos do Godot por inimigo, para caber 500 inimigos no Redmi. Por isso as regras precisam ser escritas e testadas.

| Regra | Detalhe |
|---|---|
| **Passo fixo** | toda a física roda no passo fixo de 1/60 s do `GameClock` (4.14). Nenhuma física usa o *delta* variável do frame |
| **Movimento do herói** | aceleração até a velocidade máxima em ≤ 0,1 s e parada em ≤ 0,05 s (15.2). Sem inércia que faça o jogador "escorregar". Na diagonal, a velocidade é normalizada (não anda mais rápido na diagonal) |
| **Colisão do herói com o cenário** | círculo do herói contra a **base** dos obstáculos (5.1). Ao bater na diagonal, o herói **desliza** pela borda em vez de parar seco. Nunca prende em quinas: obstáculos usam formas simples (círculo ou retângulo com cantos chanfrados) |
| **Separação da horda** | inimigos se empurram de leve (10.6) para **não se empilharem num ponto só** nem tremerem. Força limitada, amortecida e calculada a cada 2 passos para metade da horda (10.6). Teste: 300 inimigos parados em volta do herói não podem tremer mais de 1 px por frame |
| **Inimigos e cenário** | inimigos comuns **deslizam** pelos obstáculos (mesma regra do herói) e usam um **campo de direção** simples (*flow field*) por chunk para contornar casas e rochas, em vez de ficarem presos atrás delas. Inimigo preso por mais de 3 s é teletransportado (5.2) |
| **Knockback** | impulso aplicado uma vez e amortecido (×0,85 por passo, 10.6), reduzido pela `knockback_resist`. Chefes e Tanques têm resistência alta. Knockback nunca empurra inimigo para dentro de obstáculo |
| **Projéteis** | colisão círculo × círculo com teste **contínuo** (*swept*) para projéteis rápidos: verificar o segmento percorrido no passo, não só o ponto final. Isso evita atravessar inimigos (*tunneling*) mesmo em 3x (4.14) |
| **Perfuração e alvos** | cada projétil guarda os inimigos já atingidos, para não acertar o mesmo duas vezes por perfuração. Áreas de dano contínuo (Incenso, Bomba de Fumaça) usam *ticks* com tempo próprio por inimigo |
| **Brasas e ímã** | brasas atraídas aceleram até o herói (10.8) com curva suave e **nunca orbitam** sem ser coletadas: se passarem perto, são coletadas |
| **Hitbox ≠ sprite** | hitbox do herói ~60% do sprite; hitbox de dano dos inimigos um pouco **menor** que o desenho; hitbox de coleta (ímã) generosa. A regra é: em dúvida, a favor do jogador (15.2) |
| **Contato com inimigos** | dano por contato com intervalo por inimigo (não a cada passo) e invencibilidade de 0,5 s do herói (15.2). Ser cercado não pode matar instantaneamente |
| **Determinismo** | a física usa só o `Rng` com semente (10.1) e ordem fixa de atualização. Mesma semente = mesma partida, em qualquer velocidade (15.1) |
| **Depuração** | overlay de debug (13, Fase 1) desenha hitboxes, vetores de velocidade, células do *spatial hash* e o campo de direção. Indispensável para ajustar a física no aparelho |

#### 8.7.3 Testes de animação e física

- **Automáticos:** o bot (14.4) mede se algum inimigo ficou preso mais de 3 s, se houve projétil que atravessou um alvo dentro do raio de colisão (log de *tunneling*), se as brasas foram todas coletadas e se o herói ficou preso em quina. Cada caso conta como falha no CI.
- **Testes unitários da física:** deslizar na diagonal contra parede, knockback amortecido, teste contínuo de projétil rápido, separação sem tremor e normalização diagonal.
- **Revisão visual no Redmi**, em toda fase do roadmap: gravar 30 s de tela em 120 Hz e assistir em câmera lenta procurando tremor, patinação, pivot pulando, inimigos empilhados e sprites atravessando o cenário.

---

## 9. Áudio (música e SFX)

### 9.1 Música

- **Fonte principal:** as 37 faixas do Ninja Adventure (CC0) — mesma identidade do visual.
- Complementos CC0: "Oriental Somber" (Tozan, OpenGameArt) para o Diário/Créditos; "5 Chiptunes (Action)" (SubspaceAudio/Juhani Junkala, CC0) como reserva.
- Mapa: Título, Seleção, 5 fases (cada uma com faixa própria), Chefe (2 faixas alternando), Baú, Vitória/Amanhecer, Derrota, Santuário.
- Formato: **OGG Vorbis**, 96–128 kbps, loop marcado no import (`loop = true`, `loop_offset` quando houver intro).
- **Camadas dinâmicas** (opcional, fase 4 do roadmap): ao surgir o chefe, *crossfade* de 1,5 s para a faixa de chefe; nos últimos 30 s, filtro passa-baixa removido gradualmente ("o sol nascendo").

### 9.2 Efeitos sonoros

| Categoria | Exemplos | Fonte |
|---|---|---|
| Armas | corte, arremesso, trovão, vento, tambor | Ninja Adventure SFX (100+, CC0); 512 Sound Effects 8-bit (SubspaceAudio, CC0) |
| Impacto/morte de inimigo | "pop", "thud" | idem |
| Coleta | brasa (pitch sobe em sequência), ryō, comida | idem + jsfxr (gerar e exportar; som gerado por você = seu) |
| UI | clique, abrir/fechar, erro, level-up | Kenney Interface Sounds (CC0) |
| Baú/roleta | tique-tique, fanfarra | jsfxr + Kenney |
| Ambiente | vento, grilos, sinos | Ninja Adventure / Freesound **somente CC0** |

### 9.3 Mixagem e limites técnicos

- Buses: `Master` → `Music`, `SFX` (→ `SFX_Weapons`, `SFX_Hits`, `SFX_UI`), `Ambience`.
- **Limite de polifonia por som**: no máx. 4 instâncias simultâneas do mesmo SFX de acerto; os demais são descartados (com 300 acertos/s, sem isso o áudio estoura e a CPU sofre). Implementar `SfxPool` com `AudioStreamPlayer` reciclados e cooldown por som (30 ms).
- Variação de pitch aleatória ±8% nos acertos.
- *Ducking*: Music −6 dB durante baú e level-up (compressor *sidechain* no bus Music ou tween de volume).
- Volume padrão: Music 70%, SFX 80%.

---

## 10. Arquitetura técnica (Godot 4.7.2)

### 10.1 Decisões

| Tema | Decisão | Motivo |
|---|---|---|
| Versão | Godot **4.7.2 estável** (instalado em `C:\src\tools\godot`, com templates de exportação) — versão travada | é a versão instalada mais recente; o protótipo M1 já roda e exporta APK nela. Atenção: o 4.7 tem uma classe nativa `VirtualJoystick`, por isso o joystick do jogo se chama `TouchJoystick` |
| Linguagem | GDScript com tipagem estática (`var x: int`) | velocidade de iteração; tipagem dá ganho de performance |
| Renderer | **Compatibility** (OpenGL ES 3) primeiro; testar Mobile (Vulkan) na fase 5 | 2D puro, menor overhead e maior compatibilidade |
| Física | **Não** usar `CharacterBody2D`/`Area2D` por inimigo; colisão própria por *spatial hash* | centenas de corpos físicos derrubam o FPS em mobile |
| Dados | **JSON** em `data/*.json` (armas, passivos, inimigos, chefes, fases/ondas, heróis, Kami, power-ups, conquistas, itens, Loja, história), carregados pelo autoload `DB` e validados pelos testes de integração (*implementado em 21/10/2026; substitui a ideia original de `.tres`*) | balanceamento sem tocar em código; diffs legíveis no git; validação automática de referências; edição sem abrir o editor |
| Salvamento | JSON em `user://save.json` com `version` + backup `save.bak` | simples e migrável |
| Testes | `tests/run_tests.gd` (regras puras, sem autoloads) + `tests/integration_tests.tscn` (dados, idiomas, fontes, Loja, Santuário, save), bot determinístico 1x/2x/3x, estresse e `gdlint` — tudo em `tools/run_checks.ps1` (*implementado; GUT/gdUnit4 dispensados*) | regressões de balanceamento e de conteúdo |
| Textos | `i18n/strings.csv` gerado por `tools/build_i18n.py` a partir de `tools/i18n/*.py`, lido em tempo de execução pelo autoload `Locale` (importador do Godot desligado: `importer="keep"`) | um lugar para traduzir; o gerador confere chaves, 11 colunas e marcadores `%s/%d` |
| Anúncios e compras | `AdsManager`/`PurchaseManager` com dois provedores: **real** no Android (plugin Poing AdMob 5.1.0 com UMP, e GodotGooglePlayBilling 3.3.0; exigem build Gradle) e **simulado** no PC e nos testes. Até a conta AdMob existir, o real usa os IDs de teste do Google (*implementado em 21/10/2026*) | o jogo fala só com os autoloads; dá para testar todos os fluxos no PC e os anúncios reais de teste no emulador |
| Build de publicação | `tools/build_release.ps1`: verificações → AAB e APK de release assinados (chave fora do repositório, via variáveis de ambiente) com R8 → conferência das assinaturas → instala e abre no emulador | um comando reproduzível para cada envio à Play Store |

### 10.2 Estrutura de pastas

```
hyakki/
├─ project.godot
├─ ASSET_LICENSES.md          # gerado a partir de licenses/registry.json
├─ CREDITS.md                 # gerado a partir de licenses/registry.json
├─ licenses/                  # vai no APK (filtro de export, 12.6.5)
│  ├─ registry.json  dev-only.json  index.json (gerado)
│  ├─ texts/*.txt             # textos canônicos (CC0-1.0, MIT, OFL-1.1, Apache-2.0...)
│  └─ notices/*.txt           # arquivos de licença que vêm dentro de cada pacote
├─ docs/licenses/             # snapshots PDF/HTML das páginas de origem (fora do APK)
├─ addons/                    # gdUnit4/GUT, etc.
├─ assets/
│  ├─ art/{actors,bosses,tilesets,fx,ui,icons,items}/
│  ├─ audio/{music,sfx,ambience}/
│  └─ fonts/
├─ data/
│  ├─ heroes/*.tres  weapons/*.tres  passives/*.tres
│  ├─ enemies/*.tres  bosses/*.tres  waves/stage_01.tres ...
│  ├─ kami/*.tres  powerups/*.tres  achievements/*.tres
├─ i18n/strings.csv
├─ scenes/
│  ├─ boot/Boot.tscn  menus/*.tscn  ui/hud/*.tscn
│  ├─ game/Game.tscn (World + Systems + HUD)
│  ├─ actors/Player.tscn  Enemy.tscn  Boss_*.tscn
│  └─ weapons/*.tscn  pickups/*.tscn
├─ scripts/
│  ├─ autoload/ (GameState, SaveManager, AudioManager, Events, Settings, PixelScaler)
│  ├─ core/ (StatBlock, ObjectPool, SpatialHash, Rng)
│  ├─ systems/ (EnemyManager, Spawner, ProjectileManager, PickupManager, LevelUpSystem,
│  │            ChunkManager, LanternSystem, KamiSystem, BossDirector)
│  ├─ weapons/ (WeaponBase + 12 comportamentos)
│  └─ data/ (classes Resource: WeaponData, EnemyData, WaveData...)
├─ shaders/
├─ tests/
└─ tools/ (build_spriteframes.gd, balance_export.gd, fetch_licenses.py,
           check_licenses.py, build_license_index.gd, subset_fonts.py,
           capture_locales.gd)
```

### 10.3 Autoloads

| Autoload | Responsabilidade |
|---|---|
| `GameClock` | tempo de jogo com passo fixo de 1/60 s; 1, 2 ou 3 passos de simulação por frame conforme a velocidade (4.14) |
| `Events` | barramento de sinais globais (`enemy_killed`, `player_leveled`, `chest_opened`, `boss_spawned`...) |
| `GameState` | partida atual: herói, fase, tempo, stats, inventário, seed |
| `SaveManager` | load/save, migração por versão, autosave ao sair do app |
| `Settings` | opções do usuário |
| `AudioManager` | música com crossfade, `SfxPool` com limite de polifonia |
| `PixelScaler` | cálculo da escala inteira (8.2) |
| `AdsManager` | AdMob: consentimento UMP, anúncio de abertura, anúncios recompensados, timeouts, modo de teste (17.1) |
| `PurchaseManager` | Google Play Billing: compra "Remover anúncio de abertura", confirmação, restauração, reembolso, pendentes (17.7) |
| `ShopManager` | vagas da loja, esperas de 6 h, proteção contra relógio voltando, entrega e gravação das recompensas (17.3) |

### 10.4 Modelo de dados (Resources)

```gdscript
# scripts/data/weapon_data.gd
class_name WeaponData extends Resource
@export var id: StringName
@export var name_key: String            # chave i18n
@export var icon: Texture2D
@export var behavior: PackedScene       # cena com script que herda WeaponBase
@export var base_damage := 10.0
@export var cooldown := 1.0
@export var area := 1.0
@export var amount := 1
@export var pierce := 1
@export var duration := 1.0
@export var speed := 200.0
@export var max_level := 8
@export var levels: Array[Dictionary] = []   # [{ "damage": +5 }, { "amount": +1 }, ...]
@export var evolves_with: StringName          # id do passivo
@export var evolution: WeaponData
@export var unlocked_by: StringName           # id da conquista (vazio = inicial)
```

```gdscript
# scripts/data/enemy_data.gd
class_name EnemyData extends Resource
@export var id: StringName
@export var frames: SpriteFrames
@export var archetype: StringName = &"chaser"   # chaser, swarm, ring, charger, shooter, tank, shade, splitter
@export var hp := 10.0
@export var speed := 40.0
@export var damage := 5.0
@export var xp := 1
@export var radius := 6.0
@export var knockback_resist := 0.0
@export var palette: Texture2D                  # LUT opcional para variante
@export var scale := 1.0
```

### 10.5 StatBlock

```gdscript
class_name StatBlock extends RefCounted
var base: Dictionary = {}          # stat -> valor base
var add: Dictionary = {}           # stat -> soma de aditivos
var mul: Dictionary = {}           # stat -> produto de multiplicadores
func get_stat(s: StringName) -> float:
    return (base.get(s, 0.0) + add.get(s, 0.0)) * mul.get(s, 1.0)
func add_mod(s: StringName, v: float) -> void:
    add[s] = add.get(s, 0.0) + v
func mul_mod(s: StringName, v: float) -> void:
    mul[s] = mul.get(s, 1.0) * v
```

### 10.6 Inimigos em massa (núcleo de performance)

Princípio: **um gerenciador atualiza todos os inimigos num único laço**; cada inimigo é só um `Node2D` leve com `AnimatedSprite2D`, reciclado por pool. Sem `_process` por inimigo, sem corpos físicos.

```gdscript
# scripts/systems/enemy_manager.gd
class_name EnemyManager extends Node2D
const MAX := 500
var pool: ObjectPool
var alive: Array[Enemy] = []
var grid := SpatialHash.new(32.0)
@onready var player: Node2D = %Player

func _physics_process(delta: float) -> void:
    grid.clear()
    var ppos := player.global_position
    for i in alive.size():
        var e := alive[i]
        grid.insert(i, e.position)
    for i in range(alive.size() - 1, -1, -1):
        var e := alive[i]
        var dir := (ppos - e.position).normalized()
        # separação suave: empurra para longe de até 4 vizinhos
        var push := Vector2.ZERO
        var n := 0
        for j in grid.query(e.position):
            if j == i: continue
            var o := alive[j]
            var d := e.position - o.position
            var dist2 := d.length_squared()
            if dist2 < 144.0 and dist2 > 0.01:
                push += d / dist2
                n += 1
                if n >= 4: break
        e.velocity = e.velocity.lerp(dir * e.speed + push * 40.0, 0.2) + e.knockback
        e.knockback *= 0.85
        e.position += e.velocity * delta
        e.sprite.flip_h = dir.x < 0.0
        if e.position.distance_squared_to(ppos) < (e.radius + 6.0) ** 2:
            Events.player_hit.emit(e.damage)   # o Player aplica i-frames de 0,5 s
```

```gdscript
# scripts/core/spatial_hash.gd
class_name SpatialHash extends RefCounted
var cell: float
var grid: Dictionary = {}   # Vector2i -> Array[int]
func _init(c: float) -> void: cell = c
func clear() -> void: grid.clear()
func _key(p: Vector2) -> Vector2i: return Vector2i(floori(p.x / cell), floori(p.y / cell))
func insert(id: int, p: Vector2) -> void:
    var k := _key(p)
    var arr: Array = grid.get(k, [])
    if arr.is_empty(): grid[k] = arr       # Array é por referência; PackedArray NÃO (copiaria)
    arr.append(id)
func query(p: Vector2) -> Array[int]:
    var out: Array[int] = []
    var k := _key(p)
    for x in range(k.x - 1, k.x + 2):
        for y in range(k.y - 1, k.y + 2):
            out.append_array(grid.get(Vector2i(x, y), []))
    return out
```

**Evolução se precisar de mais performance** (decidir pelos números da fase 5, não antes):
1. Reduzir alocações (reusar o `Array` do `query`, guardar `Vector2i` em cache).
2. Atualizar separação a cada 2 frames (metade dos inimigos por frame).
3. Renderizar inimigos comuns com **`MultiMeshInstance2D`** (1 draw call por tipo) e animar via `INSTANCE_CUSTOM` no shader.
4. Mover o laço para **C# ou GDExtension (C++)** — só o `EnemyManager`.

### 10.7 Armas e projéteis

```gdscript
# scripts/weapons/weapon_base.gd
class_name WeaponBase extends Node2D
var data: WeaponData
var level := 1
var stats: StatBlock        # do jogador
var _t := 0.0
func _physics_process(delta: float) -> void:
    _t -= delta
    if _t <= 0.0:
        _t = data.cooldown * stats.get_stat(&"cooldown")
        fire()
func fire() -> void: pass     # sobrescrito por cada arma
func damage() -> float: return data.base_damage * stats.get_stat(&"might")
```

- Projéteis: `ProjectileManager` com pool (até 300), mesmo esquema do `EnemyManager`: um laço move todos e consulta o `SpatialHash` dos inimigos para colisão (círculo × círculo).
- Armas de área (Incenso, Taiko): consultam o hash por raio, não criam projéteis.
- "Inimigo mais próximo": consulta o hash expandindo anéis de células até achar — não percorrer a lista toda.

### 10.8 Pickups (brasas, ryō, comida)

- `PickupManager` com pool de 400; dentro do raio do ímã viram "atraídas" (aceleram até o jogador).
- Fusão acima de 300 (ver 4.3).
- Brasas fora da tela por mais de 60 s são fundidas numa gema "acumulada" perto do jogador (padrão VS).

### 10.9 Chunks do mapa

- `ChunkManager` mantém 3×3 chunks de `TileMapLayer` ao redor do jogador. Ao cruzar uma borda, a coluna/linha que saiu é *reposicionada* e repintada a partir de um template sorteado (`seed + coord`) — sem instanciar/destruir nós.
- Decoração e destrutíveis por chunk também vêm de pools.

### 10.10 Salvamento

```json
{
  "version": 3,
  "ryo": 12450,
  "powerups": { "might": 3, "armor": 2 },
  "unlocked": { "heroes": ["aki","kenta"], "weapons": ["katana","shuriken"], "stages": [1,2] },
  "achievements": ["first_light"],
  "codex": { "slime_rice": 1240 },
  "best": { "stage_1": { "time": 900, "moon": 2 } },
  "settings": { "music": 0.7, "sfx": 0.8, "vibration": true, "fps": 60, "lang": "pt_BR" }
}
```

- Salvar ao fim de cada partida, ao comprar no Santuário e em `NOTIFICATION_APPLICATION_PAUSED` (Android pode matar o app em segundo plano).
- Escrita atômica: grava `save.tmp`, renomeia para `save.json`, mantém `save.bak`.

### 10.11 Partida suspensa

Ao ir para segundo plano no meio da partida: pausar e serializar um *snapshot* leve (tempo, inventário, níveis, HP, seed, inimigos vivos não) para retomar como "continuar partida" — evita a frustração mais comum em mobile.

---

## 11. Android e o Redmi Note 14 Pro+

### 11.1 Perfil do aparelho

| Item | Valor | Implicação |
|---|---|---|
| SoC / GPU | Snapdragon 7s Gen 3 / Adreno 710 | intermediário-alto; 500 inimigos a 60 fps é meta realista com a arquitetura de 10.6 |
| Tela | AMOLED 6,67", 2712×1220, até 120 Hz | escala inteira ×4 → 678×305 lógico; preto real (o tema noturno fica ótimo) |
| Sistema | Android 14 / HyperOS | gerenciamento agressivo de bateria — salvar sempre ao pausar |
| Câmera frontal | furo na tela | respeitar safe area em paisagem |

### 11.2 Configuração do ambiente (Windows)

1. Godot 4.6.x + **Export Templates** da mesma versão.
2. **JDK 17** e **Android SDK** (via Android Studio ou command-line tools): platform-tools, build-tools, platform recentes. Em *Editor Settings → Export → Android*, apontar `java_sdk_path` e `android_sdk_path`.
3. Keystore de debug (o Godot gera) e keystore de **release** própria (guardar fora do repositório + backup).
4. Preset de exportação:
   - `screen/orientation`: **Sensor Landscape**
   - `screen/immersive_mode`: on
   - Arquiteturas: **arm64-v8a** (o Redmi); deixar armeabi-v7a desligado para APK menor
   - Permissões: `VIBRATE`, `INTERNET`, `ACCESS_NETWORK_STATE` e `AD_ID` (anúncios, 17.1). O jogo continua jogável offline
   - `gradle_build/use_gradle_build`: **on** (necessário para o plugin AdMob, 17.1)
   - Formato de release: **AAB** para a Play Store; APK para testes
   - Target SDK: conferir o mínimo exigido pela Google Play na data do envio (sobe todo ano) e ajustar no preset.

### 11.3 Preparar o Redmi (HyperOS)

1. *Configurações → Sobre o telefone →* tocar 7× em **Versão do SO** para ativar Opções do desenvolvedor.
2. *Configurações adicionais → Opções do desenvolvedor*: ativar **Depuração USB**, **Instalar via USB** e **Depuração USB (configurações de segurança)** — no Xiaomi esta última exige login na conta Mi e às vezes chip inserido.
3. Conectar via USB e aceitar a chave RSA; `adb devices` deve listar o aparelho.
4. Opcional: **Depuração sem fio** (Android 11+): parear com `adb pair ip:porta` e `adb connect ip:porta` — permite testar sem cabo.
5. No Godot: com o aparelho detectado, o ícone **Remote Deploy (Android)** aparece no canto superior direito → um clique instala e roda, com **depurador remoto** (breakpoints, monitor de performance) e `print()` no console do editor.
6. Logs nativos: `adb logcat -s godot:V`.
7. Desligar *Otimização MIUI/HyperOS* para o app durante os testes, se houver comportamento estranho em segundo plano.

### 11.4 Orçamentos de performance (no Redmi)

| Métrica | Meta | Como medir |
|---|---|---|
| FPS | 60 estável (p1 ≥ 55) com 500 inimigos + 300 projéteis + 400 brasas | monitor do depurador remoto + overlay próprio (FPS, contagens) |
| Frame time CPU | ≤ 12 ms | `Performance.get_monitor(TIME_PROCESS/TIME_PHYSICS_PROCESS)` |
| Draw calls | ≤ 150 | `RENDER_TOTAL_DRAW_CALLS_IN_FRAME` |
| Memória | ≤ 400 MB | `MEMORY_STATIC` + Android Studio Profiler |
| Térmico | sem queda > 15% de FPS após 30 min | sessão de *soak* com bot (14.4) |
| Bateria | ≤ 12%/hora em 60 fps | configurações → bateria |
| Tamanho | AAB ≤ 150 MB | OGG para música, PNG otimizado (oxipng) |
| Tempo de boot | ≤ 4 s até o título | cronômetro |
| FPS em velocidade acelerada (4.14) | 2x: ≥ 55 fps; 3x: ≥ 50 fps no pior cenário | mesmo teste de estresse, com o botão de velocidade |

Perfis automáticos: se o FPS médio cair abaixo de 50 por 10 s, reduzir teto de inimigos (500 → 400), desligar números de dano e partículas de morte — avisar nas opções ("Modo Desempenho").

---

## 12. Catálogo de assets e licenças

### 12.1 Política

1. **Prioridade:** CC0 > licenças próprias que permitem uso comercial sem crédito > CC-BY (crédito obrigatório). **Evitar CC-BY-SA, CC-NC e GPL para arte** (copyleft/não comercial).
2. Para cada asset **e cada software** que vai no APK: baixar uma **cópia do texto da licença** (`licenses/texts/`) e salvar a **página de origem como PDF** na data do download (`docs/licenses/`), porque licenças de itch.io podem mudar. O processo completo, com verificação automática e a tela no jogo, está em **12.6**.
3. Registrar tudo em `licenses/registry.json`, de onde `ASSET_LICENSES.md` é gerado (modelo no apêndice 18.3).
4. Mesmo CC0, **creditar todos** em CREDITS.md e na tela de créditos (boa prática e boa vontade da comunidade).
5. Não redistribuir os packs brutos (ex.: não subir as pastas originais num repositório público) — algumas licenças (Craftpix, Domin Dev) proíbem; versionar só o que o jogo usa, num repositório **privado**.
6. **O jogo é monetizado (anúncios e compra, seção 17).** Por isso, licenças "grátis para uso pessoal", "não comercial" ou "só para jogos sem anúncios ou microtransações" estão **proibidas**, mesmo que o arquivo seja grátis. Muitos pacotes "free" do itch.io têm exatamente essa restrição (ver 12.7.8).
7. **Assets feitos com IA generativa:** evitar no jogo, porque jogadores e criadores de conteúdo costumam reagir mal e a proteção de direitos autorais é incerta. Só usar como reserva, marcados como `ai_generated: true` no registro (12.6.2) e com decisão registrada.

### 12.2 Núcleo (estilo unificado)

| Asset | Autor | Licença verificada | Conteúdo usado | Link |
|---|---|---|---|---|
| **Ninja Adventure – Asset Pack** | pixel-boy (+AAA) | **CC0 1.0** (crédito opcional); "pague o quanto quiser" | heróis, monstros, chefes, tilesets, itens, FX, ícones de magia, UI (tema madeira), 37 músicas, 100+ SFX, 2 fontes | https://pixel-boy.itch.io/ninja-adventure-asset-pack |

Última atualização do pack: Update #8 (29/03/2026) — "Animation V2", animais, acampamento. O pack inclui exemplo de projeto Godot 4, útil como referência de importação.

### 12.3 Complementos

| Asset | Autor | Licença | Uso no Hyakki | Link |
|---|---|---|---|---|
| Particle Pack | Kenney | CC0 (80 arquivos) | texturas de partícula (reduzidas e posterizadas) | https://kenney.nl/assets/particle-pack |
| Interface Sounds / UI Audio | Kenney | CC0 | sons de menu | https://kenney.nl/ |
| Input Prompts (pixel) | Kenney | CC0 | ícones de gamepad nas opções | https://kenney.nl/ |
| 496 pixel art icons for medieval/fantasy RPG | Henrique Lazarini (7Soul1) | CC0 (domínio público) | ícones extras de passivos/conquistas | https://opengameart.org/content/496-pixel-art-icons-for-medievalfantasy-rpg |
| 512 Sound Effects (8-bit style) | SubspaceAudio (Juhani Junkala) | CC0 | SFX de armas/coleta/UI | https://opengameart.org/content/512-sound-effects-8-bit-style |
| 5 Chiptunes (Action) | SubspaceAudio (Juhani Junkala) | CC0 | música reserva | https://opengameart.org/content/5-chiptunes-action |
| Oriental Somber | Tozan | CC0 | música do Diário/Créditos | https://opengameart.org/content/oriental-somber |
| 100 CC0 SFX | rubberduck | CC0 | foley (sinos, gongo, madeira, metal) | https://opengameart.org/content/100-cc0-sfx |
| jsfxr | (ferramenta) | sons gerados são seus | coleta, level-up, roleta | https://sfxr.me/ |
| Pixelify Sans / outra pixel font do Google Fonts | Google Fonts | SIL OFL 1.1 (uso comercial ok, embutir ok) | fonte de UI com acentos e cirílico, se as fontes do pack não cobrirem; fontes CJK em 7.7.2 | https://fonts.google.com/ |

> **Verificar na fase 0:** as 2 fontes do Ninja Adventure cobrem acentuação do português? Se não, usar uma fonte OFL do Google Fonts.

### 12.4 Avaliados e **não** recomendados para o núcleo (estilo diferente)

| Asset | Licença verificada | Por que não no núcleo |
|---|---|---|
| 0x72 16x16 DungeonTileset II | CC0 (código MIT) | ótimo, mas paleta/estilo de masmorra gótica diferente; usar só se o tema virar "dungeon" (plano B) |
| Kaishido — Cursed Realm | uso comercial permitido, crédito opcional | conteúdo pequeno (1 herói, 5 inimigos), estilo diferente |
| Trevor Pupkin — Roguelike Dungeon Asset Bundle | uso comercial permitido, crédito opcional | sem tileset, personagens só olham esquerda/direita, 40×40 px |
| Domin Dev — Free Pixel Fantasy/Melee Weapon Packs | comercial ok; **proíbe redistribuir o pack** | ícones de armas úteis só se casarem com a paleta (testar) |
| CraftPix freebies (já em `C:\src\assets\craftpix-net`) | comercial ok, sem crédito; **proíbe redistribuição e uso para treinar IA** | estilo vetorial/alta resolução incompatível com 16 px |
| Kenney Particle Pack | CC0 | usado só como textura de partícula (12.3) |
| Pacotes de música japonesa pagos (ex.: airyluvs, US$ 49) | royalty-free, mas pago | fora da regra "só gratuitos" |

### 12.5 Inventário (tarefa da Fase 0)

Após baixar o Ninja Adventure, rodar um script (`tools/inventory_assets.py`) que gera `docs/asset_inventory.csv` com: caminho, dimensões, nº de quadros estimado, categoria. Com ele, preencher a **matriz de mapeamento**:

| ID do jogo | Arquivo do pack | Ajuste (recolor/escala) | Status |
|---|---|---|---|
| hero_aki | Actor/Characters/... | — | ☐ |
| enemy_slime_rice | Actor/Monsters/... | palette_swap: arroz | ☐ |
| boss_tanuki | Actor/Boss/... | escala ×1 | ☐ |
| ... | | | |

### 12.6 Verificação, cópia e exibição das licenças

Objetivo: **todo** software e **todo** asset que vai no APK precisa ter licença verificada, uma **cópia local do texto da licença** (baixada e guardada no repositório) e uma entrada visível na tela **Licenças** do jogo. Nada entra no build sem isso.

#### 12.6.1 Escopo: o que precisa de licença

| Categoria | Exemplos | Vai no APK? | Aparece na tela Licenças? |
|---|---|---|---|
| Motor | Godot Engine (MIT) | sim | sim |
| Bibliotecas de terceiros do motor | FreeType, HarfBuzz, ICU, libogg/libvorbis, zlib, mbedTLS, etc. | sim | sim (lista gerada automaticamente, 12.6.5) |
| Bibliotecas Android do template | AndroidX/Kotlin (Apache 2.0) e, se usado, plugin de faturamento do Google Play | sim | sim |
| Plugins/addons do Godot que vão no build | plugin AdMob, plugin Google Play Billing (17.7), etc. | sim | sim |
| SDKs de anúncios | Google Mobile Ads SDK, UMP SDK (termos próprios do Google) e, se houver mediação, os SDKs de cada rede | sim | sim |
| Arte | Ninja Adventure, Kenney, 496 RPG Icons | sim | sim |
| Áudio | Ninja Adventure, SubspaceAudio, Tozan, rubberduck | sim | sim |
| Fontes | fontes do pack, Pixelify Sans (OFL) | sim | sim (a OFL **exige** que o texto acompanhe a fonte) |
| Addons só de desenvolvimento | gdUnit4/GUT | não | não (ficam registrados em `licenses/dev-only.json`) |
| Ferramentas | Aseprite, Pixelorama, LibreSprite, jsfxr, Python | não | não (registrar que o que elas geram pertence ao projeto) |

#### 12.6.2 Fonte única de verdade: `licenses/registry.json`

Um único arquivo descreve cada componente. `ASSET_LICENSES.md` e `CREDITS.md` são **gerados** a partir dele, não editados à mão.

```json
{
  "id": "ninja_adventure",
  "name": "Ninja Adventure – Asset Pack",
  "category": "art",                      // engine | engine_thirdparty | android | plugin | art | audio | font
  "author": "pixel-boy & AAA",
  "version": "Update #8 (2026-03-29)",
  "source_url": "https://pixel-boy.itch.io/ninja-adventure-asset-pack",
  "license_id": "CC0-1.0",                // identificador SPDX
  "license_url": "https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt",
  "license_file": "licenses/texts/CC0-1.0.txt",
  "notice_file": "licenses/notices/ninja_adventure.txt",   // texto/aviso do próprio autor, se houver
  "snapshot_file": "docs/licenses/ninja_adventure_2026-10-20.pdf",
  "sha256": { "license_file": "…", "notice_file": "…", "snapshot_file": "…" },
  "downloaded_at": "2026-10-20",
  "verified_at": "2026-10-20",
  "verified_by": "Clayton",
  "attribution_required": false,
  "commercial_use": true,
  "redistribution_of_raw_pack": true,
  "modifications": "recolor de heróis; reescala de chefes",
  "files": ["assets/art/actors/**", "assets/audio/music/ninja_*.ogg"]
}
```

#### 12.6.3 Download das cópias das licenças (`tools/fetch_licenses.py`)

Para cada entrada do registro, o script:

1. Baixa o **texto canônico da licença** (`license_url`) para `licenses/texts/<SPDX>.txt`. Ex.: CC0 (`legalcode.txt` da Creative Commons), MIT do Godot (`LICENSE.txt` da *tag* exata da versão usada no GitHub), OFL 1.1, Apache 2.0.
2. Copia o **arquivo de licença que vem dentro do pacote** baixado (`LICENSE`, `License.txt`, `OFL.txt`, `readme`), se existir, para `licenses/notices/<id>.txt`.
3. Salva um **snapshot da página de origem** na data do download, em `docs/licenses/<id>_<data>.pdf` (via Chrome *headless* `--print-to-pdf`) e `.html`. Em itch.io e OpenGameArt, a licença está escrita na própria página e pode mudar depois.
4. Calcula o **SHA-256** de cada arquivo, grava no registro e preenche `downloaded_at`.
5. Nunca sobrescreve uma cópia antiga: se o conteúdo mudou, salva uma nova versão com a data e marca a entrada como `needs_review`.

Os textos ficam em `licenses/` (versionados e **incluídos no APK**). Os snapshots ficam em `docs/licenses/` (versionados, **fora** do APK).

#### 12.6.4 Verificação (`tools/check_licenses.py`): roda no CI, nos testes e antes de cada release

Falha o build se:

- algum arquivo em `assets/` ou `addons/` (que vá no export) não está coberto por um padrão em `files` de alguma entrada;
- alguma entrada não tem `license_file` local, ou o hash não confere;
- a licença não está na lista permitida: `CC0-1.0`, `MIT`, `Apache-2.0`, `OFL-1.1`, `CC-BY-4.0`, `BSD-*`, `Zlib`, `FTL`, `LicenseRef-*` (licenças próprias revisadas à mão). **Bloqueadas:** `*-NC-*`, `*-ND-*`, `CC-BY-SA-*` e `GPL-*` para arte e áudio, e qualquer licença marcada `personal_only` ou `no_monetized_games` (12.1, regra 6);
- `attribution_required = true` e o componente não aparece em `CREDITS.md`;
- `verified_at` tem mais de 180 dias, ou a entrada está marcada `needs_review` (aviso no dia a dia, **erro** no build de release);
- (modo `--online`, só antes do release) a licença ou a página de origem mudou em relação ao snapshot guardado.

**Checklist manual por entrada** (registrar no campo `verified_by`): a licença permite uso comercial? Exige crédito? Proíbe redistribuir o pack bruto? Proíbe uso para treinar IA? Exige que o texto acompanhe o arquivo? A licença cobre **todos** os arquivos do pacote (alguns packs misturam autores)?

#### 12.6.5 Tela "Licenças" no jogo

**Acesso:** Título → Créditos → **Licenças**, e também Opções → Sobre → Licenças. Funciona offline: todos os textos vão empacotados.

**Layout em paisagem (678×305 lógico):**

```
┌───────────────────────────────────────────────────────────────────────┐
│ ← Voltar        LICENÇAS                         [🔍 buscar      ]    │
│ [Todos] [Motor] [Arte] [Áudio] [Fontes] [Android/Plugins]             │
├──────────────────────────┬────────────────────────────────────────────┤
│ ▸ Godot Engine     MIT   │ Ninja Adventure – Asset Pack               │
│ ▸ FreeType         FTL   │ Autor: pixel-boy & AAA                     │
│ ▸ Ninja Adventure  CC0 ◀ │ Licença: CC0 1.0   Versão: Update #8       │
│ ▸ Kenney Particle  CC0   │ Baixado em 20/10/2026 · verificado em ...  │
│ ▸ Pixelify Sans    OFL   │ Modificações: recolor de heróis            │
│ ▸ ...                    │ Usado em: 214 arquivos                     │
│                          │ [Abrir site]   [Ver texto da licença]      │
└──────────────────────────┴────────────────────────────────────────────┘
```

- **Lista à esquerda** com nome e "selo" da licença; **detalhe à direita**. "Ver texto da licença" abre o texto completo (`RichTextLabel` rolável, fonte legível não-pixel com fallback, tamanho ajustável). Mostra também o `notice_file`, se houver.
- **"Abrir site"** usa `OS.shell_open(source_url)`, com confirmação antes de sair do jogo.
- **Seção "Motor e bibliotecas"** gerada em tempo de execução por `Engine.get_license_text()`, `Engine.get_copyright_info()` e `Engine.get_license_info()`. Assim ela cobre automaticamente todos os componentes de terceiros do Godot da versão exportada. Os itens do Android e dos plugins vêm do registro.
- **Dados:** no build, `tools/build_license_index.gd` converte `licenses/registry.json` em `res://licenses/index.json` (sem caminhos de `docs/`).
- **Export:** adicionar `licenses/*.txt, licenses/*.json` ao filtro **"arquivos não-recurso a exportar"** do preset Android. Sem isso, os `.txt` não entram no APK. O teste 14.2 confere isso.
- Alvos de toque ≥ 48 dp, rolagem por arraste e suporte a gamepad (navegar pela lista e abrir o texto).

#### 12.6.6 Fluxo para adicionar um asset ou software novo

1. Ler a licença e preencher o checklist (12.6.4).
2. Criar a entrada em `registry.json`.
3. Rodar `fetch_licenses.py` para baixar o texto, o aviso do autor e o snapshot.
4. Copiar para `assets/` só os arquivos que serão usados.
5. Rodar `check_licenses.py`; com tudo verde, gerar `ASSET_LICENSES.md` e `CREDITS.md`.
6. Commitar tudo junto (asset, registro, textos e snapshot).

### 12.7 Pesquisa de assets complementares (20/10/2026)

**Objetivo:** encontrar assets gratuitos que deixem o jogo **mais gostoso de jogar e de ouvir**, para o jogador continuar jogando. O foco está no que mais pesa nisso num survivors-like: **sons de impacto e recompensa, efeitos visuais, música com identidade japonesa, ícones legíveis e fontes para os 11 idiomas**.

**Como ler as tabelas:**
- **Status:** ✅ recomendado (entra na prova de estilo da Fase 0) · 🟡 reserva ou condicional · ❌ rejeitado.
- A licença foi lida na página do autor em 20/10/2026. **Mesmo assim, todo item passa pelo processo de 12.6** (download do texto, snapshot, checklist) antes de entrar no jogo.
- **Regra de estilo (8.1) continua valendo:** nada de outro pacote de personagens ou tileset no núcleo. Complementos visuais só entram se passarem na **prancha de estilo**: colocar o asset ao lado do Ninja Adventure, na escala do jogo, com a paleta ajustada (`palette_swap`, 8.4), e aprovar no Redmi.

#### 12.7.1 Efeitos sonoros (impacto, magia, interface, recompensa)

| Status | Asset | Autor | Conteúdo | Licença (resumo) | Por que ajuda a reter | Link |
|---|---|---|---|---|---|---|
| ✅ | **FREE Pixel Combat SFX** | Helton Yan | **2.100 sons** de combate retrô (golpe, magia, explosão, buff, movimento), 12 categorias, 6 variações cada | **CC BY 4.0** (crédito obrigatório) | é a maior fonte de variação de acertos: 6 variações por som evitam a fadiga em 15 min (15.7) | https://heltonyan.itch.io/pixelcombat |
| ✅ | **RPG Essentials SFX – Free** | Leohpaz | 48 sons: UI, magia por elemento, cura, buff, reviver, abate | comercial ok; crédito opcional; **não redistribuir** | sons de UI, de cura e de **reviver** (17.6) no mesmo estilo | https://leohpaz.itch.io/rpg-essentials-sfx-free |
| ✅ | **Music Jingles** | Kenney | **85 jingles** curtos | **CC0** | base para o level-up, a fanfarra do baú, conquista e "Desbloqueado!" (15.7) | https://kenney.nl/assets/music-jingles |
| ✅ | **効果音ラボ** (Sound Effect Lab) | site japonês | grande biblioteca de efeitos, **inclusive sons japoneses** | comercial grátis, **sem crédito**; proíbe redistribuir os sons, treinar IA e Content ID | sons japoneses de interface, de templo e de festival (12.7.11) | https://soundeffect-lab.info/agreement/ |
| ✅ | **Sonniss GameAudioGDC** (bundles anuais) | vários estúdios | dezenas de GB de sons profissionais (o de 2024 tem 23,5 GB) | uso comercial e ilimitado, **sem crédito**; não revender os sons; **proibido usar para treinar IA** | taiko, sinos de templo, gongo, vento, fogo, ambientes: qualidade profissional para os momentos-chave (chefe chegando, amanhecer) | https://sonniss.com/gameaudiogdc |
| 🟡 | Pixabay (sons e músicas) | vários | biblioteca grande | Pixabay Content License: comercial e sem crédito; proíbe distribuir o arquivo sozinho e usar com marcas registradas | bom para preencher buracos (ex.: um instrumento específico). Baixar a página do item como snapshot, porque os autores variam | https://pixabay.com/service/license-summary/ |

#### 12.7.2 Música

> **Implementado (21/10/2026):** 15 faixas da categoria 和風・アジア do **甘茶の音楽工房** substituíram as músicas do Ninja Adventure em todas as fases, chefes, menus, história, amanhecer, Noite Sem Fim e créditos (só a derrota continua com o Ninja Adventure). O 魔王魂 ficou como reserva, porque exige crédito em toda faixa. Mapa de faixas em `tools/amacha_assets.json`; licença em `licenses/sources/LicenseRef-Amacha.txt`.

| Status | Asset | Autor | Conteúdo | Licença | Uso no Hyakki | Link |
|---|---|---|---|---|---|---|
| ✅ | **High Quality 16-bit RPG Music** | HydroGene | 28 faixas estilo SNES, com loop perfeito (ogg/wav) | **CC0** | reserva de faixas de batalha e de chefe; combina com o som 16-bit do pack | https://hydrogene.itch.io/high-quality-16-bit-music |
| ✅ | **FREE Music Loop Bundle** | Tallbeard Studios / Abstraction | **200+ músicas** com loops (chiptune, ambiente, animadas) | **CC0** (o autor pede que não seja usado em NFT ou IA, sem ser condição) | menus, Santuário, Loja, variações de faixa para a Noite Sem Fim | https://tallbeard.itch.io/music-loop-bundle |
| ✅ | HoliznaCC0 (ChipTunes, Retro Gamer Soundtrack) | Holizna | álbuns de chiptune | **CC0** (conferir faixa a faixa) | reserva | https://freemusicarchive.org/music/holiznacc0/chiptunes |
| ✅ | **甘茶の音楽工房** (Amacha) – categoria 和風・アジア | Amacha (JP) | várias páginas de faixas japonesas (ex.: 平安ノ宵, 桜雲, お地蔵様のいる小道) | comercial grátis, **crédito opcional**; não redistribuir; não registrar no Content ID | **música principal das fases** (Vila, Bambu, Templo), Diário e Santuário | https://amachamusic.chagasi.com/terms.html |
| ✅ | **魔王魂** (Maou Damashii) | Morita Kōichi (JP) | 5.000+ músicas e efeitos, com faixas japonesas | comercial sem limite; **crédito obrigatório** ("音楽：魔王魂"); proíbe IA e NFT | batalha de chefe, fases 4 e 5 | https://maou.audio/rule/ |
| ✅ | **OpenTracks** (antigo DOVA-SYNDROME) | vários compositores (JP) | grande catálogo, com categoria japonesa | jogos permitidos, sem crédito; **regras extras por compositor** | reserva; snapshot de cada faixa | https://opentracks.com/help/articles/license/ |
| ❌ | **WAFU Free Sampler** | wafusoundworks | 3 faixas japonesas (shakuhachi, koto, shamisen, taiko), com versão em loop | comercial ok, sem crédito; proíbe redistribuir e treinar IA | **composto com IA (Suno)**. Pela regra 7 de 12.1, só entraria sem alternativa, e agora há alternativas sem IA (甘茶, 魔王魂, OpenTracks; 12.7.11) | https://wafusoundworks.itch.io/wafu-free-sampler-japanese-game-music |

> **Lacuna resolvida pela pesquisa japonesa (12.7.11):** a primeira rodada não achou música japonesa gratuita, sem IA e com licença clara. A pesquisa em sites japoneses achou: **甘茶の音楽工房** (categoria 和風・アジア, comercial grátis, **sem crédito obrigatório**), **魔王魂** (5.000+ músicas, comercial, **crédito obrigatório**) e **OpenTracks** (antigo DOVA-SYNDROME, sem crédito, mas cada compositor pode ter regras extras). Elas passam a ser a **fonte principal de música japonesa**, e o WAFU (feito com IA) sai das opções. O tema principal (motivo-assinatura de 15.7) continua sendo o melhor candidato a encomenda, se houver orçamento.

#### 12.7.3 Efeitos visuais (VFX)

| Status | Asset | Autor | Conteúdo | Licença | Uso | Link |
|---|---|---|---|---|---|---|
| ✅ | **Pixel Art VFX – Lightning** | Frostwindz | 6 animações de raio (128–256 px) | comercial ok; crédito opcional; não redistribuir | Raio de Raijin e Fúria de Raijin (4.5, 4.7); reduzir a escala na prancha de estilo | https://frostwindz.itch.io/pixel-art-skill-animations-lightning |
| ✅ | Pixel Art VFX – Paladin / Warrior (versões FREE) | Frostwindz | golpes e habilidades | mesma licença (conferir cada página) | Lâmina do Amanhecer, Golpe da Lanterna | https://frostwindz.itch.io/pixel-art-animations-paladin |
| ✅ | **Free Pixel Effects Pack #8 – Mini Magick Shoots** (e os outros packs grátis do autor) | XYEzawr | projéteis mágicos em 9 cores | comercial ok; crédito opcional; não redistribuir | Hitodama, projéteis de Kitsune e de Atirador | https://xyezawr.itch.io/free-pixel-effects-pack8 |
| 🟡 | Battle VFX: Hit Spark | pimen | 1 efeito grátis (o pack completo de 11 custa US$ 5) | comercial ok, crédito opcional | faísca de acerto crítico | https://pimen.itch.io/battle-vfx-hit-spark |
| ✅ | **Juice Shaders Lite** | StuartEvil | shaders `hit_flash`, `outline`, `dissolve` para Godot 4 | **MIT** | ponto de partida pronto para 8.4 | https://godotengine.org/asset-library/asset/5212 |
| ✅ | Hit FX (shaders e scripts Godot) | binbun3d | efeitos de impacto por shader | **CC0** | hit-stop, flash e partículas de impacto | https://binbun3d.itch.io/hit-fx |
| ✅ | godotshaders.com (shaders com licença CC0) | comunidade | dissolve pixel art, outline pixel-perfect, etc. | **CC0 por shader** (conferir cada um; as imagens da página não estão incluídas) | amanhecer, morte de chefe | https://godotshaders.com/shader/dissolve-add-details-pixel-art/ |

#### 12.7.4 Ícones

| Status | Asset | Autor | Conteúdo | Licença | Uso | Link |
|---|---|---|---|---|---|---|
| ✅ | **Pixel Art Icons – RPG Essentials (16×16)** | Kettoman | 64 ícones: armas, comida, materiais, poções | **CC0** | passivos, Loja (17.3), itens de chão | https://kettoman.itch.io/pixel-art-icons-rpg-essentials-16x16 |
| ✅ | **Free 16×16 Weapon RPG Icons** | Shade | armas, **incluindo katana**, faca, foice | **CC0** | ícones de armas (4.5), kusarigama/foice | https://merchant-shade.itch.io/free-16x16-weapon-rpg-icons |
| ✅ | RPG Pixel Art Icon Pack (33) | iD01t Productions | armas, poções, moeda, baú | **CC0** | moeda de ryō, baú | https://id01t.itch.io/rpg-pixel-art-icon-pack |
| 🟡 | Shikashi's Fantasy Icons / 600+ Icon Pack | Matt Firth (shikashipx) | 600+ ícones, inclusive 16×16 | comercial ok **com crédito**; parte deriva de game-icons.net (CC BY 4.0, crédito duplo) | conquistas e Diário, se faltar ícone | https://shikashipx.itch.io/shikashis-600-icon-pack |

#### 12.7.5 Interface (UI)

| Status | Asset | Autor | Conteúdo | Licença | Uso | Link |
|---|---|---|---|---|---|---|
| ✅ | **Pixel UI Free** | heyheythere | **Theme de Godot pronto, estilo madeira** (botões, sliders, abas, janelas), barras de HP/XP, 20 ícones 16×16, cursores. Testado em Godot 4.3–4.7 e no renderer Compatibility | **CC BY 4.0** (crédito obrigatório) | combina com o tema madeira do Ninja Adventure e economiza dias de trabalho na Fase 4 | https://godotengine.org/asset-library/asset/5494 |
| 🟡 | Free Medieval Fantasy UI Pack | Kibyra | botões e painéis (32×32, 64×32) | comercial ok; crédito opcional; não redistribuir | alternativa se o Pixel UI não passar na prancha de estilo | https://kibyra.itch.io/free-medieval-fantasy-ui-pack |

#### 12.7.6 Fontes (11 idiomas, 7.7.2)

| Status | Fonte | Cobertura | Licença | Uso | Link |
|---|---|---|---|---|---|
| ✅ | **Fusion Pixel Font** (TakWolf) | latim + **japonês, coreano, chinês simplificado e tradicional**; 8, 10 e 12 px | **OFL 1.1** (sem nome reservado informado na página; conferir o arquivo) | fonte CJK principal | https://github.com/TakWolf/fusion-pixel-font |
| ✅ | **monogram** (datagoblin) | latim com acentos (pt, es), **cirílico (ru)**, grego; versão "extended" | **CC0** | fonte latina e cirílica principal, se a fonte do pack não cobrir | https://datagoblin.itch.io/monogram |
| ✅ | DotGothic16 (Fontworks, Google Fonts) | japonês com aparência pixel | OFL 1.1 | títulos em japonês | https://fonts.google.com/specimen/DotGothic16 |
| 🟡 | k8x12, PixelMplus | japonês | licenças próprias que, segundo terceiros, permitem uso comercial | só depois de ler o arquivo de licença original | — |
| ❌ | Misaki | japonês | fontes conflitantes sobre o uso comercial | evitar enquanto não houver texto original claro | — |

#### 12.7.7 Personagens, monstros e cenário

| Status | Asset | Autor | Conteúdo | Licença | Observação | Link |
|---|---|---|---|---|---|---|
| 🟡 | Free Pixel Monsters Pack 16×16 | danaida | 25 monstros 16×16 | comercial ok; editar ok; não redistribuir | **só se passar na prancha de estilo**; útil para variar inimigos comuns | https://danaida.itch.io/free-pixel-monsters-pack-16x16 |
| 🟡 | **Sakura Shrine Village** (demo grátis; pack pago) | bubbabba | 16×16 top-down japonês: tiles, 319 objetos, 60 animações, 4 estações, NPCs 16×32 | comercial ok; não redistribuir | é o pacote **mais alinhado com o tema** encontrado (torii, cerejeiras, santuário). A demo grátis tem só a primavera. O completo custa ~US$ 5–15, o que quebra a regra "só gratuitos". Decidir na Fase 0 com a prancha de estilo | https://bubbabba.itch.io/sakura-shrine-village |

> **Lacuna encontrada:** não existe pacote **gratuito**, 16×16, top-down, com yōkai animados e licença comercial clara. O Ninja Adventure continua sendo a base, e os yōkai que faltarem são feitos com recolor + escala (8.6). Se houver orçamento de arte (lacuna de vitrine apontada na análise de mercado), os primeiros itens a encomendar são a Aki, os chefes, o ícone e a arte principal da loja.

#### 12.7.8 Avaliados e rejeitados

| Asset | Motivo |
|---|---|
| Raven Fantasy Icons (versão grátis) | a versão grátis é **só para uso pessoal** e jogos sem anúncios ou microtransações. Incompatível com 17 |
| Pacotes grátis de efeitos da BDragon1727 | versão grátis **não comercial**; o uso comercial exige pagar a versão completa |
| Pixel Material Studio – yōkai (CP32/CP41) | pagos, sprites de 100–400 px (não 16 px) e **feitos com IA** |
| Japan Neighborhood (The Flavare), Ninja Pixel Sprite Pack (smok-3r) | feitos para jogos de plataforma (visão lateral), não para top-down |
| Free Shinobi Sprites (CraftPix) | sprites de 128 px, estilo incompatível; licença CraftPix proíbe redistribuir e treinar IA |
| Combat FX (RagnaPixel) | pago (US$ 3,99) e CC BY 4.0 |
| CC0 Game Music (Duckhive), Fantasy Music Mega Pack (Blacis) | CC0, mas **gerados com IA** e de qualidade irregular |

#### 12.7.9 Créditos obrigatórios gerados por esta pesquisa

Os itens com **CC BY 4.0** ou crédito obrigatório exigem crédito em `CREDITS.md`, na tela de Créditos e na tela de Licenças (12.6). Hoje são:
- **Helton Yan** (Pixel Combat SFX)
- **heyheythere** (Pixel UI Free)
- **魔王魂 / Maou Damashii** (música), no formato exigido pelo site: "音楽：魔王魂". Nos outros idiomas: "Music: Maou Damashii (魔王魂)"
- **Poppy Works** (fonte Silver), se escolhida em 7.7.2
- se usados: **Matt Firth/shikashipx + game-icons.net**, **PixyMoon**

As fontes OFL (Fusion Pixel, Cubic 11, BoutiqueBitmap9x9, Smiley Sans, Press Start 2P, Pixeloid) não exigem crédito na tela, mas o arquivo `OFL.txt` de cada uma precisa ir junto (tela de Licenças, 12.6.5). O `check_licenses.py` falha o build se algum crédito ou arquivo de licença faltar.

#### 12.7.10 Pesquisa ampliada: fontes da lista do usuário (20/10/2026)

A lista completa de fontes fica em [01-prompt.md](01-prompt.md). Avaliação de cada uma para o Hyakki: pixel art 16×16, top-down, jogo monetizado.

**Novos achados que valem a pena:**

| Status | Asset | Fonte | Conteúdo | Licença | Uso no Hyakki | Link |
|---|---|---|---|---|---|---|
| 🟡 | **Starquest – Yokai Monsters** | GuidoSprite (itch.io) | yōkai animados **top-down** (espíritos, oni, guardiões da floresta, trapaceiros), andar + ícones | comercial ok; editar ok; não redistribuir. **Pago: US$ 3,99** | é o único pacote de yōkai top-down com licença comercial clara encontrado. Se a prancha de estilo aprovar, preenche a maior lacuna de 12.7.7 por pouco dinheiro | https://guidosprite.itch.io/starquest-yokai-monsters |
| 🟡 | Tiny Adventure Pack | Vryell | herói, esqueleto, árvore, pedra, baú, moedas e orbes, grade 16×16 | uso pessoal e comercial; crédito opcional; não redistribuir | baú com animação e orbes (brasas), se passar na prancha de estilo | https://vryell.itch.io/tiny-adventure-pack |
| 🟡 | Cute RPG – Icons | PixyMoon | 140+ ícones em 16, 32 e 48 px | comercial ok; **crédito obrigatório**; não vender o pack | ícones de reserva | https://pixymoon.itch.io/cute-rpg |
| ✅ | Kenney (pacotes de áudio): Impact Sounds, Interface Sounds, RPG Audio, UI Audio | Kenney | sons de impacto, UI e RPG | **CC0** (conferir em cada página) | completam os sons de UI e de impacto, sem crédito | https://kenney.nl/assets |
| ✅ | **BigSoundBank** | Joseph Sardin | biblioteca de sons reais (sinos, madeira, água, vento) | **CC0** nos arquivos marcados "Free and Royalty Free" | foley e ambiente das fases (sinos de templo, vento no bambu) | https://bigsoundbank.com/ |
| ✅ | 99Sounds | vários | bibliotecas temáticas de sons | comercial ok, inclusive jogos; crédito opcional; não redistribuir os arquivos soltos | ambiências e impactos cinematográficos | https://99sounds.org/ |
| ✅ | Mixkit – **efeitos sonoros** | Envato | sons variados | Sound Effects Free License: jogos permitidos, crédito opcional. **A música do Mixkit NÃO pode ser usada em jogos** | sons de reserva | https://mixkit.co/free-sound-effects/ |
| ✅ | Lospec – paletas | comunidade | 4.500+ paletas de pixel art | paletas são só listas de cores | escolher uma paleta-mestra para os recolors (`palette_swap`, 8.4) e testar as paletas noturnas de cada fase | https://lospec.com/palette-list |
| 🟡 | Kitsune Mask 16×18; My random Japanese pixel art | OpenGameArt | máscara kitsune; arte japonesa avulsa | **CC0** | detalhes avulsos (máscara Noh/kitsune como ícone do passivo 4.6) | https://opengameart.org/content/kitsune-mask-16x18 |

**Fontes de música com restrições que importam:**

| Fonte | Situação | Motivo |
|---|---|---|
| incompetech (Kevin MacLeod) | 🟡 | CC BY (crédito obrigatório). Tem faixas com clima asiático. Bom, mas **muito usado** em vídeos do YouTube, o que tira identidade do jogo. Conferir a versão da CC por faixa |
| Soundimage.org (Eric Matyas) | 🟡 | grátis **com crédito dentro do jogo** (não basta a página da loja); sem crédito custa US$ 30 por música |
| Fesliyan Studios | ❌ | grátis só para projetos **não comerciais**; jogo comercial exige doação. Fora da regra "só gratuitos" |
| Mixkit (música) | ❌ | a licença de música proíbe uso em jogos |
| Uppbeat | ❌ | crédito em toda descrição, limite mensal de downloads, uso comercial grande não coberto |
| FreePD | ❌ | o site **foi fechado** |
| Bensound, Tunetank, IndieGameMusic, Partners in Rhyme, SoundDogs | ❌ | modelos de assinatura ou pagos, ou licença grátis restrita a vídeos |
| ccMixter, Free Music Archive, Freesound, SoundBible, Zapsplat | 🟡 | **licença varia por arquivo** (muitos são CC BY-NC, que é proibido). Usar só itens CC0 ou CC BY, um por um, com snapshot da página. O Zapsplat grátis exige crédito e só entrega MP3 |
| Open Music Archive, Musopen | ❌ | gravações antigas e música clássica ocidental; não combinam com o jogo |
| SoundJay, FreeSFX, The Motion Monkey, Signature Sounds | 🟡 | não verificados a fundo; licenças próprias. Só usar depois de ler a licença do site |

**Arte 2D que não combina com o estilo do Hyakki:**

| Fonte | Motivo |
|---|---|
| Free Game Assets, GameArt2D, Super Game Asset, Glitch (OpenGameArt), CraftPix (freebies) | arte **vetorial/cartum em alta resolução** ou de plataforma, não pixel 16×16 top-down. A CraftPix também proíbe uso para IA e redistribuição |
| Pixel Frog (Pixel Adventure, Treasure Hunters, Kings and Pigs, Pirate Bomb) | **CC0** e excelentes, mas todos são de **plataforma** (visão lateral). No máximo como inspiração de animação |
| Kevin's Mom's House | maioria 8×8 ou de plataforma; sem licença na página principal |
| almostApixel (Smallburg) | 16×16 estilo fazenda; quase tudo pago; só o Town Pack é grátis |
| LyniaDesign – Tiny Pixel Japan (samurai, personagens, fundo) | tema japonês e uso comercial permitido, mas é de **plataforma** (23×25 px, pular e cair) |
| Reiner's Tilesets | sprites renderizados de 3D, estilo isométrico anos 2000 |
| Game-Icons.net | ícones vetoriais monocromáticos, **CC BY 3.0** (crédito). Úteis só para a interface fora do combate (Opções, Licenças) |
| Unsplash, Pexels, Vecteezy, Pixabay (imagens) | fotos e vetores: servem no máximo para material de divulgação |
| Domin Dev, Kaishido, Trevor Pupkin | já avaliados em 12.4 |

**Fora de escopo (jogo 2D):** Quaternius, KayKit, Fab, FreeStylized, Poly Haven, Sketchfab, Mixamo, Free3D, Poly Pizza, FreePoly, ambientCG, Textures.com, Share Textures, 3D Textures, Material Maker. Ficam na lista para uma possível versão PC/3D ou para arte de marketing.

**Fontes tipográficas:** Google Fonts (OFL) e Font Squirrel (só fontes liberadas para uso comercial) são confiáveis. **DaFont, 1001 Fonts e FontStruct têm licenças misturadas**, muitas só para uso pessoal; só usar uma fonte de lá depois de ler o arquivo de licença dela.

**Itens da tabela que parece ser de outro projeto (zumbis / tower defense):** Kenney Particle Pack (já está em 12.3) e Kenney Background Elements (CC0, mas vetorial; só se passar na prancha de estilo). The Zombie (OpenGameArt) e os pacotes CraftPix (Plague Town, Horizontal Backgrounds, Zombie Character, Forbidden Graveyard, Market Cartoon) **não servem**: tema de zumbi ou cidade ocidental, estilo vetorial e visão lateral.

**Conclusão da pesquisa ampliada:** a lista não trouxe nenhum substituto melhor para o Ninja Adventure. Os ganhos reais são: **sons** (Kenney áudio, BigSoundBank, 99Sounds, Mixkit SFX), **paletas** (Lospec) e, se aprovado na prancha de estilo, os **yōkai top-down da GuidoSprite** por US$ 3,99.

#### 12.7.11 Pesquisa em sites japoneses, chineses e russos (20/10/2026)

O detalhamento site a site está em [02-pesquisa-assets-japao-china-russia.md](02-pesquisa-assets-japao-china-russia.md). Avaliados: **34 fontes japonesas, 21 chinesas/taiwanesas e 18 russas (ou em russo)**. A meta era 50 por país. Ela não foi atingida porque, depois das fontes sérias, o que sobra nesses mercados é quase todo **agregador sem dono identificável, republicação de bibliotecas pagas ou material exclusivo do RPG Maker**. Contar esses sites só inflaria o número sem trazer nenhum asset utilizável.

**Aprovados e o que mudam no plano:**

| Status | Asset | País | Licença (lida na fonte) | Mudança no plano | Link do termo |
|---|---|---|---|---|---|
| ✅ | **甘茶の音楽工房** (Amacha) – música 和風・アジア | JP | comercial grátis, inclusive jogos; **crédito opcional**; proíbe vender ou redistribuir a música sozinha e registrar no Content ID | **nova fonte principal de música japonesa** (12.7.2) | https://amachamusic.chagasi.com/terms.html |
| ✅ | **魔王魂** (Maou Damashii) – 5.000+ músicas e efeitos | JP | comercial sem limite; **crédito obrigatório**; proíbe IA, NFT e registro em entidades de direitos autorais | música japonesa e de batalha; crédito em 12.7.9 | https://maou.audio/rule/ |
| ✅ | **OpenTracks** (antigo DOVA-SYNDROME) | JP | jogos e apps permitidos; **sem crédito**; proíbe IA, Content ID e redistribuição. **Cada compositor pode ter regras extras**, que precisam ser lidas faixa a faixa | reserva de música, com snapshot da página de cada faixa | https://opentracks.com/help/articles/license/ |
| ✅ | **効果音ラボ** (Sound Effect Lab) | JP | comercial grátis; **sem crédito**; colocar dentro do app é permitido; proíbe redistribuir os sons, treinar IA e Content ID | efeitos sonoros gerais e **sons japoneses**; junta-se a Kenney e Helton Yan em 12.7.1 | https://soundeffect-lab.info/agreement/ |
| ✅ | **ぴぽや (Pipoya)** – tileset 16×16 grátis, efeitos (VFX) grátis | JP | comercial ok, pessoa física ou empresa; **sem crédito**; pode modificar; não vender o material | candidatos de **efeitos visuais** (portal, pilar de luz, sino, escudo) e de tileset 16×16 para a prancha de estilo | https://pipoya.net/sozai/terms-of-use/ · https://pipoya.itch.io/free-rpg-tileset-16x16 |
| ✅ | **Cubic 11 / 俐方體11號** | TW | OFL 1.1, com nome reservado | alternativa de fonte para zh-TW (7.7.2) | https://github.com/ACh-K/Cubic-11 |
| ✅ | **BoutiqueBitmap9x9 / 精品點陣體** | TW | OFL 1.1, com nome reservado | alternativa de fonte para zh-TW e zh-CN (7.7.2) | https://github.com/scott0107000/BoutiqueBitmap9x9 |
| ✅ | **Smiley Sans / 得意黑** | CN | OFL 1.1 | títulos em chinês simplificado (7.7.2) | https://github.com/atelier-anchor/smiley-sans |
| ✅ | **LXGW WenKai / 霞鹜文楷** | CN | OFL 1.1, nomes reservados | reserva para textos longos em chinês (não é pixel) | https://github.com/lxgw/LxgwWenKai |
| ✅ | **Silver** (Poppy Works) | — | CC BY 4.0 | candidata a fonte única dos 11 idiomas (7.7.2) | https://poppyworks.itch.io/silver |
| ✅ | **Press Start 2P**, **Pixeloid** | — | OFL 1.1 | alternativas de fonte com cirílico para `ru` (7.7.2) | https://fontlibrary.org/en/font/press-start-2p · https://ggbot.itch.io/pixeloid-font |
| ✅ | **SoundsFree** (gerador procedural de sons) | RU | sons gerados são royalty-free, comercial ok, sem crédito | ferramenta de reserva junto com o jsfxr; o som gerado é do projeto | https://www.soundsfree.art/ru/ |
| 🟡 | **DOT ILLUST** | JP | comercial ok **até 30 itens por jogo**; sem crédito | só para ilustrações avulsas (Diário, tela de carregamento); controlar a contagem no registro | https://dot-illust.net/terms/ |
| 🟡 | **和風 BGM 36 faixas (maruya328, BOOTH)** | JP | comercial ok, sem crédito; **pago (¥2.980)**; OGG sem ponto de loop | alternativa barata à encomenda do tema, se as faixas grátis não bastarem | https://booth.pm/ja/items/5711297 |
| 🟡 | **Liborio Conti** (no-copyright-music.com) | RU (site) | comercial ok, sem crédito; não redistribuir | reserva de música genérica; não tem estilo japonês | https://www.no-copyright-music.com/ru/ |
| 🟡 | **VonwaonBitmap / 凤凰点阵体** | CN | CC0, mas origem dos glifos contestada | só reserva (7.7.2) | https://timothyqiu.itch.io/vonwaon-bitmap |
| 🟡 | **Wuxia Masks Icons** | CN | CC0 segundo a listagem do itch.io | conferir a página; máscaras como ícones do passivo "Máscara Noh" (4.6) | itch.io (tag wuxia) |

**Rejeitados (principais motivos):**

| Asset ou site | País | Motivo |
|---|---|---|
| H/MIX GALLERY | JP | grátis só para obras pessoais/dōjin; **jogo comercial exige licença paga** (¥2.200) |
| PeriTune | JP | termos do site e CC BY 4.0 se contradizem; o próprio autor está revisando. Licença **não verificável** hoje |
| OtoLogic | JP | página de licença bloqueada (403); crédito obrigatório citado só por terceiros |
| REFMAP / First Seed Material | JP | site fora do ar; licença só conhecida por comentários |
| Material para RPG Maker (ex.: série "ラルフくんとRTPの仲間たち") e material derivado do RTP | JP | **exclusivo do RPG Maker** |
| GTM (BOOTH) – música 和風 | JP | pago (¥6.000–9.000 por faixa); a amostra grátis é só para teste |
| ねこびっドー (Gumroad) – sons de taiko, koto, shamisen | JP | pago por item; licença não lida |
| Zpix / 最像素 | CN | uso comercial pago e proíbe subconjunto |
| 爱给网 (aigei), 淘声网, 素材中国, 千图网, 包图网 | CN | **agregadores**: os arquivos são enviados por terceiros e a autoria não é verificável, mesmo quando marcados "CC" |
| Cute SCKR – tilesets wuxia | CN | pagos e **feitos com ajuda de IA** |
| 耳聆网 (ear0) | CN | licença por arquivo, sem termo oficial encontrado; só usar item a item, se aparecer |
| NoiseFX | RU | **só uso pessoal** |
| ZvukBox, zvukogram, zvukitop, zvukipro | RU | agregadores ou republicação, sem dono identificável; zvukitop republica até Kevin MacLeod (CC BY) como se fosse CC0 |
| FiftySounds | RU | termo de licença não encontrado na página |
| Cyrillic Pixel-7, F77 Minecraft, Grand9K | RU | só uso pessoal, CC BY-ND (proíbe modificar) e CC BY-SA, respectivamente |
| Magnific/Freepik, canais do Telegram, listas da Pikabu e da Habr | RU | estoque genérico ou listas de terceiros, sem licença própria verificável |

**Conclusão:** a pesquisa **não trouxe substituto melhor para o Ninja Adventure** na arte. Os ganhos reais são três:
1. **Música japonesa grátis, sem IA e com licença clara** (甘茶, 魔王魂, OpenTracks). Isso preenche a maior lacuna de áudio do plano.
2. **Efeitos sonoros com sons japoneses e sem crédito** (効果音ラボ).
3. **Mais opções de fonte** para chinês (Cubic 11, BoutiqueBitmap9x9) e uma candidata a fonte única (Silver).

Os efeitos e o tileset 16×16 da Pipoya entram na prancha de estilo como candidatos.

#### 12.7.12 Tarefa da Fase 0

1. Baixar os itens ✅ e 🟡 para `C:\src\assets\candidatos\` (fora do projeto).
2. Montar a **prancha de estilo**: uma cena de Godot com o Ninja Adventure e cada candidato visual, na escala ×4, testada no Redmi ao sol.
3. Montar a **prancha sonora**: tocar os sons-chave de cada pacote no alto-falante do Redmi e em fones; escolher pelo critério de 15.7 (som reconhecível, sem cansar).
4. Os aprovados entram pelo processo de 12.6.6. Os reprovados ficam registrados aqui com o motivo.

---

## 13. Roadmap de implementação

Estimativas para **1 dev em tempo parcial (~20 h/semana)**. Cada fase termina com build instalado no Redmi.

### Fase 0 — Pré-produção (semana 1)

- [ ] Criar repositório privado `hyakki/`, `.gitignore` do Godot, Git LFS para `*.png *.ogg *.wav`.
- [ ] Instalar Godot 4.6.x + templates; criar projeto com configurações de 8.2 e 11.2.
- [ ] Base de localização (7.7): `strings.csv` com colunas dos 11 idiomas, pseudolocalização ligada no debug, fontes de fallback (latina, cirílica, CJK) escolhidas e com licença verificada, `Fmt.number()`.
- [ ] Qualidade de código (15.1): tipagem como erro, gdtoolkit e gdUnit4 no pre-commit, CI com Godot headless, template de PR, pasta `docs/adr/`.
- [ ] Baixar Ninja Adventure + complementos.
- [ ] Criar `licenses/registry.json` com **todos** os componentes: assets, Godot e bibliotecas, template Android e fontes (12.6.1).
- [ ] Escrever `tools/fetch_licenses.py` e `tools/check_licenses.py`; baixar textos, avisos e snapshots de todas as licenças; preencher o checklist de cada entrada (12.6.3–12.6.4).
- [ ] Gerar `ASSET_LICENSES.md` e `CREDITS.md` a partir do registro; colocar `check_licenses.py` no hook de pre-commit e nos testes.
- [ ] Inventário e matriz de mapeamento (12.5).
- [ ] Prancha de estilo e prancha sonora com os candidatos de 12.7; decidir sobre os pagos de baixo custo (Sakura Shrine Village, Starquest Yokai Monsters) e sobre a encomenda do tema musical (12.7.10).
- [ ] Testar export vazio no Redmi (Remote Deploy funcionando).
- [ ] **Prova técnica de anúncios:** build Gradle com o plugin AdMob mostrando um App Open e um Rewarded **de teste** no Redmi, e o plugin Google Play Billing compilando no mesmo build. Se o plugin não funcionar com Godot 4.6, decidir a alternativa agora (17.1).
- [ ] Planilha de balanceamento inicial (`docs/balance.xlsx` ou CSV) com armas, inimigos, ondas.
- **Pronto quando:** "Hello World" em paisagem roda no Redmi com escala ×4 nítida, todas as licenças baixadas e verificadas, e `check_licenses.py` verde.

### Fase 1 — Protótipo do núcleo (semanas 2–3)

- [x] Player com joystick flutuante, i-frames, HP.
- [x] Câmera que segue o player; chão infinito simples (textura repetida; os templates de chunk ficam para a Fase 2).
- [x] `GameClock` com passo fixo desde o início (4.14): todos os sistemas leem o tempo dele. Fazer isso depois custa muito mais. Velocidade 1x/2x/3x já funciona, com determinismo verificado.
- [x] `EnemyManager` + `SpatialHash` + pool; 4 inimigos (slime, morcego, esqueleto, slime vermelho).
- [x] Spawner por tabela simples (alvo por minuto), com nascimento na borda da tela e orçamento por segundo (5.2).
- [x] 3 armas: Katana, Shuriken, Incenso (8 níveis cada) + 6 passivos.
- [x] Brasas, ímã, barra de XP, level-up com 3 cartas (UI provisória).
- [x] Morte → tela de resultado (com dano e DPS por arma) → reiniciar.
- [~] Overlay de debug: FPS, inimigos vivos, projéteis, brasas, custo da simulação (F3) e **hitboxes** (F4) prontos. Faltam draw calls, vetores de velocidade e células do spatial hash (8.7.2).
- [~] Física base de 8.7.2: separação (com teto de vizinhos), knockback, teste contínuo de projéteis, interpolação de desenho e início aleatório da animação nos inimigos prontos. Faltam deslizar em obstáculos (ainda não há obstáculos) e animação ligada à velocidade (8.7.1).
- **Pronto quando:** partida de 10 min divertida no Redmi; **teste de estresse com 500 inimigos ≥ 55 fps**. *Se não atingir, resolver a performance agora (10.6) antes de criar conteúdo.*

### Fase 2 — Sistemas completos (semanas 4–7)

- [ ] Resources de dados (10.4) e carregamento data-driven de armas/passivos/inimigos/ondas.
- [ ] 6 arquétipos de inimigo + elites + baú com roleta.
- [ ] 12 armas base e 12 passivos; evoluções; uniões.
- [ ] Lanterna (shader + mecânica de raio + Sombras).
- [ ] Santuário de Kami (5 pactos para começar).
- [ ] Golpe da Lanterna (ultimate) para Aki.
- [ ] Destrutíveis e itens de chão.
- [ ] Botão de velocidade 1x/2x/3x (4.14): telas que ficam sempre em 1x, áudio e números de dano em tempo real, proteção automática de desempenho.
- [ ] `ChunkManager` com templates.
- [ ] SaveManager, ryō, Santuário (meta-progressão) com 8 power-ups.
- [ ] `AdsManager` e `ShopManager` (17.1–17.3) com anúncios de teste: anúncio de abertura com tempo máximo de espera, loja com 6 vagas e esperas de 6 h, painel de Reviver na morte e botão Dobrar ryō nos resultados (17.6).
- [ ] `PurchaseManager` (17.7) com o produto `remove_open_ad` em teste: compra, confirmação, restauração e reembolso.
- [ ] Testes unitários: StatBlock, curva de XP, pool de level-up, evoluções.
- [ ] Simulação headless de balanceamento e telemetria de cartas/Kami/eventos (15.4); sons-chave de recompensa e perigo da fase 1 (15.7).
- **Pronto quando:** fase 1 completa jogável de 0 a 15:00 com chefe placeholder e amanhecer.

### Fase 3 — Conteúdo (semanas 8–14)

- [ ] 5 fases: tilesets, 6–10 templates de chunk cada, tabelas de ondas, perigos ambientais.
- [ ] ~35 inimigos (incluindo variantes) e 10 chefes com padrões.
- [ ] 6 heróis com ultimates; desbloqueios.
- [ ] 15 Kami; 14 power-ups; 40 conquistas; Diário do Guardião.
- [ ] Narrativa: intro, frases de fase, painéis de amanhecer, final.
- [ ] **Congelamento do texto** (7.7.3): texto final em pt-BR e en, glossário, contagem de palavras; pedir orçamento de tradução a 2–3 fornecedores e começar a tradução.
- [ ] Música por fase, SFX completos, `SfxPool` com polifonia.
- **Pronto quando:** campanha completa de 5 fases jogável do início ao fim.

### Fase 4 — UI final, juice e polimento (semanas 15–18)

- [ ] UI final com tema do pack (madeira) e fonte definitiva; todas as telas de 7.3.
- [ ] Tela final da **Loja** (17.3), consentimento UMP, opção "Privacidade e anúncios" e áudio em mudo durante anúncios.
- [ ] Tela **Licenças** (12.6.5): lista, filtros, busca, texto completo, seção do motor gerada por `Engine.get_copyright_info()`, `index.json` gerado no build e filtro de export para `licenses/*`.
- [ ] Shaders: hit flash, outline, palette swap, dissolve, amanhecer.
- [ ] Números de dano, screen shake, partículas, hápticos, ducking.
- [ ] Opções e acessibilidade (7.5).
- [ ] Localização (7.7): tradução dos 11 idiomas, revisão cultural em ja, LQA em cada idioma, fontes CJK com subconjunto.
- [ ] Tutorial implícito: primeiros 60 s da fase 1 com dicas contextuais ("Arraste para mover", "Toque para o Golpe da Lanterna" quando carregar).
- [ ] Ícone do app, splash, arte da loja.
- **Pronto quando:** um testador novo entende o jogo sem explicação e pede "mais uma".

### Fase 5 — Performance, Android e QA (semanas 19–22)

- [ ] Profiling no Redmi com o pior cenário (fase 5, 14:00, build com 12 armas evoluídas).
- [ ] Aplicar otimizações de 10.6 conforme necessário; comparar Compatibility × Mobile renderer.
- [ ] Teste térmico de 30 min e de bateria.
- [ ] Partida suspensa / retomada; teste de interrupções (ligação, notificação, bloqueio de tela, troca de app).
- [ ] Teste em 2–3 aparelhos mais fracos (emprestados ou Firebase Test Lab gratuito/Play Console pre-launch report).
- [ ] Balanceamento com telemetria local (14.3) e 5+ playtesters.
- **Pronto quando:** todas as metas de 11.4 cumpridas; zero crash em 20 partidas seguidas.

### Fase 6 — Lançamento (semanas 23–26)

- [ ] Conta de desenvolvedor Google Play e conta AdMob; política de privacidade com anúncios e consentimento (17.5); `app-ads.txt` no site; "Contém anúncios" e Segurança dos dados declarados; trocar IDs de teste pelos IDs reais **só** no build de release.
- [ ] Produto `remove_open_ad` ativo no Play Console com preço por região; "Contém compras no app" marcado; compra testada com testadores de licença no teste fechado.
- [ ] AAB assinado; **teste fechado** (exigência do Play para contas pessoais novas: grupo mínimo de testadores por um período — conferir a regra vigente).
- [ ] Ficha da loja nos 11 idiomas (título, descrições, screenshots com legendas traduzidas), 6–8 screenshots em paisagem, vídeo de 30 s, Feature Graphic.
- [ ] Classificação etária (IARC), seção de segurança de dados.
- [ ] **Auditoria de licenças da release:** `check_licenses.py --online --release` verde; nenhuma entrada `needs_review`; abrir no Redmi a tela Licenças do AAB final e conferir item por item contra o registro.
- [ ] Lançamento; monitorar *Android vitals* (ANR, crashes).
- **Pronto quando:** publicado.

### Pós-1.0 (backlog)

Desafio diário, fase secreta, mais heróis, co-op local (2 jogadores em um aparelho com gamepad), Steam/PC (Godot exporta quase sem mudanças), modo exército (inspirado em Boneraiser Minions).

### 13.1 Marcos

| Marco | Semana | Entregável |
|---|---|---|
| M0 | 1 | Projeto + export no Redmi |
| M1 | 3 | **Protótipo divertido + 500 inimigos a 60 fps** |
| M2 | 7 | Vertical slice: fase 1 completa |
| M3 | 14 | Conteúdo completo (alpha) |
| M4 | 18 | Beta polido |
| M5 | 22 | Release candidate |
| M6 | 26 | Lançamento |

---

## 14. Plano de testes

### 14.1 Testes automatizados

- **Unitários de reviver e compra:** reviver oferecido no máximo 1× por partida e só depois de gastar o Revive do Santuário; não oferecido no Desafio Diário nem contra o Shinigami; dobrar ryō só 1× e só sobre o ryō da partida; compra reembolsada faz o anúncio de abertura voltar; compra pendente não libera.
- **Unitários da loja:** espera de 6 h por vaga, relógio voltando no tempo não libera a vaga, recompensa entregue só com o callback de recompensa, recompensa gravada antes de fechar o anúncio, limite de 1 de cada para "próxima partida".
- **Unitários (gdUnit4/GUT):** StatBlock, fórmulas de XP e escalonamento, geração do pool de level-up (nunca oferece item no máximo; respeita slots), evoluções (condições), save/load e migração de versão.
- **Testes de dados:** script que valida todos os `.tres` (ids únicos, evolução aponta para passivo existente, toda chave i18n existe nos 11 idiomas, respeita o limite de caracteres e tem todos os caracteres na fonte do idioma — 7.7.4).
- **Testes de licença:** `check_licenses.py` (12.6.4). Todo arquivo exportado precisa estar coberto pelo registro, todo texto de licença precisa existir com o hash correto, nenhuma licença pode estar na lista bloqueada e todo crédito obrigatório precisa estar em `CREDITS.md`. Um teste gdUnit4 carrega `res://licenses/index.json` e confere que cada `license_file` abre dentro do projeto exportado.

### 14.2 Matriz de testes manuais

| Área | Casos |
|---|---|
| Entrada | joystick em todas as direções; soltar/encostar rápido; dois dedos; canhoto; gamepad |
| Level-up | toque acidental (bloqueio 0,35 s); 4ª escolha; reroll/pular/banir; tudo no máximo |
| Baú | 1/3/5 itens; evolução pronta; pular animação |
| Kami | aceitar, ignorar, efeitos e custos aplicados corretamente |
| Ciclo de vida | minimizar, bloquear tela, ligação recebida, girar o aparelho 180° (furo da câmera do outro lado), pouca bateria |
| Save | matar o app pelo multitarefa logo após comprar no Santuário; espaço cheio |
| Áudio | fones Bluetooth (latência), modo silencioso, volume 0 |
| Localização | em cada um dos 11 idiomas: textos cabem (alemão e russo), quebra de linha CJK correta, números formatados, troca de idioma sem reiniciar, idioma detectado na primeira abertura |
| Anúncios | 1ª abertura sem anúncio; 2ª abertura com anúncio; modo avião (jogo libera em ≤ 4 s); sem anúncio disponível; voltar do segundo plano no meio da partida (sem anúncio); fechar o recompensado antes do fim (sem recompensa); minimizar durante o anúncio; ligação recebida durante o anúncio; consentimento aceito e recusado; adiantar e atrasar o relógio do aparelho; reabrir o consentimento em Opções |
| Velocidade | trocar 1x/2x/3x no meio da partida; level-up, baú, Kami, morte e resultados abrem em 1x e voltam à velocidade escolhida; escolha lembrada entre partidas; botão escondido na 1ª partida; pior cenário em 3x aciona a proteção automática sem travar; áudio sem embolar em 3x |
| Reviver e Dobrar | reviver aceito, recusado e com a contagem acabando; reviver sem internet (painel não aparece); app minimizado durante o anúncio de reviver; dobrar ryō em vitória e em derrota; app fechado logo após a recompensa (ryō não se perde) |
| Compra | comprar, cancelar no meio, pagamento pendente, reinstalar e restaurar, trocar de aparelho, reembolso pelo Play Console, comprar sem internet, botão "Restaurar compras" |
| Licenças | abrir todas as entradas no APK instalado, **offline** (modo avião); textos longos rolam sem travar; seção do motor aparece; "Abrir site" pede confirmação; navegação por gamepad |

### 14.3 Balanceamento

- **Telemetria local** (sem internet): ao fim da partida, gravar linha em `user://runs.csv` — herói, fase, tempo, nível, causa da morte, armas/níveis, dano por arma, ryō. Botão nas opções de debug para exportar (compartilhar arquivo).
- Metas de balanceamento:
  - Jogador novo morre entre 5 e 9 min na primeira partida da fase 1; vence a fase 1 entre a 3ª e a 6ª partida.
  - Nenhuma arma responde por > 45% do dano médio em 20 partidas aleatórias.
  - Toda evolução é alcançável antes de 12:00 em ≥ 50% das partidas que a buscam.
- Ferramenta: modo debug com *god mode*, dar qualquer item, pular minuto, 4× velocidade.
- Critérios completos (índice de pressão, pick rate de cartas, Kami, economia, simulação headless): ver **15.4**.

### 14.4 Bot de soak test

Um "piloto automático" (move em círculos/foge do centro de massa dos inimigos, escolhe cartas aleatórias) roda partidas de 30 min no Redmi para medir FPS, temperatura e vazamento de memória — e encontrar crashes sem jogar manualmente.

### 14.5 Playtests

- Rodada 1 (fim da fase 1 do roadmap): 3 pessoas, só observar — "onde travou? sorriu quando?".
- Rodada 2 (alpha): 5–8 pessoas, questionário de 5 perguntas + telemetria.
- Rodada 3 (beta): teste fechado na Play Store.

---

## 15. Critérios de qualidade

Cada critério tem **meta**, **como medir** e **marco** em que passa a ser obrigatório (15.9). Um critério que não pode ser medido não é critério; se um número se mostrar errado no playtest, ajustar o número **e registrar o porquê** em `docs/quality_log.md`.

### 15.1 Qualidade de código

| Critério | Meta | Como medir | Marco |
|---|---|---|---|
| Tipagem estática | 100% das variáveis, parâmetros e retornos tipados | Project Settings → `debug/gdscript/warnings/untyped_declaration = Error` (e `inferred_declaration` liberado) | M0 |
| Estilo e formatação | 0 avisos | **gdtoolkit** (`gdformat --check` + `gdlint`) no pre-commit e no CI; seguir o *GDScript style guide* oficial | M0 |
| Tamanho e complexidade | função ≤ 40 linhas; arquivo ≤ 400 linhas; ≤ 5 parâmetros; aninhamento ≤ 3 | regras do `gdlint` (`max-file-lines`, `function-arguments-number`) + revisão | M1 |
| Avisos e erros em runtime | 0 avisos no editor; 0 erros/avisos no log durante 30 min de soak (14.4) | `godot --headless` com o bot, varrer o log no CI | M2 |
| Testes | toda regra de jogo em `scripts/core` e `scripts/systems` (StatBlock, XP, escalonamento, pool de level-up, evoluções, Kami, economia, save) tem teste; 100% dos testes passando | gdUnit4 no CI; PR sem teste para regra nova não entra | M1 |
| Dados, não números mágicos | nenhum valor de balanceamento no código; tudo em `.tres`/CSV | `tools/check_magic_numbers.py` (procura literais numéricos fora de `const` em `scripts/systems` e `scripts/weapons`) + testes de dados (14.1) | M2 |
| Arquitetura | sistemas se comunicam por sinais do `Events` ou por referências injetadas; nada de `get_node("/root/...")` entre sistemas; nenhum autoload novo sem ADR | revisão + grep no CI | M1 |
| Laço quente sem alocação | 0 alocações por frame em `_physics_process` de EnemyManager, ProjectileManager e PickupManager (sem `Array.new()`, `Dictionary` temporário, `str()` ou `%` de string) | profiler do Godot (*Monitors → Object/Memory*) estável por 10 min no pior cenário | M1 |
| Orçamento de frame | ver 11.4; cada sistema tem orçamento (ex.: inimigos ≤ 4 ms, projéteis ≤ 2 ms, UI ≤ 1 ms no Redmi) | `Performance.get_monitor` + medição própria por sistema no overlay de debug | M1 |
| Save robusto | load de **todas** as versões anteriores do save funciona; save corrompido cai no backup sem crash | testes de migração com fixtures `tests/fixtures/save_v*.json` | M2 |
| Determinismo | mesma semente + mesmas entradas = mesma partida (necessário para Desafio Diário e para reproduzir bugs), **em qualquer velocidade** (4.14) | teste: o bot roda com a mesma semente em 1x, 2x e 3x e compara o hash do estado no minuto 5 | M3 |
| Decisões registradas | toda decisão de arquitetura relevante tem ADR curto em `docs/adr/NNN-titulo.md` | revisão | M0 |
| Commits e revisão | Conventional Commits; cada mudança passa por um checklist de PR (testes, lint, licenças 12.6, perf) mesmo trabalhando sozinho; revisão com `/code-review` nas mudanças grandes | template `.github/pull_request_template.md` | M0 |
| Crashes | 0 crash em 20 partidas seguidas (13, fase 5); taxa de crash < 0,5% das sessões e ANR < 0,2% no Android vitals | Play Console | M5/M6 |

**Definição de pronto de uma tarefa:** compila sem avisos, lint verde, testes verdes, `check_licenses.py` verde, testado no Redmi (não só no PC), sem queda de FPS no overlay e, se mexe em balanceamento, simulação de 15.4 rodada.

### 15.2 Jogabilidade (*game feel* e justiça)

| Critério | Meta | Como medir |
|---|---|---|
| Latência de toque → movimento | ≤ 50 ms (≤ 3 frames a 60 fps) | vídeo em câmera lenta (240 fps) de outro celular filmando o dedo e a tela |
| Resposta do movimento | velocidade máxima em ≤ 0,1 s; parada em ≤ 0,05 s; sem "deslizar" | gravação + log de velocidade no overlay |
| Hitbox justa | hitbox do herói = ~60% do sprite; inimigos causam dano só com contato real (não pela borda do sprite) | overlay de debug que desenha hitboxes |
| Invencibilidade após dano | 0,5 s com piscar visível | teste manual |
| Aviso de ataque | todo ataque de chefe e de elite avisado ≥ 0,7 s antes (área vermelha + som) | checklist por chefe |
| Mortes injustas | < 10% das mortes classificadas pelo testador como "não sei do que morri" | pergunta pós-morte no playtest |
| Leitura da tela | projéteis inimigos com contraste ≥ 3:1 sobre o chão de **todas** as 5 fases; teste ao sol com brilho em 50% | script que mede o contraste em screenshots + teste ao ar livre |
| Ritmo inicial | primeiro abate ≤ 3 s; primeiro level-up ≤ 20 s; primeira escolha "interessante" (2 armas diferentes) ≤ 60 s | telemetria local (14.3) |
| Sem tempo morto | nunca mais de **45 s** sem uma novidade (level-up, evento de onda, baú, item no chão, Kami, chefe) | telemetria local com timestamps de eventos |
| Reiniciar rápido | do resultado à nova partida em ≤ 2 toques e ≤ 3 s de carregamento | cronômetro no Redmi |
| Pausa e retomada | pausa a qualquer momento; ao voltar, contagem 3-2-1 de 1,5 s para o jogador reposicionar o polegar | teste manual (14.2) |
| Controles confortáveis | 0 toques acidentais em botões durante o combate em 10 partidas de playtest | observação no playtest |
| Animação sem patinação nem tremor | 0 casos de "patinar", pivot pulando ou horda sincronizada na revisão em câmera lenta (8.7.3) | gravação em 120 Hz no Redmi |
| Horda sem empilhar nem tremer | 300 inimigos em volta do herói: tremor ≤ 1 px por frame; nenhum ponto com mais de 4 inimigos sobrepostos | overlay de debug + bot |
| Sem prender e sem atravessar | 0 inimigos presos > 3 s sem teletransporte; 0 projéteis atravessando alvos; herói nunca preso em quina | log do bot (8.7.3) em 1x, 2x e 3x |
| Movimento suave em 120 Hz | sem tremor visível do herói e da câmera com interpolação ligada | gravação em câmera lenta |

### 15.3 Níveis de dificuldade

Duas dimensões independentes: **modo base** (escolhido antes da partida) e **Lua Vermelha** (dificuldade extra opcional, já descrita em 4.11).

| Nível | Para quem | Modificadores | Meta de vitória na fase 1 |
|---|---|---|---|
| **Brisa** (história) | quem quer ver o enredo | dano inimigo −40%, +1 revive, ímã +50%; conquistas de "Lua" bloqueadas, o resto liberado | vence em 1–3 partidas |
| **Normal** | padrão | valores de 4.11 | vence entre a 3ª e a 6ª partida |
| **Lua Vermelha I–V** | veteranos | `lua_mult` de 4.11 (+HP, +velocidade, +ouro/XP) + 1 regra nova por nível: I mais elites; II chefes com 1 padrão extra; III Sombras também no claro; IV sem bolinhos de arroz; V Kami só oferece 2 pactos | taxa de vitória de quem já venceu o nível anterior: I 50%, II 40%, III 30%, IV 20%, V 10% |

Regras:
- **Curva dentro da partida:** a pressão cresce em ondas, não em linha reta. Depois de cada chefe há **20–30 s de respiro** (alvo de inimigos −50%), e o "cerco" e a "Procissão" (5.2) são picos curtos. Gráfico-alvo de intensidade por minuto em `docs/balance/intensity_curve.csv`, comparado com o medido pelo bot.
- **Curva entre fases:** a fase N+1 deve ser vencível por um jogador que venceu a fase N sem comprar nada a mais no Santuário, em ≤ 5 tentativas.
- **Sem ajuste escondido de dificuldade.** Em roguelites o jogador precisa sentir que mereceu. O único "ajuste" é sugerir o modo Brisa depois de 5 derrotas seguidas na mesma fase, com um texto gentil e sem penalidade.
- O nível escolhido aparece na tela de resultados e nas conquistas.

### 15.4 Balanceamento

Complementa as metas de 14.3.

| Critério | Meta | Como medir |
|---|---|---|
| Índice de pressão | `pressão = HP inimigo que chega por segundo ÷ DPS esperado do jogador` entre **0,6 e 1,1** em todo minuto; > 1,1 só em picos ≤ 30 s | simulação *headless* (abaixo) |
| Viabilidade das armas | toda arma base aparece em ≥ 15% das vitórias simuladas; nenhuma arma > 45% do dano médio (14.3) | simulação + telemetria dos playtests |
| Viabilidade dos heróis | taxa de vitória de cada herói a ±10 pontos percentuais da média | idem |
| Escolhas no level-up | nenhuma carta escolhida em > 80% das vezes em que aparece (escolha óbvia = escolha chata); nenhuma em < 5% (carta inútil) | telemetria de cartas oferecidas e escolhidas |
| Kami | cada pacto escolhido em 15–60% das vezes em que é oferecido | telemetria |
| Evoluções | toda evolução alcançável antes de 12:00 em ≥ 50% das partidas que a buscam (14.3) | simulação |
| Economia de ryō | 1ª partida (mesmo perdendo aos 5 min) rende o suficiente para **1 power-up**; Santuário completo em 25–35 h de jogo | simulação da economia em planilha |
| Escala de poder | DPS do jogador cresce ~×30–×60 do minuto 0 ao 15 numa build boa; HP dos inimigos cresce mais devagar no começo e mais rápido no fim, para o meio da partida ser o momento de domínio | simulação + gráfico DPS × HP |
| Recompensas por anúncio | no máximo ~25% do ryō diário de um jogador típico só com a Loja, e ~40% somando Reviver e Dobrar ryō (17.6); campanha completa só jogando, sem nenhum anúncio recompensado, em ≤ +15% de tempo em relação a quem usa a loja | simulação da economia com e sem loja |
| Causas de morte | nenhum inimigo comum é responsável por > 30% das mortes; chefes ≤ 35% | telemetria |

**Ferramenta de simulação:** `godot --headless -- --sim --runs=200 --speed=8 --seed=...` roda o bot de 14.4 com escolhas por heurística (aleatória, gananciosa por dano e "busca evolução") e gera `docs/balance/sim_<data>.csv`. Uma planilha lê o CSV e mostra os gráficos. **Toda mudança em `.tres` de balanceamento roda a simulação** antes do commit, e o CI compara com a rodada anterior (alerta se a taxa de vitória mudar mais de 10 pontos).

### 15.5 Progressão

**Dentro da partida (poder):**
- O jogador precisa **ver** a evolução da build: nível 1 = tela cheia de inimigos; minuto 12+ com build boa = "apagar a tela". Medir com o tempo médio de vida de um inimigo comum na tela (meta: de ~4 s no minuto 1 para < 1 s no minuto 13 numa build boa).
- Cada evolução tem efeito visual e sonoro novo, não só números maiores.

**Entre partidas (meta-progressão):**

| Tempo de jogo | Meta de desbloqueio |
|---|---|
| 1ª partida | sempre ganha algo: ryō para 1 power-up + 1 conquista fácil ("Primeiros Passos") |
| 0–2 h | algo novo a **cada partida** (arma, passivo, herói, Kami, entrada do Diário) |
| 2–10 h | algo novo a cada 2–3 partidas; fases 2 e 3 abertas |
| 10–25 h | Lua Vermelha, heróis restantes, fase 5 e final |
| 25–40 h | 100% das conquistas, fase secreta, Lua V |

Regras:
- **Nenhuma partida sem progresso** (pilar 4 de 1.4): mínimo de ryō por partida e progresso parcial de conquistas sempre visíveis.
- **"Próximo desbloqueio"** na tela de resultados: a conquista mais próxima de ser completada, com barra de progresso ("Faltam 312 abates para liberar Goro"). Ver um objetivo quase completo é o motivo mais honesto para jogar mais uma.
- A curva de desbloqueios fica numa planilha (`docs/balance/unlocks.csv`) com a hora estimada de cada um, validada contra a telemetria do playtest 2.
- Nenhum conteúdo de campanha fica preso só a moeda; quem joga bem desbloqueia por habilidade.

### 15.6 Diversão

A diversão é medida no playtest (14.5) e não se discute em teoria. Critérios por rodada:

| Critério | Meta | Como medir |
|---|---|---|
| "Mais uma partida" | ≥ 70% dos testadores começam outra partida **sem ser pedido** | observação |
| Vontade de voltar | nota média ≥ 4/5 em "Você jogaria de novo amanhã?" | questionário |
| Momentos marcantes | ≥ 3 "momentos uau" por partida vencida (evolução, baú de 5 itens, chefe derrotado, amanhecer) e testadores conseguem citar 1 de memória no dia seguinte | telemetria + pergunta de acompanhamento |
| Decisões interessantes | em ≥ 60% dos level-ups o testador hesita ou comenta a escolha | observação + pick rate (15.4) |
| Tédio | nenhum trecho de 2 min apontado como "chato" por mais de 1 em 5 testadores | questionário com linha do tempo da partida |
| Frustração | ≤ 1 em 5 testadores larga o celular irritado sem tentar de novo | observação |
| Descoberta | ≥ 10 segredos ou combinações (evoluções, uniões, fase secreta, conquistas escondidas) e testadores comentam ou perguntam sobre eles | observação |
| Retenção (teste fechado e lançamento) | D1 ≥ 35%, D7 ≥ 12%, D30 ≥ 5% (metas de referência para jogos premium/casuais de nicho) | estatísticas do Play Console, **sem SDK de analytics** |

**Regra do corte:** se um sistema falha em 2 rodadas seguidas de playtest (por exemplo, a Lanterna irrita mais do que tensiona), ele é simplificado ou cortado. Nada é sagrado, exceto os pilares de 1.4.

### 15.7 Som que chama atenção e faz voltar

O som é metade do "juice" de um survivors-like (1.2). Critérios para que ele seja **recompensador, legível e memorável**, sem cansar.

**Identidade sonora**
- **Motivo-assinatura** de 3–4 notas (do tema principal) usado em todo momento de recompensa: tela de título, level-up, baú, amanhecer e conquista. O jogador associa a melodia à recompensa e a reconhece fora do jogo, o que ajuda a lembrar do jogo e voltar.
- Cada evento importante tem um som **único e reconhecível**. Meta: num teste às cegas com 5 pessoas, ≥ 80% identificam pelo som qual evento ocorreu (level-up, baú, chefe chegando, HP baixo, ultimate pronto, Kami próximo).

**Recompensa (o "som de cassino" de 1.2, com moderação)**
- **Coleta de brasas:** o pitch sobe em escala musical (pentatônica japonesa, *in* ou *yo*) a cada brasa coletada em sequência; reinicia após 1,5 s sem coletar. Coletar muitas vira uma melodia.
- **Level-up:** *jingle* curto (≤ 1,2 s), tom maior, com o motivo-assinatura.
- **Baú:** tique-tique da roleta acelerando e fanfarra **proporcional ao prêmio**: 1 item (1,5 s), 3 itens (3 s), 5 itens (5 s com taiko e coral). O jogador precisa aprender a "ouvir" um baú bom.
- **Ultimate pronto:** sino curto e brilhante, uma vez. Não repetir até ser usado.
- **Tela de resultados:** contagem de ryō com moedas tilintando e um *sting* de "Novo recorde!" ou de "Desbloqueado!". Mesmo uma derrota termina com sons de ganho.

**Perigo e legibilidade**
- **Prioridade de áudio:** avisos de perigo (ataque de chefe, HP baixo, Sombra perto) nunca são descartados pelo limite de polifonia (9.3) e passam acima da mixagem com *ducking* de −4 dB nos outros sons.
- **HP < 25%:** batimento cardíaco + passa-baixa leve na música; some ao se curar. Dá tensão e a sensação de "por pouco".
- **Chefe chegando:** tambores 3 s antes da entrada, sempre o mesmo padrão.
- **Pensar no alto-falante do celular:** sons-chave com energia principal entre **1 e 4 kHz** (o alto-falante do celular quase não reproduz abaixo de ~200 Hz). Testar todo som-chave no alto-falante do Redmi **e** em fones.

**Conforto (para não cansar em 15 min)**
- Sons repetidos (acerto, abate) com 3–4 variações + pitch ±8% (9.3); nenhum som repetitivo apontado como "irritante" no playtest.
- **Loudness:** música em −16 LUFS integrado (±1); picos de SFX ≤ −1 dBTP; todas as faixas e SFX normalizados no mesmo padrão (medir com ffmpeg `loudnorm` ou Audacity).
- **Latência:** som do evento no mesmo frame ou no seguinte (≤ 33 ms de diferença percebida); ajustar `audio/driver/output_latency` e testar com fones Bluetooth (14.2).
- Volumes separados (música, efeitos, interface) e opção de reduzir sons de recompensa repetitivos (acessibilidade sensorial).
- Hápticos (7.6) acompanham os mesmos eventos com a mesma hierarquia.

**Fazer voltar sem manipular**
- O que traz a pessoa de volta é o motivo-assinatura, o "próximo desbloqueio" (15.5), o Desafio Diário e a Lua Vermelha, **não** pressão.
- Notificação local opcional, **desligada por padrão**, no máximo 1 por dia, só quando há um Desafio Diário novo: "A lanterna ainda queima. O desafio de hoje chegou."
- Proibido: energia/stamina, recompensa que se perde se não entrar no dia, contagem regressiva falsa, sons de alerta fora do jogo.

### 15.8 Ferramentas de qualidade (resumo)

| Área | Ferramenta |
|---|---|
| Código | gdtoolkit (`gdlint`, `gdformat`), gdUnit4, pre-commit, CI (GitHub Actions com Godot headless) |
| Performance | profiler e monitores do Godot, overlay de debug, bot de soak (14.4) |
| Balanceamento | simulação headless (15.4), planilhas em `docs/balance/`, telemetria local (14.3) |
| Diversão | roteiro de playtest e questionário em `docs/playtest/` |
| Áudio | Audacity / ffmpeg `loudnorm`, teste às cegas, teste no alto-falante do Redmi |
| Licenças | `check_licenses.py` (12.6) |

### 15.9 Portões de qualidade por marco

Um marco (13.1) só é considerado atingido quando todos os critérios marcados até ele passam.

| Marco | Critérios obrigatórios |
|---|---|
| **M0** | tipagem, lint, ADRs, checklist de PR, licenças (12.6) |
| **M1** | + testes das regras, arquitetura, laço sem alocação, orçamento de frame, latência e resposta do movimento, hitbox justa, ritmo inicial; playtest 1: "mais uma partida" ≥ 50% |
| **M2** | + 0 avisos em soak, dados sem números mágicos, save robusto, sem tempo morto, índice de pressão na fase 1, simulação de balanceamento rodando, sons-chave da fase 1 (brasas, level-up, baú, perigo) |
| **M3** | + determinismo, níveis de dificuldade, viabilidade de armas e heróis, curva de desbloqueios; playtest 2 com metas de diversão de 15.6 |
| **M4** | + todos os critérios de som (15.7), leitura de tela em todas as fases, controles confortáveis |
| **M5** | + 0 crash em 20 partidas, metas de 11.4, balanceamento de todas as Luas |
| **M6** | + crash < 0,5% e ANR < 0,2% no teste fechado; retenção D1/D7 medida e analisada |

---

## 16. Riscos e mitigação

| Risco | Prob. | Impacto | Mitigação |
|---|---|---|---|
| Performance com centenas de inimigos em GDScript | média | alto | arquitetura de 10.6 desde o dia 1; meta de 500 @ 60 fps no M1; plano B MultiMesh/C#/GDExtension |
| Pack não ter sprites para tudo (chefes, projéteis) | alta | médio | recolor + escala + desenhar 8–16 px à mão; inventário na fase 0 |
| Mistura de estilos ao adicionar assets de terceiros | média | alto | regra de ouro de 8.1; prancha de estilo antes de aceitar qualquer asset novo |
| Licença de asset mudar ou ser ambígua | baixa | alto | textos e snapshots baixados com data e hash (12.6.3); `check_licenses.py --online` antes de cada release; preferir CC0; evitar autores sem licença escrita |
| Violação de política do AdMob ou do Google Play (conta suspensa) | média | **muito alto** | formato App Open na abertura (não interstitial), só IDs de teste no desenvolvimento, nunca tocar nos próprios anúncios, UMP, Segurança dos dados correta, revisar as políticas antes de cada release |
| Anúncio de abertura derrubar a retenção e a nota | média | alto | sem anúncio na 1ª abertura, só no início a frio, intervalo mínimo de 4 h, tempo máximo de espera de 4 s; acompanhar D1/D7 e as avaliações e reduzir a frequência se cair (17.4) |
| Plugin AdMob incompatível com a versão do Godot | média | alto | prova técnica na Fase 0; `AdsManager` isola o plugin para trocar sem mexer no jogo |
| Animação "patinando" ou horda tremendo/empilhando (aparência amadora) | alta | alto | regras de 8.7, critérios de 15.2, revisão em câmera lenta no Redmi a cada fase do roadmap, validação de pivot no pipeline |
| Velocidade 3x derrubar o FPS ou causar bugs de colisão | média | médio | `GameClock` com passos fixos (sem *tunneling*), orçamentos por velocidade (11.4), redução automática 3x → 2x, teste de determinismo entre velocidades (15.1) |
| Bug no fluxo de reviver ou de compra (principal motivo de notas baixas do VS, 1.1) | média | alto | testes unitários e manuais dedicados (14.1, 14.2), recompensa gravada na hora, restauração automática de compras, testadores de licença no teste fechado |
| Reviver por anúncio deixar o jogo fácil demais | média | médio | 1× por partida, só depois do Revive do Santuário, fora do Desafio Diário; acompanhar a taxa de vitória com e sem reviver na simulação (15.4) |
| Receita baixa por pouco preenchimento em alguns países | média | médio | avaliar mediação depois do lançamento; considerar a compra "Remover anúncio de abertura" (17.6) |
| Tradução para 11 idiomas cara ou de baixa qualidade | alta | alto | ≤ 12 mil palavras, sem dublagem; profissional só em ja/zh/ko; revisão nativa nos demais; LQA no aparelho; congelamento do texto na Fase 3 (7.7.3) |
| Fontes CJK pesadas ou sem cobertura | média | médio | subconjunto por `strings.csv`; teste de cobertura de caracteres; fontes OFL escolhidas na Fase 0 (7.7.2) |
| Asset ou biblioteca entrar no build sem licença registrada | média | alto | `check_licenses.py` no pre-commit e nos testes falha o build; tela Licenças conferida na release |
| Mecânica da Lanterna atrapalhar a leitura da tela | média | médio | escuridão parcial (72%), raio generoso, opção de acessibilidade; validar no playtest 1 |
| Escopo grande para 1 pessoa | alta | alto | fases do roadmap com "pronto quando"; cortar para 3 fases/4 heróis se M3 atrasar > 3 semanas |
| Fadiga do gênero (muitos clones) | média | médio | tema yōkai, Lanterna, Kami e ultimate como diferenciais; vídeo da loja mostrando o amanhecer |
| Similaridade excessiva com VS (nomes, UI) | baixa | médio | nomes e arte próprios; mecânicas de gênero não são protegidas, mas evitar copiar textos, ícones e layout exatos |
| HyperOS matar o app em segundo plano | média | médio | save em `APPLICATION_PAUSED`; partida suspensa (10.11) |

---

## 17. Monetização: gratuito com anúncios

**Decisão:** o jogo é **gratuito para baixar e jogar**, e a receita vem de **anúncios**. São dois pontos de anúncio:

1. **Anúncio de abertura**: aparece ao abrir o jogo, antes de liberar o jogo.
2. **Loja de recompensas**: o jogador assiste a um anúncio recompensado e libera uma recompensa, que fica disponível de novo **a cada 6 horas**.
3. **Reviver e Dobrar ryō** (17.6): anúncios recompensados oferecidos **na morte** (reviver 1× por partida) e **nos resultados** (dobrar o ryō da partida).
4. **Compra "Remover anúncio de abertura"** (17.7): compra única para quem não quer ver o anúncio ao abrir o jogo.

Regras que valem para todo o resto: **nenhum anúncio interrompe uma partida em andamento** (o reviver só é oferecido quando o jogador já morreu, e é sempre opcional), e o jogo inteiro (campanha, heróis, final) **pode ser completado sem assistir a nenhum anúncio recompensado**. Os anúncios aceleram o progresso, mas não são obrigatórios para vencer.

### 17.1 Rede de anúncios e integração técnica

| Item | Decisão |
|---|---|
| Rede | **Google AdMob** (integração simples com o Play, formatos *App Open* e *Rewarded*). Mediação (AppLovin MAX, Unity Ads, etc.) pode ser avaliada depois do lançamento para aumentar o preenchimento |
| Plugin Godot | plugin AdMob para Godot 4 Android (ex.: **Poing Studios godot-admob**, MIT). Confirmar compatibilidade com Godot 4.6 na Fase 0 |
| Build | `gradle_build/use_gradle_build = on` (11.2), template Android customizado |
| Autoload | `AdsManager`: inicialização, consentimento, carregamento antecipado, exibição, timeouts, callbacks, modo de teste. O jogo só conversa com ele (nunca com o plugin direto), o que permite trocar de rede ou de plugin |
| Autoload | `ShopManager`: itens da loja, cooldowns, entrega de recompensas e persistência no save |
| Permissões | `INTERNET`, `ACCESS_NETWORK_STATE` e `com.google.android.gms.permission.AD_ID` (ID de publicidade, Android 13+) |
| Consentimento | **Google UMP** (User Messaging Platform) na primeira abertura: GDPR/UE, LGPD/Brasil e leis estaduais dos EUA. Se o jogador recusar, os anúncios continuam, mas **não personalizados** |
| Licenças | plugin (MIT) e **Google Mobile Ads SDK** (termos próprios do Google, `LicenseRef-Google-Mobile-Ads-SDK`) entram no registro e na tela Licenças (12.6) |
| Público | classificação 12+ (seção 2) e **não direcionado a crianças**. Se a Play Console indicar público misto, seguir a política *Famílias*: só SDKs certificados, sem anúncios personalizados para menores |
| Durante o desenvolvimento | **somente IDs de teste** do AdMob e o Redmi registrado como dispositivo de teste. **Nunca** tocar nos próprios anúncios reais, porque isso pode suspender a conta AdMob |

### 17.2 Anúncio de abertura ("liberar para jogar")

**Fluxo:**

```
Abrir o app (início a frio)
  → Splash + carregamento do jogo (o anúncio carrega em paralelo)
  → [1ª vez] tela de consentimento UMP
  → Anúncio App Open (tela cheia, com botão "Continuar para o app" do próprio formato)
  → Título → jogar
```

Regras:

- Formato **App Open** do AdMob, que é o formato feito para esse momento (sobre a tela de carregamento). Não usar *interstitial* na abertura, porque a política do AdMob desaconselha isso e há risco de violação.
- **Não aparece** para quem comprou "Remover anúncio de abertura" (17.7).
- Aparece **só no início a frio** (app aberto do zero). Voltar ao jogo depois de minimizar **não** mostra anúncio quando: estava no meio de uma partida, passou menos de **4 h** em segundo plano, ou o último anúncio de abertura foi há menos de 4 h. Assim, quem abre e fecha o jogo várias vezes não vê anúncio toda hora.
- **Tempo máximo de espera de 4 s** para carregar o anúncio. Se não carregar (sem internet, sem anúncio disponível, erro), o jogo **libera do mesmo jeito**. O jogo é jogável offline (1.1), e travar o jogador sem internet geraria avaliações de 1 estrela.
- **Primeira abertura de todas:** sem anúncio de abertura. A primeira impressão é a intro (3.2) e o tutorial. O anúncio de abertura começa na **2ª abertura**, o que protege a retenção do primeiro dia (15.6).
- Nada de anúncio ao sair do jogo, na tela de morte ou entre fases.

### 17.3 Loja de recompensas (anúncio recompensado a cada 6 h)

**Acesso:** Título → **Loja** (ícone com selo de "disponível" quando algum item está pronto). A loja também aparece como atalho na tela de Resultados.

**Funcionamento:**

- A loja tem **6 vagas** de recompensa. Cada vaga tem um botão **"Assistir anúncio"**.
- Ao assistir o anúncio **até o fim**, o jogador recebe a recompensa e aquela vaga entra em **espera de 6 h**, com contagem regressiva ("Disponível em 05:42:10").
- Cada vaga tem a **própria espera**. O jogador pode pegar as 6 de uma vez ou aos poucos. No máximo **6 anúncios recompensados a cada 6 h** (~24 por dia para quem pega tudo).
- Se fechar o anúncio antes do fim, não recebe a recompensa, a vaga continua disponível e aparece a mensagem: "Assista até o final para receber a recompensa".
- Se não houver anúncio disponível: botão desabilitado com "Sem anúncios no momento, tente mais tarde". A espera **não** é consumida.

**Vagas (valores iniciais; balancear em 15.4):**

| Vaga | Recompensa | Observação |
|---|---|---|
| 1. Saco de Ryō | +150 ryō (cresce com o progresso da campanha, até +400) | acelera o Santuário |
| 2. Bênção da Lanterna | próxima partida começa com luz +30% e ultimate carregado pela metade | vale por 1 partida |
| 3. Baú do Viajante | 1 Baú Laqueado aberto no início da próxima partida (1 melhoria) | sem evolução garantida |
| 4. Selos de Sorte | +2 Rerolar e +1 Pular para a próxima partida | aproveita o sistema de 4.4 |
| 5. Incenso de Brasas | +25% XP na próxima partida | |
| 6. Oferenda ao Kami | 1 **cosmético** aleatório (cor de lanterna, paleta de herói, rastro de brasas), sem efeito no jogo | cria coleção, sem pay-to-win |

- Recompensas de "próxima partida" **acumulam no máximo 1 de cada** e mostram um ícone na seleção de fase. O jogador escolhe usar ou guardar.
- **Limite de economia (15.4):** a Loja rende no máximo **~25% do ryō** que um jogador típico ganha jogando num dia. Toda conquista, herói e fase continua desbloqueável só jogando.
- Não há moeda paga. A única compra é "Remover anúncio de abertura" (17.7), que não dá vantagem no jogo.

**Relógio e trapaça (sem servidor):**

- Guardar no save o horário de liberação de cada vaga e o maior horário já visto. Se o relógio do aparelho **voltar** no tempo, manter a espera como estava (não libera antes).
- Se o relógio for **adiantado**, a espera termina antes. Como é um jogo single-player sem ranking competitivo de dinheiro, esse risco é aceito. Se no futuro houver ranking online, usar a verificação do lado do servidor do AdMob (SSV).
- A recompensa só é entregue no callback `on_user_earned_reward` do SDK e é salva **na hora** (antes de fechar o anúncio), para não se perder se o app for fechado.

**Tela da loja (paisagem):**

```
┌──────────────────────────────────────────────────────────────────────┐
│ ← Voltar              LOJA DO SANTUÁRIO                    ¥ 1.240   │
├──────────────────────────────────────────────────────────────────────┤
│ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌───┐│
│ │ Saco de  │ │ Bênção da│ │ Baú do   │ │ Selos de │ │ Incenso  │ │...││
│ │ Ryō +150 │ │ Lanterna │ │ Viajante │ │ Sorte    │ │ de Brasas│ │   ││
│ │ [▶ Ver]  │ │ 05:42:10 │ │ [▶ Ver]  │ │ 01:03:55 │ │ [▶ Ver]  │ │   ││
│ └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────┘ └───┘│
│  Assista a um anúncio para receber a recompensa. Cada uma volta em 6 h.│
└──────────────────────────────────────────────────────────────────────┘
```

- Cartões grandes (≥ 56 dp), contagem regressiva atualizada a cada segundo, animação e som de recompensa (15.7) ao receber.
- Notificação local opcional (15.7, **desligada por padrão**): "Suas recompensas da Loja estão prontas". No máximo 1 por dia.

### 17.4 Experiência e retenção

- Música em **mudo** durante qualquer anúncio e retorno suave do áudio depois (o SDK pausa o jogo, e o `AudioManager` respeita isso).
- O jogo **nunca** fica preso numa tela de anúncio: se o callback de fechamento não chegar em 60 s, o `AdsManager` libera a tela.
- Indicadores a acompanhar (Play Console + painel do AdMob, sem SDK de analytics extra):
  - retenção D1/D7/D30 (15.6). Se o anúncio de abertura derrubar a retenção, reduzir a frequência (ex.: só a cada 8 h);
  - % de jogadores diários que usam a loja (meta ≥ 30%) e anúncios recompensados por usuário por dia;
  - % de mortes em que o jogador aceita o reviver e % de resultados com ryō dobrado;
  - conversão da compra "Remover anúncio de abertura" (pelo relatório financeiro do Play Console);
  - eCPM e taxa de preenchimento por país;
  - nota média e avaliações que citam "anúncio".

### 17.5 Lojas, conta e políticas

- **Conta AdMob** ligada à conta do Google Play; pagamento configurado no AdMob.
- **`app-ads.txt`** publicado no site do desenvolvedor (o site precisa estar na página da loja), exigido para não perder receita.
- **Página da loja:** marcar "Contém anúncios".
- **Segurança dos dados (Play Console):** declarar o ID de publicidade e os dados coletados pelo SDK de anúncios (conforme a documentação do Google Mobile Ads).
- **Política de privacidade** real (deixa de ser "simples"), publicada num link e acessível em Opções → Sobre, explicando anúncios, ID de publicidade e consentimento, nos 11 idiomas (7.7).
- Em Opções: **"Privacidade e anúncios"**, que reabre o formulário de consentimento do UMP.

### 17.6 Reviver e Dobrar ryō (anúncios recompensados)

Os dois são **opcionais** e aparecem só quando o jogador já não está em combate.

**Reviver (1× por partida)**

```
Herói morre → jogo pausa → painel "A chama ainda tremula..."
   [▶ Reviver (anúncio)]        [Ver resultados]
   (contagem de 8 s; se acabar, vai para os resultados)
```

- Ao assistir até o fim: o herói volta com **50% do HP**, 3 s de invencibilidade e uma onda de luz que empurra os inimigos próximos (como o anel do level-up, 8.5). A partida continua de onde parou.
- **Uma vez por partida**, independente do Revive comprado no Santuário (4.10). Primeiro se gasta o Revive do Santuário; o anúncio só é oferecido quando não há mais nenhum.
- Se não houver anúncio disponível ou não houver internet, o painel **não aparece**: o jogo vai direto para os resultados (sem frustração de "botão que não funciona").
- Contagem de 8 s com botão "Ver resultados" grande. Nunca forçar o anúncio.
- **Disponível em:** Campanha e Noite Sem Fim, em todos os níveis de dificuldade. **Não disponível** no Desafio Diário (ranking justo).
- **Conquistas:** uma vitória com reviver por anúncio vale normalmente, **exceto** as conquistas de "sem morrer" (ex.: "Ilesa"). A tela de resultados mostra um pequeno ícone de chama quando houve reviver.
- Contra o Shinigami (Noite Sem Fim, 20:00): o reviver não é oferecido, porque ele é o fim natural da partida.

**Dobrar ryō (1× por partida)**

- Na tela de Resultados, depois da contagem de ryō: botão **"▶ Dobrar ryō (anúncio)"** ao lado de "Continuar".
- Dobra só o ryō **ganho naquela partida**, seja vitória ou derrota. A contagem anima de novo com o som de moedas (15.7).
- Se não houver anúncio, o botão some (não fica desabilitado sem explicação).
- O ryō dobrado é gravado na hora em que a recompensa é confirmada pelo SDK.

**Balanceamento:** com a loja (17.3), o reviver e o dobrar, o total que vem de anúncios fica em no máximo **~40% do ryō** que um jogador típico ganha por dia (15.4). Campanha, heróis e conquistas continuam alcançáveis sem nenhum anúncio recompensado.

### 17.7 Compra "Remover anúncio de abertura"

| Item | Decisão |
|---|---|
| Produto | compra **única e permanente** (*non-consumable*, produto `remove_open_ad` no Play Console) |
| Preço | baixo, sugestão **US$ 2,99 / R$ 9,90**, com **preço por região** do Play Console |
| O que faz | remove o **anúncio de abertura** para sempre. Os anúncios recompensados (Loja, Reviver, Dobrar) **continuam disponíveis**, porque são escolha do jogador e dão recompensas |
| Bônus | cosmético exclusivo "Lanterna Dourada" (sem efeito no jogo), como agradecimento |
| Onde comprar | botão na Loja (17.3) e em Opções → Privacidade e anúncios. Depois do 5º anúncio de abertura visto, uma oferta discreta **uma única vez** ("Prefere jogar sem o anúncio de abertura?") |
| Plugin | plugin oficial **Godot Google Play Billing** (MIT) ou o mais atual compatível com Godot 4.6. Confirmar na prova técnica da Fase 0. Entra no registro de licenças (12.6) |
| Autoload | `PurchaseManager`: consulta de produtos, compra, **confirmação (*acknowledge*)** da compra, restauração e reembolso |

**Regras técnicas:**

- **Confirmar toda compra** (*acknowledge*) logo após a entrega. Compras não confirmadas em 3 dias são reembolsadas automaticamente pelo Google.
- **Restaurar compras** ao abrir o jogo (consulta às compras do usuário): quem reinstala ou troca de aparelho recebe o benefício de volta sem fazer nada. Também há um botão "Restaurar compras" em Opções.
- Guardar o direito localmente (para funcionar offline) e revalidar com o Google Play quando houver internet. Se a compra for **reembolsada ou cancelada**, o anúncio de abertura volta.
- Estados de compra **pendente** (pagamento em dinheiro, boleto, etc.): mostrar "Pagamento pendente" e liberar só quando for confirmado.
- Sem servidor próprio na 1.0. A validação é feita pelo Google Play Billing no aparelho; risco de pirataria aceito, porque o produto só remove um anúncio.

**Página da loja e políticas:** marcar "Contém compras no app"; incluir as compras na Segurança dos dados e na política de privacidade (17.5); testar com **testadores de licença** do Play Console (compras de teste, sem cobrança real) antes do lançamento.

Nunca: energia/stamina, *pay-to-win*, anúncio no meio da partida ou anúncio que não pode ser fechado. As avaliações do VS mostram que bugs no fluxo de reviver e de compras derrubam a nota, então todo fluxo de anúncio tem teste dedicado (14.2).

---

## 18. Apêndices

### 18.1 Curva de alvo de inimigos (todas as fases)

`alvo(m) = round(15 + 22·m + 0,9·m²)` para m em minutos (0–15) → 15, 38, 63, 89, 117, 148 … ≈ 548 aos 15 min, limitado pelo teto do perfil de performance (500 padrão). Fases 2–5 aplicam um multiplicador (1,0; 1,05; 1,1; 1,2). A fase 1 usa a tabela ajustada à mão de 5.2 (mais suave, por ser a porta de entrada).

### 18.2 Tabela de níveis de uma arma (exemplo: Katana Crescente)

| Nível | Mudança |
|---|---|
| 1 | 10 dano, 1 corte à frente |
| 2 | +1 quantidade (corte atrás) |
| 3 | +5 dano |
| 4 | +10% área, +5 dano |
| 5 | +5 dano |
| 6 | +10% área, +5 dano |
| 7 | +5 dano |
| 8 | +10 dano |

### 18.3 Modelo de `ASSET_LICENSES.md` (gerado a partir de `licenses/registry.json`)

```markdown
| Componente | Arquivos | Origem (URL) | Autor | Licença | Baixado / verificado | Texto da licença | Snapshot | Modificações |
|---|---|---|---|---|---|---|---|---|
| Ninja Adventure | assets/art/actors/** | https://pixel-boy.itch.io/ninja-adventure-asset-pack | pixel-boy | CC0-1.0 | 2026-10-20 / 2026-10-20 | licenses/texts/CC0-1.0.txt | docs/licenses/ninja_adventure_2026-10-20.pdf | recolor do cabelo |
| Godot Engine 4.6.3 | (motor) | https://godotengine.org/license | Godot contributors | MIT | 2026-10-20 / 2026-10-20 | licenses/texts/MIT-godot.txt | docs/licenses/godot_2026-10-20.pdf | — |
```

### 18.4 Modelo de créditos

```
HYAKKI — Até o Amanhecer
Design, programação e direção: Clayton

Arte e áudio principal: Ninja Adventure Asset Pack — pixel-boy & AAA (CC0)
Partículas e sons de interface: Kenney (CC0)
Ícones: Henrique Lazarini / 7Soul1 (CC0)
Efeitos sonoros: SubspaceAudio / Juhani Junkala (CC0), rubberduck (CC0)
Música adicional: Tozan (CC0), SubspaceAudio (CC0)
Fonte: <nome> (SIL Open Font License)
Feito com Godot Engine (MIT) — godotengine.org/license
```

> A licença MIT do Godot exige incluir o aviso de copyright do motor no jogo. Isso é feito na tela **Licenças** (12.6.5), que gera essa parte automaticamente com `Engine.get_license_text()`, `Engine.get_copyright_info()` e `Engine.get_license_info()`.

### 18.5 Fontes da pesquisa

- Vampire Survivors na Google Play: https://play.google.com/store/apps/details?id=com.poncle.vampiresurvivors&hl=pt_BR
- Evoluções (wiki): https://vampire-survivors.fandom.com/wiki/Evolution
- Psicologia de design do VS (The Conversation): https://theconversation.com/vampire-survivors-how-developers-used-gambling-psychology-to-create-a-bafta-winning-game-203613
- Panorama de concorrentes: https://summerengine.com/blog/games-like-vampire-survivors
- Ninja Adventure (licença CC0 e conteúdo): https://pixel-boy.itch.io/ninja-adventure-asset-pack e devlog https://pixel-boy.itch.io/ninja-adventure-asset-pack/devlog
- 0x72 DungeonTileset II: https://0x72.itch.io/dungeontileset-ii
- Kaishido Cursed Realm: https://kaishido.itch.io/cursed-realm
- Trevor Pupkin bundle: https://trevor-pupkin.itch.io/roguelike-dungeon-asset-bundle
- Domin Dev weapon pack: https://domin-dev.itch.io/free-pixel-fantasy-weapon-pack
- CraftPix licença: https://craftpix.net/file-licenses/
- Kenney Particle Pack: https://kenney.nl/assets/particle-pack
- Pesquisa de assets complementares (20/10/2026): todos os links estão nas tabelas de 12.7.
- OpenGameArt: 496 ícones, 100 CC0 SFX, 512 SFX 8-bit, 5 Chiptunes, Oriental Somber (links em 12.3)
- Redmi Note 14 Pro+ (GSMArena): https://m.gsmarena.com/_redmi_note_14_pro+_5g_(global)-13612.php

