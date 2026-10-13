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
	Completed = Color3.fromRGB(255, 176, 40),
	Building = Color3.fromRGB(255, 215, 130),
	Ghost = Color3.fromRGB(255, 245, 220),
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

-- Visual --------------------------------------------------------------------

local function addProgressLabel(cell: Model, progress: number)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Progresso"
	gui.Size = UDim2.fromOffset(160, 36)
	gui.StudsOffset = Vector3.new(0, 0, 0)
	gui.MaxDistance = 120
	gui.LightInfluence = 0
	gui.AlwaysOnTop = true
	gui.Adornee = cell.PrimaryPart

	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(28, 22, 16)
	bg.BackgroundTransparency = 0.2
	bg.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = bg

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(progress / 100, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(255, 176, 40)
	fill.BackgroundTransparency = 0.35
	fill.Parent = bg
	local fillCorner = corner:Clone()
	fillCorner.Parent = fill

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(250, 244, 230)
	label.Text = `Construção {math.floor(progress)}%`
	label.Parent = bg

	gui.Parent = cell
end

local function renderPlot(index: number)
	local plot = plots[index]
	local folder: Folder = plot.Data.CellsFolder
	folder:ClearAllChildren()

	local owner = plot.Owner
	if not owner then
		plot.Data.SignLabel.Text = "Colmeia livre"
		return
	end

	local profile = PlayerDataService.Get(owner)
	local side = Config.Hive.CellSide
	local depth = 3

	for _, cell in profile.Cells do
		local model
		if cell.Completed then
			model = Hex.Prism(slotCFrame(plot, cell.Slot), side, depth, {
				Color = COLORS.Completed,
				Material = Enum.Material.Glass,
				Transparency = 0.1,
				Name = `Celula_{cell.Slot}`,
			})
		else
			model = Hex.Prism(slotCFrame(plot, cell.Slot), side, depth * 0.6, {
				Color = COLORS.Building,
				Material = Enum.Material.SmoothPlastic,
				Transparency = 0.5,
				Name = `Celula_{cell.Slot}`,
			})
			addProgressLabel(model, cell.Progress)
		end
		model.Parent = folder
	end

	-- Próxima posição livre: mostra um "fantasma" com o custo e o prompt.
	local nextSlot = #profile.Cells + 1
	if not HiveService.GetBuilding(profile) and nextSlot <= Config.Hive.MaxCells then
		local ghost = Hex.Prism(slotCFrame(plot, nextSlot), side, depth * 0.4, {
			Color = COLORS.Ghost,
			Material = Enum.Material.SmoothPlastic,
			Transparency = 0.75,
			CanCollide = false,
			Name = "ProximaCelula",
		})
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

	local honey = cargo.Nectar * Config.NectarToHoneyRate
	local points = 0
	for rarity, amount in cargo.Combs do
		points += amount * Config.Rarities[rarity].BuildContribution
	end

	profile.Honey += honey
	profile.HoneyEarned += honey
	profile.CombPoints += points
	feedBuilding(player, profile)

	notify(player, `Entregue: +{honey} mel, +{points} pts de favo`, "ok")
	ProgressionService.AddXP(player, honey * Config.Progression.XP.HoneyDelivered)
	QuestService.Add(player, "Mel", honey)
	HiveService.CollectStored(player, true)
	Remotes.Get("Effect"):FireAllClients("entrega", plot.Data.Delivery.Position, player.UserId)
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
end

-- Soma a produção de `seconds` segundos (puro, testável).
function HiveService.Produce(profile: Types.Profile, seconds: number)
	local cells = HiveService.CountCompleted(profile)
	local produced = cells * Config.Hive.HoneyPerCellPerMinute * (seconds / 60)
	profile.HiveHoney = math.min(HiveService.StorageCapacity(profile), profile.HiveHoney + produced)
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
