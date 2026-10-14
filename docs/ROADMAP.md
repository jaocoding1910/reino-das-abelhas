# Roadmap

| Etapa | Entrega | Status |
|---|---|---|
| 0 | Estrutura Rojo, Config, Remotes, Loader | ✅ rodou no Studio |
| A | Voo, câmera, mapa, coleta, entrega e construção | ✅ rodou no Studio |
| B | Três raridades, peso da carga, melhorias | ✅ código pronto |
| C | Dia/noite, aranha, vida, derrota e renascimento | ✅ código pronto |
| D | Combate entre abelhas e carga perdida | ✅ código pronto |
| E | Salvamento, XP/nível, acessórios, HUD final | ✅ código pronto (falta som) |
| Salto 8 | Missões, mel passivo, especialidades, modelos 3D próprios, voo com inclinação e arrancada, painel com abas, animações, partículas de ambiente, sons configuráveis | ✅ código pronto |
| Salto 9 | Parede de favos brilhante (moldura dourada, cera, vidro em construção), fachada com arco, estandartes vermelhos com coroa, lanternas, pisca-pisca, caixotes de cera, abelhas operárias voando, noite roxa com lua grande e flores acesas | ✅ código pronto |
| Salto 10 | Louva-a-deus (bote com aviso), abelhinhas dentro das células, mel escorrendo, janelas/varandas/raízes nas árvores-colmeia, trilha dourada até o objetivo (G) | ✅ código pronto |
| Salto 11 | Rainha Abelha com pedidos especiais, recompensa diária (7 dias), colônias (clãs) com bônus e sem fogo amigo, praça central com fonte de mel e ranking (servidor + global), 8 sons próprios | ✅ código pronto |
| Onda 1 | Besouro mercador (poções e trocas), chuva de pólen (flores douradas 3×), 12 conquistas com prêmio, mascotes que voam com você | ✅ código pronto |
| Onda 2 | Clima (chuva/neblina), Caverna de Cristal, Lago das Libélulas (predador novo), colmeia que evolui (4 níveis), Vespa Gigante (chefe cooperativo à noite) | ✅ código pronto |
| Onda 3 | Tela de abertura com JOGAR, tutorial com a Rainha, configurações (P / ⚙), qualidade baixa para celular | ✅ código pronto |
| Salto 20 | Câmera atrás da abelha (V), Renascer, operárias contratadas, melhorias Sorte e Fôlego, missões diárias, códigos, baús do tesouro, anéis de impulso, corrida até a Ilha nas Nuvens, Ilha nas Nuvens, flor arco-íris, borboletas, plaquinha com nível/⭐, bônus de amigos, ícones no minimapa, 3 acessórios novos, 4 conquistas, ⭐ no ranking, comandos de teste | ✅ código pronto |
| Salto 24 | Gráficos: montanhas altas e castelo sempre visíveis (modelos Persistent no streaming), névoa mais leve, iluminação Future com sombras suaves, água turquesa com reflexo, andaimes com escada, roldana e balde nas colmeias, trilhas de terra até colmeias/castelo/lago/caverna, campo com flores do tamanho da abelha, lavandas e tufos de grama | ✅ código pronto (não rodou no Studio) |
| Salto 23 | Paisagem da referência: cordilheira no horizonte, colinas, 2 grupos de penhascos com casinhas de favo, lanternas, pontes de corda e cachoeiras com lago; cores mais vivas e fundo desfocado; pirueta lateral (duplo toque em A/D) | ✅ código pronto (não rodou no Studio) |
| Salto 22 | Ciclo completo do PROMPT_COMPLETO: derrota única (metade da carga cai), noite com risco e recompensa, objetivo Rei/Rainha da Colmeia, tutorial de 7 passos, patas e favo na 1ª pessoa, carga visível no corpo, gotas de néctar, contorno de proximidade, predadores com linha de visão, trava de sessão do perfil, validação de deslocamento, sensibilidade/reduzir movimento/qualidade média (ver `docs/ENTREGA_SALTO22.md`) | ✅ código pronto (não rodou no Studio) |
| Salto 21 | Abelhas de frente (jogador, operárias, mascotes, Rainha), Rainha vira o rosto para quem chega, painel "próximo passo" no topo, entrega automática no pote, combo de coleta (até x5), números flutuantes (+3 🌼 / +40 🍯), confete ao subir de nível, coleta mais rápida, tecla H (tela limpa) | ✅ código pronto |

