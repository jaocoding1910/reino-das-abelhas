--[[
	MapBuilder — monta o cenário por código.

	Tudo é gerado com uma semente fixa (Config.Map.Seed): o mapa sai
	igual em todo servidor e qualquer pessoa reconstrói o mesmo mundo.

	Regiões:
	- Área das colmeias: anel de árvores-colmeia no centro (spawn de cada jogador).
	- Campo inicial: flores gigantes e favos comuns.
	- Bosque: árvores, cogumelos (brilham à noite) e favos médios.
	- Copas altas: favos raros, difíceis de alcançar.
	- Lagos: água de Terrain.

	Para trocar por modelos feitos no Studio: salve o modelo em assets/
	como .rbxm e substitua a função correspondente.
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local AssetLibrary = require(script.Parent.Parent.Lib.AssetLibrary)
local Hex = require(script.Parent.Hex)

local MapBuilder = {}

export type Plot = {
	Index: number,
	CFrame: CFrame, -- centro do lote, olhando para o centro do mapa
	WallOrigin: CFrame, -- centro da parede de células
	SpawnCFrame: CFrame,
	Spawn: SpawnLocation, -- usado como Player.RespawnLocation do dono
	Folder: Folder,
	CellsFolder: Folder,
	Delivery: BasePart,
	SignLabel: TextLabel,
}

export type MapData = {
	Folder: Folder,
	Plots: { Plot },
	Flowers: { BasePart }, -- a parte central (néctar) de cada flor
	Combs: { Model }, -- favos coletáveis (atributo Rarity)
	SpiderSpots: { Vector3 }, -- pés das árvores do bosque (teias)
	RoyalPosition: Vector3,
	DefaultSpawn: CFrame,
}

-- Tags lidas por outros sistemas.
MapBuilder.Tags = {
	FloatingComb = "FavoFlutuante", -- cliente gira e flutua
	NightGlow = "BrilhoNoturno", -- DayNightService liga à noite
}

local MAP_NAME = "Mapa"

local PETAL_COLORS = {
	{ Color3.fromRGB(250, 250, 245), Color3.fromRGB(255, 240, 200) },
	{ Color3.fromRGB(255, 205, 80), Color3.fromRGB(255, 235, 150) },
	{ Color3.fromRGB(240, 120, 165), Color3.fromRGB(255, 185, 210) },
	{ Color3.fromRGB(160, 110, 230), Color3.fromRGB(205, 170, 255) },
	{ Color3.fromRGB(255, 145, 65), Color3.fromRGB(255, 200, 130) },
	{ Color3.fromRGB(90, 160, 255), Color3.fromRGB(170, 210, 255) },
}

local function newPart(name: string, size: Vector3, cf: CFrame, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Cilindro em pé (no Roblox o eixo do cilindro é o X da peça).
local function uprightCylinder(name, height, diameter, center: Vector3, color, parent): Part
	local part = newPart(
		name,
		Vector3.new(height, diameter, diameter),
		CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		parent
	)
	part.Shape = Enum.PartType.Cylinder
	return part
end

local function ball(name, diameter, center: Vector3, color, parent): Part
	local part = newPart(name, Vector3.one * diameter, CFrame.new(center), color, parent)
	part.Shape = Enum.PartType.Ball
	return part
end

-- Posição aleatória num anel entre minR e maxR.
local function ringPosition(rng: Random, minR: number, maxR: number): Vector3
	local angle = rng:NextNumber(0, math.pi * 2)
	local radius = rng:NextNumber(minR, maxR)
	return Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
end

local function sparkles(parent: Instance, color: Color3, rate: number, size: number): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Brilho"
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Rate = rate
	emitter.Lifetime = NumberRange.new(1.5, 2.5)
	emitter.Speed = NumberRange.new(0.5, 1.5)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, 1, 0)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.2, size),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Parent = parent
	return emitter
end

local function light(parent: Instance, color: Color3, range: number, brightness: number): PointLight
	local pointLight = Instance.new("PointLight")
	pointLight.Color = color
	pointLight.Range = range
	pointLight.Brightness = brightness
	pointLight.Shadows = false
	pointLight.Parent = parent
	return pointLight
end

local function addLabel(adornee: BasePart, title: string, subtitle: string, color: Color3): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "Rotulo"
	-- Tamanho em studs: diminui com a distância, como um objeto do mundo.
	gui.Size = UDim2.fromScale(7, 2)
	gui.StudsOffset = Vector3.new(0, 3.2, 0)
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	gui.Adornee = adornee

	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(28, 22, 16)
	bg.BackgroundTransparency = 0.25
	bg.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.2, 0)
	corner.Parent = bg
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Transparency = 0.3
	stroke.Parent = bg

	local top = Instance.new("TextLabel")
	top.BackgroundTransparency = 1
	top.Size = UDim2.new(1, 0, 0.55, 0)
	top.Font = Enum.Font.GothamBold
	top.TextScaled = true
	top.TextColor3 = Color3.fromRGB(250, 244, 230)
	top.Text = title
	top.Parent = bg

	local bottom = Instance.new("TextLabel")
	bottom.BackgroundTransparency = 1
	bottom.Position = UDim2.fromScale(0, 0.55)
	bottom.Size = UDim2.new(1, 0, 0.4, 0)
	bottom.Font = Enum.Font.GothamBold
	bottom.TextScaled = true
	bottom.TextColor3 = color
	bottom.Text = subtitle
	bottom.Parent = bg

	gui.Parent = adornee
	return gui
