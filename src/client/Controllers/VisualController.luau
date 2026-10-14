--[[
	VisualController (cliente)

	Tudo aqui é só visual e roda no cliente (não pesa no servidor):
	- Favos coletáveis girando e flutuando (tag "FavoFlutuante").
	- Asas de todas as abelhas batendo; a frequência acompanha a velocidade
	  de cada abelha (parada = zumbido calmo, arrancada = asas a mil).
	- Explosões de partículas dos eventos do servidor (Remotes "Effect"):
	  coleta, entrega, dano, derrota, ataque e subida de nível.
	- Bolinhas de mel que VOAM até você ao coletar e da sua carga até a colmeia
	  ao entregar.
	- Partículas de ambiente presas à câmera: pólen de dia, vaga-lumes à noite.
	- Rajadas de vento na tela durante a arrancada.
	- Flores pequenas de enfeite espalhadas pelo campo (só no cliente, com
	  semente fixa: todo mundo vê o mesmo campo, sem custo de rede).

	Só anima o que está perto da câmera, para poupar o celular.
]]

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Remotes = require(Shared.Remotes)

local ClientSettings = require(script.Parent.Parent.UI.ClientSettings)
local FlightController = require(script.Parent.FlightController)

local VisualController = {}

local player = Players.LocalPlayer

local COMB_TAG = "FavoFlutuante"
local WING_TAG = "AsaAbelha"
local COMB_RANGE = 220
local WING_RANGE = 250
local DECOR_COUNT = 520 -- flores, lavandas, tufos e cogumelinhos de enfeite (só no cliente)

type CombEntry = { Model: Model, Base: CFrame, Phase: number }
type Orb = {
	Part: BasePart,
	From: Vector3,
	Target: () -> Vector3?,
	Start: number,
	Duration: number,
	Arc: number,
}

local combs: { [Model]: CombEntry } = {}
local wings: { [Weld]: number } = {} -- weld → fase da batida (acumulada)
local orbs: { Orb } = {}
local glowCaps: { BasePart } = {} -- cogumelinhos de enfeite que brilham à noite
local lastNight: boolean? = nil

local effectsFolder = Instance.new("Folder")
effectsFolder.Name = "EfeitosLocais"

-- ---------------------------------------------------------------- utilidades

local function invisiblePart(name: string, size: Vector3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = size
	return part
end

local function rootOf(target: Player): BasePart?
	local character = target.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- ---------------------------------------------------------------- favos e asas

local function addComb(instance: Instance)
	if instance:IsA("Model") then
		combs[instance] = {
			Model = instance,
			Base = instance:GetPivot(),
			Phase = math.random() * math.pi * 2,
		}
	end
end

local function addWing(instance: Instance)
	if instance:IsA("Weld") then
		wings[instance] = math.random() * math.pi * 2
	end
end

local function track(tag: string, add: (Instance) -> (), remove: (Instance) -> ())
	for _, instance in CollectionService:GetTagged(tag) do
		add(instance)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(add)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(remove)
end

-- ---------------------------------------------------------------- explosões

local EFFECTS = {
	coleta = { Color = Color3.fromRGB(255, 215, 90), Count = 18, Size = 0.6, Speed = 8 },
	entrega = { Color = Color3.fromRGB(255, 190, 60), Count = 35, Size = 0.9, Speed = 12 },
	dano = { Color = Color3.fromRGB(255, 70, 70), Count = 14, Size = 0.7, Speed = 10 },
	derrota = { Color = Color3.fromRGB(255, 120, 80), Count = 45, Size = 1.1, Speed = 16 },
	ataque = { Color = Color3.fromRGB(255, 255, 255), Count = 8, Size = 0.5, Speed = 14 },
	nivel = { Color = Color3.fromRGB(255, 230, 120), Count = 60, Size = 1, Speed = 20 },
}

local function burst(kind: string, position: Vector3)
	local info = EFFECTS[kind]
	if not info then
		return
	end
	local holder = invisiblePart("Explosao", Vector3.one)
	holder.Position = position
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(info.Color)
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.5, 1)
	emitter.Speed = NumberRange.new(info.Speed * 0.5, info.Speed)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 4
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, info.Size),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Parent = holder
	holder.Parent = effectsFolder
	emitter:Emit(info.Count)
	Debris:AddItem(holder, 1.5)

	if kind == "nivel" then
		-- Anel dourado que se expande.
		local ring = invisiblePart("AnelNivel", Vector3.new(0.3, 2, 2))
		ring.Shape = Enum.PartType.Cylinder
		ring.Material = Enum.Material.Neon
		ring.Color = info.Color
		ring.Transparency = 0.2
		ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
		ring.Parent = effectsFolder
		local start = os.clock()
		local conn: RBXScriptConnection
		conn = RunService.RenderStepped:Connect(function()
			local t = (os.clock() - start) / 0.8
			if t >= 1 then
				conn:Disconnect()
				ring:Destroy()
				return
			end
			local size = 2 + t * 26
			ring.Size = Vector3.new(0.3, size, size)
			ring.Transparency = 0.2 + t * 0.8
		end)
	end
