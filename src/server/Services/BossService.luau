--[[
	BossService (servidor) — Vespa Gigante (chefe cooperativo)

	- Toda noite, pouco depois de escurecer, a Vespa Gigante aparece voando
	  em volta da Colmeia Real (zona de disputa). Some ao amanhecer.
	- Vida = BaseHealth + HealthPerPlayer × jogadores no servidor.
	- Ataque: escolhe uma abelha perto, avisa (olhos vermelhos e "!") e dá
	  um mergulho até onde ela estava. Desviar salva.
	- As abelhas atacam com o mesmo clique do combate (CombatService chama
	  BossService.TryHit). Quem acertou ao menos uma vez ganha a recompensa.
	- Estado para o HUD: atributos no workspace
	  ChefeAtivo, ChefeVida, ChefeVidaMax.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Remotes = require(Shared.Remotes)

local HealthService = require(script.Parent.HealthService)
local Notifier = require(script.Parent.Parent.Lib.Notifier)
local PlayerDataService = require(script.Parent.PlayerDataService)
local PredatorBase = require(script.Parent.Parent.Predators.PredatorBase)
local ProgressionService = require(script.Parent.ProgressionService)

local BossService = {}

local YELLOW = Color3.fromRGB(255, 190, 30)
local BLACK = Color3.fromRGB(25, 20, 20)
local EYE = Color3.fromRGB(255, 120, 40)
local EYE_ANGRY = Color3.fromRGB(255, 20, 20)

type Boss = {
	Brain: any, -- PredatorBase (território, alvos)
	Model: Model,
	Root: BasePart,
	Eyes: { BasePart },
	Warning: BillboardGui,
	Health: number,
	MaxHealth: number,
	State: string,
	StateStart: number,
	NextAttack: number,
	Angle: number,
	Facing: Vector3,
	DiveFrom: Vector3,
	DiveTo: Vector3,
	Hit: boolean,
	Contributors: { [Player]: boolean },
}

local boss: Boss? = nil
local center = Vector3.zero

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
	if oval then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	p.Parent = parent
	return p
end

local function buildModel(): (Model, BasePart, { BasePart }, BillboardGui)
	local model = Instance.new("Model")
	model.Name = "VespaGigante"
	local root = part("Raiz", Vector3.one, BLACK, model)
	root.Transparency = 1
	model.PrimaryPart = root
	local function at(p: BasePart, offset: CFrame)
		p:SetAttribute("Offset", offset)
	end
	-- Abdômen listrado (frente = -Z).
	for i = 0, 4 do
		local band = part(
			"Abdomen",
			Vector3.new(9 - math.abs(i - 1.5) * 1.2, 9 - math.abs(i - 1.5) * 1.2, 3.4),
			if i % 2 == 0 then YELLOW else BLACK,
			model,
			true
		)
		at(band, CFrame.new(0, -0.5 - i * 0.4, 5 + i * 2.6))
	end
	local stinger = part("Ferrao", Vector3.new(1.2, 1.2, 5), BLACK, model, true)
	at(stinger, CFrame.new(0, -2.4, 17.5) * CFrame.Angles(math.rad(-12), 0, 0))
	at(part("Torax", Vector3.new(6.5, 6, 7), BLACK, model, true), CFrame.new(0, 0.5, -1.5))
	at(part("Cabeca", Vector3.new(7, 6, 5), YELLOW, model, true), CFrame.new(0, 1.2, -6.8))
	local eyes = {}
	for side = -1, 1, 2 do
		local eye = part("Olho", Vector3.new(2.6, 3.4, 2.2), EYE, model, true)
		eye.Material = Enum.Material.Neon
		at(eye, CFrame.new(side * 2.3, 2, -8.4))
		table.insert(eyes, eye)
		local mandible = part("Mandibula", Vector3.new(0.8, 0.8, 2.4), BLACK, model)
		at(mandible, CFrame.new(side * 1.1, -1, -9.4) * CFrame.Angles(0, math.rad(side * 20), 0))
		local antenna = part("Antena", Vector3.new(0.35, 0.35, 6), BLACK, model)
		at(antenna, CFrame.new(side * 1.4, 4.6, -9.5) * CFrame.Angles(math.rad(40), math.rad(side * 15), 0))
		for k, z in { -3.2, -0.8, 1.6 } do
			local leg = part("Pata", Vector3.new(0.6, 0.6, 7), BLACK, model)
			at(
				leg,
				CFrame.new(side * 4.4, -3.2, z)
					* CFrame.Angles(0, math.rad(90), 0)
					* CFrame.Angles(0, 0, math.rad(side * (55 - k * 5)))
			)
		end
		for k, z in { -2, 1.2 } do
			local wing =
				part("Asa", Vector3.new(14 - k * 2, 0.2, 4.4), Color3.fromRGB(230, 220, 200), model, true)
			wing.Material = Enum.Material.Glass
			wing.Transparency = 0.4
			wing:SetAttribute("Lado", side)
			at(wing, CFrame.new(side * 8, 4, z) * CFrame.Angles(0, math.rad(side * 15), 0))
		end
	end
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 120, 40)
	glow.Range = 40
	glow.Brightness = 1.5
	glow.Parent = root

	local warning = Instance.new("BillboardGui")
	warning.Name = "Aviso"
	warning.Size = UDim2.fromScale(10, 10)
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
	mark.TextColor3 = Color3.fromRGB(255, 60, 60)
	mark.TextStrokeTransparency = 0.2
	mark.Text = "!"
	mark.Parent = warning
	warning.Parent = model

	local nameTag = Instance.new("BillboardGui")
	nameTag.Size = UDim2.fromScale(26, 4)
	nameTag.StudsOffset = Vector3.new(0, 10, 0)
	nameTag.MaxDistance = 400
	nameTag.LightInfluence = 0
	nameTag.Adornee = root
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 90, 60)
	label.TextStrokeTransparency = 0.2
	label.Text = "⚔️ Vespa Gigante"
	label.Parent = nameTag
	nameTag.Parent = model
	return model, root, eyes, warning
