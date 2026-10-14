--[[
	HiveService (servidor) — Etapa A

	Cada jogador recebe um lote com uma colmeia própria.

	Fluxo:
	1. Entregar carga no pote dourado da colmeia:
	   - néctar vira mel (Config.NectarToHoneyRate);
	   - favos viram pontos de favo (contribuição por raridade: 1, 3, 8).
	2. Iniciar uma célula na próxima posição da parede (custa mel).
	3. A célula em construção consome pontos de favo até 100%.

	Segurança:
	- Só o dono entrega ou constrói na própria colmeia.
	- Distância conferida no servidor.
	- Uma célula em construção por vez.
	- Células concluídas nunca são removidas.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Log = require(Shared.Util.Log)
local Types = require(Shared.Types)

local Hex = require(script.Parent.Parent.World.Hex)
local Levels = require(Shared.Levels)
local ClanService = require(script.Parent.ClanService)
local Notifier = require(script.Parent.Parent.Lib.Notifier)
local InventoryService = require(script.Parent.InventoryService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ProgressionService = require(script.Parent.ProgressionService)
local QuestService = require(script.Parent.QuestService)
local WorldService = require(script.Parent.WorldService)

local HiveService = {}

type PlotState = {
	Data: any, -- MapBuilder.Plot
	Owner: Player?,
}

local plots: { PlotState } = {}
local plotOfPlayer: { [Player]: number } = {}
local slotLayout = Hex.SpiralSlots(Config.Hive.Rings)

local COLORS = {
	Frame = Color3.fromRGB(196, 132, 52), -- moldura de cera/madeira dourada
	Honey = Color3.fromRGB(235, 145, 30), -- fundo da célula pronta (brilha)
	Wax = Color3.fromRGB(252, 246, 228), -- blocos de cera dentro da célula
	Glass = Color3.fromRGB(215, 235, 255), -- célula em construção (vidro)
	Ghost = Color3.fromRGB(255, 245, 220),
	Empty = Color3.fromRGB(150, 96, 42), -- moldura de posição ainda vazia
}

local notify = Notifier.Notify

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function isNear(player: Player, target: Vector3, maxDistance: number): boolean
	local root = rootOf(player)
	return root ~= nil and (root.Position - target).Magnitude <= maxDistance
end

local function slotCFrame(plot: PlotState, slot: number): CFrame
	local axial = slotLayout[slot]
	local offset = Hex.AxialToOffset(axial[1], axial[2], Config.Hive.CellSide, 1.06)
	return plot.Data.WallOrigin * CFrame.new(offset.X, offset.Y, 0)
end

-- Consulta ----------------------------------------------------------------

function HiveService.GetPlotIndex(player: Player): number?
	return plotOfPlayer[player]
end

function HiveService.GetBuilding(profile: Types.Profile): Types.Cell?
	for _, cell in profile.Cells do
		if not cell.Completed then
			return cell
		end
	end
	return nil
end

function HiveService.CountCompleted(profile: Types.Profile): number
	local count = 0
	for _, cell in profile.Cells do
		if cell.Completed then
			count += 1
		end
	end
	return count
end

function HiveService.GetSpawnCFrame(player: Player): CFrame
	local index = plotOfPlayer[player]
	if index then
		return plots[index].Data.SpawnCFrame
	end
	return WorldService.GetMap().DefaultSpawn
end

function HiveService.GetHivePosition(player: Player): Vector3?
	local index = plotOfPlayer[player]
	return if index then plots[index].Data.WallOrigin.Position else nil
end

function HiveService.GetDeliveryPosition(player: Player): Vector3?
	local index = plotOfPlayer[player]
	return if index then plots[index].Data.Delivery.Position else nil
end

-- Visual --------------------------------------------------------------------

local function addProgressLabel(adornee: BasePart, parent: Instance, progress: number)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Progresso"
	gui.Size = UDim2.fromOffset(170, 50)
	gui.StudsOffset = Vector3.new(0, Config.Hive.CellSide * 1.6, 0)
	gui.MaxDistance = 140
	gui.LightInfluence = 0
	gui.AlwaysOnTop = true
	gui.Adornee = adornee

	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(28, 22, 16)
	bg.BackgroundTransparency = 0.15
	bg.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = bg
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(176, 120, 24)
	stroke.Transparency = 0.2
	stroke.Parent = bg

	local label = Instance.new("TextLabel")
	label.Position = UDim2.fromOffset(12, 4)
	label.Size = UDim2.new(1, -24, 0, 24)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.fromRGB(250, 244, 230)
	label.Text = `Construção {math.floor(progress)}%`
	label.Parent = bg

	local back = Instance.new("Frame")
	back.Position = UDim2.fromOffset(12, 32)
	back.Size = UDim2.new(1, -24, 0, 10)
	back.BackgroundColor3 = Color3.fromRGB(60, 48, 36)
	back.BorderSizePixel = 0
	back.Parent = bg
	local backCorner = Instance.new("UICorner")
	backCorner.CornerRadius = UDim.new(1, 0)
	backCorner.Parent = back
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(math.clamp(progress / 100, 0, 1), 1)
	fill.BackgroundColor3 = Color3.fromRGB(255, 196, 64)
	fill.BorderSizePixel = 0
	fill.Parent = back
	local fillCorner = backCorner:Clone()
	fillCorner.Parent = fill

	gui.Parent = parent
end

-- Uma célula da parede: moldura dourada + fundo + conteúdo, conforme o estado.
-- kind: "Pronta" | "Construindo" | "Fantasma" | "Vazia"
local function buildCell(cf: CFrame, slot: number, kind: string, progress: number): Model
	local side = Config.Hive.CellSide
	local model = Instance.new("Model")
	model.Name = if kind == "Fantasma" then "ProximaCelula" else `Celula_{slot}`

	if kind == "Pronta" then
		Hex.Frame(cf, side, 3.4, { Color = COLORS.Frame, Thickness = 0.75 }, model)
		local back = Hex.Prism(cf * CFrame.new(0, 0, 1.2), side * 0.92, 0.6, {
			Color = COLORS.Honey,
			Material = Enum.Material.Neon,
			Name = "Fundo",
		})
		back.Parent = model
		model.PrimaryPart = back.PrimaryPart
		-- Blocos de cera no "chão" da célula (varia por posição, sem sorteio).
		local blocks = 1 + slot % 3
		for i = 1, blocks do
			local x = (i - (blocks + 1) / 2) * 1.25
			local stack = if i == 2 then 1 else 0
			for level = 0, stack do
				local wax = Instance.new("Part")
				wax.Name = "Cera"
				wax.Anchored = true
				wax.CanCollide = false
				wax.Size = Vector3.new(1.1, 1, 1.1)
				wax.CFrame = cf * CFrame.new(x, -side * 0.69 + 0.5 + level * 1, 0.2)
				wax.Color = COLORS.Wax
				wax.Material = Enum.Material.SmoothPlastic
				wax.Parent = model
			end
		end
		-- Mel escorrendo de algumas células.
		if slot % 4 == 2 then
			local drip = Instance.new("Attachment")
			drip.Name = "Gota"
			drip.Position = (back.PrimaryPart :: BasePart).CFrame:PointToObjectSpace(
				(cf * CFrame.new(0, -side * 0.8, -0.6)).Position
			)
			drip.Parent = back.PrimaryPart
			local emitter = Instance.new("ParticleEmitter")
			emitter.Color = ColorSequence.new(Color3.fromRGB(255, 170, 40))
			emitter.LightEmission = 0.4
			emitter.Rate = 0.7
			emitter.Lifetime = NumberRange.new(1, 1.4)
			emitter.Speed = NumberRange.new(0)
			emitter.Acceleration = Vector3.new(0, -14, 0)
			emitter.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.1),
				NumberSequenceKeypoint.new(0.2, 0.28),
				NumberSequenceKeypoint.new(1, 0.2),
			})
			emitter.Parent = drip
		end
		-- Luz quente em parte das células (todas pesaria no celular).
		if slot % 3 == 1 then
			local glow = Instance.new("PointLight")
			glow.Color = Color3.fromRGB(255, 180, 80)
			glow.Range = 12
			glow.Brightness = 0.8
			glow.Parent = back.PrimaryPart
		end
	elseif kind == "Construindo" then
		Hex.Frame(cf, side, 3.4, {
			Color = COLORS.Glass,
			Material = Enum.Material.Glass,
			Transparency = 0.25,
			Thickness = 0.6,
		}, model)
		-- O fundo vai ficando cor de mel conforme a construção avança.
		local back = Hex.Prism(cf * CFrame.new(0, 0, 1.2), side * 0.92, 0.6, {
			Color = COLORS.Glass:Lerp(COLORS.Honey, progress / 100),
			Material = Enum.Material.Glass,
			Transparency = 0.75 - 0.5 * progress / 100,
			Name = "Fundo",
		})
		back.Parent = model
		model.PrimaryPart = back.PrimaryPart
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(200, 230, 255)
		glow.Range = 10
		glow.Brightness = 1
		glow.Parent = back.PrimaryPart
		addProgressLabel(back.PrimaryPart :: BasePart, model, progress)
	elseif kind == "Vazia" then
		-- Só a moldura, recuada: a parede já parece uma colmeia desde o começo.
		model.Name = `Vazia_{slot}`
		Hex.Frame(cf * CFrame.new(0, 0, 0.9), side, 1.4, { Color = COLORS.Empty, Thickness = 0.55 }, model)
	else
		Hex.Frame(cf, side, 2, {
			Color = COLORS.Ghost,
			Transparency = 0.55,
			Thickness = 0.45,
		}, model)
		local back = Hex.Prism(cf * CFrame.new(0, 0, 1.2), side * 0.92, 0.4, {
			Color = COLORS.Ghost,
			Transparency = 0.85,
			CanCollide = false,
			Name = "Fundo",
		})
		back.Parent = model
		model.PrimaryPart = back.PrimaryPart
	end
	return model
