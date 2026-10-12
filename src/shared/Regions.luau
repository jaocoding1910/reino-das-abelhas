--!strict
--[[
	Regions — em que região uma posição está.

	Função pura (só matemática), usada pelo servidor para decidir regras
	e testável fora do Roblox. O cliente recebe o resultado pelo atributo
	"Region" do Player; ele não decide nada com isto.

	- Colmeias: anel das árvores-colmeia no centro. Protegida.
	- Campo: campo inicial. Protegida.
	- Bosque: predadores, sem combate entre jogadores.
	- Disputa: copas altas do bosque e a Colmeia Real. Predadores e combate.
]]

local Config = require(script.Parent.Config)

export type RegionName = "Colmeias" | "Campo" | "Bosque" | "Disputa"

local Regions = {}

Regions.Info = {
	Colmeias = { Label = "Área protegida", Protected = true, PvP = false, Predators = false },
	Campo = { Label = "Campo protegido", Protected = true, PvP = false, Predators = false },
	Bosque = { Label = "Bosque • predadores", Protected = false, PvP = false, Predators = true },
	Disputa = { Label = "Zona de disputa", Protected = false, PvP = true, Predators = true },
}

function Regions.Classify(position: Vector3): RegionName
	local flat = Vector3.new(position.X, 0, position.Z)
	local distance = flat.Magnitude
	local settings = Config.Regions

	local royal = Config.Map.RoyalHive.Position
	if (flat - Vector3.new(royal.X, 0, royal.Z)).Magnitude <= settings.RoyalRadius then
		return "Disputa"
	end
	if distance <= settings.HiveRadius then
		return "Colmeias"
	end
	if distance <= settings.SafeRadius then
		return "Campo"
	end
	if position.Y >= settings.DisputeAltitude then
		return "Disputa"
	end
	return "Bosque"
end

function Regions.IsProtected(name: string): boolean
	local info = Regions.Info[name]
	return info ~= nil and info.Protected
end

function Regions.AllowsPvP(name: string): boolean
	local info = Regions.Info[name]
	return info ~= nil and info.PvP
end

function Regions.AllowsPredators(name: string): boolean
	local info = Regions.Info[name]
	return info ~= nil and info.Predators
end

return Regions
