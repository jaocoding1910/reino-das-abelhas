--[[
	PetService (servidor) — mascotes

	Abelhinhas de estimação compradas com mel (Config.Pets). Ficam salvas
	no perfil. A mascote equipada vai no atributo "Mascote" do Player;
	cada cliente desenha as mascotes de todos (PetController), sem custo
	para o servidor.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Remotes = require(Shared.Remotes)

local Notifier = require(script.Parent.Parent.Lib.Notifier)
local PlayerDataService = require(script.Parent.PlayerDataService)

local PetService = {}

local lastRequest: { [Player]: number } = {}

local function apply(player: Player)
	local profile = PlayerDataService.Get(player)
	player:SetAttribute("Mascote", profile.EquippedPet)
end

function PetService.Summary(player: Player)
	local profile = PlayerDataService.Get(player)
	local list = {}
	for _, id in Config.PetOrder do
		local info = Config.Pets[id]
		table.insert(list, {
			Id = id,
			DisplayName = info.DisplayName,
			Price = info.Price,
			Owned = table.find(profile.Pets, id) ~= nil,
			Equipped = profile.EquippedPet == id,
		})
	end
	return list
end

local function handle(player: Player, action: unknown, id: unknown)
	local now = os.clock()
	if now - (lastRequest[player] or 0) < 0.4 then
		return
	end
	lastRequest[player] = now
	if typeof(action) ~= "string" or typeof(id) ~= "string" or not PlayerDataService.IsLoaded(player) then
		return
	end
	local info = Config.Pets[id]
	if not info then
		return
	end
	local profile = PlayerDataService.Get(player)
	local owned = table.find(profile.Pets, id) ~= nil
	if action == "Comprar" and not owned then
		if profile.Honey < info.Price then
			Notifier.Notify(player, `{info.DisplayName} custa {info.Price} mel.`, "erro")
			return
		end
		profile.Honey -= info.Price
		table.insert(profile.Pets, id)
		profile.EquippedPet = id
		Notifier.Notify(player, `🐝 {info.DisplayName} agora te acompanha!`, "ok")
	elseif action == "Equipar" and owned then
		profile.EquippedPet = if profile.EquippedPet == id then "" else id
	else
		return
	end
	apply(player)
	Notifier.Changed(player)
end

function PetService:Init() end

function PetService:Start()
	Remotes.Get("RequestPet").OnServerEvent:Connect(handle)
	local function onPlayer(player: Player)
		task.spawn(function()
			PlayerDataService.WaitForProfile(player)
			apply(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
	Log.info("PetService", "pronto")
end

return PetService