end

local function render(b: Boss)
	local base = CFrame.lookAt(b.Root.Position, b.Root.Position + b.Facing)
	local flap = math.sin(os.clock() * 30) * 0.4
	for _, p in b.Model:GetChildren() do
		if p:IsA("BasePart") then
			local offset = p:GetAttribute("Offset")
			if typeof(offset) == "CFrame" then
				local side = p:GetAttribute("Lado")
				p.CFrame = if typeof(side) == "number"
					then base * offset * CFrame.Angles(0, 0, flap * side)
					else base * offset
			end
		end
	end
end

local function publish(b: Boss?)
	workspace:SetAttribute("ChefeAtivo", b ~= nil)
	workspace:SetAttribute("ChefeVida", if b then math.max(0, math.ceil(b.Health)) else 0)
	workspace:SetAttribute("ChefeVidaMax", if b then b.MaxHealth else 0)
end

local function setState(b: Boss, state: string)
	b.State = state
	b.StateStart = os.clock()
	b.Warning.Enabled = state == "Mirando"
	for _, eye in b.Eyes do
		eye.Color = if state == "Mirando" or state == "Mergulho" then EYE_ANGRY else EYE
	end
end

local function orbitPoint(b: Boss): Vector3
	local settings = Config.Boss
	return center
		+ Vector3.new(
			math.cos(b.Angle) * settings.OrbitRadius,
			settings.OrbitHeight + math.sin(b.Angle * 2) * 6,
			math.sin(b.Angle) * settings.OrbitRadius
		)
end

local function despawn(message: string?)
	local b = boss
	if not b then
		return
	end
	b.Model:Destroy()
	boss = nil
	publish(nil)
	if message then
		Remotes.Get("WorldUpdated"):FireAllClients(message, "info")
	end
end

local function spawnBoss()
	if boss then
		return
	end
	local settings = Config.Boss
	local model, root, eyes, warning = buildModel()
	local maxHealth = settings.BaseHealth + settings.HealthPerPlayer * #Players:GetPlayers()
	local brain = PredatorBase.new("Vespa", center, Config.Regions.RoyalRadius)
	local b: Boss = {
		Brain = brain,
		Model = model,
		Root = root,
		Eyes = eyes,
		Warning = warning,
		Health = maxHealth,
		MaxHealth = maxHealth,
		State = "Rondando",
		StateStart = os.clock(),
		NextAttack = os.clock() + 6,
		Angle = 0,
		Facing = Vector3.new(0, 0, -1),
		DiveFrom = center,
		DiveTo = center,
		Hit = false,
		Contributors = {},
	}
	root.CFrame = CFrame.new(orbitPoint(b))
	model.Parent = workspace
	boss = b
	publish(b)
	render(b)
	Remotes.Get("WorldUpdated")
		:FireAllClients(
			"⚔️ A Vespa Gigante apareceu na Colmeia Real! Juntem-se para derrotá-la!",
			"erro"
		)
	Log.info("BossService", `vespa com {maxHealth} de vida`)
end

local function defeat(b: Boss)
	local position = b.Root.Position
	Remotes.Get("Effect"):FireAllClients("nivel", position)
	Remotes.Get("Effect"):FireAllClients("derrota", position)
	local names = {}
	for player in b.Contributors do
		if player.Parent and PlayerDataService.IsLoaded(player) then
			local profile = PlayerDataService.Get(player)
			profile.Honey += Config.Boss.RewardHoney
			profile.HoneyEarned += Config.Boss.RewardHoney
			profile.Stats.Chefe = (profile.Stats.Chefe or 0) + 1
			ProgressionService.AddXP(player, Config.Boss.RewardXP)
			Notifier.Notify(
				player,
				`⚔️ Vitória! +{Config.Boss.RewardHoney} mel · +{Config.Boss.RewardXP} XP`,
				"ok"
			)
			Notifier.Changed(player)
			table.insert(names, player.DisplayName)
		end
	end
	despawn(`🏆 A Vespa Gigante foi derrotada por {table.concat(names, ", ")}!`)
