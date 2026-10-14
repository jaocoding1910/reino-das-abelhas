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

local Boosts = require(script.Parent.Parent.Lib.Boosts)
local Notifier = require(script.Parent.Parent.Lib.Notifier)
local InventoryService = require(script.Parent.InventoryService)
local PlayerDataService = require(script.Parent.PlayerDataService)
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
local lastSample: { [Player]: { Position: Vector3, Time: number, Character: Model } } = {}

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
		-- Chuva: as flores se recuperam mais rápido.
		local rain = workspace:GetAttribute("Clima") == "Chuva"
		return Config.Collection.FlowerRespawnTime
			* (if rain then Config.Weather.RainRespawnMultiplier else 1)
	end
	local base = Config.Collection.CombRespawnTime[entry.Rarity :: Types.Rarity]
	-- Noite: favos raros voltam mais rápido (mais oportunidade, mais risco).
	if entry.Rarity == "Raro" and workspace:GetAttribute("IsNight") == true then
		return base / Config.DayNight.NightRareChanceMultiplier
	end
	return base
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

	-- Deslocamento impossível há pouco (teleporte)? Coleta bloqueada por um instante.
	local blocked = player:GetAttribute("MovimentoSuspeitoAte")
	if typeof(blocked) == "number" and blocked > now then
		return "Movimento estranho detectado. Tente de novo em instantes."
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

-- Combo: cada coleta feita até Config.Combo.Window segundos depois da
-- anterior sobe um degrau (máx. Config.Combo.Max). O cliente mostra o combo
-- pelos atributos "Combo" e "ComboAte" (hora do servidor em que ele acaba).
local combos: { [Player]: { Count: number, Last: number } } = {}

local function bumpCombo(player: Player): number
	local now = os.clock()
	local combo = combos[player]
	if combo and now - combo.Last <= Config.Combo.Window then
		combo.Count = math.min(Config.Combo.Max, combo.Count + 1)
	else
		combo = { Count = 1, Last = now }
		combos[player] = combo
	end
	combo.Last = now
	player:SetAttribute("Combo", combo.Count)
	player:SetAttribute("ComboAte", workspace:GetServerTimeNow() + Config.Combo.Window)
	return combo.Count
end

local function luckChance(player: Player): number
	local level = PlayerDataService.Get(player).Upgrades.Sorte or 0
	return level * Config.Upgrades.Sorte.BonusPerLevel
end

