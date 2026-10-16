--[[
	OnboardingController (cliente) — tutorial e configurações

	Tutorial (só para quem nunca terminou; state.TutorialDone):
	  a Rainha explica 5 passos, que avançam sozinhos conforme o jogador faz:
	  voar → coletar néctar → entregar → abrir o painel (2) → construir célula.
	  No fim, o servidor dá Config.TutorialReward de mel. Dá para pular.
	  Quem já tem bastante mel (save antigo) pula sozinho.

	Configurações (botão ⚙ ao lado do relógio, ou tecla P):
	  música, volume dos efeitos, trilha dourada, inclinar a câmera e
	  qualidade (Baixa = menos partículas e enfeites, bom para celular).
	  Salvas no perfil pelo servidor.
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

local ClientSettings = require(script.Parent.Parent.UI.ClientSettings)
local Theme = require(script.Parent.Parent.UI.Theme)
local W = require(script.Parent.Parent.UI.Widgets)
local TourController = require(script.Parent.TourController)

local OnboardingController = {}

local player = Players.LocalPlayer
local DARK_BUTTON = Color3.fromRGB(60, 50, 38)
local GREEN = Color3.fromRGB(80, 200, 120)

local state: any = nil
local refs: { [string]: any } = {}

-- Tutorial -----------------------------------------------------------------------

local STEPS = {
	"Bem-vinda ao Reino! Voe com W A S D. Espaço sobe, Q desce, Shift arranca e V mostra sua abelha.",
	"Siga a trilha dourada até uma flor e segure E perto do miolo para pegar néctar.",
	"Ótimo! Siga a trilha de volta e voe até o pote de mel da sua colmeia: a entrega é automática.",
	"Aperte 2 para abrir o painel da sua colmeia (melhorias, mascotes e medalhas).",
	"Com 50 de mel, construa uma célula: na parede de favos, segure E no contorno claro.",
	"Melhore sua abelha: aperte 2, aba Abelha, e compre Velocidade, Capacidade ou Resistência.",
	"Área verde = segura. À noite 🌙 os predadores ficam fortes, mas favos raros entregues valem mel extra. Meta final: virar Rei/Rainha da Colmeia!",
}

local step = 1
local stepShownAt = 0
local startPosition: Vector3? = nil
local finished = false

local function hivePanelOpen(): boolean
	local gui = player:FindFirstChild("PlayerGui")
	local hud = gui and gui:FindFirstChild("HUD_Abelhas")
	local panel = hud and hud:FindFirstChild("SuaColmeia")
	return panel ~= nil and (panel :: GuiObject).Visible
end

local function stepDone(index: number): boolean
	local s = state
	if not s then
		return false
	end
	if index == 1 then
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return false
		end
		startPosition = startPosition or root.Position
		return (root.Position - (startPosition :: Vector3)).Magnitude > 40
	elseif index == 2 then
		return (s.Nectar or 0) > 0 or (s.HoneyEarned or 0) > 0
	elseif index == 3 then
		return (s.HoneyEarned or 0) > 0
	elseif index == 4 then
		return hivePanelOpen()
	elseif index == 5 then
		return s.Building ~= nil or (s.CellsCompleted or 0) > Config.Hive.InitialCells
	elseif index == 6 then
		for _, upgrade in s.Upgrades or {} do
			if (upgrade.Level or 0) > 0 then
				return true
			end
		end
		return false
	elseif index == 7 then
		-- Passo só de leitura: avança sozinho depois de alguns segundos.
		return os.clock() - stepShownAt > 9
	end
	return false
end

local function buildTutorial(gui: ScreenGui)
	local card =
		W.Panel("Tutorial", UDim2.fromOffset(500, 92), UDim2.new(0.5, 0, 1, -178), Vector2.new(0.5, 1), gui)
	card.Visible = false
	local stroke = card:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = Theme.Colors.Gold
		stroke.Thickness = 2.5
	end
	local badge, crown = W.HexBadge("Rainha", 64, "👑", card)
	badge.Position = UDim2.fromOffset(12, 14)
	crown.TextColor3 = Theme.Colors.Gold
	refs.TutorialStep = W.Text("Passo", "", UDim2.new(1, -170, 0, 18), UDim2.fromOffset(86, 8), card, {
		TextColor3 = Theme.Colors.Gold,
	})
	refs.TutorialText = W.Text("Texto", "", UDim2.new(1, -100, 0, 50), UDim2.fromOffset(86, 30), card, {
		Font = Theme.FontRegular,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 20
	limit.Parent = refs.TutorialText
	local skip =
		W.Button("Pular", "Pular", UDim2.fromOffset(70, 24), UDim2.new(1, -80, 0, 6), card, DARK_BUTTON)
	skip.Activated:Connect(function()
		finished = true
		card.Visible = false
		Remotes.Get("RequestTutorial"):FireServer("Pular")
	end)
	refs.TutorialCard = card
end

local function showStep()
	stepShownAt = os.clock()
	refs.TutorialStep.Text = `Rainha Melissa · passo {step}/{#STEPS}`
	refs.TutorialText.Text = STEPS[step]
	local card: Frame = refs.TutorialCard
	card.Visible = true
	local scale = card:FindFirstChild("Entrada") :: UIScale?
	if not scale then
		local created = Instance.new("UIScale")
		created.Name = "Entrada"
		created.Parent = card
		scale = created
	end
	local s = scale :: UIScale
	s.Scale = 0.85
	TweenService:Create(s, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
end

local function finishTutorial()
	finished = true
	local card: Frame = refs.TutorialCard
	refs.TutorialStep.Text = "Rainha Melissa"
	refs.TutorialText.Text =
		`Perfeito! Você já sabe o essencial. Tome +{Config.TutorialReward} mel para começar bem!`
	refs.TutorialText.TextColor3 = GREEN
	Remotes.Get("RequestTutorial"):FireServer("Concluir")
	task.delay(5, function()
		card.Visible = false
	end)
end

local function tickTutorial()
	if finished or not state then
		return
	end
	if state.TutorialDone then
		finished = true
		refs.TutorialCard.Visible = false
		return
	end
	-- Save antigo com bastante mel: já sabe jogar.
	if (state.HoneyEarned or 0) >= 500 then
		finished = true
		Remotes.Get("RequestTutorial"):FireServer("Pular")
		return
	end
	if not refs.TutorialCard.Visible then
		showStep()
	end
	while step <= #STEPS and stepDone(step) do
		step += 1
		if step <= #STEPS then
			showStep()
		end
	end
	if step > #STEPS then
		finishTutorial()
	end
end

-- Configurações ------------------------------------------------------------------

local SFX_LEVELS = { 0, 0.4, 0.8, 1 }

local function toggleRow(
	panel: Frame,
	y: number,
	label: string,
	key: string,
	render: (any) -> string,
	onClick: () -> ()
)
	W.Text(`Rotulo{key}`, label, UDim2.new(1, -190, 0, 24), UDim2.fromOffset(20, y + 8), panel)
	local button =
		W.Button(key, "", UDim2.fromOffset(150, 36), UDim2.new(1, -170, 0, y + 2), panel, DARK_BUTTON)
	button.Activated:Connect(onClick)
	refs[`Botao{key}`] = { Button = button, Render = render }
end

local function renderSettings()
	local settings = ClientSettings.Get()
	for _, key in
		{
			"MusicLevel",
			"Sfx",
			"Trail",
			"CameraRoll",
			"Quality",
			"ThirdPerson",
			"Sensitivity",
			"ReducedMotion",
		}
	do
		local entry = refs[`Botao{key}`]
		if entry then
			local text = entry.Render(settings[key])
			entry.Button.Text = text
			local on = settings[key] == true
				or (type(settings[key]) == "number" and settings[key] > 0)
				or settings[key] == "Alta"
				or settings[key] == "Media"
			entry.Button.BackgroundColor3 = if on then Theme.Colors.Gold else DARK_BUTTON
			entry.Button.TextColor3 = if on then Theme.Colors.Panel else Theme.Colors.Text
		end
	end
end

local function buildSettings(gui: ScreenGui)
	local panel = W.Panel(
		"Configuracoes",
		UDim2.fromOffset(420, 520),
		UDim2.fromScale(0.5, 0.5),
		Vector2.new(0.5, 0.5),
		gui
	)
	panel.Visible = false
	panel.ZIndex = 6
	W.Text("Titulo", "⚙ Configurações", UDim2.new(1, -40, 0, 30), UDim2.fromOffset(20, 12), panel, {
		TextColor3 = Theme.Colors.Gold,
	})
	local function flip(key: string)
		return function()
			ClientSettings.Set(key, not ClientSettings.Get()[key])
		end
	end
	local function onOff(value: any): string
		return if value then "Ligada" else "Desligada"
	end
	local function cycle(key: string, levels: { number })
		return function()
			local current = ClientSettings.Get()[key]
			local index = 1
			for i, level in levels do
				if math.abs(level - (tonumber(current) or 0)) < 0.05 then
					index = i
				end
			end
			local nextLevel = levels[index % #levels + 1]
			ClientSettings.Set(key, nextLevel)
			if key == "MusicLevel" then
				ClientSettings.Set("Music", nextLevel > 0)
			end
		end
	end
	local function percent(value: any): string
		return if (tonumber(value) or 0) <= 0 then "Mudo" else `{math.floor(value * 100 + 0.5)}%`
	end
	toggleRow(
		panel,
		52,
		"🎵 Volume dos ambientes",
		"MusicLevel",
		percent,
		cycle("MusicLevel", { 0, 0.3, 0.6, 1 })
	)
	toggleRow(panel, 96, "🔊 Efeitos sonoros", "Sfx", function(value)
		return if value <= 0 then "Mudo" else `{math.floor(value * 100 + 0.5)}%`
	end, function()
		local current = ClientSettings.Get().Sfx
		local index = 1
		for i, level in SFX_LEVELS do
			if math.abs(level - current) < 0.05 then
				index = i
			end
		end
		ClientSettings.Set("Sfx", SFX_LEVELS[index % #SFX_LEVELS + 1])
	end)
	toggleRow(panel, 140, "✨ Trilha dourada (G)", "Trail", onOff, flip("Trail"))
	toggleRow(panel, 184, "🎥 Inclinar câmera nas curvas", "CameraRoll", onOff, flip("CameraRoll"))
	toggleRow(panel, 228, "📱 Qualidade gráfica", "Quality", function(value)
		return if value == "Baixa" then "Baixa (leve)" elseif value == "Media" then "Média" else "Alta"
	end, function()
		local order = { Alta = "Media", Media = "Baixa", Baixa = "Alta" }
		ClientSettings.Set("Quality", order[ClientSettings.Get().Quality] or "Alta")
	end)
	toggleRow(panel, 272, "🐝 Câmera atrás da abelha (V)", "ThirdPerson", onOff, flip("ThirdPerson"))
	toggleRow(panel, 316, "🖱 Sensibilidade do mouse", "Sensitivity", function(value)
		return string.format("%.2g×", tonumber(value) or 1)
	end, cycle("Sensitivity", { 0.5, 0.75, 1, 1.5, 2 }))
	toggleRow(panel, 360, "🧘 Reduzir movimento", "ReducedMotion", onOff, flip("ReducedMotion"))

	-- Códigos de recompensa.
	W.Text("RotuloCodigo", "🎁 Código", UDim2.fromOffset(110, 24), UDim2.fromOffset(20, 414), panel)
	local box = Instance.new("TextBox")
	box.Name = "Codigo"
	box.Size = UDim2.new(1, -270, 0, 36)
	box.Position = UDim2.fromOffset(120, 408)
	box.BackgroundColor3 = Color3.fromRGB(45, 37, 28)
	box.TextColor3 = Theme.Colors.Text
	box.PlaceholderText = "digite aqui"
	box.PlaceholderColor3 = Theme.Colors.TextMuted
	box.Font = Theme.Font
	box.TextSize = 18
	box.ClearTextOnFocus = false
	box.Text = ""
	W.Corner(box, 8)
	box.Parent = panel
	local redeem =
		W.Button("Resgatar", "Resgatar", UDim2.fromOffset(130, 36), UDim2.new(1, -150, 0, 408), panel)
	redeem.Activated:Connect(function()
		if box.Text ~= "" then
			Remotes.Get("RequestCode"):FireServer(box.Text)
			box.Text = ""
		end
	end)

	local close = W.Button(
		"Fechar",
		"Fechar",
		UDim2.new(0, 120, 0, 36),
		UDim2.new(1, -140, 1, -48),
		panel,
		Color3.fromRGB(80, 66, 50)
	)
	close.Modal = true
	close.Activated:Connect(function()
		panel.Visible = false
	end)
	-- Tour de apresentação (também na tecla T).
	local tour = W.Button(
		"Tour",
		"🎬 Tour de apresentação (T)",
		UDim2.new(0, 240, 0, 36),
		UDim2.new(0, 20, 1, -48),
		panel,
		DARK_BUTTON
	)
	tour.Activated:Connect(function()
		panel.Visible = false
		TourController.Play()
	end)
	refs.SettingsPanel = panel

	-- Botão ⚙ ao lado do relógio.
	local gear =
		W.Button("Engrenagem", "⚙", UDim2.fromOffset(36, 36), UDim2.new(0.5, 168, 0, 8), gui, DARK_BUTTON)
	gear.Activated:Connect(function()
		OnboardingController.ToggleSettings()
	end)
end

function OnboardingController.ToggleSettings()
	local panel: Frame = refs.SettingsPanel
	panel.Visible = not panel.Visible
	if panel.Visible then
		renderSettings()
	end
end

-- Ciclo --------------------------------------------------------------------------

local function updateScale()
	local viewport = workspace.CurrentCamera.ViewportSize
	refs.Scale.Scale = math.clamp(math.min(viewport.X / 1366, viewport.Y / 768), 0.55, 1)
end

function OnboardingController:Init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "HUD_Ajuda"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 3
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local scale = Instance.new("UIScale")
	scale.Parent = gui
	refs.Scale = scale
	buildTutorial(gui)
	buildSettings(gui)
	gui.Parent = player:WaitForChild("PlayerGui")
end

function OnboardingController:Start()
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
	ClientSettings.Changed:Connect(renderSettings)
	ContextActionService:BindAction("AbrirConfiguracoes", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			OnboardingController.ToggleSettings()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.P)

	-- O tutorial começa depois da tela de abertura e confere os passos 2x por segundo.
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= 0.5 then
			accumulator = 0
			if not player:GetAttribute("NaAbertura") then
				tickTutorial()
			end
		end
	end)
	updateScale()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	Log.info("OnboardingController", "pronto (P abre as configurações)")
end

return OnboardingController
