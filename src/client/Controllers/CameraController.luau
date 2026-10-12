--[[
	CameraController (cliente) — Etapa A

	Primeira pessoa confortável:
	- CameraMode = LockFirstPerson (definido no default.project.json).
	- Campo de visão um pouco mais aberto para dar sensação de escala.
	- Sem balanço de câmera.
	- Duas patas discretas no canto inferior da tela (só na sua câmera).

	Dica de teste no Studio: Esc solta o mouse; Shift+F5 para o teste.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared.Util.Log)

local CameraController = {}

local FIELD_OF_VIEW = 78
local LEG_COLOR = Color3.fromRGB(35, 28, 22)

local legs: { { Part: BasePart, Offset: CFrame } } = {}

local function makeLeg(name: string, offset: CFrame)
	local camera = workspace.CurrentCamera
	local leg = Instance.new("Part")
	leg.Name = name
	leg.Shape = Enum.PartType.Cylinder
	leg.Size = Vector3.new(0.7, 0.09, 0.09)
	leg.Color = LEG_COLOR
	leg.Material = Enum.Material.SmoothPlastic
	leg.Anchored = true
	leg.CanCollide = false
	leg.CanQuery = false
	leg.CanTouch = false
	leg.CastShadow = false
	leg.Parent = camera
	table.insert(legs, { Part = leg, Offset = offset })
end

function CameraController:Init()
	local camera = workspace.CurrentCamera
	camera.FieldOfView = FIELD_OF_VIEW

	-- Patas: baixas e afastadas do centro para não atrapalhar a visão.
	makeLeg("PataEsquerda", CFrame.new(-0.55, -0.72, -1.25) * CFrame.Angles(0, math.rad(65), math.rad(20)))
	makeLeg("PataDireita", CFrame.new(0.55, -0.72, -1.25) * CFrame.Angles(0, math.rad(115), math.rad(-20)))
end

function CameraController:Start()
	RunService:BindToRenderStep("PatasAbelha", Enum.RenderPriority.Camera.Value + 1, function()
		local cameraCFrame = workspace.CurrentCamera.CFrame
		for _, leg in legs do
			leg.Part.CFrame = cameraCFrame * leg.Offset
		end
	end)
	Log.info("CameraController", "pronto")
end

return CameraController
