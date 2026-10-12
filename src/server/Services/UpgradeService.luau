--[[
	UpgradeService (servidor) — Etapa B

	Melhorias compradas com mel: Velocidade, Capacidade e Resistência.

	- O cliente só pede "quero comprar X" (RemoteEvent RequestUpgrade).
	- O servidor confere: nome válido, nível máximo, mel suficiente
	  e frequência de pedidos. O custo é sempre calculado aqui.
	- Custo cresce a cada nível: BaseCost × CostGrowth ^ nível.
	- Nenhuma melhoria passa de MaxLevel (a abelha nunca fica invencível).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Remotes = require(Shared.Remotes)

local InventoryService = require(script.Parent.InventoryService)
local Notifier = require(script.Parent.Parent.Lib.Notifier)
local PlayerDataService = require(script.Parent.PlayerDataService)

local UpgradeService = {}

local lastRequest: { [Player]: number } = {}

function UpgradeService.Cost(name: string, level: number): number
	local info = Config.Upgrades[name]
	return math.floor(info.BaseCost * info.CostGrowth ^ level)
end

-- Resumo para o HUD (nível, máximo, próximo custo).
function UpgradeService.Summary(player: Player)
	local profile = PlayerDataService.Get(player)
	local list = {}
	for _, name in Config.UpgradeOrder do
		local info = Config.Upgrades[name]
		local level = profile.Upgrades[name] or 0
		table.insert(list, {
			Name = name,
			DisplayName = info.DisplayName,
			Level = level,
			MaxLevel = info.MaxLevel,
			Cost = if level < info.MaxLevel then UpgradeService.Cost(name, level) else nil,
		})
	end
	return list
end

local function buy(player: Player, name: unknown)
	local now = os.clock()
	if now - (lastRequest[player] or 0) < 0.3 then
		return
	end
	lastRequest[player] = now

	-- Nunca confiar no que o cliente manda: validar o tipo e o nome.
	if typeof(name) ~= "string" or Config.Upgrades[name] == nil or not PlayerDataService.IsLoaded(player) then
		return
	end
	local upgradeName = name :: string
	local info = Config.Upgrades[upgradeName]
	local profile = PlayerDataService.Get(player)
	local level = profile.Upgrades[upgradeName] or 0

	if level >= info.MaxLevel then
		Notifier.Notify(player, `{info.DisplayName} já está no nível máximo.`, "info")
		return
	end
	local cost = UpgradeService.Cost(upgradeName, level)
	if profile.Honey < cost then
		Notifier.Notify(player, `Faltam {cost - profile.Honey} de mel para {info.DisplayName}.`, "erro")
		return
	end

	profile.Honey -= cost
	profile.Upgrades[upgradeName] = level + 1
	Notifier.Notify(player, `{info.DisplayName} nível {level + 1}!`, "ok")
	InventoryService.Refresh(player)
end

function UpgradeService:Init() end

function UpgradeService:Start()
	Remotes.Get("RequestUpgrade").OnServerEvent:Connect(buy)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
	Log.info("UpgradeService", "pronto")
end

return UpgradeService
