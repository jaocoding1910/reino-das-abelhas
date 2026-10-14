--[[
	Abertura (ReplicatedFirst) — tela de entrada do Reino das Abelhas

	Roda antes de tudo, enquanto o jogo carrega:
	- fundo cor de mel com favos flutuando e o título;
	- "Carregando o reino…" até o jogo terminar de carregar;
	- botão JOGAR; ao clicar, a tela some com um fade.
	Enquanto ela está aberta, o atributo local "NaAbertura" do jogador fica
	true (o tutorial espera ela fechar).
]]

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
player:SetAttribute("NaAbertura", true)
ReplicatedFirst:RemoveDefaultLoadingScreen()

local GOLD = Color3.fromRGB(255, 196, 64)
local DARK = Color3.fromRGB(28, 22, 16)
local SQRT3 = math.sqrt(3)

local gui = Instance.new("ScreenGui")
gui.Name = "Abertura"
gui.IgnoreGuiInset = true
gui.DisplayOrder = 100
gui.ResetOnSpawn = false

local back = Instance.new("CanvasGroup")
back.Size = UDim2.fromScale(1, 1)
back.BackgroundColor3 = Color3.fromRGB(255, 170, 40)
back.Parent = gui
local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 205, 90)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(235, 140, 30)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 70, 20)),
})
gradient.Rotation = 90
gradient.Parent = back

-- Hexágono de 3 retângulos (mesmo truque do HUD).
local function hex(size: number, color: Color3, transparency: number, parent: Instance): Frame
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Size = UDim2.fromOffset(size * SQRT3 / 2, size)
	for i = 0, 2 do
		local piece = Instance.new("Frame")
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		piece.Position = UDim2.fromScale(0.5, 0.5)
		piece.Size = UDim2.fromOffset(size / 2, size / 2 * SQRT3)
		piece.Rotation = 60 * i + 90
		piece.BackgroundColor3 = color
		piece.BackgroundTransparency = transparency
		piece.BorderSizePixel = 0
		piece.Parent = holder
	end
	holder.Parent = parent
	return holder
end

-- Favos flutuando ao fundo.
local floaters = {}
local rng = Random.new(7)
for i = 1, 26 do
	local size = rng:NextNumber(40, 130)
	local h = hex(size, Color3.fromRGB(255, 225, 140), rng:NextNumber(0.55, 0.85), back)
	h.Position = UDim2.fromScale(rng:NextNumber(0, 1), rng:NextNumber(0, 1))
	table.insert(floaters, {
		Frame = h,
		X = h.Position.X.Scale,
		Y = h.Position.Y.Scale,
		Speed = rng:NextNumber(0.01, 0.04),
		Phase = i,
	})
end

local center = Instance.new("Frame")
center.AnchorPoint = Vector2.new(0.5, 0.5)
center.Position = UDim2.fromScale(0.5, 0.45)
center.Size = UDim2.fromOffset(700, 420)
center.BackgroundTransparency = 1
center.Parent = back
local scale = Instance.new("UIScale")
scale.Parent = center

local badge = hex(150, DARK, 0.1, center)
badge.Position = UDim2.new(0.5, 0, 0, 80)
local badgeRing = hex(170, GOLD, 0, center)
badgeRing.Position = badge.Position
badgeRing.ZIndex = 0
for _, piece in badgeRing:GetChildren() do
	(piece :: Frame).ZIndex = 0
end
local bee = Instance.new("TextLabel")
bee.AnchorPoint = Vector2.new(0.5, 0.5)
bee.Position = UDim2.new(0.5, 0, 0, 80)
bee.Size = UDim2.fromOffset(90, 90)
bee.BackgroundTransparency = 1
bee.TextScaled = true
bee.Text = "🐝"
bee.ZIndex = 3
bee.Parent = center

