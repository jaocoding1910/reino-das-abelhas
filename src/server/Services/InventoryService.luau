--[[
	InventoryService (servidor) — Etapas A/B

	Carga TRANSPORTADA de cada abelha (néctar e favos), separada dos
	recursos já depositados no perfil.

	- Limite de carga por peso (Config.Carry).
	- Carga pesada reduz a velocidade, com teto (MaxSpeedPenalty).
	  O valor vai para o atributo "SpeedMultiplier" do Player, que o
	  FlightController do cliente lê.
	- Ao sair do jogo a carga é descartada (não é salva).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Types = require(Shared.Types)

local Notifier = require(script.Parent.Parent.Lib.Notifier)
local PlayerDataService = require(script.Parent.PlayerDataService)

local InventoryService = {}

local cargoByPlayer: { [Player]: Types.Cargo } = {}

local function publish(player: Player)
	Notifier.Changed(player)
end

function InventoryService.Get(player: Player): Types.Cargo
	local cargo = cargoByPlayer[player]
	if not cargo then
		cargo = Types.EmptyCargo()
		cargoByPlayer[player] = cargo
	end
	return cargo
end

function InventoryService.Weight(player: Player): number
	local cargo = InventoryService.Get(player)
	local weight = cargo.Nectar * Config.Carry.NectarWeight
	for rarity, amount in cargo.Combs do
		weight += amount * Config.Carry.CombWeight[rarity]
	end
	return weight
end

local function specialty(player: Player)
	local id = PlayerDataService.Get(player).Specialty
	return if id then Config.Specialties[id] else nil
end

function InventoryService.Capacity(player: Player): number
	local level = PlayerDataService.Get(player).Upgrades.Capacidade or 0
	local base = Config.Carry.BaseCapacity + level * Config.Upgrades.Capacidade.BonusPerLevel
	local info = specialty(player)
	return math.floor(base * (if info then info.CapacityMultiplier else 1))
end

function InventoryService.FreeSpace(player: Player): number
	return math.max(0, InventoryService.Capacity(player) - InventoryService.Weight(player))
end

function InventoryService.IsEmpty(player: Player): boolean
	return InventoryService.Weight(player) <= 0
end

local slowUntil: { [Player]: number } = {}
local slowFactor: { [Player]: number } = {}

-- Velocidade final = bônus da melhoria × penalidade da carga × lentidão (teia).
local function updateSpeed(player: Player)
	local penalty = InventoryService.Weight(player) * Config.Carry.SpeedPenaltyPerWeight
	penalty = math.min(penalty, Config.Carry.MaxSpeedPenalty)
	local level = PlayerDataService.Get(player).Upgrades.Velocidade or 0
	local bonus = 1 + level * Config.Upgrades.Velocidade.BonusPerLevel
	local info = specialty(player)
	if info then
		bonus *= info.SpeedMultiplier
	end
	local slow = if (slowUntil[player] or 0) > os.clock() then slowFactor[player] or 1 else 1
	player:SetAttribute("SpeedMultiplier", bonus * (1 - penalty) * slow)
	player:SetAttribute("Slowed", slow < 1)
end

-- Deixa a abelha mais lenta por um tempo (teia da aranha).
function InventoryService.ApplySlow(player: Player, multiplier: number, duration: number)
	slowUntil[player] = os.clock() + duration
	slowFactor[player] = multiplier
	updateSpeed(player)
	task.delay(duration + 0.05, function()
		if player.Parent then
			updateSpeed(player)
		end
	end)
end

-- Recalcula velocidade e avisa o HUD (usado depois de comprar melhorias).
function InventoryService.Refresh(player: Player)
	updateSpeed(player)
	publish(player)
end

-- Adiciona até `amount` de néctar. Retorna quanto coube de fato.
function InventoryService.AddNectar(player: Player, amount: number): number
	local free = math.floor(InventoryService.FreeSpace(player) / Config.Carry.NectarWeight)
	local added = math.min(amount, free)
	if added > 0 then
		InventoryService.Get(player).Nectar += added
		updateSpeed(player)
		publish(player)
	end
	return added
end

-- Adiciona um favo se houver espaço. Retorna true se coube.
function InventoryService.AddComb(player: Player, rarity: Types.Rarity): boolean
	if InventoryService.FreeSpace(player) < Config.Carry.CombWeight[rarity] then
		return false
	end
	local cargo = InventoryService.Get(player)
	cargo.Combs[rarity] += 1
	updateSpeed(player)
	publish(player)
	return true
end

-- Esvazia a carga e devolve o que havia (usado na entrega e na morte).
-- Chamar duas vezes seguidas devolve vazio na segunda: perda única garantida.
function InventoryService.Take(player: Player): Types.Cargo
	local cargo = InventoryService.Get(player)
	cargoByPlayer[player] = Types.EmptyCargo()
	updateSpeed(player)
	publish(player)
	return cargo
end

function InventoryService:Init() end

function InventoryService:Start()
	Players.PlayerAdded:Connect(updateSpeed)
	for _, player in Players:GetPlayers() do
		updateSpeed(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		-- Desconectou carregando? A carga é perdida (nunca é salva): sem duplicação.
		cargoByPlayer[player] = nil
		slowUntil[player] = nil
		slowFactor[player] = nil
	end)
	Log.info("InventoryService", "pronto")
end

return InventoryService