end

-- Nível de evolução da colmeia (0 a #Config.HiveTiers) pelo número de células.
function HiveService.Tier(completed: number): number
	local tier = 0
	for i, info in Config.HiveTiers do
		if completed >= info.Cells then
			tier = i
		end
	end
	return tier
end

local function evoPart(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Enfeites que aparecem conforme a colmeia cresce (Config.HiveTiers).
local function renderEvolution(plot: PlotState, tier: number)
	local plotFolder = plot.Data.Folder :: Folder
	local old = plotFolder:FindFirstChild("Evolucao")
	if old then
		old:Destroy()
	end
	if tier <= 0 then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Evolucao"
	local plotCF: CFrame = plot.Data.CFrame
	local wall: CFrame = plot.Data.WallOrigin
	local gold = Color3.fromRGB(245, 190, 60)
	-- 1: dois potes de mel gigantes na plataforma.
	for side = -1, 1, 2 do
		local base = plotCF * CFrame.new(side * 15, 2, -14)
		local jar = evoPart(
			folder,
			"PoteGigante",
			Vector3.new(7, 6, 6),
			base * CFrame.new(0, 3.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(255, 170, 40),
			Enum.Material.Glass
		)
		jar.Shape = Enum.PartType.Cylinder
		jar.Transparency = 0.15
		local lid = evoPart(
			folder,
			"Tampa",
			Vector3.new(1, 6.6, 6.6),
			base * CFrame.new(0, 7.3, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(150, 100, 55),
			Enum.Material.Wood
		)
		lid.Shape = Enum.PartType.Cylinder
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 180, 70)
		glow.Range = 16
		glow.Parent = jar
	end
	-- 2: coroa dourada no alto do arco.
	if tier >= 2 then
		local crownCF = wall * CFrame.new(0, 34, -3)
		local ring = evoPart(
			folder,
			"Coroa",
			Vector3.new(2.4, 9, 9),
			crownCF * CFrame.Angles(0, 0, math.rad(90)),
			gold,
			Enum.Material.Neon
		)
		ring.Shape = Enum.PartType.Cylinder
		for i = 0, 4 do
			local angle = i * math.pi * 2 / 5
			evoPart(
				folder,
				"Ponta",
				Vector3.new(1.2, 3.6, 1.2),
				crownCF * CFrame.new(math.cos(angle) * 3.8, 2.6, math.sin(angle) * 3.8),
				gold,
				Enum.Material.Neon
			)
			local gem = evoPart(
				folder,
				"Joia",
				Vector3.one * 1.3,
				crownCF * CFrame.new(math.cos(angle) * 3.8, 4.6, math.sin(angle) * 3.8),
				if i % 2 == 0 then Color3.fromRGB(230, 40, 80) else Color3.fromRGB(80, 160, 255),
				Enum.Material.Neon
			)
			gem.Shape = Enum.PartType.Ball
		end
	end
	-- 3: aura de brilhos dourados em volta da parede.
	if tier >= 3 then
		local holder = evoPart(folder, "Aura", Vector3.new(56, 56, 2), wall * CFrame.new(0, 0, -3), gold)
		holder.Transparency = 1
		local aura = Instance.new("ParticleEmitter")
		aura.Color = ColorSequence.new(Color3.fromRGB(255, 215, 90))
		aura.LightEmission = 1
		aura.Rate = 20
		aura.Lifetime = NumberRange.new(2, 3)
		aura.Speed = NumberRange.new(1, 3)
		aura.SpreadAngle = Vector2.new(180, 180)
		aura.Acceleration = Vector3.new(0, 2, 0)
		aura.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.3, 0.5),
			NumberSequenceKeypoint.new(1, 0),
		})
		aura.Parent = holder
	end
	-- 4: colmeia lendária: faixa dourada e feixe de luz para o céu.
	if tier >= 4 then
		local beam = evoPart(
			folder,
			"FeixeLendario",
			Vector3.new(400, 6, 6),
			wall * CFrame.new(0, 236, 8) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(255, 220, 120),
			Enum.Material.Neon
		)
		beam.Shape = Enum.PartType.Cylinder
		beam.Transparency = 0.6
		beam.CastShadow = false
		local sign = Instance.new("BillboardGui")
		sign.Size = UDim2.fromScale(30, 4)
		sign.StudsOffset = Vector3.new(0, 48, 0)
		sign.MaxDistance = 600
		sign.LightInfluence = 0
		sign.Adornee = plot.Data.Delivery
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.GothamBlack
		text.TextScaled = true
		text.TextColor3 = gold
		text.TextStrokeTransparency = 0.2
		text.Text = "✨ COLMEIA LENDÁRIA ✨"
		text.Parent = sign
		sign.Parent = folder
	end
	folder.Parent = plotFolder
