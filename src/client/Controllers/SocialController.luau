--[[
	SocialController (cliente) — Rainha, colônias e recompensa diária

	- Conversa com a Rainha: abre ao acionar o aviso "Falar com a Rainha".
	  Mostra o pedido, o progresso e os botões Aceitar / Receber.
	- Painel de colônias (tecla 3 / botão "Clã"): fundar com nome, entrar
	  numa colônia do servidor, ver membros e bônus, sair.
	- Calendário da recompensa diária (7 dias) quando o servidor avisa.
	- Loja do Besouro mercador: poções e trocas.

	Como o resto do HUD: só mostra e pede. Todas as regras ficam no servidor.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared.Util.Log)
local Remotes = require(Shared.Remotes)

local Theme = require(script.Parent.Parent.UI.Theme)
local W = require(script.Parent.Parent.UI.Widgets)
local AudioController = require(script.Parent.AudioController)

local SocialController = {}

local player = Players.LocalPlayer
local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local GREEN = Color3.fromRGB(80, 200, 120)

local state: any = nil
local refs: { [string]: any } = {}

local function formatNumber(n: number): string
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1."):reverse()
	if formatted:sub(1, 1) == "." then
		formatted = formatted:sub(2)
	end
	return formatted
end

local function popIn(frame: GuiObject)
	local scale = frame:FindFirstChild("Entrada") :: UIScale?
	if not scale then
		local created = Instance.new("UIScale")
		created.Name = "Entrada"
		created.Parent = frame
		scale = created
	end
	local s = scale :: UIScale
	s.Scale = 0.85
	TweenService
		:Create(s, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
end

local function closeButton(parent: Frame, onClick: () -> ()): TextButton
	local close = W.Button(
		"Fechar",
		"Fechar",
		UDim2.new(0, 120, 0, 36),
		UDim2.new(1, -134, 1, -48),
		parent,
		Color3.fromRGB(80, 66, 50)
	)
	close.Modal = true -- solta o mouse enquanto o painel está aberto
	close.Activated:Connect(onClick)
	return close
end

-- Rainha -------------------------------------------------------------------------

local function buildQueenDialog(gui: ScreenGui)
	local panel = W.Panel(
		"ConversaRainha",
		UDim2.fromOffset(580, 236),
		UDim2.new(0.5, 0, 1, -150),
		Vector2.new(0.5, 1),
		gui
	)
	panel.Visible = false
	panel.ZIndex = 6
	local stroke = panel:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = Theme.Colors.Gold
		stroke.Thickness = 3
	end
	local portrait, crown = W.HexBadge("Retrato", 92, "👑", panel)
	portrait.Position = UDim2.fromOffset(18, 18)
	crown.TextColor3 = Theme.Colors.Gold
	W.Text("Nome", "Rainha Melissa", UDim2.new(1, -150, 0, 28), UDim2.fromOffset(130, 16), panel, {
		TextColor3 = Theme.Colors.Gold,
	})
	refs.QueenSpeech = W.Text("Fala", "", UDim2.new(1, -150, 0, 66), UDim2.fromOffset(130, 50), panel, {
		Font = Theme.FontRegular,
		TextScaled = true, -- ocupa o espaço todo, mesmo com a janela pequena
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 24
	limit.MinTextSize = 12
	limit.Parent = refs.QueenSpeech
	refs.QueenBar =
		W.Bar("Progresso", UDim2.new(1, -150, 0, 14), UDim2.fromOffset(130, 124), Theme.Colors.Gold, panel)
	refs.QueenBarText = W.Text("Numeros", "", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), refs.QueenBar, {
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.5,
		ZIndex = 2,
	})
	refs.QueenAction = W.Button("Acao", "", UDim2.new(0, 230, 0, 40), UDim2.new(0, 130, 1, -52), panel)
	refs.QueenAction.Activated:Connect(function()
		local action = refs.QueenAction:GetAttribute("Acao")
		if typeof(action) == "string" then
			Remotes.Get("RequestRoyal"):FireServer(action)
		end
	end)
	closeButton(panel, function()
		panel.Visible = false
		ProximityPromptService.Enabled = true -- volta a mostrar os avisos
	end)
	refs.QueenPanel = panel
end

local function renderQueen()
	local panel: Frame = refs.QueenPanel
	if not panel.Visible or not state or not state.Royal then
		return
	end
	local royal = state.Royal
	local bar: Frame = refs.QueenBar
	local action: TextButton = refs.QueenAction
	if royal.Ready then
		refs.QueenSpeech.Text =
			`Maravilha, abelhinha! O reino agradece. Aqui está a sua recompensa: +{formatNumber(royal.Honey)} mel e +{royal.XP} XP.`
		bar.Visible = true
		W.SetBar(bar, 1, GREEN)
		refs.QueenBarText.Text = `{royal.Progress}/{royal.Goal} ✓`
		action.Visible = true
		action.Text = "Receber recompensa"
		action:SetAttribute("Acao", "Receber")
	elseif royal.Active then
		refs.QueenSpeech.Text =
			`Ainda espero por você: {royal.Text}. Recompensa: {formatNumber(royal.Honey)} mel e {royal.XP} XP.`
		bar.Visible = true
		W.SetBar(bar, royal.Progress / math.max(1, royal.Goal), Theme.Colors.Gold)
		refs.QueenBarText.Text = `{royal.Progress}/{royal.Goal}`
		action.Visible = false
	elseif royal.NextIn > 0 then
		refs.QueenSpeech.Text =
			`Você já me ajudou muito hoje. Volte em {math.ceil(royal.NextIn / 60)} min para um novo pedido. Pedidos cumpridos: {royal.Completed}.`
		bar.Visible = false
		action.Visible = false
	else
		refs.QueenSpeech.Text =
			"Abelhinha! O reino precisa de você. Aceita um pedido especial? Pago mais que as missões comuns."
		bar.Visible = false
		action.Visible = true
		action.Text = "Aceitar pedido"
		action:SetAttribute("Acao", "Aceitar")
	end
end

-- Colônias -----------------------------------------------------------------------

local MAX_LIST = 5

local function buildClanPanel(gui: ScreenGui)
	local panel =
		W.Panel("Colonias", UDim2.fromOffset(440, 470), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), gui)
	panel.Visible = false
	panel.ZIndex = 6
	local icon = W.Hex("Icone", 30, Theme.Colors.Gold, panel)
	icon.Position = UDim2.fromOffset(14, 12)
	W.Text("Titulo", "🐝 Colônias", UDim2.new(1, -70, 0, 28), UDim2.fromOffset(54, 13), panel)

	-- Sem colônia: fundar + lista.
	local join = Instance.new("Frame")
	join.Name = "SemColonia"
	join.BackgroundTransparency = 1
	join.Position = UDim2.fromOffset(0, 54)
	join.Size = UDim2.new(1, 0, 1, -110)
	join.Parent = panel
	W.Text(
		"Explica",
		"Mesma colônia não se ataca e, com outro membro online, cada entrega rende mais mel.",
		UDim2.new(1, -28, 0, 40),
		UDim2.fromOffset(14, 0),
		join,
		{
			Font = Theme.FontRegular,
			TextScaled = false,
			TextSize = 14,
			TextWrapped = true,
			TextColor3 = Theme.Colors.TextMuted,
			TextYAlignment = Enum.TextYAlignment.Top,
		}
	)
	local box = Instance.new("TextBox")
	box.Name = "NomeColonia"
	box.Size = UDim2.new(1, -170, 0, 40)
	box.Position = UDim2.fromOffset(14, 48)
	box.BackgroundColor3 = Color3.fromRGB(45, 37, 28)
	box.TextColor3 = Theme.Colors.Text
	box.PlaceholderText = "Nome (3 a 16 letras)"
	box.PlaceholderColor3 = Theme.Colors.TextMuted
	box.Font = Theme.Font
	box.TextSize = 18
	box.ClearTextOnFocus = false
	box.Text = ""
	W.Corner(box, 8)
	box.Parent = join
	refs.ClanBox = box
	refs.ClanCreate = W.Button("Fundar", "Fundar", UDim2.fromOffset(140, 40), UDim2.new(1, -154, 0, 48), join)
	refs.ClanCreate.Activated:Connect(function()
		Remotes.Get("RequestClan"):FireServer("Criar", box.Text)
	end)
	W.Text(
		"ListaTitulo",
		"Colônias neste servidor",
		UDim2.new(1, -28, 0, 20),
		UDim2.fromOffset(14, 102),
		join,
		{
			TextColor3 = Theme.Colors.TextMuted,
		}
	)
	refs.ClanRows = {}
	for i = 1, MAX_LIST do
		local row = Instance.new("Frame")
		row.Name = `Linha{i}`
		row.Size = UDim2.new(1, -28, 0, 40)
		row.Position = UDim2.fromOffset(14, 128 + (i - 1) * 46)
		row.BackgroundColor3 = Color3.fromRGB(45, 37, 28)
		row.BackgroundTransparency = 0.2
		W.Corner(row, 8)
		row.Parent = join
		local label = W.Text("Nome", "", UDim2.new(1, -130, 1, -14), UDim2.fromOffset(12, 7), row)
		local button = W.Button("Entrar", "Entrar", UDim2.fromOffset(100, 30), UDim2.new(1, -110, 0, 5), row)
		button.Activated:Connect(function()
			local name = row:GetAttribute("Colonia")
			if typeof(name) == "string" then
				Remotes.Get("RequestClan"):FireServer("Entrar", name)
			end
		end)
		refs.ClanRows[i] = { Frame = row, Label = label }
	end
	refs.ClanEmpty = W.Text(
		"Vazio",
		"Nenhuma colônia aqui ainda. Funde a primeira!",
		UDim2.new(1, -28, 0, 24),
		UDim2.fromOffset(14, 136),
		join,
		{
			Font = Theme.FontRegular,
			TextColor3 = Theme.Colors.TextMuted,
		}
	)
	refs.ClanJoin = join

	-- Com colônia: nome, membros, bônus, sair.
	local mine = Instance.new("Frame")
	mine.Name = "MinhaColonia"
	mine.BackgroundTransparency = 1
	mine.Position = UDim2.fromOffset(0, 54)
	mine.Size = UDim2.new(1, 0, 1, -110)
	mine.Parent = panel
	refs.ClanName = W.Text("Nome", "", UDim2.new(1, -28, 0, 30), UDim2.fromOffset(14, 0), mine, {
		TextColor3 = Theme.Colors.Gold,
	})
	refs.ClanBonus = W.Text("Bonus", "", UDim2.new(1, -28, 0, 20), UDim2.fromOffset(14, 36), mine, {
		Font = Theme.FontRegular,
	})
	W.Text("MembrosTitulo", "Membros online", UDim2.new(1, -28, 0, 20), UDim2.fromOffset(14, 66), mine, {
		TextColor3 = Theme.Colors.TextMuted,
	})
	refs.ClanMembers = W.Text("Membros", "", UDim2.new(1, -28, 0, 190), UDim2.fromOffset(14, 90), mine, {
		Font = Theme.FontRegular,
		TextScaled = false,
		TextSize = 17,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	local leave = W.Button(
		"Sair",
		"Sair da colônia",
		UDim2.fromOffset(180, 36),
		UDim2.new(0, 14, 1, -40),
		mine,
		Theme.Colors.Danger
	)
	leave.Activated:Connect(function()
		Remotes.Get("RequestClan"):FireServer("Sair")
	end)
	refs.ClanMine = mine

	closeButton(panel, function()
		panel.Visible = false
	end)
	refs.ClanPanel = panel
end

local function renderClan()
	local panel: Frame = refs.ClanPanel
	if not panel.Visible or not state or not state.Clan then
		return
	end
	local clan = state.Clan
	local inClan = clan.Name ~= ""
	refs.ClanJoin.Visible = not inClan
	refs.ClanMine.Visible = inClan
	if inClan then
		refs.ClanName.Text = `🐝 {clan.Name}`
		local percent = math.floor(clan.Bonus * 100 + 0.5)
		refs.ClanBonus.Text = if clan.BonusActive
			then `✓ Bônus ativo: +{percent}% de mel nas entregas`
			else `Chame outro membro para ganhar +{percent}% de mel`
		refs.ClanBonus.TextColor3 = if clan.BonusActive then GREEN else Theme.Colors.TextMuted
		refs.ClanMembers.Text = table.concat(clan.Members, "\n")
	else
		refs.ClanCreate.Text = `Fundar · {clan.CreateCost} mel`
		local list = clan.List or {}
		refs.ClanEmpty.Visible = #list == 0
		for i, row in refs.ClanRows do
			local entry = list[i]
			row.Frame.Visible = entry ~= nil
			if entry then
				row.Label.Text = `{entry.Name}  ·  {entry.Count} online`
				row.Frame:SetAttribute("Colonia", entry.Name)
			end
		end
	end
end

function SocialController.ToggleClan()
	local panel: Frame = refs.ClanPanel
	panel.Visible = not panel.Visible
	if panel.Visible then
		popIn(panel)
		renderClan()
	end
end

-- Besouro mercador ---------------------------------------------------------------

local function buildShop(gui: ScreenGui)
	local panel = W.Panel(
		"LojaBesouro",
		UDim2.fromOffset(520, 430),
		UDim2.fromScale(0.5, 0.5),
		Vector2.new(0.5, 0.5),
		gui
	)
	panel.Visible = false
	panel.ZIndex = 6
	local stroke = panel:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = Color3.fromRGB(110, 210, 160)
		stroke.Thickness = 3
	end
	W.Text(
		"Titulo",
		"🐞 Seu Besouro · poções e trocas",
		UDim2.new(1, -40, 0, 28),
		UDim2.fromOffset(20, 12),
		panel,
		{
			TextColor3 = Color3.fromRGB(150, 240, 190),
		}
	)
	W.Text(
		"Secao1",
		"Poções (efeito por alguns minutos)",
		UDim2.new(1, -40, 0, 18),
		UDim2.fromOffset(20, 48),
		panel,
		{
			TextColor3 = Theme.Colors.TextMuted,
		}
	)
	refs.PotionRows = {}
	for i = 1, 3 do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -40, 0, 50)
		row.Position = UDim2.fromOffset(20, 70 + (i - 1) * 56)
		row.BackgroundColor3 = Color3.fromRGB(45, 37, 28)
		row.BackgroundTransparency = 0.2
		W.Corner(row, 8)
		row.Parent = panel
		local icon = W.Text("Icone", "", UDim2.fromOffset(34, 34), UDim2.fromOffset(8, 8), row, {
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		local name = W.Text("Nome", "", UDim2.new(1, -200, 0, 20), UDim2.fromOffset(50, 5), row)
		local desc = W.Text("Desc", "", UDim2.new(1, -200, 0, 16), UDim2.fromOffset(50, 28), row, {
			Font = Theme.FontRegular,
			TextColor3 = Theme.Colors.TextMuted,
		})
		local buy = W.Button("Comprar", "", UDim2.fromOffset(136, 34), UDim2.new(1, -144, 0, 8), row)
		buy.Activated:Connect(function()
			local id = row:GetAttribute("Id")
			if typeof(id) == "string" then
				Remotes.Get("RequestShop"):FireServer("Pocao", id)
			end
		end)
		refs.PotionRows[i] = { Row = row, Icon = icon, Name = name, Desc = desc, Buy = buy }
	end
	W.Text(
		"Secao2",
		"Trocas (usa os favos da sua carga)",
		UDim2.new(1, -40, 0, 18),
		UDim2.fromOffset(20, 242),
		panel,
		{
			TextColor3 = Theme.Colors.TextMuted,
		}
	)
	refs.TradeRows = {}
	for i = 1, 3 do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -40, 0, 34)
		row.Position = UDim2.fromOffset(20, 264 + (i - 1) * 40)
		row.BackgroundTransparency = 1
		row.Parent = panel
		local text = W.Text("Texto", "", UDim2.new(1, -130, 1, -8), UDim2.fromOffset(4, 4), row, {
			Font = Theme.FontRegular,
		})
		local trade = W.Button("Trocar", "Trocar", UDim2.fromOffset(110, 30), UDim2.new(1, -112, 0, 2), row)
		trade.Activated:Connect(function()
			local id = row:GetAttribute("Id")
			if typeof(id) == "string" then
				Remotes.Get("RequestShop"):FireServer("Troca", id)
			end
		end)
		refs.TradeRows[i] = { Row = row, Text = text, Button = trade }
	end
	closeButton(panel, function()
		panel.Visible = false
		ProximityPromptService.Enabled = true
	end)
	refs.ShopPanel = panel
end

local function renderShop()
	local panel: Frame = refs.ShopPanel
	if not panel.Visible or not state or not state.Shop then
		return
	end
	local honey = state.Honey or 0
	for i, potion in state.Shop.Potions do
		local row = refs.PotionRows[i]
		if row then
			row.Row:SetAttribute("Id", potion.Id)
			row.Icon.Text = potion.Icon
			row.Name.Text = potion.DisplayName
			local minutes = math.floor(potion.Duration / 60)
			row.Desc.Text = if potion.Remaining > 0
				then `{potion.Description} · ativa ({math.ceil(potion.Remaining / 60)} min)`
				else `{potion.Description} · {minutes} min`
			local afford = honey >= potion.Price
			row.Buy.Text = if potion.Remaining > 0
				then `+tempo · {potion.Price}`
				else `Comprar · {potion.Price}`
			row.Buy.BackgroundColor3 = if afford then Theme.Colors.Gold else Color3.fromRGB(60, 50, 38)
			row.Buy.TextColor3 = if afford then Theme.Colors.Panel else Theme.Colors.TextMuted
		end
	end
	for i, trade in state.Shop.Trades do
		local row = refs.TradeRows[i]
		if row then
			row.Row:SetAttribute("Id", trade.Id)
			row.Text.Text = trade.Text
			row.Text.TextColor3 = if trade.Can then Theme.Colors.Text else Theme.Colors.TextMuted
			row.Button.BackgroundColor3 = if trade.Can then Theme.Colors.Gold else Color3.fromRGB(60, 50, 38)
			row.Button.TextColor3 = if trade.Can then Theme.Colors.Panel else Theme.Colors.TextMuted
		end
	end
end

-- Recompensa diária --------------------------------------------------------------

local function buildDaily(gui: ScreenGui)
	local panel =
		W.Panel("Diaria", UDim2.fromOffset(620, 300), UDim2.fromScale(0.5, 0.45), Vector2.new(0.5, 0.5), gui)
	panel.Visible = false
	panel.ZIndex = 7
	local stroke = panel:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = Theme.Colors.Gold
		stroke.Thickness = 3
	end
	W.Text("Titulo", "🎁 Recompensa diária", UDim2.new(1, -40, 0, 34), UDim2.fromOffset(20, 14), panel, {
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Theme.Colors.Gold,
	})
	refs.DailySubtitle = W.Text("Sequencia", "", UDim2.new(1, -40, 0, 22), UDim2.fromOffset(20, 52), panel, {
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.FontRegular,
	})
	refs.DailyDays = {}
	for i = 1, 7 do
		local slot = Instance.new("Frame")
		slot.Name = `Dia{i}`
		slot.BackgroundTransparency = 1
		slot.Size = UDim2.fromOffset(76, 120)
		slot.Position = UDim2.fromOffset(20 + (i - 1) * 84, 86)
		slot.Parent = panel
		local hex, label = W.HexBadge("Hex", 66, tostring(i), slot)
		hex.Position = UDim2.fromOffset(9, 0)
		local honey = W.Text("Mel", "", UDim2.new(1, 0, 0, 20), UDim2.fromOffset(0, 72), slot, {
			TextXAlignment = Enum.TextXAlignment.Center,
			Font = Theme.FontRegular,
		})
		local tag = W.Text("Marca", "", UDim2.new(1, 0, 0, 18), UDim2.fromOffset(0, 94), slot, {
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		refs.DailyDays[i] = { Hex = hex, Label = label, Honey = honey, Tag = tag }
	end
	local claim = W.Button("Receber", "", UDim2.fromOffset(240, 44), UDim2.new(0.5, -120, 1, -60), panel)
	claim.Modal = true
	claim.Activated:Connect(function()
		panel.Visible = false
	end)
	refs.DailyClaim = claim
	refs.DailyPanel = panel
end

local function showDaily(info: any)
	if type(info) ~= "table" then
		return
	end
	local panel: Frame = refs.DailyPanel
	refs.DailySubtitle.Text = if info.Streak > 1
		then `Sequência de {info.Streak} dias seguidos! Volte amanhã para o próximo prêmio.`
		else "Entre todo dia: o prêmio cresce até o dia 7."
	for i, day in refs.DailyDays do
		local reward = info.Rewards and info.Rewards[i] or 0
		day.Honey.Text = `{reward} mel`
		local isToday = i == info.Index
		local past = i < info.Index
		W.SetHexColor(
			day.Hex,
			if isToday then Theme.Colors.Gold elseif past then GREEN else Color3.fromRGB(110, 95, 75)
		)
		day.Tag.Text = if isToday then "HOJE" elseif past then "✓" else ""
		day.Tag.TextColor3 = if isToday then Theme.Colors.Gold else GREEN
	end
	refs.DailyClaim.Text = `Receber +{formatNumber(info.Honey)} mel`
	panel.Visible = true
	popIn(panel)
	AudioController.Play("Nivel")
end

-- Ciclo --------------------------------------------------------------------------

local function updateScale()
	local viewport = workspace.CurrentCamera.ViewportSize
	refs.Scale.Scale = math.clamp(math.min(viewport.X / 1366, viewport.Y / 768), 0.55, 1)
end

function SocialController:Init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "HUD_Social"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 2
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local scale = Instance.new("UIScale")
	scale.Parent = gui
	refs.Scale = scale
	buildQueenDialog(gui)
	buildClanPanel(gui)
	buildDaily(gui)
	buildShop(gui)
	gui.Parent = player:WaitForChild("PlayerGui")
end

function SocialController:Start()
	Remotes.Get("StateUpdated").OnClientEvent:Connect(function(newState)
		state = newState
		renderQueen()
		renderClan()
		renderShop()
	end)
	task.spawn(function()
		local ok, initial = pcall(function()
			return Remotes.GetFunction("GetInitialState"):InvokeServer()
		end)
		if ok and initial and not state then
			state = initial
		end
	end)
	Remotes.Get("DailyReward").OnClientEvent:Connect(showDaily)

	-- Fecha a conversa sozinha se você se afastar da Rainha (e devolve os avisos).
	task.spawn(function()
		while true do
			task.wait(0.5)
			local shopPanel: Frame = refs.ShopPanel
			if shopPanel.Visible then
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local shop = state and state.Shop
				if
					not root or (shop and shop.Position and (root.Position - shop.Position).Magnitude > 50)
				then
					shopPanel.Visible = false
					ProximityPromptService.Enabled = true
				end
			end
			local panel: Frame = refs.QueenPanel
			if panel.Visible then
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local royal = state and state.Royal
				local far = not root
					or (royal and royal.Position and (root.Position - royal.Position).Magnitude > 80)
				if far then
					panel.Visible = false
					ProximityPromptService.Enabled = true
				end
			end
		end
	end)

	-- Abrir a conversa ao acionar o aviso da Rainha.
	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who == player and prompt:GetAttribute("Mercador") then
			local panel: Frame = refs.ShopPanel
			panel.Visible = true
			ProximityPromptService.Enabled = false
			popIn(panel)
			renderShop()
		elseif who == player and prompt:GetAttribute("Rainha") then
			local panel: Frame = refs.QueenPanel
			panel.Visible = true
			-- Esconde os avisos (E) enquanto conversa: não ficam por cima do painel.
			ProximityPromptService.Enabled = false
			popIn(panel)
			renderQueen()
		end
	end)

	updateScale()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	if isTouch then
		Log.info("SocialController", "pronto (toque)")
	else
		Log.info("SocialController", "pronto")
	end
end

return SocialController
