--[[
	ProgressionService (servidor) — XP e nível

	XP vem de jogar (valores em Config.Progression.XP):
	- néctar e favos coletados, mel entregue, células concluídas.
	O nível é calculado a partir da XP total (Shared/Levels), então não
	há como "dessincronizar". Os títulos (Abelha iniciante → Rei da
	Colmeia) continuam dependendo de células e mel, no StateService.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Levels = require(Shared.Levels)
local Log = require(Shared.Util.Log)
local Remotes = require(Shared.Remotes)

local Notifier = require(script.Parent.Parent.Lib.Notifier)
local PlayerDataService = require(script.Parent.PlayerDataService)

local ProgressionService = {}

function ProgressionService.AddXP(player: Player, amount: number)
	if amount <= 0 or not PlayerDataService.IsLoaded(player) then
		return
	end
	local profile = PlayerDataService.Get(player)
	local before = Levels.FromXP(profile.XP)
	profile.XP += math.floor(amount + 0.5)
	local after = Levels.FromXP(profile.XP)
	if after > before then
		Notifier.Notify(player, `Nível {after}! Sua abelha está mais experiente.`, "ok")
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			Remotes.Get("Effect"):FireAllClients("nivel", root.Position, player.UserId)
		end
	end
	Notifier.Changed(player)
end

function ProgressionService:Init() end

function ProgressionService:Start()
	Log.info("ProgressionService", "pronto")
end

return ProgressionService
