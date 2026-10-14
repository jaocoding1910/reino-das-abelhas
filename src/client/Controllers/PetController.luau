--[[
	PetController (cliente) — mascotes voando junto dos donos

	O servidor só guarda qual mascote cada um usa (atributo "Mascote" no
	Player). Cada cliente desenha as mascotes de todos com o molde
	ReplicatedStorage.ModelosProntos.AbelhaMini, pintado na cor da mascote.
	- A sua voa ao seu lado, à frente (você vê em primeira pessoa).
	- As dos outros voam atrás do ombro deles.
	Movimento suave, com balanço; as asas batem pelo VisualController.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)

local PetController = {}

local localPlayer = Players.LocalPlayer
local RANGE = 300

type Pet = { Id: string, Model: Model, Root: BasePart, Position: Vector3, Phase: number }

local pets: { [Player]: Pet } = {}
local folder: Folder
local template: Model? = nil

local function paint(model: Model, color: Color3)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local role = part:GetAttribute("Papel") or part.Name
			if role == "Corpo" then
				part.Color = color
			elseif role == "Pelo" then
				part.Color = color:Lerp(Color3.new(1, 1, 1), 0.35)
			end
		end
	end
end

local function remove(player: Player)
	local pet = pets[player]
	if pet then
		pet.Model:Destroy()
		pets[player] = nil
	end
end

local function sync(player: Player)
	local id = player:GetAttribute("Mascote")
	local current = pets[player]
	if typeof(id) ~= "string" or id == "" or not Config.Pets[id] or not template then
		remove(player)
		return
	end
	if current and current.Id == id then
		return
	end
	remove(player)
	local clone = (template :: Model):Clone()
	local root = clone.PrimaryPart
	if not root then
		clone:Destroy()
		return
	end
	paint(clone, Config.Pets[id].Color)
	clone.Name = `Mascote_{player.Name}`
	clone.Parent = folder
	local character = player.Character
	local ownerRoot = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local start = if ownerRoot then ownerRoot.Position + Vector3.new(0, 3, 0) else Vector3.new(0, -400, 0)
	root.CFrame = CFrame.new(start)
	pets[player] = { Id = id, Model = clone, Root = root, Position = start, Phase = math.random() * 6.28 }
end

local function watch(player: Player)
	player:GetAttributeChangedSignal("Mascote"):Connect(function()
		sync(player)
	end)
	sync(player)
end

local function step(dt: number)
	local now = os.clock()
	local camera = workspace.CurrentCamera.CFrame.Position
	for player, pet in pets do
		local character = player.Character
		local ownerRoot = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if ownerRoot and (ownerRoot.Position - camera).Magnitude < RANGE then
			local look = ownerRoot.CFrame.LookVector
			local flat = Vector3.new(look.X, 0, look.Z)
			flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis
			local right = flat:Cross(Vector3.yAxis)
			-- Sua mascote: à direita e à frente (aparece na tela). Dos outros: atrás do ombro.
			local offset = if player == localPlayer
				then right * 3.4 + flat * 4.5 + Vector3.new(0, -0.6, 0)
				else right * 2.6 - flat * 2.4 + Vector3.new(0, 1.4, 0)
			local bob = Vector3.new(0, math.sin(now * 3 + pet.Phase) * 0.35, 0)
			local target = ownerRoot.Position + offset + bob
			local alpha = math.clamp(dt * 6, 0, 1)
			pet.Position = pet.Position:Lerp(target, alpha)
			if (pet.Position - target).Magnitude > 60 then
				pet.Position = target -- teleportou (renasceu): vai junto
			end
			pet.Root.CFrame = CFrame.lookAt(pet.Position, pet.Position + flat)
		end
	end
end

function PetController:Init()
	folder = Instance.new("Folder")
	folder.Name = "Mascotes"
	folder.Parent = workspace
end

function PetController:Start()
	task.spawn(function()
		local ready = ReplicatedStorage:WaitForChild("ModelosProntos", 30)
		local mini = ready and ready:WaitForChild("AbelhaMini", 30)
		if not mini or not mini:IsA("Model") then
			Log.warn("PetController", "molde da mascote não encontrado")
			return
		end
		template = mini
		Players.PlayerAdded:Connect(watch)
		for _, player in Players:GetPlayers() do
			watch(player)
		end
		Players.PlayerRemoving:Connect(remove)
		RunService.RenderStepped:Connect(step)
	end)
	Log.info("PetController", "pronto")
end

return PetController