end

-- Céu, luz e terreno ------------------------------------------------------------

local function ensure(className: string, parent: Instance): Instance
	local existing = parent:FindFirstChildOfClass(className)
	if existing then
		return existing
	end
	local created = Instance.new(className)
	created.Parent = parent
	return created
end

local function buildLighting()
	local atmosphere = ensure("Atmosphere", Lighting) :: Atmosphere
	atmosphere.Density = 0.32
	atmosphere.Haze = 1.4
	atmosphere.Glare = 0.4
	atmosphere.Color = Color3.fromRGB(255, 228, 190)
	atmosphere.Decay = Color3.fromRGB(110, 150, 220)

	local bloom = ensure("BloomEffect", Lighting) :: BloomEffect
	bloom.Intensity = 0.6
	bloom.Size = 30
	bloom.Threshold = 1.6

	local rays = ensure("SunRaysEffect", Lighting) :: SunRaysEffect
	rays.Intensity = 0.08
	rays.Spread = 0.6

	local color = ensure("ColorCorrectionEffect", Lighting) :: ColorCorrectionEffect
	color.Saturation = 0.15
	color.Contrast = 0.08
	color.TintColor = Color3.fromRGB(255, 248, 235)

	local clouds = ensure("Clouds", workspace.Terrain) :: Clouds
	clouds.Cover = 0.55
	clouds.Density = 0.6
	clouds.Color = Color3.fromRGB(255, 250, 245)
end

local function buildTerrain(rng: Random)
	local terrain = workspace.Terrain
	terrain:FillBlock(CFrame.new(0, -4, 0), Vector3.new(2048, 8, 2048), Enum.Material.Grass)
	-- Manchas de grama alta e terra dão textura ao chão.
	for _ = 1, 40 do
		local position = ringPosition(rng, 60, 900)
		terrain:FillCylinder(
			CFrame.new(position + Vector3.new(0, -0.5, 0)),
			1,
			rng:NextNumber(15, 40),
			if rng:NextNumber() < 0.5 then Enum.Material.LeafyGrass else Enum.Material.Ground
		)
	end
	terrain:FillBlock(CFrame.new(300, -3, -340), Vector3.new(150, 6, 100), Enum.Material.Water)
	terrain:FillBlock(CFrame.new(-360, -3, 300), Vector3.new(100, 6, 130), Enum.Material.Water)
end

-- Flores ------------------------------------------------------------------

-- Néctar de um modelo importado: usa a peça "Miolo" (ou cria uma no topo).
local function nectarAnchor(model: Model, parent: Instance): BasePart
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part:GetAttribute("Papel") == "Miolo" then
			part:SetAttribute("NectarColor", part.Color)
			local emitter = sparkles(part, Color3.fromRGB(255, 215, 90), 3, 0.5)
			emitter.Name = "Polen"
			return part
		end
	end
	local boxCFrame, boxSize = model:GetBoundingBox()
	local top = boxCFrame.Position + Vector3.new(0, boxSize.Y / 2 - 1, 0)
	local anchor =
		newPart("Nectar", Vector3.new(6, 2, 6), CFrame.new(top), Color3.fromRGB(255, 190, 40), parent)
	anchor.Transparency = 1
	anchor.CanCollide = false
	local emitter = sparkles(anchor, Color3.fromRGB(255, 215, 90), 3, 0.5)
	emitter.Name = "Polen"
	return anchor
end

-- Girassol: pétalas compridas e miolo escuro enorme.
local function buildSunflower(parent: Instance, base: Vector3, rng: Random): BasePart
	local height = rng:NextNumber(45, 75)
	local imported = AssetLibrary.Place(
		"Girassol",
		CFrame.new(base) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0),
		height,
		parent,
		{
			Petala = Color3.fromRGB(255, 200, 30),
			Miolo = Color3.fromRGB(110, 70, 30),
			MioloBorda = Color3.fromRGB(150, 100, 40),
		}
	)
	if imported then
		return nectarAnchor(imported, imported)
	end

	local model = Instance.new("Model")
	model.Name = "Girassol"
	local head = rng:NextNumber(22, 30)
	local top = base + Vector3.new(0, height, 0)
	local facing = rng:NextNumber(0, math.pi * 2)

	uprightCylinder(
		"Caule",
		height,
		3.2,
		base + Vector3.new(0, height / 2, 0),
		Color3.fromRGB(80, 140, 55),
		model
	)
	for i = 1, 4 do
		local side = if i % 2 == 0 then 1 else -1
		local leafCF = CFrame.new(base + Vector3.new(0, height * (0.15 + i * 0.15), 0))
			* CFrame.Angles(0, facing + i * 1.7, 0)
			* CFrame.new(side * 5, 0, 0)
			* CFrame.Angles(0, 0, math.rad(25 * side))
		local leaf = newPart("Folha", Vector3.new(10, 0.5, 5), leafCF, Color3.fromRGB(70, 150, 60), model)
		leaf.Material = Enum.Material.Grass
	end

	-- Cabeça levemente inclinada, como girassol de verdade.
	local headCF = CFrame.new(top) * CFrame.Angles(0, facing, 0) * CFrame.Angles(math.rad(-20), 0, 0)
	local petals = 16
	for i = 1, petals do
		local angle = (i / petals) * math.pi * 2
		local petalCF = headCF * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -head * 0.42)
		newPart(
			"Petala",
			Vector3.new(head * 0.16, 0.6, head * 0.38),
			petalCF,
			Color3.fromRGB(255, 200, 30),
			model
		)
	end
	local center = newPart(
		"Nectar",
		Vector3.new(2, head * 0.55, head * 0.55),
		headCF * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(110, 70, 30),
		model
	)
	center.Shape = Enum.PartType.Cylinder
	center.Material = Enum.Material.Sand
	center:SetAttribute("NectarColor", Color3.fromRGB(110, 70, 30))
	local emitter = sparkles(center, Color3.fromRGB(255, 215, 90), 3, 0.5)
	emitter.Name = "Polen"

	model.Parent = parent
	return center
