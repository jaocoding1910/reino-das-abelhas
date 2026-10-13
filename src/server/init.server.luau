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
	"InventoryService", -- carga transportada x recursos depositados
	"ProgressionService", -- XP e nível
	"QuestService", -- missões em sequência
	"ResourceService", -- flores, favos, raridades, regeneração
	"HiveService", -- colmeias, entrega e construção de células
	"DropService", -- carga perdida no chão
	"HealthService", -- vida, derrota, renascimento, penalidade
	"UpgradeService", -- velocidade, capacidade, resistência
	"CharacterService", -- corpo de abelha, acessórios e spawn na colmeia
	"CosmeticService", -- compra/equipar acessórios
	"StateService", -- monta o estado que o HUD mostra
	"DayNightService", -- ciclo sincronizado
	"PredatorService", -- aranhas
	"CombatService", -- combate entre abelhas (zona de disputa)
})
