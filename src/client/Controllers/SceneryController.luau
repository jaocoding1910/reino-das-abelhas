--[[
	SceneryController (cliente) — cordilheira do horizonte

	As montanhas que fecham o vale são criadas AQUI, no cliente, e não no
	servidor. Motivo: com StreamingEnabled o Roblox só manda ao jogador o que
	está perto dele; peças a ~1200 studs nunca chegavam e o céu ficava vazio.
	Peças criadas pelo próprio cliente existem sempre.

	São só cenário (não têm coleta nem lógica): 24 picos de elipsoide (encosta
	verde, pico de pedra e neve em alguns), com semente fixa para todos verem
	o mesmo horizonte. Não colidem e não entram em raios (CanQuery desligado).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)

local SceneryController = {}

local function ellipsoid(
	parent: Instance,
	name: string,
	size: Vector3,
	center: Vector3,
	color: Color3,
	material: Enum.Material
)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = size
	part.CFrame = CFrame.new(center)
	part.Color = color
	part.Material = material
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	part.Parent = parent
	return part
end

function SceneryController:Init()
	local folder = Instance.new("Folder")
	folder.Name = "HorizonteLocal"
	local settings = Config.Scenery
	local rng = Random.new(Config.Map.Seed + 404)
	for i = 1, settings.Peaks do
		local angle = (i / settings.Peaks) * math.pi * 2 + rng:NextNumber(-0.05, 0.05)
		local radius = rng:NextNumber(settings.RadiusMin, settings.RadiusMax)
		local base = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local width = rng:NextNumber(260, 360)
		local height = rng:NextNumber(520, 760)
		ellipsoid(
			folder,
			"Encosta",
			Vector3.new(width * 1.7, height * 0.45, width * 1.7),
			base + Vector3.new(0, 10, 0),
			Color3.fromRGB(78, 122, 66),
			Enum.Material.Grass
		)
		ellipsoid(
			folder,
			"Pico",
			Vector3.new(width, height, width * 0.9),
			base + Vector3.new(rng:NextNumber(-20, 20), 40, 0),
			Color3.fromRGB(112, 110, 124),
			Enum.Material.Slate
		)
		if rng:NextNumber() < 0.6 then
			ellipsoid(
				folder,
				"Neve",
				Vector3.new(width * 0.42, height * 0.2, width * 0.4),
				base + Vector3.new(0, 40 + height * 0.42, 0),
				Color3.fromRGB(242, 246, 252),
				Enum.Material.Snow
			)
		end
	end
	folder.Parent = workspace
	Log.info("SceneryController", `{settings.Peaks} picos no horizonte`)
end

function SceneryController:Start() end

return SceneryController