end

local function buildFlower(parent: Instance, base: Vector3, rng: Random): BasePart
	if rng:NextNumber() < Config.Map.SunflowerChance then
		return buildSunflower(parent, base, rng)
	end
	local importedHeight = rng:NextNumber(20, 60)
	local colors = PETAL_COLORS[rng:NextInteger(1, #PETAL_COLORS)]
	local imported = AssetLibrary.Place(
		"Flor",
		CFrame.new(base) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0),
		importedHeight,
		parent,
		{ Petala = colors[1], PetalaInterna = colors[2] }
	)
	if imported then
		return nectarAnchor(imported, imported)
	end

	local model = Instance.new("Model")
	model.Name = "Flor"

	local height = rng:NextNumber(20, 60)
	local head = rng:NextNumber(15, 26)
	local palette = PETAL_COLORS[rng:NextInteger(1, #PETAL_COLORS)]
	local top = base + Vector3.new(0, height, 0)
	local tilt = rng:NextNumber(0, math.pi * 2)

	uprightCylinder(
		"Caule",
		height,
		2.6,
		base + Vector3.new(0, height / 2, 0),
		Color3.fromRGB(85, 150, 60),
		model
	)

	-- Folhas grandes ao longo do caule.
	for i = 1, 3 do
		local side = if i % 2 == 0 then 1 else -1
		local leafCF = CFrame.new(base + Vector3.new(0, height * (0.2 + i * 0.15), 0))
			* CFrame.Angles(0, tilt + i * 2.1, 0)
			* CFrame.new(side * 4, 0, 0)
			* CFrame.Angles(0, 0, math.rad(20 * side))
		local leaf = newPart("Folha", Vector3.new(8, 0.5, 4), leafCF, Color3.fromRGB(75, 160, 70), model)
		leaf.Material = Enum.Material.Grass
	end

	-- Pétalas em duas camadas.
	local petals = 10
	for i = 1, petals do
		local angle = (i / petals) * math.pi * 2 + tilt
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * head * 0.4
		uprightCylinder("Petala", 0.7, head * 0.42, top + offset, palette[1], model)
	end
	for i = 1, petals do
		local angle = ((i + 0.5) / petals) * math.pi * 2 + tilt
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * head * 0.27
		uprightCylinder(
			"PetalaInterna",
			0.7,
			head * 0.3,
			top + offset + Vector3.new(0, 0.4, 0),
			palette[2],
			model
		)
	end

	-- Miolo: é aqui que fica o néctar (ResourceService põe o prompt).
	local center = uprightCylinder(
		"Nectar",
		1.8,
		head * 0.4,
		top + Vector3.new(0, 0.9, 0),
		Color3.fromRGB(255, 190, 40),
		model
	)
	center.Material = Enum.Material.Sand
	local emitter = sparkles(center, Color3.fromRGB(255, 215, 90), 3, 0.5)
	emitter.Name = "Polen"

	model.Parent = parent
	return center
end

-- Favos coletáveis ----------------------------------------------------------

local function mergeInto(target: Model, source: Model)
	for _, part in source:GetChildren() do
		part.Parent = target
	end
	source:Destroy()
end

-- Cada raridade tem forma e efeito próprios (não só cor):
-- Comum = hexágono simples · Médio = hexágono duplo com luz · Raro = cristal brilhante.
local function buildComb(parent: Instance, position: Vector3, rarity: string): Model
	local info = Config.Rarities[rarity]
	local base = CFrame.new(position) * CFrame.Angles(0, math.rad(30), 0)

	local comb = Hex.Prism(base, 1.4, 0.9, {
		Color = info.Color,
		Material = if rarity == "Raro" then Enum.Material.Neon else Enum.Material.SmoothPlastic,
		CanCollide = false,
		Name = "Favo",
	})
	local anchor = comb.PrimaryPart :: BasePart

	if rarity == "Medio" then
		mergeInto(
			comb,
			Hex.Prism(base * CFrame.new(0, 0, 1.1), 1.1, 0.7, {
				Color = info.Color,
				CanCollide = false,
			})
		)
		light(anchor, info.Color, 10, 1.2)
	elseif rarity == "Raro" then
		mergeInto(
			comb,
			Hex.Prism(base * CFrame.Angles(0, math.rad(90), 0), 1, 1, {
				Color = Color3.fromRGB(240, 210, 255),
				Material = Enum.Material.Neon,
				CanCollide = false,
			})
		)
		light(anchor, info.Color, 18, 2)
		sparkles(anchor, info.Color, 8, 0.6)
	else
		sparkles(anchor, Color3.fromRGB(255, 240, 200), 2, 0.35)
	end

	comb:SetAttribute("Rarity", rarity)
	CollectionService:AddTag(comb, MapBuilder.Tags.FloatingComb)
	addLabel(anchor, info.DisplayName, info.Label, info.Color)
	comb.Parent = parent
	return comb
end

-- Bosque ------------------------------------------------------------------

-- Retorna a posição acima da copa (bom lugar para favo raro).
local function buildTree(parent: Instance, base: Vector3, rng: Random): Vector3
	local height = rng:NextNumber(100, 160)
	local imported = AssetLibrary.Place(
		"Arvore",
		CFrame.new(base) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0),
		height + 40,
		parent
	)
	if imported then
		local boxCFrame, boxSize = imported:GetBoundingBox()
		return boxCFrame.Position + Vector3.new(0, boxSize.Y / 2 + 3, 0)
	end

	local model = Instance.new("Model")
	model.Name = "Arvore"
	local width = rng:NextNumber(14, 22)
	local trunk = uprightCylinder(
		"Tronco",
		height,
		width,
		base + Vector3.new(0, height / 2, 0),
		Color3.fromRGB(105, 75, 50),
		model
	)
	trunk.Material = Enum.Material.Wood

	-- Raízes.
	for i = 1, 4 do
		local angle = i * math.pi / 2 + rng:NextNumber(-0.3, 0.3)
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local root = newPart(
			"Raiz",
			Vector3.new(4, 4, width * 0.9),
			CFrame.lookAt(base + dir * width * 0.6 + Vector3.new(0, 1, 0), base + dir * width * 1.5),
			Color3.fromRGB(95, 68, 45),
			model
		)
		root.Material = Enum.Material.Wood
	end

	local topY = 0
	for i = 1, 4 do
		local offset = Vector3.new(rng:NextNumber(-20, 20), rng:NextNumber(-10, 14), rng:NextNumber(-20, 20))
		local size = rng:NextNumber(48, 75)
		local leaves = ball(
			"Copa",
			size,
			base + Vector3.new(0, height, 0) + offset,
			Color3.fromRGB(60 + i * 8, 130 + i * 6, 60),
			model
		)
		leaves.Material = Enum.Material.Grass
		topY = math.max(topY, height + offset.Y + size / 2)
	end
	model.Parent = parent
	return base + Vector3.new(0, topY + 3, 0)
end

-- Retorna a posição acima do chapéu.
local function buildMushroom(parent: Instance, base: Vector3, rng: Random): Vector3
	local height = rng:NextNumber(8, 22)
	local isBlue = rng:NextNumber() < 0.5
	local imported = AssetLibrary.Place("Cogumelo", CFrame.new(base), height + 8, parent, {
		Chapeu = if isBlue then Color3.fromRGB(80, 120, 230) else Color3.fromRGB(200, 60, 70),
		NightColor = if isBlue then Color3.fromRGB(120, 220, 255) else Color3.fromRGB(255, 140, 220),
	})
	if imported then
		local boxCFrame, boxSize = imported:GetBoundingBox()
		local glowAnchor = imported.PrimaryPart or imported:FindFirstChildWhichIsA("BasePart")
		if glowAnchor then
			local glow = light(glowAnchor, Color3.fromRGB(120, 220, 255), 28, 2)
			glow.Enabled = false
			CollectionService:AddTag(glow, MapBuilder.Tags.NightGlow)
		end
		return boxCFrame.Position + Vector3.new(0, boxSize.Y / 2 + 3, 0)
	end

	local model = Instance.new("Model")
	model.Name = "Cogumelo"
	local capSize = rng:NextNumber(16, 28)
	local blue = rng:NextNumber() < 0.5
	local capColor = if blue then Color3.fromRGB(80, 120, 230) else Color3.fromRGB(200, 60, 70)
	local glowColor = if blue then Color3.fromRGB(120, 220, 255) else Color3.fromRGB(255, 140, 220)

	uprightCylinder(
		"Pe",
		height,
		4.5,
		base + Vector3.new(0, height / 2, 0),
		Color3.fromRGB(240, 230, 210),
		model
	)
	local cap =
		uprightCylinder("Chapeu", 3.5, capSize, base + Vector3.new(0, height + 1.5, 0), capColor, model)

	-- Pintas que viram neon à noite.
	for i = 1, 5 do
		local angle = i * 1.25
		local spot = uprightCylinder(
			"Pinta",
			0.4,
			capSize * 0.16,
			base + Vector3.new(math.cos(angle) * capSize * 0.3, height + 3.3, math.sin(angle) * capSize * 0.3),
			Color3.fromRGB(250, 250, 240),
			model
		)
		spot:SetAttribute("NightColor", glowColor)
		CollectionService:AddTag(spot, MapBuilder.Tags.NightGlow)
	end
	local glow = light(cap, glowColor, 28, 2)
	glow.Enabled = false
	CollectionService:AddTag(glow, MapBuilder.Tags.NightGlow)

	model.Parent = parent
	return base + Vector3.new(0, height + 6, 0)
end

-- Cristais roxos -----------------------------------------------------------

local function buildCrystal(parent: Instance, base: Vector3, rng: Random)
	local imported = AssetLibrary.Place("Cristal", CFrame.new(base), rng:NextNumber(8, 16), parent)
	if imported then
		return
	end
	local model = Instance.new("Model")
	model.Name = "Cristal"
	for i = 1, rng:NextInteger(3, 5) do
		local h = rng:NextNumber(5, 14)
		local cf = CFrame.new(base + Vector3.new(rng:NextNumber(-3, 3), h / 2 - 1, rng:NextNumber(-3, 3)))
			* CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6.28), rng:NextNumber(-0.4, 0.4))
		local shard =
			newPart(`Lasca{i}`, Vector3.new(h * 0.28, h, h * 0.28), cf, Color3.fromRGB(150, 80, 255), model)
		shard.Material = Enum.Material.Neon
		shard.Transparency = 0.15
	end
	light(model:FindFirstChildWhichIsA("BasePart") :: BasePart, Color3.fromRGB(170, 100, 255), 20, 1.5)
	model.Parent = parent
