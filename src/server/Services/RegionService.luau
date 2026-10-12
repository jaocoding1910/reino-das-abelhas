--[[
	RegionService (servidor)

	A cada 0,3 s descobre em que região cada abelha está e grava no
	atributo "Region" do Player (o HUD mostra "Área protegida" etc.).
	As regras ficam em Shared/Regions; aqui só aplicamos.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared.Util.Log)
local Regions = require(Shared.Regions)

local RegionService = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Região atual calculada na hora (o servidor nunca confia no atributo para regras).
function RegionService.Of(player: Player): string
	local root = rootOf(player)
	if not root then
		return "Colmeias"
	end
	return Regions.Classify(root.Position)
end

function RegionService:Init() end

function RegionService:Start()
	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				local region = RegionService.Of(player)
				if player:GetAttribute("Region") ~= region then
					player:SetAttribute("Region", region)
				end
			end
			task.wait(0.3)
		end
	end)
	Log.info("RegionService", "pronto")
end

return RegionService
