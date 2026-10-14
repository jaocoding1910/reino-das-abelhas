--[[
	Bootstrap do servidor (ServerScriptService.Server).

	Ordem de inicialização dos serviços. Para adicionar um serviço:
	1. Crie src/server/Services/NomeService.luau (copie um existente).
	2. Coloque o nome na lista abaixo, depois das dependências dele.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Loader = require(Shared.Util.Loader)
local Remotes = require(Shared.Remotes)

Remotes.Setup()

Loader.Run("Servidor", script.Services, {
	"PlayerDataService", -- perfil e DataStore (primeiro: outros leem o perfil)
	"WorldService", -- monta o mapa
	"RegionService", -- em que região cada abelha está
	"ClanService", -- colônias (clãs): nome, bônus de mel, sem fogo amigo
	"InventoryService", -- carga transportada x recursos depositados
	"ProgressionService", -- XP e nível
	"QuestService", -- missões em sequência (e progresso do pedido da Rainha)
	"RoyalService", -- Rainha Abelha e pedidos especiais
	"DailyRewardService", -- recompensa diária com sequência
	"AchievementService", -- conquistas (contadores do perfil)
	"PetService", -- mascotes (abelhinhas que seguem você)
	"ResourceService", -- flores, favos, raridades, regeneração
	"HiveService", -- colmeias, entrega e construção de células
	"DropService", -- carga perdida no chão
	"HealthService", -- vida, derrota, renascimento, penalidade
	"UpgradeService", -- velocidade, capacidade, resistência
	"CharacterService", -- corpo de abelha, acessórios e spawn na colmeia
	"CosmeticService", -- compra/equipar acessórios
	"CrownService", -- objetivo de longo prazo: Rei/Rainha da Colmeia
	"StateService", -- monta o estado que o HUD mostra
	"DayNightService", -- ciclo sincronizado
	"PredatorService", -- aranhas e louva-a-deus
	"LeaderboardService", -- praça do centro: ranking de mel e fonte
	"MerchantService", -- Besouro mercador: poções e trocas
	"PollenEventService", -- evento: chuva de pólen (flores douradas)
	"WeatherService", -- clima: limpo, chuva, neblina
	"BossService", -- Vespa Gigante (chefe à noite)
	"TutorialService", -- primeiros passos e configurações salvas
	"RaceService", -- anéis de impulso e corrida até a Ilha nas Nuvens
	"ChestService", -- baús do tesouro
	"CodeService", -- códigos de recompensa
	"CombatService", -- combate entre abelhas (zona de disputa) e na vespa
	"DevCommandService", -- comandos de teste no chat (só no Studio)
})
