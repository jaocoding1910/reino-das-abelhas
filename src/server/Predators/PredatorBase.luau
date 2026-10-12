--[[
	PredatorBase — regras comuns de TODO predador NPC.

	Predadores nunca são controlados por jogadores. Todos herdam daqui:
	- Território: não persegue fora de TerritoryRadius em volta da casa.
	- Nunca entra em área protegida (Shared/Regions).
	- Nunca escolhe como alvo quem está protegido ao nascer.
	- Só ataca depois de um aviso visual (o predador implementa o tempo).

	Para criar um predador novo (ex.: louva-a-deus), depois que a aranha
	estiver estável:
	1. Crie src/server/Predators/LouvaDeus.luau usando PredatorBase.new.
	2. Implemente Update(self, dt, activity).
	3. Valores em Config.Predators.LouvaDeus.
	4. Registre no PredatorService.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Regions = require(ReplicatedStorage:WaitForChild("Shared").Regions)

local PredatorBase = {}
PredatorBase.__index = PredatorBase

function PredatorBase.new(name: string, home: Vector3, territoryRadius: number)
	local self = setmetatable({}, PredatorBase)
	self.Name = name
	self.Home = home
	self.TerritoryRadius = territoryRadius
	self.Position = home
	self.Target = nil :: Player?
	self.Model = nil :: Model?
	return self
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

function PredatorBase:IsInsideTerritory(position: Vector3): boolean
	return flatDistance(position, self.Home) <= self.TerritoryRadius
end

-- Pode pisar aqui? (dentro do território e fora de área protegida)
function PredatorBase:CanEnter(position: Vector3): boolean
	return self:IsInsideTerritory(position) and Regions.AllowsPredators(Regions.Classify(position))
end

-- Alvo válido: vivo, sem proteção de nascimento, num lugar onde predador pode ir.
-- `isProtected` e `isAlive` vêm do HealthService (injetados para evitar dependência circular).
function PredatorBase:IsValidTarget(
	player: Player,
	isAlive: (Player) -> boolean,
	isProtected: (Player) -> boolean
): boolean
	if not player.Parent or not isAlive(player) or isProtected(player) then
		return false
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and self:CanEnter(root.Position)
end

-- Jogador válido mais próximo dentro de `range`.
function PredatorBase:FindTarget(
	range: number,
	isAlive: (Player) -> boolean,
	isProtected: (Player) -> boolean
): Player?
	local best, bestDistance = nil, range
	for _, player in Players:GetPlayers() do
		if self:IsValidTarget(player, isAlive, isProtected) then
			local root = (player.Character :: Model):FindFirstChild("HumanoidRootPart") :: BasePart
			local distance = (root.Position - self.Position).Magnitude
			if distance <= bestDistance then
				best, bestDistance = player, distance
			end
		end
	end
	return best
end

function PredatorBase:Update(_dt: number, _activity: number) end

function PredatorBase:Destroy()
	if self.Model then
		self.Model:Destroy()
		self.Model = nil
	end
	self.Target = nil
end

return PredatorBase
