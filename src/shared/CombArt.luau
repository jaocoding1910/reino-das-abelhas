--[[
	CombArt — geometria do favo/néctar CARREGADO (usada pelo servidor, na
	abelha que todos veem, e pelo cliente, no viewmodel de primeira pessoa).

	Cada célula é um prisma hexagonal feito com 3 blocos girados 0°/60°/120°
	(a união forma um hexágono regular). Um favo tem 7 células (centro + 6),
	com moldura e miolo, nas cores de cada raridade:
	- Comum (Favo de Cera): cera clara e opaca.
	- Medio (Favo de Mel): mel âmbar translúcido com brilho no miolo.
	- Raro (Favo Real): cristal violeta com moldura dourada brilhante.
	- Nectar: gota dourada brilhante (sem favo).

	Build devolve um Model com PrimaryPart "Centro" (invisível) na origem.
	O eixo do favo é o Z local (a face olha para +Z e -Z).
]]

local CombArt = {}

export type Style = {
	Rim: Color3,
	RimMaterial: Enum.Material,
	Core: Color3,
	CoreMaterial: Enum.Material,
	CoreTransparency: number,
	Glow: Color3?,
}

CombArt.Styles = {
	Comum = {
		Rim = Color3.fromRGB(232, 205, 140),
		RimMaterial = Enum.Material.SmoothPlastic,
		Core = Color3.fromRGB(252, 240, 205),
		CoreMaterial = Enum.Material.SmoothPlastic,
		CoreTransparency = 0,
		Glow = nil,
	},
	Medio = {
		Rim = Color3.fromRGB(214, 132, 20),
		RimMaterial = Enum.Material.SmoothPlastic,
		Core = Color3.fromRGB(255, 176, 40),
		CoreMaterial = Enum.Material.Glass,
		CoreTransparency = 0.2,
		Glow = Color3.fromRGB(255, 180, 60),
	},
	Raro = {
		Rim = Color3.fromRGB(255, 205, 90),
		RimMaterial = Enum.Material.Neon,
		Core = Color3.fromRGB(165, 80, 255),
		CoreMaterial = Enum.Material.Glass,
		CoreTransparency = 0.12,
		Glow = Color3.fromRGB(190, 110, 255),
	},
} :: { [string]: Style }

local SQRT3 = math.sqrt(3)

local function block(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

-- Prisma hexagonal: `width` = distância entre lados opostos; eixo em Z.
function CombArt.Hex(
	parent: Instance,
	cf: CFrame,
	width: number,
	depth: number,
	color: Color3,
	material: Enum.Material,
	transparency: number?
)
	local side = width / SQRT3
	for k = 0, 2 do
		local p = block(
			"Hex",
			Vector3.new(side, width, depth),
			cf * CFrame.Angles(0, 0, k * math.pi / 3),
			color,
			material
		)
		p.Transparency = transparency or 0
		p.Parent = parent
	end
end

-- Favo (7 células) ou gota de néctar. `size` = largura total aproximada.
function CombArt.Build(kind: string, size: number): Model
	local model = Instance.new("Model")
	model.Name = `Carga_{kind}`
	local center =
		block("Centro", Vector3.one * 0.1, CFrame.identity, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
	center.Transparency = 1
	center.Parent = model
	model.PrimaryPart = center

	if kind == "Nectar" then
		local drop = block(
			"Gota",
			Vector3.one * size * 0.55,
			CFrame.identity,
			Color3.fromRGB(255, 196, 40),
			Enum.Material.Glass
		)
		drop.Shape = Enum.PartType.Ball
		drop.Transparency = 0.25
		drop.Parent = model
		local core = block(
			"Brilho",
			Vector3.one * size * 0.32,
			CFrame.identity,
			Color3.fromRGB(255, 220, 110),
			Enum.Material.Neon
		)
		core.Shape = Enum.PartType.Ball
		core.Parent = model
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 200, 80)
		light.Range = size * 4
		light.Brightness = 0.6
		light.Parent = core
		return model
	end

	local style = CombArt.Styles[kind] or CombArt.Styles.Comum
	-- 7 células: largura de cada uma para o conjunto caber em `size`.
	local cell = size / 3.1
	local depth = cell * 0.9
	local centers = { Vector3.zero }
	for k = 0, 5 do
		local angle = math.rad(30 + 60 * k)
		table.insert(centers, Vector3.new(math.cos(angle), math.sin(angle), 0) * cell)
	end
	for i, offset in centers do
		-- O centro fica um pouco à frente: o favo parece abaulado.
		local bulge = if i == 1 then cell * 0.12 else 0
		local cf = CFrame.new(offset + Vector3.new(0, 0, bulge))
		CombArt.Hex(model, cf, cell * 0.98, depth, style.Rim, style.RimMaterial, 0)
		-- Miolo um pouco menor e mais saliente nas duas faces.
		CombArt.Hex(
			model,
			cf,
			cell * 0.74,
			depth + cell * 0.08,
			style.Core,
			style.CoreMaterial,
			style.CoreTransparency
		)
	end
	if style.Glow then
		local light = Instance.new("PointLight")
		light.Color = style.Glow
		light.Range = size * 3.5
		light.Brightness = 0.7
		light.Parent = center
	end
	return model
end

-- Tipo mais "valioso" da carga: Raro > Medio > Comum > Nectar > "".
function CombArt.KindOf(cargo: any): string
	if type(cargo) ~= "table" then
		return ""
	end
	local combs = cargo.Combs or {}
	if (combs.Raro or 0) > 0 then
		return "Raro"
	elseif (combs.Medio or 0) > 0 then
		return "Medio"
	elseif (combs.Comum or 0) > 0 then
		return "Comum"
	elseif (cargo.Nectar or 0) > 0 then
		return "Nectar"
	end
	return ""
end

return CombArt
