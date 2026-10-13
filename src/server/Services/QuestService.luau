--[[
	QuestService (servidor) — missões em sequência

	As missões ficam em Config.Quests. Cada uma tem um tipo (Kind), uma meta
	e uma recompensa em mel e XP. Os outros serviços avisam o que aconteceu:

		QuestService.Add(player, "Nectar", 3)

	Quando a lista acaba, as missões a partir de Config.QuestRepeatFrom se
	repetem com meta e recompensa maiores (Config.QuestRepeatGrowth por volta).
	O progresso fica salvo no perfil (QuestIndex, QuestProgress, QuestCycle).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Types = require(Shared.Types)

local Notifier = require(script.Parent.Parent.Lib.Notifier)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ProgressionService = require(script.Parent.ProgressionService)

local QuestService = {}

export type Quest = { Kind: string, Text: string, Goal: number, Honey: number, XP: number }

-- Missão atual do perfil, já com a meta/recompensa da volta em que está.
function QuestService.Current(profile: Types.Profile): Quest
	local index = math.clamp(profile.QuestIndex, 1, #Config.Quests)
	local base = Config.Quests[index]
	local factor = 1 + profile.QuestCycle * Config.QuestRepeatGrowth
	return {
		Kind = base.Kind,
		Text = base.Text,
		Goal = math.max(1, math.floor(base.Goal * factor + 0.5)),
		Honey = math.floor(base.Honey * factor + 0.5),
		XP = math.floor(base.XP * factor + 0.5),
	}
end

-- Avança para a próxima missão (puro, testável).
function QuestService.Advance(profile: Types.Profile)
	profile.QuestProgress = 0
	profile.QuestIndex += 1
	if profile.QuestIndex > #Config.Quests then
		profile.QuestIndex = Config.QuestRepeatFrom
		profile.QuestCycle += 1
	end
end

-- Pedido da Rainha: avança junto com as missões (mesmos tipos de evento).
local function addRoyal(player: Player, profile: Types.Profile, kind: string, amount: number): boolean
	local royal = profile.Royal
	if royal.Kind ~= kind or royal.Progress >= royal.Goal then
		return false
	end
	royal.Progress = math.min(royal.Goal, royal.Progress + amount)
	if royal.Progress >= royal.Goal then
		Notifier.Notify(player, "👑 Pedido da Rainha pronto! Volte à Colmeia Real para receber.", "ok")
	end
	return true
end

function QuestService.Add(player: Player, kind: string, amount: number)
	if amount <= 0 or not PlayerDataService.IsLoaded(player) then
		return
	end
	local profile = PlayerDataService.Get(player)
	local changed = addRoyal(player, profile, kind, amount)
	local quest = QuestService.Current(profile)
	if quest.Kind == kind then
		changed = true
		profile.QuestProgress = math.min(quest.Goal, profile.QuestProgress + amount)
		if profile.QuestProgress >= quest.Goal then
			profile.Honey += quest.Honey
			profile.HoneyEarned += quest.Honey
			QuestService.Advance(profile)
			Notifier.Notify(
				player,
				`Missão concluída: {quest.Text}! +{quest.Honey} mel · +{quest.XP} XP`,
				"ok"
			)
			ProgressionService.AddXP(player, quest.XP)
		end
	end
	if changed then
		Notifier.Changed(player)
	end
end

function QuestService.Summary(player: Player)
	local profile = PlayerDataService.Get(player)
	local quest = QuestService.Current(profile)
	return {
		Kind = quest.Kind,
		Text = quest.Text,
		Progress = profile.QuestProgress,
		Goal = quest.Goal,
		Honey = quest.Honey,
		XP = quest.XP,
		Number = profile.QuestIndex + profile.QuestCycle * (#Config.Quests - Config.QuestRepeatFrom + 1),
	}
end

function QuestService:Init() end

function QuestService:Start()
	Log.info("QuestService", `{#Config.Quests} missões`)
end

return QuestService
