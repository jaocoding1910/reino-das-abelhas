--[[
	AssetLibrary — troca peças geradas por modelos 3D de verdade.

	Como usar (no Studio):
	1. Pegue um modelo (Loja do Criador / Toolbox, ou feito por você).
	2. Renomeie o Model para um dos nomes abaixo.
	3. Clique com o direito → "Salvar em arquivo" → salve em
	   C:\Projetos Lua\reino-das-abelhas\assets\<Nome>.rbxm
	4. O Rojo coloca em ReplicatedStorage.Assets e o jogo passa a usar.

	Nomes reconhecidos:
	- Flor, Girassol, Arvore, Cogumelo, Cristal  (mapa)
	- Abelha                                       (corpo do jogador)
	- Aranha                                       (predador)

	Segurança: modelos de terceiros podem trazer scripts. Esta biblioteca
	REMOVE qualquer Script/LocalScript/ModuleScript ao clonar.
	Sem o arquivo, o jogo continua usando as peças geradas por código.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetLibrary = {}

local function folder(): Instance?
	return ReplicatedStorage:FindFirstChild("Assets")
end

function AssetLibrary.Has(name: string): boolean
	local assets = folder()
	return assets ~= nil and assets:FindFirstChild(name) ~= nil
end

local function sanitize(model: Instance)
	for _, item in model:GetDescendants() do
		if item:IsA("LuaSourceContainer") then
			item:Destroy()
		end
	end
end

-- Clona o modelo, ajusta a ALTURA para `height` e coloca a base em `baseCFrame`.
-- Retorna nil se o modelo não existir.
function AssetLibrary.Place(name: string, baseCFrame: CFrame, height: number, parent: Instance): Model?
	local assets = folder()
	local source = assets and assets:FindFirstChild(name)
	if not source or not source:IsA("Model") then
		return nil
	end

	local model = source:Clone()
	sanitize(model)

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

-- Clona um modelo para ser soldado a uma peça (ex.: corpo da abelha).
-- `length` é o maior lado desejado.
function AssetLibrary.Attach(name: string, root: BasePart, length: number, offset: CFrame): Model?
	local assets = folder()
	local source = assets and assets:FindFirstChild(name)
	if not source or not source:IsA("Model") then
		return nil
	end

	local model = source:Clone()
	sanitize(model)
	local _, size = model:GetBoundingBox()
	local biggest = math.max(size.X, size.Y, size.Z)
	if biggest > 0 then
		model:ScaleTo(model:GetScale() * (length / biggest))
	end
	model:PivotTo(root.CFrame * offset)

	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
			part:SetAttribute("Abelha", true)
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = part
			weld.Parent = part
		end
	end
	return model
end

return AssetLibrary
