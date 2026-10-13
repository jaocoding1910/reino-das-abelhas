--[[
	FlightController (cliente)

	Voo da abelha com sensação de jogo:
	- Velocidade suave (aceleração), subir/descer, teto de altitude.
	- Inclinação do corpo nas curvas (bank) e para a frente ao acelerar.
	- Arrancada (Shift / botão "Arrancar") que gasta fôlego e recupera parada.
	- A carga, as melhorias, a especialidade e a teia mudam a velocidade:
	  o servidor define o atributo "SpeedMultiplier" no Player.

	Outros controladores leem FlightController.State (velocidade, inclinação,
	fôlego) para câmera, som e interface.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)

local InputController = require(script.Parent.InputController)

local FlightController = {}

FlightController.State = {
	SpeedFraction = 0, -- 0 parado · 1 velocidade base · >1 arrancada
	Bank = 0, -- graus de inclinação lateral atual
	Stamina = Config.Flight.StaminaMax,
	Sprinting = false,
}

local player = Players.LocalPlayer
local connection: RBXScriptConnection? = nil

local function stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	FlightController.State.SpeedFraction = 0
	FlightController.State.Bank = 0
end

local function yawOf(vector: Vector3): number
	return math.atan2(-vector.X, -vector.Z)
end

local function angleDelta(a: number, b: number): number
	local d = (b - a) % (2 * math.pi)
	if d > math.pi then
		d -= 2 * math.pi
	end
	return d
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
	local bank = 0
	local pitch = 0
	local lastYaw: number? = nil
	local lastSprintTime = 0
	local state = FlightController.State
	state.Stamina = Config.Flight.StaminaMax

	connection = RunService.Heartbeat:Connect(function(dt)
		if not root.Parent or humanoid.Health <= 0 then
			stop()
			return
		end
		local flight = Config.Flight
		local now = os.clock()

		-- Velocidade alvo (servidor manda o multiplicador).
		local multiplier = player:GetAttribute("SpeedMultiplier")
		local speed = flight.BaseSpeed * (if typeof(multiplier) == "number" then multiplier else 1)
		local moving = humanoid.MoveDirection.Magnitude > 0.1

		-- Arrancada com fôlego.
		local sprinting = InputController.IsSprinting() and moving and state.Stamina > 0
		if sprinting then
			speed *= flight.SprintMultiplier
			state.Stamina = math.max(0, state.Stamina - flight.StaminaDrainPerSecond * dt)
			lastSprintTime = now
		elseif now - lastSprintTime > flight.StaminaRegenDelay then
			state.Stamina = math.min(flight.StaminaMax, state.Stamina + flight.StaminaRegenPerSecond * dt)
		end
		state.Sprinting = sprinting

		local horizontal = humanoid.MoveDirection * speed
		local vertical = InputController.GetVertical() * flight.VerticalSpeed
		local target = Vector3.new(horizontal.X, vertical, horizontal.Z)
		if root.Position.Y >= flight.MaxAltitude and target.Y > 0 then
			target = Vector3.new(target.X, 0, target.Z)
		end

		local alpha = math.clamp(dt * flight.Acceleration, 0, 1)
		current = current:Lerp(target, alpha)
		velocity.VectorVelocity = current
		state.SpeedFraction = current.Magnitude / flight.BaseSpeed

		-- Direção da câmera e quanto ela girou neste quadro (para inclinar).
		local camera = workspace.CurrentCamera
		local look = camera.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude > 0.01 then
			flat = flat.Unit
			local yaw = yawOf(flat)
			local yawRate = if lastYaw then angleDelta(lastYaw, yaw) / math.max(dt, 1e-3) else 0
			lastYaw = yaw

			-- Inclinação: curva da câmera + deslize lateral.
			local right = camera.CFrame.RightVector
			local lateral = current:Dot(Vector3.new(right.X, 0, right.Z)) / flight.BaseSpeed
			local bankTarget = math.clamp(yawRate * 9 - lateral * 14, -flight.BankDegrees, flight.BankDegrees)
			bank += (bankTarget - bank) * math.clamp(dt * 5, 0, 1)

			-- Para a frente ao acelerar; nariz para cima/baixo ao subir/descer.
			local forward = current:Dot(flat) / flight.BaseSpeed
			local pitchTarget = math.clamp(-forward * 10 + current.Y / flight.VerticalSpeed * 12, -18, 18)
			pitch += (pitchTarget - pitch) * math.clamp(dt * 4, 0, 1)

			orientation.CFrame = CFrame.lookAt(Vector3.zero, flat)
				* CFrame.Angles(math.rad(pitch), 0, math.rad(bank))
		end
		state.Bank = bank
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
