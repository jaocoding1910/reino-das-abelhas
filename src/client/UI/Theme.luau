--!strict
-- Theme — cores e fontes da interface, inspiradas nas imagens de referência.

local Theme = {}

Theme.Colors = {
	Gold = Color3.fromRGB(255, 196, 64),
	GoldDark = Color3.fromRGB(176, 120, 24),
	Panel = Color3.fromRGB(28, 22, 16),
	PanelTransparency = 0.25,
	Text = Color3.fromRGB(250, 244, 230),
	TextMuted = Color3.fromRGB(200, 190, 170),
	Health = Color3.fromRGB(220, 60, 60),
	Protected = Color3.fromRGB(70, 200, 120),
	Danger = Color3.fromRGB(240, 70, 90),
	Night = Color3.fromRGB(120, 110, 255),
}

Theme.Font = Enum.Font.GothamBold
Theme.FontRegular = Enum.Font.Gotham
Theme.CornerRadius = UDim.new(0, 10)

return Theme
