--[[
	WorldService (servidor) — Etapa A

	Monta o mapa no Init (antes de qualquer Start) e guarda os dados
	para os outros serviços: lotes de colmeia, flores e favos.

	Também publica em ReplicatedStorage.ModelosProntos a "AbelhaOperaria":
	a abelha já pintada, com asas na dobradiça, que o cliente copia para as
	abelhas operárias que voam pelo mapa (só visual).
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local AssetLibrary = require(script.Parent.Parent.Lib.AssetLibrary)
local MapBuilder = require(script.Parent.Parent.World.MapBuilder)

-- Abelha operária simples (sem o pacote 3D): bolinha listrada com asas.
local function fallbackWorker(root: BasePart, model: Model)
	local function piece(name: string, size: Vector3, offset: CFrame, color: Color3, shape: Enum.PartType)
		local part = Instance.new("Part")
		part.Name = name
		part.Shape = shape
		part.Size = size
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.CFrame = root.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
		part.Parent = model
		return part
	end
	local yellow = Color3.fromRGB(255, 196, 40)
	local black = Color3.fromRGB(35, 28, 24)
	piece("Corpo", Vector3.new(1.6, 1.6, 2.2), CFrame.new(0, 0, 0.3), yellow, Enum.PartType.Ball)
	piece(
		"Listra",
		Vector3.new(0.35, 1.65, 1.65),
		CFrame.new(0, 0, 0.4) * CFrame.Angles(0, math.rad(90), 0),
		black,
		Enum.PartType.Cylinder
	)
	piece("Cabeca", Vector3.one * 1.1, CFrame.new(0, 0.15, -0.9), black, Enum.PartType.Ball)
	for side = -1, 1, 2 do
		local wing = Instance.new("Part")
		wing.Name = if side < 0 then "AsaE" else "AsaD"
		wing.Size = Vector3.new(1.4, 0.08, 0.8)
		wing.Color = Color3.fromRGB(230, 242, 255)
		wing.Material = Enum.Material.Glass
		wing.Transparency = 0.4
		wing.CanCollide = false
		wing.CanQuery = false
		wing.CanTouch = false
		wing.Massless = true
		local baseC0 = CFrame.new(side * 0.8, 0.75, 0.2) * CFrame.Angles(0, 0, math.rad(-20 * side))
		local weld = Instance.new("Weld")
		weld.Part0 = root
		weld.Part1 = wing
		weld.C0 = baseC0
		weld:SetAttribute("BaseC0", baseC0)
		weld:SetAttribute("Side", side)
		CollectionService:AddTag(weld, "AsaAbelha")
		weld.Parent = wing
		wing.Parent = model
	end
end

local function buildTemplate(name: string, length: number): Model
	local model = Instance.new("Model")
	model.Name = name
	local root = Instance.new("Part")
	root.Name = "Raiz"
	root.Size = Vector3.one * 0.4
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CFrame = CFrame.new(0, -500, 0) -- longe de tudo enquanto é só um molde
	root.Parent = model
	model.PrimaryPart = root
	local body = AssetLibrary.Attach("Abelha", root, length, CFrame.identity)
	if body then
		body.Parent = model
	else
		fallbackWorker(root, model)
	end
	return model
end

local function publishWorkerTemplate()
	local folder = Instance.new("Folder")
	folder.Name = "ModelosProntos"
	buildTemplate("AbelhaOperaria", Config.Art.WorkerBeeLength).Parent = folder
	-- Versão pequena, para as abelhas que trabalham dentro das células.
	buildTemplate("AbelhaMini", Config.Art.WorkerBeeLength * 0.62).Parent = folder
	folder.Parent = ReplicatedStorage
end

local WorldService = {}

WorldService.Map = nil :: MapBuilder.MapData?

function WorldService.GetMap(): MapBuilder.MapData
	assert(WorldService.Map, "WorldService ainda não montou o mapa")
	return WorldService.Map :: MapBuilder.MapData
end

function WorldService:Init()
	WorldService.Map = MapBuilder.Build()
end

function WorldService:Start()
	publishWorkerTemplate()
	local map = WorldService.GetMap()
	Log.info("WorldService", `mapa pronto: {#map.Plots} colmeias, {#map.Flowers} flores, {#map.Combs} favos`)
end

return WorldService
