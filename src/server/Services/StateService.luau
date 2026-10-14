--[[
	StateService (servidor) — Etapa A

	Monta o "retrato" do jogador que o HUD mostra e envia ao cliente.
	O cliente só exibe; todos os números vêm daqui.

	Os outros serviços avisam mudanças com Notifier.Changed(player);
	este serviço escuta e envia o estado completo ao cliente.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Levels = require(Shared.Levels)
local Remotes = require(Shared.Remotes)

local AchievementService = require(script.Parent.AchievementService)
local ClanService = require(script.Parent.ClanService)
local CrownService = require(script.Parent.CrownService)
local CosmeticService = require(script.Parent.CosmeticService)
local HiveService = require(script.Parent.HiveService)
local InventoryService = require(script.Parent.InventoryService)
local Notifier = require(script.Parent.Parent.Lib.Notifier)
local PlayerDataService = require(script.Parent.PlayerDataService)
local MerchantService = require(script.Parent.MerchantService)
local PetService = require(script.Parent.PetService)
local QuestService = require(script.Parent.QuestService)
local RoyalService = require(script.Parent.RoyalService)
local UpgradeService = require(script.Parent.UpgradeService)

local StateService = {}

local function titleFor(cellsCompleted: number, honeyEarned: number)
	local current = Config.Titles[1]
	local nextTitle = nil
	for _, title in Config.Titles do
		if cellsCompleted >= title.RequiredCells and honeyEarned >= title.RequiredHoney then
			current = title
		elseif not nextTitle then
			nextTitle = title
		end
	end
	return current, nextTitle
end

function StateService.Build(player: Player)
	local profile = PlayerDataService.Get(player)
	local cargo = InventoryService.Get(player)
	local building = HiveService.GetBuilding(profile)
	local completed = HiveService.CountCompleted(profile)
	local title, nextTitle = titleFor(completed, profile.HoneyEarned)
	local level, xpInLevel, xpNext = Levels.FromXP(profile.XP)

	return {
		Honey = profile.Honey,
		CombPoints = profile.CombPoints,
		Nectar = cargo.Nectar,
		Combs = table.clone(cargo.Combs),
		CarryWeight = InventoryService.Weight(player),
		Capacity = InventoryService.Capacity(player),
		Title = title.Name,
		NextTitle = if nextTitle
			then `{nextTitle.Name}: {nextTitle.RequiredCells} células e {nextTitle.RequiredHoney} mel ganhos`
			else nil,
		ColonyName = profile.ColonyName,
		CellsCompleted = completed,
		CellsMax = Config.Hive.MaxCells,
		Building = if building then { Slot = building.Slot, Progress = building.Progress } else nil,
		CellHoneyCost = Config.Hive.CellHoneyCost,
		HivePosition = HiveService.GetHivePosition(player),
		DeliveryPosition = HiveService.GetDeliveryPosition(player),
		Upgrades = UpgradeService.Summary(player),
		Cosmetics = CosmeticService.Summary(player),
		Level = level,
		XPInLevel = xpInLevel,
		XPNext = xpNext,
		Loaded = PlayerDataService.IsLoaded(player),
		Quest = QuestService.Summary(player),
		HiveHoney = math.floor(profile.HiveHoney),
		HiveStorage = HiveService.StorageCapacity(profile),
		Specialty = UpgradeService.SpecialtySummary(player),
		Royal = RoyalService.Summary(player),
		Clan = ClanService.Summary(player),
		DailyStreak = profile.DailyStreak,
		Achievements = AchievementService.Summary(player),
		Pets = PetService.Summary(player),
		Shop = MerchantService.Summary(player),
		HoneyEarned = profile.HoneyEarned,
		TutorialDone = profile.TutorialDone,
		Settings = profile.Settings,
		HiveTier = HiveService.Tier(completed),
		Rebirths = profile.Rebirths,
		RebirthCost = HiveService.RebirthCost(profile.Rebirths),
		RebirthMinLevel = Config.Rebirth.MinLevel,
		HoneyMultiplier = HiveService.HoneyMultiplier(profile),
		Workers = profile.Workers,
		WorkersMax = Config.Workers.Max,
		WorkerCost = HiveService.WorkerCost(profile.Workers),
		HoneyPerMinute = math.floor(HiveService.HoneyPerMinute(profile) * 10 + 0.5) / 10,
		Daily = profile.Daily,
		BestRace = profile.BestRace,
		Crown = CrownService.Summary(player),
		-- Sem DataStore (Studio sem API ou falha ao carregar): nada é salvo.
		TestMode = not PlayerDataService.CanSave(player),
		NightRareBonus = Config.DayNight.NightRareHoneyBonus,
	}
end

function StateService.Publish(player: Player)
	if player.Parent then
		Remotes.Get("StateUpdated"):FireClient(player, StateService.Build(player))
	end
end

function StateService:Init()
	Remotes.GetFunction("GetInitialState").OnServerInvoke = function(player)
		return StateService.Build(player)
	end
end

function StateService:Start()
	Notifier.OnChanged:Connect(StateService.Publish)
	Log.info("StateService", "pronto")
end

return StateService
