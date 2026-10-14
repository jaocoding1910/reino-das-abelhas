--[[
	WeatherService (servidor) — clima

	Troca o tempo de vez em quando (Config.Weather):
	- Limpo: normal.
	- Chuva: céu fechado; as flores renascem mais rápido (ResourceService).
	- Neblina: névoa densa; os predadores enxergam menos (PredatorService).

	Publica workspace:GetAttribute("Clima"); o cliente desenha a chuva.
	A névoa e as nuvens mudam aqui (Lighting e Clouds replicam sozinhos).
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Remotes = require(Shared.Remotes)

local WeatherService = {}

local LOOKS = {
	Limpo = {
		Density = 0.16,
		Haze = 0.9,
		Cover = 0.55,
		CloudDensity = 0.6,
		CloudColor = Color3.fromRGB(255, 250, 245),
	},
	Chuva = {
		Density = 0.3,
		Haze = 1.8,
		Cover = 0.85,
		CloudDensity = 0.85,
		CloudColor = Color3.fromRGB(150, 155, 170),
	},
	Neblina = {
		Density = 0.62,
		Haze = 3,
		Cover = 0.7,
		CloudDensity = 0.7,
		CloudColor = Color3.fromRGB(220, 220, 225),
	},
}

local MESSAGES = {
	Limpo = { "☀️ O tempo abriu!", "ok" },
	Chuva = { "🌧️ Começou a chover: as flores se recuperam mais rápido!", "info" },
	Neblina = { "🌫️ Neblina no reino: os predadores enxergam menos.", "info" },
}

function WeatherService.Pick(roll: number): string
	local acc = 0
	for _, name in { "Limpo", "Chuva", "Neblina" } do
		acc += Config.Weather.Chances[name]
		if roll <= acc then
			return name
		end
	end
	return "Limpo"
end

local function apply(name: string)
	local look = LOOKS[name]
	local info = TweenInfo.new(12, Enum.EasingStyle.Sine)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		TweenService:Create(atmosphere, info, { Density = look.Density, Haze = look.Haze }):Play()
	end
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
	if clouds then
		TweenService
			:Create(
				clouds,
				info,
				{ Cover = look.Cover, Density = look.CloudDensity, Color = look.CloudColor }
			)
			:Play()
	end
	workspace:SetAttribute("Clima", name)
	local message = MESSAGES[name]
	Remotes.Get("WorldUpdated"):FireAllClients(message[1], message[2])
	Log.info("WeatherService", `clima: {name}`)
end

-- Troca o clima na hora (comandos de teste).
function WeatherService.Set(name: string)
	if LOOKS[name] then
		apply(name)
	end
end

function WeatherService:Init()
	workspace:SetAttribute("Clima", "Limpo")
end

function WeatherService:Start()
	task.spawn(function()
		local current = "Limpo"
		while true do
			task.wait(math.random(Config.Weather.MinDuration, Config.Weather.MaxDuration))
			-- Depois de chuva/neblina sempre volta ao limpo; do limpo, sorteia.
			local nextWeather = if current ~= "Limpo" then "Limpo" else WeatherService.Pick(math.random())
			if nextWeather ~= current then
				current = nextWeather
				apply(current)
			end
		end
	end)
end

return WeatherService
