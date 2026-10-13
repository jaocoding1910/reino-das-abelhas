--[[
	GuideController (cliente) — trilha dourada até o objetivo

	Uma linha brilhante em arco sai da sua abelha e vai até o próximo passo
	da missão, com um marcador "👇 X m" em cima do alvo:
	- Carga cheia (ou missão de mel/célula com carga) → pote de mel da colmeia.
	- Missão de néctar → flor mais perto que ainda tem néctar.
	- Missão de favo (comum/médio/raro) → favo disponível mais perto.
	- Missão de célula → parede da colmeia.
	- Pedido da Rainha pronto → a Rainha, na Colmeia Real.
	- Missão de melhoria → sem trilha (é no painel: tecla 2).
	Perto do alvo (menos de 16 studs), a trilha some.

	Tecla G (ou o botão "Trilha" no celular) liga e desliga.
	Só lê o estado que o servidor manda; não decide nada.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared.Util.Log)
local Remotes = require(Shared.Remotes)

local GuideController = {}

local player = Players.LocalPlayer
local GOLD = Color3.fromRGB(255, 205, 80)
local HIDE_DISTANCE = 16

local state: any = nil
local enabled = true

local nectarPrompts: { ProximityPrompt } = {}
local combPrompts: { ProximityPrompt } = {}

local targetPart: Part
local targetAttachment: Attachment
local beam: Beam
local marker: BillboardGui
local markerText: TextLabel
local rootAttachment: Attachment? = nil

local function scanPrompts()
	local map = workspace:FindFirstChild("Mapa")
	if not map then
		return
	end
	local nectar, combs = {}, {}
	local flowers = map:FindFirstChild("Flores")
	if flowers then
		for _, item in flowers:GetDescendants() do
			if item:IsA("ProximityPrompt") then
				table.insert(nectar, item)
			end
		end
	end
	local favos = map:FindFirstChild("Favos")
	if favos then
		for _, item in favos:GetDescendants() do
			if item:IsA("ProximityPrompt") then
				table.insert(combs, item)
			end
		end
	end
	nectarPrompts, combPrompts = nectar, combs
end

local function rarityOf(prompt: ProximityPrompt): string?
	local node: Instance? = prompt.Parent
	while node and node ~= workspace do
		local rarity = node:GetAttribute("Rarity")
		if typeof(rarity) == "string" then
			return rarity
		end
		node = node.Parent
	end
	return nil
end

local function nearest(prompts: { ProximityPrompt }, from: Vector3, rarity: string?): Vector3?
	local best, bestDistance = nil, math.huge
	for _, prompt in prompts do
		local holder = prompt.Parent
		if prompt.Enabled and holder and holder:IsA("BasePart") then
			if not rarity or rarityOf(prompt) == rarity then
				local distance = (holder.Position - from).Magnitude
				if distance < bestDistance then
					best, bestDistance = holder.Position, distance
				end
			end
		end
	end
	return best
end

-- Decide o alvo a partir da missão e da carga.
local function chooseTarget(from: Vector3): (Vector3?, string?)
	local s = state
	if not s then
		return nil, nil
	end
	local quest = s.Quest
	local kind = quest and quest.Kind
	local carrying = (s.CarryWeight or 0) > 0
	local full = s.Capacity and s.CarryWeight >= s.Capacity

	if full or (carrying and (kind == "Mel" or kind == "Celula")) then
		return s.DeliveryPosition, "Entregue no pote"
	end
	local royal = s.Royal
	if royal and royal.Ready and royal.Position then
		return royal.Position, "Rainha"
	end
	if kind == "Nectar" or kind == "Mel" then
		return nearest(nectarPrompts, from, nil), "Néctar"
	elseif kind == "Comb" then
		return nearest(combPrompts, from, nil), "Favo"
	elseif kind == "CombMedio" then
		return nearest(combPrompts, from, "Medio"), "Favo médio"
	elseif kind == "CombRaro" then
		return nearest(combPrompts, from, "Raro"), "Favo raro"
	elseif kind == "Celula" then
		return s.HivePosition, "Sua colmeia"
	end
	return nil, nil
end

local function build()
	targetPart = Instance.new("Part")
	targetPart.Name = "AlvoTrilha"
	targetPart.Anchored = true
	targetPart.CanCollide = false
	targetPart.CanQuery = false
	targetPart.CanTouch = false
	targetPart.Transparency = 1
	targetPart.Size = Vector3.one
	targetPart.Parent = workspace

	targetAttachment = Instance.new("Attachment")
	targetAttachment.Orientation = Vector3.new(0, 0, 90) -- eixo X para cima: a curva sobe
	targetAttachment.Parent = targetPart

	beam = Instance.new("Beam")
	beam.Name = "TrilhaDourada"
	beam.Color = ColorSequence.new(GOLD)
	beam.LightEmission = 0.6
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.Segments = 30
	-- Mais grossa longe de você: de longe uma linha fina some (menos de 1 pixel).
	beam.Width0 = 0.35
	beam.Width1 = 1
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.85),
		NumberSequenceKeypoint.new(0.1, 0.45),
		NumberSequenceKeypoint.new(0.9, 0.35),
		NumberSequenceKeypoint.new(1, 0.6),
	})
	beam.Attachment1 = targetAttachment
	beam.Enabled = false
	beam.Parent = targetPart

	marker = Instance.new("BillboardGui")
	marker.Name = "MarcadorAlvo"
	marker.Size = UDim2.fromOffset(120, 54)
	marker.StudsOffset = Vector3.new(0, 6, 0)
	marker.AlwaysOnTop = true
	marker.LightInfluence = 0
	marker.Adornee = targetPart
	marker.Enabled = false
	markerText = Instance.new("TextLabel")
	markerText.Size = UDim2.fromScale(1, 1)
	markerText.BackgroundTransparency = 1
	markerText.Font = Enum.Font.GothamBold
	markerText.TextScaled = true
	markerText.TextColor3 = GOLD
	markerText.TextStrokeTransparency = 0.3
	markerText.Parent = marker
	marker.Parent = player:WaitForChild("PlayerGui")
