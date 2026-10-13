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
| F | Sons escolhidos (IDs), clãs, louva-a-deus, mais modelos | ⏳ próximo |

"Código pronto" = passou na verificação de tipos e nos testes de lógica, mas ainda precisa do teste no Studio abaixo.

## Roteiro de teste — Salto 8 (o que é novo)

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
