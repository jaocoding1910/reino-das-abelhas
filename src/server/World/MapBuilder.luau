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
	MantisSpots: { Vector3 }, -- topo dos cogumelos (poleiro do louva-a-deus)
	LakeCenter: Vector3, -- lago das libélulas
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

-- Lugares reservados (caverna e lago): nada é sorteado em cima deles.
local function isReserved(position: Vector3): boolean
	for _, place in { Config.Places.Cave, Config.Places.Lake, Config.SkyIsland } do
		local delta = Vector3.new(position.X - place.Position.X, 0, position.Z - place.Position.Z)
		if delta.Magnitude < place.Radius + 18 then
			return true
		end
	end
	return false
end

-- Posição aleatória num anel entre minR e maxR (fora dos lugares reservados).
local function ringPosition(rng: Random, minR: number, maxR: number): Vector3
	local position = Vector3.zero
	for _ = 1, 12 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(minR, maxR)
		position = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		if not isReserved(position) then
			break
		end
	end
	return position
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
	-- Névoa leve: com densidade alta tudo depois de ~800 studs some no céu
	-- (as montanhas do horizonte ficavam invisíveis).
	atmosphere.Density = 0.16
	atmosphere.Haze = 0.9
	atmosphere.Glare = 0.4
	atmosphere.Color = Color3.fromRGB(255, 228, 190)
	atmosphere.Decay = Color3.fromRGB(110, 150, 220)

	local bloom = ensure("BloomEffect", Lighting) :: BloomEffect
	bloom.Intensity = 0.85
	bloom.Size = 36
	bloom.Threshold = 1.25

	-- Céu: lua grande e muitas estrelas (a noite das imagens de referência).
	local sky = ensure("Sky", Lighting) :: Sky
	sky.MoonAngularSize = 24
	sky.SunAngularSize = 16
	sky.StarCount = 4000

	-- Fundo levemente desfocado: dá cara de "cena de filme" sem atrapalhar o perto.
	local depth = ensure("DepthOfFieldEffect", Lighting) :: DepthOfFieldEffect
	depth.FarIntensity = 0.18
	depth.FocusDistance = 120
	depth.InFocusRadius = 160
	depth.NearIntensity = 0

	local rays = ensure("SunRaysEffect", Lighting) :: SunRaysEffect
	rays.Intensity = 0.12
	rays.Spread = 0.6

	local color = ensure("ColorCorrectionEffect", Lighting) :: ColorCorrectionEffect
	color.Saturation = 0.24 -- cores vivas da referência (mel, verde, céu azul)
	color.Contrast = 0.1
	color.TintColor = Color3.fromRGB(255, 248, 235)

	local clouds = ensure("Clouds", workspace.Terrain) :: Clouds
	clouds.Cover = 0.55
	clouds.Density = 0.6
	clouds.Color = Color3.fromRGB(255, 250, 245)
end

local function buildTerrain(rng: Random)
	local terrain = workspace.Terrain
	-- Água azul-turquesa com reflexo (lagos e cachoeiras da referência).
	terrain.WaterColor = Color3.fromRGB(60, 160, 190)
	terrain.WaterTransparency = 0.55
	terrain.WaterReflectance = 0.6
	terrain.WaterWaveSize = 0.12
	terrain.WaterWaveSpeed = 8
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
		-- À noite as pétalas de dentro acendem (flores mágicas da referência).
		-- (A luz fica numa pétala, não no miolo: o miolo apaga quando é coletado.)
		local lightHolder: BasePart? = nil
		for _, part in imported:GetDescendants() do
			if part:IsA("BasePart") and part:GetAttribute("Papel") == "PetalaInterna" then
				part:SetAttribute("NightColor", colors[2]:Lerp(Color3.new(1, 1, 1), 0.15))
				CollectionService:AddTag(part, MapBuilder.Tags.NightGlow)
				lightHolder = lightHolder or part
			end
		end
		if lightHolder then
			local glow = light(lightHolder, colors[1], 22, 1.2)
			glow.Enabled = false
			CollectionService:AddTag(glow, MapBuilder.Tags.NightGlow)
		end
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

-- Caverna de Cristal: domo de pedra escavado no terreno, cristais acesos dentro.
-- Retorna pontos para favos (dentro da caverna).
local function buildCave(parent: Instance): { Vector3 }
	local info = Config.Places.Cave
	local center = info.Position
	local r = info.Radius
	local terrain = workspace.Terrain
	terrain:FillBall(center + Vector3.new(0, 6, 0), r, Enum.Material.Slate)
	terrain:FillBall(center + Vector3.new(0, 8, 0), r - 7, Enum.Material.Air)
	-- Chão plano dentro e entrada virada para o centro do mapa.
	terrain:FillBlock(
		CFrame.new(center + Vector3.new(0, -2, 0)),
		Vector3.new(r * 2 - 10, 4, r * 2 - 10),
		Enum.Material.Slate
	)
	local toCenter = Vector3.new(-center.X, 0, -center.Z).Unit
	local door = center + toCenter * (r - 3) + Vector3.new(0, 10, 0)
	terrain:FillBlock(CFrame.lookAt(door, door + toCenter), Vector3.new(22, 18, 20), Enum.Material.Air)

	local model = Instance.new("Model")
	model.Name = "CavernaDeCristal"
	local rng = Random.new(Config.Map.Seed + 9)
	local spots = {}
	for i = 1, 14 do
		local angle = (i / 14) * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local radius = rng:NextNumber(10, r - 12)
		local base = center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local height = rng:NextNumber(5, 13)
		local color = if i % 3 == 0 then Color3.fromRGB(90, 200, 255) else Color3.fromRGB(170, 90, 255)
		local shard = newPart(
			"Cristal",
			Vector3.new(height, rng:NextNumber(1.6, 3), rng:NextNumber(1.6, 3)),
			CFrame.new(base + Vector3.new(0, height / 2 - 0.5, 0))
				* CFrame.Angles(
					rng:NextNumber(-0.3, 0.3),
					rng:NextNumber(0, 6),
					math.rad(90) + rng:NextNumber(-0.3, 0.3)
				),
			color,
			model
		)
		shard.Material = Enum.Material.Neon
		shard.Transparency = 0.15
		if i % 2 == 0 then
			light(shard, color, 22, 1.4)
		end
		if i % 4 == 1 then
			table.insert(spots, base + Vector3.new(0, 3, 0))
		end
	end
	-- Brilho no ar.
	local mote =
		newPart("Brilho", Vector3.one, CFrame.new(center + Vector3.new(0, 12, 0)), Color3.new(1, 1, 1), model)
	mote.Transparency = 1
	mote.CanCollide = false
	local dust = sparkles(mote, Color3.fromRGB(200, 160, 255), 8, 0.4)
	dust.SpreadAngle = Vector2.new(180, 180)
	-- Placa na entrada.
	local signPost = newPart(
		"Placa",
		Vector3.new(1, 1, 1),
		CFrame.new(door + toCenter * 14 - Vector3.new(0, 4, 0)),
		Color3.new(),
		model
	)
	signPost.Transparency = 1
	signPost.CanCollide = false
	addLabel(signPost, "Caverna de Cristal", "favos raros lá dentro", Color3.fromRGB(190, 140, 255)).MaxDistance =
		220
	model.Parent = parent
	return spots