"Código pronto" = passou na verificação de tipos e nos testes de lógica, mas ainda precisa do teste no Studio abaixo.

## Roteiro de teste — Salto 24

1. **Horizonte:** suba alto. Montanhas com neve em volta do vale e a Colmeia Real visível de longe.
2. **Iluminação:** lanternas e janelas iluminam o entorno de verdade (Future), e as sombras ficam suaves.
3. **Colmeias:** andaimes dos dois lados da parede de favos, com tablados, blocos de cera, escada e balde de mel pendurado.
4. **Trilhas:** caminhos de terra saem da praça até cada colmeia, até o castelo, o lago e a caverna.
5. **Campo:** flores do tamanho da abelha, lavandas roxas e tufos de grama (Qualidade Baixa esconde).
6. **Água:** lagos azul-turquesa com reflexo.
7. **FPS:** compare com antes. Se cair muito, use Qualidade Média/Baixa (P).

## Roteiro de teste — Salto 23

1. **Horizonte:** de qualquer colmeia, olhe em volta. Montanhas azuladas fecham o vale, e o castelo (Colmeia Real) fica na frente delas.
2. **Penhascos:** voe para oeste e para leste (veja no minimapa) até os pilares de pedra com casinhas de favo, janelas acesas, lanternas e pontes de corda. A cachoeira cai do pilar mais alto num laguinho.
3. **Noite** (`/noite`): as janelas das casinhas brilham.
4. **Voar de lado:** A/D deslizam para o lado. **Duplo toque rápido em A ou D** = pirueta de 360° com dash (gasta 20 de fôlego).
5. **Desempenho:** o servidor demora um pouco mais para montar o terreno. Observe se o Play começa normal e se o FPS continua bom.

## Roteiro de teste — Salto 22 (perfil novo)

Para começar com perfil novo no Studio sem API, cada Play já é um perfil novo (MODO TESTE).

1. **Tutorial:** os 7 passos da Rainha até "Tutorial concluído" (+100 mel).
2. **Primeira pessoa:** ombros peludos nos cantos de baixo. Pegue néctar: as patas sobem segurando uma gota dourada. Pegue um favo: aparece o favo (cera, âmbar ou violeta). A mira continua livre.
3. **V:** a abelha aparece de costas, segurando a carga. Outro jogador também vê.
4. **Flores:** gotas brilhando nas flores disponíveis. O recurso mais perto ganha contorno dourado.
5. **Mochila:** encha a carga. O chip mostra "-N% vel" e o voo fica mais lento. Entregue no pote (automático).
6. **Construir:** a tecla 2 (Construir) abre o painel. Expanda uma célula e compre cada melhoria.
7. **Noite** (`/noite`): o HUD fica em NOITE · Perigo elevado. Pegue um favo raro (caverna/torres) e entregue: "+60 mel extra".
8. **Derrota:** deixe a aranha te pegar com carga. A tela lista o que caiu (metade). Você renasce na colmeia com escudo e a outra metade continua na mochila. O que caiu está no chão.
9. **Predador e morro:** atrás de um tronco/morro, a aranha não te vê. Na área verde ninguém te acerta.
10. **Objetivo 👑:** clique no chip de baixo à direita: aparecem as 4 metas com números reais. Teste rápido: `/xp 99999` faz a meta de nível ficar ✅.
11. **Configurações (P):** sensibilidade muda o mouse na hora. Reduzir movimento tira a inclinação e o FOV. Qualidade Média/Baixa.
12. **Publicado:** saia e entre. O mel e as células voltam, e a carga não (por regra).
13. **Sessão de 20–30 min:** observe a Saída (nada vermelho começando com `[Abelhas`) e o FPS (Ctrl+Shift+F5 no Studio).

