--[[
	Widgets — peças de interface reutilizáveis no estilo do jogo:
	painéis escuros com borda dourada, hexágonos, barras e botões.
]]

local Theme = require(script.Parent.Theme)

local Widgets = {}

local SQRT3 = math.sqrt(3)

function Widgets.Corner(parent: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 10)
	c.Parent = parent
	return c
end

function Widgets.Stroke(parent: Instance, color: Color3?, thickness: number?)
	local s = Instance.new("UIStroke")
	s.Color = color or Theme.Colors.GoldDark
	s.Thickness = thickness or 1.5
	s.Transparency = 0.15
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

function Widgets.Panel(name: string, size: UDim2, position: UDim2, anchor: Vector2, parent: Instance): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.AnchorPoint = anchor
	frame.BackgroundColor3 = Theme.Colors.Panel
	frame.BackgroundTransparency = Theme.Colors.PanelTransparency
	Widgets.Corner(frame)
	Widgets.Stroke(frame)
	frame.Parent = parent
	return frame
end

function Widgets.Text(
	name: string,
	value: string,
	size: UDim2,
	position: UDim2,
	parent: Instance,
	props: { [string]: any }?
): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = position
	label.Font = Theme.Font
	label.TextColor3 = Theme.Colors.Text
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = value
	if props then
		for key, v in props do
			(label :: any)[key] = v
		end
	end
	label.Parent = parent
	return label
end

function Widgets.Button(
	name: string,
	value: string,
	size: UDim2,
	position: UDim2,
	parent: Instance,
	color: Color3?
): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = color or Theme.Colors.Gold
	button.Font = Theme.Font
	button.TextScaled = true
	button.TextColor3 = if color then Theme.Colors.Text else Theme.Colors.Panel
	button.Text = value
	button.AutoButtonColor = true
	Widgets.Corner(button, 8)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.18, 0)
	pad.PaddingBottom = UDim.new(0.18, 0)
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = button
	button.Parent = parent
	return button
end

-- Hexágono "de ponta para cima" (como os selos das imagens de referência),
-- desenhado com 3 retângulos girados. `size` é a ALTURA em pixels.
function Widgets.Hex(
	name: string,
	size: number,
	color: Color3,
	parent: Instance,
	transparency: number?
): Frame
	local holder = Instance.new("Frame")
	holder.Name = name
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(size * SQRT3 / 2, size)
	local side = size / 2
	for i = 0, 2 do
		local piece = Instance.new("Frame")
		piece.Name = `Parte{i}`
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		piece.Position = UDim2.fromScale(0.5, 0.5)
		piece.Size = UDim2.fromOffset(side, side * SQRT3)
		piece.Rotation = 60 * i + 90
		piece.BackgroundColor3 = color
		piece.BackgroundTransparency = transparency or 0
		piece.BorderSizePixel = 0
		piece.Parent = holder
	end
	holder.Parent = parent
	return holder
end

function Widgets.SetHexColor(hex: Frame, color: Color3)
	for _, piece in hex:GetChildren() do
		if piece:IsA("Frame") then
			piece.BackgroundColor3 = color
		end
	end
end

-- Selo hexagonal com borda dourada e texto no meio.
function Widgets.HexBadge(name: string, size: number, value: string, parent: Instance): (Frame, TextLabel)
	local outer = Widgets.Hex(name, size, Theme.Colors.Gold, parent)
	local inner = Widgets.Hex("Interno", size * 0.84, Theme.Colors.Panel, outer)
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	local label = Widgets.Text("Valor", value, UDim2.fromScale(0.7, 0.6), UDim2.fromScale(0.15, 0.2), outer, {
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	})
	return outer, label
end

function Widgets.Bar(name: string, size: UDim2, position: UDim2, color: Color3, parent: Instance): Frame
	local back = Instance.new("Frame")
	back.Name = name
	back.Size = size
	back.Position = position
	back.BackgroundColor3 = Color3.fromRGB(55, 45, 35)
	back.BorderSizePixel = 0
	Widgets.Corner(back, 6)
	local fill = Instance.new("Frame")
	fill.Name = "Preenchimento"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	Widgets.Corner(fill, 6)
	fill.Parent = back
	back.Parent = parent
	return back
end

function Widgets.SetBar(back: Frame, fraction: number, color: Color3?)
	local fill = back:FindFirstChild("Preenchimento") :: Frame
	fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
	if color then
		fill.BackgroundColor3 = color
	end
end

-- Chip: painel pequeno com ícone hexagonal à esquerda e texto.
function Widgets.Chip(
	name: string,
	size: UDim2,
	position: UDim2,
	anchor: Vector2,
	iconColor: Color3,
	parent: Instance
): (Frame, TextLabel, Frame)
	local chip = Widgets.Panel(name, size, position, anchor, parent)
	local icon = Widgets.Hex("Icone", 26, iconColor, chip)
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, 10, 0.5, 0)
	local label = Widgets.Text("Texto", "", UDim2.new(1, -52, 0.62, 0), UDim2.new(0, 44, 0.19, 0), chip)
	return chip, label, icon
end

return Widgets