end

-- ---------------------------------------------------------------- bolinhas voadoras

local function spawnOrb(from: Vector3, target: () -> Vector3?, delay: number, color: Color3)
	task.delay(delay, function()
		local part = invisiblePart("Gota", Vector3.one * 0.7)
		part.Shape = Enum.PartType.Ball
		part.Material = Enum.Material.Neon
		part.Color = color
		part.Transparency = 0
		part.Position = from
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 6
		light.Brightness = 1.5
		light.Parent = part
		part.Parent = effectsFolder
		table.insert(orbs, {
			Part = part,
			From = from,
			Target = target,
			Start = os.clock(),
			Duration = 0.45 + math.random() * 0.2,
			Arc = 3 + math.random() * 4,
		})
	end)
end

-- ---------------------------------------------------------------- números flutuantes

-- "+3 🌼" subindo e sumindo em cima de onde você coletou/entregou.
local function floatText(position: Vector3, text: string, color: Color3, big: boolean)
	local holder = invisiblePart("TextoFlutuante", Vector3.one * 0.2)
	holder.Position = position + Vector3.new(0, 3, 0)
	holder.Parent = effectsFolder
	local gui = Instance.new("BillboardGui")
	gui.Size = if big then UDim2.fromOffset(300, 110) else UDim2.fromOffset(200, 76)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 250
	gui.Adornee = holder
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeColor3 = Color3.fromRGB(60, 30, 0)
	label.TextStrokeTransparency = 0
	label.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Scale = 0.2
	scale.Parent = label
	gui.Parent = holder
	TweenService
		:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	TweenService:Create(holder, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = holder.Position + Vector3.new(0, if big then 9 else 6, 0),
	}):Play()
	task.delay(0.9, function()
		TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 })
			:Play()
	end)
	Debris:AddItem(holder, 1.6)
end

local function localRootPosition(): Vector3?
	local root = rootOf(player)
	return root and root.Position
end

local function onEffect(kind: string, position: Vector3, userId: number?, text: string?)
	if typeof(position) ~= "Vector3" then
		return
	end
	if (position - workspace.CurrentCamera.CFrame.Position).Magnitude > 300 then
		return
	end
	burst(kind, position)

	if userId ~= player.UserId then
		return
	end
	if typeof(text) == "string" and text ~= "" then
		local delivery = kind == "entrega"
		floatText(
			position,
			text,
			if delivery then Color3.fromRGB(255, 190, 40) else Color3.fromRGB(255, 240, 150),
			delivery
		)
	end
	if kind == "coleta" then
		-- Do favo/flor até você.
		for i = 1, 6 do
			local jitter = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 3
			spawnOrb(position + jitter, localRootPosition, i * 0.04, Color3.fromRGB(255, 200, 60))
		end
	elseif kind == "entrega" then
		-- Da sua carga até a colmeia.
		local from = localRootPosition()
		if from then
			for i = 1, 10 do
				spawnOrb(from, function()
					return position
				end, i * 0.05, Color3.fromRGB(255, 175, 40))
			end
		end
	end
end

