--[[
	RoyalService (servidor) — a Rainha Abelha e seus pedidos especiais

	A Rainha fica num trono na frente do salão da Colmeia Real (zona de
	disputa: arriscado, mas vale a pena). Ao falar com ela:
	1. Sem pedido: "Aceitar" sorteia um pedido de Config.Royal.Requests,
	   com meta e recompensa maiores conforme o seu nível.
	2. O progresso anda sozinho (QuestService.Add conta os mesmos eventos).
	3. Pedido completo: volte e "Receber" → mel + XP.
	4. Depois espera Config.Royal.Cooldown para o próximo.

	O cliente só abre a conversa e pede "Aceitar"/"Receber"; o servidor
	confere a distância até a Rainha e todas as regras.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Levels = require(Shared.Levels)
local Log = require(Shared.Util.Log)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)

local AssetLibrary = require(script.Parent.Parent.Lib.AssetLibrary)
local Notifier = require(script.Parent.Parent.Lib.Notifier)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ProgressionService = require(script.Parent.ProgressionService)
local QuestService = require(script.Parent.QuestService)
local WorldService = require(script.Parent.WorldService)

local RoyalService = {}

local GOLD = Color3.fromRGB(245, 190, 60)
local RED = Color3.fromRGB(160, 25, 45)

local queenPosition = Vector3.zero
local lastRequest: { [Player]: number } = {}

local function part(name: string, size: Vector3, cf: CFrame, color: Color3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function weldTo(root: BasePart, p: BasePart)
	p.Anchored = false
	p.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = p
	weld.Parent = p
end

-- Abelha grande (pacote 3D se houver) + coroa + capa, presa a uma raiz ancorada.
local function buildQueen(parent: Instance, cf: CFrame): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "RainhaAbelha"
	local root = part("Raiz", Vector3.one, cf, GOLD, model)
	root.Transparency = 1
	model.PrimaryPart = root

	local body = AssetLibrary.Attach("Abelha", root, 16, CFrame.identity)
	if body then
		body.Parent = model
	else
		-- Sem o pacote 3D: corpo simples de bolas.
		local yellow = Color3.fromRGB(255, 196, 40)
		for i, info in { { 0, 0, 2, 9 }, { 0, 0.6, -4, 6.5 } } do
			local ball = part(
				if i == 1 then "Corpo" else "Cabeca",
				Vector3.one * info[4],
				cf * CFrame.new(info[1], info[2], info[3]),
				if i == 1 then yellow else Color3.fromRGB(35, 28, 24),
				model
			)
			ball.Shape = Enum.PartType.Ball
			weldTo(root, ball)
		end
	end

	-- Coroa: aro dourado, cinco pontas e joias.
	local crownCF = cf * CFrame.new(0, 3.5, -5.4)
	local ring =
		part("Coroa", Vector3.new(1.2, 4.6, 4.6), crownCF * CFrame.Angles(0, 0, math.rad(90)), GOLD, model)
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	weldTo(root, ring)
	for i = 0, 4 do
		local angle = i * math.pi * 2 / 5
		local spike = part(
			"Ponta",
			Vector3.new(0.6, 1.8, 0.6),
			crownCF * CFrame.new(math.cos(angle) * 2, 1.3, math.sin(angle) * 2),
			GOLD,
			model
		)
		spike.Material = Enum.Material.Neon
		weldTo(root, spike)
		local gem = part(
			"Joia",
			Vector3.one * 0.7,
			crownCF * CFrame.new(math.cos(angle) * 2, 2.3, math.sin(angle) * 2),
			if i % 2 == 0 then Color3.fromRGB(230, 40, 80) else Color3.fromRGB(80, 160, 255),
			model
		)
		gem.Shape = Enum.PartType.Ball
		gem.Material = Enum.Material.Neon
		weldTo(root, gem)
	end
	-- Gola real em volta do pescoço (entre a cabeça e o corpo): veludo vermelho
	-- com arminho branco. Cilindro com o eixo ao longo do corpo (Z).
	local alongBody = CFrame.Angles(0, math.rad(90), 0)
	local collar =
		part("Gola", Vector3.new(1.6, 9.2, 9.2), cf * CFrame.new(0, 0, -3.6) * alongBody, RED, model)
	collar.Shape = Enum.PartType.Cylinder
	collar.Material = Enum.Material.Fabric
	weldTo(root, collar)
	local fur = part(
		"Arminho",
		Vector3.new(0.8, 9.8, 9.8),
		cf * CFrame.new(0, 0, -4.4) * alongBody,
		Color3.fromRGB(250, 248, 240),
		model
	)
	fur.Shape = Enum.PartType.Cylinder
	fur.Material = Enum.Material.Fabric
	weldTo(root, fur)
	-- Pintinhas pretas do arminho.
	for k = 0, 5 do
		local angle = k * math.pi / 3
		local spot = part(
			"Pinta",
			Vector3.one * 0.6,
			cf * CFrame.new(math.cos(angle) * 4.6, math.sin(angle) * 4.6, -4.8),
			Color3.fromRGB(30, 25, 25),
			model
		)
		spot.Shape = Enum.PartType.Ball
		weldTo(root, spot)
	end

	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 210, 120)
	glow.Range = 22
	glow.Brightness = 0.5
	glow.Parent = ring

	model.Parent = parent
	return model, root
end

local function buildThrone(parent: Instance, base: Vector3)
	local dais = part(
		"Trono",
		Vector3.new(3, 26, 26),
		CFrame.new(base + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		GOLD,
		parent
	)
	dais.Shape = Enum.PartType.Cylinder
	dais.CanCollide = true
	dais.Reflectance = 0.15
	local carpet =
		part("Tapete", Vector3.new(10, 0.4, 40), CFrame.new(base + Vector3.new(0, 0.3, 30)), RED, parent)
	carpet.Material = Enum.Material.Fabric
	carpet.CanCollide = true
	for side = -1, 1, 2 do
		local pillar = part(
			"Pilar",
			Vector3.new(2.4, 18, 2.4),
			CFrame.new(base + Vector3.new(side * 14, 9, -4)),
			GOLD,
			parent
		)
		pillar.CanCollide = true
		local flame = part(
			"Chama",
			Vector3.new(2, 2.6, 2),
			CFrame.new(base + Vector3.new(side * 14, 19.4, -4)),
			Color3.fromRGB(255, 200, 90),
			parent
		)
		flame.Material = Enum.Material.Neon
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 180, 80)
		light.Range = 22
		light.Brightness = 0.5
		light.Parent = flame
	end
end

local function label(adornee: BasePart)
	local gui = Instance.new("BillboardGui")
	gui.Name = "NomeRainha"
	gui.Size = UDim2.fromScale(24, 4)
	gui.StudsOffset = Vector3.new(0, 13, 0)
	gui.MaxDistance = 260
	gui.LightInfluence = 0
	gui.Adornee = adornee
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBlack
	text.TextScaled = true
	text.TextColor3 = GOLD
	text.TextStrokeTransparency = 0.2
	text.Text = "👑 Rainha Melissa"
	text.Parent = gui
	gui.Parent = adornee
end

-- Pedido sorteado, ajustado ao nível do jogador.
function RoyalService.MakeRequest(level: number, pick: number): Types.RoyalQuest
	local base = Config.Royal.Requests[math.clamp(pick, 1, #Config.Royal.Requests)]
	local factor = 1 + math.max(0, level - 1) * Config.Royal.LevelScale
	return {
		Kind = base.Kind,
		Text = base.Text,
		Goal = math.max(1, math.floor(base.Goal * factor + 0.5)),
		Progress = 0,
		Honey = math.floor(base.Honey * factor + 0.5),
		XP = math.floor(base.XP * factor + 0.5),
	}
end

function RoyalService.Summary(player: Player)
	local profile = PlayerDataService.Get(player)
	local royal = profile.Royal
	return {
		Kind = royal.Kind,
		Text = royal.Text,
		Goal = royal.Goal,
		Progress = royal.Progress,
		Honey = royal.Honey,
		XP = royal.XP,
		Active = royal.Kind ~= "",
		Ready = royal.Kind ~= "" and royal.Progress >= royal.Goal,
		NextIn = math.max(0, profile.RoyalNextAt - os.time()),
		Completed = profile.RoyalCompleted,
		Position = queenPosition,
	}
end

local function near(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and (root.Position - queenPosition).Magnitude <= Config.Royal.TalkDistance
end

local function handle(player: Player, action: unknown)
	local now = os.clock()
	if now - (lastRequest[player] or 0) < 0.5 then
		return
	end
	lastRequest[player] = now
	if typeof(action) ~= "string" or not PlayerDataService.IsLoaded(player) then
		return
	end
	if not near(player) then
		Notifier.Notify(player, "Chegue mais perto da Rainha.", "erro")
		return
	end
	local profile = PlayerDataService.Get(player)
	local royal = profile.Royal

	if action == "Aceitar" then
		if royal.Kind ~= "" then
			Notifier.Notify(player, "Você já tem um pedido da Rainha.", "info")
			return
		end
		local wait = profile.RoyalNextAt - os.time()
		if wait > 0 then
			Notifier.Notify(player, `A Rainha terá um novo pedido em {math.ceil(wait / 60)} min.`, "info")
			return
		end
		local level = Levels.FromXP(profile.XP)
		profile.Royal = RoyalService.MakeRequest(level, math.random(1, #Config.Royal.Requests))
		Notifier.Notify(player, `👑 Novo pedido: {profile.Royal.Text} (0/{profile.Royal.Goal})`, "ok")
	elseif action == "Receber" then
		if royal.Kind == "" or royal.Progress < royal.Goal then
			Notifier.Notify(player, "O pedido ainda não está completo.", "erro")
			return
		end
		profile.Honey += royal.Honey
		profile.HoneyEarned += royal.Honey
		profile.RoyalCompleted += 1
		profile.RoyalNextAt = os.time() + Config.Royal.Cooldown
		profile.Royal = Types.EmptyRoyal()
		Notifier.Notify(player, `👑 A Rainha agradece! +{royal.Honey} mel · +{royal.XP} XP`, "ok")
		Remotes.Get("Effect"):FireAllClients("nivel", queenPosition, player.UserId)
		ProgressionService.AddXP(player, royal.XP)
		QuestService.Add(player, "Rainha", 1) -- conta para missões, conquistas e Rei da Colmeia
	else
		return
	end
	Notifier.Changed(player)
end

function RoyalService:Init() end

function RoyalService:Start()
	local royal = Config.Map.RoyalHive
	local floor = royal.Position + Vector3.new(0, royal.PlateauHeight, 0)
	local folder = Instance.new("Folder")
	folder.Name = "Rainha"
	folder.Parent = WorldService.GetMap().Folder

	-- Na frente do salão, olhando para as colmeias (+Z).
	local throneBase = floor + Vector3.new(0, 0, 62)
	buildThrone(folder, throneBase)
	local cf = CFrame.lookAt(throneBase + Vector3.new(0, 11, 0), throneBase + Vector3.new(0, 11, 100))
	queenPosition = cf.Position
	local _, root = buildQueen(folder, cf)
	label(root)

	-- Flutua devagar e vira o rosto para a abelha mais perto (as peças
	-- soldadas seguem a raiz). Gira no máximo ~90° para os lados, então ela
	-- nunca dá as costas para quem chega pela frente do salão.
	local yaw = 0
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 1 / 20 then
			return
		end
		local step = accumulator
		accumulator = 0
		local nearest, nearestDistance = nil, 110
		for _, other in Players:GetPlayers() do
			local character = other.Character
			local otherRoot = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if otherRoot then
				local distance = (otherRoot.Position - cf.Position).Magnitude
				if distance < nearestDistance then
					nearest, nearestDistance = otherRoot.Position, distance
				end
			end
		end
		local targetYaw = 0
		if nearest then
			local rel = cf:PointToObjectSpace(nearest)
			-- A frente é -Z: ângulo que leva -Z até o jogador.
			targetYaw = math.clamp(math.atan2(-rel.X, -rel.Z), -1.6, 1.6)
		end
		yaw += (targetYaw - yaw) * math.clamp(step * 2.5, 0, 1)
		local bob = (math.sin(os.clock() * 1.3) + 1) * 0.7
		root.CFrame = cf * CFrame.new(0, bob, 0) * CFrame.Angles(0, yaw, 0)
	end)

	-- O cliente abre a conversa ao acionar este aviso (atributo "Rainha").
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "FalarRainha"
	prompt.ActionText = "Falar com a Rainha"
	prompt.ObjectText = "Rainha Melissa"
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 48 -- dá para falar de longe (ela é grande)
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Rainha", true)
	prompt.Parent = root

	Remotes.Get("RequestRoyal").OnServerEvent:Connect(handle)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
	Log.info("RoyalService", "Rainha no trono")
end

return RoyalService
