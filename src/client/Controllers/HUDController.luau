--[[
	HUDController (cliente)

	Interface inspirada nas imagens de referência:
	- Topo esquerdo: selo hexagonal de nível, título e barra de XP; missão atual
	  com barra de progresso e recompensa; dica do que fazer agora.
	- Topo centro: dia/noite e objetivo de perigo.
	- Topo direito: Mel (conta subindo + pulso), Favos/carga, Néctar, região.
	- Esquerda embaixo: minimapa com bússola, colmeia e Colmeia Real.
	- Centro embaixo: vida, fôlego da arrancada e barra de ações
	  1 Coletar · 2 Colmeia · 3 Clã.
	- Painel "Sua colmeia" com abas (Colmeia · Abelha · Visual), deslizando
	  da direita.
	- Faixas animadas: "Subiu de nível!" e "Missão concluída!".
	- Mira, avisos, flash de dano, tela de derrota e marcadores no mundo.

	O HUD só MOSTRA e PEDE. Todos os números e decisões vêm do servidor.
]]

local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Regions = require(Shared.Regions)
local Remotes = require(Shared.Remotes)

local Theme = require(script.Parent.Parent.UI.Theme)
local W = require(script.Parent.Parent.UI.Widgets)
local FlightController = require(script.Parent.FlightController)

local HUDController = {}

local player = Players.LocalPlayer
local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local state: any = nil
local refs: { [string]: any } = {}

local GREEN = Color3.fromRGB(80, 200, 120)
local ORANGE = Color3.fromRGB(255, 150, 60)
local PURPLE = Color3.fromRGB(170, 90, 255)
local DARK_BUTTON = Color3.fromRGB(60, 50, 38)
local STAMINA = Color3.fromRGB(90, 200, 255)

-- O chat novo do Roblox fica no canto de cima à esquerda e ignora
-- ChatWindowConfiguration.HorizontalAlignment; por isso o selo de nível e a
-- missão começam abaixo dele.
local LEFT_TOP = 140

local PANEL_OPEN = UDim2.new(1, -12, 0.5, 20)
local PANEL_CLOSED = UDim2.new(1, 400, 0.5, 20)

local function formatNumber(n: number): string
	-- 4360 → "4.360"
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1."):reverse()
	if formatted:sub(1, 1) == "." then
		formatted = formatted:sub(2)
	end
	return formatted
end

local function tween(instance: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?)
	local t = TweenService:Create(
		instance,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		goal
	)
	t:Play()
	return t
end

-- Pulso: cresce e volta (usa um UIScale dentro do objeto).
local function pulse(gui: GuiObject, amount: number?)
	local scale = gui:FindFirstChild("Pulso") :: UIScale?
	if not scale then
		local created = Instance.new("UIScale")
		created.Name = "Pulso"
		created.Parent = gui
		scale = created
	end
	local s = scale :: UIScale
	s.Scale = 1 + (amount or 0.12)
	tween(s, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- Construção --------------------------------------------------------------------

local function buildTopLeft(gui: ScreenGui)
	local badge, level = W.HexBadge("SeloNivel", 78, "1", gui)
	badge.Position = UDim2.fromOffset(12, LEFT_TOP + 6)
	refs.Level = level
	refs.LevelBadge = badge

	local header =
		W.Panel("Titulo", UDim2.fromOffset(250, 52), UDim2.fromOffset(84, LEFT_TOP + 14), Vector2.zero, gui)
	refs.Title =
		W.Text("Nome", "ABELHA INICIANTE", UDim2.new(1, -20, 0, 20), UDim2.fromOffset(10, 5), header, {
			TextColor3 = Theme.Colors.Gold,
		})
	refs.XPBar = W.Bar("XP", UDim2.new(1, -20, 0, 16), UDim2.fromOffset(10, 29), Theme.Colors.Gold, header)
	refs.XPText = W.Text("Numeros", "0 / 100", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), refs.XPBar, {
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Theme.Colors.Text,
		TextStrokeTransparency = 0.5,
		ZIndex = 2,
	})

	-- Missão (vem do QuestService).
	local mission =
		W.Panel("Missao", UDim2.fromOffset(322, 78), UDim2.fromOffset(12, LEFT_TOP + 92), Vector2.zero, gui)
	refs.MissionPanel = mission
	local icon = W.Hex("Icone", 30, Theme.Colors.Gold, mission)
	icon.Position = UDim2.fromOffset(10, 10)
	refs.MissionNumber = W.Text("Numero", "1", UDim2.fromOffset(26, 18), UDim2.fromOffset(0, 6), icon, {
		Size = UDim2.fromScale(1, 0.6),
		Position = UDim2.fromScale(0, 0.2),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Theme.Colors.Panel,
		ZIndex = 2,
	})
	W.Text("Rotulo", "MISSÃO", UDim2.new(1, -60, 0, 14), UDim2.fromOffset(48, 6), mission, {
		TextColor3 = Theme.Colors.Gold,
	})
	refs.Mission = W.Text("Texto", "", UDim2.new(1, -60, 0, 20), UDim2.fromOffset(48, 22), mission, {
		TextWrapped = true,
	})
	refs.MissionBar =
		W.Bar("Progresso", UDim2.new(1, -150, 0, 14), UDim2.fromOffset(48, 50), Theme.Colors.Gold, mission)
	refs.MissionCount =
		W.Text("Contagem", "", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), refs.MissionBar, {
			TextXAlignment = Enum.TextXAlignment.Center,
			TextStrokeTransparency = 0.5,
			ZIndex = 2,
		})
	refs.MissionReward = W.Text("Premio", "", UDim2.fromOffset(92, 16), UDim2.new(1, -98, 0, 49), mission, {
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Theme.Colors.Gold,
		Font = Theme.FontRegular,
	})

	-- Dica de contexto (sem painel, discreta).
	refs.Hint = W.Text("Dica", "", UDim2.fromOffset(322, 18), UDim2.fromOffset(16, LEFT_TOP + 176), gui, {
		Font = Theme.FontRegular,
		TextColor3 = Theme.Colors.Text,
		TextStrokeTransparency = 0.4,
	})
end