end

-- Colmeia Real: palácio dourado num platô com cachoeiras ------------------------

local GOLD = Color3.fromRGB(240, 185, 60)
local GOLD_LIGHT = Color3.fromRGB(255, 225, 140)

local function tower(parent: Instance, base: Vector3, height: number, width: number)
	local body = uprightCylinder("Torre", height, width, base + Vector3.new(0, height / 2, 0), GOLD, parent)
	body.Reflectance = 0.15
	-- Telhado em degraus (o Roblox não tem cone; empilhamos discos).
	for i = 1, 4 do
		local w = width * (1 - i * 0.2)
		uprightCylinder("Telhado", 3, w, base + Vector3.new(0, height + i * 3, 0), GOLD_LIGHT, parent)
	end
	local tip = ball("Ponta", width * 0.25, base + Vector3.new(0, height + 15, 0), GOLD_LIGHT, parent)
	tip.Material = Enum.Material.Neon
	-- Janelas brilhantes.
	for i = 1, 3 do
		local window = newPart(
			"Janela",
			Vector3.new(width * 0.25, 4, 0.5),
			CFrame.new(base + Vector3.new(0, height * (i / 4), 0)) * CFrame.new(0, 0, -width / 2),
			Color3.fromRGB(255, 220, 130),
			parent
		)
		window.Material = Enum.Material.Neon
	end
	return base + Vector3.new(0, height + 18, 0)