end

local function renderPlot(index: number)
	local plot = plots[index]
	local folder: Folder = plot.Data.CellsFolder
	folder:ClearAllChildren()

	local owner = plot.Owner
	-- O cliente desenha as operárias contratadas lendo este atributo.
	plot.Data.Folder:SetAttribute("Contratadas", if owner then PlayerDataService.Get(owner).Workers else 0)
	renderEvolution(
		plot,
		if owner then HiveService.Tier(HiveService.CountCompleted(PlayerDataService.Get(owner))) else 0
	)
	if not owner then
		for slot = 1, Config.Hive.MaxCells do
			buildCell(slotCFrame(plot, slot), slot, "Vazia", 0).Parent = folder
		end
		plot.Data.SignLabel.Text = "Colmeia livre"
		return
	end

	local profile = PlayerDataService.Get(owner)

	for _, cell in profile.Cells do
		local kind = if cell.Completed then "Pronta" else "Construindo"
		buildCell(slotCFrame(plot, cell.Slot), cell.Slot, kind, cell.Progress).Parent = folder
	end

	-- Próxima posição livre: mostra um "fantasma" com o custo e o prompt.
	local nextSlot = #profile.Cells + 1
	if not HiveService.GetBuilding(profile) and nextSlot <= Config.Hive.MaxCells then
		local ghost = buildCell(slotCFrame(plot, nextSlot), nextSlot, "Fantasma", 0)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Construir célula"
		prompt.ObjectText =
			`Custo: {Config.Hive.CellHoneyCost} mel • {Config.Hive.CellCombCost} pts de favo`
		prompt.HoldDuration = 0.5
		prompt.MaxActivationDistance = 16
		prompt.RequiresLineOfSight = false
		prompt.Parent = ghost.PrimaryPart
		prompt.Triggered:Connect(function(player)
			HiveService.TryBuild(player, index)
		end)
		ghost.Parent = folder
	end

	-- Molduras vazias no resto da parede.
	local firstEmpty = #profile.Cells + (if HiveService.GetBuilding(profile) then 1 else 2)
	for slot = firstEmpty, Config.Hive.MaxCells do
		buildCell(slotCFrame(plot, slot), slot, "Vazia", 0).Parent = folder
	end

	plot.Data.SignLabel.Text =
		`Colmeia de {owner.DisplayName} • {HiveService.CountCompleted(profile)}/{Config.Hive.MaxCells}`
