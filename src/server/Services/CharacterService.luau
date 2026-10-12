--[[
	CharacterService (servidor) — Etapa A

	Transforma o personagem padrão em abelha e coloca o jogador
	na frente da própria colmeia ao nascer.

	- O avatar fica invisível; um corpo de abelha (peças simples)
	  é soldado ao HumanoidRootPart. Os outros jogadores veem a abelha.
	- Na própria câmera em primeira pessoa o Roblox já esconde o
	  personagem local; o CameraController desenha só as patas.
	- Etapa E: trocar as peças por um modelo de abelha feito no Studio
	  (assets/Abelha.rbxm) mantendo esta mesma função.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared.Util.Log)

local AssetLibrary = require(script.Parent.Parent.Lib.AssetLibrary)
local HiveService = require(script.Parent.HiveService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local CharacterService = {}

local YELLOW = Color3.fromRGB(255, 196, 40)
local BLACK = Color3.fromRGB(30, 25, 20)

local function hideAvatar(character: Model, root: BasePart)
	local function hide(item: Instance)
		if item:IsA("BasePart") and item ~= root and item:GetAttribute("Abelha") == nil then
			item.Transparency = 1
		elseif item:IsA("Decal") then
			item.Transparency = 1
		elseif item:IsA("Accessory") then
			item:Destroy()
		end
	end
	for _, item in character:GetDescendants() do
		hide(item)
	end
	character.DescendantAdded:Connect(hide)
end

local function beePart(
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	root: BasePart,
	shape: Enum.PartType?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	if shape then
		part.Shape = shape
	end
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CFrame = root.CFrame * offset
	part:SetAttribute("Abelha", true)

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	return part
end

-- Corpo simples: abdômen listrado, cabeça, olhos, asas e ferrão.
-- No Roblox, a frente do personagem é o -Z local.
local function buildBee(character: Model, root: BasePart)
	-- Modelo 3D em assets/Abelha.rbxm? Usa ele no lugar das peças.
	local imported = AssetLibrary.Attach("Abelha", root, 6, CFrame.new(0, 0, 0.5))
	if imported then
		imported.Name = "CorpoAbelha"
		imported.Parent = character
		return
	end

	local model = Instance.new("Model")
	model.Name = "CorpoAbelha"

	local cylinder = Enum.PartType.Cylinder
	local ballShape = Enum.PartType.Ball
	local sideways = CFrame.Angles(0, math.rad(90), 0) -- eixo do cilindro ao longo do corpo

	beePart("Abdomen", Vector3.new(3.4, 3, 3), CFrame.new(0, 0, 1) * sideways, YELLOW, root, cylinder).Parent =
		model
	beePart("Listra1", Vector3.new(0.7, 3.15, 3.15), CFrame.new(0, 0, 0.4) * sideways, BLACK, root, cylinder).Parent =
		model
	beePart("Listra2", Vector3.new(0.7, 3.15, 3.15), CFrame.new(0, 0, 1.8) * sideways, BLACK, root, cylinder).Parent =
		model
	beePart("Traseira", Vector3.new(2.6, 2.6, 2.6), CFrame.new(0, 0, 2.6), YELLOW, root, ballShape).Parent =
		model
	beePart("Ferrao", Vector3.new(0.4, 0.4, 1), CFrame.new(0, 0, 4), BLACK, root).Parent = model
	beePart("Cabeca", Vector3.new(2.2, 2.2, 2.2), CFrame.new(0, 0.3, -1.4), BLACK, root, ballShape).Parent =
		model
	beePart(
		"OlhoE",
		Vector3.new(0.7, 0.7, 0.7),
		CFrame.new(-0.6, 0.6, -2.3),
		Color3.new(1, 1, 1),
		root,
		ballShape
	).Parent =
		model
	beePart(
		"OlhoD",
		Vector3.new(0.7, 0.7, 0.7),
		CFrame.new(0.6, 0.6, -2.3),
		Color3.new(1, 1, 1),
		root,
		ballShape
	).Parent =
		model

	-- Asas usam Weld (e não WeldConstraint) para o cliente poder bater
	-- as asas mudando o C0 sem mexer no resto do corpo.
	for side = -1, 1, 2 do
		local wing = Instance.new("Part")
		wing.Name = if side < 0 then "AsaE" else "AsaD"
		wing.Size = Vector3.new(3.2, 0.15, 1.8)
		wing.Color = Color3.fromRGB(235, 245, 255)
		wing.Material = Enum.Material.Glass
		wing.Transparency = 0.4
		wing.CanCollide = false
		wing.CanQuery = false
		wing.CanTouch = false
		wing.Massless = true
		wing:SetAttribute("Abelha", true)

		local baseC0 = CFrame.new(side * 1.9, 1.6, 0.6) * CFrame.Angles(0, 0, math.rad(-20 * side))
		local weld = Instance.new("Weld")
		weld.Name = "AsaWeld"
		weld.Part0 = root
		weld.Part1 = wing
		weld.C0 = baseC0
		weld:SetAttribute("BaseC0", baseC0)
		weld:SetAttribute("Side", side)
		CollectionService:AddTag(weld, "AsaAbelha")
		weld.Parent = wing
		wing.Parent = model
	end

	model.Parent = character
end

-- Acessórios -----------------------------------------------------------------

local function buildCosmetic(id: string, root: BasePart, parent: Instance)
	local cylinder = Enum.PartType.Cylinder
	if id == "Oculos" then
		-- Óculos de aviador: duas lentes e a tira.
		for side = -1, 1, 2 do
			local frame = beePart(
				"Aro",
				Vector3.new(0.25, 0.95, 0.95),
				CFrame.new(side * 0.55, 0.65, -2.45) * CFrame.Angles(0, math.rad(90), 0),
				Color3.fromRGB(150, 100, 50),
				root,
				cylinder
			)
			frame.Parent = parent
			local lens = beePart(
				"Lente",
				Vector3.new(0.3, 0.75, 0.75),
				CFrame.new(side * 0.55, 0.65, -2.5) * CFrame.Angles(0, math.rad(90), 0),
				Color3.fromRGB(40, 60, 90),
				root,
				cylinder
			)
			lens.Material = Enum.Material.Glass
			lens.Reflectance = 0.3
			lens.Parent = parent
		end
		beePart(
			"Tira",
			Vector3.new(2.35, 0.3, 2.35),
			CFrame.new(0, 0.65, -1.4) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(120, 80, 40),
			root,
			cylinder
		).Parent =
			parent
	elseif id == "Chapeu" then
		beePart(
			"Aba",
			Vector3.new(0.2, 2.8, 2.8),
			CFrame.new(0, 1.35, -1.4) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(60, 40, 30),
			root,
			cylinder
		).Parent =
			parent
		beePart(
			"Copa",
			Vector3.new(1.4, 1.6, 1.6),
			CFrame.new(0, 2.05, -1.4) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(60, 40, 30),
			root,
			cylinder
		).Parent =
			parent
		beePart(
			"Fita",
			Vector3.new(0.3, 1.65, 1.65),
			CFrame.new(0, 1.55, -1.4) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(240, 185, 60),
			root,
			cylinder
		).Parent =
			parent
	elseif id == "Lenco" then
		beePart(
			"Lenco",
			Vector3.new(0.6, 2.7, 2.7),
			CFrame.new(0, -0.1, -0.45) * CFrame.Angles(0, math.rad(90), 0),
			Color3.fromRGB(200, 40, 40),
			root,
			cylinder
		).Parent =
			parent
		beePart(
			"Ponta",
			Vector3.new(0.9, 0.3, 1.1),
			CFrame.new(0.9, -0.9, -0.7) * CFrame.Angles(math.rad(30), 0, math.rad(20)),
			Color3.fromRGB(200, 40, 40),
			root
		).Parent =
			parent
	end
end

-- Remonta os acessórios equipados (chamado ao nascer e ao trocar).
function CharacterService.ApplyCosmetics(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not root then
		return
	end
	local old = character:FindFirstChild("Acessorios")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Model")
	folder.Name = "Acessorios"
	for _, id in PlayerDataService.Get(player).EquippedCosmetics do
		buildCosmetic(id, root, folder)
	end
	folder.Parent = character
end

local function onCharacter(player: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = 0

	hideAvatar(character, root)
	buildBee(character, root)
	task.spawn(function()
		-- Acessórios dependem do perfil carregado.
		if PlayerDataService.WaitForProfile(player) and character.Parent then
			CharacterService.ApplyCosmetics(player)
		end
	end)

	-- Nasce na frente da própria colmeia. O RespawnLocation já resolve
	-- os renascimentos; este teleporte cobre o primeiro spawn, que pode
	-- acontecer antes de a colmeia ser atribuída. A espera curta evita
	-- que o motor sobrescreva a posição logo depois do CharacterAdded.
	task.spawn(function()
		task.wait(0.2)
		-- Espera a colmeia ser atribuída (o perfil pode estar carregando).
		local started = os.clock()
		while not HiveService.GetPlotIndex(player) and os.clock() - started < 10 and character.Parent do
			task.wait(0.2)
		end
		if character.Parent and root.Parent then
			root.AssemblyLinearVelocity = Vector3.zero
			character:PivotTo(HiveService.GetSpawnCFrame(player))
		end
	end)
end

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
end

function CharacterService:Init() end

function CharacterService:Start()
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Log.info("CharacterService", "pronto")
end

return CharacterService