end

-- Lago das Libélulas: água, vitórias-régias e juncos. Retorna pontos para favos.
local function buildLake(parent: Instance): { Vector3 }
	local info = Config.Places.Lake
	local center = info.Position
	local terrain = workspace.Terrain
	terrain:FillCylinder(CFrame.new(center + Vector3.new(0, -3, 0)), 6, info.Radius, Enum.Material.Water)
	terrain:FillCylinder(CFrame.new(center + Vector3.new(0, -7, 0)), 2, info.Radius, Enum.Material.Mud)

	local model = Instance.new("Model")
	model.Name = "LagoDasLibelulas"
	local rng = Random.new(Config.Map.Seed + 21)
	local spots = {}
	for i = 1, 12 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(8, info.Radius - 10)
		local position = center + Vector3.new(math.cos(angle) * radius, 0.2, math.sin(angle) * radius)
		local size = rng:NextNumber(5, 9)
		local pad = newPart(
			"VitoriaRegia",
			Vector3.new(0.4, size, size),
			CFrame.new(position) * CFrame.Angles(0, rng:NextNumber(0, 6), math.rad(90)),
			Color3.fromRGB(70, 150, 70),
			model
		)
		pad.Shape = Enum.PartType.Cylinder
		if i % 3 == 0 then
			local bloom = ball(
				"FlorDoLago",
				1.6,
				position + Vector3.new(0, 0.8, 0),
				Color3.fromRGB(255, 150, 200),
				model
			)
			bloom.Material = Enum.Material.Neon
			bloom.CanCollide = false
		end
		if i % 4 == 0 then
			table.insert(spots, position + Vector3.new(0, 2.5, 0))
		end
	end
	for i = 1, 40 do
		local angle = (i / 40) * math.pi * 2 + rng:NextNumber(-0.05, 0.05)
		local radius = info.Radius + rng:NextNumber(-2, 4)
		local base = center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local height = rng:NextNumber(4, 9)
		local reed = newPart(
			"Junco",
			Vector3.new(0.35, height, 0.35),
			CFrame.new(base + Vector3.new(0, height / 2, 0))
				* CFrame.Angles(rng:NextNumber(-0.15, 0.15), 0, rng:NextNumber(-0.15, 0.15)),
			Color3.fromRGB(95, 140, 60),
			model
		)
		reed.CanCollide = false
		if i % 3 == 0 then
			newPart(
				"Taboa",
				Vector3.new(0.6, 1.4, 0.6),
				reed.CFrame * CFrame.new(0, height / 2 - 0.4, 0),
				Color3.fromRGB(110, 70, 40),
				model
			).CanCollide =
				false
		end
	end
	local signPost =
		newPart("Placa", Vector3.one, CFrame.new(center + Vector3.new(0, 18, 0)), Color3.new(), model)
	signPost.Transparency = 1
	signPost.CanCollide = false
	addLabel(signPost, "Lago das Libélulas", "cuidado com os rasantes!", Color3.fromRGB(110, 200, 255)).MaxDistance =
		260
	model.Parent = parent
	return spots
end

-- Ilha nas Nuvens: terreno flutuante com flores especiais. Retorna os néctares.
local function buildSkyIsland(parent: Instance, rng: Random): { BasePart }
	local info = Config.SkyIsland
	local center = info.Position
	local r = info.Radius
	local terrain = workspace.Terrain
	-- Base de pedra afinando para baixo e grama em cima (topo em center.Y).
	terrain:FillCylinder(CFrame.new(center + Vector3.new(0, -6, 0)), 10, r, Enum.Material.Rock)
	terrain:FillBall(center + Vector3.new(0, -18, 0), r * 0.75, Enum.Material.Rock)
	terrain:FillBall(center + Vector3.new(0, -36, 0), r * 0.4, Enum.Material.Rock)
	terrain:FillCylinder(CFrame.new(center + Vector3.new(0, -1.5, 0)), 3, r, Enum.Material.Grass)

	local model = Instance.new("Model")
	model.Name = "IlhaNasNuvens"
	-- Nuvens fofas em volta.
	for i = 1, 16 do
		local angle = (i / 16) * math.pi * 2
		local radius = r + rng:NextNumber(-6, 10)
		local size = rng:NextNumber(10, 22)
		local cloud = ball(
			"Nuvem",
			size,
			center + Vector3.new(math.cos(angle) * radius, rng:NextNumber(-14, -4), math.sin(angle) * radius),
			Color3.fromRGB(250, 250, 255),
			model
		)
		cloud.Transparency = 0.15
		cloud.CanCollide = false
		cloud.CastShadow = false
	end
	local signPost =
		newPart("Placa", Vector3.one, CFrame.new(center + Vector3.new(0, 30, 0)), Color3.new(), model)
	signPost.Transparency = 1
	signPost.CanCollide = false
	addLabel(signPost, "Ilha nas Nuvens", "flores com 2× néctar", Color3.fromRGB(150, 220, 255)).MaxDistance =
		500
	model.Parent = parent

	local centers = {}
	for i = 1, info.Flowers do
		local angle = (i / info.Flowers) * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local radius = rng:NextNumber(8, r - 10)
		local base = center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local nectar = buildFlower(parent, base, rng)
		nectar:SetAttribute("Nuvem", true)
		table.insert(centers, nectar)
	end
	return centers
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

	-- Marco de navegação: sempre enviado a todos (não some com a distância).
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model.Parent = parent
	return spots
