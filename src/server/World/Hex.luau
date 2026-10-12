--!strict
--[[
	Hex — geometria hexagonal (células da colmeia e favos no mapa).

	O Roblox não tem peça hexagonal pronta. Um hexágono regular é a
	união de 3 retângulos (lado × lado·√3) girados 0°, 60° e 120°.
	O eixo do prisma é o Z local do CFrame recebido.
]]

local Hex = {}

local SQRT3 = math.sqrt(3)

export type PrismOptions = {
	Color: Color3,
	Material: Enum.Material?,
	Transparency: number?,
	CanCollide: boolean?,
	Name: string?,
}

-- Cria um prisma hexagonal "de topo plano" com centro em cf.
function Hex.Prism(cf: CFrame, side: number, depth: number, options: PrismOptions): Model
	local model = Instance.new("Model")
	model.Name = options.Name or "Hexagono"

	for i = 0, 2 do
		local part = Instance.new("Part")
		part.Name = `Lado{i + 1}`
		part.Anchored = true
		part.CanCollide = if options.CanCollide == nil then true else options.CanCollide
		part.Size = Vector3.new(side, side * SQRT3, depth)
		part.CFrame = cf * CFrame.Angles(0, 0, math.rad(60 * i))
		part.Color = options.Color
		part.Material = options.Material or Enum.Material.SmoothPlastic
		part.Transparency = options.Transparency or 0
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = model
	end

	model.PrimaryPart = model:FindFirstChild("Lado1") :: BasePart
	return model
end

-- Converte coordenada axial (q, r) em deslocamento no plano local XY.
function Hex.AxialToOffset(q: number, r: number, side: number, gap: number): Vector2
	local x = side * 1.5 * q
	local y = side * SQRT3 * (r + q / 2)
	return Vector2.new(x, y) * gap
end

-- Direções axiais dos 6 vizinhos.
local DIRECTIONS = {
	{ 1, 0 },
	{ 1, -1 },
	{ 0, -1 },
	{ -1, 0 },
	{ -1, 1 },
	{ 0, 1 },
}

-- Lista de posições em espiral: centro, depois anel 1, anel 2…
-- Assim a colmeia cresce de dentro para fora.
function Hex.SpiralSlots(rings: number): { { number } }
	local slots = { { 0, 0 } }
	for k = 1, rings do
		local q = DIRECTIONS[5][1] * k
		local r = DIRECTIONS[5][2] * k
		for side = 1, 6 do
			for _ = 1, k do
				table.insert(slots, { q, r })
				q += DIRECTIONS[side][1]
				r += DIRECTIONS[side][2]
			end
		end
	end
	return slots
end

return Hex