local title = Instance.new("TextLabel")
title.AnchorPoint = Vector2.new(0.5, 0)
title.Position = UDim2.new(0.5, 0, 0, 175)
title.Size = UDim2.fromOffset(700, 86)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.TextScaled = true
title.TextColor3 = Color3.fromRGB(255, 248, 230)
title.Text = "REINO DAS ABELHAS"
title.Parent = center
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(120, 60, 10)
stroke.Thickness = 4
stroke.Parent = title

local subtitle = Instance.new("TextLabel")
subtitle.AnchorPoint = Vector2.new(0.5, 0)
subtitle.Position = UDim2.new(0.5, 0, 0, 262)
subtitle.Size = UDim2.fromOffset(600, 30)
subtitle.BackgroundTransparency = 1
subtitle.Font = Enum.Font.GothamBold
subtitle.TextScaled = true
subtitle.TextColor3 = DARK
subtitle.Text = "Colete, construa e proteja a sua colmeia"
subtitle.Parent = center

local status = Instance.new("TextLabel")
status.AnchorPoint = Vector2.new(0.5, 0)
status.Position = UDim2.new(0.5, 0, 0, 318)
status.Size = UDim2.fromOffset(400, 26)
status.BackgroundTransparency = 1
status.Font = Enum.Font.Gotham
status.TextScaled = true
status.TextColor3 = Color3.fromRGB(70, 40, 10)
status.Text = "Carregando o reino…"
status.Parent = center

local play = Instance.new("TextButton")
play.AnchorPoint = Vector2.new(0.5, 0)
play.Position = UDim2.new(0.5, 0, 0, 312)
play.Size = UDim2.fromOffset(240, 64)
play.BackgroundColor3 = DARK
play.Font = Enum.Font.GothamBlack
play.TextScaled = true
play.TextColor3 = GOLD
play.Text = "JOGAR"
play.Visible = false
play.Modal = true -- solta o mouse (primeira pessoa trava o cursor no centro)
play.Parent = center
local playCorner = Instance.new("UICorner")
playCorner.CornerRadius = UDim.new(0, 14)
playCorner.Parent = play
local playStroke = Instance.new("UIStroke")
playStroke.Color = GOLD
playStroke.Thickness = 3
playStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
playStroke.Parent = play
local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0.2, 0)
padding.PaddingBottom = UDim.new(0.2, 0)
padding.Parent = play

gui.Parent = player:WaitForChild("PlayerGui")

local function fitScale()
	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
		or Vector2.new(1366, 768)
	scale.Scale = math.clamp(math.min(viewport.X / 1000, viewport.Y / 620), 0.45, 1.3)
end
fitScale()

local closing = false
local connection = RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for _, f in floaters do
		local y = (f.Y - t * f.Speed) % 1.2 - 0.1
		f.Frame.Position = UDim2.fromScale(f.X + math.sin(t * 0.5 + f.Phase) * 0.01, y)
		f.Frame.Rotation = math.sin(t * 0.3 + f.Phase) * 10
	end
	bee.Rotation = math.sin(t * 2) * 8
	bee.Position = UDim2.new(0.5, 0, 0, 80 + math.sin(t * 3) * 6)
	fitScale()
end)

-- Espera o jogo carregar (com limite) e mostra o JOGAR.
task.spawn(function()
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	local deadline = os.clock() + 4
	while os.clock() < deadline and not player:FindFirstChild("PlayerGui"):FindFirstChild("HUD_Abelhas") do
		task.wait(0.2)
	end
	status.Visible = false
	play.Visible = true
	play.Size = UDim2.fromOffset(200, 54)
	TweenService
		:Create(play, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(240, 64) })
		:Play()
end)

play.Activated:Connect(function()
	if closing then
		return
	end
	closing = true
	local fade = TweenService:Create(back, TweenInfo.new(0.6), { GroupTransparency = 1 })
	fade:Play()
	fade.Completed:Wait()
	connection:Disconnect()
	gui:Destroy()
	player:SetAttribute("NaAbertura", false)
end)
