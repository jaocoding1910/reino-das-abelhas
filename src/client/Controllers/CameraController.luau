--[[
	CameraController (cliente)

	Primeira pessoa confortável e com sensação de velocidade:
	- CameraMode = LockFirstPerson (default.project.json).
	- Campo de visão abre com a velocidade (Config.Flight.FieldOfViewBoost).
	- Leve inclinação da câmera nas curvas (Config.Flight.CameraRollDegrees; 0 desliga).
	- Sem balanço de câmera (evita enjoo).
	- Patinhas no canto inferior da tela (Config.Flight.ShowLegs; desligadas por padrão).

	Dica de teste no Studio: Esc solta o mouse; Shift+F5 para o teste.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)

local FlightController = require(script.Parent.FlightController)

local CameraController = {}

local LEG_COLOR = Color3.fromRGB(35, 28, 22)

local legs: { { Part: BasePart, Offset: CFrame } } = {}

local function makeLeg(name: string, offset: CFrame)
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
	leg.Parent = workspace.CurrentCamera
	table.insert(legs, { Part = leg, Offset = offset })
end

function CameraController:Init()
	workspace.CurrentCamera.FieldOfView = Config.Flight.FieldOfView
	if not Config.Flight.ShowLegs then
		return
	end
	makeLeg("PataEsquerda", CFrame.new(-0.55, -0.72, -1.25) * CFrame.Angles(0, math.rad(65), math.rad(20)))
	makeLeg("PataDireita", CFrame.new(0.55, -0.72, -1.25) * CFrame.Angles(0, math.rad(115), math.rad(-20)))
end

function CameraController:Start()
	local fov = Config.Flight.FieldOfView
	RunService:BindToRenderStep("SensacaoVoo", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local camera = workspace.CurrentCamera
		local flight = Config.Flight
		local state = FlightController.State

		-- FOV acompanha a velocidade (mais forte na arrancada).
		local boost = math.clamp((state.SpeedFraction - 0.3) / 1.2, 0, 1)
		local target = flight.FieldOfView + flight.FieldOfViewBoost * boost
		fov += (target - fov) * math.clamp(dt * 4, 0, 1)
		camera.FieldOfView = fov

		-- Inclinação leve da câmera, proporcional à do corpo.
		if flight.CameraRollDegrees > 0 and flight.BankDegrees > 0 then
			local roll = state.Bank / flight.BankDegrees * flight.CameraRollDegrees
			camera.CFrame *= CFrame.Angles(0, 0, math.rad(roll))
		end

		for _, leg in legs do
			leg.Part.CFrame = camera.CFrame * leg.Offset
		end
	end)
	Log.info("CameraController", "pronto")
end

return CameraController
