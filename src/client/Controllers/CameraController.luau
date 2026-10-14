--[[
	CameraController (cliente)

	Primeira pessoa confortável e com sensação de velocidade:
	- CameraMode = LockFirstPerson (default.project.json).
	- Campo de visão abre com a velocidade (Config.Flight.FieldOfViewBoost).
	- Leve inclinação da câmera nas curvas (Config.Flight.CameraRollDegrees; 0 desliga).
	- Sem balanço de câmera (evita enjoo).
	- Patas e carga na tela: ViewmodelController.
	- Configurações: sensibilidade do mouse e "Reduzir movimento" (sem FOV
	  de velocidade e sem inclinação).

	Dica de teste no Studio: Esc solta o mouse; Shift+F5 para o teste.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)

local ClientSettings = require(script.Parent.Parent.UI.ClientSettings)
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

-- Terceira pessoa (tecla V): câmera atrás da abelha, mouse preso no centro
-- (como o "shift lock"), então o voo continua igual.
local player = Players.LocalPlayer
local THIRD_DISTANCE = 16
local modalButtons: { GuiButton } = {}

local function trackModals(gui: Instance)
	local function check(item: Instance)
		if item:IsA("GuiButton") and item.Modal then
			table.insert(modalButtons, item)
		end
	end
	for _, item in gui:GetDescendants() do
		check(item)
	end
	gui.DescendantAdded:Connect(function(item)
		task.defer(check, item) -- Modal é ligado logo depois de criar
	end)
end

-- Algum painel com botão "Modal" está aberto? (aí o mouse fica livre)
local function panelOpen(): boolean
	for i = #modalButtons, 1, -1 do
		local button = modalButtons[i]
		if not button.Parent then
			table.remove(modalButtons, i)
		else
			local visible = true
			local node: Instance? = button
			while node and node:IsA("GuiObject") do
				if not (node :: GuiObject).Visible then
					visible = false
					break
				end
				node = node.Parent
			end
			if visible then
				return true
			end
		end
	end
	return false
end

local function applyCameraMode(third: boolean)
	if third then
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMaxZoomDistance = THIRD_DISTANCE
		player.CameraMinZoomDistance = THIRD_DISTANCE
	else
		player.CameraMinZoomDistance = 0.5
		player.CameraMaxZoomDistance = 0.5
		player.CameraMode = Enum.CameraMode.LockFirstPerson
	end
end

function CameraController:Start()
	local function applySettings(settings)
		applyCameraMode(settings.ThirdPerson)
		local sensitivity = tonumber(settings.Sensitivity) or 1
		UserInputService.MouseDeltaSensitivity = math.clamp(sensitivity, 0.25, 3)
	end
	applySettings(ClientSettings.Get())
	ClientSettings.Changed:Connect(applySettings)
	ContextActionService:BindAction("TrocarCamera", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			ClientSettings.Set("ThirdPerson", not ClientSettings.Get().ThirdPerson)
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.V)
	ContextActionService:SetTitle("TrocarCamera", "Câmera")
	ContextActionService:SetPosition("TrocarCamera", UDim2.new(1, -245, 1, -170))
	trackModals(player:WaitForChild("PlayerGui"))
	RunService:BindToRenderStep("MouseTerceiraPessoa", Enum.RenderPriority.Input.Value + 1, function()
		if ClientSettings.Get().ThirdPerson and not UserInputService.TouchEnabled then
			UserInputService.MouseBehavior = if panelOpen()
				then Enum.MouseBehavior.Default
				else Enum.MouseBehavior.LockCenter
		end
	end)

	local fov = Config.Flight.FieldOfView
	RunService:BindToRenderStep("SensacaoVoo", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local camera = workspace.CurrentCamera
		local flight = Config.Flight
		local state = FlightController.State

		-- FOV acompanha a velocidade (mais forte na arrancada).
		local reduced = ClientSettings.Get().ReducedMotion
		local boost = if reduced then 0 else math.clamp((state.SpeedFraction - 0.3) / 1.2, 0, 1)
		local target = flight.FieldOfView + flight.FieldOfViewBoost * boost
		fov += (target - fov) * math.clamp(dt * 4, 0, 1)
		camera.FieldOfView = fov

		-- Inclinação leve da câmera, proporcional à do corpo.
		if
			flight.CameraRollDegrees > 0
			and flight.BankDegrees > 0
			and ClientSettings.Get().CameraRoll
			and not reduced
		then
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
