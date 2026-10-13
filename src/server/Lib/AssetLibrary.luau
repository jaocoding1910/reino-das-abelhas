--[[
	AssetLibrary — troca peças geradas por modelos 3D de verdade.

	O jogo procura modelos dentro de ReplicatedStorage.Assets (a pasta
	assets/ do projeto), em QUALQUER profundidade. Assim funciona tanto o
	pacote pronto (assets/PacoteAbelhas.rbxm, com Abelha, Flor, Girassol,
	Cogumelo, Arvore e Cristal dentro) quanto um .rbxm por modelo.

	Cada peça é recolorida pelo PAPEL no nome ("Corpo_3" → "Corpo"),
	usando Config.Art.Palette. Também:
	- peças "Pinta" brilham à noite (tag BrilhoNoturno);
	- peças "AsaE"/"AsaD" da abelha batem (Weld com dobradiça + tag AsaAbelha).

	Segurança: modelos de terceiros podem trazer scripts. Esta biblioteca
	REMOVE qualquer Script/LocalScript/ModuleScript ao clonar.
	Sem o modelo, o jogo continua usando as peças geradas por código.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local AssetLibrary = {}

export type Overrides = { [string]: Color3 }

local cache: { [string]: Model | false } = {}
local reported: { [string]: boolean } = {}

-- Diagnóstico (uma vez por modelo): quantas peças de cada papel e quais
-- nomes não estão na paleta. Ajuda a ver por que algo ficou cinza.
local function report(name: string, model: Model)
	if reported[name] then
		return
	end
	reported[name] = true
	local roles: { [string]: number } = {}
	local unknown: { [string]: number } = {}
	local classes: { [string]: number } = {}
	for _, part in model:GetDescendants() do
		classes[part.ClassName] = (classes[part.ClassName] or 0) + 1
		if part:IsA("BasePart") then
			local role = AssetLibrary.RoleFor(part, model)
			roles[role] = (roles[role] or 0) + 1
			if not Config.Art.Palette[role] then
				unknown[role] = (unknown[role] or 0) + 1
			end
		end
	end
	local function list(t: { [string]: number }): string
		local out = {}
		for key, count in t do
			table.insert(out, `{key}={count}`)
		end
		table.sort(out)
		return table.concat(out, ", ")
	end
	print(`[Abelhas:Modelos] {name}: {list(roles)} | classes: {list(classes)}`)
	if next(unknown) then
		warn(`[Abelhas:Modelos] {name}: nomes fora da paleta (ficam sem cor): {list(unknown)}`)
	end
end

local function find(name: string): Model?
	local cached = cache[name]
	if cached ~= nil then
		return if cached then cached else nil
	end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local found = assets and assets:FindFirstChild(name, true)
	-- O importador pode criar o modelo como Model ou Folder; aceitamos Model.
	local model = if found and found:IsA("Model") then found else nil
	cache[name] = model or false
	return model
end

function AssetLibrary.Has(name: string): boolean
	return find(name) ~= nil
end

-- "Corpo_3" → "Corpo"; "Corpo3" → "Corpo"; "Asa" → "Asa"
function AssetLibrary.RoleOf(partName: string): string
	return string.match(partName, "^(%a+)") or partName
end

-- Nomes de malha que o importador do Studio usa no lugar do nome do nó.
local ALIASES: { [string]: string } = {
	Olho = "OlhoBranco",
	PontaAntena = "Antena",
	Raiz = "Tronco",
}

-- Papel de uma peça importada. O importador do Studio coloca cada malha num
-- Model com o nome do nó ("AsaE_1") e dá à peça o nome da malha ("Asa2").
-- Tentamos o Model primeiro; senão, o nome da peça com apelidos.
function AssetLibrary.RoleFor(part: BasePart, root: Model): string
	local parent = part.Parent
	if parent and parent ~= root and parent:IsA("Model") then
		local fromNode = string.match(parent.Name, "^(%a+)_%d+$")
		if fromNode then
			return fromNode
		end
	end
	local role = AssetLibrary.RoleOf(part.Name)
	role = ALIASES[role] or role
	if role == "Asa" or role == "AsaPequena" then
		-- Lado da asa pela posição: esquerda (-X) ou direita (+X) do modelo.
		local x = root:GetPivot():PointToObjectSpace(part.Position).X
		role = if x < 0 then "AsaE" else "AsaD"
	end
	return role
end

local function prepare(source: Model, overrides: Overrides?): Model
	local model = source:Clone()
	report(source.Name, model)
	for _, item in model:GetDescendants() do
		if item:IsA("LuaSourceContainer") then
			item:Destroy()
		end
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local role = AssetLibrary.RoleFor(part, model)
			part:SetAttribute("Papel", role)
			local style = Config.Art.Palette[role]
			if style then
				part.Color = style.Color
				local material = style.Material or Enum.Material.SmoothPlastic
				-- Materiais com textura (Grass, Wood, Sand, Fabric…) precisam de UV no
				-- modelo; sem isso a cor fica lavada/cinza. Nos MeshParts do pacote,
				-- só Neon e Glass ficam; o resto vira plástico liso.
				if
					part:IsA("MeshPart")
					and material ~= Enum.Material.Neon
					and material ~= Enum.Material.Glass
				then
					material = Enum.Material.SmoothPlastic
				end
				part.Material = material
				part.Transparency = style.Transparency or 0
			end
			if overrides and overrides[role] then
				part.Color = overrides[role]
			end
			if role == "Pinta" then
				part:SetAttribute(
					"NightColor",
					if overrides and overrides.NightColor
						then overrides.NightColor
						else Color3.fromRGB(255, 140, 220)
				)
				CollectionService:AddTag(part, "BrilhoNoturno")
			end
		end
	end
	return model
end

-- Clona o modelo, ajusta a ALTURA para `height` e coloca a base em `baseCFrame`.
-- Retorna nil se o modelo não existir.
function AssetLibrary.Place(
	name: string,
	baseCFrame: CFrame,
	height: number,
	parent: Instance,
	overrides: Overrides?
): Model?
	local source = find(name)
	if not source then
		return nil
	end
	local model = prepare(source, overrides)

	local _, size = model:GetBoundingBox()
	if size.Y > 0 then
		model:ScaleTo(model:GetScale() * (height / size.Y))
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end

	-- Encosta a base do modelo no chão do ponto pedido.
	local boxCFrame, boxSize = model:GetBoundingBox()
	local pivot = model:GetPivot()
	local bottomOffset = pivot.Position.Y - (boxCFrame.Position.Y - boxSize.Y / 2)
	model:PivotTo(baseCFrame * CFrame.new(0, bottomOffset, 0) * pivot.Rotation)
	model.Parent = parent
	return model
end

-- Clona um modelo e solda a uma peça (ex.: corpo da abelha no HumanoidRootPart).
-- `length` é o maior lado desejado. Asas ganham dobradiça para bater.
function AssetLibrary.Attach(name: string, root: BasePart, length: number, offset: CFrame): Model?
	local source = find(name)
	if not source then
		return nil
	end
	local model = prepare(source, nil)
	local _, size = model:GetBoundingBox()
	local biggest = math.max(size.X, size.Y, size.Z)
	if biggest > 0 then
		model:ScaleTo(model:GetScale() * (length / biggest))
	end
	local boxCFrame = model:GetBoundingBox()
	-- Centraliza o modelo no root e aplica o giro de correção (Config.Art.BeeYawDegrees).
	local yaw = CFrame.Angles(0, math.rad(Config.Art.BeeYawDegrees), 0)
	local pivotToBox = model:GetPivot():ToObjectSpace(boxCFrame)
	model:PivotTo(root.CFrame * offset * yaw * pivotToBox:Inverse())

	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
			part:SetAttribute("Abelha", true)

			local role = part:GetAttribute("Papel")
			if role == "AsaE" or role == "AsaD" then
				-- Dobradiça perto do corpo: a asa gira em volta dela.
				local side = if role == "AsaE" then -1 else 1
				local rel = root.CFrame:ToObjectSpace(part.CFrame)
				local hinge = Vector3.new(side * 0.35, rel.Position.Y, rel.Position.Z)
				local c0 = CFrame.new(hinge) * rel.Rotation
				local weld = Instance.new("Weld")
				weld.Name = "AsaWeld"
				weld.Part0 = root
				weld.Part1 = part
				weld.C0 = c0
				weld.C1 = rel:Inverse() * c0
				weld:SetAttribute("BaseC0", c0)
				weld:SetAttribute("Side", side)
				CollectionService:AddTag(weld, "AsaAbelha")
				weld.Parent = part
			else
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = root
				weld.Part1 = part
				weld.Parent = part
			end
		end
	end
	return model
end

return AssetLibrary