end

-- Regras --------------------------------------------------------------------

-- Usa pontos de favo do perfil na célula em construção.
local function feedBuilding(player: Player, profile: Types.Profile)
	local cell = HiveService.GetBuilding(profile)
	if not cell or profile.CombPoints <= 0 then
		return
	end
	local perPoint = 100 / Config.Hive.CellCombCost
	local needed = math.ceil((100 - cell.Progress) / perPoint - 1e-6)
	local used = math.min(profile.CombPoints, needed)
	profile.CombPoints -= used
	cell.Progress = math.min(100, cell.Progress + used * perPoint)
	if cell.Progress >= 100 then
		cell.Progress = 100
		cell.Completed = true
		notify(player, "Célula concluída! Sua colmeia cresceu.", "ok")
		ProgressionService.AddXP(player, Config.Progression.XP.CellCompleted)
		QuestService.Add(player, "Celula", 1)
	end
end

function HiveService.TryDeliver(player: Player, index: number, maxDistance: number?)
	local plot = plots[index]
	if plot.Owner ~= player then
		notify(player, "Essa colmeia não é sua.", "erro")
		return
	end
	if not isNear(player, plot.Data.Delivery.Position, maxDistance or 22) then
		notify(player, "Chegue mais perto do pote de mel da sua colmeia para entregar.", "erro")
		return
	end
	if InventoryService.IsEmpty(player) then
		notify(player, "Você não está carregando nada.", "info")
		return
	end

	local cargo = InventoryService.Take(player)
	local profile = PlayerDataService.Get(player)

	local base = cargo.Nectar * Config.NectarToHoneyRate
	local honey = math.floor(base * HiveService.HoneyMultiplier(profile) + 0.5)
	local clanBonus = 0
	if base > 0 and ClanService.HasOnlineMate(player) then
		clanBonus = math.floor(base * Config.Clan.HoneyBonus + 0.5)
		honey += clanBonus
	end
	local friendBonus = 0
	if base > 0 and ClanService.HasFriendOnline(player) then
		friendBonus = math.floor(base * Config.FriendBonus + 0.5)
		honey += friendBonus
	end
	local points = 0
	for rarity, amount in cargo.Combs do
		points += amount * Config.Rarities[rarity].BuildContribution
	end
	-- Noite: risco maior, recompensa maior. Favo raro entregue à noite vale mel extra.
	local rare = cargo.Combs.Raro or 0
	local nightBonus = 0
	if rare > 0 and workspace:GetAttribute("IsNight") == true then
		nightBonus = rare * Config.DayNight.NightRareHoneyBonus
		honey += nightBonus
	end

	profile.Honey += honey
	profile.HoneyEarned += honey
	profile.CombPoints += points
	feedBuilding(player, profile)

	notify(
		player,
		`Entregue: +{honey} mel, +{points} pts de favo`
			.. (if clanBonus > 0 then ` (colônia +{clanBonus})` else "")
			.. (if friendBonus > 0 then ` (amigos +{friendBonus})` else ""),
		"ok"
	)
	if nightBonus > 0 then
		notify(player, `🌙 Favo raro entregue à noite: +{nightBonus} mel extra!`, "ok")
	end
	ProgressionService.AddXP(player, honey * Config.Progression.XP.HoneyDelivered)
	QuestService.Add(player, "Mel", honey)
	if rare > 0 then
		QuestService.Add(player, "RaroEntregue", rare)
		if nightBonus > 0 then
			QuestService.Add(player, "RaroNoturno", rare)
		end
	end
	HiveService.CollectStored(player, true)
	local floating = if honey > 0 then `+{honey} 🍯 mel` else `+{points} pts de favo`
	Remotes.Get("Effect"):FireAllClients("entrega", plot.Data.Delivery.Position, player.UserId, floating)
	renderPlot(index)
	Notifier.Changed(player)
