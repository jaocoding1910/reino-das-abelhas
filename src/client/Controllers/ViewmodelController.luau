--[[
	ViewmodelController (cliente) — patas peludas e carga na primeira pessoa

	Como nas referências: na parte de baixo da tela aparecem os "ombros"
	peludos amarelo/preto da sua abelha nos cantos e duas patas pretas
	segurando o que você carrega:
	- Favo de Cera (cera clara), Favo de Mel (âmbar), Favo Real (violeta
	  com moldura dourada) ou uma gota de néctar brilhante (CombArt).
	- Sem carga: as patas descem e ficam quase fora da tela.

	Regras:
	- Só existe no SEU cliente (peças dentro da Camera): não replica para
	  ninguém e não colide (CanCollide/CanQuery/CanTouch desligados).
	- Fica abaixo do centro: nunca cobre a mira.
	- Some em terceira pessoa (V), morto ou com a câmera longe da cabeça.
	- Balanço leve com o voo; desligado em "Reduzir movimento".
	- Movido com workspace:BulkMoveTo (uma chamada por quadro).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombArt = require(Shared.CombArt)
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Remotes = require(Shared.Remotes)

local ClientSettings = require(script.Parent.Parent.UI.ClientSettings)
local FlightController = require(script.Parent.FlightController)

local ViewmodelController = {}

local player = Players.LocalPlayer

local BLACK = Color3.fromRGB(28, 22, 18)
local YELLOW = Color3.fromRGB(255, 192, 40)

type Piece = { Part: BasePart, Offset: CFrame }

local folder: Model
local body: { Piece } = {} -- ombros e patas (sempre os mesmos)
local cargoPieces: { Piece } = {} -- favo/gota atual
local currentKind = "?"
local hold = 0 -- 0 = patas baixas, 1 = segurando
local swayX, swayY = 0, 0
-- Onde o favo fica: abaixo da mira, face para a câmera, inclinado para cima.
local CARGO_CF = CFrame.new(0, -0.66, -1.5) * CFrame.Angles(math.rad(18), 0, 0)
local lastLook: Vector3? = nil

local function fuzzy(name: string, size: Vector3, color: Color3, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.Fabric -- textura de "pelo" barata
	if shape then
		part.Shape = shape
	end
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = folder
	return part
end

local function add(list: { Piece }, part: BasePart, offset: CFrame)
	table.insert(list, { Part = part, Offset = offset })
end

-- Ombros (cantos de baixo) e patas (do ombro até o centro).
local function buildBody()
	local ball = Enum.PartType.Ball
	for side = -1, 1, 2 do
		-- Ombro: bola preta com uma faixa amarela por cima.
		add(body, fuzzy("Ombro", Vector3.one * 0.95, BLACK, ball), CFrame.new(side * 1.02, -0.98, -1.15))
		add(
			body,
			fuzzy("Faixa", Vector3.new(0.98, 0.42, 0.98), YELLOW, ball),
			CFrame.new(side * 1.02, -0.72, -1.15) * CFrame.Angles(0, 0, math.rad(side * -18))
		)
		-- Antebraço: do ombro até perto do favo.
		local forearm = fuzzy("Pata", Vector3.new(0.2, 0.2, 0.62), BLACK)
		add(
			body,
			forearm,
			CFrame.new(side * 0.6, -0.8, -1.32) * CFrame.Angles(math.rad(-20), math.rad(side * 48), 0)
		)
		-- "Mão": bolinha peluda que encosta no favo.
		add(body, fuzzy("Mao", Vector3.one * 0.26, BLACK, ball), CFrame.new(side * 0.36, -0.72, -1.48))
	end
end

local function setCargo(kind: string)
	if kind == currentKind then
		return
	end
	currentKind = kind
	for _, piece in cargoPieces do
		piece.Part:Destroy()
	end
	table.clear(cargoPieces)
	if kind == "" then
		return
	end
	local model = CombArt.Build(kind, if kind == "Nectar" then 0.5 else 0.62)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			add(cargoPieces, part, part.CFrame) -- posição relativa ao centro do favo
			part.CastShadow = false
			part.Parent = folder
		end
	end
	model:Destroy()
end

local function visible(): boolean
	if not Config.Flight.Viewmodel or ClientSettings.Get().ThirdPerson then
		return false
	end
	local character = player.Character
	local head = character
		and (character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart"))
	if not head or not head:IsA("BasePart") then
		return false
	end
	local health = player:GetAttribute("Health")
	if typeof(health) == "number" and health <= 0 then
		return false
	end
	-- Câmera colada na cabeça = primeira pessoa de verdade.
	return (workspace.CurrentCamera.CFrame.Position - head.Position).Magnitude < 3
end

function ViewmodelController:Init()
	folder = Instance.new("Model")
	folder.Name = "Viewmodel"
	buildBody()
end

function ViewmodelController:Start()
	local function onState(state: any)
		if type(state) == "table" then
			setCargo(CombArt.KindOf({ Nectar = state.Nectar, Combs = state.Combs }))
		end
	end
	Remotes.Get("StateUpdated").OnClientEvent:Connect(onState)
	task.spawn(function()
		local ok, state = pcall(function()
			return Remotes.GetFunction("GetInitialState"):InvokeServer()
		end)
		if ok then
			onState(state)
		end
	end)

	local parts: { BasePart } = {}
	local frames: { CFrame } = {}
	RunService:BindToRenderStep("Viewmodel", Enum.RenderPriority.Camera.Value + 2, function(dt)
		local camera = workspace.CurrentCamera
		local show = visible()
		if not show then
			if folder.Parent then
				folder.Parent = nil
			end
			lastLook = nil
			return
		end
		if folder.Parent ~= camera then
			folder.Parent = camera
		end

		local reduced = ClientSettings.Get().ReducedMotion
		local state = FlightController.State
		local now = os.clock()
		local k = math.clamp(dt * 8, 0, 1)

		-- Patas sobem quando há carga.
		hold += ((if currentKind ~= "" then 1 else 0) - hold) * math.clamp(dt * 6, 0, 1)

		-- Balanço: as patas "atrasam" um pouco quando você vira a câmera.
		local look = camera.CFrame.LookVector
		if lastLook and not reduced then
			local delta = camera.CFrame:VectorToObjectSpace(lastLook - look)
			swayX += (math.clamp(delta.X * 6, -0.12, 0.12) - swayX) * k
			swayY += (math.clamp(delta.Y * 6, -0.1, 0.1) - swayY) * k
		else
			swayX += (0 - swayX) * k
			swayY += (0 - swayY) * k
		end
		lastLook = look
		local bob = if reduced
			then 0
			else math.sin(now * 9) * 0.012 + math.sin(now * 2.1) * 0.02 * (0.4 + state.SpeedFraction)
		local lowered = (1 - hold) * -0.42

		local base = camera.CFrame * CFrame.new(swayX, bob + swayY, 0)
		local armBase = base * CFrame.new(0, lowered, 0)
		local count = 0
		for _, piece in body do
			count += 1
			parts[count] = piece.Part
			-- Ombros quase não descem; patas descem junto com a carga.
			local shoulder = piece.Part.Name == "Ombro" or piece.Part.Name == "Faixa"
			frames[count] = (if shoulder then base * CFrame.new(0, lowered * 0.2, 0) else armBase)
				* piece.Offset
		end
		local spin = if reduced then CFrame.identity else CFrame.Angles(0, 0, math.sin(now * 1.3) * 0.05)
		for _, piece in cargoPieces do
			count += 1
			parts[count] = piece.Part
			frames[count] = armBase * CARGO_CF * spin * piece.Offset
		end
		for i = #parts, count + 1, -1 do
			parts[i] = nil
			frames[i] = nil
		end
		workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end)
	Log.info("ViewmodelController", "pronto (patas e carga na 1ª pessoa)")
end

return ViewmodelController
