--[[
	CodeService (servidor) — códigos de recompensa

	O jogador digita um código nas Configurações. Se existir em Config.Codes
	e ainda não foi usado por ele, ganha o prêmio (mel e/ou poção).
	Cada código vale uma vez por jogador (profile.Codes).
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

local CodeService = {}

local lastTry: { [Player]: number } = {}

-- "  bem vindo " → "BEMVINDO"
function CodeService.Normalize(raw: string): string
	local upper = string.upper(raw)
	return (string.gsub(upper, "[^%w]", ""))
end

local function redeem(player: Player, raw: unknown)
	local now = os.clock()
	if now - (lastTry[player] or 0) < 1.5 then
		return
	end
	lastTry[player] = now
	if typeof(raw) ~= "string" or #raw > 40 or not PlayerDataService.IsLoaded(player) then
		return
	end
	local code = CodeService.Normalize(raw)
	local reward = Config.Codes[code]
	if not reward then
		Notifier.Notify(player, "Código inválido.", "erro")
		return
	end
	local profile = PlayerDataService.Get(player)
	if profile.Codes[code] then
		Notifier.Notify(player, "Você já usou este código.", "info")
		return
	end
	profile.Codes[code] = true
	local parts = {}
	if reward.Honey then
		profile.Honey += reward.Honey
		profile.HoneyEarned += reward.Honey
		table.insert(parts, `+{reward.Honey} mel`)
	end
	if reward.Potion then
		MerchantService.GivePotion(player, reward.Potion)
		table.insert(parts, Config.Potions[reward.Potion].DisplayName)
	end
	Notifier.Notify(player, `🎁 Código {code}: {table.concat(parts, " e ")}!`, "ok")
	Notifier.Changed(player)
end

function CodeService:Init() end

function CodeService:Start()
	Remotes.Get("RequestCode").OnServerEvent:Connect(redeem)
	Players.PlayerRemoving:Connect(function(player)
		lastTry[player] = nil
	end)
	Log.info("CodeService", "pronto")
end

return CodeService
