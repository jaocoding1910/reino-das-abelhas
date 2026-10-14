--[[
	WorkerBeeController (cliente)

	Abelhas operárias: deixam o mapa vivo, como nas imagens de referência.
	Só visual e só no cliente (nada passa pela rede):
	- Algumas abelhas por árvore-colmeia: pairam na frente da parede de favos,
	  voam até uma flor, "coletam" um pouco e voltam.
	- Um enxame girando em volta da Colmeia Real.
	- Abelhinhas trabalhando dentro de parte das células prontas
	  (molde "AbelhaMini"; reaparecem quando a parede muda).

	O servidor publica o molde em ReplicatedStorage.ModelosProntos.AbelhaOperaria
	(abelha 3D pintada, com asas na dobradiça). As asas batem sozinhas pelo
	VisualController (tag "AsaAbelha").

	Quantidade: Config.Art.WorkerBeesPerHive e Config.Art.WorkerBeesRoyal.
	Com StreamingEnabled, flores longe ainda não existem no cliente; por isso
	a lista de flores é atualizada de tempos em tempos.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)

local ClientSettings = require(script.Parent.Parent.UI.ClientSettings)

local WorkerBeeController = {}

local UPDATE_RANGE = 450 -- longe disso a abelha "voa" sem ser desenhada
local SPEED = 22 -- studs por segundo

type Bee = {
	Root: BasePart,
	Home: Vector3, -- ponto na frente da parede de favos
	HomeForward: Vector3, -- para onde a parede olha
	Royal: boolean,
	State: string, -- "Pairando" | "Indo" | "Coletando" | "Voltando" | "Orbita"
	Timer: number,
	From: Vector3,
	To: Vector3,
	Control: Vector3,
	Duration: number,
	Elapsed: number,
	Phase: number,
	Position: Vector3,
	Look: Vector3,
	Bank: number,
	Orbit: number,
}

local bees: { Bee } = {}
local flowerTops: { Vector3 } = {}
local rng = Random.new()

local function quadratic(a: Vector3, c: Vector3, b: Vector3, t: number): Vector3
	local u = 1 - t
	return a * (u * u) + c * (2 * u * t) + b * (t * t)
end

local function refreshFlowers()
	local map = workspace:FindFirstChild("Mapa")
	local flowers = map and map:FindFirstChild("Flores")
	if not flowers then
		return
	end
	local list = {}
	for _, item in flowers:GetChildren() do
		if item:IsA("Model") then
			local ok, cf, size = pcall(function()
				return item:GetBoundingBox()
			end)
			if ok and size.Magnitude > 1 then
				table.insert(list, cf.Position + Vector3.new(0, size.Y / 2 + 2, 0))
			end
		end
	end
	if #list > 0 then
		flowerTops = list
	end
end

local function nearestFlowers(origin: Vector3, maxDistance: number): { Vector3 }
	local out = {}
	for _, top in flowerTops do
		if (top - origin).Magnitude <= maxDistance then
			table.insert(out, top)
		end
	end
	return out
end

local function startFlight(bee: Bee, target: Vector3, state: string)
	bee.State = state
	bee.From = bee.Position
	bee.To = target
	local distance = (target - bee.From).Magnitude
	local side = (target - bee.From):Cross(Vector3.yAxis)
	side = if side.Magnitude > 0.01 then side.Unit else Vector3.xAxis
	bee.Control = (bee.From + target) / 2
		+ Vector3.new(0, math.min(30, distance * 0.25) + 6, 0)
		+ side * rng:NextNumber(-distance * 0.2, distance * 0.2)
	bee.Duration = math.max(1.5, distance / (SPEED * rng:NextNumber(0.85, 1.15)))
	bee.Elapsed = 0
end

local function hoverPoint(bee: Bee): Vector3
	local right = bee.HomeForward:Cross(Vector3.yAxis)
	return bee.Home
		+ right * rng:NextNumber(-14, 14)
		+ Vector3.new(0, rng:NextNumber(-12, 14), 0)
		+ bee.HomeForward * rng:NextNumber(0, 6)
end

local function newBee(
	template: Model,
	folder: Instance,
	home: Vector3,
	forward: Vector3,
	royal: boolean
): Bee?
	local clone = template:Clone()
	local root = clone.PrimaryPart
	if not root then
		clone:Destroy()
		return nil
	end
	clone.Parent = folder
	local start = home + Vector3.new(rng:NextNumber(-10, 10), rng:NextNumber(-6, 10), rng:NextNumber(-4, 4))
	local bee: Bee = {
		Root = root,
		Home = home,
		HomeForward = forward,
		Royal = royal,
		State = if royal then "Orbita" else "Pairando",
		Timer = rng:NextNumber(0.5, 4),
		From = start,
		To = start,
		Control = start,
		Duration = 1,
		Elapsed = 0,
		Phase = rng:NextNumber(0, math.pi * 2),
		Position = start,
		Look = forward,
		Bank = 0,
		Orbit = rng:NextNumber(0, math.pi * 2),
	}
	root.CFrame = CFrame.new(start)
	return bee
end

local function step(bee: Bee, dt: number, now: number)
	local previous = bee.Position
	if bee.State == "Orbita" then
		-- Enxame da Colmeia Real: círculos largos em alturas diferentes.
		bee.Orbit += dt * 0.35
		local radius = 45 + math.sin(bee.Phase) * 20
		bee.Position = bee.Home
			+ Vector3.new(
				math.cos(bee.Orbit + bee.Phase) * radius,
				25 + math.sin(now * 0.6 + bee.Phase) * 10 + bee.Phase * 4,
				math.sin(bee.Orbit + bee.Phase) * radius
			)
	elseif bee.State == "Pairando" or bee.State == "Coletando" then
		bee.Timer -= dt
		-- Pequenos círculos em volta do ponto, como abelha de verdade.
		local wobble = Vector3.new(
			math.cos(now * 1.7 + bee.Phase) * 1.2,
			math.sin(now * 2.3 + bee.Phase) * 0.8,
			math.sin(now * 1.3 + bee.Phase) * 1.2
		)
		bee.Position = bee.To + wobble
		if bee.Timer <= 0 then
			if bee.State == "Coletando" then
				startFlight(bee, hoverPoint(bee), "Voltando")
			else
				local options = nearestFlowers(bee.Home, 320)
				if #options > 0 and rng:NextNumber() < 0.7 then
					startFlight(bee, options[rng:NextInteger(1, #options)], "Indo")
				else
					startFlight(bee, hoverPoint(bee), "Voltando")
				end
			end
		end
	else
		bee.Elapsed += dt
		local t = math.clamp(bee.Elapsed / bee.Duration, 0, 1)
		-- Começa e termina devagar.
		local eased = t * t * (3 - 2 * t)
		bee.Position = quadratic(bee.From, bee.Control, bee.To, eased)
			+ Vector3.new(0, math.sin(now * 6 + bee.Phase) * 0.25, 0)
		if t >= 1 then
			if bee.State == "Indo" then
				bee.State = "Coletando"
				bee.Timer = rng:NextNumber(2, 4)
			else
				bee.State = "Pairando"
				bee.Timer = rng:NextNumber(2, 6)
			end
		end
	end

	-- Olha para onde está indo, com inclinação nas curvas.
	local velocity = (bee.Position - previous) / math.max(dt, 1e-3)
	local flat = Vector3.new(velocity.X, 0, velocity.Z)
	if flat.Magnitude > 2 then
		local newLook = flat.Unit
		local turn = bee.Look:Cross(newLook).Y
		bee.Bank += (math.clamp(-turn * 40, -0.6, 0.6) - bee.Bank) * math.clamp(dt * 4, 0, 1)
		bee.Look = bee.Look:Lerp(newLook, math.clamp(dt * 5, 0, 1))
	elseif bee.State ~= "Orbita" then
		-- Parada: vira devagar para a flor/parede.
		local face = if bee.State == "Coletando" then (bee.To - bee.Position) else -bee.HomeForward
		face = Vector3.new(face.X, 0, face.Z)
		if face.Magnitude > 0.1 then
			bee.Look = bee.Look:Lerp(face.Unit, math.clamp(dt * 2, 0, 1))
		end
		bee.Bank *= 0.9
	end
	if bee.Look.Magnitude < 0.01 then
		bee.Look = Vector3.zAxis
	end
	local pitch = math.clamp(-velocity.Y / SPEED, -0.5, 0.5) * 0.6
	bee.Root.CFrame = CFrame.lookAt(bee.Position, bee.Position + bee.Look) * CFrame.Angles(pitch, 0, bee.Bank)
end

local function spawnAll(template: Model)
	local folder = Instance.new("Folder")
	folder.Name = "AbelhasOperarias"
	folder.Parent = workspace

	local map = workspace:WaitForChild("Mapa", 30)
	local hives = map and map:WaitForChild("Colmeias", 30)
	if hives then
		for _, hive in hives:GetChildren() do
			local wall = hive:FindFirstChild("FundoFavos") :: BasePart?
			if wall then
				-- Toda colmeia olha para o centro do mapa: essa é a "frente".
				local toCenter = Vector3.new(-wall.Position.X, 0, -wall.Position.Z)
				local forward = if toCenter.Magnitude > 0.01 then toCenter.Unit else Vector3.zAxis
				local home = wall.Position + forward * 8
				for _ = 1, Config.Art.WorkerBeesPerHive do
					local bee = newBee(template, folder, home, forward, false)
					if bee then
						table.insert(bees, bee)
					end
				end
				-- Operárias contratadas pelo dono (atributo do servidor).
				local hired: { Bee } = {}
				local function syncHired()
					local wanted = hive:GetAttribute("Contratadas")
					wanted = if typeof(wanted) == "number" then math.clamp(wanted, 0, 20) else 0
					while #hired < wanted do
						local bee = newBee(template, folder, home, forward, false)
						if not bee then
							break
						end
						table.insert(hired, bee)
						table.insert(bees, bee)
					end
					while #hired > wanted do
						local bee = table.remove(hired) :: Bee
						local index = table.find(bees, bee)
						if index then
							table.remove(bees, index)
						end
						local model = bee.Root.Parent
						if model then
							model:Destroy()
						end
					end
				end
				hive:GetAttributeChangedSignal("Contratadas"):Connect(syncHired)
				syncHired()
			end
		end
	end

	local royalHome = Config.Map.RoyalHive.Position + Vector3.new(0, Config.Map.RoyalHive.PlateauHeight, 0)
	for _ = 1, Config.Art.WorkerBeesRoyal do
		local bee = newBee(template, folder, royalHome, Vector3.zAxis, true)
		if bee then
			table.insert(bees, bee)
		end
	end
	Log.info("WorkerBeeController", `{#bees} abelhas operárias`)
end

-- Abelhas dentro das células prontas ------------------------------------------

type CellBee = { Model: Model, Root: BasePart, Base: CFrame, Phase: number }

local CELL_BEE_RANGE = 140
local MAX_CELL_BEES_PER_HIVE = 6
local cellBees: { [Instance]: { CellBee } } = {} -- pasta "Celulas" → abelhas

local function clearCellBees(cellsFolder: Instance)
	local existing = cellBees[cellsFolder]
	if existing then
		for _, bee in existing do
			bee.Model:Destroy()
		end
	end
	cellBees[cellsFolder] = {}
end

-- Coloca abelhinhas em parte das células prontas (as que têm cera).
local function populateCells(cellsFolder: Instance, mini: Model, parent: Instance)
	clearCellBees(cellsFolder)
	local list = {}
	local count = 0
	for _, cell in cellsFolder:GetChildren() do
		if count >= MAX_CELL_BEES_PER_HIVE then
			break
		end
		local slot = tonumber(string.match(cell.Name, "^Celula_(%d+)$"))
		local back = cell:FindFirstChild("Fundo")
		local primary = back and back:IsA("Model") and back.PrimaryPart
		if slot and slot % 2 == 1 and primary and cell:FindFirstChild("Cera") then
			-- O fundo olha para a frente da colmeia: a abelha fica entre o fundo
			-- e a boca da célula, virada para fora, um pouco acima da cera.
			local base = primary.CFrame * CFrame.new(0, 0.4, -1.9)
			local clone = mini:Clone()
			local root = clone.PrimaryPart
			if root then
				root.CFrame = base
				clone.Parent = parent
				table.insert(
					list,
					{ Model = clone, Root = root, Base = base, Phase = rng:NextNumber(0, 6.28) }
				)
				count += 1
			else
				clone:Destroy()
			end
		end
	end
	cellBees[cellsFolder] = list
end

local function watchCells(cellsFolder: Instance, mini: Model, parent: Instance)
	local pending = false
	local function schedule()
		if pending then
			return
		end
		pending = true
		task.delay(0.6, function()
			pending = false
			populateCells(cellsFolder, mini, parent)
		end)
	end
	cellsFolder.ChildAdded:Connect(schedule)
	cellsFolder.ChildRemoved:Connect(schedule)
	schedule()
end

local function stepCellBees(now: number, camera: Vector3)
	for _, list in cellBees do
		for _, bee in list do
			if (bee.Base.Position - camera).Magnitude < CELL_BEE_RANGE then
				-- Trabalhando: anda de lado, vira para dentro e para fora.
				local t = now * 0.9 + bee.Phase
				local shuffle = math.sin(t) * 0.6
				local turn = math.sin(t * 0.5) * 0.9
				local bob = math.sin(now * 5 + bee.Phase) * 0.08
				bee.Root.CFrame = bee.Base * CFrame.new(shuffle, bob, 0) * CFrame.Angles(0, turn, 0)
			end
		end
	end
end

function WorkerBeeController:Init() end

function WorkerBeeController:Start()
	task.spawn(function()
		local ready = ReplicatedStorage:WaitForChild("ModelosProntos", 30)
		local template = ready and ready:WaitForChild("AbelhaOperaria", 30)
		if not template or not template:IsA("Model") then
			Log.warn("WorkerBeeController", "molde da abelha operária não encontrado")
			return
		end
		task.wait(3) -- dá tempo do mapa chegar (StreamingEnabled)
		refreshFlowers()
		spawnAll(template)

		local beesFolder = workspace:FindFirstChild("AbelhasOperarias")
		local function applyQuality(settings)
			if beesFolder then
				beesFolder.Parent = if settings.Quality == "Baixa" then nil else workspace
			end
		end
		ClientSettings.Changed:Connect(applyQuality)
		applyQuality(ClientSettings.Get())

		local mini = ready:FindFirstChild("AbelhaMini")
		local hives = workspace:FindFirstChild("Mapa") and workspace.Mapa:FindFirstChild("Colmeias")
		if mini and mini:IsA("Model") and hives then
			local folder = beesFolder or workspace
			for _, hive in hives:GetChildren() do
				local cells = hive:FindFirstChild("Celulas")
				if cells then
					watchCells(cells, mini, folder)
				end
			end
		end

		task.spawn(function()
			while true do
				task.wait(8)
				refreshFlowers()
			end
		end)

		RunService.RenderStepped:Connect(function(dt)
			local now = os.clock()
			local camera = workspace.CurrentCamera.CFrame.Position
			if ClientSettings.Get().Quality == "Baixa" then
				return -- qualidade baixa: as operárias ficam paradas e escondidas
			end
			stepCellBees(now, camera)
			for _, bee in bees do
				if (bee.Position - camera).Magnitude < UPDATE_RANGE then
					step(bee, dt, now)
				else
					-- Longe: só avança o tempo (barato), sem mover as peças.
					bee.Timer -= dt
					bee.Elapsed += dt
				end
			end
		end)
	end)
	Log.info("WorkerBeeController", "pronto")
end

return WorkerBeeController
