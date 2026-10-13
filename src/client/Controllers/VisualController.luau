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

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Remotes = require(Shared.Remotes)

local FlightController = require(script.Parent.FlightController)

local VisualController = {}

local player = Players.LocalPlayer

local COMB_TAG = "FavoFlutuante"
local WING_TAG = "AsaAbelha"
local COMB_RANGE = 220
local WING_RANGE = 250
local DECOR_COUNT = 260

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

local function localRootPosition(): Vector3?
	local root = rootOf(player)
	return root and root.Position
end

local function onEffect(kind: string, position: Vector3, userId: number?)
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

local ambientPart: Part
local pollen: ParticleEmitter
local fireflies: ParticleEmitter
local windPart: Part
local wind: ParticleEmitter

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
	pollen.Enabled = not night
	if night ~= lastNight then
		lastNight = night
		for _, cap in glowCaps do
			cap.Material = if night then Enum.Material.Neon else Enum.Material.SmoothPlastic
		end
	end
	fireflies.Rate += ((if night then 14 else 0) - fireflies.Rate) * math.clamp(dt, 0, 1)

	windPart.CFrame = camera.CFrame * CFrame.new(0, 0, -16)
	local state = FlightController.State
	wind.Rate = if state.Sprinting then 40 + 40 * math.clamp(state.SpeedFraction - 1, 0, 1) else 0
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
			Height = rng:NextNumber(1.2, 2.6),
			Tilt = rng:NextNumber(-20, 20),
			Color = DECOR_COLORS[rng:NextInteger(1, #DECOR_COLORS)],
			Mushroom = radius > Config.Map.ForestRadius.Min and rng:NextNumber() < 0.6,
			Done = false,
		})
	end
end

local decorFolder: Folder? = nil

local function buildSpot(spot: DecorSpot, ground: Vector3)
	local folder = decorFolder :: Folder
	local base = CFrame.new(ground) * CFrame.Angles(0, spot.Yaw, 0)
	local height = spot.Height
	decorPart(
		folder,
		Vector3.new(height, 0.14, 0.14),
		base * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(85, 150, 60),
		Enum.PartType.Cylinder
	)
	if spot.Mushroom then
		-- Cogumelinho que brilha à noite, no bosque.
		local cap = decorPart(
			folder,
			Vector3.new(0.5, 1.3, 1.3),
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
				Vector3.new(0.45, 0.1, 0.9),
				head
					* CFrame.Angles(0, p * math.pi * 2 / 5, 0)
					* CFrame.new(0, 0, -0.45)
					* CFrame.Angles(math.rad(15), 0, 0),
				spot.Color,
				Enum.PartType.Block
			)
		end
		decorPart(
			folder,
			Vector3.one * 0.45,
			head * CFrame.new(0, 0.08, 0),
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
end

function VisualController:Start()
	Remotes.Get("Effect").OnClientEvent:Connect(onEffect)

	planDecor()
	task.spawn(decorLoop)

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
	end)
	Log.info("VisualController", "pronto")
end

return VisualController
