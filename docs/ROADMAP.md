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
| F | Sons escolhidos (IDs), clãs, mais modelos | ⏳ próximo |

"Código pronto" = passou na verificação de tipos e nos testes de lógica, mas ainda precisa do teste no Studio abaixo.

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
