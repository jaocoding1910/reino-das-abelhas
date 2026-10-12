--[[
	PredatorService (servidor)

	Cria as aranhas nos pés das árvores do bosque e as atualiza a cada
	quadro. A atividade muda com o ciclo:
	- dia: Config.Predators.Spider.DayActivityMultiplier (enxergam menos)
	- noite: Config.Predators.Spider.NightActivityMultiplier (mais perigosas)

	O dano passa SEMPRE pelo HealthService (proteção ao nascer, trava de
	derrota única e penalidade de predador ficam lá).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)

local HealthService = require(script.Parent.HealthService)
local InventoryService = require(script.Parent.InventoryService)
local Spider = require(script.Parent.Parent.Predators.Spider)
local WorldService = require(script.Parent.WorldService)

local PredatorService = {}

local predators = {}

local hooks: Spider.Hooks = {
	IsAlive = HealthService.IsAlive,
	IsProtected = HealthService.IsSpawnProtected,
	Damage = function(player, amount)
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
		table.insert(predators, Spider.new(home, folder, hooks))
	end

	RunService.Heartbeat:Connect(function(dt)
		local settings = Config.Predators.Spider
		local activity = if workspace:GetAttribute("IsNight")
			then settings.NightActivityMultiplier
			else settings.DayActivityMultiplier
		for _, predator in predators do
			predator:Update(dt, activity)
		end
	end)

	Log.info("PredatorService", `{#predators} aranhas no bosque`)
end

return PredatorService
