--[[
	DailyRewardService (servidor) — recompensa diária

	Ao entrar (com o perfil carregado), se for um dia novo:
	- entrou ontem também → sequência +1; senão → sequência volta para 1;
	- ganha Config.Daily.Honey[dia] (dias 1 a 7, depois repete) e XP;
	- o cliente recebe "DailyReward" e mostra o calendário de 7 dias.

	O "dia" usa Config.Daily.UtcOffsetHours (Brasília = -3).
	Sessão sem salvar (falha no DataStore) não ganha nada, para não duplicar.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)

local Notifier = require(script.Parent.Parent.Lib.Notifier)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ProgressionService = require(script.Parent.ProgressionService)

local DailyRewardService = {}

function DailyRewardService.Today(now: number?): number
	return math.floor(((now or os.time()) + Config.Daily.UtcOffsetHours * 3600) / 86400)
end

-- Regra pura (testável): devolve a nova sequência e o índice do prêmio, ou nil
-- se hoje já foi pago.
function DailyRewardService.Next(lastDay: number, streak: number, today: number): (number?, number?)
	if lastDay == today then
		return nil, nil
	end
	local newStreak = if lastDay == today - 1 then streak + 1 else 1
	local index = ((newStreak - 1) % #Config.Daily.Honey) + 1
	return newStreak, index
end

local function grant(player: Player, profile: Types.Profile)
	local today = DailyRewardService.Today()
	local streak, index = DailyRewardService.Next(profile.LastDailyDay, profile.DailyStreak, today)
	if not streak or not index then
		return
	end
	local honey = Config.Daily.Honey[index]
	local xp = Config.Daily.XPPerDay * index
	profile.LastDailyDay = today
	profile.DailyStreak = streak
	profile.Honey += honey
	profile.HoneyEarned += honey
	ProgressionService.AddXP(player, xp)
	Notifier.Changed(player)
	-- Espera o HUD do jogador ficar pronto antes de mostrar o calendário.
	task.delay(6, function()
		if player.Parent then
			Remotes.Get("DailyReward"):FireClient(player, {
				Streak = streak,
				Index = index,
				Honey = honey,
				XP = xp,
				Rewards = Config.Daily.Honey,
			})
		end
	end)
	Log.info("DailyRewardService", `{player.Name}: dia {index} (sequência {streak}) +{honey} mel`)
end

local function onPlayer(player: Player)
	local profile = PlayerDataService.WaitForProfile(player)
	if profile and PlayerDataService.IsLoaded(player) then
		grant(player, profile)
	end
end

function DailyRewardService:Init() end

function DailyRewardService:Start()
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
end

return DailyRewardService
