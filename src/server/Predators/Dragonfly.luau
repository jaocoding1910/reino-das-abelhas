--[[
	Dragonfly — libélula do Lago das Libélulas (terceiro predador).

	Estados:
	- Patrulhando: voa em círculo sobre o lago, balançando.
	- Mirando: viu uma abelha. Para no ar, vira para ela, olhos vermelhos
	  e "!" por AttackWindup segundos.
	- Rasante: dispara em linha reta até ONDE a abelha estava no fim do
	  aviso (e passa um pouco além). Acerta se passar perto. Desviar salva!
	- Voltando: volta para o círculo e espera AttackCooldown.

	Respeita o PredatorBase: território, áreas protegidas e proteção ao nascer.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local PredatorBase = require(script.Parent.PredatorBase)

local Dragonfly = setmetatable({}, { __index = PredatorBase })
Dragonfly.__index = Dragonfly

export type Hooks = {
	IsAlive: (Player) -> boolean,
	IsProtected: (Player) -> boolean,
	Damage: (Player, number) -> boolean,
	Slow: (Player, number, number) -> (),
	AllPlayers: () -> { Player },
}

local BODY = Color3.fromRGB(40, 150, 220)
local BODY_DARK = Color3.fromRGB(20, 80, 140)
local EYE = Color3.fromRGB(90, 230, 160)
local EYE_ANGRY = Color3.fromRGB(255, 50, 50)

local function part(name: string, size: Vector3, color: Color3, parent: Instance, oval: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if oval then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	p.Parent = parent
	return p
end

local function buildModel(parent: Instance): (Model, BillboardGui, { BasePart }, { BasePart })
	local model = Instance.new("Model")
	model.Name = "Libelula"
	local root = part("Raiz", Vector3.one, BODY, model)
	root.Transparency = 1
	model.PrimaryPart = root

	local function at(p: BasePart, offset: CFrame)
		p:SetAttribute("Offset", offset)
		p.CFrame = offset
	end

	-- Corpo comprido segmentado (frente = -Z).
	at(part("Torax", Vector3.new(2.2, 2.2, 3.6), BODY, model, true), CFrame.new(0, 0, -1))
	for i = 0, 6 do
		local segment = part(
			"Cauda",
			Vector3.new(1.1 - i * 0.07, 1.1 - i * 0.07, 2.2),
			if i % 2 == 0 then BODY else BODY_DARK,
			model,
			true
		)
		segment.Material = Enum.Material.Neon
		at(segment, CFrame.new(0, 0.1 * i, 1.8 + i * 1.9))
	end
	local eyes = {}
	for side = -1, 1, 2 do
		local eye = part("Olho", Vector3.new(1.5, 1.6, 1.5), EYE, model, true)
		eye.Material = Enum.Material.Neon
		at(eye, CFrame.new(side * 0.85, 0.3, -3.2))
		table.insert(eyes, eye)
	end
	-- Quatro asas transparentes (batem no Render).
	local wings = {}
	for side = -1, 1, 2 do
		for k, z in { -1.6, 0.2 } do
			local wing =
				part("Asa", Vector3.new(7, 0.1, 1.6 - k * 0.2), Color3.fromRGB(210, 240, 255), model, true)
			wing.Material = Enum.Material.Glass
			wing.Transparency = 0.45
			wing:SetAttribute("Lado", side)
			at(wing, CFrame.new(side * 3.8, 0.9, z))
			table.insert(wings, wing)
		end
	end

	local warning = Instance.new("BillboardGui")
	warning.Name = "Aviso"
	warning.Size = UDim2.fromScale(4, 4)
	warning.StudsOffset = Vector3.new(0, 5, 0)
	warning.AlwaysOnTop = true
	warning.LightInfluence = 0
	warning.Enabled = false
	warning.Adornee = root
	local mark = Instance.new("TextLabel")
	mark.Size = UDim2.fromScale(1, 1)
	mark.BackgroundTransparency = 1
	mark.Font = Enum.Font.GothamBlack
	mark.TextScaled = true
	mark.TextColor3 = Color3.fromRGB(255, 70, 70)
	mark.TextStrokeTransparency = 0.2
	mark.Text = "!"
	mark.Parent = warning
	warning.Parent = model

	model.Parent = parent
	return model, warning, eyes, wings
end

function Dragonfly.new(center: Vector3, phase: number, parent: Instance, hooks: Hooks)
	local settings = Config.Predators.Libelula
	local home = center + Vector3.new(0, settings.PatrolHeight, 0)
	local self = PredatorBase.new("Libelula", home, settings.TerritoryRadius)
	setmetatable(self, Dragonfly)
	self.Hooks = hooks
	self.Center = center
	self.Angle = phase
	self.State = "Patrulhando"
	self.StateStart = os.clock()
	self.CooldownUntil = 0
	self.Facing = Vector3.new(0, 0, -1)
	self.DashFrom = home
	self.DashTo = home
	self.Hit = false
	local model, warning, eyes, wings = buildModel(parent)
	self.Model = model
	self.Warning = warning
	self.Eyes = eyes
	self.Wings = wings
	self.Position = self:PatrolPoint()
	self:Render()
	return self
end

function Dragonfly:PatrolPoint(): Vector3
	local settings = Config.Predators.Libelula
	return self.Center
		+ Vector3.new(
			math.cos(self.Angle) * settings.PatrolRadius,
			settings.PatrolHeight + math.sin(self.Angle * 3) * 2,
			math.sin(self.Angle) * settings.PatrolRadius
		)
end

function Dragonfly:SetState(state: string)
	self.State = state
	self.StateStart = os.clock()
	self.Warning.Enabled = state == "Mirando"
	for _, eye in self.Eyes do
		eye.Color = if state == "Mirando" or state == "Rasante" then EYE_ANGRY else EYE
	end
end

function Dragonfly:Render()
	local base = CFrame.lookAt(self.Position, self.Position + self.Facing)
	local model = self.Model :: Model
	(model.PrimaryPart :: BasePart).CFrame = base
	local flap = math.sin(os.clock() * 40) * 0.35
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") then
			local offset = p:GetAttribute("Offset")
			if typeof(offset) == "CFrame" then
				local side = p:GetAttribute("Lado")
				if typeof(side) == "number" then
					p.CFrame = base * offset * CFrame.Angles(0, 0, flap * side)
				else
					p.CFrame = base * offset
				end
			end
		end
	end
end

local function rootPosition(player: Player): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root and root.Position
end

function Dragonfly:Face(target: Vector3, dt: number)
	local delta = target - self.Position
	if delta.Magnitude > 0.1 then
		self.Facing = self.Facing:Lerp(delta.Unit, math.clamp(dt * 6, 0, 1))
		if self.Facing.Magnitude < 0.01 then
			self.Facing = delta.Unit
		end
	end
end

function Dragonfly:Update(dt: number, activity: number)
	local settings = Config.Predators.Libelula
	local hooks = self.Hooks
	local now = os.clock()
	local target = self.Target
	local targetValid = target ~= nil and self:IsValidTarget(target, hooks.IsAlive, hooks.IsProtected)

	if self.State == "Patrulhando" then
		self.Angle += dt * settings.PatrolSpeed
		local goal = self:PatrolPoint()
		self:Face(goal, dt)
		self.Position = self.Position:Lerp(goal, math.clamp(dt * 3, 0, 1))
		if now >= self.CooldownUntil then
			local found =
				self:FindTarget(settings.DetectionRange * activity, hooks.IsAlive, hooks.IsProtected)
			if found then
				self.Target = found
				self:SetState("Mirando")
			end
		end
	elseif self.State == "Mirando" then
		if not targetValid then
			self:SetState("Voltando")
		else
			local goal = rootPosition(target :: Player) :: Vector3
			self:Face(goal, dt)
			-- Treme no ar enquanto mira.
			self.Position += Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 0.3
			if now - self.StateStart >= settings.AttackWindup then
				local direction = goal - self.Position
				if direction.Magnitude < 0.1 then
					direction = self.Facing
				end
				self.DashFrom = self.Position
				self.DashTo = goal + direction.Unit * settings.DashOvershoot
				self.Hit = false
				self:SetState("Rasante")
			end
		end
	elseif self.State == "Rasante" then
		local total = (self.DashTo - self.DashFrom).Magnitude
		local travelled = (now - self.StateStart) * settings.DashSpeed
		local t = if total > 0 then math.clamp(travelled / total, 0, 1) else 1
		local nextPosition = self.DashFrom:Lerp(self.DashTo, t)
		if self:CanEnter(nextPosition) then
			self.Position = nextPosition
		else
			t = 1
		end
		self.Facing = (self.DashTo - self.DashFrom).Unit
		if not self.Hit and targetValid then
			local goal = rootPosition(target :: Player) :: Vector3
			if (goal - self.Position).Magnitude <= settings.StrikeRadius then
				self.Hit = true
				hooks.Damage(target :: Player, settings.AttackDamage)
			end
		end
		if t >= 1 then
			self.CooldownUntil = now + settings.AttackCooldown
			self.Target = nil
			self:SetState("Voltando")
		end
	elseif self.State == "Voltando" then
		local goal = self:PatrolPoint()
		self:Face(goal, dt)
		local delta = goal - self.Position
		local step = math.min(delta.Magnitude, 40 * dt)
		if delta.Magnitude > 0.1 then
			self.Position += delta.Unit * step
		end
		if delta.Magnitude < 3 then
			self:SetState("Patrulhando")
		end
	end
	self:Render()
end

return Dragonfly
