--[[
	HealthService (servidor) — vida, derrota e renascimento

	Vida fica nos atributos "Health" e "MaxHealth" do Player (o HUD lê).
	Só este serviço muda a vida; ninguém aceita dano vindo do cliente.

	Regras:
	- Vida máxima = Config.Health.Max + melhoria de Resistência.
	- Proteção ao nascer (Config.Health.SpawnProtection), cancelada ao atacar.
	- Em área protegida a vida se recupera aos poucos.
	- Regra ÚNICA de derrota (predador, jogador ou "Redefinir"), aplicada uma
	  vez só (trava `dying`):
	    1. perde Config.Defeat.CargoLossFraction de cada tipo carregado;
	    2. o que caiu fica no chão (DropService) para ser recuperado;
	    3. colmeia, melhorias e mel depositado ficam intactos;
	    4. a tela de derrota lista exatamente o que caiu;
	    5. renasce na própria colmeia, com proteção breve.
	- Sem vidas nem espera extra. Desconectar: a carga nunca é salva, então
	  não há duplicação.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Regions = require(Shared.Regions)
local Remotes = require(Shared.Remotes)

local DropService = require(script.Parent.DropService)
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

-- "Caiu no chão: 3 néctar, 1 Favo Real." (ou "Você não carregava nada.")
function HealthService.DescribeLoss(lost: any): string
	local parts = {}
	if lost.Nectar > 0 then
		table.insert(parts, `{lost.Nectar} néctar`)
	end
	for _, rarity in { "Comum", "Medio", "Raro" } do
		local amount = lost.Combs[rarity] or 0
		if amount > 0 then
			table.insert(parts, `{amount} {Config.Rarities[rarity].DisplayName}`)
		end
	end
	if #parts == 0 then
		return "Você não carregava nada: nada foi perdido."
	end
	return `Caiu no chão (dá para recuperar): {table.concat(parts, ", ")}.`
end

local function die(player: Player, source: DamageSource, attacker: Player?)
	if dying[player] then
		return -- trava: perdas aplicadas uma única vez por derrota
	end
	dying[player] = true
	player:SetAttribute("Health", 0)

	local root = rootOf(player)
	local position = if root then root.Position else Vector3.zero

	-- Parte da carga cai uma vez (a trava acima impede repetir).
	local lost = InventoryService.TakeFraction(player, Config.Defeat.CargoLossFraction)
	DropService.Spawn(position, lost)

	local lines = { "Você foi derrotado!" }
	table.insert(lines, HealthService.DescribeLoss(lost))
	if source == "Jogador" and attacker then
		Notifier.Notify(
			attacker,
			`Você derrotou {player.DisplayName}! Parte da carga dele caiu no chão.`,
			"ok"
		)
	end
	table.insert(lines, "Colmeia, melhorias e mel guardado continuam salvos.")

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
		-- Morreu por outro motivo (ex.: botão "Redefinir"): mesma regra única.
		if not dying[player] then
			dying[player] = true
			local root = rootOf(player)
			local lost = InventoryService.TakeFraction(player, Config.Defeat.CargoLossFraction)
			DropService.Spawn(if root then root.Position else Vector3.zero, lost)
			Notifier.Notify(player, HealthService.DescribeLoss(lost), "info")
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