local function updateOrbs(now: number)
	for i = #orbs, 1, -1 do
		local orb = orbs[i]
		local target = orb.Target()
		local t = (now - orb.Start) / orb.Duration
		if not target or t >= 1 then
			orb.Part:Destroy()
			table.remove(orbs, i)
		else
			-- Curva suave com um arco para cima (ease-in: começa devagar, chega rápido).
			local e = t * t
			local pos = orb.From:Lerp(target, e) + Vector3.new(0, math.sin(t * math.pi) * orb.Arc, 0)
			orb.Part.Position = pos
			orb.Part.Size = Vector3.one * (0.7 - 0.4 * t)
		end
	end
end

-- ---------------------------------------------------------------- ambiente

local decorFolder: Folder? = nil
local ambientPart: Part
local pollen: ParticleEmitter
local fireflies: ParticleEmitter
local windPart: Part
local wind: ParticleEmitter
local goldenRain: ParticleEmitter
local rain: ParticleEmitter

local function buildAmbient()
	ambientPart = invisiblePart("Ambiente", Vector3.new(90, 30, 90))
	ambientPart.Parent = effectsFolder

	pollen = Instance.new("ParticleEmitter")
	pollen.Name = "Polen"
	pollen.Shape = Enum.ParticleEmitterShape.Box
	pollen.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	pollen.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	pollen.Color = ColorSequence.new(Color3.fromRGB(255, 240, 170))
	pollen.LightEmission = 0.6
	pollen.LightInfluence = 0.4
	pollen.Rate = 18
	pollen.Lifetime = NumberRange.new(5, 8)
	pollen.Speed = NumberRange.new(0.3, 1)
	pollen.SpreadAngle = Vector2.new(180, 180)
	pollen.Acceleration = Vector3.new(0.4, 0.15, 0.2)
	pollen.RotSpeed = NumberRange.new(-30, 30)
	pollen.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.15, 0.18),
		NumberSequenceKeypoint.new(0.85, 0.18),
		NumberSequenceKeypoint.new(1, 0),
	})
	pollen.Parent = ambientPart

	fireflies = Instance.new("ParticleEmitter")
	fireflies.Name = "VagaLumes"
	fireflies.Shape = Enum.ParticleEmitterShape.Box
	fireflies.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	fireflies.Color = ColorSequence.new(Color3.fromRGB(200, 255, 120))
	fireflies.LightEmission = 1
	fireflies.LightInfluence = 0
	fireflies.Brightness = 3
	fireflies.Rate = 0
	fireflies.Lifetime = NumberRange.new(4, 7)
	fireflies.Speed = NumberRange.new(0.5, 1.5)
	fireflies.SpreadAngle = Vector2.new(180, 180)
	fireflies.Drag = 0.5
	fireflies.Size = NumberSequence.new(0.35)
	-- Pisca: liga e desliga ao longo da vida.
	fireflies.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.1, 0),
		NumberSequenceKeypoint.new(0.3, 0.9),
		NumberSequenceKeypoint.new(0.45, 0),
		NumberSequenceKeypoint.new(0.7, 0.85),
		NumberSequenceKeypoint.new(0.85, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	fireflies.Parent = ambientPart

	-- Chuva de pólen (evento): pontinhos dourados caindo do céu.
	goldenRain = Instance.new("ParticleEmitter")
	goldenRain.Name = "ChuvaDePolen"
	goldenRain.Shape = Enum.ParticleEmitterShape.Box
	goldenRain.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	goldenRain.Color = ColorSequence.new(Color3.fromRGB(255, 215, 70))
	goldenRain.LightEmission = 1
	goldenRain.LightInfluence = 0
	goldenRain.Rate = 0
	goldenRain.Lifetime = NumberRange.new(3, 5)
	goldenRain.Speed = NumberRange.new(4, 8)
	goldenRain.EmissionDirection = Enum.NormalId.Bottom
	goldenRain.SpreadAngle = Vector2.new(15, 15)
	goldenRain.RotSpeed = NumberRange.new(-90, 90)
	goldenRain.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.1, 0.3),
		NumberSequenceKeypoint.new(0.9, 0.25),
		NumberSequenceKeypoint.new(1, 0),
	})
	goldenRain.Parent = ambientPart

	-- Chuva (clima): riscos azulados caindo rápido.
	rain = Instance.new("ParticleEmitter")
	rain.Name = "Chuva"
	rain.Shape = Enum.ParticleEmitterShape.Box
	rain.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	rain.EmissionDirection = Enum.NormalId.Bottom
	rain.Orientation = Enum.ParticleOrientation.VelocityParallel
	rain.Color = ColorSequence.new(Color3.fromRGB(190, 210, 240))
	rain.LightEmission = 0.2
	rain.Transparency = NumberSequence.new(0.45)
	rain.Size = NumberSequence.new(0.08)
	rain.Squash = NumberSequence.new(-4)
	rain.Speed = NumberRange.new(70, 90)
	rain.Lifetime = NumberRange.new(0.5, 0.7)
	rain.SpreadAngle = Vector2.new(4, 4)
	rain.Rate = 0
	rain.Parent = ambientPart

	-- Vento da arrancada: riscos que passam pela câmera.
	windPart = invisiblePart("Vento", Vector3.new(22, 14, 1))
	windPart.Parent = effectsFolder
	wind = Instance.new("ParticleEmitter")
	wind.Name = "Vento"
	wind.Shape = Enum.ParticleEmitterShape.Box
	wind.EmissionDirection = Enum.NormalId.Back
	wind.Orientation = Enum.ParticleOrientation.VelocityParallel
	wind.Color = ColorSequence.new(Color3.new(1, 1, 1))
	wind.LightEmission = 0.5
	wind.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	wind.Size = NumberSequence.new(0.06)
	wind.Squash = NumberSequence.new(-3)
	wind.Speed = NumberRange.new(70, 90)
	wind.Lifetime = NumberRange.new(0.15, 0.25)
	wind.Rate = 0
	wind.Parent = windPart
