--[[
	Spider — aranha do bosque (primeiro predador).

	Estados:
	- Parada: perto da teia, balançando. Procura abelhas no alcance.
	- Perseguindo: anda até a abelha (no chão e subindo até MaxClimb).
	  Abelha que voa alto o bastante escapa!
	- Preparando: para, olhos e "!" vermelhos por AttackWindup segundos.
	  É a chance de fugir. Depois do aviso, golpeia se ainda alcançar.
	- Voltando: perdeu o alvo ou saiu do território; volta para a teia.

	Teia: encostar desacelera (WebSlowMultiplier por WebSlowDuration).
	A atividade (alcance de visão e velocidade) aumenta à noite.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local PredatorBase = require(script.Parent.PredatorBase)

local Spider = setmetatable({}, { __index = PredatorBase })
Spider.__index = Spider

export type Hooks = {
	IsAlive: (Player) -> boolean,
	IsProtected: (Player) -> boolean,
	Damage: (Player, number) -> boolean,
	Slow: (Player, number, number) -> (),
	AllPlayers: () -> { Player },
}

local BODY = Color3.fromRGB(40, 30, 35)
local MARK = Color3.fromRGB(230, 120, 40)

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

-- Monta o corpo em volta da origem (frente = -Z) e posiciona depois.
local function buildModel(parent: Instance): (Model, BillboardGui, { BasePart })
	local model = Instance.new("Model")
	model.Name = "Aranha"

	local root = part("Raiz", Vector3.new(1, 1, 1), BODY, model)
	root.Transparency = 1
	model.PrimaryPart = root

	local pieces = {}
	local function at(p: BasePart, offset: CFrame)
		p.CFrame = offset
		table.insert(pieces, p)
	end

	at(part("Corpo", Vector3.new(5, 5, 5), BODY, model, Enum.PartType.Ball), CFrame.new(0, 3, 0))
	at(part("Abdomen", Vector3.new(7, 7, 7), BODY, model, Enum.PartType.Ball), CFrame.new(0, 4, 5))
	at(part("Marca", Vector3.new(2.5, 2.5, 2.5), MARK, model, Enum.PartType.Ball), CFrame.new(0, 7, 5.5))

	local eyes = {}
	for i, x in { -0.9, 0.9, -0.4, 0.4 } do
		local eye =
			part("Olho", Vector3.new(0.7, 0.7, 0.7), Color3.fromRGB(255, 60, 60), model, Enum.PartType.Ball)
		eye.Material = Enum.Material.Neon
		at(eye, CFrame.new(x, if i <= 2 then 3.6 else 4.2, -2.3))
		table.insert(eyes, eye)
	end

	-- 8 patas: dois segmentos cada, abertas para os lados.
	for side = -1, 1, 2 do
		for i = 1, 4 do
			local z = -1.5 + (i - 1) * 1.3
			local upper = part("Pata", Vector3.new(0.5, 0.5, 5), BODY, model)
			at(
				upper,
				CFrame.new(side * 3.5, 4.2, z)
					* CFrame.Angles(0, 0, math.rad(35 * side))
					* CFrame.Angles(0, math.rad(90), 0)
			)
			local lower = part("Pata", Vector3.new(0.4, 0.4, 5), BODY, model)
			at(
				lower,
				CFrame.new(side * 6.5, 2, z)
					* CFrame.Angles(0, 0, math.rad(-60 * side))
					* CFrame.Angles(0, math.rad(90), 0)
			)
		end
	end

	-- Aviso de ataque.
	local warning = Instance.new("BillboardGui")
	warning.Name = "Aviso"
	warning.Size = UDim2.fromScale(4, 4)
	warning.StudsOffset = Vector3.new(0, 11, 0)
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

	-- Guarda o deslocamento de cada peça em relação à raiz.
	for _, p in pieces do
		p:SetAttribute("Offset", p.CFrame)
	end

	model.Parent = parent
	return model, warning, eyes
end

local function buildWeb(parent: Instance, center: Vector3)
	local model = Instance.new("Model")
	model.Name = "Teia"
	local radius = Config.Predators.Spider.WebRadius
	for i = 1, 6 do
		local angle = i * math.pi / 3
		local strand = part("Fio", Vector3.new(0.2, 0.2, radius * 2), Color3.fromRGB(240, 240, 250), model)
		strand.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, angle) * CFrame.Angles(0, math.rad(90), 0)
		strand.Material = Enum.Material.Neon
		strand.Transparency = 0.4
	end
	local sheet = part(
		"Lencol",
		Vector3.new(0.2, radius * 2, radius * 2),
		Color3.fromRGB(240, 240, 255),
		model,
		Enum.PartType.Cylinder
	)
	sheet.CFrame = CFrame.new(center) * CFrame.Angles(0, math.rad(90), 0)
	sheet.Transparency = 0.8
	sheet.Material = Enum.Material.ForceField
	model.Parent = parent
end

function Spider.new(home: Vector3, parent: Instance, hooks: Hooks)
	local settings = Config.Predators.Spider
	local self = PredatorBase.new("Aranha", home, settings.TerritoryRadius)
	setmetatable(self, Spider)

	self.Hooks = hooks
	self.State = "Parada"
	self.StateStart = os.clock()
	self.CooldownUntil = 0
	self.Facing = Vector3.new(0, 0, -1)
	self.WebCenter = home + Vector3.new(0, 12, 0)

	buildWeb(parent, self.WebCenter)
	local model, warning, eyes = buildModel(parent)
	self.Model = model
	self.Warning = warning
	self.Eyes = eyes
	self:Render(0)
	return self
end

function Spider:SetState(state: string)
	self.State = state
	self.StateStart = os.clock()
	self.Warning.Enabled = state == "Preparando"
	for _, eye in self.Eyes do
		eye.Color = if state == "Preparando" then Color3.fromRGB(255, 20, 20) else Color3.fromRGB(255, 90, 90)
	end
end

function Spider:Render(shake: number)
	local base = CFrame.lookAt(self.Position, self.Position + self.Facing)
	if shake > 0 then
		base *= CFrame.new(math.random() * shake - shake / 2, 0, math.random() * shake - shake / 2)
	end
	local model = self.Model :: Model
	(model.PrimaryPart :: BasePart).CFrame = base
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") then
			local offset = p:GetAttribute("Offset")
			if typeof(offset) == "CFrame" then
				p.CFrame = base * offset
			end
		end
	end
end

local function rootPosition(player: Player): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root and root.Position
end

-- Anda até `goal` sem sair do território nem entrar em área protegida.
function Spider:MoveToward(goal: Vector3, speed: number, dt: number)
	local settings = Config.Predators.Spider
	local clampedY = math.clamp(goal.Y - 3, self.Home.Y, self.Home.Y + settings.MaxClimb)
	local target = Vector3.new(goal.X, clampedY, goal.Z)
	local delta = target - self.Position
	if delta.Magnitude < 0.1 then
		return
	end
	local step = delta.Unit * math.min(delta.Magnitude, speed * dt)
	local nextPosition = self.Position + step
	if self:CanEnter(nextPosition) then
		self.Position = nextPosition
	end
	local flat = Vector3.new(delta.X, 0, delta.Z)
	if flat.Magnitude > 0.1 then
		self.Facing = flat.Unit
	end
end

function Spider:Update(dt: number, activity: number)
	local settings = Config.Predators.Spider
	local hooks = self.Hooks
	local now = os.clock()
	local speed = settings.MoveSpeed * math.max(activity, 0.8)

	-- Teia: quem encosta fica lento (reaplica no máximo a cada 0,5 s).
	self.WebTouched = self.WebTouched or {}
	for _, player in hooks.AllPlayers() do
		local position = rootPosition(player)
		if
			position
			and (position - self.WebCenter).Magnitude <= settings.WebRadius
			and hooks.IsAlive(player)
			and now - (self.WebTouched[player] or 0) > 0.5
		then
			self.WebTouched[player] = now
			hooks.Slow(player, settings.WebSlowMultiplier, settings.WebSlowDuration)
		end
	end

	local target = self.Target
	local targetValid = target ~= nil and self:IsValidTarget(target, hooks.IsAlive, hooks.IsProtected)

	if self.State == "Parada" then
		self.Position = self.Home + Vector3.new(0, math.abs(math.sin(now * 1.5)) * 0.4, 0)
		local found = self:FindTarget(settings.DetectionRange * activity, hooks.IsAlive, hooks.IsProtected)
		if found then
			self.Target = found
			self:SetState("Perseguindo")
		end
		self:Render(0)
	elseif self.State == "Perseguindo" then
		if not targetValid then
			self.Target = nil
			self:SetState("Voltando")
		else
			local goal = rootPosition(target :: Player) :: Vector3
			self:MoveToward(goal, speed, dt)
			local distance = (goal - (self.Position + Vector3.new(0, 4, 0))).Magnitude
			if distance <= settings.AttackRange and now >= self.CooldownUntil then
				self:SetState("Preparando")
			end
		end
		self:Render(0)
	elseif self.State == "Preparando" then
		-- Aviso visível: treme parada antes do golpe.
		self:Render(0.4)
		if now - self.StateStart >= settings.AttackWindup then
			if targetValid then
				local goal = rootPosition(target :: Player) :: Vector3
				local distance = (goal - (self.Position + Vector3.new(0, 4, 0))).Magnitude
				if distance <= settings.AttackRange * 1.3 then
					if hooks.Damage(target :: Player, settings.AttackDamage) then
						hooks.Slow(target :: Player, settings.WebSlowMultiplier, settings.WebSlowDuration)
					end
				end
			end
			self.CooldownUntil = now + settings.AttackCooldown
			self:SetState(if targetValid then "Perseguindo" else "Voltando")
		end
	elseif self.State == "Voltando" then
		self:MoveToward(self.Home + Vector3.new(0, 3, 0), speed * 0.7, dt)
		if (self.Position - self.Home).Magnitude < 2 then
			self.Position = self.Home
			self:SetState("Parada")
		else
			-- No caminho de volta, pode avistar outra abelha.
			local found =
				self:FindTarget(settings.DetectionRange * activity * 0.7, hooks.IsAlive, hooks.IsProtected)
			if found then
				self.Target = found
				self:SetState("Perseguindo")
			end
		end
		self:Render(0)
	end
end

return Spider