end

-- Retorna posições no alto das torres (favos raros).
local function buildRoyalHive(parent: Instance): { Vector3 }
	local royal = Config.Map.RoyalHive
	local center = royal.Position
	local top = royal.PlateauHeight
	local terrain = workspace.Terrain

	-- Platô de pedra com grama em cima e lago na base.
	terrain:FillBlock(
		CFrame.new(center + Vector3.new(0, top / 2 - 4, 0)),
		Vector3.new(300, top, 220),
		Enum.Material.Rock
	)
	terrain:FillBlock(
		CFrame.new(center + Vector3.new(0, top - 2, 0)),
		Vector3.new(296, 4, 216),
		Enum.Material.Grass
	)
	terrain:FillBlock(
		CFrame.new(center + Vector3.new(0, -3, 150)),
		Vector3.new(260, 6, 70),
		Enum.Material.Water
	)

	local model = Instance.new("Model")
	model.Name = "ColmeiaReal"
	local floor = center + Vector3.new(0, top, 0)

	local spots = {}
	table.insert(spots, tower(model, floor, 90, 34))
	for _, offset in
		{ Vector3.new(-45, 0, 10), Vector3.new(45, 0, 10), Vector3.new(-30, 0, -40), Vector3.new(30, 0, -40) }
	do
		table.insert(spots, tower(model, floor + offset, 60, 16))
	end

	-- Salão e parede de favos dourados na frente.
	local hall =
		newPart("Salao", Vector3.new(80, 34, 40), CFrame.new(floor + Vector3.new(0, 17, 20)), GOLD, model)
	hall.Reflectance = 0.1
	local wallCF = CFrame.lookAt(floor + Vector3.new(0, 20, 41), floor + Vector3.new(0, 20, 200))
	for _, axial in Hex.SpiralSlots(2) do
		local offset = Hex.AxialToOffset(axial[1], axial[2], 3.2, 1.05)
		local cell = Hex.Prism(wallCF * CFrame.new(offset.X, offset.Y, 0), 3.2, 2, {
			Color = Color3.fromRGB(255, 190, 50),
			Material = Enum.Material.Glass,
			Transparency = 0.1,
		})
		cell.Parent = model
	end

	-- Cachoeiras: lâminas de "água" com névoa na base.
	for i = -1, 1 do
		local x = i * 70
		local fall = newPart(
			"Cachoeira",
			Vector3.new(16, top, 2),
			CFrame.new(center + Vector3.new(x, top / 2, 111)),
			Color3.fromRGB(170, 215, 255),
			model
		)
		fall.Material = Enum.Material.Glass
		fall.Transparency = 0.35
		fall.CanCollide = false
		local mist = newPart(
			"Nevoa",
			Vector3.new(16, 1, 6),
			CFrame.new(center + Vector3.new(x, 1, 116)),
			Color3.new(1, 1, 1),
			model
		)
		mist.Transparency = 1
		mist.CanCollide = false
		local spray = sparkles(mist, Color3.fromRGB(230, 245, 255), 25, 2.5)
		spray.LightEmission = 0.3
		spray.Speed = NumberRange.new(3, 6)
	end

	model.Parent = parent
	return spots
