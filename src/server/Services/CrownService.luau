--[[
	CrownService (servidor) — objetivo de longo prazo "Rei/Rainha da Colmeia"

	Não é o NPC Rainha: é um título que o JOGADOR conquista. O progresso
	vem só de dados salvos do perfil (nada é dado por visitar o castelo):
	  1. nível Config.Crown.Level;
	  2. Config.Crown.Cells células prontas na colmeia;
	  3. Config.Crown.RareDelivered favos raros ENTREGUES (Stats.RaroEntregue);
	  4. Config.Crown.RoyalRequests pedidos da Rainha cumpridos (Stats.Rainha).
	Progresso = média das quatro metas (cada uma limitada a 100%).
	Ao completar tudo, uma única vez: profile.Crowned = true, prêmio em mel,
	Coroa liberada de graça e aviso para o servidor inteiro.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Levels = require(Shared.Levels)
local Log = require(Shared.Util.Log)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)

local HiveService = require(script.Parent.HiveService)
local Notifier = require(script.Parent.Parent.Lib.Notifier)
local PlayerDataService = require(script.Parent.PlayerDataService)

local CrownService = {}

export type Goal = { Text: string, Current: number, Goal: number }

function CrownService.Goals(profile: Types.Profile): { Goal }
	local crown = Config.Crown
	return {
		{ Text = `Nível {crown.Level}`, Current = Levels.FromXP(profile.XP), Goal = crown.Level },
		{
			Text = `{crown.Cells} células prontas`,
			Current = HiveService.CountCompleted(profile),
			Goal = crown.Cells,
		},
		{
			Text = `{crown.RareDelivered} favos raros entregues`,
			Current = profile.Stats.RaroEntregue or 0,
			Goal = crown.RareDelivered,
		},
		{
			Text = `{crown.RoyalRequests} pedidos da Rainha`,
			Current = profile.Stats.Rainha or 0,
			Goal = crown.RoyalRequests,
		},
	}
end

-- 0 a 1. Perfil já coroado fica em 1 (renascer não tira o título).
function CrownService.Progress(profile: Types.Profile): number
	if profile.Crowned then
		return 1
	end
	local total = 0
	local goals = CrownService.Goals(profile)
	for _, goal in goals do
		total += math.clamp(goal.Current / math.max(1, goal.Goal), 0, 1)
	end
	return total / #goals
end

function CrownService.Summary(player: Player)
	local profile = PlayerDataService.Get(player)
	local goals = CrownService.Goals(profile)
	local list = {}
	for _, goal in goals do
		table.insert(list, {
			Text = goal.Text,
			Current = math.min(goal.Current, goal.Goal),
			Goal = goal.Goal,
			Done = goal.Current >= goal.Goal,
		})
	end
	return { Progress = CrownService.Progress(profile), Crowned = profile.Crowned, Goals = list }
end

local function check(player: Player)
	if not PlayerDataService.IsLoaded(player) then
		return
	end
	local profile = PlayerDataService.Get(player)
	if profile.Crowned or CrownService.Progress(profile) < 1 then
		return
	end
	profile.Crowned = true
	profile.Honey += Config.Crown.RewardHoney
	profile.HoneyEarned += Config.Crown.RewardHoney
	if Config.Cosmetics.Coroa and not table.find(profile.Cosmetics, "Coroa") then
		table.insert(profile.Cosmetics, "Coroa")
	end
	player:SetAttribute("Coroado", true)
	Notifier.Notify(
		player,
		`CONQUISTA: Rei/Rainha da Colmeia|Você reina no Reino das Abelhas! +{Config.Crown.RewardHoney} mel e Coroa liberada.`,
		"conquista"
	)
	Remotes.Get("WorldUpdated"):FireAllClients(`👑 {player.DisplayName} virou Rei/Rainha da Colmeia!`, "ok")
	Notifier.Changed(player)
	Log.info("CrownService", `{player.Name} conquistou o título`)
end

function CrownService:Init() end

function CrownService:Start()
	local lastCheck: { [Player]: number } = {}
	Notifier.OnChanged:Connect(function(player)
		local now = os.clock()
		if now - (lastCheck[player] or 0) >= 1 then
			lastCheck[player] = now
			task.defer(check, player)
		end
	end)
	local function onPlayer(player: Player)
		task.spawn(function()
			local profile = PlayerDataService.WaitForProfile(player)
			if profile then
				player:SetAttribute("Coroado", profile.Crowned)
				check(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastCheck[player] = nil
	end)
	Log.info("CrownService", "pronto")
end

return CrownService
