--[[
	DropService (servidor) — carga perdida

	Quando uma abelha é derrotada, a carga que ela levava cai no chão
	como uma "Carga perdida" que qualquer abelha pode recolher.

	- Cai UMA vez por derrota (o HealthService garante).
	- Some depois de Config.Health.DroppedCargoLifetime segundos.
	- Quem recolhe leva o que couber; o resto continua no chão.
]]

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Types = require(Shared.Types)

local InventoryService = require(script.Parent.InventoryService)
local Notifier = require(script.Parent.Parent.Lib.Notifier)

local DropService = {}

local folder: Folder

local function isEmpty(cargo: Types.Cargo): boolean
	if cargo.Nectar > 0 then
		return false
	end
	for _, amount in cargo.Combs do
		if amount > 0 then
			return false
		end
	end
	return true
end

local function describe(cargo: Types.Cargo): string
	local parts = {}
	if cargo.Nectar > 0 then
		table.insert(parts, `{cargo.Nectar} néctar`)
	end
	for _, rarity in Config.RarityOrder do
		local amount = cargo.Combs[rarity]
		if amount > 0 then
			table.insert(parts, `{amount} {Config.Rarities[rarity].Label:lower()}`)
		end
	end
	return table.concat(parts, " · ")
end

function DropService.Spawn(position: Vector3, cargo: Types.Cargo)
	if isEmpty(cargo) then
		return
	end
	local remaining = cargo

	local bag = Instance.new("Part")
	bag.Name = "CargaPerdida"
	bag.Shape = Enum.PartType.Ball
	bag.Size = Vector3.new(3.5, 3.5, 3.5)
	bag.Color = Color3.fromRGB(255, 190, 60)
	bag.Material = Enum.Material.Neon
	bag.Anchored = true
	bag.CanCollide = false
	bag.Position = Vector3.new(position.X, math.max(position.Y, 3), position.Z)

	local light = Instance.new("PointLight")
	light.Color = bag.Color
	light.Range = 16
	light.Brightness = 2
	light.Parent = bag

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Recolher carga"
	prompt.ObjectText = describe(remaining)
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = bag

	local label = Instance.new("BillboardGui")
	label.Size = UDim2.fromScale(8, 1.6)
	label.StudsOffset = Vector3.new(0, 3.5, 0)
	label.MaxDistance = 120
	label.LightInfluence = 0
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(255, 210, 90)
	text.TextStrokeTransparency = 0.4
	text.Text = "Carga perdida"
	text.Parent = label
	label.Parent = bag

	prompt.Triggered:Connect(function(player)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root or (root.Position - bag.Position).Magnitude > 22 then
			return
		end

		local took = 0
		local added = InventoryService.AddNectar(player, remaining.Nectar)
		remaining.Nectar -= added
		took += added
		for _, rarity in Config.RarityOrder do
			while remaining.Combs[rarity] > 0 and InventoryService.AddComb(player, rarity :: Types.Rarity) do
				remaining.Combs[rarity] -= 1
				took += 1
			end
		end

		if took == 0 then
			Notifier.Notify(player, "Sem espaço na carga para recolher.", "erro")
		elseif isEmpty(remaining) then
			Notifier.Notify(player, "Carga recolhida!", "ok")
			bag:Destroy()
		else
			Notifier.Notify(player, "Você recolheu o que coube. O resto ficou no chão.", "info")
			prompt.ObjectText = describe(remaining)
		end
	end)

	bag.Parent = folder
	Debris:AddItem(bag, Config.Health.DroppedCargoLifetime)
end

function DropService:Init()
	folder = Instance.new("Folder")
	folder.Name = "CargasPerdidas"
	folder.Parent = workspace
end

function DropService:Start()
	Log.info("DropService", "pronto")
end

return DropService