end

-- Decoração das árvores-colmeia -------------------------------------------------

local NAVY = Color3.fromRGB(35, 45, 90)

-- Hexágono desenhado em 2D (3 retângulos girados) para bandeiras.
local function hexEmblem(parent: GuiObject, color: Color3)
	for i = 0, 2 do
		local frame = Instance.new("Frame")
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = UDim2.fromScale(0.5, 0.45)
		frame.Size = UDim2.fromScale(0.18, 0.18 * math.sqrt(3)) -- lado × lado·√3
		frame.SizeConstraint = Enum.SizeConstraint.RelativeXX
		frame.Rotation = 60 * i
		frame.BackgroundColor3 = color
		frame.BorderSizePixel = 0
		frame.Parent = parent
	end
end

local function banner(parent: Instance, cf: CFrame)
	local cloth = newPart("Bandeira", Vector3.new(8, 18, 0.4), cf, NAVY, parent)
	cloth.Material = Enum.Material.Fabric
	cloth.CanCollide = false
	local trim = newPart(
		"Haste",
		Vector3.new(10, 0.8, 0.8),
		cf * CFrame.new(0, 9.4, 0),
		Color3.fromRGB(200, 150, 60),
		parent
	)
	trim.CanCollide = false
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.CanvasSize = Vector2.new(200, 450)
		gui.LightInfluence = 0.6
		local bg = Instance.new("Frame")
		bg.Size = UDim2.fromScale(1, 1)
		bg.BackgroundTransparency = 1
		bg.Parent = gui
		hexEmblem(bg, Color3.fromRGB(240, 185, 60))
		gui.Parent = cloth
	end
end

local function lantern(parent: Instance, position: Vector3)
	local glass = ball("Lanterna", 2.6, position, Color3.fromRGB(255, 210, 110), parent)
	glass.Material = Enum.Material.Neon
	glass.CanCollide = false
	newPart(
		"Gancho",
		Vector3.new(0.3, 3, 0.3),
		CFrame.new(position + Vector3.new(0, 2.6, 0)),
		Color3.fromRGB(60, 45, 30),
		parent
	).CanCollide =
		false
	local glow = light(glass, Color3.fromRGB(255, 190, 100), 24, 1)
	CollectionService:AddTag(glow, MapBuilder.Tags.NightGlow)
end

local function decorateHiveTree(parent: Instance, plotCF: CFrame, trunkCenter: Vector3)
	-- Bandeiras dos lados da parede.
	banner(parent, plotCF * CFrame.new(-30, 38, -1))
	banner(parent, plotCF * CFrame.new(30, 38, -1))
	-- Lanternas na frente da plataforma.
	lantern(parent, (plotCF * CFrame.new(-24, 10, -22)).Position)
	lantern(parent, (plotCF * CFrame.new(24, 10, -22)).Position)
	-- Potes de mel pendurados na copa.
	for i = 1, 4 do
		local a = i * 1.57 + 0.6
		local pod = ball(
			"PoteDeMel",
			6,
			trunkCenter + Vector3.new(math.cos(a) * 34, 40, math.sin(a) * 34),
			Color3.fromRGB(255, 180, 50),
			parent
		)
		pod.Material = Enum.Material.Glass
		pod.Transparency = 0.1
	end
	-- Varanda em volta do tronco, na altura das pontes.
	local ring = uprightCylinder(
		"Varanda",
		2,
		82,
		trunkCenter + Vector3.new(0, Config.Map.BridgeHeight - 55, 0),
		Color3.fromRGB(150, 105, 65),
		parent
	)
	ring.Material = Enum.Material.WoodPlanks
end