end

local function attachToCharacter(character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "InicioTrilha"
	attachment.Position = Vector3.new(0, -1.5, -2) -- um pouco à frente e abaixo: aparece na tela
	attachment.Orientation = Vector3.new(0, 0, 90)
	attachment.Parent = root
	rootAttachment = attachment
	beam.Attachment0 = attachment
end

function GuideController:Init()
	build()
end

function GuideController:Start()
	Remotes.Get("StateUpdated").OnClientEvent:Connect(function(newState)
		state = newState
	end)
	task.spawn(function()
		local ok, initial = pcall(function()
			return Remotes.GetFunction("GetInitialState"):InvokeServer()
		end)
		if ok and initial and not state then
			state = initial
		end
	end)

	player.CharacterAdded:Connect(attachToCharacter)
	if player.Character then
		task.spawn(attachToCharacter, player.Character)
	end

	ContextActionService:BindAction("TrilhaDourada", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			enabled = not enabled
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.G)
	ContextActionService:SetTitle("TrilhaDourada", "Trilha")
	ContextActionService:SetPosition("TrilhaDourada", UDim2.new(1, -95, 1, -235))

	task.spawn(function()
		while true do
			scanPrompts()
			task.wait(2)
		end
	end)

	local accumulator = 0
	RunService.RenderStepped:Connect(function(dt)
		accumulator += dt
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not enabled or not root or not rootAttachment or rootAttachment.Parent ~= root then
			beam.Enabled = false
			marker.Enabled = false
			return
		end
		-- Recalcula o alvo 4x por segundo (barato); a linha acompanha todo quadro.
		if accumulator >= 0.25 then
			accumulator = 0
			local target, label = chooseTarget(root.Position)
			if target then
				targetPart.Position = target
				targetPart:SetAttribute("Rotulo", label)
				targetPart:SetAttribute("Ativo", true)
			else
				targetPart:SetAttribute("Ativo", false)
			end
		end
		local active = targetPart:GetAttribute("Ativo") == true
		local distance = (targetPart.Position - root.Position).Magnitude
		local show = active and distance > HIDE_DISTANCE
		beam.Enabled = show
		marker.Enabled = show
		if show then
			local curve = math.clamp(distance * 0.08, 2, 14)
			beam.CurveSize0 = curve
			beam.CurveSize1 = -curve
			-- Largura acompanha a distância para continuar visível.
			beam.Width1 = math.clamp(distance * 0.008, 0.5, 1.6)
			local bounce = math.abs(math.sin(os.clock() * 3)) * 1.5
			marker.StudsOffset = Vector3.new(0, 6 + bounce, 0)
			markerText.Text = `👇 {targetPart:GetAttribute("Rotulo") or ""}\n{math.floor(distance)} m`
		end
	end)
	Log.info("GuideController", "pronto (G liga/desliga a trilha)")
end

return GuideController