end

local function updateAmbient(dt: number)
	local camera = workspace.CurrentCamera
	ambientPart.Position = camera.CFrame.Position
	local night = workspace:GetAttribute("IsNight") == true
	local low = ClientSettings.Get().Quality == "Baixa"
	pollen.Enabled = not night and not low
	local raining = workspace:GetAttribute("Evento") == "ChuvaDePolen"
	goldenRain.Rate += ((if raining then (if low then 15 else 60) else 0) - goldenRain.Rate) * math.clamp(
		dt * 2,
		0,
		1
	)
	local weatherRain = workspace:GetAttribute("Clima") == "Chuva"
	rain.Rate += ((if weatherRain then (if low then 120 else 450) else 0) - rain.Rate) * math.clamp(dt, 0, 1)
	-- A chuva cai do alto da caixa em volta da câmera.
	ambientPart.Position = camera.CFrame.Position + Vector3.new(0, if weatherRain then 18 else 0, 0)
	if night ~= lastNight then
		lastNight = night
		for _, cap in glowCaps do
			cap.Material = if night then Enum.Material.Neon else Enum.Material.SmoothPlastic
		end
	end
	fireflies.Rate += ((if night and not low then 14 else 0) - fireflies.Rate) * math.clamp(dt, 0, 1)
	if decorFolder then
		decorFolder.Parent = if low then nil else effectsFolder
	end

	windPart.CFrame = camera.CFrame * CFrame.new(0, 0, -16)
	local state = FlightController.State
	wind.Rate = if state.Sprinting and not low then 40 + 40 * math.clamp(state.SpeedFraction - 1, 0, 1) else 0
end

-- ---------------------------------------------------------------- flores de enfeite

local DECOR_COLORS = {
	Color3.fromRGB(255, 120, 170),
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(180, 140, 255),
	Color3.fromRGB(255, 220, 80),
	Color3.fromRGB(120, 190, 255),
	Color3.fromRGB(255, 150, 90),
}

local function decorPart(
	parent: Instance,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	shape: Enum.PartType
): Part
	local part = invisiblePart("Enfeite", size)
	part.Shape = shape
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Transparency = 0
	part.Parent = parent
	return part
end