end

function HiveService.TryBuild(player: Player, index: number, maxDistance: number?)
	local plot = plots[index]
	if plot.Owner ~= player then
		notify(player, "Você só pode construir na sua própria colmeia.", "erro")
		return
	end
	local profile = PlayerDataService.Get(player)
	if HiveService.GetBuilding(profile) then
		notify(player, "Termine a célula em construção primeiro.", "erro")
		return
	end
	local slot = #profile.Cells + 1
	if slot > Config.Hive.MaxCells then
		notify(player, "Sua colmeia está completa!", "info")
		return
	end
	if not isNear(player, slotCFrame(plot, slot).Position, maxDistance or 24) then
		notify(player, "Chegue mais perto da parede da colmeia.", "erro")
		return
	end
	if profile.Honey < Config.Hive.CellHoneyCost then
		notify(player, `Faltam {Config.Hive.CellHoneyCost - profile.Honey} de mel.`, "erro")
		return
	end

	profile.Honey -= Config.Hive.CellHoneyCost
	table.insert(profile.Cells, { Slot = slot, Progress = 0, Completed = false })
	feedBuilding(player, profile)

	notify(player, "Nova célula iniciada! Entregue favos para concluir.", "ok")
	renderPlot(index)
	Notifier.Changed(player)
end

