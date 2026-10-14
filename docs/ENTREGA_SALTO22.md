# Salto 22: ciclo completo guiado pelas 4 referências

Esta entrega executa o `PROMPT_COMPLETO.txt` sobre o projeto existente. Os sistemas que já existiam foram preservados. Nenhum serviço foi duplicado.

## 1. O que mudou

### Ciclo de jogo (servidor)

| Área | Mudança | Arquivos |
|---|---|---|
| Derrota | Regra única. Perde metade (para cima) de cada tipo carregado (`Config.Defeat.CargoLossFraction`). O que perde cai no chão para recuperar. Colmeia, melhorias e mel guardado ficam intactos. A tela lista o que caiu. A penalidade antiga na célula foi desligada. O botão Redefinir segue a mesma regra. A trava `dying` garante uma única aplicação. | `HealthService`, `InventoryService.TakeFraction`, `Types.SplitCargo` |
| Noite | Favos raros renascem 2× mais rápido. Cada favo raro **entregue** à noite vale +60 mel. O aviso antes de anoitecer já existia. | `ResourceService`, `HiveService`, `Config.DayNight` |
| Missões | A cadeia agora pede para **entregar** um favo raro (não só pegar) e depois cumprir um pedido da Rainha. | `Config.Quests`, `RoyalService` |
| Objetivo final | Título **Rei/Rainha da Colmeia**: nível 20, 24 células, 5 raros entregues e 3 pedidos da Rainha. O progresso real é a média das 4 metas. Vem com prêmio único (2.000 mel e a Coroa), fica salvo (`Crowned`) e aparece com 👑 na plaquinha. | `CrownService` (novo), `StateService`, `ClanService` |
| Tutorial | 7 passos: voar, coletar, entregar, abrir o painel, construir, **melhorar** e um passo final de leitura sobre a **área segura e a noite**. | `OnboardingController` |
| Predadores | Só detectam quem está **à vista**: terreno e cenário bloqueiam, e peças invisíveis e teias são ignoradas. O dano é recusado se o alvo já está em área protegida. | `PredatorBase.CanSee`, `PredatorService` |
| Movimento | Validação plausível de deslocamento: um salto impossível bloqueia a coleta por 2 s. A folga é grande, para não punir arrancada, anéis e poções. | `ResourceService`, `Config.Movement` |
| Dados | **Trava de sessão** no próprio perfil (`_Sessao`). Outro servidor espera até 30 s. Se a trava não sair, a pessoa entra sem salvar, e o perfil verdadeiro nunca é sobrescrito. Ao salvar, se outro servidor assumiu, este para de salvar. O autosave passou a ser a cada 60 s. Versão do perfil: 6. A migração é compatível e o namespace não mudou. | `PlayerDataService` |
| Modo teste | Sem DataStore (Studio sem API), o HUD mostra "⚠ MODO TESTE · progresso não é salvo". | `StateService`, `HUDController` |

### Visual e HUD (cliente)

| Área | Mudança | Arquivos |
|---|---|---|
| Primeira pessoa | **Viewmodel** com ombros peludos nos cantos e patas pretas segurando a carga: favo de cera, favo de mel âmbar, favo real violeta com moldura dourada ou gota de néctar. É local (dentro da Camera): não replica e não colide. Fica abaixo da mira e balança com o voo. Some em terceira pessoa. | `ViewmodelController` (novo), `CombArt` (novo) |
| Terceira pessoa | A abelha **segura a carga** entre as patas, e todos veem. | `CharacterService` |
| Abelhas | Todas viradas para a frente: jogador, operárias, mascotes e Rainha. A Rainha vira o rosto para quem chega. | `Config.Art.BeeYawDegrees`, `AssetLibrary`, `RoyalService` |
| Flores | Gotas de néctar brilhando nas 10 flores disponíveis mais perto (peças reaproveitadas). Contorno dourado no recurso mais perto (até 30 studs). | `VisualController` |
| HUD | Ação 2 virou **Construir** 🔨. Novo chip **👑 Objetivo: Rei/Rainha da Colmeia** (clique para ver as metas). Mochila com o peso e a perda de velocidade ("-12% vel"). Painel "próximo passo", combo, números flutuantes e confete. | `HUDController` |
| Configurações | Volume dos ambientes, efeitos, **sensibilidade do mouse**, **reduzir movimento** (sem FOV de velocidade, inclinação ou balanço) e qualidade **Alta/Média/Baixa**. | `OnboardingController`, `CameraController`, `AudioController` |

