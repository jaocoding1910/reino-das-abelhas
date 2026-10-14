--[[
	ChestService (servidor) — baús do tesouro

	Config.Chests.Count baús escondidos pelo mapa (campo, bosque, caverna,
	lago e Ilha nas Nuvens). Cada jogador pode abrir cada baú de novo depois
	de Config.Chests.Cooldown (fica salvo no perfil: profile.Chests[id]).
	Prêmio: mel aleatório e, às vezes, uma poção.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Remotes = require(Shared.Remotes)

local MerchantService = require(script.Parent.MerchantService)
local Notifier = require(script.Parent.Parent.Lib.Notifier)
local PlayerDataService = require(script.Parent.PlayerDataService)
local QuestService = require(script.Parent.QuestService)
local WorldService = require(script.Parent.WorldService)

local ChestService = {}

local WOOD = Color3.fromRGB(130, 80, 40)
local GOLD = Color3.fromRGB(245, 190, 60)

local function part(name: string, size: Vector3, cf: CFrame, color: Color3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.WoodPlanks
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Chão de terreno embaixo de um ponto (ou o próprio ponto se não achar).
local function ground(position: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local hit = workspace:Raycast(position + Vector3.new(0, 60, 0), Vector3.new(0, -200, 0), params)
	return if hit then hit.Position else position
end

local function buildChest(parent: Instance, id: string, base: Vector3, yaw: number): BasePart
	local model = Instance.new("Model")
	model.Name = `Bau_{id}`
	local cf = CFrame.new(base) * CFrame.Angles(0, yaw, 0)
	local box = part("Caixa", Vector3.new(5, 3, 3.4), cf * CFrame.new(0, 1.5, 0), WOOD, model)
	local lid = part("Tampa", Vector3.new(5.2, 1.4, 3.6), cf * CFrame.new(0, 3.6, 0), WOOD, model)
	for _, x in { -2.2, 2.2 } do
		local band = part("Faixa", Vector3.new(0.4, 4.6, 3.7), cf * CFrame.new(x, 2.3, 0), GOLD, model)
		band.Material = Enum.Material.Metal
	end
	local lock = part("Fechadura", Vector3.new(0.9, 1, 0.3), cf * CFrame.new(0, 2.9, -1.85), GOLD, model)
	lock.Material = Enum.Material.Neon
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Color = ColorSequence.new(GOLD)
	sparkle.LightEmission = 1
	sparkle.Rate = 4
	sparkle.Lifetime = NumberRange.new(1, 2)
	sparkle.Speed = NumberRange.new(1, 2)
	sparkle.SpreadAngle = Vector2.new(60, 60)
	sparkle.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0) })
	sparkle.Parent = lid
	local light = Instance.new("PointLight")
	light.Color = GOLD
	light.Range = 10
	light.Brightness = 0.8
	light.Parent = lock
	model.Parent = parent
	return box
end

local lastTry: { [Player]: number } = {}

local function open(player: Player, id: string, position: Vector3)
	local now = os.clock()
	if now - (lastTry[player] or 0) < 0.5 or not PlayerDataService.IsLoaded(player) then
		return
	end
	lastTry[player] = now
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - position).Magnitude > 20 then
		return
	end
	local profile = PlayerDataService.Get(player)
	local wait = (profile.Chests[id] or 0) + Config.Chests.Cooldown - os.time()
	if wait > 0 then
		Notifier.Notify(
			player,
			`🧰 Você já abriu este baú. Ele enche de novo em {math.ceil(wait / 60)} min.`,
			"info"
		)
		return
	end
	profile.Chests[id] = os.time()
	local honey = math.random(Config.Chests.MinHoney, Config.Chests.MaxHoney)
	profile.Honey += honey
	profile.HoneyEarned += honey
	local message = `🧰 Tesouro! +{honey} mel`
	if math.random() < Config.Chests.PotionChance then
		local potion = Config.PotionOrder[math.random(1, #Config.PotionOrder)]
		MerchantService.GivePotion(player, potion)
		message ..= ` e {Config.Potions[potion].Icon} {Config.Potions[potion].DisplayName}!`
	end
	Notifier.Notify(player, message, "ok")
	Remotes.Get("Effect"):FireAllClients("entrega", position, player.UserId)
	QuestService.Add(player, "Bau", 1)
end

function ChestService:Init() end

function ChestService:Start()
	local folder = Instance.new("Folder")
	folder.Name = "Baus"
	folder.Parent = WorldService.GetMap().Folder

	-- Lugares: alguns fixos (caverna, lago, ilha) e o resto sorteado.
	local spots = {
		Config.Places.Cave.Position + Vector3.new(0, 1, -8),
		Config.Places.Lake.Position + Vector3.new(Config.Places.Lake.Radius + 8, 0, 0),
		Config.SkyIsland.Position + Vector3.new(0, 0, 10),
	}
	local rng = Random.new(Config.Map.Seed + 33)
	while #spots < Config.Chests.Count do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(Config.Regions.HiveRadius + 20, Config.Map.ForestRadius.Max - 20)
		table.insert(spots, Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius))
	end
	for i, spot in spots do
		local id = tostring(i)
		-- Caverna: chão de dentro (o raio bateria no teto). Resto: procura o chão.
		local base = if i == 1 then Vector3.new(spot.X, 0, spot.Z) else ground(spot)
		local box = buildChest(folder, id, base, rng:NextNumber(0, math.pi * 2))
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Abrir baú"
		prompt.ObjectText = "Baú do tesouro"
		prompt.HoldDuration = 0.6
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt.Parent = box
		prompt.Triggered:Connect(function(player)
			open(player, id, box.Position)
		end)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastTry[player] = nil
	end)
	Log.info("ChestService", `{#spots} baús escondidos`)
end

return ChestService
