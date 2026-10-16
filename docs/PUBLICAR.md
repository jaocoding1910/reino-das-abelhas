# Publicar o Reino das Abelhas no Roblox

Um passo a passo para tirar o jogo do Studio e deixá-lo jogável num servidor de verdade, com salvamento ligado. Os nomes dos menus podem mudar um pouco entre versões do Studio e do Creator Hub.

## 1. Antes de publicar (no PC)

1. Abra o place e conecte o Rojo (`rojo serve` + Connect). O código precisa estar sincronizado: **o que vai para o Roblox é o que está no Studio**, não a pasta do PC.
2. Aperte F5 e confira se a Saída não tem nada vermelho começando com `[Abelhas` ou `ServerScriptService`.
3. **Modelos 3D:** confirme que existe `ReplicatedStorage → Assets → PacoteAbelhas` (veja `docs/MODELOS_3D.md`). Sem ele, o jogo usa as peças simples.
4. **Pare o teste** e só então publique.

## 2. Publicar

1. **Arquivo → Publicar no Roblox** (*File → Publish to Roblox*).
2. Escolha **criar uma experiência nova**, com o nome "Reino das Abelhas" (ou o nome em inglês que você escolher).
3. Gênero: **Simulação** ou **Aventura**. Dispositivos: PC, celular, tablet e console.

## 3. Configurações do jogo (no Studio: Início → Configurações do jogo)

| Onde | O que ligar | Por quê |
|---|---|---|
| Segurança | **Permitir acesso do Studio aos serviços de API** | Sem isso o salvamento não funciona, nem no Studio |
| Segurança | Permitir solicitações HTTP: **desligado** | O jogo não usa internet externa |
| Avatar | Tipo de avatar R15 (padrão) | O corpo é escondido e vira abelha de qualquer jeito |
| Permissões | Deixe **Privado** enquanto testa | Libere para o público só quando estiver pronto |

## 4. No Creator Hub (create.roblox.com → sua experiência)

1. **Tamanho do servidor:** em *Places* → o lugar → configurar, coloque o máximo de jogadores em **8**, porque o mapa tem 8 colmeias (`Config.Map.PlotCount`). Com mais gente, o 9º jogador fica sem colmeia.
2. **Questionário de maturidade:** responda ao questionário de conteúdo. Ele é obrigatório para deixar o jogo público. Não há violência realista nem compras no jogo.
3. **Ícone e miniaturas:** use prints do jogo (o tour da tecla T rende ótimas imagens).
4. **Descrição:** use o texto curto do final deste guia.

## 5. Sons (opcional, mas faz muita diferença)

Envie os 8 arquivos de `sons/` pelo Gerenciador de ativos e cole os IDs em `Config.Sounds`. O passo a passo está em `docs/SONS.md`. Depois **publique de novo**.

## 6. Testar o servidor de verdade

1. Na página do jogo, clique em **Jogar**. Agora é um servidor do Roblox, não o Studio.
2. O aviso **MODO TESTE** não pode aparecer. Se aparecer, o salvamento não está ligado (volte ao passo 3).
3. Ganhe mel, saia e entre de novo: o mel e as células voltam. A carga não volta, por regra.
4. Chame um amigo e teste os dois coletando a mesma flor: só um ganha.

## 7. Cada atualização

1. Mude o código no VS Code, com o Rojo conectado.
2. Teste no Studio (F5).
3. **Arquivo → Publicar no Roblox** de novo.
4. No Creator Hub, use **Reiniciar servidores** para todo mundo pegar a versão nova.

## Descrição curta para a página do jogo

> Seja uma abelha num reino gigante! Voe entre flores enormes, colete néctar e favos raros, construa sua colmeia célula por célula, fuja de aranhas e louva-a-deus à noite e cumpra os pedidos da Rainha. Junte-se a uma colônia, faça combos, corra pelos anéis até a Ilha nas Nuvens e conquiste o título de Rei ou Rainha da Colmeia. 🐝
