--[[
	CombatService (servidor) — combate entre abelhas

	- O cliente só avisa "ataquei" (RequestAttack, sem argumentos).
	- O servidor escolhe o alvo e decide tudo: intervalo, alcance, se o
	  alvo está à frente, se os DOIS estão na zona de disputa e se o alvo
	  não está protegido ao nascer.
	- Atacar cancela a sua própria proteção de nascimento.
	- O dano passa pelo HealthService (derrota única, carga cai no chão).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Regions = require(Shared.Regions)
local Remotes = require(Shared.Remotes)

local HealthService = require(script.Parent.HealthService)
local Notifier = require(script.Parent.Parent.Lib.Notifier)

local CombatService = {}

local lastAttack: { [Player]: number } = {}
local lastWarning: { [Player]: number } = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function warn(player: Player, text: string)
	local now = os.clock()
	if now - (lastWarning[player] or 0) > 3 then
		lastWarning[player] = now
		Notifier.Notify(player, text, "info")
	end
end

local function attack(attacker: Player)
	local now = os.clock()
	if now - (lastAttack[attacker] or 0) < Config.Combat.Cooldown then
		return
	end
	if not HealthService.IsAlive(attacker) then
		return
	end
	local root = rootOf(attacker)
	if not root then
		return
	end
	if not Regions.AllowsPvP(Regions.Classify(root.Position)) then
		warn(attacker, "Combate só na zona de disputa (copas altas e Colmeia Real).")
		return
	end
	lastAttack[attacker] = now
	HealthService.CancelSpawnProtection(attacker)
	Remotes.Get("Effect"):FireAllClients("ataque", root.Position, attacker.UserId)

	-- Alvo: o jogador válido mais próximo à frente.
	local look = root.CFrame.LookVector
	local best, bestDistance = nil, Config.Combat.Range + 2 -- margem para latência
	for _, other in Players:GetPlayers() do
		if other ~= attacker and HealthService.IsAlive(other) then
			local otherRoot = rootOf(other)
			if otherRoot and Regions.AllowsPvP(Regions.Classify(otherRoot.Position)) then
				local offset = otherRoot.Position - root.Position
				local distance = offset.Magnitude
				local inFront = distance < 3 or look:Dot(offset.Unit) >= Config.Combat.FrontDot
				if distance <= bestDistance and inFront then
					best, bestDistance = other, distance
				end
			end
		end
	end

	if best then
		if not HealthService.Damage(best, Config.Combat.Damage, "Jogador", attacker) then
			warn(attacker, `{best.DisplayName} está protegido por ter acabado de nascer.`)
		end
	end
end

function CombatService:Init() end

function CombatService:Start()
	Remotes.Get("RequestAttack").OnServerEvent:Connect(attack)
	Players.PlayerRemoving:Connect(function(player)
		lastAttack[player] = nil
		lastWarning[player] = nil
	end)
	Log.info("CombatService", "pronto")
end

return CombatService