end

-- Chamado pelo CombatService quando uma abelha ataca (clique).
-- Retorna true se o ataque acertou a vespa.
function BossService.TryHit(attacker: Player, root: BasePart): boolean
	local b = boss
	if not b or b.Health <= 0 then
		return false
	end
	local offset = b.Root.Position - root.Position
	if offset.Magnitude > Config.Boss.HitRange then
		return false
	end
	b.Health -= Config.Boss.HitDamage
	b.Contributors[attacker] = true
	Remotes.Get("Effect"):FireAllClients("dano", b.Root.Position)
	publish(b)
	if b.Health <= 0 then
		defeat(b)
	end
	return true
end

local function rootPosition(player: Player): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root and root.Position
end

local function update(dt: number)
	local b = boss
	if not b then
		return
	end
	local settings = Config.Boss
	local now = os.clock()
	local position = b.Root.Position
	local target = b.Brain.Target
	local valid = target ~= nil
		and b.Brain:IsValidTarget(target, HealthService.IsAlive, HealthService.IsSpawnProtected)

	if b.State == "Rondando" then
		b.Angle += dt * 0.35
		local goal = orbitPoint(b)
		local nextPosition = position:Lerp(goal, math.clamp(dt * 1.5, 0, 1))
		local move = nextPosition - position
		if move.Magnitude > 0.05 then
			b.Facing = b.Facing:Lerp(move.Unit, math.clamp(dt * 3, 0, 1))
		end
		b.Root.CFrame = CFrame.new(nextPosition)
		if now >= b.NextAttack then
			b.Brain.Position = nextPosition
			local found = b.Brain:FindTarget(
				settings.TargetRange,
				HealthService.IsAlive,
				HealthService.IsSpawnProtected
			)
			if found then
				b.Brain.Target = found
				setState(b, "Mirando")
			else
				b.NextAttack = now + 1.5
			end
		end
	elseif b.State == "Mirando" then
		if not valid then
			b.NextAttack = now + 2
			setState(b, "Rondando")
		else
			local goal = rootPosition(target :: Player) :: Vector3
			local look = goal - position
			if look.Magnitude > 0.1 then
				b.Facing = b.Facing:Lerp(look.Unit, math.clamp(dt * 6, 0, 1))
			end
			b.Root.CFrame =
				CFrame.new(position + Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * 0.6)
			if now - b.StateStart >= settings.AttackWindup then
				b.DiveFrom = position
				b.DiveTo = goal + (goal - position).Unit * 15
				b.Hit = false
				setState(b, "Mergulho")
			end
		end
	elseif b.State == "Mergulho" then
		local total = (b.DiveTo - b.DiveFrom).Magnitude
		local t = if total > 0 then math.clamp((now - b.StateStart) * settings.DiveSpeed / total, 0, 1) else 1
		local nextPosition = b.DiveFrom:Lerp(b.DiveTo, t)
		if b.Brain:CanEnter(nextPosition) then
			b.Root.CFrame = CFrame.new(nextPosition)
		else
			t = 1
		end
		if not b.Hit and valid then
			local goal = rootPosition(target :: Player) :: Vector3
			if (goal - b.Root.Position).Magnitude <= settings.StrikeRadius then
				b.Hit = true
				HealthService.Damage(target :: Player, settings.AttackDamage, "Predador")
			end
		end
		if t >= 1 then
			b.Brain.Target = nil
			b.NextAttack = now + settings.AttackInterval
			setState(b, "Voltando")
		end
	elseif b.State == "Voltando" then
		local goal = orbitPoint(b)
		local delta = goal - position
		if delta.Magnitude < 4 then
			setState(b, "Rondando")
		else
			b.Facing = b.Facing:Lerp(delta.Unit, math.clamp(dt * 4, 0, 1))
			b.Root.CFrame = CFrame.new(position + delta.Unit * math.min(delta.Magnitude, 45 * dt))
		end
	end
	render(b)
end

BossService.Spawn = function()
	spawnBoss()
end

function BossService:Init()
	publish(nil)
end

function BossService:Start()
	local royal = Config.Map.RoyalHive
	center = royal.Position + Vector3.new(0, royal.PlateauHeight, 0)
	local spawnToken = 0
	workspace:GetAttributeChangedSignal("IsNight"):Connect(function()
		spawnToken += 1
		local token = spawnToken
		if workspace:GetAttribute("IsNight") == true then
			task.delay(20, function()
				if token == spawnToken and workspace:GetAttribute("IsNight") == true then
					spawnBoss()
				end
			end)
		else
			despawn("🌅 A Vespa Gigante fugiu com o sol.")
		end
	end)
	RunService.Heartbeat:Connect(update)
	Players.PlayerRemoving:Connect(function(player)
		local b = boss
		if b then
			b.Contributors[player] = nil
			if b.Brain.Target == player then
				b.Brain.Target = nil
			end
		end
	end)
	Log.info("BossService", "pronto (vespa aparece à noite)")
end

return BossService