## 2. Validações realmente executadas (neste ambiente, sem Studio)

| Ferramenta | Resultado |
|---|---|
| StyLua 2.6 | ✅ código formatado |
| luau-lsp analyze (definições Roblox, sourcemap Rojo) | ✅ 0 erros, 0 avisos em `src/` |
| Rojo 7.7.1 build | ✅ `build/ReinoDasAbelhas_codigo.rbxlx` gerado do código final |
| Testes de lógica (luau) | ✅ divisão da carga na derrota (arredondamento, conservação, carga vazia, limites), geometria do hexágono, progresso do título, bônus do combo. Os testes antigos (missões, produção, diárias, conquistas, clima, configurações) também rodaram, mas sobre cópias antigas do código. |
| Selene | ❌ não rodou: precisa baixar a API do Roblox, e a internet deste ambiente bloqueia |
| Roblox Studio | ❌ não existe aqui. **Nada desta entrega foi executado no Studio.** Não há capturas reais, nem medição de FPS, nem teste com 2 clientes ou celular. |

Build passando não prova que o jogo funciona. O roteiro abaixo é o teste de verdade.

## 3. Operações que dependem da sua conta (lista única)

1. **Modelos 3D** (se ainda não fez): Importar 3D → `modelos3d/PacoteAbelhas.glb` → botão direito → Salvar em arquivo → `assets/PacoteAbelhas.rbxm` (detalhes em `docs/MODELOS_3D.md`). Sem isso, o jogo usa as peças geradas por código.
2. **Sons:** enviar os 8 `.wav` de `sons/` pelo Gerenciador de ativos e colar os IDs em `Config.Sounds` (`docs/SONS.md`). Sem IDs, o jogo roda em silêncio, sem erro.
3. **Salvamento:** Publicar no Roblox → Configurações do jogo → Segurança → "Permitir acesso do Studio aos serviços de API". Sem isso, o HUD mostra MODO TESTE.

## 4. O place

O zip **não traz mais** `ReinoDasAbelhas.rbxlx` na raiz, para não apagar o seu place nem os modelos importados nele. O place gerado do código fica em `build/ReinoDasAbelhas_codigo.rbxlx`. Para gerar de novo, use `scripts\build.ps1`. O fluxo normal continua `rojo serve` (porta 34872) + Connect.

## 5. Comparação honesta com as referências

| Referência | O que o jogo tem agora | O que ainda não chega lá |
|---|---|---|
| 01 Exploração diurna | 1ª pessoa com patas e favo segurado, rótulos "Favo de Cera · Comum", contorno de proximidade, castelo/Colmeia Real como marco, outras abelhas com nome e carga visível, HUD nível/missão/mel/favos/minimapa/ações 1-2-3 | Pelos realistas, profundidade de vale com camadas e cachoeiras na escala da arte (o mapa por código é mais simples), densidade de abelhas no céu |
| 02 Reino e início | Colmeia própria identificada, flores com gotas de néctar, girassóis, cogumelos, lago, logo na abertura, objetivo "Rei/Rainha da Colmeia %" | Andaimes de construção na árvore, áreas de clã marcadas no mapa, ilhas rochosas com a mesma riqueza |
| 03 Colmeia ao entardecer | Células com moldura dourada, vidro em construção com %, operárias nas células, lanternas, estandartes, painel Sua colmeia (Entregar/Expandir/Melhorar), área protegida | Materiais com textura (cera translúcida real), iluminação cinematográfica, painel com ícones desenhados |
| 04 Noite e predadores | NOITE · Perigo elevado, objetivo "Leve o favo raro para casa", favo raro violeta segurado na tela, aranha com teia, louva-a-deus, cogumelos e flores que brilham, vaga-lumes, lua, risco e recompensa diferentes à noite | Reflexos na água, orvalho nas pétalas, bioluminescência na intensidade da arte |

As referências são arte pronta. O jogo usa formas do Roblox e o pacote 3D próprio. Ele se aproxima na composição, nas cores e na leitura, não pixel a pixel.

## 6. Limitações que continuam

- O mapa (`MapBuilder`) não foi recomposto nesta entrega: o vale, as cachoeiras e as pontes continuam como estavam. Recompor exige ver o resultado no Studio a cada passo.
- As metas de 60 FPS no PC e 30 no celular não foram medidas.
- A trava de sessão protege contra sobrescrita, mas só foi verificada pelo tipo e pela lógica, não com dois servidores reais.
- O áudio depende do envio dos sons (item 2 da lista).
