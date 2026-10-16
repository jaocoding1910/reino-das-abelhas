--[[
	TourController (cliente) — tour de apresentação

	Aperte T (ou o botão "🎬 Tour" nas Configurações) e a câmera passeia
	sozinha pelos lugares principais do Reino, com faixas de cinema e um
	título em cada cena. Serve para apresentar o jogo e gravar o vídeo do
	portfólio. Aperte T de novo para sair a qualquer momento.

	É só câmera e interface no SEU cliente: o servidor não sabe do tour e
	nada do jogo muda (a abelha fica parada onde estava).
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Remotes = require(Shared.Remotes)

local TourController = {}

local player = Players.LocalPlayer

type Shot = { Title: string, Subtitle: string, From: Vector3, To: Vector3, Look: Vector3 }

local playing = false
local token = 0
local hivePosition: Vector3? = nil

local gui: ScreenGui
local fade: Frame
local title: TextLabel
local subtitle: TextLabel

local function shots(): { Shot }
	local royal = Config.Map.RoyalHive.Position + Vector3.new(0, Config.Map.RoyalHive.PlateauHeight, 0)
	local lake = Config.Places.Lake.Position
	local cave = Config.Places.Cave.Position
	local sky = Config.SkyIsland.Position
	local cliff = Config.Map.CliffGroups[1].Center
	local hive = hivePosition or Vector3.new(Config.Map.PlotRingRadius, 0, 0) -- colmeia 1 se o estado ainda não chegou
	local toCenter = Vector3.new(-hive.X, 0, -hive.Z).Unit
	local side = Vector3.new(-toCenter.Z, 0, toCenter.X)
	return {
		{
			Title = "REINO DAS ABELHAS",
			Subtitle = "Um mundo em escala de abelha",
			From = Vector3.new(-380, 300, 420),
			To = Vector3.new(380, 260, 380),
			Look = Vector3.new(0, 30, 0),
		},
		{
			Title = "Sua colmeia",
			Subtitle = "Entregue néctar e favos e construa célula por célula",
			From = hive + toCenter * 120 + side * 40 + Vector3.new(0, 40, 0),
			To = hive + toCenter * 70 - side * 20 + Vector3.new(0, 30, 0),
			Look = hive + Vector3.new(0, 32, 0),
		},
		{
			Title = "Campo de flores",
			Subtitle = "Colete néctar em sequência para fazer combos",
			From = Vector3.new(260, 14, -60),
			To = Vector3.new(330, 18, 110),
			Look = Vector3.new(420, 10, 220),
		},
		{
			Title = "Ilha nas Nuvens",
			Subtitle = "Corrida de anéis e flores que dão néctar em dobro",
			From = sky + Vector3.new(-140, 30, -120),
			To = sky + Vector3.new(-80, 60, 120),
			Look = sky,
		},
		{
			Title = "Colmeia Real",
			Subtitle = "A Rainha, os favos raros e a zona de disputa",
			From = royal + Vector3.new(-160, 60, 380),
			To = royal + Vector3.new(120, 40, 300),
			Look = royal + Vector3.new(0, 30, 0),
		},
		{
			Title = "Lago das Libélulas",
			Subtitle = "Favos médios nas vitórias-régias — cuidado com o rasante",
			From = lake + Vector3.new(-160, 40, 60),
			To = lake + Vector3.new(-90, 25, 140),
			Look = lake,
		},
		{
			Title = "Penhascos do Vale",
			Subtitle = "Casinhas de favo, pontes de corda e cachoeiras",
			From = cliff + Vector3.new(260, 90, -120),
			To = cliff + Vector3.new(200, 110, 120),
			Look = cliff + Vector3.new(0, 80, 60),
		},
		{
			Title = "Caverna de Cristal",
			Subtitle = "Favos raros no escuro, longe da segurança",
			From = cave + Vector3.new(160, 50, -140),
			To = cave + Vector3.new(90, 25, -80),
			Look = cave + Vector3.new(0, 10, 0),
		},
		{
			Title = "Rumo à coroa",
			Subtitle = "Torne-se Rei ou Rainha da Colmeia",
			From = Vector3.new(380, 220, -380),
			To = Vector3.new(-120, 360, -560),
			Look = royal,
		},
	}
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "TourApresentacao"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	gui.Enabled = false
	for _, y in { 0, 1 } do
		local bar = Instance.new("Frame")
		bar.Name = "FaixaCinema"
		bar.BackgroundColor3 = Color3.new(0, 0, 0)
		bar.BorderSizePixel = 0
		bar.AnchorPoint = Vector2.new(0, y)
		bar.Position = UDim2.fromScale(0, y)
		bar.Size = UDim2.new(1, 0, 0.1, 0)
		bar.Parent = gui
	end
	title = Instance.new("TextLabel")
	title.Name = "Titulo"
	title.BackgroundTransparency = 1
	title.AnchorPoint = Vector2.new(0, 1)
	title.Position = UDim2.new(0.06, 0, 0.82, 0)
	title.Size = UDim2.new(0.8, 0, 0.09, 0)
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(255, 205, 80)
	title.TextStrokeTransparency = 0.4
	title.Parent = gui
	subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitulo"
	subtitle.BackgroundTransparency = 1
	subtitle.Position = UDim2.new(0.06, 0, 0.82, 4)
	subtitle.Size = UDim2.new(0.8, 0, 0.045, 0)
	subtitle.Font = Enum.Font.GothamMedium
	subtitle.TextScaled = true
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.TextColor3 = Color3.fromRGB(255, 248, 230)
	subtitle.TextStrokeTransparency = 0.5
	subtitle.Parent = gui
	fade = Instance.new("Frame")
	fade.Name = "Fade"
	fade.BackgroundColor3 = Color3.new(0, 0, 0)
	fade.BorderSizePixel = 0
	fade.Size = UDim2.fromScale(1, 1)
	fade.BackgroundTransparency = 1
	fade.ZIndex = 10
	fade.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
end

local hidden: { ScreenGui } = {}

local function setHud(visible: boolean)
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end
	if visible then
		for _, item in hidden do
			if item.Parent then
				item.Enabled = true
			end
		end
		table.clear(hidden)
	else
		for _, item in playerGui:GetChildren() do
			if item:IsA("ScreenGui") and item ~= gui and item.Enabled then
				item.Enabled = false
				table.insert(hidden, item)
			end
		end
	end
end

local function fadeTo(transparency: number)
	local tween = TweenService:Create(
		fade,
		TweenInfo.new(Config.Tour.FadeSeconds),
		{ BackgroundTransparency = transparency }
	)
	tween:Play()
	tween.Completed:Wait()
end

function TourController.Stop()
	if not playing then
		return
	end
	playing = false
	token += 1
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	gui.Enabled = false
	fade.BackgroundTransparency = 1
	setHud(true)
end

function TourController.Play()
	if playing then
		TourController.Stop()
		return
	end
	playing = true
	token += 1
	local myToken = token
	local camera = workspace.CurrentCamera
	setHud(false)
	gui.Enabled = true
	fade.BackgroundTransparency = 0
	camera.CameraType = Enum.CameraType.Scriptable
	task.spawn(function()
		for _, shot in shots() do
			if myToken ~= token then
				return
			end
			title.Text = shot.Title
			subtitle.Text = shot.Subtitle
			local started = os.clock()
			local duration = Config.Tour.ShotSeconds
			local connection = RunService.RenderStepped:Connect(function()
				local t = math.clamp((os.clock() - started) / duration, 0, 1)
				local eased = t * t * (3 - 2 * t) -- suave no começo e no fim
				local position = shot.From:Lerp(shot.To, eased)
				camera.CFrame = CFrame.lookAt(position, shot.Look)
			end)
			fadeTo(1)
			task.wait(math.max(0, duration - Config.Tour.FadeSeconds * 2))
			if myToken == token then
				fadeTo(0)
			end
			connection:Disconnect()
		end
		if myToken == token then
			TourController.Stop()
		end
	end)
end

function TourController:Init()
	build()
end

function TourController:Start()
	Remotes.Get("StateUpdated").OnClientEvent:Connect(function(state)
		if type(state) == "table" and typeof(state.HivePosition) == "Vector3" then
			hivePosition = state.HivePosition
		end
	end)
	ContextActionService:BindAction("TourApresentacao", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			TourController.Play()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.T)
	Log.info("TourController", "pronto (T = tour de apresentação)")
end

return TourController
