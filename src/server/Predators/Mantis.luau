--[[
	Mantis — louva-a-deus (segundo predador).

	Diferente da aranha, ele NÃO persegue: fica de tocaia no alto de um
	cogumelo do bosque e ataca com um bote rápido em linha reta.

	Estados:
	- Espreitando: parado no poleiro, balançando devagar. Vira para a abelha
	  mais próxima que enxergar.
	- Mirando: a abelha chegou no alcance do bote. Ergue os braços, olhos
	  vermelhos e "!" por AttackWindup segundos. No FIM do aviso, ele marca
	  onde a abelha está e dá o bote até lá.
	- Bote: voa em linha reta muito rápido. Se a cabeça chegar perto da
	  abelha (StrikeRadius), acerta. Quem se mexeu durante o aviso escapa.
	- Recuando: volta para o poleiro e espera AttackCooldown.

	Respeita o PredatorBase: território, áreas protegidas e proteção ao nascer.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local PredatorBase = require(script.Parent.PredatorBase)

local Mantis = setmetatable({}, { __index = PredatorBase })
Mantis.__index = Mantis

export type Hooks = {
	IsAlive: (Player) -> boolean,
	IsProtected: (Player) -> boolean,
	Damage: (Player, number) -> boolean,
	Slow: (Player, number, number) -> (),
	AllPlayers: () -> { Player },
}

local GREEN = Color3.fromRGB(110, 185, 70)
local DARK = Color3.fromRGB(70, 130, 50)
local EYE = Color3.fromRGB(220, 240, 90)
local EYE_ANGRY = Color3.fromRGB(255, 40, 40)

local SHOULDER_Y = 8.4
local SHOULDER_Z = -1.6

local function part(name: string, size: Vector3, color: Color3, parent: Instance, shape: Enum.PartType?): Part
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
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

-- Corpo em volta da origem (pés no chão, frente = -Z).
local function buildModel(parent: Instance): (Model, BillboardGui, { BasePart })
	local model = Instance.new("Model")
	model.Name = "LouvaDeus"

	local root = part("Raiz", Vector3.one, GREEN, model)
	root.Transparency = 1
	model.PrimaryPart = root

	local function at(p: BasePart, offset: CFrame, arm: number?)
		p:SetAttribute("Offset", offset)
		if arm then
			p:SetAttribute("Braco", arm) -- -1 esquerdo, 1 direito
		end
		p.CFrame = offset
	end

	-- Abdômen comprido inclinado para trás.
	at(
		part("Abdomen", Vector3.new(2.4, 2.2, 8), GREEN, model, Enum.PartType.Ball),
		CFrame.new(0, 4.2, 3.6) * CFrame.Angles(math.rad(12), 0, 0)
	)
	-- Asas dobradas por cima.
	for side = -1, 1, 2 do
		local wing = part("Asa", Vector3.new(1.4, 0.15, 6.5), Color3.fromRGB(180, 230, 150), model)
		wing.Material = Enum.Material.Glass
		wing.Transparency = 0.35
		at(wing, CFrame.new(side * 0.5, 5.4, 3.4) * CFrame.Angles(math.rad(12), 0, math.rad(side * 10)))
	end
	-- Tórax em pé (o "pescoço" longo).
	at(
		part("Torax", Vector3.new(1.2, 1.2, 6), DARK, model, Enum.PartType.Cylinder),
		CFrame.new(0, 6.6, 0.2) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(0, 0, math.rad(-62))
	)
	-- Cabeça triangular e olhos grandes.
	at(part("Cabeca", Vector3.new(2.6, 1.8, 1.6), GREEN, model, Enum.PartType.Ball), CFrame.new(0, 10, -1.6))
	local eyes = {}
	for side = -1, 1, 2 do
		local eye = part("Olho", Vector3.new(1.1, 1.1, 1.1), EYE, model, Enum.PartType.Ball)
		eye.Material = Enum.Material.Neon
		at(eye, CFrame.new(side * 1.25, 10.3, -1.8))
		table.insert(eyes, eye)
		local antenna = part("Antena", Vector3.new(0.15, 0.15, 4), DARK, model)
		at(antenna, CFrame.new(side * 0.6, 11.6, -2.6) * CFrame.Angles(math.rad(-50), math.rad(side * 15), 0))
	end
	-- Braços de caça (dobrados), presos no ombro. Giram no ataque.
	for side = -1, 1, 2 do
		local x = side * 0.9
		at(
			part("Braco", Vector3.new(0.7, 0.7, 4), DARK, model),
			CFrame.new(x, SHOULDER_Y - 0.9, SHOULDER_Z - 1.6) * CFrame.Angles(math.rad(30), 0, 0),
			side
		)
		at(
			part("Garra", Vector3.new(0.6, 0.6, 3.6), GREEN, model),
			CFrame.new(x, SHOULDER_Y - 0.9, SHOULDER_Z - 2.4) * CFrame.Angles(math.rad(-55), 0, 0),
			side
		)
		for k = 0, 2 do
			at(
				part("Espinho", Vector3.new(0.2, 0.6, 0.2), Color3.fromRGB(40, 70, 30), model),
				CFrame.new(x, SHOULDER_Y - 1.4 + k * 0.5, SHOULDER_Z - 2.2 - k * 0.35),
				side
			)
		end
	end
	-- Quatro patas finas até o chão.
	for side = -1, 1, 2 do
		for _, z in { 1.2, 4.2 } do
			at(
				part("Pata", Vector3.new(0.3, 0.3, 5.6), DARK, model),
				CFrame.new(side * 2.2, 2.4, z)
					* CFrame.Angles(0, math.rad(90), 0)
					* CFrame.Angles(0, 0, math.rad(side * -55))
			)
		end
	end

	local warning = Instance.new("BillboardGui")
	warning.Name = "Aviso"
	warning.Size = UDim2.fromScale(4, 4)
	warning.StudsOffset = Vector3.new(0, 14, 0)
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
	return model, warning, eyes
end

function Mantis.new(perch: Vector3, parent: Instance, hooks: Hooks)
	local settings = Config.Predators.LouvaDeus
	local self = PredatorBase.new("LouvaDeus", perch, settings.TerritoryRadius)
	setmetatable(self, Mantis)

	self.Hooks = hooks
	self.Perch = perch
	self.State = "Espreitando"
	self.StateStart = os.clock()
	self.CooldownUntil = 0
	self.Facing = Vector3.new(0, 0, -1)
	self.ArmRaise = 0 -- 0 = dobrado, 1 = erguido (aviso), -1 = esticado (bote)
	self.LungeFrom = perch
	self.LungeTo = perch
	self.Pitch = 0

	local model, warning, eyes = buildModel(parent)
	self.Model = model
	self.Warning = warning
	self.Eyes = eyes
	self:Render(0)
	return self
end

function Mantis:SetState(state: string)
	self.State = state
	self.StateStart = os.clock()
	self.Warning.Enabled = state == "Mirando"
	for _, eye in self.Eyes do
		eye.Color = if state == "Mirando" or state == "Bote" then EYE_ANGRY else EYE
	end
end

function Mantis:Render(shake: number)
	local base = CFrame.lookAt(self.Position, self.Position + self.Facing) * CFrame.Angles(self.Pitch, 0, 0)
	if shake > 0 then
		base *= CFrame.new(math.random() * shake - shake / 2, 0, math.random() * shake - shake / 2)
	end
	local model = self.Model :: Model
	(model.PrimaryPart :: BasePart).CFrame = base
	-- Braços giram em volta do ombro conforme ArmRaise.
	local armAngle = if self.ArmRaise >= 0
		then -self.ArmRaise * math.rad(70)
		else -self.ArmRaise * math.rad(45)
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") then
			local offset = p:GetAttribute("Offset")
			if typeof(offset) == "CFrame" then
				if p:GetAttribute("Braco") then
					local pivot = CFrame.new(0, SHOULDER_Y, SHOULDER_Z)
					p.CFrame = base * pivot * CFrame.Angles(armAngle, 0, 0) * pivot:Inverse() * offset
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

function Mantis:Face(position: Vector3, dt: number)
	local flat = Vector3.new(position.X - self.Position.X, 0, position.Z - self.Position.Z)
	if flat.Magnitude > 0.1 then
		self.Facing = self.Facing:Lerp(flat.Unit, math.clamp(dt * 6, 0, 1))
		if self.Facing.Magnitude < 0.01 then
			self.Facing = flat.Unit
		end
	end
end

function Mantis:Update(dt: number, activity: number)
	local settings = Config.Predators.LouvaDeus
	local hooks = self.Hooks
	local now = os.clock()

	local target = self.Target
	local targetValid = target ~= nil and self:IsValidTarget(target, hooks.IsAlive, hooks.IsProtected)
	local headOffset = Vector3.new(0, 10, 0)

	if self.State == "Espreitando" then
		self.ArmRaise += (0 - self.ArmRaise) * math.clamp(dt * 4, 0, 1)
		self.Pitch += (0 - self.Pitch) * math.clamp(dt * 4, 0, 1)
		-- Balança devagar, como folha ao vento (camuflagem).
		self.Position = self.Perch + Vector3.new(0, math.sin(now * 0.8) * 0.15, 0)
		local found = self:FindTarget(settings.DetectionRange * activity, hooks.IsAlive, hooks.IsProtected)
		self.Target = found
		if found then
			local goal = rootPosition(found) :: Vector3
			self:Face(goal, dt)
			local distance = (goal - (self.Position + headOffset)).Magnitude
			if distance <= settings.LungeDistance and now >= self.CooldownUntil then
				self:SetState("Mirando")
			end
		end
		self:Render(0)
	elseif self.State == "Mirando" then
		self.ArmRaise += (1 - self.ArmRaise) * math.clamp(dt * 8, 0, 1)
		if targetValid then
			self:Face(rootPosition(target :: Player) :: Vector3, dt)
		end
		self:Render(0.25)
		if now - self.StateStart >= settings.AttackWindup then
			if not targetValid then
				self:SetState("Recuando")
			else
				-- Marca onde a abelha está AGORA e dá o bote até lá (limitado).
				local goal = rootPosition(target :: Player) :: Vector3
				local from = self.Position
				local delta = (goal - headOffset) - from
				if delta.Magnitude > settings.LungeDistance then
					delta = delta.Unit * settings.LungeDistance
				end
				self.LungeFrom = from
				self.LungeTo = from + delta
				self:SetState("Bote")
			end
		end
	elseif self.State == "Bote" then
		self.ArmRaise += (-1 - self.ArmRaise) * math.clamp(dt * 12, 0, 1)
		local total = (self.LungeTo - self.LungeFrom).Magnitude
		local travelled = (now - self.StateStart) * settings.LungeSpeed
		local t = if total > 0 then math.clamp(travelled / total, 0, 1) else 1
		local nextPosition = self.LungeFrom:Lerp(self.LungeTo, t)
		-- Nunca entra em área protegida nem sai do território.
		if self:CanEnter(nextPosition) then
			self.Position = nextPosition
		else
			t = 1
		end
		local direction = self.LungeTo - self.LungeFrom
		if direction.Magnitude > 0.1 then
			self.Pitch = math.clamp(-math.asin(direction.Unit.Y), -0.8, 0.8) * 0.6
		end
		self:Render(0)
		if t >= 1 then
			if targetValid then
				local goal = rootPosition(target :: Player) :: Vector3
				if (goal - (self.Position + headOffset)).Magnitude <= settings.StrikeRadius then
					hooks.Damage(target :: Player, settings.AttackDamage)
				end
			end
			self.CooldownUntil = now + settings.AttackCooldown
			self:SetState("Recuando")
		end
	elseif self.State == "Recuando" then
		self.ArmRaise += (0 - self.ArmRaise) * math.clamp(dt * 4, 0, 1)
		self.Pitch += (0 - self.Pitch) * math.clamp(dt * 4, 0, 1)
		local delta = self.Perch - self.Position
		if delta.Magnitude < 1 then
			self.Position = self.Perch
			self.Target = nil
			self:SetState("Espreitando")
		else
			self.Position += delta.Unit * math.min(delta.Magnitude, settings.ReturnSpeed * dt)
		end
		self:Render(0)
	end
end

return Mantis