-- Ponte de tábuas entre duas árvores-colmeia vizinhas.
local function bridge(parent: Instance, from: Vector3, to: Vector3)
	local y = Config.Map.BridgeHeight
	local a = Vector3.new(from.X, y, from.Z)
	local b = Vector3.new(to.X, y, to.Z)
	local direction = (b - a).Unit
	a += direction * 40
	b -= direction * 40
	local length = (b - a).Magnitude
	if length <= 0 then
		return
	end
	local model = Instance.new("Model")
	model.Name = "Ponte"
	local mid = (a + b) / 2
	local cf = CFrame.lookAt(mid, b)
	local planks = math.floor(length / 3)
	for i = 0, planks - 1 do
		-- Leve curva para baixo no meio, como ponte de corda.
		local t = (i + 0.5) / planks
		local sag = math.sin(t * math.pi) * 4
		local plankCF = CFrame.lookAt(a + direction * (t * length) - Vector3.new(0, sag, 0), b)
		local plank = newPart("Tabua", Vector3.new(8, 0.6, 2.4), plankCF, Color3.fromRGB(150, 110, 70), model)
		plank.Material = Enum.Material.WoodPlanks
	end
	for side = -1, 1, 2 do
		local rope = newPart(
			"Corda",
			Vector3.new(0.4, 0.4, length),
			cf * CFrame.new(side * 4, 3, 0),
			Color3.fromRGB(180, 150, 100),
			model
		)
		rope.CanCollide = false
		rope.Material = Enum.Material.Fabric
	end
	model.Parent = parent
end

-- Árvores-colmeia (lotes dos jogadores) --------------------------------------------

local function buildPlot(parent: Instance, index: number, total: number): Plot
	local angle = (index / total) * math.pi * 2
	local radius = Config.Map.PlotRingRadius
	local position = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
	-- LookVector aponta para o centro: a parede de células fica virada para dentro.
	local plotCF = CFrame.lookAt(position, Vector3.new(0, 0, 0))

	local folder = Instance.new("Folder")
	folder.Name = `Colmeia_{index}`

	-- Tronco gigante atrás da parede de células.
	local trunkCenter = (plotCF * CFrame.new(0, 55, 36)).Position
	local trunk = uprightCylinder("Tronco", 110, 66, trunkCenter, Color3.fromRGB(110, 78, 50), folder)
	trunk.Material = Enum.Material.Wood

	-- Casca plana onde as células encostam.
	local bark = newPart(
		"Casca",
		Vector3.new(50, 50, 4),
		plotCF * CFrame.new(0, 30, 5),
		Color3.fromRGB(125, 88, 55),
		folder
	)
	bark.Material = Enum.Material.WoodPlanks

	-- Copa.
	for i = 1, 5 do
		local a = i * 1.26
		local offset = Vector3.new(math.cos(a) * 28, (i % 2) * 10, math.sin(a) * 28)
		local leaves = ball(
			"Copa",
			62 + (i % 3) * 8,
			trunkCenter + Vector3.new(0, 58, 0) + offset,
			Color3.fromRGB(70, 145, 70),
			folder
		)
		leaves.Material = Enum.Material.Grass
	end

	decorateHiveTree(folder, plotCF, trunkCenter)

	-- Plataforma de madeira na frente.
	local deck = newPart(
		"Plataforma",
		Vector3.new(56, 2, 28),
		plotCF * CFrame.new(0, 1, -10),
		Color3.fromRGB(160, 115, 70),
		folder
	)
	deck.Material = Enum.Material.WoodPlanks

	-- Pote de mel (entrega).
	local potPosition = (plotCF * CFrame.new(0, 5, -16)).Position
	local delivery = uprightCylinder("Entrega", 6, 9, potPosition, Color3.fromRGB(255, 176, 40), folder)
	delivery.Material = Enum.Material.Glass
	delivery.Transparency = 0.1
	local rim = uprightCylinder(
		"Borda",
		1,
		10,
		potPosition + Vector3.new(0, 3.2, 0),
		Color3.fromRGB(255, 220, 120),
		folder
	)
	rim.Material = Enum.Material.Neon
	light(delivery, Color3.fromRGB(255, 190, 80), 22, 1.5)
	sparkles(delivery, Color3.fromRGB(255, 210, 90), 4, 0.6)
	addLabel(rim, "Pote de mel", "Entregue aqui", Color3.fromRGB(255, 196, 64))

	-- Placa com o nome do dono.
	local sign = Instance.new("BillboardGui")
	sign.Name = "Placa"
	sign.Size = UDim2.fromScale(28, 4.5) -- em studs: some com a distância
	sign.StudsOffset = Vector3.new(0, 30, 0)
	sign.MaxDistance = 320
	sign.LightInfluence = 0
	sign.Adornee = bark
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(28, 22, 16)
	label.BackgroundTransparency = 0.3
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 196, 64)
	label.Text = "Colmeia livre"
	label.Parent = sign
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.25, 0)
	corner.Parent = label
	sign.Parent = bark

	local cells = Instance.new("Folder")
	cells.Name = "Celulas"
	cells.Parent = folder

	local spawnPosition = (plotCF * CFrame.new(0, 12, -38)).Position
	local wallOrigin = plotCF * CFrame.new(0, 30, 1.5)
	local spawnCFrame = CFrame.lookAt(spawnPosition, Vector3.new(wallOrigin.X, spawnPosition.Y, wallOrigin.Z))

	-- Ponto de nascimento invisível do dono deste lote.
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Nascimento"
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.Transparency = 1
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = spawnCFrame
	spawn.Neutral = true
	spawn.Duration = 0 -- sem campo de força
	spawn.Parent = folder

	folder.Parent = parent

	return {
		Index = index,
		CFrame = plotCF,
		WallOrigin = wallOrigin,
		SpawnCFrame = spawnCFrame,
		Spawn = spawn,
		Folder = folder,
		CellsFolder = cells,
		Delivery = delivery,
		SignLabel = label,
	}
