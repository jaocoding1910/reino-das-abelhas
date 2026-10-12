--[[
	CosmeticService (servidor) — acessórios da abelha

	Óculos, chapéu e lenço, comprados com mel (sem Robux no protótipo).
	Pedidos do cliente: RequestCosmetic("Comprar" | "Equipar", id).
	O servidor confere id, preço e posse; o visual é montado pelo
	CharacterService e todo mundo vê.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Remotes = require(Shared.Remotes)

local CharacterService = require(script.Parent.CharacterService)
local Notifier = require(script.Parent.Parent.Lib.Notifier)
local PlayerDataService = require(script.Parent.PlayerDataService)

local CosmeticService = {}

local lastRequest: { [Player]: number } = {}

function CosmeticService.Summary(player: Player)
	local profile = PlayerDataService.Get(player)
	local list = {}
	for _, id in Config.CosmeticOrder do
		table.insert(list, {
			Id = id,
			DisplayName = Config.Cosmetics[id].DisplayName,
			Price = Config.Cosmetics[id].Price,
			Owned = table.find(profile.Cosmetics, id) ~= nil,
			Equipped = table.find(profile.EquippedCosmetics, id) ~= nil,
		})
	end
	return list
end

local function handle(player: Player, action: unknown, id: unknown)
	local now = os.clock()
	if now - (lastRequest[player] or 0) < 0.3 then
		return
	end
	lastRequest[player] = now
	if typeof(id) ~= "string" or Config.Cosmetics[id] == nil or not PlayerDataService.IsLoaded(player) then
		return
	end
	local cosmeticId = id :: string
	local info = Config.Cosmetics[cosmeticId]
	local profile = PlayerDataService.Get(player)
	local owned = table.find(profile.Cosmetics, cosmeticId) ~= nil

	if action == "Comprar" and not owned then
		if profile.Honey < info.Price then
			Notifier.Notify(
				player,
				`Faltam {info.Price - profile.Honey} de mel para {info.DisplayName}.`,
				"erro"
			)
			return
		end
		profile.Honey -= info.Price
		table.insert(profile.Cosmetics, cosmeticId)
		table.insert(profile.EquippedCosmetics, cosmeticId)
		Notifier.Notify(player, `{info.DisplayName} comprado e equipado!`, "ok")
	elseif action == "Equipar" or (action == "Comprar" and owned) then
		if not owned then
			return
		end
		local index = table.find(profile.EquippedCosmetics, cosmeticId)
		if index then
			table.remove(profile.EquippedCosmetics, index)
		else
			table.insert(profile.EquippedCosmetics, cosmeticId)
		end
	else
		return
	end

	CharacterService.ApplyCosmetics(player)
	Notifier.Changed(player)
end

function CosmeticService:Init() end

function CosmeticService:Start()
	Remotes.Get("RequestCosmetic").OnServerEvent:Connect(handle)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
	Log.info("CosmeticService", "pronto")
end

return CosmeticService
