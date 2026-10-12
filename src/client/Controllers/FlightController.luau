--[[
	FlightController (cliente) — Etapa A

	Voo suave da abelha.

	Como funciona:
	- O Humanoid fica em PlatformStand (sem andar/pular/cair).
	- LinearVelocity controla a velocidade do HumanoidRootPart.
	- AlignOrientation vira a abelha para onde a câmera olha.
	- A velocidade alvo combina a direção dos controles (horizontal)
	  com Subir/Descer (vertical), e a velocidade atual se aproxima dela
	  aos poucos (Config.Flight.Acceleration) para não dar trancos.
	- A carga pesada reduz a velocidade: o servidor define o atributo
	  "SpeedMultiplier" no Player e este controlador obedece.

	Etapa D: o servidor passará a conferir velocidades impossíveis.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)

local InputController = require(script.Parent.InputController)

local FlightController = {}

local player = Players.LocalPlayer
local connection: RBXScriptConnection? = nil

local function stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
end

local function setup(character: Model)
	stop()

	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart

	humanoid.UseJumpPower = false
	humanoid.JumpHeight = 0
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	humanoid.PlatformStand = true

	local attachment = Instance.new("Attachment")
	attachment.Name = "VooAttachment"
	attachment.Parent = root

	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "VooVelocidade"
	velocity.Attachment0 = attachment
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.MaxForce = 1e6
	velocity.VectorVelocity = Vector3.zero
	velocity.Parent = root

	local orientation = Instance.new("AlignOrientation")
	orientation.Name = "VooOrientacao"
	orientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	orientation.Attachment0 = attachment
	orientation.MaxTorque = 1e6
	orientation.Responsiveness = 25
	orientation.CFrame = root.CFrame.Rotation
	orientation.Parent = root

	local current = Vector3.zero

	connection = RunService.Heartbeat:Connect(function(dt)
		if not root.Parent or humanoid.Health <= 0 then
			stop()
			return
		end

		local multiplier = player:GetAttribute("SpeedMultiplier")
		local speed = Config.Flight.BaseSpeed * (if typeof(multiplier) == "number" then multiplier else 1)

		local horizontal = humanoid.MoveDirection * speed
		local vertical = InputController.GetVertical() * Config.Flight.VerticalSpeed
		local target = Vector3.new(horizontal.X, vertical, horizontal.Z)

		-- Teto de altitude: não deixa subir além do limite.
		if root.Position.Y >= Config.Flight.MaxAltitude and target.Y > 0 then
			target = Vector3.new(target.X, 0, target.Z)
		end

		local alpha = math.clamp(dt * Config.Flight.Acceleration, 0, 1)
		current = current:Lerp(target, alpha)
		velocity.VectorVelocity = current

		-- Vira o corpo para a direção horizontal da câmera.
		local camera = workspace.CurrentCamera
		if camera then
			local look = camera.CFrame.LookVector
			local flat = Vector3.new(look.X, 0, look.Z)
			if flat.Magnitude > 0.01 then
				orientation.CFrame = CFrame.lookAt(Vector3.zero, flat.Unit)
			end
		end
	end)

	humanoid.Died:Connect(stop)
end

function FlightController:Init() end

function FlightController:Start()
	player.CharacterAdded:Connect(setup)
	if player.Character then
		task.spawn(setup, player.Character)
	end
	Log.info("FlightController", "pronto")
end

return FlightController