end

-- Montagem completa -----------------------------------------------------------

function MapBuilder.Build(): MapData
	local old = workspace:FindFirstChild(MAP_NAME)
	if old then
		old:Destroy()
	end

	local rng = Random.new(Config.Map.Seed)
	local folder = Instance.new("Folder")
	folder.Name = MAP_NAME

	buildLighting()
	buildTerrain(rng)

	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Colmeias"
	plotsFolder.Parent = folder
	local plots = {}
	for i = 1, Config.Map.PlotCount do
		table.insert(plots, buildPlot(plotsFolder, i, Config.Map.PlotCount))
	end
	-- Pontes entre árvores vizinhas (o tronco fica 36 studs atrás do centro do lote).
	for i = 1, #plots do
		local current = plots[i].CFrame * CFrame.new(0, 0, 36)
		local nextPlot = plots[(i % #plots) + 1].CFrame * CFrame.new(0, 0, 36)
		bridge(plotsFolder, current.Position, nextPlot.Position)
	end

	local flowersFolder = Instance.new("Folder")
	flowersFolder.Name = "Flores"
	flowersFolder.Parent = folder
	local flowers = {}
	local field = Config.Map.FieldRadius
	for _ = 1, Config.Map.FlowerCount do
		table.insert(flowers, buildFlower(flowersFolder, ringPosition(rng, field.Min, field.Max), rng))
	end

	local forestFolder = Instance.new("Folder")
	forestFolder.Name = "Bosque"
	forestFolder.Parent = folder
	local forest = Config.Map.ForestRadius
	local treeTops = {}
	local treeBases = {}
	for _ = 1, Config.Map.TreeCount do
		local base = ringPosition(rng, forest.Min, forest.Max)
		table.insert(treeBases, base)
		table.insert(treeTops, buildTree(forestFolder, base, rng))
	end
	local mushroomTops = {}
	for _ = 1, Config.Map.MushroomCount do
		table.insert(mushroomTops, buildMushroom(forestFolder, ringPosition(rng, field.Max, forest.Max), rng))
	end
	for _ = 1, Config.Map.CrystalCount do
		buildCrystal(forestFolder, ringPosition(rng, forest.Min, forest.Max), rng)
	end

	local royalSpots = buildRoyalHive(folder)

	local combsFolder = Instance.new("Folder")
	combsFolder.Name = "Favos"
	combsFolder.Parent = folder
	local combs = {}

	-- Comuns: campo, metade em cima das flores.
	for i = 1, Config.Map.CombCount do
		local position
		if i % 2 == 0 then
			local flower = flowers[rng:NextInteger(1, #flowers)]
			position = flower.Position + Vector3.new(rng:NextNumber(-3, 3), 3.5, rng:NextNumber(-3, 3))
		else
			position = ringPosition(rng, field.Min, field.Max) + Vector3.new(0, 3, 0)
		end
		table.insert(combs, buildComb(combsFolder, position, "Comum"))
	end

	-- Médios: bosque, nos pés das árvores e em cima dos cogumelos.
	for i = 1, Config.Map.MediumCombCount do
		local position
		if i % 2 == 0 then
			position = mushroomTops[rng:NextInteger(1, #mushroomTops)]
		else
			local base = treeBases[rng:NextInteger(1, #treeBases)]
			local angle = rng:NextNumber(0, math.pi * 2)
			position = base + Vector3.new(math.cos(angle) * 22, 4, math.sin(angle) * 22)
		end
		table.insert(combs, buildComb(combsFolder, position, "Medio"))
	end

	-- Raros: topo das copas mais altas.
	table.sort(treeTops, function(a, b)
		return a.Y > b.Y
	end)
	for i = 1, math.min(Config.Map.RareCombCount, #treeTops) do
		table.insert(combs, buildComb(combsFolder, treeTops[i], "Raro"))
	end
	-- E no alto das torres da Colmeia Real (zona de disputa).
	for i = 1, math.min(Config.Map.RoyalHive.RareCombs, #royalSpots) do
		table.insert(combs, buildComb(combsFolder, royalSpots[i], "Raro"))
	end

	folder.Parent = workspace

	return {
		Folder = folder,
		Plots = plots,
		Flowers = flowers,
		Combs = combs,
		SpiderSpots = treeBases,
		RoyalPosition = Config.Map.RoyalHive.Position + Vector3.new(0, Config.Map.RoyalHive.PlateauHeight, 0),
		DefaultSpawn = CFrame.new(0, 15, 0),
	}
end

return MapBuilder
