--[[
	PollenEventService (servidor) — evento "Chuva de pólen"

	De tempos em tempos (Config.Events) algumas flores ficam DOURADAS:
	coletar nelas rende GoldenMultiplier × néctar (ResourceService lê o
	atributo "Dourada"). Todos recebem o aviso e o cliente faz cair pólen
	dourado do céu enquanto workspace:GetAttribute("Evento") == "ChuvaDePolen".
	Coletou uma flor dourada? Ela volta normal quando renascer.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Remotes = require(Shared.Remotes)

local WorldService = require(script.Parent.WorldService)

local PollenEventService = {}

local GOLD = Color3.fromRGB(255, 215, 60)

local function makeGolden(center: BasePart)
	center:SetAttribute("Dourada", true)
	center:SetAttribute("MaterialAntes", center.Material.Name)
	center.Color = GOLD
	center.Material = Enum.Material.Neon
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Name = "BrilhoDourado"
	sparkle.Color = ColorSequence.new(GOLD)
	sparkle.LightEmission = 1
	sparkle.Rate = 14
	sparkle.Lifetime = NumberRange.new(1, 1.8)
	sparkle.Speed = NumberRange.new(2, 5)
	sparkle.SpreadAngle = Vector2.new(60, 60)
	sparkle.EmissionDirection = Enum.NormalId.Top
	sparkle.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparkle.Parent = center
	local light = Instance.new("PointLight")
	light.Name = "LuzDourada"
	light.Color = GOLD
	light.Range = 26
	light.Brightness = 2
	light.Parent = center
end

local function clearGolden(center: BasePart)
	if center:GetAttribute("Dourada") ~= true then
		return
	end
	center:SetAttribute("Dourada", false)
	for _, name in { "BrilhoDourado", "LuzDourada" } do
		local item = center:FindFirstChild(name)
		if item then
			item:Destroy()
		end
	end
	-- Só restaura a cor se a flor ainda estiver "cheia" (Neon dourado).
	if center.Material == Enum.Material.Neon then
		local ok, material = pcall(function()
			return (Enum.Material :: any)[center:GetAttribute("MaterialAntes")]
		end)
		center.Material = if ok and material then material else Enum.Material.SmoothPlastic
		local original = center:GetAttribute("NectarColor")
		if typeof(original) == "Color3" then
			center.Color = original
		end
	end
end

local function runEvent()
	local flowers = WorldService.GetMap().Flowers
	local chosen = {}
	local pool = table.clone(flowers)
	for _ = 1, math.min(Config.Events.GoldenFlowers, #pool) do
		local index = math.random(1, #pool)
		local center = table.remove(pool, index)
		-- Só flores com néctar disponível (o aviso de coleta está ligado).
		local prompt = center and center:FindFirstChildOfClass("ProximityPrompt")
		if center and prompt and prompt.Enabled and center:GetAttribute("Dourada") ~= true then
			makeGolden(center)
			table.insert(chosen, center)
		end
	end
	workspace:SetAttribute("Evento", "ChuvaDePolen")
	Remotes.Get("WorldUpdated"):FireAllClients(
		`🌟 Chuva de pólen! {#chosen} flores douradas dão {Config.Events.GoldenMultiplier}× néctar!`,
		"ok"
	)
	Log.info("PollenEventService", `chuva de pólen: {#chosen} flores douradas`)
	task.wait(Config.Events.PollenDuration)
	for _, center in chosen do
		clearGolden(center)
	end
	workspace:SetAttribute("Evento", "")
	Remotes.Get("WorldUpdated"):FireAllClients("A chuva de pólen acabou.", "info")
end

-- Flor arco-íris --------------------------------------------------------------
-- Uma flor por vez vira arco-íris (8× néctar). O cliente faz as cores girarem
-- (tag "FlorArcoIris"). Some quando alguém coleta (ResourceService apaga o
-- atributo "ArcoIris") ou depois de Config.Rainbow.Duration.

local CollectionService = game:GetService("CollectionService")

local function clearRainbow(center: BasePart)
	CollectionService:RemoveTag(center, "FlorArcoIris")
	center:SetAttribute("ArcoIris", false)
	local light = center:FindFirstChild("LuzArcoIris")
	if light then
		light:Destroy()
	end
end

function PollenEventService.RunRainbow()
	local flowers = WorldService.GetMap().Flowers
	local options = {}
	for _, center in flowers do
		local prompt = center:FindFirstChildOfClass("ProximityPrompt")
		if
			prompt
			and prompt.Enabled
			and center:GetAttribute("Dourada") ~= true
			and center:GetAttribute("Nuvem") ~= true
		then
			table.insert(options, center)
		end
	end
	if #options == 0 then
		return
	end
	local center = options[math.random(1, #options)]
	center:SetAttribute("ArcoIris", true)
	CollectionService:AddTag(center, "FlorArcoIris")
	local light = Instance.new("PointLight")
	light.Name = "LuzArcoIris"
	light.Range = 30
	light.Brightness = 2.5
	light.Color = Color3.fromRGB(255, 120, 220)
	light.Parent = center
	Remotes.Get("WorldUpdated"):FireAllClients(
		`🌈 Uma flor arco-íris apareceu! Ela dá {Config.Rainbow.NectarMultiplier}× néctar. Corra!`,
		"ok"
	)
	-- Limpa quando alguém pegar ou quando acabar o tempo.
	local done = false
	local connection: RBXScriptConnection
	connection = center:GetAttributeChangedSignal("ArcoIris"):Connect(function()
		if center:GetAttribute("ArcoIris") ~= true and not done then
			done = true
			connection:Disconnect()
			clearRainbow(center)
		end
	end)
	task.delay(Config.Rainbow.Duration, function()
		if not done then
			done = true
			connection:Disconnect()
			clearRainbow(center)
		end
	end)
end

PollenEventService.RunPollen = runEvent

function PollenEventService:Init()
	workspace:SetAttribute("Evento", "")
end

function PollenEventService:Start()
	task.spawn(function()
		task.wait(Config.Rainbow.FirstAfter)
		while true do
			PollenEventService.RunRainbow()
			task.wait(Config.Rainbow.Interval)
		end
	end)
	task.spawn(function()
		task.wait(Config.Events.FirstPollenAfter)
		while true do
			runEvent()
			task.wait(Config.Events.PollenInterval)
		end
	end)
end

return PollenEventService
