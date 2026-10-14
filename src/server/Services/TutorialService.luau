--[[
	TutorialService (servidor) — primeiros passos e configurações

	- Tutorial: o cliente mostra os passos para quem nunca terminou
	  (profile.TutorialDone). "Concluir" dá Config.TutorialReward de mel uma
	  vez só, e só se o jogador já entregou mel de verdade (HoneyEarned > 0).
	  "Pular" só marca como feito.
	- Configurações: o cliente manda a tabela; o servidor valida
	  (PlayerDataService.CleanSettings) e salva no perfil.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Remotes = require(Shared.Remotes)

local Notifier = require(script.Parent.Parent.Lib.Notifier)
local PlayerDataService = require(script.Parent.PlayerDataService)

local TutorialService = {}

local lastRequest: { [Player]: number } = {}

local function throttled(player: Player): boolean
	local now = os.clock()
	if now - (lastRequest[player] or 0) < 0.5 then
		return true
	end
	lastRequest[player] = now
	return false
end

function TutorialService:Init() end

function TutorialService:Start()
	Remotes.Get("RequestTutorial").OnServerEvent:Connect(function(player, action)
		if throttled(player) or typeof(action) ~= "string" or not PlayerDataService.IsLoaded(player) then
			return
		end
		local profile = PlayerDataService.Get(player)
		if profile.TutorialDone then
			return
		end
		if action == "Concluir" then
			if profile.HoneyEarned <= 0 then
				return
			end
			profile.TutorialDone = true
			profile.Honey += Config.TutorialReward
			profile.HoneyEarned += Config.TutorialReward
			Notifier.Notify(
				player,
				`👑 Tutorial concluído! A Rainha te deu +{Config.TutorialReward} mel.`,
				"ok"
			)
		elseif action == "Pular" then
			profile.TutorialDone = true
		else
			return
		end
		Notifier.Changed(player)
	end)

	Remotes.Get("RequestSettings").OnServerEvent:Connect(function(player, raw)
		if throttled(player) or not PlayerDataService.IsLoaded(player) then
			return
		end
		local profile = PlayerDataService.Get(player)
		profile.Settings = PlayerDataService.CleanSettings(raw, profile.Settings)
		Notifier.Changed(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
	Log.info("TutorialService", "pronto")
end

return TutorialService