local function buildTopCenter(gui: ScreenGui)
	local clock =
		W.Panel("Relogio", UDim2.fromOffset(320, 36), UDim2.new(0.5, 0, 0, 8), Vector2.new(0.5, 0), gui)
	refs.Clock = W.Text("Hora", "", UDim2.new(1, -20, 1, -10), UDim2.fromOffset(10, 5), clock, {
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local objective =
		W.Panel("Objetivo", UDim2.fromOffset(320, 34), UDim2.new(0.5, 0, 0, 50), Vector2.new(0.5, 0), gui)
	objective.Visible = false
	refs.Objective = objective
	refs.ObjectiveText = W.Text("Texto", "", UDim2.new(1, -20, 1, -10), UDim2.fromOffset(10, 5), objective, {
		TextXAlignment = Enum.TextXAlignment.Center,
	})
end

local function buildTopRight(gui: ScreenGui)
	local x = UDim2.new(1, -12, 0, 0)
	local honey, honeyText = W.Chip(
		"Mel",
		UDim2.fromOffset(230, 46),
		x + UDim2.fromOffset(0, 8),
		Vector2.new(1, 0),
		Theme.Colors.Gold,
		gui
	)
	honeyText.TextColor3 = Theme.Colors.Gold
	honeyText.Size = UDim2.new(1, -90, 0.62, 0)
	refs.HoneyChip = honey
	refs.Honey = honeyText
	refs.HoneyPlus = W.Button("Mais", "+", UDim2.fromOffset(30, 30), UDim2.new(1, -38, 0.5, -15), honey)

	local combs, combsText = W.Chip(
		"Favos",
		UDim2.fromOffset(230, 46),
		x + UDim2.fromOffset(0, 60),
		Vector2.new(1, 0),
		Theme.Colors.Gold,
		gui
	)
	refs.CombsChip = combs
	refs.Combs = combsText
	refs.CarryBar = W.Bar("Carga", UDim2.new(1, -54, 0, 4), UDim2.new(0, 44, 1, -8), Theme.Colors.Gold, combs)

	local nectar, nectarText = W.Chip(
		"Nectar",
		UDim2.fromOffset(230, 40),
		x + UDim2.fromOffset(0, 112),
		Vector2.new(1, 0),
		Color3.fromRGB(255, 220, 90),
		gui
	)
	refs.NectarChip = nectar
	refs.Nectar = nectarText

	local region, regionText, regionIcon = W.Chip(
		"Regiao",
		UDim2.fromOffset(230, 40),
		x + UDim2.fromOffset(0, 158),
		Vector2.new(1, 0),
		GREEN,
		gui
	)
	refs.Region = region
	refs.RegionText = regionText
	refs.RegionIcon = regionIcon
end

local function buildMinimap(gui: ScreenGui)
	local size = if isTouch then 130 else 180
	local position = if isTouch then UDim2.new(1, -12 - size, 0, 210) else UDim2.new(0, 12, 1, -size - 56)

	local map = Instance.new("Frame")
	map.Name = "Minimapa"
	map.Size = UDim2.fromOffset(size, size)
	map.Position = position
	map.BackgroundColor3 = Color3.fromRGB(40, 70, 40)
	map.BackgroundTransparency = 0.2
	map.ClipsDescendants = true
	W.Corner(map, size)
	W.Stroke(map, Theme.Colors.Gold, 3)
	map.Parent = gui
	refs.Map = map
	refs.MapRadius = size / 2
	refs.MapScale = 640 / (size / 2) -- studs por pixel (mostra ~640 studs de raio)

	-- Anéis das áreas protegidas (centro do mundo).
	local function ring(name: string, radiusStuds: number, color: Color3): Frame
		local r = Instance.new("Frame")
		r.Name = name
		r.AnchorPoint = Vector2.new(0.5, 0.5)
		r.BackgroundTransparency = 1
		W.Corner(r, 9999)
		local stroke = W.Stroke(r, color, 1.5)
		stroke.Transparency = 0.4
		r:SetAttribute("Radius", radiusStuds)
		r.Parent = map
		return r
	end
	refs.MapRings = {
		ring("Colmeias", Config.Regions.HiveRadius, Theme.Colors.Gold),
		ring("Seguro", Config.Regions.SafeRadius, GREEN),
	}

	-- Sua colmeia: hexágono de verdade (o caractere ⬢ virava um quadradinho).
	local hive = W.Hex("Colmeia", 16, Theme.Colors.Gold, map)
	hive.AnchorPoint = Vector2.new(0.5, 0.5)
	hive.ZIndex = 3
	refs.MapHive = hive

	refs.MapRoyal = W.Text("Real", "👑", UDim2.fromOffset(18, 18), UDim2.fromScale(0.5, 0.5), map, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	})

	-- Você: bolinha laranja com "bico" apontando para onde a câmera olha.
	local me = Instance.new("Frame")
	me.Name = "Voce"
	me.AnchorPoint = Vector2.new(0.5, 0.5)
	me.Position = UDim2.fromScale(0.5, 0.5)
	me.Size = UDim2.fromOffset(20, 20)
	me.BackgroundTransparency = 1
	me.ZIndex = 4
	me.Parent = map
	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.6)
	dot.Size = UDim2.fromOffset(11, 11)
	dot.BackgroundColor3 = ORANGE
	dot.BorderSizePixel = 0
	dot.ZIndex = 5
	W.Corner(dot, 6)
	W.Stroke(dot, Color3.new(1, 1, 1), 1.5)
	dot.Parent = me
	local nose = Instance.new("Frame")
	nose.AnchorPoint = Vector2.new(0.5, 0.5)
	nose.Position = UDim2.fromScale(0.5, 0.22)
	nose.Size = UDim2.fromOffset(7, 7)
	nose.Rotation = 45
	nose.BackgroundColor3 = ORANGE
	nose.BorderSizePixel = 0
	nose.ZIndex = 5
	nose.Parent = me
	refs.MapArrow = me

	local letters = {
		{ "N", UDim2.new(0.5, 0, 0, 10) },
		{ "S", UDim2.new(0.5, 0, 1, -10) },
		{ "L", UDim2.new(1, -10, 0.5, 0) },
		{ "O", UDim2.new(0, 10, 0.5, 0) },
	}
	for _, entry in letters do
		W.Text(entry[1], entry[1], UDim2.fromOffset(16, 16), entry[2], map, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 6,
		})
	end

	local hiveChip = W.Panel(
		"DistanciaColmeia",
		UDim2.fromOffset(size, 34),
		position + UDim2.fromOffset(0, size + 8),
		Vector2.zero,
		gui
	)
	refs.HiveDistance =
		W.Text("Texto", "Sua colmeia", UDim2.new(1, -16, 1, -10), UDim2.fromOffset(8, 5), hiveChip, {
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = Theme.Colors.Gold,
		})
end

local ACTIONS = {
	{ Key = "1", Name = "Coletar", Icon = "🌼" },
	{ Key = "2", Name = "Colmeia", Icon = "🍯" },
	{ Key = "3", Name = "Clã", Icon = "👥" },
}