type DecorSpot = {
	X: number,
	Z: number,
	Yaw: number,
	Height: number,
	Tilt: number,
	Color: Color3,
	Mushroom: boolean,
	Kind: string, -- "Flor" | "Lavanda" | "Tufo"
	Done: boolean,
}

local decorSpots: { DecorSpot } = {}

-- Sorteia os pontos uma vez (semente fixa = mesmo campo para todos).
local function planDecor()
	local rng = Random.new(Config.Map.Seed + 77)
	for _ = 1, DECOR_COUNT do
		-- Do anel das colmeias até a borda do bosque.
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(Config.Regions.HiveRadius - 40, Config.Map.ForestRadius.Max)
		table.insert(decorSpots, {
			X = math.cos(angle) * radius,
			Z = math.sin(angle) * radius,
			Yaw = rng:NextNumber(0, math.pi * 2),
			-- Na escala da abelha (6 studs): flores do tamanho dela, como na referência.
			Height = rng:NextNumber(3, 7),
			Tilt = rng:NextNumber(-20, 20),
			Color = DECOR_COLORS[rng:NextInteger(1, #DECOR_COLORS)],
			Mushroom = radius > Config.Map.ForestRadius.Min and rng:NextNumber() < 0.6,
			Kind = (function()
				local roll = rng:NextNumber()
				return if roll < 0.3 then "Lavanda" elseif roll < 0.5 then "Tufo" else "Flor"
			end)(),
			Done = false,
		})
	end
end

local function buildSpot(spot: DecorSpot, ground: Vector3)
	local folder = decorFolder :: Folder
	local base = CFrame.new(ground) * CFrame.Angles(0, spot.Yaw, 0)
	local height = spot.Height
	if not spot.Mushroom and spot.Kind == "Tufo" then
		-- Tufo de grama alta: lâminas finas inclinadas.
		for blade = 0, 4 do
			decorPart(
				folder,
				Vector3.new(0.3, height * 0.8, 0.08),
				base
					* CFrame.Angles(0, blade * 1.3, 0)
					* CFrame.new(0, height * 0.35, 0)
					* CFrame.Angles(math.rad(12 + blade * 4), 0, 0),
				Color3.fromRGB(95 + blade * 8, 165, 70),
				Enum.PartType.Block
			)
		end
		return
	end
	if not spot.Mushroom and spot.Kind == "Lavanda" then
		-- Lavanda: haste com espiga de bolinhas roxas.
		decorPart(
			folder,
			Vector3.new(height, 0.18, 0.18),
			base * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(90, 140, 70),
			Enum.PartType.Cylinder
		)
		for k = 0, 5 do
			decorPart(
				folder,
				Vector3.one * (0.75 - k * 0.07),
				base * CFrame.new(0, height * 0.62 + k * height * 0.075, 0),
				Color3.fromRGB(150 + k * 6, 110, 230),
				Enum.PartType.Ball
			)
		end
		return
	end
	decorPart(
		folder,
		Vector3.new(height, 0.22, 0.22),
		base * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(85, 150, 60),
		Enum.PartType.Cylinder
	)
	if spot.Mushroom then
		-- Cogumelinho que brilha à noite, no bosque.
		local cap = decorPart(
			folder,
			Vector3.new(0.7, 2.6, 2.6),
			base * CFrame.new(0, height, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(150, 110, 255),
			Enum.PartType.Cylinder
		)
		if lastNight then
			cap.Material = Enum.Material.Neon
		end
		table.insert(glowCaps, cap)
	else
		local head = base * CFrame.new(0, height, 0) * CFrame.Angles(math.rad(spot.Tilt), 0, 0)
		for p = 0, 4 do
			decorPart(
				folder,
				Vector3.new(1.1, 0.14, 2),
				head
					* CFrame.Angles(0, p * math.pi * 2 / 5, 0)
					* CFrame.new(0, 0, -1)
					* CFrame.Angles(math.rad(15), 0, 0),
				spot.Color,
				Enum.PartType.Block
			)
		end
		decorPart(
			folder,
			Vector3.one * 1.05,
			head * CFrame.new(0, 0.15, 0),
			Color3.fromRGB(255, 200, 50),
			Enum.PartType.Ball
		)
	end
end

-- Com StreamingEnabled o terreno longe ainda não existe no cliente; por isso
-- as flores nascem aos poucos, só perto da câmera, quando o chão já chegou.
local function decorLoop()
	local folder = Instance.new("Folder")
	folder.Name = "FloresEnfeite"
	folder.Parent = effectsFolder
	decorFolder = folder

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	params.IgnoreWater = false

	local remaining = #decorSpots
	while remaining > 0 do
		local camera = workspace.CurrentCamera.CFrame.Position
		local budget = 40
		for _, spot in decorSpots do
			if budget <= 0 then
				break
			end
			if not spot.Done then
				local dx, dz = spot.X - camera.X, spot.Z - camera.Z
				if dx * dx + dz * dz < 300 * 300 then
					budget -= 1
					local hit =
						workspace:Raycast(Vector3.new(spot.X, 300, spot.Z), Vector3.new(0, -400, 0), params)
					if hit then
						spot.Done = true
						remaining -= 1
						if hit.Material ~= Enum.Material.Water and hit.Normal.Y > 0.85 then
							buildSpot(spot, hit.Position)
						end
					end
				end
			end
		end
		task.wait(0.5)
	end
end

-- ---------------------------------------------------------------- borboletas e arco-íris

type Butterfly = {
	Body: BasePart,
	WingL: BasePart,
	WingR: BasePart,
	Center: Vector3,
	Phase: number,
	Radius: number,
}
local butterflies: { Butterfly } = {}
local BUTTERFLY_COLORS = {
	Color3.fromRGB(255, 150, 60),
	Color3.fromRGB(120, 180, 255),
	Color3.fromRGB(255, 120, 200),
	Color3.fromRGB(255, 230, 90),
	Color3.fromRGB(170, 120, 255),
}

local function buildButterflies()
	local folder = Instance.new("Folder")
	folder.Name = "Borboletas"
	folder.Parent = effectsFolder
	local rng = Random.new(Config.Map.Seed + 5)
	for i = 1, 18 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(Config.Regions.HiveRadius, Config.Map.FieldRadius.Max)
		local center = Vector3.new(math.cos(angle) * radius, rng:NextNumber(8, 30), math.sin(angle) * radius)
		local color = BUTTERFLY_COLORS[(i % #BUTTERFLY_COLORS) + 1]
		local body = invisiblePart("Corpo", Vector3.new(0.25, 0.25, 1.2))
		body.Transparency = 0
		body.Color = Color3.fromRGB(40, 30, 30)
		body.Parent = folder
		local function wing(name: string): Part
			local w = invisiblePart(name, Vector3.new(1.4, 0.06, 1.3))
			w.Transparency = 0
			w.Color = color
			w.Material = Enum.Material.SmoothPlastic
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = w
			w.Parent = folder
			return w
		end
		table.insert(butterflies, {
			Body = body,
			WingL = wing("AsaE"),
			WingR = wing("AsaD"),
			Center = center,
			Phase = rng:NextNumber(0, 100),
			Radius = rng:NextNumber(6, 16),
		})
	end
end

local function updateButterflies(now: number, cameraPosition: Vector3, low: boolean)
	for _, b in butterflies do
		local visible = not low and (b.Center - cameraPosition).Magnitude < 260
		if not visible then
			if b.Body.Transparency < 1 then
				b.Body.Transparency, b.WingL.Transparency, b.WingR.Transparency = 1, 1, 1
			end
		else
			if b.Body.Transparency > 0 then
				b.Body.Transparency, b.WingL.Transparency, b.WingR.Transparency = 0, 0, 0
			end
			local t = now * 0.45 + b.Phase
			local position = b.Center
				+ Vector3.new(math.cos(t) * b.Radius, math.sin(t * 2.3) * 2, math.sin(t * 0.8) * b.Radius)
			local ahead = b.Center
				+ Vector3.new(
					math.cos(t + 0.1) * b.Radius,
					math.sin((t + 0.1) * 2.3) * 2,
					math.sin((t + 0.1) * 0.8) * b.Radius
				)
			local cf = CFrame.lookAt(position, ahead)
			local flap = math.sin(now * 14 + b.Phase) * 1.1
			b.Body.CFrame = cf
			b.WingL.CFrame = cf * CFrame.Angles(0, 0, flap) * CFrame.new(-0.7, 0, 0)
			b.WingR.CFrame = cf * CFrame.Angles(0, 0, -flap) * CFrame.new(0.7, 0, 0)
		end
	end
end

-- Flor arco-íris: as cores giram enquanto ela existir.
local rainbowParts: { [BasePart]: boolean } = {}

local function updateRainbow(now: number)
	for part in rainbowParts do
		part.Color = Color3.fromHSV((now * 0.35) % 1, 0.75, 1)
	end
end

-- ---------------------------------------------------------------- néctar e destaque

-- Gotas de néctar brilhando nas flores DISPONÍVEIS mais perto (como na
-- referência). Conjunto fixo de peças reaproveitadas: nada é criado por flor.
local DROPS_FLOWERS = 10
local DROPS_PER_FLOWER = 3
local DROP_RANGE = 140
local dropParts: { BasePart } = {}
local dropFrames: { CFrame } = {}
local dropTargets: { BasePart } = {}
local nectarPrompts: { ProximityPrompt } = {}
local resourcePrompts: { ProximityPrompt } = {}
local highlight: Highlight

local function buildDrops()
	for i = 1, DROPS_FLOWERS * DROPS_PER_FLOWER do
		local drop = invisiblePart("GotaNectar", Vector3.one * (0.55 + (i % 3) * 0.18))
		drop.Shape = Enum.PartType.Ball
		drop.Material = Enum.Material.Glass
		drop.Color = Color3.fromRGB(255, 200, 50)
		drop.Transparency = 1
		drop.Parent = effectsFolder
		dropParts[i] = drop
		dropFrames[i] = CFrame.new(0, -1000, 0)
	end
	highlight = Instance.new("Highlight")
	highlight.Name = "DestaqueRecurso"
	highlight.FillTransparency = 1
	highlight.OutlineColor = Color3.fromRGB(255, 220, 110)
	highlight.OutlineTransparency = 0.15
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Enabled = false
	highlight.Parent = effectsFolder
end

local function scanResources()
	local map = workspace:FindFirstChild("Mapa")
	if not map then
		return
	end
	local nectar, all = {}, {}
	for _, folderName in { "Flores", "Favos" } do
		local holder = map:FindFirstChild(folderName)
		if holder then
			for _, item in holder:GetDescendants() do
				if item:IsA("ProximityPrompt") then
					table.insert(all, item)
					if folderName == "Flores" then
						table.insert(nectar, item)
					end
				end
			end
		end
	end
	nectarPrompts, resourcePrompts = nectar, all
end

-- Escolhe as flores (4× por segundo) e o recurso mais perto para destacar.
local function pickTargets(cameraPosition: Vector3, low: boolean)
	table.clear(dropTargets)
	if not low then
		local candidates = {}
		for _, prompt in nectarPrompts do
			local holder = prompt.Parent
			if prompt.Enabled and holder and holder:IsA("BasePart") then
				local distance = (holder.Position - cameraPosition).Magnitude
				if distance < DROP_RANGE then
					table.insert(candidates, { Part = holder, Distance = distance })
				end
			end
		end
		table.sort(candidates, function(a, b)
			return a.Distance < b.Distance
		end)
		for i = 1, math.min(DROPS_FLOWERS, #candidates) do
			dropTargets[i] = candidates[i].Part
		end
	end
	-- Destaque dourado no recurso disponível mais perto (até 30 studs).
	local best, bestDistance = nil, 30
	for _, prompt in resourcePrompts do
		local holder = prompt.Parent
		if prompt.Enabled and holder and holder:IsA("BasePart") then
			local distance = (holder.Position - cameraPosition).Magnitude
			if distance < bestDistance then
				best, bestDistance = holder, distance
			end
		end
	end
	local adornee: Instance? = best
	if best and best.Parent and best.Parent:IsA("Model") and best.Parent.Name ~= "Flores" then
		adornee = best.Parent -- favo inteiro
	end
	highlight.Adornee = adornee
	highlight.Enabled = adornee ~= nil
end

local function updateDrops(now: number)
	for i, drop in dropParts do
		local flower = dropTargets[(i - 1) // DROPS_PER_FLOWER + 1]
		if flower and flower.Parent then
			local k = (i - 1) % DROPS_PER_FLOWER
			local radius = math.max(flower.Size.X, flower.Size.Z) * 0.22
			local angle = k * 2.1 + now * 0.4
			local lift = math.min(flower.Size.X, flower.Size.Y, flower.Size.Z) * 0.5 + 0.5
			local bob = math.sin(now * 2.4 + i) * 0.25
			dropFrames[i] = CFrame.new(
				flower.Position + Vector3.new(math.cos(angle) * radius, lift + bob, math.sin(angle) * radius)
			)
			drop.Transparency = 0.15
		else
			dropFrames[i] = CFrame.new(0, -1000, 0)
			drop.Transparency = 1
		end
	end
	workspace:BulkMoveTo(dropParts, dropFrames, Enum.BulkMoveMode.FireCFrameChanged)
end

-- ---------------------------------------------------------------- ciclo

function VisualController:Init()
	effectsFolder.Parent = workspace.CurrentCamera
	track(COMB_TAG, addComb, function(instance)
		combs[instance :: Model] = nil
	end)
	track(WING_TAG, addWing, function(instance)
		wings[instance :: Weld] = nil
	end)
	buildAmbient()
	buildButterflies()
	buildDrops()
	local function addRainbow(instance: Instance)
		if instance:IsA("BasePart") then
			rainbowParts[instance] = true
		end
	end
	track("FlorArcoIris", addRainbow, function(instance)
		rainbowParts[instance :: BasePart] = nil
		-- Volta a cor normal (o servidor também ajusta ao coletar).
		local original = instance:GetAttribute("NectarColor")
		if typeof(original) == "Color3" and instance:IsA("BasePart") then
			instance.Color = original
		end
	end)
end

function VisualController:Start()
	Remotes.Get("Effect").OnClientEvent:Connect(onEffect)

	planDecor()
	task.spawn(decorLoop)
	task.spawn(function()
		while true do
			scanResources()
			task.wait(3)
		end
	end)
	local pickAccumulator = 1

	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		local cameraPosition = workspace.CurrentCamera.CFrame.Position

		for _, entry in combs do
			if (entry.Base.Position - cameraPosition).Magnitude < COMB_RANGE then
				local bob = math.sin(now * 2 + entry.Phase) * 0.6
				entry.Model:PivotTo(
					entry.Base * CFrame.new(0, bob, 0) * CFrame.Angles(0, now * 1.2 + entry.Phase, 0)
				)
			end
		end

		for weld, phase in wings do
			local wing = weld.Part1
			local body = weld.Part0
			if wing and body and (wing.Position - cameraPosition).Magnitude < WING_RANGE then
				local base = weld:GetAttribute("BaseC0")
				local side = weld:GetAttribute("Side")
				if typeof(base) == "CFrame" and typeof(side) == "number" then
					-- Frequência e amplitude crescem com a velocidade da abelha.
					local speed =
						math.clamp(body.AssemblyLinearVelocity.Magnitude / Config.Flight.BaseSpeed, 0, 1.6)
					local frequency = 26 + 22 * speed
					local amplitude = 0.35 + 0.15 * speed
					phase += dt * frequency
					wings[weld] = phase
					weld.C0 = base * CFrame.Angles(0, 0, math.sin(phase) * amplitude * side)
				end
			end
		end

		updateOrbs(now)
		updateAmbient(dt)
		updateButterflies(now, cameraPosition, ClientSettings.Get().Quality ~= "Alta")
		pickAccumulator += dt
		if pickAccumulator >= 0.25 then
			pickAccumulator = 0
			pickTargets(cameraPosition, ClientSettings.Get().Quality == "Baixa")
		end
		updateDrops(now)
		updateRainbow(now)
	end)
	Log.info("VisualController", "pronto")
end

return VisualController