## Roteiro de teste — Salto 21

1. **Abelha de frente:** aperte **V**. Você vê as costas e o ferrão da sua abelha, e ela voa com a cabeça para a frente. As asas batem perto do corpo.
2. **Operárias e mascote:** voam com a cabeça para onde vão.
3. **Rainha:** chegue pela frente do trono e ande de um lado para o outro: ela vira o rosto para você.
4. **Próximo passo:** o painel embaixo do relógio diz o que fazer ("🌼 Siga a trilha dourada e segure E na flor"). Com a mochila cheia, fica laranja.
5. **Combo:** colete flores uma atrás da outra (menos de 10 s entre elas). Aparece "🔥 COMBO x2… x5" em cima da vida, com +1 néctar por degrau.
6. **Números:** "+3 🌼" sobe da flor; na entrega aparece "+N 🍯 mel" grande no pote.
7. **Entrega automática:** com carga, voe até o pote da sua colmeia. A entrega acontece sozinha, sem apertar nada.
8. **Confete:** suba de nível (`/xp 3000`) ou complete uma missão.
9. **Tela limpa:** aperte **H** para esconder a interface e **H** de novo para voltar.

## Roteiro de teste — Salto 20

**Comandos de teste (só no Studio, digite no chat):** `/mel 5000`, `/xp 3000`, `/noite`, `/dia`, `/chuva`, `/neblina`, `/limpo`, `/vespa`, `/polen`, `/arcoiris`, `/ajuda`.

1. **Câmera:** aperte **V** → câmera atrás da sua abelha (o mouse continua girando a câmera). V de novo volta à primeira pessoa. Também nas Configurações.
2. **Anéis e corrida:** na praça, do lado da fonte, o anel "🏁 LARGADA". Atravesse: impulso de velocidade, o próximo anel fica azul e aparece "🏁 1/12 · 3,2 s" no canto direito. Siga até a "🏁 CHEGADA" na Ilha nas Nuvens: tempo, recorde e +120 mel.
3. **Ilha nas Nuvens:** ilha flutuante com nuvens e 8 flores que dão 2× néctar (☁️ no minimapa).
4. **Baús do tesouro:** 10 baús com brilho dourado (um na caverna, um no lago, um na ilha, o resto espalhado). E → mel aleatório e às vezes poção. Depois de aberto, volta em 20 min.
5. **Flor arco-íris:** `/arcoiris` → aviso, uma flor com as cores girando, a trilha leva até ela; 8× néctar.
6. **Missões diárias:** tecla 2 → aba **Diárias**: 3 missões do dia com barra; ao completar, o mel entra sozinho.
7. **Operárias:** aba Colmeia → "Contratar operária": +3 mel/min e mais abelhas voando na sua colmeia.
8. **Renascer:** `/xp 3000` e `/mel 5000` → aba Colmeia → "⭐ Renascer" (clique duas vezes). Colmeia volta ao início e ganha +25% de mel para sempre; a plaquinha mostra ⭐1.
9. **Melhorias novas:** aba Abelha agora tem 5: Velocidade, Capacidade, Resistência, **Sorte** (🍀 coleta em dobro) e **Fôlego** (barra de arrancada maior).
10. **Códigos:** Configurações (P) → Código → `BEMVINDO`, `ZUMBIDO`, `ASAS`, `FAVODEMEL`.
11. **Acessórios novos:** aba Visual → Coroa dourada, Auréola de luz, Laço rosa.
12. **Plaquinha:** com 2 jogadores, em cima da abelha do outro: "[Colônia] Nome" e "Nv X · ⭐N".
13. **Borboletas** coloridas voando pelo campo.
14. **Minimapa:** ícones do Besouro 🐞, caverna 💜, lago 💧 e ilha ☁️.