local function buildBottomCenter(gui: ScreenGui)
	local bar = Instance.new("Frame")
	bar.Name = "Acoes"
	bar.BackgroundTransparency = 1
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -10)
	bar.Size = UDim2.fromOffset(3 * 86, 96)
	bar.Parent = gui
	refs.ActionButtons = {}
	for i, action in ACTIONS do
		local slot = Instance.new("TextButton")
		slot.Name = action.Name
		slot.Text = ""
		slot.BackgroundTransparency = 1
		slot.Size = UDim2.fromOffset(78, 96)
		slot.Position = UDim2.fromOffset((i - 1) * 86, 0)
		slot.Parent = bar
		local hex, label = W.HexBadge("Hex", 70, action.Icon, slot)
		hex.Position = UDim2.fromOffset(9, 0)
		label.TextColor3 = Theme.Colors.Gold
		W.Text("Nome", action.Name, UDim2.new(1, 0, 0, 20), UDim2.fromOffset(0, 72), slot, {
			TextXAlignment = Enum.TextXAlignment.Center,
			TextStrokeTransparency = 0.4,
		})
		if not isTouch then
			local keyChip =
				W.Panel("Tecla", UDim2.fromOffset(20, 20), UDim2.fromOffset(29, -12), Vector2.zero, slot)
			W.Text("K", action.Key, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), keyChip, {
				TextXAlignment = Enum.TextXAlignment.Center,
			})
		end
		slot.MouseEnter:Connect(function()
			tween(hex, 0.15, { Position = UDim2.fromOffset(9, -6) })
		end)
		slot.MouseLeave:Connect(function()
			tween(hex, 0.15, { Position = UDim2.fromOffset(9, 0) })
		end)
		refs.ActionButtons[i] = slot
	end

	local health =
		W.Panel("Vida", UDim2.fromOffset(300, 34), UDim2.new(0.5, 0, 1, -116), Vector2.new(0.5, 1), gui)
	W.Text("Coracao", "❤", UDim2.fromOffset(24, 24), UDim2.fromOffset(8, 5), health, {
		TextColor3 = Theme.Colors.Health,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	refs.HealthText =
		W.Text("Texto", "Vida 100/100", UDim2.fromOffset(110, 20), UDim2.fromOffset(38, 7), health)
	refs.HealthBar =
		W.Bar("Barra", UDim2.new(1, -184, 0, 12), UDim2.fromOffset(150, 11), Theme.Colors.Health, health)
	refs.Shield = W.Text("Escudo", "🛡", UDim2.fromOffset(22, 22), UDim2.new(1, -6, 0, 6), health, {
		AnchorPoint = Vector2.new(1, 0),
		Visible = false,
	})

	-- Fôlego da arrancada: só aparece quando está sendo usado/recuperado.
	local stamina = Instance.new("CanvasGroup")
	stamina.Name = "Folego"
	stamina.AnchorPoint = Vector2.new(0.5, 1)
	stamina.Position = UDim2.new(0.5, 0, 1, -156)
	stamina.Size = UDim2.fromOffset(220, 22)
	stamina.BackgroundTransparency = 1
	stamina.GroupTransparency = 1
	stamina.Parent = gui
	W.Text(
		"Rotulo",
		if isTouch then "Fôlego" else "Fôlego  [Shift]",
		UDim2.fromOffset(110, 12),
		UDim2.fromOffset(0, 0),
		stamina,
		{
			Font = Theme.FontRegular,
			TextStrokeTransparency = 0.4,
		}
	)
	refs.StaminaBar = W.Bar("Barra", UDim2.new(1, 0, 0, 7), UDim2.fromOffset(0, 14), STAMINA, stamina)
	refs.Stamina = stamina

	local rare =
		W.Panel("FavoRaro", UDim2.fromOffset(200, 44), UDim2.new(1, -12, 0.62, 0), Vector2.new(1, 0), gui)
	local rareIcon = W.Hex("Icone", 28, PURPLE, rare)
	rareIcon.Position = UDim2.fromOffset(10, 8)
	refs.RareText = W.Text("Texto", "", UDim2.new(1, -56, 0, 24), UDim2.fromOffset(46, 10), rare)
	refs.Rare = rare
	rare.Visible = false
end

-- Painel da colmeia com abas --------------------------------------------------------

local TABS = { "Colmeia", "Abelha", "Visual" }

local function sectionLabel(text: string, y: number, parent: Instance): TextLabel
	return W.Text("Secao", text, UDim2.new(1, -28, 0, 18), UDim2.fromOffset(14, y), parent, {
		TextColor3 = Theme.Colors.TextMuted,
	})
end

local function buildHiveTab(page: Frame)
	refs.ColonyLine = W.Text("Colonia", "", UDim2.new(1, -28, 0, 20), UDim2.fromOffset(14, 0), page, {
		TextColor3 = Theme.Colors.Gold,
	})

	refs.CellsText = W.Text("Celulas", "", UDim2.new(1, -28, 0, 18), UDim2.fromOffset(14, 28), page)
	refs.CellsBar =
		W.Bar("BarraCelulas", UDim2.new(1, -28, 0, 10), UDim2.fromOffset(14, 50), Theme.Colors.Gold, page)

	refs.StoredText = W.Text("Estoque", "", UDim2.new(1, -28, 0, 18), UDim2.fromOffset(14, 72), page)
	refs.StoredBar = W.Bar("BarraEstoque", UDim2.new(1, -28, 0, 10), UDim2.fromOffset(14, 94), ORANGE, page)
	refs.CollectButton =
		W.Button("ColetarMel", "Recolher mel", UDim2.new(1, -28, 0, 42), UDim2.fromOffset(14, 112), page)

	refs.DeliverButton =
		W.Button("Entregar", "Entregar favos", UDim2.new(1, -28, 0, 42), UDim2.fromOffset(14, 164), page)
	refs.ExpandButton = W.Button(
		"Expandir",
		"Expandir",
		UDim2.new(1, -28, 0, 42),
		UDim2.fromOffset(14, 216),
		page,
		DARK_BUTTON
	)
	refs.NextTitle = W.Text("ProximoTitulo", "", UDim2.new(1, -28, 0, 34), UDim2.fromOffset(14, 268), page, {
		Font = Theme.FontRegular,
		TextColor3 = Theme.Colors.TextMuted,
		TextWrapped = true,
		TextScaled = false,
		TextSize = 14,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
end

local UPGRADE_ICONS = { "⚡", "🎒", "❤️" }
local UPGRADE_COLORS = { Color3.fromRGB(60, 140, 255), Theme.Colors.Gold, Color3.fromRGB(220, 60, 70) }

local function buildBeeTab(page: Frame)
	sectionLabel("Melhorias", 0, page)
	refs.UpgradeSlots = {}
	for i = 1, 3 do
		local slot = Instance.new("TextButton")
		slot.Name = `Melhoria{i}`
		slot.Text = ""
		slot.BackgroundColor3 = Color3.fromRGB(45, 37, 28)
		slot.BackgroundTransparency = 0.2
		slot.AutoButtonColor = true
		slot.Size = UDim2.fromOffset(104, 128)
		slot.Position = UDim2.fromOffset(14 + (i - 1) * 112, 22)
		W.Corner(slot, 10)
		slot.Parent = page
		local hex = W.Hex("Hex", 54, UPGRADE_COLORS[i], slot)
		hex.Position = UDim2.fromOffset(29, 6)
		W.Text("Simbolo", UPGRADE_ICONS[i], UDim2.fromOffset(46, 30), UDim2.fromOffset(29, 18), slot, {
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 2,
		})
		local name = W.Text("Nome", "", UDim2.new(1, -8, 0, 18), UDim2.fromOffset(4, 64), slot, {
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		local pips = {}
		for p = 1, 5 do
			local pip = Instance.new("Frame")
			pip.Size = UDim2.fromOffset(14, 6)
			pip.Position = UDim2.fromOffset(13 + (p - 1) * 16, 88)
			pip.BorderSizePixel = 0
			pip.BackgroundColor3 = Color3.fromRGB(70, 60, 50)
			W.Corner(pip, 3)
			pip.Parent = slot
			pips[p] = pip
		end
		local cost = W.Text("Custo", "", UDim2.new(1, -8, 0, 16), UDim2.fromOffset(4, 102), slot, {
			TextXAlignment = Enum.TextXAlignment.Center,
			Font = Theme.FontRegular,
			TextColor3 = Theme.Colors.TextMuted,
		})
		refs.UpgradeSlots[i] =
			{ Button = slot, Name = name, Pips = pips, Cost = cost, Color = UPGRADE_COLORS[i] }
	end

	sectionLabel("Especialidade", 162, page)
	refs.SpecialtyCost = W.Text("Custo", "", UDim2.fromOffset(170, 16), UDim2.new(1, -184, 0, 163), page, {
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Theme.FontRegular,
		TextColor3 = Theme.Colors.TextMuted,
	})
	refs.SpecialtyRows = {}
	for i = 1, 3 do
		local row = Instance.new("TextButton")
		row.Name = `Especialidade{i}`
		row.Text = ""
		row.AutoButtonColor = true
		row.BackgroundColor3 = DARK_BUTTON
		row.Size = UDim2.new(1, -28, 0, 50)
		row.Position = UDim2.fromOffset(14, 184 + (i - 1) * 56)
		W.Corner(row, 8)
		row.Parent = page
		local title = W.Text("Nome", "", UDim2.new(1, -20, 0, 18), UDim2.fromOffset(10, 5), row)
		local description = W.Text("Descricao", "", UDim2.new(1, -20, 0, 20), UDim2.fromOffset(10, 25), row, {
			Font = Theme.FontRegular,
			TextScaled = false,
			TextSize = 13,
			TextWrapped = true,
			TextColor3 = Theme.Colors.TextMuted,
		})
		refs.SpecialtyRows[i] = { Button = row, Title = title, Description = description }
	end
end

local function buildVisualTab(page: Frame)
	sectionLabel("Acessórios (só visual, comprados com mel)", 0, page)
	refs.CosmeticButtons = {}
	for i = 1, 3 do
		refs.CosmeticButtons[i] = W.Button(
			`Acessorio{i}`,
			"",
			UDim2.new(1, -28, 0, 48),
			UDim2.fromOffset(14, 26 + (i - 1) * 58),
			page,
			DARK_BUTTON
		)
	end
end

local function buildHivePanel(gui: ScreenGui)
	local panel = W.Panel("SuaColmeia", UDim2.fromOffset(372, 470), PANEL_CLOSED, Vector2.new(1, 0.5), gui)
	panel.Visible = false
	panel.ZIndex = 5
	refs.HivePanel = panel

	local icon = W.Hex("Icone", 30, Theme.Colors.Gold, panel)
	icon.Position = UDim2.fromOffset(14, 12)
	W.Text("Titulo", "Sua colmeia", UDim2.new(1, -70, 0, 28), UDim2.fromOffset(54, 13), panel)

	refs.Tabs = {}
	refs.Pages = {}
	local tabWidth = (372 - 28 - 2 * 6) / #TABS
	for i, name in TABS do
		local tab = W.Button(
			`Aba{name}`,
			name,
			UDim2.fromOffset(tabWidth, 34),
			UDim2.fromOffset(14 + (i - 1) * (tabWidth + 6), 52),
			panel,
			DARK_BUTTON
		)
		refs.Tabs[name] = tab

		local page = Instance.new("Frame")
		page.Name = `Pagina{name}`
		page.BackgroundTransparency = 1
		page.Position = UDim2.fromOffset(0, 98)
		page.Size = UDim2.new(1, 0, 1, -98 - 56)
		page.Visible = false
		page.Parent = panel
		refs.Pages[name] = page
	end
	buildHiveTab(refs.Pages.Colmeia)
	buildBeeTab(refs.Pages.Abelha)
	buildVisualTab(refs.Pages.Visual)

	-- Modal = true solta o mouse enquanto o painel está aberto (primeira pessoa).
	local close = W.Button(
		"Fechar",
		if isTouch then "Fechar" else "Fechar  [2]",
		UDim2.new(1, -28, 0, 36),
		UDim2.new(0, 14, 1, -48),
		panel,
		Color3.fromRGB(80, 66, 50)
	)
	close.Modal = true
	refs.HiveClose = close
end

local function buildOverlays(gui: ScreenGui)
	-- Mira.
	local cross = Instance.new("Frame")
	cross.Name = "Mira"
	cross.AnchorPoint = Vector2.new(0.5, 0.5)
	cross.Position = UDim2.fromScale(0.5, 0.5)
	cross.Size = UDim2.fromOffset(16, 16)
	cross.BackgroundTransparency = 1
	W.Corner(cross, 8)
	local crossStroke = W.Stroke(cross, Color3.new(1, 1, 1), 1.5)
	crossStroke.Transparency = 0.3
	cross.Parent = gui

	-- Avisos rápidos.
	local toast =
		W.Panel("Aviso", UDim2.fromOffset(460, 40), UDim2.new(0.5, 0, 0, 92), Vector2.new(0.5, 0), gui)
	toast.Visible = false
	refs.Toast = toast
	refs.ToastText = W.Text("Texto", "", UDim2.new(1, -20, 1, -10), UDim2.fromOffset(10, 5), toast, {
		TextXAlignment = Enum.TextXAlignment.Center,
	})

	-- Faixa grande: "Subiu de nível!" / "Missão concluída!".
	local banner =
		W.Panel("Faixa", UDim2.fromOffset(440, 86), UDim2.new(0.5, 0, 0, -300), Vector2.new(0.5, 0), gui)
	banner.ZIndex = 8
	banner.Visible = false
	local bannerStroke = banner:FindFirstChildOfClass("UIStroke")
	if bannerStroke then
		bannerStroke.Color = Theme.Colors.Gold
		bannerStroke.Thickness = 3
	end
	local bannerHex = W.Hex("Icone", 62, Theme.Colors.Gold, banner)
	bannerHex.Position = UDim2.fromOffset(14, 12)
	refs.BannerIcon = bannerHex
	refs.BannerIconText =
		W.Text("Simbolo", "", UDim2.fromScale(0.7, 0.6), UDim2.fromScale(0.15, 0.2), bannerHex, {
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = Theme.Colors.Panel,
			ZIndex = 9,
		})
	refs.BannerTitle = W.Text("Titulo", "", UDim2.new(1, -100, 0, 34), UDim2.fromOffset(88, 12), banner, {
		TextColor3 = Theme.Colors.Gold,
		ZIndex = 9,
	})
	refs.BannerText = W.Text("Texto", "", UDim2.new(1, -100, 0, 24), UDim2.fromOffset(88, 50), banner, {
		Font = Theme.FontRegular,
		ZIndex = 9,
	})
	refs.Banner = banner

	-- "+25" que sobe ao lado do Mel.
	refs.HoneyGain = W.Text("GanhoMel", "", UDim2.fromOffset(120, 26), UDim2.new(1, -250, 0, 18), gui, {
		AnchorPoint = Vector2.new(1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Theme.Colors.Gold,
		TextStrokeTransparency = 0.3,
		TextTransparency = 1,
	})

	-- Flash vermelho nas bordas ao levar dano.
	local hurt = Instance.new("Frame")
	hurt.Name = "Dano"
	hurt.Size = UDim2.fromScale(1, 1)
	hurt.BackgroundTransparency = 1
	hurt.BorderSizePixel = 0
	local hurtStroke = Instance.new("UIStroke")
	hurtStroke.Color = Theme.Colors.Danger
	hurtStroke.Thickness = 40
	hurtStroke.Transparency = 1
	hurtStroke.Parent = hurt
	hurt.Parent = gui
	refs.HurtStroke = hurtStroke

	-- Tela de derrota.
	local death = Instance.new("Frame")
	death.Name = "Derrota"
	death.Size = UDim2.fromScale(1, 1)
	death.BackgroundColor3 = Color3.fromRGB(40, 5, 10)
	death.BackgroundTransparency = 0.35
	death.Visible = false
	death.ZIndex = 10
	death.Parent = gui
	refs.Death = death
	W.Text("Titulo", "Você foi derrotado", UDim2.new(0.6, 0, 0, 56), UDim2.new(0.2, 0, 0.3, 0), death, {
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Theme.Colors.Danger,
		ZIndex = 11,
	})
	refs.DeathText = W.Text("Detalhes", "", UDim2.new(0.6, 0, 0, 100), UDim2.new(0.2, 0, 0.3, 70), death, {
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = true,
		Font = Theme.FontRegular,
		ZIndex = 11,
	})
	refs.DeathTimer = W.Text("Tempo", "", UDim2.new(0.6, 0, 0, 30), UDim2.new(0.2, 0, 0.3, 182), death, {
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Theme.Colors.Gold,
		ZIndex = 11,
	})
end

local function worldMarker(name: string, color: Color3, offsetY: number): (BasePart, BillboardGui, TextLabel)
	local anchor = Instance.new("Part")
	anchor.Name = name
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Parent = workspace.CurrentCamera

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(190, 36)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.StudsOffset = Vector3.new(0, offsetY, 0)
	gui.Adornee = anchor
	gui.Enabled = false
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Theme.Font
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
	-- BillboardGui fica direto no PlayerGui (dentro de ScreenGui não aparece).
	gui.Parent = player:WaitForChild("PlayerGui")
	return anchor, gui, label
end

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "HUD_Abelhas"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local scale = Instance.new("UIScale")
	scale.Parent = gui
	refs.Scale = scale

	buildTopLeft(gui)
	buildTopCenter(gui)
	buildTopRight(gui)
	buildMinimap(gui)
	buildBottomCenter(gui)
	buildHivePanel(gui)
	buildOverlays(gui)

	gui.Parent = player:WaitForChild("PlayerGui")
	refs.Gui = gui

	refs.HiveAnchor, refs.HiveMarker, refs.HiveMarkerLabel =
		worldMarker("MarcadorColmeia", Theme.Colors.Gold, 40)
	refs.RoyalAnchor, refs.RoyalMarker, refs.RoyalMarkerLabel =
		worldMarker("MarcadorReal", Theme.Colors.Gold, 120)
	refs.RoyalAnchor.Position = Config.Map.RoyalHive.Position
		+ Vector3.new(0, Config.Map.RoyalHive.PlateauHeight, 0)
	refs.RoyalMarker.Enabled = true
end

-- Faixa animada -------------------------------------------------------------------

local bannerToken = 0
local function showBanner(title: string, text: string, symbol: string, color: Color3)
	bannerToken += 1
	local token = bannerToken
	local banner: Frame = refs.Banner
	refs.BannerTitle.Text = title
	refs.BannerTitle.TextColor3 = color
	refs.BannerText.Text = text
	refs.BannerIconText.Text = symbol
	W.SetHexColor(refs.BannerIcon, color)
	local stroke = banner:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = color
	end
	banner.Position = UDim2.new(0.5, 0, 0, -300)
	banner.Visible = true
	tween(banner, 0.45, { Position = UDim2.new(0.5, 0, 0, 140) }, Enum.EasingStyle.Back)
	pulse(refs.BannerIcon, 0.3)
	task.delay(2.8, function()
		if token == bannerToken then
			tween(banner, 0.35, { Position = UDim2.new(0.5, 0, 0, -300) }).Completed:Connect(function()
				if token == bannerToken then
					banner.Visible = false
				end
			end)
		end
	end)
end

-- Atualização ---------------------------------------------------------------------

local function hintFor(s): string
	if s.Building then
		local needed = math.ceil((100 - s.Building.Progress) / (100 / Config.Hive.CellCombCost) - 1e-6)
		return `🔨 Construindo célula {math.floor(s.Building.Progress)}% · faltam {needed} pts de favo`
	elseif s.CarryWeight >= s.Capacity then
		return "🎒 Carga cheia! Volte à colmeia e entregue no pote dourado"
	elseif (s.HiveHoney or 0) >= math.max(10, (s.HiveStorage or 0) * 0.5) then
		return `🍯 Sua colmeia fez {s.HiveHoney} de mel · aperte 2 para recolher`
	elseif s.Honey >= s.CellHoneyCost and s.CellsCompleted < s.CellsMax then
		return `✨ Você tem mel para uma nova célula ({s.CellHoneyCost})`
	elseif s.CarryWeight > 0 then
		return `🐝 Carregando {s.CarryWeight}/{s.Capacity} · leve à colmeia`
	end
	return "🌼 Colete néctar nas flores e favos no campo e no bosque"
end

local function renderHivePanel()
	local s = state
	if not s then
		return
	end

	-- Aba Colmeia.
	refs.ColonyLine.Text = `{s.ColonyName or "Sua colônia"} · {s.Title}`
	refs.CellsText.Text = `Células prontas: {s.CellsCompleted}/{s.CellsMax}`
	W.SetBar(refs.CellsBar, s.CellsCompleted / math.max(1, s.CellsMax))
	local stored, storage = s.HiveHoney or 0, s.HiveStorage or 0
	refs.StoredText.Text = `Mel fabricado na colmeia: {stored}/{storage}`
	W.SetBar(refs.StoredBar, if storage > 0 then stored / storage else 0)
	refs.CollectButton.Text = if stored > 0 then `Recolher {stored} de mel` else "Nada para recolher ainda"
	refs.CollectButton.BackgroundColor3 = if stored > 0 then Theme.Colors.Gold else DARK_BUTTON
	refs.CollectButton.TextColor3 = if stored > 0 then Theme.Colors.Panel else Theme.Colors.TextMuted

	local hasCargo = s.CarryWeight > 0
	refs.DeliverButton.Text = if hasCargo
		then `Entregar carga ({s.CarryWeight})`
		else "Sem carga para entregar"
	refs.DeliverButton.BackgroundColor3 = if hasCargo then Theme.Colors.Gold else DARK_BUTTON
	refs.DeliverButton.TextColor3 = if hasCargo then Theme.Colors.Panel else Theme.Colors.TextMuted

	local canExpand = s.Building == nil and s.CellsCompleted < s.CellsMax
	local affordable = canExpand and s.Honey >= s.CellHoneyCost
	refs.ExpandButton.Text = if s.Building
		then `Construindo {math.floor(s.Building.Progress)}%`
		elseif canExpand then `Nova célula · {s.CellHoneyCost} mel`
		else "Colmeia completa"
	refs.ExpandButton.BackgroundColor3 = if affordable then Theme.Colors.Gold else DARK_BUTTON
	refs.ExpandButton.TextColor3 = if affordable then Theme.Colors.Panel else Theme.Colors.Text
	refs.NextTitle.Text = if s.NextTitle
		then `Próximo título → {s.NextTitle}`
		else "Você chegou ao título máximo!"

	-- Aba Abelha: melhorias.
	for i, upgrade in s.Upgrades or {} do
		local slot = refs.UpgradeSlots[i]
		if slot then
			slot.Name.Text = upgrade.DisplayName
			for p, pip in slot.Pips do
				pip.BackgroundColor3 = if p <= upgrade.Level then slot.Color else Color3.fromRGB(70, 60, 50)
			end
			slot.Cost.Text = if upgrade.Cost then `{formatNumber(upgrade.Cost)} mel` else "Máximo"
			slot.Cost.TextColor3 = if upgrade.Cost and s.Honey >= upgrade.Cost
				then Theme.Colors.Gold
				else Theme.Colors.TextMuted
		end
	end

	-- Aba Abelha: especialidade.
	local specialty = s.Specialty
	if specialty then
		refs.SpecialtyCost.Text = if specialty.Current
			then `trocar custa {specialty.ChangeCost} mel`
			else "a primeira é grátis!"
		for i, option in specialty.Options do
			local row = refs.SpecialtyRows[i]
			if row then
				row.Title.Text = if option.Active then `✓ {option.DisplayName}` else option.DisplayName
				row.Description.Text = option.Description
				row.Button.BackgroundColor3 = if option.Active then Theme.Colors.Gold else DARK_BUTTON
				row.Title.TextColor3 = if option.Active then Theme.Colors.Panel else Theme.Colors.Text
				row.Description.TextColor3 = if option.Active
					then Color3.fromRGB(70, 50, 20)
					else Theme.Colors.TextMuted
			end
		end
	end

	-- Aba Visual.
	for i, cosmetic in s.Cosmetics or {} do
		local button = refs.CosmeticButtons[i]
		if button then
			if cosmetic.Owned then
				button.Text = if cosmetic.Equipped
					then `✓ {cosmetic.DisplayName} · usando`
					else `{cosmetic.DisplayName} · vestir`
				button.BackgroundColor3 = if cosmetic.Equipped then Theme.Colors.Gold else DARK_BUTTON
				button.TextColor3 = if cosmetic.Equipped then Theme.Colors.Panel else Theme.Colors.Text
			else
				button.Text = `{cosmetic.DisplayName} · {cosmetic.Price} mel`
				button.BackgroundColor3 = DARK_BUTTON
				button.TextColor3 = if s.Honey >= cosmetic.Price
					then Theme.Colors.Gold
					else Theme.Colors.TextMuted
			end
		end
	end
end

local displayedHoney: number? = nil
local targetHoney = 0
local lastLevel: number? = nil
local lastQuest: any = nil

local function render()
	local s = state
	if not s then
		return
	end

	-- Subiu de nível?
	local level = s.Level or 1
	if lastLevel and level > lastLevel then
		showBanner("SUBIU DE NÍVEL!", `Agora você é nível {level}`, tostring(level), Theme.Colors.Gold)
		pulse(refs.LevelBadge, 0.3)
	end
	lastLevel = level

	-- Missão concluída?
	local quest = s.Quest
	if lastQuest and quest and quest.Number > lastQuest.Number then
		showBanner(
			"MISSÃO CONCLUÍDA!",
			`{lastQuest.Text} · +{lastQuest.Honey} mel · +{lastQuest.XP} XP`,
			"✓",
			GREEN
		)
	end
	lastQuest = quest

	refs.Level.Text = tostring(level)
	refs.Title.Text = string.upper(s.Title)
	if s.XPNext and s.XPNext > 0 then
		W.SetBar(refs.XPBar, s.XPInLevel / s.XPNext)
		refs.XPText.Text = `{formatNumber(s.XPInLevel)} / {formatNumber(s.XPNext)}`
	end

	if quest then
		refs.MissionNumber.Text = tostring(quest.Number)
		refs.Mission.Text = quest.Text
		W.SetBar(refs.MissionBar, quest.Progress / math.max(1, quest.Goal))
		refs.MissionCount.Text = `{quest.Progress}/{quest.Goal}`
		refs.MissionReward.Text = `+{quest.Honey} mel`
	end
	refs.Hint.Text = hintFor(s)

	-- Mel com contador subindo.
	if displayedHoney == nil then
		displayedHoney = s.Honey
	elseif s.Honey > targetHoney then
		local gain = s.Honey - targetHoney
		pulse(refs.HoneyChip)
		local label: TextLabel = refs.HoneyGain
		label.Text = `+{formatNumber(gain)}`
		label.Position = UDim2.new(1, -250, 0, 18)
		label.TextTransparency = 0
		tween(label, 1.2, { Position = UDim2.new(1, -250, 0, -4), TextTransparency = 1 })
	end
	targetHoney = s.Honey

	local combCount = 0
	for _, amount in s.Combs do
		combCount += amount
	end
	local previousCombs = refs.LastCombCount
	if previousCombs and combCount > previousCombs then
		pulse(refs.CombsChip)
	end
	refs.LastCombCount = combCount
	refs.Combs.Text = `Favos {combCount}  ·  carga {s.CarryWeight}/{s.Capacity}`
	local fraction = if s.Capacity > 0 then s.CarryWeight / s.Capacity else 0
	W.SetBar(refs.CarryBar, fraction, if fraction >= 1 then Theme.Colors.Danger else Theme.Colors.Gold)
	if refs.LastNectar and s.Nectar > refs.LastNectar then
		pulse(refs.NectarChip)
	end
	refs.LastNectar = s.Nectar
	refs.Nectar.Text = `Néctar {s.Nectar}`

	local rare = s.Combs.Raro or 0
	refs.Rare.Visible = rare > 0
	refs.RareText.Text = `Favo raro: {rare}`

	if s.HivePosition then
		refs.HiveAnchor.Position = s.HivePosition
		refs.HiveMarker.Enabled = true
	end

	if refs.HivePanel.Visible then
		renderHivePanel()
	end
end

local function renderRegion()
	local region = player:GetAttribute("Region")
	local info = if typeof(region) == "string" then Regions.Info[region] else nil
	if not info then
		refs.Region.Visible = false
		return
	end
	local changed = refs.Region.Visible and refs.RegionText.Text ~= info.Label
	refs.Region.Visible = true
	refs.RegionText.Text = info.Label
	local color = if info.Protected then GREEN elseif info.PvP then Theme.Colors.Danger else ORANGE
	refs.RegionText.TextColor3 = color
	W.SetHexColor(refs.RegionIcon, color)
	if changed then
		pulse(refs.Region, 0.15)
	end
end

local function renderHealth()
	local health = player:GetAttribute("Health")
	local max = player:GetAttribute("MaxHealth")
	if typeof(health) == "number" and typeof(max) == "number" and max > 0 then
		refs.HealthText.Text = `Vida {math.floor(health)}/{math.floor(max)}`
		W.SetBar(refs.HealthBar, health / max)
	end
	local protectedUntil = player:GetAttribute("ProtectedUntil")
	refs.Shield.Visible = typeof(protectedUntil) == "number" and protectedUntil > workspace:GetServerTimeNow()
end

local function renderClock()
	local hours = Lighting.ClockTime
	local h = math.floor(hours)
	local m = math.floor((hours - h) * 60)
	local time = string.format("%02d:%02d", h, m)
	local night = workspace:GetAttribute("IsNight") == true
	if night then
		refs.Clock.Text = `🌙 NOITE · {time} · Perigo elevado`
		refs.Clock.TextColor3 = Theme.Colors.Danger
	else
		refs.Clock.Text = `☀️ Dia · {time}`
		refs.Clock.TextColor3 = Theme.Colors.Text
	end

	local s = state
	local objective = nil
	if s and (s.Combs.Raro or 0) > 0 then
		objective = "Retorne com o favo raro!"
	elseif night and s and s.CarryWeight > 0 then
		objective = "Leve a carga para casa em segurança"
	end
	refs.Objective.Visible = objective ~= nil
	refs.ObjectiveText.Text = objective or ""
end

local function renderFrame(dt: number)
	-- Contador do mel.
	if displayedHoney then
		local current = displayedHoney :: number
		local diff = targetHoney - current
		current = if math.abs(diff) < 0.5 then targetHoney else current + diff * math.clamp(dt * 7, 0, 1)
		displayedHoney = current
		refs.Honey.Text = `Mel   {formatNumber(current)}`
	end

	-- Fôlego.
	local flight = FlightController.State
	local fraction = flight.Stamina / Config.Flight.StaminaMax
	W.SetBar(refs.StaminaBar, fraction, if fraction < 0.25 then Theme.Colors.Danger else STAMINA)
	local show = flight.Sprinting or fraction < 0.999
	local group: CanvasGroup = refs.Stamina
	group.GroupTransparency += ((if show then 0 else 1) - group.GroupTransparency) * math.clamp(dt * 6, 0, 1)

	-- Minimapa.
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local radius = refs.MapRadius
	local scale = refs.MapScale
	local me = root.Position

	local function place(gui: GuiObject, world: Vector3)
		local offset = Vector2.new(world.X - me.X, world.Z - me.Z) / scale
		if offset.Magnitude > radius - 12 then
			offset = offset.Unit * (radius - 12) -- fica na borda apontando a direção
		end
		gui.Position = UDim2.new(0.5, offset.X, 0.5, offset.Y)
	end

	if state and state.HivePosition then
		local distance = math.floor((me - state.HivePosition).Magnitude)
		place(refs.MapHive, state.HivePosition)
		refs.HiveDistance.Text = `Sua colmeia · {distance} m`
		refs.HiveMarkerLabel.Text = `🏠 Sua colmeia · {distance} m`
	end
	place(refs.MapRoyal, refs.RoyalAnchor.Position)
	refs.RoyalMarkerLabel.Text =
		`👑 Colmeia Real · {math.floor((me - refs.RoyalAnchor.Position).Magnitude)} m`

	for _, ring in refs.MapRings do
		local studs = ring:GetAttribute("Radius")
		local diameter = 2 * studs / scale
		ring.Size = UDim2.fromOffset(diameter, diameter)
		local center = Vector2.new(-me.X, -me.Z) / scale
		ring.Position = UDim2.new(0.5, center.X, 0.5, center.Y)
	end

	local look = workspace.CurrentCamera.CFrame.LookVector
	refs.MapArrow.Rotation = math.deg(math.atan2(look.X, -look.Z))
end

local toastToken = 0
local function showToast(message: string, kind: string)
	if kind == "derrota" then
		refs.DeathText.Text = message
		refs.Death.Visible = true
		task.spawn(function()
			for t = Config.Health.RespawnDelay, 1, -1 do
				refs.DeathTimer.Text = `Renascendo na sua colmeia em {t}...`
				task.wait(1)
			end
			refs.Death.Visible = false
		end)
		return
	end
	-- A faixa "Missão concluída!" já mostra isso.
	if string.find(message, "^Missão concluída") then
		return
	end
	toastToken += 1
	local token = toastToken
	local toast: Frame = refs.Toast
	refs.ToastText.Text = message
	refs.ToastText.TextColor3 = if kind == "erro"
		then Theme.Colors.Danger
		elseif kind == "ok" then Theme.Colors.Gold
		else Theme.Colors.Text
	toast.Visible = true
	toast.BackgroundTransparency = Theme.Colors.PanelTransparency
	refs.ToastText.TextTransparency = 0
	pulse(toast, 0.06)
	task.delay(2.6, function()
		if token == toastToken then
			tween(refs.ToastText, 0.3, { TextTransparency = 1 })
			local t = tween(toast, 0.3, { BackgroundTransparency = 1 })
			t.Completed:Wait()
			if token == toastToken then
				toast.Visible = false
			end
		end
	end)
end

local function flashDamage()
	refs.HurtStroke.Transparency = 0.2
	tween(refs.HurtStroke, 0.6, { Transparency = 1 })
end

local currentTab = "Colmeia"
local function selectTab(name: string)
	currentTab = name
	for tabName, button in refs.Tabs do
		local active = tabName == name
		button.BackgroundColor3 = if active then Theme.Colors.Gold else DARK_BUTTON
		button.TextColor3 = if active then Theme.Colors.Panel else Theme.Colors.Text
		refs.Pages[tabName].Visible = active
	end
end

local panelOpen = false
local function setHivePanel(open: boolean, tab: string?)
	if tab then
		selectTab(tab)
	end
	if open == panelOpen then
		return
	end
	panelOpen = open
	local panel: Frame = refs.HivePanel
	if open then
		renderHivePanel()
		panel.Visible = true
		panel.Position = PANEL_CLOSED
		tween(panel, 0.3, { Position = PANEL_OPEN }, Enum.EasingStyle.Back)
	else
		local t = tween(panel, 0.2, { Position = PANEL_CLOSED })
		t.Completed:Connect(function()
			if not panelOpen then
				panel.Visible = false
			end
		end)
	end
end

local function runAction(index: number)
	if index == 1 then
		showToast("Chegue perto de uma flor ou favo e segure E (ou toque no aviso).", "info")
	elseif index == 2 then
		setHivePanel(not panelOpen)
	elseif index == 3 then
		showToast("Clãs chegam em breve: junte abelhas numa mesma colônia!", "info")
	end
end

local function updateScale()
	local viewport = workspace.CurrentCamera.ViewportSize
	refs.Scale.Scale = math.clamp(math.min(viewport.X / 1366, viewport.Y / 768), 0.55, 1)
end

local function tidyCoreGui()
	-- A lista de jogadores do Roblox ocuparia o canto dos chips de Mel/Favos.
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
		-- Sem ferramentas no jogo: libera as teclas 1/2/3 para a barra de ações.
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)
	-- Chat embaixo à direita, deixando o topo esquerdo para o selo de nível.
	-- A configuração da janela do chat pode demorar a existir: esperamos por ela.
	-- (O default.project.json também já configura isso; aqui é o reforço.)
	task.spawn(function()
		local window = TextChatService:WaitForChild("ChatWindowConfiguration", 10)
		if not window then
			Log.warn("HUDController", "chat: ChatWindowConfiguration não encontrado")
			return
		end
		local ok, err = pcall(function()
			(window :: any).HorizontalAlignment = Enum.HorizontalAlignment.Right;
			(window :: any).VerticalAlignment = Enum.VerticalAlignment.Bottom
		end)
		if ok then
			Log.info("HUDController", "chat movido para baixo à direita")
		else
			Log.warn("HUDController", `chat não pôde ser movido: {err}`)
		end
	end)
end

function HUDController:Init()
	tidyCoreGui()
	build()
	selectTab(currentTab)
end

function HUDController:Start()
	Remotes.Get("StateUpdated").OnClientEvent:Connect(function(newState)
		state = newState
		render()
	end)
	Remotes.Get("Notify").OnClientEvent:Connect(showToast)
	Remotes.Get("WorldUpdated").OnClientEvent:Connect(showToast)
	Remotes.Get("Effect").OnClientEvent:Connect(function(kind, _position, userId)
		if kind == "dano" and userId == player.UserId then
			flashDamage()
		end
	end)

	task.spawn(function()
		local ok, initial = pcall(function()
			return Remotes.GetFunction("GetInitialState"):InvokeServer()
		end)
		if ok and initial and not state then
			state = initial
			render()
		end
	end)

	-- Botões.
	refs.HoneyPlus.Activated:Connect(function()
		setHivePanel(true, "Abelha")
	end)
	refs.HiveClose.Activated:Connect(function()
		setHivePanel(false)
	end)
	for name, button in refs.Tabs do
		button.Activated:Connect(function()
			selectTab(name)
		end)
	end
	refs.CollectButton.Activated:Connect(function()
		Remotes.Get("RequestHiveAction"):FireServer("ColetarMel")
	end)
	refs.DeliverButton.Activated:Connect(function()
		Remotes.Get("RequestHiveAction"):FireServer("Entregar")
	end)
	refs.ExpandButton.Activated:Connect(function()
		Remotes.Get("RequestHiveAction"):FireServer("Expandir")
	end)
	for i, slot in refs.UpgradeSlots do
		slot.Button.Activated:Connect(function()
			local upgrade = state and state.Upgrades and state.Upgrades[i]
			if upgrade then
				Remotes.Get("RequestUpgrade"):FireServer(upgrade.Name)
			end
		end)
	end
	for i, row in refs.SpecialtyRows do
		row.Button.Activated:Connect(function()
			local option = state and state.Specialty and state.Specialty.Options[i]
			if option and not option.Active then
				Remotes.Get("RequestSpecialty"):FireServer(option.Id)
			end
		end)
	end
	for i, button in refs.CosmeticButtons do
		button.Activated:Connect(function()
			local cosmetic = state and state.Cosmetics and state.Cosmetics[i]
			if cosmetic then
				Remotes.Get("RequestCosmetic")
					:FireServer(if cosmetic.Owned then "Equipar" else "Comprar", cosmetic.Id)
			end
		end)
	end
	for i, slot in refs.ActionButtons do
		slot.Activated:Connect(function()
			runAction(i)
		end)
	end

	-- Teclas 1/2/3 e U (U também abre a colmeia).
	local keyToAction = {
		[Enum.KeyCode.One] = 1,
		[Enum.KeyCode.Two] = 2,
		[Enum.KeyCode.Three] = 3,
		[Enum.KeyCode.U] = 2,
	}
	ContextActionService:BindAction("AcoesHUD", function(_, inputState, input)
		if inputState == Enum.UserInputState.Begin and keyToAction[input.KeyCode] then
			runAction(keyToAction[input.KeyCode])
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.U)

	-- Atributos que o servidor atualiza.
	player:GetAttributeChangedSignal("Region"):Connect(renderRegion)
	player:GetAttributeChangedSignal("Health"):Connect(renderHealth)
	player:GetAttributeChangedSignal("MaxHealth"):Connect(renderHealth)
	player:GetAttributeChangedSignal("ProtectedUntil"):Connect(renderHealth)
	renderRegion()
	renderHealth()

	updateScale()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)

	task.spawn(function()
		while true do
			renderClock()
			renderHealth()
			task.wait(0.5)
		end
	end)
	RunService.RenderStepped:Connect(renderFrame)

	Log.info("HUDController", "pronto")
end

return HUDController
