--[[
	PredatorService (servidor)

	Cria os predadores do bosque e os atualiza a cada quadro:
	- Aranhas nos pés das árvores (perseguem).
	- Louva-a-deus no alto dos cogumelos fora da área protegida (bote).
	A atividade muda com o ciclo (Day/NightActivityMultiplier de cada um).

	O dano passa SEMPRE pelo HealthService (proteção ao nascer, trava de
	derrota única e penalidade de predador ficam lá).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)

local Regions = require(ReplicatedStorage:WaitForChild("Shared").Regions)
local HealthService = require(script.Parent.HealthService)
local InventoryService = require(script.Parent.InventoryService)
local Dragonfly = require(script.Parent.Parent.Predators.Dragonfly)
local Mantis = require(script.Parent.Parent.Predators.Mantis)
local Spider = require(script.Parent.Parent.Predators.Spider)
local WorldService = require(script.Parent.WorldService)

local PredatorService = {}

type Entry = { Predator: any, Settings: any }
local predators: { Entry } = {}

local hooks: Spider.Hooks = {
	IsAlive = HealthService.IsAlive,
	IsProtected = HealthService.IsSpawnProtected,
	Damage = function(player, amount)
		-- Segurança extra: nunca acerta quem já está em área protegida.
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root or Regions.IsProtected(Regions.Classify(root.Position)) then
			return false
		end
		return HealthService.Damage(player, amount, "Predador")
	end,
	Slow = InventoryService.ApplySlow,
	AllPlayers = function()
		return Players:GetPlayers()
	end,
}

function PredatorService:Init() end

function PredatorService:Start()
	local map = WorldService.GetMap()
	local folder = Instance.new("Folder")
	folder.Name = "Predadores"
	folder.Parent = workspace

	local spots = map.SpiderSpots
	local count = math.min(Config.Predators.Spider.Count, #spots)
	for i = 1, count do
		-- Espalha: pega árvores alternadas e afasta a teia do tronco.
		local base = spots[((i - 1) * 3) % #spots + 1]
		local outward = Vector3.new(base.X, 0, base.Z).Unit
		local home = base - outward * 28
		table.insert(
			predators,
			{ Predator = Spider.new(home, folder, hooks), Settings = Config.Predators.Spider }
		)
	end

	-- Louva-a-deus: só em cogumelos fora do campo protegido (com folga).
	local perches = {}
	for _, top in map.MantisSpots do
		if Vector3.new(top.X, 0, top.Z).Magnitude > Config.Regions.SafeRadius + 30 then
			table.insert(perches, top - Vector3.new(0, 2.6, 0)) -- o topo vem 3 studs acima do chapéu
		end
	end
	local mantisCount = 0
	for i = 1, math.min(Config.Predators.LouvaDeus.Count, #perches) do
		local perch = perches[((i - 1) * 2) % #perches + 1]
		table.insert(
			predators,
			{ Predator = Mantis.new(perch, folder, hooks), Settings = Config.Predators.LouvaDeus }
		)
		mantisCount += 1
	end

	-- Libélulas no lago, espalhadas no círculo.
	local dragonflies = Config.Predators.Libelula.Count
	for i = 1, dragonflies do
		table.insert(predators, {
			Predator = Dragonfly.new(map.LakeCenter, (i - 1) * math.pi * 2 / dragonflies, folder, hooks),
			Settings = Config.Predators.Libelula,
		})
	end

	RunService.Heartbeat:Connect(function(dt)
		local night = workspace:GetAttribute("IsNight") == true
		local fog = workspace:GetAttribute("Clima") == "Neblina"
		for _, entry in predators do
			local settings = entry.Settings
			local activity = if night
				then settings.NightActivityMultiplier
				else settings.DayActivityMultiplier
			-- Neblina: enxergam menos.
			if fog then
				activity *= Config.Weather.FogPredatorVision
			end
			entry.Predator:Update(dt, activity)
		end
	end)

	Log.info(
		"PredatorService",
		`{#predators - mantisCount - dragonflies} aranhas, {mantisCount} louva-a-deus e {dragonflies} libélulas`
	)
end

return PredatorService