end

-- Decoração das árvores-colmeia -------------------------------------------------

local BANNER_RED = Color3.fromRGB(150, 28, 40)
local DARK_WOOD = Color3.fromRGB(70, 48, 30)
local WAX = Color3.fromRGB(252, 246, 228)
local FAIRY_COLORS = {
	Color3.fromRGB(255, 214, 120),
	Color3.fromRGB(255, 170, 80),
	Color3.fromRGB(255, 236, 170),
}

-- Hexágono desenhado em 2D (3 retângulos girados) para bandeiras.
local function hexEmblem(parent: GuiObject, color: Color3, centerY: number, size: number)
	for i = 0, 2 do
		local frame = Instance.new("Frame")
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = UDim2.fromScale(0.5, centerY)
		frame.Size = UDim2.fromScale(size, size * math.sqrt(3)) -- lado × lado·√3
		frame.SizeConstraint = Enum.SizeConstraint.RelativeXX
		frame.Rotation = 60 * i
		frame.BackgroundColor3 = color
		frame.BorderSizePixel = 0
		frame.Parent = parent
	end
end

-- Estandarte vermelho com coroa e favo dourados (como na referência).
local function banner(parent: Instance, cf: CFrame, width: number, height: number)
	local cloth = newPart("Estandarte", Vector3.new(width, height, 0.3), cf, BANNER_RED, parent)
	cloth.Material = Enum.Material.Fabric
	cloth.CanCollide = false
	local rod = newPart(
		"Haste",
		Vector3.new(width + 2, 0.7, 0.7),
		cf * CFrame.new(0, height / 2 + 0.3, 0),
		GOLD,
		parent
	)
	rod.CanCollide = false
	-- Ponta em "V" embaixo: dois triângulos feitos com cunhas.
	for side = -1, 1, 2 do
		local tip = Instance.new("WedgePart")
		tip.Name = "Ponta"
		tip.Anchored = true
		tip.CanCollide = false
		tip.Size = Vector3.new(0.3, height * 0.18, width / 2)
		tip.CFrame = cf
			* CFrame.new(side * width / 4, -height / 2 - height * 0.09, 0)
			* CFrame.Angles(0, math.rad(90 * side), math.rad(180))
		tip.Color = BANNER_RED
		tip.Material = Enum.Material.Fabric
		tip.Parent = parent
	end
	local trim = newPart(
		"Franja",
		Vector3.new(width, 0.6, 0.4),
		cf * CFrame.new(0, -height / 2 + 0.3, 0),
		GOLD,
		parent
	)
	trim.CanCollide = false
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.CanvasSize = Vector2.new(200, math.floor(200 * height / width))
		gui.LightInfluence = 0.5
		local bg = Instance.new("Frame")
		bg.Size = UDim2.fromScale(1, 1)
		bg.BackgroundTransparency = 1
		bg.Parent = gui
		-- Borda dourada.
		local border = Instance.new("UIStroke")
		border.Color = GOLD
		border.Thickness = 6
		border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		local inner = Instance.new("Frame")
		inner.AnchorPoint = Vector2.new(0.5, 0.5)
		inner.Position = UDim2.fromScale(0.5, 0.5)
		inner.Size = UDim2.new(1, -24, 1, -24)
		inner.BackgroundTransparency = 1
		border.Parent = inner
		inner.Parent = bg
		local crown = Instance.new("TextLabel")
		crown.BackgroundTransparency = 1
		crown.AnchorPoint = Vector2.new(0.5, 0.5)
		crown.Position = UDim2.fromScale(0.5, 0.3)
		crown.Size = UDim2.fromScale(0.6, 0.18)
		crown.TextScaled = true
		crown.Text = "👑"
		crown.Parent = bg
		hexEmblem(bg, GOLD, 0.55, 0.2)
		hexEmblem(bg, BANNER_RED, 0.55, 0.12)
		gui.Parent = cloth
	end
end

-- Lanterna de verdade: tampa, vidro aceso e base. Acende a luz à noite.
local function lantern(parent: Instance, position: Vector3, scale: number?)
	local k = scale or 1
	newPart(
		"Tampa",
		Vector3.new(2.4, 0.5, 2.4) * k,
		CFrame.new(position + Vector3.new(0, 1.55 * k, 0)),
		DARK_WOOD,
		parent
	).CanCollide =
		false
	newPart(
		"Topo",
		Vector3.new(1, 0.6, 1) * k,
		CFrame.new(position + Vector3.new(0, 2.1 * k, 0)),
		DARK_WOOD,
		parent
	).CanCollide =
		false
	local glass =
		uprightCylinder("Lanterna", 2.6 * k, 1.9 * k, position, Color3.fromRGB(255, 205, 110), parent)
	glass.Material = Enum.Material.Neon
	glass.CanCollide = false
	newPart(
		"Base",
		Vector3.new(2.2, 0.4, 2.2) * k,
		CFrame.new(position - Vector3.new(0, 1.5 * k, 0)),
		DARK_WOOD,
		parent
	).CanCollide =
		false
	local glow = light(glass, Color3.fromRGB(255, 185, 95), 26 * k, 1.3)
	glow.Enabled = false
	CollectionService:AddTag(glow, MapBuilder.Tags.NightGlow)
end

