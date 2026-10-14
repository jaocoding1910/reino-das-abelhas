--[[
	RaceService (servidor) — anéis de impulso e corrida até a Ilha nas Nuvens

	- Monta Config.Rings.Count anéis dourados num caminho que sai da praça,
	  serpenteia subindo e chega na Ilha nas Nuvens.
	- Qualquer anel dá impulso de velocidade (o cliente aplica, é só visual
	  de voo; tag "AnelImpulso").
	- Corrida: passar no anel 1 começa; passar em ordem até o último termina.
	  O servidor confere a passagem pela posição da abelha (não confia no
	  cliente) e guarda o melhor tempo (profile.BestRace). Prêmio de mel no
	  máximo a cada Config.Rings.RaceCooldown.
	- Avisa o cliente pelo Remote "RaceUpdate" (anel atual e tempo).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Remotes = require(Shared.Remotes)

local Notifier = require(script.Parent.Parent.Lib.Notifier)
local PlayerDataService = require(script.Parent.PlayerDataService)
local QuestService = require(script.Parent.QuestService)
local WorldService = require(script.Parent.WorldService)

local RaceService = {}

local GOLD = Color3.fromRGB(255, 200, 60)

type RaceState = { Next: number, Start: number }

local ringCenters: { Vector3 } = {}
local races: { [Player]: RaceState } = {}

-- Caminho: começa na praça e sobe serpenteando até a beira da ilha.
function RaceService.PathPoint(t: number): Vector3
	local island = Config.SkyIsland.Position
	-- Sai da praça na direção da ilha (que fica entre duas árvores-colmeia).
	local start = Vector3.new(island.X, 0, island.Z).Unit * 50 + Vector3.new(0, 22, 0)
	local finish = island
		- Vector3.new(island.X, 0, island.Z).Unit * (Config.SkyIsland.Radius + 6)
		+ Vector3.new(0, 8, 0)
	local flatStart = Vector3.new(start.X, 0, start.Z)
	local flatEnd = Vector3.new(finish.X, 0, finish.Z)
	local flat = flatStart:Lerp(flatEnd, t)
	local direction = (flatEnd - flatStart).Unit
	local side = direction:Cross(Vector3.yAxis)
	-- Sobe rápido para passar alto pelas árvores-colmeia; só serpenteia depois delas.
	local wiggle = side * math.sin(t * math.pi * 3) * 40 * math.clamp((t - 0.45) / 0.2, 0, 1)
	local height = start.Y + (finish.Y - start.Y) * (t ^ 0.75) + math.sin(t * math.pi * 2) * 8
	return flat + wiggle + Vector3.new(0, height, 0)
end

local function buildRing(parent: Instance, index: number, center: Vector3, toward: Vector3)
	local model = Instance.new("Model")
	model.Name = `Anel_{index}`
	local facing = CFrame.lookAt(center, toward)
	local radius = Config.Rings.Radius
	local segments = 16
	for k = 0, segments - 1 do
		local angle = (k + 0.5) / segments * math.pi * 2
		local part = Instance.new("Part")
		part.Name = "Segmento"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.Neon
		part.Color = GOLD
		part.Size = Vector3.new(math.pi * 2 * radius / segments + 0.4, 0.9, 0.9)
		part.CFrame = facing
			* CFrame.new(math.cos(angle) * radius, math.sin(angle) * radius, 0)
			* CFrame.Angles(0, 0, angle + math.pi / 2)
		part.Parent = model
	end
	model:SetAttribute("Indice", index)
	model:SetAttribute("Centro", center)
	CollectionService:AddTag(model, "AnelImpulso")
	if index == 1 or index == Config.Rings.Count then
		local anchor = Instance.new("Part")
		anchor.Name = "Rotulo"
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.Transparency = 1
		anchor.Size = Vector3.one
		anchor.Position = center + Vector3.new(0, radius + 4, 0)
		anchor.Parent = model
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromScale(18, 3)
		gui.MaxDistance = 300
		gui.LightInfluence = 0
		gui.Adornee = anchor
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.GothamBlack
		text.TextScaled = true
		text.TextColor3 = GOLD
		text.TextStrokeTransparency = 0.2
		text.Text = if index == 1 then "🏁 LARGADA · corrida até a ilha" else "🏁 CHEGADA"
		text.Parent = gui
		gui.Parent = anchor
	end
	model.Parent = parent
end

local function send(player: Player, info: { [string]: any })
	Remotes.Get("RaceUpdate"):FireClient(player, info)
end

local function finish(player: Player, seconds: number)
	local profile = PlayerDataService.Get(player)
	local best = profile.BestRace
	local record = best <= 0 or seconds < best
	if record then
		profile.BestRace = math.floor(seconds * 100 + 0.5) / 100
	end
	local rewarded = os.time() - profile.LastRaceReward >= Config.Rings.RaceCooldown
	if rewarded then
		profile.LastRaceReward = os.time()
		profile.Honey += Config.Rings.RaceHoney
		profile.HoneyEarned += Config.Rings.RaceHoney
	end
	QuestService.Add(player, "Corrida", 1)
	local timeText = string.format("%.1f", seconds)
	Notifier.Notify(
		player,
		`🏁 Corrida completa em {timeText} s!`
			.. (if record then " Novo recorde!" else "")
			.. (if rewarded then ` +{Config.Rings.RaceHoney} mel` else ""),
		"ok"
	)
	send(player, { Active = false, Finished = seconds, Best = profile.BestRace })
	Notifier.Changed(player)
end

local function step()
	local now = os.clock()
	local total = #ringCenters
	local reach = Config.Rings.Radius + 2
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and PlayerDataService.IsLoaded(player) then
			local race = races[player]
			if race and now - race.Start > Config.Rings.RaceTimeout then
				races[player] = nil
				race = nil
				send(player, { Active = false, TimedOut = true })
			end
			if not race then
				if (root.Position - ringCenters[1]).Magnitude <= reach then
					races[player] = { Next = 2, Start = now }
					send(player, {
						Active = true,
						Next = 2,
						Total = total,
						Best = PlayerDataService.Get(player).BestRace,
					})
				end
			elseif (root.Position - ringCenters[race.Next]).Magnitude <= reach then
				if race.Next >= total then
					races[player] = nil
					finish(player, now - race.Start)
				else
					race.Next += 1
					send(
						player,
						{ Active = true, Next = race.Next, Total = total, Elapsed = now - race.Start }
					)
				end
			end
		end
	end
end

function RaceService:Init() end

function RaceService:Start()
	local folder = Instance.new("Folder")
	folder.Name = "Aneis"
	folder.Parent = WorldService.GetMap().Folder
	local count = Config.Rings.Count
	for i = 1, count do
		ringCenters[i] = RaceService.PathPoint((i - 1) / (count - 1))
	end
	for i = 1, count do
		local toward = if i < count
			then ringCenters[i + 1]
			else ringCenters[i] + (ringCenters[i] - ringCenters[i - 1])
		buildRing(folder, i, ringCenters[i], toward)
	end
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= 0.05 then
			accumulator = 0
			step()
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		races[player] = nil
	end)
	Log.info("RaceService", `{count} anéis até a Ilha nas Nuvens`)
end

return RaceService