-- Produção passiva -------------------------------------------------------------

function HiveService.StorageCapacity(profile: Types.Profile): number
	return HiveService.CountCompleted(profile) * Config.Hive.StoragePerCell
		+ profile.Workers * Config.Workers.StorageEach
end

-- Bônus permanente de mel dos renascimentos (1 = sem bônus).
function HiveService.HoneyMultiplier(profile: Types.Profile): number
	return 1 + profile.Rebirths * Config.Rebirth.HoneyBonus
end

-- Mel por minuto que a colmeia fabrica sozinha.
function HiveService.HoneyPerMinute(profile: Types.Profile): number
	local cells = HiveService.CountCompleted(profile)
	local base = cells * Config.Hive.HoneyPerCellPerMinute + profile.Workers * Config.Workers.HoneyPerMinute
	return base * HiveService.HoneyMultiplier(profile)
end

-- Soma a produção de `seconds` segundos (puro, testável).
function HiveService.Produce(profile: Types.Profile, seconds: number)
	local produced = HiveService.HoneyPerMinute(profile) * (seconds / 60)
	profile.HiveHoney = math.min(HiveService.StorageCapacity(profile), profile.HiveHoney + produced)
end

function HiveService.WorkerCost(hired: number): number
	return math.floor(Config.Workers.BaseCost * Config.Workers.CostGrowth ^ hired + 0.5)
end

