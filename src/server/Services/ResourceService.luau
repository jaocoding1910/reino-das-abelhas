--[[
	ResourceService (servidor) — Etapas A/B

	Flores (néctar) e favos coletáveis espalhados pelo mapa.

	Como a coleta funciona:
	- Cada recurso tem um ProximityPrompt (funciona no PC, celular e controle).
	- O jogador segura pelo tempo Config.Collection.InteractTime.
	- O servidor confere TUDO no Triggered: disponibilidade, tempo segurado,
	  distância, frequência e espaço na carga.
	- O primeiro a concluir leva; o recurso some na hora para todos.
	  Como o servidor processa um evento por vez, dois jogadores nunca
	  recebem o mesmo recurso.
	- Depois de um tempo o recurso volta (regeneração configurável).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Log = require(Shared.Util.Log)
local Types = require(Shared.Types)

local Notifier = require(script.Parent.Parent.Lib.Notifier)
local InventoryService = require(script.Parent.InventoryService)
local ProgressionService = require(script.Parent.ProgressionService)
local QuestService = require(script.Parent.QuestService)
local WorldService = require(script.Parent.WorldService)

local ResourceService = {}

type Entry = {
	Kind: "Nectar" | "Comb",
	Rarity: Types.Rarity?,
	Anchor: BasePart, -- peça usada para medir distância
	Visual: Instance,
	Prompt: ProximityPrompt,
	Available: boolean,
	HoldStart: { [Player]: number },
}

local lastAction: { [Player]: number } = {}

local notify = Notifier.Notify

local function makePrompt(parent: BasePart, action: string, object: string): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = Config.Collection.InteractTime
	prompt.MaxActivationDistance = Config.Collection.MaxDistance
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Default
	prompt.Parent = parent
	return prompt
end

local function setAvailable(entry: Entry, available: boolean)
	entry.Available = available
	entry.Prompt.Enabled = available
	if entry.Kind == "Nectar" then
		local center = entry.Visual :: BasePart
		local original = center:GetAttribute("NectarColor")
		local fullColor = if typeof(original) == "Color3" then original else Color3.fromRGB(255, 190, 40)
		center.Color = if available then fullColor else Color3.fromRGB(120, 90, 50)
	end
	for _, item in entry.Visual:GetDescendants() do
		if item:IsA("BasePart") and entry.Kind == "Comb" then
			item.Transparency = if available then 0 else 1
		elseif item:IsA("BillboardGui") or item:IsA("PointLight") or item:IsA("ParticleEmitter") then
			item.Enabled = available
		end
	end
end

local function respawnTime(entry: Entry): number
	if entry.Kind == "Nectar" then
		return Config.Collection.FlowerRespawnTime
	end
	return Config.Collection.CombRespawnTime[entry.Rarity :: Types.Rarity]
end

-- Todas as validações do servidor. Retorna motivo de recusa ou nil.
local function validate(player: Player, entry: Entry): string?
	if not entry.Available then
		return "Outra abelha chegou primeiro!"
	end

	local now = os.clock()
	if now - (lastAction[player] or 0) < Config.Collection.MinIntervalBetweenActions then
		return "Calma, uma coleta por vez."
	end

	local holdStart = entry.HoldStart[player]
	entry.HoldStart[player] = nil
	if not holdStart or now - holdStart < Config.Collection.InteractTime * 0.75 then
		return "Segure o botão até completar a coleta."
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return "Abelha não encontrada."
	end
	-- Margem extra porque a flor é larga e o prompt fica no centro.
	if (root.Position - entry.Anchor.Position).Magnitude > Config.Collection.MaxDistance + 8 then
		return "Chegue mais perto para coletar."
	end

	return nil
end

local function collect(player: Player, entry: Entry)
	local refusal = validate(player, entry)
	if refusal then
		notify(player, refusal, "erro")
		return
	end
	lastAction[player] = os.clock()

	if entry.Kind == "Nectar" then
		local added = InventoryService.AddNectar(player, Config.Collection.NectarPerFlower)
		if added <= 0 then
			notify(player, "Carga cheia! Volte à colmeia para entregar.", "erro")
			return
		end
		notify(player, `+{added} néctar`, "ok")
		ProgressionService.AddXP(player, added * Config.Progression.XP.NectarPerUnit)
		QuestService.Add(player, "Nectar", added)
	else
		local rarity = entry.Rarity :: Types.Rarity
		if not InventoryService.AddComb(player, rarity) then
			notify(player, "Sem espaço para este favo. Entregue sua carga.", "erro")
			return
		end
		notify(player, `+1 {Config.Rarities[rarity].DisplayName} ({Config.Rarities[rarity].Label})`, "ok")
		ProgressionService.AddXP(player, Config.Progression.XP.Comb[rarity])
		QuestService.Add(player, "Comb", 1)
		if rarity == "Medio" then
			QuestService.Add(player, "CombMedio", 1)
		elseif rarity == "Raro" then
			QuestService.Add(player, "CombRaro", 1)
		end
	end

	Remotes.Get("Effect"):FireAllClients("coleta", entry.Anchor.Position, player.UserId)

	-- Some para todos agora; volta depois do tempo de regeneração.
	setAvailable(entry, false)
	task.delay(respawnTime(entry), function()
		setAvailable(entry, true)
	end)
end

local function register(entry: Entry)
	entry.Prompt.PromptButtonHoldBegan:Connect(function(player)
		entry.HoldStart[player] = os.clock()
	end)
	entry.Prompt.PromptButtonHoldEnded:Connect(function(player)
		-- Soltou antes de completar: o Triggered não vem, então só limpamos
		-- se já tiver passado bastante tempo (evita lixo na tabela).
		local started = entry.HoldStart[player]
		if started and os.clock() - started > 5 then
			entry.HoldStart[player] = nil
		end
	end)
	entry.Prompt.Triggered:Connect(function(player)
		collect(player, entry)
	end)
end

function ResourceService:Init() end

function ResourceService:Start()
	local map = WorldService.GetMap()

	for _, center in map.Flowers do
		register({
			Kind = "Nectar",
			Rarity = nil,
			Anchor = center,
			Visual = center,
			Prompt = makePrompt(center, "Coletar néctar", "Flor"),
			Available = true,
			HoldStart = {},
		})
	end

	for _, comb in map.Combs do
		local rarity = (comb:GetAttribute("Rarity") or "Comum") :: Types.Rarity
		local info = Config.Rarities[rarity]
		local anchor = comb.PrimaryPart :: BasePart
		register({
			Kind = "Comb",
			Rarity = rarity,
			Anchor = anchor,
			Visual = comb,
			Prompt = makePrompt(anchor, "Coletar", `{info.DisplayName} ({info.Label})`),
			Available = true,
			HoldStart = {},
		})
	end

	Players.PlayerRemoving:Connect(function(player)
		lastAction[player] = nil
	end)

	Log.info("ResourceService", `{#map.Flowers} flores e {#map.Combs} favos ativos`)
end

return ResourceService
