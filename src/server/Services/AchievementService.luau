--[[
	AchievementService (servidor) — conquistas

	Cada conquista (Config.Achievements) olha um contador do perfil
	(profile.Stats, somado pelo QuestService e por outros serviços).
	A cada mudança do jogador (Notifier.OnChanged) confere se alguma foi
	alcançada: dá o mel, marca como feita e mostra a faixa no HUD.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)

local Notifier = require(script.Parent.Parent.Lib.Notifier)
local PlayerDataService = require(script.Parent.PlayerDataService)

local AchievementService = {}

-- Regra pura (testável): lista das conquistas recém-alcançadas.
function AchievementService.Pending(profile: Types.Profile): { any }
	local list = {}
	for _, info in Config.Achievements do
		if not profile.Achievements[info.Id] and (profile.Stats[info.Stat] or 0) >= info.Goal then
			table.insert(list, info)
		end
	end
	return list
end

function AchievementService.Summary(player: Player)
	local profile = PlayerDataService.Get(player)
	local list = {}
	local done = 0
	for _, info in Config.Achievements do
		local finished = profile.Achievements[info.Id] == true
		if finished then
			done += 1
		end
		table.insert(list, {
			Id = info.Id,
			Name = info.Name,
			Desc = info.Desc,
			Icon = info.Icon,
			Goal = info.Goal,
			Progress = math.min(info.Goal, profile.Stats[info.Stat] or 0),
			Honey = info.Honey,
			Done = finished,
		})
	end
	return { List = list, Done = done, Total = #Config.Achievements }
end

local checking: { [Player]: boolean } = {}

local function check(player: Player)
	if checking[player] or not PlayerDataService.IsLoaded(player) then
		return
	end
	checking[player] = true
	local profile = PlayerDataService.Get(player)
	local pending = AchievementService.Pending(profile)
	for _, info in pending do
		profile.Achievements[info.Id] = true
		profile.Honey += info.Honey
		profile.HoneyEarned += info.Honey
		Remotes.Get("Notify")
			:FireClient(player, `{info.Icon} {info.Name}|+{info.Honey} mel · {info.Desc}`, "conquista")
		Log.info("AchievementService", `{player.Name}: {info.Name}`)
	end
	checking[player] = false
	if #pending > 0 then
		Notifier.Changed(player)
	end
end

function AchievementService:Init() end

function AchievementService:Start()
	Notifier.OnChanged:Connect(check)
end

return AchievementService