function HiveService.RebirthCost(rebirths: number): number
	return math.floor(Config.Rebirth.BaseCost * Config.Rebirth.CostGrowth ^ rebirths + 0.5)
end

-- Renascer (regra pura, testável): zera a colmeia e as melhorias, mantém
-- XP, acessórios, mascotes, conquistas e colônia; soma 1 renascimento.
function HiveService.ApplyRebirth(profile: Types.Profile)
	profile.Rebirths += 1
	profile.Honey = 0
	profile.CombPoints = 0
	profile.HiveHoney = 0
	profile.Workers = 0
	profile.Cells = {}
	for slot = 1, Config.Hive.InitialCells do
		table.insert(profile.Cells, { Slot = slot, Progress = 100, Completed = true })
	end
	for name in profile.Upgrades do
		profile.Upgrades[name] = 0
	end
	profile.Stats.Renascer = (profile.Stats.Renascer or 0) + 1
end

-- Recolhe o mel guardado na colmeia. `silent` evita aviso duplicado na entrega.
function HiveService.CollectStored(player: Player, silent: boolean?): number
	local profile = PlayerDataService.Get(player)
	local amount = math.floor(profile.HiveHoney)
	if amount <= 0 then
		if not silent then
			notify(player, "A colmeia ainda não produziu mel. Construa mais células!", "info")
		end
		return 0
	end
	profile.HiveHoney -= amount
	profile.Honey += amount
	profile.HoneyEarned += amount
	notify(player, `+{amount} mel produzido pela sua colmeia`, "ok")
	Notifier.Changed(player)
	return amount
end

-- Penalidade de derrota por predador: tira pontos de UMA célula inacabada.
-- Nunca abaixo de zero; células concluídas nunca são tocadas.
-- Retorna quantos pontos foram tirados (0 se não havia célula em construção).
function HiveService.ApplyPredatorPenalty(player: Player, points: number): number
	local profile = PlayerDataService.Get(player)
	local cell = HiveService.GetBuilding(profile)
	if not cell or cell.Progress <= 0 then
		return 0
	end
	local lost = math.min(points, cell.Progress)
	cell.Progress -= lost
	local index = plotOfPlayer[player]
	if index then
		renderPlot(index)
	end
	Notifier.Changed(player)
	return lost
end

-- Ciclo de vida ---------------------------------------------------------------

local function assign(player: Player)
	-- Espera o perfil carregar do DataStore antes de montar a colmeia.
	if not PlayerDataService.WaitForProfile(player) then
		return
	end
	for index, plot in plots do
		if plot.Owner == nil then
			plot.Owner = player
			plotOfPlayer[player] = index
			player.RespawnLocation = plot.Data.Spawn

			local profile = PlayerDataService.Get(player)
			if #profile.Cells == 0 then
				for slot = 1, Config.Hive.InitialCells do
					table.insert(profile.Cells, { Slot = slot, Progress = 100, Completed = true })
				end
			end
			renderPlot(index)
			Notifier.Changed(player)
			return
		end
	end
	Log.warn("HiveService", `sem colmeia livre para {player.Name}; ajuste o máximo de jogadores`)
end

local function release(player: Player)
	local index = plotOfPlayer[player]
	if index then
		plots[index].Owner = nil
		plotOfPlayer[player] = nil
		(player :: any).RespawnLocation = nil -- volta ao spawn padrão
		renderPlot(index)
	end
end

function HiveService:Init() end

