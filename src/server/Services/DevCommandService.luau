--[[
	DevCommandService (servidor) — comandos de teste, SÓ NO STUDIO

	Digite no chat durante o teste:
	  /mel 1000      ganha mel          /xp 500     ganha XP
	  /noite  /dia   muda a hora        /chuva  /neblina  /limpo
	  /vespa         chama a Vespa      /polen      chuva de pólen
	  /arcoiris      flor arco-íris     /ajuda      lista os comandos
	No jogo publicado este serviço não faz nada.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared.Util.Log)

local BossService = require(script.Parent.BossService)
local DayNightService = require(script.Parent.DayNightService)
local Notifier = require(script.Parent.Parent.Lib.Notifier)
local PlayerDataService = require(script.Parent.PlayerDataService)
local PollenEventService = require(script.Parent.PollenEventService)
local ProgressionService = require(script.Parent.ProgressionService)
local WeatherService = require(script.Parent.WeatherService)

local DevCommandService = {}

local HELP =
	"/mel N · /xp N · /noite · /dia · /chuva · /neblina · /limpo · /vespa · /polen · /arcoiris"

local function run(player: Player, message: string)
	local command, argument = string.match(message, "^/(%a+)%s*(%d*)")
	if not command then
		return
	end
	command = string.lower(command)
	local amount = tonumber(argument) or 1000
	local profile = PlayerDataService.Get(player)
	if command == "mel" then
		profile.Honey += amount
		profile.HoneyEarned += amount
	elseif command == "xp" then
		ProgressionService.AddXP(player, amount)
	elseif command == "noite" then
		DayNightService.SetNight(true)
	elseif command == "dia" then
		DayNightService.SetNight(false)
	elseif command == "chuva" then
		WeatherService.Set("Chuva")
	elseif command == "neblina" then
		WeatherService.Set("Neblina")
	elseif command == "limpo" then
		WeatherService.Set("Limpo")
	elseif command == "vespa" then
		BossService.Spawn()
	elseif command == "polen" then
		task.spawn(PollenEventService.RunPollen)
	elseif command == "arcoiris" then
		PollenEventService.RunRainbow()
	elseif command == "ajuda" then
		Notifier.Notify(player, HELP, "info")
		return
	else
		return
	end
	Notifier.Notify(player, `🛠 Comando de teste: /{command}`, "info")
	Notifier.Changed(player)
end

function DevCommandService:Init() end

function DevCommandService:Start()
	if not RunService:IsStudio() then
		return
	end
	local function watch(player: Player)
		player.Chatted:Connect(function(message)
			run(player, message)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Log.info("DevCommandService", "comandos de teste ligados (Studio): " .. HELP)
end

return DevCommandService
