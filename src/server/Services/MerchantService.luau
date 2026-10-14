--[[
	MerchantService (servidor) — Besouro mercador

	Um besouro com carrinho de mercadorias fica na praça do centro.
	Falando com ele (aviso "Falar com o Besouro"), o cliente abre a loja:
	- Poções (Config.Potions): pagas com mel, efeito temporário (Lib/Boosts).
	  Comprar de novo uma poção ativa soma o tempo.
	- Trocas (Config.Trades): favos da CARGA viram mel ou poção.
	O servidor confere distância, mel, carga e o intervalo entre pedidos.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Remotes = require(Shared.Remotes)

local Boosts = require(script.Parent.Parent.Lib.Boosts)
local InventoryService = require(script.Parent.InventoryService)
local Notifier = require(script.Parent.Parent.Lib.Notifier)
local PlayerDataService = require(script.Parent.PlayerDataService)
local QuestService = require(script.Parent.QuestService)
local WorldService = require(script.Parent.WorldService)

local MerchantService = {}

local SHELL = Color3.fromRGB(35, 110, 80)
local SHELL_DARK = Color3.fromRGB(20, 60, 45)
local WOOD = Color3.fromRGB(150, 105, 62)

local merchantPosition = Config.Merchant.Position
local lastRequest: { [Player]: number } = {}

local function part(
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	parent: Instance,
	shape: Enum.PartType?
): Part
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
	if shape == Enum.PartType.Ball and (size.X ~= size.Y or size.Y ~= size.Z) then
		-- Bola no Roblox é sempre esfera perfeita: para oval, usa malha de esfera.
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	elseif shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

-- Besouro (frente = -Z) em volta de `cf`, que fica no chão.
local function buildBeetle(parent: Instance, cf: CFrame): BasePart
	local model = Instance.new("Model")
	model.Name = "BesouroMercador"
	-- Casco: duas metades brilhantes com a linha do meio.
	for side = -1, 1, 2 do
		local half = part(
			"Casco",
			Vector3.new(3.4, 4.2, 7.5),
			cf * CFrame.new(side * 1.65, 3.6, 0.6),
			SHELL,
			model,
			Enum.PartType.Ball
		)
		half.Material = Enum.Material.Glass
		half.Reflectance = 0.25
	end
	part("Linha", Vector3.new(0.25, 4.3, 7.4), cf * CFrame.new(0, 3.7, 0.6), SHELL_DARK, model)
	part(
		"Barriga",
		Vector3.new(6, 2.4, 7),
		cf * CFrame.new(0, 2.2, 0.6),
		SHELL_DARK,
		model,
		Enum.PartType.Ball
	)
	-- Cabeça, chifre curvo e olhos.
	part(
		"Cabeca",
		Vector3.new(3.2, 2.6, 2.6),
		cf * CFrame.new(0, 2.9, -3.6),
		SHELL_DARK,
		model,
		Enum.PartType.Ball
	)
	part(
		"Chifre",
		Vector3.new(0.7, 0.7, 3.4),
		cf * CFrame.new(0, 4.2, -5.2) * CFrame.Angles(math.rad(35), 0, 0),
		SHELL_DARK,
		model
	)
	part(
		"Ponta",
		Vector3.new(0.6, 0.6, 1.8),
		cf * CFrame.new(0, 5.6, -6.2) * CFrame.Angles(math.rad(-30), 0, 0),
		SHELL_DARK,
		model
	)
	for side = -1, 1, 2 do
		local eye = part(
			"Olho",
			Vector3.one * 0.9,
			cf * CFrame.new(side * 0.95, 3.4, -4.7),
			Color3.new(1, 1, 1),
			model,
			Enum.PartType.Ball
		)
		eye.Material = Enum.Material.SmoothPlastic
		part(
			"Pupila",
			Vector3.one * 0.45,
			cf * CFrame.new(side * 0.95, 3.4, -5.12),
			Color3.fromRGB(20, 20, 20),
			model,
			Enum.PartType.Ball
		)
		-- Três patas de cada lado.
		for i, z in { -1.6, 0.6, 2.8 } do
			part(
				"Pata",
				Vector3.new(0.4, 0.4, 3.2),
				cf
					* CFrame.new(side * 3.2, 1.2, z)
					* CFrame.Angles(0, math.rad(90), 0)
					* CFrame.Angles(0, 0, math.rad(side * (40 + i * 2))),
				SHELL_DARK,
				model
			)
		end
	end
	-- Chapéu de mercador.
	part(
		"Aba",
		Vector3.new(0.3, 3.6, 3.6),
		cf * CFrame.new(0, 4.3, -3.6) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(120, 40, 40),
		model,
		Enum.PartType.Cylinder
	)
	part(
		"Copa",
		Vector3.new(1.6, 2.2, 2.2),
		cf * CFrame.new(0, 5.1, -3.6) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(150, 50, 50),
		model,
		Enum.PartType.Cylinder
	)

	-- Carrinho com caixotes e poções.
	local cart = cf * CFrame.new(0, 0, 7.5)
	part("Carrinho", Vector3.new(7, 1, 5), cart * CFrame.new(0, 2.2, 0), WOOD, model).Material =
		Enum.Material.WoodPlanks
	for side = -1, 1, 2 do
		part(
			"Roda",
			Vector3.new(0.6, 3, 3),
			cart * CFrame.new(side * 3.6, 1.5, 0),
			Color3.fromRGB(90, 60, 35),
			model,
			Enum.PartType.Cylinder
		)
	end
	part("Caixote", Vector3.new(2.4, 2, 2.4), cart * CFrame.new(-1.8, 3.7, 0.6), WOOD, model).Material =
		Enum.Material.WoodPlanks
	local colors =
		{ Color3.fromRGB(90, 200, 255), Color3.fromRGB(255, 210, 60), Color3.fromRGB(255, 120, 190) }
	for i, color in colors do
		local bottle = part(
			"Pocao",
			Vector3.new(1.4, 0.9, 0.9),
			cart * CFrame.new(0.2 + (i - 1) * 1.2, 3.4, -0.8) * CFrame.Angles(0, 0, math.rad(90)),
			color,
			model,
			Enum.PartType.Cylinder
		)
		bottle.Material = Enum.Material.Neon
	end
	local sign = part("Placa", Vector3.new(6, 1.6, 0.3), cart * CFrame.new(0, 6.4, 2.4), WOOD, model)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front -- virada para a fonte
	gui.CanvasSize = Vector2.new(300, 80)
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBlack
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(255, 220, 120)
	text.Text = "🐞 POÇÕES & TROCAS"
	text.Parent = gui
	gui.Parent = sign
	for side = -1, 1, 2 do
		part(
			"Haste",
			Vector3.new(0.3, 3, 0.3),
			cart * CFrame.new(side * 2.6, 4.6, 2.4),
			Color3.fromRGB(90, 60, 35),
			model
		)
	end

	model.Parent = parent
	return model:FindFirstChild("Cabeca") :: BasePart
end

local function label(adornee: BasePart)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(14, 2.6)
	gui.StudsOffset = Vector3.new(0, 5, 0)
	gui.MaxDistance = 120
	gui.LightInfluence = 0
	gui.Adornee = adornee
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(150, 240, 190)
	text.TextStrokeTransparency = 0.3
	text.Text = "🐞 Seu Besouro · mercador"
	text.Parent = gui
	gui.Parent = adornee
end

function MerchantService.Summary(player: Player)
	local cargo = InventoryService.Get(player)
	local potions = {}
	for _, id in Config.PotionOrder do
		local info = Config.Potions[id]
		table.insert(potions, {
			Id = id,
			DisplayName = info.DisplayName,
			Icon = info.Icon,
			Description = info.Description,
			Price = info.Price,
			Duration = info.Duration,
			Remaining = math.floor(Boosts.Remaining(player, id)),
		})
	end
	local trades = {}
	for _, trade in Config.Trades do
		table.insert(trades, {
			Id = trade.Id,
			Text = trade.Text,
			Can = (cargo.Combs[trade.Rarity] or 0) >= trade.Amount,
		})
	end
	return { Potions = potions, Trades = trades, Position = merchantPosition }
end

-- Liga a poção e agenda o fim (recalcula velocidade/carga e avisa o HUD).
local function applyPotion(player: Player, id: string)
	local info = Config.Potions[id]
	Boosts.Start(player, id, info.Duration)
	InventoryService.Refresh(player)
	Notifier.Changed(player)
	local remaining = Boosts.Remaining(player, id)
	task.delay(remaining + 0.2, function()
		if player.Parent and not Boosts.IsActive(player, id) then
			InventoryService.Refresh(player)
			Notifier.Notify(player, `{info.Icon} {info.DisplayName} acabou.`, "info")
			Notifier.Changed(player)
		end
	end)
end

-- Dá uma poção de presente (códigos, baús).
function MerchantService.GivePotion(player: Player, id: string)
	if Config.Potions[id] then
		applyPotion(player, id)
	end
end

local function near(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and (root.Position - merchantPosition).Magnitude <= Config.Merchant.TalkDistance
end

local function handle(player: Player, action: unknown, id: unknown)
	local now = os.clock()
	if now - (lastRequest[player] or 0) < 0.4 then
		return
	end
	lastRequest[player] = now
	if typeof(action) ~= "string" or typeof(id) ~= "string" or not PlayerDataService.IsLoaded(player) then
		return
	end
	if not near(player) then
		Notifier.Notify(player, "Chegue mais perto do Besouro.", "erro")
		return
	end
	local profile = PlayerDataService.Get(player)

	if action == "Pocao" then
		local info = Config.Potions[id]
		if not info then
			return
		end
		if profile.Honey < info.Price then
			Notifier.Notify(player, `Falta mel: {info.DisplayName} custa {info.Price}.`, "erro")
			return
		end
		profile.Honey -= info.Price
		applyPotion(player, id)
		Notifier.Notify(
			player,
			`{info.Icon} {info.DisplayName}! {info.Description} por {math.floor(info.Duration / 60)} min.`,
			"ok"
		)
	elseif action == "Troca" then
		local trade = nil
		for _, entry in Config.Trades do
			if entry.Id == id then
				trade = entry
			end
		end
		if not trade then
			return
		end
		local cargo = InventoryService.Get(player)
		if (cargo.Combs[trade.Rarity] or 0) < trade.Amount then
			Notifier.Notify(player, "Você não tem esses favos na carga.", "erro")
			return
		end
		cargo.Combs[trade.Rarity] -= trade.Amount
		if trade.Honey > 0 then
			profile.Honey += trade.Honey
			profile.HoneyEarned += trade.Honey
		end
		if trade.Potion ~= "" then
			applyPotion(player, trade.Potion)
		end
		QuestService.Add(player, "Troca", 1) -- conta para conquista e diárias
		InventoryService.Refresh(player)
		Notifier.Notify(player, `🐞 Negócio fechado: {trade.Text}`, "ok")
		Notifier.Changed(player)
	end
end

function MerchantService:Init() end

function MerchantService:Start()
	local folder = Instance.new("Folder")
	folder.Name = "Mercador"
	folder.Parent = WorldService.GetMap().Folder
	-- Na beira da praça, olhando para a fonte.
	local ground = Vector3.new(merchantPosition.X, 1.2, merchantPosition.Z)
	local cf = CFrame.lookAt(ground, Vector3.new(0, 1.2, 0))
	local head = buildBeetle(folder, cf)
	label(head)

	-- O aviso fica na cabeça; o cliente abre a loja ao acioná-lo.
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "FalarBesouro"
	prompt.ActionText = "Falar com o Besouro"
	prompt.ObjectText = "Poções e trocas"
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 20
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Mercador", true)
	prompt.Parent = head

	-- Brilhinho nas poções.
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(150, 230, 255)
	glow.Range = 14
	glow.Brightness = 0.8
	glow.Parent = head
	TweenService
		:Create(glow, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			Brightness = 0.2,
		})
		:Play()

	Remotes.Get("RequestShop").OnServerEvent:Connect(handle)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
		Boosts.Clear(player)
	end)
	Log.info("MerchantService", "Besouro na praça")
end

return MerchantService