function HiveService:Start()
	for index, data in WorldService.GetMap().Plots do
		plots[index] = { Data = data, Owner = nil }

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Entregar carga"
		prompt.ObjectText = "Pote da colmeia"
		prompt.HoldDuration = 0.4
		prompt.MaxActivationDistance = 16
		prompt.RequiresLineOfSight = false
		prompt.Parent = data.Delivery
		prompt.Triggered:Connect(function(player)
			HiveService.TryDeliver(player, index)
		end)

		renderPlot(index)
	end

	Players.PlayerAdded:Connect(assign)
	for _, player in Players:GetPlayers() do
		task.spawn(assign, player)
	end

	-- Entrega automática: chegou perto do pote com carga, entrega sozinho.
	-- (O aviso "Entregar carga" e o botão do painel continuam funcionando.)
	task.spawn(function()
		while true do
			task.wait(0.4)
			for player, index in plotOfPlayer do
				if
					player.Parent
					and PlayerDataService.IsLoaded(player)
					and not InventoryService.IsEmpty(player)
					and isNear(player, plots[index].Data.Delivery.Position, Config.AutoDeliver.Distance)
				then
					HiveService.TryDeliver(player, index, Config.AutoDeliver.Distance)
				end
			end
		end
	end)

	-- Botões do painel "Sua colmeia" (alcance maior que o dos avisos no mundo).
	Remotes.Get("RequestHiveAction").OnServerEvent:Connect(function(player, action)
		local index = plotOfPlayer[player]
		if not index then
			return
		end
		if action == "Entregar" then
			HiveService.TryDeliver(player, index, 40)
		elseif action == "Expandir" then
			HiveService.TryBuild(player, index, 70)
		elseif action == "ColetarMel" then
			if isNear(player, plots[index].Data.WallOrigin.Position, 90) then
				HiveService.CollectStored(player)
			else
				notify(player, "Volte para perto da sua colmeia para recolher o mel.", "erro")
			end
		end
	end)

	-- Contratar operária.
	Remotes.Get("RequestWorker").OnServerEvent:Connect(function(player)
		local index = plotOfPlayer[player]
		if not index or not PlayerDataService.IsLoaded(player) then
			return
		end
		local profile = PlayerDataService.Get(player)
		if profile.Workers >= Config.Workers.Max then
			notify(player, "Sua colmeia já tem o máximo de operárias.", "info")
			return
		end
		local cost = HiveService.WorkerCost(profile.Workers)
		if profile.Honey < cost then
			notify(player, `Contratar uma operária custa {cost} mel.`, "erro")
			return
		end
		profile.Honey -= cost
		profile.Workers += 1
		notify(player, `🐝 Operária contratada! Agora são {profile.Workers}.`, "ok")
		renderPlot(index)
		Notifier.Changed(player)
	end)

	-- Renascer.
	Remotes.Get("RequestRebirth").OnServerEvent:Connect(function(player)
		local index = plotOfPlayer[player]
		if not index or not PlayerDataService.IsLoaded(player) then
			return
		end
		local profile = PlayerDataService.Get(player)
		local level = Levels.FromXP(profile.XP)
		local cost = HiveService.RebirthCost(profile.Rebirths)
		if level < Config.Rebirth.MinLevel then
			notify(player, `Renascer libera no nível {Config.Rebirth.MinLevel}.`, "erro")
			return
		end
		if profile.Honey < cost then
			notify(player, `Renascer custa {cost} mel.`, "erro")
			return
		end
		HiveService.ApplyRebirth(profile)
		InventoryService.Take(player) -- a carga também some
		InventoryService.Refresh(player)
		local percent = math.floor(profile.Rebirths * Config.Rebirth.HoneyBonus * 100 + 0.5)
		notify(player, `⭐ Você renasceu! Bônus permanente: +{percent}% de mel.`, "ok")
		Remotes.Get("Effect"):FireAllClients("nivel", plots[index].Data.Delivery.Position, player.UserId)
		renderPlot(index)
		Notifier.Changed(player)
	end)

	-- Produção passiva de mel a cada 5 segundos.
	task.spawn(function()
		while true do
			task.wait(5)
			for player in plotOfPlayer do
				if PlayerDataService.IsLoaded(player) then
					local profile = PlayerDataService.Get(player)
					local before = math.floor(profile.HiveHoney)
					HiveService.Produce(profile, 5)
					if math.floor(profile.HiveHoney) ~= before then
						Notifier.Changed(player)
					end
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(release)

	Log.info("HiveService", `{#plots} lotes de colmeia prontos`)
end

return HiveService