local function collect(player: Player, entry: Entry)
	local refusal = validate(player, entry)
	if refusal then
		notify(player, refusal, "erro")
		return
	end
	lastAction[player] = os.clock()
	local floating = ""

	if entry.Kind == "Nectar" then
		local amount = Config.Collection.NectarPerFlower
		local golden = entry.Anchor:GetAttribute("Dourada") == true
		if golden then
			amount *= Config.Events.GoldenMultiplier
		end
		if Boosts.IsActive(player, "Dobro") then
			amount *= Config.Potions.Dobro.NectarMultiplier
		end
		if entry.Anchor:GetAttribute("Nuvem") == true then
			amount *= Config.SkyIsland.NectarMultiplier
		end
		local rainbow = entry.Anchor:GetAttribute("ArcoIris") == true
		if rainbow then
			amount *= Config.Rainbow.NectarMultiplier
		end
		local lucky = math.random() < luckChance(player)
		if lucky then
			amount *= 2
		end
		if InventoryService.FreeSpace(player) <= 0 then
			notify(player, "Mochila cheia! Voe até o pote da sua colmeia: a entrega é automática.", "erro")
			return
		end
		local combo = bumpCombo(player)
		amount += (combo - 1) * Config.Combo.NectarPerStep
		local added = InventoryService.AddNectar(player, amount)
		if added <= 0 then
			notify(player, "Mochila cheia! Voe até o pote da sua colmeia: a entrega é automática.", "erro")
			return
		end
		floating = `+{added} 🌼` .. (if combo > 1 then `\nCOMBO x{combo}` else "")
		if rainbow then
			entry.Anchor:SetAttribute("ArcoIris", false) -- o PollenEventService limpa o resto
			QuestService.Add(player, "ArcoIris", 1)
			Remotes.Get("WorldUpdated")
				:FireAllClients(`🌈 {player.DisplayName} pegou a flor arco-íris!`, "ok")
		end
		-- O número comum aparece flutuando na flor; o aviso fica só para o especial.
		local label = if rainbow then "🌈" elseif golden then "🌟" elseif lucky then "🍀" else ""
		if label ~= "" then
			notify(player, `{label} +{added} néctar{if lucky then " (sorte!)" else ""}`, "ok")
		end
		ProgressionService.AddXP(player, added * Config.Progression.XP.NectarPerUnit)
		QuestService.Add(player, "Nectar", added)
	else
		local rarity = entry.Rarity :: Types.Rarity
		if not InventoryService.AddComb(player, rarity) then
			notify(player, "Sem espaço para este favo. Entregue sua carga.", "erro")
			return
		end
		-- Sorte: às vezes vem um favo a mais (se couber).
		local count = 1
		if math.random() < luckChance(player) and InventoryService.AddComb(player, rarity) then
			notify(player, "🍀 Sorte! Favo em dobro!", "ok")
			count = 2
		end
		local combo = bumpCombo(player)
		floating = `+{count} {Config.Rarities[rarity].DisplayName}`
			.. (if combo > 1 then `\nCOMBO x{combo}` else "")
		if rarity ~= "Comum" then
			notify(
				player,
				`+{count} {Config.Rarities[rarity].DisplayName} ({Config.Rarities[rarity].Label})`,
				"ok"
			)
		end
		ProgressionService.AddXP(player, Config.Progression.XP.Comb[rarity])
		QuestService.Add(player, "Comb", 1)
		local model = entry.Visual
		if typeof(model) == "Instance" and model:GetAttribute("Caverna") then
			QuestService.Add(player, "Caverna", 1)
		end
		if rarity == "Medio" then
			QuestService.Add(player, "CombMedio", 1)
		elseif rarity == "Raro" then
			QuestService.Add(player, "CombRaro", 1)
		end
	end

	Remotes.Get("Effect"):FireAllClients("coleta", entry.Anchor.Position, player.UserId, floating)

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
		combos[player] = nil
		lastSample[player] = nil
	end)

	-- Validação plausível de deslocamento: compara a distância andada entre
	-- duas amostras com a maior velocidade possível (com muita folga).
	-- Renascer/teleporte do próprio servidor reinicia a amostra (CharacterAdded).
	task.spawn(function()
		local settings = Config.Movement
		while true do
			task.wait(settings.CheckInterval)
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					local sample = lastSample[player]
					local position = root.Position
					if sample and sample.Character == character then
						local elapsed = os.clock() - sample.Time
						local multiplier = player:GetAttribute("SpeedMultiplier")
						local speed = Config.Flight.BaseSpeed
							* (if typeof(multiplier) == "number" then math.max(1, multiplier) else 1)
							* settings.SpeedFactor
						if (position - sample.Position).Magnitude > speed * elapsed + settings.Slack then
							player:SetAttribute("MovimentoSuspeitoAte", os.clock() + settings.BlockSeconds)
						end
					end
					lastSample[player] = { Position = position, Time = os.clock(), Character = character }
				end
			end
		end
	end)
	local function resetSample(player: Player)
		player.CharacterAdded:Connect(function()
			lastSample[player] = nil
			task.delay(1.5, function()
				lastSample[player] = nil -- o servidor teleporta para a colmeia logo depois
			end)
		end)
	end
	Players.PlayerAdded:Connect(resetSample)
	for _, player in Players:GetPlayers() do
		resetSample(player)
	end

	Log.info("ResourceService", `{#map.Flowers} flores e {#map.Combs} favos ativos`)
end

return ResourceService