## Roteiro de teste — Ondas 2 e 3

**Atenção:** o `default.project.json` mudou (tela de abertura em ReplicatedFirst). Reinicie o `rojo serve` (Ctrl+C e rode de novo) e reconecte no Studio.

1. **Abertura:** ao dar Play, tela cor de mel com favos flutuando, a abelha e "REINO DAS ABELHAS". Depois de carregar aparece **JOGAR**.
2. **Tutorial:** perfil novo (no Studio sempre): cartão da Rainha embaixo, 5 passos que avançam sozinhos. No fim: +100 mel. "Pular" fecha.
3. **Configurações:** botão ⚙ ao lado do relógio (ou **P**): música, efeitos, trilha, inclinar câmera e qualidade. "Baixa" tira pólen, vaga-lumes, flores de enfeite e abelhas operárias.
4. **Clima:** a cada 2,5–4,5 min pode chover (riscos de chuva, céu cinza, relógio "🌧️ Chuva") ou dar neblina (🌫️). Teste rápido: `MinDuration = 20, MaxDuration = 30` em `Config.Weather`.
5. **Caverna de Cristal:** no bosque a oeste (siga a placa roxa): domo de pedra com cristais acesos e favos raros/médios dentro. Conquista "Exploradora".
6. **Lago das Libélulas:** no bosque a leste: água, vitórias-régias, juncos e 2 libélulas azuis. Chegue perto: ela para, "!" e dá um rasante reto — desvie.
7. **Colmeia que evolui:** 5 células = potes gigantes; 12 = coroa dourada no arco; 24 = aura de brilhos; 37 = feixe de luz e "COLMEIA LENDÁRIA".
8. **Vespa Gigante:** 20 s depois de anoitecer, aviso e barra vermelha no topo. Vá à Colmeia Real e clique perto dela (até 18 studs) para atacar. Ela avisa ("!") e mergulha. Derrotada: +400 mel para quem ajudou. Teste rápido: `DayDuration = 60, NightDuration = 90`.

## Roteiro de teste — Onda 1

Dica: para testar compras, em `src/shared/Types.luau` (função `NewProfile`) troque `Honey = 0` por `Honey = 2000` e depois volte.

1. **Besouro mercador:** na praça do centro, ao lado da fonte: besouro verde brilhante com chapéu, carrinho de poções e a placa "🐞 POÇÕES & TROCAS". E → loja.
   - Compre a **Poção de Velocidade**: aparece o chip "⚡ 2:59" embaixo da região e você voa mais rápido. Comprar de novo soma tempo.
   - **Mochila Extra**: a carga passa de 10 para 16. **Néctar em Dobro**: cada flor dá o dobro.
   - **Trocas**: com 5 favos de cera na carga, "Trocar" vira 70 mel (o botão fica dourado quando dá).
2. **Chuva de pólen:** 2 minutos depois de começar (depois a cada 7 min): aviso "🌟 Chuva de pólen!", pontinhos dourados caindo do céu e 8 flores com o miolo dourado brilhando. Coletar nelas: "🌟 +9 néctar dourado!". A trilha dourada aponta para a flor dourada mais perto. Dica: `FirstPollenAfter = 20` no Config para testar rápido.
3. **Conquistas:** tecla 2 → aba **Medalhas** (12, com barra de progresso). Ao coletar o primeiro néctar: faixa roxa "CONQUISTA: 🌼 Primeiro gole" e +20 mel.
4. **Mascotes:** tecla 2 → aba **Visual** → "Abelhinha Dourada · 300 mel". Ela voa à sua direita, na frente. Clique de novo para guardar. Com 2 jogadores, um vê a mascote do outro.

## Roteiro de teste — Salto 11

