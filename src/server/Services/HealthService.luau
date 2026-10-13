--[[
	HealthService (servidor) — vida, derrota e renascimento

	Vida fica nos atributos "Health" e "MaxHealth" do Player (o HUD lê).
	Só este serviço muda a vida; ninguém aceita dano vindo do cliente.

	Regras:
	- Vida máxima = Config.Health.Max + melhoria de Resistência.
	- Proteção ao nascer (Config.Health.SpawnProtection), cancelada ao atacar.
	- Em área protegida a vida se recupera aos poucos.
	- Ao chegar a zero (UMA vez por derrota, garantido pela trava `dying`):
	    1. a carga transportada cai no chão (DropService);
	    2. se foi um predador e a penalidade estiver ligada, UMA célula
	       inacabada perde Config.DeathPenalty.PredatorBuildProgressLoss pontos
	       (nunca abaixo de zero; células concluídas nunca são tocadas);
	    3. o jogador recebe a explicação das perdas;
	    4. renasce na própria colmeia depois de Config.Health.RespawnDelay.
	- Derrota por outro jogador: só perde a carga.

	Ideia futura (não implementada, ver docs/ROADMAP.md): vidas de expedição
	que recarregam com o tempo. Não combinar com esta penalidade sem rebalancear.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Regions = require(Shared.Regions)
local Remotes = require(Shared.Remotes)

local DropService = require(script.Parent.DropService)
local HiveService = require(script.Parent.HiveService)
local InventoryService = require(script.Parent.InventoryService)
local Notifier = require(script.Parent.Parent.Lib.Notifier)
local PlayerDataService = require(script.Parent.PlayerDataService)

local HealthService = {}

export type DamageSource = "Predador" | "Jogador"

local dying: { [Player]: boolean } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function HealthService.MaxHealth(player: Player): number
	local profile = PlayerDataService.Get(player)
	local level = profile.Upgrades.Resistencia or 0
	local base = Config.Health.Max + level * Config.Upgrades.Resistencia.BonusPerLevel
	local info = if profile.Specialty then Config.Specialties[profile.Specialty] else nil
	return math.floor(base * (if info then info.HealthMultiplier else 1))
end

function HealthService.Get(player: Player): number
	local value = player:GetAttribute("Health")
	return if typeof(value) == "number" then value else HealthService.MaxHealth(player)
end

function HealthService.IsAlive(player: Player): boolean
	return not dying[player] and rootOf(player) ~= nil and HealthService.Get(player) > 0
end

function HealthService.IsSpawnProtected(player: Player): boolean
	local untilTime = player:GetAttribute("ProtectedUntil")
	return typeof(untilTime) == "number" and untilTime > now()
end

function HealthService.CancelSpawnProtection(player: Player)
	player:SetAttribute("ProtectedUntil", 0)
end

local function die(player: Player, source: DamageSource, attacker: Player?)
	if dying[player] then
		return -- trava: perdas aplicadas uma única vez por derrota
	end
	dying[player] = true
	player:SetAttribute("Health", 0)

	local root = rootOf(player)
	local position = if root then root.Position else Vector3.zero

	-- 1. Carga cai uma vez (Take esvazia; chamar de novo devolveria vazio).
	local cargo = InventoryService.Take(player)
	DropService.Spawn(position, cargo)

	-- 2. Penalidade de construção (só predador).
	local lines = { "Você foi derrotado!" }
	table.insert(lines, "Perdeu a carga que levava (ela ficou no chão por um tempo).")
	if source == "Predador" and Config.DeathPenalty.Enabled then
		local lost = HiveService.ApplyPredatorPenalty(player, Config.DeathPenalty.PredatorBuildProgressLoss)
		if lost > 0 then
			table.insert(lines, `A célula em construção perdeu {lost} pontos de progresso.`)
		end
	elseif source == "Jogador" and attacker then
		Notifier.Notify(attacker, `Você derrotou {player.DisplayName}! A carga dele caiu no chão.`, "ok")
	end
	table.insert(lines, "Mel, células e melhorias continuam salvos.")

	Remotes.Get("Effect"):FireAllClients("derrota", position)
	Notifier.Notify(player, table.concat(lines, "\n"), "derrota")

	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Health = 0 -- o Roblox renasce depois de Players.RespawnTime
	end
end

-- Aplica dano. Retorna true se o dano entrou.
function HealthService.Damage(
	player: Player,
	amount: number,
	source: DamageSource,
	attacker: Player?
): boolean
	if not HealthService.IsAlive(player) or HealthService.IsSpawnProtected(player) then
		return false
	end
	local health = HealthService.Get(player) - amount
	player:SetAttribute("Health", math.max(0, health))

	local root = rootOf(player)
	if root then
		Remotes.Get("Effect"):FireAllClients("dano", root.Position, player.UserId)
	end
	if health <= 0 then
		die(player, source, attacker)
	end
	return true
end

local function onCharacter(player: Player, character: Model)
	dying[player] = nil
	local max = HealthService.MaxHealth(player)
	player:SetAttribute("MaxHealth", max)
	player:SetAttribute("Health", max)
	player:SetAttribute("ProtectedUntil", now() + Config.Health.SpawnProtection)

	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Connect(function()
		-- Morreu por outro motivo (ex.: botão "Redefinir"): perde só a carga.
		if not dying[player] then
			dying[player] = true
			local root = rootOf(player)
			DropService.Spawn(if root then root.Position else Vector3.zero, InventoryService.Take(player))
		end
	end)
end

function HealthService:Init()
	Players.RespawnTime = Config.Health.RespawnDelay
end

function HealthService:Start()
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		dying[player] = nil
	end)

	-- Vida máxima atualizada (melhorias) e regeneração em área protegida.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				if HealthService.IsAlive(player) then
					local max = HealthService.MaxHealth(player)
					player:SetAttribute("MaxHealth", max)
					local health = math.min(HealthService.Get(player), max)
					local root = rootOf(player)
					if root and Regions.IsProtected(Regions.Classify(root.Position)) then
						health = math.min(max, health + Config.Health.RegenPerSecondInSafeZone)
					end
					player:SetAttribute("Health", health)
				end
			end
		end
	end)

	Log.info("HealthService", "pronto")
end

return HealthService