-- Poste de madeira com lanterna pendurada.
local function lampPost(parent: Instance, base: Vector3, facing: CFrame)
	local height = 11
	uprightCylinder("Poste", height, 0.9, base + Vector3.new(0, height / 2, 0), DARK_WOOD, parent).CanCollide =
		false
	local arm = newPart(
		"Braco",
		Vector3.new(0.6, 0.6, 3),
		CFrame.new(base + Vector3.new(0, height - 0.3, 0)) * facing.Rotation * CFrame.new(0, 0, -1.3),
		DARK_WOOD,
		parent
	)
	arm.CanCollide = false
	local hang = (arm.CFrame * CFrame.new(0, -2.4, -1.2)).Position
	lantern(parent, hang, 0.8)
end

-- Luzinhas (pisca-pisca) ao longo de uma curva: lista de pontos.
local function fairyLights(parent: Instance, points: { Vector3 })
	for i, point in points do
		local bulb = ball("Luzinha", 0.7, point, FAIRY_COLORS[(i % #FAIRY_COLORS) + 1], parent)
		bulb.Material = Enum.Material.Neon
		bulb.CanCollide = false
		bulb.CastShadow = false
	end
end

-- Caixote com blocos de cera empilhados (como os da referência).
local function waxCrate(parent: Instance, cf: CFrame)
	local box = newPart(
		"Caixote",
		Vector3.new(5, 3, 5),
		cf * CFrame.new(0, 1.5, 0),
		Color3.fromRGB(150, 105, 62),
		parent
	)
	box.Material = Enum.Material.WoodPlanks
	for x = -1, 1, 2 do
		for z = -1, 1, 2 do
			local wax = newPart(
				"Cera",
				Vector3.new(2.1, 1.6, 2.1),
				cf * CFrame.new(x * 1.15, 3.8, z * 1.15),
				WAX,
				parent
			)
			wax.CanCollide = false
		end
	end
	newPart("Cera", Vector3.new(2.1, 1.6, 2.1), cf * CFrame.new(0.4, 5.4, -0.2), WAX, parent).CanCollide =
		false
end

-- Arco de madeira com friso dourado emoldurando a parede de favos.
local function hiveArch(parent: Instance, center: CFrame, radius: number, postBottom: number)
	local thickness = 4
	local postHeight = -postBottom
	for side = -1, 1, 2 do
		local post = newPart(
			"Pilar",
			Vector3.new(thickness, postHeight, thickness),
			center * CFrame.new(side * radius, -postHeight / 2, 0),
			Color3.fromRGB(135, 92, 52),
			parent
		)
		post.Material = Enum.Material.Wood
		local trim = newPart(
			"Friso",
			Vector3.new(0.7, postHeight, 0.7),
			center * CFrame.new(side * (radius - thickness / 2 - 0.2), -postHeight / 2, -thickness / 2),
			GOLD,
			parent
		)
		trim.CanCollide = false
	end
	local segments = 14
	local bulbs = {}
	for i = 0, segments - 1 do
		local angle = math.pi * (i + 0.5) / segments
		local length = math.pi * radius / segments + 0.8
		local segment = newPart(
			"Arco",
			Vector3.new(length, thickness, thickness),
			center
				* CFrame.new(math.cos(angle) * radius, math.sin(angle) * radius, 0)
				* CFrame.Angles(0, 0, angle + math.pi / 2),
			Color3.fromRGB(135, 92, 52),
			parent
		)
		segment.Material = Enum.Material.Wood
		local inner = radius - thickness / 2 - 0.2
		local trim = newPart(
			"Friso",
			Vector3.new(math.pi * inner / segments + 0.3, 0.7, 0.7),
			center
				* CFrame.new(math.cos(angle) * inner, math.sin(angle) * inner, -thickness / 2)
				* CFrame.Angles(0, 0, angle + math.pi / 2),
			GOLD,
			parent
		)
		trim.CanCollide = false
	end
	-- Luzinhas por fora do arco.
	for i = 0, 20 do
		local angle = math.pi * i / 20
		table.insert(
			bulbs,
			(center * CFrame.new(math.cos(angle) * (radius + 2.6), math.sin(angle) * (radius + 2.6), -1)).Position
		)
	end
	fairyLights(parent, bulbs)
end

local function decorateHiveTree(parent: Instance, plotCF: CFrame, trunkCenter: Vector3, wallCenter: CFrame)
	local archRadius = 30
	hiveArch(parent, wallCenter * CFrame.new(0, 0, -1.6), archRadius, -wallCenter.Position.Y + 2)
	-- Estandartes vermelhos pendurados nos pilares do arco.
	banner(parent, wallCenter * CFrame.new(-archRadius, -6, -4), 6, 14)
	banner(parent, wallCenter * CFrame.new(archRadius, -6, -4), 6, 14)
	-- Lanternas penduradas no arco, dos dois lados (sem tampar as células).
	for side = -1, 1, 2 do
		local angle = math.rad(90 - 40 * side)
		local inner = archRadius - 2.2
		local hook = wallCenter * CFrame.new(math.cos(angle) * inner, math.sin(angle) * inner, -4)
		lantern(parent, (hook * CFrame.new(0, -3.4, 0)).Position, 0.9)
	end
	-- Postes com lanterna na frente da plataforma.
	lampPost(parent, (plotCF * CFrame.new(-25, 2, -21)).Position, plotCF)
	lampPost(parent, (plotCF * CFrame.new(25, 2, -21)).Position, plotCF)
	-- Caixotes de cera nos cantos.
	waxCrate(parent, plotCF * CFrame.new(-21, 2, -3) * CFrame.Angles(0, 0.3, 0))
	waxCrate(parent, plotCF * CFrame.new(21, 2, -3) * CFrame.Angles(0, -0.25, 0))
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

-- Tronco da árvore-colmeia: janelas redondas, varandinhas e raízes.
-- `a` = ângulo em volta do tronco no espaço do lote (0 = fundos, 180° = frente).
local function decorateTrunk(parent: Instance, plotCF: CFrame, trunkCenter: Vector3, radius: number)
	local function around(a: number): Vector3
		return plotCF:VectorToWorldSpace(Vector3.new(math.sin(math.rad(a)), 0, math.cos(math.rad(a))))
	end
	local windows = {
		{ -65, 22, true },
		{ 65, 30, false },
		{ -110, 52, false },
		{ 110, 46, true },
		{ 0, 40, true },
		{ -30, 70, false },
		{ 35, 66, false },
	}
	for _, info in windows do
		local dir = around(info[1])
		local center = Vector3.new(trunkCenter.X, info[2], trunkCenter.Z) + dir * (radius + 0.3)
		-- Cilindro com o eixo apontando para fora do tronco.
		local facing = CFrame.lookAt(center, center + dir) * CFrame.Angles(0, math.rad(90), 0)
		local frame = newPart("Moldura", Vector3.new(1, 8.4, 8.4), facing, DARK_WOOD, parent)
		frame.Shape = Enum.PartType.Cylinder
		local glass =
			newPart("Janela", Vector3.new(1.3, 6.6, 6.6), facing, Color3.fromRGB(210, 150, 70), parent)
		glass.Shape = Enum.PartType.Cylinder
		glass.Material = Enum.Material.Glass
		glass:SetAttribute("NightColor", Color3.fromRGB(255, 200, 110))
		CollectionService:AddTag(glass, MapBuilder.Tags.NightGlow)
		local glow = light(glass, Color3.fromRGB(255, 185, 95), 20, 1)
		glow.Enabled = false
		CollectionService:AddTag(glow, MapBuilder.Tags.NightGlow)
		-- Cruz da janela.
		for _, angle in { 0, 90 } do
			newPart(
				"Travessa",
				Vector3.new(1.5, 0.5, 6.6),
				facing * CFrame.Angles(math.rad(angle), 0, 0),
				DARK_WOOD,
				parent
			).CanCollide =
				false
		end
		if info[3] then
			-- Varandinha com parapeito embaixo da janela.
			local deckCF = CFrame.lookAt(
				center + dir * 2.6 - Vector3.new(0, 5, 0),
				center + dir * 10 - Vector3.new(0, 5, 0)
			)
			local deck =
				newPart("Varandinha", Vector3.new(10, 0.8, 5), deckCF, Color3.fromRGB(150, 105, 62), parent)
			deck.Material = Enum.Material.WoodPlanks
			newPart(
				"Parapeito",
				Vector3.new(10, 0.4, 0.4),
				deckCF * CFrame.new(0, 2.4, -2.3),
				DARK_WOOD,
				parent
			).CanCollide =
				false
			for x = -4.6, 4.6, 2.3 do
				newPart(
					"Balaustre",
					Vector3.new(0.35, 2.4, 0.35),
					deckCF * CFrame.new(x, 1.2, -2.3),
					DARK_WOOD,
					parent
				).CanCollide =
					false
			end
		end
	end
	-- Raízes grossas saindo da base.
	for _, a in { 0, 60, -60, 125, -125 } do
		local dir = around(a)
		local start = Vector3.new(trunkCenter.X, 3, trunkCenter.Z) + dir * (radius - 2)
		local root = newPart(
			"Raiz",
			Vector3.new(7, 5, 18),
			CFrame.lookAt(start + dir * 6, start + dir * 20 - Vector3.new(0, 6, 0)),
			Color3.fromRGB(100, 70, 45),
			parent
		)
		root.Material = Enum.Material.Wood
	end
end

-- Ponte de tábuas entre duas árvores-colmeia vizinhas.
-- Ponte de corda entre dois pontos. Sem alturas: usa Config.Map.BridgeHeight
-- (pontes entre as árvores-colmeia). `inset` = quanto recua de cada ponta.
local function bridge(
	parent: Instance,
	from: Vector3,
	to: Vector3,
	yFrom: number?,
	yTo: number?,
	inset: number?
)
	local a = Vector3.new(from.X, yFrom or Config.Map.BridgeHeight, from.Z)
	local b = Vector3.new(to.X, yTo or Config.Map.BridgeHeight, to.Z)
	local direction = (b - a).Unit
	a += direction * (inset or 40)
	b -= direction * (inset or 40)
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
		-- Pisca-pisca pendurado na corda, com leve barriga.
		local bulbs = {}
		local count = math.max(2, math.floor(length / 4))
		for i = 0, count do
			local t = i / count
			local sag = math.sin(t * math.pi) * 1.5
			table.insert(bulbs, (cf * CFrame.new(side * 4, 2.2 - sag, -length / 2 + t * length)).Position)
		end
		fairyLights(model, bulbs)
	end
	model.Parent = parent
end

-- Paisagem da referência ------------------------------------------------------
-- O chão era uma planície. Agora o vale tem: cordilheira no horizonte (limite
-- visual do mundo e fundo para o castelo), colinas no pé das montanhas e
-- dois grupos de penhascos com casinhas de favo, lanternas, pontes de corda
-- e cachoeiras — a silhueta das imagens 01 e 02. Tudo fica FORA dos anéis
-- usados pelo jogo (colmeias, campo, bosque, caverna, lago e Colmeia Real).

local function angleDelta(a: number, b: number): number
	local d = (b - a) % (2 * math.pi)
	if d > math.pi then
		d -= 2 * math.pi
	end
	return d
end
local HUT_WAX = Color3.fromRGB(246, 206, 110)
local HUT_ROOF = Color3.fromRGB(176, 104, 40)
local LANTERN = Color3.fromRGB(255, 205, 110)

-- Cachoeira: lâmina translúcida + gotas caindo (partículas) + névoa no pé.
local function waterfall(parent: Instance, top: Vector3, height: number, width: number, facing: Vector3)
	local flat = Vector3.new(facing.X, 0, facing.Z).Unit
	local middle = top - Vector3.new(0, height / 2, 0) + flat * 1.5
	local sheet = newPart(
		"Cachoeira",
		Vector3.new(width, height, 1.2),
		CFrame.lookAt(middle, middle + flat),
		Color3.fromRGB(175, 222, 255),
		parent
	)
	sheet.Material = Enum.Material.Glass
	sheet.Transparency = 0.3
	sheet.CanCollide = false
	sheet.CastShadow = false
	local source = newPart(
		"Nascente",
		Vector3.new(width, 1, 2),
		CFrame.lookAt(top + flat * 2, top + flat * 3),
		Color3.new(1, 1, 1),
		parent
	)
	source.Transparency = 1
	source.CanCollide = false
	local drops = Instance.new("ParticleEmitter")
	drops.Name = "Agua"
	drops.Color = ColorSequence.new(Color3.fromRGB(225, 242, 255))
	drops.LightEmission = 0.2
	drops.Transparency = NumberSequence.new(0.35)
	drops.Size = NumberSequence.new(2.4)
	drops.Rate = width * 2
	drops.Speed = NumberRange.new(4, 8)
	drops.SpreadAngle = Vector2.new(8, 8)
	drops.EmissionDirection = Enum.NormalId.Bottom
	drops.Acceleration = Vector3.new(0, -70, 0)
	drops.Lifetime = NumberRange.new(math.sqrt(2 * height / 70))
	drops.Parent = source
	local mist = newPart(
		"Nevoa",
		Vector3.new(width, 1, 8),
		CFrame.new(top - Vector3.new(0, height - 1, 0) + flat * 4),
		Color3.new(1, 1, 1),
		parent
	)
	mist.Transparency = 1
	mist.CanCollide = false
	local spray = sparkles(mist, Color3.fromRGB(235, 248, 255), 18, 3)
	spray.LightEmission = 0.3
	spray.Speed = NumberRange.new(3, 7)
end

-- Casinha de favo: torre hexagonal de cera, telhado em cúpula, janela acesa.
local function honeyHut(parent: Instance, base: Vector3, height: number, rng: Random)
	local width = height * 0.8
	local side = width / math.sqrt(3)
	local yaw = rng:NextNumber(0, math.pi)
	local body = CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, yaw, 0)
	for k = 0, 2 do
		-- Prisma hexagonal em pé: 3 blocos girados em volta do eixo vertical.
		local block = newPart(
			"Casa",
			Vector3.new(side, height, width),
			body * CFrame.Angles(0, k * math.pi / 3, 0),
			HUT_WAX,
			parent
		)
		block.Material = Enum.Material.SmoothPlastic
	end
	local roof = ball("Telhado", width * 1.15, base + Vector3.new(0, height, 0), HUT_ROOF, parent)
	roof.Size = Vector3.new(width * 1.15, width * 0.8, width * 1.15)
	local window = newPart(
		"Janela",
		Vector3.new(width * 0.32, height * 0.32, 0.4),
		body * CFrame.new(0, height * 0.05, -width / 2 - 0.1),
		LANTERN,
		parent
	)
	window.Material = Enum.Material.Neon
	window:SetAttribute("NightColor", LANTERN)
	CollectionService:AddTag(window, MapBuilder.Tags.NightGlow)
	local door = newPart(
		"Porta",
		Vector3.new(width * 0.3, height * 0.38, 0.4),
		body * CFrame.new(0, -height * 0.31, width / 2 + 0.1),
		DARK_WOOD,
		parent
	)
	door.Material = Enum.Material.Wood
end

-- Penhasco: coluna de rocha com topo gramado, casinhas e uma lanterna.
local function cliffPillar(
	parent: Instance,
	center: Vector3,
	radius: number,
	height: number,
	rng: Random
): Vector3
	local terrain = workspace.Terrain
	terrain:FillCylinder(
		CFrame.new(center + Vector3.new(0, height / 2 - 6, 0)),
		height + 12,
		radius,
		Enum.Material.Rock
	)
	-- Saias de pedra mais largas na base (silhueta irregular).
	terrain:FillBall(center + Vector3.new(radius * 0.4, 10, -radius * 0.3), radius * 0.9, Enum.Material.Slate)
	terrain:FillCylinder(
		CFrame.new(center + Vector3.new(0, height + 1, 0)),
		4,
		radius + 2,
		Enum.Material.Grass
	)
	terrain:FillBall(center + Vector3.new(0, height + 1, 0), radius * 0.55, Enum.Material.LeafyGrass)
	local top = center + Vector3.new(0, height + 3, 0)
	for i = 1, 2 do
		local angle = i * math.pi + rng:NextNumber(-0.6, 0.6)
		local spot = top + Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius * 0.45
		honeyHut(parent, spot, rng:NextNumber(10, 15), rng)
	end
	local post = newPart(
		"Poste",
		Vector3.new(0.8, 9, 0.8),
		CFrame.new(top + Vector3.new(0, 4.5, 0)),
		DARK_WOOD,
		parent
	)
	post.Material = Enum.Material.Wood
	local lamp = ball("Lanterna", 2.2, top + Vector3.new(0, 9.6, 0), LANTERN, parent)
	lamp.Material = Enum.Material.Neon
	local light = Instance.new("PointLight")
	light.Color = LANTERN
	light.Range = 26
	light.Brightness = 0.8
	light.Parent = lamp
	return top
end

local function buildLandscape(parent: Instance, rng: Random)
	local folder = Instance.new("Model")
	folder.Name = "Paisagem"
	folder.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	folder.Parent = parent
	local terrain = workspace.Terrain
	local royalAngle = math.atan2(Config.Map.RoyalHive.Position.Z, Config.Map.RoyalHive.Position.X)

	-- 1. Cordilheira no horizonte: picos ALTOS (300–400 studs) feitos de peças
	-- (elipsoides), que passam por cima das copas e aparecem de qualquer lugar.
	-- Peças grandes são baratas (uma peça por forma) e chegam ao cliente.
	-- Model "Persistent": o Roblox manda para todos os clientes mesmo longe
	-- (com streaming, peças a mais de ~1000 studs não chegavam e o céu ficava vazio).
	local mountains = Instance.new("Model")
	mountains.Name = "Montanhas"
	mountains.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	mountains.Parent = folder
	local function ellipsoid(
		name: string,
		size: Vector3,
		center: Vector3,
		color: Color3,
		material: Enum.Material
	)
		local part = newPart(name, size, CFrame.new(center), color, mountains)
		part.Material = material
		part.CastShadow = false
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
		return part
	end
	local peaks = 24
	for i = 1, peaks do
		local angle = (i / peaks) * math.pi * 2 + rng:NextNumber(-0.05, 0.05)
		local radius = rng:NextNumber(1190, 1260) -- atrás dos penhascos (que ficam a ~950)
		local base = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local width = rng:NextNumber(230, 330)
		local height = rng:NextNumber(480, 700)
		-- Saia verde larga, pico de pedra e (às vezes) neve no topo.
		ellipsoid(
			"Encosta",
			Vector3.new(width * 1.6, height * 0.42, width * 1.6),
			base + Vector3.new(0, 10, 0),
			Color3.fromRGB(86, 128, 70),
			Enum.Material.Grass
		)
		ellipsoid(
			"Pico",
			Vector3.new(width, height, width * 0.9),
			base + Vector3.new(rng:NextNumber(-20, 20), 40, 0),
			Color3.fromRGB(122, 118, 126),
			Enum.Material.Slate
		)
		if rng:NextNumber() < 0.55 then
			ellipsoid(
				"Neve",
				Vector3.new(width * 0.42, height * 0.2, width * 0.4),
				base + Vector3.new(0, 40 + height * 0.42, 0),
				Color3.fromRGB(240, 245, 252),
				Enum.Material.Snow
			)
		end
	end

	-- 2. Colinas no pé das montanhas (longe do castelo, para não esconder o palácio).
	for i = 1, 26 do
		local angle = (i / 26) * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
		if math.abs(angleDelta(angle, royalAngle)) > 0.4 then
			local radius = rng:NextNumber(900, 960)
			local center = Vector3.new(math.cos(angle) * radius, -40, math.sin(angle) * radius)
			terrain:FillBall(center, rng:NextNumber(70, 110), Enum.Material.Grass)
			terrain:FillBall(center + Vector3.new(0, 20, 0), rng:NextNumber(40, 60), Enum.Material.LeafyGrass)
		end
	end

	-- 3. Dois grupos de penhascos com casinhas, pontes e cachoeira.
	for _, group in Config.Map.CliffGroups do
		local tops: { Vector3 } = {}
		local radii: { number } = {}
		for i, offset in group.Pillars do
			local center = group.Center + offset
			local radius = rng:NextNumber(24, 34)
			local height = rng:NextNumber(70, 120) + (if i == 1 then 30 else 0)
			table.insert(tops, cliffPillar(folder, center, radius, height, rng))
			table.insert(radii, radius)
		end
		for i = 1, #tops - 1 do
			bridge(
				folder,
				tops[i],
				tops[i + 1],
				tops[i].Y + 2,
				tops[i + 1].Y + 2,
				math.max(radii[i], radii[i + 1]) - 4
			)
		end
		-- Cachoeira no penhasco mais alto, virada para o centro do vale.
		local toCenter = -Vector3.new(tops[1].X, 0, tops[1].Z).Unit
		local edge = Vector3.new(tops[1].X, tops[1].Y - 3, tops[1].Z) + toCenter * (radii[1] + 1)
		waterfall(folder, edge, tops[1].Y - 4, 14, toCenter)
		terrain:FillCylinder(
			CFrame.new(Vector3.new(edge.X, -3, edge.Z) + toCenter * 22),
			6,
			26,
			Enum.Material.Water
		)
	end
end

-- Andaimes de madeira dos dois lados da parede de favos (referências 02/03):
-- postes, travessas, plataformas com blocos de cera, escada e roldana com balde.
local SCAFFOLD_WOOD = Color3.fromRGB(150, 108, 66)

local function scaffolding(parent: Instance, plotCF: CFrame)
	local model = Instance.new("Model")
	model.Name = "Andaimes"
	for side = -1, 1, 2 do
		local x0 = side * 36
		local x1 = side * 46
		for _, x in { x0, x1 } do
			for _, z in { -3, -11 } do
				local post = newPart(
					"Poste",
					Vector3.new(1.2, 62, 1.2),
					plotCF * CFrame.new(x, 31, z),
					SCAFFOLD_WOOD,
					model
				)
				post.Material = Enum.Material.Wood
			end
		end
		for level = 1, 3 do
			local y = level * 16
			-- Plataforma (tábuas) e travessas.
			local floor = newPart(
				"Tablado",
				Vector3.new(11, 0.8, 10),
				plotCF * CFrame.new((x0 + x1) / 2, y, -7),
				Color3.fromRGB(170, 124, 78),
				model
			)
			floor.Material = Enum.Material.WoodPlanks
			for _, z in { -3, -11 } do
				local rail = newPart(
					"Corrimao",
					Vector3.new(11, 0.5, 0.5),
					plotCF * CFrame.new((x0 + x1) / 2, y + 3, z),
					SCAFFOLD_WOOD,
					model
				)
				rail.Material = Enum.Material.Wood
				rail.CanCollide = false
			end
			-- Travessa diagonal (X do andaime).
			local brace = newPart(
				"Travessa",
				Vector3.new(0.5, 18, 0.5),
				plotCF * CFrame.new((x0 + x1) / 2, y - 8, -11) * CFrame.Angles(0, 0, math.rad(side * 32)),
				SCAFFOLD_WOOD,
				model
			)
			brace.Material = Enum.Material.Wood
			brace.CanCollide = false
			-- Blocos de cera empilhados (material de construção).
			for k = 0, level % 2 do
				local block = newPart(
					"BlocoCera",
					Vector3.new(2.4, 2, 2.4),
					plotCF * CFrame.new((x0 + x1) / 2 + (k - 0.5) * 3, y + 1.4, -6),
					WAX,
					model
				)
				block.CanCollide = false
			end
		end
		-- Escada encostada.
		for step = 0, 12 do
			local rung = newPart(
				"Degrau",
				Vector3.new(4, 0.4, 0.4),
				plotCF * CFrame.new(x1 + side * 2.5, 2 + step * 3.6, -1.5),
				SCAFFOLD_WOOD,
				model
			)
			rung.Material = Enum.Material.Wood
			rung.CanCollide = false
		end
		for _, dx in { -2, 2 } do
			local beam = newPart(
				"Banzo",
				Vector3.new(0.5, 47, 0.5),
				plotCF * CFrame.new(x1 + side * 2.5 + dx, 23.5, -1.5),
				SCAFFOLD_WOOD,
				model
			)
			beam.Material = Enum.Material.Wood
			beam.CanCollide = false
		end
		-- Roldana no alto com corda e balde de mel.
		local arm = newPart(
			"Braco",
			Vector3.new(8, 0.8, 0.8),
			plotCF * CFrame.new(x1 + side * 3, 62, -7),
			SCAFFOLD_WOOD,
			model
		)
		arm.Material = Enum.Material.Wood
		local rope = newPart(
			"Corda",
			Vector3.new(0.25, 26, 0.25),
			plotCF * CFrame.new(x1 + side * 6.5, 49, -7),
			Color3.fromRGB(190, 160, 110),
			model
		)
		rope.Material = Enum.Material.Fabric
		rope.CanCollide = false
		local bucket = newPart(
			"Balde",
			Vector3.new(2.6, 3.2, 3.2),
			plotCF * CFrame.new(x1 + side * 6.5, 35, -7) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(120, 84, 50),
			model
		)
		bucket.Shape = Enum.PartType.Cylinder
		bucket.CanCollide = false
		local honey = newPart(
			"Mel",
			Vector3.new(0.4, 2.8, 2.8),
			plotCF * CFrame.new(x1 + side * 6.5, 36.5, -7) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(255, 176, 40),
			model
		)
		honey.Shape = Enum.PartType.Cylinder
		honey.Material = Enum.Material.Neon
		honey.CanCollide = false
	end
	model.Parent = parent
end

-- Trilhas de terra: da praça central até cada colmeia e para os lugares
-- importantes (campo, Colmeia Real, lago, caverna). Dá leitura de "rota".
local function dirtPath(from: Vector3, to: Vector3, width: number)
	local terrain = workspace.Terrain
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local length = flat.Magnitude
	if length < 1 then
		return
	end
	local steps = math.ceil(length / 24)
	for i = 0, steps - 1 do
		local t0, t1 = i / steps, (i + 1) / steps
		-- Leve zigue-zague para não parecer régua.
		local wobble = math.sin(i * 1.7) * 3
		local a = from:Lerp(to, t0)
		local b = from:Lerp(to, t1)
		local mid = (a + b) / 2
		local cf = CFrame.lookAt(Vector3.new(mid.X, -0.6, mid.Z), Vector3.new(b.X, -0.6, b.Z))
			* CFrame.new(wobble, 0, 0)
		terrain:FillBlock(cf, Vector3.new(width, 1.4, length / steps + 4), Enum.Material.Ground)
	end
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
	decorateTrunk(folder, plotCF, trunkCenter, 33)

	-- Casca plana onde as células encostam (atrás do arco).
	local bark = newPart(
		"Casca",
		Vector3.new(64, 70, 4),
		plotCF * CFrame.new(0, 35, 5),
		Color3.fromRGB(96, 64, 38),
		folder
	)
	bark.Material = Enum.Material.WoodPlanks
	-- Fundo da parede de favos: cor de mel escuro, para as células "saltarem".
	-- Formato do arco: disco em cima + retângulo embaixo.
	local honeyBack = newPart(
		"FundoFavos",
		Vector3.new(0.6, 56, 56),
		plotCF * CFrame.new(0, 34, 2.9) * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(120, 70, 20),
		folder
	)
	honeyBack.Shape = Enum.PartType.Cylinder
	honeyBack.CanCollide = false
	local honeyBottom = newPart(
		"FundoFavosBase",
		Vector3.new(56, 30, 0.6),
		plotCF * CFrame.new(0, 19, 2.9),
		Color3.fromRGB(120, 70, 20),
		folder
	)
	honeyBottom.CanCollide = false

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

	local wallOrigin = plotCF * CFrame.new(0, 34, 1.5)
	decorateHiveTree(folder, plotCF, trunkCenter, wallOrigin)
	scaffolding(folder, plotCF)

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
	sign.StudsOffset = Vector3.new(0, 42, 0)
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

	-- Trilhas (antes das colmeias, que ficam por cima).
	for i = 1, Config.Map.PlotCount do
		local angle = (i / Config.Map.PlotCount) * math.pi * 2
		local plot = Vector3.new(math.cos(angle), 0, math.sin(angle)) * (Config.Map.PlotRingRadius - 20)
		dirtPath(Vector3.zero, plot, 9)
	end
	dirtPath(Vector3.new(0, 0, -40), Config.Map.RoyalHive.Position + Vector3.new(0, 0, 130), 12)
	dirtPath(Vector3.new(40, 0, -20), Config.Places.Lake.Position - Vector3.new(80, 0, -40), 9)
	dirtPath(Vector3.new(-30, 0, 30), Config.Places.Cave.Position + Vector3.new(50, 0, -40), 9)

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
	for _, nectar in buildSkyIsland(flowersFolder, rng) do
		table.insert(flowers, nectar)
	end
	local caveSpots = buildCave(forestFolder)
	local lakeSpots = buildLake(forestFolder)
	buildLandscape(folder, rng)

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
	-- Caverna de Cristal: 2 raros e o resto médios (marcados para a conquista).
	for i, spot in caveSpots do
		local comb = buildComb(combsFolder, spot, if i <= 2 then "Raro" else "Medio")
		comb:SetAttribute("Caverna", true)
		table.insert(combs, comb)
	end
	-- Lago: favos médios em cima das vitórias-régias.
	for _, spot in lakeSpots do
		table.insert(combs, buildComb(combsFolder, spot, "Medio"))
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
		MantisSpots = mushroomTops,
		LakeCenter = Config.Places.Lake.Position,
		RoyalPosition = Config.Map.RoyalHive.Position + Vector3.new(0, Config.Map.RoyalHive.PlateauHeight, 0),
		DefaultSpawn = CFrame.new(0, 15, 0),
	}
end

return MapBuilder