1. **Recompensa diária:** ~6 s depois de entrar aparece o calendário de 7 dias com "HOJE" e "Receber +50 mel". No Studio sem publicar aparece toda vez (o perfil não é salvo).
2. **Praça do centro:** voe até o meio das colmeias: praça redonda, fonte jorrando mel e o painel "🏆 Mais mel · este servidor". Do outro lado: "🌍 Recordes" (só funciona publicado; no Studio mostra o aviso).
3. **Rainha:** siga o 👑 até a Colmeia Real. Na frente do salão: trono dourado, tapete vermelho e a Rainha Melissa (abelha grande com coroa e capa). Aperte E em "Falar com a Rainha" → "Aceitar pedido". Aparece a linha "👑 Rainha: … (0/X)" embaixo da missão. Cumpra, volte e "Receber recompensa". A trilha dourada leva até ela quando o pedido fica pronto.
4. **Colônias:** tecla **3** → digite um nome → "Fundar · 100 mel". Com 2 jogadores: o segundo vê a colônia na lista → "Entrar". Os dois ganham "+10% de mel" nas entregas, aparece "[Nome] Jogador" em cima da abelha e na zona de disputa um não consegue atacar o outro.
5. **Sons:** siga `docs/SONS.md` para enviar e colar os IDs.

## Roteiro de teste — Salto 10

1. **Trilha dourada:** logo ao nascer, uma linha em arco sai da sua abelha até a flor mais perto com néctar, com "👇 Néctar · X m". Com a carga cheia, ela aponta para o pote. **G** liga/desliga.
2. **Abelhinhas nas células:** dentro de parte das células prontas, abelhas pequenas andando de lado e virando.
3. **Mel escorrendo:** gotas caindo de algumas células.
4. **Árvores-colmeia por fora:** janelas redondas (âmbar de dia, acesas à noite), varandinhas com parapeito e raízes grossas.
5. **Louva-a-deus:** no bosque, em cima de cogumelos (fora da área protegida). Chegue a ~35 studs: ele ergue os braços, olhos vermelhos e "!". **Mude de lugar** durante o aviso: o bote vai onde você estava e erra. Ficando parado, leva 25 de dano.
6. Saída: "X aranhas e Y louva-a-deus no bosque".

## Roteiro de teste — Salto 9 (visual da referência)

1. **Sua colmeia:** arco de madeira com friso dourado e luzinhas em volta da parede de favos; estandartes vermelhos com 👑 nos pilares; postes com lanterna na frente; caixotes com blocos de cera.
2. **Células:** prontas = moldura dourada, fundo cor de mel brilhando e blocos de cera dentro. Em construção = vidro claro com o cartão "Construção X%" e barra. Próxima = contorno transparente.
3. **Abelhas operárias:** 3 por árvore pairando na frente dos favos, voando até as flores e voltando; um enxame girando na Colmeia Real.
4. **Noite** (dica: `DayDuration = 60`, `NightDuration = 40` no Config): céu roxo com lua grande e estrelas, lanternas acesas, pétalas internas das flores brilhando, cogumelos neon. De manhã tudo volta às cores normais.
5. **Pontes:** pisca-pisca nas cordas.
6. **HUD:** 🍯 no chip de Mel e 🌼 no de Néctar.

## Roteiro de teste — Salto 8

1. **Voo:** voe para a frente e vire o mouse: a câmera e o corpo **inclinam** na curva; ao acelerar, o campo de visão abre.
2. **Arrancada:** segure **Shift** voando. Aparece a barra azul "Fôlego", riscos de vento passam pela tela; soltando, o fôlego volta.
3. **Missão:** topo esquerdo mostra "MISSÃO", o texto, a barra x/y e "+mel". Ao completar: faixa verde **MISSÃO CONCLUÍDA!** desce do topo.
4. **Coleta:** ao coletar, bolinhas douradas **voam até você**; o chip de Néctar/Favos pulsa.
5. **Nível:** ao subir de nível, faixa dourada **SUBIU DE NÍVEL!**, anel de luz e o selo pulsa.
6. **Mel:** ao ganhar mel, o número **sobe contando** e aparece "+N" ao lado.
7. **Painel (tecla 2):** desliza da direita, com abas **Colmeia · Abelha · Visual**.
   - Colmeia: células, "Mel fabricado na colmeia" (sobe sozinho com células prontas) e **Recolher** (perto da sua árvore).
   - Abelha: 3 melhorias e as 3 especialidades (a primeira é grátis; trocar custa 100 mel).
   - Visual: acessórios.
8. **Minimapa:** sua colmeia agora é um hexágono dourado (antes aparecia um quadradinho); você é a bolinha laranja com bico.
9. **Ambiente:** pólen flutuando de dia, vaga-lumes piscando à noite, florzinhas coloridas no chão do campo e cogumelinhos roxos no bosque.
10. **Chat:** deve ficar embaixo à direita (se continuar no topo, me avise com um print).
11. **Modelos 3D:** importe o pacote (`docs/MODELOS_3D.md`) e veja abelha, flores, girassóis, cogumelos, árvores e cristais trocarem.

## Roteiro de teste — 1 jogador

1. **Nascer:** você aparece na frente da sua árvore-colmeia, com escudo 🛡 na barra de vida (proteção de 8 s).
2. **HUD:** selo de nível 1, missão, Mel/Favos/Néctar, chip verde "Área protegida", minimapa com a colmeia e 👑.
3. **Coleta:** segure E numa flor (+3 néctar, +XP) e num favo de cera.
4. **Entrega:** aperte **2** → "Entregar favos" perto do pote, ou segure E no pote.
5. **Construção:** com 50 de mel, **2** → "Expandir". Entregue favos até 100%.
6. **Melhorias e acessórios:** abas Abelha e Visual do painel. Compre os Óculos (150 mel) e veja no corpo da abelha (2 jogadores).
7. **Bosque:** voe para longe do centro; o chip fica laranja "Bosque • predadores".
8. **Aranha:** chegue perto de uma teia. A aranha persegue; antes do golpe aparece "!" vermelho. Fuja voando alto (ela só sobe ~28 studs).
9. **Derrota por aranha:** deixe ela te derrotar com uma célula em construção. Esperado: tela "Você foi derrotado", carga no chão ("Carga perdida"), célula perdeu 5 pontos UMA vez, renasce na colmeia em 5 s.
10. **Colmeia Real:** siga o 👑 no minimapa. Palácio dourado com cachoeiras, favos raros nas torres, chip vermelho "Zona de disputa".
11. **Noite:** em `Config.luau` use `DayDuration = 60` e `NightDuration = 40`. À noite: céu violeta, cogumelos brilhando, aranhas mais rápidas.

## Roteiro de teste — 2 jogadores (Teste → Clientes e servidores → 2 jogadores)

- [ ] Os dois correm para o mesmo favo e seguram E juntos: **só um recebe**, o outro vê "Outra abelha chegou primeiro!".
- [ ] Jogador 2 tenta entregar/construir na colmeia do jogador 1: recusado ("Essa colmeia não é sua").
- [ ] No campo/colmeias, clique para atacar: recusado ("Combate só na zona de disputa").
- [ ] Na Colmeia Real, um ataca o outro: dano aparece, ao zerar a carga cai **uma vez** e o vencedor pode recolher.
- [ ] Atacar logo após nascer cancela o próprio escudo; atacar quem acabou de nascer não causa dano.
- [ ] A aranha não entra no campo protegido nem ataca quem tem escudo.
- [ ] Os acessórios de um aparecem para o outro.

## Salvamento (precisa publicar)

1. Arquivo → **Publicar no Roblox**.
2. Configurações do jogo → **Segurança** → ligar **Permitir acesso do Studio aos serviços de API**.
3. Jogue, ganhe mel, pare o teste, jogue de novo: o mel e as células voltam; a carga não.
4. Sem o passo 2, o jogo avisa que a sessão não será salva (e não apaga nada).

## Ideia futura (não implementada)

**Vidas de expedição:** algumas vidas que recarregam com o tempo; sem vidas, o jogador continua na base (construir, personalizar). Não combinar com a penalidade de construção atual sem rebalancear.
